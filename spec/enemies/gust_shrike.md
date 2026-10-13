# Gust Shrike — en-05

Director source: `spec/peer_benchmark/enemy_roster_v1.md` and protected
`spec/peer_benchmark/staged/enemies/wave_e2.json`. Production preserves the
complete authored object verbatim in value; no tuning or encounter additions.
The director's en-05 feedback 1 resolves the Dive rules and tooltip copy below.

Light Hollow Gale skirmisher: 9 HP, initiative 9, 8 Embers; authored weighted
activation cadence 13.5 before spawn stagger and legality filtering. Closest
comparison: Harrier's mobile melee pressure at a lighter HP/cadence band.

4. Flying is a permanent badge. Ordinary movement ignores surface costs,
   surface damage/contact and traps; it can traverse Bramble and Ice Pillars,
   including a committed path, but cannot end on impassable terrain. Other
   units remain ordinary movement blockers. Forced movement uses the existing
   collision rules and can push the bird normally.
5. Dive forecasts a cardinal line of at most four tiles ending at the hero.
   Units are allowed; walls and impassable terrain prevent the Dive line.
   A deterministic approach of at most two tiles can establish a line;
   impossible Dive choices are filtered before a seeded weighted intent roll,
   leaving Talon Rake/Hover. Telegraph and resolution share one plan. The
   dashed line is #8ea3b8, width 2, dash/gap 10/6. Flight takes 0.35 seconds.
   Each unit strictly between the flight start and hero receives at most one
   Push 1 to the Dive's right-hand side: `(dx, dy) -> (-dy, dx)` on the board
   grid (x right, y down), whether initially aligned or approaching. Blocked
   or impassable side tiles use ordinary collisions, with no opposite-side
   fallback. The hero is never side-pushed and takes 4 air damage only when
   the bird lands on the tile before the hero. After pushes resolve, if that
   landing remains occupied, the bird stops on the last free path tile before
   it (the start if no intermediate tile is free); the hero takes no damage.
   Threat tiles and the dashed telegraph end at the actual stop tile in that
   case; the damage forecast and compass omit the hero hit. Side-push paths
   show the exact attempted tile, including blocked pushes/collision markers.
   Planning and resolution share the push and landing helpers.
6. Talon Rake retains Move 2, melee 3, Bleed 1. Hover retains away 2 and Block 3.

Approved tooltips in `ActionIconLibrary`:

- `Dive: flies straight at you (up to 4 tiles), knocking each unit it passes 1 tile aside, then strikes for 4.`
- `Flying: moves over traps, surfaces, Bramble and Ice Pillars and takes no surface damage. Can still be pushed.`

Dive's range/damage text is formatted from the action data, including the
actual intent values. All five original design placeholders are resolved.

Mechanics: `scripts/enemy_mechanics/dive.gd`; presentation: `dive_view.gd`.
Static art: `assets/art/enemies/gust_shrike.png`, 255 square, 184-pixel
silhouette (85% of the 216-pixel hero after integer rounding), wings raised,
baseline y=251 matching Chainbound Gaoler. Portrait:
`assets/art/portraits/gust_shrike.png`, native 128 square, top padding 8,
centred on the head/beak. Icons: `assets/art/icons/dive.png` and `flying.png`.
No idle sheet/cutout; existing art scale/offset defaults. Only the approved
source paintings were keyed, fitted and density-processed.
Feedback 1 leaves all art unchanged; the director's art-02 unit owns re-art.

The director adds `air_shrikes` after merge, even though `biome_groups` is
already present. No new analytics events; existing enemy actions, ground and
collision/death events remain authoritative. Save round-trips use the real
progression store; no new persistent phase state or old-save migration is
needed for these definition-backed passives and immediately resolved actions.

The headless logic, asset, live preview and windowed proof entry points are
listed in `glacial_mirror.md`. The probe shows the approved aligned right-hand
pushes at rest and after Dive, plus blocked-landing rest/after captures.
