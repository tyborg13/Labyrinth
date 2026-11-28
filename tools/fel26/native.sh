#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../.." && pwd)"
cd "$project"
fel13="$project/tools/fel13"
export FEL13_TOOL_DIR="$fel13"
export LABYRINTH_CEL_LOOK=all
export FEL26_VIEWPORT_INPUT=1
unset FEL13_FIXTURE FEL13_SHADER_DEBUG FEL26_BASELINE_SOURCE FEL26_RELEASE_BASELINE FEL26_AUDIT FEL26_PARITY FEL26_BASELINE_SHADER
variants=(off window always)
motions=(M1a M2)
session="$fel13/session.gd"
failed=0
mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
output="$(mktemp -d "$tool_dir/captures/fel26.XXXXXX")"
echo "FEL26 capture directory $output"

run_headless() {
    python3 tools/godot_task_runner.py --task-id fel-26 --stream -- godot --headless --path "$project" --script "$session"
}

run_visual() {
    python3 tools/visual_probe_runner.py --task-id fel-26 --no-headless --display-driver macos         --audio-driver Dummy --attempts 1 --timeout 240 --expect-size 1920x1080 "$@" "$session"
}

case "${1:-}" in
    --headless)
        export FEL26_PARITY=1
        git show 26cb83943:scripts/board_occlusion_silhouettes.gd > "$output/release-overlay.txt"
        FEL26_BASELINE_SOURCE="$output/release-overlay.txt" FEL26_RELEASE_BASELINE=1 FEL26_AUDIT=1             FEL13_MODE=witness FEL13_SIDE=branch LABYRINTH_OCCLUDER_EDGE=off run_headless \
            > "$output/release.log" 2>&1 || failed=1
        for variant in "${variants[@]}"; do
            FEL26_AUDIT=1 FEL13_MODE=witness FEL13_SIDE=branch LABYRINTH_OCCLUDER_EDGE="$variant" \
                run_headless | tee "$output/$variant.log" || failed=1
        done
        if [[ "$failed" == 0 ]]; then
            python3 "$tool_dir/proof.py" headless "$output"
        else
            echo "FEL26 OCCLUDER EDGE FAIL logs=$output" >&2
            exit 1
        fi
        exit 0
        ;;
    --dry-run)
        for variant in "${variants[@]}"; do
            export LABYRINTH_OCCLUDER_EDGE="$variant"
            FEL13_MODE=fel26_still run_headless | tee "$output/$variant-stills.log" || failed=1
            for motion in "${motions[@]}"; do
                FEL13_MODE=motion FEL13_MOTION="$motion" run_headless | tee "$output/$variant-$motion.log" || failed=1
            done
        done
        exit "$failed"
        ;;
    "") ;;
    *) echo "Usage: $0 [--headless | --dry-run]" >&2; exit 2 ;;
esac

git show 26cb83943:scripts/board_occlusion_silhouettes.gdshader > "$output/release-outline.txt"
export FEL26_BASELINE_SHADER="$output/release-outline.txt"
for variant in "${variants[@]}"; do
    export LABYRINTH_OCCLUDER_EDGE="$variant"
    dir="$output/$variant"
    mkdir -p "$dir"
    FEL13_MODE=fel26_still FEL13_CAPTURE_DIR="$dir" \
        run_visual --proof-contract "$tool_dir/still_contract.json" --result-manifest "$dir/stills.json" \
        2>&1 | tee "$dir/stills.log" || failed=1
    for motion in "${motions[@]}"; do
        take="$dir/$motion"
        mkdir -p "$take"
        FEL13_MODE=motion FEL13_MOTION="$motion" FEL13_CAPTURE_DIR="$take" FEL13_MOVIE="$take/game.avi" \
            run_visual --godot "$fel13/movie_godot.sh" --proof-contract "$tool_dir/motion_contract.json" \
            --result-manifest "$take/proof.json" 2>&1 | tee "$take/run.log" || failed=1
    done
done
if [[ "$failed" == 0 ]]; then
    python3 "$tool_dir/proof.py" native "$output" || failed=1
fi
exit "$failed"
