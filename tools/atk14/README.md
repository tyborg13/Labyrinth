# atk-14 implementation handoff

**Current status:** [Feedback 3](FEEDBACK_3.md) restores Skybreak's narrow per-tile sky-bolt renderer for every board strike, makes peak sampling deterministic, and adds native bright-area measurements. The [feedback 2 primitive audit](FEEDBACK_2.md#2-other-rule-playback-audit) and five canonical ground decals are retained. [Feedback 1](FEEDBACK_1.md) supplies the icon/hold values and per-unit contact numbers. Earlier pending-design sections are historical and superseded.

Changes remain uncommitted in `codex/atk-14`. The design owner owns commit, peer review, inspection fixture and publication. No peer/reviewer agent was used. No windowed run was attempted.

## Numbered requirements

1. **Done:** Lightning Storm no longer injects Shock. The shared resolver covers `dynamo`, `snare_lightning`, `storm_cantor` and `zekarion`; damage, Chain, cadences and approved sentences are unchanged. Arc's conditional Shock remains. Rule assertions now require no hidden Shock, including zero-damage and illusion cases.
2. **Rows done; compact icon geometry pending design:** one helper reads installed live dials. Combat rows and focused board callouts append the beat after both generic and specialized action rows, including Dynamo. Pre-battle uses its installed preview rule (so an ordinary Capacitor is not mislabeled Dynamo), and renders an actual separate inline icon/token row. Half-Health Zekarion reads Chain 2. Compact badge data includes `rule_icon`; drawing awaits the named geometry placeholders below.
3. **Done:** compact descriptors consume the existing surface-bonus tokens and retain their condition icon. The real Arc export is `secondary_icon=shock`, `secondary_number=+1`, `condition_icon=surface_electrified`. Existing rider priority is preserved; other bonus token types can fall back to the same slot.
4. **Done:** the existing forecast records gained harmful statuses at action boundaries and before turn-start consumption, including Freeze-extended spans and action/target preview gains. It renders `+N [icon]` after resource rows, with the glossary tooltip on the icon. Status-only harm cannot display Safe. No additional production simulation was added. A rule test proves gained Freeze survives consumption and the skipped turn, without mutating the source.
5. **Playback done; caption icon geometry/hold pending design:** all rule firings emit a dedicated step, including activation-end room rules. Lightning Storm reuses descending bolts for all struck tiles together, then the actual resolver's victim-to-victim card Chain arcs at the prescribed 0.12 seconds per jump. Reduced motion uses the existing strike frame rules. Existing damage-number helpers remain in use. Gust retains its existing effects; other rules add only the caption and retain completion feedback. Activation-end costs before the beat are reconciled separately. The old activation API signature is preserved for existing callers/test doubles.
6. **Done:** the forecast's actual Chain-hit receipt contributes red on a hovered destination. The additional contribution is gated on the previewed destination differing from the resting hero tile. At-rest red's policy is unchanged.

No data, art, icon registry, fonts, audio, dialogue, save schema or `dragon_combat_rules.gd` was edited. No playback-only analytics event was added. The existing append-only `battlefield_rule_fired` event and adapter are unchanged.

## Balance and analytics check

Read the supplied heuristic and analytics sections. Neither the heuristic nor `tools/card_heuristic.py` assumed Lightning Storm's hidden Shock, so no synchronized assumption/scorer edit was needed. Mechanical delta per realized primary/Chain victim: Shock 1 → 0, damage/Chain unchanged. At the heuristic's generic Shock coefficient 2.5, this removes up to 2.5 control value per newly Shocked victim; this is a mechanical comparison, not a retune. Card definitions/scores are unchanged. Existing beat damage/status analytics follow the resolver's new actual outcome.

## Audit: before and after

