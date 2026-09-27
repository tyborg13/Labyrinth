# Dragon playtest cutout repairs — 2026-09-27

Scope: feedback 12 (Iskaldra rear seams), 16–17 (Vaeloryx articulated rear and wing roots), 22–23 (Zekarion rear seams and Lightning Wisp articulation), and 32 (Noctyrax idle seams). This is a follow-up to the production baseline at `44e856d0432aa9b299060022c30d22bbe125d098`. Worker-owned Git preflight passed before edits.

## Design

Each creature retains one coordinated breathing phase. Grounded dragons keep terminal claws rigid and planted while their proximal joints stay attached to the moving torso. Vaeloryx and the Wisp hover with restrained part-relative displacement in that same phase. No traveling wave, independent oscillation, or whole-paint substitution is introduced.

- **Iskaldra:** old idle counter-translated both complete hind legs, exposing their cut edges against the rising pelvis. Idle now uses its existing support solver; proximal leg/fill weights blend into the pelvis. Tail follows the pelvis.
- **Zekarion:** old torso-only translation left root-bound hind limbs and tail behind. The complete trunk now carries their attachment points, four support solvers preserve the claws, and proximal hind-leg weights refer to the torso.
- **Noctyrax:** old idle froze entire leg roots. Support IK now follows the moving shoulder/hip while holding the distal claws in place. All original paint and layout bytes remain unchanged.
- **Vaeloryx:** head, wing tips, claws and tail move by different restrained amounts using one shared breathing phase. Wing and hind-limb attachment meshes blend into the torso. Rear art was corrected with built-in image generation: both wing roots meet the upper back and the head is visible beside the near wing. The first edit was rejected because it retained ambiguous anatomy. The selected coherent painting was registered once at native size, explicitly segmented with no unassigned visible pixels, and skinned with source-space shared fields.
- **Lightning Wisp:** crown, tail and side arcs move relative to the core in the same breathing phase. Existing root blends retain attachment; the core aperture remains rigid.

All changes live in `experiments/cutouts/<character>/feedback_v02/`, seeded directly from production. Old builders were read only as recipe references. The accepted front Vaeloryx paint remains unchanged. Generated rear source, exact prompt, registration, ownership and skin recipes are retained in that case.

## Verification status

Five structural case validations pass. Iskaldra, Zekarion, Noctyrax and Lightning Wisp have passed full native Metal case captures at 1920×1080/100%, including rigid/support geometry, complete canvas bounds, and pixel-identical editable-scene save/reload. Both full idle cycles and peak board frames were visually inspected before promoting their motion/layouts. Noctyrax and Wisp also pass `validate --protect art`; all their baseline paint and layouts remain identical.

Evidence currently retained outside the repository:

- `/private/tmp/iskaldra-feedback-iteration1/`
- `/private/tmp/zekarion-feedback-iteration1/`
- `/private/tmp/noctyrax-feedback-iteration1/`
- `/private/tmp/lightning_wisp-feedback-iteration1/`

Each contains complete native pose/board sequences, saved scenes, and front/rear idle contact sheets. Iskaldra, Zekarion and Noctyrax also have decoded timed reels. Their first walk studies used old authoring durations; the cases now use the current production .60/.76/.68-second walk cycles. No runtime cadence changed. Final toolkit renders must use these corrected values. Wisp's capture already uses its .39-second production walk cycle.

Vaeloryx iteration 1 exposed incorrect pixel ownership at the far wing tip and tail tip. The explicit ownership recipe was corrected at source; `/private/tmp/vaeloryx-feedback-iteration2/` passes numerical/canvas checks and pixel-identical reload, and the front/rear idle cycles, sampled complete action cycles, maximum Pull bend and rear board peak were inspected before promotion. This accepted pass removes the detached fragments. The rejected native pass is not accepted proof. All five development studies have timed reels that decode fully. Explicit Vaeloryx mouth landmarks align the new spell origin with the front snout and corrected rear head.

