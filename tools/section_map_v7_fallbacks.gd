extends SceneTree

# Regenerates data/section_map_v7_fallbacks.json: one revision-7 section per
# index, produced by the ordinary generator, whose special placement succeeds.
# Run headless through tools/godot_task_runner.py. section_map_v7_suite checks
# the stored sections against every map rule.
const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const OUTPUT: String = "res://data/section_map_v7_fallbacks.json"
const SEARCH_SEEDS: int = 200
const PLACEMENT_SEEDS: int = 16

func _initialize() -> void:
	var result: Dictionary = {}
	for index: int in range(6):
		var count: int = Graph.ROOM_COUNTS[index]
		for seed_value: int in range(1, SEARCH_SEEDS + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var diagnostics: Dictionary = {"enabled": true}
			var layout: Dictionary = Graph._section_layout_v7(rng, seed_value, index, diagnostics)
			if int(diagnostics.get("fallback", 0)) > 0 or not _places(layout, count): continue
			result[str(index)] = _serialize(layout)
			print("Section %d fallback from seed %d" % [index + 1, seed_value])
			break
		if not result.has(str(index)):
			push_error("No fallback found for section %d" % (index + 1))
			quit(1)
			return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true) + "\n")
	file.close()
	print("Wrote " + OUTPUT)
	quit(0)

func _places(layout: Dictionary, count: int) -> bool:
	for placement_seed: int in range(PLACEMENT_SEEDS):
		var rng := RandomNumberGenerator.new()
		rng.seed = placement_seed
		if not Specials.place(layout.duplicate(true), rng, count, "none"): return false
	return true

func _serialize(layout: Dictionary) -> Dictionary:
	var rows: Dictionary = {}
	for step: int in layout["rows"]: rows[str(step)] = layout["rows"][step]
	var children: Dictionary = {}
	for cell: Vector2i in layout["children"]:
		var targets: Array[String]
		for target: Vector2i in layout["children"][cell]: targets.append("%d,%d" % [target.x, target.y])
		children["%d,%d" % [cell.x, cell.y]] = targets
	var types: Dictionary = {}
	var mysteries: Dictionary = {}
	for cell: Vector2i in layout["order"]:
		var node: Dictionary = layout["nodes"][cell]
		if not bool(node["fixed"]): types["%d,%d" % [cell.x, cell.y]] = str(node["type"])
		# A mystery's hidden type decides whether it counts as a fight.
		if str(node["type"]) == "mystery": mysteries["%d,%d" % [cell.x, cell.y]] = str(node["mystery_type"])
	return {"rows": rows, "children": children, "types": types, "mystery_types": mysteries}
