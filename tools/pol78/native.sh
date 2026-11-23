#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${POL78_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/pol-78}
baseline=${POL78_BASE_PROJECT:-"$root/../mrg-18"}
candidate=647b49092cd1464d5c6339b9808b05973f62a4f4

case "${1:-}" in
    --dry-run) mode=headless ;;
    "") mode=native ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'POL78_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac
export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
if [ "$(git -C "$baseline" rev-parse HEAD)" != "$candidate" ]; then
    printf 'POL78_BASE_PROJECT must be checked out at candidate 7 (%s).\n' "$candidate" >&2
    exit 1
fi

mkdir -p "$output" "$root/.godot"
captures=$(mktemp -d "$output/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/pol78-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
printf 'POL-78 output: %s\n' "$captures"

# Stage the candidate's project and imports so the visual runner can manage
# them without writing to the baseline worktree.
git -C "$baseline" archive --output "$stage/source.tar" "$candidate" \
    project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools
tar -xf "$stage/source.tar" -C "$stage"
rm "$stage/source.tar"
cp -cRp "$baseline/cel_look_variants" "$stage/cel_look_variants"
mkdir -p "$stage/.godot" "$stage/tools/pol78"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$baseline/.godot/$path" "$stage/.godot/$path"
done
cp -p "$root/tools/pol78/measure.gd" "$stage/tools/pol78/"

native_timeout=180
for phase in before after; do
    folder="$captures/$phase"
    mkdir -p "$folder"
    project=$stage
    set --
    if [ "$phase" = after ]; then
        project=$root
        set -- --verify-held
    fi
    script="$project/tools/pol78/measure.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id pol-78 --stream -- godot \
            --headless --path "$project" --script "$script" -- --dry-run --out "$folder" "$@"
    else
        python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id pol-78 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/pol78/proof.json" \
            --result-manifest "$folder/manifest.json" -- --out "$folder" "$@"
        find "$folder" -maxdepth 1 -type f -name '*.png' | sort
    fi
done
if [ "$mode" = headless ]; then
    printf 'POL-78 NATIVE DRY RUN PASS — %s\n' "$captures"
fi
