#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TASK_ID="${LABYRINTH_TASK_ID:-create-escape-the-umbra-steam-trailer-with-remotion}"
FOOTAGE_DIR="${REPO_ROOT}/marketing/trailer/public/footage"
CLIPS=(route prebattle trap_combo aoe umbra reward)

mkdir -p "${FOOTAGE_DIR}"

for clip in "${CLIPS[@]}"; do
  raw_path="${FOOTAGE_DIR}/${clip}.avi"
  edit_path="${FOOTAGE_DIR}/${clip}.mp4"

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
    "--clip=${clip}"

  ffmpeg \
    -y \
    -loglevel error \
    -i "${raw_path}" \
    -an \
    -c:v libx264 \
    -preset medium \
    -crf 15 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "${edit_path}"
done

printf 'Captured %d trailer clips in %s\n' "${#CLIPS[@]}" "${FOOTAGE_DIR}"
