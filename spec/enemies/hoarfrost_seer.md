# Hoarfrost Seer — en-02 implementation

Binding design: `../peer_benchmark/enemy_roster_v1.md`, the en-02 brief supplied
in the implementation task, and protected
`../peer_benchmark/staged/enemies/wave_e1.json`. `briefs/en-common.md` and
`briefs/en-02.md` are absent from this base; the task contains their rules.

Controller in Rime Hall: 12 HP, base initiative 12, 11 Embers. The staged entry
is copied verbatim into `data/enemies.json`. The Seer controls space through
delayed damage and temporary obstacles; closest comparisons are Frostglass
Lancer and Acolyte. Standard band. The director adds encounter groups after merge; this unit leaves
`data/encounters.json` untouched.

1. Icefall marks the hero's tile plus perpendicular neighbors, at Manhattan
   range 5. A horizontal seer-to-hero direction produces a column; vertical or
   diagonal directions produce a row. Off-board and impassable tiles are
   skipped. The tile array is stored on the enemy, so moving either actor
   does not retarget landing. A saved `icefall_serial` keeps terrain ids unique
   through both clock-based and legacy phase APIs. Ineligible mark/bolt intents are removed before
   the seeded authored-weight roll.
2. Marks force `icefall_land`, whose random weight is zero. Freeze/Shock
   preserve the held landing until it can execute. Each actor intersecting
   the marked array takes one 5-damage ice hit, including enemies and
   illusions. Living occupants prevent a pillar afterward. Each empty marked
   floor tile gains impassable, sight-blocking Ice Pillar terrain. Its three
   rounds count down at the end of each enemy turn, including landing's own
   boundary and skipped turns, after wind pushes resolve. A pillar on its last
   round still blocks that turn's wind. Ice Pillars cannot be targeted or
   damaged by attacks; expiry and push collisions are their only removal paths. Pushing into it deals exactly 2 collision
   damage, shatters it and stops movement. Existing defense, death, reward,
   Freeze/Chilled and player-card credit paths are retained.
3. Rime Bolt and Withdraw reuse existing ranged/Chilled and move-away/Block
   actions with the protected staged values (3 at range 4; move 2 + Block 4).

The focused helpers are `scripts/enemy_mechanics/icefall.gd` and
`icefall_view.gd`. Marks reuse Meteorfall's wash, ring and front-edge medallion
geometry, with approved `#9cc8e6` tint and `icefall.png`. Landing uses existing
ice VFX for a 0.18-second fall followed by a 0.30-second frost puff. The pillar uses
`assets/art/biomes/iskaldra/pillar.png` and the ordinary pillar fitting/rendering
path; no rock-tint fallback is needed.

Only the approved raw painting was processed. Board art:
`assets/art/enemies/hoarfrost_seer.png`; portrait:
`assets/art/portraits/hoarfrost_seer.png`; no idle sheet or rig was added.
No `art_scale` or offsets were added to the protected entry: existing defaults
apply. The 255×255 canvas uses the Gaoler's baseline, clamped to the director's
standard-height band relative to the Lancer. The processed source was adopted
and density-treated; there is no new rig/rest requiring a native rebake.

Director feedback 1 supplies the remaining timing, terrain behavior and copy.
Pillars store remaining rounds, without HP or a hidden durability sentinel.
Their tooltip is exactly: "Ice Pillar: blocks movement and sight for <n> more
round(s). A unit pushed into it shatters it and takes 2 damage."
The Icefall icon description is "Icefall: icicles fall on the marked tiles on
the Seer's next turn."

Proof: `tests/en02_enemies_test.gd` / `tests/suites/en02_enemies_suite.gd`,
`tests/en02_enemies_probe.gd`, and `tests/proof_contracts/en02_enemies.json`.
The probe captures marks, mid-fall icicles and resulting pillars at
1920×1080/100% UI scale. Windowed captures remain design-owner work because
the implementation sandbox has no window-server access.

Inspection (regenerates and verifies the pre-mark state, then opens it):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/inspection_fixture.py --task-id en-02 --run-id en02-hoarfrost-seer --scenario combat --enemy-types hoarfrost_seer --enemy-positions 5:2 --enemy-intents icefall --player-position 5:5 --umbra-stage clear --biome iskaldra --manifest /private/tmp/labyrinth-inspection-manifests/en02-hoarfrost-seer.json --summary 'Hoarfrost Seer before Icefall marks and landing' --launch
```

The design owner owns task-contract completion, commits, review, inspection
and publication. This implementation does not perform those workflow steps.

## spx-04 — The Rime Oracle

Only the living Warband captain with `oracle_icewall` marks a five-tile line at
the coordinate midpoint, with odd coordinates rounded toward the hero. Its axis
is perpendicular to the Oracle-to-hero bearing. Existing range, legal-floor
filter, stored delayed marks, damage, empty-tile pillars and shatter-for-2
collision remain unchanged. Ordinary Seers retain their full-state legacy golden.
Oblique grid bearings project onto their dominant cardinal axis. Exact
diagonals (`|dx| == |dy|`) use the x axis before taking the perpendicular.

Validation and director capture commands: [spx-04 handoff](spx04_orders.md).
