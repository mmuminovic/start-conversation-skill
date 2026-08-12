#!/usr/bin/env bash
# speak.sh — speaks a text aloud in the selected language.
#
# Usage:
#   speak.sh "text"                     # uses the active conversation language
#   speak.sh -l de "Guten Tag"          # explicit language
#   speak.sh -l en -g female "Hello"    # explicit language + voice gender
#   speak.sh --list                     # print the supported language table
#
# Environment overrides:
#   SPEAK_LANG=de       same as -l
#   SPEAK_GENDER=female same as -g   (male | female)
#   SPEAK_VOICE=de-DE-KatjaNeural     hard override, skips the language map
#   SPEAK_RATE=+10%     speech rate passed to edge-tts
#
# Engine: Microsoft Edge TTS (neural voices) via `uvx edge-tts`.
# Offline / no uvx: falls back to the macOS `say` command with the closest
# installed system voice for that language.
#
# User preferences:
#   - Serbian (sr), Croatian (hr), Bosnian (bs): use bs-BA-GoranNeural (male voice)
#   - All text respects native characters (č, š, ž, đ, ć, etc.) without simplification

set -euo pipefail

# State lives next to the Claude profile that is running, so multi-profile setups
# (claude-personal / claude-work) do not read each other's language file.
STATE_DIR="${CLAUDE_VOICE_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
LANG_FILE="$STATE_DIR/.voice-lang"

# ---------------------------------------------------------------- language map

# normalize <input> -> canonical language key
normalize_lang() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    en|eng|en-us|en_us|us|american)              echo en ;;
    en-gb|en_gb|gb|british|uk-en)                echo en-gb ;;
    bs|bos|bh|bih|bosanski|bosnian)              echo bs ;;
    sr|rs|srb|srp|srpski|serbian)                echo sr ;;
    hr|cro|hrv|hrvatski|croatian)                echo hr ;;
    sl|si|slo|slovenian|slovenscina)             echo sl ;;
    mk|mkd|macedonian|makedonski)                echo mk ;;
    sq|al|alb|albanian|shqip)                    echo sq ;;
    de|ger|deu|german|deutsch)                   echo de ;;
    es|esp|spa|spanish|espanol)                  echo es ;;
    fr|fra|fre|french|francais)                  echo fr ;;
    it|ita|italian|italiano)                     echo it ;;
    pt|por|portuguese|portugues)                 echo pt ;;
    pt-br|pt_br|br|brazilian)                    echo pt-br ;;
    nl|nld|dut|dutch|nederlands)                 echo nl ;;
    pl|pol|polish|polski)                        echo pl ;;
    ru|rus|russian)                              echo ru ;;
    uk|ua|ukr|ukrainian)                         echo uk ;;
    tr|tur|turkish|turkce)                       echo tr ;;
    ar|ara|arabic)                               echo ar ;;
    zh|cn|chi|zho|chinese|mandarin)              echo zh ;;
    ja|jp|jpn|japanese)                          echo ja ;;
    ko|kr|kor|korean)                            echo ko ;;
    hi|hin|hindi|in)                             echo hi ;;
    sv|se|swe|swedish|svenska)                   echo sv ;;
    no|nb|nor|norwegian|norsk)                   echo no ;;
    da|dk|dan|danish|dansk)                      echo da ;;
    fi|fin|finnish|suomi)                        echo fi ;;
    cs|cz|ces|cze|czech|cestina)                 echo cs ;;
    sk|svk|slovak|slovencina)                    echo sk ;;
    el|gr|ell|gre|greek)                         echo el ;;
    he|il|heb|hebrew)                            echo he ;;
    ro|rou|rum|romanian|romana)                  echo ro ;;
    hu|hun|hungarian|magyar)                     echo hu ;;
    bg|bul|bulgarian)                            echo bg ;;
    id|ind|indonesian|bahasa)                    echo id ;;
    vi|vn|vie|vietnamese)                        echo vi ;;
    th|tha|thai)                                 echo th ;;
    *)                                           echo "" ;;
  esac
}

