# ptf-06 implementation handoff

All changes are uncommitted. No branch, Git metadata, queue, publication, or peer-review operations were performed.

## Acceptance criteria

1. **Inline help:** event choice buttons and outcome wells forward hit tests from mouse-transparent text to the shared glossary icon panel. This preserves choice input and hover routing. Omen HUD tooltips and event reward previews include the referenced glossary panels; native tooltip windows cannot sustain nested hover popups. Relic Cache and HUD relics retain their existing shared glossary stacks, with direct rich-text help enabled on relic-choice descriptions. Scavenger card/equipment inspections use the shared card builder and now include keyword panels. Reward card hit testing exposes area-pattern help and uses glossary icon panels for Rite and other keywords. No content data or approved asset was changed.
2. **Cards outside combat:** the shared card/equipment tooltip builder includes the same deduplicated entries, panel factory, copy, textures, gap and separation as combat inspection. It covers Character Gear/Magic and pre-fight Your Kit, including run display modifiers. Existing root inspection metadata is forwarded to the wrapper.
3. **Omen Grimoire:** every omen is generated from `GameData.omens()`, with its name, original inline effect, referenced glossary text and authored fight duration. Entries are searchable by default, including Dread. Grimoire bodies now render the original inline icons.
4. **Scrolling:** the design owner verified the real renderer: wheel 0 → 260 and scrollbar drag 0 → 222. Both work; no scrolling change is needed.

## Files changed

- `scripts/event_view_text.gd`, `scripts/event_view_choice.gd`, `scripts/event_view.gd`: transparent inline hit-test forwarding.
- `scripts/inline_icon_text.gd`, `scripts/ui_tooltip_panel.gd`: shared glossary panels and embedded definition support.
- `scripts/omen_badges.gd`, `scripts/event_reward_preview.gd`: omen/relic effect explanations.
- `scripts/item_preview_builders.gd`: card/equipment inspection keyword panels, including Scavenger.
- `scripts/card_widget.gd`: card token glossary panels and approved area-pattern help.
- `scripts/grimoire_library.gd`, `scripts/run_scene.gd`: generated omen entries, inline detail rendering and relic-choice text help.
- `tools/ptf06/`: focused/affected headless tests, real-renderer probe, proof contract, script UID sidecars and this handoff.

## Approved director decisions

- `CardWidget.AREA_PATTERN_TOOLTIP`: "Area: the pattern shows which tiles this card hits."
- `GrimoireLibrary.OMEN_SECTION`: `keywords`; the generated duration reads "Lasts N fights."
- No TODO_DESIGN placeholders remain.

## Chosen defaults

No new visual/tuning/audio assets or player-facing numeric defaults. Panel dimensions and spacing reuse the existing combat inspection constants and factory.

Proof-only fields in `hover_probe.gd`: `PROOF_SIZE=1920x1080`, `PROOF_READY_FRAMES=900`, `PROOF_SETTLE_SECONDS=0.6`, `PROOF_HOVER_SECONDS=1.5`, `PROOF_HIT_STEP=3`, `PROOF_DRAG_DISTANCE=100`, `PROOF_SAFE_POINT=(8,8)`, `PROOF_WHEEL_STEPS=5`, `PROOF_THUMB_INSET=8`, `PROOF_RITE_ID=thorn_crown_pact`. Fixtures reuse the event suite's seed/state builder and select existing production cards with the required tokens. Focused tests use synthetic Expose/area geometry and existing production cards only. Runner caps: 60 seconds for focused checks, 120 seconds for the known multistate windowed probe, 45 seconds for renderer startup; the import bootstrap cap is 1800 seconds.

## Proof for the design owner

This one command captures all five requested states, plus Rite help and the scrolling reproduction, with the cel look, 1920x1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --startup-timeout 45 --expect-size 1920x1080 --proof-contract tools/ptf06/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-06/feedback1-visual-proof.json tools/ptf06/hover_probe.gd --task-id ptf-06
```

Capture paths (01–05 accepted by the design owner; 09 requires a fresh run):

- `/private/tmp/labyrinth_codex/ptf-06/captures/01_sarcophagus_dread.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/02_character_magic.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/03_reward_pattern.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/04_grimoire_dread.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/05_hud_omen.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/06_grimoire_scroll_before.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/07_grimoire_scroll_wheel.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/08_grimoire_scroll_drag.png`
- `/private/tmp/labyrinth_codex/ptf-06/captures/09_reward_rite.png`

`semantics.json` records probe failures and wheel/drag offsets. No inspection fixture command was requested by this brief. The owner owns renderer execution, visual judgment, fixture preparation and peer review.

## Headless checks

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/godot_task_runner.py --task-id ptf-06 --timeout 60 --stream -- godot --headless --path . --script tools/ptf06/focused_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/godot_task_runner.py --task-id ptf-06 --timeout 60 --stream -- godot --headless --path . --script tools/ptf06/affected_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/godot_task_runner.py --task-id ptf-06 --stream -- godot --headless --path . --check-only --script tools/ptf06/hover_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/program_suite_runner.py --task-id ptf-06 --jobs 2 --suite event_view_test --suite card_display_overrides_test --result-file /private/tmp/labyrinth_codex/ptf-06/affected-results.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-06/python-audit
```