Before is the preserved atk-13 census + real-health evidence, re-reported under the new label `atk14-before`; it is not a newly executed baseline engine. After reran the same natural seeds, five census and two real-health walks per tier, 36 decisions maximum, under `atk-14`, labels `census-after` and `real-health-after`. Early after runs were refreshed to use the final explicit Chain-receipt instrumentation. All 21 after runs completed. Removing Shock changes which walks/destinations occur, so denominators differ.

```text
ATK13 REPORT atk14-before: runs=21 checks=4380 oracle_mismatches=0 receipt_hp_exceeds_actual=0
ATK13 REPORT all-after: runs=21 checks=4194 oracle_mismatches=0 receipt_hp_exceeds_actual=0
ATK14 RECEIPT COVERAGE: PASS (4749 alternatives including stay; every row version 1)
```

Both reports have zero UI/replica mismatches and zero undisclosed widened-hit mismatches. The after report has 1,028 alternatives with disclosed uncertainty. All alternatives retain resumable production saves.

Cells are **told+hit / told+no-hit / not-told+hit / neither**. Each entry shows **before → after**. PASS means the panel's actual resource/status rows; move text is the currently visible announced move, not an unknown future roll. Intent disclosure's told/no-hit is a possible effect that did not occur, not a forecast false alarm.

| Choice / source | Hovered red | PASS panel | Announced move text |
| --- | --- | --- | --- |
| pass / peal_direct | 184 / 1 / 6 / 391 → 180 / 0 / 6 / 369 | 183 / 0 / 7 / 392 → 179 / 0 / 7 / 369 | 0 / 0 / 190 / 392 → 134 / 4 / 52 / 365 |
| pass / peal_chain | 4 / 0 / 7 / 571 → 4 / 0 / 4 / 547 | 4 / 0 / 7 / 571 → 4 / 0 / 4 / 547 | 0 / 0 / 11 / 571 → 4 / 134 / 4 / 413 |
| pass / capacitor_shock | 107 / 13 / 0 / 462 → 142 / 0 / 0 / 413 | 0 / 0 / 107 / 475 → 142 / 0 / 0 / 413 | 107 / 67 / 0 / 408 → 142 / 25 / 0 / 388 |
| move / peal_direct | 1139 / 4 / 46 / 2609 → 1115 / 0 / 42 / 2482 | 1136 / 0 / 49 / 2613 → 1112 / 0 / 45 / 2482 | 0 / 0 / 1185 / 2613 → 866 / 56 / 291 / 2426 |
| move / peal_chain | 64 / 4 / 36 / 3694 → 62 / 4 / 27 / 3546 | 64 / 4 / 36 / 3694 → 62 / 4 / 27 / 3546 | 0 / 0 / 100 / 3698 → 52 / 870 / 37 / 2680 |
| move / capacitor_shock | 589 / 86 / 1 / 3122 → 780 / 35 / 1 / 2823 | 0 / 0 / 590 / 3208 → 781 / 0 / 0 / 2858 | 590 / 423 / 0 / 2785 → 781 / 193 / 0 / 2665 |

New aggregate PASS status rows, including false alarms:

| Status/measure | Before | After |
| --- | ---: | ---: |
| Shock told + gained | 0 | 923 |
| Shock told + not gained (false alarm) | 0 | 0 |
| Shock not told + gained | 1,864 | 0 |
| Neither | 2,516 | 3,271 |
| Status amount disagreements | 1,864 | 0 |
| Peal primary Shock gains | 1,058 | 0 |
| Peal Chain Shock gains | 109 | 0 |
| Capacitor Arc Shock gains | 697 | 923 |

The after audit observed only Shock gains; it does not establish natural-play coverage for every other harmful status. The rule test additionally covers a consumed Freeze.

**Hovered-destination Chain:** the original actual-hit matrix was 64 told / 36 missed out of 100. In the after run, **all 66 destinations with an explicit Chain hit in their own forecast are red: 66/66, 0 misses**. The separate actual-hit matrix above still has 27 Chain misses under the information/uncertainty boundary; this unit does not claim to forecast unknown actors/moves. Raw actual hits and forecast hits are different denominators. PASS status rows had no observed false alarms, including disclosed choices.

