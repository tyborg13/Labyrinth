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

## Warbands and revision-6 standard fights (spx-03)

Standard `combat` rooms with `section_map_layout_revision >= 6` always use
`kill_all`. Earlier revisions retain their exact seeded objective roll, roster,
placement RNG and serialized layouts. Guardian and dragon objectives and stats
are unchanged. Existing Survive and Reach Exit saves remain supported.

The spx-02 entry contract is `{type: special, special_type: warband,
special_variant: <biome>}`. `SpecialEncounterLibrary` reads the immutable
`data/special_encounters.json`, falling back to the staged director file until
spx-02 installs it. Neither file is rewritten. `order` fields are not read.

`WarbandRoomRules` uses the specific variant captain and the first 3/4/5 ordered
escorts at the existing local depth tier. It bypasses generic leader selection,
spawn-group expansion and extra-unit adjustments. Ordinary depth/sequence HP
scaling applies, then the captain receives ×1.25 HP rounded up and 2/3/4
Stoneskin, replacing the generic leader bonuses. Pixel density is unchanged.
Per [director feedback 1](peer_benchmark/feedback/spx-03_feedback_1.md), placement
uses Manhattan range 5–7 from the entry for the captain. Every escort starts at
least 3 from the entry, and every enemy respects the ordinary spawn halo
(`RoomGenerator.ENEMY_SPAWN_SAFE_RADIUS`, currently 2). A strictly closer
follower keeps the captain from being closest; escort[0] is on a shortest grid
path and at least 3 from entry. Every other escort starts within range 3 of the
captain. Every generated room is validated. The approved range supersedes the
protected file's original 4–6, with named constants in `WarbandRoomRules`;
neither supplied data copy is rewritten.

The seeded search retains 20 rerolls. Its deterministic fallback tries the
strict formation first, then relaxes only the other escorts' range from the
captain before clearing interior template blockers if no safe formation fits.
The captain range, minimum escort entry distance, ordinary entry halo and screen
path never relax. An additive `warband_escort_radius_relaxed` layout field marks
the capacity exception; validation rejects it when a strict formation fits.
Dynamo anchors are searched farthest first across all legal reachable
candidates, including full escort capacity under the applicable constraints.

`WarbandCombatRules` computes Command at use time from the living captain and
current follower position. Every positive-damage action receives +1 within
Manhattan range 2. It is idempotent, reflected in board intent tokens, known
moves, projected attack actions, forecasts and resolved damage, including after
movement. The saved intent retains its authored base amounts. The floor banner
uses the existing leader-marker gold (extracted into `LEADER_MARKER_GOLD` without
a colour change), 18% fill and 2 px/70% outer edges. It follows the live captain
and disappears on death; existing Umbra privacy remains in effect.

At a mobile captain's turn, after ordinary start-of-turn statuses, a player
within range 2 triggers one legal movement tile. Farthest screened destinations
win, then farthest unscreened destinations. Actual navigation respects occupancy,
terrain, Rubble, traps, ordinary movement-action Bleed and arrival effects; Frozen/Petrified/Immobilized movement
restrictions and immobile Dynamo are preserved. The normal intent then retargets. Both the initiative and legacy batch APIs
share this activation path.
Full previews use the same resolution and the immediate plan includes this step.

Captain death follows the existing leader objective outcome. Fleeing followers
are cleared without actor-death effects, Tick bursts, summons or reward records.
Individually killed Warband followers also award no Embers. Batched captain /
Tick / Ooze deaths recognize the captain before draining the death queue, so
queued bursts or spawn effects cannot outlive the break. Their simultaneous
escape routes run up to two tiles toward the nearest reachable interior board
edge, respecting blockers and reserving destinations. Presentation runs this one
silent beat, then uses the existing silhouette dissolve. Concealed followers
show their bodies for this escape presentation without executing Erupt/Ambush
or changing the committed mechanic/status state. Reduced motion skips
the run and uses the existing reduced dissolve. `break_line` appears once in the
ordinary action announcement; the existing victory flow owns audio. No map,
reward selection, Ember room payout or variant order behavior is implemented here.

`EnemyIdentity.display_name` resolves the saved per-instance `display_name`,
falling back to the unchanged definition name. It feeds action captions, status
captions, turn-order projections, board/support tooltips, pre-battle cards and
inspection, console output and death/destination presentations. The objective
uses the running form (`Defeat the Stormcaller`) and this exact tooltip:
“Kill the captain and the rest flee. Followers within 2 tiles of it deal +1 damage.”
The existing leader marker is unchanged. All Warband state is ordinary saved
combat data; no save migration or outcome-event schema change is needed.
Instance metadata and internal Command action annotations are additive, and the
analytics context builders are untouched. The heuristic's encounter assumptions
and specification were updated together; intrinsic card coefficients are unchanged.

### Validation and fixture commands

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/spx-03`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/godot_task_runner.py --task-id spx-03 --stream -- godot --headless --path . --script tests/warband_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/godot_task_runner.py --task-id spx-03 --stream -- godot --headless --path . --script tests/warband_ui_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/godot_task_runner.py --task-id spx-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tests/test_icon_identity_policy.py
```

