# Executed proof, defaults and limits

Audit risk tier: **low, verify only**. There are no product edits and no new tests. The two existing focused tests ran once; no full Godot or Python suite ran. No `tests/test*.py` module was created, so no Python suite resource registration was required. No UI/art/icon identity gate or balance scorer was run because no product/UI/art/identity/mechanics changed.

The runtime checkout stayed on `codex/qa-52` at `ec119e9ae7e9fec59212bd541f5a982406e2a762`. Release advanced during work; the pinned comparison to `3acf7848f5599fa2cbb2edbdb1371ce28f19bcb8` is saved in `evidence/release_delta.json` and `.patch`. All cited product sources are unchanged. The changed cited hand test steps the same tweens on a deterministic clock; it was not copied into this checkout. New rig render gating is source-inspected here, not executed or pixel-verified. Conclusions about the newer tree are explicitly inferences.

## Exact commands and observed results

All engine commands below ran **headlessly** through the required task runner, with separate runner-owned saves/HOME. Complete result lines and observed exit codes are also in [executions.json](evidence/executions.json). Raw logs retain all diagnostics. Native commands were written but never run.

### Intentional asset/class bootstrap

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 tools/godot_task_runner.py --task-id qa-52 --timeout 1800 --stream -- godot --headless --path . --import
```

Observed tool return: `exit_code=0`. Log: [import.log](evidence/import.log).

No synthetic PASS line is claimed; this command completed with the observed return above.

### Existing hand flow test

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script tests/card_draw_hand_flow_test.gd
```

Observed tool return: `exit_code=0`. Log: [hand_flow.log](evidence/hand_flow.log).

```text
KB02 KEYWORD TRACE: input=controller card=0 first_visible=9 strength=1.000000 drift=0.000px
KB02 KEYWORD TRACE: input=controller card=1 first_visible=8 strength=1.000000 drift=0.000px
KB02 KEYWORD TRACE: input=controller card=2 first_visible=9 strength=1.000000 drift=0.000px
HUD REVIEW NEW COMBAT: cleared=true launch_count=5 stable=true
HUD REVIEW SHRINKING FAN: held=1272.48 widest=1272.48 stable=true draw_cap=9
HUD REVIEW HANDOFF RESIZE: contained=true
CARD DRAW HAND FLOW TEST RESULT: PASS
```

### Existing card display test

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script tests/card_display_overrides_test.gd
```

Observed tool return: `exit_code=0`. Log: [card_display.log](evidence/card_display.log).

```text
CARD DISPLAY OVERRIDES TEST RESULT: PASS (16749 checks, 0 failures)
```

### Live scenes and metrics

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=all QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/verified python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [scenes.log](evidence/scenes.log).

```text
QA52 OBSERVER COMPLETE surface=all renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/verified
```

### Corrected pointer trace

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=combat QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_combat python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [combat_final.log](evidence/combat_final.log).

```text
QA52 OBSERVER COMPLETE surface=combat renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_combat
```

### Zero-score defeat recap

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=defeat QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_defeat python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [defeat_final.log](evidence/defeat_final.log).

```text
QA52 OBSERVER COMPLETE surface=defeat renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_defeat
```

### All-six victory recap

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=victory QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_victory python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [victory_final.log](evidence/victory_final.log).

```text
QA52 OBSERVER COMPLETE surface=victory renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_victory
```

### Elemental Gift strips

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=boon QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_boon python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [boon_final.log](evidence/boon_final.log).

```text
QA52 OBSERVER COMPLETE surface=boon renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_boon
```

### Settings routed input

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=settings QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/settings_input python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [settings_input.log](evidence/settings_input.log).

```text
QA52 OBSERVER COMPLETE surface=settings renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/settings_input
```

### Hanged Knight text

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=event QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/hanged_knight python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd -- --event-id hanged_knight
```

Observed tool return: `exit_code=0`. Log: [hanged_knight.log](evidence/hanged_knight.log).

```text
QA52 OBSERVER COMPLETE surface=event renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/hanged_knight
```

### Reward notice A/B

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=reward QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_reward python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Observed tool return: `exit_code=0`. Log: [reward_final.log](evidence/reward_final.log).

```text
QA52 OBSERVER COMPLETE surface=reward renderer=headless output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/final_reward
```

### Sound routing/card tokens/aim

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=logic python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/logic_observe.gd
```

Observed tool return: `exit_code=0`. Log: [logic.log](evidence/logic.log).

```text
QA52 LOGIC OBSERVER COMPLETE output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/logic
```

### Seeded defeat wording

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=titles python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/title_observe.gd
```

Observed tool return: `exit_code=0`. Log: [titles.log](evidence/titles.log).

```text
QA52 TITLE OBSERVER COMPLETE output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/titles
```

