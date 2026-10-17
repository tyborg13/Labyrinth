# qa-08 implementation and proof

Worktree: `codex/qa-08`, initial HEAD `723104fe4`. All implementation is uncommitted. No production gameplay code, approved assets, design data, queue state, or Git history was rewritten. No existing failure assertion was removed or relaxed. Test fixtures and registration changed; the design owner retains commit, review, inspection and publication.

## 1. Skill analytics root cause

The fixture is stale; the reported terminal failure is not a production persistence bug. `finish_combat()` now returns a resumable final dragon reward, then `continue_dragon_reward()` produces victory. The fixture skipped Continue. It now saves/reloads that reward checkpoint, verifies it remains resumable, continues through the real engine API, and retains all original terminal clearing, outbox transfer, retry, acknowledgment and exactly-once assertions.

Focused result: `TEST RESULT: PASS`. The `combat_skill_event_outbox` persistence error is expected fault injection in the earlier blocked-run-path scenario, followed by tested recovery; the Moltshard save error is also deliberate. These logs are not the failed terminal assertions.

Every first-parent integration state touching run_scene/run_engine/progression_store/analytics_store/the failing test since `816f5e68a` was exercised. All already fail the same two terminal assertions. Investigation extended before master: `84145c88c` introduced the reward checkpoint. Its parent passes the terminal assertions but has an unrelated old `result_stats` script error, so its process exit is correctly reported as failure. No all-green historical run is claimed. Historical scripts/tests/scenes/data/shaders were extracted without checkout/branch changes; asset paths use the existing approved tree. The two pre-master boundary checks were also rerun with historical tools.

| Revision | Result / runner exit | Evidence |
|---|---|---|

| `efa98ec6b` | terminal assertions PASS; unrelated result_stats script error; exit 1 | [Keep planning music on the active Graftwright screen](../output/qa-08/history-corrected/efa98ec6b.log) |

| `84145c88c` | FAIL (2 terminal assertions); exit 1 | [Make dragon battles tactical and reward every milestone](../output/qa-08/history-corrected/84145c88c.log) |

| `816f5e68a` | FAIL (2 terminal assertions); exit 1 | [Merge remote-tracking branch 'origin/master' into codex/waiting-takes-time-unused-card-plays-cost-5-time-plus-turn-order-legibil](../output/qa-08/history/816f5e68a.log) |

| `5ca4bfe87` | FAIL (2 terminal assertions); exit 1 | [Merge ev-01: event engine and omens](../output/qa-08/history/5ca4bfe87.log) |

| `09af36a0c` | FAIL (2 terminal assertions); exit 1 | [Merge feel-01: hit-stop, shake tiers, flash, enemy pacing, Combat speed](../output/qa-08/history/09af36a0c.log) |

| `f3fcff1fc` | FAIL (2 terminal assertions); exit 1 | [Merge ev-02: illustrated event screen, omen HUD, event/omen art](../output/qa-08/history/f3fcff1fc.log) |

| `8c71fa17b` | FAIL (2 terminal assertions); exit 1 | [Merge biome-01: per-section biomes](../output/qa-08/history/8c71fa17b.log) |

| `e1032c6e9` | FAIL (2 terminal assertions); exit 1 | [Merge map-01: section map revision 4](../output/qa-08/history/e1032c6e9.log) |

| `102106be6` | FAIL (2 terminal assertions); exit 1 | [Merge feel-02: health-bar damage ghost](../output/qa-08/history/102106be6.log) |

| `28170510d` | FAIL (2 terminal assertions); exit 1 | [Merge itb-02 (movement undo) into peer-benchmark](../output/qa-08/history/28170510d.log) |

| `83eb01a5c` | FAIL (2 terminal assertions); exit 1 | [Merge fix-01 (wave-1 peer-review fixes) into peer-benchmark](../output/qa-08/history/83eb01a5c.log) |

| `6e1edef37` | FAIL (2 terminal assertions); exit 1 | [Merge itb-01 (threats at rest) into peer-benchmark](../output/qa-08/history/6e1edef37.log) |

| `21ed3604f` | FAIL (2 terminal assertions); exit 1 | [Merge fix-01 r1 (re-review fixes) into peer-benchmark](../output/qa-08/history/21ed3604f.log) |

| `7a12f17f7` | FAIL (2 terminal assertions); exit 1 | [Merge enc-01 (section encounter tables + empty-board render fix) into peer-benchmark](../output/qa-08/history/7a12f17f7.log) |

