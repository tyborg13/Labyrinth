#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TASK_ID="${LABYRINTH_TASK_ID:-create-escape-the-umbra-steam-trailer-with-remotion}"
FOOTAGE_DIR="${REPO_ROOT}/marketing/trailer/public/footage"
ALL_CLIPS=(route prebattle trap_combo aoe umbra merchant relic spell equipment)
if (( $# > 0 )); then
  CLIPS=("$@")
else
  CLIPS=("${ALL_CLIPS[@]}")
fi

for clip in "${CLIPS[@]}"; do
  case " ${ALL_CLIPS[*]} " in
    *" ${clip} "*) ;;
    *)
      printf 'Unknown trailer clip: %s\n' "${clip}" >&2
      exit 2
      ;;
  esac
done

mkdir -p "${FOOTAGE_DIR}"

for clip in "${CLIPS[@]}"; do
  raw_path="${FOOTAGE_DIR}/${clip}.avi"
  edit_path="${FOOTAGE_DIR}/${clip}.mp4"

  case "${clip}" in
    route) trim_frames=42 ;;
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
    "--clip=${clip}"

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
    -movflags +faststart \
    "${edit_path}"
done

printf 'Captured %d trailer clips in %s\n' "${#CLIPS[@]}" "${FOOTAGE_DIR}"
