#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../.." && pwd)"
cd "$project"
export LABYRINTH_CEL_LOOK=all
capture_timeout=300
baseline=7cd924f52656aa6b5ddeeffc8a547a811343029d

case "$#:${1:-}" in
    0:) mode=native ;;
    1:--dry-run) mode=dry; printf 'Windowed replay: cd %q && tools/fel14/native.sh\n' "$PWD" ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
output="$(mktemp -d "$tool_dir/captures/round1-$mode.XXXXXX")"
mkdir "$output/release" "$output/branch" "$output/movie-frames"
export FEL14_ROUND1_PLAN="$output/plan.json"
python3 "$tool_dir/round1.py" --plan "$FEL14_ROUND1_PLAN"
printf 'FEL14 Round 1 output %s\n' "$output"

headless() {
    python3 tools/godot_task_runner.py --task-id fel-14 --stream -- godot \
        --headless --fixed-fps "$1" --path . --script tools/fel14/census.gd
}

windowed() {
    local side_project="$1" manifest="$2"
    shift 2
    python3 tools/visual_probe_runner.py --task-id fel-14 --no-headless \
        --project "$side_project" --godot "$tool_dir/fixed_godot.sh" \
        --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
        --expect-size 1920x1080 --result-manifest "$manifest" "$@" \
        "$side_project/tools/fel14/census.gd"
}

export FEL14_PROOF_SIDE=branch FEL14_CAPTURE_DIR="$output/branch" FEL14_MOVIE=0 FEL14_PROOF_FPS=60
if [[ "$mode" == dry ]]; then
    headless 60 2>&1 | tee "$output/branch/runner.log"
    export FEL14_MOVIE=1 FEL14_CAPTURE_DIR="$output/movie-frames"
    headless 30 2>&1 | tee "$output/movie-frames/runner.log"
    exit 0
fi

# Keep import/cache/window override writes in the cloned project, as in fel-08.
# The round-zero ref also contains the exact fixtures used by the reviewed stills.
release_project="$output/release-project"
mkdir "$release_project"
git archive "$baseline" | tar -xf - -C "$release_project"
cp -cRp "$project/.godot" "$release_project/.godot"
if [[ -d "$project/cel_look_variants" ]]; then
    cp -cRp "$project/cel_look_variants" "$release_project/cel_look_variants"
fi
cp "$tool_dir/"*.gd "$release_project/tools/fel14/"

export FEL14_PROOF_SIDE=release FEL14_CAPTURE_DIR="$output/release"
windowed "$release_project" "$output/release/visual-proof.json" \
    --proof-contract "$tool_dir/proof_contract.json" 2>&1 | tee "$output/release/runner.log"
export FEL14_PROOF_SIDE=branch FEL14_CAPTURE_DIR="$output/branch"
windowed "$project" "$output/branch/visual-proof.json" \
    --proof-contract "$tool_dir/proof_contract.json" 2>&1 | tee "$output/branch/runner.log"

export FEL14_MOVIE=1 FEL14_PROOF_FPS=30 FEL14_CAPTURE_DIR="$output/movie-frames"
windowed "$project" "$output/movie-frames/visual-proof.json" \
    2>&1 | tee "$output/movie-frames/runner.log"
ffmpeg -nostdin -v error -framerate 30 -i "$FEL14_CAPTURE_DIR/frame-%06d.png" \
    -c:v libx264 -pix_fmt yuv420p "$output/rank-07-enemy-turn.mp4"
python3 "$tool_dir/round1.py" --native-pairs "$output"
