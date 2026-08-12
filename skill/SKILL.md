---
name: start-conversation
description: Runs a continuous hands-free voice conversation through Spokenly - Claude speaks a summary of every piece of work out loud and immediately reopens the microphone for the next question, looping until the user says they are done. Works in 38 languages, picked with an argument like /start-conversation en, sr, bs, de, fr, es; optional extra arguments set the voice gender and the speaking rate (slow, fast, +25%). Use when the user types /start-conversation or asks to talk by voice instead of typing.
hooks:
  Stop:
    - hooks:
        - type: command
          timeout: 30
          command: |
            CD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
            [ -f "$CD/.voice-lang" ] || exit 0
            jq -e '.stop_hook_active == true' >/dev/null 2>&1 && exit 0
            VL="$(tr -d '[:space:]' < "$CD/.voice-lang" 2>/dev/null)"
            [ -n "$VL" ] || VL=bs
            H=""
            case "$VL" in
              bs) H=" bs = Bosnian: LATIN script ONLY (never Cyrillic), ijekavica — no Serbian, Croatian or Russian words." ;;
              hr) H=" hr = Croatian: Latin script, ijekavica, Croatian vocabulary." ;;
              sr) H=" sr = Serbian: ekavica; Latin script unless the user explicitly asked for Cyrillic." ;;
            esac
            jq -n --arg l "$VL" --arg h "$H" --arg d "$CD" '{decision:"block", reason:("VOICE MODE IS ACTIVE (language: " + $l + ")." + $h + " You must not end the turn silently. 1) Write a spoken summary of 2 to 4 sentences IN THAT LANGUAGE. 2) Speak it: " + $d + "/skills/start-conversation/speak.sh -l " + $l + " \"<summary>\" 3) Call mcp__spokenly__ask_user_dictation with the same text as the question. If the user said the conversation is over, run: rm -f " + $d + "/.voice-lang — then say goodbye and you may stop.")}'
---

# Voice conversation

From this point the conversation is spoken. You talk, the user answers by voice, and that repeats without interruption.

## Argument: the language

The skill is invoked as `/start-conversation [language] [gender] [rate]`, for example:

