# map-01 — Branching section map v2 (generator rules, visibility, mystery rooms)

## Header
- Goal: each section becomes a Slay-the-Spire-style branching map the player can plan: 4 lanes, paths that split and
  merge every step, every room type visible except **mystery rooms** ("?"), several optional Guardians per section,
  a guaranteed mid-section treasure row and a Hearth row before the boss. Route choice should trade risk (Guardians,
  more fights) against services.
- Base: `codex/peer-benchmark`. Depends on: nothing. Runs in parallel with ev-01 (ev-01 owns event rooms' contents; you
  only place `event` nodes).
- Docs (sections): spec/section_map.md (all of "Route contract", "Discovery and decisions", "Saves, recovery and
  analytics"); spec/graftwright.md eligibility paragraph; spec/guardian_combats/approved_design.md map placement.
- Owned files/dirs: `scripts/section_map_graph.gd`, `scripts/section_map_panel.gd` (ONLY the node position function at
  ~line 411 and the legend entry list — NOT `_build_event`, which ev-01 owns), `scripts/section_map_node.gd` (mystery
  icon hookup only), `scripts/run_engine.gd` (only where room entry dispatches by type: add `mystery` resolution;
  keep edits minimal and away from `resolve_map_event`), `tests/suites/section_map_suite.gd`, new
  `tests/suites/section_map_v2_suite.gd` + `tests/section_map_v2_test.gd`, `spec/section_map.md`,
  `tools/headless_playtest.gd` (map printing for lanes 0–3 and `?` only).
- Rules: generation stays pure/headless and deterministic from the run seed; Windows typed-array rule; no art (use the
  existing Unknown ring as the temporary mystery emblem; the director will supply a dedicated icon later);
  `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier **high** (run structure, saves). Acceptance: (1) new runs use layout revision 4 with the rules
  below, verified over ≥ 64 seeds; (2) all saved older layouts keep their stored topology and knowledge rules; (3) every
  room is reachable and every complete route satisfies the budgets; (4) mystery rooms resolve to their hidden type on
  entry; (5) the map panel renders 4 lanes legibly. Proof: section_map suites, dragon_boss suite, full suite;
  director runs the visual probe.

## Change (numbered, testable)
1. **Revision.** `LAYOUT_REVISION = 4` for new runs. Keep the revision-3 generator reachable only for regenerating
   nothing: stored layouts are never regenerated (existing contract). Runs whose saved revision < 4 keep today's
   knowledge/fog/Scout behaviour exactly.
2. **Grid per section.** Steps 1..S−1 are rooms, step S is the boss, S = the existing `ROOM_COUNTS[index]` (10, 11, 11,
   11, 11, 12). Lanes 0..3 (4 rows). The entry/threshold node stays as today (step 0, lane 1.5 visually centred).
3. **Paths.** Generate exactly 5 lane walks per section with a section-seeded RNG:
   - Walk k picks its step-1 lane: walks 0 and 1 must start on different lanes; others uniform in 0..3.
   - From step t to t+1 a walk moves to lane −1/0/+1 (clamped to 0..3), chosen uniformly among moves that do not cross
     an already-created edge between the same two steps (edge a→b crosses c→d iff (a−c)·(b−d) < 0). If every move
     crosses, take the move that keeps the lane.
   - Nodes = union of (step, lane) visited; edges = union of moves. The entry links to every step-1 node; every step S−1
     node links to the boss.
   - Reject and regenerate (same RNG stream, bounded to 50 attempts, then a deterministic fallback that is still legal)
     if any step has fewer than 2 nodes, or step 1 has fewer than 2 nodes.
4. **Fixed rows.** Step 1: all `combat`. Step S−1: all `campfire` (Ember Hearth). Step ceil(S/2): all `treasure`.
5. **Other nodes** (steps 2..S−2 except the treasure row) get types by weighted roll, then repair:
   - Weights: combat 46, mystery 22, guardian 10, scavenger 10, graftwright 6, event 6.
   - Placement constraints: guardian only at steps ≥ 3 and ≤ S−3; scavenger only at steps ≥ 3; graftwright only where
     every route from the entry to that node has passed ≥ 3 fights (combat or guardian rooms, counting mystery-combat as
     a fight); no two nodes of the same type in {guardian, scavenger, graftwright, campfire, treasure} directly connected
     (parent→child); children of one parent all have different types when they have ≥ 2 children (combat may repeat only
     if the parent has 3 children).
   - Path constraints, checked over EVERY complete route entry→boss: fights (combat + guardian + mystery whose hidden
     type is combat, excluding the boss) within [F−1, F+1] where F = `FIGHT_COUNTS[index] − 1` (5, 5, 6, 6, 6, 6);
     guardians ≤ 1 per route; ≥ 1 route with a guardian and ≥ 1 route without; ≥ 1 non-fight service (scavenger,
     graftwright, event, or mystery whose hidden type is not combat) per route besides the treasure row and Hearth row;
     at least 2 guardian nodes and at least 1 scavenger node in the section.
   - Repair by re-rolling offending nodes (bounded), then whole-section regeneration (bounded), then a deterministic
     legal fallback. Never ship an invalid section; assert in tests over 64 seeds.
6. **Guardians.** Every guardian node in a section is that section's Guardian (`Guardians.for_boss(boss_id)`), with the
   same fields as today (element, guardian_id, guardian_relic, boss_id). A route can meet at most one (rule 5), so the
   trophy is never duplicated. `info["guardian"]` becomes `info["guardians"]: Array[Vector2i]`; keep `info["guardian"]`
   as the first one for compatibility.
7. **Mystery rooms.** Type `mystery` with a hidden `mystery_type` rolled at generation: event 70, combat 20, treasure 5,
   scavenger 5 (seeded per node). On entry the node's `type` becomes its `mystery_type` (and gets the same fields a
   generated node of that type has: combat element, scavenger npcs/merchant_kind, etc.) and records
   `was_mystery: true`. Before entry, tooltips and legend call it "Unknown room" and never reveal the hidden type.
   Scout (revision 4): targets are unentered mystery rooms in the current section that are still reachable; using it
   sets `scouted: true`, which reveals the hidden type on the map (emblem of that type over the unknown ring) without
   converting the node until entry. Two Scouts per section as today.
8. **Visibility (revision 4).** Sections I–V: every node and edge of the current section is revealed and outlined from
   the moment the section is entered (no fog, no proximity reveal needed). Section VI (Noctyrax, the heart of the Umbra)
   keeps today's knowledge rules (next 2 transitions revealed, third outlined, fog shader, landmarks) — but mystery rooms
   there still hide their type until scouted or entered. Future sections stay hidden behind disabled tabs.
9. **Coordinates/depth.** Room coords must stay unique and on the depth ring the run engine uses (`_room_depth` =
   Chebyshev distance). Step→depth band for section index i with S steps: steps 1..S−1 split into the three local bands
   as evenly as possible (earlier bands never larger than later ones), i.e. local depth = 1 + floor(3·(step−1)/(S−1)),
   EXCEPT that band capacity (8·depth ring slots) must hold every node of the band: if a band would overflow its ring,
   move its last step to the next band. Assert capacity in tests for all sections with 4 lanes.
10. **Presentation (minimal).** In `section_map_panel.gd` place nodes at y = 116 + (field_h − 232) × lane / 3.0 (lanes
    0..3) and keep x by step. Legend: replace "Unknown" with "Unknown room" for revision-4 runs (the broken-ring
    emblem). Mystery nodes use the existing undiscovered/broken-ring emblem until the director supplies an icon; a
    scouted mystery shows its revealed type's emblem. Do not restyle anything else.
11. **Spec.** Rewrite spec/section_map.md "Route contract" and "Discovery and decisions" for revision 4 (keep the
    revision-3 text as a short "Older layouts" subsection).

## Keep (must not break)
- Stored layouts and their saves (revisions 1–3, legacy circular map), boss order, Ember recovery placement onto an
  existing combat/guardian/boss node, physical exit doors for Reach the Exit (doors map to outgoing connections — with up
  to 3 children; keep the existing door-direction mapping), Graftwright service behaviour, event rooms (ev-01 fills
  their contents), analytics outbox events (`route_choice_committed` etc.; add `mystery_resolved {room, type}` and
  `map_scout_used` scope `mystery` additively and document in spec/analytics.md — you may edit only those analytics
  lines).

## Proof
- `tests/section_map_v2_test.gd`: 64 seeds × 6 sections: path count, crossing-free edges, lane bounds, fixed rows, type
  constraints, per-route budgets/guardian/service rules, ≥ 2 guardians and ≥ 1 scavenger per section, all reachable,
  coords unique and on the right depth band, deterministic regeneration from seed, mystery resolution on entry, Scout
  on mystery, Section VI knowledge rules, a revision-3 saved layout loads and plays unchanged.
- Keep green: section_map suite (update only revision-3-specific expectations that are now revision-4 behaviour for new
  runs; never weaken legacy checks), dragon_boss suite, full suite.
- For me (windowed): the existing `tests/section_map_probe.gd` command line to re-capture all six section backgrounds
  with the new layout (list it; you cannot run it).

## Out of scope
- New map art/icons, fog removal visuals beyond not drawing fog for revision-4 sections I–V, node styling, map panel
  redesign, event contents, rebalancing fights.
