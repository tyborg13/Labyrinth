# Burrow Grub — EN01 implementation

Binding design: [director roster v1](../peer_benchmark/enemy_roster_v1.md),
protected `burrow_grub` entry in `../peer_benchmark/staged/enemies/wave_e1.json`,
and the supplied EN01/shared brief plus director feedback 1. Staged standard Worldspine Roots enemy:
12 HP, initiative 10, 10 Embers. The nearest body/cadence comparison is
Frostglass Lancer (12 HP, initiative 11, 11 Embers), with held earth pressure.

1. Burrow records the hero tile at resolution in `erupt_tile`, sets `burrowed`,
   and leaves occupancy. Single-target attacks, Swap and Petrify cannot target
   it; area and ground damage still hit its old position. Forced movement does
   not move it. Health and intent remain visible above its mound.
2. Erupt is forced next; its zero weight prevents random selection. It hits the
   center for 6 using existing defenses, displaces a surviving occupant to the
   nearest free cardinal neighbor (away from the old tile, then clockwise), and
   pushes the pre-displacement cardinal neighbors once with existing collision
   rules. It surfaces, leaves Rubble and gains Expose 2. An impassable mark uses
   a deterministic nearest-free landing and no center hit. A buried death
   removes the mark. A skipped Erupt retains the buried state and forced intent.
   If the marked occupant has no free adjacent exit, it takes 6 and stays; the
   grub surfaces at the nearest free tile and pushes from that actual tile.
3. Gnaw reuses Move 2 and melee 3 from the protected data.

Implementation: `scripts/enemy_mechanics/burrow.gd` and `burrow_view.gd`.
State lives on the ordinary enemy dictionary; production Variant saves preserve
it without adding fields to old living enemies. Area damage includes the buried
unit even when another occupant shares its tile. Existing action/death analytics
and enemy-caused Ember policy are retained.

The renderer uses the Meteorfall wash/ring/front-edge medallion geometry with
earth `#b98b45`; blocked marks project to the actual fallback landing and show
zero center damage. The static body rises over the authored 0.25 seconds,
clipped at its registered floor baseline, before push/damage state is presented.
Mound breathing is 1.5 seconds at ±3%, suppressed by reduced motion. The mound
is 60% tile width × 32% tile height, base `#4a3520`, upper-left 1 px rim
`#7a5a34`, and seven seeded 2–3 px specks (four `#2e2116`, three `#b98b45`).
The board render dictionary explicitly carries `burrowed`; body/shadow drawing
is bypassed while health/intent remain. Erupt's ten radial earth particles fade
from 70% to zero over 0.35 s, travelling 0.6 tile widths. Particle diameter was
5 px (director); puff drawing
disabled until the director fills that single field. Rubble creation uses
the existing surface feedback. Intent/status share approved `burrow`; Erupt's
intent/mark use approved `erupt`.

Approved raw art was keyed with `tools/process_biome_art.py:key_green`, trimmed,
registered on a 255×255 canvas with base at y=251 (Chainbound Gaoler).
The silhouette is 162 pixels high, 75% of the 216 px standing hero reference.
Protected data keeps default `art_scale=1`, zero offsets and static fallback.
The density pipeline processed only this new entry; no rig rebake is needed.
Raw SHA-256 records are in `spec/assets/enemies/`. The 128×128 portrait uses
the processed mouth ring, centred at approximately 70% portrait width with
the existing transparent background and 8 px margin. It is explicitly
registered in the turn clock. No art was generated or downloaded.

Encounter pools are unchanged: `enc-01`/`data/encounters.json` is absent here.
The director must add `earth_grub` and `earth_grub_pair` after that unit lands.
Balance context is mirrored in `spec/card_balance_heuristic.md` and
`tools/card_heuristic.py`; no card coefficient changed.

Proof: `tests/en01_enemies_test.gd`; the full suite registers the extracted
`tests/suites/en01_enemies_suite.gd`. The renderer probe is
`tests/en01_enemies_probe.gd`, with its adjacent proof contract, 1920×1080/100%.
Captures 01, 01b and 02–03 cover the mound/mark, persistent hidden body, clipped rise with dust, and pushed units.
See [EN01 proof commands](en01_proof.md) for exact owner commands.
