# Spokenly — download, setup, and pairing with `/start-conversation`

Spokenly is the microphone half of this setup. The skill speaks; Spokenly listens.
Without it the loop cannot run, because the skill has no other way to reopen the mic.

Verified against Spokenly **2.24.3+485** on macOS and the official
[Voice for Agents (MCP)](https://spokenly.app/docs/macos/voice-for-agents) docs.

---

## 1. Download the right build

Go to **<https://spokenly.app/download>** and get the macOS build.

> **Critical:** you need the **sideload build, version 2.18.0 or newer**.
> The Mac App Store build does **not** ship the MCP server, so `ask_user_dictation`
> will never appear and the skill will refuse to start.

Pricing, for context: the free tier covers unlimited **local** transcription with
Whisper models (offline, private) plus bring-your-own-key cloud engines. Pro is
$9.99/mo for managed cloud models. The voice loop works fine on the free tier.

Move `Spokenly.app` to `/Applications` and launch it.

## 2. Grant permissions

On first launch macOS will ask for:

- **Microphone** — required, dictation is dead without it
- **Accessibility** — required for system-wide dictation into any app
- **Input Monitoring** — required for the push-to-talk hotkey

If you skipped a prompt: **System Settings → Privacy & Security**, find the
category, and toggle Spokenly on. After granting Accessibility you must quit and
relaunch the app.

## 3. Turn on the MCP server

In Spokenly: **Settings → General → Voice for AI Agents (MCP)**.

- enable the MCP server
- optionally enable **"Speak AI questions aloud"** — but note this uses cloud TTS
  credits, and **this skill already speaks locally via `speak.sh`**, so leaving it
  off avoids paying twice for the same sentence

Verify the server is actually up:

```bash
lsof -nP -iTCP:51089 -sTCP:LISTEN
```

You should see a `Spokenly` process listening on `127.0.0.1:51089`. If nothing is
listening, Spokenly is either not running or the MCP toggle is off. **Spokenly must
stay running for the whole voice conversation** — the port dies with the app.

## 4. Register Spokenly with Claude Code

`install.sh` does this for you. To do it by hand:

```bash
# available in every project (recommended)
claude mcp add spokenly --scope user -- "$HOME/Library/Application Support/Spokenly/mcp-bridge.sh"

# or only in the current project, as the official docs show
claude mcp add spokenly -- ~/Library/Application\ Support/Spokenly/mcp-bridge.sh
```

**Restart Claude Code**, then run `/mcp`. You want `spokenly` listed as connected,
exposing `ask_user_dictation` (parameter: `questions`, a **list of strings**) and
`transcribe_file`.

### If you run more than one Claude profile

MCP servers are registered per config directory. With wrappers like
`claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'`, register once per profile:

```bash
CLAUDE_CONFIG_DIR=~/.claude-personal claude mcp add spokenly --scope user -- "$HOME/Library/Application Support/Spokenly/mcp-bridge.sh"
CLAUDE_CONFIG_DIR=~/.claude-work     claude mcp add spokenly --scope user -- "$HOME/Library/Application Support/Spokenly/mcp-bridge.sh"
```

Check what a given profile sees:

```bash
CLAUDE_CONFIG_DIR=~/.claude-personal claude mcp list | grep -i spokenly
```

The same applies to the skill itself — see the multi-profile note in
[README.md](README.md#running-more-than-one-claude-profile).

### Why a bridge script and not a plain HTTP MCP server

Claude Code times out HTTP MCP calls after 60 seconds. A dictation call stays open
for as long as you are thinking and talking. `mcp-bridge.sh` is a tiny stdio→HTTP
proxy that reads JSON-RPC lines on stdin and POSTs them to `localhost:51089` with a
600-second timeout, so long pauses do not kill the call. Use the stdio bridge, not
a direct HTTP transport.

## 5. Make Claude prefer voice for questions

Add this to `~/.claude/CLAUDE.md` so Claude asks by voice even outside the skill:

```
ALWAYS ask questions via mcp__spokenly__ask_user_dictation (load via ToolSearch if
needed), never as plain text. I use Spokenly for voice input.
```

*(This line is already in your `~/.claude/CLAUDE.md`.)*

## 6. Pair it with the skill

Install the skill and start a conversation:

```bash
bash ~/Desktop/start-conversation-skill/install.sh
# restart Claude Code
```

```
/start-conversation en
```

What should happen, in order:

1. the skill writes `~/.claude/.voice-lang` — this arms the loop
2. you **hear** a greeting through `speak.sh` (Edge TTS neural voice)
3. Spokenly opens the microphone and records your answer
4. you speak, press Enter, the transcript goes back to Claude
5. Claude works, speaks a 2–4 sentence summary, and reopens the mic — repeat
6. you say "that's all" → Claude deletes `~/.claude/.voice-lang`, says goodbye, stops

## 7. Split of responsibilities

| Direction | Component | Engine |
|---|---|---|
| Claude → your ears | `speak.sh` in the skill | Edge TTS neural voices via `uvx edge-tts`, macOS `say` as offline fallback |
| Your mouth → Claude | Spokenly `ask_user_dictation` | local Whisper, or a cloud engine if you configured one |

They are independent. Spokenly's own "speak aloud" option is not needed and is not
used by this skill.

---

## Troubleshooting

**`ask_user_dictation` does not exist / `/mcp` shows nothing**
App Store build instead of sideload, or the MCP toggle is off, or Claude Code was
not restarted after `claude mcp add`. Check all three in that order.

**The tool exists but recording never starts**
Spokenly is not running, or the microphone permission was denied. Confirm with the
`lsof` command from step 3.

**Long answers fail with a timeout**
A known limitation of the stdio bridge. Answer in shorter chunks. The skill is told
not to retry in a loop when this happens — it exits voice mode and tells you in text.

**Empty transcript**
The skill asks once more, and if the second attempt is empty too it treats it as
"conversation over" and exits cleanly. That is deliberate, so a broken mic cannot
trap you in an infinite loop.

**Claude keeps talking and will not stop**
The Stop hook is armed. Kill it from any terminal:

```bash
rm -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/.voice-lang
```

That single file is the on/off switch for the entire loop.

**No sound, but no error**
Test the speech half on its own:

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/skills/start-conversation/speak.sh -l en 'Testing one two three.'
```

No `uvx` → it falls back to macOS `say`, which sounds noticeably worse.
Install `uv` for neural voices: `curl -LsSf https://astral.sh/uv/install.sh | sh`

---

## Bonus: the Spokenly CLI

The sideload build also drops a CLI next to the bridge:

```bash
"$HOME/Library/Application Support/Spokenly/spokenly" transcribe meeting.mp3 --format srt
```

Formats: `text`, `srt`, `vtt`, `markdown`, `json`; `--speakers` adds speaker labels.
Spokenly.app must be running. Handy for turning a recorded meeting into notes
without leaving the terminal.

---

Sources: [Spokenly](https://spokenly.app), [Download](https://spokenly.app/download),
[Voice for Agents (MCP)](https://spokenly.app/docs/macos/voice-for-agents),
[Claude Code voice mode](https://spokenly.app/blog/voice-dictation-for-developers/claude-code),
[Spokenly CLI](https://spokenly.app/docs/macos/cli)
