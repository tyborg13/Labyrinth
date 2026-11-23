#!/bin/sh
set -eu

# The validated visual runner invokes this branch from the project it renders.
if [ "${POL66_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-66 --stream -- godot "$@"
fi

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
proof_dir=$(cd "$(dirname "$launcher")" && pwd)
task_dir=$(cd "$proof_dir/../.." && pwd)
base_dir=$(cd "$task_dir/../scn-02" && pwd)
mode=${1:-}
case "$#:$mode" in
    0:|1:--dry-run) ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

output_root=/private/tmp/labyrinth_codex/pol-66
mkdir -p "$output_root"
output_dir=$(mktemp -d "$output_root/skills.XXXXXXXX")
echo "Output folder: $output_dir"
cd "$task_dir"

# Match the four-enemy Character Skills census fixture.
export LABYRINTH_CEL_LOOK=all
fixture_log="$output_dir/fixture.log"
LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id pol-66 --stream -- \
    godot --headless --path . --script tools/inspection_fixture.gd -- \
    --scenario combat --seed 7262026 --enemy-types crawler,acolyte,harrier,warden \
    --player-position 2:4 --enemy-positions 4:4,5:2,5:5,4:6 \
    --hand pale_spark,quick_stab,guarded_step,sidestep_slash > "$fixture_log" 2>&1 || {
        tail -40 "$fixture_log" >&2
        exit 1
    }
fixture_dir=$(python3 - "$fixture_log" <<'PY'
import json
import sys
from pathlib import Path

prefix = "INSPECTION_FIXTURE_RESULT "
results = [json.loads(line.removeprefix(prefix)) for line in Path(sys.argv[1]).read_text().splitlines()
           if line.startswith(prefix)]
if len(results) != 1 or not results[0]["ok"]:
    raise SystemExit("Expected a certified inspection fixture")
print(Path(results[0]["save_path"]).parent)
PY
)

capture() {
    revision=$1
    project=$2
    destination="$output_dir/$revision"
    log="$output_dir/$revision.log"
    mkdir "$destination"
    if [ "$mode" = --dry-run ]; then
        python3 tools/godot_task_runner.py --task-id pol-66 --stream -- \
            godot --headless --path "$project" --script "$proof_dir/capture.gd" -- \
            "$revision" "$destination" "$fixture_dir" > "$log" 2>&1 || {
                tail -40 "$log" >&2
                return 1
            }
    else
        POL66_WINDOWED_ENGINE=1 python3 tools/visual_probe_runner.py "$proof_dir/capture.gd" \
            --project "$project" --task-id pol-66 --no-headless --display-driver macos --audio-driver Dummy \
            --godot "$proof_dir/native.sh" --proof-contract "$proof_dir/proof_contract.json" \
            --result-manifest "$output_dir/$revision.json" -- \
            "$revision" "$destination" "$fixture_dir" > "$log" 2>&1 || {
                tail -40 "$log" >&2
                return 1
            }
    fi
    sed -n '/^POL66 GEOMETRY /p' "$log" > "$output_dir/$revision-geometry.txt"
    sed -n '/^POL66 D-PAD /p; /^POL66 .*: PASS /p; /^Validated /p' "$log"
}

capture before "$base_dir"
capture after "$task_dir"
diff -u "$output_dir/before-geometry.txt" "$output_dir/after-geometry.txt"
echo "POL66 GEOMETRY COMPARISON: PASS"
echo "Output folder: $output_dir"
