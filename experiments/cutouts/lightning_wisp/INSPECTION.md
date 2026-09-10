# Lightning Wisp inspection

This branch replaces only the Wisp's combat-board presentation. Its accepted front paint, identity, HP, initiative, damage, movement/ranges, electrical surfaces, conduction, Shock, summon rules, portrait and rewards remain intact. The body is an editable floating core and electrical envelope with coherent hover, distance-driven flight, a Spark Dart lunge, and electrical gather/release casts.

## Art and motion

- Editable case: `v01/cutout.json`; saved Godot scenes: `v01/proof/front.tscn` and `v01/proof/rear.tscn`.
- Native study reel: `v01/proof/videos/cutout_review.mp4`.
- Actual gameplay preview: `runtime_v1/gameplay/lightning_wisp_preview.mp4`.
- Complete gameplay reel and timed samples: `runtime_v1/gameplay/lightning_wisp_gameplay_full_speed.mp4`, `manifest.json`, `video_timeline.json`.
- Front/rear registration, ownership and actual generation prompts: `v01/source/`.
- Production integration and residual limits: `spec/lightning_wisp_cutout_runtime.md` from the repository root.

Native proof uses Metal at 1920×1080 and 100% UI scale. The study reel shows authored playback; the gameplay reel preserves the wall-clock timing recorded from RunScene. Mirrors use the real front/rear rigs. The aperture remains rigid, and all lightning branches translate coherently with the core at idle.

## Playable pre-action fixture

After the exact committed branch has peer signoff, generate and independently verify the task-local fixture with the following command. It recreates the starting state each time, then opens the game. Choose Continue. Move around the Wisps to see completed-movement facing; Pass to see Spark Dart, Static Lash and Capacitor Arc; attack a Wisp to inspect its death dissolve. The fixture is isolated from ordinary saves.

```bash
cd /Users/borgerding/.codex/worktrees/af89/Labyrinth && python3 tools/inspection_fixture.py --task-id animate-lightning-wisp-cutout --run-id lightning-wisp-inspection --manifest /private/tmp/lightning-wisp-inspection.json --launch --scenario combat --summary 'Three Lightning Wisps: move around them to inspect facing, then Pass for Spark Dart, Static Lash and Capacitor Arc.' --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types lightning_wisp,lightning_wisp,lightning_wisp --enemy-positions 3:3,5:4,1:4 --enemy-intents spark_dart,static_lash,blinding_arc --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

The handoff records the reviewed commit, separate reviewer verdict and generated verifier manifest. Publication and cleanup remain subject to the user's explicit approval of that commit.

## Reproduce verification

Run commands from this worktree. Native captures use the common GUI lease, one capture at a time. The optional lease wait below affects queue waiting only; native startup and capture watchdogs remain intact.

```bash
python3 tools/godot_task_runner.py --task-id animate-lightning-wisp-cutout --stream -- godot --headless --path . --script tests/lightning_wisp_cutout_test.gd
python3 tools/godot_task_runner.py --task-id animate-lightning-wisp-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tests/test_cutout_workflow.py
python3 tools/cutout_workflow.py validate experiments/cutouts/lightning_wisp/v01
python3 tools/cutout_workflow.py verify-render experiments/cutouts/lightning_wisp/v01 --output experiments/cutouts/lightning_wisp/v01/proof
python3 experiments/cutouts/lightning_wisp/capture_proof.py verify
```

Fresh native studies require a new output directory:

```bash
python3 tools/cutout_workflow.py render experiments/cutouts/lightning_wisp/v01 --output /private/tmp/lightning-wisp-fresh-study --task-id animate-lightning-wisp-cutout --backend metal --gui-lease-timeout 1800
```

`runtime_v1/export_build.log`, `export_runtime.log` and `export_template.json` record the production-only renderer package check and the unchanged official macOS export template digest. This is a resource-closure check, not a complete cross-platform release test.
