#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
OUT=/private/tmp/labyrinth_codex/fnd-02
BASE="$OUT/base"
CAPTURE="$ROOT/tools/fnd02/native_capture.gd"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
cd "$ROOT"

case "${1:-}" in
    --plan) kind=plan ;;
    "") kind=native ;;
    *) echo "Usage: $0 [--plan]" >&2; exit 1 ;;
esac

if [ ! -f "$BASE/.fnd02-base" ]; then
    mkdir -p "$BASE"
    git archive 3c27b676d | tar -xf - -C "$BASE"
    mkdir -p "$BASE/.godot"
    cp "$ROOT/.godot/global_script_class_cache.cfg" "$ROOT/.godot/uid_cache.bin" "$BASE/.godot/"
    printf '%s\n' 3c27b676d > "$BASE/.fnd02-base"
fi
if [ -L "$BASE/.godot/imported" ]; then
    rm "$BASE/.godot/imported"
fi
if [ ! -d "$BASE/.godot/imported" ]; then
    cp -pcR "$ROOT/.godot/imported" "$BASE/.godot/imported"
fi
test -f "$ROOT/cel_look_variants/manifest.json"
ln -sfn "$ROOT/cel_look_variants" "$BASE/cel_look_variants"

if [ "$kind" = native ]; then
    command -v ffmpeg >/dev/null
    command -v ffprobe >/dev/null
fi

capture() {
    version=$1
    project=$2
    take=$3
    shift 3
    dir="$OUT/$kind/$version/$take"
    mkdir -p "$dir"
    if [ "$kind" = plan ]; then
        python3 tools/godot_task_runner.py --task-id fnd-02 --stream -- godot --headless \
            --fixed-fps 60 --path "$project" --script "$CAPTURE" -- \
            --plan --case "$take" --out "$dir" "$@"
    else
        export FX12_CLOCK_FILE="$dir/clock.avi"
        python3 tools/visual_probe_runner.py "$CAPTURE" --task-id fnd-02 --project "$project" \
            --no-headless --display-driver macos --audio-driver Dummy --godot "$ROOT/tools/fx12/movie_clock.sh" \
            --timeout 120 --proof-contract "$ROOT/tools/fnd02/proof_contract.json" \
            --result-manifest "$dir/manifest.json" --overwrite-result-manifest -- \
            --case "$take" --out "$dir" "$@"
        if [ "$version" = before ]; then rm -f "$FX12_CLOCK_FILE"; fi
    fi
}

for take in venom storm; do
    capture before "$BASE" "$take"
    capture after "$ROOT" "$take" --after --clip
done

if [ "$kind" = plan ]; then
    set -- --plan
fi
python3 tools/fnd02/encode_clip.py "$OUT/$kind" "$OUT/native/relic-claims.mp4" "$@"