Final case metadata now matches the concurrent presentation choreography: 1.1-second area effects, .8-second utility, .42 physical contact, and held breath release/contact at playback .30/.52. Noctyrax Eclipse has both a 1.1-second area and .8-second summon use; its authoring reel records the area use. Initial development action reels predate this timing update and are geometry witnesses, not the final timing proof.

Focused Iskaldra, Vaeloryx, Noctyrax and Lightning Wisp runtime suites pass. Zekarion's obsolete expectation that generic AoE cannot animate was replaced with the actual Overload-charge contract; its corrected standalone rerun passes in `dragon-boss-encounters-milestone-rewards-1790533835937684000-30144`. The cutout worker read that Godot log after the reward worker's lease run.

The existing production-only roster PCK build passes. Every packed renderer (19 distinct cutouts plus 13 guardian variants) loads both rigs, paints and unique textures and samples four directions/hit/death on the unmodified official macOS Godot 4.6.1 release template with `editor=false`. No experiments, tools, legacy tree or imported asset cache is present. The installed template disables `--main-pack`; the accepted smoke uses its standard same-basename adjacent PCK lookup from `/private/tmp/dragon-cutout-feedback-pack/`. That packaging test is not a full platform export or Windows certification.

Live integration is accepted in `output/dragon-revision/presentation-feedback-03.json`: the native Metal/Mobile probe passed 167 images at 1920×1080/100%, with 133 recorded witnesses including 87 semantic prepare/release/impact stages, legal front/rear idle snapshots and actual reduced-motion multi-action Pass playback. See `playtest/dragon_presentation_feedback_notes.md` for inspected evidence and the later geometry/legacy-warning addenda. These production-scene witnesses supersede the earlier pending live-idle status; they do not replace the toolkit's complete-cycle and editable-scene receipts.

The first complete frozen-source batch, `/private/tmp/dragon-cutout-final-v1`, completed all 3,696 timed board samples and passed all seven final `verify-render` calls. Visual inspection nevertheless rejected three cases, so this set remains development evidence. Independent Iskaldra, Zekarion and Wisp full-cycle acceptance is recorded in [the four-rig review](dragon_four_rig_final_cutout_review_20260927.md); Noctyrax acceptance is in [its separate review](dragon_noctyrax_final_cutout_review_20260927.md). The repairs below are now closed by the final-v2 current-source receipts recorded at the end of this note.

Vaeloryx front idle frame 11 opened the neck/torso cut (pixel 250,246 became transparent), and rear Pull frame 11 opened shoulder/tail cuts. The front neck field was moving the painted contact edge independently of its rigid torso. The rear curved tail's later projection bands incorrectly reached back into its proximal attachment. `feedback_v02/repair_attachments.py` now retains a body-owned neck collar, gates tail influences in chain order, and puts the torso through the same mesh path. It preserves all motion and original part PNG bytes. The focused `/private/tmp/vaeloryx-attachment-fix-01` capture passed 480 frames, all roundtrips and integrity checks, and the standalone production rig suite passed in run `dragon-boss-encounters-milestone-rewards-1790540931827460000-39253`. Inspection closed the front gap but still found one-texel rear shoulder cracks at fractional translation. This first candidate remains rejected. No paint generation, whole-image bob, frozen limb or reduced action amplitude is used for this repair.

The second candidate adds a hidden body-bound two-source-pixel collar using the existing torso paint behind its complementary cut edges. `/private/tmp/vaeloryx-attachment-fix-02` completed with exit 0: 480 timed boards, all twelve clip reloads, encoded/full-decoded timing proof, and automatic verification of 2,155 inputs/1,279 outputs with no errors. The author inspected all twelve full-cycle sheets (368 unique poses), twelve original-scale peak poses, exact idle 23→24/walk 31→32 board boundaries, the two previously failing originals and four full 1920×1080 board witnesses. Neck, wing roots, tail and distal attachments remain continuous; front pixel (250,246) is now alpha 255, and rear pixels (265,246)/(270,247) are alpha 252. Derived review sheets remain outside immutable proof at `/private/tmp/vaeloryx-attachment-inspection-02`. The presentation worker independently accepted the same full-cycle/peak/former-gap scope, native boards and loop boundaries; its scoped receipt is recorded in [the four-rig review](dragon_four_rig_final_cutout_review_20260927.md).

