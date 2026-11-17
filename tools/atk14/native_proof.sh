#!/bin/sh
# Native, cel look, production timing, 1920x1080, 100%; no renderer retries.
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$TASK_ROOT"
export LABYRINTH_TASK_ID=atk-14
export ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures
SAVE_ROOT=/private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-2" intent peal_expanded --enemy storm_cantor --intent peal
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-2" portrait peal_disc --enemy storm_cantor --intent peal
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-9" prebattle cantor_prebattle --enemy storm_cantor
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-9" intent arc_compact_and_rows --enemy lightning_wisp --intent blinding_arc
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-9" pass arc_pass
export ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-2" playback peal_playback
sh tools/atk13/native_capture.sh "$SAVE_ROOT/1305-2" playback peal_playback_reduced --reduced-motion true

# Controlled production-resolver cases: authored boss art/rules, isolated staging.
export ATK13_CAPTURE_SCRIPT=res://tools/atk14/capture.gd
export ATK13_PROOF_CONTRACT=tools/atk13/capture_contract.json
sh tools/atk13/native_capture.sh controlled caption_only caption_only --case caption_only
export ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json
sh tools/atk13/native_capture.sh controlled zekarion zekarion_self_strike --case zekarion
sh tools/atk13/native_capture.sh controlled zekarion zekarion_self_strike_reduced --case zekarion --reduced-motion true

# Owner feedback 2: matching native before/after peak-bolt strips.
sh tools/atk14/native_feedback2.sh both
