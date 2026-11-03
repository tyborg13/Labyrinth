# qa-23 release-candidate whole-run hunt

Base: `65b9d0d43636c1d5bd72944c38518c5a8540e5cb`, branch `codex/qa-23`.
Evidence root: `/private/tmp/labyrinth_codex/qa-23/`.

The owner supplied the worktree and task contract. All implementation is left
uncommitted; the owner performs commits, peer review, inspection and publication.
Humanoid rig data, `scripts/maquette_cutout_runtime/*`, the turn-start HUD and
qa-22's tests are excluded from fixes.

The unchanged `tools/run_hunt.py` still hard-codes runner task `qa-18`.
The retained private launcher `run_hunt_task.py` imports it and overrides only
the child task namespace to `qa-23` and generated replay command paths. It does
not change the Godot hunt, offer policy, settings, inputs or detection thresholds.
Every seed retains its actual child argv in `command.json`; the launcher digest
and acceptance contract are in `execution-contract.json`.

The sequential coordinator `run_campaigns.py` starts the two campaigns, drains
the first before starting the second, then runs the Python default group.
Worker execution remains headless. No full suite is run. A native renderer proof
for the supplemental polygon fix is prepared for the design owner below.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --minutes 45 --processes 2 --output-dir /private/tmp/labyrinth_codex/qa-23/campaign-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --minutes 45 --processes 2 --no-embrace --output-dir /private/tmp/labyrinth_codex/qa-23/campaign-no-embrace
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-23/python-default
```

Completed coverage, triage and exact check results are in `result.md`. Raw logs
remain in the evidence root; rebuilt campaign reports and findings are retained
here. The report distinguishes the fixed renderer error from the protected
contact-runtime error and from non-bug exploration/growth flags.

## Chosen defaults

- `CAMPAIGN_SEED = 1`: the existing coordinator default, independently fresh per campaign.
- `TASK_ID = "qa-23"`: this unit's required runner namespace.
- Evidence and report paths above: task-local diagnostic storage only.
- All gameplay, Health override, sampling, viewport, speed and watchdog defaults
  are inherited unchanged from the approved hunt.

## Proof for the design owner

The campaigns and worker checks are headless. The new renderer finding also
has a native proof command and contract below, to be run by the design owner.
Inspection-fixture preparation remains with that owner. No art, icon, font or
audio asset is created.

## Retained proof sources

`proof-sources/` stores exact plain-text snapshots of the private launcher,
read-only census driver, payload diagnostic, campaign coordinator and replay
coordinator. The `.txt` suffix keeps these report artifacts out of Godot's script
inventory. Restore the scratch helpers if needed before using the exact recorded
commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-03/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-23')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

The census driver only reads subtree/script counts, pool sizes and the terminal
combat state; it does not change the decision policy or gameplay. The payload
diagnostic uses named test-only positions `(2, 2)` / `(6, 6)` and actor ID `1` to
inspect an effectless Ambush strike. These are additional chosen defaults for
proof only; the player never sees the fixture.

## Polygon-renderer verification

A supplemental replay found a native polygon triangulation error in the shared
world-art rectangle path. A headless regression now lives in the existing
`tests/combat_art_treatment_probe.gd`; its windowed path retains the existing
pixel comparisons for UV regions, atlas margins, tint, alpha and Umbra clipping.
The qa-22 protected-file list was requested but was unavailable in this worktree
or shared task metadata. The directly related art-treatment probe was selected
as the narrow regression-file scope assumption; existing assertions are retained.

The design owner must run the native proof after the final patch. This worker
has no window-server access and does not attempt or retry this command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && python3 tools/visual_probe_runner.py --task-id qa-23 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-03/polygon-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-23/polygon-native-proof.json tests/combat_art_treatment_probe.gd
```

The existing probe explicitly sets `ui_scale = 1.0` and captures all eight
1920×1080 views under its isolated `user://pillar_torch_lighting_probe` directory.
The result manifest records their exact absolute paths. Use a fresh manifest
path on subsequent invocations. No inspection-fixture command is requested by
this unit's brief; the owner retains inspection-fixture preparation.

The supplemental `confirm_polygon.py` source snapshot is a historical diagnostic
that expects the unfixed baseline and refuses to overwrite a changed product
file. Ordinary fixed-tree reproduction uses `run_hunt_task.py`; the final
headless regression uses `program_suite_runner.py` as listed in `result.md`.
