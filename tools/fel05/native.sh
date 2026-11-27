#!/usr/bin/env bash
set -euo pipefail

dry_run=false
if [[ "${1:-}" == --dry-run ]]; then
    dry_run=true
    shift
fi
if [[ "$#" != 1 ]]; then
    echo "Usage: $0 [--dry-run] <fel-03-baseline-worktree>" >&2
    exit 2
fi
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$tool_dir/../.." && pwd)"
baseline="$(cd "$1" && pwd)"
cd "$repo"
export LABYRINTH_CEL_LOOK=all
capture_timeout=180
release_capture="$baseline/tools/fel03/captures/native.0uBNGs"

compare_zooms() {
    python3 tools/godot_task_runner.py --task-id fel-05 --stream -- \
        godot --headless --path . --script tools/fel05/compare_zooms.gd -- "$release_capture" "$1" "$2"
}

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
if "$dry_run"; then
    out="$(mktemp -d "$tool_dir/captures/dry.XXXXXX")"
    python3 tools/godot_task_runner.py --task-id fel-05 --timeout "$capture_timeout" --stream -- \
        godot --headless --fixed-fps 60 --path . --script tools/fel03/capture.gd -- --dry-run \
        | tee "$out/runner.log"
    # Exercise the zoom builder on the two director-supplied captures.
    compare_zooms "$tool_dir/captures/native.QcukmM" "$out/comparison-check" \
        | tee "$out/zoom-check.log"
else
    driver="$(mktemp "$tool_dir/.fel03-native.XXXXXX")"
    driver_log="$(mktemp "$tool_dir/captures/.driver.XXXXXX")"
    trap 'rm -f "$driver" "$driver_log"' EXIT
    # Run the original launcher bytes from this sibling directory so its
    # BASH_SOURCE-derived capture path belongs to fel05.
    cp tools/fel03/native.sh "$driver"
    bash "$driver" | tee "$driver_log"
    out="$(dirname "$(tail -n 1 "$driver_log")")"
    test -f "$out/visual-proof.json"
    python3 "$tool_dir/after_strips.py" "$out"
    compare_zooms "$out" "$out/comparisons" | tee "$out/zoom.log"
fi

measure() (
    local pair="$1" revision="$2" worktree="$3" dest="$out/$1/$2"
    mkdir -p "$dest"
    export FEL03_CAPTURE_DIR="$dest"
    if "$dry_run"; then
        python3 "$repo/tools/godot_task_runner.py" --task-id fel-05 --timeout "$capture_timeout" --stream -- \
            godot --headless --fixed-fps 60 --path "$worktree" --script "$tool_dir/timing.gd" -- --dry-run \
            2>&1 | tee "$dest/runner.log"
    else
        export FX15_CLOCK_FILE="$dest/clock.avi"
        trap 'rm -f "$FX15_CLOCK_FILE"' EXIT
        cd "$worktree"
        python3 tools/visual_probe_runner.py "$tool_dir/timing.gd" --task-id fel-05 \
            --no-headless --display-driver macos --audio-driver Dummy \
            --godot tools/fx15/movie_clock.sh --timeout "$capture_timeout" --min-images 0 \
            --result-manifest "$dest/timing-proof.json" 2>&1 | tee "$dest/runner.log"
    fi
    printf 'FEL05 %s %s timing: %s\n' "$pair" "$revision" "$dest"
)
measure pair-01 before "$baseline"
measure pair-01 after "$repo"
measure pair-02 after "$repo"
measure pair-02 before "$baseline"
measure pair-03 before "$baseline"
measure pair-03 after "$repo"
if "$dry_run"; then
    python3 "$tool_dir/after_strips.py" "$out" --timings --dry-run
    printf '%s\n' "$out/effect-overlay-dry.md"
else
    python3 "$tool_dir/after_strips.py" "$out" --timings
    printf '%s\n' "$out/after-strips.md" "$out/comparisons/" "$out/effect-overlay.md"
fi
