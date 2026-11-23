#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

out=/private/tmp/labyrinth_codex/mrg-15
fnd_reference=/private/tmp/labyrinth_codex/fnd-03/plan/before
capture_timeout=300
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
unset LABYRINTH_GROUND_FX

case "${1:-}" in
    --dry-run) dry=true ;;
    "") dry=false ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

headless() {
    clock=$1
    script=$2
    shift 2
    python3 tools/godot_task_runner.py --task-id mrg-15 --stream -- godot \
        --headless "$clock" 60 --path . --script "$script" -- "$@"
}

if [ "$dry" = false ]; then
    command -v ffmpeg >/dev/null
    command -v ffprobe >/dev/null
    stage=$(mktemp -d .godot/mrg15-capture.XXXXXX)
    trap 'python3 -c "import shutil, sys; shutil.rmtree(sys.argv[1])" "$stage"' EXIT
    cat > "$stage/clock.sh" <<'CLOCK'
#!/bin/sh
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${MRG15_CLOCK_FILE:?}" "$@"
CLOCK
    chmod +x "$stage/clock.sh"
fi

capture() {
    script=$1
    contract=$2
    capture_dir=$3
    shift 3
    mkdir -p "$capture_dir"
    export MRG15_CLOCK_FILE="$capture_dir/clock.avi"
    python3 tools/visual_probe_runner.py "$script" --task-id mrg-15 --no-headless \
        --display-driver macos --audio-driver Dummy --godot "$PWD/$stage/clock.sh" \
        --timeout "$capture_timeout" --proof-contract "$contract" --overwrite-result-manifest \
        --result-manifest "$capture_dir/manifest.json" -- --out "$capture_dir" "$@"
}

silent_reel() {
    frames=$1
    raw=$2
    clip=$3
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i "$raw" -frames:v "$frames" -an -c:v libx264 -pix_fmt yuv420p "$clip"
    python3 -c 'import sys; from pathlib import Path; Path(sys.argv[1]).unlink()' "$raw"
}

mirror_capture() {
    unit=$1
    strip_contract=$2
    reel_frames=$3
    clip=$4
    directory="$out/native/$unit"
    printf '%s output: %s\n' "$unit" "$directory"
    if [ "$dry" = true ]; then
        headless --max-fps "tools/$unit/native.gd" --dry-run --mode strip --out "$directory"
        headless --max-fps "tools/$unit/native.gd" --dry-run --mode reel --out "$directory/reel"
    else
        capture "tools/$unit/native.gd" "tools/$unit/$strip_contract" "$directory" --mode strip
        capture "tools/$unit/native.gd" "tools/$unit/reel_proof.json" "$directory/reel" --mode reel
        silent_reel "$reel_frames" "$directory/reel/frames.rgb" "$directory/$clip"
    fi
}

mirror_capture gfix34 native_proof.json 180 mirror-return.mp4

directory="$out/native/fx23"
printf 'fx23 output: %s\n' "$directory"
if [ "$dry" = true ]; then
    headless --fixed-fps tools/mrg15/native_fx23_plan.gd --out "$out/native-plan/fx23"
else
    inventory=$(headless --fixed-fps tools/fx23/verify.gd --list-cases)
    set -- $(printf '%s\n' "$inventory" | sed -n 's/^FX-23 CASES: //p')
    test "$#" -gt 0
    for take in "$@"; do
        capture tools/fx23/native.gd tools/fx23/proof_contract.json "$directory/$take" --case "$take"
    done
    capture tools/fx23/native.gd tools/fx23/reel_contract.json "$directory/recording" --case recording
    silent_reel 240 "$directory/recording/frames.rgb" "$directory/fire-lightning.mp4"
fi

mirror_capture fx29 native_proof.json 240 refraction.mp4

directory="$out/native/fnd03"
printf 'fnd03 output: %s\n' "$directory"
takes="$directory"
if [ "$dry" = true ]; then takes="$out/native-plan/fnd03"; fi
for take in shop_card shop_gear event_relic event_card dragon; do
    before="$takes/before/$take"
    after="$takes/after/$take"
    mkdir -p "$before" "$after"
    cp "$fnd_reference/$take/take.json" "$before/take.json"
    if [ "$dry" = true ]; then
        headless --fixed-fps tools/fnd03/native_capture.gd --plan --case "$take" --out "$after" --after
    else
        capture tools/fnd03/native_capture.gd tools/fnd03/proof_contract.json "$after" --case "$take" --after
    fi
done
set --
if [ "$dry" = true ]; then set -- --plan; fi
python3 tools/fnd03/encode_reel.py "$takes" "$directory/acquisition-gains.mp4" "$@"
