# Section encounter tables

Revision-4 section-map regular fights use the director-authored
[`data/encounters.json`](../data/encounters.json). `EncounterTables.load()` reads
and validates it once. The cached definition is immutable; picks own their
expanded unit lists. Invalid definitions produce an assertion/error, and the
focused suite checks validation explicitly rather than accepting a fallback.

## Format

- `version`: currently `1`; `_doc` describes the authored contract.
- `element_regulars`: room-element keys mapped to ordered concrete enemy-id
  groups. Valid keys are Fire, Earth, Ice, Air and Lightning's lowercase ids.
- `tiers`: keys `1`, `2`, `3`; each contains entries with globally unique `id`,
  positive relative `weight`, and a nonempty ordered `units` list.
- `biome_groups`: all six section dragon elements (`fire`, `earth`, `ice`,
  `air`, `lightning`, `shadow`), each containing groups with unique local `id`,
  positive relative `weight`, and nonempty concrete `units`.
- `rules.no_repeat_last`: number of recent run-wide composition ids excluded.
- `rules.max_units`: maximum expanded base composition size.
- `rules.trim_rule`: drop concrete non-token units from the end until the
  composition fits; never drop a unit contributed by a token.

All concrete unit ids must exist in `data/enemies.json`. Unknown keys, tokens,
nonpositive weights, duplicate ids, invalid rules, and token expansions that
cannot fit even after removing all concrete units fail validation. The protected
version-1 table supplies `no_repeat_last = 2` and `max_units = 7`.

## Selection and expansion

`EncounterTables.pick(tier, room_element, biome, history, rng)` returns
`{id, units}`. The tier is the existing local depth band, clamped to `1–3`;
completed sequences retain their existing HP scaling. The biome comes from the
section's dragon, independently of the room's element. Mystery combat resolves
its hidden element before selection.

1. Remove entries containing `$element` when the room has no element (`none`).
2. Exclude ids from the last `no_repeat_last` picks. If this removes every
   eligible entry, use the complete eligible tier instead.
3. Pick an entry using relative weights and the room's existing seeded RNG.
4. Expand tokens in place. `$element` inserts the full room-element regular
   group. Each `$biome` independently picks and inserts a weighted group from
   the section dragon's biome.
5. Apply the trim rule to the expanded list, preserving all token units.
6. Apply existing Reach Exit extra enemies and leader adjustments afterward.
   These objective extras can raise the final count above `max_units`.

Table-path spawn tiles remain distinct, outside the existing player entry halo,
off door tiles, and reachable from the entrance. Terrain generation retains its
existing connectivity rules.

The selected `encounter_id` and `biome` are stored in room metadata when combat
begins. The saved run-wide `encounter_history` appends once at direct entry or
Begin; previews, preparation, and choosing an entry tile do not consume picks.
New revision-4 runs begin with empty history. Old revision-4 saves missing the
field also begin empty; earlier layouts read missing history as empty without
adding fields or changing their state hashes. Room metadata carries identity
through save/resume and supplies combat-start analytics.

## Adding a section enemy

Once another unit supplies the enemy definition and approved assets, add one
`biome_groups` entry under its section element, using its enemy id in `units`
and director-authored `id` and `weight`. No room-generator pool or code change
is needed. Concrete groups cannot contain tokens. Validate the table, inspect
base HP/unit totals, and rerun placement proof after any group change.

## Legacy rule

Non-section runs, section layout revisions below `4`, Guardian and dragon rooms,
NPC rooms, the authored guided tutorial, and recovery fights synthesized from
noncombat rooms retain the hard-coded pools, placement RNG, and adjustments.
The table path adds no fields to those legacy layouts or run states. The focused
suite compares pre-change serialized layouts, pools and non-section/revision-3
run states for 64 seeds against SHA-256 baselines captured on `79b1c6ba`.

## Proof

Run commands from this task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-01 && python3 tools/godot_task_runner.py --task-id enc-01 --stream -- godot --headless --path . --script tests/encounter_tables_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-01 && python3 tools/godot_task_runner.py --task-id enc-01 --stream -- godot --headless --path . --script tests/encounter_tables_test.gd -- --integrations-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-01 && python3 tools/godot_task_runner.py --task-id enc-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The full suite uses a 900-second limit because its existing scene and timing
checks outlasted the runner's default 300 seconds after a successful launch.
The focused suite runs 10,000 picks per tier for elemental and neutral cohorts
with a ±2% relative tolerance against each expected share, independent weighted biome-token
proof, no-repeat/fallback, trim, real save/load, deterministic selection, legacy
byte identity, and every legal entry × six biomes × six room elements × 32 seeds.
Neutral `$element` cases are checked as ineligible. All existing entrance
orientations, Reach Exit extras, and leader objectives are included in the sweep.
Its base HP/unit report exhaustively enumerates independent biome-group choices,
with an unweighted mean over expansions; it excludes HP scaling and objectives.
The intrinsic card scorer does not read encounter pools, so its coefficients and
assumptions remain unchanged by this unit. Current protected-table base HP min/mean/max is `28 / 34.625 / 38`,
`46 / 49.820513 / 56`, and `36 / 63.042735 / 74`; unit count is
`3 / 3.395833 / 6`, `4 / 4.611111 / 7`, and `5 / 5.623932 / 7`,
respectively. These enumerate `240 / 234 / 234` expansions.
Legacy tier comparison means supplied
by the director are `36 / 49 / 67`.

Native proof is written but must run on a machine with window-server access:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-01 && python3 tools/godot_task_runner.py --task-id enc-01 --stream -- godot --headless --path . --script tests/encounter_tables_test.gd -- --proof-contract-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 90 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth-inspection-manifests/enc-01-visual-contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/enc-01-visual-result.json tests/encounter_tables_test.gd --task-id enc-01
```

The extended timeout allows six production-scene captures in one process.
Captures use only existing production assets and the actual section, room
and encounter data, at `1920×1080`, `100%` UI scale, under
`user://probes/encounter_tables/<biome>_encounter.png`; `captures.json` records
composition id, biome, room element and unit count. Proof uses seed `83`, fixed weight-test seeds `4723/4709`, `4820/4703`,
`4743/4704` (elemental/neutral, by tier), a
`0.25`-second settling wait, and each section's deepest regular room as debug-only
fixture defaults. Peer review, inspection fixtures, commits and publication
belong to the design owner for this implementation handoff.
