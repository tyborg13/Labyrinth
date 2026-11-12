> Historical initial/feedback-1 record. Current feedback-2 fixes, real-game fixtures, results and native commands are in [FEEDBACK2_RESULTS.md](FEEDBACK2_RESULTS.md).

Before: board body/footprint hover, rail portrait hover and controller board focus kept the selected rest threat at 100% and other rest threats at **40%**. Chip hover only hit the underlying floor tile; in this fixture it incidentally hit its owner's footprint and produced the same 40% result. Details-off submitted one focused enemy preview; other preview families had no common isolation.

Before: Zekarion/Vyraketh footprint hover contained no enemy summary (one Vyraketh tile showed its existing item pickup). Craghide's existing 1×1 guardian tile also contained no summary. The exact cause was a surface-only tooltip cache plus first-match registered-tooltip precedence: a leader marker returned its leader-only string before the surface fallback. Marker pixels were not captured in the worker sandbox.

All changes are uncommitted. No peer review, publication, queue operation or native/windowed run was performed.

## Files changed

- `scripts/board_threat_isolation.gd` + `.uid`: selected enemy sets, reverse lookup, complete enemy summaries, mark ownership, retained alpha transitions; director-approved gold rail edge and return tween.
- `scripts/board_threat_isolation_paint.gd` + `.uid`: ordered rendering plans with enemy ownership, retaining hero and floor ownership.
- Small integration hooks in `scripts/combat_board_view.gd`, `scripts/run_scene.gd`, `scripts/turn_order_slots.gd`.
- `tools/rd04/`: certified-save proof, baseline reproduction/preparation, focused test runners and UIDs, native launcher and owner command wrapper, still/movie contracts, movie finalizer, README and this report. Generated baseline source copies are removed after use.

## Numbered requirements

1. Reproduced using original HEAD sources and the same certified save. The final log records body centre, footprint, rail, chip, controller and all named enemy types: `/private/tmp/labyrinth_codex/rd-04/before-final.log`.
2. Implemented 30% retained alpha and 0.12-second ease-out in/out for owner-scoped threat paint. Direct hover works during idle, movement selection and card targeting; playback/enemy turns are gated. Hero previews and floor surfaces retain their owners.
3. Reverse lookup and expansion are implemented for empty threatened tiles, including persistent marks; card aiming suppresses reverse lookup. Director feedback 1 completes the visual rail highlight: selected edges use full-alpha `UiPalette.GOLD_BRIGHT` and return to rest over 0.12 seconds with ease-out. Scale, width and glow construction remain unchanged.
4. Production body/footprint inspection includes name, Health, existing status vocabulary and intent; the existing marked-leader line appends. Surface stacks/activation are preserved. The guardian data is 1×1 and was not enlarged.
5. No process-loop redraw was added. Tweens change CanvasItem modulation. Latest proof: `RD04 IDLE REDRAWS: frames=120 requests=131 full=0 static=0`. Requests include existing idle/clock animations; full-board and static-floor redraws stayed zero.
6. Identity lint: `Ran 25 tests in 4.297s` / `OK`. No baseline or policy allowance was changed. Native visual judgment remains for the owner.

## Observed checks

| Check | Exact result |
|---|---|
| Certified isolation proof | `RD04 THREAT ISOLATION: PASS (1764 checks, 0 failures)` |
| Enemy-intent continuity | `PTF09 DOMAIN enemy-intent: 1918 checks, 0 cumulative failures`; `PTF09 FOCUSED: PASS (1918 checks, 0 failures)` |
| Intent chip placement | `RD04 INTENT CHIP PLACEMENT: 15764 checks, 0 failures`; `RD04 FOCUSED: PASS (15764 checks, 0 failures)` |
| Turn-order rail lifetime | `RD04 TURN ORDER RAIL: 812 cumulative checks, 0 failures`; `RD04 FOCUSED: PASS (812 checks, 0 failures)` |
| Hover equivalence | `RD04 CANDIDATE HOVER: 52316 checks, 0 failures (0 distinct labels)` |
| Board tile tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` |
| Live tooltip mutation | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| Tooltip input routes | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| Python resource audit | `ISOLATION AUDIT: 56 modules` (no new Python test module) |
| New script UIDs | `RD04 SIDECARS: PASS` |
| Shell/Python proof tooling | `sh -n` and Python bytecode compilation exited 0 |
| Whitespace | `git diff --check` exited 0 |

Logs and JSON manifests are under `/private/tmp/labyrinth_codex/rd-04/`. The final default-group invocation selected only the default group (20 of 56 modules): `Ran 189 tests in 154.258s` / `FAILED (failures=1)`. The unchanged approved-content runtime smoke command reached its existing 30-second timeout (exit 124). The earlier child-start failure passed on this final invocation. The isolated approved-content recheck passed unchanged: `SHARD 1 COMPLETE: 1 tests; 13.498s`, `Ran 1 tests in 13.726s`, `OK`. The 189-test group itself is reported as failed, not relabelled as a pass. The first default-group run observed `Ran 189 tests in 57.153s` / `FAILED (failures=1)`: the unchanged runner child-cleanup test reported `Child did not start`. No assertion was rewritten. The suite's optional timing-cache write to shared read-only Git metadata was refused; implementation files stayed writable.

Chip and rail suites must use separate Godot processes. Combining them exposed two shared-resource Unknown Presence texture-path assertions; isolated rail and original-source rail checks both passed. The supplied focused runner now separates these domains.

## Proof for the design owner

These commands have **not** been run here. Their exact expanded native Metal/task-runner commands are in `proof_for_owner.sh` and `native_capture.sh`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && tools/rd04/proof_for_owner.sh fixture
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh movie
```