| `ba3cd901c` | FAIL (2 terminal assertions); exit 1 | [Merge sfx-01 (SFX cue bank, router, call sites) into peer-benchmark](../output/qa-08/history/ba3cd901c.log) |

| `6f4bbacfb` | FAIL (2 terminal assertions); exit 1 | [Merge meta-01 (run score + run-end screen) into peer-benchmark](../output/qa-08/history/6f4bbacfb.log) |

| `d56270280` | FAIL (2 terminal assertions); exit 1 | [Merge en-01 (Burrow Grub + Ember Tick) into peer-benchmark](../output/qa-08/history/d56270280.log) |

| `0d54a5970` | FAIL (2 terminal assertions); exit 1 | [Merge fix-02 (play time out of combat state) into peer-benchmark](../output/qa-08/history/0d54a5970.log) |

| `bc63d4b36` | FAIL (2 terminal assertions); exit 1 | [Merge en-03 (Arc Thrall + Gloam Stalker) into peer-benchmark](../output/qa-08/history/bc63d4b36.log) |

| `90823d36d` | FAIL (2 terminal assertions); exit 1 | [Merge meta-03 (Umbra Depths) into peer-benchmark](../output/qa-08/history/90823d36d.log) |

| `066b4c970` | FAIL (2 terminal assertions); exit 1 | [Merge en-02 (Hoarfrost Seer + Gale Herald) into peer-benchmark](../output/qa-08/history/066b4c970.log) |

| `e5c36d24d` | FAIL (2 terminal assertions); exit 1 | [Merge meta-02 (Chronicle) into peer-benchmark](../output/qa-08/history/e5c36d24d.log) |

| `a0855abec` | FAIL (2 terminal assertions); exit 1 | [Merge ux-01 (start room opens the map) into peer-benchmark](../output/qa-08/history/a0855abec.log) |

| `9cb078a0a` | FAIL (2 terminal assertions); exit 1 | [Merge en-06 (Storm Capacitor + Hollow Mimic) into peer-benchmark](../output/qa-08/history/9cb078a0a.log) |

| `4fc16f982` | FAIL (2 terminal assertions); exit 1 | [Merge itb-03 (threats at rest v2) into peer-benchmark](../output/qa-08/history/4fc16f982.log) |

| `63271ccf4` | FAIL (2 terminal assertions); exit 1 | [Merge en-04 (Briar Weaver + Slag Mortar) into peer-benchmark](../output/qa-08/history/63271ccf4.log) |

| `062c3d40a` | FAIL (2 terminal assertions); exit 1 | [Merge en-05 (Glacial Mirror + Gust Shrike) into peer-benchmark](../output/qa-08/history/062c3d40a.log) |

| `3ede04408` | FAIL (2 terminal assertions); exit 1 | [Merge fix-03: Fatigue never amplified (owner), SPENT HUD, token icons, Lightning Strikes chip; peer signoff 64d34965f](../output/qa-08/history/3ede04408.log) |

| `9d711ceb5` | FAIL (2 terminal assertions); exit 1 | [Merge chr-02: Chronicle spells as card tiles (peer signoff 99d872fa5; r5 tests-only)](../output/qa-08/history/9d711ceb5.log) |

| `a98d3683f` | FAIL (2 terminal assertions); exit 1 | [Merge ux-03: glossary tooltip stacks for relics and inline icons, data-driven glossary (Codex peer signoff aaf2b48ff)](../output/qa-08/history/a98d3683f.log) |

| `1a9e585e7` | FAIL (2 terminal assertions); exit 1 | [Merge ux-04: approved glossary and relic text, renames (ids unchanged), gold keyword tokens, budgets and coverage (Codex signoff 1eaa7b490)](../output/qa-08/history/1a9e585e7.log) |

| `7eeb4a4d9` | FAIL (2 terminal assertions); exit 1 | [Merge sfx-04: audio/visual sync (anchored triggers, per-call peak alignment at climax+15 ms across speeds and frame rates), cue length caps, regression harness (Codex signoff 73301ac8b)](../output/qa-08/history/7eeb4a4d9.log) |

| `f411c09a9` | FAIL (2 terminal assertions); exit 1 | [Merge rr-03 + qa-06: Gust Shrike cutout rig (idle/move/dive/talon rake/hover/hit/death; collapse death), density-registered, shadow cache, bone-level signed motion gates, production capture from real clip progression (Codex signoff 7d39578e6)](../output/qa-08/history/f411c09a9.log) |

