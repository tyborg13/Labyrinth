# hf-01 implementation and owner proof

The live scene uses `hero_facing_combat.gd`, a presentation adapter around the
unchanged combat resolver. Its only durable addition is
`combat_state.hero_facing = {facing: front|rear, mirrored: bool}`. Preview copies
remain copies. Enemy commit snapshots receive the resolved facing, including
Continue checkpoints that occur before presentation. The scene's independent
presentation cursor advances on movement/action frames and on existing impact
feedback, without introducing a timer. The renderer receives that explicit
facing before reactions; gear, source sockets and strike samples use it.

`settings.json` accepts `hero_facing: persist|snap`, defaulting to `persist`.
There is no Options control. Launches may override it with `--hero-facing`.
The inspection fixture persists the preference and forwards it to its launch;
the headless console and matched recording launcher accept it too.

## Acceptance coverage

1. Walk direction and final-step persistence: policy tests and the scripted
   production movement animation, followed by idle.
2. Targeted card and area centre: direction policy and real melee presentation;
   self Block, buffs, draw, Wait and self-centred area actions retain facing.
3. Enemy impact: source ownership, blocked hits, Lob source versus landing tile,
   ordered multiple sources, real enemy commits and exact impact-frame routing.
   Negative cases cover rules, surfaces, traps, statuses and forced displacement;
   real Frostbite damage and Gust displacement exercise the rule resolver.
4. Entry and migration: nearest enemy/id tie, empty encounter and actual old-save
   scene load. Distance and facing ties follow the director decisions below.
5. Additive save field: serializer round-trip and real scene Continue; ordinary
   idle/UI board refresh uses the held cursor, never a preview's proposed facing.
6. Facing selection is an instant property swap on the existing frames. No
   production timing, game rules, event schema, RNG or action costs change.
7. Reactions/death/other clips receive the held facing. Both existing rigs and
   all existing gear are reused. Socket and strike-trail samples use the actual
   selected facing. Enemy facing and rig depth/sort are untouched.

The rear-facing coverage query uses the already prepared registration texture
with the precomputed rear contour; both facings share the same source canvas.
This avoids a cold image decode when Continue starts facing backward. The
coverage generator changed only the renderer fingerprint in
`assets/generated/hero_rest_coverage.tres`; contour data is byte-unchanged.

The snap golden was captured **before production changes** from HEAD
`07d541d9fa47bcf32ca1aca86ccabaed7fe5c968`. It contains all 179 authored
presentation submissions in the seeded move/card/Block/two-hit fight.
`tests/fixtures/hero_facing_snap.csv` has Git blob hash
`3901cfcbd417c40b8dd81b729a86a710a588b322`. A deterministic test clock removes
wall-clock scheduling differences; it does not replace production routing,
resolver results or authored frame counts. There is no golden update mode.
Existing gear motion proofs explicitly select `snap` to retain their original
front-idle assertions.

Existing exact-state checks keep their assertions: the combat-feel fixture now
uses normal scene synchronization, the analytics fixture carries an explicit
facing value, and save/resume and surface-preview comparisons use the live
engine adapter. The scene still accepts the clock suite's substitute base
engine. These changes account for the additive field without excluding other
state, RNG, timing, or event differences from equality checks.

## Proof for the design owner

The director recorded both modes from round 0 (`ab5d45f07`) on seed `260908`
and accepted persistence after walking and successive hits, plus byte-identical
snap behavior. These commands remain available for matched recordings. Each
performs real movement away from the camera, Quick Stab, then Pass against two
flanking enemies, at seed `260908`, 1920×1080 and 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/hero_facing_playtest.py --hero-facing persist --seed 260908 --result-manifest /private/tmp/labyrinth_codex/hf-01-proof/persist-visual.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/hero_facing_playtest.py --hero-facing snap --seed 260908 --result-manifest /private/tmp/labyrinth_codex/hf-01-proof/snap-visual.json
```

The launcher uses `tools/visual_probe_runner.py` with
`tests/hero_facing_probe_contract.json`. Its output identifies the isolated
`user://probes/hero_facing/<mode>/` directory. Open `recording.html` there to
play the timestamped PNG recording. The four required stills are
`00_start.png`, `01_rear_idle.png`, `02_targeted_idle.png`, and
`03_two_sources_idle.png`; `manifest.json` records facing and source checks.