# edge_voice <lang> <gender> -> neural voice id
edge_voice() {
  local l="$1" g="$2"
  case "$l" in
    en)    [ "$g" = female ] && echo en-US-JennyNeural      || echo en-US-GuyNeural ;;
    en-gb) [ "$g" = female ] && echo en-GB-SoniaNeural      || echo en-GB-RyanNeural ;;
    bs|sr|hr) echo bs-BA-GoranNeural ;; # user preference: Balkan languages use Goran (male)
    sl)    [ "$g" = female ] && echo sl-SI-PetraNeural      || echo sl-SI-RokNeural ;;
    mk)    [ "$g" = female ] && echo mk-MK-MarijaNeural     || echo mk-MK-AleksandarNeural ;;
    sq)    [ "$g" = female ] && echo sq-AL-AnilaNeural      || echo sq-AL-IlirNeural ;;
    de)    [ "$g" = female ] && echo de-DE-KatjaNeural      || echo de-DE-ConradNeural ;;
    es)    [ "$g" = female ] && echo es-ES-ElviraNeural     || echo es-ES-AlvaroNeural ;;
    fr)    [ "$g" = female ] && echo fr-FR-DeniseNeural     || echo fr-FR-HenriNeural ;;
    it)    [ "$g" = female ] && echo it-IT-ElsaNeural       || echo it-IT-DiegoNeural ;;
    pt)    [ "$g" = female ] && echo pt-PT-RaquelNeural     || echo pt-PT-DuarteNeural ;;
    pt-br) [ "$g" = female ] && echo pt-BR-FranciscaNeural  || echo pt-BR-AntonioNeural ;;
    nl)    [ "$g" = female ] && echo nl-NL-ColetteNeural    || echo nl-NL-MaartenNeural ;;
    pl)    [ "$g" = female ] && echo pl-PL-ZofiaNeural      || echo pl-PL-MarekNeural ;;
    ru)    [ "$g" = female ] && echo ru-RU-SvetlanaNeural   || echo ru-RU-DmitryNeural ;;
    uk)    [ "$g" = female ] && echo uk-UA-PolinaNeural     || echo uk-UA-OstapNeural ;;
    tr)    [ "$g" = female ] && echo tr-TR-EmelNeural       || echo tr-TR-AhmetNeural ;;
    ar)    [ "$g" = female ] && echo ar-SA-ZariyahNeural    || echo ar-SA-HamedNeural ;;
    zh)    [ "$g" = female ] && echo zh-CN-XiaoxiaoNeural   || echo zh-CN-YunxiNeural ;;
    ja)    [ "$g" = female ] && echo ja-JP-NanamiNeural     || echo ja-JP-KeitaNeural ;;
    ko)    [ "$g" = female ] && echo ko-KR-SunHiNeural      || echo ko-KR-InJoonNeural ;;
    hi)    [ "$g" = female ] && echo hi-IN-SwaraNeural      || echo hi-IN-MadhurNeural ;;
    sv)    [ "$g" = female ] && echo sv-SE-SofieNeural      || echo sv-SE-MattiasNeural ;;
    no)    [ "$g" = female ] && echo nb-NO-PernilleNeural   || echo nb-NO-FinnNeural ;;
    da)    [ "$g" = female ] && echo da-DK-ChristelNeural   || echo da-DK-JeppeNeural ;;
    fi)    [ "$g" = female ] && echo fi-FI-NooraNeural      || echo fi-FI-HarriNeural ;;
    cs)    [ "$g" = female ] && echo cs-CZ-VlastaNeural     || echo cs-CZ-AntoninNeural ;;
    sk)    [ "$g" = female ] && echo sk-SK-ViktoriaNeural   || echo sk-SK-LukasNeural ;;
    el)    [ "$g" = female ] && echo el-GR-AthinaNeural     || echo el-GR-NestorasNeural ;;
    he)    [ "$g" = female ] && echo he-IL-HilaNeural       || echo he-IL-AvriNeural ;;
    ro)    [ "$g" = female ] && echo ro-RO-AlinaNeural      || echo ro-RO-EmilNeural ;;
    hu)    [ "$g" = female ] && echo hu-HU-NoemiNeural      || echo hu-HU-TamasNeural ;;
    bg)    [ "$g" = female ] && echo bg-BG-KalinaNeural     || echo bg-BG-BorislavNeural ;;
    id)    [ "$g" = female ] && echo id-ID-GadisNeural      || echo id-ID-ArdiNeural ;;
    vi)    [ "$g" = female ] && echo vi-VN-HoaiMyNeural     || echo vi-VN-NamMinhNeural ;;
    th)    [ "$g" = female ] && echo th-TH-PremwadeeNeural  || echo th-TH-NiwatNeural ;;
    *)     echo bs-BA-GoranNeural ;;
  esac
}

