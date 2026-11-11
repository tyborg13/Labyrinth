#!/usr/bin/env python3
"""Verify compatibility baseline against the unchanged source at the brief’s base."""
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-01/baseline-verification')
SEEDS = 20
BASE_REF = "7cf181c7e"


def original(path):
    return subprocess.check_output(['git', 'show', f'{BASE_REF}:{path}'], cwd=ROOT, text=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'encounters.json').write_text(original('data/encounters.json'))
    table_path = OUTPUT / 'tables.gd'
    table_path.write_text(original('scripts/encounter_tables.gd')
                          .replace('class_name EncounterTables', '')
                          .replace('res://data/encounters.json', str(OUTPUT / 'encounters.json')))
    generator_path = OUTPUT / 'generator.gd'
    generator_path.write_text(original('scripts/room_generator.gd')
                              .replace('class_name RoomGenerator', '')
                              .replace('res://scripts/encounter_tables.gd', str(table_path)))
    probe = OUTPUT / 'verify.gd'
    probe.write_text('''extends SceneTree
const Original = preload("%s")
const Baseline = preload("res://tools/ptf01/baseline_generator.gd")
func _initialize() -> void:
	var original := Original.new()
	var baseline := Baseline.new()
	var checked: int = 0
	for seed_value: int in range(%d):
		for tier: int in range(1, 4):
			for biome: String in ["earth", "fire", "ice", "air", "lightning", "shadow"]:
				for element: String in ["none", "fire", "lightning"]:
					var room: Dictionary = {"coord": Vector2i(tier, seed_value), "depth": tier, "type": "combat", "element": element, "encounter_biome": biome, "section_map_layout_revision": 7, "section_index": 0, "encounter_history": ["t1_crawl_pack", "t2_element"]}
					var expected: Dictionary = original.generate_room(seed_value, room, Vector2i(1, 0))
					var actual: Dictionary = baseline.generate_room(seed_value, room, Vector2i(1, 0))
					actual.erase("encounter_tier")
					if expected != actual:
						print("PTF01 BASELINE: FAIL seed=", seed_value, " tier=", tier, " biome=", biome, " element=", element)
						quit(1)
						return
					checked += 1
	print("PTF01 BASELINE: PASS original-source rooms=", checked)
	quit(0)
''' % (generator_path, SEEDS))
    result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'ptf-01',
                             '--stream', '--', 'godot', '--headless', '--path', '.',
                             '--script', str(probe)], cwd=ROOT)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
