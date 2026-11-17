# trp-01 implementation handoff

Uncommitted on `codex/trp-01`, based on director commit `7e8987832`.
No commit, branch change, preflight, peer review, publication, queue edit,
windowed run or full suite was performed. The design owner retains those steps.

## Numbered requirements

1. **Center ground and forecasts.** `CombatEngine.trap_ground_tiles` owns the
   center-plus-cardinals footprint. Damage still resolves first, followed by
   ordinary `BoardSurfaceRules.place` with the same trap source. Air retains
   its existing damage and outward Push. `trap_wake_tiles` still returns only
   the cardinal neighbors. Movement/attack previews and the Pass forecast use
   the production resolver; their center ground is verified. Disarm, placement
   restrictions, delayed occupant contact and death-before-ground order are
   checked. `trap_triggered.center_surface` is additive, normalized, and empty
   for Air/blocked centers. Analytics documentation matches. No save fields,
   damage numbers, generator, counts or AI hazard coefficients changed.
2. **Exact tooltip text.** Titles use `ElementData.name`; all five bodies match
   the brief's three lines, with literal, valid inline tokens. Trap tile entries
   use the existing `traps` icon. Both mouse and controller use the shared tile
   entry and panel factory. Protected glossary/grimoire files are unchanged.
3. **Five trap loops.** Registry entries `trap_fire`, `trap_ice`,
   `trap_lightning`, `trap_earth`, `trap_air` match source kind `trap` and exact
   `element`. All use normal speed, 36–96 action frames at 30 fps, 1.5 MB cap,
   existing TLW2 compression, crop, vignette, fades, hold, crossfade and reduced
   motion. Fixtures use their production elemental biomes, a live generated
   depth-1 trap (6 damage), the same Crawler as Upheaval, and an untouched idle
   hero at least two tiles from every affected tile. The Crawler enters through
   the committed production movement/arrival resolver. Rehearsal observes the
   real trap effect, real `-6`, all five production ground layers, or the far
   Crawler's production Air-push slide with no ground.

Enemy move feedback otherwise snaps the secondary pushed actor at its final
submission. For this recording, its display position is held until the existing
production wind-push slide plays. That slide was extracted unchanged into
`forced_displacement_view.gd`; wind calls the same helper with its original
actors, clocks and effect. There is no new animation timing or VFX. The complete
gameplay result is never modified. All sixteen existing loops also rehearse
successfully, and their shipped media is unchanged.

The descriptive trap assumptions in the heuristic/spec now include center
ground. Card values and scoring coefficients are unchanged. Existing Earth
route tests now pay both Rubble exits; their synthetic full-route budget is 5.

## Observed headless proof

Evidence root: `/private/tmp/labyrinth_codex/trp-01/proof/`.

| Check | Exact result | Evidence |
|---|---|---|
| New per-element rules, triggers, disarm, previews, Pass, blocked center, order | `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` | `trap-rules.log` |
| Existing focused trap/surface, movement, enemy, destruction and Sure-Footed checks | `TRP01 FOCUSED TRAP/SURFACE: PASS (788 checks, 0 failures)` / `TEST RESULT: PASS` | `focused-rules-final.log` |
| All 21 semantic/rehearsal scripts | `TIP01 REHEARSAL RESULT: PASS (0 failures)` / `TIP03 DESIGN PENDING: 0 loops (excluded from recording)` | `all-loops.log`, `all-loops/summary.json` |
| Actual tooltip factories with task-local numerical media | `TRP01 TOOLTIP ROUTES: PASS (five elements; mouse and controller; source isolation)` / `TIP01 TOOLTIP SEMANTICS: PASS (0 failures)` | `tooltip-semantics-final.log` |
| Glossary, tokens and coverage | `GLOSSARY TEST RESULT: PASS (6530 checks, 0 failures)` | `glossary-final.log` |
| Grimoire/short-copy checks | `SHORT CARD TOOLTIPS TEST RESULT: FAIL (767 checks, 2 failures)` | `grimoire-text.log` |
| UI identity lint | `Ran 25 tests in 5.660s` / `OK` | `ui-identity-complete.log` |
| Python resource audit, without executing suites | `ISOLATION AUDIT: 56 modules` | `python-audit/isolation-audit.md` |
| Protected inputs/media | `TRP01 PROTECTED INPUTS: PASS (34 files unchanged)` | `protected-assets.json` |

Final all-loop rehearsal measurements (headless geometry/commands, not native
pixel acceptance):

| Loop | Action frames | Seconds | Minimum sprite margin |
|---|---:|---:|---:|
| Fire | 37 | 1.233 | 25.6559 px |
| Ice | 37 | 1.233 | 25.6557 px |
| Lightning | 36 | 1.200 | 25.6557 px |
| Earth | 37 | 1.233 | 25.6557 px |
| Air | 48 | 1.600 | 25.6558 px |

