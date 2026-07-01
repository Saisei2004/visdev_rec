#!/usr/bin/env python3
import argparse
import json
import mimetypes
import os
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from update_report_docx import regenerate_docx


DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
GOOGLE_DOC_MIME = "application/vnd.google-apps.document"
DEFAULT_VIDEO_FOLDER_URL = ""

try:
    import certifi
    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except Exception:
    SSL_CONTEXT = ssl.create_default_context()


def parse_drive_id(value):
    value = (value or "").strip()
    if not value:
        return ""
    if "/" not in value and "?" not in value:
        return value
    patterns = [
        "/folders/",
        "/document/d/",
        "/file/d/",
    ]
    for pattern in patterns:
        if pattern in value:
            return value.split(pattern, 1)[1].split("/", 1)[0].split("?", 1)[0]
    parsed = urllib.parse.urlparse(value)
    query = urllib.parse.parse_qs(parsed.query)
    return query.get("id", [""])[0]


def gcloud_path():
    candidates = [
        os.environ.get("ONEFPS_GCLOUD"),
        str(Path.home() / ".local/google-cloud-cli-install/google-cloud-sdk/bin/gcloud"),
        "/opt/homebrew/bin/gcloud",
        "/usr/local/bin/gcloud",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    return "gcloud"


def access_token():
    commands = [
        [gcloud_path(), "auth", "application-default", "print-access-token"],
        [gcloud_path(), "auth", "print-access-token"],
    ]
    last_error = None
    for command in commands:
        try:
            result = subprocess.run(command, check=True, capture_output=True, text=True)
            token = result.stdout.strip()
            if token:
                return token
        except Exception as exc:
            last_error = exc
    raise RuntimeError(f"Google認証トークンを取得できませんでした: {last_error}")


def request_json(method, url, token, payload=None, headers=None):
    data = None
    all_headers = {"Authorization": f"Bearer {token}"}
    if headers:
        all_headers.update(headers)
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        all_headers["Content-Type"] = "application/json; charset=UTF-8"
    request = urllib.request.Request(url, data=data, headers=all_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60, context=SSL_CONTEXT) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Google APIエラー {exc.code}: {detail}") from exc
    if not body:
        return {}
    return json.loads(body.decode("utf-8"))


def request_bytes(method, url, token):
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=120, context=SSL_CONTEXT) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Google APIエラー {exc.code}: {detail}") from exc


def find_report_document(token, folder_id, name):
    escaped_name = name.replace("\\", "\\\\").replace("'", "\\'")
    query = (
        f"'{folder_id}' in parents and "
        f"name = '{escaped_name}' and "
        f"mimeType = '{GOOGLE_DOC_MIME}' and trashed = false"
    )
    params = urllib.parse.urlencode({
        "q": query,
        "fields": "files(id,name,mimeType,webViewLink)",
        "pageSize": "10",
        "supportsAllDrives": "true",
        "includeItemsFromAllDrives": "true",
    })
    result = request_json("GET", f"https://www.googleapis.com/drive/v3/files?{params}", token)
    files = result.get("files", [])
    return files[0] if files else None


def create_google_document(token, folder_id, name, docx_path):
    boundary = "onefps-" + uuid.uuid4().hex
    metadata = {"name": name, "parents": [folder_id], "mimeType": GOOGLE_DOC_MIME}
    media = Path(docx_path).read_bytes()
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        b"Content-Type: application/json; charset=UTF-8\r\n\r\n",
        json.dumps(metadata).encode("utf-8"),
        b"\r\n",
        f"--{boundary}\r\n".encode(),
        f"Content-Type: {DOCX_MIME}\r\n\r\n".encode(),
        media,
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    params = urllib.parse.urlencode({
        "uploadType": "multipart",
        "fields": "id,name,mimeType,webViewLink",
        "supportsAllDrives": "true",
    })
    request = urllib.request.Request(
        f"https://www.googleapis.com/upload/drive/v3/files?{params}",
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/related; boundary={boundary}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180, context=SSL_CONTEXT) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Google Drive新規作成に失敗しました {exc.code}: {detail}") from exc


def find_drive_file(token, folder_id, name):
    escaped_name = name.replace("\\", "\\\\").replace("'", "\\'")
    query = f"'{folder_id}' in parents and name = '{escaped_name}' and trashed = false"
    params = urllib.parse.urlencode({
        "q": query,
        "fields": "files(id,name,mimeType,webViewLink)",
        "pageSize": "1",
        "supportsAllDrives": "true",
        "includeItemsFromAllDrives": "true",
    })
    result = request_json("GET", f"https://www.googleapis.com/drive/v3/files?{params}", token)
    files = result.get("files", [])
    return files[0] if files else None


def export_google_docx(token, document_id, output_path):
    params = urllib.parse.urlencode({"mimeType": DOCX_MIME})
    data = request_bytes(
        "GET",
        f"https://www.googleapis.com/drive/v3/files/{document_id}/export?{params}",
        token,
    )
    Path(output_path).write_bytes(data)


