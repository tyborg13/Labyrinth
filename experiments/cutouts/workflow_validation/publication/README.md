# Publication merge verification

The user approved checkpoint `8b7497552d772cf6b47ffb3bab121a11ab23cba2` for push and cleanup on September 8, 2026. Publication fetched upstream `685c3dde359e7d28ceb3173c2c10f8878e4114ee` and encountered one overlapping `_ready()` edit in `CombatBoardView`.

The resolution keeps the approved cutout renderer initialization followed by upstream's `not _initial_assets_prepared` asset-loading guard. It preserves both branches' intended behavior. All character paint, layout, rig and motion files remain identical to the approved checkpoint. The automatically merged performance changes remain intact.

## Affected verification

- The complete Godot suite, focused protagonist suite and main-menu input/transition suite pass. The menu suite includes New, Continue, replacement, reduced motion and interrupted staging. Logs are in `tests/`; the known test warning about ambiguous legacy saves and ObjectDB shutdown warning remain visible.
- `board_startup_manifest_probe.gd` still proves synchronous/staged asset equivalence. Added checks establish a prepared cutout rest texture before attachment, exactly one ready live renderer, shared renderer identity in retained layers, and retention of the staged rest texture. Six loading slices complete with no semantic errors. The 15 MB original log is identified by path/digest in `tests/board-startup-summary.json`; its large manifest sections have separate digests.
- The existing native gameplay probe passes at 1920×1080, 100% UI scale with 22 clips, 901 sampled frames and no manifest errors. Selected original PNGs and the full sampled manifest are in `gameplay/`. Visual inspection covered idle, movement, rear melee, Whirlwind hit labels, equipment, incoming contact and reduced motion. The remaining raw frame sequence is identified by `gameplay/retention.json`.
- The new native Continue probe uses the actual root scene lifecycle and an isolated saved boss room. A fixed 1920×1080 viewport render target avoids host window geometry changing the proof size. All three screenshots assert their dimensions; preparing/revealing/complete phases, settled destination layout, restored input and the accepted front cutout pass. The loading overlay and revealed room were visually inspected. See `continue/`.
- The proof input scan now includes generated `.res` assets, including upstream's card and shadow caches. A regression test changes a resource and verifies its input hash changes. All 15 focused Python tests pass.

The Continue probe initially used a child SubViewport that Godot rejected for `current_scene`; a second attempt exposed host fullscreen/window bounds. These were probe harness issues. The retained final result uses the real root, windowed settings and fixed viewport rendering, with no Godot errors. The startup probe's live renderer required deferred test teardown; it now queues the board for deletion and waits one frame.

`gameplay_input_sha256.json` binds the gameplay script and production source/image closure captured before rendering. Unrelated test/tool files are excluded because this gameplay probe does not load them. `test_input_sha256.json` identifies the exact maintained GDScript tests. `generated_resources_sha256.json` proves both binary caches match immutable upstream. Earlier operationalization proof remains historical evidence for the accepted checkpoint; fresh workflow proof is described below.

## Fresh reusable workflow proof

The final portable salute case capture and its hashes are retained in `workflow/`. The complete capture verifies 923 inputs and 755 outputs, 312 board frames and eight pixel-identical editable-scene comparisons. Selected original board PNGs, scene resources, the timed reel and full manifests are retained; omitted raw JPEGs/pose duplicates remain in the temporary directory recorded by `retention.json`. The original proof hash manifest lists those omitted files and cannot verify this curated subset as a complete render output. `pose-comparison.json` records native pose hashes and comparison with the inspected checkpoint. This remains an authoring demonstration, with the previously documented rear-salute HP overlap; it does not add a production action. The case reproduces approved idle/walk/attack paint and movement and exports reloadable scenes. The original nonhumanoid loader rehearsal remains valid historical proof: its graph and loader behavior have not changed in this merge.

Reproduce the affected checks through the task runners:

```sh
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/board_startup_manifest_probe.gd
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/main_menu_input_test.gd
python3 tools/visual_probe_runner.py --task-id <task-id> tests/protagonist_cutout_continue_probe.gd --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080
python3 tools/cutout_workflow.py render experiments/cutouts/workflow_validation/salute_case --output /private/tmp/cutout-fresh-publication --task-id <task-id> --backend metal
python3 tests/test_cutout_workflow.py
```

The approved live fixture remains the inspection surface; this publication adjustment preserves its character content. No Windows or physical-controller certification is claimed. Original final-pass package proof remains applicable to the unchanged standalone rig/motion/art resources.
