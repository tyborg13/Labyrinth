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
- **Status badges** use the existing status badge row with new icons (icons come from a separate director image job;
  until approved icons exist, use `TODO_DESIGN_ICON_<name>` and fall back to the closest existing status icon).
- **Hidden states** (Burrowed, Veiled): the unit's health bar and intent pill stay visible (ITB honesty); the body is
  drawn as specified per enemy.
- New enemy art: `assets/art/enemies/<id>.png` static 255×255 sprites processed by the director from approved
  paintings (provided in your worktree before launch, registered for board pixel density). Portraits:
  `assets/art/portraits/<id>.png` 128×128 (director-provided). Cutout rigs come later in separate units — keep the
  enemy working with the static sprite path (the existing static-sprite fallback).
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
