# fel-12 · Noctyrax brazier callouts

## Director feedback 1

The round-0 capture placed the lower plate 4,139.992 px² inside the brazier's clearance rectangle. In the crowded take, the upper tether crossed the lower plate's 6 px clearance and ran back through its own plate. The two round-0 hand guards and the launcher's base-status handling stay in place. The comparison uses the committed round-0 board implementation at `f613d398ebcb20b03dfe176f382f387d680a888a`.

| Requirement | Implementation and proof |
| --- | --- |
| 1. Brazier clearance | Every rendered watch brazier reserves its prop rectangle and, when lit, the full procedural flame envelope. Plates clear that rectangle by 6 px. The 32 branch plates recorded zero brazier overlap. |
| 2. Tether clearance | The placement search checks each tether against the other plates and tethers in both directions. The branch recorded zero hard conflicts in all 16 states. Each living unit intersection adds 40,000. Twelve states had a unit rectangle covering a brazier's required tether endpoint. The witness identifies every such soft crossing with a `FEL12 CROWDED` line. |
| 3. Facing anchor | The plate uses the bottom centre when above its brazier and the top centre otherwise. The line still uses the original 5 px dark stroke and 2 px colour stroke. |
| 4. Search order | The search tries every brazier order and backtracks among candidates to keep the lowest combined score for a clear layout. |
| 5. Tether length | Each candidate pays 0.6 points per px. The crowded upper tether measured 345.067 px on round 0 and 190.196 px on the branch. The replacement lower tether in the capture measures 52.869 px and starts above its plate. |
| 6. Fallbacks | The full plate tries the existing positions and then the expanded grid. Next comes the 34 px plate without the detail line. The last stage prefers hard clearance, then the least unit overlap, and keeps the callout visible. A synthetic witness exercised all three fallback stages and a true tether crossing. The 16 production states used the existing candidate grid. |
| 7. Existing presentation | Standard plate dimensions, copy, colours, shape, icon, tooltip, and visibility rules use the original values. The shared HUD score and other placements retain their original implementation. |

### Feedback verification

- [Headless base and branch witness](../../output/fel12/feedback-1/witness.log), via `bash tools/fel12/native.sh --witness`
  - `FEL12 base WITNESS: FAIL (1/16 states with zero violations, 1 soft-only, 0 expanded, 0 compact, 0 crowded fallbacks, 0 validation failures)`
  - `FEL12 branch WITNESS: PASS (4/16 states with zero violations, 12 soft-only, 0 expanded, 0 compact, 0 crowded fallbacks, 0 validation failures)`
  - `FEL12 solver checks expanded/compact/crowded=true crossing=true`
- [Native launch dry run](../../output/fel12/feedback-1/native-dry-run.log), via `bash tools/fel12/native.sh --dry-run`
  - `FEL12 base NATIVE DRY RUN: PASS (0/3 states with zero violations, 1 soft-only, 0 expanded, 0 compact, 0 crowded fallbacks, 0 validation failures)`
  - `FEL12 branch NATIVE DRY RUN: PASS (1/3 states with zero violations, 2 soft-only, 0 expanded, 0 compact, 0 crowded fallbacks, 0 validation failures)`
- UI identity lint printed `Ran 25 tests in 5.401s` and `OK`. Rules text lint printed `Ran 3 tests in 0.098s`, `OK` and `PASS: Rules text lint (16 existing hits)`.