# say_candidates <lang> -> space separated macOS voice names, best first
say_candidates() {
  case "$1" in
    en)          echo "Samantha Alex Daniel" ;;
    en-gb)       echo "Daniel Serena Samantha" ;;
    bs|sr|hr|sl) echo "Lana Milena Zuzana" ;;
    mk|bg)       echo "Daria Milena" ;;
    sq)          echo "Alice Samantha" ;;
    de)          echo "Anna Markus Petra" ;;
    es)          echo "Monica Jorge Paulina" ;;
    fr)          echo "Thomas Amelie Aurelie" ;;
    it)          echo "Alice Luca" ;;
    pt|pt-br)    echo "Joana Luciana" ;;
    nl)          echo "Xander Ellen" ;;
    pl)          echo "Zosia Krzysztof" ;;
    ru)          echo "Milena Yuri" ;;
    uk)          echo "Lesya Milena" ;;
    tr)          echo "Yelda Cem" ;;
    ar)          echo "Maged Majed" ;;
    zh)          echo "Tingting Sinji" ;;
    ja)          echo "Kyoko Otoya" ;;
    ko)          echo "Yuna" ;;
    hi)          echo "Lekha" ;;
    sv)          echo "Alva" ;;
    no)          echo "Nora" ;;
    da)          echo "Sara" ;;
    fi)          echo "Satu" ;;
    cs)          echo "Zuzana" ;;
    sk)          echo "Laura Zuzana" ;;
    el)          echo "Melina" ;;
    he)          echo "Carmit" ;;
    ro)          echo "Ioana" ;;
    hu)          echo "Mariska" ;;
    id)          echo "Damayanti" ;;
    vi)          echo "Linh" ;;
    th)          echo "Kanya" ;;
    *)           echo "" ;;
  esac
}

print_table() {
  cat <<'TABLE'
Supported languages for /start-conversation and speak.sh -l

 code    language            male voice                female voice
 ------  ------------------  ------------------------  ------------------------
 en      English (US)        en-US-GuyNeural           en-US-JennyNeural
 en-gb   English (UK)        en-GB-RyanNeural          en-GB-SoniaNeural
 bs      Bosnian             bs-BA-GoranNeural         bs-BA-VesnaNeural
 sr/rs   Serbian             sr-RS-NicholasNeural      sr-RS-SophieNeural
 hr      Croatian            hr-HR-SreckoNeural        hr-HR-GabrijelaNeural
 sl      Slovenian           sl-SI-RokNeural           sl-SI-PetraNeural
 mk      Macedonian          mk-MK-AleksandarNeural    mk-MK-MarijaNeural
 sq      Albanian            sq-AL-IlirNeural          sq-AL-AnilaNeural
 de      German              de-DE-ConradNeural        de-DE-KatjaNeural
 es      Spanish             es-ES-AlvaroNeural        es-ES-ElviraNeural
 fr      French              fr-FR-HenriNeural         fr-FR-DeniseNeural
 it      Italian             it-IT-DiegoNeural         it-IT-ElsaNeural
 pt      Portuguese (PT)     pt-PT-DuarteNeural        pt-PT-RaquelNeural
 pt-br   Portuguese (BR)     pt-BR-AntonioNeural       pt-BR-FranciscaNeural
 nl      Dutch               nl-NL-MaartenNeural       nl-NL-ColetteNeural
 pl      Polish              pl-PL-MarekNeural         pl-PL-ZofiaNeural
 ru      Russian             ru-RU-DmitryNeural        ru-RU-SvetlanaNeural
 uk      Ukrainian           uk-UA-OstapNeural         uk-UA-PolinaNeural
 tr      Turkish             tr-TR-AhmetNeural         tr-TR-EmelNeural
 ar      Arabic              ar-SA-HamedNeural         ar-SA-ZariyahNeural
 zh      Chinese (Mandarin)  zh-CN-YunxiNeural         zh-CN-XiaoxiaoNeural
 ja      Japanese            ja-JP-KeitaNeural         ja-JP-NanamiNeural
 ko      Korean              ko-KR-InJoonNeural        ko-KR-SunHiNeural
 hi      Hindi               hi-IN-MadhurNeural        hi-IN-SwaraNeural
 sv      Swedish             sv-SE-MattiasNeural       sv-SE-SofieNeural
 no/nb   Norwegian           nb-NO-FinnNeural          nb-NO-PernilleNeural
 da      Danish              da-DK-JeppeNeural         da-DK-ChristelNeural
 fi      Finnish             fi-FI-HarriNeural         fi-FI-NooraNeural
 cs      Czech               cs-CZ-AntoninNeural       cs-CZ-VlastaNeural
 sk      Slovak              sk-SK-LukasNeural         sk-SK-ViktoriaNeural
 el      Greek               el-GR-NestorasNeural      el-GR-AthinaNeural
 he      Hebrew              he-IL-AvriNeural          he-IL-HilaNeural
 ro      Romanian            ro-RO-EmilNeural          ro-RO-AlinaNeural
 hu      Hungarian           hu-HU-TamasNeural         hu-HU-NoemiNeural
 bg      Bulgarian           bg-BG-BorislavNeural      bg-BG-KalinaNeural
 id      Indonesian          id-ID-ArdiNeural          id-ID-GadisNeural
 vi      Vietnamese          vi-VN-NamMinhNeural       vi-VN-HoaiMyNeural
 th      Thai                th-TH-NiwatNeural         th-TH-PremwadeeNeural

Note: "uk" is Ukrainian (ISO 639-1). For British English use "en-gb".
TABLE
}

