# ptf-09 observed results

> Original implementation-run evidence is archived below. Feedback 1 supersedes
> its appearance/layer values; see [FEEDBACK1_RESULTS.md](FEEDBACK1_RESULTS.md)
> for the revised implementation and verification.

Implementation is uncommitted. No peer review, sign-off, windowed/native run,
inspection-fixture preparation, publication, branch operation or Git write was
performed by the implementation worker.

## Acceptance criteria

1. **Targeting state and tile:** the overlay consumes `_hovered_board_tile` and
   the existing action preview. Card, movement, surface, guardian/illusion utility,
   controller, idle, invalid and animation-exit cases are exercised by the
   headless highlight proof. Controller and pointer changes move it immediately.
2. **Director appearance:** implemented the 3 px raised border, 4 px lift,
   2 px/45% plane rim, 10 px/35% outer glow, no fill, 1.4 s 80–100–80% pulse,
   reduced-motion hold and zoom scaling. Headless geometry/layer/occlusion-fixture
   checks pass. Actual renderer appearance remains for the owner to inspect.
3. **Tones:** reuses `_action_context_target_color` for move/attack/valid/invalid;
   shortcut attacks are attack tone; ground utility remains valid; invalid tone
   alpha is 70%. The proof checks every palette case.
4. **Intent-icon click:** targeting clicks reach the production tile handler;
   idle intent inspection preserves its early return. Prop/tile tooltip logic is
   unchanged, and the existing tooltip test passed.
5. **Performance:** one retained shader quad; pulse updates only opacity, with no
   per-frame board redraw. Measured serial A/B, B/A, A/B against release base
   `7cf181c7e26428b39d3350b52b2586ac89f2bf94` using existing runtime instrumentation.
   Native renderer/GPU performance remains for the owner.
6. **UI identity:** all 25 lint tests pass; baseline was not changed.

## Exact observed result lines

| Check | Observed output |
|---|---|
| Headless highlight proof | `PTF09 HIGHLIGHT: PASS (74 checks, 0 failures)` |
| Focused hover/input/shortcut/targeting-audit/enemy-intent | `PTF09 FOCUSED: PASS (61323 checks, 0 failures)` |
| Card audit, within focused run | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json` |
| Board tile tooltip test | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` |
| Headless capture setup | `PTF09 CAPTURE CONTRACT: PASS (96 states, 1920x1080, UI scale 100%)` |
| UI identity lint | `Ran 25 tests in 8.145s` / `OK` |
| Python default group, final run | `Ran 189 tests in 32.665s` / `OK` |
| Python resource audit | `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/ptf-09/python-audit/isolation-audit.md` |
| Paired instrumentation | `PTF09 PERFORMANCE: completed A/B, B/A, A/B; headless (no GPU claims for headless)` |

The focused-domain cumulative counts were 52316 after hover, 52779 after input,
53839 after shortcut, 59405 after targeting-audit and 61323 after enemy-intent,
all with zero failures. Both full project suites were intentionally omitted.

## Final paired headless measurements

360 samples per side, with the same fixed 1920×1080 SubViewport. A is the supplied
release base, B is this implementation. Values below are microseconds.

| Cost | A median | B median | A p99 | B p99 |
|---|---:|---:|---:|---:|
| Hover handler | 18.0 | 37.5 | 125.0 | 227.0 |
| Instrumented runtime CPU per frame | 6756.0 | 6765.5 | 18016.0 | 18766.0 |
| Wall interval per frame | 10023.0 | 9956.0 | 24405.0 | 29845.0 |

These are observed headless CPU/frame intervals, including scheduler variation.
The frame-wall p99 increased by 5440 us. They do not validate shader/GPU costs
or native frame pacing; no performance improvement is claimed. The native
paired command in README.md retains the same fixture and sample order.

## Evidence paths

All outputs are under `/private/tmp/labyrinth_codex/ptf-09/`:

- `highlight_proof.log`
- `focused_checks.log`
- `capture_contract.log` and `captures/semantics.json` (headless setup only)
- `performance_headless.json`, `performance_headless.log`, `performance_report.txt`
- `python-default-final/summary.json`, `python-default-final.log`
- `python-audit/isolation-audit.md`

The standalone tooltip log is
`/private/tmp/labyrinth-godot-home/ptf-09-1794368137679483000-48885/godot.log`.
The final card audit is
`/private/tmp/labyrinth-godot-home/ptf-09-1794368380416484000-49204/Library/Application Support/Escape the Umbra Parallel ptf-09-1794368380416484000-49204/card_targeting_audit.json`.

There are **no rendered captures yet**. The exact cel-look windowed commands and
all intended PNG filenames are in README.md. The renderer run will emit six
stills plus 90 PNG sweep frames at 1920×1080, 100% UI scale.

## Execution notes and open issues

- Initial headless parsing lacked the fresh worktree's script-class cache.
  An intentional headless import populated that cache; the broad asset import
  was interrupted rather than reported as passing. New owned UID sidecars were
  preserved/generated with Godot. Twenty-six new untracked import sidecars
  outside this unit were removed, recorded in `import_metadata_cleanup.json`.
- Existing headless output includes the macOS certificate-store error
  `Condition "ret != noErr" is true`, raw-image loading warnings for the existing
  card-drag-arrow tests, and missing glossary entries for `bramble`/`ice_pillar`.
  The task runner returned success for the result lines above; none are new
  script/parse failures, and no existing assertions were rewritten.
- The Python runner passed but could not save its optional timing cache:
  `[Errno 1] Operation not permitted` under
  `/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/`.
- HEAD changed to ptf-05b (`3c0b1145c`) during work without its added files
  appearing in this checkout. Missing `scripts/target_click_feedback.gd*` and
  `tools/ptf05/*` are an owner-side integration inconsistency. The ptf-09 code
  was verified relative to the brief's release base, and no missing other-unit
  files were recreated. Reconcile the branch/index/worktree before committing.
- TODO_DESIGN placeholders: none. Chosen debug/proof defaults are listed in
  README.md. Native shader appearance, actual body/crate occlusion, the pulse
  clip, independent visual judgement and native timing remain owner proof.
