# Noctyrax final cutout inspection — 2026-09-27

Reviewer: root coordinator, reviewing the cutout worker's repaired Noctyrax rig.
This is scoped visual acceptance of the rig, not independent review of root's
combat changes or a branch-wide exact-HEAD signoff.

## Receipt and coverage

Final native Metal receipt: `/private/tmp/dragon-cutout-final-v1/noctyrax/`.
The render report records 608 authored board samples at 1920×1080 and UI scale
1.0, 2,153 bound inputs, 1,599 outputs, and no verification errors. The manifest
contains both facings of idle, walk, claw, breath, coil and eclipse. All twelve
recorded editable-scene reloads are pixel-identical; both saved `.tscn` files
exist. Structural validation passes with 22 joints, 17 parts and six meshes per
facing. Final all-seven current-source verification is owned by the batch.

Inspected every first-cycle pose in all twelve contact sheets under
`/private/tmp/dragon-cutout-final-inspection-v1/noctyrax/`: 32 idle poses and
40 poses for each other clip per facing. These are derived inspection sheets
outside the immutable receipt. Original 512×512 PNGs inspected separately:

- `rear_idle/pose_0016.png` and `front_idle/pose_0016.png`;
- `rear_claw/pose_0014.png`;
- `rear_breath/pose_0011.png` and `front_breath/pose_0011.png`;
- `rear_coil/pose_0011.png`;
- `rear_eclipse/pose_0020.png` and `front_eclipse/pose_0020.png`.

Inspected original 1920×1080 board witnesses `rear_idle_0016.png`,
`rear_claw/board_0014.jpg`, `rear_breath/board_0011.jpg`,
`front_eclipse/board_0020.jpg`, `front_walk/board_0000.jpg`,
`front_walk/board_0040.jpg`, `rear_walk/board_0040.jpg`, and
`rear_idle/board_0032.jpg`.

## Observations and loop checks

No actionable splitting was visible at the neck, torso, limb roots, tail or
wing roots over the inspected cycles. Grounded idle claws remain registered
while the body breathes. Walk limbs articulate coherently; claw reaches and
recovers, breath pitches the head, coil compresses and settles, and eclipse
raises the body and wings before returning. The silhouette remains readable
at native board scale. No canvas clipping was visible.

Second-cycle source-canvas pixels match exactly for both facings: idle frames
0/32 and 31/63, walk frames 0/40 and 39/79. Comparisons use the right-hand
source-canvas rectangle `(1328, 240, 1888, 880)` of the native JPGs, excluding
frame-number text. Whole-board walk images intentionally differ because the
study translates the actor across the board; that is not a pose-loop defect.
Both idle board regions also match across cycles. The full first-cycle sheets
include the samples on either side of each loop boundary.

The manifest reports zero idle support drift and no geometry errors. Walk's
maximum recorded support drift is below 0.00010 pixels; this corroborates,
but does not replace, the visual inspection. The encoding report records a
full decode PASS, 21.12 seconds of declared source timing and 21.1333 seconds
encoded, with each clip within one 60-fps frame. This review used complete
sampled sequences and inspected board witnesses; it does not claim an
additional real-time movie viewing or an input-device certification.

## Evidence identity and limits

- `render_manifest.json` SHA-256: `85c16e661b827df3b88b91733cf5554ece019635b9ce00f06877340b69bb5bca`
- `capture_input_sha256.json` SHA-256: `c5c12083336f6287ab39f153726d26266634e0abc37022c3cdf7e298ce8053c6`
- `proof_sha256.json` SHA-256: `95da78eecd0ae4cc01f5ae3881307e2638ecc778a3b08aa813b23020a261429a`

Verdict: accept this Noctyrax rig receipt within the stated scope. Production
attack routing, elemental effects and reduced motion have their separate
presentation receipts; actual fight behavior is covered by the Noct01 native
ledger. Final shared-source verification, exact-HEAD peer review and user
inspection remain separate gates.


## Final-v2 unchanged-cycle carry and fresh inspection

The new frozen-source native receipt is
`/private/tmp/dragon-cutout-final-v2/noctyrax/`. Compared the complete relative
PNG/JPG file sets and SHA-256 bytes against the accepted v1 predecessor: 1,577
images compared, 1,576 identical, no missing or added images. The only changed
image is `keyboard_focus.png`; its pixel difference is restricted to the Play
button's focus glow at `(450,131)–(508,171)`. Both original 1920×1080 images
were inspected. The ring remains clearly visible, and every character/board
pixel outside that glow is unchanged. This is capture timing, not a rig defect.

All cycle poses, timed boards and editable-scene roundtrip images therefore
carry the full-cycle inspection above. Freshly inspected final-v2 witnesses
are rear Idle pose16, rear Breath pose11, rear Idle lossless board16 and front
Eclipse native board20. Neck, torso, wing roots and limb attachments remain
continuous, the rear support contacts remain registered, and both facings are
readable at native board scale. No new defect or additional capture is requested.
This is an explicit carry of identical cycles plus bounded fresh inspection,
not a claim that the whole movie was watched again.

The new manifest records 608 authored samples, 12 clips, no geometry errors
and 12 editable-scene roundtrips. The native probe accepts Metal/Mobile at
1920×1080 and scale 1.0; the new encoding report gives full-decode PASS,
21.12 seconds authored and 21.1333 encoded.

- `render_manifest.json`: `85c16e661b827df3b88b91733cf5554ece019635b9ce00f06877340b69bb5bca`
- `capture_input_sha256.json`: `07e3a46fa994774f9bea575dff0040a4b91177f2f9af560eac164f6c8ef833dc`
- `proof_sha256.json`: `bd7b597841707248e9fda266cc022cfd816c88795d92603ebca7e2aa7968a668`

Scoped visual acceptance is complete. The full sequential batch exited0 in
session 52299, and all seven post-capture `verify-render` calls passed against
the unchanged source closure. Noctyrax reports 2,153 inputs/1,599 outputs and
no errors. Final-v2 is accepted within this review's independent rig scope;
committed-HEAD review remains the separate branch-wide gate.
