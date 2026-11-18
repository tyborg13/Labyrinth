extends SceneTree
## Measures the live board HUD after a production hover; native runs also save PNGs.
const Badges = preload("res://scripts/intent_badges.gd")
const BurstText = preload("res://scripts/enemy_mechanics/burst_trait_text.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 7262026
const FIXTURE_DEPTH: int = 4
const RESOLUTION_PROTECTION_HP: int = 999
const HEADLESS_SETTLE_FRAMES: int = 2
const NATIVE_SETTLE_FRAMES: int = 12
const CATALOG_SIZE: int = 8
const CATALOG_ENEMY_TILE := Vector2i(3, 3)
const CATALOG_PLAYER_TILE := Vector2i(3, 5)
const CATALOG_ENEMY_ID: int = 1
const BOSS_ENEMY_INDEX: int = 0
const FIRST_CHARGE: int = 0
const LAST_CHARGE: int = 3
const OUTPUT: String = "user://probes/pol48"

var _scene: Node
var _board: Control
var _canvas: SubViewport
var _failures: int = 0
var _overlaps: int = 0
var _measurements: int = 0
var _catalog_foes: PackedStringArray
var _catalog_affected: PackedStringArray

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://pol48_profile.json")
	Store.set_run_storage_path("user://pol48_run.save")
	Settings.set_storage_path("user://pol48_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	_canvas = SubViewport.new()
	_canvas.size = SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.msaa_2d = root.msaa_2d
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	for _frame: int in range(NATIVE_SETTLE_FRAMES):
		await process_frame
	_board = _scene.get("board_view")
	var run: Dictionary = _summoned_wisp_fixture()
	var state: Dictionary = run["combat_state"]
	var wisp_ids: Array[int]
	for enemy: Dictionary in state["enemies"]:
		if str(enemy["type"]) == "lightning_wisp" and int(enemy["hp"]) > 0:
			wisp_ids.append(int(enemy["id"]))
	_check(not wisp_ids.is_empty(), "Call Wisps summoned live Lightning Wisps")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(SIZE)
	for id: int in wisp_ids:
		var index: int = Combat.new()._enemy_index_for_id(state, id)
		var enemy: Dictionary = state["enemies"][index]
		for intent: Dictionary in Data.enemy_def("lightning_wisp")["intents"]:
			enemy["intent"] = intent.duplicate(true)
			for charge: int in range(FIRST_CHARGE, LAST_CHARGE + 1):
				enemy["charge"] = charge
				await _hover(run, enemy["pos"])
				var label: String = "zek_%d_%s_charge_%d" % [id, intent["id"], charge]
				_check(_measure(label, "enemy_%d" % id), "Wisp hover has a live title and disc: " + label)
				if charge == FIRST_CHARGE and DisplayServer.get_name() != "headless":
					await _capture(label)
	if OS.get_cmdline_user_args().has("--catalog"):
		await _measure_catalog(run, Data.enemies().keys())
		print("POL48 FOES WITH DISCS (%d): %s" % [_catalog_foes.size(), ", ".join(_catalog_foes)])
		print("POL48 FOES WITH OVERLAP (%d): %s" % [_catalog_affected.size(), ", ".join(_catalog_affected)])
	elif DisplayServer.get_name() != "headless":
		await _measure_catalog(run, ["burrow_grub"])
	_scene.queue_free()
	_canvas.queue_free()
	await process_frame
	print("POL48 GEOMETRY: %d measured, %d overlapping, %d fixture errors" % [_measurements, _overlaps, _failures])
	var measure_only: bool = OS.get_cmdline_user_args().has("--measure-only")
	quit(0 if _failures == 0 and (measure_only or _overlaps == 0) else 1)

func _summoned_wisp_fixture() -> Dictionary:
	var options: Dictionary = {"seed": FIXTURE_SEED, "dragon_id": "zekarion", "dragon_depth": FIXTURE_DEPTH, "dragon_build": "balanced"}
	var engine := Run.new()
	var combat := Combat.new()
	var run: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
	var state: Dictionary = run["combat_state"]
	var player: Dictionary = state["player"].duplicate(true)
	state["player"]["hp"] = RESOLUTION_PROTECTION_HP
	state["player"]["max_hp"] = RESOLUTION_PROTECTION_HP
	for intent_id: String in ["skybreak", "storm_claw", "call_wisps"]:
		_check(str(state["enemies"][BOSS_ENEMY_INDEX]["intent"]["id"]) == intent_id, "Zekarion intent: " + intent_id)
		state["turn"] = int(state["turn"]) + 1
		state = combat.resolve_enemy_turn_with_steps(state, BOSS_ENEMY_INDEX)["state"]
	state["player"]["hp"] = player["hp"]
	state["player"]["max_hp"] = player["max_hp"]
	run["combat_state"] = state
	for prompt: String in Tutorial.prompt_ids():
		run["progression"] = Tutorial.resolve_progression(run["progression"], prompt)
	return run

func _hover(run: Dictionary, tile: Vector2i) -> void:
	_scene.set("_progression", run["progression"].duplicate(true))
	_scene.call("_load_run_state", run.duplicate(true))
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	await process_frame
	# A just-mounted stage can submit before the board has its fitted size.
	for _frame: int in range(NATIVE_SETTLE_FRAMES):
		if float(_board.call("_tile_width")) >= Badges.MEDALLION_DIAMETER: break
		await process_frame
	_check(float(_board.call("_tile_width")) >= Badges.MEDALLION_DIAMETER, "Hover fixture has a fitted board")
	_board.call("_update_hover_at", _board.call("world_position_for_tile", tile))
	var settle_frames: int = HEADLESS_SETTLE_FRAMES if DisplayServer.get_name() == "headless" else NATIVE_SETTLE_FRAMES
	for _frame: int in range(settle_frames):
		await process_frame

func _measure_catalog(template: Dictionary, types: Array) -> void:
	var combat := Combat.new()
	var grid: Array = []
	for y: int in range(CATALOG_SIZE):
		var row: Array = []
		for x: int in range(CATALOG_SIZE):
			row.append("wall" if x in [0, CATALOG_SIZE - 1] or y in [0, CATALOG_SIZE - 1] else "stone")
		grid.append(row)
	types.sort()
	for type: String in types:
		var definition: Dictionary = Data.enemy_def(type)
		var hp: int = int(definition.get("max_hp", 1))
		var layout: Dictionary = {"name": "HUD layout fixture", "coord": template["current_room"],
			"type": "combat", "grid": grid, "player_start": CATALOG_PLAYER_TILE,
			"enemies": [{"id": CATALOG_ENEMY_ID, "type": type, "pos": CATALOG_ENEMY_TILE, "hp": hp, "max_hp": hp, "block": 0}],
			"traps": [], "terrain": [], "element": "none"}
		var run: Dictionary = template.duplicate(true)
		run["current_room_layout"] = layout
		var player: Dictionary = (template["combat_state"]["player"] as Dictionary).duplicate(true)
		player["deck_cards"] = run["deck_cards"]
		var state: Dictionary = combat.create_combat(FIXTURE_SEED, layout, player)
		if state.get("enemies", []).is_empty():
			_check(false, "Catalog fixture could not spawn " + type)
			continue
		run["combat_state"] = state
		var enemy: Dictionary = state["enemies"][0]
		var actor_key: String = "enemy_%d" % int(enemy["id"])
		for intent: Dictionary in definition.get("intents", []):
			enemy["intent"] = intent.duplicate(true)
			if type == "storm_capacitor":
				enemy["charge"] = LAST_CHARGE if str(intent["id"]) == "discharge" else FIRST_CHARGE
			await _hover(run, enemy["pos"])
			var label: String = "catalog_%s_%s" % [type, intent["id"]]
			var overlaps_before: int = _overlaps
			if _measure(label, actor_key) and not _catalog_foes.has(type):
				_catalog_foes.append(type)
			if _overlaps > overlaps_before and not _catalog_affected.has(type):
				_catalog_affected.append(type)
			if type == "burrow_grub" and str(intent["id"]) in ["erupt", "gnaw"] and DisplayServer.get_name() != "headless":
				await _capture(label)

func _measure(label: String, actor_key: String) -> bool:
	var layout: Dictionary = {}
	for entry: Dictionary in _board.get("_hud_layout_entries_cache"):
		if str(entry.get("actor_key", "")) == actor_key:
			layout = entry.get("layout", {})
			break
	var rows: Array = layout.get("rows", [])
	var lines: Array = layout.get("line_rects", [])
	if str(layout.get("intent_name", "")).is_empty() or lines.is_empty():
		print("POL48 %s: no live title (hover=%s, mode=%s, visible=%s)" % [label, _board.get("_hover_tile"), _scene.get("_run_state").get("mode"), _board.call("_visible_units").map(func(unit: Dictionary) -> String: return str(unit.get("key", "")))])
		return false
	var title_index: int = BurstText.title_index(rows)
	var title: Rect2 = lines[title_index]
	var presentation: Dictionary = _board.get("presentation")
	var discs: Array[Rect2]
	var own_disc: bool = false
	for badge: Dictionary in Badges.layouts(_board, presentation.get("threats_at_rest", {}).get("badges", [])):
		var own_badge: bool = str(badge["key"]) == actor_key
		own_disc = own_disc or own_badge
		var disc := Rect2((badge["center"] as Vector2) - Vector2.ONE * Badges.MEDALLION_DIAMETER * 0.5, Vector2.ONE * Badges.MEDALLION_DIAMETER)
		for other: Rect2 in discs:
			_check(not other.intersects(disc), "Separate disc hit regions in " + label)
		discs.append(disc)
		var overlap: bool = title.intersects(disc)
		if label.begins_with("catalog_") and not own_badge: continue
		var chip: Rect2 = badge["rect"]
		var chip_overlap: bool = title.intersects(chip)
		_measurements += 1
		_overlaps += int(overlap or chip_overlap)
		print("POL48 %s: %s title %s, %s/%s disc %s, overlap=%s, chip %s, chip_overlap=%s" % [label, layout["intent_name"], title, badge["key"], badge.get("icon", ""), disc, overlap, chip, chip_overlap])
	if not own_disc:
		print("POL48 %s: title %s, no owned disc" % [label, title])
	return own_disc

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _canvas.get_texture().get_image()
	_check(image.get_size() == SIZE and is_equal_approx(root.content_scale_factor, 1.0), "Native 1920x1080 at 100%")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var path: String = OUTPUT.path_join(label + ".png")
	_check(image.save_png(path) == OK, "Saved " + label)
	print(ProjectSettings.globalize_path(path))

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
