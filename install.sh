#!/usr/bin/env bash
# install.sh — installs the multilingual /start-conversation voice skill for Claude Code.
# Run with --help for usage.

set -euo pipefail

usage() {
  cat <<'USAGE'
install.sh — installs the /start-conversation voice skill for Claude Code

From GitHub, one line:
  curl -fsSL https://raw.githubusercontent.com/mmuminovic/start-conversation-skill/main/install.sh | bash

From a local copy of the folder:
  bash ~/Desktop/start-conversation-skill/install.sh

Options:
  --default-lang <code>  language used when /start-conversation gets no argument
  --config-dir <path>    Claude config dir (default: $CLAUDE_CONFIG_DIR, else ~/.claude)
  --dir <path>           install target (default: <config-dir>/skills/start-conversation)
  --no-mcp               do not register the Spokenly MCP server
  --force                overwrite an existing installation without warning
  -h, --help             this text

Multiple Claude profiles? Skills live in $CLAUDE_CONFIG_DIR/skills, so install once
per profile:
  CLAUDE_CONFIG_DIR=~/.claude-personal bash install.sh
  CLAUDE_CONFIG_DIR=~/.claude-work     bash install.sh

Pass options through a pipe with -s --
  curl -fsSL <url>/install.sh | bash -s -- --default-lang en

Env: SC_REPO (default mmuminovic/start-conversation-skill), SC_REF (default main)

Spokenly must be installed separately — see SPOKENLY-SETUP.md
USAGE
}

REPO="${SC_REPO:-mmuminovic/start-conversation-skill}"
REF="${SC_REF:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$REF"

# Claude Code reads user skills from $CLAUDE_CONFIG_DIR/skills (default ~/.claude/skills).
# Multi-profile setups — e.g. aliases like
#   claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'
# — set this per profile. Honour it: installing into the wrong profile makes the
# skill invisible. Override with --config-dir, or install once per profile.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET=""
DEFAULT_LANG=""
REGISTER_MCP=1
FORCE=0

BRIDGE="$HOME/Library/Application Support/Spokenly/mcp-bridge.sh"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mfail\033[0m  %s\n' "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --default-lang) DEFAULT_LANG="${2:-}"; shift 2 ;;
    --config-dir)   CONFIG_DIR="${2:-$CONFIG_DIR}"; shift 2 ;;
    --dir)          TARGET="${2:-}"; shift 2 ;;
    --no-mcp)       REGISTER_MCP=0; shift ;;
    --force)        FORCE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

TARGET="${TARGET:-$CONFIG_DIR/skills/start-conversation}"
STATE_DIR="$CONFIG_DIR"

bold "Installing /start-conversation"
ok "config dir: $CONFIG_DIR"

# ------------------------------------------------------------------- 1. sources

SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  CAND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$CAND/skill/SKILL.md" ] && SRC_DIR="$CAND"
fi

