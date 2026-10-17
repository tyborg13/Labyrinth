# map-02 — Section maps with real branching variety (owner playtest 9 note 1)

## Header
- Owner: "map needs to be better, more interesting branching, take inspiration from Slay the Spire. (this is partially
  fixed since I took the note, but I think we need further improvement here)".
- Triage §1 (`spec/peer_benchmark/triage_playtest9.md`): revision 4 (`scripts/section_map_graph.gd:62`) falls back to
  the same canned topology in **26 of 30** sampled sections: two straight outer routes with repeated split/merge
  diamonds in the middle. The median is 10 routes per section.
- Base `codex/peer-benchmark`. Owned: `scripts/section_map_graph.gd`, the layout part of
  `scripts/section_map_panel.gd` (node positions only), a new headless variety tool, and tests.
  Not owned: run flow, the section-change and boss onward action (flow-01 will own those), and room contents.

## Root cause first
Before changing rules, instrument revision 4 over seeds 1–200 × 6 sections. Report:
- the fallback rate;
- the count per rejection reason (crossing, door compatibility, fork-type distinctness, per-route service,
  Guardian or fight counts, section-level counts);
- which stage causes the fallback.

Put the table in the result. The fix below must address the reasons you find. If the data contradicts the
approach below, stop and report under TODO_DESIGN instead of improvising.

## Change: revision 5 (new runs only)
1. **Saves keep their revision.** Saved runs keep their recorded `section_map_layout_revision` and generator
   (3 and 4 stay byte-identical). New runs use revision 5.
2. **Lanes and walks.**
   - 5 lanes (0–4) and 6 walks.
   - The three opening combat nodes stay exactly three. Their lanes are three distinct lanes, drawn at random from
     0–4.
   - Walks 1–3 start one per opening node. Walks 4–6 each start at a random opening node.
   - Each step moves the lane by −1, 0 or +1 with weights 30/40/30, clamped to 0–4.
   - A step that would cross an existing edge picks another legal move. If none exists, it keeps its lane.
3. **Structure first, room types second.**
   - Generate the topology with the structural rules only: non-crossing edges, lane change ≤ 1, physical door
     compatibility, 2–5 nodes per interior row, and the fixed rows (step 1 fights, mid Treasure row, Campfire row
     before the boss).
   - Then assign room types with a constraint solver (seeded backtracking) that enforces every existing type rule
     unchanged: fork destinations of different types except three-way Combat forks, ≥ 1 service encounter per route,
     ≤ 1 Guardian per route, fights within ±1 of the target, ≥ 2 Guardians and ≥ 1 Scavenger per section, a
     Guardian-free route, Guardian rows 3…count−3, Scavengers from row 3, and Graftwright after ≥ 3 fights.
   - Keep the candidate weights (Combat 46, Mystery 22, Guardian 10, Scavenger 10, Graftwright 6, Event 6) and the
     mystery roll (70/20/5/5).
   - Re-roll the topology only when the solver proves it unsatisfiable. Use the canned fallback only after 50
     topology re-rolls, and log each use.
4. **Variety rules (structural):**
   - At least one interior row with ≥ 4 nodes.
   - At least one long divergence: two entry-to-boss routes that share no node for ≥ 4 consecutive rows.
   - No more than 3 consecutive rows with the identical lane set.
5. **Layout.**
   - Nodes are placed at `y = 116 + (field_height − 232) · lane / 4` for revision 5. Revisions 3 and 4 keep their
     current divisors.
   - Node size, x spacing and the existing deterministic jitter are unchanged.
   - At the 1920x1080 field size, node buttons never overlap and keep a gap of ≥ 8 px for all 200 seeds. If the
     jitter breaks this, clamp the jitter rather than shrinking nodes.
6. Section VI fog and Scout behaviour are unchanged.

## Acceptance metrics (headless tool, seeds 1–200 × 6 sections, revision 5)
- Fallback rate ≤ 1%.
- Distinct topology signatures ≥ 95% within each section index. The signature is the lane string per walk, as in the
  triage.
- Median distinct entry-to-boss routes between 12 and 40 per section.
- A row with ≥ 4 nodes in ≥ 80% of sections. A long divergence in 100% of sections.
- Room-type frequencies within ±3 percentage points of the triage table (Combat 46.0, Mystery 16.2, Treasure 9.0,
  Campfire 8.9, Guardian 6.5, Scavenger 5.7, Event 5.2, Graftwright 2.4).
- Every existing route and section constraint holds in 100% of sections.

Print a before/after table (revision 4 vs 5) in the result.

## Proof
- Tests:
  - determinism (same seed gives an identical graph);
  - revision 4 saves byte-identical;
  - the metric thresholds above as a test over seeds 1–50;
  - no node overlap at 1920x1080.
- Exact windowed commands for the director: real-renderer captures at 1920x1080, 100% UI scale, of the full-visibility
  section map for sections I, III and V of three seeds that look different. Use a debug flag that reveals the whole
  section for proof only.
- Full Godot and Python suites PASS.
