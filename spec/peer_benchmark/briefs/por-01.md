# por-01 — Rebuild stale turn-order portraits from the shipped (post-density) art

## Header
- rr-01's peer review: `tools/build_turn_order_assets.gd --verify-only` fails for 17 enemy portraits because they are
  crops of pre-density-pass art, so the turn-order rail mixes old and new pixel density. The builder already defines
  each portrait's source and focus; this unit re-runs it so every builder-defined portrait is the exact crop of its
  shipped source.
- Base: `codex/peer-benchmark`. Owned files: the stale files under `assets/art/portraits/`,
  `tools/build_turn_order_assets.gd` (only bug fixes needed to rebuild), new `tests/turn_order_portraits_test.py` (or
  extend an existing portrait test), a contact sheet `tests/turn_order_portrait_contact.png`.
- Rules: do not change any focus point, source path or crop size in the builder; do not touch the art-03/art-04 portraits
  made by the static-facing crop pipeline (they are not builder entries); do not touch `tunnel_crawler.png` (already
  current). If a builder source no longer exists or is the wrong file, stop and list it as `TODO_DESIGN_PORTRAIT_<key>`.

## Change
1. Rebuild every builder portrait that fails `--verify-only`; leave passing ones byte-identical.
2. Add a test that runs the builder's verification for all keys (headless) so a future art change that forgets the
   portrait fails.
3. Contact sheet: for each rebuilt portrait, old | new at 2× nearest, labelled, one row per enemy.

## Proof
`godot --headless --script tools/build_turn_order_assets.gd -- --verify-only` → PASS (all); the new test; full suite.
Windowed: a turn-order clock capture with at least 5 rebuilt portraits visible (list the command; the director runs it).

## Out of scope
New crops/focus points, new portraits, art changes.
