# Independent Vyraketh / Tharokh attachment review — 2026-09-27

Reviewer: `cutout_repairs`; author: `boss_fun_review`. This is an independent review of the two `feedback_seams_v03` rig repairs. It is not signoff on the reviewer's own five rigs, the author's shared combat presentation, or the entire branch. No renderer was launched and no production source was edited by the reviewer during this review.

## Current verdict

- **Vyraketh final-v2: accepted for geometry and animation.** The former floating claws are attached. The accepted candidate01 cycles carry through byte-identical final animation outputs, with fresh spot review and current-source verification below.
- **Tharokh final-v2: accepted for geometry and animation.** The spikes and chips now follow their correct painted parts. The accepted candidate02 cycles carry through byte-identical final animation outputs; candidate01 remains rejected and preserved below. Production parity, current-source verification and the refreshed packaged-runtime smoke have passed.

## Vyraketh accepted evidence

Immutable capture: `/private/tmp/dragon-seam-repair/vyraketh-candidate01`; native run `dragon-boss-encounters-milestone-rew-1790546340800017000-42700-preview-1`, outer session 90115 exited 0. The manifest reports 656 timed board frames, 512 unique first-cycle poses across all 12 clips, no errors, and 12 pixel-identical editable-scene reloads. The automatic source/output verification reported 2,199 inputs and 1,743 outputs. `proof_sha256.json` file SHA-256: `d56fe3cfceaf7e46b902156b1803810800b5b77209af059c217deae2af713796`.

I inspected every front/rear Idle, Walk, Maw, Kindle, Crownfire and Cinderfall cycle sheet, all 12 unscaled maximum-difference original poses, and the exact Idle 31→32 and Walk 39→40 board boundaries. Former failure witnesses `front_walk/pose_0029.png` and `rear_walk/pose_0029.png` visibly reconnect the claws. Full 1920×1080 board witnesses inspected: both Walk frame 29, front Maw 20, rear Cinderfall 24, front Crownfire 24, rear Kindle 24, plus rear Walk 0 for the inherited paint-fleck check. No actionable attachment opening, clipping, or loop snap was observed.

The small orange fleck left of the rear tail at Walk 0 is also present in the rejected v1's rest-of-cycle source art; I compared the two original poses and the new full board. It is a tiny inherited painted fleck, not the repaired floating claw. This acceptance does not claim every isolated alpha pixel has been removed.

Derived inspection sheets live outside the immutable proof at `/private/tmp/dragon-seam-repair-independent-inspection/vyraketh`. The early native outputs used for sheet generation match all **1,721 PNG/JPG files** in the finished immutable proof byte-for-byte: `/private/tmp/vyr-candidate01-raw-final-equality.json`.

## Tharokh rejected candidate01 evidence

Immutable capture: `/private/tmp/dragon-seam-repair/tharokh-candidate01`; native run `dragon-boss-encounters-milestone-rew-1790546592746528000-43104-preview-1`. Its manifest reports 576 timed board frames, 448 unique first-cycle poses across all 12 clips, no renderer errors, and 12 pixel-identical editable-scene reloads. Numeric success does not override the visual rejection. `proof_sha256.json` file SHA-256: `ab2007aa0fdde348b528fdf1e2a1b2fd6f204c94eb30f32f58afaf76ef6d9daf`.

I inspected every front/rear Idle, Walk, Claw, Brace, Breath and Faultline cycle sheet, all 12 unscaled maximum-difference original poses, exact Idle 23→24 and Walk 39→40 board boundaries, and original former-failure poses. Full 1920×1080 board witnesses inspected: front/rear Breath 24, front Walk 29, rear Walk 10, front Claw 20, rear Faultline 20. The large front/rear neck openings and former wrist disconnections are improved; no new loop snap or canvas clipping was observed.

The remaining primary defect is explicit in `front_breath/pose_0015.png` and peak `pose_0025.png`: two spikes around source canvas `(235,182)` remain suspended above the lowered head. They are absent as detached fragments at rest and remain visible in the native board's front Breath 24. This is the same loose-spike class identified in v1, so candidate01 is not acceptable merely because its rear neck now closes.

