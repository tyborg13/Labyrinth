# Section enemies — shared rules for en-01 / en-02 / en-03 (read with your unit brief)

Design source: `spec/peer_benchmark/enemy_roster_v1.md` (binding). Data: `spec/peer_benchmark/staged/enemies/wave_e1.json`
(director-authored; copy your unit's entries into `data/enemies.json` verbatim, protected). Use the
`$create-labyrinth-enemy` workflow's checks (schema, turn clock portraits, previews, balance comparison) but take every
number, text and visual from this brief, never from your own judgement.

## Engineering rules
- New verbs live in new focused scripts (`scripts/enemy_mechanics/<verb>.gd`, static functions on state dictionaries),
  called from `combat_engine.gd` through one dispatch line each; drawing for new telegraphs lives in
  `scripts/enemy_mechanics/<verb>_view.gd` called from `combat_board_view.gd`. Keep `combat_engine.gd` +
  `combat_board_view.gd` growth under 120 lines each and `run_scene.gd` under 20.
- `next_intent` (generic, shared by all three units — implement it the same way if it doesn't exist yet when you start;
  the director merges duplicates): an intent with `"next_intent": "<id>"` forces that intent as the enemy's following
  intent; an intent with weight 0 is never rolled randomly.
- Deterministic (seeded) choices only; save/load mid-mechanic (marked tiles, burrowed/veiled/kindled state, wind rounds,
  terrain rounds) round-trips; old saves without these fields load unchanged.
- Enemy-vs-enemy damage from these mechanics uses the existing friendly-fire rules (no Ember reward for kills by
  enemies unless existing rules give it; card-play bonuses unchanged).
- AI: enemies never pick an intent that is impossible this turn (e.g. Tether with no living partner falls back to its
  other intent); preview, the intent compass, the turn clock and the threats-at-rest pills (if present) all show the
  real outcome.
- Windows typed-array rule. Analytics: none needed beyond existing enemy action events.

## Presentation language (all units)
- **Delayed marks** (anything that lands on a later activation: Erupt, Icefall): the existing Meteorfall mark language
  (`combat_board_view.gd` `_draw_meteor_mark` / `_draw_meteor_mark_badges`): tile wash 20% + 3.2 px ring + medallion at
  the tile's front edge with the intent's icon and its damage; tinted by element — earth `#b98b45`, ice `#9cc8e6`,
  lightning `#a77bf0`, shadow `#8a6bd6`, fire keeps the ember colours. Tooltip: "<Intent>\nOn <Enemy>'s next turn this
  tile takes <N> damage<, and …>.<\nYou are standing on it.>".
- **Icons** (director-approved raw paintings, outside git, hashes in `spec/peer_benchmark/staged/enemies/raw_sha256.txt`):
  `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/icons/<name>.png` — burrow, erupt,
  burst (en-01); icefall, wind (en-02); tether, veil (en-03). Process the ones your unit uses exactly like the existing
  64×64 icons in `assets/art/icons/` (key green, trim, fit with the same padding as `cinder_marks.png`/`blink.png`, the
  repository's icon processing tool if one exists), register them in `ActionIconLibrary` and the icon identity
  registry, and run `python3 tests/test_icon_identity_policy.py`. One icon per concept: the intent and its status share
  it (Burrow intent + Burrowed status = burrow; Fade + Veiled = veil; Call the Wind + wind chip = wind; Kindle intent +
  Bursts badge = burst; Erupt and Icefall marks use erupt/icefall). Ambush, Gnaw, Scuttle etc. use existing
  melee/ranged icons.
- **Status badges** use the existing status badge row with these icons.
- **Hidden states** (Burrowed, Veiled): the unit's health bar and intent pill stay visible (ITB honesty); the body is
  drawn as specified per enemy.
- New enemy art: the director-approved raw painting for each enemy is at
  `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/enemies/<id>.png` (1024–1254 px,
  flat green background; outside git — record its sha256 in `spec/assets/enemies/raw_sha256.txt`). Process it with the
  repository's existing tools: key out the green, trim, register onto the 255×255 static sprite canvas with the feet/base
  on the same baseline as `assets/art/enemies/chainbound_gaoler.png` and the body height matching the roster band
  (light: 60–70% of `frostglass_lancer`'s height; standard: 85–95%; heavy: 100–115%), then the board pixel-density
  pipeline (`spec/board_pixel_density.md`: process → rest record → `--check`). Output `assets/art/enemies/<id>.png`.
  Portrait: `assets/art/portraits/<id>.png` 128×128 crop of the processed art centred on the head/front (top of the
  silhouette 8 px from the top, same framing as the existing portraits). Cutout rigs come later in separate units —
  keep the enemy working with the static sprite (the existing static-sprite fallback).
- Sounds: route through existing cues only (attack families by action type); no new audio.

## Encounters
- After enc-01 lands, add each enemy to `data/encounters.json` `biome_groups` exactly as your brief says. If enc-01 has
  not landed in your base, add nothing to pools and report it (the director adds the data entries).

## Proof (each unit)
- Engine suite per mechanic (resolution, telegraph tiles = resolved tiles, save/load, friendly fire, AI fallback),
  schema test, turn-clock portrait test, the full suite.
- A windowed probe `tests/<unit>_enemies_probe.gd` capturing each enemy: at rest with its telegraph visible, mid-way
  through the resolution, after resolution; plus an inspection fixture command that opens a combat room with each enemy
  before its key mechanic resolves (one fixture per enemy).