Evidence:
- `/private/tmp/labyrinth_codex/atk-13/audit/atk14-before/report.json`
- `/private/tmp/labyrinth_codex/atk-14/audit/all-after/report.json`
- `/private/tmp/labyrinth_codex/atk-14/comparison.json`
- `/private/tmp/labyrinth_codex/atk-14/audit/{census-after,real-health-after}/tier-*/{samples.jsonl,cost.json,godot.log,repro/}`

Exact rerun commands (each starts in this worktree):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 python3 tools/atk13/audit.py run --root /private/tmp/labyrinth_codex/atk-14/audit --label census-after --count 5 --health 9999 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 python3 tools/atk13/audit.py run --root /private/tmp/labyrinth_codex/atk-14/audit --label real-health-after --count 2 --health 0 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/atk13/audit.py report --root /private/tmp/labyrinth_codex/atk-14/audit --label all-after --include-label census-after real-health-after
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/atk14/compare.py
```

The actual execution split independent tiers across three processes. Each run's `cost.json` records its exact Godot runner invocation and environment. Existing completed results are skipped unless `--force` is given.

## Focused checks

Only the requested focused checks and affected suites/probes ran; neither full suite was run.

```text
ATK14 RULES RESULT: PASS (0 failures)
ATK03 FOCUSED RESULT: PASS (1790 assertions, 0 failures)
ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)
THREATS AT REST TEST RESULT: PASS (16952 assertions; includes compass suite)
Ran 25 tests
OK
ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/atk-14/python-audit/isolation-audit.md
ATK14 TOOL SYNTAX: PASS (2 shell scripts, 3 Python modules)
ATK14 OWNED UID SIDECARS: PASS (5 scripts)
ATK14 SIDECAR INVENTORY: PASS (tracked and new task files)
```

The rule driver runs the existing battlefield rules (including both feedback suites), conduction, fuel and Chain suites, plus the four existing lightning trap/strike cases from `run_tests.gd`. Its added tests are confined to the allowed battlefield rule suite. The final dedicated rule run also passed two added Freeze-receipt assertions. No new `tests/test*.py` module was added, so the Python resource manifest is unchanged. The isolation audit was `--audit-only`.

Godot command shape, used for `tools/atk14/rules_check.gd`, `tools/atk03/focused_tests.gd`, `tools/atk04/focused_tests.gd`, and `tests/threats_at_rest_test.gd`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/rules_check.gd
```

Full logs: `/private/tmp/labyrinth_codex/atk-14/checks/`.

## Headless probe evidence

Seven real-save views exited 0 with their `ATK13 CAPTURE ...: PASS` lines: Peal intent, portrait, pre-battle, Arc PASS, Arc intent/compact descriptor, normal playback and reduced-motion playback. They assert the pre-battle icon-token row, Arc Shock gain, and actual bolt/Chain effect submissions. The Peal timeline includes `Storm Cantor: Peal`, `Lightning Storm`, simultaneous `lightning_strikes`, then arcs `(4,5) → (4,4)` and `(4,5) → (6,5)` in order. Native strip sampling includes start/mid-effect samples, retaining the real route.

Sidecars and logs: `/private/tmp/labyrinth_codex/atk-14/headless/{intent,portrait,prebattle,pass,arc,playback,reduced}.{json,log}`. Each sidecar explicitly says `headless_semantics_only: true`; none is renderer or pointer proof. No PNG was generated here. The three existing approved loop frames referenced by atk-13 were viewed; loop assets are untouched.

## Proof for the design owner

