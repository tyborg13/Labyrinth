# fix-10 — el-02 fallout in suites el-02 never ran

## Header
- Base: `codex/peer-benchmark` (el-02, fix-09 and el-04 merged). Risk tier: standard. Tests first; production code only
  where a test exposes a real el-02 defect.
- Binding design: `spec/peer_benchmark/element_rules/design.md` §3–§4 (owner-approved). Bramble, Ice Pillar and Tether
  are retired; Thornwall raises Outcrops through Upheaval; Tether became Lightning Strikes along the partner line.
- Owned: the failing tests below, their fixtures, and any el-02 production code a test proves wrong. Not the views
  (el-04, merged).

## Why
Full Godot suite on integration 4ca3b9f6c (el-02 merged without suites) fails beyond fix-09's SFX/perf items:
1. `tests/suites/enemy_intent_continuity_suite.gd`: 28 Briar Weaver cases (solo/squad × out_of_range/blocked_sight),
   e.g. `actually resolves Thornwall before checking the regression` and `unreachable Lash still pays its authored Time`.
2. `threats_at_rest_test`:
   - `briar_weaver at-rest chip uses its own bramble icon`;
   - `Live briar_weaver chip uses its own icon`.
3. `tests/suites/destruction_preview_suite.gd`: `Removed lifetime terrain retains its body and death mark without adding a
   health bar`, which was built on Bramble lifetime terrain.
4. `warband_test`, three cases:
   - `Composite preview shows resolved Command: tether_beam`;
   - `Composite fixture actually hits: tether_beam`;
   - `Composite Command at hit position (tether_beam enters=true)`.
5. Rig production regressions (Python suite):
   - `test_rr07_production` (Arc Thrall): `tether: fewer than six real progression frames`, `missing real contact`.
   - `test_rr21_production` (Briar Weaver): `thornwall: fewer than six sampled frames`, `missing real contact frame`.
   The casts were rebuilt on Lightning Strikes and Upheaval, and the cutouts' `tether` / `thornwall` clips no longer
   play when the Thrall or the Weaver casts. That's a visible regression: each cast must still play its authored clip
   with its real contact frame. Route the new action types to the existing clips. Don't change motion data or the
   rigs' bound case files.

## Change
For each case, first decide whether it guards a **still-live behaviour** or a **retired mechanic**:
- **Live behaviour**: keep the guard and adapt it to the el-02 mechanic.
  - Lash continuity, cancelled-attack badge, analytics attribution and Time all still apply.
  - Thornwall now marks its line and raises Outcrops (health 3) through Upheaval on its next turn.
  - The Weaver's at-rest/live chip shows its Thornwall intent icon (whatever el-02 registered for the new Thornwall,
    not `bramble`).
  - The Dynamo's composite Command is now Lightning Strikes along the partner line. Keep the composite-Command preview
    and hit assertions against it.
  - The destruction preview's lifetime-terrain guard moves to a still-live lifetime terrain if one exists. Otherwise
    report it.
- **Retired mechanic only**: remove the case and say why in the result.
- If a case exposes a real el-02 defect (preview ≠ resolution, a lost behaviour, a dangling reference to a retired
  kind), fix the production code and add a regression test.
- Never weaken an assertion to pass; never change the approved design.

## Proof
- Those four suites and `test_rr07_production`, `test_rr21_production` pass, plus `en02`–`en06`, `battlefield_rules`, `element_retrofit`, `warband_orders`, `warband_ui`,
  `snare`, `snare_ui`, `el04_rule_views`, the registration audit and the program-manifest test.
- For each adapted case, show it fails on a mutation of the behaviour it guards. Focused only.

## Out of scope
Balance, copy, views, the approved design.
