#!/bin/sh
# Headless production-only smoke with the installed, unmodified release template.
set -eu
rr10_project="$(pwd)"
rr10_pack="$rr10_project/experiments/cutouts/hoarfrost_seer/rr10/proof/production_pack"
mkdir -p "$rr10_pack/empty_project"
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/pack.gd -- "$rr10_pack/rr10.pck"
python3 - "$rr10_pack" <<'PY'
from pathlib import Path
import shutil
import sys
import zipfile
EXPORT_EXECUTABLE_MODE = 0o755
root=Path(sys.argv[1])
template=Path.home()/'Library/Application Support/Godot/export_templates/4.6.1.stable/macos.zip'
with zipfile.ZipFile(template) as archive:
    (root/'godot').write_bytes(archive.read('macos_template.app/Contents/MacOS/godot_macos_release.universal'))
(root/'godot').chmod(EXPORT_EXECUTABLE_MODE)
# The unmodified template disallows path overrides; use its adjacent auto-pack.
shutil.copyfile(root/'rr10.pck',root/'godot.pck')
PY
python3 tools/godot_task_runner.py --task-id rr-10 --project "$rr10_pack/empty_project" --stream -- "$rr10_pack/godot" --headless