The placement matrix covers six variants × three tiers × 200 seeds, rotating
through all four entrances. The 192 legacy full-layout SHA-256 goldens in
`tests/fixtures/spx03_legacy_golden.json` were captured from unmodified HEAD
`f3beee6fe36b1faa37277a14426831b37f2f043f` generators/objective rules (64 seeds
per revision 3/4/5). The temporary reference copies were removed after capture.
All 18 biome/tier fixture combinations retain an actual matching section room and its connections.
Both focused tests are registered with the full suite's headless program runner.
The UI test parses the native probe without executing it and checks all six
naming paths, both at-rest and Details intent numbers, silent follower audio
snapshots, the reduced-motion break, and real scene combat/pre-battle loading
for the two proof fixtures.

Feedback 1's focused placement pass also covers the exact console reproductions
(`warband air 2 83`, `warband fire 1 7`), a narrow room that can retain its
blockers only by relaxing captain clustering, and a wider ordinary entry halo.
To record first-turn damage for the same 3,600-room matrix, use:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/godot_task_runner.py --task-id spx-03 --timeout 900 --stream -- godot --headless --path . --script tests/warband_test.gd -- --opening-damage-report /private/tmp/labyrinth_codex/spx-03-feedback1-opening-damage.json
```

The optional report uses the existing console incoming-preview path:
`finish_player_activation`, then `advance_to_next_player_turn_with_steps`,
comparing player HP before next-turn setup. It includes Command, initiative and
repeat activations; it does not estimate damage from printed attack totals.
Each room uses fresh-run default equipment/relics and no plays or movement, with
test HP 100 to avoid lethal truncation. It records the count and percentage over
6 HP for every biome/tier cohort and the total. Normal suite runs omit this
extra simulation cost. The director reruns native proof after this focused fix.

The manual headless console accepts `warband <biome> <tier> [seed]`. For example:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/godot_task_runner.py --task-id spx-03 --stream -- godot --headless --path . --script tools/headless_playtest.gd -- --seed 83 --output-dir /private/tmp/labyrinth_codex/spx-03-console
```

Then enter `warband air 2 83` or `warband lightning 3 83`. The command uses the
ordinary combat-start/tracker path with reason `warband_fixture`; outcomes retain
the existing event schemas and local append-only analytics writer.
`tools/inspection_fixture.py --scenario warband --warband-biome <biome>
--warband-tier <1|2|3> --seed <seed>` generates and verifies an ordinary combat
save. `--warband-case keep_distance` puts the hero within trigger range;
`--warband-case break` leaves a 1 HP captain. `pre_battle` is also staged, but
production entry into a special room remains spx-02's integration responsibility.
The capture probe supplies the normal prepared factory directly so it can prove
the production pre-battle UI before that unit lands.

### Proof for the design owner

This sandbox has no macOS window server. Native proof must run on the director's
machine, at 1920×1080 and 100% UI scale. No native capture is claimed here.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/proof_contracts/spx03_warband.json --result-manifest /private/tmp/labyrinth-inspection-manifests/spx-03-visual-result.json tests/warband_probe.gd --task-id spx-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/inspection_fixture.py --task-id spx-03 --run-id spx-03-air-inspection --manifest /private/tmp/labyrinth-inspection-manifests/spx-03-air-tier2.json --launch --scenario warband --warband-biome air --warband-tier 2 --seed 83 --umbra-stage clear
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-03 && python3 tools/inspection_fixture.py --task-id spx-03 --run-id spx-03-lightning-inspection --manifest /private/tmp/labyrinth-inspection-manifests/spx-03-lightning-tier3.json --launch --scenario warband --warband-biome lightning --warband-tier 3 --seed 83 --umbra-stage clear
```

The 180-second visual timeout allows two complete scene preparations and eight
native captures, including movement/death presentation. Capture paths are
`user://probes/spx03/{air_tier2,lightning_tier3}/{pre_battle,first_player_turn,
keep_distance,warband_breaks}.png`; `captures.json` records seed, size, UI scale,
Command followers and resolved movement/break facts. Every body must be
prepared and observed in a native draw before capture. `keep_distance` for Dynamo
proves the required immobile skip; the Stormcaller capture shows a real step.
The probe's unlimited-vision field is capture-only, allowing every follower and
intent to be inspected without changing gameplay visibility rules.

Director feedback 1 approves `WarbandView.BREAK_BEAT_SECONDS = 0.4`, the existing
two-tile travel cadence; the design placeholder is removed. No asset was
created, altered or downloaded. The
proposal URL/diagram was inaccessible to the implementation environment; the
explicit unit brief and protected data are authoritative.

Chosen non-player defaults: proof/test seed 83; fixture biome air and tier 2
when omitted (the console/inspector keep their existing seed defaults);
proof readiness timeout 20 s, settling wait 0.25 s, movement sample wait 0.1 s,
break sample fraction 0.5, unlimited capture vision and Clear Umbra for the
interactive inspection saves;
200 placement seeds per cohort, test player HP 100, fallback-proof seed 123456,
headless foe-card test size 300×400 and 64 legacy seeds per revision. They live
as named test/fixture/proof fields.
