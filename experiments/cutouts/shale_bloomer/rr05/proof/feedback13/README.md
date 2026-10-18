# Feedback 13: stopped on saved-sample binding mismatch

The three requested code fixes are implemented, uncommitted. Rechecking CPU gates against the existing samples returned `Stale or incomplete pixel samples` for both creatures. Feedback 13 says to stop if a gate result changes, so native verification and the remaining suites were not run. No capture metadata, production assets, art, layouts, motion or runtime GDScript was changed.

## Numbered fixes

1. Promotion requires a sealed, passing certificate bound by SHA-256 to the current case inputs, layouts, textures, continuity/feature proofs and gate implementation. Fresh CLI gates and native review save a certificate only after verifying its report and current bindings; inputs changing during a gate also reject. Promotion checks before creating its destination or copying files. The support-recolour regression rejects stale promotion, then a fresh material check finds the reviewer's 1,239-pixel derived slab in `rear/shell/0014`. Layout, tool, report and certificate mutations reject too.
2. Exact-tie candidates use only in-range texture coordinates. Boundary alternatives collapse onto the sole real texel. The 12×12 half-pixel translation regression rejects the erased first row/column (23 pixels). All three retained native fixtures pass. Tolerances are unchanged.
3. The native-alpha fixture creates its temporary directory in system temp. Its targeted test passes. The complete focused suite from a clean output directory remains unrun because of the stop condition.

## Gate stop evidence

Both creatures returned:

```text
MAQUETTE PIXEL GATES: FAIL (1 errors)
['Stale or incomplete pixel samples']
```

The following mismatches occur in each creature's case samples, native samples and native frame manifest:

| Runtime file | Recorded SHA-256 prefix | Current / HEAD prefix |
| --- | --- | --- |
| `scripts/run_scene.gd` | `b1ce4ae81938` | `584d23a17070` |
| `scripts/combat_board_view.gd` | `76b9aa121fed` | `bb7eb7124539` |

Both current files are byte-identical to HEAD c87609f84. These mismatches predate this round's changes. Full hashes and affected manifests are in [stop_condition.json](stop_condition.json). Capture bindings were not rewritten and no rendering inputs were exempted from validation. Native part verification was not reached; no native success is claimed.

## Observed verification

| Command | Exact result |
| --- | --- |
| `python3 -m unittest discover -s tests -p 'test_maquette_native*.py' -v` | `Ran 16 tests in 1.005s` / `OK` |
| `python3 -m unittest discover -s tests -p 'test_maquette_certificates.py' -v` | `Ran 3 tests in 6.327s` / `OK` |
| `python3 -m unittest discover -s tests -p 'test_maquette_joint_seams.py' -v` | `Ran 14 tests in 1.346s` / `OK` |
| CPU gate recheck, both creatures | `MAQUETTE PIXEL GATES: FAIL (1 errors)`; stale samples |
| `git diff --check` | Exit 0 |

Logs are under `output/rr-05/feedback13/`: `native-tests.log`, `certificate-tests.log`, `seam-tests.log`, `shale-recheck.log`, `wisp-recheck.log`. [verification.json](verification.json) distinguishes completed and unrun proof. [preservation.json](preservation.json) records 899 unchanged protected files.

## Files changed

- `tools/maquette_motion/certificates.py`: certificate sealing and current-input verification.
- `tools/maquette_motion/gates.py`: include the certificate implementation in gate-tool hashes.
- `tools/maquette_cutout_polish.py`: bind fresh gate reports and save passing certificates.
- `tools/maquette_cutout_review.py`: save the freshly verified native gate certificate.
- `tools/maquette_cutout_build.py`: require current certification before promotion copies.
- `tools/maquette_motion/raster.py`: restrict exact-tie candidates to real texels.
- `tests/test_maquette_certificates.py`: freshness and support-recolour regressions.
- `tests/test_maquette_native_ties.py`: boundary-erasure regression.
- `tests/test_maquette_native_alpha.py`: system-temp fixture.
- `tests/test_maquette_joint_seams.py`: isolate certificate checking in the existing seam-only promotion fixture.
- This handoff folder and the rr05 README: observed results and stop evidence.

## Chosen defaults and open issues

No player-facing defaults or TODO_DESIGN placeholders were added. Test-only values are listed in [chosen_defaults.json](chosen_defaults.json). The open issue is the saved sample/runtime binding mismatch. No new capture command is requested by this handoff: the director must resolve that evidence mismatch before proof continues. Full native verification, clean-output focused testing, full Godot and full Python suites remain unrun for this round.
