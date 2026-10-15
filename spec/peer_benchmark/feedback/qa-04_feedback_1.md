# qa-04 feedback 1 (director, after peer review)

Work on top of HEAD (a7c54306c). Do not commit.
1. **Revert** the edit to `output/classical_soundtracks/chopin_op35_funeral_march/scripts/build_arrangement_v05.py` (it
   breaks the approved v05 reproducibility hash pinned in `track.v05.json` / `VERIFICATION.json`). Put the sidecar
   tolerance in `tests/test_chopin_death_music.py`: copy the v04 tree with `shutil.ignore_patterns("*.import")`, point the
   check at the copy, call `_verify_v04_is_untouched`; keep the negative cases (.uid, .import.bak, other added files,
   changed content). Prove `verify_reproducibility` for v05 passes again.
2. `tools/output_gdignore.py`: refuse to run if `output` itself is a symlink or resolves outside the repo.
Proof: Chopin tests, helper tests, the v05 reproducibility verification, full Python suite.
