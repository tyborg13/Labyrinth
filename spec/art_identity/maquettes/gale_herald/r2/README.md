# gale_herald — mq-12 feedback 1

The accepted round-0 pose is preserved exactly. The canonical recipe and `../delivery/` now contain the sealed shoulder revision.

1. Both shoulders are level in body space and meet the front projection rule. All limb lengths, spine/neck bend, near side, mask/head cover, legs and horn are preserved. Far shoulder garment attachments follow the shoulder delta with a source-bounded blend. Herald banners use their actual native pinned roots; the front waist-pinned tabard lies wholly on the protected near side and stays fixed, while the far rear tabard top follows the shoulder. Gloam’s single `head` mesh includes a lower shoulder-cowl skirt: only far skirt faces below the native skull boundary move; the head cover and opening stay exactly fixed.
2. Every mq-04 label name and colour is unchanged.
3. Shoulder, facing, collision, ownership, exact native determinism, true-turn in both views, fit, fresh regeneration and hash-bound delivery gates pass. See `review/mq12_gates.json`, `review/feedback1_collision.json` and `validation/native/preservation.json`.

| View | Original IoU | Feedback 1 IoU | Minimum |
|---|---:|---:|---:|
| front | 0.735791380 | 0.731448464 | 0.7 |
| rear | 0.680294454 | 0.677904215 | 0.65 |

Open `review/mq12_shoulders.html` for the native 1024 sheet: old front clay / new front clay / new front map, then rear; shoulder joints marked. `review/mq12_joint_table.md` gives shoulders, far elbow and hand before/after. Gloam additionally retains `review/gloam_front_per_part.md` and its hash-bound JSON. Unoccluded native part masks establish the changed regions; registered coverage uses whole painting alpha because no painting part segmentation was supplied.

Fresh input-only regeneration matches both clay/map pixels and unrounded geometry. Three native builds (cold, shared-cache replay, independent cold) agree exactly. The eight other measured figure deliveries and compiled specifications, plus the Lancer source, are bound by `../../gale_herald/r2/validation/scope.json`.

All generated blends, caches, duplicate exports, superseded proof and clean input trees are hashed in `../discarded_proof_sha256.json` before removal. `../COMMIT_MANIFEST.txt` lists every retained file; the per-figure limit is 6,000,000 bytes.

Proof uses the director’s bridge only. For either figure run these operations in order (substitute its id):

```sh
python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gale_herald build --feedback1
python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gale_herald capture --feedback1
python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gale_herald regenerate --feedback1
python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gale_herald proof --feedback1
```

No Godot, windowed probe or inspection fixture applies to this offline Blender-only change. The director owns inspection, full suites, peer review, commits and publication. Changes remain uncommitted.

Chosen defaults are recorded in `validation/chosen_defaults.json`; no player-facing design values were chosen. No unresolved TODO_DESIGN placeholders.

`review/feedback1_occlusions.json` records native occlusion certificates under the existing mq-04 rule. Herald rear `upper_far` has a genuine nonempty solo and all 13,762 pixels are covered by `cape_far`. Source occlusion values are unchanged.
