#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=/private/tmp/labyrinth_codex/fx-29
stage=$(mktemp -d .godot/fx29-base.XXXXXX)
trap 'python3 -c "from pathlib import Path; import shutil; import sys; path = Path(sys.argv[1]); assert path.parent == Path(\".godot\") and path.name.startswith(\"fx29-base.\"); shutil.rmtree(path)" "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
python3 tools/fx29/stage.py "$stage"
base="res://$stage"

run_headless() {
    script=$1
    shift
    python3 tools/godot_task_runner.py --task-id fx-29 --stream -- godot \
        --headless --max-fps 60 --path . --script "$script" -- "$@"
}

case "${1:-}" in
    --verify)
        run_headless tools/fx29/verify.gd --base "$base"
        exit
        ;;
    --dry-run)
        run_headless tools/fx29/native.gd --dry-run --mode strip --base "$base" --out "$out/native/before"
        run_headless tools/fx29/native.gd --dry-run --mode strip --out "$out/native/after"
        run_headless tools/fx29/native.gd --dry-run --mode reel --out "$out/native/after/reel"
        exit
        ;;
esac

cat > "$stage/movie-clock.sh" <<'CLOCK'
#!/bin/sh
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${FX29_MOVIE_CLOCK:?}" "$@"
CLOCK
chmod +x "$stage/movie-clock.sh"
export FX29_MOVIE_CLOCK="$PWD/$stage/clock.avi"

capture() {
    mode=$1
    directory=$2
    contract=$3
    shift 3
    mkdir -p "$directory"
    python3 tools/visual_probe_runner.py tools/fx29/native.gd --task-id fx-29 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$PWD/$stage/movie-clock.sh" \
        --timeout 300 --proof-contract "$contract" --overwrite-result-manifest \
        --result-manifest "$directory/manifest.json" -- --mode "$mode" --out "$directory" "$@"
}

capture strip "$out/native/before" tools/fx29/native_proof.json --base "$base"
capture strip "$out/native/after" tools/fx29/native_proof.json
capture reel "$out/native/after/reel" tools/fx29/reel_proof.json
raw="$out/native/after/reel/frames.rgb"
clip="$out/native/refraction.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -frames:v 240 -an -c:v libx264 -pix_fmt yuv420p "$clip"
python3 -c 'from pathlib import Path; import sys; Path(sys.argv[1]).unlink()' "$raw"
printf 'Before strip: %s\nAfter strip: %s\nSilent MP4: %s\n' \
    "$out/native/before/strip.png" "$out/native/after/strip.png" "$clip"
