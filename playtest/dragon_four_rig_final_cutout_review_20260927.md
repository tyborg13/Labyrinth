# Four-rig final cutout inspection — 2026-09-27

Reviewer: `boss_fun_review`, independently inspecting the cutout worker's
Iskaldra, Zekarion, Lightning Wisp and Vaeloryx rigs. This reviewer did not
implement those rigs. Noctyrax is covered by the root coordinator's separate
review. This is not independent acceptance of this reviewer's own shared
presentation work or Tharokh changes, and is not a branch-wide signoff.

## Verdict on final-v1

Accept the inspected Iskaldra, Zekarion and Lightning Wisp geometry and sampled
cycles. **Request changes for Vaeloryx:** moving neck/shoulder boundaries open
transparent seams. Root independently confirmed both defects. Preserve this
receipt as iteration evidence; repaired Vaeloryx needs a fresh native render
and inspection. Any production repair also requires renewed shared-source
verification before all-seven closure.

## Receipt and inspection coverage

Native receipts are under `/private/tmp/dragon-cutout-final-v1/<rig>/`;
compact render reports are in its `logs/<rig>-render.json`. All four reports
record `ok: true`, 1920×1080, UI scale 1.0 and no verification errors. A
structural/hash pass does not establish visual acceptance: Vaeloryx's report
passed despite the visible defects below.

| Rig | Facing/clip cycles inspected | First-cycle pose samples | Timed board samples in receipt | Bound inputs / outputs |
| --- | ---: | ---: | ---: | ---: |
| Iskaldra | 12 | 432 | 560 | 2162 / 1487 |
| Zekarion | 12 | 368 | 480 | 2162 / 1279 |
| Lightning Wisp | 8 | 240 | 336 | 2129 / 863 |
| Vaeloryx | 12 | 368 | 480 | 2154 / 1279 |

The first-cycle count means one recorded sample at each authored phase, not
a claim that every image is pixel-distinct. Idle and walk repeat twice in the
timed board sequences. Every first-cycle pose was visually inspected using
the complete contact sheets in
`/private/tmp/dragon-cutout-final-inspection-v1/<rig>/`. These derived sheets
are outside the immutable receipt. Original 512×512 pose PNGs at the largest
visible-change phase of every clip were also inspected. A pixel-difference
ranking selected those supplemental phases; it was not used as a visual pass
criterion.

Native-resolution board crops around each idle/walk loop boundary were
inspected separately: frame 0, the last first-cycle frame, the first repeated
frame, and the following frame, for both facings. The derived boundary sheets
and exact peak-file lists are in
`/private/tmp/dragon-cutout-final-independent-inspection/<rig>/loops.png` and
`peaks.json`. Wisp movement leaves the generic crop, so its complete native
front/rear board frames 23 and 24 were additionally inspected. No inspection
assets were written inside the proof directories.

## Iskaldra — accepted geometry

Both facings: idle 24, walk 40, talon 40, lance 40, storm 40 and mantle 32
first-cycle samples. Original peak pose indices, in that clip order:

- Front: 12, 29, 29, 10, 19, 9.
- Rear: 12, 31, 30, 10, 19, 9.

Original native board PNGs inspected: `front_talon_0020.png`,
`rear_walk_0020.png`, `front_idle_0012.png`, `rear_idle_0012.png`,
`front_storm_0020.png` and `rear_lance_0020.png`. Front/rear rest PNGs were also
inspected, but those smaller files are not counted as native board witnesses.
Loop boundaries were idle 23→24 and walk 39→40 in both facings.

No actionable separation, clipped wing/tail, disconnected attacking limb or
loop snap was visible. Rear wing, neck, back and tail remain connected through
the casts. Grounded idle supports remain registered while the upper body
moves. The recorded walk support drift below 0.00006 pixels corroborates the
inspection; it does not replace it.

## Zekarion — accepted geometry

Both facings: idle 24; walk, claw, breath, charge and call 32 samples each.
Original peak pose indices in that order:

- Front: 12, 8, 13, 10, 16, 16.
- Rear: 12, 8, 14, 10, 16, 10.

Original native board PNGs inspected: `front_idle_0012.png`,
`rear_idle_0012.png`, `front_charge_0016.png` and `rear_claw_0016.png`.
Loop boundaries were idle 23→24 and walk 31→32 in both facings.

No actionable segmentation gap, detached limb, clipping or loop snap was
visible. Charge and Call preserve the wing roots and the gold edge follows
the articulated parts coherently. The stronger walk-leg extension remains
connected to the body.

## Lightning Wisp — accepted geometry

Both facings: idle/walk 24, attack/cast 36 samples. Original peak pose indices
in that order were 12, 11, 15 and 13 for each facing.

