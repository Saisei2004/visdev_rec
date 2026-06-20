#!/usr/bin/env python3
import argparse
import copy
import json
import shutil
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape


NS_W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
ET.register_namespace("w", NS_W)


def q(name):
    return f"{{{NS_W}}}{name}"


def read_section_properties(doc_xml):
    try:
        root = ET.fromstring(doc_xml)
        body = root.find(q("body"))
        if body is not None:
            sect = body.find(q("sectPr"))
            if sect is not None:
                return ET.tostring(sect, encoding="unicode")
    except ET.ParseError:
        pass
    return (
        '<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>'
        "</w:sectPr>"
    )


def text_run(text, bold=False):
    safe = escape(str(text or ""))
    preserve = ' xml:space="preserve"' if safe.strip() != safe else ""
    props = "<w:rPr><w:b/></w:rPr>" if bold else ""
    return f"<w:r>{props}<w:t{preserve}>{safe}</w:t></w:r>"


def paragraph(text="", bold=False, align=None, page_break=False):
    ppr = ""
    if align:
        ppr = f'<w:pPr><w:jc w:val="{align}"/></w:pPr>'
    runs = '<w:r><w:br w:type="page"/></w:r>' if page_break else text_run(text, bold)
    return f"<w:p>{ppr}{runs}</w:p>"


def table_cell(text="", bold=False):
    return (
        '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/>'
        '<w:vAlign w:val="center"/></w:tcPr>'
        f'{paragraph(text, bold=bold, align="center" if bold else None)}'
        "</w:tc>"
    )


def table_row(values, bold_first=False):
    cells = []
    for index, value in enumerate(values):
        cells.append(table_cell(value, bold=(bold_first and index == 0) or values[0] == "項目"))
    return "<w:tr>" + "".join(cells) + "</w:tr>"


def generated_report_table(entry):
    video_link = entry.get("videoLink") or entry.get("videoFileName") or ""
    rows = [
        ("項目", "入力欄", "備考欄"),
        ("担当者", entry.get("reporter", ""), ""),
        ("日付", entry.get("displayDate", ""), ""),
        ("業務時間", f'{entry.get("hours", 0)}h', "切り捨て1時間単位"),
        ("業務プラン", entry.get("workPlan", ""), ""),
        ("業務内容", entry.get("workContent", ""), ""),
        ("業務動画リンク", video_link, f'提出動画: {entry.get("videoFileName", "")}'),
        ("次回までのTask", entry.get("nextTask", ""), ""),
        ("業務は順調ですか？", entry.get("status", ""), ""),
        ("Visitasへのメッセージ", entry.get("message", ""), ""),
    ]
    borders = (
        '<w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '<w:left w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '<w:right w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '<w:insideH w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '<w:insideV w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
        '</w:tblBorders></w:tblPr>'
    )
    grid = '<w:tblGrid><w:gridCol w:w="2500"/><w:gridCol w:w="4300"/><w:gridCol w:w="3000"/></w:tblGrid>'
    return "<w:tbl>" + borders + grid + "".join(table_row(row, bold_first=True) for row in rows) + "</w:tbl>"


def clear_paragraph_text(paragraph_element, text):
    ppr = paragraph_element.find(q("pPr"))
    for child in list(paragraph_element):
        if ppr is not None and child is ppr:
            continue
        paragraph_element.remove(child)
    run = ET.SubElement(paragraph_element, q("r"))
    text_element = ET.SubElement(run, q("t"))
    value = str(text or "")
    if value.strip() != value:
        text_element.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
    text_element.text = value


def set_cell_text(table_element, row_index, col_index, text):
    rows = table_element.findall(q("tr"))
    if row_index >= len(rows):
        return
    cells = rows[row_index].findall(q("tc"))
    if col_index >= len(cells):
        return
    paragraphs = cells[col_index].findall(q("p"))
    if not paragraphs:
        paragraphs = [ET.SubElement(cells[col_index], q("p"))]
    clear_paragraph_text(paragraphs[0], text)
    for extra in paragraphs[1:]:
        cells[col_index].remove(extra)


def fill_template_table(table_element, entry):
    video_link = entry.get("videoLink") or entry.get("videoFileName") or ""
    values = {
        1: (entry.get("reporter", ""), ""),
        2: (entry.get("displayDate", ""), ""),
        3: (f'{entry.get("hours", 0)}h', "切り捨て1時間単位"),
        4: (entry.get("workPlan", ""), ""),
        5: (entry.get("workContent", ""), ""),
        6: (video_link, f'提出動画: {entry.get("videoFileName", "")}'),
        7: (entry.get("nextTask", ""), ""),
        8: (entry.get("status", ""), ""),
        9: (entry.get("message", ""), ""),
    }
    for row_index, (input_text, note_text) in values.items():
        set_cell_text(table_element, row_index, 1, input_text)
        set_cell_text(table_element, row_index, 2, note_text)


def page_break_element():
    return ET.fromstring(paragraph(page_break=True))


def build_document_tree_from_template(original_doc, entries):
    root = ET.fromstring(original_doc)
    body = root.find(q("body"))
    if body is None:
        raise ValueError("DOCXテンプレートの本文が見つかりません。")

    children = list(body)
    sect_pr = body.find(q("sectPr"))
    content_children = [child for child in children if child.tag != q("sectPr")]
    table_index = next((index for index, child in enumerate(content_children) if child.tag == q("tbl")), None)
    if table_index is None:
        raise ValueError("DOCXテンプレートに表が見つかりません。")

    prefix = content_children[:table_index]
    table_template = content_children[table_index]

    for child in list(body):
        body.remove(child)

    if not entries:
        entries = [{}]
    for index, entry in enumerate(entries):
        if index > 0:
            body.append(page_break_element())
        for element in prefix:
            body.append(copy.deepcopy(element))
        table = copy.deepcopy(table_template)
        fill_template_table(table, entry)
        body.append(table)

    if sect_pr is not None:
        body.append(copy.deepcopy(sect_pr))
    return root


def regenerate_docx(template, output, entries_json):
    entries = json.loads(Path(entries_json).read_text(encoding="utf-8"))
    entries.sort(key=lambda item: item.get("date", ""))
    output = Path(output)
    source = Path(template)
    if not source.exists() and output.exists():
        source = output
    if not source.exists():
        raise FileNotFoundError(f"テンプレートDOCXが見つかりません: {template}")

    with zipfile.ZipFile(source, "r") as zin:
        original_doc = zin.read("word/document.xml").decode("utf-8")
        try:
            root = build_document_tree_from_template(original_doc, entries)
            new_doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + ET.tostring(root, encoding="unicode")
        except Exception:
            sect_pr = read_section_properties(original_doc)
            new_doc = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                f'<w:document xmlns:w="{NS_W}"><w:body>'
                + "".join(generated_report_table(entry) for entry in entries)
                + sect_pr
                + "</w:body></w:document>"
            )
        with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp_file:
            tmp_path = Path(tmp_file.name)
        try:
            with zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
                seen = set()
                for item in zin.infolist():
                    if item.filename == "word/document.xml":
                        zout.writestr(item, new_doc.encode("utf-8"))
                    else:
                        zout.writestr(item, zin.read(item.filename))
                    seen.add(item.filename)
                if "word/document.xml" not in seen:
                    zout.writestr("word/document.xml", new_doc.encode("utf-8"))
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(tmp_path), output)
        finally:
            tmp_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--entries-json", required=True)
    args = parser.parse_args()
    regenerate_docx(args.template, args.output, args.entries_json)


if __name__ == "__main__":
    main()
