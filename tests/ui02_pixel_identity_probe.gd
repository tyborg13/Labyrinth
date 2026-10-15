extends SceneTree

# One renderer/process captures the immutable task base, then the working tree.
# --check-fixtures runs all setup/semantic checks headlessly, without pretending
# that the dummy renderer proves pixel identity. It also writes the contract.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const MapView = preload("res://scripts/labyrinth_map_view.gd")
const SkillView = preload("res://scripts/skill_tree_view.gd")
const SectionPanel = preload("res://scripts/section_map_panel.gd")
const SkillLibrary = preload("res://scripts/skill_tree_library.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const BASE_COMMIT: String = "3aaf88d854401fbfadcd45a804e7d46789cb3273"
const OUTPUT: String = "res://.godot/ui02/pixel_identity"
const CONTRACT: String = "res://.godot/ui02/proof_contract.json"
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_INSET: Vector2 = Vector2(28, 28)
const SETTLE_FRAMES: int = 6
const SECTION_SEED: int = 90429
const SECTION_STEPS: int = 3
const FROZEN_PULSE_PHASE: float = 0.0
const SKILL_POINTS: int = 4
const SKILL_REQUIRED_COUNT: int = 5
const OWNED_SKILL: String = "quick_wits"
const AVAILABLE_SKILL: String = "measured_breath"
const LOCKED_SKILL: String = "confluence"
const MAP_HOVER_COORD: Vector2i = Vector2i(3, 3)
const MAP_BOSS_COORD: Vector2i = Vector2i(4, 2)
const MAP_BLOCKED_COORD: Vector2i = Vector2i(0, 1)
const MAP_BRANCH_COORD: Vector2i = Vector2i(1, 1)
const MAP_PATH: Array = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]
const MAP_TYPES: Array = ["start", "combat", "campfire", "combat", "treasure", "scavenger", "combat", "boss", "combat"]
const CASES: Array = ["map", "map_hover", "skills_owned", "skills_selected", "skills_locked", "section", "section_focus"]
const OWNED_PATHS: Array = ["scripts/labyrinth_map_view.gd", "scripts/skill_tree_view.gd", "scripts/section_map_node.gd"]

var _errors: Array[String]
var _before_scripts: Dictionary = {}
var _source_hashes: Dictionary = {}
var _before_images: Dictionary = {}
var _comparisons: Array[Dictionary]
var _view: SubViewport
var _headless_check: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_headless_check = OS.get_cmdline_user_args().has("--check-fixtures")
	if not _headless_check and DisplayServer.get_name() == "headless":
		_check(false, "Pixel proof requires the real renderer; use --check-fixtures for headless validation")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_write_contract()
	for path: String in OWNED_PATHS:
		_before_scripts[path] = _load_before(path)
	var panel_source: String = FileAccess.get_file_as_string("res://scripts/section_map_panel.gd")
	# Inject the base node and legacy-map implementations before _ready builds
	# the real section panel. The surrounding panel is outside this unit's scope.
	panel_source = panel_source.replace("class_name SectionMapPanel\n", "")
	panel_source = panel_source.replace('const NodeButton = preload("res://scripts/section_map_node.gd")', "var NodeButton: GDScript")
	panel_source = panel_source.replace('const LegacyMap = preload("res://scripts/labyrinth_map_view.gd")', "var LegacyMap: GDScript")
	_before_scripts["panel"] = _compile(panel_source)
	if not _errors.is_empty():
		_finish()
		return
	if not _headless_check:
		root.mode = Window.MODE_WINDOWED
		root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	_view = SubViewport.new()
	_view.size = PROOF_SIZE
	_view.msaa_2d = root.msaa_2d
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_check_style_equivalence()
	for before: bool in [true, false]:
		for case_id: String in CASES:
			await _run_case(case_id, before)
	_view.free()
	_finish()

func _load_before(path: String) -> GDScript:
	var output: Array
	var result: int = OS.execute("git", PackedStringArray(["show", BASE_COMMIT + ":" + path]), output, true)
	_check(result == 0 and not output.is_empty(), "Read immutable base: " + path)
	if result != 0 or output.is_empty():
		return null
	var source: String = str(output[0])
	_source_hashes[path] = {"before": source.sha256_text(), "after": FileAccess.get_file_as_string("res://" + path).sha256_text()}
	source = source.replace("class_name LabyrinthMapView\n", "").replace("class_name SkillTreeView\n", "")
	return _compile(source)

