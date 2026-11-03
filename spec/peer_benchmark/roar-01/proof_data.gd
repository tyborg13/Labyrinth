extends RefCounted

# Unit-local proof inputs; these do not change the game's encounters or cameras.
const IDS: Array = ["tharokh", "vyraketh", "iskaldra", "vaeloryx", "noctyrax", "zekarion"]
const PHASES: Array = [0.0, 0.10, 0.21, 0.27, 0.50, 0.79, 0.90, 1.0]
# Peaks selected from existing wing/head release and planted-support keys.
# Zekarion hit supplies his strongest approved backward load and wing fold.
const BASELINES: Dictionary = {"tharokh": [["breath", 0.42], ["breath", 0.55], ["brace", 0.42], ["claw", 0.55], ["faultline", 0.55]], "vyraketh": [["crownfire", 0.43], ["crownfire", 0.55]], "iskaldra": [["storm", 0.35], ["storm", 0.50], ["hit", 0.15]], "vaeloryx": [["dive", 0.34], ["dive", 0.42], ["gale", 0.42], ["guard", 0.30], ["pull", 0.42]], "noctyrax": [["eclipse", 0.40], ["eclipse", 0.50]], "zekarion": [["call", 0.55], ["charge", 0.55], ["hit", 0.15]]}
# First positive/negative 14-Hz extrema inside the authored roar hold.
const STRESS_PHASES: Array = [(0.40 + 2.25 / 14.0) / 1.90, (0.40 + 1.75 / 14.0) / 1.90]
const CANVAS := Vector2i(512, 512)
const SCREEN := Vector2i(1920, 1080)
const OUTPUT: String = "/Users/borgerding/workspace/Labyrinth/output/roar-01"
const ENEMY_TILE := Vector2i(3, 3)
const HERO_TILES: Array = [Vector2i(1, 3), Vector2i(3, 1), Vector2i(1, 1)]

static func renderer(id: String) -> Node:
	return load("res://scripts/%s_cutout/renderer.gd" % id).new()

static func state(id: String, hero: Vector2i) -> Dictionary:
	var result: Dictionary = preload("res://tests/suites/vyraketh_cutout_suite.gd").fixture_state()
	var enemy: Dictionary = result["enemies"][0].duplicate(true)
	enemy["type"] = id
	enemy["pos"] = ENEMY_TILE
	enemy["footprint"] = Vector2i(2, 2)
	result["enemies"] = [enemy]
	result["player"]["pos"] = hero
	return result

static func value(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback
