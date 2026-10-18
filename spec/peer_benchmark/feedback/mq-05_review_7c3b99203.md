Four Medium findings prevent signoff:

1. **Failed/stale fit reports are accepted.** [delivery_validation.py:73](/private/tmp/labyrinth_codex/review/mq-05-7c3b99203/spec/art_identity/maquettes/blender/delivery_validation.py:73) excludes `fit_report.json`. Across all three figures, setting its fit to failed/IoU zero or replacing its spec hash still passes delivery validation and curation. **Fix:** validate and bind the final fit report, or recompute fit during final verification. [Reproduction script](/private/tmp/mq-05-review-audit.py).

2. **The Tick’s far-third toe misses the approved footprint.** The path at [measurements.json:1839](/private/tmp/labyrinth_codex/review/mq-05-7c3b99203/spec/art_identity/maquettes/ember_tick/measurements.json:1839) places its rear contact at approximately `(170.76, 242.97)` after delivery registration—**14.39 source pixels from the nearest painted silhouette pixel**. The delivered part map confirms that toe exists there. Non-coplanarity does not explain this footprint mismatch. **Fix:** reconcile the distal measurement/path with the approved painting and protected joint contract; add per-foot projection checks. All eight knee joins coincide, but contact heights span **0.110–0.547 m**, so flat-ground support remains unproved.

3. **Disabled modelling modifiers pass the surface gate.** [sculpted_mass.py:181](/private/tmp/labyrinth_codex/review/mq-05-7c3b99203/spec/art_identity/maquettes/blender/sculpted_mass.py:181) checks modifier presence/settings without checking whether they are enabled. Portable fixtures disabling subdivision, displacement, bevel, or fracture each return `True`; [build.py:82](/private/tmp/labyrinth_codex/review/mq-05-7c3b99203/spec/art_identity/maquettes/blender/build.py:82) freezes evaluated geometry. **Fix:** require active evaluation settings and test disabled-modifier rejection.

4. **Lancer regeneration proof is missing.** Four batch-A regeneration comparisons are retained, but the [Lancer native replay test is skipped](/private/tmp/labyrinth_codex/review/mq-05-7c3b99203/spec/art_identity/maquettes/burrow_grub/delivery/validation/python/maquette.log:20). **Fix:** retain a current-builder Lancer regeneration comparing both clays and part maps, with input hashes.

Mutation results:

| Exercise | Caught/rejected | Survived/accepted |
|---|---:|---:|
| Existing guard mutations | 8 | 0 |
| New required-check removals | 3 | 2 |
| False/missing native-check probes | 48 | 0 |
| Failed/stale fit and disabled-modifier probes | 0 | 10 |

The two surviving guard removals were `native_contacts` and `native_sculpted_sections`.

Verification: **97 Blender/delivery tests and 111 art-identity tests passed**. All three fit reports recomputed identically; curation passes at **3.36/5.21/4.76 MB**. No typed-array violation or stray-file issue found. The checkout is clean.

Fresh Blender regeneration was refused by the bridge’s script allowlist. The broader maquette rerun was interrupted after detecting fixed internal `rr-*` runner IDs; no complete rerun is claimed.

CHANGES REQUESTED