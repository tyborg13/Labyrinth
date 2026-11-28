#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/../.." && pwd -P)"
tool_dir="$project/tools/pol85"
checkpoint="$project/tools/fel01/fixtures/04-s0-seed8-0--3_2-t5"
output_root=/private/tmp/labyrinth_codex/pol85
fps=60
dry_run=false
if [[ "${1:-}" == --dry-run ]]; then
    dry_run=true
    shift
fi
if "$dry_run" && [[ $# == 0 ]]; then
    mkdir -p "$output_root"
    set -- "$project/../release" "$(mktemp -d "$output_root/dry.XXXXXX")"
fi
if [[ $# != 2 ]]; then
    printf 'Usage: %s [--dry-run] <release worktree> <out dir>\n' "$0" >&2
    exit 2
fi
release="$(cd "$1" && pwd -P)"
if [[ ! -f "$release/project.godot" || "$release" == "$project" ]]; then
    printf 'Pass a separate release worktree containing project.godot.\n' >&2
    exit 2
fi
mkdir -p "$2"
output="$(cd "$2" && pwd -P)"
if ! "$dry_run"; then
    command -v ffmpeg >/dev/null
    command -v ffprobe >/dev/null
    python3 -c 'from PIL import Image, ImageDraw, ImageFont'
fi
mkdir "$output/checkpoint" "$output/before" "$output/after"
cp "$checkpoint"/{run.save,progression.json,combat.witness} "$output/checkpoint/"
printf 'POL85 OUTPUT %s\n' "$output"

run_take() {
    local build="$1" source="$2" directory="$output/$1"
    local probe="$tool_dir/movie_probe.gd"
    local args=(--build "$build" --checkpoint "$output/checkpoint" --proof-output "$directory")
    if "$dry_run"; then
        python3 "$project/tools/godot_task_runner.py" --project "$source" --task-id pol-85 --stream -- \
            godot --headless --path "$source" --fixed-fps "$fps" --script "$probe" -- --movie-check "${args[@]}"
    else
        POL85_MOVIE_DIR="$directory" python3 "$project/tools/visual_probe_runner.py" \
            --project "$source" --godot "$tool_dir/movie_godot.sh" --no-headless --display-driver macos \
            --rendering-driver metal --rendering-method mobile --audio-driver Dummy \
            --timeout 300 --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
            --result-manifest "$directory/manifest.json" --task-id pol-85 \
            "$probe" -- --movie "${args[@]}"
    fi
}
run_take before "$release" 2>&1 | tee "$output/before/runner.log"
run_take after "$project" 2>&1 | tee "$output/after/runner.log"
if "$dry_run"; then
    python3 "$tool_dir/pair.py" --timeline-only "$output"
    printf 'POL85 DRY RUN PASS before=hand,grimoire after=hand,grimoire\n'
else
    python3 "$tool_dir/pair.py" "$output"
fi
