#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${BAL05_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/bal-05}
candidate=7b3176ac60526b4d249f0e330631e98097a1ed1c
candidate_cache=${BAL05_CANDIDATE_CACHE:-"$root/.godot"}
native_timeout=300

mode=native
round_flag=
contract=proof.json
for option in "$@"; do
    case "$option" in
        --dry-run) mode=headless ;;
        --round-1) round_flag=--round-1; contract=proof-round1.json ;;
        *) printf 'Usage: %s [--round-1] [--dry-run]\n' "$0" >&2; exit 2 ;;
    esac
done
case "$output" in
    /*) ;;
    *) printf 'BAL05_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac
if [ -n "$round_flag" ]; then
    output="$output/round1"
fi

export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
mkdir -p "$output" "$root/.godot"
captures=$(mktemp -d "$output/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/bal05-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
printf 'BAL-05 output: %s\n' "$captures"

# Read the candidate from Git and reuse the task worktree’s generated import cache.
# The card and test edits do not change any imported assets.
git archive --format=tar --output="$stage/candidate.tar" "$candidate" \
    project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools
tar -xf "$stage/candidate.tar" -C "$stage"
rm "$stage/candidate.tar"
mkdir -p "$stage/.godot" "$stage/tools/bal05"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$candidate_cache/$path" "$stage/.godot/$path"
done
cp -cRp "$root/cel_look_variants" "$stage/cel_look_variants"
cp -p "$root/tools/bal05/probe.gd" "$root/tools/bal05/probe.gd.uid" "$stage/tools/bal05/"

for phase in before after; do
    folder="$captures/$phase"
    mkdir -p "$folder"
    project=$stage
    set --
    if [ "$phase" = after ]; then
        project=$root
        set -- --after
    fi
    if [ -n "$round_flag" ]; then
        set -- "$@" "$round_flag"
    fi
    script="$project/tools/bal05/probe.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id bal-05 --stream -- godot \
            --headless --path "$project" --script "$script" -- --dry-run --out "$folder" "$@"
    else
        python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id bal-05 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/bal05/$contract" \
            --result-manifest "$folder/manifest.json" -- --out "$folder" "$@"
    fi
done
if [ "$mode" = headless ]; then
    printf 'BAL-05 NATIVE DRY RUN PASS — %s\n' "$captures"
fi
