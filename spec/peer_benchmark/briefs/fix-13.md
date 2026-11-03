# fix-13 — Historical maquette preservation tests ignore new figures

## Header
- `tests/test_mq11_accessories.py` checks the mq-11 baseline through
  `spec/art_identity/maquettes/hollow_mimic/owner_review/preservation.py` `check()`. Its `current_inputs()` scans
  every figure's `delivery/` tree, so any **new** figure's delivery counts as a protected change.
  - Both pending maquettes break it: mq-15 (the Gaoler, on `codex/mq-15`) and mq-14 (the Lancer, on `codex/rr-37`).
  - Errors: `test_before_iou_and_every_existing_delivery_remain_byte_identical` and
    `test_unresolved_status_uses_test_owned_design_files`.
  - Failures: `test_todos_stop_the_whole_batch_before_writes_or_native_submission` for `hollow_mimic` and
    `slag_mortar`, because the preservation error is raised before the TODO check.
  - Reproduction: `/private/tmp/mq15-cd510ab7b-preservation-reproduction.json`.
- mq-15 already fixed the same problem in `tests/test_mq12_successor.py` (commit cd510ab7b on `codex/mq-15`) by
  scoping the test's inputs to the pinned inventory: the figures and delivery trees the baseline pins. Additions
  inside a pinned tree stay caught. Use that same pattern.
- `preservation.py` is hash-pinned by the mq-11 proof records and `tests/mq11_preservation.py`: **don't edit it**.
  Scope in the tests only.
- Base `codex/peer-benchmark` (71afb7c06). Risk tier: low. Owned: `tests/test_mq11_accessories.py`, and any other
  historical maquette test that scans all delivery trees (find them; report each one), plus their tests.

## Change
1. Scope these tests to the pinned inventory. Figures and delivery trees not in the baseline are ignored; a new path
   inside a pinned delivery tree is still a failure.
2. Add a regression: inject a new figure's delivery file, which must pass; inject a new file inside a pinned tree,
   which must fail.
3. Prove it against both pending deliveries without merging them. Overlay mq-15's `chainbound_gaoler/delivery/`
   (from `codex/mq-15`) and mq-14's `frostglass_lancer/delivery/` (from `codex/rr-37`) in a temporary checkout, and
   run the scoped tests green against each.

## Proof
- `python3 -B -m unittest tests.test_mq11_accessories` green on the base and with each overlay.
- The mutations: remove the scoping, which must fail with an overlay; drop the pinned-tree addition check, which
  must fail.
- Focused tests only.

## Out of scope
- The preservation module, any proof record, and any maquette.