| `58b4f59b8` | FAIL (2 terminal assertions); exit 1 | [Merge ux-05: previews mark destruction instead of hiding it (terrain, traps, illusions, lethal pull ghosts, multi-action), information-safe (Codex signoff 156ebec72)](../output/qa-08/history/58b4f59b8.log) |

| `3f8a19b15` | FAIL (2 terminal assertions); exit 1 | [Merge deck-01: magic-slot limit dropped — spells go straight into the deck; save migration; MAGIC IN DECK panel; Purge at Scavenger (50 +25 paid-only) and Campfire with a centred confirm dialog; deck wording everywhere; analytics (Codex signoff d926871aa)](../output/qa-08/history/3f8a19b15.log) |

| `58c58c9af` | FAIL (2 terminal assertions); exit 1 | [Merge rr-04: Shale Bloomer + Lightning Wisp cutout rigs from maquettes (generic semantic motion compiler; board, portraits; density + shadow cache; move facing + root-travel HUD fixes) (Codex signoff b244014b8)](../output/qa-08/history/58c58c9af.log) |


## 2. Complete audit

[Every matching test, suite and probe](qa_08_test_inventory.md) is classified with executable registration evidence or an explicit native exclusion. The initial exploratory sweep ran 239 standalone scripts, including redundant wrappers; all real headless orphans were exercised. Pack tests were then run with their required build/verify arguments in an empty project. Expensive checks that exceeded the initial 45-second sweep were rerun at the normal 180-second budget where applicable; native-only tests were not attempted.

`python3 tools/test_registration_audit.py --json output/qa-08/audit.json --markdown output/qa-08/audit.md` regenerates the classification. `--check-quarantine --output-dir output/qa-08/quarantine-check` reruns all unresolved headless entries, including libraries through their explicit standalone wrapper. `--run-orphans` remains available for newly discovered unregistered scripts.

## 3. Registration and guard

`headless_test_programs.json` currently adds 116 isolated process tests (the original 115 plus the newly passing objective-glyph fixture). Surface Relic runs in-process. Assertion-free wrappers reuse the exact suite methods the runner already invokes. New ordinary headless scripts, unused preloads, parse-only references, uncalled methods, local wrapper assertions, stale/duplicate registrations and inherited initializer false positives have regression coverage.

Cutout package fixtures now recursively include their literal script dependencies instead of freezing transitive dependency lists. Nineteen per-creature build/verify checks and four source-package builders pass; the remaining Lightning Wisp legacy fixture is listed below. Demo capture settings run with their actual startup override in a private minimal project. Missing GameData preloads, the analytics depth reference, and the obsolete hover spy hook were fixed without changing existing assertions.

Current fast guard: `TEST REGISTRATION AUDIT: PASS (718 scripts; full suite=373, quarantined=33, windowed probe=312)`. All remaining entries in `quarantine.json` have exactly one category, reason, relative evidence-log path and follow-up id. The slow guard reruns every quarantined assertion and fails if any now pass. The dragon-area library shares its standalone entrypoint: the initial 34 entries use 33 processes; after registering the newly passing objective test, 33 entries use 32 processes.

`python3 -m unittest discover -s tests -p 'test_test_registration_audit.py' -v`: `Ran 20 tests in 0.922s`; `OK` ([log](../output/qa-08/guard-feedback.log)). Coverage includes every required field, category/owner validity, safe evidence paths, duplicate/deleted entries, registered/native overlaps, exact library entrypoint execution, and passing-quarantine rejection.

The initial slow check found `objective_glyph_equivalence_test.gd` passing unchanged: 26 cases, 12,629 checks, no errors. Its original failure depended on a cold glyph workload taking at least the production 4 ms slice; faster execution skipped the cancellation callback. This is a timing-sensitive fixture, not proof that headless TextServer cannot prepare native font caches. The ownership fixture now prepares a real outline first and delays its test-only liveness callback by `Glyphs.SLICE_USEC + 1` microseconds. All original outline, cancellation, ownership, state and native pixel assertions remain. It passes with 26 cases / 12,633 checks and joins the manifest, making **116 supplemental programs**. The native pixel path still needs design-owner execution; no native pass is claimed. [Focused log](../output/qa-08/objective-glyph-deterministic.log).

