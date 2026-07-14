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

## Cross-device acceptance

- The Mac detected the Windows device `SAISEI_2` and read all six Windows-created schema-2 events successfully.
- All 24 shared event IDs were unique, and the Mac confirmed the Windows handoff for `SYS-WINDOWS-COMPAT`.
- Mac-to-Windows and Windows-to-Mac Task Hub synchronization passed. `SYS-WINDOWS-COMPAT` is complete.
- Physical monitor unplug/replug and explicitly authorized live Drive/Slack posting remain tracked separately as `SYS-WINDOWS-COMPAT-E2E`.

## GitHub publication

- Branch: `feature/windows-compatible-system`
- Implementation commit accepted by the Mac: `c9c8270f3a681b6b7a93811171e3fe69b3080411`
- Draft PR: [#2](https://github.com/Saisei2004/visdev_rec/pull/2), targeting `feature/drive-report-submit`
- GitHub CLI remains unauthenticated locally; the branch was pushed through Git Credential Manager and the Draft PR was created through the GitHub integration.
