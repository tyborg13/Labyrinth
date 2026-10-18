Two Medium proof-validation defects prevent signoff.

1. **Medium — curation accepts stale or failed tube proof.** [curate.py:22](/private/tmp/labyrinth_codex/review/mq-07-70ac9e5ef/spec/art_identity/maquettes/arc_thrall/r2/curate.py:22) checks selected summaries without validating the receipt’s spec hash or required tube gates. In separate temporary copies, setting `gates.spec_hash` to zeros or setting both `native_tube_entry_passed` and `tube_geometry.passed` false still produced `COMMIT_CURATION: PASS` and deleted native evidence. **Fix:** bind gates to the current spec/capture and require every mandatory tube, floor, fit and framing gate before deletion; add stale/missing/false receipt tests.

2. **Medium — resealing permits missing socket proof.** [delivery_validation.py:22](/private/tmp/labyrinth_codex/review/mq-07-70ac9e5ef/spec/art_identity/maquettes/blender/delivery_validation.py:22) never requires `native_socket_tucks`. Removing that field from build/capture checks, plus all socket details, still lets `seal_delivery()` and `validate_delivery()` succeed against the unchanged Thrall spec. **Fix:** require the socket check whenever `base.socket_tucks` exists and test omission before resealing.

3. **Low — merged builder wiring lacks regression coverage.** Removing the procedural branch, native repose call, or socket-tuck call each survived 67 relevant Python tests. Disabling contract socket validation or foot-exception rejection also survived. **Fix:** add mocked builder-order/dispatch tests and invalid-contract fixtures.

The delivered geometry otherwise passed review:

- Shoulder difference: **41.7 px**, matching the rule.
- Tube: **67.92 px** diameter, **−8 px** mouth offset, **12 px** band height, **4 px** raise, **23.8 px** dome; arm entry visible in both captures; removed labels absent.
- Far ankle planted without exception; exact turn, pan-only framing, ≥8 px margins and coverage passed.
- Recomputed IoU: front **0.70810**; rear **0.70477 dynamic / 0.69214 fixed**.
- Curation: **5,903,943 bytes**. Baselines are byte-identical to the base. Other deliveries match the incoming director branch.
- No mq-07 GDScript, Windows typed-array issue, unexplained tunables or stray files found.

Verification: **92 focused tests**, **86 restored-state tests**, and **111 art-identity tests** passed. Reviewed the committed **892-test full-suite PASS** receipt; did not rerun Blender or Godot.

Code mutations: **2 caught** (plant correction removed; mouth capped), **5 survived** as listed above. [Experiment results](/tmp/mq07-review-experiments.log) and [additional reproductions](/tmp/mq07-review-extra.log). Every tracked mutation was restored; checkout is clean.

CHANGES REQUESTED