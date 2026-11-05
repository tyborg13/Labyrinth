# qa-53 session memory

The director supplied `codex/qa-53`, the task contract and preflight. This worker
leaves changes uncommitted. Commit, peer review, inspection fixture and publication
remain with the director. No player-facing design, asset or number is authored.
The perf-54 load path, qa-51 focus changes and named intentional caches are protected.

Evidence and runnable tools: `/private/tmp/labyrinth_codex/qa-53/`.
Restore task-local diagnostic scripts from their `.txt` snapshots:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 - <<'PY_RESTORE'
from pathlib import Path
exec(Path('spec/peer_benchmark/qa/session_memory_2026-11-05/proof-sources/restore_tools.py.txt').read_text())
PY_RESTORE
```

The bridge uses the installed macOS debug Godot's exported `ObjectDB::debug_objects`,
`Object::get_class_name` and `RefCounted::get_reference_count`. It checks each symbol
and writes only IDs, native class names and reference counts; it creates no Godot
objects and holds no object references. It is task-local, compiled with the existing
system `clang++`, and is never added to the game or export. Counts cover native
classes omitted from the script API too. The census takes monitor values **before**
allocating diagnostic reports. Its native class enumeration includes two transient
bridge objects, independently checked against the pre-census monitor. Detailed
script inspection is restricted to game-owned families: taking a first script
reference to certain engine-owned RefCounteds can destroy them on release.
The raw ID/class/refcount files remain authoritative when metadata is absent.

This follows Godot's own [snapshot collector](https://github.com/godotengine/godot/blob/4.6/modules/objectdb_profiler/snapshot_collector.cpp)
and [GDExtension interface](https://github.com/godotengine/godot/blob/4.4/core/extension/gdextension_interface.h).
The built-in profiler's remote-debug transport requires a localhost listener,
which this sandbox rejected with `PermissionError(1, 'Operation not permitted')`.
No socket permission workaround is attempted.

## Headless reproduction

Every launch needs a fresh output label; existing evidence is never overwritten.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 tools/godot_task_runner.py --task-id qa-53 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-53/tools/census_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 /private/tmp/labyrinth_codex/qa-53/tools/run_session.py before-owner
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 /private/tmp/labyrinth_codex/qa-53/tools/summarize_session.py /private/tmp/labyrinth_codex/qa-53/before-owner
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 /private/tmp/labyrinth_codex/qa-53/tools/run_session.py after-owner
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 /private/tmp/labyrinth_codex/qa-53/tools/summarize_session.py /private/tmp/labyrinth_codex/qa-53/after-owner --compare /private/tmp/labyrinth_codex/qa-53/before-owner
```

The driver inherits qa-45's whole-run policy and qa-46's exact orphan-cache
ownership census. It enters through the real title menu's Start button; each end
returns through the production recap's Back to Menu action. The profile, settings,
recent events and append-only analytics stay in the same namespace for all five
runs. It samples initial menu and all ten run-end/menu boundaries. Menus settle
until the production departed-run drain disappears. No engine or state fixture is
installed. One inherited diagnostic HP override allows the first run to attempt
all six dragons; four runs use production HP. Coverage fails unless there are five
actual end screens, a death and a section-5 victory. A fight budget or softlock is
retained as failure, never substituted for a completed run.

`session.json` contains all monitors, top 20 classes, complete class/script counts,
orphan ownership and boundary integrity hashes. `*-objects.json` and `*-ids.txt`
retain per-instance identity. `trace.jsonl` retains real decisions plus committed
state and policy RNG hashes. `growth.json` lists increasing menu classes, surviving
IDs and script references; its `NEEDS_ROOT_CAUSE_REVIEW` is deliberately not an
automated leak verdict. `engine.log` includes verbose exit warnings. The comparison
keeps every strict mismatch; only documented transport IDs/timestamps are normalized.
Headless GPU monitor zeros are unavailable measurements, not a GPU plateau claim.

## Proof for the design owner

