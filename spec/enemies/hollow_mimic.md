# Hollow Mimic `hollow_mimic`

Design authority: owner-approved `enemy-mechanics-audit`, mim-01, 2026-10-30.
Standard shadow skirmisher: 14 HP, initiative 12, 11 Embers; no art, rig or audio changes.

- Echo (weight 3, Time 6): ranged 3 shadow damage at range 4, then Retaliate 3.
- Shade Bolt is unchanged. Recede retains its weight and Time, moves away 2,
  and grants no Block.
- Enemy Retaliate lasts until the start of that enemy's next turn, including a
  skipped turn. A melee attack, or another hero attack from an adjacent tile,
  triggers it once per attack, including Detonate. Distant ranged and area attacks do not trigger it.
  Block and Stoneskin absorb it; Chill, Freeze and Expose do not amplify it.
- The shared `scripts/retaliate_rules.gd` primitive owns both sides. The existing
  status row shows the Retaliate icon/count, and exact card resolution feeds the
  hero's aimed damage preview. Status and action tooltips share the glossary:
  “Until its next turn, whoever hits this unit up close takes that much damage.”
- Echo uses the existing bolt attack clip, shadow ranged effect and normal cues.
- Save loading converts held Mirror intents in active fights/checkpoints to Echo
  and removes retired attack history through `retired_mirror_save_migration.gd`.
  Only `combat_state` and `pending_combat_checkpoints[].state` are migrated;
  embedded analytics/history and layout records remain untouched.
  Legacy tenfold combat units normalize before the natural-unit Echo is inserted.
  No combat-wide card tracking or copy-specific resolver/presentation remains.

Authored weighted cadence remains 17 Time at local depth 2. Encounter assumptions
are shared with the heuristic/scorer; intrinsic card coefficients are unchanged.
The `shadow_mimic` encounter retains its existing weight and roster.

Proof: `tests/mim01_test.gd`, `tests/test_mim01.py`, `tests/mim01_probe.gd`.
Director feedback 1 measurements use the first 100 baseline samples per tier
for ordinary Mimic rooms and shadow Warbands, unchanged policy/decks and two
workers. The one-time measurement helpers are retired after those 600 fights.
Mirror-only move/copy and reaction fixtures are retired from the composite
matrices; Tether fixtures are also retired by the earlier Thrall integration.
Shared ordinary Warden analytics and playback checks remain, while
`mim01_suite.gd` owns Echo/Retaliate behavior. Historical art/rig checks retain immutable inputs.

## spx-04 — The Hollow Prior

Only the living Warband captain with `prior_veil` gives its distant followers
Veil and hidden-enemy presentation. Distance is the ordinary closest-footprint
Manhattan distance: more than 2 hides; entering 2 reveals. Existing Light and
Truesight reveal them. All hidden targeting, threat privacy, collision, captions
and information-limited forecasts use the ordinary visibility query. Revealed
followers use their ordinary bodies; the retired native Veiled status and
targeting restriction do not return. Captain death disables the aura immediately and reveals followers even through
room Umbra; missing captains in partial forecasts never count as death. Break reveals followers before the existing flee display. It never executes Fade
or Ambush. Fade/Ambush behavior remains unchanged.
No new art, animation, sound, analytics events or save migration are introduced.

Validation and director capture commands: [spx-04 handoff](spx04_orders.md).
