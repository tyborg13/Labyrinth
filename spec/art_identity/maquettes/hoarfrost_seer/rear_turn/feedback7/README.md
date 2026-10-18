# mq-06 feedback 7 — crawler exemption follows spec identity

This round changes only `tests/test_maquette_rear_turn.py`, this proof folder
and the Seer commit manifest. The director's merged HEAD `d0fc5906b` is
preserved. No merge, commit, review, geometry build or capture was performed.
The referenced `mq-06_review_b919e7ac2.md` is absent from this checkout; the
design owner's quoted finding supplies the requirements.

1. **Identity determines the exemption.** A delivery is exempt only when its
   figure's `measurements.json` labels contain neither `foot_near` nor
   `foot_far`. The absence of an image cannot grant an exemption. Labelled
   bipeds must have both foot solos in both views; missing files fail discovery
   explicitly before pixel inspection. Existing pixel checks still reject
   empty solos. The legacy Lancer archive can retain its spec fallback for
   labelled feet, but cannot obtain a crawler exemption without measurements.

2. **Mirror is required.** `glacial_mirror` joins the required roster alongside
   Seer, Lancer, Thrall, Herald and Gloam. The real merged Mirror delivery is
   included in the existing foot-position and body-side depth-order checks.

3. **Omission regression.** Temporary fixtures copy the approved Mirror data.
   One retains the correct rear; one replaces the rear captures with front
   copies, which demonstrably retain front depth order. For each, all four
   foot solos are omitted separately under three label inventories: both foot
   labels, only near, and only far. All 24 omission cases must raise the
   labelled-biped missing-solo error. Complete fixtures are discovered before
   every omission. Only temporary copies are mutated.

   Before the fix, `omissions_before.log` records `Ran 2 tests in 0.824s`,
   `FAILED (failures=25)`: all 24 omissions escaped discovery rejection, and
   the real crawler-exemption names were not reported. This is intentional
   pre-fix evidence. Final observed results are in `verification.txt`.

4. **Named real crawler exemptions.** A separate test verifies the actual
   Grub/Tick measurement labels and the diagnostic output. The committed-data
   turn test reports:

   ```text
   MAQUETTE_REAR_TURN_EXEMPT: burrow_grub/delivery; crawler; measurements.json labels contain neither foot_near nor foot_far
   MAQUETTE_REAR_TURN_EXEMPT: ember_tick/delivery; crawler; measurements.json labels contain neither foot_near nor foot_far
   ```

Focused and full-suite logs include the actual six-biped turn observations.
`verification.txt` records the exact test result lines and final byte/hash
audit. `final_file_list.txt` lists every changed/new file. The manifest and
`curation.log` cover the complete figure tree under the 6,000,000-byte budget.
No evidence was discarded in this round, so the discarded-proof inventory
does not need another entry.

Commands, from the task worktree:

```sh
python3 tools/output_gdignore.py
python3 -B -m unittest tests.test_maquette_blender spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_drape spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_round3 tests.test_maquette_rear_turn -v
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/hoarfrost_seer
git diff --check
```

Proof for the design owner: no windowed command applies to this test-only
fix. No `.gd` file or native asset changed. The accepted native 1024 sheet is
still [`../feedback4/rear_sheet.png`](../feedback4/rear_sheet.png); no new
capture was requested or produced. Existing delivery certificates remain
subject to strict curation verification.

TODO_DESIGN placeholders: none. Chosen defaults: no new numeric defaults.
Named test fixture fields enumerate the required four solo filenames and
the both/near-only/far-only label inventories. The incorrect-rear fixture
uses front copies as an intentionally invalid control. No player-facing
value or supplied design data changed. Open implementation issues: none.
