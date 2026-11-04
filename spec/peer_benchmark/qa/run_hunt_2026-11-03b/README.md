# qa-25 release-line whole-run hunt

Base `47b98da9b6df892650b105a37a378ad337cd1b2f`, branch `codex/qa-25`.
Evidence root: `/private/tmp/labyrinth_codex/qa-25/`.
The director supplied the worktree, contract and preflight and owns commits,
peer review, inspection and publication. This worker leaves changes uncommitted.

## Execution

The qa-23 launcher is retained with only this task's namespace and paths changed.
It imports `tools/run_hunt.py`, whose child runner otherwise hard-codes qa-18.
The unchanged production hunt, action policy, gameplay settings and watchdogs
remain authoritative. The sequential coordinator runs default, then no-embrace,
with fresh campaign seed base **2**, a 45-minute launch window and two processes
per campaign. It drains active seeds before proceeding, then runs the Python
default group. No full suite is requested or run.

Each seed retains `command.json`, `godot.log`, `trace.jsonl`, `summary.json` and
`evidence.json` under the evidence root. Campaign reports, findings and coverage
are retained beside this README after completion. See `execution-contract.json`
for acceptance criteria, provenance and bootstrap proof.

Restore task-local helpers from their exact retained sources before reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-03b/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-25')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

Use fresh, empty output directories for each execution:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --minutes 45 --processes 2 --seed 2 --output-dir /private/tmp/labyrinth_codex/qa-25/campaign-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --minutes 45 --processes 2 --seed 2 --no-embrace --output-dir /private/tmp/labyrinth_codex/qa-25/campaign-no-embrace
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-25/python-default
```

The read-only census driver extends qa-23's host/script census with descendant
counts for named pools, their existing production capacities, current tile
canvases, Grimoire rows and retained Character/pre-battle contents. It changes no
input, state, policy or limit. Its terminal combat snapshot permits independent
triage of exploration-budget outcomes. Census helpers are plain-text snapshots
so they do not enter Godot's resource inventory.

## Chosen defaults

- `TASK_ID = "qa-25"` and task-local diagnostic/report paths.
- `CAMPAIGN_SEED = 2`, `CAMPAIGN_MINUTES = 45`, `CAMPAIGN_PROCESSES = 2`: brief requirements.
- Health override, clock, sampling, viewport, settlement and watchdog defaults:
  inherited unchanged from the approved hunt and qa-23 coordinator.

No player-perceived value, asset, tuning, text, save schema or analytics field
is authored by this report. No art, icon, audio or font is generated or fetched.

## Capacity recovery

The model-capacity interruption stopped the original coordinator and both
in-flight runners after 882.534 seconds of trace activity. Runner PID existence
checks returned `ProcessLookupError`; terminal events and native exit statuses
were unavailable. Default seeds 2, 3, 4, 6 and 7 had completed and were retained.
Seeds 5 and 8 have preserved partial logs and are classified as infrastructure
interruptions, not product crashes.

`resume_campaigns.py` continues with unused seed 9 for the remaining
30.2911022981-minute launch budget, then starts the full fresh no-embrace
campaign with seed base 2 and runs the required Python default group. Its
inference uses the first command's timestamp and the last flushed trace's
mtime; the pause is excluded. Combined reports distinguish ended runs from
interrupted starts. Exact timing, paths and segment commands are retained in
`capacity-recovery.json` and execution metadata. No completed campaign or seed
is restarted. The original partial campaign metadata is retained under
`/private/tmp/labyrinth_codex/qa-25/interrupted-default-*`.

## Census reproduction and interpretation

The initial pair replays default seed 12 and no-embrace seed 2. Seed 2 stops
before section 5 at the fight budget. Supplemental seed 3 is interrupted by
ENOSPC; a fresh bounded seed-3 retry supplies the second comparison. Default
12 and seed 3 both reached section 5 in their campaigns. Use fresh output paths when reproducing:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --runs 1 --processes 1 --seed 12 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd --output-dir /private/tmp/labyrinth_codex/qa-25/replay-default-seed-12
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --runs 1 --processes 1 --seed 2 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd --output-dir /private/tmp/labyrinth_codex/qa-25/replay-no-embrace-seed-2 --no-embrace
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && python3 /private/tmp/labyrinth_codex/qa-25/collect_census.py
```

`node-census-triage.json` retains the first section-0 and section-5 samples,
production capacities and predicate results. The tree allowance is conservative:
`1.25 × section_0_tree + max(0, section_5_named_pool_nodes - section_0_named_pool_nodes)`.
Named descendants are unioned by instance ID, so overlapping owners count once.
They cover hand/pile/proxy entries, Grimoire rows, the current and prepared
Character views, its hidden-row and retained-skill-tree hosts, and pre-battle
contents. Current Character contents are included even when they occupy the
live dialog slot. Independent tree/orphan monitors and subtree/script deltas
remain visible; cached-view screen fit, Grimoire viewport height, card capacities,
current tile-canvas capacities and released pre-battle/hidden-row contents are
checked separately. The retained sources show every owner and formula.

These are seeded fuzz replays, not recorded-input playback: read-only census
work can affect the timing of sampled UI offers. Any replay divergence and
missing section-5 proof is reported rather than inferred from another seed.

`rig-coverage.json` summarizes the existing append-only analytics from ended
campaign runs. It separates resolved actions from restricted or unresolved
attempts for `storm_cantor` and `last_lamplighter`; capacity-interrupted profiles
are excluded from those counts. Analytics files are read without rewriting them.

## Proof for the design owner

This unit's hunt and census proof is headless. No windowed command or capture is
attempted in this sandbox, and the brief requests no `inspection_fixture.py`
command. Inspection and publication remain with the director. If native visual
inspection is desired, it is additional owner work; no renderer-capture success
is claimed by these node and error checks.

## Storage-incident census retry

The OS reported `ENOSPC` during the later diagnostics; no campaign or Python
result was affected. Preserved last-committed snapshots decode successfully.
Default 12's required census is earlier than the incident. The incomplete
seed-3 attempt has no retained native exit status and remains separate.

The bounded driver is a copy of the same read-only census driver with one
additional diagnostic exit after its first section-5 sample. It retains every
prior policy, setting and limit, and emits `census_complete` rather than claiming
a terminal gameplay outcome. Its parser check passes. Exact retry command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && python3 /private/tmp/labyrinth_codex/qa-25/run_storage_retry.py
```

`run_storage_retry.py` uses the existing task launcher, fresh output
`/private/tmp/labyrinth_codex/qa-25/replay-no-embrace-seed-3-storage-retry`, seed 3,
`--no-embrace`, one process and `run_hunt_census_bounded.gd`. The emitted
`command.json` and execution record retain the actual complete arguments.
As with all commands above, use fresh output paths for another reproduction.
