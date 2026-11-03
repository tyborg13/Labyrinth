# mq-18 — Last Lamplighter, director feedback 3

Proof and controls only. The approved compiled spec, all delivery images and
reports, and both director prompts remain byte-unchanged. No shape, pose,
camera, material, render setting or production art changed. Changes remain
uncommitted on `codex/mq-18`; no review or publication was performed.

## Review requirements

1. `regeneration_validation.py` checks the complete expected input set against
   current source bytes, after checking the retained inventory's raw SHA-256
   (including when stored as gzip). Generation and verification share the same
   input list. Acceptance must pass, cached models must not be reused, and all
   four front/rear clay/part-map comparisons must pass. Canonical comparison
   hashes and raw delivery hashes are recomputed from the delivered images.
   Rejection tests cover opaque lantern glass, a failed front-clay comparison,
   an invalid inventory digest, an omitted source, missing comparisons and
   forged image hashes. The old receipt was observed to reject all three
   corrected source files before the fresh rebuild.
2. The measured tear gate reads `robe_tears_min`. Segment construction reads
   `arm_lames` and `leg_lames`; tests vary these controls. Unused `caprows` is
   removed. The compiled digest stays exactly
   `7b97bbfebb71122ed90d38c1fdaf5ddc184b41f910334febac3f52dee5302cf4`.
3. `COMMIT_MANIFEST.txt` includes the protected `prompt_front.md` and
   `prompt_rear.md`. Both prompts retain their original bytes. Curation includes
   current proof sources, receipts and logs under the 6,000,000-byte budget.

## Observed proof

- `MQ18_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false`.
- `MQ18_CAPTURE_MERGE: PASS; views=2; solos=44`.
- `MQ18_ACCEPTANCE: PASS; unexplained_parts=[]`.
- Unit: `Ran 32 tests in 17.665s` / `OK`.
- Shared focused checks: `Ran 64 tests in 4.097s` / `OK (skipped=2)`.
- Art identity: `Ran 111 tests in 65.995s` / `OK`.
- `ISOLATION AUDIT: 228 modules`; the unit still declares `[]`.

`feedback3_checks.log.gz` retains the check and regeneration logs.
`delivery/validation/regeneration/regeneration.json` retains the four exact
comparisons and native report bindings. Its retained input inventory validates
against current source bytes. `bridge_evidence.json.gz` losslessly packs each
bridge receipt/log as base64 bytes. Discarded-proof inventories use lossless
XZ storage, retaining every prior record and hash; legacy gzip remains readable.
Models, caches and duplicate clean-rebuild images are removed only after their
hashes are recorded. Approved delivery PNGs are never rewritten.

The approved six geometry requirements remain passing: 87 numeric rows,
11 rejected native mutations, a 0.771455860 rear/front lantern area ratio,
visible candle through at least two panes in each view, six folds, six tears,
and 8.000000011 degrees of measured lean. Existing cold/cache/independent and
exact native replay receipts remain intact. The foreign-file inventory binds
2,051 unchanged files and 16 foreign compiled inputs. Geometry tables, coverage,
1024px clays, part maps, 44 solos, joints and the contact sheet remain under
`delivery/`; the contact sheet includes current art and the approved mq-17 clay.

## Proof for the design owner

All Blender calls ran through the director bridge, with the normal 110s
execution / 120s absolute response limits. This round's commands were:

```sh
python3 -B -m spec.art_identity.maquettes.last_lamplighter.proof regenerate --out spec/art_identity/maquettes/last_lamplighter/proof/feedback3_fresh
python3 -B -m unittest tests.test_mq18_maquette -q
python3 -B -m spec.art_identity.maquettes.last_lamplighter.proof curate
python3 -B -m spec.art_identity.maquettes.last_lamplighter.proof verify
```

Run from this worktree; future regeneration needs a new empty destination.
No windowed Godot probe or `inspection_fixture.py` command applies to this
offline native maquette. No full suite or windowed run was attempted.

`chosen_defaults.json` records numerical, test and proof controls. This round
adds only internal archive encoding: XZ preset 6 for discarded hashes and
base64 entries inside the existing deterministic gzip settings for bridge
logs. No unresolved `TODO_DESIGN` placeholder or open issue remains.
