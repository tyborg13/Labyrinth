# perf-12 hand hover coalescing

Hand enter/leave commit the hovered index immediately and join the board hover's
single deferred presentation pass. That pass applies the final emphasis,
glossary, stage, turn order and tutorial, using the already committed board
hover/aim state. Discrete `_input` events and direct card/board action, drag and
Pass entry points flush pending hand work before reading it. Pure pointer motion
keeps coalescing. The existing interaction/animation/selection guards remain.

`--hand-sweep` is opt-in on both soaks. It replaces only the hover phase with
`hand_sweep`: first enter, each adjacent leave+enter in one frame, final leave,
with no board target. With the option absent, the original hover calls and waits
are unchanged. The attribution report includes synchronous calls, inclusive
stage/deferred work and stage-refresh counts per input frame. Nested timers
must not be added. Headless frame intervals measure scheduler cadence, not
native performance.

Prepare the pinned perf-11 oracle with read-only Git (no worktree mutations):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && python3 tools/perf11_proof.py --reference-rev 51e083cde --output-dir /private/tmp/labyrinth_codex/perf-12/oracle
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11/hover_equivalence.gd -- --reference /private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd --output-dir /private/tmp/labyrinth_codex/perf-12/equivalence
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11/hover_focused.gd
```

The oracle compares the full preview and board dictionaries, emphasis owner,
glossary entries/visibility, turn-order entries/strip roles, tutorial definition,
and selection/drag state at the first pre-draw boundary and after settling.
Wall-time analytics combat IDs are pinned to a named fixture identity before
rebuilding caches; all other compared dictionary fields remain intact.
Headless uses a deferred sentinel at the message-queue boundary; native uses
`frame_pre_draw`. Neither explicitly calls the candidate flush. Every row records
input/boundary process-frame IDs and stage-refresh counts per frame. Action cases
include their own required refreshes; the one-refresh target applies to hover
presentation. A paired pre-process input case also checks the first-draw emphasis and strip
fade clocks against the original, with the same engine delta. The focused runner
reuses the unchanged drag, card-keyword/Empower and turn-clock suites. No new default-suite budget/count guard is added.

## Proof for the design owner

The worker never runs windowed Godot. Run serially on a quiet machine, focused,
with source art, at 1920x1080 and 100% scale. Use fresh output directories if
repeating. First run the oracle command above. Same-frame state/capture proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tools/perf11/hover_proof.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-equivalence/manifest.json tools/perf11/hover_equivalence.gd -- --capture --reference /private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd --output-dir /private/tmp/labyrinth_codex/perf-12/native-equivalence
```

Inspect `native-equivalence/{enter,leave_enter,click,tutorial,motion}_{before,after}.png`.
All ten captures show the first frame, with normal production motion. They are semantic
and visual comparisons, not frozen-clock pixel equality checks.

Native attribution before and after, default workload:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-before/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-after/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-after
```

Native attribution before and after, sweep workload:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-sweep-before/manifest.json tools/perf11_soak.gd -- --native --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-sweep-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-sweep-after/manifest.json tools/perf11_soak.gd -- --native --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-sweep-after
```

Clean acceptance (without attribution overhead), default and sweep:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-clean/manifest.json tests/fight_soak_probe.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-clean
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-12/native-clean-sweep/manifest.json tests/fight_soak_probe.gd -- --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/native-clean-sweep
```

Soak capture paths: `{round_01,round_10,round_20}.png` beneath each output.
Require hover over-33-ms <=5%, median <=16.7 ms, and unchanged other phases.
Headless CPU results cannot establish those native targets. Summarize each
attribution report with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && python3 tools/perf11_report.py /private/tmp/labyrinth_codex/perf-12/native-sweep-after/report.json --output /private/tmp/labyrinth_codex/perf-12/native-sweep-after/attribution.md --frames-tsv /private/tmp/labyrinth_codex/perf-12/native-sweep-after/frames.tsv
```

No inspection_fixture.py command was requested. The design owner prepares any
inspection fixture, commits, reviews and publishes.

Chosen proof-only defaults: `SETTLE_FRAMES=8`, `SETTLE_SECONDS=0.22`,
`ACTION_TIMEOUT_FRAMES=1200`, the existing turn-clock fixture/seed/hand and guided
fixture, first/next card indices `0/1`, `DRAG_POINTER=(960,900)`,
`BOARD_TARGET=(3,4)`, `PROOF_KEYCODE=Shift`, capture
case selection, `FIXTURE_COMBAT_ID=perf12_oracle_combat`, paired-clock input
before process/tweens, luma thresholds 16/2. Soak seed, 20 rounds, 120 FPS cap and
headless acceleration are unchanged. No TODO_DESIGN placeholder is needed.

The missed-flush negative control is private and must fail:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11/hover_equivalence.gd -- --reference /private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd --candidate /private/tmp/labyrinth_codex/perf-12/oracle/fault_hover_profile.gd --output-dir /private/tmp/labyrinth_codex/perf-12/negative
```

## Headless attribution commands

These four commands were run serially, with the same fixture and attribution:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11_soak.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/cpu-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11_soak.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/cpu-after
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-12/oracle/reference_profile.gd python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11_soak.gd -- --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/cpu-sweep-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-12 && env LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id perf-12 --stream -- godot --headless --path . --script tools/perf11_soak.gd -- --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-12/cpu-sweep-after
```

Default final-leave tracing stops before its deferred work, so a zero stage
count in that row means unavailable. The sweep's final-leave row measures that
path through its flush. It still performs one stage, turn-order and tutorial
refresh. Stage visibility, preview/forecast construction and board submission
are retained; this unit only removes duplicate refreshes.
