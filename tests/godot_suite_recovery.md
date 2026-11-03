# Godot suite recovery (test-02)

The quarantine is empty. The registration CLI rejects non-empty quarantine data.
The table records each of the original 29 entries; shared library entrypoints are
listed independently so no quarantine entry disappears without a disposition.
The tests retain functional assertions in the default suite. Native-only glyph
outline checks remain conditional on an actual renderer in the same dual-mode
fixture. No art, tuning, reward amounts, wording data or save schema changed.

| Original entry (`tests/`) | Outcome | Reason and regression coverage |
|---|---|---|
| `boot_splash_export_test.gd` | Deleted | Requires an exported PCK and empty-project invocation; that workflow is not run by this suite. Source launches do not test the export contract. |
| `card_presentation_export_test.gd` | Deleted | Requires exported/imported textures in a supplied PCK; a source-only substitute would be invalid proof. |
| `combat_board_navigation_test.gd` | Product fixed; readmitted | Pointer anchoring used the viewport centre despite scale-dependent room framing. Use the actual old and new board origins; the existing one-pixel assertion passes. |
| `combat_boundary_equivalence_test.gd` | Stale fixture updated; readmitted | Retain independent deep-copy paths, migrate score/checkpoint fields and the moved display helper, and inject the synthetic effect into the display service's actual resolver. |
| `combat_hud_badges_test.gd` | Stale fixture updated; readmitted | Check the approved Details label/tooltips and relic glossary stack, including the live reserve counter; retain passive-frame/controller assertions. |
| `committed_hand_queries_test.gd` | Stale fixture updated; readmitted | The old 20-Time fixture is clamped to 12 and permitted a repeat before the delayed player. Use a zero-spent-Time player and a legal 12-Time intent to isolate the intended hidden follow-up. |
| `contextual_creature_motion_test.gd` | Deleted | Tests absent, non-shipped historical experiment outputs and baseline motion rather than the production rigs. Current rig/runtime suites remain registered. |
| `cutout_rig_data_test.gd` | Stale fixture updated; readmitted | Remove the retired legacy Wisp mesh-loader case. The production Wisp uses the maquette runtime, covered by `maquette_cutout_test.gd`; retain all current shared mesh-loader cases. |
| `dragon_area_presentation_test.gd` | Stale fixture updated; readmitted | Crownfire and Faultline gained authored ordinary follow-ups. Isolate the cancelable area action; retain empty-area, no-area-damage and ranged-impact assertions. Full intents remain covered by `dragon_committed_patterns_test.gd`. |
| `dragon_pressure_escape_probe.gd` | Readmitted with measured timeout | Complete 48-warning geometry diagnostic passed in 169.930 s outside the full pool; previously exceeded 180 s under load. Independent cap: 600 s. |
| `dragon_rewards_test.gd` | Stale fixture updated; readmitted | Count the keyed claim alongside legitimate `run_scored` events. Receipt-recovery fixtures complete their heirloom choice; a separate case verifies that a pending choice intentionally retains the terminal save. Bank, gift, exact-once append, blocked-save retry and replay checks pass. |
| `en05_integration_sync_test.gd` | Deleted | Retired wave-E2 merge-provenance snapshot freezes superseded tuning and pre-promotion shadow sources. Current enemies and promoted runtime integration remain covered by `en05_elemental_test.gd`, `en05_live_integration_test.gd` and cutout/cache suites. |
| `equipment_inventory_readability_test.gd` | Product fixed; readmitted | Inventory rows clipped granted-card names and used 13 px captions. Wrap the full names and use the approved shared 14 px caption floor. All six gear pairs, consumables, focus, drag and equip assertions pass. |
| `lightning_wisp_cutout_pack_test.gd` | Deleted | Packages the retired six-bone renderer and nonexistent crown. The shipped Wisp is the promoted maquette runtime, already tested by its production suite. |
| `noncombat_move_equivalence_test.gd` | Stale reference updated; readmitted | Keep the eager/discarded-work oracle, adding current score, Chronicle, mystery and special-room entry contracts. Preserve complete-state, mutation and work-count comparisons. |
| `owned_combat_creation_equivalence_test.gd` | Stale reference updated; readmitted | The independent serial factory now carries current initial fields and shared gameplay initialization; it remains independent of the cooperative cursor. Full matrix passed in 129.339 s. Independent cap: 600 s for load. |
| `prepared_encounter_equivalence_test.gd` | Stale reference updated; readmitted | Use current encounter metadata and serial factory fields while keeping uncached room generation and complete state/RNG comparisons. |
| `prepared_equipment_combat_test.gd` | Stale reference updated; readmitted | Same serial factory migration; preserve all equipment cases and invalidation/ownership assertions. |
| `prepared_equipment_scene_handoff_test.gd` | Stale fixture updated; readmitted | Use the migrated factory and a fixed fixture play clock so elapsed wall time cannot invalidate an otherwise exact ready future. Retain identity/adoption and cancellation assertions. |
| `prepared_reward_choices_test.gd` | Stale fixture updated; readmitted | Sequential scene comparisons now share a fixed play clock; all complete-state, RNG, save, fallback and ownership assertions remain. |
| `prepared_shop_glyph_equivalence_test.gd` | Stale fixture updated; readmitted | Headless mode verifies cancellation, suspension, ownership, cache/fallback semantics and teardown. Native mode additionally requires actual outline rasterization and exact pixels. |
| `prepared_travel_combat_test.gd` | Stale reference updated; readmitted | Shared eager factory migration preserves current encounter metadata and full preview/Begin/fallback comparisons. |
| `retained_character_deck_equivalence_test.gd` | Stale fixture updated; readmitted | The spells tab replaced its old slot/deck panel with a deck list. Retain Gear deck-group identity comparisons; current spells/purge behavior is covered by `magic_deck_test.gd`. |
| `retained_section_map_equivalence_test.gd` | Stale reference updated; readmitted | Rebuild fresh nodes using current approved geometry/input primitives, removing retired event/Continue/legend properties. Retain exact snapshots, focus, callbacks, bounded ownership and teardown checks. |
| `retained_shop_rows_equivalence_test.gd` | Product fixed and stale fixture updated; readmitted | Replace the retired spell-sell fixture with a consumable. Freed retained Variants must be checked before casting; paging/filtering now survives external owner teardown without script errors. |
| `scavenger_visual_pass_4_test.gd` | Stale fixture updated; readmitted | Purchased spells now enter `attuned_magic_cards`, not the removed reserve. Controller purchase/input assertions remain. |
| `suites/dragon_area_presentation_suite.gd` | Stale fixture updated; readmitted through wrapper | Same isolated area-action regression as `dragon_area_presentation_test.gd`; executed once through that entrypoint. |
| `surface_feedback_ui_test.gd` | Stale fixture updated; readmitted | Use approved “Expended:” condition text. Remove the retired reserve-to-slot magic drag subcase; retain all current card/intent/equipment/proxy checks and current deck coverage. |
| `surface_query_handoff_test.gd` | Stale fixture updated; readmitted | Compare exact engine and durable save state at action completion, before rendered-frame analytics staging. Reduced motion can finish before preparation and uses the synchronous fallback; normal adoption and cancellation assertions remain. |

