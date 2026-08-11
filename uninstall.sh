#!/usr/bin/env bash
# uninstall.sh — removes the /start-conversation skill and its state files.
#
#   bash ~/Desktop/start-conversation-skill/uninstall.sh
#
# The Spokenly MCP registration is NOT removed automatically — other skills and
# your CLAUDE.md rule may still depend on it. The command is printed instead.

set -euo pipefail

# Same profile resolution as install.sh — removing from the wrong config dir would
# leave the skill live. Override with CLAUDE_CONFIG_DIR=... or a path argument.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET="${1:-$CONFIG_DIR/skills/start-conversation}"

printf '\033[1mUninstalling /start-conversation\033[0m\n'
printf '  config dir: %s\n' "$CONFIG_DIR"

if [ -d "$TARGET" ]; then
  rm -rf "$TARGET"
  printf '  removed  %s\n' "$TARGET"
else
  printf '  skipped  %s (not installed)\n' "$TARGET"
fi

for f in .voice-lang .voice-gender .voice-lang-default .voice-off; do
  if [ -f "$CONFIG_DIR/$f" ]; then
    rm -f "$CONFIG_DIR/$f"
    printf '  removed  %s/%s\n' "$CONFIG_DIR" "$f"
  fi
done

echo
echo "Spokenly is left registered. To remove it too:"
echo "    claude mcp remove spokenly --scope user"
echo
echo "Restart Claude Code for the skill to disappear."