Every loop's five tile polygons remain inside the crop; every sampled unit has
at least 4 px margin. Each settled tail is 0.033333 s. The unchanged runtime
terminal hold supplies the brief's pause, without padding the recorded tail.
Per-loop timing and observed ground/push reports are `all-loops/trap_*_timing.json`.

Parser-only runner checks, Python AST validation, working-tree sidecar audit
(including untracked files), canonical UID validation and `git diff --check`
also passed. No new Python test module was added, so the Python resource
manifest needs no entry.

Initial checks caught a dynamically formatted inline token and a missing
secondary Air-push slide; both were fixed. The new fixture also rejected the
old four-tile rule as expected (8 missing-center failures, Air passing).
These exploratory logs are separate from final evidence. Existing macOS CA
certificate diagnostics and intentional glossary overflow warnings appear.
An initial collector trial missed section-0 metadata and was excluded. Its two
workers were interrupted; replacements briefly overlapped them during restart.
The reported paired arms each ran with two workers. The strict task-wide
two-worker limit was therefore exceeded briefly during that excluded setup.

### Existing protected-copy failures

The two grimoire failures are:

```text
ERROR: Protected short copy: traps
ERROR: Full rules remain in their expected owning topic: traps -> combat:traps
```

The director's protected data, the historical
`spec/peer_benchmark/staged/tt-01/tooltips.json`, the expectation fixture and
`tests/short_card_tooltips_test.gd` are all byte-identical to HEAD. The historical
fixture still expects “Trigger when entered or hit, spreading their element
around.” and its old full body. Neither appears in the director's new protected
trap entry. These assertions were left unchanged as instructed.

## Difficulty sanity

The unchanged best-draft, full-health ladder captured the first 24 normal rooms
in s0 and s2 from each of two disjoint odd/even seed workers (seeds 1–14).
All 96 constructor payloads round-trip and reproduce their original initial
state. The after arm replays those exact payloads with the frozen policy.
This measures the rule change on identical fights, without changed route/reward
trajectories. Both before workers completed successfully.

Both after workers also completed successfully. Exact paired result lines:

```text
TRP01 LADDER s0: 41/48 (85.42%) -> 43/48 (89.58%); +4.17 percentage points
TRP01 LADDER s2: 37/48 (77.08%) -> 37/48 (77.08%); +0.00 percentage points
TRP01 LADDER PAIRING: PASS (96 identical constructor inputs; frozen policy; 2 workers)
```

Turn caps, counted as losses by the unchanged bot protocol: s0 before 5 / after
4; s2 before 1 / after 1. `proof/ladder-summary.json` contains counts,
rates and source hashes. Raw records and binary constructors are under
`proof/ladder-{1,2}/`; process logs are `proof/ladder-{before,after}-{1,2}.log`.
Before source SHA-256 is `79d32532b251ca9dd7277758b8bef9d2d84680aed501929e62e7b4d6408cc0fe`;
after is `424d55624535373762409d16fae92789a14b8da3e9555096502791f8dd5763c3`.
Policy SHA-256 remains `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`.
Results are a sanity sample, with no tuning applied.

The two before commands used the old code and existing heuristic scores at
`proof/scores.json`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id trp-01 --timeout 0 --stream -- godot --headless --path . --script tools/trp01/ladder.gd -- --seed 1 --scores /private/tmp/labyrinth_codex/trp-01/proof/scores.json --output-dir /private/tmp/labyrinth_codex/trp-01/proof/ladder-1
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id trp-01 --timeout 0 --stream -- godot --headless --path . --script tools/trp01/ladder.gd -- --seed 2 --scores /private/tmp/labyrinth_codex/trp-01/proof/scores.json --output-dir /private/tmp/labyrinth_codex/trp-01/proof/ladder-2
```

The after commands and report:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id trp-01 --timeout 0 --stream -- godot --headless --path . --script tools/trp01/ladder.gd -- --replay --output-dir /private/tmp/labyrinth_codex/trp-01/proof/ladder-1
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id trp-01 --timeout 0 --stream -- godot --headless --path . --script tools/trp01/ladder.gd -- --replay --output-dir /private/tmp/labyrinth_codex/trp-01/proof/ladder-2
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && python3 tools/trp01/ladder_report.py --proof-dir /private/tmp/labyrinth_codex/trp-01/proof
```

## Reproduce focused headless checks