if [ -d "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
  warn "$TARGET already exists — overwriting its files (state files are kept)"
fi

mkdir -p "$TARGET"

if [ -n "$SRC_DIR" ]; then
  cp "$SRC_DIR/skill/SKILL.md" "$TARGET/SKILL.md"
  cp "$SRC_DIR/skill/speak.sh" "$TARGET/speak.sh"
  ok "copied from $SRC_DIR/skill"
else
  command -v curl >/dev/null 2>&1 || { fail "curl not found"; exit 1; }
  for f in SKILL.md speak.sh; do
    if ! curl -fsSL "$RAW/skill/$f" -o "$TARGET/$f" 2>/dev/null; then
      fail "could not download skill/$f from $REPO@$REF"
      echo
      echo "  The repo is probably not pushed to GitHub yet — see the Publishing"
      echo "  section of README.md. Until then install from the local folder:"
      echo "      bash ~/Desktop/start-conversation-skill/install.sh"
      echo
      echo "  Different repo or branch? Set SC_REPO / SC_REF:"
      echo "      SC_REPO=user/repo SC_REF=main bash install.sh"
      exit 1
    fi
  done
  ok "downloaded from $REPO@$REF"
fi

chmod +x "$TARGET/speak.sh"
grep -q '^name: start-conversation' "$TARGET/SKILL.md" || { fail "SKILL.md looks corrupted"; exit 1; }
ok "installed to $TARGET"

# ------------------------------------------------------- 2. default language

mkdir -p "$STATE_DIR"
rm -f "$STATE_DIR/.voice-lang" "$STATE_DIR/.voice-off"   # never start armed

if [ -n "$DEFAULT_LANG" ]; then
  printf '%s' "$DEFAULT_LANG" > "$STATE_DIR/.voice-lang-default"
  ok "default language: $DEFAULT_LANG"
elif [ -f "$STATE_DIR/.voice-lang-default" ]; then
  ok "default language: $(cat "$STATE_DIR/.voice-lang-default") (kept)"
else
  printf 'bs' > "$STATE_DIR/.voice-lang-default"
  ok "default language: bs (change with --default-lang en)"
fi

# ------------------------------------------------------------ 3. dependencies

if command -v jq >/dev/null 2>&1; then
  ok "jq found — the voice loop hook can run"
else
  fail "jq NOT found — the loop hook cannot run. Install it: brew install jq"
fi

if command -v uvx >/dev/null 2>&1; then
  ok "uvx found — neural Edge TTS voices available"
else
  warn "uvx not found — falling back to the built-in macOS 'say' voices."
  warn "For neural voices: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

command -v afplay >/dev/null 2>&1 && ok "afplay found" || warn "afplay not found — this skill targets macOS"

# --------------------------------------------------------------- 4. Spokenly

if [ -f "$BRIDGE" ]; then
  ok "Spokenly MCP bridge found"
  if [ "$REGISTER_MCP" -eq 1 ] && command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -qi '^spokenly'; then
      ok "Spokenly already registered as an MCP server"
    elif claude mcp add spokenly --scope user -- "$BRIDGE" >/dev/null 2>&1; then
      ok "registered Spokenly as a user-scoped MCP server"
    else
      warn "could not register automatically. Run it yourself:"
      printf '        claude mcp add spokenly --scope user -- "%s"\n' "$BRIDGE"
    fi
  elif [ "$REGISTER_MCP" -eq 1 ]; then
    warn "the 'claude' CLI is not on PATH — register manually:"
    printf '        claude mcp add spokenly --scope user -- "%s"\n' "$BRIDGE"
  fi
else
  warn "Spokenly is not installed (no mcp-bridge.sh)."
  warn "The skill is installed, but the voice loop needs Spokenly — see SPOKENLY-SETUP.md"
fi

# ------------------------------------------------------------------ 5. summary

# Multi-profile setups: point out the profiles that did NOT get the skill.
OTHERS=""
for c in "$HOME/.claude" "$HOME/.claude-personal" "$HOME/.claude-work"; do
  [ -d "$c" ] && [ "$c" != "$CONFIG_DIR" ] && OTHERS="$OTHERS $c"
done

echo
bold "Done."
echo "  Restart Claude Code, then try:"
echo "     /start-conversation en"
echo "     /start-conversation de female"
echo "     /start-conversation sr"
echo
echo "  All languages:  $TARGET/speak.sh --list"
echo "  Test the voice: $TARGET/speak.sh -l en 'Voice mode is working.'"
echo "  Stuck in the loop? rm -f $STATE_DIR/.voice-lang"

if [ -n "$OTHERS" ]; then
  echo
  warn "installed into $CONFIG_DIR only. Other Claude profiles found:"
  for c in $OTHERS; do printf '        %s\n' "$c"; done
  echo "        Install there too with:"
  for c in $OTHERS; do printf '        CLAUDE_CONFIG_DIR=%s bash install.sh\n' "$c"; done
fi
