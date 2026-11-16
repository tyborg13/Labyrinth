# uph-01 implementation handoff

All changes are uncommitted. The design owner retains commit, review, inspection-fixture preparation and publication ownership. No permanent tests, approved data, art, icons, audio, fonts, rules, forecasts, AI, analytics or save fields were changed.

## Step 0: baseline presentation

Before implementation, both `adjacent_free` placement paths snapped their displaced occupant:

- Upheaval: `scripts/battlefield_rules/upheaval.gd:87–90` chooses the landing and applies ground arrival. `scripts/run_scene.gd:25001–25005` accepts the surface step; `34691–34710` draws the already-resolved state while the Outcrop rises. There was no occupant movement presentation.
- Erupt: the production Grub cutout animates emergence, but `assets/units/burrow_grub_cutout/actions.gd:46–49` replaces the entire state at its contact boundary, then draws it at `:66–67`. The displaced occupant snaps. The legacy path similarly replaces the state at `scripts/enemy_mechanics/burrow_view.gd:131–137`, after the emergence frames.
- The other `_force_place_actor` call, inside `_force_move_actor`, belongs to existing Push/Pull movement, not `adjacent_free`; that movement retains its existing presentation.

These are baseline line numbers, before the additions in this unit. No existing Erupt occupant throw matched the brief.

## Acceptance

1. **Launch:** `scripts/displacement_throw.gd` presents production terrain feedback from zero, holds the occupant until 0.06 s, then requests its existing hit clip. Static actors retain their facing and idle frame. It does not transform the body beyond translation; the approved hit clip remains unchanged.
2. **Flight:** linear interpolation of the two engine anchors for 0.36 s, minus `4 * (0.5 * tile_height) * t * (1-t)` on Y. The existing shadow geometry is drawn by a separate floor-depth canvas at the linear ground point, without scaling. The original body/rim canvas temporarily uses z=1 above board bodies/terrain, returning to z=0 on contact. Maquette root placement stays continuous during flight.
3. **Landing:** at 0.42 s, the display releases the committed occupant state and starts its existing arrival feedback and production damage number. Outcrop rise and arrival effects have separate surface-feedback clocks. Existing sound identities are reused and deduplicated across these clocks; there are no new cues, effects or shake calls.
4. **Together:** one shared elapsed clock samples every displaced occupant. The proof fixture throws the Crawler and hero together.
5. **Reduced motion:** the committed landing and raised Outcrop appear together on the first presentation frame, with no flight or elevated body canvas.
6. **Other paths:** the same helper now presents the production Grub Erupt adapter and its legacy `burrow_view.gd` fallback. Erupt neighbors' ordinary pushes remain outside the central-occupant throw. The Upheaval surface path is the sole `run_scene.gd` integration site.

Landing coordinates come from the committed `after` snapshot. Presentation never reruns `adjacent_free`. The semantic probe also compares these coordinates to the public forecast moves used by the rule-view landing ghosts.

## Files

- `scripts/displacement_throw.gd`: shared path extraction, display snapshots, trajectory, reactions, feedback clocks and floor-shadow canvas.
- `scripts/run_scene.gd`: one surface-presentation dispatch site.
- `scripts/combat_board_view.gd`: floor-shadow draw dispatch, body/shadow separation, held idle frame, continuous flight placement and per-tile arrival clocks.
- `scripts/board_unit_team_outlines.gd`: forwards retained actor canvases to the shared depth/shadow helper.
- `scripts/static_enemy_facing.gd`: retains the existing still's facing during flight.
- `scripts/enemy_mechanics/burrow_view.gd`, `assets/units/burrow_grub_cutout/actions.gd`: legacy and production Erupt integration.
- `tools/uph01/capture_scene.gd`, `throw_probe.gd`, `proof_contract.json`, this document: unit-local proof tooling and handoff.

## Observed verification

All Godot commands ran through `python3 tools/godot_task_runner.py --task-id uph-01 --stream -- godot --headless --path . --script …`.

