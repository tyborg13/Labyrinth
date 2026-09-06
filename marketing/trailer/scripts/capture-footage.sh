#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TASK_ID="${LABYRINTH_TASK_ID:-create-escape-the-umbra-steam-trailer-with-remotion}"
FOOTAGE_DIR="${REPO_ROOT}/marketing/trailer/public/footage"
ALL_CLIPS=(push_bloom root_chain route prebattle trap_combo aoe earth air lightning umbra merchant relic spell magic_equip equipment campfire)
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
  python3 "${SCRIPT_DIR}/capture-movie.py" --task-id "${TASK_ID}" "${clip}"
done

printf 'Captured %d trailer clips in %s\n' "${#CLIPS[@]}" "${FOOTAGE_DIR}"
