# qa-08 feedback 1 — quarantine the 34 with owners; wire the 115 into qa-07's runner

The root cause and audit are accepted. The dragon-reward fixture fix is good: the reason is stated and no assertion
was weakened. Next:

1. **Explicit quarantine.**
   - Add `tests/quarantine.json`. Each unresolved entry gets: path, category (from your table:
     `export-workflow`, `stale-reference`, `legacy-cutout`, `long-diagnostic`, `needs-design`, `possible-bug`),
     reason, evidence log path, and `follow_up` (an id from the list below).
   - The completeness guard passes when every non-windowed test is either registered or quarantined with all fields
     present.
   - It fails on any new unregistered test, any quarantine entry missing a field, and any quarantined test that now
     passes. Run each quarantined test in the guard's slow mode or as a separate check, so a passing one is flagged to
     be wired in.
   - Document the quarantine in `spec/development_workflow.md`, next to the runner section.
2. **Follow-up ids** (I'll brief these as units):
   - `qa-09`: stale independent references (`combat_boundary_equivalence`, `noncombat_move_equivalence`,
     `committed_hand_queries`, the `prepared_*` family, `dragon_rewards` singleton outbox, `en05_integration_sync`
     baseline).
   - `qa-10`: legacy cutout tests (`cutout_rig_data`, `lightning_wisp_cutout_pack`, `contextual_creature_motion`),
     migrated to the production maquette runtime.
   - `qa-11`: long diagnostics (`dragon_pressure_escape_probe`, `owned_combat_creation_equivalence`), partitioned and
     budgeted.
   - `qa-12`: export-workflow tests (`boot_splash_export`, `card_presentation_export`) behind an export fixture.
   - `bug-01`: `prepared_other_character_view`, the possible real input-capture/cancellation ownership bug.
   - `design-01`: needs director decisions (`combat_hud_badges`, `equipment_inventory_readability`,
     `combat_board_navigation` zoom anchoring, `dragon_area_presentation` cancellation,
     `objective_glyph_equivalence` and `prepared_shop_glyph_equivalence` headless/native split).
   - Assign every one of the 34 to exactly one of these. If one doesn't fit, say so.
3. **Runner integration.** qa-07 (the parallel program runner) is close to landing. When it lands I merge it into your
   branch. Then register the 115 supplemental programs in qa-07's program manifest, so they run in the full suite under
   its 4-worker scheduler with the 180 s per-child cap. Until then, keep your registration code isolated so the merge
   is mechanical.
4. Report the full-suite wall time after integration. The target is ≤ 600 s on this machine with no other load, under
   the 900 s hard cap.