usage() {
  cat <<'USAGE'
speak.sh — speak text aloud in a chosen language

  speak.sh "text"                  speak in the active conversation language
  speak.sh -l de "Guten Tag"       speak in a specific language
  speak.sh -l en -g female "Hi"    choose the voice gender
  speak.sh --list                  show all supported languages
  speak.sh --check                 verify the TTS engine works

Env: SPEAK_LANG, SPEAK_GENDER (male|female), SPEAK_VOICE, SPEAK_RATE
USAGE
}

# ------------------------------------------------------------------ arg parsing

lang_arg=""
gender="${SPEAK_GENDER:-male}"
text=""

while [ $# -gt 0 ]; do
  case "$1" in
    -l|--lang)   lang_arg="${2:-}"; shift 2 ;;
    -g|--gender) gender="${2:-male}"; shift 2 ;;
    --list)      print_table; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    --check)     text="TTS check. One two three."; lang_arg="${lang_arg:-en}"; shift ;;
    --)          shift; text="${1:-}"; shift || true ;;
    *)           text="$1"; shift ;;
  esac
done

if [ -z "$text" ]; then
  usage >&2
  exit 1
fi

# language: -l flag > SPEAK_LANG > state file > bs
raw_lang="${lang_arg:-${SPEAK_LANG:-}}"
if [ -z "$raw_lang" ] && [ -f "$LANG_FILE" ]; then
  raw_lang="$(tr -d '[:space:]' < "$LANG_FILE" || true)"
fi
[ -z "$raw_lang" ] && raw_lang="bs"

lang="$(normalize_lang "$raw_lang")"
if [ -z "$lang" ]; then
  printf 'speak.sh: unknown language "%s" — falling back to bs. Run --list to see codes.\n' "$raw_lang" >&2
  lang="bs"
fi

case "$gender" in
  f|female|w|woman|zenski) gender="female" ;;
  *)                       gender="male" ;;
esac

VOICE="${SPEAK_VOICE:-$(edge_voice "$lang" "$gender")}"
RATE="${SPEAK_RATE:-+10%}"

# ---------------------------------------------------------------------- speaking

TMP="$(mktemp -t claude-speak).mp3"
trap 'rm -f "$TMP"' EXIT

if command -v uvx >/dev/null 2>&1 &&
   uvx edge-tts --voice "$VOICE" --rate="$RATE" --text "$text" --write-media "$TMP" 2>/dev/null &&
   [ -s "$TMP" ]; then
  afplay "$TMP"
  exit 0
fi

# Fallback: no network / no uvx -> local macOS voice for that language
if command -v say >/dev/null 2>&1; then
  for cand in $(say_candidates "$lang"); do
    if say -v "$cand" "" >/dev/null 2>&1; then
      say -v "$cand" "$text"
      exit 0
    fi
  done
  say "$text"
  exit 0
fi

printf 'speak.sh: no TTS engine available (needs uvx+edge-tts or macOS say).\n' >&2
exit 1
