#!/bin/sh
set -eu

root=${FX38_WORKTREE:-/Users/borgerding/workspace/Labyrinth.worktrees/fx-38}
if [ -f "$(dirname "$0")/stage_project.py" ]; then
    root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fi
cd "$root"

out=${FX38_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-38}
base=${FX38_BASE_PROJECT:-/Users/borgerding/workspace/Labyrinth.worktrees/mrg-15}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0

mode=native
if [ "${1:-}" = --dry-run ]; then
    mode=plan
    shift
fi
if [ "$#" -ne 0 ]; then
    printf '%s\n' 'Usage: native.sh [--dry-run]' >&2
    exit 2
fi
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
run=$(mktemp -d "$out/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/fx38-proof.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/before" "$stage/after"
python3 tools/fx38/stage_project.py "$base" "$stage/before" "$mode" before
python3 tools/fx38/stage_project.py "$root" "$stage/after" "$mode" after

capture() {
    variant=$1
    project=$2
    shift 2
    dir="$run/$variant"
    mkdir -p "$dir"
    if [ "$mode" = plan ]; then
        python3 tools/godot_task_runner.py --task-id fx-38 --stream -- godot \
            --headless --fixed-fps 60 --path "$project" --script tools/fx38/native.gd -- \
            --plan --out "$dir" "$@" > "$dir/probe.log" 2>&1 || {
                cat "$dir/probe.log"
                return 1
            }
        cat "$dir/probe.log"
        if [ "$variant" = before ]; then
            rg -q 'FX-38 BASE draw_colored_polygon.*vertices=33 alpha=0.55' "$dir/probe.log"
            count=$(rg -c 'FX-38 BASE draw_colored_polygon.*vertices=33' "$dir/probe.log")
            test "$count" -ge 4
        fi
        rg -q "PLAN PASS" "$dir/probe.log"
        return
    fi
    export FX38_CLOCK_FILE="$stage/$variant.avi"
    python3 tools/visual_probe_runner.py tools/fx38/native.gd --project "$project" --task-id fx-38 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx38/movie_clock.sh" \
        --timeout 180 --expect-size 1920x1080 --proof-contract "$root/tools/fx38/$variant.json" \
        --result-manifest "$dir/manifest.json" -- --out "$dir" "$@"
    find "$dir" -name '*.png' -print | sort
}
capture before "$stage/before" --before
capture after "$stage/after"
printf 'FX-38 %s evidence %s\n' "$mode" "$run"
