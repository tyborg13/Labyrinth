#!/usr/bin/env bash
# Run from a logged-in macOS session with the repository's native capture tools.
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
project="$PWD"
release_ref=codex/release
release_sha="$(git merge-base HEAD "$release_ref")"
capture_timeout=180
movie_fps=60
variant_fixture=07-s4-seed1-4-19_-19-t4
proof_contract="$project/tools/fel09/proof_contract.json"
export LABYRINTH_CEL_LOOK=all

case "${1:-}" in
    --dry-run) (( $# == 1 )) || exit 2; dry_run=1 ;;
    '') (( $# == 0 )) || exit 2; dry_run=0 ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
for executable in godot ffmpeg ffprobe; do command -v "$executable" >/dev/null; done

if (( dry_run )); then
    python3 tools/fel09/native_report.py --check
    printf 'FEL15 NATIVE DRY RUN PASS release=%s paired=07,11,12 branch_still=01-12 variants=reduced,hurry fps=%s\n' "$release_sha" "$movie_fps"
    printf 'FEL15 WINDOWED COMMAND cd %q && bash tools/fel15/native.sh\n' "$project"
    exit 0
fi

mkdir -p output/fel15
touch output/.gdignore
run_dir="$(mktemp -d "$project/output/fel15/native.XXXXXX")"
release_project="$run_dir/release-project"
mkdir "$release_project"
printf 'FEL15 NATIVE OUTPUT %s\n' "$run_dir"
printf '%s\n' "$release_sha" > "$run_dir/release-ref.txt"
# Release predates the fel-09 fixtures. Add the same witness to the archived
# source and keep the owner's release worktree untouched.
git archive "$release_sha" | tar -xf - -C "$release_project"
if [[ -d .godot ]]; then cp -cR .godot "$release_project/.godot"; fi
cp -R tools/fel01 tools/fel09 "$release_project/tools/"

run_probe() {
    local side="$1" fixture="$2" variant="$3" movie="$4"
    local scene_project="$project" directory="$run_dir/$side${variant:+-$variant}/$fixture"
    local -a godot_args=()
    if [[ "$side" == release ]]; then scene_project="$release_project"; fi
    mkdir -p "$directory"
    if [[ "$movie" == movie ]]; then godot_args=(--godot "$tool_dir/movie.sh"); fi
    FEL09_CAPTURE_DIR="$directory" FEL09_FIXTURE="$fixture" FEL15_VARIANT="$variant" \
        FEL15_MOVIE_PATH="$directory/turn.avi" FEL15_MOVIE_FPS="$movie_fps" \
        python3 tools/visual_probe_runner.py --project "$scene_project" --task-id fel-15 \
        --no-headless --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
        --expect-size 1920x1080 --proof-contract "$proof_contract" \
        --result-manifest "$directory/visual-proof.json" "${godot_args[@]+${godot_args[@]}}" tools/fel09/census.gd \
        2>&1 | tee "$directory/runner.log"
    python3 tools/fel09/native_report.py --fixture "$directory" | tee "$directory/still.log"
}

check_pair() {
    python3 tools/fel15/compare.py "$1" "$2" | tee -a "$run_dir/summary.log"
}

status=0
for source in tools/fel01/fixtures/*/; do
    fixture="$(basename "$source")"
    case "$fixture" in
        07-*|11-*|12-*)
            run_probe release "$fixture" '' movie
            run_probe branch "$fixture" '' movie
            release_take="$run_dir/release/$fixture"
            branch_take="$run_dir/branch/$fixture"
            python3 tools/fel15/pair.py "$release_take" "$branch_take" "$run_dir/${fixture:0:2}-release-branch.mp4" "$movie_fps"
            check_pair "$release_take" "$branch_take" || status=1
            rm "$release_take/turn.avi" "$branch_take/turn.avi"
            ;;
        *) run_probe branch "$fixture" '' still ;;
    esac
done
for variant in reduced hurry; do
    run_probe release "$variant_fixture" "$variant" still
    run_probe branch "$variant_fixture" "$variant" still
    check_pair "$run_dir/release-$variant/$variant_fixture" "$run_dir/branch-$variant/$variant_fixture" || status=1
done

python3 - "$run_dir" <<'PY' | tee -a "$run_dir/summary.log" || status=1
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
failed = False
for side in ("release", "branch", "release-reduced", "branch-reduced", "release-hurry", "branch-hurry"):
    receipts = sorted((root / side).glob("*/still.json"))
    expected = 12 if side == "branch" else 3 if side == "release" else 1
    if len(receipts) != expected:
        raise ValueError(f"Missing native receipts for {side}")
    still = sum(len(json.loads(path.read_text())["runs"]) for path in receipts)
    stacked = sum(json.loads(path.with_name("timeline.json").read_text())["fixtures"][0]["stacked_number_frames"] for path in receipts)
    print(f"FEL15 NATIVE STILL side={side} runs={still} minimum_ms=150")
    print(f"FEL15 STACKED NUMBERS frames={stacked}")
    if side.startswith("branch"): failed |= still != 0 or stacked != 0
raise SystemExit(int(failed))
PY
exit "$status"
