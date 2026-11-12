#!/bin/sh
set -eu
# Deliberately focused domains; the design owner owns the full suites.
for domain in hover shortcut targeting-audit enemy-intent; do
    python3 tools/godot_task_runner.py --task-id rd-03 --stream -- godot --headless --path . --script tools/ptf09/focused_checks.gd -- --domain "$domain"
done
python3 tools/godot_task_runner.py --task-id rd-03 --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
