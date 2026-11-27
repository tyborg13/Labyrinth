#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../.." && pwd)"
cd "$project"
export FEL13_TOOL_DIR="$tool_dir"
export LABYRINTH_CEL_LOOK=all
base_project="${FEL13_RELEASE_PROJECT:-$project/../release}"
timeout=240
content_dry_timeout=360
session="$tool_dir/session.gd"
grid_only="${FEL13_SHADER_DEBUG:-}"
unset FEL13_FIXTURE FEL13_SHADER_DEBUG
failed=0
sample_order=(1-release 1-branch 2-branch 2-release 3-release 3-branch)
motions=(M1a M1b M2 M3)

run_headless() {
    python3 tools/godot_task_runner.py --task-id fel-16 --timeout "${2:-$timeout}" --stream \
        -- godot --headless --path "$1" --script "$session"
}

skip_content() {
    echo "FEL16 NATIVE CONTENT SKIPPED (grid failed)"
    exit 1
}

if [[ "${1:-}" == --dry-run ]]; then
    printf 'Windowed proof: cd %q && tools/fel13/native.sh\n' "$project"
    printf 'Windowed timing only: cd %q && tools/fel13/native.sh --perf\n' "$project"
    echo "FEL16 NATIVE PLAN grid P1"
    FEL13_SHADER_DEBUG=grid FEL13_MODE=dry FEL13_SIDE=branch run_headless "$project" || skip_content
    if [[ "$grid_only" == grid ]]; then exit 0; fi
    echo "FEL16 NATIVE PLAN content on/off/clear"
    if [[ "${2:-}" == --content ]]; then
        FEL13_MODE=content FEL13_SIDE=branch run_headless "$project" "$content_dry_timeout"
        exit 0
    fi
    for side in release branch; do
        repo="$project"
        if [[ "$side" == release ]]; then repo="$base_project"; fi
        FEL13_MODE=dry FEL13_SIDE="$side" run_headless "$repo" || failed=1
    done
    echo "FEL16 NATIVE PLAN zooms P1-P8 release/branch"
    echo "FEL16 NATIVE PLAN motion ${motions[*]}"
    for motion in "${motions[@]}"; do
        FEL13_MODE=motion FEL13_MOTION="$motion" run_headless "$project" || failed=1
    done
    echo "FEL16 NATIVE PLAN perf ${sample_order[*]}"
    for side in release branch; do
        repo="$project"
        if [[ "$side" == release ]]; then repo="$base_project"; fi
        FEL13_MODE=perf FEL13_SIDE="$side" run_headless "$repo" || failed=1
    done
    exit "$failed"
fi

case "${1:-}" in
    ""|--content|--perf|--motion) ;;
    *) echo "Usage: $0 [--dry-run [--content] | --content | --perf | --motion]" >&2; exit 2 ;;
esac

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
output="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
echo "FEL13 capture directory $output"

run_visual() {
    python3 tools/visual_probe_runner.py --task-id fel-16 --no-headless --display-driver macos \
        --audio-driver Dummy --attempts 1 --timeout "$timeout" --expect-size 1920x1080 "$@" "$session"
}

run_perf() {
    samples=()
    for sample in "${sample_order[@]}"; do
        side="${sample#*-}"
        repo="$project"
        if [[ "$side" == release ]]; then repo="$base_project"; fi
        dir="$output/$sample"
        mkdir "$dir"
        FEL13_MODE=perf FEL13_SIDE="$side" FEL13_CAPTURE_DIR="$dir" \
            run_visual --project "$repo" --result-manifest "$dir/proof.json" 2>&1 | tee "$dir/run.log" || failed=1
        samples+=("$dir/run.log")
    done
    python3 "$tool_dir/proof.py" perf "${samples[@]}" || failed=1
}

run_motion() {
    for motion in "${motions[@]}"; do
        dir="$output/$motion"
        mkdir "$dir"
        FEL13_MODE=motion FEL13_MOTION="$motion" FEL13_CAPTURE_DIR="$dir" FEL13_MOVIE="$dir/game.avi" \
            run_visual --godot "$tool_dir/movie_godot.sh" --result-manifest "$dir/proof.json" 2>&1 | tee "$dir/run.log" || failed=1
    done
    python3 "$tool_dir/proof.py" motion "$output" || failed=1
}

if [[ "${1:-}" == --motion ]]; then
    run_motion
    exit "$failed"
fi

if [[ "${1:-}" == --perf ]]; then
    run_perf
    exit "$failed"
fi

mkdir -p "$output/branch"
grid_log="$output/branch/grid.log"
FEL13_SHADER_DEBUG=grid FEL13_MODE=still FEL13_SIDE=branch FEL13_CAPTURE_DIR="$output/branch" \
    run_visual --project "$project" --proof-contract "$tool_dir/grid_proof_contract.json" --result-manifest "$output/branch/grid-proof.json" 2>&1 | tee "$grid_log" || skip_content
if ! grep -q '^FEL13 NATIVE GRID PASS red_in_on=' "$grid_log"; then skip_content; fi
if [[ "$grid_only" == grid ]]; then exit 0; fi

if [[ "${1:-}" == --content ]]; then
    export FEL16_REFERENCE_DIR="${FEL16_REFERENCE_DIR:-$tool_dir/captures/native.zmvinb/branch}"
    FEL13_MODE=content FEL13_SIDE=branch FEL13_CAPTURE_DIR="$output/branch" \
        run_visual --project "$project" --min-images 60 --result-manifest "$output/branch/content-proof.json" \
        2>&1 | tee "$output/branch/run.log"
    exit 0
fi

for side in release branch; do
    repo="$project"
    if [[ "$side" == release ]]; then repo="$base_project"; fi
    dir="$output/$side"
    mkdir -p "$dir"
    FEL13_MODE=still FEL13_SIDE="$side" FEL13_CAPTURE_DIR="$dir" \
        run_visual --project "$repo" --proof-contract "$tool_dir/proof_contract.json" --result-manifest "$dir/proof.json" 2>&1 | tee "$dir/run.log" || failed=1
done
python3 "$tool_dir/proof.py" contacts "$output" || failed=1
python3 "$tool_dir/proof.py" zooms "$output" || failed=1

run_motion
run_perf
exit "$failed"