| Script / command | Exact result |
| --- | --- |
| `tools/uph01/throw_probe.gd -- --logic-only` | `UPH01 SEMANTIC RESULT: PASS (2115 checks, 0 failures)` |
| `tests/bos01_rules_test.gd` | `BOS01 RULES TEST RESULT: PASS (420 checks, 0 failures)` |
| `tests/battlefield_fuel_test.gd` | `BATTLEFIELD FUEL TEST RESULT: PASS (67 checks, 0 failures)` |
| `tests/el04_rule_views_test.gd` | `EL04 RULE VIEWS RESULT: PASS (0 failures)` |
| `tests/brs02_test.gd -- --feedback-only` | `BRS02 FOCUSED RESULT: PASS (248 checks; 0 failures)` |
| `tests/hero_facing_test.gd` | `HERO FACING TEST: PASS (76 checks)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.388s` / `OK` |
| `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/uph-01/python-audit-final` | `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/uph-01/python-audit-final/isolation-audit.md` (exit 0) |
| `git diff --check` | exit 0, no output |

The semantic tool invokes the existing `battlefield_rules_suite.gd` and its feedback suites. Its additional proof checks cover both engine landings, forecast parity, launch/landing boundaries, the exact parabola, simultaneous actors, floor-depth shadow canvases, existing hit clips, normal-depth restoration, reduced motion, production Erupt playback, landing-time damage numbers, arrival-trap feedback and the full 30 fps capture schedule. It writes `/private/tmp/labyrinth_codex/uph-01/headless/manifest.json`, explicitly marked `native_pixels: false`. No PNGs were captured in this sandbox.

Godot printed the environment diagnostic `Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates` on startup. All final commands above exited 0. An initial probe fixture incorrectly treated Thornmother as an enemy catalog type; this was corrected to use the protected earth Warband variant's captain (`briar_weaver`) and title. The final probe passed.

## Proof for the design owner

Windowed rendering is unavailable in this sandbox and was not attempted. Run this exact command from the unit worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/uph-01 && LABYRINTH_CEL_LOOK=all UPH01_OUTPUT_DIR=/private/tmp/labyrinth_codex/uph-01/native python3 tools/visual_probe_runner.py --task-id uph-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --expect-size 1440x640 --proof-contract tools/uph01/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/uph-01/native/runner_result.json tools/uph01/throw_probe.gd
```

The tool uses production scene playback in a native 1920×1080 viewport, 100% UI scale and the approved cel look. It prepares the real Thornmother line, moves the hero and Crawler onto two different marked tiles, then calls the real resolver and surface-presentation callback. It produces:

- `throw_000.png` through `throw_024.png`: 30 fps, -0.10 s through +0.70 s relative to the raise.
- `tail_throw.png`: exact +0.72 s, 0.30 s after landing.
- Matching `reduced_*.png` and `tail_reduced.png` captures.
- Matching `strip_*.png` board crops at 1440×640; the source captures remain 1920×1080.
- `manifest.json`: timestamps, engine paths, presented positions, ground-shadow positions and semantic results.
- `runner_result.json`: validated PNG dimensions, nonblank board-region checks and runner metadata.

The contract requires all 104 PNGs. Inspect the launch, apex, contact, floor shadows, actor depth and reduced-motion snap. Native appearance, the independent visual judgment and the playable inspection fixture remain with the design owner. The brief requests no `inspection_fixture.py` command from this implementation worker.

Headless reproduction:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/uph-01 && UPH01_OUTPUT_DIR=/private/tmp/labyrinth_codex/uph-01/headless python3 tools/godot_task_runner.py --task-id uph-01 --stream -- godot --headless --path . --script tools/uph01/throw_probe.gd -- --logic-only
```

## TODO_DESIGN placeholders

None introduced. Existing Upheaval placeholders and all protected design values are untouched.

## Chosen defaults

Only implementation/proof values were chosen:

- `AIRBORNE_Z = 1`, with shadow relative z=-1, implements the specified body-above-board/floor-shadow ordering; normal actor z stays 0.
- Proof clock `STEP_SECONDS = 1/300`; `SETTLE_FRAMES = 8`.
- Debug crop `STRIP = Rect2i(240, 160, 1440, 640)`; native proof timeout 120 s.
- Existing open-board fixture/seed (`Fixtures.FIXTURE_SEED = 20261012`), `SOURCE = (5,2)`, preparation `HERO = (5,5)`, `HERO_MARK = (5,4)`, `CRAWLER = (4,4)`, `SOURCE_ID = 1`, `CRAWLER_ID = 2`, `FIXTURE_HP = 50`, and `PROOF_TRAP_DAMAGE = 2`. These values occur only in proof tooling.
- Proof files default to runner-isolated `user://uph01-proof`; `UPH01_OUTPUT_DIR` selects the explicit output paths above.

No production tuning or asset values were chosen. Full integration suites, review, commit and publication were not run, as assigned to the design owner.
