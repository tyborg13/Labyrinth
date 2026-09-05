#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TASK_ID="${LABYRINTH_TASK_ID:-create-escape-the-umbra-steam-trailer-with-remotion}"
FOOTAGE_DIR="${REPO_ROOT}/marketing/trailer/public/footage"
ALL_CLIPS=(route prebattle trap_combo aoe umbra merchant relic spell magic_equip equipment)
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

  capture_log="$(mktemp "${TMPDIR:-/tmp}/umbra-${clip}.XXXXXX")"

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
    "--clip=${clip}" | tee "${capture_log}"

  trim_frames="$(sed -n 's/^STEAM_TRAILER_SAFE_START_FRAME=//p' "${capture_log}" | tail -1)"
  if [[ ! "${trim_frames}" =~ ^[0-9]+$ ]]; then
    printf 'Missing measured safe first frame for %s (log: %s)\n' "${clip}" "${capture_log}" >&2
    exit 1
  fi
  printf 'Trimming %s at measured frame %s (log: %s)\n' "${clip}" "${trim_frames}" "${capture_log}"

  # Godot Movie Maker writes full-range JPEG/BT.601. Convert the samples as
  # well as the tags so the compositor retains the original shadow detail.
  ffmpeg \
    -y \
    -loglevel error \
    -i "${raw_path}" \
    -an \
    -vf "trim=start_frame=${trim_frames},setpts=PTS-STARTPTS,scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setsar=1" \
    -c:v libx264 \
    -preset medium \
    -crf 15 \
    -pix_fmt yuv420p \
    -color_range tv \
    -colorspace bt709 \
    -color_primaries bt709 \
    -color_trc bt709 \
    -bsf:v h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 \
    -movflags +faststart \
    "${edit_path}"
done

printf 'Captured %d trailer clips in %s\n' "${#CLIPS[@]}" "${FOOTAGE_DIR}"