Additional bounded ownership witnesses sent to the author: rear Walk 0 below the forearm near `(310,289)`, rear Walk 10 under the thigh near `(242,310)`, and front Walk 29 below the forearm near `(191,338)`. Small remnants are also visible under the front Claw. These need an ownership trace and a corrected full-cycle capture; this review does not assert a new mechanical cause for every tiny chip.

Derived inspection sheets live outside the immutable proof at `/private/tmp/dragon-seam-repair-independent-inspection/tharokh`. All **1,513 PNG/JPG files** used from early native output match the finished immutable proof byte-for-byte: `/private/tmp/thar-candidate01-raw-final-equality.json`.

## Tharokh accepted candidate02 evidence

Immutable capture: `/private/tmp/dragon-seam-repair/tharokh-candidate02`; native run `dragon-boss-encounters-milestone-rew-1790547598493228000-44220-preview-1`, outer session 33232 exited 0. It records 576 timed board frames, 448 unique first-cycle poses across all 12 clips, no errors, 12 pixel-identical editable-scene reloads, and verification of 2,184 inputs/1,535 outputs. `proof_sha256.json` file SHA-256: `cd80ea4ae64a52f3c997e1a17baa8e3fb90e9447cbaff813097cd48e4900ec70`.

The repair assigns the isolated crown-tip paint in `wing_far` to head motion and the traced limb/tail paint islands to their actual owners. The case's `attachment_repair.json` records exact source bounds and owners. All 48 original PNG bytes and the motion sampler remain unchanged.

I freshly inspected all twelve complete cycle sheets, all twelve original peak poses, exact Idle 23→24 and Walk 39→40 board boundaries, and the former original failure frames: front Breath 15/25, front Walk 29, rear Walk 0/10. Six full 1920×1080 boards at 100% UI scale were inspected: front/rear Breath 24, front Walk 29, rear Walk 10, front Claw 20 and rear Faultline 20. The reported loose crown tips and limb chips are now attached, and the larger neck/wrist fixes remain continuous. No actionable attachment split, clipping, or loop snap was observed. This is a visual acceptance at the captured scales, not a claim that all isolated antialias texels have been eliminated.

The derived sheets are outside immutable proof at `/private/tmp/dragon-seam-repair-independent-inspection/tharokh-candidate02`. All **1,513 PNG/JPG files** from the raw output used for review match the completed proof byte-for-byte: `/private/tmp/thar-candidate02-raw-final-equality.json`.

## Production closure

Preserve both rejected candidate01 proof and accepted candidate02 proof. The author's production promotion and strict parity/rest checks are now complete: four layouts promoted with paint/motion/rest PNGs unchanged; 392/392 native production/case poses and all four rest images equal in `output/dragon-revision/attachment-assets-01.json` (396 images), followed by focused Vyraketh/Tharokh runtime suite PASS. This review treats those as author-owned production checks. Root's final-v2 batch finished with frozen production. Earlier accepted cycle inspection is carried only for byte-identical native animation outputs, with fresh source-bound verification; every mismatching image was separately inspected below.

## Final-v2 carry and fresh spot review

Vyraketh final capture `/private/tmp/dragon-cutout-final-v2/vyraketh` passes automatic verification of 2,199 inputs/1,743 outputs, 656 timed frames, all 12 pixel-identical editable-scene reloads, and no manifest errors. Its `proof_sha256.json` file hash is `93d9a78cd989a3f108d3c4b8cf32890599a551fdf5366c90ee010fd91e4b67d2`.

Comparison with accepted candidate01 covered every **1,721 PNG/JPG**: **1,720 are byte-identical**, with no added/missing files. The only mismatch is `keyboard_focus.png`, whose 247 changed pixels are confined to the Play-button focus decoration at `(455,131)–(498,171)`. I inspected both full original screenshots: the focused control remains readable, the layout and rig remain correct, and the differing focus highlight is accepted. Comparison record: `/private/tmp/dragon-final-v2-vyraketh-equality.json`.

