# qa-136 save migration and Chronicle repair

The release witness ran at `c6d0e65fc`. Three installs on qa-136 preserved the profile bytes. The Chronicle read the two damaged release records and preserved their source bytes. The worktree changes are uncommitted.

## Implementation

| Requirement | Result |
| --- | --- |
| 1. Preserve current IDs | The walk builds one set from the current catalogs. Bare IDs and namespaced IDs survive as dictionary keys and values. The catalogs include cards, gear, relics, enemies and their intents, events and their choices, omens, NPCs, upgrades, skills, Grimoire entries, biomes, elements, opening boons, special encounters, battlefield rules and glossary entries. |
| 2. Exclude saved Chronicle records | The walk skips the whole `chronicle_records` subtree in the profile and in embedded progression. It also skips printed score rows, stored killer names and queued profile analytics. |
| 3. Preserve legacy migration | The seven retired IDs keep their mappings. Profile migration applies exact bare and namespaced mappings. The free-text neutralizer and legacy composite replacements run only on checkpoints flagged by `run_content_migration_required`. The audit found no profile prose that relies on the neutralizer. In a dictionary collision, an existing canonical key and its value take precedence. |
| 4. Repair Chronicle presentation | Current names and intent names supply reverse matches for the historical regex. A uniquely reversible printed name is replaced in the view. Relic and card IDs resolve in their own catalogs, with live IDs checked first. The deck retains counts and recorded card deltas. The panel uses the same display data for its tiles, tooltips and art preparation. |
| 5. Preserve discoveries and counts | The Grimoire filters unknown IDs through its existing catalog lookup for lists, search totals and unread badges. Profile writes retain these IDs. A rediscovery writes the valid ID alongside the damaged entry, and the valid page stays available across later installs. |

### Changed functions and line ranges

| File | Functions and lines |
| --- | --- |
| `scripts/renamed_content_vocabulary.gd` | `neutralizer`, `catalogs`, `nested_definitions`, `catalog_ids` (17–51) |
| `scripts/run_engine.gd` | `migrate_profile_content_ids`, `migrate_renamed_content_ids`, `_migrate_content_ids`, `_replace_renamed_content_ids`, `_profile_snapshot_field` (704–788). The seven-entry map is at 722–731. |
| `scripts/run_scene.gd` | `_load_run_state` profile migration and Grimoire merge (9620–9627) |
| `scripts/chronicle_rules.gd` | `enter_room` and `build_record` use the existing section-name fallback at write time (57–106). `display_killer_text`, `display_section_name`, `display_printed_text`, `_prepare_printed_name_repairs`, `display_build` and item resolution (149–269). `result_word` (435–438). |
| `scripts/chronicle_panel.gd` | `_prepare_record_art` and `_build_detail` use resolved display entries and printed names (269–296, 361–452) |
| `scripts/grimoire_library.gd` | `_ensure_progression_state_in_place`, `_ensure_run_state_in_place`, `unlock_entries`, `clear_unread` and the alias/retention helpers (378–485, 544–573) |
| `tests/chronicle_test.gd` | `_test_legacy_content_save` (178–292) |
| `tools/qa136/` | `witness.gd` and its UID, `release_profile.json`, `native.sh`, this report and the capture contract |

### Chronicle ambiguity and catalog precedence

- The release regex collapsed both `ashen_brand` and `ashen_phylactery` to `cinder`. Both release records omit that entry. The regression independently demonstrates resolution to Ashen Brand with the corresponding stored icon path and to Ashen Phylactery with the corresponding stored name. The display reads optional per-entry `relic_icon_paths` and `relic_names` by their saved relic positions. Missing evidence and conflicting unique evidence both leave the slot out of the view.
- `liturgy_of_cinder` maps uniquely to `liturgy_of_ash`. Both release records display **Liturgy of Ash** with `res://assets/art/relics/liturgy_of_ash.png`.
- The printed forms `cinder Hound` and `cinder Reaver` map uniquely to Ash Hound and Ashen Reaver. Intent names use the same rule. Raking Flame in the release fixture retains its authored spelling. The current intent catalog has zero names beginning with the legacy prefix.
- No live catalog entry has the exact ID `cinder`. Current IDs beginning with `cinder` include cards `cinder_bloom`, `cinder_fusillade`, `cinder_patch`, `cinder_second`, `cinder_trail`, `cinder_wall`, `cinderburst`, `cinderline_tempo` and `cinderweave_guard`, gear `cinderweave_mail`, relic `cinderbrand_tongs`, enemies `cinder_droplet` and `cinder_ooze`, event `cinder_supplicant`, and intents `cinder_bloom`, `cinder_maw` and `cinderfall`. Their Grimoire and namespaced forms draw the current content. The regression checks `cinder_wall` and an isolated catalog entry with the exact ID `cinder`.

### Profile fields that contain content references

