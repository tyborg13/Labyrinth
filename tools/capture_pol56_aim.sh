#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
branch_project="$PWD"
release_project="$(cd "${1:?Pass the detached f667a0126 project directory}" && pwd -P)"
expected_release="$(git rev-parse f667a0126^{commit})"
if [[ "$(git -C "$release_project" rev-parse HEAD)" != "$expected_release" ]]; then
    printf 'Expected release %s in %s\n' "$expected_release" "$release_project" >&2
    exit 1
fi

python3 tools/cel_look.py status --project "$release_project"
python3 tools/cel_look.py status --project "$branch_project"
output="$(mktemp -d /private/tmp/labyrinth_codex/pol-56-aim.XXXXXX)"
probe="$branch_project/tests/rotatable_card_aim_probe.gd"
contract="$branch_project/tests/rotatable_card_aim_probe_contract.json"

capture() {
    local phase="$1"
    local project="$2"
    LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
        --project "$project" --no-headless --display-driver macos --audio-driver Dummy \
        "$probe" --task-id pol-56 --expect-size 1920x1080 --proof-contract "$contract" \
        --result-manifest "$output/$phase.json" -- \
        "--proof-phase=$phase" "--proof-output=$output"
}

capture before "$release_project"
test -s "$output/camera_before.json"
capture after "$branch_project"
printf 'Capture pairs: %s\n' "$output"
