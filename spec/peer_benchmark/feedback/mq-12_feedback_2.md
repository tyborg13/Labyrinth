# mq-12 — feedback 2 (Codex review of 55784c329: CHANGES REQUESTED)

Fix all three findings below. Keep the approved poses, garments and deliveries' look unchanged. Focused tests only;
the Blender bridge is running for this worktree.

## Review
Three findings prevent signoff:

1. **Blocking — required regression tests fail.** [test_mq09_forms.py:161](/private/tmp/labyrinth_codex/review/mq-12-55784c329/tests/test_mq09_forms.py:161) and line 176 produce nine failures because regeneration inventories differ from the eight changed builder files. Both tests pass when supplied with `HEAD~` builder bytes and inventory. **Fix:** reconcile the preservation checks with this opt-in change, retaining historical receipts and adding exact comparisons that protect other figures’ current compiled specs and deliveries.

2. **Medium — the garment motion gate accepts broken motion.** [shoulder_garments.py:115](/private/tmp/labyrinth_codex/review/mq-12-55784c329/spec/art_identity/maquettes/blender/shoulder_garments.py:115) checks only vertices selected by the computed zero-influence mask. Two executable mutations survived all 11 mq-12 tests and kept this gate passing:
   - Replace the movement at line 93 with `shifted = points.copy()`: the far attachment stays stationary.
   - Change the near-side protection at line 92 from `0` to `1`: protected near vertices move by 0.2 m.
   
   **Fix:** independently verify attachment displacement and protected-face positions, and exercise the actual application path in Python fixtures. Require both mutations to fail.

3. **Medium — committed deliveries fail curation verification.** [Herald COMMIT_MANIFEST.txt:94](/private/tmp/labyrinth_codex/review/mq-12-55784c329/spec/art_identity/maquettes/gale_herald/COMMIT_MANIFEST.txt:94) and [Gloam COMMIT_MANIFEST.txt:84](/private/tmp/labyrinth_codex/review/mq-12-55784c329/spec/art_identity/maquettes/gloam_stalker/COMMIT_MANIFEST.txt:84) each list ten absent build receipts/logs. The generic `build/` ignore rule explains their omission. **Fix:** track the intended proof files and verify both curated trees from committed contents.

Other mutation results: shoulder target shifted by 40 px **caught**; required motion gate removed **caught**; attachment-root hash binding removed **caught**; all **18** stale/failed-report mutations **caught**.

Verification: mq-12’s 11 tests pass. The 21 requested matching modules ran 369 cases: nine inventory failures, two Blender skips, and one existing import-path error that passed when rerun with `PYTHONPATH=tests`.

All eight other recipes compile identically to `HEAD~`; their 791 delivery files are unchanged. All 70 deleted files are archived proof/reports/logs/overlays with matching hashes; no source files were deleted. Both figures remain under 6 MB. No GDScript changed, so the Windows typed-array rule is inapplicable.

Current regeneration input hashes, capture hashes, IoUs and true-turn observations check out. Blender regeneration could not be rerun without the director’s bridge. The checkout is clean.

CHANGES REQUESTED