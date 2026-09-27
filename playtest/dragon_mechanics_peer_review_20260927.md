# Dragon feedback: independent mechanics/presentation review — 2026-09-27

Reviewer: reward/NPC worker. Result: no actionable defect found in the bounded
scope below. This is a read-only review of the uncommitted feedback snapshot on
`44e856d0432aa9b299060022c30d22bbe125d098`, not exact-HEAD signoff or publication
approval. The production/Godot freeze was respected; only this review note was
written. No Godot process, test run, staging, or commit was performed here.

## Independently reviewed scope

- `data/enemies.json` dragon action changes; `dragon_combat_rules.gd`,
  `guardian_combat_rules.gd`, and `committed_pattern_shapes.gd`: declaration,
  held direction/path, dynamic ring range, swept-path geometry, live charge
  snapshot filtering, route-preserving spire selection, owned Ice replacement,
  current and legacy Noctyrax snuff/relight behavior.
- Enemy-only changes in `combat_engine.gd`: resolved-path carry in all three
  enemy resolution entry points, threat/step construction, damaging Meteorfall,
  Crystal Mantle break events, spire creation events, summon scheduling and
  caps, player-arrival brazier hook, legacy Eclipse snuff guard, the
  `no_conduction` gate, and nearest-body radial forced movement. Player trophy,
  relay, cost and payment changes are excluded below.
- `data/cards.json` Gust Step reorder/required attack against the existing
  move-and-attack shortcut. The direct-attack type list already includes Pull;
  the focused test exercises a real single enemy click through RunScene.
- `dragon_presentation.gd` profile/direction/pose mapping only (not `tiles()`),
  `dragon_spell_presentation.gd`, `dragon_board_props.gd`, `attack_fx_library.gd`,
  and the dragon changes in `combat_outcome_feedback.gd`.
- Dragon-only RunScene enemy action playback, utility playback, contact timing,
  board motion mapping, immutable step application, Mantle feedback, boss status
  row/banner layout; corresponding combat-board area/depth FX, muzzle source,
  procedural spire rendering, intent row geometry, refuge markers, and shared
  action-icon rule text. Art assets and individual cutout rig/motion revisions
  remain the cutout reviewer's separate scope.
- Relevant focused fixtures in `dragon_feedback_mechanics_test.gd` and
  `dragon_committed_patterns_test.gd`, plus the unowned presentation probe
  action-stage and compound-action expectations. My queue assertion change is
  explicitly excluded from independent approval.

## Checks and conclusions

The live preview and resolver use the same geometric helpers. Movement stores
its actually resolved path into the activation context before later swept
attacks and their animation steps; a blocked route cannot retain its unreachable
landing. Ring distance uses the whole body. Iskaldra's current layers adjust the
ring before resolution, all remaining layers are then consumed, and old Whiteout
Ice is retired only when its source still belongs to that dragon. The focused
fixtures exercise blocked Dive, off-anchor trap cost, layer peeling, full lanes,
and replacement by player-owned Ice.

Overload keeps the announced charge snapshot, drops charges that were replaced,
and bypasses automatic Lightning conduction. Later charges neither enlarge its
warning nor its damage/consumption. The tests cover disconnected charges, later
additions, removal, single damage and surviving later ground.

The shared dragon summon path schedules each surviving new helper once, beyond
the already booked player turn where necessary, while retaining a later normal
activation. The Wisp/Acolyte reaction fixture covers a long player delay; the
separate actual-clock Wisp fixture covers serialization and a subsequent attack.
Noctyrax uses current Night Coil snuff followed by player-arrival relighting;
explicit legacy flags preserve already announced saved warnings. Current and
legacy copy branch on those same flags/verbs.

Action-level presentation keeps Stonewake/Mantle utility and their secondary
strikes distinct, and likewise separates Call Wisps/Eclipse from their summons.
Resolved step snapshots drive displayed state without rerunning combat. Full
areas are drawn cell by cell, reduced motion uses static feedback, and the final
state has existing real Pass/queue evidence. I found no newly added bare literal
assignment to `Array[T]` or literal conditional branch in the changed/new GDScript
lines scanned. This static check is not a Windows runtime certification.

## Evidence inspected and limits

I read the actual integrated runner log for
`dragon-boss-encounters-milestone-rewards-1790536614403264000-33594`: it ends in
`TEST RESULT: PASS`, with the documented migration and ObjectDB cleanup warnings.
The verified exit-0 receipt is retained in
[the integrated note](dragon_feedback_integrated_suite_20260927.md).

I checked the accepted Metal manifests: feedback03 (167 images), queue04 (167),
fan02 (6), Thar-order01 (9), and legacy-refuge01 (3), all accepted return code 0.
The owning [presentation note](dragon_presentation_feedback_notes.md) and
[scoped review](dragon_feedback_static_review_20260927.md) distinguish semantic
coverage from pixel inspection. I did not independently re-inspect those full
image sets in this review. Earlier feedback03 proves eight real state fields;
queue04 supplies the corrected real `turn_queue` comparison, whose assertion I
authored and therefore cannot independently approve.

