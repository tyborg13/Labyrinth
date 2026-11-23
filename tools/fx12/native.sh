#!/bin/sh
set -eu
ROOT=/Users/borgerding/workspace/Labyrinth.worktrees/fx-12
OUT=${FX12_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-12/native}
cd "$ROOT"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

capture() {
    take=$1
    shift
    dir="$OUT/$take"
    mkdir -p "$dir"
    export FX12_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx12/native_capture.gd --task-id fx-12 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx12/movie_clock.sh \
        --timeout 480 --proof-contract tools/fx12/proof_contract.json \
        --result-manifest "$dir/manifest.json" -- --case "$take" --out "$dir" "$@"
    rm -f "$FX12_CLOCK_FILE"
    if [ "$take" = "whirlwind_then_frost" ]; then
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
            -framerate 60 -i "$dir/frames.rgb" -frames:v 240 -c:v libx264 -pix_fmt yuv420p "$dir/whirlwind-then-frost.mp4"
        rm -f "$dir/frames.rgb"
    fi
}

if [ "$#" -gt 0 ]; then
    capture "$@"
    exit
fi
for take in whirlwind_slash spear_thrust sweeping_haft tombsplitter windlass_volley shrapnel_bomb \
    lantern_rain tremor frost_nova thunderclap grave_mortar cyclone_seal immolation rime_shard \
    squall_shot volt_surge cinder_bloom consumed_fire_burst terrain_burst illusion_burst \
    crushing_step glass_lunge lightning_storm_strike whirlwind_then_frost
do
    capture "$take"
done
