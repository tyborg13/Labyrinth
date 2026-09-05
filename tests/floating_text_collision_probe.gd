extends SceneTree
const CombatEngine = preload("res://scripts/combat_engine.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const OUTPUT_DIR: String = "user://floating_text_collision_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://floating_collision_progression.json")
	ProgressionStore.set_run_storage_path("user://floating_collision_run.save")
	SettingsStore.set_storage_path("user://floating_collision_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_load_run_state", RunEngine.new().create_new_run(62001, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await _load_combat_fixture(instance, 62001)
	await _settle()
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard")
	board.set_process(false)
	var base_entries: Array = []
	var values: Array[String] = ["-14", "-10", "-12"]
	var targets: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4)]
	for index: int in range(targets.size()):
		base_entries.append(FloatingCombatText.damage_entry(targets[index], "-3", Color("f0c85c")))
		base_entries.append(FloatingCombatText.damage_entry(targets[index], values[index], Color("f39779")))
	for reduced: bool in [false, true]:
		settings["reduced_motion"] = reduced
		instance.set("_settings", settings)
		var state: Dictionary = instance.get("_combat_state") as Dictionary
		instance.call("_render_board_state", state, {"floating_texts": []})
		await _settle()
		var previous_offsets: Dictionary = {}
		for elapsed: float in [0.0, 0.08, 0.16, 0.30, 0.42]:
			var entries: Array[Dictionary] = FloatingCombatText.animate_entries(base_entries, elapsed, reduced)
			instance.call("_render_board_state", state, {"floating_texts": entries, "reduced_motion": reduced})
			await _settle()
			var layer: Control = board.get("_effects_render_layer") as Control
			var layouts: Array = layer.get("_floating_text_last_layout") as Array
			_expect(layouts.size() == entries.size(), "Every active result must remain rendered without being delayed or suppressed")
			for index: int in range(layouts.size()):
				var popup: Dictionary = layouts[index]
				var envelope: Rect2 = popup["rendered_rect"]
				var offset: Vector2 = popup["layout_offset"]
				var rect := Rect2(envelope.position + offset, envelope.size)
				for health_var: Variant in (layer.get("_hud_health_rects_cache") as Dictionary).values():
					_expect(not rect.intersects(health_var as Rect2), "Health bars must not paint over floating results")
				var key: String = str(popup["key"])
				if previous_offsets.has(key):
					_expect((previous_offsets[key] as Vector2).is_equal_approx(offset), "Popup lanes must stay stable through stagger and font settling")
				previous_offsets[key] = offset
				_expect(absf(offset.y) <= 160.0, "Dense results must remain close to their actors")
				_expect(absf(offset.x) <= 24.0, "Labels must stay associated with their actors")
				for other_index: int in range(index):
					var other: Dictionary = layouts[other_index]
					var other_envelope: Rect2 = other["rendered_rect"]
					var other_rect := Rect2(other_envelope.position + (other["layout_offset"] as Vector2), other_envelope.size)
					_expect(not rect.intersects(other_rect), "Simultaneous damage and block-loss glyphs must not overlap")
			await RenderingServer.frame_post_draw
			var screenshot: Image = viewport.get_texture().get_image()
			_expect(screenshot.get_size() == VIEWPORT_SIZE, "Proof must render at 1920x1080")
			_expect(screenshot.save_png("%s/%s_%03d.png" % [OUTPUT_DIR, "reduced" if reduced else "normal", roundi(elapsed * 1000)]) == OK, "Screenshot must save")
	for error: String in _errors:
		push_error(error)
	print("FLOATING TEXT COLLISION PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _settle() -> void:
	for frame: int in range(5):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _load_combat_fixture(instance: Node, seed: int) -> void:
	var layout: Dictionary = {
		"name": "Sealed Hall",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"element": "fire",
		"grid": _combat_grid(),
		"player_start": Vector2i(1, 3),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 40, "max_hp": 40, "block": 3},
			{"id": 2, "type": "harrier", "pos": Vector2i(5, 3), "hp": 40, "max_hp": 40, "block": 3},
			{"id": 3, "type": "acolyte", "pos": Vector2i(4, 4), "hp": 40, "max_hp": 40, "block": 3}
		],
		"loot": [{"id": "vial", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(5, 4)}],
		"traps": [{"id": "trap", "element": "fire", "pos": Vector2i(4, 3), "damage": 3, "armed": true}],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(5, 2), "hp": 8, "max_hp": 8}]
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 30,
		"max_hp": 30,
		"deck_cards": ["quick_stab", "guarded_step", "lantern_shot", "brace", "bone_dart"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "guarded_step", "lantern_shot", "brace", "bone_dart"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	var rooms: Dictionary = (run_state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["2,0"] = {"type": "combat", "coord": Vector2i(2, 0), "revealed": true, "visited": true}
	run_state["rooms"] = rooms
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	for tile: Vector2i in [Vector2i(1, 1), Vector2i(7, 1), Vector2i(1, 5), Vector2i(7, 5), Vector2i(5, 1)]:
		grid[tile.y][tile.x] = "pillar"
	return grid

