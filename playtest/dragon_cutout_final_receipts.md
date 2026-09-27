# Final seven-cutout receipt batch

The first complete batch ran after all six native encounter studies and the
integrated regression passed. All seven automated receipts passed, but visual
review rejected Vaeloryx attachment seams and Vyraketh/Tharokh limb or neck gaps.
`/private/tmp/dragon-cutout-final-v1` is preserved as development evidence, not
accepted final proof. See [current repair and review status](dragon_cutout_feedback_notes.md).
All three bounded repairs now have independent cycle acceptance, production
promotion, native parity/rest checks and passing focused suites. The final-v2
batch completed with exit 0 in session 52299: 3,696 timed board frames across
80 clips, 80 pixel-identical editable-scene reloads, full-decode timing checks,
and all seven end-of-batch current-source verifications passed. Independent
visual acceptance is recorded in the [four-rig review](dragon_four_rig_final_cutout_review_20260927.md),
[Noctyrax review](dragon_noctyrax_final_cutout_review_20260927.md), and
[Vyraketh/Tharokh review](dragon_vyr_thar_attachment_review_20260927.md).
The fresh captures preserve every accepted animation image byte; the seven
changed editor focus-glow screenshots were individually inspected and accepted.
Source/proof bindings and totals are indexed in
`/private/tmp/dragon-cutout-final-v2/batch-summary.json`.

The reproducible commands below require an exclusive Godot/renderer lease.
Do not run a native game, another probe or another Godot test concurrently.

From the shared task worktree, using a fresh output version:

```sh
bash playtest/dragon_cutout_final_receipts.sh render /private/tmp/dragon-cutout-final-v2
```

This checks case/production motion equality and tool availability, runs all seven
native Metal captures sequentially, and then verifies all seven again against
the final unchanged sources. It stops on any failure. No timeout override is
added: the workflow derives its capture allowance from sample count and retains
the visual runner's startup watchdog and GUI lease behavior. Use an asynchronous
terminal/tool session so the coordinating agent can keep providing updates.

To recheck existing receipts after inspection or a content-preserving commit:

```sh
bash playtest/dragon_cutout_final_receipts.sh verify /private/tmp/dragon-cutout-final-v2
```

The batch is a thin wrapper around these exact per-case commands:

```sh
python3 tools/cutout_workflow.py render experiments/cutouts/NAME/VARIANT --output /private/tmp/dragon-cutout-final-v2/NAME --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --backend metal
python3 tools/cutout_workflow.py verify-render experiments/cutouts/NAME/VARIANT --output /private/tmp/dragon-cutout-final-v2/NAME
```

| Order / NAME | VARIANT | Timed board frames, both facings | Full clip set |
| --- | --- | ---: | --- |
| 1 iskaldra | feedback_v02 | 560 | idle, walk, talon, lance, storm, mantle |
| 2 zekarion | feedback_v02 | 480 | idle, walk, claw, breath, charge, call |
| 3 noctyrax | feedback_v02 | 608 | idle, walk, claw, breath, coil, eclipse |
| 4 lightning_wisp | feedback_v02 | 336 | idle, walk, attack, cast |
| 5 vaeloryx | feedback_v02 | 480 | idle, walk, dive, gale, pull, guard |
| 6 vyraketh | feedback_seams_v03 | 656 | idle, walk, maw, kindle, crownfire, cinderfall |
| 7 tharokh | feedback_seams_v03 | 576 | idle, walk, claw, brace, breath, faultline |
| Total | | 3696 | |

Counts are an index of the prepared metadata, not a substitute for each render
report's actual `authored_frames`. If metadata changes before the freeze, update
this index and the batch's expected-count labels; do not alter the case to fit it.

## Source closure and invalidation

Current `cutout_pipeline.proof.input_hashes` hashes each case's `cutout.json`,
motion, layouts, referenced part/mesh/rest images and declared `sources`.
It also hashes `project.godot`, `tools/cutout_workflow.py`, and recursively:

- `scripts/*.gd`
- `tools/cutout_pipeline/*.{gd,py}`
- `scenes/*.tscn`
- `data/*.json`
- `shaders/*.gdshader`
- `assets/*.{png,ttf,otf,json,res}`

Task Markdown, ordinary tests, this batch, audio and import caches are outside
that closure. A production source change during capture rejects that capture;
one after capture invalidates its receipt. A shared script/data/art change
invalidates all seven. Changing Git metadata or committing identical bytes does
not. Do not edit/annotate files inside a finished case proof directory. Keep
inspection notes and any derived contact sheets outside it.

For failure, preserve the rejected output/logs, diagnose and use a fresh version;
never overwrite proof or continue a mixed-source set. If unchanged sources and
one isolated runner failure warrant resuming, invoke the remaining exact per-case
commands with fresh case output directories and finally verify all seven. Root
must explicitly account for the resulting output paths in the index.

## Output index and inspection

The batch writes `/private/tmp/dragon-cutout-final-v2/index.md`, per-case command
reports under `logs/`, and immutable proof directories named for each creature.
For every case inspect these outputs:

| Output inside NAME/ | Meaning / inspection |
| --- | --- |
| `videos/cutout_review.mp4` | All front/rear clips at case-declared timing; inspect complete cycles and transitions. |
| `videos/front_CLIP.mp4`, `videos/rear_CLIP.mp4` | Individual timed clips; inspect both full idles and all peak action bends. |
| `front_CLIP/board_####.jpg`, `rear_CLIP/board_####.jpg` | Every native board frame at 1920×1080, UI scale 1.0. |
| `front_CLIP/pose_####.png`, `rear_CLIP/pose_####.png` | First full cycle on 512×512 transparent puppet canvas; inspect seams, support contacts, wing roots, tail and head. |
| `front_CLIP_####.png`, `rear_CLIP_####.png` | Lossless board samples at start, half-cycle and final sample. |
| `front.tscn`, `rear.tscn`, `render_manifest.json` | Editable scenes and native geometry/bounds/roundtrip checks; every recorded reload must be pixel-identical. |
| `visual_probe_result.json`, `native_probe.log` | Real renderer dimensions, backend/runner acceptance and diagnostics. |
| `case_validation.json`, `videos/encoding.json` | Structural result, authored/encoded durations and full video decode PASS. |
| `capture_input_sha256.json`, `proof_sha256.json` | Exact input/output bindings checked by `verify-render`. |

Grounded dragon claws must remain planted through idle while proximal joints
stay attached. Vaeloryx and Wisp must articulate parts coherently through hover.
Inspect the corrected rear wing roots/head, Iskaldra/Zekarion/Noctyrax rear seams,
and maximum Vaeloryx Pull bend, plus both new Vyraketh/Tharokh breath cycles.
No whole-image motion substitute or numeric-only acceptance closes these checks.

For the second final batch, accepted predecessors are v1 for Iskaldra, Zekarion,
Noctyrax and Lightning Wisp; `/private/tmp/vaeloryx-attachment-fix-02` for
Vaeloryx; and `/private/tmp/dragon-seam-repair/vyraketh-candidate01` and
`/private/tmp/dragon-seam-repair/tharokh-candidate02` for the remaining two.
Compare every PNG/JPG byte against the relevant inspected predecessor. Carry
prior full-cycle inspection only when those image bytes match; inspect every
mismatch and new bounded board/peak witnesses. Fresh source/output verification,
editable-scene reload checks, and encoded/full-decoded timing checks are still
required for every new receipt. Record carried and freshly inspected scopes
explicitly, without claiming the carried cycles were newly watched.

Runtime timing is 1.1 seconds for shared areas, 0.8 for utility, physical contact
at 0.42 and breath release/contact at playback 0.30/0.52. Noctyrax's Eclipse case
records its 1.1-second area use; the live reduced/utility proof owns its 0.8-second
summon use. Authoring captures do not replace production action/idle/reduced
integration receipts or native encounter studies. They also do not certify a
Windows export. Record inspection and final seven verification results in
[cutout notes](dragon_cutout_feedback_notes.md) before exact-HEAD handoff.
