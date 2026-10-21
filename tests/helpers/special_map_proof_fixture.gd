extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const FIXTURE_SEED: int = 83
const LEGEND_SEARCH_SEEDS: int = 64
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PANEL_POSITION: Vector2 = Vector2(28, 28)
const PANEL_SIZE: Vector2 = Vector2(1864, 1024)
const CONTRACT_PATH: String = "/private/tmp/labyrinth-inspection-manifests/spx-02-visual-contract.json"
const CAPTURES: Array = ["01_future.png", "02_available.png", "03_hover.png", "04_focus.png", "05_visited.png", "06_bypassed.png", "07_fullest_legend.png", "08_section_vi_fog.png"]

static func new_state(seed_value: int = FIXTURE_SEED) -> Dictionary:
	var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state)
	return state

static func special_coord(state: Dictionary, section_index: int = 0) -> Vector2i:
	for node: Dictionary in state["rooms"].values():
		if str(node["type"]) == "special" and int(node["section_index"]) == section_index: return node["coord"]
	return Graph.INVALID

static func available_state(state: Dictionary, target: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	for node: Dictionary in next["rooms"].values():
		for edge: Dictionary in node["connections"]:
			if edge["coord"] == target:
				next["current_room"] = node["coord"]
				node["visited"] = true
				node["cleared"] = true
				Graph.refresh_knowledge(next)
				return next
	return next

static func bypassed_state(state: Dictionary, target: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var index: int = int(Graph.room(next, target)["section_index"])
	for node: Dictionary in next["rooms"].values():
		if int(node["section_index"]) != index or node["coord"] == target: continue
		if int(node["map_step"]) > int(Graph.room(next, target)["map_step"]): continue
		if Graph.descendants(next, node["coord"]).has(target): continue
		next["current_room"] = node["coord"]
		node["visited"] = true
		node["cleared"] = true
		Graph.refresh_knowledge(next)
		return next
	return next

static func section_types(state: Dictionary, index: int) -> Dictionary:
	var types: Dictionary = {}
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) != index or node["type"] == "start": continue
		var type: String = str(node["type"])
		if type == "special": type = "special_" + str(node["special_type"])
		if type == "mystery": type = "unknown"
		types[type] = true
	return types

static func fullest_state() -> Dictionary:
	var best: Dictionary = {}
	var maximum: int = 0
	# Nine ordinary legend concepts plus every currently enabled special.
	var full_count: int = 9 + mini(3, Specials.enabled_types().size())
	for seed_value: int in range(LEGEND_SEARCH_SEEDS):
		var state: Dictionary = new_state(seed_value)
		for index: int in range(6):
			var count: int = section_types(state, index).size()
			if count <= maximum: continue
			maximum = count
			best = state.duplicate(true)
			best["current_room"] = Graph.section(best, index)["entry"]
			Graph.refresh_knowledge(best)
			if count == full_count: return best
	return best

static func write_contract() -> Error:
	var required: Array[Dictionary]
	for filename: String in CAPTURES:
		required.append({"pattern": "*" + filename, "width": PROOF_SIZE.x, "height": PROOF_SIZE.y})
	DirAccess.make_dir_recursive_absolute(CONTRACT_PATH.get_base_dir())
	var file := FileAccess.open(CONTRACT_PATH, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"min_images": CAPTURES.size(), "expected_sizes": ["1920x1080"], "required_images": required}, "\t"))
	print("SPX visual proof contract: " + CONTRACT_PATH)
	return OK
