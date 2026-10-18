**Medium — floor validation can omit the feet.** [view_delivery.py:101](/private/tmp/labyrinth_codex/review/mq-06-57d2abd81/spec/art_identity/maquettes/blender/view_delivery.py:101) validates only supplied contact rows; [floor_contact.py:158](/private/tmp/labyrinth_codex/review/mq-06-57d2abd81/spec/art_identity/maquettes/blender/floor_contact.py:158) also accepts an empty set.

Reproduction: delete `ankle_far` from the rear native report, or retain only `hem_min`/`hem_max`. Both mutations survived rear sealing, root sealing, and strict delivery validation. Require the complete expected ankle/hem/prop contact inventory, reject empty sets, and add omission tests that reseal certificates.

Mutation results:

- **Caught:** ankle lifted 0.18 m; mirrored front substituted for rear; front and rear joints shifted 0.03 px with refreshed checksums.
- **Survived:** missing far ankle; all foot/prop rows omitted; empty helper input.

Other checks passed: all 21 front files and front joints unchanged; exact 180° rotation with matching camera direction/scale; all 18 rear PNGs have ≥8 px margins; fixed IoU policy restricted to Seer; other figures unchanged; curation **4,919,950 bytes**. No GDScript changes introduce Windows typed-array hazards.

Verification: 109 focused tests passed (2 skipped), 111 art-gate tests passed, and curation validation passed. Full-suite execution was stopped before unrelated tests could invoke Godot under other task IDs. All mutations were restored; checkout is clean.

CHANGES REQUESTED