Observed results:

- `PTF06 focused: 0 failures` (includes every production card's inspection stack, generated omen names/effects/durations, Dread search and actual reward-token forwarding).
- `PTF06 affected search and inline suites: 0 failures`.
- `Event view fit: 326 pages, 45 events × fresh/rich states`; `Event view suite: 0 failures` (final run after transparent-input forwarding).
- `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16749 checks, 0 failures)`.
- UI identity lint: `Ran 25 tests in 11.264s`, `OK`.
- Python default group: `Ran 189 tests in 112.338s`, `OK`. Ran only the 20 modules from `tools/python_suite_groups.json` default group with `PYTHONPATH=tests`; log `/private/tmp/labyrinth_codex/ptf-06/python-default-final.log`.
- Isolation audit: `ISOLATION AUDIT: 56 modules`; no new Python test module was added.
- Hover probe `--check-only`: exit 0. This validates parsing, not renderer behavior or screenshots.
- `git diff --check`: exit 0 for owned paths.

Initial failed attempts were corrected: nested-class static call qualification, missing class cache, a test search-result key, and the Python invocation's missing helper import path. The existing inline suite correctly rejected interactive event labels; the implementation now leaves those labels transparent and forwards through their input owners. No existing assertion was changed.

## Open proof issues

- The headless import bootstrap generated the class cache used by the checks, then was stopped (exit 130) during bulk asset import before handoff. It is not reported as a passing import; the visual runner performs its own import freshness check before the owner's proof.

- The design owner accepted captures 01–05. Reward Rite capture 09 needs a fresh renderer run after feedback 1.
- Grimoire scrolling is verified by the design owner’s real-renderer run (wheel 0 → 260; drag 0 → 222).
- Godot emits a sandbox CA-certificate message on headless launches. The existing card-display suite also reports an ObjectDB/resource-at-exit warning despite its passing result; no assertion was altered.

## Feedback 1

Preserved the director's area-pattern copy, Keywords section and "Lasts N fights." duration. The real-renderer Rite capture targeted a resting token before the reward hover lift moved it. The probe now enters Thorn Crown Pact, waits for its existing motion to settle, and then aims at Rite's current position. CardWidget's native tooltip query now honors Godot's supplied card-local point, and the complete icon/label/gap group carries its keyword help. Regression checks cover the native-facing API after the actual reward lift and scale, and the shared glossary icon-panel factory.

No new player-facing defaults or TODO_DESIGN placeholders. Feedback-only fixture fields: `REWARD_RITE_FIXTURE=thorn_crown_pact`, `REWARD_FIXTURE_SIZE=(250,352)`, `REWARD_FIXTURE_SCALE=0.9`, `REWARD_FIXTURE_POSITION=(600,200)`, `REWARD_HOVER_SETTLE_SECONDS=0.2`; hover pose reuses the production reward constants.

Feedback 1 verification (no full suites):

- `PTF06 focused: 0 failures`; the added native-query regression failed before the fix and passes afterward.
- `PTF06 affected search and inline suites: 0 failures`.
- Hover probe parser check: exit 0; no windowed run in the implementation sandbox.
- UI identity lint: `Ran 25 tests in 16.208s`, `OK`.
- Owned-path whitespace check: `git diff --check` exit 0.

Feedback 1 capture command is above; output `09_reward_rite.png` should now place the pointer on the settled Rite token and show its glossary panel. The fresh manifest is `feedback1-visual-proof.json` so the previous owner's proof manifest remains available.

- Feedback 1 Python default group: `Ran 189 tests in 192.039s`, `OK`; log `/private/tmp/labyrinth_codex/ptf-06/feedback1-python-default.log`.
- The first feedback 1 event-suite run reported `Event view suite: 1 failures`: `Expired badge fades out and is removed`. It ran alongside the Python default group; the unchanged expiry tween/assertion is timing-sensitive. The standalone retry passed: `Event view suite: 0 failures`, recorded in `feedback1-event-serial-results.json`; no expiry code or assertion was changed.

## Combined full-suite feedback

See [combined_gate_report.md](combined_gate_report.md) for branch-only reproduction of every reported failing program, attribution, fixes and exact result lines. Only the listed programs and ptf-06 focused checks ran in this round; all changes remain uncommitted.
