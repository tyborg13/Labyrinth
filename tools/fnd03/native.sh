#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
OUT=/private/tmp/labyrinth_codex/fnd-03
REV=c1beae85d9a08d3462e4c1cc94c598764b885e2e
BASE="$OUT/base"
CAPTURE="$ROOT/tools/fnd03/native_capture.gd"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
cd "$ROOT"

case "${1:-}" in
    --plan) kind=plan ;;
    "") kind=native ;;
    *) echo "Usage: $0 [--plan]" >&2; exit 1 ;;
esac

PREVIOUS="$ROOT/../fnd-02"
if [ "$kind" = plan ] && [ "$(git -C "$PREVIOUS" rev-parse HEAD 2>/dev/null)" = "$REV" ] &&
    git -C "$PREVIOUS" diff --quiet "$REV"; then
    BASE="$PREVIOUS"
else
    if [ ! -f "$BASE/.fnd03-base" ]; then
        mkdir -p "$BASE"
        git archive "$REV" | tar -xf - -C "$BASE"
        mkdir -p "$BASE/.godot"
        cp "$ROOT/.godot/global_script_class_cache.cfg" "$ROOT/.godot/uid_cache.bin" "$BASE/.godot/"
        cp -pcR "$ROOT/.godot/imported" "$BASE/.godot/imported"
        ln -sfn "$ROOT/cel_look_variants" "$BASE/cel_look_variants"
        printf '%s\n' "$REV" > "$BASE/.fnd03-base"
    fi
    test "$(cat "$BASE/.fnd03-base")" = "$REV"
fi
test -f "$BASE/cel_look_variants/manifest.json"

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
        python3 tools/godot_task_runner.py --task-id fnd-03 --stream -- godot --headless \
            --fixed-fps 60 --path "$project" --script "$CAPTURE" -- --plan --case "$take" --out "$dir" "$@"
    else
        images=2
        if [ "$version" = after ]; then images=4; fi
        export FX12_CLOCK_FILE="$dir/clock.avi"
        python3 tools/visual_probe_runner.py "$CAPTURE" --task-id fnd-03 --project "$project" \
            --no-headless --display-driver macos --audio-driver Dummy --godot "$ROOT/tools/fx12/movie_clock.sh" \
            --timeout 120 --min-images "$images" --proof-contract "$ROOT/tools/fnd03/proof_contract.json" \
            --result-manifest "$dir/manifest.json" --overwrite-result-manifest -- --case "$take" --out "$dir" "$@"
        if [ "$version" = before ]; then rm -f "$FX12_CLOCK_FILE"; fi
    fi
}

for take in shop_card shop_gear event_relic event_card dragon; do
    capture before "$BASE" "$take"
    capture after "$ROOT" "$take" --after
done

set --
if [ "$kind" = plan ]; then set -- --plan; fi
python3 tools/fnd03/encode_reel.py "$OUT/$kind" "$OUT/native/acquisition-gains.mp4" "$@"
