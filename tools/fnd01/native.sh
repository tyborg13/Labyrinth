#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
BASE=${FND01_BASE_PROJECT:-"$(dirname "$ROOT")/fx-12"}
OUT=${FND01_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fnd-01}
CAPTURE="$ROOT/tools/fnd01/native_capture.gd"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
cd "$ROOT"

PLAN=0
CLIP=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --plan) PLAN=1 ;;
        --clip) CLIP=1 ;;
        *) break ;;
    esac
    shift
done
if [ "$#" -eq 0 ]; then
    if [ "$CLIP" -eq 1 ]; then
        set -- item gear epic common
    else
        set -- item gear common epic
        if [ "$PLAN" -eq 1 ]; then
            set -- "$@" item-reduced gear-reduced common-reduced
        fi
    fi
fi

if [ "$CLIP" -eq 1 ]; then
    if [ "$PLAN" -eq 1 ]; then
        TAKES="$OUT/clip-plan"
    else
        TAKES="$OUT/clips/takes"
        command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || {
            echo "Native clip mode requires ffmpeg and ffprobe." >&2
            exit 1
        }
    fi
    for clip_case in "$@"; do
        case "$clip_case" in
            item|gear|epic|common) ;;
            *) echo "Unknown clip case: $clip_case" >&2; exit 1 ;;
        esac
    done
fi

capture() {
    version=$1
    project=$2
    take=$3
    shift 3
    case "$take" in
        *-reduced) set -- --reduced "$@" ;;
    esac
    case_id=${take%-reduced}
    if [ "$CLIP" -eq 1 ]; then
        dir="$TAKES/$version/$take"
        set -- --clip "$@"
    elif [ "$PLAN" -eq 1 ]; then
        dir="$OUT/plan/$version/$take"
    else
        dir="$OUT/native/$version/$take"
    fi
    mkdir -p "$dir"
    if [ "$PLAN" -eq 1 ]; then
        python3 tools/godot_task_runner.py --task-id fnd-01 --stream -- godot --headless \
            --fixed-fps 60 --path "$project" --script "$CAPTURE" -- \
            --plan --case "$case_id" --out "$dir" "$@"
    else
        export FX12_CLOCK_FILE="$dir/clock.avi"
        python3 tools/visual_probe_runner.py "$CAPTURE" --task-id fnd-01 --project "$project" \
            --no-headless --display-driver macos --audio-driver Dummy --godot "$ROOT/tools/fx12/movie_clock.sh" \
            --timeout 120 --proof-contract "$ROOT/tools/fnd01/proof_contract.json" \
            --result-manifest "$dir/manifest.json" --overwrite-result-manifest -- \
            --case "$case_id" --out "$dir" "$@"
        if [ "$CLIP" -eq 0 ]; then rm -f "$FX12_CLOCK_FILE"; fi
    fi
}

for take in "$@"; do
    capture before "$BASE" "$take"
    capture after "$ROOT" "$take" --after
    if [ "$CLIP" -eq 1 ]; then
        if [ "$PLAN" -eq 1 ]; then
            python3 tools/fnd01/encode_clips.py --takes "$TAKES" --output "$OUT/clips" --plan "$take"
        else
            python3 tools/fnd01/encode_clips.py --takes "$TAKES" --output "$OUT/clips" "$take"
        fi
    fi
done

if [ "$PLAN" -eq 1 ] && [ "$CLIP" -eq 0 ]; then
    python3 - "$OUT/plan" "$@" <<'PY'
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1])
for take in sys.argv[2:]:
    before, after = (json.loads((directory / side / take / "take.json").read_text())
                     for side in ("before", "after"))
    fields = ("ray", "subject_end", "complete")
    timings = tuple(after[field] for field in fields)
    if timings != tuple(before[field] for field in fields):
        raise SystemExit(f"FND-01 PACING FAIL {take}: {before} vs {after}")
    print(f"FND-01 PACING PASS {take}: ray={timings[0]} subject_end={timings[1]} "
          f"complete={timings[2]}; burst_end={before['burst_end']}->{after['burst_end']}")
PY
fi
