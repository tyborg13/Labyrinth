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

The entry contract is `{type: special, special_type: warband,
special_variant: <biome>}`. `SpecialEncounterLibrary` reads
`data/special_encounters.json`; the staged director copy remains byte-identical.
The spx-07 follower placement object is copied verbatim from
`peer_benchmark/staged/spx-07/followers.json`. Other supplied values are unchanged.

`WarbandRoomRules` uses the specific variant captain and the first 3/4/5 ordered
escorts at the existing local depth tier. It bypasses generic leader selection,
spawn-group expansion and extra-unit adjustments. Ordinary depth/sequence HP
scaling applies, then the captain receives ×1.25 HP rounded up and 2/3/4
Stoneskin, replacing the generic leader bonuses. Pixel density is unchanged.
Per [director feedback 1](peer_benchmark/feedback/spx-03_feedback_1.md), placement
uses Manhattan range 5–7 from the entry for the captain. The protected
`captain.start_distance` value is unchanged; the existing named override remains.
Every enemy respects the ordinary entry halo (currently 2); every follower is
at least 3 from the entry. The ordered escorts now occupy these roles:

- Guard: within the data's `guard_radius` (2) of the captain.
- Screen: `screen_distance` (2–3) from the captain, on both the Manhattan segment
  and a shortest walkable entry-to-captain path.
- Remaining skirmishers: `skirmisher_entry_distance` (3–5) from entry, alternating
  left then right of the oriented entry-to-captain line, with `min_gap` (3) from
  the captain and every other follower. In the grid's y-down convention, left
  has a negative cross product. No followers are adjacent.

A separate flood fill guarantees a walkable route from entry to within 2 of the
captain, avoiding all occupied tiles and every tile next to a screen/skirmisher.
Guard adjacency is permitted on that approach. Every complete formation is
validated. The seeded search retains 20 template rerolls. Its deterministic
fallback preserves all spacing and approach constraints; if no formation fits,
the existing generator clears interior blockers and searches again. It never
relaxes follower spacing. Dynamo still takes the farthest legal complete anchor.

Within each side, the seeded roll chooses among valid candidates with no further
ranking. Tiles on the entry-to-captain line (cross product zero) belong to neither
side and never take a skirmisher. Deterministic fallback retains the established
candidate scan order, preserving every role/range/gap/approach constraint.