Follow-up scope exceptions: the retained-character-inventory, retained-shop pagination, and static-floor-cache failures are provisionally assigned to `bug-01` as possible bugs. They exceed its explicitly named character-view cancellation scope; these three scope extensions remain flagged for the design owner. The remaining retained/deck/map/shop fixture migrations fit `qa-09`, while the legacy surface-copy fixture needs `design-01`.

| Remaining script | Category / owner | Root cause / scope | Evidence log |
|---|---|---|---|

| `tests/boot_splash_export_test.gd` | export-workflow / `qa-12` | Missing invocation fixture: explicitly requires an exported PCK and an empty project. A source-tree launch fails its precondition; no exported artifact was provided. Requires an export workflow, not an assertion rewrite. | [log](../output/qa-08/quarantine-check/boot_splash_export_test.gd.log) |

| `tests/card_presentation_export_test.gd` | export-workflow / `qa-12` | Missing invocation fixture: requires an actual exported/imported texture PCK and an empty project. A source-only pack would not test the exported texture-import contract. Requires export integration. | [log](../output/qa-08/quarantine-check/card_presentation_export_test.gd.log) |

| `tests/combat_board_navigation_test.gd` | needs-design / `design-01` | Zoom anchoring fails the <=1 px geometry contract. Other navigation checks pass. Needs framing/zoom investigation with renderer proof; changing the expected coordinates here would choose player-visible behavior. | [log](../output/qa-08/quarantine-check/combat_board_navigation_test.gd.log) |

| `tests/combat_boundary_equivalence_test.gd` | stale-reference / `qa-09` | Frozen OriginalRunEngine/OriginalCombatEngine copies disagree with current checkpoints (12 assertions), and the display fixture no longer consumes its one-shot modifier. Requires updating the independent reference to the current save/deck/clock contracts; assertions retained. | [log](../output/qa-08/quarantine-check/combat_boundary_equivalence_test.gd.log) |

| `tests/combat_hud_badges_test.gd` | needs-design / `design-01` | Fixture expects INTENTS [I]/INTENTS ON [I] and the former controller-tooltip contract. These expectations predate the current HUD presentation. Needs the design owner's current UI contract; no copy or layout changed. | [log](../output/qa-08/quarantine-check/combat_hud_badges_test.gd.log) |

| `tests/committed_hand_queries_test.gd` | stale-reference / `qa-09` | One mixed revealed/hidden forecast fixture no longer reports unrevealed_before_player; prepared and synchronous results still compare equal. Requires rebuilding the scheduled hidden-enemy fixture without weakening that assertion. | [log](../output/qa-08/quarantine-check/committed_hand_queries_test.gd.log) |

| `tests/contextual_creature_motion_test.gd` | legacy-cutout / `qa-10` | Non-shipped historical experiment inputs under output/contextual-animation-polish/creatures/cases/crawler are absent (motion.gd, baseline_motion.gd and JSON). The script errors and never reaches quit. Needs a reproducible fixture or migration to the current approved rig. | [log](../output/qa-08/quarantine-check/contextual_creature_motion_test.gd.log) |

| `tests/cutout_rig_data_test.gd` | legacy-cutout / `qa-10` | Legacy Lightning Wisp motion reads crown, which the promoted maquette layout no longer contains. The test can print PASS after this script error; the task runner correctly fails it. Requires migration to the production maquette runtime. | [log](../output/qa-08/quarantine-check/cutout_rig_data_test.gd.log) |

| `tests/dragon_area_presentation_test.gd` | needs-design / `design-01` | Four Fire/Earth cancellation assertions fail against current committed-pattern behavior. This crosses authored counterplay rules; requires a dedicated encounter investigation/approved fixture update, not altered assertions. | [log](../output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) |

| `tests/dragon_pressure_escape_probe.gd` | long-diagnostic / `qa-11` | This is an exhaustive headless geometry/Time diagnostic, not a renderer probe. Its all-dragon/all-warning BFS sweep timed out first at 45 seconds, then at the normal 180-second program budget (180.050s, exit 124); no assertion verdict. Needs separately budgeted/partitioned diagnostic coverage before suite inclusion. | [log](../output/qa-08/quarantine-check/dragon_pressure_escape_probe.gd.log) |

