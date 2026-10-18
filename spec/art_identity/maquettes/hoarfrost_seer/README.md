# hoarfrost_seer — frozen front and planted rear (mq-06)

mq-06 feedback 5 accepts and stages the planted rear. The front's 21 delivery
files and front joints remain unchanged. `measurements.json` remains the frozen
front input; `delivery/view_sources.json` identifies the separate planted rear
recipe and its independently sealed native proof in `delivery/rear_native/`.
Rear acceptance uses the fixed original mq-04 registration: **0.7609076185 ≥
0.60**. Dynamic registration **0.2054038784** is retained as a diagnostic of the
different ground anchors. Other figures retain their existing method.

The [mq-06 completion report](rear_turn/feedback5/README.md) contains the final
file list, rear hashes, tests, floor/collision/coverage proof and exact native
reconstruction commands. The director-reviewed [rear sheet](rear_turn/feedback4/rear_sheet.png)
is retained unchanged. Use the per-view commands in that report for the current
delivery; the single-body regeneration command below describes mq-04 history.

## Historical mq-04 notes

Director feedback 4 accepts and freezes the r3 clay, including the dense staff cuff folds. No modeling changes in round 4.

`measurements.json` is the canonical build specification and measured input. It records the protected identity references, their SHA-256 values, source contours, part labels and native solver settings. `spec_native.json` is generated compiler output: it is **not tracked** and is regenerated inside the clean build tree. The builder does not need a pre-existing generated specification.

`COMMIT_MANIFEST.txt` is the complete list to track in this figure tree. `delivery/` contains native 1024 front/rear clays, part maps, unoccluded part solos, joints, capture manifests and compact native proof. `discarded_proof_sha256.json` records the exact hashes and byte lengths of deleted historical builds, caches, replay copies, candidates and old proof. No saved Blender model is required as an input.

Feedback 5: staging copies native PNG bytes unchanged. Regeneration canonicalises temporary copies of both front/rear clays and part maps; it never rewrites delivery PNGs. Existing round-4 PNG files are retained unchanged. Delivery verification requires passing build, capture, facing, collision and ownership reports, with their exact file hashes sealed into the matching cold-build proof. Native source-file hashes remain in provenance.

From the worktree root, regenerate from an empty, input-only project:

```sh
python3 -B -m spec.art_identity.maquettes.blender.regenerate_delivery spec/art_identity/maquettes/hoarfrost_seer --out spec/art_identity/maquettes/hoarfrost_seer/regenerated --verify --preview --discard-build
```

Omit `--preview` to regenerate all solos and maps. Every Blender invocation goes through `bridge_client.py`, with a 900 s execution budget and the bridge's separate 120 s start deadline. The approved external CC0 base bundle is the binary dependency named in `blender/contract.py`; its hash is recorded by regeneration. Cloth uses the native Blender solver and the Lancer collision margins. No Godot/GDScript or windowed proof is involved.

The current design-owner gates are front IoU >= 0.70 and rear >= 0.65 (feedback 2). Per-part visible/solo pixel coverage is in the shared review CSV; every label must have genuine part-colour pixels or a recorded occlusion. Review sheets compare all four clays with the protected Lancer r3 at the same 2.4 m orthographic scale, copying native 1024 cells without rescaling.

Shared review: `../gale_herald/delivery/review/fit_table.md`, `fit_overlay_contact_sheet.png` and `per_part_coverage.csv`. The same-scale five-figure clay comparison is `../arc_thrall/delivery/review/clay_comparison_lancer_r3.png`. Approved Lancer comparison inputs are retained byte-for-byte in `../gloam_stalker/delivery/reference/lancer_r3/`.

Original r3 PNG byte restoration is pending an original-file backup. The eight Seer/Thrall clay/map pixel streams exactly match the paint-over kit refs after green compositing; see `../gale_herald/delivery/validation/feedback5_pixels.json`. The recorded original r3 file hashes remain in `delivery/provenance.json`; no replacement encoding is presented as the original file.

Fresh feedback-5 regeneration: `delivery/regeneration.json` compares all four clay/map images and validates native build/capture/facing/collision/ownership against the retained cold proof. Clean input hashes, native discarded-build hashes and bridge log are shared at `../gale_herald/delivery/validation/feedback5_regeneration/hoarfrost_seer/`.