The base witness exits 1 for its placement violations and the launcher continues to the branch. The native proof records the comparison images for both revisions. Both headless revisions emitted the existing macOS certificate diagnostic from `get_system_ca_certificates`.

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-12 && LABYRINTH_CEL_LOOK=all bash tools/fel12/native.sh
```

Windowed capture remains pending. The command writes these 1920×1080 captures at 100% UI scale, plus both manifests.

| Scene | Base | Branch |
| --- | --- | --- |
| Capture | `output/fel12/feedback-1/native/base/capture.png` | `output/fel12/feedback-1/native/branch/capture.png` |
| Crowded | `output/fel12/feedback-1/native/base/crowded.png` | `output/fel12/feedback-1/native/branch/crowded.png` |
| Hero in front | `output/fel12/feedback-1/native/base/hero_in_front.png` | `output/fel12/feedback-1/native/branch/hero_in_front.png` |

### Chosen defaults

The front fixture uses grid tile `(6, 7)`, one step along both grid axes from the lower brazier. That projects straight down-screen. The synthetic fallback fixtures use a 200 px test plate. The feedback-specific output folder preserves the director's round-0 captures.

No `TODO_DESIGN` placeholders were needed. Changes are uncommitted.

## Round 0

### Root cause

Before the hand cards were laid out, `_hand_visual_top()` returned infinity. The retained board received a hand reservation with position `(10, inf)` and size `(0, -inf)`. Transforming that reservation to board space introduced `NaN` coordinates. Every candidate score became `NaN`, so the search kept its initial rectangle directly above each brazier. The hero and Noctyrax were both in the obstacle list.

The callout search now excludes non-finite reservations before transforming them. The original offsets yielded clear placements in every proof state. [Production change](../../scripts/combat_board_view.gd#L6693)

## Acceptance

| Requirement | Evidence |
| --- | --- |
| 0. Reproduce first | The production Starless Breath fixture from the DFX-03 capture reproduced the overlap on `codex/release` at `7ba6cacac36037ca11967a6205cb6562f18e54ae`. Hero `(4, 4)`, Noctyrax `(4, 1)`, lower brazier `(5, 6)`. The witness prints the chosen rect, every overlap and its area, the winning score and the best unit-clear score. |
| 1. Clear the obstacles | All 30 drawn plates across 15 branch states had zero overlap with living bodies grown by 8 px, health-bar rectangles, prior plates grown by 8 px and fixed HUD rectangles. The witness checked the registered draw rect against the placement result. Coverage includes all eight cardinal hero positions, a dragon footprint adjacent to the lower brazier, the Night Coil threat, the saved Dark before Eclipse warning, the unlit and automatic relight messages, and the result of stepping onto an unlit brazier. |
| 2. Placement order | The existing search found a clear spot in every witness state after the finite-rect guard. Expanded search, compact plate and crowded fallback were each needed in 0 states. |
| 3. Tether | Draw code still connects the bottom centre of the chosen plate to the brazier tile centre. |
| 4. Presentation | The source diff is confined to the fixed HUD obstacle loop in `_noctyrax_brazier_marker_rect`. Callout visibility, text, colours, shape, icon, tooltip and shared HUD scoring retain their existing implementations. |

| Capture plate | Release rect `(x, y, width, height)` | Release body overlap | Branch rect `(x, y, width, height)` | Branch score |
| --- | --- | --- | --- | --- |
| Upper `(3, 2)` | `(893.9569, 232.8017, 261, 54)` | Noctyrax, 6,336.053 px² | `(711.2569, 232.8017, 261, 54)` | 438.480 |
| Lower `(5, 6)` | `(765.0431, 426.1724, 261, 54)` | Hero, 7,583.417 px² | `(765.0431, 566.1724, 261, 54)` | 224.000 |

Both release scores and their best unit-clear scores were `NaN`. With the single bad rectangle excluded, the best unit-clear scores were 438.480 and 224.000. The branch picked both clear candidates. The full witness also logs the release upper plate's overlaps with two additional scoring rectangles.

## Verification

- `bash tools/fel12/native.sh --witness` uses the task-local Godot runner. [Witness log](../../output/fel12/witness.log)
  - `FEL12 base WITNESS: PASS (15 states, 0 expanded, 0 compact, 0 failures)`
  - `FEL12 branch WITNESS: PASS (15 states, 0 expanded, 0 compact, 0 failures)`
- `bash tools/fel12/native.sh --dry-run` exercised both native takes headlessly. [Dry-run log](../../output/fel12/native-dry-run.log)
  - `FEL12 base NATIVE DRY RUN: PASS (2 states, 0 expanded, 0 compact, 0 failures)`
  - `FEL12 branch NATIVE DRY RUN: PASS (2 states, 0 expanded, 0 compact, 0 failures)`
- `python3 tests/test_ui_identity_lint.py` printed `Ran 25 tests in 4.549s` and `OK`.
- `python3 tests/test_rules_text_lint.py` printed `Ran 3 tests in 0.075s`, `OK` and `PASS: Rules text lint (16 existing hits)`.
- `bash -n tools/fel12/native.sh`, `python3 -m json.tool tools/fel12/proof_contract.json` and `git diff --check` exited 0.

Both Godot revisions emitted the same macOS sandbox diagnostic, `ERROR: Condition "ret != noErr" is true. Returning: ""` at `get_system_ca_certificates`. The headless commands exited 0.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-12 && LABYRINTH_CEL_LOOK=all bash tools/fel12/native.sh
```

The runner will validate the 1920×1080 captures at 100% UI scale and write `capture.png`, `crowded.png` and `manifest.json` to each of `output/fel12/native/base/` and `output/fel12/native/branch/`. Both versions load the same production fixture and assets from this worktree. The SubViewport accepts no input and the probe never moves the OS pointer. Windowed capture and visual inspection are pending the design owner's run.

## Chosen defaults

- The native pair uses the west neighbour of the upper brazier, hero `(2, 2)`, as the crowded take. It tied for the fewest clear candidates for one plate at 11 and had the highest combined winning score among the tied states.
- The witness settles for `STATE_SETTLE_FRAMES = 4` after each fixture update. It reuses the DFX-03 fixture seed, sink size, frame rate and opening settle budget.
- If an adjacent hero fixture tile is occupied by Noctyrax, the proof moves the dragon to the closest passable footprint. For the dragon-adjacency case it uses the closest legal footprint adjacent to the lower brazier.

No `TODO_DESIGN` placeholders were needed. Source and tools are uncommitted.
