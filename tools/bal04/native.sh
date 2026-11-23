#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${BAL04_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/bal-04}
candidate=647b49092cd1464d5c6339b9808b05973f62a4f4
candidate_cache=${BAL04_CANDIDATE_CACHE:-"$root/../mrg-18/.godot"}
native_timeout=300

case "${1:-}" in
    --dry-run) mode=headless ;;
    "") mode=native ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'BAL04_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac

export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
mkdir -p "$output" "$root/.godot"
captures=$(mktemp -d "$output/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/bal04-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
printf 'BAL-04 output: %s\n' "$captures"

# Read tracked candidate files from Git. Another branch may be using the
# candidate worktree, so reuse only its generated import cache.
git archive --format=tar --output="$stage/candidate.tar" "$candidate" \
    project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools
tar -xf "$stage/candidate.tar" -C "$stage"
rm "$stage/candidate.tar"
mkdir -p "$stage/.godot" "$stage/tools/bal04"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$candidate_cache/$path" "$stage/.godot/$path"
done
cp -cRp "$root/cel_look_variants" "$stage/cel_look_variants"
cp -p "$root/tools/bal04/probe.gd" "$root/tools/bal04/probe.gd.uid" "$stage/tools/bal04/"

for phase in before after; do
    folder="$captures/$phase"
    mkdir -p "$folder"
    project=$stage
    set --
    if [ "$phase" = after ]; then
        project=$root
        set -- --after
    fi
    script="$project/tools/bal04/probe.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id bal-04 --stream -- godot \
            --headless --path "$project" --script "$script" -- --dry-run --out "$folder" "$@"
    else
        python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id bal-04 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/bal04/proof.json" \
            --result-manifest "$folder/manifest.json" -- --out "$folder" "$@"
    fi
done
if [ "$mode" = headless ]; then
    printf 'BAL-04 NATIVE DRY RUN PASS — %s\n' "$captures"
fi
