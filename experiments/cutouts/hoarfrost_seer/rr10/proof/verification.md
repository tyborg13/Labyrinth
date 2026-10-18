# Observed rr-10 verification

All commands ran in the rr-10 worktree on `codex/rr-10`. Changes remain
uncommitted. No reviewer or windowed renderer was invoked.

| Command | Observed result | Evidence |
|---|---|---|
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_build.py` | `RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; `RR10 TUCK COVERAGE: 0 missing source pixels (see proof/build.json)` | `build.json`; source composition, not native pixels |
| Task runner → `godot --headless --path . --script tests/rr10/samples.gd` | `RR10 BONE SAMPLES: PASS (629 poses; headless transforms only)` | `samples.json`, `logs/samples.log` |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py` | `RR10 FRONT BONE/CUT GATES: PASS (0 errors)` | `gates.json`; design placeholders remain |
| `python3 -m unittest discover -s tests -p 'test_rr10_humanoid.py' -v` | `Ran 17 tests in 39.704s`; `OK` | `logs/focused.log` |
| Task runner → `godot --headless --path . --script tests/rr10/runtime_checks.gd` | `RR10 RUNTIME: PASS (10 checks; headless logic only)` | `logs/runtime.log` |
| Task runner → `godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-validate --validate-only` | `RR10 NATIVE PROBE LOAD: PASS` | `logs/native_probe_load.log`; check textures and GPU-reference mesh setup loaded, no native pixels |
| Task runner → `godot --headless --path . --script tests/rr10/production_capture.gd -- --type hoarfrost_seer --output /private/tmp/rr10-production-final --logic-only` | `MAQUETTE PRODUCTION LOGIC: PASS (1441 frames)` | `production_logic.json`; each recorded renderer explicitly asserts humanoid_v2; one front rig, exactly three idle poses |
| Task runner, `--timeout 900` → `godot --headless --path . --script tests/run_tests.gd` | `FULL SUITE RUNTIME: 417.504 seconds (budget 900 seconds)`; `TEST RESULT: PASS` | `logs/godot_full.log`; exit 0 |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | `Ran 856 tests in 772.694s`; `OK (skipped=63)` | `logs/python_full.log`; exit 0 |
| `python3 -m unittest discover -s tests -p 'test_board_pixel_density.py' -v` | `Ran 47 tests in 96.591s`; `OK` | `logs/density.log` |
| `PYTHONPATH=tests python3 -m unittest test_board_pixel_density.BoardPixelDensityTest.test_rig_coverage_names_adoption_command_for_new_art -v` | `Ran 1 test in 0.027s`; `OK` | Focused check after moving unpromoted paint out of the registered production asset tree |
| `PYTHONPATH=tools python3 -m humanoid_cutout.proof --help`; `sh -n experiments/cutouts/hoarfrost_seer/rr10_proof.sh`; `git diff --check` | exit 0 | Proof CLI parsing, shell syntax, whitespace |

Every Godot command above used
`python3 tools/godot_task_runner.py --task-id rr-10 --stream -- ...`.
The full Godot run additionally used the listed 900-second budget.

The 63 Python skips are reported in the full verbose log. Godot emitted its
existing macOS CA-certificate diagnostic and full-suite ObjectDB warning; the
listed commands exited successfully with the observed result lines above.

Earlier runs caught two implementation/proof issues, both fixed without changing
master assertions: the first production probe still captured rr-07 (that report
is not counted), and raw candidate PNGs in the production family triggered the
density gate (paint now remains in the case until promotion/adoption). The
affected checks and full discovery subsequently passed.

Windowed proof was **not run**. There are no native rest/frame/movie/contact-sheet
captures yet. Exact commands and destinations are in `../README.md` and
`../../rr10_proof.sh`. Numerical source/bone passes are not a visual approval.

Acceptance remains partial for the rope-belt ownership split; rear proof and
production promotion are deferred. See both `TODO_DESIGN` entries in
`../inputs.json`. The owner also needs to repair the existing Git task metadata
contract; the worker's contract write was denied by the sandbox and preflight
reported the missing contract.