Run the prepared exact command list, using atk-13's native capture script and its real audited saves:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && sh tools/atk14/native_proof.sh
```

Expanded commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-2 intent peal_expanded --enemy storm_cantor --intent peal
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-2 portrait peal_disc --enemy storm_cantor --intent peal
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-9 prebattle cantor_prebattle --enemy storm_cantor
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-9 intent arc_compact_and_rows --enemy lightning_wisp --intent blinding_arc
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-9 pass arc_pass
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-2 playback peal_playback
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-2 playback peal_playback_reduced --reduced-motion true
```

These use `visual_probe_runner.py`, cel/Metal mobile, 1920×1080, 100% UI scale, no retries, and the capture contracts. Expected outputs are `/private/tmp/labyrinth_codex/atk-14/captures/<name>.png`, `.json`, `.manifest.json`, `.log`; playback additionally emits `_stepN.png` strips. These are planned native output paths, not claimed captures. Inspect both mid-bolt and mid-arc frames and tooltip reachability. `inspection_fixture.py` is not applicable here: these commands resume the existing real production saves in isolated runner homes; no global Continue save or fixture installation is needed.

## TODO_DESIGN placeholders / open issues

The brief did not specify new disc-rider or caption-icon geometry, or a caption-only hold duration. Per the design-authority instruction, no player-visible value was invented:

- `scripts/intent_badges.gd`: `TODO_DESIGN_RULE_RIDER_OFFSET`, `TODO_DESIGN_RULE_RIDER_SIZE`.
- `scripts/battlefield_rules/playback.gd`: `TODO_DESIGN_RULE_CAPTION_ICON_OFFSET`, `TODO_DESIGN_RULE_CAPTION_ICON_SIZE`, `TODO_DESIGN_RULE_CAPTION_HOLD_SECONDS`.

Zero geometry keeps those two icons unpainted. Zero hold adds no extra caption delay; caption-only rules currently submit a frame. Requirements 2 and 5 therefore remain visually incomplete until these design fields are supplied. The rule names, rows, routes, timing of Chain jumps and other implementation are wired.

Native rendering/pointer interaction and the owner-run visual review remain open. Headless logs contain the usual macOS certificate and HUD anchor warnings. The pre-battle semantic probe also logs ObjectDB/resources-in-use at shutdown despite exit 0 and a PASS sidecar; that shutdown diagnostic remains open and is not claimed fixed. No existing failing-master assertion was rewritten.

## Chosen defaults

Only new non-player defaults: headless probe time scale 16 and FPS cap 120; debug strip mid-effect sample at progress 0.5; existing 50-HP rule fixture tested at its exact half, 25 HP; task-local audit/output labels and paths. Native production timing is unchanged except the director's 0.12-second Chain jumps. All other probe staging, seeds, health levels, turn limit, frame budgets and capture sizes reuse atk-13's approved proof setup.

## Files changed

Runtime:
- `scripts/battlefield_rules/lightning_storm.gd`, `dispatcher.gd`, `committed.gd`; new `intent_rows.gd`, `playback.gd`.
- `scripts/board_attack_rules.gd`, `combat_engine.gd`, `combat_board_view.gd`, `run_scene.gd`.
- `scripts/intent_badges.gd`, `pre_battle_inspection_view.gd`.
- New `scripts/pass_forecast_statuses.gd`; `pass_forecast_focus_tooltip.gd`, `pass_forecast_red_tiles.gd`, `pass_forecast_repeats.gd`, `pass_forecast_turn_start.gd`.

Allowed rule tests:
- `tests/suites/battlefield_rules_suite.gd`, `battlefield_rules_feedback_suite.gd`, `battlefield_rules_feedback_2_suite.gd`.

Audit/proof tools (existing defaults retained):
- `tools/atk13/audit.gd`, `audit.py`, `reporting.py`, `presentation.gd`, `capture.gd`, `native_capture.sh`.
- New `tools/atk14/{rules_check.gd,capture.gd,compare.py,native_proof.sh,playback_contract.json,README.md}`.
- Godot-generated `.uid` sidecars for the five new GDScript files above.
