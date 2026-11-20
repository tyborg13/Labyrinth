#!/usr/bin/env bash
# Native proof entry points. Run from the perf-156 worktree.
set -eo pipefail

mode="${1:-}"
profile="${2:-normal}"
base="$PWD/output/perf-156/r1/release-project"
out="${PERF156_NATIVE_OUT:-$PWD/output/perf-156/r1/native-proof}"
archive="/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/perf_attribution/perf152_data"

usage() {
  printf '%s\n' 'Usage: bash tools/perf156/native.sh pixels | timing {normal,background} | tour {normal,background}'
}

case "$mode" in
  pixels|timing|tour) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
qos=()
case "$profile" in
  normal) ;;
  background) qos=(taskpolicy -c background) ;;
  *) usage >&2; exit 2 ;;
esac

test -f "$base/project.godot"
mkdir -p "$out"
cp tools/perf156/probe.gd "$base/tools/perf156/probe.gd"

capture() {
  local project="$1" demo="$2" script="$3" proof="$4" destination="$5"
  shift 5
  LABYRINTH_DEMO="$demo" LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
    --project "$project" --task-id perf-156 --no-headless --display-driver macos \
    --rendering-driver metal --audio-driver Dummy --timeout 300 --expect-size 1920x1080 \
    --proof-contract "$proof" --result-manifest "$destination.json" \
    "$script" -- --capture --output="$destination" "$@"
}

timing() {
  local project="$1" demo="$2" size="$3" script="$4" destination="$5"
  shift 5
  LABYRINTH_HITCH_TRACE=1 LABYRINTH_DEMO="$demo" LABYRINTH_CEL_LOOK=all \
    "${qos[@]}" python3 tools/godot_task_runner.py --project "$project" --task-id perf-156 \
    --timeout 480 --stream -- godot --path "$project" --windowed --resolution "$size" \
    --display-driver macos --rendering-driver metal --audio-driver Dummy --script "$script" \
    -- --output="$destination" "$@"
}

deck_project() {
  local source="$1" project="$2" entry
  mkdir "$project"
  for entry in assets addons data fonts scenes scripts shaders themes tools tests project.godot .godot cel_look_variants; do
    cp -cR "$source/$entry" "$project/$entry"
  done
  cat > "$project/override.cfg" <<'CFG'
[display]
window/size/mode=0
window/size/window_width_override=1280
window/size/window_height_override=800
window/dpi/allow_hidpi=false
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale=1.15
CFG
}

for side in base candidate; do
  source_project="$PWD"
  if [ "$side" = base ]; then source_project="$base"; fi
  case "$mode" in
    pixels)
      capture "$source_project" 1 res://tools/perf_142/new_run_probe.gd tools/perf156/start-proof.json "$out/$side-start-images" --require-release-idle
      capture "$source_project" 0 res://tools/perf156/probe.gd tools/perf156/proof.json "$out/$side-visit-images"
      ;;
    timing)
      timing "$source_project" 1 1920x1080 res://tools/perf_142/new_run_probe.gd "$out/$side-start-$profile" --require-release-idle
      timing "$source_project" 0 1920x1080 res://tools/perf156/probe.gd "$out/$side-visits-$profile"
      ;;
    tour)
      project="$out/$side-deck-$profile-project"
      deck_project "$source_project" "$project"
      LABYRINTH_PROBE_WINDOW=1 SteamDeck=1 timing "$project" 0 1280x800 res://tools/hitch_census/driver.gd "$out/$side-tour-$profile" --driver=tour --seed=83 --seconds=420
      ;;
  esac
done

case "$mode" in
  pixels)
    result=0
    python3 tools/perf156/report.py --pixels "$out/base-start-images" "$out/candidate-start-images" || result=1
    python3 tools/perf156/report.py --pixels "$out/base-visit-images" "$out/candidate-visit-images" || result=1
    exit "$result"
    ;;
  timing)
    python3 tools/perf156/report.py --audit "$archive/textures.csv.gz" --observations "$archive/measurements.json.gz" \
      --start "$out/base-start-$profile" "$out/candidate-start-$profile" \
      --visits "$out/base-visits-$profile" "$out/candidate-visits-$profile" \
      --output "$out/report-$profile" | tee "$out/$profile-tables.txt"
    ;;
  tour)
    python3 tools/perf156/report.py --tour "$out/base-tour-$profile" "$out/candidate-tour-$profile" \
      --output "$out/tour-report-$profile" | tee "$out/$profile-tour-tables.txt"
    ;;
esac