Every animation image is byte-identical to the independently inspected predecessor, so the complete 12-cycle/512-pose inspection above carries forward. I freshly inspected the final front/rear Walk 29 originals and the final front Maw 20 and rear Cinderfall 24 full native boards; the repaired claws remain attached and the new samples are accepted. This explicitly carries earlier full-cycle inspection rather than claiming it was newly repeated.

Tharokh final capture `/private/tmp/dragon-cutout-final-v2/tharokh` passes automatic verification of 2,184 inputs/1,535 outputs, 576 timed frames, all 12 pixel-identical editable-scene reloads, and no manifest errors. Its `proof_sha256.json` file hash is `37f7d85b63d12710975188707ee547ad38b280fc0ca493d056fe247043886679`. Every **1,513 PNG/JPG** was compared with accepted candidate02: **1,512 are byte-identical**, with no added/missing files. The sole mismatch is `keyboard_focus.png`: 60 changed Play-button focus-decoration pixels within `(458,131)–(494,171)`. Both full originals were inspected and accepted; the control, layout and puppet remain correct. Comparison record: `/private/tmp/dragon-final-v2-tharokh-equality.json`.

All Tharokh animation image bytes match the independently inspected candidate02, so the complete 12-cycle/448-pose acceptance carries forward. I freshly inspected final front Breath 15, front Walk 29 and rear Walk 10 originals, plus front Breath 24 and rear Claw 20 full native boards. The former spike/chip failures remain repaired, with no new actionable split or clipping. I also read all seven end-of-batch `logs/*-verify-final.json` files: each reports `ok:true` and `errors:[]`. This closes the scoped final rig review; exact-HEAD whole-branch signoff and user inspection remain root-owned gates.

## Packaged-runtime closure audit

The earlier `/private/tmp/dragon-cutout-feedback-pack` smoke predates the accepted rig promotion. This is proven from the existing PCK's directory digests, not just file dates: all six front/rear Vaeloryx, Vyraketh and Tharokh layout entries differ from current production, and Vaeloryx's rear `rest.png` differs. The Vyraketh/Tharokh rear rest entries are unchanged. Exact comparison: `/private/tmp/dragon-roster-pack-staleness.json`.

The test actually covers **32 actors: 19 distinct cutouts plus 13 guardian variants**. The existing runtime log has 32 per-actor PASS lines, matching `ACTORS` and `Guardian.ACTOR_IDS`; earlier 33/14 descriptions were documentation count errors. The owning notes/index are being reconciled by root.

After the seven-case batch exited, root explicitly granted the exclusive Godot lease for the prepared bounded command, `bash /private/tmp/dragon-cutout-final-pack-smoke.sh`. It completed in session **7564 with exit 0**, without any production edit or other test. Builder run `dragon-boss-encounters-milestone-rewards-1790549942052247000-46582` passed. Official export-runtime run `dragon-boss-encounters-milestone-rewards-1790549942914222000-46587` passed with `editor=false` and **all 32 actor PASS lines**. All **2,297 packed production script/asset digests match current source**, with no mismatches. The default 300-second watchdog was unchanged.

Fresh proof is `/private/tmp/dragon-cutout-final-pack-v2/export_proof.json`; exact packed-source SHA-256 bindings are `production_pack_sources.json` beside it. Build/runtime transcripts are `export_build.log` and `export_runtime.log`. The extracted binary matches the unmodified official macOS Godot 4.6.1 archive member, SHA-256 `aa1a4febbb87876717d6d2fc9b65ad0878696d1e676b64c1bb1c18775bb1f070`. The fresh package SHA-256 is `6b6bcea26e2f9f013cad1efb52865c6991236f3c9c137ac5bad600c6bb479b71`. The old stale package remains preserved. This is current package/resource closure on macOS, not a complete platform export or Windows certification. The reviewer explicitly returned the Godot lease to root after session 7564 exited; no reviewer-owned process remains active.
