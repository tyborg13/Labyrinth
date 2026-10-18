#!/usr/bin/env bash
# Exact rr-05 owner commands. Worker runs headless derivation and gates only.
set -euo pipefail

RR05_START_STAGE=derive
RR05_CREATURES=(shale_bloomer lightning_wisp)
while (( $# )); do
  case "$1" in
    --from-native) RR05_START_STAGE=native; shift ;;
    --from-adopt) RR05_START_STAGE=adopt; shift ;;
    --creature)
      if (( $# < 2 )); then echo '--creature requires shale_bloomer or lightning_wisp.' >&2; exit 2; fi
      case "$2" in
        shale_bloomer|lightning_wisp) RR05_CREATURES=("$2") ;;
        *) echo "Unknown creature: $2" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --help|-h)
      echo 'Usage: bash proof_for_design_owner.sh [--from-native|--from-adopt] [--creature shale_bloomer|lightning_wisp]'
      echo 'Default: both creatures; derive, native reviews, promote, density adopt, rebake, production captures.'
      echo '--from-native: skip derives and begin with native reviews.'
      echo '--from-adopt: resume density adoption after successful native review and promote.'
      echo '--creature: run only the selected creature at every creature-specific stage.'
      echo 'The shared shadow cache and density audit run once after the selected rebakes.'
      echo 'Playable inspection is run separately by the director.'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05
mkdir -p output/rr-05
python3 tools/output_gdignore.py

rr05_select() {
  RR05_CREATURE="$1"
  case "$RR05_CREATURE" in
    shale_bloomer) RR05_CASE=experiments/cutouts/shale_bloomer/mq3; RR05_PREFIX=shale; RR05_DENSITY=shale_bloomer_cutout; RR05_TYPE=bile_bloomer ;;
    lightning_wisp) RR05_CASE=experiments/cutouts/lightning_wisp/mq4; RR05_PREFIX=wisp; RR05_DENSITY=lightning_wisp; RR05_TYPE=lightning_wisp ;;
  esac
}

# Feedback 11 changes generated support textures: use the default/full pass
# (no --from-native) to derive, recapture native pixels and finish adoption.
# Director-supplied declarations, masks and painted-fill previews are protected.
if [[ "$RR05_START_STAGE" == derive ]]; then
  for creature in "${RR05_CREATURES[@]}"; do
    rr05_select "$creature"
    python3 tools/maquette_cutout_polish.py derive --case "$RR05_CASE" --output "output/rr-05/$RR05_PREFIX-derive.json"
  done
fi

# Blocking headless acceptance includes exposed derived dark slabs in every
# clip/view; approved painted-fill shadows report only (feedback 12). Seam tears, negative
# space and protrusion remain in pixel_gates.json as per-clip reports only.
# The director judges visible seams in both native MP4s.
if [[ "$RR05_START_STAGE" != adopt ]]; then
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/godot_task_runner.py --task-id rr-05 --stream -- godot --headless --path . --script tests/maquette_cutout/pixel_samples.gd -- --case "$RR05_CASE" --output "/Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/$RR05_PREFIX-headless-pixels.json"
  python3 tools/maquette_cutout_polish.py gate --case "$RR05_CASE" --samples "output/rr-05/$RR05_PREFIX-headless-pixels.json" --output "output/rr-05/$RR05_PREFIX-headless-gates.json"
done

# Native isolated parts and rigs: 60 Hz, 1920x1080 / 100%; verify before MP4.
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/maquette_cutout_review.py --task-id rr-05 --case "$RR05_CASE" --capture "output/rr-05/$RR05_PREFIX-native" --output "output/rr-05/${RR05_CREATURE}_review.mp4" --render
done

# Owner-only adoption requires the native reviews above, then a native rebake.
for creature in "${RR05_CREATURES[@]}"; do
  python3 tools/maquette_cutout_build.py promote --creature "$creature"
done
fi
python3 - "${RR05_CREATURES[@]}" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
from cutout_pipeline.cases import read_json, write_json
import process_board_density as density
from process_board_density import main
paths = []
registry = density.load_registry()
for creature in sys.argv[1:]:
    current = []
    for view in ('front', 'rear'):
        base = 'assets/units/' + creature + '_cutout/'
        current.extend(base + part['file'] for part in read_json(Path(base + view + '.json'))['parts'])
    entry = next(item for item in registry['entries'] if item.get('dir') == base.rstrip('/'))
    entry['paths'] = sorted(set(entry['paths']) | set(current))
    feature_file = Path(base) / 'features.json'
    if feature_file.is_file():
        for feature in read_json(feature_file)['features']:
            for declaration in feature['views'].values():
                mask = base + declaration['mask']
                if mask in entry['paths']:
                    raise ValueError('Feature constraint mask is also registered as painted art: ' + mask)
                registry['excluded_paths'][mask] = {
                    'category': 'never_drawn',
                    'reason': 'Protected feature constraint mask; reference data, never rendered or density treated.'}
    paths.extend(current)
write_json(density.REGISTRY, registry)
sys.argv = ['process_board_density.py', '--force-adopt', '--adopt', *sorted(set(paths))]
raise SystemExit(main())
PY
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/process_board_density.py --only "$RR05_DENSITY"
done
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only "$RR05_DENSITY"
done
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/process_board_density.py --only "$RR05_DENSITY" --record-rests
  python3 tools/maquette_cutout_build.py seal-density --creature "$creature"
done
# One shared resource: rebuild after the selected production rests are recorded.
python3 tools/godot_task_runner.py --task-id rr-05 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
python3 tools/process_board_density.py --check

# Actual resolver -> RunScene callbacks -> selected production capture.
for creature in "${RR05_CREATURES[@]}"; do
  rr05_select "$creature"
  python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "tests/maquette_cutout/${RR05_CREATURE}_production_contract.json" --result-manifest "output/rr-05/$RR05_PREFIX-production-result.json" tests/maquette_cutout/production_capture.gd -- --type "$RR05_TYPE" --output "/Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/$RR05_PREFIX-production"
  python3 tools/maquette_cutout_gates.py --case "$RR05_CASE" --production "output/rr-05/$RR05_PREFIX-production/frames.json" --output "output/rr-05/$RR05_PREFIX-production-gates.json"
done
# Playable inspection is deliberately separate from this proof/adoption pass.