### Production Continue/manual harness, headless

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual_validation python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd
```

Observed tool return: `exit_code=0`. Log: [manual_validation.log](evidence/manual_validation.log).

```text
QA52 MANUAL READY: real input enabled; F9 captures; 60 seconds
QA52 MANUAL COMPLETE output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/manual_validation
```

### Production New Run/default profile, headless

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=fresh_validation QA52_FRESH=1 python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd
```

Observed tool return: `exit_code=0`. Log: [fresh_validation.log](evidence/fresh_validation.log).

```text
QA52 MANUAL READY: real input enabled; F9 captures; 60 seconds
QA52 MANUAL COMPLETE output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/fresh_validation
```

### Skill-gated capture fixture, headless

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=deferred_validation python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario reward --seed 83 --level 3 --skills discerning_eye,deferred_choice
```

Observed tool return: `exit_code=0`. Log: [deferred_validation.log](evidence/deferred_validation.log).

```text
QA52 MANUAL READY: real input enabled; F9 captures; 60 seconds
QA52 MANUAL COMPLETE output=/Users/borgerding/workspace/Labyrinth.worktrees/qa-52/spec/peer_benchmark/qa/polish_verify_2026-11-05/evidence/deferred_validation
```

### Final observer parser

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 tools/godot_task_runner.py --task-id qa-52 --stream -- godot --headless --path . --check-only --script spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd
```

Observed tool return: `exit_code=0`. Log: [final_parser.log](evidence/final_parser.log).

No synthetic PASS line is claimed; this command completed with the observed return above.

### Read-only file metrics

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/read_data.py
```

Observed tool return: `exit_code=0`. Log: [data.log](evidence/data.log).

```text
QA52 DATA AUDIT COMPLETE cards=10 fonts=3 audio_files=6
```

### Read-only source snapshot

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/read_sources.py
```

Observed tool return: `exit_code=0`. Log: [sources.log](evidence/sources.log).

```text
QA52 SOURCE SNAPSHOT COMPLETE excerpts=171 files=48 missing_files=0
```

### Moving release comparison

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/compare_release.py
```

Observed tool return: `exit_code=0`. Log: [release_delta.log](evidence/release_delta.log).

```text
QA52 RELEASE COMPARISON: audited=ec119e9ae release=3acf7848f changed_files=18 cited_source_matches=47/48
```

### Report coverage

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/build_report.py
```

Observed tool return: `exit_code=0`. Log: [report_coverage.log](evidence/report_coverage.log).

```text
QA52 REPORT COVERAGE: 115/115 player-facing rows; excluded_metadata=4
QA52 CLASSIFICATIONS: already fixed=35, reproduces=37, can't tell headlessly=43
QA52 WINDOWED CONTRACTS: 36 commands; none executed
```

## Observer corrections and diagnostics

- The first broad observer saved fixtures but did not install the direct-scene resume state. Its combat observer dereferenced a missing card and the required runner rejected it with exit 1. `scenes_initial_invalid.log` is retained; it is not evidence of a product bug.
- The next broad observer had Godot's default EXPAND aspect, yielding a 1920×1920 logical root. Those geometry payloads were discarded. The final observer explicitly uses KEEP and logs 1920×1080. Original `scenes_expand_invalid.log` remains for the audit trail. The early `data_observer.log` and `continue.log` also came from the EXPAND prototype and are superseded by the verified geometry/production-Continue evidence.
- The first logic observer preloaded a nonexistent helper filename; `logic_initial_parser.log` retains that parse failure. It was corrected to the existing `card_display_overrides.gd` before the successful logic run.
- The first boon observer lacked the authored opening-boon state. `boon_initial_fixture.log` is retained. The final run uses the existing `opening_boon_fixture.force_boon("elemental_gift")`; no production content was changed.
- Recap fixtures equipped with a nonstarter weapon initially hit the existing heirloom prompt. The final recap observers resolve the existing Leave nothing state before observing the settled recap. Hidden preliminary recap nodes are not used as evidence.
- An early custom pointer observation omitted the root screen transform and therefore missed the hand. The final combat observer applies the same screen transform as the existing hand test. Its recorded pointer/hover/under-pointer all agree at card 0. The passing existing hand-flow test is the primary evidence for deselect/redeal behavior.
- `_floating_texts_for_step` samples are helper observations, not complete player-card playback. The player buff-text finding additionally audits the actual `_animate_player_action_step` match, which has no handlers for those buff types.
- Headless logs include the macOS certificate diagnostic `ERROR: Condition "ret != noErr" is true. Returning: ""`, occasional dummy-texture `ERROR: Parameter "t" is null.`, resource-at-exit diagnostics and an import duplicate-UID warning. These are preserved. None was silently relabeled a test assertion pass; the focused test result lines and runner exit codes are reported separately.
- An attempt to terminate the lengthy bootstrap returned `zsh:kill:1: kill 68823 failed: operation not permitted`. No escalation/workaround was used. The owned bootstrap subsequently completed with exit 0; no process remains pending.