| Profile field | Migration and read behavior |
| --- | --- |
| `grimoire_unlocked`, `grimoire_unread` | Exact retired aliases migrate. Current discovery IDs and unknown remnants remain stored. The display counts only resolved entries. Rediscovery adds the valid ID. |
| `skill_ids` | Current skill catalog IDs are protected. Existing skill selection normalization still owns the legal build and refunds. |
| `heirloom_equipment` | Current equipment IDs are protected. Heirloom storage was introduced after the seven-ID rename. The existing equipment-catalog lookup owns validity. |
| `starting_relic_gifts[].relic_id` | Current relic IDs are protected. Gift reads already validate relic IDs through the relic catalog. Gift receipt IDs are separate from content identity. |
| `chronicle_records` | The saved `gear`, `relics`, `deck`, `deck_card_definitions`, `dragon_ids`, path and printed fields are outside the migration walk. Repairs are view-only. |
| `last_run_result`, `completed_run_results` | The walk protects current `killer.enemy_type`, `killer.intent_id`, `killer.surface` and `biome` IDs. Printed `lines`, `feats` and `killer.name` are skipped. |
| `progression_analytics_outbox` | Queued historical payloads and context can contain catalog IDs. The entire queued snapshot is skipped. |
| Retired `purchased_upgrades`, `card_upgrades`, `card_mods` | Progression normalization already settles and removes these legacy card and upgrade references before the install walk. |

`run_bests` and the result ledger's `stats` and `new_bests` use fixed metric IDs. `umbra_depth_best_scores` uses numeric depth keys. `chronicle_totals` uses aggregate counters. There is no current profile counter keyed per enemy, card or relic. Run, wallet, gift, award and completion receipts identify transactions. The retired `recent_events` field is removed by existing profile normalization.

## Receipts

| Check | Observed result |
| --- | --- |
| Release witness | `QA136 RELEASE INSTALL WITNESS: PASS`. Each install reported `profile bytes identical=false`. The diff shows both killer names, both relic cases, the discovery lists and the catalog-key collisions. [Full diff](../../output/qa136/witness-release.log) |
| Branch witness | `QA136 BRANCH INSTALL WITNESS: PASS`. Each install reported `profile bytes identical=true`. `QA136 Chronicle source profile bytes identical=true`. [Log](../../output/qa136/witness-branch.log) |
| Legacy and save regression | `CHRONICLE TEST RESULT: PASS`. The regression exercised all seven mappings in an installed legacy checkpoint and profile, historical text and IDs, actual tiles, matching evidence, and rediscovery followed by three installs. [Log](../../output/qa136/chronicle.log) |
| Surface save migration | `Surface migration checks: PASS`. [Log](../../output/qa136/save.log) |
| Grimoire | `GRIMOIRE PERFORMANCE RESULT: PASS` and `GRIMOIRE SEARCH PROBE RESULT: PASS`. [Performance log](../../output/qa136/grimoire.log), [headless search log](../../output/qa136/grimoire-search.log) |
| Parse | `QA136 PARSE PASS scripts/run_scene.gd`, `QA136 PARSE PASS scripts/chronicle_panel.gd`, `QA136 PARSE PASS tools/qa136/witness.gd`. [Log](../../output/qa136/parse.log) |
| Python default | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 27.877s`, `OK`. Includes rules-text lint. [Log](../../output/qa136/python-default.log) |
| UI identity lint | `Ran 25 tests in 5.563s`, `OK`. [Log](../../output/qa136/ui-identity.log) |
| Proof files | `QA136 PROOF FILE CHECK: PASS`. Shell syntax and capture filenames match the release fixture. |
| Native fixture dry run | `QA136 NATIVE FIXTURE HEADLESS DRY RUN: PASS`. The live Chronicle controls reported both killer lines and the existing Liturgy of Ash icon. [Log](../../output/qa136/native-dry.log) |

The macOS certificate diagnostic `Condition "ret != noErr" is true` appeared in both the release and branch headless runs. The release and branch install witnesses emitted an ObjectDB exit warning. The Chronicle regression, which installs a RunScene, also emitted that warning. Python passed and reported a denied write to the shared Git timing cache.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-136 && tools/qa136/native.sh
```

The launcher uses the visual probe runner with `LABYRINTH_CEL_LOOK=all`, a 1920×1080 SubViewport and 100% UI scale. Expected captures are `user://qa136/1920x1080/qa136-ambiguous.png` and `user://qa136/1920x1080/qa136-reaver.png`. The runner resolves the isolated user paths and records them in `output/qa136/native-result.json`. Native captures and visual inspection are pending because this session has no window-server access.

## Chosen defaults

- Proof-only run seed `FIXTURE_SEED` and `ASH_TEST_SEED` are 6, matching the demo audit. The witness waits four process frames between selections and uses the pre-battle fixture's 4× MSAA.
- The debug-only records use the run IDs `qa136-ambiguous` and `qa136-reaver`, score 136, two of four rooms, Training Sword and Pale Spark. The existing run-scene install and the production Chronicle panel provide the rest.
- The regression creates an isolated synthetic card `ash_qa136_spell` using an existing card definition, plus a temporary exact `cinder` entry to check live-ID precedence.

No new `TODO_DESIGN` placeholders.