Original native board images inspected: front and rear `walk/board_0023.jpg`
and `walk/board_0024.jpg`, plus `front_cast_0018.png`,
`front_idle_0012.png`, `rear_idle_0012.png` and `rear_attack_0018.png`.
Idle and walk loop boundaries were 23→24 for both facings.

The core and lightning outline remain coherent through the attack lean,
casting swell and repeated movement. No broken core, detached bolt or
stretching artifact was visible. This is a floating actor; this review does
not claim grounded foot behavior for it.

## Vaeloryx — request changes

Both facings: idle 24, walk/dive 32, gale/pull 36, guard 24 samples.
Original peak pose indices, in that order:

- Front: 11, 13, 13, 14, 9, 7.
- Rear: 12, 13, 14, 14, 11, 7.

Original native board images inspected: `front_idle_0012.png`,
`rear_idle_0012.png`, `rear_pull_0018.png`, `rear_pull/board_0011.jpg`,
`front_dive_0016.png` and `rear_gale_0018.png`. Loop boundaries were idle
23→24 and walk 31→32. The sampled loop transition itself has no abrupt pose
reset; this does not excuse the within-cycle seams.

Two actionable defects remain in this receipt:

1. **Front idle neck seam.** Compare `front_idle/pose_0000.png` with
   `front_idle/pose_0011.png` (phase 0.4583). The latter opens a thin dark cut
   across the lower neck/chest around source-canvas x225–260, y244–248.
   It is also visible in the original `front_idle_0012.png` 1× source canvas.
   At source pixel (250, 246), rest alpha is 255 and pose 11 alpha is 0:
   the opening is transparent, rather than a painted anatomical line.
2. **Rear Pull shoulder split.** Compare `rear_pull/pose_0000.png` with
   `rear_pull/pose_0011.png` (phase 0.5565). An angular open boundary crosses
   the shoulder/torso around x247–279, y244–266. The complete native frame
   `rear_pull/board_0011.jpg` reproduces it. Pixels (265, 246) and (270, 247)
   have alpha 252 at rest and 0 at the peak. A similar seam is visible in
   the rear Gale source canvas.

Repair the overlap/mesh ownership through actual articulation; freezing the
affected part would remove the required motion. Reinspect every corrected
front/rear cycle, the exact failing phases, source-size and native board
views, and repeated idle/walk boundaries after a fresh render. No production
repair was made by this reviewer.

## Evidence identity and limits

SHA-256 of each inspected `proof_sha256.json`:

- Iskaldra: `aee4d3c80f6f454e476a82ccc63e7e4e7c971d259004fdb4882140764b7a5b66`
- Zekarion: `334391d824face61ffd252d4aac905be43d13b6b20a1fd9a3f414fe9344d7701`
- Lightning Wisp: `f24e2f37fd158e30de7ca8c2f238d248b74cf52cd15c7cc8c9ac090605cc5f1b`
- Vaeloryx: `37c5d641512fd7bc1b925e3435c28acb0f6d05267f7c567fb9c650e8df7bc9a6`

This review covers complete sampled pose sequences, selected original peak
PNGs and native board witnesses. It does not claim an additional real-time
viewing of all encoded movies or independent testing of attack dispatch,
elemental effects, reduced motion, input devices or combat balance. Those
have separate presentation and native-game receipts. The three accepted
geometries remain scoped to the recorded inputs; final shared-source
verification, corrected Vaeloryx acceptance, exact-HEAD peer review and user
inspection remain open.

## Vaeloryx candidate02 follow-up — accepted geometry

The rejected final-v1 findings above remain the historical failure evidence.
Fresh native receipt `/private/tmp/vaeloryx-attachment-fix-02` closes both
attachment defects. Its `proof_sha256.json` SHA-256 is
`0b91998f6d9e7fbbac3c0eed83b052f96cc46d740f219370618396a1fffff7fa`.
The capture contains 480 timed board frames and 368 first-cycle pose samples
across all twelve clips. The toolkit reports no validation/roundtrip errors.

I independently inspected every first-cycle pose through the twelve common-
crop filmstrips, then original 512×512 peak PNGs. Front peak indices in
idle/walk/dive/gale/pull/guard order were 12, 13, 13, 14, 9, 7; rear indices
were 12, 13, 14, 14, 8, 7. I also reopened the exact former failure frames
`front_idle/pose_0011.png` and `rear_pull/pose_0011.png`. The front lower neck
stays joined to the chest; the rear shoulder and tail root remain continuous
during Pull and Gale. Wing, head, tail and leg articulation remains visible.
No remaining actionable attachment gap, detached fragment or clipping was
visible in this scope.