For interactive comparison, generate and launch the same pre-action fixture:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/inspection_fixture.py --task-id hf-01 --run-id hf-01-persist --hero-facing persist --scenario combat --seed 260908 --player-position 3:4 --hand quick_stab,brace,bone_dart,patch_up,sidestep_slash --enemy-types crawler,crawler --enemy-positions 4:3,2:3 --enemy-intents skitter_strike,skitter_strike --enemy-hp 40 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/inspection_fixture.py --task-id hf-01 --run-id hf-01-snap --hero-facing snap --scenario combat --seed 260908 --player-position 3:4 --hand quick_stab,brace,bone_dart,patch_up,sidestep_slash --enemy-types crawler,crawler --enemy-positions 4:3,2:3 --enemy-intents skitter_strike,skitter_strike --enemy-hp 40 --launch
```

## Director decisions (feedback 1)

- A facing tie retains the current facing when it is one of the candidates.
  Otherwise choose the unmirrored candidate: front over front-mirrored, rear
  over rear-mirrored. Always choose from the tied pair, including when both
  candidates are rear. Mixed front/rear ties follow the same unmirrored rule.
- Combat start uses Manhattan distance on the tile grid (movement steps), with
  equal distances resolved by the lower enemy id. The implemented metric is
  now the accepted decision rather than a placeholder.

## Chosen defaults (test/proof only)

- Logic-test seed `261028`; matched existing gameplay-fixture seed `260908`.
- Debug-only fixture positions: hero (3,4), enemies (4,3) and (2,3); move to
  (3,3). Existing Crawler, Quick Stab, Block and gear assets/data are reused.
- Deterministic popup tail: 8 samples; proof idle settlement: 4 frames.
- PNG recording interval: 100 ms; action watchdog: 30 s; entire recording
  process watchdog: 120 s. These do not alter production animation clocks.

No commit, publication, peer review or renderer inspection is performed by the
implementation worker. Those steps remain assigned to the design owner.

## Round 0 verification

Final focused checks after the rear-facing coverage fix:

- `HERO FACING TEST: PASS` (65 checks).
- `HERO FACING SNAP GOLDEN: PASS` (179 authored frames).
- `HERO FACING GAMEPLAY: PASS` (179 scripted frames).
- `HERO FACING MUTATIONS: PASS` (3/3 killed: always front, never turn on hit,
  and turn on battlefield beat).
- Probe contract, UI identity lint, draw-origin and movement checks: pass.
- Hero coverage: all 6 tests pass, including staleness and zero-runtime
  mutations. Instrumented Continue has zero image/rig/thread calls and a
  0.032 ms coverage scope (0.5 ms limit).
- Retained inventory comparison: baseline and candidate each pass 105 cases,
  with zero differences, semantic errors or orphan actors; 54.360 s and
  55.356 s respectively. The earlier concurrent 180 s timeouts did not recur.

Focused result index:
`/private/tmp/labyrinth_codex/hf-01-proof/focused-final-summary.json`.
The inventory comparison is in `inventory-comparison.json` in the same folder.
The final full Godot run completed in **830.691 s**, within its 900 s budget:
495,758 main-body assertions and 253/254 child groups passed. Its sole failure
was the existing `card_display_performance_test`: one unchanged-text sample
took 14.404 ms against a 2 ms limit (median 0.151 ms). That check exercises the
unchanged card display path. An immediate isolated rerun passed with zero
failures. The full-run exit remains **1**; the isolated pass does not replace it.
All three hero-facing groups, save/resume, analytics equivalence, surface preview
and inventory equivalence passed within the full run. Registration audit:
902 scripts; 538 full-suite, 29 quarantined and 335 windowed probes.

Logs: `godot-full-after-fixture-fixes.log` and
`card-performance-final-isolated.log` in the proof folder above.
The final Python run uses four shards and a 3600 s per-shard watchdog because
the previous run reached 2400 s with 89/90 modules completed in its largest
resource-linked shard. Individual test limits and assertions are unchanged.

Final Python result: **exit 0, `OK (skipped=66)`**, 2,247 tests across all
234 modules in **1616.501 s**, with zero failures, errors, expected failures or
unexpected successes. All four shard reports are complete. The nonessential
attempt to update the shared Git timing cache was denied by the sandbox; the
suite result and isolated reports were written successfully.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/godot_task_runner.py --task-id hf-01 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/run_python_suite.py --shards 4 --shard-timeout 3600 --output-dir /private/tmp/labyrinth_codex/hf-01-proof/python-full-final
```