No pre-existing assertion was edited. No stale unrelated windowed suite was run or rewritten. No renderer capture, windowed launch or retry was attempted in this sandbox.

## Chosen defaults

All are proof-only fields/constants; no product values were chosen or changed.

- `SIZE_QA=1920×1080`, UI scale 1.0 and KEEP aspect implement the brief's required proof configuration. No alternative resolution is captured.
- `SETTLE_FRAMES_QA=12`, `BOOT_SETTLE_FRAMES_QA=30`, `STATE_SETTLE_FRAMES_QA=20`, `SHORT_SETTLE_FRAMES_QA=3`, `FRAME_PAIR_QA=2`, `HOVER_REST_SAMPLE_FRAMES_QA=4`; hand-size samples are `HAND_COUNTS_QA=[5,3,1,0]`. These settle/sampling choices are not native timing verdicts.
- `LAUNCH_LIMIT_SECONDS_QA=60`, `INTRO_SETTLE_SECONDS_QA=3.5`, `TERMINAL_SETTLE_SECONDS_QA=6`. Native wrappers allow 180 s total and 75 s startup because they combine a 60 s production launch deadline with the 60 s interactive capture.
- Manual observer: `QA_MANUAL_SECONDS=60`, `QA_CHECKPOINT_SECONDS=5`, `QA_TRACE_FPS=60`, `QA_BURST_FRAMES=30`, F9 checkpoint key. Bursts are enabled only with `QA52_BURST=1`. In headless validation the manual loop observes one frame and exits; it does not pretend to accept real human input.
- Debug seed 83 comes from the ledger; the isolated boon sample uses the existing authored QA fixture's seed 2. Seeded title sampling uses ten identities (`TITLE_SAMPLE_COUNT_QA=10`).
- Rich scene fixtures use 1000 held/profile Embers, existing Iron Cleaver/Duelist Rapier and Crimson Draught/Mossglass Elixir inventory IDs, and seven existing magic IDs (listed in the observer's `_options` fields). The five-card combat hand is Quick Stab, Volt Surge, Whetstone, Tempest Form, Updraft. Tutorial is completed only for inspection fixtures; `QA52_FRESH=1` uses the actual default profile/New Run path.
- Recap-only fixtures take the existing Leave nothing heirloom resolution. Six dragon IDs populate the victory score fixture. The future escape capture uses the explicit `enemy_hp=1` debug flag to shorten a real final-fight/reward/escape transition; this is not product balance tuning.
- Router/line-aim fixture fields: fake bank time 10000 ms/frame 1; hero HP 24→21; new crawler HP 9; line-test foes HP 100; hero position (3,3), paired horizontal or vertical foe positions (all recorded in the trace). These isolate presentation routing and orientation without changing production definitions.
- Existing strip geometry 190×30 and health 24/24 reproduce the ledger examples. Existing assets/fonts/audio are read in place. File audio metrics use decoded float samples and explicitly distinguish per-channel RMS from summed-channel power.

## TODO_DESIGN placeholders

**None introduced.** This unit authors no player-facing behavior or design. Prospective changes in the report are conditional recommendations; unresolved taste/wording/assets are left to the director rather than invented or written into product data.

## Remaining proof / open issues

The report has 43 can't-tell-headlessly rows, plus explicitly qualified pixel/taste parts of source-proven observations. Use [WINDOWED_COMMANDS.md](WINDOWED_COMMANDS.md) for all 36 concrete native commands and recipes. Current native capture count is **0**. Planned captures are `native/<command-key>/*.png` at 1920×1080, with state JSONL and `native/manifest_<key>.json` proof manifests. No screenshot path is presented as an existing image.

Rare Continue stalls, the full real first-profile flow, fast hover flashes, actual mouse-held Pass tooltips, transient escape residue, board paint overlap, subjective art/mix quality and real reaction timings remain explicitly limited in the table. Do not use this report to authorize any fix of those without the corresponding native proof.

A playable publication fixture and peer signoff are **not part of this verify-only unit**; the brief assigns those to the design owner. No commit, branch change, push, merge, stash, queue edit, reviewer agent or signoff request occurred.

## Report artifact validation

The inventory/link/trace/command-ID check and native dispatcher dry run are artifact checks, not new product tests. Both completed with observed exit code 0. The dispatcher dry run opened no windows.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/run_native.py --case all --dry-run
```

```text
QA52 NATIVE DISPATCH DRY RUN: 36 commands; windows_opened=0
QA52 REPORT INTEGRITY: PASS (115 unique quoted rows; 37 reproduction locations; 36 native commands/contracts; links/traces/IDs valid; 0 PNGs; no tracked product changes)
```

Logs: [native dispatcher](evidence/native_dispatch_dry_run.log), [artifact integrity](evidence/integrity.log). Final `git diff --check` returned 0; `git status --short` contains only this report directory.
