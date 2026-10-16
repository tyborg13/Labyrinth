#!/usr/bin/env bash
# Design-owner windowed proof; generated from the command sequence in ../README.md.
# This worker syntax-checks this script only; it does not execute it.
set -euo pipefail

cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && mkdir -p output/rr-04
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/output_gdignore.py

# Native rest identity against the approved, untreated case paint.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/native_contract.json --result-manifest output/rr-04/shale-rest-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-rest --rest-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/native_contract.json --result-manifest output/rr-04/wisp-rest-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-rest --rest-only

# Native clip rendering, each authored clip sampled at 60fps in both views.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_render_contract.json --result-manifest output/rr-04/shale-render-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_render_contract.json --result-manifest output/rr-04/wisp-render-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-native

# Verify all captured files/rests and signed bone motion.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --native output/rr-04/shale-native --output output/rr-04/shale-native-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --native output/rr-04/wisp-native --output output/rr-04/wisp-native-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tests/maquette_cutout/samples.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tests/maquette_cutout/samples.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --samples output/rr-04/shale-samples.json --output output/rr-04/shale-motion-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --samples output/rr-04/wisp-samples.json --output output/rr-04/wisp-motion-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tests/test_semantic_maquette_motion.py -v

# Finish density rests using the real renderer, then record and seal them.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only shale_bloomer_cutout
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only lightning_wisp
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --only shale_bloomer_cutout --record-rests
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --only lightning_wisp --record-rests
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_build.py seal-density --creature shale_bloomer
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_build.py seal-density --creature lightning_wisp
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --check

# Real production callback capture at 1920x1080, 100% UI scale.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_production_contract.json --result-manifest output/rr-04/shale-production-result.json tests/maquette_cutout/production_capture.gd -- --type bile_bloomer --output res://output/rr-04/shale-production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_production_contract.json --result-manifest output/rr-04/wisp-production-result.json tests/maquette_cutout/production_capture.gd -- --type lightning_wisp --output res://output/rr-04/wisp-production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --production output/rr-04/shale-production/frames.json --output output/rr-04/shale-production-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --production output/rr-04/wisp-production/frames.json --output output/rr-04/wisp-production-gates.json

# The two real-time MP4s, without retiming or interpolated frames.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_review.py --case experiments/cutouts/shale_bloomer/mq3 --capture output/rr-04/shale-native --output output/rr-04/shale_bloomer_review.mp4
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_review.py --case experiments/cutouts/lightning_wisp/mq4 --capture output/rr-04/wisp-native --output output/rr-04/lightning_wisp_review.mp4

# Owner-owned playable inspection fixture and launch.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/inspection_fixture.py --task-id rr-04 --scenario combat --enemy-types bile_bloomer,lightning_wisp --enemy-intents bile_burst,spark_dart --summary 'rr-04 Shale Bloomer and Lightning Wisp maquette rigs' --manifest /private/tmp/labyrinth-inspection-manifests/rr-04.json --launch

# Full final suites after native rest completion.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 -m unittest discover -s tests -p 'test_*.py' -v
