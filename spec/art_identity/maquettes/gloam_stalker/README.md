# gloam_stalker — mq-04 curated maquette

Round 4: separately owned rigid back carapace, native thigh/foot fitting, attached single-piece crescent claws, and source-measured tattered front/back cloak panels. Both cloth panels and the carapace remain in one model turned 180 degrees.

`measurements.json` is the canonical build specification and measured input. It records the protected identity references, their SHA-256 values, source contours, part labels and native solver settings. `spec_native.json` is generated compiler output: it is **not tracked** and is regenerated inside the clean build tree. The builder does not need a pre-existing generated specification.

`COMMIT_MANIFEST.txt` is the complete list to track in this figure tree. `delivery/` contains native 1024 front/rear clays, part maps, unoccluded part solos, joints, capture manifests and compact native proof. `discarded_proof_sha256.json` records the exact hashes and byte lengths of deleted historical builds, caches, replay copies, candidates and old proof. No saved Blender model is required as an input.

Feedback 5: staging copies native PNG bytes unchanged. Regeneration canonicalises temporary copies of both front/rear clays and part maps; it never rewrites delivery PNGs. Existing round-4 PNG files are retained unchanged. Delivery verification requires passing build, capture, facing, collision and ownership reports, with their exact file hashes sealed into the matching cold-build proof. Native source-file hashes remain in provenance.

From the worktree root, regenerate from an empty, input-only project:

```sh
python3 -B -m spec.art_identity.maquettes.blender.regenerate_delivery spec/art_identity/maquettes/gloam_stalker --out spec/art_identity/maquettes/gloam_stalker/regenerated --verify --preview --discard-build
```

Omit `--preview` to regenerate all solos and maps. Every Blender invocation goes through `bridge_client.py`, with a 900 s execution budget and the bridge's separate 120 s start deadline. The approved external CC0 base bundle is the binary dependency named in `blender/contract.py`; its hash is recorded by regeneration. Cloth uses the native Blender solver and the Lancer collision margins. No Godot/GDScript or windowed proof is involved.

The current design-owner gates are front IoU >= 0.70 and rear >= 0.65 (feedback 2). Per-part visible/solo pixel coverage is in the shared review CSV; every label must have genuine part-colour pixels or a recorded occlusion. Review sheets compare all four clays with the protected Lancer r3 at the same 2.4 m orthographic scale, copying native 1024 cells without rescaling.

Shared review: `../gale_herald/delivery/review/fit_table.md`, `fit_overlay_contact_sheet.png` and `per_part_coverage.csv`. The same-scale five-figure clay comparison is `../arc_thrall/delivery/review/clay_comparison_lancer_r3.png`. Approved Lancer comparison inputs are retained byte-for-byte in `../gloam_stalker/delivery/reference/lancer_r3/`.

Fresh feedback-5 regeneration: `delivery/regeneration.json` compares all four clay/map images and validates native build/capture/facing/collision/ownership against the retained cold proof. Clean input hashes, native discarded-build hashes and bridge log are shared at `../gale_herald/delivery/validation/feedback5_regeneration/gloam_stalker/`.
