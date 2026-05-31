#!/usr/bin/env bash
# Build SFX assets for Lexaway.
#
# Converts Kenney .ogg sources to .wav (PCM s16le, 44.1kHz) and copies the
# Ninja Adventure / freesound .wav sources straight into assets/audio/ under
# stable, purpose-based names. Idempotent — safe to re-run.
#
# Usage:  bash tools/build_sfx.sh
set -euo pipefail

ASSETS="$(cd "$(dirname "$0")/../assets" && pwd)"
OUT="$ASSETS/audio"
KI="$ASSETS/kenney_interface-sounds/Audio"
KJ="$ASSETS/kenney_music-jingles/Audio/Pizzicato jingles"
NA="$ASSETS/Ninja Adventure - Asset Pack/Audio/Sounds"

mkdir -p "$OUT"

# Skip (with a warning) when a source is missing so a pruned raw pack doesn't
# abort the whole build — the already-built asset in assets/audio/ stays put.
SKIPPED=0
skip() { echo "  SKIP $2 (missing source: $1)" >&2; SKIPPED=$((SKIPPED + 1)); }

# ogg -> wav (decode to canonical PCM)
ogg() { [ -f "$KI/$1.ogg" ] || { skip "$KI/$1.ogg" "$2"; return; }; ffmpeg -v error -y -i "$KI/$1.ogg" -ar 44100 -ac 1 -c:a pcm_s16le "$OUT/$2"; echo "  ogg  $2"; }
jing() { [ -f "$KJ/$1.ogg" ] || { skip "$KJ/$1.ogg" "$2"; return; }; ffmpeg -v error -y -i "$KJ/$1.ogg" -ar 44100 -ac 1 -c:a pcm_s16le "$OUT/$2"; echo "  jing $2"; }
# wav -> wav (normalize container/format so all shipped SFX match)
wav() { [ -f "$1" ] || { skip "$1" "$2"; return; }; ffmpeg -v error -y -i "$1" -ar 44100 -ac 1 -c:a pcm_s16le "$OUT/$2"; echo "  wav  $2"; }
# wav -> wav, ambient bed: keep stereo for width (no -ac 1 downmix)
amb() { [ -f "$1" ] || { skip "$1" "$2"; return; }; ffmpeg -v error -y -i "$1" -ar 44100 -c:a pcm_s16le "$OUT/$2"; echo "  amb  $2"; }

echo "== 8 swaps =="
wav  "$NA/Menu/Accept5.wav"        correct.wav
ogg  error_005                      wrong.wav
wav  "$NA/Bonus/Coin.wav"          coin.wav
wav  "$NA/Bonus/Gold1.wav"         gem.wav
wav  "$NA/Bonus/PowerUp1.wav"      streak.wav
wav  "$NA/Bonus/PowerUp2.wav"      milestone.wav
wav  "$ASSETS/244736__reitanna__egg-crack5.wav" egg_crack.wav
jing jingles_PIZZI02                hatch_chime.wav

echo "== UI / egg / pack =="
ogg  bong_001          ui_tap.wav
ogg  confirmation_001  ui_confirm.wav
ogg  click_001         ui_click_1.wav
ogg  click_002         ui_click_2.wav
ogg  click_003         ui_click_3.wav
ogg  click_004         ui_click_4.wav
ogg  click_005         ui_click_5.wav
ogg  toggle_001        ui_toggle.wav
ogg  switch_002        ui_switch.wav
ogg  error_001         ui_error.wav
ogg  maximize_006      sheet_open.wav
ogg  minimize_006      sheet_close.wav
ogg  glitch_004        egg_tap.wav
ogg  drop_001          egg_wobble.wav

echo "== claw =="
ogg  question_002      claw_prompt.wav
ogg  back_003          claw_decline.wav
ogg  maximize_001      claw_zoom_in.wav
ogg  minimize_001      claw_zoom_out.wav
ogg  select_006        claw_drop_btn.wav
ogg  drop_003          claw_prize_drop.wav
ogg  glitch_001        claw_shell_crack.wav
ogg  glass_001         claw_clink_1.wav
ogg  glass_002         claw_clink_2.wav
ogg  glass_005         claw_clink_3.wav
ogg  glass_006         claw_clink_4.wav

echo "== jingles / voice =="
jing jingles_PIZZI10   jingle_win.wav
jing jingles_PIZZI07   jingle_lose.wav
jing jingles_PIZZI04   jingle_unlock.wav
for i in 1 2 3 4 5 6 7 8 9 10; do wav "$NA/Voice/Voice$i.wav" "voice_$i.wav"; done

echo "== game-world =="
wav  "$NA/Elemental/Grass.wav"     creature_flee_1.wav
wav  "$NA/Elemental/Grass2.wav"    creature_flee_2.wav
wav  "$NA/Jump & Bounce/Bounce.wav" fidget_hop.wav

echo "== ambient beds =="
amb  "$NA/Ambient/WaveFar.wav"     ambient_tropics.wav

if [ "$SKIPPED" -gt 0 ]; then
  echo "Done -> $OUT  ($SKIPPED source(s) missing — kept existing assets)"
else
  echo "Done -> $OUT"
fi
