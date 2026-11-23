#!/bin/sh
set -eu

project=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$project"
if [ "${POL74_WINDOWED_ENGINE:-0}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-74 --stream -- godot "$@"
fi

output=/private/tmp/labyrinth_codex/pol-74
base="${POL74_BASE_WORKTREE:-$project/../pol-70}"
base_commit=a753ba8a5d15ab03ae9887bab453ef7674229b8f
fixed_fps=60
export LABYRINTH_CEL_LOOK=all

mkdir -p "$output"
probe="$output/shop_readability.gd"
cp tools/pol74/shop_readability.gd.in "$probe"

check_base() {
    if [ "$(git -C "$base" branch --show-current)" != codex/pol-70 ] ||
       [ "$(git -C "$base" rev-parse HEAD)" != "$base_commit" ] ||
       ! git -C "$base" diff --quiet HEAD -- project.godot scripts scenes data assets themes; then
        echo "Before capture needs the unchanged codex/pol-70 worktree at $base_commit." >&2
        exit 1
    fi
}

capture() {
    revision=$1
    source=$2
    shift 2
    POL74_WINDOWED_ENGINE=1 python3 tools/visual_probe_runner.py "$probe" --project "$source" --task-id pol-74 \
        --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --godot "$project/tools/pol74/native.sh" \
        --proof-contract "$project/tools/pol74/native_contract.json" \
        --result-manifest "$output/$revision-manifest.json" --overwrite-result-manifest \
        -- --output "$output/$revision" "$@"
}

if [ "${1:-}" = --dry-run ]; then
    case "${2:-after}" in
        before)
            check_base
            source=$base
            set -- --before
            ;;
        after) source=$project; set -- ;;
        *) echo "Use --dry-run before or --dry-run after." >&2; exit 1 ;;
    esac
    exec python3 tools/godot_task_runner.py --task-id pol-74 --stream -- \
        godot --headless --fixed-fps "$fixed_fps" --path "$source" --script "$probe" -- --output "$output" "$@"
fi

check_base
capture before "$base" --before
capture after "$project"
