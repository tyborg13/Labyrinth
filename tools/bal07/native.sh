#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${BAL07_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/bal-07}
candidate=23152865ae25efdea3a915fc7bb56fe2a10e18fd
candidate_cache=${BAL07_CANDIDATE_CACHE:-"$root/.godot"}
native_timeout=300

mode=native
case "$#:$*" in
    0:) ;;
    1:--dry-run) mode=headless ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'BAL07_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac

export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
mkdir -p "$output" "$root/.godot"
captures=$(mktemp -d "$output/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/bal07-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
printf 'BAL-07 output: %s\n' "$captures"

# Stage the exact candidate and reuse the worktree's generated imports.
# The numeric card changes do not alter content imported by Godot.
git archive --format=tar --output="$stage/candidate.tar" "$candidate" \
    project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools
tar -xf "$stage/candidate.tar" -C "$stage"
rm "$stage/candidate.tar"
mkdir -p "$stage/.godot" "$stage/tools/bal07"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$candidate_cache/$path" "$stage/.godot/$path"
done
cp -cRp "$root/cel_look_variants" "$stage/cel_look_variants"
cp -p "$root/tools/bal07/probe.gd" "$root/tools/bal07/probe.gd.uid" "$stage/tools/bal07/"

for phase in before after; do
    folder="$captures/$phase"
    mkdir -p "$folder"
    project=$stage
    set --
    if [ "$phase" = after ]; then
        project=$root
        set -- --after
    fi
    script="$project/tools/bal07/probe.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id bal-07 --stream -- godot \
            --headless --path "$project" --script "$script" -- --dry-run --out "$folder" "$@"
    else
        python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id bal-07 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/bal07/proof.json" \
            --result-manifest "$folder/manifest.json" -- --out "$folder" "$@"
    fi
done
if [ "$mode" = headless ]; then
    printf 'BAL-07 NATIVE DRY RUN PASS — %s\n' "$captures"
fi