The first command regenerates/verifies the headless inspection save. Expected native proof is under `stills/`, with the five required states plus other footprint captures. The movie finalizer validates/copies 90 consecutive native 1920×1080 frames at 30 fps into `clip/frames/`, excluding setup. No PNG, movie or visual signoff is claimed to exist. See `README.md` for individual capture paths and contracts.

## TODO_DESIGN / chosen defaults / open issues

- `TODO_DESIGN_RAIL_HOVER_HIGHLIGHT_COLOR` was resolved by director feedback 1 and removed. No design placeholder remains.
- Native screenshots, the three-second movie, UI identity judging and inspection remain for the design owner, as assigned in the brief.
- Chosen defaults are restricted to proof: seed 4404; approved enemy/intent fixture choices and explicit positions; 20 setup frames; 0.7-second tooltip wait; embedded tooltip windows; 90-second still timeout and the director-required 240-second movie probe timeout; 0.16-second rail-return proof wait; unpublished Bleed 1/leader and enemy-turn copied-unit assertions; isolated output paths and stable UIDs. Full values are listed in `README.md`. Production alpha, transition duration, resolution, UI scale and movie timing come from the brief.


## Feedback 1 changes

- Rail ownership highlights use `UiPalette.GOLD_BRIGHT` at full alpha. Return uses the same 0.12-second quadratic ease-out. Slot reconciliation preserves an in-flight return tween; held identity does not restart it.
- Added required owner still `stills/06_reverse_lookup_both_rail_slots_lit.png`, with both attackers' lit rail keys recorded in `stills/proof.json` and a required-image entry in the capture contract.
- Confirmed both native commands explicitly use `--rendering-method mobile --rendering-driver metal --fallback-rendering-driver metal`. Movie probe uses `--timeout 240`; no native command was run here.
- Added native engine-log validation. A clean synthetic log was accepted and an unavailable-variant log rejected: `RD04 CAPTURE LOG GUARD: PASS (clean accepted; fallback rejected)`.
- Copied variants passed `python3 tools/cel_look.py status` (exit 0). No generated art or variant values were edited.
- No full suite was run in this feedback round. Focused results are appended below.


Feedback 1 observed results:

- `RD04 THREAT ISOLATION: PASS (1798 checks, 0 failures)` — includes all hover sources, two-attacker rail highlighting, exact 0.12-second return/midpoint, held-set tween identity, and no scale/width/glow additions. Log: `/private/tmp/labyrinth_codex/rd-04/feedback1-proof-final.log`.
- `RD04 IDLE REDRAWS: frames=120 requests=131 full=0 static=0`.
- `RD04 TURN ORDER RAIL: 812 cumulative checks, 0 failures`; `RD04 FOCUSED: PASS (812 checks, 0 failures)`. Log: `/private/tmp/labyrinth_codex/rd-04/feedback1-rail.log`.
- Identity ratchet: `Ran 25 tests in 5.866s` / `OK`. Log: `/private/tmp/labyrinth_codex/rd-04/feedback1-ui.log`.
- Cel-look proof launched with `LABYRINTH_CEL_LOOK=all`: `RD04 CAPTURE CEL LOOK: PASS (no unavailable variants)`. Native capture logs will be checked by the same guard.
- Both shell syntax checks and `git diff --check` exited 0. New capture-log guard accepts a clean fixture and rejects an unavailable-variant fixture.

Native captures remain unrun. The added still is expected at `/private/tmp/labyrinth_codex/rd-04/stills/06_reverse_lookup_both_rail_slots_lit.png`. No TODO_DESIGN placeholder or newly chosen player-facing value remains in this feedback round; the only added proof timing default is the named 0.16-second rail-return wait.
