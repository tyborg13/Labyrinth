#!/bin/sh
# Candidate 5 captures use only the integrated production tree and live probes.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
out=${MRG16_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/mrg-16}
case "${1:-}" in
    --dry-run) mode=headless ;;
    "") mode=native ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$out" in
    /*) ;;
    *) printf 'MRG16_OUTPUT_ROOT must be absolute.\n' >&2; exit 2 ;;
esac
mkdir -p "$out"
captures=$(mktemp -d "$out/$mode.XXXXXX")
stage=$(mktemp -d "$root/.godot/mrg16-capture.XXXXXX")
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
native_timeout=300
reference_size=1920x1080
fps=60
printf '%s\n' "$captures"

headless() {
    project=$1
    script=$2
    shift 2
    python3 tools/godot_task_runner.py --task-id mrg-16 --stream -- godot \
        --headless --fixed-fps "$fps" --path "$project" --script "$script" -- "$@"
}

capture() {
    project=$1
    script=$2
    contract=$3
    folder=$4
    clock=$5
    shift 5
    mkdir -p "$folder"
    if [ "$clock" = fixed ]; then
        export FX15_CLOCK_FILE="$folder/clock.avi"
        set -- --godot "$root/tools/fx15/movie_clock.sh" -- "$@"
    else
        set -- --expect-size "$reference_size" -- "$@"
    fi
    python3 tools/visual_probe_runner.py "$script" --project "$project" --task-id mrg-16 \
        --no-headless --display-driver macos --audio-driver Dummy --timeout "$native_timeout" \
        --proof-contract "$contract" --result-manifest "$folder/manifest.json" "$@"
    if [ "$clock" = fixed ]; then
        rm -f "$FX15_CLOCK_FILE"
    fi
    printf '%s\n' "$folder"
}

for case_id in chain_bolt storm_relay capacitor; do
    folder="$captures/fx36/$case_id"
    if [ "$mode" = headless ]; then
        headless "$root" tools/fx36/native_capture.gd --plan --case "$case_id" --out "$folder"
    else
        capture "$root" tools/fx36/native_capture.gd tools/fx36/proof_contract.json "$folder" fixed \
            --case "$case_id" --out "$folder"
    fi
done

# The original Shadow probe verifies the source-atlas hashes. The after
# project uses the integrated tree and only omits the effect PNG sidecars.
python3 tools/fx35/stage.py "$stage"
for case_id in area_ranged closing_shade; do
    folder="$captures/fx35/after/$case_id"
    if [ "$mode" = headless ]; then
        headless "$stage/before" tools/fx35/native_capture.gd --plan --case "$case_id" --out "$captures/fx35/before/$case_id"
        headless "$stage/after" tools/fx35/native_capture.gd --plan --case "$case_id" --out "$folder"
    else
        capture "$stage/after" "$root/tools/fx35/native_capture.gd" "$root/tools/fx35/proof_contract.json" "$folder" fixed \
            --case "$case_id" --out "$folder"
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size "$reference_size" -framerate "$fps" \
            -i "$folder/frames.rgb" -an -c:v libx264 -pix_fmt yuv420p "$folder/clip.mp4"
        rm -f "$folder/frames.rgb"
    fi
done
if [ "$mode" = headless ]; then
    python3 tools/fx35/verify_takes.py "$captures/fx35"
fi

folder="$captures/fx34/conduction"
if [ "$mode" = headless ]; then
    MRG16_OUTPUT_ROOT="$captures" tools/mrg16/verify_fx34.sh --case spark
    headless "$root" tools/mrg16/gear_fade.gd --plan --out "$captures/gear-fade"
else
    capture "$root" tools/fx34/native_capture.gd tools/fx34/proof_contract.json "$folder" fixed --case spark --out "$folder"
    capture "$root" tools/mrg16/gear_fade.gd tools/mrg16/gear_fade_contract.json "$captures/gear-fade" fixed \
        --out "$captures/gear-fade"
fi

# Keep the original relic probe and image criteria, selecting the 1920x1080
# witnesses for this native contract. Its full layouts are checked separately.
python3 - "$stage" <<'PY'
import json
from pathlib import Path
import sys

stage = Path(sys.argv[1])
source = Path("tools/txt26/capture_relics.gd").read_text()
old = "[Vector2i(1920, 1080), Vector2i(1280, 800)]"
assert source.count(old) == 1
(stage / "relics.gd").write_text(source.replace(old, "[Vector2i(1920, 1080)]"))
for batch, proof in (("director", "after"), ("edited", "text_fit")):
    contract = json.loads(Path(f"tools/txt26/{proof}_proof.json").read_text())
    images = [image for image in contract["required_images"] if image["width"] == 1920]
    contract.update(min_images=len(images), expected_sizes=["1920x1080"], required_images=images)
    (stage / f"relics-{batch}.json").write_text(json.dumps(contract))
PY
export TXT26_PHASE=after
for batch in director edited; do
    export TXT26_BATCH="$batch" TXT26_OUTPUT="$captures/txt26/$batch"
    mkdir -p "$TXT26_OUTPUT"
    if [ "$mode" = headless ]; then
        TXT26_CAPTURE=0 headless "$root" "$stage/relics.gd"
    else
        TXT26_CAPTURE=1 capture "$root" "$stage/relics.gd" "$stage/relics-$batch.json" "$TXT26_OUTPUT" normal
    fi
done

for unit in txt27 txt28 txt30; do
    script="tools/$unit/capture.gd"
    folder="$captures/$unit"
    mkdir -p "$folder"
    case "$unit" in
        txt27) contract=proof-1920x1080.json; set -- "--output=$folder" ;;
        txt28) contract=after.contract.json; set -- after "$reference_size" "$folder" ;;
        txt30) contract=full.contract.json; set -- after "$reference_size" "$folder" ;;
    esac
    if [ "$mode" = headless ]; then
        if [ "$unit" = txt27 ]; then set -- "$@" --validate-only; fi
        headless "$root" "$script" "$@"
    else
        capture "$root" "$script" "tools/$unit/$contract" "$folder" normal "$@"
    fi
done
printf '%s\n' "$captures"
if [ "$mode" = headless ]; then printf '%s\n' 'MRG-16 NATIVE DRY RUN PASS'; fi