def multipart_upload_update(token, file_id, docx_path):
    boundary = "onefps-" + uuid.uuid4().hex
    metadata = {"mimeType": GOOGLE_DOC_MIME}
    media = Path(docx_path).read_bytes()
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        b"Content-Type: application/json; charset=UTF-8\r\n\r\n",
        json.dumps(metadata).encode("utf-8"),
        b"\r\n",
        f"--{boundary}\r\n".encode(),
        f"Content-Type: {DOCX_MIME}\r\n\r\n".encode(),
        media,
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    params = urllib.parse.urlencode({
        "uploadType": "multipart",
        "fields": "id,name,mimeType,webViewLink",
        "supportsAllDrives": "true",
    })
    request = urllib.request.Request(
        f"https://www.googleapis.com/upload/drive/v3/files/{file_id}?{params}",
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/related; boundary={boundary}",
        },
        method="PATCH",
    )
    try:
        with urllib.request.urlopen(request, timeout=180, context=SSL_CONTEXT) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Google Drive上書きに失敗しました {exc.code}: {detail}") from exc


def upload_video(token, folder_id, video_path):
    path = Path(video_path)
    if not path.exists():
        raise RuntimeError(f"動画が見つかりません: {video_path}")
    boundary = "onefps-" + uuid.uuid4().hex
    content_type = mimetypes.guess_type(path.name)[0] or "video/mp4"
    metadata = {"name": path.name, "parents": [folder_id]}
    existing = find_drive_file(token, folder_id, path.name)
    if existing:
        metadata = {"name": path.name}
    media = path.read_bytes()
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        b"Content-Type: application/json; charset=UTF-8\r\n\r\n",
        json.dumps(metadata).encode("utf-8"),
        b"\r\n",
        f"--{boundary}\r\n".encode(),
        f"Content-Type: {content_type}\r\n\r\n".encode(),
        media,
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    params = urllib.parse.urlencode({
        "uploadType": "multipart",
        "fields": "id,name,webViewLink",
        "supportsAllDrives": "true",
    })
    method = "PATCH" if existing else "POST"
    target = (
        f"https://www.googleapis.com/upload/drive/v3/files/{existing['id']}?{params}"
        if existing
        else f"https://www.googleapis.com/upload/drive/v3/files?{params}"
    )
    request = urllib.request.Request(
        target,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/related; boundary={boundary}",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=600, context=SSL_CONTEXT) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"動画アップロードに失敗しました {exc.code}: {detail}") from exc


def trash_file(token, file_id):
    return request_json(
        "PATCH",
        f"https://www.googleapis.com/drive/v3/files/{file_id}?supportsAllDrives=true&fields=id,name,trashed",
        token,
        payload={"trashed": True},
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--folder-url", required=True)
    parser.add_argument("--video-folder-url", default=DEFAULT_VIDEO_FOLDER_URL)
    parser.add_argument("--document-name", default="報告書（6月分）")
    parser.add_argument("--entries-json", required=True)
    parser.add_argument("--template")
    parser.add_argument("--video")
    parser.add_argument("--output-json")
    args = parser.parse_args()

    token = access_token()
    folder_id = parse_drive_id(args.folder_url)
    video_folder_id = parse_drive_id(args.video_folder_url)
    if not folder_id:
        raise RuntimeError("DriveフォルダIDを取得できませんでした。")
    if args.video and not video_folder_id:
        video_folder_id = folder_id

    with tempfile.TemporaryDirectory() as tmp:
        template_path = Path(tmp) / "drive-template.docx"
        output_path = Path(tmp) / "drive-updated.docx"
        document = find_report_document(token, folder_id, args.document_name)
        video_result = None
        entries_path = Path(args.entries_json)
        if args.video:
            video_result = upload_video(token, video_folder_id, args.video)
            misplaced_video = find_drive_file(token, folder_id, Path(args.video).name)
            if misplaced_video and misplaced_video.get("id") != video_result.get("id"):
                trash_file(token, misplaced_video["id"])
            entries = json.loads(entries_path.read_text(encoding="utf-8"))
            if entries:
                entries[-1]["videoLink"] = video_result.get("webViewLink") or video_result.get("name") or ""
                args_entries_path = Path(args.entries_json)
                args_entries_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
                entries_path = Path(tmp) / "entries-with-video-link.json"
                entries_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
        if args.template:
            template_path = Path(args.template).expanduser()
            if not template_path.exists():
                raise RuntimeError(f"報告書テンプレートが見つかりません: {template_path}")
        else:
            if not document:
                raise RuntimeError(f"Driveフォルダ内にGoogleドキュメント「{args.document_name}」が見つかりません。新規作成には --template が必要です。")
            export_google_docx(token, document["id"], template_path)
        regenerate_docx(str(template_path), str(output_path), str(entries_path))
        if document:
            updated = multipart_upload_update(token, document["id"], output_path)
        else:
            updated = create_google_document(token, folder_id, args.document_name, output_path)

    result = {"document": updated, "video": video_result}
    if args.output_json:
        Path(args.output_json).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