| `tests/dragon_rewards_test.gd` | stale-reference / `qa-09` | Confirmed stale singleton-outbox expectation: the diagnostic observes has_run=false and exactly reward_claimed plus run_scored. The run clears and the claim persists; meta-01 added the second legitimate event. Existing assertion retained as requested; migrate the fixture to test the keyed claim independently. | [log](../output/qa-08/quarantine-check/dragon_rewards_test.gd.log) |

| `tests/en05_integration_sync_test.gd` | stale-reference / `qa-09` | Snapshot assumes the prior Gust Shrike front/rear source hashes and shadow roster. The approved rr-03 cutout promotion changed that presentation, so exact frozen shadow entries/additions no longer match. Needs a new approved baseline. | [log](../output/qa-08/quarantine-check/en05_integration_sync_test.gd.log) |

| `tests/equipment_inventory_readability_test.gd` | needs-design / `design-01` | Current equipment card labels fail the fixture's font-size/word-clipping limits (six named equipment pairs). Requires actual UI proof and owner-directed layout/copy decisions; no visual values changed. | [log](../output/qa-08/quarantine-check/equipment_inventory_readability_test.gd.log) |

| `tests/lightning_wisp_cutout_pack_test.gd` | legacy-cutout / `qa-10` | The transitive dependency fix exposes the older renderer's crown lookup and old skeleton-count assumptions against the promoted maquette assets. Package build succeeds; verification fails. Needs migration to the actual production maquette renderer, with the original coverage preserved. | [log](../output/qa-08/quarantine-check/lightning_wisp_cutout_pack_test.gd.log) |

| `tests/noncombat_move_equivalence_test.gd` | stale-reference / `qa-09` | Independent original movement reference omits new run_stats/Chronicle fields and differs on some encounter transitions. The log records 1,920 cases and exact differing keys. Requires a coordinated reference update for current run/encounter flow. | [log](../output/qa-08/quarantine-check/noncombat_move_equivalence_test.gd.log) |

| `tests/owned_combat_creation_equivalence_test.gd` | long-diagnostic / `qa-11` | Exhaustive run/tutorial/relic preparation matrix exceeds the existing 180-second program budget (exit 124, no final result). Initial 45-second timeout was rerun at the normal budget. Needs matrix partitioning/performance investigation; no success or gameplay-bug claim. | [log](../output/qa-08/quarantine-check/owned_combat_creation_equivalence_test.gd.log) |

| `tests/prepared_encounter_equivalence_test.gd` | stale-reference / `qa-09` | Frozen pre_battle_factory_reference no longer matches the complete current combat factory and invalidation inputs after run-flow changes. Twenty-four cases fail reference/state comparisons. Needs independent reference migration. | [log](../output/qa-08/quarantine-check/prepared_encounter_equivalence_test.gd.log) |

| `tests/prepared_equipment_combat_test.gd` | stale-reference / `qa-09` | Same frozen pre-battle factory mismatch across 144 equipment cases (1,625 checks). Updating only expected booleans would hide the migration; dedicated factory-reference work required. | [log](../output/qa-08/quarantine-check/prepared_equipment_combat_test.gd.log) |

| `tests/prepared_equipment_scene_handoff_test.gd` | stale-reference / `qa-09` | Prepared equipment scene callback/factory differs from the frozen original complete state (38 checks). Shares the outdated factory reference and requires end-to-end reference/ownership investigation. | [log](../output/qa-08/quarantine-check/prepared_equipment_scene_handoff_test.gd.log) |

| `tests/prepared_other_character_view_test.gd` | possible-bug / `bug-01` | Completes at the normal budget: 45 cases/1,116 checks, zero visual differences, one input-capture/cancellation ownership assertion fails. This is a potential real invalidation bug; requires a focused character-view ownership fix. | [log](../output/qa-08/quarantine-check/prepared_other_character_view_test.gd.log) |

| `tests/prepared_reward_choices_test.gd` | stale-reference / `qa-09` | Missing GameData preload fixed in its workload dependency. It now completes and exposes stale full-state comparisons with the independent reward reference across 20 cases (no pixel differences). Requires reference/committed-analytics reconciliation. | [log](../output/qa-08/quarantine-check/prepared_reward_choices_test.gd.log) |

| `tests/prepared_shop_glyph_equivalence_test.gd` | needs-design / `design-01` | Headless path still asserts that cancellation/show/detach crossed real native outline rendering. Needs headless cancellation semantics separated from actual-renderer proof; assertions retained. | [log](../output/qa-08/quarantine-check/prepared_shop_glyph_equivalence_test.gd.log) |

