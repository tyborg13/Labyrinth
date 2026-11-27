#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
export FEL01_FIXTURES="${FEL01_FIXTURES:-$tool_dir/fixtures}"
capture_timeout=180
dry_run=0
sample_count=3
unset FEL01_SAMPLES
for option in "$@"; do
    case "$option" in
        --dry-run) dry_run=1 ;;
        --samples)
            export FEL01_FIXTURES="$tool_dir/samples"
            export FEL01_SAMPLES=1
            ;;
        *) echo "Usage: $0 [--dry-run] [--samples]" >&2; exit 2 ;;
    esac
done

if [[ "$dry_run" == 1 ]]; then
    export FEL01_DRY_RUN=1
    exec python3 tools/godot_task_runner.py --task-id fel-01 --timeout "$capture_timeout" \
        --stream -- godot --headless --path . --script tools/fel01/resume_probe.gd
fi

unset FEL01_DRY_RUN FEL01_FIXTURE
mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
FEL01_CAPTURE_DIR="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
export FEL01_CAPTURE_DIR
manifest="$FEL01_CAPTURE_DIR/visual-proof.json"
contract="$tool_dir/proof_contract.json"
if [[ "${FEL01_SAMPLES:-0}" == 1 ]]; then
    sample_contract="$FEL01_CAPTURE_DIR/proof_contract.json"
    python3 - "$contract" "$sample_contract" "$sample_count" <<'PY'
import json
import sys
from pathlib import Path

source, destination, count = sys.argv[1:]
contract = json.loads(Path(source).read_text())
contract["min_images"] = len(contract["required_images"]) * int(count)
for requirement in contract["required_images"]:
    requirement["min_count"] = int(count)
Path(destination).write_text(json.dumps(contract, indent=2) + "\n")
PY
    contract="$sample_contract"
fi

python3 tools/visual_probe_runner.py --task-id fel-01 --no-headless \
    --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
    --expect-size 1920x1080 --proof-contract "$contract" \
    --result-manifest "$manifest" tools/fel01/resume_probe.gd 2>&1 | tee "$FEL01_CAPTURE_DIR/runner.log"
python3 - "$manifest" <<'PY'
import json
import sys
from pathlib import Path

for image in json.loads(Path(sys.argv[1]).read_text())["images"]:
    print(image["path"])
PY
