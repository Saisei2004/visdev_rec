# Windows compatibility verification

Verified on 2026-07-13 against base commit `a9d38f067e34a4264835edfeaa4f28935569bb26`.

## Automated checks

- Task Hub: 5/5 tests passed, including concurrent Mac/Windows append, Mac event reading, exclusive event creation, and persistent device ID.
- Reporting: 5/5 tests passed, including dry-run, independent permissions, partial-success retry, macOS receipt schema, and explicit `not_checked` sources.
- .NET: Release build succeeded with zero warnings and zero errors.
- Windows harness: stable monitor resolution, missing-monitor no-fallback behavior, persisted configuration, and minimal popup layout passed.
- Capture smoke: Desktop Duplication through ffmpeg `ddagrab` produced H.264, 960x600, 1/1 FPS. The temporary screen recording was deleted after `ffprobe` validation.

## Installed-system checks

- Task Hub CLI `sync` and `brief` succeeded against the Box event directory.
- Task Hub UI health succeeded on `127.0.0.1:7700`; no non-loopback listener is configured.
- Logon sync and 60-second sync tasks are registered; the minute task returned exit code 0.
- Recorder logon task is registered and starts the installed WPF process.
- Two attached displays resolved to distinct stable identities; the selected display survived application restart.
- The settings UI was opened and saved; minimal popup mode persisted as 40x40 and renders only the state dot by layout test.
- A Windows `device.register` event and subsequent task updates were added as new schema-2 files. Existing event files were not modified by the implementation.

## External-write safety

- No video upload, Drive update, Slack post, Gmail read, or GitHub write was performed during development.
- Report execution defaults to dry-run. Actual execution requires `--execute` plus a separate permission for each requested destination.
- The WPF batch UI asks the three required questions independently before external execution.
- Slack publishing requires `#日報` and a configured personal `thread_ts`; channel-root posting is rejected.

## Pending external confirmation

- A Mac must sync Box and confirm that the Windows-created schema-2 event files materialize there. Until then, cross-device Box acceptance is incomplete.
- GitHub CLI is installed but not authenticated on this Windows PC. Push and Draft PR creation remain pending authentication.
