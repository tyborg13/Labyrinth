# EN01 proof and owner handoff

Implementation remains uncommitted on `codex/en-01`. No push, commit, branch
change, peer review, signoff or publication was performed. The task helper
reported an empty contract; contract/review/publication remain owner work.

## Numbered requirements and director feedback 1

The six original requirements are implemented: Burrow occupancy/targeting/area
rules and save/load; Erupt impact/displacement/push/Rubble/Expose and forced
intent; existing Gnaw; exactly-once breadth-first friendly-fire Burst and real
card forecasts; capped Kindle; existing Scuttle. The only unfinished visual
parameter is the dust particle diameter noted below.

| Feedback | Implementation / acceptance |
| --- | --- |
| 1 | Shared integration patch applied to the seven newly authorized files. Static melee retains generic arc windows; temporary strike fields removed. Existing roster cutout assertions remain; only these new static enemies are excepted. |
| 2 | Approved green-keyed 64×64 `burrow`, `erupt`, `burst` paint, existing icon padding, distinct registry identities and approved intent/status sharing. Raw hashes recorded. |
| 3 | `burrowed` reaches the board render dictionary. Mound-only drawing bypasses body/shadow; health/intent remain. New `01b_grub_burrowed.png` probe checkpoint. |
| 4 | Exact mound colours, upper-left 1 px rim, seeded seven 2–3 px specks, 60% × 32% tile ellipse, ±3% / 1.5 s breath; reduced motion static. |
| 5 | Puff count, colour, alpha, travel and 0.35 s timeline wired; existing Rubble creation visual runs. Particle diameter 5 px (director). |
| 6 | Surrounded marked occupant takes 6 and stays. Grub surfaces nearest-free, pushes from actual landing and still gains Expose / leaves Rubble. Focused preview and resolution tests pass. |
| 7 | Additive abdomen ellipse, 70% × 40%, `#ff8a3a`, 35% / 55% alpha by stack, ±10% / 1.2 s pulse; reduced motion steady. Bonus reaches render dictionary. |
| 8 | Status badge has `burst` icon + total only, exact director tooltip; ordinary status-row spacing retained. |
| 9 | Dashed ring: 2 px `#e8722c`, 85%, dash 8 / gap 6. |
| 10 | FIFO presentation starts each next burst 0.18 s later; frame sampling lands on each boundary without changing individual dissolve duration. Snapshots and dissolve progress follow real deaths. Mid-chain probe uses this production helper. |
| 11 | Grub height 162 px (75% of 216 px standing hero), Tick 97 px (45%, source-pixel rounding). Base y=251 retained. Density source/process/rest/check and shadow cache refreshed. |
| 12 | 128×128 processed-art portraits centre mouth ring / front shell at approximately 70% width, transparent background with existing 8 px margin. Explicit turn-clock registrations. |
| 13 | `data/encounters.json` untouched; director owns the four pool entries. Protected staged enemy definitions are unchanged. |

## Proof for the design owner

Windowed proof has **not** been run: this worker has no window-server access.
Run exactly from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-01 && python3 tools/visual_probe_runner.py --task-id en-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --startup-timeout 30 --expect-size 1920x1080 --proof-contract tests/en01_enemies_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/en01-renderer-manifest.json tests/en01_enemies_probe.gd
```

The runner creates a fresh task namespace. Captures are under that namespace's
`probes/en01_enemies/`, and their absolute paths are printed as `EN01 CAPTURE`:

1. `01_grub_mound_mark.png`
2. `01b_grub_burrowed.png`
3. `02_grub_erupt_mid.png`
4. `03_grub_after_erupt.png`
5. `04_ticks_hover_burst_ring.png`
6. `05_tick_kindle_resolution.png`
7. `06_tick_after_kindle.png`
8. `07_tick_lethal_card_preview.png`
9. `08_tick_chain_mid.png`
10. `09_tick_chain_after.png`

All are 1920×1080 at 100% UI scale. The midpoint captures use production
presentation helpers/snapshots with a debug checkpoint, rather than slowing
the authored animation. The probe writes `semantic-proof.json` beside them.
The Kindle action has no authored continuous animation; its resolution image
shows the actual bonus/glow state during the existing status presentation.

These inspection commands regenerate and verify the original pre-action save
before opening the game. Headless generation/reload already succeeded; the
interactive launch is owner proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-01 && python3 tools/inspection_fixture.py --task-id en-01 --run-id en01-grub --scenario combat --seed 611 --enemy-types burrow_grub --enemy-positions 3:3 --enemy-intents burrow --player-position 4:4 --hand quick_stab,pale_spark --summary 'Burrow Grub before Burrow' --manifest /private/tmp/labyrinth-inspection-manifests/en01-grub.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-01 && python3 tools/inspection_fixture.py --task-id en-01 --run-id en01-ticks --scenario combat --seed 611 --enemy-types ember_tick,ember_tick,ember_tick,crawler,crawler --enemy-positions 3:3,4:3,5:3,3:4,5:4 --enemy-intents kindle,scuttle,scuttle,skitter_strike,skitter_strike --player-position 4:4 --hand quick_stab,pale_spark --summary 'Three Ember Ticks near two Crawlers' --manifest /private/tmp/labyrinth-inspection-manifests/en01-ticks.json --launch
```

