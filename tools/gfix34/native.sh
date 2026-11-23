#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=/private/tmp/labyrinth_codex/gfix-34
stage=$(mktemp -d .godot/gfix34-base.XXXXXX)
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
python3 tools/gfix34/stage.py "$stage"
base="res://$stage"
mkdir -p "$out"

if [ "${1:-}" = --dry-run ]; then
    python3 tools/godot_task_runner.py --task-id gfix-34 --stream -- godot \
        --headless --max-fps 60 --path . --script tools/gfix34/verify.gd -- --base "$base"
    for revision in before after; do
        base_arg=""
        if [ "$revision" = before ]; then base_arg="$base"; fi
        python3 tools/godot_task_runner.py --task-id gfix-34 --stream -- godot \
            --headless --max-fps 60 --path . --script tools/gfix34/native.gd -- \
            --dry-run --mode strip --base "$base_arg" --out "$out/native/$revision"
    done
    python3 tools/godot_task_runner.py --task-id gfix-34 --stream -- godot \
        --headless --max-fps 60 --path . --script tools/gfix34/native.gd -- \
        --dry-run --mode reel --out "$out/native/after/reel"
    printf 'Strips: %s\nSilent MP4: %s\n' "$out/native/{before,after}/strip.png" "$out/native/mirror-return.mp4"
    exit
fi

cat > "$stage/movie-clock.sh" <<'CLOCK'
#!/bin/sh
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${GFIX34_MOVIE_CLOCK:?}" "$@"
CLOCK
chmod +x "$stage/movie-clock.sh"
export GFIX34_MOVIE_CLOCK="$PWD/$stage/clock.avi"

capture() {
    mode=$1
    directory=$2
    contract=$3
    shift 3
    mkdir -p "$directory"
    python3 tools/visual_probe_runner.py tools/gfix34/native.gd --task-id gfix-34 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$PWD/$stage/movie-clock.sh" \
        --timeout 300 --proof-contract "$contract" --overwrite-result-manifest \
        --result-manifest "$directory/manifest.json" -- --mode "$mode" --out "$directory" "$@"
}

capture strip "$out/native/before" tools/gfix34/native_proof.json --base "$base"
capture strip "$out/native/after" tools/gfix34/native_proof.json
capture reel "$out/native/after/reel" tools/gfix34/reel_proof.json
raw="$out/native/after/reel/frames.rgb"
clip="$out/native/mirror-return.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -frames:v 180 -an -c:v libx264 -pix_fmt yuv420p "$clip"
rm "$raw"
printf 'Before strip: %s\nAfter strip: %s\nSilent MP4: %s\n' \
    "$out/native/before/strip.png" "$out/native/after/strip.png" "$clip"
