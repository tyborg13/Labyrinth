# Hover-change attribution (perf-11)

The clean native soak's first hover interval combines **hand-card entry and
the first board target**, in one frame. Its other four intervals each contain
one board target. The existing native reports have their slow interval almost
always at that first position. They do not show a hitch on every target change.

`perf11_soak.gd` preserves fight_soak's fixture, bot, inputs and clocks by
default. Its optional subclasses record synchronous hand/target input, deferred
hover and HUD work, forecast sections, board submission, draw sections, glossary
construction/layout, turn-order strip construction/layout, node additions and
removals, telemetry overhead, pipeline counters and root viewport render times.
`report.json` retains intervals, timestamps and process-frame IDs. Partitioning,
tree census, JSON and capture readback happen outside sampled frames. Inclusive
sections overlap; do not sum them. `perf11_report.py --frames-tsv` emits one row
per traced frame, with input labels, CPU sections, node events and render data.

Headless process-frame boundaries are scheduler intervals, not native pacing.
TIME_PROCESS retains its engine monitor cadence. Script timers measure elapsed
CPU-path wall time, including descheduling. Headless cannot identify GPU cost,
pipeline creation, font-atlas uploads or first-use shader work. Glossary timing
includes synchronous construction, measurement and text shaping; engine-internal
shaping is not separately timed. Delayed native board tooltips do not run in the
default direct `_gui_input` workload. The optional viewport/hold run exercises
that separate path; do not mix it into acceptance statistics. Zero render timing
means unavailable, not free. Root viewport timings are delayed and omit portrait
SubViewports. Metal GPU timestamps can be unavailable (see
`spec/performance_telemetry.md`).

The repeated CPU construction found here is the landing strip's animated
portrait rigs. Slots now retain their same-source controls and canvases. Every
original content rebuild still reapplies order, metadata, ETA, tint and geometry,
and resets the portrait through `reset_prepared_state()` and `present()`. Its
original fade, visibility, signature, input and animation boundaries remain.
Unused slots are freed; no hidden pool grows between fights. Valid movement
risk chips now borrow the surface forecast's `single_state`, removing a second
simulation of the same move. Empower repeats and automatic follow-ups remain
outside the risk chips, exactly as before. No forecast rules, save code, shader
warmup or user-dir cache behavior changes. The earlier shader
warmup was removed by the shader-01 owner; its feedback documents persistent
shader caches versus per-session Metal pipeline creation.

## CPU and equivalence proof

From this worktree, prepare the original factory and original RunScene from the
pinned base, using read-only Git. Generated files remain private. The original
scene uses the same attribution wrappers and the original strip; other resources
are unchanged by this unit.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && python3 tools/perf11_proof.py --output-dir /private/tmp/labyrinth_codex/perf-11/oracle
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && python3 tools/godot_task_runner.py --task-id perf-11 --stream -- godot --headless --path . --script tools/perf11/slot_equivalence.gd -- --reference /private/tmp/labyrinth_codex/perf-11/oracle/reference_strip.gd --output-dir /private/tmp/labyrinth_codex/perf-11/equivalence
```

The whole original factory is the oracle. It compares control/rig snapshots and
advanced clocks over all 16 registered maquette identities: initial, unchanged,
role exchange, reduced motion, hide/reveal, actor removal, act again, restoration
and detach/re-entry. `equivalence.json` includes paired synchronous timings. Its
initial reference always pays cold resource loading first; compare recurring
rebuilds, not those cold timings. `--candidate .../oracle/fault_strip.gd` must
fail: that private candidate deliberately retains the wrong animation phase.
These are on-demand proofs, with no new default-suite budget/count guards.

The second on-demand proof compares the complete risk-chip and surface-feedback
dictionaries against the original RunScene over legal Move/Blink targets with
bleed, Fire, Ice, Rubble, a trap, a pickup, Empower and limited Umbra. It also
checks source immutability and reports simulation counts:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && python3 tools/godot_task_runner.py --task-id perf-11 --stream -- godot --headless --path . --script tools/perf11/movement_equivalence.gd -- --reference /private/tmp/labyrinth_codex/perf-11/oracle/reference_run.gd
```

## Proof for the design owner

No windowed command was attempted in the worker sandbox. Run the following
serially, on a quiet machine with the window focused, at 1920x1080 and 100% UI
scale. Fresh output directories avoid old captures. Use the same renderer and
binary for both attribution runs. The commands select source art (`off`), as the
clean native `integ-off` baseline did. Repeat with `all` only if desired.

Before, using the untouched original strip in this same worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-11/oracle/reference_profile.gd python3 tools/visual_probe_runner.py --task-id perf-11 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-11/native-before/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-11/native-before
```

After, identical instrumentation and workload:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-11 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-11/native-after/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-11/native-after
```

Acceptance uses the original clean soak without finer tracing:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-11 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-11/native-clean/manifest.json tests/fight_soak_probe.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-11/native-clean
```

Require hover over-33-ms frames <=5%, median <=16.7 ms, and unchanged other
phases. Discard unfocused runs. Capture paths are `round_01.png`, `round_10.png`,
`round_20.png` beneath each native output directory. The worker cannot establish
these targets headlessly.

Exact original/retained strip pixel comparison, with frozen matching portrait
clocks. Inspect all eight captures at full resolution:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && python3 tools/visual_probe_runner.py --task-id perf-11 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tools/perf11/slot_proof.json --result-manifest /private/tmp/labyrinth_codex/perf-11/native-slots/manifest.json tools/perf11/slot_equivalence.gd -- --capture --reference /private/tmp/labyrinth_codex/perf-11/oracle/reference_strip.gd --output-dir /private/tmp/labyrinth_codex/perf-11/native-slots
```

Capture paths: `native-slots/{initial,exchange,reduced,hidden}_{before,after}.png`.

Separate optional real-viewport tooltip/held-target diagnostic (72 additional
same-target frames per target; **not** the acceptance workload):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_VIEWPORT_INPUT=1 LABYRINTH_PERF11_HOLD_FRAMES=72 python3 tools/visual_probe_runner.py --task-id perf-11 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-11/native-held/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-11/native-held
```

Summarize either native attribution report after the run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-11 && python3 tools/perf11_report.py /private/tmp/labyrinth_codex/perf-11/native-after/report.json --output /private/tmp/labyrinth_codex/perf-11/native-after/attribution.md --frames-tsv /private/tmp/labyrinth_codex/perf-11/native-after/frames.tsv
```

No inspection_fixture.py command was requested by the brief; inspection fixture,
review, commit and publication belong to the design owner.

Chosen proof-only defaults: `SIZE`, `TARGET_RECT`, `ADVANCE_SECONDS=0.31`,
`SETTLE_FRAMES=3`, `CAPTURE_CASES`, fixture ETA/sequence fields in `_entries`,
contract luma thresholds 16/2, movement proof `HAZARD_TILE`, `TARGET_LIMIT=8`,
fixture range/bleed/damage/pickup fields, and optional `hold_frames` (default zero). The
soak retains its existing 20 rounds, 120 FPS cap, seed and headless acceleration.
No perceivable design default or TODO_DESIGN placeholder was introduced.

The perf-12 hand-refresh continuation, oracle and exact native commands are in
[perf12.md](perf11/perf12.md).