## Files changed

- Runtime: `scripts/enemy_mechanics/{burrow,death_burst,kindle}.gd` and the three
  `_view.gd` helpers; focused dispatch/state integration in `combat_engine.gd`,
  `combat_board_view.gd`, `run_scene.gd`; icon, compass and strike registries.
- Data/art: two protected entries in `data/enemies.json`; two enemy sprites,
  two portraits, three icons; density registry, sources and output digests;
  generated shadow cache; raw enemy/icon hash records.
- Validation: extracted EN01 suite, focused executable, probe/contract,
  full-suite registration; icon audit, static density checks and contextual
  cutout exceptions for only these two enemies.
- Specifications/tools: both enemy specs and this proof record, applied shared
  integration patch (now regenerated to the final approved registrations),
  icon policy, synchronized heuristic roster context and EN01 art processor.

No commit, push, peer review, queue edit or encounter-pool edit was performed.
The initial full suite's seven EN01 registration failures are resolved. No
existing base-failure assertion was weakened.

## Chosen defaults

Only debug/proof/runtime limits were chosen:

- Test/fixture seed `611`; hero tile `(4,4)`, grub old tile `(2,4)`, clustered tick
  tiles `(3,3)`–`(5,3)`, crawler tiles `(3,4)` and `(5,4)`; synthetic hero HP 30 and HP overrides
  of 4 for secondary chain ticks and 20 for a friendly-fire victim.
- Probe midpoint `0.5`, settling 6 frames; dummy-renderer smoke settling 3 frames.
- Full-suite timeout 1800 seconds after observed progress exceeded the default
  300 seconds. Windowed probe limit 120 seconds, startup limit 30 seconds for
  ten full-scene captures.
- Numerical chain-boundary tolerance `TIME_BOUNDARY_EPSILON = 0.000001`; it
  prevents floating-point rounding from skipping an exact scheduled frame.

Art geometry is measured from the approved painting and standing hero reference.
All gameplay tuning remains protected director data. The only design placeholder
is 5 px (director).

## Observed checks (feedback 1)

- Focused: `EN01 HEADLESS DRAW BRANCHES: executed; no renderer capture`;
  `EN01 ENEMIES TEST RESULT: PASS`.
- Probe contract/compilation: `EN01 PROBE HEADLESS CONTRACT RESULT: PASS`.
- Icon audit: `Ran 7 tests`; `OK`.
- Density Python suite: `Ran 41 tests`; `OK`.
- Both scoped density checks: `CHECK-OK`; source processing `PROCESSED 1 file(s)`
  each and static rest records `RECORDED-RESTS 0 file(s)` each.
- Shadow cache: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=44 sources=38`.
- Heuristic tests: `Ran 38 tests`; `OK`.
- Full Godot suite on final code: `TEST RESULT: PASS`, runner exit 0.
- Both regenerated inspection fixtures: `Inspection fixture saved.` and
  `Inspection fixture verified.`; both JSON results contain `"ok":true`.
- `git diff --check`: clean. `EN01 DIRECTOR DATA VERBATIM: PASS`;
  `EN01 PYTHON SOURCE COMPILATION: PASS`; `EN01 JSON VALIDATION: PASS`.
  Staged/production equality is also in the focused suite.

Logs: `/private/tmp/labyrinth_codex/en01-feedback-{focused,probe-headless,icons,density-python,heuristic,full-suite,shadows,fixture-grub,fixture-ticks}.log`.
The full suite uses the already justified 1800 s limit for the large gear-motion
checks. It emits the existing macOS certificate error and ObjectDB shutdown
warning; the actual final result is the line above.

All nine supplied first-round native captures and their proof sheet were inspected at
`/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/en-01/sheet.png`.
It is prior-revision evidence. Updated renderer captures have not been produced
by this worker: no window-server access. The ten named files are required owner
outputs, not completed native proof. Dust size remains an explicit design input.
