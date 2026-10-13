# Briar Weaver — en-04 implementation

Binding design: `../peer_benchmark/enemy_roster_v1.md`,
`../peer_benchmark/briefs/en-common.md` and the en-04 unit brief. The
`briar_weaver` entry is copied unchanged from
`../peer_benchmark/staged/enemies/wave_e2.json` into `data/enemies.json`.
The design owner owns encounter integration, commit, peer review, inspection
and publication. All implementation changes remain uncommitted.

1. **Thornwall** uses `scripts/enemy_mechanics/bramble.gd` and
   `bramble_view.gd`. It grows immediately on the three-tile perpendicular
   line centred one tile toward the Weaver from the hero. Horizontal directions
   use a column; vertical/diagonal directions use a row. The diagonal front
   takes one step on both axes toward the Weaver. Occupied, impassable and
   existing terrain tiles are skipped. Preview and resolution use the same
   tile function. Bramble has three enemy-turn boundaries of lifetime, including
   its grow turn, with wind resolving before expiry. Movement is blocked,
   sight remains open, and attacks cannot destroy the tangle. A force collision
   takes exactly 2 damage through existing defenses and applies Bleed 1 to the
   living hero/enemy; it stops movement and leaves Bramble intact. The existing
   generic illusion status policy is preserved. Existing friendly-fire reward
   and player-card credit rules are retained.
2. **Lash of Thorns** reuses ranged earth damage 3, range 3, Bleed 1.
   **Root Mend** reuses the existing support resolver, excluding the acting
   Weaver: most missing HP among living allies within 3, heal 4 capped at max.
   Equal injury retains existing distance/HP/id tie breaks. No wounded ally
   excludes Root Mend at selection, and a held Mend falls back to Lash if its
   target disappears. The board intent, compass and threats-at-rest expose
   that same fallback. All choices retain authored weights after illegal
   choices are removed, using the combat RNG.

The protected stats are 14 HP, base initiative 12, 11 Embers. Mean authored
cadence at local depth 2 with all intents legal is 17.5. This controller's
nearest comparison is the Hoarfrost Seer: immediate terrain closure replaces
its delayed Icefall pressure. Counterplay remains walking around before the
line closes and pushing enemies into the tangle. No depth eligibility or
spawn weight was invented. `enc-01` is present, but the unit brief assigns
`earth_weaver` to the director after merge, so encounter pools are untouched.

Director feedback 1 replaces the procedural strokes with the approved painted
`assets/props/enemies/bramble_thicket.png`. It uses the ordinary terrain texture
path and the same tile-depth sorting, obstruction handling and ground shadows
as crates. It preserves the painting's aspect, fits inside the crag outcrop's
one-tile width, and measures 1.1× the crate's visible alpha height. Its planted
base matches the crate's visible ground baseline. The source is keyed, trimmed
and registered at 181×195 pixels before the existing density treatment.

Grow scales only the vertical axis from 0 to 1 over 0.25 seconds with ease-out
cubic, `1 - (1-t)^3`. Expiry is its time reverse, `1 - t^3`, over 0.25 seconds.
Expired paint stays in the existing depth-sorted `terrain_destruction_units`
path. Both transitions have three small dust/leaf flecks; the director's
`BRAMBLE_HEIGHT_TILES = 0.6` remains their rise-height reference. Reduced motion
applies appearance/removal immediately without an animation ghost or flecks.
No height TODO remains. Terrain shadows are analytical contact/cast shapes;
the standard unit shadow cache was regenerated and retains 50 entries / 44
sources because terrain props are outside that cache.

Director feedback 2 requires positive `max_hp` before terrain can expose a
health bar or damage-preview bar. Bramble has no attack durability, so neither
bar appears at rest, in `attack_tiles`, or under a pending damage preview.
The existing Ice Pillar exclusion remains; damaged, highlighted and previewed
boxes, crates and kegs retain their contextual bars. The focused suite adds 35
regressions for missing/zero/negative durability and these destructible props.