`WarbandCombatRules` computes Command at use time from the living captain and
current follower position. Every positive-damage action receives +1 within
Manhattan range 2. It is idempotent, reflected in board intent tokens, known
moves, projected attack actions, forecasts and resolved damage, including after
movement. The saved intent retains its authored base amounts. The intent
medallion and Details compass numbers use the plan's projected attack action,
so moving into or out of Command changes the displayed damage before the
enemy moves. The floor banner uses the existing leader-marker gold
(extracted into `LEADER_MARKER_GOLD` without
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

Feedback 2 adds red/green regressions for the moving Ash Hound's medallion and
Details numbers (entering and leaving Command), the seed-54 DOWN screen and a
reachable grid-shortest detour rejected by Manhattan equality, and the fixture's
Windows-safe typed case list. Break coverage inspects `death_burst_events`, puts
a Tick adjacent to the player, and puts a follower three tiles from the nearest
edge to require a two-tile stop before dissolve. Controlled Tick-burst and
unbounded-route mutations are rejected by these assertions; both mutations
escaped the prior break checks. No production break behavior changes.

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

## Umbral Snare (spx-05)

`types.umbral_snare.enabled` is true in both director data copies; all other
Snare director values remain unchanged. Revision-6 placement keeps its existing
requirement for at least two outgoing branches. The objective remains
`reach_exit`, and its exit destination coordinates come from those branches.
Revision-5 and earlier Reach Exit generation, saved objectives and RNG are
unchanged. No variant `pressure` fields are consumed (spx-06 owns them).

`SnareRoomRules` orders exits by shortest walking path from entry to threshold,
then the lower map lane. SectionMapGraph stores outgoing connections in lane
order, so their saved ordinal breaks ties without inferring lanes from ring
coordinates. The first is the permanent jailer door. The remaining doors seal
after 2 and 4 completed player turns, in path order; a single sealing door uses
3. Every threshold has at least five walking edges from entry. Generation uses
20 seeded template retries, then deterministic interior-blocker clearing,
retaining every exit and unit. Blocking terrain cannot occupy the selected
walking lanes. Entry directions and ordinary rooms retain their existing rules.
The 5-tile minimum stops free movement from escaping on turn 1; an escape that spends cards on turn 1 is earned.

The Umbral Gaoler uses the normal depth-scaled Chainbound Gaoler, then ×2 HP
rounded up and the director's 2/3/4 Stoneskin. It starts one path tile inside its
threshold and keeps its normal AI. Each other exit has a Veilbound Acolyte titled
Sealbinder, exactly 4 HP, on a distinct free adjacent interior tile. Its sole
intent is `Seal · N` with no actions; forced movement cannot move it.

In the initiative engine an enemy round is the interval from finishing a player
activation to preparing the next player activation. The saved
`player_turns_completed` counter advances once at its start; seals resolve at its
end, before player-turn setup. Enemy activation count, repeats and initiative
Time do not advance the timer. The legacy batch resolver uses the same hooks.
At the deadline an unprotected sealing door becomes impassable to player,
enemy and forced movement; it is excluded from objective exits. Its Sealbinder
silently dissolves using the existing dissolve presentation, without death
rewards, death effects, kill credit or sound. Killing the binder first saves
`kept_open` on its door permanently. The jailer door has no timer.

Actor passability is centralized in `CombatEngine._tile_is_passable`, backed by
one objective-blocker lookup. Actor placement, player destination targeting and
commit (including stale previews), current/future AI anchors and forced movement
use it; navigation blocker maps carry the same sealed tiles. This covers Mirror
Image followed by Changing Winds as well as an illusion that already occupies a
threshold when it seals. Geometric surface queries, LOS and the renderer retain
the ordinary grid; no accepted Snare visual is changed by this enforcement.
Relic navigation enumerates state-passable actor tiles before applying enemy
occupancy or illusion-endpoint exceptions. Vaulting Sigil cannot cross a sealed
threshold even when a live enemy occupies it; geometric tile enumeration still
includes that floor for attack and surface patterns.

Each active sealing door has a content-sized HUD-skin chip, `Seals · N`, with
Wind's title font size, plate, fill, border and padding, minus its icon and arrow.
Its centre aligns with the destination medallion; its bottom is 6 px above the
medallion's painted top at default 1920×1080 board zoom. Both chip and gap scale
with board navigation zoom. Placement reuses `_door_icon_visual_rect`, including
the medallion ring. The chip's Control holder preserves canvas/theme ancestry.

`UiSkin.SURFACE_HUD` supplies a transparent layout StyleBox plus the shared
`ThemedPanelOrnament` paint. A PanelContainer had fitted that ornament inside the
padded content rect (18 px tall for this label), below its 36 px drawing minimum.
`SnareSealChip` keeps the exact ornament outside container layout under a Node2D
paint host and sizes it to the full panel. The regression checks a non-empty
layout StyleBox, drawable full-panel ornament, shared HUD variant and typography.
No replacement surface, palette or font is authored.

Sealing thresholds reuse the existing objective-overlay alpha with
`UiPaletteTokens.UMBRA`. Killed binders and sealed doors lose their chips. The
sealed door and opening textures use `SNARE_SEALED_DOOR_MODULATE`, derived from
`UiPaletteTokens.UMBRA` at 60% RGB brightness and alpha 1.0 (director mock option D).
A sealed door submits no destination medallion: icon, ring and unknown placeholder
are all absent. Other doors retain their ordinary medallions. There are no new
colour literals, icons, assets, timings or input targets. Chip controls ignore
pointer input and keyboard/controller focus. Reduced motion uses the existing
static/dissolve behavior.

The existing intent tooltip shows `Seal · N` followed by this exact rules line:
“Seals its door in N turns. Kill it to keep the door open. When you escape, each
open door pays 6 Embers.” At N = 1 it says “in 1 turn”. The payout comes from
`embers_per_open_door.amount`, and the live saved timer supplies N. Pointer and
controller inspection use the same title and description.

At each enemy-round start a variant hunter enters on the entry threshold, or
the nearest free tile in a stable breadth-first walk. The saved total-arrival
count caps at 3, including killed hunters; lists alternate by that count. Ice
instead places its 3 Rime Whelps on the nearest free starting tiles at least two
tiles from the hero and receives no later arrivals. Hunters use normal enemy
AI and scaling. The special starting reward roster contains only the Gaoler
and Sealbinders; hunters do not enlarge it.

The generated layout records the authored physical threshold as `snare_entry`
before True Bearing selects another player start. Combat creation copies that
field into its existing saved `snare_entry` key. Round arrivals always use the
physical entrance, including when it is now free. After True Bearing's final
start is known, ice's three hunters are placed again in the same deterministic
breadth-first entry order, excluding occupied tiles and tiles less than two
Manhattan edges from the final player. Preview and combat entry use the same
final layout. Ordinary authored starts retain their original placements; timers,
arrival totals, rewards and analytics fields retain their existing format.

Any open exit threshold still wins and commits its branch through the ordinary
pending-escape flow. The Snare goal always succeeds on escape. The existing
4-card special offer retains its Rare floor and 1.5× starting-roster Embers;
`run_engine.gd` adds exactly 6 Embers per open exit, including the used door.
The existing completed-room guard prevents duplicate payment. Saved combat data
contains the entry threshold, door roles, timers, protected/sealed flags,
Sealbinders, total hunters and pending-round bit. No migration or format change
is needed. `combat_ended` adds the two fields documented in analytics.md.
No player-card coefficient or card mechanic changes, so no intrinsic card score
is recalibrated; these fixed encounter assumptions are the director's tuning.

### Validation and proof for the design owner

Headless proof lives in `tests/snare_test.gd` and `tests/snare_ui_test.gd`, both
registered with the full suite. The matrix covers six variants × three tiers ×
200 seeds, alternating two/three exits and rotating all four entrances. It checks
path/role ordering, seal times, exact unit identities/HP/positions, complete
rosters and the five-edge rule. Focused checks cover forced fallback, exact round
boundaries, binder kills/immobility, blocked thresholds, silent removal, total
hunter caps and alternation, ice starts, normal pre-battle entry, 1/2/3-open-door
rewards, branch commitment, analytics on both callers, and mid-round save/load
through production repair. Existing 192 full-layout goldens for revisions 3–5
include revision-5 Reach Exit. UI checks parse the native probe, inspect actual
HUD-skin chip lifecycle/input behavior, exact plate geometry, medallion spacing at
default and changed zoom, door/opening draw submissions, singular/plural tooltip
text, and all four combat proof fixtures. The legend gate checks row count,
centering and exact 40–12 px gap behavior on either side of the fit boundary,
without a fixed enabled-concept count.

`tests/suites/snare_regression_suite.gd` adds feedback-2 stock-card and stock-AI
reproductions after the real turn-two seal: Mirror Image → Changing Winds at
(7,4), a live illusion on a sealed destination, and Cudgel Press from (7,3)
toward the hero at (7,5). These also run in `illusion_terrain_test.gd` and
`enemy_pathfinding_test.gd`. Production True Bearing cases cover seed 83,
lightning (2,0), and seed 0, ice (3,-2), both selecting (1,3). The authored
entrance remains (1,4), and the ice roster remains at least two tiles away.
Explicit formation adversaries reject four edges, accept five, and force the
room generator to retry a first four-edge candidate. `--feedback-2-only` on
`snare_test.gd` runs these regressions without the placement matrix. The change
restores existing movement/card assumptions; no card coefficient, balance value,
text, palette, asset or animation is redesigned.

Feedback-3 regressions strand the Gaoler on (7,4) before the real turn-two seal,
equip Vaulting Sigil and attempt turn-three free movement from (7,5) to (7,3).
The path, card targets, free-movement targets and commit all reject that crossing,
while raw geometric enumeration retains (7,4). This case also runs in the player
movement and relic U7 suites. Separate tests call direct illusion placement on
the seal and Push the Gaoler from (7,3) toward it: placement is rejected, and
Push stops before the seal with wall collision damage. These run in the illusion
and forced-movement suites as well, independently covering their low-level guards.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/godot_task_runner.py --task-id spx-05 --stream -- godot --headless --path . --script tests/snare_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/godot_task_runner.py --task-id spx-05 --stream -- godot --headless --path . --script tests/snare_ui_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/godot_task_runner.py --task-id spx-05 --stream -- godot --headless --path . --script tests/special_encounter_legend_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tests/test_ui_identity_lint.py
```

The console accepts `snare BIOME TIER [seed]`, for example `snare fire 2 83`.
It shares its factory with `--scenario snare --snare-biome BIOME --snare-tier TIER`
and `--snare-case encounter|first_turn|first_seal|kept_open|escape` in the ordinary
inspection fixture tool. It starts the normal combat tracker with reason
`snare_fixture`; analytics remain local append-only JSONL.

Windowed proof cannot run in the implementation sandbox. The director runs:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/proof_contracts/spx05_snare.json --result-manifest /private/tmp/labyrinth-inspection-manifests/spx-05-visual-result.json tests/snare_probe.gd --task-id spx-05
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/inspection_fixture.py --task-id spx-05 --run-id spx-05-fire-first-turn --manifest /private/tmp/labyrinth-inspection-manifests/spx-05-fire-first-turn.json --launch --scenario snare --snare-biome fire --snare-tier 2 --snare-case first_turn --seed 83 --umbra-stage clear
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/inspection_fixture.py --task-id spx-05 --run-id spx-05-fire-first-seal --manifest /private/tmp/labyrinth-inspection-manifests/spx-05-fire-first-seal.json --launch --scenario snare --snare-biome fire --snare-tier 2 --snare-case first_seal --seed 83 --umbra-stage clear
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/inspection_fixture.py --task-id spx-05 --run-id spx-05-fire-kept-open --manifest /private/tmp/labyrinth-inspection-manifests/spx-05-fire-kept-open.json --launch --scenario snare --snare-biome fire --snare-tier 2 --snare-case kept_open --seed 83 --umbra-stage clear
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/inspection_fixture.py --task-id spx-05 --run-id spx-05-fire-escape --manifest /private/tmp/labyrinth-inspection-manifests/spx-05-fire-escape.json --launch --scenario snare --snare-biome fire --snare-tier 2 --snare-case escape --seed 83 --umbra-stage clear
```

For a map capture with the enabled Snare and the fullest legal legend, reuse the
spx-02 probe (the first command only writes its proof contract):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/godot_task_runner.py --task-id spx-05 --stream -- godot --headless --path . --script tests/special_encounter_probe.gd -- --proof-contract-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-05 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth-inspection-manifests/spx-02-visual-contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/spx-05-map-visual-result.json tests/special_encounter_probe.gd --task-id spx-05
```

Map captures are `user://spx-02-map-proof/01_future.png` through
`08_section_vi_fog.png`; `07_fullest_legend.png` includes Umbral Snare and the
approved centred second row. The probe asserts that the enabled Snare is present.

The native probe asserts 1920×1080 and 100% scale, renderer preparation and real
body draws. Its captures are
`user://probes/spx05/fire_tier2/{first_turn,first_seal,kept_open,escape,sealbinder_tooltip,escape_reward}.png`,
with a neighboring `captures.json` recording chip labels, exits, bonus facts,
actual rendered tooltip lines, pointer/Sealbinder identity, reward payout and the
visible Ember-total label. The tooltip frame uses real viewport pointer input over
the left Sealbinder in the first-turn state and waits for its actual embedded
Godot tooltip. The reward frame finishes the escape through `RunEngine`, waits
for the ordinary reward reveal and asserts four offers plus the visible held
Ember total. These two frames are required by the six-image proof contract.
The first-seal and kept-open fixtures advance the real initiative engine across
the first deadline; escape resolves the final legal movement step.

Chosen debug defaults: seed 83, fire tier 2; three valid next-row destinations
from the actual requested section/tier so every fixture has both chips (some
natural rows have no branching combat node); 100 hero HP for unattended
boundary survival; a 0.25 s renderer settle and 20 s readiness timeout; capture-only
unlimited vision. The 180 s visual timeout accommodates four scene preparations plus the tooltip
and reward reveal; the new frames reuse their first-turn/escape scenes.
Headless fixtures use 100 HP and a fixed 100×100 door rect at (100,100) solely
for chip-placement assertions, a 1.25 navigation zoom for scaling checks, and a
1 px legend boundary delta. The door-submission double reuses the approved door
texture; its recorded draws never change production art. None of these fields changes production tuning.
The proposal URL/diagram could not be accessed; no external art was downloaded.
Commits, peer review, native inspection and publication belong to the design owner.

The enabled Snare exposes eleven concepts in the fullest production map legend.
The director confirmed spx-02's existing layout rule: use one row while even gaps
can shrink from 40 px to 12 px; otherwise use a centred second row. The production
layout already implements this rule. Both gate and native probe now derive the
entry count from the displayed section instead of expecting ten concepts.

The first-turn fixture preserves the director's allowed card-assisted escape:
two legal Shadow Step copies use normal preparation, action and finish paths on
seed 83. The free-movement assertion remains. The named two-copy test hand is a
debug fixture, never a production deck change. All three design placeholders are
resolved by the director's feedback; no pending design values remain.

### Observed feedback-2 proof (2026-10-21)

The unchanged implementation failed the new reproductions with
`Snare suite: 11 failures`. After the fixes, the focused programs below pass.
The previously surviving `MIN_EXIT_PATH_TILES` 5 → 4 mutant now exits 1 with
`Snare suite: 3 failures`: four-edge rejection, short-layout reroll and retained
five-edge minimum. The constant was restored to 5 before the passing runs.

```text
Snare suite: 0 failures
Snare UI/fixture suite: 0 failures
SPX special encounter suite: 0 failures
SPX fullest legend: seed=0 section=2 entries=11 rows=2
SPX special legend suite: 0 failures
Warband suite: 0 failures
Warband UI semantics: 0 failures
ILLUSION TERRAIN TEST RESULT: PASS
ENEMY PATHFINDING TEST RESULT: PASS
Ran 25 tests in 2.615s
OK
```

Logs are `/private/tmp/labyrinth_codex/spx-05-r2-{snare,snare-ui,special,legend,warband,warband-ui,illusion,ai,identity}.log`;
red and mutation evidence are `spx-05-r2-red.log` and
`spx-05-r2-minimum-mutant.log`. The Warband UI program emits shutdown leak
warnings (four resources still in use) after its zero-failure result. Full suites
and windowed runs were not requested or run. The director accepted feedback-1's
native captures; visual code and both director catalogs are unchanged this round,
including the director-owned Stormcaller sentence.

### Observed feedback-1 proof (2026-10-21)

The director requested focused checks only for this round; full suites were not
rerun. The effective plate regression failed against the pre-fix implementation
(`Snare UI/fixture suite: 1 failures`), demonstrating the padded-content cause.

```text
Snare placement matrix: 3600 rooms (6 variants × 3 tiers × 200 seeds), 2/3 exits, 4 entries
Snare first turn: free movement cannot escape; two legal Shadow Steps can
Snare suite: 0 failures
Snare UI/fixture suite: 0 failures
SPX fullest legend: seed=0 section=2 entries=11 rows=2
SPX special legend suite: 0 failures
Ran 25 tests in 2.764s
OK
```

Focused logs are `/private/tmp/labyrinth_codex/spx-05-feedback-{snare,ui,legend,identity}.log`.
Native frames remain for the design owner; no windowed run is attempted here.

### Observed implementation proof (2026-10-21)

```text
Snare placement matrix: 3600 rooms (6 variants × 3 tiers × 200 seeds), 2/3 exits, 4 entries
Snare suite: 0 failures
Snare UI/fixture suite: 0 failures
SPX special encounter suite: 0 failures
SECTION MAP PERFORMANCE PROGRAM RESULT: PASS (6378 checks, 0 failures)
Warband suite: 0 failures
Warband UI semantics: 0 failures
TEST REGISTRATION AUDIT: PASS (777 scripts; full suite=426, quarantined=29, windowed probe=322)
Ran 1563 tests in 1781.865s
OK (skipped=66)
FULL SUITE RUNTIME: 465.815 seconds (budget 900 seconds)
TEST RESULT: FAIL (2 failure(s))
```

The two failing Godot children are `encounter_measurement_test` (the golden and
current-objective assertions also fail at the unchanged integration HEAD), and
`special_encounter_legend_test` (the obsolete ten-concept/one-row expectations,
replaced and passing in feedback 1 with the director-approved responsive rule). The underlying
map-solver regression now validates its original combat domains before special
substitution; post-substitution identities, branching and route limits remain
covered by the special suite. UI identity passes 25 tests, icon identity passes
7, and Godot sidecars pass 19. The headless console reproduction exits 0.
Native captures and the verified, launched inspection fixture remain the design
owner's work; no windowed result is claimed.

Local proof logs are `/private/tmp/labyrinth_codex/spx-05-focused-final.log`,
`spx-05-ui-final.log`, `spx-05-full-godot-final.log`, `spx-05-full-python.log`,
`spx-05-baseline-measurement.log`, `spx-05-baseline-map-performance.log`, and
`spx-05-baseline-legend.log`. The baseline legend has ten concepts/one row and
passes; the temporary baseline project was removed after comparison.

At the final scope check, both catalogs also contained a concurrent Warband air
order-copy edit, from “everything” to “everyone else” in its wind sentence. That
unrelated edit was preserved. This unit's catalog write was only the Snare
`enabled` flag, and the remaining Snare object matches the supplied data exactly.
Both catalog copies remain byte-identical.

## Warband hover and wind implementation (spx-07)

Pointer sweeps use the real `CombatBoardView._gui_input` path and synchronously
drain only that input's deferred presentation. `tests/spx07_hover_benchmark.gd`
records all board-tile inputs, same-tile motion, card selection and card dragging,
existing phase timings, and complete board/preview snapshots. Inputs are frozen
from the base so intentional spawn/wind changes do not contaminate optimization
equivalence. A freshly assigned analytics combat id is excluded from comparison;
legacy intent hydration is tested separately. This is headless CPU-handler
measurement, not a native frame-time or renderer measurement.

Focus changes now reuse rest badge/Command/threat plans and only apply opacity.
Owned, bounded preview memoization verifies full input equality after hashing;
callers receive independent plan copies. Range coverage reuses its grid, terrain,
trap, action and footprint geometry. Presentation mechanics retain their preview
engines across hover submissions. Empty wind forecasts are retained as well.
Motion within the current tile no longer refreshes the drag's selected-card
forecast. No animation timing, visual markers, input routes or assets change.

The ordinary route search uses a stable minimum heap with the original route
comparator and FIFO ties. Its reference scan remains available for equivalence
proof. Presentation adapters copy the outer containers they change and retain
unchanged nested evidence. Enemy threat and real-resolver damage evidence are
memoized together, preserving card-damage precedence.

PASS's loss-only cursor can omit unrevealed future intent rolls and animation
snapshots for a closed, deterministic starting-loadout subset. Eligibility is
owned by `combat_preview_known_losses.gd`; unknown loadouts, mechanics and engine
subclasses retain the full simulation. It still resolves every announced action
and end-turn effect. This compact result is only a loss/uncertainty forecast;
normal gameplay, animation and full-state previews keep their complete state and
RNG continuation. The benchmark compares its summaries against the full selector
outside the timed input samples. CPU budget failures remain assertions.

Call the Wind stores `_wind_direction` in its selected action. Gale Herald and
Stormcaller previews and resolution read that same field; player moves, card
plays and pointer motion cannot re-aim it. A new own-turn intent selection can
choose the next direction. Active held wind retains its saved direction and
normal persistence/death rules. The owned load boundary fills missing legacy
announcements once from the resumed board, preserving any existing locks.
These are additive saved intent fields; analytics schemas and append-only event
writers remain unchanged. No card values or heuristic coefficients change.

Focused wind proof is `tests/warband_wind_lock_test.gd`. The existing Warband
suite checks 6 variants × 3 tiers × 200 seeds, four entry directions, role order,
Command range, screen geometry, alternating sides, gaps and an independent
approach flood fill. (The frozen ordinary order-control layouts and their spx-04 golden were retired by el-02, when
the Warband orders became battlefield-rule instances; the battlefield-rule and element-retrofit suites cover them.)

The headless proof and current remaining budget failures are recorded in
`output/spx07/HANDOFF.md`. Native first-turn proof uses the existing Warband probe
with `--first-turn-only`, `tests/proof_contracts/spx07_warband.json`, 1920×1080 and
100% UI scale. See `output/spx07/design_owner_proof.sh` for exact renderer,
frame-time and verified inspection-fixture commands. Native captures must be
run by the design owner on a machine with window-server access.

Director feedback 1 adds `tests/spx07_frame_benchmark.gd`: the director's exact
viewport-input path, 1.5-second settling period, four seconds idle and six seconds
of motion per fixture. It awaits real process frames, including deferred work and
queued CanvasItem draws. It retains raw `Performance.TIME_PROCESS` readings,
actual iteration intervals, frame-indexed board render sections, script phases
and redraw counts. Headless sampling disables low-processor mode and its fallback
sleep, with no frame cap. Godot holds the process monitor across multiple frames;
raw monitor percentiles and actual frame percentiles are reported separately.
This proves script work, not native GPU/frame delivery. The director reruns the
unchanged native probe. Director feedback 2 accepts the measured targeting floor:
card/drag limits are 6 ms median / 40 ms worst; further targeting optimization is
tracked as perf-02. Synchronous hover retains its 12 ms worst-case limit.

The measured draw hot spots were repeated path geometry/clip construction and
death-burst presence checks that scaled whole enemy intent catalogs per tile.
`board_path_draw_cache.gd` retains the original ordered polygon/line commands and
the original per-tile clipping operations; gradients, distress, colours and depth
order are preserved. Known intent paths are prepared once per committed board
revision, synchronously. The original builder remains the command-equivalence
oracle. The Warband UI test exercises cold/warm caches at two proof layouts.
Lob/Burrow mark views retain their pure preview engines; wind evidence is shared
between retained layers. `GameData.enemy_def` memoizes pure fixed-point scaling
against the exact raw definition while still returning private copies. In-place
catalog edits invalidate the memo. Planner anchor snapshots reuse their already
owned enemy array instead of deep-copying it twice.

All public cache results own their nested dictionaries, arrays and packed data.
Badge focus variants only share evidence internally; every published focus or
unfocused snapshot is a deep copy. Path-cache result snapshots also own mesh
resources, since ordinary container deep copies keep Resource references. The
production renderer prepares and draws private cached paths without publishing
those entries or meshes. It retains submitted mesh RIDs until the canvas's next
draw and releases that storage on canvas exit. Public clip queries validate the
commands in caller-owned entries as well as their ids. Every hash-indexed unit
cache verifies exact owned inputs; wind has no view-local hash-only shortcut.
One owned wind forecast serves each synchronous overlay tile loop.

`tests/helpers/spx07_cache_ownership_cases.gd`, registered through the Warband UI
suite, mutates each nested container independently and checks both retained
results and later hits. It covers memo, plan, threat/coverage/geometry, catalog,
orders, badge focus, wind, paths, clips and mesh resources. Its locked-wind
collision fixture preserves the reviewer's unequal states hashing to 2943709617:
hero `(2,3)` with nonce 104756 and `(8,8)` with nonce 8893, including undo.

## Umbral Snare: the room closes in (spx-06)

The six `pressure` objects are imported without edits from the protected
`spec/peer_benchmark/staged/spx-06/pressures.json`. The production and staged
special catalogs remain byte-identical. `snare_pressure_rules.gd` owns selection,
initialization and saved pressure state; Snare round start applies pressure
after the escape guard and before adding a hunter or resolving enemies. The
existing pending-round bit makes player completion idempotent. Seals retain
their end-of-enemy-round boundary.

| Variant / id | Exact implementation |
| --- | --- |
| Earth / `rubble_lane` | Ignore units, retain walking blockers, charge two to leave Rubble. Choose the cheapest open exit route; equal costs retain spx-05's door order (`path_tiles`, then `map_lane`). Path ties retain the existing cardinal discovery order. Paint the first legal, non-threshold, non-Rubble tile at least two path steps away. Recompute from the current board each preview/completion. |
| Fire / `fire_rows` | Snapshot entry walking distances before the first player turn, without unit/surface costs. On player completion N, paint the legal non-exit tiles at stored distance N−1. Ordinary Fire placement, entry and turn-start contact rules remain authoritative. |
| Air / `headwind` | Persist a room-owned wind with the entry-wall direction and authored push distance. Apply the existing mover once per player completion, with its ordering, collisions and anchors; Sealbinders are anchored. Enemy completions cannot repeat this wind. The existing chip's arrow remains and its title is exactly `Headwind`, with no count. Existing wind animation and reduced-motion timing are reused. |
| Ice / `frost_thresholds` | Before the first player turn, place ordinary Ice on each sealing threshold's inward adjacent floor tile with the shortest entry walk; ties use lower x, then lower y. Sealing does not remove the surface. |
| Lightning / `live_tethers` | The saved pressure id is retained. After each player turn, the existing `snare_lightning` rule strikes every Electrified tile for 3. Arc Thralls use Arc Bolt (Move 2 + ranged lightning 3, range 3, Electrified rider); ordinary movement, hover previews and damage rules apply. No crossing hook or passive enemy path is added. |
| Shadow / `umbra_rings` | Start at the normal section's Umbra stage, subtract one radius after each two completed player turns, and stop at one. Existing Light and vision effects still contribute normally. Door art, thresholds, chips and Sealbinders remain visible beyond sight. |

The objective description is shared by the HUD and pre-battle heading; the exact
pressure text is its last line. `snare_pressure_view.gd` uses the existing
Thornwall marked-intent area style, with no new art, icon, colour or marker.
Earth and Fire mark exactly the changed tiles; an upcoming sight reduction
marks exactly the tiles leaving visibility. Headwind retains its shared wind
forecast and collision paths; Ice and Electrified ground retain their ordinary surface
and telegraph evidence. Pressure presentation uses the exact, owned preview memo
so focus changes reuse the resolver while mutations invalidate it.

Saved combat data adds `snare_pressure` (id, radius loss, and Fire's immutable
distance map when applicable); room wind remains in the existing `wind` field.
Both player-turn and pending-enemy-round saves round-trip through production
repair for all six variants. Pressure event/terminal fields are documented in
`analytics.md`. Fire can kill arriving hunters; their existing zero-Ember
contract is honored at the death-reward boundary as well as in the fixed
starting-roster special reward. Seal dissolves still have no death effects.
No card mechanics or intrinsic card coefficients change; the encounter-only
pressure values are the director's supplied tuning.

### Implementation proof and design-owner renderer commands

`tests/snare_test.gd -- --pressure-only` runs the pressure suite independently;
the ordinary Snare entrypoint also includes it, including in the full Godot
manifest. Coverage includes fixed exact tiles/slides, lane switching, Fire's
immutable distances, collisions/anchors, Ice tie-breaks, repeated live entries
by walking/force and production damage chips, fog exemptions, all-six saves
and pending-round continuations, both JSONL callers and retry deduplication,
and tier-two seed-83 fixtures. The existing Snare matrix remains six variants ×
three tiers × 200 seeds; the revision-5 and Warband checks remain registered.
The seal-only no-death-rewards fixture uses Earth so Fire killing a hunter does
not confound that assertion; the pressure suite separately checks those deaths.

The implementation sandbox has no macOS window server. These commands are
prepared for the design owner and have **not** been run windowed. The probe
captures player turn three in every variant at exactly 1920×1080 and 100% UI
scale, with two aligned planned Thralls and already-shrunk normal Shadow sight:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh capture
```

That command runs exactly:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && python3 tools/visual_probe_runner.py --task-id spx-06 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/proof_contracts/spx06_snare_pressures.json --result-manifest /private/tmp/labyrinth_codex/spx-06-pressure-captures.json tests/snare_probe.gd -- --pressures-only
```

PNG paths are `user://probes/spx06/pressures_tier2/<biome>_turn3.png`, with
`captures.json` beside them and the validated result manifest above. The probe
prints each absolute capture path. Non-Shadow capture-only vision uses the
existing named `CAPTURE_VISION_BONUS`; Shadow keeps its real fog. The six-case
probe uses a 180-second execution budget while retaining the startup watchdog.
Fresh renderer inspection and the UI identity judge remain the design owner's
steps after implementation.

Each playable fixture command regenerates, verifies and launches its own saved
state. Use any of these exact task-local commands:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture earth
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture fire
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture air
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture ice
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture lightning
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && bash tests/spx06_design_owner_proof.sh fixture shadow
```

For example, the lightning wrapper expands to:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && python3 tools/inspection_fixture.py --task-id spx-06 --run-id spx-06-lightning-pressure-turn3 --manifest /private/tmp/labyrinth-inspection-manifests/spx-06-lightning-pressure-turn3.json --launch --scenario snare --snare-biome lightning --snare-tier 2 --snare-case pressure_turn3 --seed 83
```

The console accepts `snare <biome> 2 83 pressure_turn3` and prints the exact
pressure text plus the live tile/radius/slide forecast. Debug-only choices are
named fields: the focused test's 9×9 open board and 1000 HP; `TEST_POSITIONS` uses entry
`(1,4)`, hero `(4,4)`, exits `(7,4)/(4,1)/(4,7)` and Thralls `(2,3)/(6,3)`;
fixture endurance retains the existing 100 HP. Proof Thralls keep their natural
positions and receive the stock scaled Arc Bolt intent. No player-visible tuning or asset was invented.
There are no `TODO_DESIGN_*` placeholders.

### Observed implementation verification (2026-10-21)

The final-source Godot full run completed with these exact result lines:

```text
Snare placement matrix: 3600 rooms (6 variants × 3 tiers × 200 seeds), 2/3 exits, 4 entries
Snare suite: 0 failures
Snare UI/fixture suite: 0 failures
Warband suite: 0 failures
WARBAND ORDERS TEST RESULT: PASS (214 checks, 0 failures)
SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)
FULL SUITE RUNTIME: 539.269 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
```

The only failing registered child is the unchanged `special_encounter_test`:
`SPX special encounter suite: 2 failures`. Its two assertions require the real
resource-loader imports of the approved production and staged emblems. This
worktree's `.godot/imported/` cache lacks the `.ctex` files named by the existing
Warband, Snare, Ember Hoarder and Last Light sidecars. The emblem assets,
sidecars and assertions were not edited. All other 187 registered child
programs passed; the main body executed 494879 assertions. The earlier broad
run reported the same child failure. No editor scan was used to mask it.

Final Godot log: `/private/tmp/labyrinth_codex/spx-06-full-godot-final.log`.
Focused logs: `/private/tmp/labyrinth_codex/spx-06-{pressure-final,snare-final,ui-final,warband,wind-lock}.log`.
The UI identity gate separately reported `Ran 25 tests in 3.532s` and `OK` in
`/private/tmp/labyrinth_codex/spx-06-identity-final.log`. Shell syntax and
`git diff --check` exited zero. A separate catalog check reported:

```text
Pressure director import: PASS (six exact objects; catalogs byte-identical; protected data unchanged; no unrelated catalog values changed)
```

The production fixture wrapper generated and reloaded Shadow and Lightning
without launching a window; each reported `Inspection fixture verified.`.
Their manifests are
`/private/tmp/labyrinth-inspection-manifests/spx-06-shadow-pressure-headless.json`
and
`/private/tmp/labyrinth-inspection-manifests/spx-06-lightning-pressure-headless.json`.
All six variants' staged turn-three and saved-pressure contracts also passed
in the focused suite. The historical console smoke log at
`/private/tmp/labyrinth_codex/spx-06-console.log` predates `thrall-rework-v1`.
Current lightning pressure copy is
`Snare pressure [live_tethers]: After each of your turns, lightning strikes every Electrified tile for 3.`

No native capture has been generated or inspected in this sandbox. The PNG
paths and windowed commands above are the design owner's remaining renderer
proof. The branch remains uncommitted; no peer review or publication was run.
The four new GDScript sidecars were created and round-trip validated through
Godot's native UID API without an editor scan:
`Snare pressure script UIDs: 4 native identities written and validated`
(`/private/tmp/labyrinth_codex/spx-06-uids.log`).

The full Python suite was also run from this worktree with
`python3 -m unittest discover -s tests -p 'test_*.py' -v`. Its exact final result
was:

```text
Ran 1635 tests in 2535.354s
OK (skipped=66)
```

The complete verbose log, including every skip reason, is
`/private/tmp/labyrinth_codex/spx-06-full-python.log`. No assertion or optional
test gate was weakened. All changes remain uncommitted for the design owner.

### spx-06 director feedback 1 (checkpoint 463c6a0c5)

1. `CombatEngine.prepare_player_activation_end` owns the snapshot after the
   escape guard, block conversion, activation-end relics, tempo/maneuver expiry,
   Bleed cleanup and scheduling. Both the live pressure forecast and actual
   player completion use it. Resolution selects from the already prepared
   snapshot, without applying preparation twice. The console/batch Snare API
   also crosses this boundary when called directly from a player activation.
2. Pressure presentation and memo results contain only `tiles`,
   `displacement_paths` and `collision_markers`. Collision projection retains
   only the shared icon/tooltip/dedup fields. Room-wind presentation uses the
   same projection; resolver states and analytics bookkeeping are excluded.
   Exact source inputs still validate cache hits. The six-frame native probe
   compares projections, so analytics added by scene loading cannot create a
   false mismatch.
3. Sealbinders rely on the existing forced-movement guard. The duplicate
   wind-specific anchor predicate is removed. Both free-space immobility and
   collision against a Sealbinder remain covered by the pressure suite.
4. Room-wind depth drawing reads submitted displacement paths directly, rather
   than validating a complete rules query for each clipped tile. Public wind
   forecasts retain exact dependency validation. No path, marker, animation,
   timing or visual style changes.

The boundary suite uses the real `cinder_trail` card actions. Before the fix:
`Snare Cinder Trail forecast HP=2; outcome HP=0` and `Snare suite: 9 failures`
(`/private/tmp/labyrinth_codex/spx-06-feedback-before.log`). After the fix:
`Snare Cinder Trail forecast HP=0; outcome HP=0` and `Snare suite: 0 failures`.
It additionally exercises Worldheart's actual end-turn conversion, its pulse
and an Ember Tick's death burst for each of the six pressures. This covers
new Fire before Fire-row selection, Fire replacing an Ice approach, changed
actors/defenses before wind, prepared sight reduction, and lethal preparation
cancelling the pressure boundary for every variant. An observing subclass
records the real relic hook's output without replacing its behavior. Further
checks cover immutable source state, drawn-only memo results, scene-load
analytics independence and unchanged submitted wind paths.

#### Frame comparison and attribution

`tests/snare_pressure_frame_benchmark.gd` preserves the reviewer's real-iteration
headless sweep: tier 2, seed 83, player turn 3, 1920×1080, UI scale 1,
uncapped processing, 1.5 seconds settle, 4 seconds idle and 6 seconds of viewport
mouse motion per variant. Queued CanvasItem drawing executes in these samples;
this is CPU evidence with the dummy renderer, not native/GPU frame pacing.
The comparison disables the review probe's absolute budget gate on both sides
and retains raw intervals, monitor peaks and section costs. `FRAME RESULT: PASS`
means fixture/input/drawing/orphan assertions passed, not that every interval
met 16 ms.

`tools/snare_pressure_performance.py` archives integration `d96eadf4f` into a
short-lived directory inside this worktree; it never checks out or alters Git
state. Both revisions use one identical test fixture adapter. Assets/fonts are
unchanged between these revisions and shared read-only. The helper records
revision/diff and workload hashes. Two natural-board pairs reproduced the
Earth and Lightning spikes on the base. Natural Air differs because headwind
moves hunters onto the pointer sweep, causing enemy-hover redraws absent in
the base. The additional control pair loads byte-identical saved turn-three
boards on both sides, including those positions, with fixture hashes checked.

Apple M5 Pro, macOS, Godot 4.6.1, headless CPU control sweep (milliseconds):

| Biome | Base median / p95 / max | Candidate median / p95 / max |
| --- | --- | --- |
| Earth | 0.772 / 3.877 / 22.685 | 0.720 / 3.932 / 20.121 |
| Fire | 0.789 / 1.834 / 9.158 | 0.740 / 1.647 / 10.879 |
| Air | 0.806 / 2.021 / 22.947 | 0.797 / 1.818 / 18.576 |
| Ice | 0.911 / 2.230 / 12.228 | 1.034 / 2.029 / 8.366 |
| Lightning | 0.577 / 1.401 / 20.410 | 0.547 / 1.289 / 22.523 |
| Shadow | 0.517 / 1.080 / 10.815 | 0.520 / 1.187 / 8.186 |

Top draw costs on the control pair: Earth's existing `overlay_meteor`
12.874/13.279 ms (base/candidate); Air path-depth drawing 3.912/1.351 ms;
Lightning path-depth drawing 6.852/7.065 ms. These are maxima within the
instrumented draw samples, not whole-frame intervals. The natural pairs'
Lightning maxima were 20.860/18.410 and 17.895/15.816 ms; the control pair's
opposite ordering demonstrates variance rather than a consistent Lightning
regression. Whole-frame outliers also occur in unrelated torch, ambient and
Umbra sections. Common renderer work is left unchanged. Final resources on
both sides: 11 nodes, zero orphan nodes; static memory 604,210,989/603,413,720
bytes (base/candidate). No universal hardware-performance claim is made.

Raw control reports and samples:
`/private/tmp/labyrinth_codex/spx-06-feedback-frames-matched/{base,head}.json`.
Natural pairs: `spx-06-feedback-frames-{base,head}-{1,2}.json`; path optimization
samples: `spx-06-feedback-frames-optimized-{1,2}.json`, under the same directory.
Repeat the matched CPU comparison with:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-06 && python3 tools/snare_pressure_performance.py pair --output-dir /private/tmp/labyrinth_codex/spx-06-feedback-frames-matched
```

Debug-only values introduced by these regressions are named constants: lethal
Cinder HP 2, Block 2, Tick HP 1, Cinder destination `(5,4)`, Tick position `(3,4)`;
other fixture values and frame timings preserve the existing proof/review
workload. The path-capture stub uses white only as a test argument. No
`TODO_DESIGN_` placeholder or new player-facing value is introduced.

Native proof remains the director's responsibility; this sandbox has no window
server. `bash tests/spx06_design_owner_proof.sh capture` runs the updated
six-variant projection comparison. Capture targets remain
`user://probes/spx06/pressures_tier2/{earth,fire,air,ice,lightning,shadow}_turn3.png`.
The existing `fixture <biome>` commands above still launch each turn-three
inspection state. No native run was attempted during this feedback pass.

Feedback validation (logs in `/private/tmp/labyrinth_codex/`):

- Focused Snare: `Snare suite: 0 failures`; placement matrix remains 3,600 rooms.
  All six preview/outcome/escape, save/load and analytics cases pass.
- `Snare UI/fixture suite: 0 failures`.
- `Warband suite: 0 failures`.
- `WARBAND ORDERS TEST RESULT: PASS (214 checks, 0 failures)`.
- `SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)`.
- `EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)`.
- `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)`.
- Warband UI: 249 nested ownership boundaries, 100 exact cold/warm path-command
  comparisons, path batching equivalence and 43 exact catalog definitions.
- UI identity: `Ran 25 tests in 3.766s` / `OK`.
- One full Godot run: `MAIN BODY ASSERTIONS: 494879`;
  `FULL SUITE RUNTIME: 602.398 seconds (budget 900 seconds)`;
  `TEST RESULT: FAIL (2 failure(s))`. All 187 other standalone programs pass,
  including Snare and Snare UI. One failure was the new frame diagnostic's
  `_probe.gd` filename being audited as an unregistered headless test. Renamed
  it to the established `_benchmark.gd` convention; focused recheck:
  `TEST REGISTRATION AUDIT: PASS (788 scripts; full suite=436, quarantined=29, windowed probe=323)`.
  The full run retains its earlier audit failure. The other failing program is
  the unchanged `special_encounter_test`: its two approved/staged emblem
  resource-loader assertions still lack imported `.ctex` files, as at r0.
  No assertion or approved asset was rewritten. Full log:
  `spx-06-feedback-full-godot.log`; focused audit: `spx-06-feedback-registration.log`.
- One full Python discovery: `Ran 1635 tests in 2084.790s` /
  `OK (skipped=66)`; process exit 0. Log: `spx-06-feedback-full-python.log`.
  The existing optional dependency/native-tool skips remain unchanged. The
  suite-rewritten Briar Weaver `mq9/proof/samples.json` was restored to its
  exact clean pre-run bytes; it is not part of this unit's changes.
- No commits, branch changes, peer review, windowed runs or publication were
  performed. Runtime source was unchanged during the final suites; the frame
  diagnostic filename correction and this proof record are reported above.

## Last Light (spx-08)

Owner approval `last-light-v2` (2026-10-29). Last Light is the parked Survive
objective in a dark room with three braziers; every piece is an existing primitive.
`scripts/last_light_rules.gd` owns the type-keyed room and combat rules;
`scripts/enemy_mechanics/snuff.gd` owns the Wick Shade's Snuff. Shared hook points
only dispatch to them (objective type and copy, room generation, combat creation,
intent filtering/planning/resolution, the dawn reward, analytics).

- **Catalog.** `types.last_light` is enabled and placed by the shared special
  placement, from map layout revision 7 (`first_layout_revision`): saved
  revision-5/6 maps regenerate byte for byte (the map-03 digests hold). On
  revision 7 a section now rolls two (weight 3) or three (weight 2) specials and
  every map reshuffles its specials; seed-pinned revision-7 fixtures were
  re-found (see the unit report). The stub's twists,
  flames, flame radii, `fire_relights` and `hold_player_turns` are removed; each
  section keeps only its `attackers`. `bonus` is `heal_per_lit_brazier`
  (amount 2, max 6, `reward_line`). `objective_description`, `sight_radius`,
  `braziers` (count, distance from start, tooltip), `wick_shades` and
  `battlefield_instance` carry the brief's values. The staged catalog copy stays
  byte-identical.
- **Objective.** Survive unchanged: target clock 60/66/72 by encounter depth (director tuning; generic Survive remains 42/46/50),
  reinforcements every 16 Time from the room's unique starting types. Title
  "Last Light", description "Survive until dawn.", `goal_met` true. The HUD keeps
  "N time remaining · Reinforcements in M".
- **Cast.** Two Wick Shades, then the section's attackers, in that order.
  Ordinary enemy placement, with brazier tiles excluded. No objective extras,
  spawn groups or omen enemies (omens add enemies only to standard combats).
- **Darkness.** The room's Umbra stage is the stage whose sight radius equals
  `sight_radius` (3 → `deep`), so the dark, its board treatment, Light, Truesight,
  and Vision work as everywhere. Its authored sight stays 3 in every section
  and at every Umbra depth: section and depth darkening do not reduce it.
  Light and Vision can still raise sight, and Truesight still reveals enemies.
  The HUD names the stage "Deep" whatever the section (int-09 r1).
- **Braziers.** `guardian_braziers` ids 1–3, all lit: permanent radius-2 Light
  sources with the Lamplighter's watch-brazier art. Placement: passable non-door
  floor at Manhattan distance 3 from the authored start, never on the interior edge
  ring (x or y equal to 1 or 7), reachable on foot; the set maximizing the smallest
  pairwise distance, ties to the lowest row-major tile indices. Braziers are placed
  before enemies, traps, loot and terrain; a room without three legal tiles retries
  its template like Warband/Snare formations, then clears interior blockers. The
  prop tooltip is the brief's exact sentence.
- **Rule.** `battlefield_rules.json` instance `last_light`: Shadowstep, room
  source, `after_player_turn` every 1, `blink 2`, `who: all_hidden`, with the
  brief's sentence. Panel, turn-clock beat and ghost forecast are the shared
  battlefield-rule presentation; the ghost forecast uses the Snare's
  activation-end boundary (`battlefield_rule_view.gd`).
- **Snuff.** The Wick Shade gains `snuff` (Time 4, weight 2): one `move_toward`
  range 2 carrying the existing `snuff_brazier` flag. At declaration it records the
  lit brazier nearest the Shade (ties: lower brazier index) as `brazier_id`; if that
  brazier is already out when it acts, it turns to the lit brazier nearest it then.
  It moves along the shared enemy movement path, then puts the brazier out if it
  stands on it or orthogonally beside it. Rooted Shades still snuff when already
  beside; Shocked Shades only move. The Shade cycles its intents, so the weight is
  the number of interleaved cycle slots Snuff fills: Grasp, Snuff, Drift,
  Snuff. Snuff is offered only while the room has a lit brazier the hero can relight
  by stepping (`brazier_relight_on_step`), so the Lamplighter and Noctyrax fights,
  and every brazier-less fight, keep their exact intent lists and cycles.
- **Relight.** `DragonCombatRules.relight_brazier` also runs when the room sets
  `brazier_relight_on_step`; Noctyrax keeps its exact `dragon_light_restored`
  event, room relights record `brazier_relit`.
- **Reward.** Victory pays the shared special bonus plus `min(2 × lit at dawn, 6)`
  Health, capped at max Health, inside `finish_combat`'s completed-room guard;
  `pending_reward.healed_amount` records it. Defeat is ordinary.
- **Fixture.** `tools/last_light_inspection.gd`, through `tools/inspection_fixture.py
  --scenario last_light --last-light-biome <section> --last-light-tier <1-3>
  --last-light-case pre_battle|encounter`.

Open design items (no player text was invented): `TODO_DESIGN_snuff_brazier_marker`
(no per-brazier on-board marker names the threatened brazier; the plan, path ghost
and the known-move note "Move 2 toward the nearest lit brazier, then put it out if
adjacent." — the brief's own composition sentence — identify it),
`TODO_DESIGN_last_light_reward_line_placement` (no existing screen shows a special's
reward line; `LastLightRules.reward_line()` holds it) and
`TODO_DESIGN_snuff_gate_outside_last_light` (the brief's literal gate, "a lit brazier
exists", would let the Lamplighter's own Shade snuff its lit braziers).

Proof: `tests/last_light_test.gd` (`tests/suites/last_light_suite.gd`), registered in
`tests/headless_test_programs.json`; measurement in
`spec/peer_benchmark/encounter_redesign/measurements/last_light/report.md`.

## Ember Hoarder (spx-09)

Owner approval `ember-hoarder-v2` (2026-10-29). No new mechanic: the room
combines the Warband captain's back-line placement, keep-away step and break,
the Snare Sealbinder's player-turn clock and silent dissolve, the Ember Tick's
Kindle and death burst, and an ordinary `move_away` intent. `types.ember_hoarder`
is enabled in both director catalog copies (live and staged, byte-identical);
the pre-principle `spill_embers_per_hit`, per-section gangs/twists, marks and
fixed HP table are removed. Every value below is read from that type, from the
new `data/enemies.json` entry `ember_hoarder`, or from `HoarderRoomRules`
(`scripts/hoarder_room_rules.gd`). Shared hook points only dispatch to it.

- **Placement.** Exactly as the other specials, on the current map revision.
  The type declares `first_layout_revision: 7`; the shared place-level gate in
  `SpecialEncounterLibrary.place` skips it and Last Light for revision 6.
  Saved revision-6 maps and the legacy digest goldens stay byte-identical.
  Revision-7 fixtures use named seeds found on the merged catalog, without
  replacing or disabling any catalog entry. The authored two/three section
  request and at-most-two-specials route constraints remain unchanged.
- **Unit.** `ember_hoarder` is the Ember Tick's entry (art, rear art, scale,
  element, accent, Health, initiative, Embers, death burst, AI profile) with the
  name "Ember Hoarder" and two intents: the Ember Tick's Kindle (weight 1) and
  Scurry (`move_away` 2, Time 4, weight 2). It never attacks. Its board art is
  the Ember Tick's articulated rig at the Tick's scale, aliased by the director's
  int-09 decision in the maquette runtime. Floor, height and action bounds reuse
  the Tick's exact registration, and Kindle uses its existing selector. Every
  other rig remains byte-identical; provenance ledgers carry the exact alias delta.
- **Start.** The roster is the Hoarder plus three Ember Ticks at every tier,
  placed by `WarbandRoomRules.positions` and validated by `WarbandRoomRules.validate`
  (captain slot 5–7 from entry, screened). Ordinary depth, sequence and Umbra
  scaling apply to all four; then the Hoarder's Health becomes 3× the brood Tick's
  final Health. The Defeat the Leader objective carries no generic leader HP or
  Stoneskin. The Hoarder is the marked leader with the per-instance nameplate
  "Ember Hoarder" (the captain's mechanism; no new icon). Omen enemies are added
  as for the Warband.
- **Keep-away.** Before its intent, a living Hoarder at large takes the
  captain's step: `HoarderRoomRules.retreat_path` runs the unchanged
  `WarbandCombatRules.retreat_path` with this room's keep-distance dials (one
  tile away when the hero is within 2, screened tiles first; the step reads no
  other objective field). Initiative
  activations, intent plans/previews and the legacy batch API all include it.
- **Clock.** `objective.player_turns_completed` advances once per completed hero
  activation, guarded by the saved `enemy_round_pending` bit (cleared at the next
  player preparation), exactly as the Sealbinder's. Tier 1 escapes after 5 turns,
  tiers 2–3 after 4. The rule panel above the objective shows "The Hoarder slips
  away with its hoard after your Nth turn." with ` · N TURNS LEFT` (` · 1 TURN LEFT`)
  on its kicker; it hides once the Hoarder is gone. The panel title is "Slip Away"
  and uses the Hoarder's own map emblem (director decisions, int-09).
- **Escape.** At the end of that hero turn the Hoarder dissolves like a sealing
  Sealbinder (`snare_dissolved`, HP 0, no death burst, Embers, kill credit or
  sound; the Snare's audio filter covers both rooms). The objective becomes the ordinary Defeat All (`kill_all`, standard
  name, description and icon; `goal_met` false). Remaining enemies keep the fight
  going; with none left it is won at once. Standard cards and per-kill Embers.
- **Catch.** Killing the Hoarder wins at once (`goal_met` true). The brood
  scatters by the Warband break (`break_followers`, flee paths, `warband_fled`):
  their death bursts and spawns are suppressed, including batched deaths queued
  before the catch. The Hoarder's own death burst fires as an Ember Tick's
  (4 plus Kindle). The break presentation (run and dissolve) is shared;
  `break_line` is "The brood scatters!" (director decision, int-09).
- **Reward when caught.** The shared special reward (4 cards with the Rare floor,
  1.5× the captured starting roster's Embers) plus `hoard_embers`: one standard
  fight's Embers, computed like the special base (the captured
  `special_starting_reward_embers` × `standard_fight_embers` 1.0, half-up, combat
  omens). The run notice and `pending_reward.special_bonus_line` read "The
  Hoarder's hoard: +N embers". The completed-room guard prevents double payment.
- **Map.** The approved emblem `assets/art/icons/map/ember_hoarder.png` (director
  provenance hash a4807c1d…5caf, not a placeholder); tooltip line "Catch the Ember
  Hoarder before it slips away with its hoard."; objective "Ember Hoarder" /
  "Catch the Hoarder before it slips away.".

Saves need no migration: all state is ordinary objective/enemy data. Legacy
batch resolution, previews and resume share the pending bit. No player-card
coefficient changes; the encounter assumptions are mirrored in
`tools/card_heuristic.py --show-assumptions` (`combat_objectives.ember_hoarder`).

### Validation and proof (spx-09)

`tests/hoarder_test.gd` (registered) checks each requirement with independent
literals and the brief's mutations: Health 2×, clock 5 at tier 2, an attacking
Hoarder (data and behaviour), a death burst on dissolve, brood bursts after a
catch, the hoard paid on escape and a leftover `spill_embers_per_hit` are each
rejected. Its generation matrix covers 6 biomes × 3 tiers × 40 seeds across
sections I–VI and Umbra depth. The inspection fixture is
`tools/inspection_fixture.py --scenario ember_hoarder --hoarder-biome <section>
--hoarder-tier <1-3> --hoarder-case pre_battle|encounter`. Measurement (meas-02
bot, revision 7) lives in `peer_benchmark/encounter_redesign/measurements/spx-09/`;
the bot accepts any enabled special type other than the Warband as an extra
cohort (`umbral_snare` / `snare`, `last_light`, `ember_hoarder`) through the
single `Sweep.special_cohort(cohort, revision)` helper. Baseline sweep bins are unchanged.
