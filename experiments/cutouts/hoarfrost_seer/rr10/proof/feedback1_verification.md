# rr-10 feedback 1 — observed verification

Run in `/Users/borgerding/workspace/Labyrinth.worktrees/rr-10`, branch
`codex/rr-10`. Worker changes are uncommitted. No reviewer, publication or
windowed worker run. Original director captures are preserved as stale evidence.

| Command/check | Exact observed result | Evidence |
| --- | --- | --- |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_build.py` | `RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; `RR10 TUCK COVERAGE: 0 missing source pixels (see proof/build.json)` | `build.json`; source pixels only |
| Integration source vs staged source + two imports | `RR10 PROTECTED IMPORTS: PASS (3 byte-identical copies)` | SHA256 `3936cc0fb6028fe2eb858e7f753efe7aab712d92b8158ea9f74ea4dd91e25f42` |
| Approved idle channel/bone comparison | `RR10 APPROVED IDLE BONES: UNCHANGED (59 poses)` | `feedback1_idle_preservation.json`; exact original/current bone dictionaries |
| Original director isolated idle groups | `DIRECTOR BASELINE IDLE GROUP PIXEL MISMATCHES: 0` | `feedback1_baseline.json`; historical proof, not current pixels |
| Task runner -> `godot --headless --path . --script tests/rr10/samples.gd` | `RR10 BONE SAMPLES: PASS (629 poses; headless transforms only)` | `samples.json`, `logs/feedback1_samples.log` |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py` | `RR10 FRONT BONE/CUT GATES: PASS (0 errors)` | `gates.json`, `logs/feedback1_gates.log` |
| `python3 -m unittest discover -s tests -p 'test_rr10_*.py' -v` | `Ran 24 tests in 42.293s`; `OK` | `logs/feedback1_focused.log` |
| Task runner -> `godot --headless --path . --script tests/rr10/runtime_checks.gd` | `RR10 RUNTIME: PASS (10 checks; headless logic only)` | `logs/feedback1_runtime.log` |
| Task runner -> `godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-feedback1-validate --validate-only` | `RR10 NATIVE PROBE LOAD: PASS` | `logs/feedback1_native_probe_load.log`; GPU geometry setup, no pixel capture |
| Task runner -> `godot --headless --path . --script tests/rr10/production_capture.gd -- --type hoarfrost_seer --output /private/tmp/rr10-feedback1-production --logic-only` | `MAQUETTE PRODUCTION LOGIC: PASS (1441 frames)` | `feedback1_production_logic.json`, `logs/feedback1_production.log`; candidate identity/contact assertions |
| Full Godot suite (command below) | `FULL SUITE RUNTIME: 464.125 seconds (budget 900 seconds)`; `TEST RESULT: PASS` | `logs/feedback1_godot_full.log`; exit 0 |
| Full Python discovery (command below) | `Ran 863 tests in 908.364s`; `OK (skipped=63)` | `logs/feedback1_python_full.log`; exit 0 |
| `sh -n experiments/cutouts/hoarfrost_seer/rr10_proof.sh`; `git diff --check` | exit 0 | Shell syntax and whitespace |

Every Godot command used
`python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot ...`.
Full commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The first complete verification also passed (`FULL SUITE RUNTIME: 389.722
seconds (budget 900 seconds)` / `TEST RESULT: PASS`; Python `Ran 859 tests in
823.756s` / `OK (skipped=63)`). The final runs above include the completed
source cloth gate and added feedback fixture tests.

The focused tests verify all five supplied native defect frames fail the new
stray gate. Mark 30 has 5 detached components / 9 pixels; bolt 27, ward 29 and
move 29 each have 1 / 1; death 64 has 2 / 2. Those counts are historical failing
evidence, not measurements of repaired animation. The historical flat robe-band
texture fails the new cloth gate. A physically reduced 2 px tuck and split robe
also fail, alongside the existing rotation/hem/signed/feature mutations.

`RR10 SHEETS: PASS` inside the focused log is a **mocked verifier-boundary
composition fixture**. It checks gate failure refuses sheets and gate success
builds all supplied frames at 3×. It does not accept the historical bad frames
as native proof. Actual current native gates/sheets require the director's
windowed commands in [the handoff](../feedback1.md#proof-for-the-design-owner).

Fresh capture destinations remain `proof/native_rest/`, `proof/native/`,
`proof/production_native/`, `proof/contact_sheets/`, and the requested MP4s.
No new windowed pixels, movies or real contact sheets were produced by the
worker. Rear and production promotion remain deferred. Whole rope ownership
was pending at this historical stage and is now resolved in feedback 2. The
remaining placeholder is `TODO_DESIGN_mq6_rear_delivery_and_paint`.

The file inventory is [feedback1_changed_files.txt](feedback1_changed_files.txt).
It excludes the director's pre-existing untracked captures.