| `tests/prepared_travel_combat_test.gd` | stale-reference / `qa-09` | Complete travel preview/Begin/fallback comparisons disagree with pre_battle_factory_reference (24 cases). Same outdated independent factory reference; no production factory changed in this unit. | [log](../output/qa-08/quarantine-check/prepared_travel_combat_test.gd.log) |

| `tests/retained_character_deck_equivalence_test.gd` | stale-reference / `qa-09` | Fixture directly indexes the retired magic slot dictionary after deck-01 removed magic slots. Script error prevents completion. Requires migration to the approved spells-in-deck flow. | [log](../output/qa-08/quarantine-check/retained_character_deck_equivalence_test.gd.log) |

| `tests/retained_character_inventory_equivalence_test.gd` | possible-bug / `bug-01` | Normal-budget rerun completes: 117 cases and zero visual differences, but authoritative-state preservation assertions fail during equipment definition changes/boundary opens. Potential real ownership/mutation regression; dedicated fix required. | [log](../output/qa-08/quarantine-check/retained_character_inventory_equivalence_test.gd.log) |

| `tests/retained_section_map_equivalence_test.gd` | stale-reference / `qa-09` | Both current panel and old reference fixture are accessed through the removed _event_panel property. Script errors invalidate the printed errors=[]/exit-zero marker; task runner correctly rejects it. Requires fixture/API migration. | [log](../output/qa-08/quarantine-check/retained_section_map_equivalence_test.gd.log) |

| `tests/retained_shop_rows_equivalence_test.gd` | stale-reference / `qa-09` | Fixture indexes a missing sell:frostbolt row. deck-01 changed spells to the new purge/deck flow, so the legacy sell-row fixture no longer reaches its assertion boundary. Requires migration to that flow. | [log](../output/qa-08/quarantine-check/retained_shop_rows_equivalence_test.gd.log) |

| `tests/scavenger_visual_pass_4_test.gd` | stale-reference / `qa-09` | Controller trade assertion expects the inspected card purchase to appear in the old magic representation. Requires current deck/purchase fixture and native controller proof; no UI/input behavior changed. | [log](../output/qa-08/quarantine-check/scavenger_visual_pass_4_test.gd.log) |

| `tests/shop_retained_content_test.gd` | possible-bug / `bug-01` | Unchanged pack refresh loses the test's selected page. Concrete retained-shop pagination regression; needs a focused shop update (existing assertions preserved). | [log](../output/qa-08/quarantine-check/shop_retained_content_test.gd.log) |

| `tests/static_floor_cache_equivalence_test.gd` | possible-bug / `bug-01` | 102 cases/156,715 checks finish; empty-board restored presentation differs between retained/current and reference state. Needs cache presentation/empty-board restoration investigation, including native pixel proof. | [log](../output/qa-08/quarantine-check/static_floor_cache_equivalence_test.gd.log) |

| `tests/suites/dragon_area_presentation_suite.gd` | needs-design / `design-01` | Four Fire/Earth cancellation assertions fail against current committed-pattern behavior. This crosses authored counterplay rules; requires a dedicated encounter investigation/approved fixture update, not altered assertions. | [log](../output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) |

| `tests/surface_feedback_ui_test.gd` | needs-design / `design-01` | Legacy Fire-fuel copy assertion fails and an old dictionary-index expectation errors. Requires current approved surfaces/copy fixtures; no player wording or mechanics changed. | [log](../output/qa-08/quarantine-check/surface_feedback_ui_test.gd.log) |

| `tests/surface_query_handoff_test.gd` | stale-reference / `qa-09` | All three handoff modes differ only in analytics; the test compares an engine result to a scene boundary that stages/acknowledges analytics. Needs current committed-analytics reference reconciliation, retaining exact durable-save assertions. | [log](../output/qa-08/quarantine-check/surface_query_handoff_test.gd.log) |


## 4. Suite runtime and final verification


Feedback verification (current): fast audit passes with 373 covered / 33 quarantined / 312 native scripts. The first real slow guard correctly returned exit 1: `QUARANTINE CHECK: FAIL (34 entries; 33 programs; 1 now passing)`; `QUARANTINE RUNTIME: 391.387 seconds (4 workers)`. The objective-glyph pass was removed from quarantine and registered. All 33 current entries were exercised in that same run through 32 unique programs: 28 entries returned exit 1, five timed out at 180 seconds, and none passed. [Initial slow guard log](../output/qa-08/quarantine-check.log), [current-entry results](../output/qa-08/quarantine-check/current-results.json). No timeout is claimed as an assertion pass.

