# Gale Herald — en-02 implementation

Binding design: `../peer_benchmark/enemy_roster_v1.md`, the en-02 brief supplied
in the implementation task, and protected
`../peer_benchmark/staged/enemies/wave_e1.json`.

Controller in Hollow Gale: 14 HP, base initiative 13, 11 Embers. Its staged
entry is copied verbatim. Closest comparison: Chainbound Gaoler (14 HP,
initiative 13, 12 Embers). The director adds encounter groups after merge.

4. Call the Wind scans each cardinal direction up to three tiles from the
   hero. The nearest wall, pillar, impassable terrain, Fire surface, trap or
   unit selects wind; a tied direction toward the Herald wins, and without
   a hazard the existing cardinal direction toward the Herald is used.
   Wind stores direction, rounds_left, source_id and the authored push amount.
   Two enemy-turn boundaries, including Call's own and skipped turns, push
   every eligible actor one tile before decrementing the remaining rounds.
   Actors are ordered farthest downwind first, with stable actor-key ties.
   Movement, defenses, collisions, traps, surfaces and death handling reuse
   the real forced mover. The Herald, bosses, definition-tagged guardian leaders,
   objective leaders, definition-tagged constructs (`construct: true`) and explicitly Anchored actors are
   excluded. The Herald is Anchored for card/trap pushes and pulls too; grouped
   forces treat it as an immovable blocker. Source death immediately removes
   wind, including leader-objective follower clearing; a new Call refreshes it.
   Wind resolves before terrain lifetimes count down, so last-round pillars
   still block and shatter on that turn.
5. Faint white-blue chevrons use the approved 22% alpha, two per floor tile,
   40 px/s drift, 14 px head width, 2 px stroke, half-tile spacing along
   the wind direction, and static reduced-motion mode. Active wind and dashed Call
   previews remain separate layers. All push arrows and collision markers
   come from the existing card preview renderer and a copy of the real
   resolver. Hidden, unavailable Call intents do not reveal a preview.
   The HUD chip uses approved `wind.png`, the shared HUD panel/typography,
   a procedurally drawn 12 px TEXT-colour arrow, and exact `Wind · <rounds>`
   text under the turn clock. Its tooltip uses the supplied sentence with
   screen-relative isometric quadrant names. The
   Herald's Anchored status uses the existing status badge row and identity.
6. Gust Bolt and Still Air reuse existing actions at the staged values:
   ranged 3 + Push 1, range 4; Block 5. Impossible ranged intents are excluded
   before the seeded weighted roll.

Helpers: `scripts/enemy_mechanics/wind.gd` and `wind_view.gd`.
Board art: `assets/art/enemies/gale_herald.png`; portrait:
`assets/art/portraits/gale_herald.png`; no new rig, idle sheet, audio, font or
generated art. Sprite registration and density processing follow the same
standard-band/Gaoler-baseline policy as the Seer. The existing attack and
movement cue families are used. Mechanics resolve to the existing
`enemy_action_resolved` event schema, with action_type, tiles and losses;
there are no new analytics event types or save-schema migrations.

Director feedback 1 fixes boundary order, construct classification, geometry
and all copy. North/east/south/west board directions point toward the upper
right/lower right/lower left/upper left on screen, respectively. The HUD arrow
uses the same isometric arrowhead proportions as existing card push previews.
The Herald badge tooltip is "Anchored: the wind does not move it." The Wind
icon description is "Wind: at the end of each enemy turn, everything not
anchored is pushed one tile with the wind." Construct immunity reads only the
enemy definition's `construct: true`, with no type list or runtime construct
flag. Equidistant directions which are equally toward the Herald retain the
repository's existing cardinal ordering deterministically.

The balance comparison and cadence assumptions live in
`spec/card_balance_heuristic.md` and `tools/card_heuristic.py`.
`data/encounters.json` remains untouched; enc-01 has landed and the director
adds the specified groups after merge.

Headless proof uses `tests/en02_enemies_test.gd`; the windowed probe captures
dashed Call preview, active wind with HUD, mid-push, after-push and reduced
motion at 1920×1080/100% UI scale. The scene renders into an UPDATE_ALWAYS
SubViewport and captures its texture; a runtime assertion checks 100% UI scale. Probe-only choices are named constants:
seed 20261012, mid-fall elapsed 0.09 seconds, mid-push progress 0.5; fixtures use
an 11×11 test board, hero (5,5), enemy (5,2), and 50 hero HP. These are debug
proof values and are not production tuning.

Windowed proof (not run in the sandbox):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/visual_probe_runner.py tests/en02_enemies_probe.gd --task-id en-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/en02_enemies.json --result-manifest /private/tmp/labyrinth-inspection-manifests/en02-visual-proof.json
```

Expected capture suffixes: `en02_enemies_probe/01_icefall_marks.png`,
`02_icicles_mid_fall.png`, `03_ice_pillars.png`,
`04_call_wind_dashed_preview.png`, `05_wind_at_rest_hud.png`,
`06_wind_mid_push.png`, `07_wind_after_push_hud.png`,
`08_wind_reduced_motion.png`, inside the runner's isolated `user://` directory.
The result manifest records exact paths after capture; no PNG proof exists yet.

Inspection beside a damaging surface (generation/verification already run
headlessly; this command adds the owner's interactive launch):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/inspection_fixture.py --task-id en-02 --run-id en02-gale-herald --scenario combat --enemy-types gale_herald --enemy-positions 5:2 --enemy-intents call_the_wind --player-position 5:5 --surfaces fire@6:5 --umbra-stage clear --biome vaeloryx --manifest /private/tmp/labyrinth-inspection-manifests/en02-gale-herald.json --summary 'Gale Herald before Call the Wind beside Fire' --launch
```

## spx-04 — The Stormcaller

Only wind sourced by the living Warband captain with `stormcaller_wind` keeps
its authored `rounds_left` without decrement. Each Call replaces the direction
through the existing hazard scan. Every unit enters the existing forced mover;
explicit Anchored, immobile and buried rules still apply. This removes ordinary
wind-only leader/guardian/construct exemptions for the captain's gust, without
changing card forces or another Herald's wind. The same real-mover copy powers
all-unit slide/collision previews. Source death clears wind as before. Ordinary
Herald wind retains its two-boundary lifetime and its full-state legacy golden.
The persistent wind chip's unsupplied label is the literal named placeholder
`TODO_DESIGN_PERSISTENT_WIND_LABEL`; the director must supply final copy.

Validation and director capture commands: [spx-04 handoff](spx04_orders.md).
