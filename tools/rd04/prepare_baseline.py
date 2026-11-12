"""Materialize read-only HEAD sources for the before-behavior reproduction."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
for source, target in [('scripts/combat_board_view.gd','baseline_board.gd'), ('scripts/run_scene.gd','baseline_scene.gd'), ('scripts/turn_order_slots.gd','baseline_slots.gd'), ('scenes/run_scene.tscn','baseline.tscn'), ('tests/perf/hover_board_reference.gd', 'baseline_hover_reference.gd'), ('tests/perf/hover_equivalence.gd','baseline_hover_equivalence.gd')]:
    text = subprocess.check_output(['git','show','HEAD:'+source], cwd=root, text=True)
    if target == 'baseline_board.gd': text = text.replace('class_name CombatBoardView', '')
    if target == 'baseline_scene.gd': text = text.replace('res://scripts/turn_order_slots.gd','res://tools/rd04/baseline_slots.gd')
    if target == 'baseline.tscn':
        text = text.replace('res://scripts/combat_board_view.gd','res://tools/rd04/baseline_board.gd').replace('res://scripts/run_scene.gd','res://tools/rd04/baseline_scene.gd')
    if target.startswith('baseline_hover'):
        text = text.replace('res://scripts/combat_board_view.gd','res://tools/rd04/baseline_board.gd').replace('res://tests/perf/hover_board_reference.gd','res://tools/rd04/baseline_hover_reference.gd')
    (root/'tools/rd04'/target).write_text(text)
