#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TASK_ID="${LABYRINTH_TASK_ID:-refresh-all-steam-store-materials-from-current-visuals}"
OUTPUT_DIR="${REPO_ROOT}/steam/assets/screenshots"
SCRATCH_DIR="${TMPDIR:-/tmp}/escape-the-umbra-steam-screenshots-${TASK_ID}"

mkdir -p "${OUTPUT_DIR}" "${SCRATCH_DIR}"

CLIPS=(prebattle equipment umbra aoe route merchant trap_combo relic)
FILENAMES=(
  01-combat-threshold.png
  02-character-loadout.png
  03-lantern-shot.png
  04-wildfire-halo.png
  05-route-map.png
  06-arcanist-merchant.png
  07-cleaver-hook.png
  08-relic-choice.png
)
SELECT_SECONDS=(4.0 4.4 3.6 3.6 2.6 2.0 2.5 0.5)

for index in "${!CLIPS[@]}"; do
  clip="${CLIPS[$index]}"
  raw_path="${SCRATCH_DIR}/${clip}.avi"
  trimmed_path="${SCRATCH_DIR}/${clip}.mp4"
  output_path="${OUTPUT_DIR}/${FILENAMES[$index]}"

  case "${clip}" in
    route) trim_frames=27 ;;
    prebattle) trim_frames=56 ;;
    *) trim_frames=30 ;;
  esac

  python3 "${REPO_ROOT}/tools/godot_task_runner.py" \
    --task-id "${TASK_ID}" \
    --timeout 240 \
    --stream \
    -- \
    godot \
    --path "${REPO_ROOT}" \
    --display-driver macos \
    --audio-driver Dummy \
    --rendering-driver metal \
    --disable-vsync \
    --fixed-fps 30 \
    --write-movie "${raw_path}" \
    "${REPO_ROOT}/tools/steam_trailer_capture.tscn" \
    -- \
    "--clip=${clip}" \
    --safe-frame

  ffmpeg \
    -y \
    -loglevel error \
    -i "${raw_path}" \
    -an \
    -vf "trim=start_frame=${trim_frames},setpts=PTS-STARTPTS" \
    -c:v libx264 \
    -preset medium \
    -crf 15 \
    -pix_fmt yuv420p \
    "${trimmed_path}"

  ffmpeg \
    -y \
    -loglevel error \
    -ss "${SELECT_SECONDS[$index]}" \
    -i "${trimmed_path}" \
    -frames:v 1 \
    -update 1 \
    "${output_path}"
done

printf 'Captured %d current-build Steam screenshots in %s\n' "${#CLIPS[@]}" "${OUTPUT_DIR}"
