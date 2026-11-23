#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${POL75_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/pol-75}
baseline=${POL75_BASE_PROJECT:-"$root/../mrg-16"}
candidate=86d9f6ad1411e99c1336c78b8f585b018c7d70fc
case "${1:-}" in
    --dry-run) mode=headless ;;
    "") mode=native ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'POL75_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac
export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
if [ "$(git -C "$baseline" rev-parse HEAD)" != "$candidate" ] || ! git -C "$baseline" diff --quiet HEAD; then
    printf 'POL75_BASE_PROJECT must contain the unchanged candidate 5 (%s).\n' "$candidate" >&2
    exit 1
fi
mkdir -p "$output" "$root/.godot"
captures=$(mktemp -d "$output/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/pol75-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
printf 'POL-75 output: %s\n' "$captures"

# The visual runner writes an override and manages the imported cache.
# Give it its own project so the candidate worktree stays read-only.
for path in project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools cel_look_variants; do
    cp -cRp "$baseline/$path" "$stage/$path"
done
mkdir -p "$stage/.godot" "$stage/tools/pol75"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$baseline/.godot/$path" "$stage/.godot/$path"
done
cp -p "$root/tools/pol75/probe.gd" "$root/tools/pol75/probe.gd.uid" "$stage/tools/pol75/"

# The native operator needs time to hover, click, and press P in each phase.
native_timeout=300
for phase in before after; do
    folder="$captures/$phase"
    mkdir -p "$folder"
    project=$stage
    set --
    if [ "$phase" = after ]; then
        project=$root
        set -- --after
    fi
    script="$project/tools/pol75/probe.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id pol-75 --stream -- godot \
            --headless --path "$project" --script "$script" -- --dry-run --out "$folder" "$@"
    else
        python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id pol-75 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/pol75/proof.json" \
            --result-manifest "$folder/manifest.json" -- --out "$folder" --inject "$@"
        find "$folder" -maxdepth 1 -type f -name '*.png' | sort
    fi
done
if [ "$mode" = headless ]; then
    printf 'POL-75 NATIVE DRY RUN PASS — %s\n' "$captures"
fi