Python log: `/private/tmp/labyrinth_codex/hf-01-proof/python-full-final.log`;
structured result: `python-full-final/summary.json` in the same proof folder.
Both full runs followed the final round 0 source change. At that handoff,
`git diff --check` passed and HEAD remained
`07d541d9fa47bcf32ca1aca86ccabaed7fe5c968` on `codex/hf-01`, with all 33 files
uncommitted. The director subsequently committed round 0 as `ab5d45f07` and
performed the accepted windowed inspection described above.

## Feedback 1 verification

Feedback 1 changes the facing tie policy, adds front/rear/mixed diagonal
regressions and a Manhattan-specific combat-start case, and records the two
accepted decisions. Launcher and inspection-fixture support for both modes is
retained. Only focused checks are required for this round; changes remain
uncommitted for the director.

- Facing policy: **PASS (74 checks)**, including eligible-current retention,
  front/rear/mixed diagonal fallbacks, Manhattan distance and lower-id ties.
- Snap golden: **PASS (179 frames)**; gameplay replay:
  **PASS (179 scripted frames)**.
- Facing mutations: **PASS (3/3 killed)**.
- Launcher/fixture CLI: **3 tests pass**, including `--hero-facing persist|snap`
  forwarding and invalid-mode rejection. UI identity lint: **25 tests pass**.
- `git diff --check`: pass. No full suites were run for feedback 1.

Godot logs: `/private/tmp/labyrinth_codex/hf-01-feedback1/` (`policy.log`,
`snap-golden.log`, `gameplay.log`, `mutations.log`). The feedback diff contains
only `scripts/hero_facing_state.gd`, `tests/hero_facing_test.gd`, and this document.

## Feedback 2: undo, trap provenance and Erupt

The director committed feedback 1 as `5c62ec796`. Each of the three new
regressions failed on that baseline for the reported behavior, without script
or parse errors. Before logs and `baseline-results.json` are in
`/private/tmp/labyrinth_codex/hf-01-feedback2/`.

- Undo allowlists only `hero_facing.facing` and `hero_facing.mirrored`. Its
  existing state snapshot restores both leaves; the display cursor resets
  immediately before the normal refresh. The regression walks (2,4) to (3,4),
  checks the offered button, saved/run state and displayed facing, and verifies
  that undo submits no turn-animation frames. Persist covers all four initial
  facings; snap retains its base behavior.
- Enemy action context carries transient `direct_player_hits` from executed
  player-hit calls, including source actor, source tile, target tile and direct
  damage. Trap/surface/status calls do not enter those records. Facing requires
  that provenance; aggregate HP/defense loss and impact keys cannot substitute
  for a direct hit, including when the record is missing. No provenance is
  added to saved combat state or analytics events.
- Erupt records its central direct hit before forced movement and publishes
  its actual surfaced source tile on the production step. Its neighboring
  pushes have no direct-hit record. The existing impact feedback advances
  the facing cursor on contact; the legacy presentation path receives the
  impact cue only in persist. Snap keeps its original presentation path.

The trap regression resolves the natural trap-only plan (8 damage), and a
production ranged action committed to the player (1 direct damage plus the
8-damage Fire trap), with hero (3,3) and enemy (5,3). The Erupt regression uses
the surrounded mark: hero (4,4) takes 6 while the Grub surfaces at (6,4).
It also resolves an actual displacement-only eruption. Snap results compare
against the base resolver; both modes inspect production presentation
submissions at the HP-loss boundary.

