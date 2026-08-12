# /start-conversation — hands-free voice conversations with Claude Code

A Claude Code skill that turns a normal session into a continuous spoken
conversation. Claude does the work, **says a short summary out loud**, and
immediately reopens the microphone for your next instruction — looping until you
say you are done. **38 languages**, chosen with an argument.

```
/start-conversation en
/start-conversation sr
/start-conversation bs
/start-conversation de female
/start-conversation bs slow
/start-conversation en +25%
```

Speech out is Microsoft Edge TTS neural voices (free, no API key). Speech in is
[Spokenly](https://spokenly.app). macOS only.

---

## Setup

Steps 1 and 2 set up Spokenly — once per machine. Step 3 installs the skill. Step 4 is
you talking.

### Step 1 · Install Spokenly (the microphone half)

Claude speaks on its own, but it cannot **hear** you without Spokenly. Set it up first.

> ### 📖 **[→ SPOKENLY-SETUP.md — full Spokenly guide](SPOKENLY-SETUP.md)**
>
> Download link, permissions, the MCP toggle, pairing with this skill, and troubleshooting.

Short version: get the **sideload build 2.18.0+** from
[spokenly.app/download](https://spokenly.app/download) — the **App Store build will not
work**, it ships no MCP server — grant microphone and accessibility permissions, then
enable _Settings → General → Voice for AI Agents (MCP)_.

### Step 2 · Register Spokenly as an MCP server

Installing the app is not enough — Claude Code has to be told how to reach it.

**Step 3 does this for you automatically**, so you can skip ahead. Do it by hand only if
you used `--no-mcp`, or if the automatic registration failed:

```bash
claude mcp add spokenly --scope user -- "$HOME/Library/Application Support/Spokenly/mcp-bridge.sh"
```

`--scope user` makes it available in **every** project. Drop the flag to register it for
the current project only.

Verify it — restart Claude Code, run `/mcp`, and look for `spokenly` connected with the
`ask_user_dictation` tool. Then check the app side:

```bash
lsof -nP -iTCP:51089 -sTCP:LISTEN     # Spokenly must be running with the MCP toggle on
```

No output means Spokenly is closed or the MCP server is off — go back to Step 1.
**Spokenly has to stay running for the whole conversation**; the port dies with the app.

> **Why a bridge script and not a plain HTTP MCP server?** Claude Code cuts HTTP MCP
> calls off after 60 seconds, but a dictation call stays open for as long as you are
> talking. `mcp-bridge.sh` is a small stdio→HTTP proxy with a 600-second timeout.

Optional but recommended — add this to `~/.claude/CLAUDE.md` so Claude asks you by voice
even outside this skill:

```
ALWAYS ask questions via mcp__spokenly__ask_user_dictation (load via ToolSearch if
needed), never as plain text. I use Spokenly for voice input.
```

### Step 3 · Install the skill — one line

```bash
curl -fsSL https://raw.githubusercontent.com/mmuminovic/start-conversation-skill/main/install.sh | bash
```

Nothing to clone. The script downloads the skill into
`$CLAUDE_CONFIG_DIR/skills/start-conversation/` (default `~/.claude/skills/…`), registers
Spokenly as a user-scoped MCP server (Step 2, done for you), and checks every dependency
(`jq`, `uvx`, `afplay`). It prints which config dir it used and never leaves voice mode
armed.

Installing from a local copy of this folder instead:

```bash
bash ~/Desktop/start-conversation-skill/install.sh
```

#### Running more than one Claude profile?

Claude Code loads user skills from `$CLAUDE_CONFIG_DIR/skills` (default `~/.claude/skills`).
If you launch Claude through wrappers that set that variable — for example

```bash
alias claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
```

— then **each profile needs its own install**, and so does the Spokenly registration from
Step 2. Installing into the wrong one is silent: `/start-conversation` simply never shows
up. The installer honours `CLAUDE_CONFIG_DIR`, prints which directory it used, and warns
about the profiles it skipped:

```bash
CLAUDE_CONFIG_DIR=~/.claude-personal bash install.sh
CLAUDE_CONFIG_DIR=~/.claude-work     bash install.sh
```

### Step 4 · Talk

**Restart Claude Code**, then:

```
/start-conversation en
```

---

### Installer options

```bash
--default-lang en    # language used when /start-conversation gets no argument
--config-dir <path>  # Claude profile to install into ($CLAUDE_CONFIG_DIR, else ~/.claude)
--no-mcp             # skip registering the Spokenly MCP server
--dir <path>         # install target (default: <config-dir>/skills/start-conversation)
--force              # overwrite an existing install without warning
```

Pass them to either install form — after `| bash` use `-s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/mmuminovic/start-conversation-skill/main/install.sh | bash -s -- --default-lang en
```

Uninstall: `bash ~/Desktop/start-conversation-skill/uninstall.sh`

---

## Languages

First argument is the language; after it you can optionally add the voice gender
(`male` by default) and the speech rate, in any order:

```
/start-conversation de female slow
/start-conversation en fast
/start-conversation bs -15%
```

| Code        | Language        |     | Code    | Language        |     | Code        | Language  |
| ----------- | --------------- | --- | ------- | --------------- | --- | ----------- | --------- |
| `en`        | English (US)    |     | `nl`    | Dutch           |     | `he`        | Hebrew    |
| `en-gb`     | English (UK)    |     | `pl`    | Polish          |     | `ro`        | Romanian  |
| `bs`        | Bosnian         |     | `ru`    | Russian         |     | `hu`        | Hungarian |
| `sr`        | Serbian         |     | `uk`    | Ukrainian       |     | `bg`        | Bulgarian |
| `hr`        | Croatian        |     | `tr`    | Turkish         |     | `sv`        | Swedish   |
| `sl`        | Slovenian       |     | `ar`    | Arabic          |     | `no` / `nb` | Norwegian |
| `mk`        | Macedonian      |     | `zh`    | Chinese         |     | `da`        | Danish    |
| `sq`        | Albanian        |     | `ja`    | Japanese        |     | `fi`        | Finnish   |
| `de`        | German          |     | `ko`    | Korean          |     | `cs`        | Czech     |
| `es`        | Spanish         |     | `hi`    | Hindi           |     | `sk`        | Slovak    |
| `fr`        | French          |     | `id`    | Indonesian      |     | `el`        | Greek     |
| `it`        | Italian         |     | `vi`    | Vietnamese      |     | `th`        | Thai      |
| `pt`        | Portuguese (PT) |     | `pt-br` | Portuguese (BR) |     |             |           |

Aliases work too: `rs`→`sr`, `cz`→`cs`, `jp`→`ja`, `cn`→`zh`, `gb`→`en-gb`, and the
native names (`deutsch`, `srpski`, `magyar`, …). Note `uk` is **Ukrainian** — for
British English use `en-gb`.

Every voice ID was verified against the live `edge-tts` catalog. See them all:

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/skills/start-conversation/speak.sh --list
```

Switching language mid-conversation works — just say "let's continue in German".

## Speech rate

The third kind of argument controls how fast Claude talks:

| Argument        | Meaning                                          |
| --------------- | ------------------------------------------------ |
| _(none)_        | neutral rate (`+10%` over the voice's baseline)  |
| `slow` / `sporo`| slower speech (`-20%`)                           |
| `fast` / `brzo` | faster speech (`+30%`)                           |
| `+25%`, `-15%`  | exact rate relative to the voice's baseline      |
| `20`            | bare number — treated as `+20%`                  |

The rate is stored in `$CLAUDE_CONFIG_DIR/.voice-rate` and applies to every
spoken summary until the conversation ends. You can also change it mid-conversation
by voice — just say "speak slower" / "pričaj sporije" — or use it directly:

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/skills/start-conversation/speak.sh -l en -r slow 'test'
```

It works with both engines: Edge TTS takes the percentage natively, and the
offline macOS `say` fallback maps it onto words per minute.

---

## How it works

```
you speak  ──▶  Spokenly (Whisper)  ──▶  Claude does the work
                                              │
        ┌─────────────────────────────────────┘
        ▼
  Stop hook blocks the turn
        │
        ▼
  2–4 sentence spoken summary  ──▶  speak.sh (Edge TTS)  ──▶  your ears
        │
        └──▶  ask_user_dictation reopens the mic  ──▶  back to the top
```

The engine is a **`Stop` hook** declared in the skill's frontmatter. When Claude
tries to end a turn, the hook blocks it and instructs Claude to summarize aloud and
reopen the microphone instead. That is what makes the conversation continuous rather
than one-shot.

The hook is armed by a single file, inside whichever Claude profile is running:

```
$CLAUDE_CONFIG_DIR/.voice-lang     # contains e.g. "de" — present = voice mode on
                                   # defaults to ~/.claude/.voice-lang
```

The skill writes it on start and deletes it on exit. If anything ever goes wrong,
**this one command kills the loop from any terminal**:

```bash
rm -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/.voice-lang
```

The hook exits immediately when that file is absent, so it can never interfere with
your normal, non-voice sessions.

### The spoken summary

The whole design rests on one rule: what gets spoken is **result and consequence**,
not a list of steps. Two to four sentences, no markdown, no file paths, no line
numbers, always ending in a concrete question so you have something to answer.
Details stay in the on-screen text — the voice is a summary, not a transcript.

---

## Files

```
start-conversation-skill/
├── README.md            this file
├── SPOKENLY-SETUP.md    download, permissions, MCP setup, troubleshooting
├── install.sh           one-line installer
├── uninstall.sh         removal
└── skill/
    ├── SKILL.md         the skill itself: frontmatter, Stop hook, loop rules
    └── speak.sh         multilingual TTS (Edge TTS → macOS say fallback)
```

## Requirements

|                           |             |                                                                    |
| ------------------------- | ----------- | ------------------------------------------------------------------ |
| macOS                     | required    | uses `afplay` / `say`                                              |
| Spokenly 2.18.0+ sideload | required    | the microphone half                                                |
| `jq`                      | required    | the Stop hook parses hook JSON with it — `brew install jq`         |
| `uv` / `uvx`              | recommended | neural voices — `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| internet                  | recommended | Edge TTS is a cloud service; offline drops to macOS `say`          |

Without `uvx` or without a connection everything still works, just with the older
built-in macOS voices.

---

## Publishing — makes the one-liner live

The `curl` command in Step 3 points at
`github.com/mmuminovic/start-conversation-skill`. **It only resolves once this
folder is pushed there.** Until then, use the local install form.

```bash
gh auth login                      # once per machine, if not already logged in

cd ~/Desktop/start-conversation-skill
git init && git add . && git commit -m "feat: multilingual voice conversation skill"
gh repo create start-conversation-skill --public --source=. --push
```

Verify the one-liner resolves:

```bash
curl -fsSL https://raw.githubusercontent.com/mmuminovic/start-conversation-skill/main/install.sh | head -3
```

Naming the repo something else is fine — `install.sh` reads `SC_REPO` and `SC_REF`:

```bash
SC_REPO=youruser/yourrepo SC_REF=main bash install.sh
```

Then update the two `curl` URLs in Step 3 above to match.

## Troubleshooting

| Symptom                          | Fix                                                                                          |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| `/start-conversation` not offered | installed into a profile you do not launch — rerun with `CLAUDE_CONFIG_DIR=…`, then restart   |
| Claude will not stop talking     | `rm -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/.voice-lang`                                     |
| No `ask_user_dictation` tool     | App Store build instead of sideload, MCP toggle off, or Claude Code not restarted             |
| Silence, no error                | `speak.sh -l en 'test'` — if that is silent, check `uvx` and volume                           |
| Robotic voice                    | `uvx` missing, so it fell back to macOS `say`                                                 |
| Wrong language spoken            | `cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/.voice-lang`                                       |
| Long answers time out            | known stdio bridge limit — answer in shorter chunks                                           |

Full details in [SPOKENLY-SETUP.md](SPOKENLY-SETUP.md#troubleshooting).