Full Python feedback verification: `Ran 690 tests in 657.690s`; `OK (skipped=63)`; `real 658.25`, exit 0 ([log](../output/qa-08/python-feedback.log)). Integrated Godot verification and the ≤600s target measurement await the design owner's qa-07 merge. The prior complete-suite attempts below are historical evidence and do not establish a current integrated pass.


Baseline Python: `Ran 670 tests in 609.309s`; `OK (skipped=63)`.

Baseline Godot: the existing full suite exceeded its 900-second outer runner budget, exit 124, before its final result. The last completed program was sfx_sync_bank; its following SFX harness did not complete before the outer deadline. This is not a newly registered orphan. [Baseline log](../output/qa-08/godot-baseline.log).

Python: `Ran 680 tests in 584.411s`; `FAILED (failures=1, skipped=63)`; `real 585.04` [log](../output/qa-08/python-final.log).

Godot (two-worker full-suite attempt): `SUPPLEMENTAL RUNTIME: 352.702 seconds (2 workers; 693.842 process seconds)`; `error: command timed out after 900 seconds.`; `real 900.10` [log](../output/qa-08/godot-final.log).

Final four-worker supplemental group: `SUPPLEMENTAL RUNTIME: 186.710 seconds (4 workers; 725.943 process seconds)`; `real 187.62` [log](../output/qa-08/supplemental-final.log).

All 115 supplemental program tests passed in both the two-worker full-suite phase and the final four-worker CLI run (exit 0). The final default phase took 186.710 seconds; the earlier two-worker phase took 352.702 seconds. These are phase timings under different background load, not a matched complete-suite benchmark.

The four-worker supplemental program phase is the measured added work for the final default (the full-suite attempt used two workers). A matched complete-suite delta is unavailable because the original full suite already exceeds its 900-second outer budget. That earlier strict-guard failure is resolved by the explicitly owned quarantine policy; the current focused guard has 20 passing tests. Current full Python feedback verification passes as recorded above.

Focused checks: skill progression `TEST RESULT: PASS`; analytics context `TEST RESULT: PASS — 42 analytics-context/boundary comparisons (0 failures)`; hover `TEST RESULT: PASS — board hover input-batch coalescing`; migration parser check `TEST RESULT: PASS migrated presentation probe scripts`; capture settings and movie guard both PASS; 19 per-creature package build/verify fixtures and four package builders PASS. The current guard behavior regressions and repository completeness assertion pass with the explicit quarantine entries.

## Proof for the design owner

No new player-facing change, capture script, proof image, or playable inspection fixture is required for this test/tooling unit. Existing renderer-only checks were not attempted (no window-server access). To run their native checks on the design owner's machine:

```bash

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 180 tests/death_transition_test.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 180 tests/deferred_reconciliation_queue_test.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 180 tests/deferred_run_skill_analytics_test.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 180 tests/deferred_skill_analytics_test.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 180 tests/skill_ui_test.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-08 && python3 tools/visual_probe_runner.py --task-id qa-08 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 1 --timeout 180 tests/objective_glyph_equivalence_test.gd

```

The objective-glyph script explicitly settles a 1920×1080, 100% scale native window and emits objective_glyph_actual.png in its isolated user directory. The other existing scripts own their original native fixture sizes; no capture acceptance evidence was produced here. No windowed success or capture path is claimed. No inspection_fixture.py command was requested by the brief; the design owner owns that workflow.

## TODO_DESIGN placeholders

None. No missing player-perceived value was invented.

## Chosen defaults

Four supplemental workers and the 180-second child cap now follow the explicit feedback (three workers for the initial exploratory sweep); 30-second package phase bound; initial one-shot audit bound 45 seconds. The objective ownership fixture uses `OWNERSHIP_SLICE_DELAY_USEC = Glyphs.SLICE_USEC + 1` (4,001 microseconds) to force a real slice boundary without a machine-speed assumption. The capture-only MJPEG/video quality override is 1.0, matching the existing capture-settings test contract, in a private project. Pack/temp paths and the minimal project config are test fixtures. The full suite's existing 900-second budget is preserved.

## Open issues