`skill_progression_analytics_test.gd` was already registered. Its complete current
terminal reward -> Continue -> profile-outbox recovery test passes unchanged,
including the resumable-run clear. The earlier two noted failures do not
reproduce on this base.

The dragon investigation found no lost or duplicated reward: a final claim has
one stable milestone key, the wallet and single gift persist, and a pending
heirloom choice legitimately retains victory for resumption. Receipt fixtures
now distinguish that continuation from a completed terminal choice.

Product proof uses the existing navigation/readability/shop regressions. Native
captures are delegated to the design owner because the implementation sandbox has
no window-server access. The navigation probe and its new proof contract require
1920x1080 at 100% scale and an explicit pointer-anchor capture. No windowed run was
attempted.

The implementation report and exact runtime logs are written to
`/private/tmp/labyrinth_codex/test-02/result.md`. The initial 901.722-second full
run failed with 68 failures and a 900.240-second scheduler deadline. That run
also overlapped focused checks, and its late registration audit observed edits;
it is evidence of the shared-budget failure, not an idle performance benchmark.

The first loaded run also exposed a combined shop assertion: retained offer
owners were correct, but cached tooltip/glyph work exceeded the production 4 ms
slice and yielded a frame. Ownership remains an unconditional default assertion;
the unchanged no-extra-frame guard now belongs to the opt-in perf group. The
same audit split the native glyph frame guard, dense-Light navigation's 40 ms
guard and persistence scheduling upper bounds from their functional checks.
Minimum holds, deterministic-clock timing, completion watchdogs and FIFO/flush
semantics remain in the default suite.

The second loaded run exposed the status movement probe's separate 4 ms
planning maximum (11.771 ms observed). Its cold/warm and incremental planning
caps now also require the perf flag; exhaustive-placement equivalence, untouched
owner reuse, bounded LRU and stable resource assertions remain unconditional.
