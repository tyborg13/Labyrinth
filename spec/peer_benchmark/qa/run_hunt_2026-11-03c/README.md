# qa-30 release-line whole-run hunt

Base: `8e104c938`, including the director's win-02 and qa-29 merges. The owner
supplied `codex/qa-30`, its task contract and preflight. The worker leaves every
change uncommitted; commits, peer review, inspection and publication stay with
the owner. No other worktree or queue is modified.

Raw evidence: `/private/tmp/labyrinth_codex/qa-30/`. See `result.md` for observed
results, coverage, dispositions, checks, defaults and remaining issues.

`tools/run_hunt.py` still hard-codes task `qa-18`. The retained private launcher
changes only child runner namespace and generated replay paths to `qa-30`.
The two campaigns use the unchanged hunt and policy, seed base 2, a 45-minute
launch window each and two processes. Children drain before the next campaign.
The read-only census adds current lifetime-owner counts and stops after its
first section-5 sample; no input, RNG, combat or persistence policy is changed.
All diagnostic sources are retained as `.txt` to avoid Godot import inventory.

Restore private helpers before replaying commands in this report:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-03c/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-30')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

Fresh campaign commands (use unused output directories when repeating):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --minutes 45 --processes 2 --seed 2 --output-dir /private/tmp/labyrinth_codex/qa-30/campaign-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --minutes 45 --processes 2 --seed 2 --no-embrace --output-dir /private/tmp/labyrinth_codex/qa-30/campaign-no-embrace
```

The sequential `run_campaigns.py` executes both campaigns, then `run_censuses.py`
and the Python default group. It records each execution status and duration.
`census-executions.json` retains exact per-attempt commands; `command.json` in
each profile records the actual Godot runner argv. Census comparisons use
`section_5_tree <= 1.25 * section_0_tree + max(0, named_pool_node_delta)`, the
same stricter pool-delta interpretation used in qa-25. Tree/orphan counts and
all individual lifetime-bound checks are retained, including failed attempts.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-30/python-default
```

No full Python or Godot suite is requested. Any required native renderer proof
is listed in `result.md`; this worker has no window-server access and does not
attempt windowed runs. The brief requests no `inspection_fixture.py` invocation.

## Owned fix and native proof for the design owner

The original default-5 census fails the inherited pool-delta gate. Its exact
2,326-input replay attributes 292 additional nodes to the hidden Scavenger shop
(97 cold, 389 late). `ScavengerShopView` now retires closed stock, pack and detail
controls after its existing deferred close, invalidates their render signatures,
and retains logical selection/page/filter/entry/receipt state. Active hidden
travel preparation and temporary dismiss/configure/present refreshes keep their
contents. Standalone `present()` rebuilds released contents before showing them.
No authored appearance, text, tuning or animation duration changes.

`tests/scavenger_shop_probe.gd --closed-shop-only` is the additive failing-first
regression and the native close/reopen fixture. Both motion modes run at the
existing 1920×1080 / 100% scale. The existing interaction probe also passes
headlessly, including purchasing, selling, controller focus and leaving.

The worker has no window-server access. These exact commands are prepared for
the owner; neither was attempted. Each manifest records absolute capture paths
under its runner-isolated `user://scavenger_shop_probe/` directory.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && python3 tools/visual_probe_runner.py --task-id qa-30 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-03c/shop-lifetime-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-30/native-shop-lifetime.json tests/scavenger_shop_probe.gd -- --closed-shop-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && python3 tools/visual_probe_runner.py --task-id qa-30 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-03c/shop-interaction-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-30/native-shop-interaction.json tests/scavenger_shop_probe.gd
```

Lifetime captures: `{normal,reduced}_{before_close,reopened,after_cancel_reopen}.png`.
The interaction contract requires the existing `normal.png`, `controller_focus.png`,
`post_purchase.png`, `post_sale.png`, `reduced_motion.png` and
`board_after_leave.png`. Existing shop-recovery region checks are reused.
Fresh native inspection/judging and any inspection fixture remain with the owner;
this brief requests no worker `inspection_fixture.py` invocation. No peer review
or sign-off request is performed by the worker.

`run_fixed_replays.py` keeps fixed default-5/control-3 censuses separate from the
original failed comparison, then runs the final Python default group. It binds
both edited source files by SHA-256 and checks that they remained unchanged
through verification. `implementation.patch` is the uncommitted implementation,
not a staged or committed change.
