# Storm Capacitor `storm_capacitor`

Design authority: `../peer_benchmark/briefs/en-06.md`,
`../peer_benchmark/enemy_roster_v1.md`, protected staged wave E2 entry.
Director feedback 1 supplies final pip spacing and deterministic tie precedence.
Heavy Tempest Spire construct: 22 HP, initiative 16, 13 Embers. Closest
comparisons: Stone Warden's anchor and Lightning Wisp's electrical reach.

1. Charge adds one persistent Charge, capped at 3. The existing status row uses
   the approved `charge` painting and exact tooltip. Three 8px diamonds sit
   above its health bar; empty outline `#3a2f4f`, fill `#a77bf0`, glow alpha 0.4.
   Edge gaps are 4px; the row centre is 10px above the health-frame top.
   Charge and Discharge pills display integer `+1` and `6`.
2. At 3, the next selected intent is Discharge. Manhattan first reach is 4;
   nearest target wins; ties prefer the hero, then lowest current HP, then
   lowest tile y, then x. The source is
   excluded like ordinary Chain. Later hops use eight-neighbour adjacency,
   nearest Manhattan distance, no repeats, up to three jumps for 6/5/4/3.
   Every jump uses the same tie precedence. Prediction runs the same damage
   resolver on a copy, so intervening deaths
   change later targets consistently. Enemies receive existing friendly-fire
   damage/rewards; each resolved snapshot drives the existing violet Chain FX
   for 0.12 seconds. Charge resets to 0. The at-rest path uses EN03's dashed
   lightning language and the shared damage typography.
3. A transition from unshocked to Shocked removes one Charge, updates the
   revealed intent and pips, and emits the exact floating label `Grounded`.
   Extending an existing Shock is not a second transition. Both targeted and
   global status paths dispatch the helper. Immobile units cannot walk or be
   pushed/pulled; the existing Construct classification anchors wind.

Mechanics: `scripts/enemy_mechanics/capacitor.gd`; presentation:
`capacitor_view.gd`. State fields `charge` and `grounded_seq` persist through
ordinary dictionary saves, absent fields default on read. No new analytics
kinds or audio; ordinary enemy-action events and electrical cues are reused.

Approved paintings alone were keyed with repository helpers, trimmed and
registered onto the 255 canvas at Gaoler's base line (251). The wide intact
chain/base fits at body height 243. Runtime scale `216 * 1.2 / 243` restores
120% of the current hero's 216px painted silhouette; that calculation is not
new tuning. A registry native-treatment exception preserves the brief's fixed
255 canvas. The 128 portrait crops the central glass coil at 1:1 with 8px top
padding. Hashes, untouched density source, output record and shadow-cache
entry are registered. No generated art, new rig or idle sheet.

Encounter entries are deliberately left for the director after merge:
`lightning_capacitor`, weight 2, storm_capacitor + lightning_wisp.
Mean no-Shock activation cadence at local depth 2 is 20.25 Time; kill before
three pips, Shock, or separate units. See the EN06 heuristic rows and scorer.

Proof and exact commands: [en06 implementation handoff](en06_implementation_handoff.md).