`tests/hero_facing_gameplay_test.gd` runs all three regressions before its
existing 179-frame replay, so they remain part of the registered test entrypoint.
To run one independently, append `-- --review-case undo`,
`-- --review-case trap`, or `-- --review-case erupt` to this command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/godot_task_runner.py --task-id hf-01 --stream -- godot --headless --path . --script tests/hero_facing_gameplay_test.gd
```

Only focused tests are run for this round. Results and logs are collected in
the feedback 2 proof folder above. The 179-frame snap golden file retains blob
`3901cfcbd417c40b8dd81b729a86a710a588b322`.

Final focused results: policy **PASS (76 checks)**; undo/trap/Erupt review cases
**PASS (0 failures each)**; movement undo **0 failures**; EN01 burrow/Erupt
**PASS**; gameplay **PASS (179 scripted frames)**; snap golden
**PASS (179 frames)**; UI identity lint **25 tests pass**; facing mutations
**3/3 killed**. `final-results.json`, `*-final.log`, `ui-lint.log` and
`mutations-final.log` retain the results. `git diff --check` passes. The
director committed round 2 as `d75732641`, then added the ten Godot sidecars
from a headless import.

Windowed Undo capture (run by the director on 2026-10-28: PASS, manifest
`/private/tmp/labyrinth_codex/hf-01-feedback2/undo-visual.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/hf-01 && python3 tools/visual_probe_runner.py --task-id hf-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/movement_undo_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/hf-01-feedback2/undo-visual.json tests/movement_undo_probe.gd
```

The persist/snap recording and inspection-fixture commands above remain
available. All feedback 2 changes remain uncommitted for the director.

Feedback 2 files: `scripts/movement_undo_rules.gd`,
`scripts/movement_undo_button.gd`, `scripts/hero_facing_combat.gd`,
`scripts/hero_facing_state.gd`, `scripts/combat_engine.gd`,
`scripts/enemy_mechanics/burrow.gd`, `scripts/enemy_mechanics/burrow_view.gd`,
`tests/hero_facing_test.gd`, `tests/hero_facing_gameplay_test.gd`,
`tests/fixtures/hero_facing_review_cases.gd`, and this document.

## Round 0 changed files

- Runtime: `scripts/hero_facing_state.gd`, `scripts/hero_facing_combat.gd`,
  `scripts/hero_facing_presentation.gd`, `scripts/run_scene.gd`,
  `scripts/settings_store.gd`, `scripts/protagonist_cutout/renderer.gd`,
  `scripts/intent_chip_placement.gd`, `assets/generated/hero_rest_coverage.tres`.
- Launch and fixture support: `tools/headless_playtest.gd`,
  `tools/inspection_fixture.gd`, `tools/inspection_fixture.py`,
  `tools/hero_facing_playtest.py`, `tools/hero_facing_mutations.py`.
- Facing coverage and proof: `tests/hero_facing_test.gd`,
  `tests/hero_facing_gameplay_test.gd`, `tests/hero_facing_snap_golden_test.gd`,
  `tests/hero_facing_gameplay_probe.gd`, `tests/hero_facing_probe_contract.json`,
  `tests/fixtures/hero_facing_run_scene.gd`, `tests/fixtures/hero_facing_snap.csv`,
  `tests/test_hero_facing_tools.py`.
- Existing fixture compatibility: `tests/protagonist_cutout_gameplay_probe.gd`,
  `tests/helpers/protagonist_gear_motion_scenarios.gd`,
  `tests/combat_analytics_context_equivalence_test.gd`,
  `tests/suites/combat_feel_suite.gd`, `tests/save_resume_boundary_test.gd`,
  `tests/surface_preview_equivalence_test.gd`, `tests/test_pt14_04_coverage.py`.
- Suite registration: `tests/headless_test_programs.json`,
  `tests/windowed_test_allowlist.json`, `tests/test_program_suite_runner.py`,
  `tools/python_suite_resources.json`.
- Handoff: this file, `spec/proofs/hf-01/implementation.md`.
