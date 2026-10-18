# bug-01 feedback 3 — repaired native diagnostic dump

Historical feedback-3 handoff. The owner has since run the dump successfully;
the current classification and proof commands are in
[bug_01_feedback_4.md](bug_01_feedback_4.md).

The first dump crashed because its metadata called a current-board private method
on `ClockedReference`, which intentionally retains the older renderer API. Both
versions expose the geometry fields now read by `DiffCapture.geometry()`. The
caller also reports an incomplete capture instead of cascading into an `errors`
dictionary-key exception. No production files or comparison tolerances changed.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 --timeout 600 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-diff-feedback-3.manifest.json
```

No windowed run was attempted here. Strict native differences can still make this
command exit 1; their classification remains open. The diagnostic mode now dumps
**all 106 cases**, including cases whose differences might disappear with shader
time controlled. Absolute artifact paths are printed, beginning with
`user://bug_01_diff/index.json` and its per-case reports. The native execution cap
is supplied by the runner's actual `--timeout 600` CLI argument above; startup
timeouts are unchanged. No GDScript constant enforces this cap.

## Shader TIME evidence

Each case takes two additional pairs, requesting a real-time interval of 0.25 s
and then waiting for the next rendered frame:

- `time_raw_before.png` / `time_raw_after.png`: an independent production board
  using original shaders. Its floor cache is disabled before both captures, so
  a bake cannot conceal shader animation. Script and actor clocks stay frozen.
- `time_pinned_before.png` / `time_pinned_after.png`: the retained production board
  with script/actor clocks frozen and shader `TIME` controlled.

The report gives both pairs' exact metrics and masks, requested/actual wall time,
frame numbers, logical state/presentation equality, before/after actor snapshots
and equality, and shader-audit equality. An already pinned raw material is reported
as `BUG_01_RAW_TIME_PROBE_INVALID`, rather than passing as an original shader.

The selected control is a **controllable uniform in proof-only shader copies**,
`bug_01_proof_shader_seconds = 12.0`. It does not change production shader files or
source shader resources. The helper expands includes, finds whole `TIME` tokens
outside comments/quoted paths, copies only shaders that use them, redirects those
tokens to the uniform and preserves existing material parameters. Material audits
record source paths, expanded-source hashes, include dependencies and whether each
material actually uses the pinned copy. Godot's shader `TIME` is a built-in input;
script clock freezing alone does not control it. See the
[CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html).

Raw temporal changes with unchanged state/actors identify animation in that
comparison; the pinned temporal pair shows whether this control removes it. No
native temporal result has been observed here. No precision tolerance or visual
verdict is inferred from the headless mock.

## Per-case artifacts and metrics

Each `case_NNN/` contains seven cropped PNG captures: `original_submission.png`,
`restored.png`, `fresh.png` and the four temporal images above. The original and
restored images are read before fresh-board creation or waits. Fresh boards have
independent submitted commands, render layers, geometry caches and health ghosts;
only named fixture inputs are copied, and they settle for three frames. The dump
never force-redraws the retained/reference boards.

Five binary masks are lossless WebP data images: `diff_mask.webp` (restored versus
original), `diff_fresh_vs_original.webp`, `diff_restored_vs_fresh.webp`,
`diff_time_raw_0_25s.webp` and `diff_time_pinned_0_25s.webp`. White means changed;
opaque black means equal. Lossless WebP preserves all mask bytes and keeps correct
all-black masks out of the visual runner's PNG screenshot-variation gate. The
headless check verifies the exact decoded byte round trip.

`report.json` contains all twelve paths, five comparisons, case/label and metadata.
The shared board crop also encloses every differing pixel in any pair, including
outliers beyond geometric board bounds. Bounding boxes appear in crop and viewport
coordinates, using x/y/width/height with exclusive ends.

Measurements use absolute RGBA8 byte deltas, including alpha. Each comparison has
`differing_pixel_count`, bounding boxes, `max_per_channel_delta`,
`max_channel_delta`, `mean_per_channel_delta`, `mean_delta` over all cropped pixels
and channels, and `mean_delta_changed_pixels`. Equal images have zero metrics and
null bounding boxes. Existing assertions still compare complete native image
bytes strictly, with no masking or tolerance.

The existing intentional mutation error remains distinct:
`BUG_01_DELIBERATE_FLOOR_PIXEL_MUTATION` names its viewport pixel and same-board
baseline-to-mutated RGBA delta, independently of reference differences and the
ordinary 30-error reporting cap. Finishing native classification and proving
that mutation fails alone remain pending the owner's outputs.

## Observed headless verification

`static_floor_diff_capture_smoke.gd` drives `DiffCapture.record()` end to end with
the same real `ClockedBoard` and `ClockedReference` objects used natively. Only
GPU readback, render fences and the wait are replaced by explicit headless I/O.
Fresh-board creation, reference metadata access, temporal orchestration,
statistics, crops, all twelve image writes, JSON/index persistence and cleanup
run for real. Synthetic images are deleted and cannot enter native proof.

The smoke also checks TIME detection, real `res://` include expansion, immutable
source shaders, preserved material parameters and controllable uniform values.
An explicit negative control temporarily reinstated the original bad reference
call: the program exited 1 with the original `ClockedReference` missing-method
error and `End-to-end capture must return a complete result`. The corrected source
was restored in `finally`; log: `output/bug-01/capture-smoke-reference-negative.log`.

Final focused run through qa-07, dump flag enabled, exit 0, 6.657 s total;
`output/bug-01/qa-07-floor-feedback-3-final-verified.json` has `complete: true`,
`failed: false`, child `returncode: 0`, `timed_out: false`. Exact result lines:

```text
BUG_01 CAPTURE END_TO_END SMOKE: PASS (ClockedBoard + ClockedReference; GPU readback/fences mocked)
BUG_01 DIFF DUMP CHECKS: PASS (strict RGBA metrics, masks, crops, JSON, fresh fixture, isolated mutation)
RESTORED EMPTY BOARD LOGIC: PASS (native pixel proof requires window server)
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":162596,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

Command executed:

```sh
LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-floor-feedback-3-final-verified.json --suite static_floor_cache_equivalence_test
```

The engine emits its existing macOS certificate `ret != noErr` message; no script
errors occur in the passing run. Output hygiene:
`OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`. `git diff --check` passed.
Full Godot/Python results in [bug_01_findings.md](bug_01_findings.md) are historical;
they were not rerun for this limited test/probe handoff.

## Chosen defaults

Only proof/test fields: fixed shader sample 12.0 s (the existing ambient sample),
three settle frames, 600-second native cap, opaque white/black masks and RGBA8
measurements. The smoke uses case 900, an 8x6 image, white pixel (2,2) against
opaque black, and shader parameter 0.73. Its mock advances phase instead of
waiting. The native 0.25-second interval and 1920x1080 / 100% UI scale are mandated.
The earlier metric fixture remains 8x6 with crop (1,1,5,4), cases 10/11, RGB
mutation (2,2) = (2,1,0,255), alpha mutation (4,3) = (0,0,0,253), fresh blue
(5,4) = (0,0,3,255) and outlying white pixel (7,5).

TODO_DESIGN placeholders: none. Open issues: native per-case classification,
native temporal evidence and the mutation-only failure proof await the owner run.
