#!/usr/bin/env bash
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
project=$PWD
proof=/private/tmp/labyrinth_codex/art-08
base_ref=3c27b676d
base="$project/.godot/art08-base-$base_ref"
probe=tools/art08/verify.gd
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

if [[ $# -gt 1 || ( $# -eq 1 && $1 != --dry-run ) ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

if [[ ! -f "$base/.art08-base" ]]; then
    mkdir -p "$base"
    git archive "$base_ref" | tar -x -C "$base"
    mkdir -p "$base/.godot"
    ln -sfn "$project/.godot/imported" "$base/.godot/imported"
    cp .godot/global_script_class_cache.cfg .godot/uid_cache.bin "$base/.godot/"
    ln -sfn "$project/cel_look_variants" "$base/cel_look_variants"
    printf '%s\n' "$base_ref" > "$base/.art08-base"
fi
git show "$base_ref:scripts/enemy_mechanics/burrow_view.gd" | cmp -s - "$base/scripts/enemy_mechanics/burrow_view.gd"
mkdir -p "$base/tools/art08"
cp tools/art08/fight.gd "$probe" "$base/tools/art08/"

if [[ ${1:-} == --dry-run ]]; then
    out="$proof/dry-run"
    python3 tools/godot_task_runner.py --task-id art-08 --stream -- godot         --headless --path "$base" --script "$base/$probe" -- --dry-run --before --out "$out/before"
    python3 tools/godot_task_runner.py --task-id art-08 --stream -- godot         --headless --path "$project" --script "$probe" -- --dry-run --out "$out/after"
    python3 tools/art08/compare.py "$out/before/frames.json" "$out/after/frames.json"
    python3 tools/godot_task_runner.py --task-id art-08 --stream -- godot         --headless --max-fps 60 --path "$project" --script "$probe" -- --dry-run --reel --out "$out/reel"
    printf 'Native stills planned in %s/{before,after}\nNative reel planned at %s/burrow-erupt.mp4\n' "$proof/native" "$proof/native"
    exit
fi

python3 tools/cel_look.py build --if-stale
out="$proof/native"

capture() {
    local capture_project=$1 capture_path=$2 contract=$3
    shift 3
    mkdir -p "$capture_path"
    python3 tools/visual_probe_runner.py --project "$capture_project" --task-id art-08         --no-headless --display-driver macos --audio-driver Dummy --timeout 180         --proof-contract "$project/tools/art08/$contract"         --result-manifest "$capture_path/manifest.json" --overwrite-result-manifest         "$capture_project/$probe" -- --out "$capture_path" "$@"
}

capture "$base" "$out/before" proof_contract.json --before
capture "$project" "$out/after" proof_contract.json
python3 tools/art08/compare.py "$out/before/frames.json" "$out/after/frames.json"

# MovieWriter supplies fixed frame time and game audio. Video pixels come from
# the exact-size SubViewport. The small AVI window is only an audio/clock sink.
reel="$out/reel"
mkdir -p "$reel"
wrapper="$reel/movie-clock.sh"
cat > "$wrapper" <<'CLOCK'
#!/bin/sh
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${ART08_MOVIE:?}" "$@"
CLOCK
chmod +x "$wrapper"
export ART08_MOVIE="$reel/clock.avi"
python3 tools/visual_probe_runner.py --project "$project" --task-id art-08     --no-headless --display-driver macos --audio-driver Dummy --godot "$wrapper" --timeout 360     --proof-contract "$project/tools/art08/reel_contract.json"     --result-manifest "$reel/manifest.json" --overwrite-result-manifest     "$project/$probe" -- --reel --out "$reel"

ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080     -framerate 60 -i "$reel/frames.rgb" -sseof -6 -i "$ART08_MOVIE"     -map 0:v:0 -map 1:a:0 -frames:v 360 -t 6 -c:v libx264 -pix_fmt yuv420p -c:a aac     "$out/burrow-erupt.mp4"
printf 'Native stills: %s/{before,after}\nNative reel: %s/burrow-erupt.mp4\n' "$out" "$out"