qa-07 is not present in this checkout (HEAD remains `723104fe4`). The original 115 registrations plus the newly passing objective-glyph program stay isolated in `headless_test_programs.json` until the design owner merges qa-07, then they must join its four-worker manifest without a second nested scheduler. The post-integration full-suite wall time (target ≤600s; hard cap 900s) cannot be measured before that merge. Prior full-suite timeout evidence is retained above. No peer review or sign-off was requested or run.


## Files changed

- [output/qa-08/.gdignore](../output/qa-08/.gdignore)

- [output/qa-08/.gitignore](../output/qa-08/.gitignore)

- [tests/acolyte_cutout_pack_test.gd](../tests/acolyte_cutout_pack_test.gd)

- [tests/all_surface_performance_workload.gd](../tests/all_surface_performance_workload.gd)

- [tests/bile_bloomer_cutout_pack_test.gd](../tests/bile_bloomer_cutout_pack_test.gd)

- [tests/board_hover_coalescing_test.gd](../tests/board_hover_coalescing_test.gd)

- [tests/chainbound_gaoler_cutout_pack_test.gd](../tests/chainbound_gaoler_cutout_pack_test.gd)

- [tests/cinder_droplet_cutout_pack_test.gd](../tests/cinder_droplet_cutout_pack_test.gd)

- [tests/cinder_ooze_cutout_pack_test.gd](../tests/cinder_ooze_cutout_pack_test.gd)

- [tests/combat_analytics_context_equivalence_test.gd](../tests/combat_analytics_context_equivalence_test.gd)

- [tests/crawler_cutout_pack_test.gd](../tests/crawler_cutout_pack_test.gd)

- [tests/frostglass_lancer_cutout_pack_test.gd](../tests/frostglass_lancer_cutout_pack_test.gd)

- [tests/grave_surgeon_cutout_pack_test.gd](../tests/grave_surgeon_cutout_pack_test.gd)

- [tests/gust_shrike_cutout_pack_test.gd](../tests/gust_shrike_cutout_pack_test.gd)

- [tests/harrier_cutout_pack_test.gd](../tests/harrier_cutout_pack_test.gd)

- [tests/headless_test_programs.json](../tests/headless_test_programs.json)

- [tests/helpers/source_script_pack.gd](../tests/helpers/source_script_pack.gd)

- [tests/helpers/supplemental_program_suites.gd](../tests/helpers/supplemental_program_suites.gd)

- [tests/iskaldra_cutout_pack_test.gd](../tests/iskaldra_cutout_pack_test.gd)

- [tests/lightning_wisp_cutout_pack_test.gd](../tests/lightning_wisp_cutout_pack_test.gd)

- [tests/noctyrax_cutout_pack_test.gd](../tests/noctyrax_cutout_pack_test.gd)

- [tests/protagonist_cutout_pack_test.gd](../tests/protagonist_cutout_pack_test.gd)

- [tests/qa_08_test_audit.md](../tests/qa_08_test_audit.md)

- [tests/qa_08_test_inventory.md](../tests/qa_08_test_inventory.md)

- [tests/run_tests.gd](../tests/run_tests.gd)

- [tests/runtime_frame_performance_benchmark.gd](../tests/runtime_frame_performance_benchmark.gd)

- [tests/skill_progression_analytics_test.gd](../tests/skill_progression_analytics_test.gd)

- [tests/stone_warden_cutout_pack_test.gd](../tests/stone_warden_cutout_pack_test.gd)

- [tests/test_test_registration_audit.py](../tests/test_test_registration_audit.py)

- [tests/tharokh_cutout_pack_test.gd](../tests/tharokh_cutout_pack_test.gd)

- [tests/vaeloryx_cutout_pack_test.gd](../tests/vaeloryx_cutout_pack_test.gd)

- [tests/veilbound_acolyte_cutout_pack_test.gd](../tests/veilbound_acolyte_cutout_pack_test.gd)

- [tests/vyraketh_cutout_pack_test.gd](../tests/vyraketh_cutout_pack_test.gd)

- [tests/windowed_test_allowlist.json](../tests/windowed_test_allowlist.json)

- [tests/zekarion_cutout_pack_test.gd](../tests/zekarion_cutout_pack_test.gd)

- [tools/test_registration_audit.py](../tools/test_registration_audit.py)

- [spec/development_workflow.md](../spec/development_workflow.md)

- [tests/quarantine.json](../tests/quarantine.json)

- [tests/objective_glyph_equivalence_test.gd](../tests/objective_glyph_equivalence_test.gd)
