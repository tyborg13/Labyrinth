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

`TODO_DESIGN_SKIRMISHER_LANE_ORDER` remains empty: the brief does not define
"lower lane" coordinates or a priority among perpendicular offsets on one side.
Within-side candidates remain unranked until the owner resolves this. All other
role/range/gap/approach rules are enforced, including in deterministic fallback.

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
unchanged nested evidence. Tether's threat and real-resolver damage evidence are
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
approach flood fill. Ordinary order controls use frozen pre-spread layouts from
base `3fad2e65b1685996f7eed3fd407513cd54012129` in
`tests/fixtures/spx07_order_control_layouts.bin`, preserving their original golden
hash assertions rather than coupling them to the new placement search.

The headless proof and current remaining budget failures are recorded in
`output/spx07/HANDOFF.md`. Native first-turn proof uses the existing Warband probe
with `--first-turn-only`, `tests/proof_contracts/spx07_warband.json`, 1920×1080 and
100% UI scale. See `output/spx07/design_owner_proof.sh` for exact renderer,
frame-time and verified inspection-fixture commands. Native captures must be
run by the design owner on a machine with window-server access.