`tests/vaeloryx_feedback_asset_probe.gd` then compared the current case to actual production in 196 native direct/mirrored poses, including fractional seam phases. The preparation run passed every pose comparison and found only the rear neutral bake stale: 545 pixels within source rectangle (121,115)–(161,144). Its exact native 255×255 bake replaced `rear/rest.png`, with matching `rest_source_sha256`; no paint was redrawn or resized. The strict rerun `output/dragon-revision/vael-feedback-assets-02.json` exited 0 (session 16930, namespace `dragon-vael-feedback-assets-02-1790546195006082000-42462-vaeloryx_feedback_asset-1`): all 196 comparisons equal, `rest_bake_preparation=false`, both shipped stills equal their native assembly, and all 198 images validated. Two mirrored former-failure poses and the rear bake were also visually inspected. The probe's source-file image-load warnings concern its development-only PNG comparison, not a production runtime fallback. The fresh standalone production suite exited 0/PASS in run `dragon-boss-encounters-milestone-rewards-1790546252116321000-42530`; transcript `/private/tmp/vael-feedback-candidate02-suite.log`. The deliberate rear-bake write follows candidate02's broad source receipt, so final seven-case recapture/verification must close that last source change.

The cutout worker independently inspected all twelve Vyraketh and all twelve Tharokh full-cycle sheets from v1. Vyraketh walk frame 29 exposed a separated reaching claw in both views. Tharokh walk and Claw exposed distal limb cuts; Breath frame 15 exposed a large neck/chest split and loose neck spikes. The presentation worker repaired their `feedback_seams_v03` cases. Vyraketh candidate01 is independently accepted after all 12 cycles/512 poses, peaks, former failures, native boards and loop boundaries. Tharokh candidate01 fixed the large cuts but retained loose painted islands, so it remains rejected; candidate02 assigns those islands to their proper head/limb/tail motion and is independently accepted after the corresponding complete 12-cycle/448-pose review. The exact receipts and review limits are in [the independent attachment review](dragon_vyr_thar_attachment_review_20260927.md).


## Coordinated handoff

All five case motion files are promoted to `scripts/<character>_cutout/motion.gd`. Layout changes are limited to Iskaldra (support weights), Zekarion (proximal hind weights), and Vaeloryx (front attachment meshes, corrected rear rig, both mouth landmarks). Vaeloryx rear part PNGs and baked rear rest are replaced. Noctyrax and Wisp production layout/paint bytes are unchanged. Existing suite idle assertions and the five owning runtime specifications describe the repaired contracts; semantic dispatch files belong to the presentation worker.

Native gameplay/tuning and the integrated regression have passed. All three rejected rigs now have accepted repair captures, independent cycle review, production promotion, strict production parity/rest checks and passing focused suites. Final-v2 captures and independent visual acceptance are complete as recorded below. Production/layout sources remain frozen for committed-HEAD verification. No files were staged or committed by the cutout worker.

Package binary/pack digests and matching-template confirmation: `/private/tmp/dragon-cutout-feedback-pack/export_proof.json`; build/runtime logs are in the same directory. Focused runtime suite logs are `/private/tmp/<character>-feedback-suite.log`.

## Exact final capture window

The prepared [seven-case batch and output index](dragon_cutout_final_receipts.md)
provide runnable render/verify commands in `dragon_cutout_final_receipts.sh`.
The wrapper completed the first full render/verify batch. Its numeric success
did not override the visual rejections recorded above. Root owns the next
lease/freeze decision, and retries must use a new output root.