The worker has no macOS window-server access. No windowed command is attempted.
After restore/bootstrap, run the same session under a real renderer at 1920x1080,
100% UI scale. Inspect the eleven captures and paired ObjectDB reports:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 tools/visual_probe_runner.py --task-id qa-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 7200 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/session_memory_2026-11-05/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-53/native-proof.json /private/tmp/labyrinth_codex/qa-53/tools/session_memory.gd -- --output-dir /private/tmp/labyrinth_codex/qa-53/native-owner --stop-after 0
```

Expected captures: `native-owner/initial-menu.png`, `run-1-end.png`,
`run-1-menu.png`, through `run-5-end.png`, `run-5-menu.png`. The image contract
checks geometry/nonblank content; it does not replace semantic inspection.
No inspection-fixture command was requested by the brief; the director owns it.

## Chosen defaults

- Diagnostic seeds `[4,4,4,4,4]`, victory attempt index `0`: reuse qa-45's known
  six-section seed, then repeat identical seeded generation across a live profile.
- Existing hunt defaults: diagnostic victory HP `9999`, time scale `8`, `120` FPS,
  eight settling frames and unchanged policy/watchdogs. Other runs use ordinary HP.
- No-Embrace policy for all runs, and omit the separate save/resume side workload:
  this exercise targets actual death/victory and title-menu New Run lifetimes.
- Title settle `120` frames plus completion of departed-run cleanup; transition
  deadline `180` seconds; session runner timeout `7200` seconds (five whole runs).
- 1920x1080 logical/native geometry and UI scale `1.0`, as required.
- Object-reference metadata recursion depth `8`; full class/ID counts are uncapped.
- Native startup timeout `60` seconds; blank-image rejection luma range `8`,
  standard deviation `2`, inherited from qa-45's proof contract.
- Task-local names/paths, transport-ID normalization and macOS diagnostic bridge.

No TODO_DESIGN fields are required: all new values are diagnostic only.

## Observed versions and comparison

`before/` is the first complete five-run observation. Its native monitor/count
series is complete, but v1 retained report dictionaries and raised 59 errors while
examining freed bookkeeping values. Its runner exit is 1. The `_v1.gd.txt` sources
are retained; use the corrected sources for new work.

`after-clean/` is the fresh corrected observation, exit 0. It writes full reports
to individual boundary files and keeps only labels between samples; ownership
traversal guards freed values before using type tests. All five end recaps are
verified visible. The intervening `after/` trial stopped on filesystem exhaustion
at decision 470 and is excluded from after-proof.

Both complete sessions reach one Noctyrax victory and four production-health
deaths, with 2,733 decisions. The strict hash comparison remains failed for the
initial unseeded policy RNG and carried clock-derived Swift feat text; the
independent field audit checks actions, policy RNG, saves, profile and analytics:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 /private/tmp/labyrinth_codex/qa-53/tools/audit_integrity.py --before /private/tmp/labyrinth_codex/qa-53/before-owner --after /private/tmp/labyrinth_codex/qa-53/after-owner
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-53 && python3 tools/godot_task_runner.py --task-id qa-53 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-53/tools/texture_bounds_repro.gd
```

`findings.md` explains the exact normalization and the 138 unrecomputed post-win
state hashes. It also identifies the protected load-path cache leak and isolates
the BAYER StringName exit warning with shader controls. No product fix is claimed.

Additional diagnostic defaults: native class-name buffer `256` bytes; empty
texture/atlas repro with `20` repetitions and `1/5/20` checkpoints; shader controls
`empty`, `quantize`, `lines`, `both`, with `4` settling frames. Standard Python
bytecode compilation uses a task-local `PYTHONPYCACHEPREFIX`. No new dependency or
permanent test module is added. The native census bridge is macOS/debug-engine
specific; its required internal symbols are checked on load.

Runner defaults are inherited: Steam disabled, cel look `off`, and one isolated HOME/user namespace per invocation. Within each session the five runs share the task output/profile namespace.
