All commands run from the mq-08 worktree. No full suites or windowed commands apply.

```sh
python3 -B -m unittest discover -s tests -p 'test_glacial_mirror_shoulder.py'
python3 -B -m unittest discover -s tests -p 'test_glacial_mirror_regeneration.py'
python3 -B -m unittest spec.art_identity.maquettes.blender.test_creature spec.art_identity.maquettes.blender.test_sculpt_forms spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_feedback2 spec.art_identity.maquettes.blender.test_source_recipe
python3 -B -m unittest spec.art_identity.maquettes.blender.test_round3 spec.art_identity.maquettes.blender.test_drape
python3 -B -m unittest discover -s tests -p 'test_maquette_blender.py'
python3 -B -m unittest discover -s tests -p 'test_maquette_rear_turn.py'
python3 -B tests/test_art_identity_gate.py
python3 -B -m spec.art_identity.maquettes.glacial_mirror.mutation_proof
python3 -B -m spec.art_identity.maquettes.glacial_mirror.workflow regenerate
python3 -B -m spec.art_identity.maquettes.glacial_mirror.workflow regenerate --resume
python3 -B -m spec.art_identity.maquettes.glacial_mirror.workflow baselines
python3 -B -m spec.art_identity.maquettes.glacial_mirror.workflow baselines --resume
python3 -B -m spec.art_identity.maquettes.glacial_mirror.partial_capture_proof --resume
python3 -B -m spec.art_identity.maquettes.glacial_mirror.workflow curate
```

Fresh regeneration requires a new empty output tree. After curation the new-run commands recreate it; the resume commands require those original snapshots.