The tooltip and icon are unchanged:

> Bramble: blocks movement for &lt;n&gt; more round(s). A unit pushed into it takes 2 damage and Bleeds.

Approved art only: `assets/art/enemies/briar_weaver.png` (255×255),
`assets/art/portraits/briar_weaver.png` (128×128), and
`assets/art/icons/bramble.png` (64×64). `tools/process_en04_enemy_assets.py`
verifies source hashes, uses the repository green key and existing BOX fitting,
then registers the silhouette at 95% of the hero's standing height (205 px)
on the Gaoler's 251 px baseline. Portrait framing uses the measured bark-face
landmark, approximately 70% head width and an 8 px inset. Icon padding follows
Blink. Density adoption/processing and additive shadow-cache regeneration
are complete; a static sprite has no rig rest to rebake (`RECORDED-RESTS 0
file(s)`). No new art, font, audio, idle sheet, rig, art scale or offsets were
designed. Existing earth attack and static hit/death feedback are reused.

The heuristic specification and scorer contain matching encounter-context
rows; printed-card coefficients are unchanged. Existing enemy action,
status, surface and death analytics paths are preserved. No new event schema
is needed.

## Headless proof and chosen defaults

Focused suite: `tests/en04_enemies_test.gd` and
`tests/suites/en04_enemies_suite.gd`. It covers eight directions, clipping,
occupancy, immediate preview/resolution parity, movement/LOS, collision defense,
Bleed, lifetime, skipped turns, wind-before-expiry, friendly fire, heal targets,
fallback presentation, schema, turn-clock portraits, persistence, Lob
integration and terrain health/damage-preview bars. The full suite includes
this suite without changing existing master assertions. Latest focused result: `EN04 ENEMIES TEST RESULT: PASS
(427 checks, 0 failures)`.

Debug/proof defaults are plain named constants: `FIXTURE_SEED = 20261012`,
`FIXTURE_BOARD_SIZE = 11`, `FIXTURE_PLAYER_HP = 50`, `FIXTURE_HELPER_HP = 20`,
`FIXTURE_TERRAIN_MAX_HP = 3` (damage-preview fixture: `hp = 1`, `hp_loss = 2`),
`FIXTURE_HERO = (5,5)`, `FIXTURE_SOURCE = (5,2)`, `AI_ROLL_COUNT = 32`, and
`SAVE_PATH = user://en04_roundtrip.save` in the suite. The test guard's
`MINIMUM_CHECK_COUNT` covers the completed suite. The probe uses
`PROOF_SEED = 20261012`, `MID_TRANSITION_PROGRESS = 0.5`,
`MID_ARC_PROGRESS = 0.5 * ARC_SECONDS / (ARC_SECONDS + SPLASH_SECONDS)`,
`CASE_COUNT = 9`, `PROOF_WEAVER_ALLY = (6,2)`,
`PROOF_MORTAR_LEFT_ALLY = (4,5)`, `PROOF_MORTAR_RIGHT_ALLY = (6,5)`, and
`OUTPUT_DIR = user://en04_enemies_probe`.
`VIEWPORT_SIZE = (1920,1080)` and UI scale 1.0 are required by the brief.
The full-suite runner timeout is 900 s because the untouched suite was
observed still making progress when its 300 s default expired.
These choices affect only fixtures, validation or captures.

## Proof for the design owner

