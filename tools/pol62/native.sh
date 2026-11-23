#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."
proof=${LABYRINTH_POL62_PROOF_ROOT:-/private/tmp/labyrinth_codex/pol-62}
mkdir -p "$proof"
line_cards=volt_surge,molten_reach,thunderline,rime_shard,shatterline,glacier_pin,windlass_volley,fan_of_knives,wind_shear,meteorfall,spark_focus,hoarfrost_shell,borrowed_spark,cinder_wall,frost_lane,lamp_oil,earthen_rampart

if [[ ${1:-} == --fixtures ]]; then
    shift
    proof_task=${2:-pol-62}
    python3 tools/inspection_fixture.py --task-id "$proof_task" --run-id "$proof_task-aim" \
        --manifest "$proof/aim.json" --scenario combat --seed 83 \
        --summary 'North-side line opening' --player-position 3:5 \
        --enemy-types crawler,crawler --enemy-positions 3:2,3:3 --hand "$line_cards"
    python3 tools/inspection_fixture.py --task-id "$proof_task" --run-id "$proof_task-crate" \
        --manifest "$proof/crate.json" --scenario combat --seed 84 \
        --summary 'Line aim tie and destructible previews' --player-position 5:5 \
        --enemy-types crawler,crawler,crawler,crawler --enemy-positions 3:6,4:6,6:5,6:6 \
        --terrain wooden_crate@5:6,wooden_box@3:4 --hand "$line_cards" \
        --attuned-magic rite_of_the_mountain,shattered_reflection,cinderweave_guard,lodestone_reversal \
        --equipped-items crimson_draught,crimson_draught
    exit
fi

mode=${1:-native}
shift || true
phases=("$@")
if [[ $# -eq 0 ]]; then phases=(after); fi
export LABYRINTH_CEL_LOOK=all
for phase in "${phases[@]}"; do
    args=(--after)
    if [[ $phase == before ]]; then
        printf 'Run the before probe at the original POL-62 revision.\n' >&2
        exit 2
    elif [[ $phase != after ]]; then
        printf 'Unknown phase %s\n' "$phase" >&2
        exit 2

    fi
    if [[ $mode == --dry-run ]]; then
        python3 tools/godot_task_runner.py --task-id pol-62 --stream -- godot --headless --path . \
            --script tools/pol62/capture.gd -- "${args[@]}"
    elif [[ $mode == native ]]; then
        python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
            --task-id pol-62 --expect-size 1920x1080 --timeout 120 --startup-timeout 20 \
            --proof-contract tools/pol62/proof_contract.json --result-manifest "$proof/$phase-manifest.json" \
            tools/pol62/capture.gd -- "${args[@]}"
    else
        printf 'Unknown mode %s\n' "$mode" >&2
        exit 2
    fi
done
