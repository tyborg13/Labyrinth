# int-03 — Integration repair after the rig wave and ui-03

## Header
- Base: integration `f3852e68e`. It holds rr-23, rr-25, rr-24, rr-21, ui-03 and rr-26.
- The full suites there fail.
  - Godot: 12 failures in 4 program sub-suites.
  - Python: 15 failures and 2 errors.
- Logs: `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/merge_rr-26_{godot,python}.log`.
- Goal: both suites green with no product regression, no weakened assertion, and no art or motion change.
- Owned:
  - the failing tests and their fixtures;
  - the product code behind A;
  - `spec/assets/board_pixel_density/` derivations and manifest (regenerated only);
  - the Mortar's `spec/art_identity/registry.json` entries;
  - the glossary approved-copy registry.
- Not owned (rr-27 runs in parallel): `assets/units/arc_thrall_cutout/**`, `experiments/cutouts/arc_thrall/**`, and
  every rig's pieces, layouts, motion and pose records.

## Change

### A. ui-03 regression: `suites/full_scene_card_drag_program` (12 failures)
- All 12 are in `tests/suites/card_drag_play_suite.gd`, roughly lines 252–481. `codex/ui-03` (5d4d7fc05) fails them
  too, so ui-03 introduced them.
  - "Invalid in-board release should keep the shared arrow live at the release point"
  - "Post-release pointer motion should win over deferred handoff layout…"
  - "Pointer targeting handoff should keep the forged cursor hidden"
  - "Direct release handoff should show the shared targeting arrow"
  - "The forged pointer should remain hidden throughout targeting even inside the arrow's short dead zone"
  - Closing the map, a button-opened menu, Abilities, or a skill choice should restore the click-targeting arrow and
    return pointer ownership to click targeting.
- For each assertion, record where the pointer is: board, hand, or HUD.
- ui-03 brief requirement 4 (`spec/peer_benchmark/briefs/ui-03.md`): while click-targeting, the cursor is visible
  whenever the pointer is over the hand or HUD, and the targeting arrow hides while the pointer is off the board.
  - Only where the test's pointer really is over the hand or HUD may the assertion change to that behaviour. Cite the
    requirement in a comment.
  - Wherever the pointer is on the board, the old behaviour holds: fix the product code.
  - That includes closing the map, menus, Abilities and skill choices with the pointer back over the board, and
    invalid releases on the board.
- Report a table: assertion, pointer location, verdict (product fix or assertion updated per requirement 4), file:line.
- Add a regression for each product fix. It must fail before the fix.

### B. Integration fixtures (the Mortar, Weaver and Mimic now have rigs)
- `en04_enemies_test`: "briar_weaver protected mechanics retained with registered production art".
- `static_facing_test`: `Invalid access … 'enemy_1'` at `tests/static_facing_test.gd:51`, then a 180 s timeout.
  `cutout_context.STATIC_ENEMY_TYPES` is now derived (`_static_enemy_types()`). The test must follow it and never hang
  on a failed lookup.
- `pre_battle_living_foes_suite`:
  - "Instantiated renderer Script matches the board identity: slag_mortar";
  - "Only unrigged identities show the source still: slag_mortar";
  - "Every identity is covered (38 cutouts / 5 stills)".
  - Find out whether the renderer lookup is wrong (`presentation.renderer_script` now resolves
    `assets/units/<CREATURES[type]>_cutout/renderer.gd`) or the test is stale. Fix the cause.
- `test_rr20_feedback2`: two errors, "bone evidence changed: missing or changed full sample diagnostics". Make the Mimic
  tests read the canonical `read_report` record. Regenerate headless records only through the case's own sampler.
- `test_board_pixel_density.test_shipped_derivations_and_manifest_are_current`:
  - Regenerate the derivations and manifest with `tools/process_board_density.py`.
  - Every changed output must trace to a merged unit's approved source. Report the list.
  - Pixels in `assets/units/**` must not change.
- `test_art_identity_gate` strict mode: "assets/units/slag_mortar_cutout/humanoid_v2/{front,rear}/rest.png: pixel
  digest changed".
  - The files and registry entries equal rr-25's own records commit `a1615e567`, so this predates integration.
  - Confirm the rest PNGs are the director-rendered density rebakes from rr-25's records. Then update the registry
    entries through the gate tool's own update path.
  - No image changes. If the PNGs are not the rebakes, stop and report.
- `text_budget_test` glossary `empower`: the approved-copy registry still holds the pre-ui-03 line. The
  director-approved copy is ui-03 brief requirement 5: "Pay the listed extra cost when you play this card to gain the
  listed bonus. Charge it with the seal on the card's corner."
  - Update the registry entry.
  - The text must fit its budget. If it doesn't, report it. Don't shorten it yourself.
  - Same for the Grimoire `keyword:empower` line if it is registered.

### C. Single-unit preservation pins (multi-unit integration breaks them by design)
- Tests:
  - `test_rr23_owner_fixes`: `test_shadows_retain_every_other_figure_against_pinned_baseline` and
    `test_shared_records_retain_every_other_figure`;
  - `tests/rr18/shadow_refresh.gd`'s "Unrelated shadow added/changed" baseline;
  - `test_rr14_seer_identity` (9 files);
  - `test_rr13_continuations.test_both_rest_composites_and_all_garment_deformation_fields_are_unchanged`;
  - any Weaver or Capacitor equivalent that fails: `test_prior_creature_assets_and_case_data_are_byte_identical`,
    `test_shadow_baseline_is_explicit_and_portable`.
- Rule:
  - A preservation test keeps asserting that **its own unit's commit range** touched nothing else, using a pinned
    `base..unit_head` diff. That's the pattern of `experiments/cutouts/glacial_mirror/rr23_preservation.py`
    `protected_changes(..., end=UNIT_HEAD)`.
  - It doesn't compare against today's tree.
  - Identity pins that later units legitimately changed get the new hashes, with a comment naming the authorizing
    feedback. For the Seer, rr-26 feedbacks 1 and 2 authorized the sleeve and hem changes at `32ce9d813`.
  - Never delete or loosen an assertion's intent.

## Keep
- No art, paint, motion, pose or gameplay change. The only product change allowed is A's targeting fixes.
- Windows typed-array rule (AGENTS.md).

## Proof
- Focused runs for each item first.
- Then, because this unit's job is a green merge, **both full suites once at the end**:
  - `python3 tools/godot_task_runner.py --task-id int-03 --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd`
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - Report the exact result lines.
- List any windowed command the director should run, for example a ui-03 still if A changes cursor or arrow visuals.

## Out of scope
- Thrall work (rr-27).
- The keyword tooltip duplicate MELEE (backlog).
- rr-09 binding narrowing.
