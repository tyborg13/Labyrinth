# rd-08 feedback 2: Sealbinder countdown rules

Implemented the owner's decision without changing the countdown chips, their
positions, wording, icons or skin. `TODO_DESIGN_sealbinder_cue` is removed from
runtime code. Changes remain uncommitted.

`board_snare_countdown.gd` reads each existing visible door chip's exact bounds
and returns the owning Sealbinder's unchanged `SnareRules.seal_tooltip` text.
`BoardPlateVisibility.status_entries` includes those bounds in the same input
map used by fixed status icons. Board tooltip dispatch uses the same
`UiTooltipPanel` factory. Hovering a countdown therefore inspects its Sealbinder
and shows its plate; it keeps the rules tooltip at the same location when that
plate appears. Both health-bar settings are supported. Ordinary Always-mode
status icons retain their existing painted-region tooltip path.

No enemy body tooltip was reintroduced. The obsolete body-specific Sealbinder
lookup was removed. The existing countdown controls remain mouse-ignoring;
there is no new control, text, icon, visual value, gameplay rule or save change.

## Observed proof

Logs: `/private/tmp/labyrinth_codex/rd-08/feedback2/`.

| Check | Exact observed result |
|---|---|
| Real Snare fixture, stock verifier | `Inspection fixture verified.` / `INSPECTION_FIXTURE_VERIFIED ... "ok":true` |
| Integration | `RD08 INTEGRATION: PASS (5243 checks, 0 failures)` |
| Board tooltip test | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` |
| UI identity lint | `Ran 25 tests in 3.560s` / `OK` |
| Stable source sidecars | `RD08 SIDECARS: PASS` |

The integration proof's focused `sealbinder_checks.gd` boots the stock-certified
Snare save and checks both Sealbinders under both health-bar settings. It checks
exact rules text at rest and with the plate shown, the shared status hit map and
panel style, chip-to-unit hover ownership, unchanged chip bounds, and body-popup
suppression. It also retains all earlier rd-08 checks. No full suite or windowed
renderer run was performed.

Reproduce the certified fixture and the two requested checks:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/inspection_fixture.py --task-id rd-08 --run-id rd-08-sealbinder --manifest /private/tmp/labyrinth_codex/rd-08/feedback2/snare.json --scenario snare --snare-biome fire --snare-tier 2 --snare-case first_turn --seed 83 --summary 'rd-08 Sealbinder countdown tooltip proof'
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/integration_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
```

The main `prepare_fixtures.py` workflow now includes this certified Snare case,
so a fresh integration proof setup prepares all four required scenarios.

Changed this round: the new countdown hit-map helper and UID; plate-visibility
and board tooltip routing; placeholder removal; the certified-save adapter's
Snare support; integration proof plus focused Sealbinder checks and UID; fixture
preparation and sidecar tooling; handoff documentation.

No new player-visible defaults or TODO_DESIGN placeholders remain. Proof-only
values reuse the established Snare fixture (seed 83, fire, tier 2, first turn),
20 settling frames, 3-second hold expiry, 0.25-second fade settlement and the
existing off-board pointer sentinel. Native visual inspection remains assigned
to the owner under the existing sandbox split.
