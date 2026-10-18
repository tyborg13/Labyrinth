# rr-10 feedback 2 — observed verification

Worker changes are uncommitted on `codex/rr-10`, based on `a65f89a25`.
No windowed command or peer review was run. The exact protected mask is imported
without modification; no art, motion or rear view was invented.

| Command/check | Exact observed result | Evidence |
| --- | --- | --- |
| Protected source vs case import | `RR10 ROPE IMPORT: PASS (byte-identical; 465 pixels; 1 component)` | `../inputs/rope_mask_front.png`; SHA256 `26bc001a33b23ba21dada83c27e8c0e1d7fd21eb067e7b5ded4329509595444c` |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_build.py` | `RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; `RR10 TUCK COVERAGE: 0 missing source pixels (see proof/build.json)` | `build.json`; 391 existing torso pixels, 74 transferred pixels, 74 required cloth pixels |
| Previous/current compiled motion and bone samples | `RR10 MOTION PRESERVATION: PASS (629 unchanged poses; 59 idle)` | `feedback2_preservation.json`; compiled motion byte-identical |
| Task runner -> `godot --headless --path . --script tests/rr10/samples.gd` | `RR10 BONE SAMPLES: PASS (629 poses; headless transforms only)` | `samples.json`, `logs/feedback2_samples.log` |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py` | `RR10 FRONT BONE/CUT GATES: PASS (0 errors)` | `gates.json`, `logs/feedback2_gates.log` |
| `python3 -m unittest discover -s tests -p 'test_rr10_*.py' -v` | `Ran 30 tests in 39.961s`; `OK` | `logs/feedback2_focused.log` |
| Task runner -> `godot --headless --path . --script tests/rr10/runtime_checks.gd` | `RR10 RUNTIME: PASS (10 checks; headless logic only)` | `logs/feedback2_runtime.log` |
| Task runner -> `godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-feedback2-validate --validate-only` | `RR10 NATIVE PROBE LOAD: PASS` | `logs/feedback2_native_probe_load.log`; setup only, no renderer pixels |
| Task runner -> `godot --headless --path . --script tests/rr10/production_capture.gd -- --type hoarfrost_seer --output /private/tmp/rr10-feedback2-production --logic-only` | `MAQUETTE PRODUCTION LOGIC: PASS (1441 frames)` | `feedback2_production_logic.json`, `logs/feedback2_production.log` |
| Full Godot suite | `FULL SUITE RUNTIME: 385.934 seconds (budget 900 seconds)`; `TEST RESULT: PASS` | `logs/feedback2_godot_full.log`; exit 0 |
| Full Python discovery | `Ran 869 tests in 793.114s`; `OK (skipped=63)` | `logs/feedback2_python_full.log`; exit 0 |
| `sh -n experiments/cutouts/hoarfrost_seer/rr10_proof.sh`; `git diff --check` | exit 0 | Shell syntax and whitespace |

Every Godot command uses the required prefix
`python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot ...`.
Full commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

New planted regressions verify that hash tampering, missing hidden cloth, and
rope pixels returned to the robe mesh all fail. The latter two retain the
correct composed rest image, so the gates prove ownership/coverage independently
of the 0 px rest identity check. Unmasked source ownership and RGBA are unchanged.
The existing 2 px tuck, split robe, idle rotation, staff angle, planted hem,
signed motion, feature, stray and flat-band mutations remain in the focused run.

The `RR10 SHEETS: PASS` line in the focused log belongs to the existing mocked
verifier-boundary composition fixture. It is not current renderer acceptance.
No fresh native rest, animation frames or real contact sheets were captured by
the worker. Historical native captures remain stale after the mask change.

The director runs `rest`, `native`, then `sheets` using the exact commands in
[the handoff](../feedback2.md#proof-for-the-design-owner). Expected outputs:
`native_rest/`, `native/`, `native_gates.json`, `native_failures/`, and
`contact_sheets/front_<clip>_3x.png` under this proof directory.

Only `TODO_DESIGN_mq6_rear_delivery_and_paint` remains active. Rear mask path is
configured as `inputs/rope_mask_rear.png`, with no fabricated file or guessed
hash. There are no new chosen defaults. Production promotion is deferred.
