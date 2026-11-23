#!/usr/bin/env bash
# Run from the ux-18 worktree. The baseline contains the release runtime files.
set -euo pipefail

project="$(pwd -P)"
output="/private/tmp/labyrinth_codex/ux-18"
baseline_commit="f92582e85f72107cc80abf8c72e3bc4677a93dd9"
baseline="$output/baseline-slim"
mode="${1:---windowed}"
export LABYRINTH_CEL_LOOK=all

case "$mode" in
  --headless|--windowed|--demo-check) ;;
  *) echo "Usage: $0 [--windowed|--headless|--demo-check]" >&2; exit 2 ;;
esac
test -f "$project/tools/ux18/proof.gd"
test -f "$project/cel_look_variants/manifest.json"
mkdir -p "$output"

if [[ "$mode" == --demo-check ]]; then
  LABYRINTH_DEMO=1 python3 "$project/tools/godot_task_runner.py" --task-id ux-18 --stream -- \
    godot --headless --path "$project" --script tools/ux18/proof.gd -- --output-dir "$output/demo-headless" --demo-check
  exit
fi

if [[ ! -e "$baseline" ]]; then
  snapshot="$(mktemp -d "$output/baseline.XXXXXX")"
  runtime_dirs=(scripts scenes data assets fonts themes shaders addons)
  git -C "$project" archive "$baseline_commit" -- "${runtime_dirs[@]}" project.godot | tar -xf - -C "$snapshot"
  # Reuse the warmed imports addressed by these release sidecars. Copy the
  # metadata Godot uses at runtime so this does not need an editor import.
  python3 - "$project" "$snapshot" "${runtime_dirs[@]}" <<'PY'
from pathlib import Path
import re
import shutil
import sys

project, snapshot = map(Path, sys.argv[1:3])
source_cache = project / ".godot"
target_cache = snapshot / ".godot"
(target_cache / "imported").mkdir(parents=True)
for name in (".gdignore", "extension_list.cfg", "global_script_class_cache.cfg", "uid_cache.bin"):
    shutil.copy2(source_cache / name, target_cache / name)

import_path = re.compile(r'"res://\.godot/imported/([^"/]+)"')
artifacts = set()
for directory in sys.argv[3:]:
    for sidecar in (snapshot / directory).rglob("*.import"):
        artifacts.update(import_path.findall(sidecar.read_text()))
for name in sorted(artifacts):
    source = source_cache / "imported" / name
    if not source.is_file():
        raise SystemExit(f"Missing warmed release import: {source}")
    shutil.copy2(source, target_cache / "imported" / name)
PY
  cp -cR "$project/cel_look_variants" "$snapshot/cel_look_variants"
  printf '%s\n' "$baseline_commit" > "$snapshot/.ux18-baseline"
  mv "$snapshot" "$baseline"
fi
test "$(cat "$baseline/.ux18-baseline")" = "$baseline_commit"
cmp "$project/cel_look_variants/manifest.json" "$baseline/cel_look_variants/manifest.json"
mkdir -p "$baseline/tools/ux18" "$output/fixtures"
cp "$project/tools/ux18/proof.gd" "$baseline/tools/ux18/proof.gd"

proof="$output/${mode#--}"
mkdir -p "$proof/before" "$proof/after"
for label in before after; do
  target="$project"
  args=(--output-dir "$proof/$label" --backdrop "$output/fixtures/run-backdrop.png")
  if [[ "$label" == before ]]; then
    target="$baseline"
    args+=(--baseline)
  else
    args+=(--baseline-images "$proof/before")
  fi
  if [[ "$mode" == --headless ]]; then
    python3 "$project/tools/godot_task_runner.py" --task-id ux-18 --project "$target" --stream -- \
      godot --headless --path "$target" --script tools/ux18/proof.gd -- "${args[@]}"
  else
    python3 "$project/tools/visual_probe_runner.py" --task-id ux-18 --project "$target" \
      --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --startup-timeout 25 \
      --expect-size 1920x1080 --proof-contract "$project/tools/ux18/$label.json" \
      --result-manifest "$proof/$label-renderer.json" --overwrite-result-manifest \
      tools/ux18/proof.gd -- "${args[@]}"
  fi
done
python3 "$project/tools/ux18/compare.py" "$proof"
