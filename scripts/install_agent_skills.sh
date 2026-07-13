#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/skills/visitas-daily-report"

for target in "$HOME/.agents/skills/visitas-daily-report" "$HOME/.claude/skills/visitas-daily-report"; do
  mkdir -p "$target"
  rm -rf "$target/references"
  cp "$SOURCE/SKILL.md" "$target/SKILL.md"
  cp -R "$SOURCE/references" "$target/references"
done

echo "Codex/Claudeへ visitas-daily-report Skillをインストールしました。"