- `/start-conversation` → falls back to the default in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-lang-default`, or `bs` if that file does not exist
- `/start-conversation en` → English
- `/start-conversation sr` / `rs` → Serbian
- `/start-conversation bs` → Bosnian
- `/start-conversation de` → German
- `/start-conversation fr female` → French, female voice
- `/start-conversation bs slow` → Bosnian, slower speech
- `/start-conversation en +25%` → English, 25 % faster than the neutral rate

Rules for reading the argument:

1. The **first** token is the conversation language. Normalize it with the table at the bottom of this file. If several language codes are given (`en de fr`), the **first** one is the language you speak; treat the rest as languages you also accept as input from the user.
2. A token that is `male`, `female`, `m`, `f`, `zenski`, or `muski` sets the voice gender. Default is `male`.
3. A token that is `slow`, `fast`, `sporo`, `brzo`, or a percentage like `+25%` / `-15%` sets the **speech rate**. Default is `+10%` (the neutral rate of the skill). `slow` maps to `-20%`, `fast` to `+30%`; a bare number like `20` means `+20%`.
4. If the code is not in the table, tell the user in text, list a few close codes, and ask which one they want — do not guess.

**Everything you say and write from now on is in the chosen language**, not just the spoken part.

## Language fidelity — no mixing, no wrong script

Choosing a language means that exact standard language, in its standard script, with correct orthography. Bosnian, Serbian and Croatian are close but **not interchangeable** — a single wrong word or the wrong script reads as a bug to the user.

- `bs` Bosnian → **Latin script only, never Cyrillic**, ijekavica ("dijete", "riječ", "htio", "vrijeme"). Never use Serbian ekavica forms ("dete", "reč"), never Serbian Cyrillic, never Russian or Macedonian words.
- `hr` Croatian → Latin script, ijekavica, Croatian vocabulary ("tvrtka", "glazba", "tisuća").
- `sr` Serbian → ekavica ("dete", "reč"); write in Latin script (latinica) unless the user explicitly asks for Cyrillic.
- Every other language → its own standard script (Russian in Cyrillic, Greek in Greek script, …). Never borrow a neighboring language's script or vocabulary.

Before you speak or print anything, re-read the sentence and check: is **every** word in the chosen language and its script? If even one word slipped in from a related language, rewrite it. This applies to the on-screen text as much as to the spoken summary.

## Setup (do this once, immediately)

1. Write the normalized language code to the state file — this is what arms the voice loop:
   `CD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; mkdir -p "$CD" && printf '%s' "<code>" > "$CD/.voice-lang"`
   Every path below uses the same `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` form — it resolves to whichever Claude profile is running, so never hardcode `~/.claude`.
   Use the canonical code from the table (`sr`, not `rs`).
2. If a gender other than the default was requested, also run:
   `printf '%s' "<gender>" > ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-gender`
   and pass `-g <gender>` to every `speak.sh` call afterwards.
3. If a speech rate was requested, also run:
   `printf '%s' "<rate>" > ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-rate`
   (e.g. `slow`, `fast`, `+25%`). `speak.sh` reads this file automatically on every call, so you do not need to pass anything extra.
4. Check that the `mcp__spokenly__ask_user_dictation` tool exists. If it does not, say so in text and **stop here** — the loop cannot run without it. Point the user at `/mcp` and at `SPOKENLY-SETUP.md`; they need the Spokenly sideload build 2.18.0 or newer with the MCP bridge enabled.
5. If the tool exists, **say a short greeting out loud** in the chosen language via Bash:
   `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/start-conversation/speak.sh -l <code> 'greeting'`
   then immediately call the dictation tool with the same text as the question.

## The loop — rule without exceptions

**Never end a turn normally.** Every turn of yours ends with a call to `mcp__spokenly__ask_user_dictation`. The order is always the same:

1. do what was asked (read, edit, run, whatever it takes)
2. compose a **spoken summary**
3. **say it out loud**: run `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/start-conversation/speak.sh -l <code> '<spoken summary>'` through Bash — the command blocks until speech finishes, that is fine. Avoid apostrophes in the text or escape them.
4. call the tool with that same summary as the question (the user also sees it as text)
5. the user answers by voice → back to step 1

The tool parameter is `questions` and it is a **list of strings**, not a single string. For the normal flow send a list with one element. Use several elements only when you genuinely need separate answers to separate questions.

## The spoken summary — the most important part

This text is read out loud. Write it for the ear, not the eye.

- **2 to 4 sentences**, in the conversation language
- **no markdown, no code blocks, no file paths, no line numbers, no lists**
- **result and consequence, not a list of steps.** Like this: "I fixed the authentication bug, a null check was missing before the object access. Tests pass. Should I commit?" Not like this: "I read auth_handler.py, changed line 47, ran pytest."
- **end with a concrete question or proposal**, so the user has something to answer. Without that the loop collapses into a monologue.
- if the job was large, say **only the most important part** — details stay in the on-screen text; the voice is a summary, not a transcript
- numbers, versions and file names belong in the on-screen text, not in speech; say "three files" rather than "src/auth/handler.ts, src/auth/session.ts and src/auth/index.ts"

Write the text part of your answer normally and completely, as always — the user sees it on screen. The spoken summary is an addition, not a replacement.

## Switching language mid-conversation

If the user asks to switch language ("let's continue in German", "pređi na engleski"), do not restart the skill. Just:

1. `printf '%s' "<new code>" > ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-lang`
2. use `-l <new code>` in every following `speak.sh` call
3. speak and write in the new language from that point on

## Changing the speech rate mid-conversation

If the user asks you to speak slower or faster ("pričaj sporije", "speak faster", "malo brže"), do not restart the skill. Just:

1. `printf '%s' "<rate>" > ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-rate` — use `slow`, `fast`, or a percentage like `+25%` / `-15%`
2. every following `speak.sh` call picks it up automatically

To go back to the normal speed, run `rm -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-rate`.

## When you need approval

If a permission prompt for `Bash` or `Edit` stops you mid-loop, the user sees it on screen but does not hear it. So: if you expect something to require approval, **announce it in the spoken summary before you attempt it** — "I am about to run the database migration, it will ask you for approval on screen."

## Exit

When the user says anything meaning "we are done", "I am out", "enough", "thanks that is all", "bye":

1. run `rm -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-lang ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-gender ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-rate`
2. say a short goodbye out loud via `speak.sh` and say goodbye in text
3. end the turn — now you may

If Spokenly returns an **empty transcript**, ask once more, briefly: "I did not hear you, say that again?" If it is empty a second time, treat it as the user ending the conversation and exit by the procedure above.

## If something gets stuck

If the tool returns an error or a timeout, do not enter a retry loop. Tell the user in text what broke, run `rm -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.voice-lang`, and end the turn. Long recordings sometimes hit the MCP timeout — that is a known stdio bridge issue and is solved outside this skill.

## Language codes

Canonical code on the left; aliases in parentheses are also accepted.

| Code | Language | | Code | Language |
|---|---|---|---|---|
| `en` (us) | English (US) | | `sv` (se) | Swedish |
| `en-gb` (gb) | English (UK) | | `no` (nb) | Norwegian |
| `bs` (bih) | Bosnian | | `da` (dk) | Danish |
| `sr` (rs) | Serbian | | `fi` | Finnish |
| `hr` | Croatian | | `cs` (cz) | Czech |
| `sl` (si) | Slovenian | | `sk` | Slovak |
| `mk` | Macedonian | | `el` (gr) | Greek |
| `sq` (al) | Albanian | | `he` (il) | Hebrew |
| `de` | German | | `ro` | Romanian |
| `es` | Spanish | | `hu` | Hungarian |
| `fr` | French | | `bg` | Bulgarian |
| `it` | Italian | | `ru` | Russian |
| `pt` | Portuguese (PT) | | `uk` (ua) | Ukrainian |
| `pt-br` (br) | Portuguese (BR) | | `tr` | Turkish |
| `nl` | Dutch | | `ar` | Arabic |
| `pl` | Polish | | `zh` (cn) | Chinese (Mandarin) |
| `ja` (jp) | Japanese | | `ko` (kr) | Korean |
| `hi` | Hindi | | `id` | Indonesian |
| `vi` | Vietnamese | | `th` | Thai |

`uk` is Ukrainian (ISO 639-1). For British English use `en-gb`.

Run `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/start-conversation/speak.sh --list` to see the exact neural voice used per language.
