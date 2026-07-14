---
name: visitas-task-review
description: Use when the user asks to review, update, summarize, prioritize, plan, start, finish, or hand off Visitas tasks, progress, next actions, blockers, deadlines, roadmap position, PR/issue follow-up, or asks what to do next.
---

# Visitas Task Review v2

Use `~/visitas-tasks` as the shared task and handoff layer for Codex, Claude, and every Mac or Windows PC signed into the user's Box account.

## Start every Visitas task turn

1. Detect the current agent: use actor `codex` in Codex and `claude` in Claude.
2. Read `~/visitas-tasks/AGENT.md` completely.
3. Run:

   ```bash
   ~/visitas-tasks/taskctl.py --actor <actor> sync
   ~/visitas-tasks/taskctl.py --actor <actor> brief
   ```

   On Windows run the equivalent commands through the Python launcher:

   ```powershell
   py -3 "$env:USERPROFILE\visitas-tasks\taskctl.py" --actor <actor> sync
   py -3 "$env:USERPROFILE\visitas-tasks\taskctl.py" --actor <actor> brief
   ```

4. If implementation context matters, read `~/visitas-tasks/KNOWLEDGE.md`.
5. Tell the user the current focus and any blocker in one concise sentence before longer work.

## Record work as it happens

- Create a task when a new actionable Visitas item appears and no matching `source_ref` exists.
- Mark it `in_progress` when work starts.
- Record `waiting` or `blocked` with the concrete external dependency.
- Mark it `done` only after completion is verified.
- Use `github-import` for live assigned Issues. Do not infer Slack, Gmail, or planning-doc status without checking that source.
- Record each source as `checked`, `not_checked`, or `blocked` with `source-check`.

Never directly edit `tasks.json` or files below the Box `data/events` directory.

## End every material work turn

Update task status and record a handoff containing:

- the task ID;
- what changed or was learned;
- the exact next action;
- important absolute file paths or URLs;
- verification performed and its result.

Then run `sync`. This is mandatory even when the same agent expects to continue, because another PC or agent may start next.

## Privacy and correctness

- Save only summaries, routing handles, and next actions. Do not copy Slack bodies, Gmail bodies, medical content, credentials, or private source material into the Hub.
- Keep "checked" separate from "not checked". Never present a partial sweep as a full current-state audit.
- Do not commit this personal Hub to a Visitas team repository.