The sandbox has no window-server access. No windowed run was attempted.
The headless probe contract passed for nine states. The probe captures its
own 1920×1080 `SubViewport` with `UPDATE_ALWAYS`, at 100% UI scale, and never
reads `root.get_texture()`. Capture filenames are:
`01_thornwall_at_rest.png`, `02_thornwall_mid_rise.png`,
`03_thornwall_grown.png`, `04_bramble_push_collision.png`,
`05_lob_marks_at_rest.png`, `06_slag_mid_arc.png`,
`07_after_landing_fire.png`, `08_bramble_mid_sink.png`,
`09_slag_reduced_motion.png` under the isolated run's
`user://en04_enemies_probe/`. The real-renderer result manifest and PNG
paths are pending the following command:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-04 && python3 tools/visual_probe_runner.py tests/en04_enemies_probe.gd --task-id en-04 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/en04_enemies_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/en04-enemies-proof-20261012-v1.json
```

The Weaver fixture was generated and verified headlessly (`ok: true`), with
manifest `/private/tmp/labyrinth-inspection-manifests/en04-briar-weaver.json`.
The saved-room mechanic check reports `EN04 INSPECTION MECHANIC: PASS
(briar_weaver, thornwall, 3 tiles)`.
It opens the Weaver about to Thornwall beside a crawler:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-04 && python3 tools/inspection_fixture.py --task-id en-04 --run-id en04-briar-weaver --scenario combat --enemy-types briar_weaver,crawler --enemy-positions 5:2,6:2 --enemy-intents thornwall --player-position 5:5 --umbra-stage clear --biome tharokh --manifest /private/tmp/labyrinth-inspection-manifests/en04-briar-weaver.json --summary 'Briar Weaver before Thornwall beside a crawler' --launch
```

See `slag_mortar.md` for the other fixture and requirements 3–5. The design
owner must inspect native screenshots before accepting visual proof.

For feedback 2, recapture the Bramble subset (including 03 and 04) with a fresh
result manifest. The runner assigns an isolated run directory automatically
and emits the exact PNG paths in its output and result manifest:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-04 && python3 tools/visual_probe_runner.py tests/en04_enemies_probe.gd --task-id en-04 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/en04_bramble_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/en04-bramble-feedback2-v3.json -- --bramble-only
```

This emits `02_thornwall_mid_rise.png`, `03_thornwall_grown.png`,
`04_bramble_push_collision.png` and `08_bramble_mid_sink.png` in
`user://en04_enemies_probe/`, through the probe's 1920×1080 `UPDATE_ALWAYS`
SubViewport. A headless `--check-only --bramble-only` contract check validates
those four states without launching the window server.

The supplied `props/bramble_thicket.png` hash record was copied verbatim from
the director's peer-benchmark worktree into this task's staged hash file:
`4daa88c269ae488ddfeedd3ce72670cfa5fde47c800262099623f15967551216`.
The processor's `--props-only` mode verifies this record and preserves all
previous enemy/icon sources. Use `process_board_density.py --only
bramble_thicket` for subsequent processing; it starts from the adopted source.



## Final validation results

- Focused runner: `EN04 ENEMIES TEST RESULT: PASS (427 checks, 0 failures)`.
- Headless probe: `EN04 ENEMIES PROBE CONTRACT: PASS (9 states, 1920x1080, UI scale 100%)`.
- Feedback-2 headless capture subset: `EN04 ENEMIES PROBE CONTRACT: PASS (4 states, 1920x1080, UI scale 100%)`.
- Icon audit: `Ran 7 tests` / `OK`.
- Density suite: `Ran 41 tests in 88.471s` / `OK`; complete density check: `CHECK-OK`.
- Shadow generation: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=50 sources=44`.
- Protected data comparison: `EN04 PROTECTED DATA: PASS (2 verbatim entries)`.
- Final full suite: `TEST RESULT: FAIL (4 failure(s))` — only the brief's known
  pinned depth assertions: run seeds 307, 8821, 90429 and combat seed 8821.
  The encounter-table pinned assertion did not fail in this run. No existing
  assertion was edited. Full log:
  `/private/tmp/labyrinth-godot-home/en-04-1791858253745020000-22885/godot.log`.
- `git diff --check` passed. Shared runtime growth is below the brief's limits;
  RunScene gained 11 lines.
- Windowed captures were not run and no PNG capture paths are claimed as proof.
  The design owner must run and inspect the listed native command.
