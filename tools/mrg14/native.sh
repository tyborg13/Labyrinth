#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${MRG14_CAPTURE_ROOT:-/private/tmp/labyrinth_codex/mrg-14/native}
unset LABYRINTH_GROUND_FX LABYRINTH_GRD03_FIXTURE_ATLASES
export LABYRINTH_CEL_LOOK=all
mkdir -p "$out"
clock=$(mktemp -d "$out/clock.XXXXXX")
trap 'rm -rf "$clock"' EXIT
export FX15_CLOCK_FILE="$clock/fx15.avi" FX19_CLOCK_FILE="$clock/fx19.avi" FX12_CLOCK_FILE="$clock/fnd01.avi"

capture() {
    case_id=$1
    script=$2
    contract=$3
    shift 3
    python3 tools/visual_probe_runner.py --task-id mrg-14 --no-headless \
        --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 \
        --proof-contract "tools/mrg14/proof_$contract.json" \
        --overwrite-result-manifest --result-manifest "$out/$case_id/manifest.json" "$script" "$@"
}
for case_id in ground sky dragon blink reward grimoire controls; do
    mkdir -p "$out/$case_id"
done
capture ground tools/mrg14/ground_still.gd ground -- "$out/ground"
capture sky tools/mrg14/sky_still.gd sky --godot tools/fx15/movie_clock.sh -- --case skybreak --out "$out/sky"
capture dragon tools/mrg14/dragon_still.gd dragon --godot tools/fx15/movie_clock.sh -- --case cinder_breath --out "$out/dragon"
capture blink tools/mrg14/blink_still.gd blink --godot tools/fx19/movie_clock.sh -- --case hero3 --out "$out/blink"
capture reward tools/mrg14/acquisition_still.gd reward --godot tools/fx12/movie_clock.sh -- --case common --out "$out/reward" --after
capture grimoire tools/mrg14/grimoire_still.gd grimoire -- --output-dir "$out/grimoire"
capture controls tools/mrg14/controls_still.gd controls -- --output-dir "$out/controls"
