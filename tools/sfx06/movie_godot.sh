#!/bin/bash
# The visual runner owns the GUI lease, isolation and PNG validation.
set -euo pipefail
output=output/sfx/sfx-06
fps=30
clip_seconds=4
audio_rate=48000
size=1920x1080
mkdir -p "$output"
log=$(mktemp "$output/movie.XXXXXX")
trap 'rm -f "$log"' EXIT
godot --write-movie "$output/wisp-native.avi" --fixed-fps "$fps" --windowed --resolution "$size" "$@" 2>&1 | tee "$log"
start=$(sed -n 's/^SFX06_SAFE_START_FRAME=//p' "$log")
test -n "$start"
end=$((start + fps * clip_seconds))
samples_per_frame=$((audio_rate / fps))

# Keep the native frame interval and the matching range of mixed PCM.
ffmpeg -y -v error -i "$output/wisp-native.avi" \
    -vf "trim=start_frame=$start:end_frame=$end,setpts=PTS-STARTPTS" \
    -af "atrim=start_sample=$((start * samples_per_frame)):end_sample=$((end * samples_per_frame)),asetpts=PTS-STARTPTS" \
    -map 0:v:0 -map 0:a:0 -c:v ffv1 -c:a pcm_s16le "$output/wisp-attack-4s.mkv"
ffprobe -v error -count_frames \
    -show_entries stream=codec_type,width,height,sample_rate,nb_read_frames:format=duration \
    -of json "$output/wisp-attack-4s.mkv"