The [acceptance matrix](dragon_feedback_revision_20260927.md) now records all six
completed, audited native acquired-build studies and their limits. I did not
operate those native fights and do not promote those cohorts into general
multi-build balance or continuous-descent evidence. Final seven stable-source
cutout receipts, a committed exact-HEAD composite review and verified inspection
fixtures are separate remaining gates. No new implementation gap was identified
by this review.

## Authorship exclusions for composite review

The following current changes were authored by this reviewer and require another
reviewer; sharing a file with the reviewed enemy code does not erase this boundary.

- Entire new `scripts/dragon_trophy_rules.gd`; current changes to
  `scripts/dialogue_engine.gd`, `scripts/progression_store.gd`,
  `scripts/run_engine.gd`, `scripts/card_widget.gd`, and
  `scripts/chain_attack_feedback.gd`.
- `scripts/combat_engine.gd`: player ranged/ground/conductor targeting, relay
  preparation versus Worldroot payment, card Time reserve handling, relay trace
  capture/delivery and the primary-origin Chain displacement correction.
- `scripts/game_data.gd`: trophy preload and card Time-preview hook (the separate
  balance-revision identifier is root-owned).
- `scripts/run_scene.gd`: reward acquisition/map transition; Man dialogue/service,
  input and dialogue-status changes; relic counter/hand cache; player relay
  animation hook. Boss animation/status methods reviewed above are unowned.
- `data/relics.json`: Winter's Hourglass and Stormroad Coil entries, including
  their four later inline icon substitutions. Crowncoal/Worldheart are root-owned.
- `scripts/dragon_presentation.gd`: only the explicit-empty-area `tiles()` repair.
- Reward/trophy focused tests and renderer probes; the canceled-area suite,
  launcher and renderer probe; the real-queue assertion in
  `tests/dragon_presentation_feedback_probe.gd`; the five shared test repairs in
  `tests/run_tests.gd`: `_test_run_scene_offers_pass_when_hand_dead`,
  `_test_run_scene_selection_prompts_clear_after_pick`,
  `_test_run_scene_campfire_choices_use_relic_overlay`,
  `_test_run_scene_campfire_choice_press_is_single_shot`, and
  `_test_run_scene_auto_triggers_starting_npc_dialogue`.
- Owning reward/trophy/canceled-area notes and the corresponding trophy/NPC
  specification, analytics, persistence and balance/scorer additions. This note
  does not independently approve my earlier evidence or documentation edits.

## Reviewed source snapshot (SHA-256)

Whole-file hashes bind the snapshot; they do not expand the partial-file scope
above or approve excluded authored sections.

```text
3b92f61f1a4dd4d2b75f6eb709feaeab921cb260dd7bcea8c0446afd724efaa1  data/cards.json
5c6b9bf929a9860d6870c082c9df14b272ef74b8617551eba4f5aa1310ee4ef9  data/enemies.json
95aea02b57924737287603adb8b42f706f557e14b88f83f59ca63a0f6fc344ce  scripts/dragon_combat_rules.gd
d0271fcadbd0d48a2c03e94375ea75a3c89a9456c3eabbe915a5c669c47a5cc8  scripts/guardian_combat_rules.gd
58a26faaec461f35e9b68e91c1bdf120bcd0eada2d0712dae05b9b961920d4f3  scripts/committed_pattern_shapes.gd
0e313b9342d300bb3d319ca9e512e84a89e1911b8a89cd2594da2701cb8a6135  scripts/combat_engine.gd
85fc67256ea602933f004f0fb4705db3bf3d8fc688db61aa51c866eb63750422  scripts/dragon_presentation.gd
50fc426d767247bdec56af75d1701db4dab6e2b07b37eb7dce451307e30c1f68  scripts/dragon_spell_presentation.gd
022d5e93c5d6d4f4f2a7c41e4c0b1edb008c7e3a912fe91f250093dfd59e449e  scripts/dragon_board_props.gd
5092306c7e6d38667f83c80aca6f072aa88cfc46ccd71acc62cb2bc2a2e5de27  scripts/run_scene.gd
b5f786c3abf9e0ca2d50885b1c914f519a7936ac9f40d8b20bfb42bb1fe05574  scripts/combat_board_view.gd
f09eec1b1d043808ae026215d88d809a10413d3a69e6eff0f40f77e5d7855121  scripts/attack_fx_library.gd
4ef07ba8839f45a4d2311f53bb81f99502a4240a0f089aa036a9e095273b7aeb  scripts/combat_outcome_feedback.gd
ef49c1d2ca52f666a9400ccacc2baf221053b6294050a23e28fb730cf02ffb9a  scripts/action_icon_library.gd
d7c334f2eba86251836a5286cddfa9dbaf0a6d14fcbb1c888034d69229d84ba8  tests/dragon_committed_patterns_test.gd
de277d55b6fb12b9cf228e2325b6b3c6c40546eff5b890da541927039e282492  tests/dragon_feedback_mechanics_test.gd
```
