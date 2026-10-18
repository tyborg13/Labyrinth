# mq-06 feedback 6 — complete floor-contact inventory

The review's Medium finding is fixed without changing native geometry,
captures, design inputs or delivery certificates. HEAD remains the director's
`51a48efa4`, including its crawler-delivery exclusion. Changes are uncommitted.
The referenced `mq-06_review_57d2abd81.md` is absent from this checkout;
the design owner's quoted finding supplies the acceptance criteria.

1. **Spec-derived inventory.** `floor_contact.expected_contact_names(spec,
   view)` derives every ankle from the joints and prop feet from open staff/
   shaft pieces in the weapon inventory. It derives the robe boundary rows
   from cloth skirt ownership labels. It respects each piece's `capture_view`;
   torso cloth, closed prop bands and shorter tabards do not add floor hems.
   The Seer rear requires exactly `ankle_near`, `ankle_far`, `hem_min`,
   `hem_max`, and `staff_shaft.prop_foot`. No expected name comes from the
   native report. Existing documented exceptions still require a present,
   uniquely named contact and cannot replace a missing row.

2. **Reject omissions and empty sets.** The helper rejects empty contacts and
   rejects missing or unexpected names when supplied the expected inventory.
   Per-view delivery validation supplies that inventory from the compiled
   rear spec before evaluating floor heights. Collision assertions, floor
   tolerance, fit registration and all other gates are unchanged.

3. **Regression and verification.** The omission tests remove the far ankle,
   every foot/prop row, the staff butt, a hem boundary, and all contact rows.
   Each mutation retains the report's original passing summaries, reseals
   the independent rear certificate, and validates that fresh child seal.
   Both sealing the complete delivery and strict complete-delivery validation
   must then reject it specifically for its floor inventory. A restored
   complete delivery reseals and validates. Separate tests reject empty
   helper input and exercise extra ankles and view-specific robe/prop pieces.

   `omissions_before.log` records the new tests against the original code:
   `Ran 2 tests in 8.252s`, `FAILED (failures=5, errors=1)`. This is expected
   pre-fix evidence: four incomplete deliveries and empty helper input were
   accepted; an empty report instead reached an unchecked `hem_min` lookup.
   Final observed results are in `verification.txt`. The earlier feedback 5
   full-suite hold is historical; this round tests the director's integrated
   rr-07 reader fix as part of current HEAD.

Files changed for this round:

- `spec/art_identity/maquettes/blender/floor_contact.py`: inventory derivation
  and guard.
- `spec/art_identity/maquettes/blender/view_delivery.py`: require the rear
  inventory.
- `tests/test_maquette_rear_turn.py`: omission and helper tests.
- `spec/art_identity/maquettes/hoarfrost_seer/COMMIT_MANIFEST.txt`: include this
  round's proof files.
- This folder: report, before/after test logs, strict-validation/hash audit,
  full-suite log and final curation result.

The exact worktree-relative file list is `final_file_list.txt`.

`validation.log` records strict validation, the five required rear contacts,
the unchanged 21 frozen-front files and front joints, and all 34 unchanged
staged rear/supporting file hashes. The unchanged hash inventory remains
[`../feedback5/staged_rear_sha256.txt`](../feedback5/staged_rear_sha256.txt).
No existing delivery or other figure's file was rewritten.

Commands run from the worktree:

```sh
python3 tools/output_gdignore.py
python3 -B -m unittest tests.test_maquette_rear_turn -v
python3 -B -m unittest tests.test_maquette_blender spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_drape spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_round3 tests.test_maquette_rear_turn -v
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/hoarfrost_seer
git diff --check
```

Proof for the design owner: validation-only changes require no new windowed
command, Godot scene or native Blender build. The accepted native 1024 sheet
remains [`../feedback4/rear_sheet.png`](../feedback4/rear_sheet.png). Existing
cold/exact replay, collision, coverage, pan and fit certificates are strictly
validated against unchanged images. Seer fixed IoU remains 0.7609076185083125;
dynamic IoU remains the diagnostic 0.20540387838762533. No registration method
changed. Other documented floor offenders remain assigned to their owning
units: Thrall far ankle +0.070364564 m, Herald far ankle +0.048713929 m,
Lancer spear butt +0.269636631 m (possibly intentional).

TODO_DESIGN placeholders: none. Chosen defaults: the new test fixture uses
named joint/piece fields with Z=0.02 m for floor contacts, Z=1 m for its hand
and prop top, and zero lateral coordinates. These are test-only values.
The optional spec-only audit's default view is `front`, preserving its prior
scope; certification always supplies the actual view explicitly. No new
player-facing value or production tolerance was chosen. No implementation
issue remains beyond the verification results recorded alongside this report.