func _compile(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	_check(script.reload() == OK, "Base script compiles")
	return script

func _check_style_equivalence() -> void:
	var before: Control = (_before_scripts["scripts/skill_tree_view.gd"] as GDScript).new()
	var after: Control = SkillView.new()
	var old_style: StyleBoxFlat = before.call("_panel_style", Palette.GOLD)
	var new_style: StyleBoxFlat = after.call("_panel_style", Palette.GOLD)
	for property: String in ["bg_color", "border_color", "border_width_left", "border_width_top", "border_width_right", "border_width_bottom", "corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right", "anti_aliasing", "anti_aliasing_size", "shadow_size", "shadow_offset", "content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom", "expand_margin_left", "expand_margin_right", "expand_margin_top", "expand_margin_bottom"]:
		_check(old_style.get(property) == new_style.get(property), "Identical panel property: " + property)
	# Shadow colour is immaterial only while both styles disable the shadow.
	_check(old_style.shadow_size == 0 and new_style.shadow_size == 0, "Both panels disable shadows")
	before.free()
	after.free()

func _run_case(case_id: String, before: bool) -> void:
	var stage := Control.new()
	stage.size = Vector2(PROOF_SIZE)
	stage.theme = load("res://themes/default_theme.tres")
	# Keep both samples at the same presentation instant, including button FX.
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	_view.add_child(stage)
	var background := ColorRect.new()
	background.color = Palette.INK_0
	background.size = Vector2(PROOF_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(background)
	var surface: Control
	if case_id.begins_with("map"):
		surface = (_before_scripts["scripts/labyrinth_map_view.gd"] as GDScript).new() if before else MapView.new()
	elif case_id.begins_with("skills"):
		surface = (_before_scripts["scripts/skill_tree_view.gd"] as GDScript).new() if before else SkillView.new()
	else:
		surface = (_before_scripts["panel"] as GDScript).new() if before else SectionPanel.new()
		if before:
			surface.set("NodeButton", _before_scripts["scripts/section_map_node.gd"])
			surface.set("LegacyMap", _before_scripts["scripts/labyrinth_map_view.gd"])
	surface.position = PROOF_INSET
	surface.size = Vector2(PROOF_SIZE) - PROOF_INSET * 2.0
	stage.add_child(surface)
	if case_id.begins_with("map"):
		surface.call("set_run_state", _map_state())
		surface.call("center_on_current", true)
	elif case_id.begins_with("skills"):
		surface.call("configure", {"mode": "view", "owned_ids": [OWNED_SKILL], "required_count": SKILL_REQUIRED_COUNT, "unspent_points": SKILL_POINTS, "editing_enabled": true, "focused_id": OWNED_SKILL})
	else:
		surface.call("set_run_state", _section_state())
	await _settle()
	_check(Typography.ui_scale(surface) == 1.0, case_id + " uses 100% UI scale")
	if case_id.begins_with("map"):
		_check(Typography.default_font(surface) == surface.get_theme_default_font(), "Typography helper retains the theme font")
		var visible_rooms: Array = surface.call("_visible_rooms")
		var types: Dictionary = {}
		for room: Dictionary in visible_rooms:
			types[str(room["type"])] = true
		_check(types.size() == 6, "Map includes start, combat, campfire, treasure, Scavenger and boss")
		if case_id == "map_hover":
			var event := InputEventMouseMotion.new()
			event.position = surface.call("_coord_position", MAP_HOVER_COORD)
			surface.call("_gui_input", event)
			_check(surface.get("_hover_coord") == MAP_HOVER_COORD, "Pointer motion opens the map hover card")
			_check(surface.call("_room_is_onscreen", surface.call("_room_at", MAP_HOVER_COORD)), "Hovered room is on screen")
	elif case_id.begins_with("skills"):
		var focus_id: String = OWNED_SKILL if case_id == "skills_owned" else (AVAILABLE_SKILL if case_id == "skills_selected" else LOCKED_SKILL)
		surface.call("focus_skill", focus_id)
		_check(int(surface.call("node_count")) == SkillLibrary.visible_ids().size(), "Every skill node is present")
		_check(surface.call("status_for_skill", OWNED_SKILL) == "owned", "Unlocked skill is present")
		_check(surface.call("status_for_skill", AVAILABLE_SKILL) == "available", "Available skill is present")
		_check(surface.call("status_for_skill", LOCKED_SKILL) == "locked", "Locked skill is present")
		_check(surface.call("visual_state_for_skill", focus_id) == "selected", "Selected skill is emphasized")
	else:
		var buttons: Dictionary = surface.get("node_buttons")
		var states: Dictionary = {}
		for button: Control in buttons.values():
			button.set("pulse_phase", FROZEN_PULSE_PHASE)
			button.queue_redraw()
			states[str(button.get("route_state"))] = true
		_check(states.has("visited") and states.has("current") and states.has("reachable"), "Section shows visited, current and available rooms")
		if case_id == "section_focus":
			var choices: Array = surface.call("available_destinations")
			_check(not choices.is_empty(), "Section has a focusable destination")
			if not choices.is_empty():
				var button: Control = buttons[choices[0]]
				button.grab_focus()
				_check(_view.gui_get_focus_owner() == button, "Section destination retains native focus")
				_check(surface.get("selected_coord") == choices[0], "Focus opens the section preview")
	await _settle()
	if not _headless_check:
		await _capture(case_id, before)
	stage.free()
	await process_frame

func _map_state() -> Dictionary:
	var coords: Array = MAP_PATH.duplicate()
	coords.append_array([MAP_HOVER_COORD, MAP_BOSS_COORD, MAP_BLOCKED_COORD])
	var rooms: Dictionary = {}
	for index: int in range(coords.size()):
		var coord: Vector2i = coords[index]
		rooms[Graph.key(coord)] = {"coord": coord, "depth": mini(index, MAP_PATH.size()), "type": MAP_TYPES[index], "element": "fire" if MAP_TYPES[index] == "combat" else "none", "revealed": true, "visited": index < MAP_PATH.size(), "cleared": index < MAP_PATH.size(), "sealed": index == coords.size() - 1, "connections": []}
	for index: int in range(MAP_PATH.size() - 1):
		_connect_rooms(rooms, coords[index], coords[index + 1])
	_connect_rooms(rooms, MAP_PATH.back(), MAP_HOVER_COORD)
	_connect_rooms(rooms, MAP_PATH.back(), MAP_BOSS_COORD)
	_connect_rooms(rooms, MAP_BRANCH_COORD, MAP_BLOCKED_COORD)
	return {"mode": "room", "current_room": MAP_PATH.back(), "rooms": rooms}

func _connect_rooms(rooms: Dictionary, a: Vector2i, b: Vector2i) -> void:
	rooms[Graph.key(a)]["connections"].append({"coord": b})
	rooms[Graph.key(b)]["connections"].append({"coord": a})

func _section_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(SECTION_SEED, Progression.default_data())
	for step: int in range(SECTION_STEPS):
		var current: Dictionary = Graph.room(state, state["current_room"])
		current["cleared"] = true
		current["sealed"] = true
		state["current_room"] = current["connections"][0]["coord"]
		var next: Dictionary = Graph.room(state, state["current_room"])
		Graph.resolve_mystery(state, next)
		next["visited"] = true
		next["cleared"] = true
		Graph.refresh_knowledge(state)
	return state

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(case_id: String, before: bool) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _view.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Renderer produced " + case_id)
	if image == null or image.is_empty():
		return
	_check(image.get_size() == PROOF_SIZE, "Exact capture size: " + case_id)
	image.convert(Image.FORMAT_RGBA8)
	var path: String = OUTPUT.path_join(case_id + ("_before.png" if before else "_after.png"))
	_check(image.save_png(path) == OK, "Saved " + path)
	if before:
		_before_images[case_id] = image
	else:
		var reference: Image = _before_images.get(case_id)
		var identical: bool = reference != null and reference.get_data() == image.get_data()
		_comparisons.append({"case": case_id, "byte_identical": identical})
		_check(identical, "Zero differing pixel bytes: " + case_id)

func _write_contract() -> void:
	var required: Array[Dictionary]
	for case_id: String in CASES:
		for phase: String in ["before", "after"]:
			required.append({"pattern": "%s_%s.png" % [case_id, phase], "width": PROOF_SIZE.x, "height": PROOF_SIZE.y})
	_write_json(CONTRACT, {"min_images": CASES.size() * 2, "expected_sizes": ["1920x1080"], "required_images": required})

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Write " + path)
	if file != null:
		file.store_string(JSON.stringify(value, "\t") + "\n")

func _finish() -> void:
	var result: Dictionary = {"base_commit": BASE_COMMIT, "source_hashes": _source_hashes, "fixture_cases": CASES.size() * 2, "pixel_proof": not _headless_check, "comparisons": _comparisons, "errors": _errors}
	if not _headless_check:
		_check(_comparisons.size() == CASES.size(), "All capture pairs were compared")
	_write_json(OUTPUT.path_join("fixtures.json" if _headless_check else "pixel_identity.json"), result)
	print(ProjectSettings.globalize_path(OUTPUT))
	print("UI02 %s RESULT: %s" % ["FIXTURE" if _headless_check else "PIXEL IDENTITY", "PASS" if _errors.is_empty() else "FAIL"])
	quit(0 if _errors.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_errors.append(message)
		push_error(message)
