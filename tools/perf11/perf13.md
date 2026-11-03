# perf-13 hand hover rest

Pointer emphasis keeps the perf-12 deferred boundary. Stage, glossary and
turn-order projection wait for two completed `RenderingServer.frame_post_draw`
signals on the same card. Adjacent enter or leave invalidates the rest;
repeated entry of the same owner does not restart it. Discrete input/actions
flush the current owner immediately. Navigation focus explicitly bypasses rest.
Reduced motion uses the same two renders. No wall timer or process-frame count
controls production readiness. The board click/render and rail paths are untouched.

Prepare the perf-12 baseline (read-only Git):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && python3 tools/perf11_proof.py --reference-rev 8593be76e --output-dir /private/tmp/labyrinth_codex/perf-13/oracle
```

The extended oracle retains perf-12's 17 cases, final full-state comparisons
and first-frame emphasis clocks. The rest proof additionally samples each render
boundary, checks zero stage refreshes and unchanged preview/glossary/strip while
sweeping, exact maturity, immediate exit, reduced motion, repeat/reentry and
navigation focus. Click, drag, key and Pass follow an adjacent leave/enter pair
in the same input frame. Headless proof uses explicit synthetic draw signals and
checks process ticks without renders cannot mature rest. Native uses real draws.
Hidden retained strip rows are excluded only after canceled sweep exits: those
previews were intentionally never constructed. All visible exit state and every
rested strip row remain compared.

## Proof for the design owner

The worker never runs windowed Godot. Run serially on a quiet machine, focused,
with source art, at 1920x1080 and 100% scale. Use fresh output directories if
repeating. Prepare the pinned perf-12 oracle using the command above. Same-frame state/capture proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tools/perf11/hover_proof.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-equivalence/manifest.json tools/perf11/hover_equivalence.gd -- --capture --reference /private/tmp/labyrinth_codex/perf-13/oracle/reference_profile.gd --output-dir /private/tmp/labyrinth_codex/perf-13/native-equivalence
```

Inspect `native-equivalence/{enter,leave_enter,click,tutorial,motion}_{before,after}.png`.
The original ten captures show the first frame, with normal production motion. They are semantic
and visual comparisons, not frozen-clock pixel equality checks.

Native attribution before and after, default workload:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-13/oracle/reference_profile.gd python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-before/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-after/manifest.json tools/perf11_soak.gd -- --native --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-after
```

Native attribution before and after, sweep workload:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off LABYRINTH_PERF11_SCENE_SCRIPT=/private/tmp/labyrinth_codex/perf-13/oracle/reference_profile.gd python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-sweep-before/manifest.json tools/perf11_soak.gd -- --native --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-sweep-before
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-sweep-after/manifest.json tools/perf11_soak.gd -- --native --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-sweep-after
```

Clean acceptance (without attribution overhead), default and sweep:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-clean/manifest.json tests/fight_soak_probe.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-clean
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && env LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-13/native-clean-sweep/manifest.json tests/fight_soak_probe.gd -- --hand-sweep --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-13/native-clean-sweep
```

Soak capture paths: `{round_01,round_10,round_20}.png` beneath each output.
Require hand_sweep over-33-ms <=10%, with hover and all other phases unchanged.
Headless CPU results cannot establish those native targets. Summarize each
attribution report with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-13 && python3 tools/perf11_report.py /private/tmp/labyrinth_codex/perf-13/native-sweep-after/report.json --output /private/tmp/labyrinth_codex/perf-13/native-sweep-after/attribution.md --frames-tsv /private/tmp/labyrinth_codex/perf-13/native-sweep-after/frames.tsv
```

No inspection_fixture.py command was requested. The design owner prepares any
inspection fixture, commits, reviews and publishes.


Also inspect `{rest,sweep,sweep_rest,sweep_exit,reduced_rest,key_focus,controller_focus}_{sweep,rest}_{before,after}.png`.
The sweep captures intentionally retain the previous preview; rest captures must
match the baseline for the final card. These 28 images join the existing 10.

Chosen proof-only defaults inherited from perf-12 are unchanged. New named fields:
`NO_DRAW_PROCESS_FRAMES=4`, `FIRST_CARD=0`, `NEXT_CARD=1`, the explicit rest-case
and capture-case inventories. No TODO_DESIGN placeholders. No inspection fixture
command is required by this brief; the design owner owns inspection.
