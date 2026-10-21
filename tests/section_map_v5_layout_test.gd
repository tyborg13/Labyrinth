extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SEED_COUNT: int = 200
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_PANEL_SIZE: Vector2 = Vector2(1864, 1024)
const MINIMUM_BUTTON_GAP: float = 8.0
const FLOAT_TOLERANCE: float = 0.001
var ordinary_failures: int = 0
var boss_failures: int = 0
var first_failure: String = ""

func _initialize() -> void:
	Settings.set_storage_path("user://map_02_layout_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	_run.call_deferred()

func _run() -> void:
	# map-02 proves revision 5's fixed-width layout; saved runs keep it (revision 7 scrolls).
	var first_state: Dictionary = {"seed": 1, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": 5}
	Graph.initialize(first_state)
	first_state["current_room"] = Graph.section(first_state, 2)["entry"]
	var panel := MapPanel.new()
	panel.size = PROOF_PANEL_SIZE
	panel.set_run_state(first_state)
	panel.select_section(0)
	root.add_child(panel)
	if not panel.is_node_ready(): await panel.ready
	await process_frame
	await process_frame
	if not panel._built or panel._field == null or panel.viewed_section != 0 or panel.node_buttons.is_empty():
		push_error("Map 02 readiness regression: pre-ready history selection did not render after ready")
		panel.free()
		quit(1)
		return
	print("Map 02 pre-ready history selection: PASS")
	print("Map 02 layout field: ", panel._field.size, " at 1920x1080, 100% UI scale")
	for seed_value: int in range(1, SEED_COUNT + 1):
		var state: Dictionary = first_state if seed_value == 1 else {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": 5}
		if seed_value != 1: Graph.initialize(state)
		for node: Dictionary in state["rooms"].values():
			node["revealed"] = true
			node["map_outline"] = true
		for index: int in range(6):
			state["current_room"] = Graph.section(state, index)["entry"]
			panel.set_run_state(state)
			panel.select_section(index)
			var buttons: Array = panel.node_buttons.values()
			for a: int in range(buttons.size()):
				for b: int in range(a + 1, buttons.size()):
					var first: Control = buttons[a]
					var second: Control = buttons[b]
					var first_rect: Rect2 = first.get_rect()
					var second_rect: Rect2 = second.get_rect()
					var dx: float = maxf(0, maxf(first_rect.position.x - second_rect.end.x, second_rect.position.x - first_rect.end.x))
					var dy: float = maxf(0, maxf(first_rect.position.y - second_rect.end.y, second_rect.position.y - first_rect.end.y))
					var gap: float = Vector2(dx, dy).length()
					if gap + FLOAT_TOLERANCE >= MINIMUM_BUTTON_GAP: continue
					var boss: bool = first.get("room_data")["type"] == "boss" or second.get("room_data")["type"] == "boss"
					if boss: boss_failures += 1
					else: ordinary_failures += 1
					if first_failure.is_empty(): first_failure = "seed=%d section=%d %s / %s gap=%.3fpx" % [seed_value, index + 1, first.name, second.name, gap]
		if seed_value % 10 == 0: print("Map 02 layout: %d/%d seeds" % [seed_value, SEED_COUNT])
	panel.free()
	print("Map 02 ordinary button gaps: %d violations (200 seeds x 6 sections)" % ordinary_failures)
	print("Map 02 boss button gaps: %d violations (200 seeds x 6 sections)" % boss_failures)
	if not first_failure.is_empty(): print("First gap failure: " + first_failure)
	print("Section map v5 no-overlap suite: %s" % ("PASS" if ordinary_failures + boss_failures == 0 else "FAIL"))
	quit(0 if ordinary_failures + boss_failures == 0 else 1)