After native tuning and failure-driven regression fixes settle, freeze all seven
cases (the five `feedback_v02` and two `feedback_seams_v03` cases) and the rendering input closure for the entire sequential
capture/verification window. The current toolkit hashes every case source plus
`project.godot`, `tools/cutout_workflow.py`, all `scripts/*.gd`,
`tools/cutout_pipeline/*.{gd,py}`, `scenes/*.tscn`, `data/*.json`,
`shaders/*.gdshader`, and `assets/*.{png,ttf,otf,json,res}` recursively. Audio,
task markdown and ordinary tests are not in this project closure. Any later
production/script/data/art change invalidates earlier case receipts, even if it
is unrelated to the creature being rendered.

For each of Iskaldra, Zekarion, Noctyrax, Lightning Wisp and Vaeloryx, run fresh
`tools/cutout_workflow.py render experiments/cutouts/<name>/feedback_v02
--output /private/tmp/<name>-feedback-final-v1 --task-id
 dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --backend metal`,
then `verify-render` for that case/output. Use fresh output versions on retries.
The render subcommand already uses the visual runner, verifies native geometry,
canvas bounds and every editable-scene pixel-equal roundtrip, encodes/fully decodes
timed clips, and binds both source and proof output digests. Reinspect full front
and rear idle cycles and maximum bend/action seams at board scale with the final
metadata timings. Re-run all seven `verify-render` calls after the last of the seven captures.
Expect roughly 15 minutes for these five, exclusive of inspection/any repair.

The presentation worker's Vyraketh and Tharokh `feedback_seams_v03` cases need the
same final render/verify treatment in this stable window after these five. Final
live action/idle/reduced-motion integration is accepted in the presentation probe
described above, including actual reduced Pass playback and legal player-position
idle assertions. The corrected Zekarion Overload routing suite and integrated
regression have both passed. Existing production-only release PCK
smoke is passed, but rebuild it if later art/rig/export changes affect the closure.


## Accepted final source closure

The sequential final-v2 batch completed in session 52299 with exit 0. All seven
receipts in `/private/tmp/dragon-cutout-final-v2` pass their individual capture
verification and the final unchanged-source check after the last capture. The
set contains 3,696 timed 1920×1080/100% board frames, 80 full clips and 80
pixel-identical editable-scene reloads; every encoded reel fully decodes.
`batch-summary.json` binds each case's exact input/output manifests.

Independent scoped reviewers compared all PNG/JPGs with the fully inspected
accepted predecessors. Every cycle, pose, native board, loop-boundary and rest
image is byte-identical. Each case differs only in its editor keyboard-focus
glow; all seven changed full-size images were inspected and accepted. Fresh
peak and native board witnesses also pass. This carries the earlier full-cycle
inspection explicitly and does not claim a second complete movie viewing.
See the [four-rig receipt](dragon_four_rig_final_cutout_review_20260927.md),
[Noctyrax receipt](dragon_noctyrax_final_cutout_review_20260927.md), and
[Vyraketh/Tharokh receipt](dragon_vyr_thar_attachment_review_20260927.md).

The earlier production-only PCK was an intermediate resource check. Its old
Vaeloryx/Vyraketh/Tharokh layouts and Vaeloryx rear rest were demonstrably stale
after the accepted repairs. The fresh package under
`/private/tmp/dragon-cutout-final-pack-v2` passes both build and official macOS
Godot 4.6.1 release-runtime smoke with `editor=false`: all 32 actors (19 distinct
cutouts and 13 guardian variants), both rigs and their paint resources load.
The final export receipt binds 2,297 packed production scripts/assets to current
source with zero mismatches. This supersedes the intermediate package for
current resource closure; it remains neither a full platform export nor Windows
certification. The independent attachment review records the exact run receipt.

No remaining visual repair is requested. Whole-task exact-HEAD peer signoff and
the final inspection-save check are recorded externally after commit so their
recording cannot change the reviewed source bytes. Publication remains separate.