Native 1920×1080 board checks included `front_idle_0012.png`,
`rear_idle/board_0006.jpg`, `rear_pull/board_0011.jpg`,
`front_dive_0016.png` and `rear_gale_0018.png`. Common native board crops also
cover idle 23→24 and walk 31→32 in both facings, with their neighboring
frames. These loops have no abrupt attachment or pose reset. Additional
rear idle source frames 6 and 18 retain the painted feather silhouette;
they do not show a detached anatomical part at native board scale.

The separate production/case receipt `output/dragon-revision/vael-feedback-assets-02.json`
records 196 pixel-identical frame pairs, `rest_bake_preparation=false`, both
shipped rest matches true and no errors. I checked those receipt fields.
The exact native rear rest bake was promoted after the candidate capture,
so final shared-source verification must bind that expected bake change.
This accepts the repaired Vaeloryx geometry only; it is not an independent
signoff on my Vyraketh/Tharokh work, the complete branch, or final source closure.

## Final-v2 independent carry and fresh inspection — accepted

Root's frozen seven-case batch writes `/private/tmp/dragon-cutout-final-v2`.
The comparison checks every relative PNG/JPG filename and SHA-256 byte value,
including missing and added files. The first three rigs use their inspected
final-v1 predecessor; Vaeloryx uses the accepted attachment-fix-02 predecessor.
Only identical cycle images carry the complete original visual inspection.
This is explicitly a carry plus bounded fresh inspection, not a claim to have
visually rewatched every identical cycle. Changed images are inspected afresh.

| Rig | Compared PNG/JPG files | Identical files | Changed/missing/added | Fresh spot checks |
| --- | ---: | ---: | --- | --- |
| Iskaldra | 1,465 | 1,464 | Only `keyboard_focus.png`; none missing/added | Rear Lance pose 10, rear Idle pose 12; native front Storm 20 and rear Walk 20 |
| Zekarion | 1,257 | 1,256 | Only `keyboard_focus.png`; none missing/added | Front Charge pose 16, rear Claw pose 14; native front Charge 16 and rear Idle 12 |
| Lightning Wisp | 845 | 844 | Only `keyboard_focus.png`; none missing/added | Front Cast pose 13, rear Attack pose 15; native front Cast 18 and rear Walk board 24 |
| Vaeloryx | 1,257 | 1,256 | Only `keyboard_focus.png`; none missing/added | Exact former front Idle/rear Pull pose 11 failures; native rear Pull board 11 and front Dive 16 |

All four changed focus screenshots were inspected alongside
their originals at 1920×1080. Differences are confined to the Play button's
animated focus glow: Iskaldra `(444,131)–(480,171)` and Zekarion
`(457,131)–(509,171)`, Wisp `(444,131)–(486,171)` and Vaeloryx
`(454,131)–(496,171)`. The focus remains visible and legible, and no rig pixels
changed. All first-cycle poses, timed boards, rest images and loop-boundary
frames for all four rigs are byte-identical. Fresh peaks and native boards have no
actionable attachment, clipping or support defect. Their scoped geometry
acceptance carries with the current-source verification below.

Read-only comparison records are `/private/tmp/dragon-final-v2-<rig>-compare.json`.
The inspected final-v2 `proof_sha256.json` file identities are:

- Iskaldra: `3767ae96c96b9d0622b7c2f1f99c1f3eee0b753616eea614792e7b9ab6e46a8f`
- Zekarion: `bc01a41b7d2f0b188cd82525d958379e6cb30f39fa47b265a567185b00bdf069`
- Lightning Wisp: `d0b057862488ce20cea9710690c2bddef905e151d0b007247e0b27016168ebcd`
- Vaeloryx: `22dbefb27cedac42b2368e4d28033bfcd214bc227b690687ea0d3eed19f36585`

After root's complete seven-case batch exited zero, I independently ran the
read-only `tools/cutout_workflow.py verify-render` command for each assigned
`experiments/cutouts/<rig>/feedback_v02` case against its final-v2 receipt. All
four exited zero with `ok: true` and `errors: []`:

| Rig | Current input hashes verified | Output hashes verified |
| --- | ---: | ---: |
| Iskaldra | 2,162 | 1,487 |
| Zekarion | 2,162 | 1,279 |
| Lightning Wisp | 2,129 | 863 |
| Vaeloryx | 2,155 | 1,279 |

**Scoped verdict: accept these four final-v2 rigs.** This binds the original
full-cycle visual inspections, complete image-byte comparisons, changed-focus
inspection and fresh source/board spot checks to the frozen current source.
No Vyraketh/Tharokh self-signoff, whole-branch signoff or publication approval
is implied. Exact-HEAD review and inspection-fixture reconciliation remain
the coordinator's separate completion gates.
