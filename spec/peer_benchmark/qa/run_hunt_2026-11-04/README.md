# qa-43 whole-run hunt

Baseline: `8398f4680` on `codex/qa-43`, including the director's perf-32 and
perf-33 merges. The worker leaves all changes uncommitted; the design owner owns
commit, review, inspection and publication. Acceptance, protected inputs and
helper hashes are recorded in `execution-contract.json`.

Raw evidence lives in `/private/tmp/labyrinth_codex/qa-43/`. `proof-sources/`
retains exact text snapshots of the private helpers; `.txt` prevents Godot from
importing these report artifacts. Restore them before repeating a command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-04/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-43')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

The launcher imports unchanged `tools/run_hunt.py`, replacing only its inherited
`qa-18` runner namespace and replay command path with `qa-43`. Gameplay, policy,
health override, sampling, watchdogs and offer choices are unchanged. Each child
retains its actual argv in `command.json`. Each campaign uses fresh seed 3,
45 minutes of seed launching, two processes, and drains its children before the
next campaign begins. Repeating requires new empty output directories.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --minutes 45 --processes 2 --seed 3 --output-dir /private/tmp/labyrinth_codex/qa-43/campaign-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --minutes 45 --processes 2 --seed 3 --no-embrace --output-dir /private/tmp/labyrinth_codex/qa-43/campaign-no-embrace
```

`run_campaigns.py` coordinates those commands sequentially. After both campaigns,
`run_censuses.py` selects section-5 seeds and runs two read-only replay drivers
at most two at a time. It retains incomplete attempts and falls back to another
campaign seed when needed. The census retains qa-30's lifetime measurements and bounds, with task-local
names and paths. A read-only glossary geometry observer was added to triage the
reveal-time warnings. The bounded driver samples section 0 and stops at the first section-5 room.
When a selected campaign seed has a shutdown ObjectDB warning, the coordinator
uses `run_hunt_census_full.gd` and `run_hunt_task_verbose.py`: the same read-only
census continues to natural termination, adding only Godot `--verbose` output.
Its first section-0/5 comparison uses the same acceptance formula:
`late_tree <= 1.25 * initial_tree + max(0, late_named_pool_nodes - initial_named_pool_nodes)`.
Hand, pile, proxy, grimoire, character and pre-battle node identities are unioned
so overlapping owners are counted once; tile-canvas bounds are checked separately.
No additional allowance is introduced.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && python3 /private/tmp/labyrinth_codex/qa-43/run_censuses.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-43/python-default
```

The required Python default group is the 19-module product-pass inventory in
`tools/python_suite_groups.json`; no full Godot or Python discovery is requested.
Final coverage, findings and check results are in `result.md`.

## Chosen defaults

- `TASK_ID = "qa-43"`, the mandated task namespace; evidence and report paths above.
- `TRACE_TAIL_BYTES = 65536`, only the status helper's bounded read of recent
  diagnostic output. It cannot affect a running seed.
- All other hunt and census values are inherited unchanged or prescribed by the
  brief. No player-facing value is selected by this worker.

## Proof for the design owner

This brief requests headless campaigns, censuses and the Python default group.
No windowed proof or inspection-fixture command is required for a report-only
hunt. The worker has no window-server access and does not attempt windowed runs.
Any owned fix requiring native renderer proof will be called out in `result.md`.