All Godot commands below start in this worktree and use the required runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tests/trap_center_ground_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tools/trp01/focused_rules.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/trp-01/proof/all-loops python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tools/tooltip_loops/capture.gd -- --semantics-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tests/glossary_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id trp-01 --stream -- godot --headless --path . --script tests/short_card_tooltips_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/trp-01/proof/python-audit
```

## Proof for the design owner

Run these in order on the window server. Recording uses cel look, sounds off,
1920×1080, 100% UI scale and the existing native recorder. Only the five new
streams are selected; the sixteen existing streams remain untouched.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && python3 tools/tooltip_loops/record.py --task-id trp-01 --output-dir /private/tmp/labyrinth_codex/trp-01/record --loops trap_fire,trap_ice,trap_lightning,trap_earth,trap_air --proof-contract tools/trp01/record_contract.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/trp-01 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/trp01/capture.gd --task-id trp-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tools/trp01/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/trp-01/capture/manifest.json --overwrite-result-manifest
```

Recording outputs: `/private/tmp/labyrinth_codex/trp-01/record/`, including 15
source PNGs `trap_<element>_source_{start,first_motion,end}_1920x1080.png`, raw
streams, timings, provenance, manifest and compression report. Compression
installs each `assets/tooltip_loops/trap_<element>.tlw` and `.tlw.json` only
after the existing gates and new duration limits pass.

Native capture outputs in `/private/tmp/labyrinth_codex/trp-01/capture/`:

- `trap_fire_tooltip_playing_1920x1080.png`
- `trap_air_tooltip_playing_1920x1080.png`
- `trap_fire_five_tile_aftermath_1920x1080.png`
- `manifest.json`

The first two require live native tile hover and an advancing loop frame; the
third runs the production trigger and asserts the five-tile Fire result before
capture. No `inspection_fixture.py` command was requested by this unit.

## Files changed

- `scripts/combat_engine.gd`: center ground helper, placement and additive event.
- `scripts/combat_board_view.gd`: exact concise trap text.
- `scripts/board_tile_tooltip.gd`: icon and source on shared mouse/controller entries.
- `scripts/tooltip_loop_registry.gd`, `data/tooltip_loops.json`: element match and five rows.
- `scripts/forced_displacement_view.gd` / UID, `scripts/enemy_mechanics/wind_view.gd`: shared existing push slide.
- `spec/analytics.md`, `spec/card_balance_heuristic.md`, `tools/card_heuristic.py`: additive event contract and descriptive trap assumptions.
- `tests/trap_center_ground_test.gd` / UID: new permitted rules cases.
- `tests/run_tests.gd`, `tests/suites/board_surface_suite.gd`, `tests/suites/surface_core_review_suite.gd`: affected existing trap copy/footprint/Rubble expectations.
- `tools/tooltip_loops/trap_fixture.gd`, `trap_checks.gd`, `trap_context.gd` / UIDs: staging, continuous capture observations and factory/copy checks.
- `tools/tooltip_loops/fixture.gd`, `playback.gd`, `patch_checks.gd`, `record.gd`, `capture.gd`: trap integration and proof/provenance hooks.
- `tools/tooltip_loops/record.py`, `compress.py`: optional task/output/contract flags and minimum-duration gate; existing defaults preserved.
- `tools/trp01/capture.gd`, `focused_rules.gd`, `ladder.gd` / UIDs: native proof, focused existing suites and matched measurements.
- `tools/trp01/capture_contract.json`, `record_contract.json`, `ladder_report.py`, this handoff.

## TODO_DESIGN placeholders

None added; no design decision is pending.

## Chosen defaults

Only offline proof/test/measurement fields were chosen:

- Recording staging: center `(1,1)`, entry `(0,1)`, far Air Crawler `(2,1)` →
  `(3,1)`, hero `(3,2)`, within the existing 4×3 crop. Damage and hero/enemy
  stats come from production; the one-step held route is the brief's script.
- Rule fixtures: center `(4,3)`, entry `(3,3)`, remote enemy `(7,6)`, existing
  Base fixture HP 1000, test attack damage 1, blocked crate HP 1000, lethal
  center occupant HP 1. The synthetic full dynamic-Rubble route budget is 5.
- Measurement: two workers, 24 rooms per section each, odd/even seeds starting
  at 1/2, 100-seed fault bound, best draft, original full-health ladder and
  existing heuristic scores. Both arms use exactly the same constructors.
- Task-local proof/output directories above. Native capture retains the
  existing 180-second capture watchdog; recorder retains 240 seconds. No
  player-facing clocks, motion, camera, crop, tuning, colors or sound changed.

## Open issues

Native recordings, `.tlw`/provenance installation, native screenshot inspection
and the owner's visual judgment are pending the two commands above. Until
recording, new trap panels safely remain text-only. The two pre-existing
protected-copy test failures need the design owner's resolution. All changes
remain uncommitted for integration, peer review and inspection by the owner.
