extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const OUTPUT_DIR: String = "user://probes/move_attack_shortcut_v4"
const PROBE_VIEWPORT := Vector2i(1920, 1080)
const PLAYER_TILE := Vector2i(2, 4)


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://labyrinth_progression_move_attack_shortcut_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_move_attack_shortcut_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_move_melee_shortcut("slipstream_cut", "clear", Vector2i(5, 4), "slipstream_cut_move_or_enemy_targets_v4.png", true)
	await _capture_move_melee_shortcut("sidestep_slash", "heart", Vector2i(4, 4), "sidestep_slash_umbra_move_or_enemy_targets_v4.png", false)
	await _capture_move_only_pickup_route()
	await _capture_empty_center_aoe()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _capture_move_melee_shortcut(card_id: String, umbra_stage: String, enemy_tile: Vector2i, screenshot_name: String, expect_force_preview: bool) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "%s proof should load RunScene" % card_id)
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var combat := CombatEngine.new()
	var layout: Dictionary = _combat_layout(umbra_stage, enemy_tile)
	var combat_state: Dictionary = combat.create_combat(86000 + enemy_tile.x, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	_resolve_contextual_prompts(instance)
	await _settle_ui()

	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	instance.call("_on_board_tile_hovered", enemy_tile)
	await _settle_ui()
	var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var path_tiles: Array = presentation.get("path_tiles", []) as Array
	var effect: Dictionary = presentation.get("effect", {}) as Dictionary
	_expect((board.get("attack_tiles") as Array).has(enemy_tile), "%s should highlight the enemy as a one-click move-melee target" % card_id)
	_expect(not (board.get("move_tiles") as Array).is_empty(), "%s should retain move-only destinations beside its enemy shortcut" % card_id)
	_expect(not bool(instance.call("_current_action_can_skip")), "%s should not expose an extra movement-skip click" % card_id)
	_expect(path_tiles.size() >= 2, "%s should display a multi-tile movement route arrow while the enemy is hovered" % card_id)
	_expect(path_tiles[0] == PLAYER_TILE, "%s movement route arrow should begin at the player" % card_id)
	_expect(path_tiles[path_tiles.size() - 1] != enemy_tile, "%s movement route arrow should end on its adjacent attack position" % card_id)
	_expect(path_tiles.has(Vector2i(3, 4)), "%s should preview the minimum movement path into melee range" % card_id)
	_expect(str(effect.get("kind", "")) == "melee", "%s should preview melee damage before the click" % card_id)
	_expect(not (effect.get("damage_preview", {}) as Dictionary).is_empty(), "%s should preview follow-up melee damage" % card_id)
	if expect_force_preview:
		_expect(not (effect.get("force_tiles", []) as Array).is_empty(), "%s should preview the default push direction that its one-click shortcut will use" % card_id)
	else:
		_expect(str(presentation.get("umbra_stage", "")) == "heart", "%s proof should retain the authored Heart Umbra" % card_id)
	await _save_root_screenshot("%s/%s" % [OUTPUT_DIR, screenshot_name])

	await instance.call("_on_board_tile_clicked", enemy_tile)
	var resolved_state: Dictionary = instance.get("_combat_state") as Dictionary
	var resolved_enemy: Dictionary = (resolved_state.get("enemies", []) as Array)[0] as Dictionary
	_expect(int(resolved_enemy.get("hp", 100)) < 100, "%s enemy click should resolve melee damage" % card_id)
	_expect(int(instance.get("_selected_card_index")) < 0, "%s enemy click should finish without another target confirmation" % card_id)
	instance.queue_free()
	await process_frame


func _capture_move_only_pickup_route() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var combat := CombatEngine.new()
	var goal := Vector2i(5, 4)
	var gear_tile := Vector2i(3, 3)
	var trap_tile := Vector2i(3, 4)
	var layout: Dictionary = _combat_layout("clear", Vector2i(7, 2))
	layout["loot"] = [{"id": "route_gear", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": gear_tile, "claimed": false}]
	layout["traps"] = [{"id": "route_trap", "pos": trap_tile, "element": "fire", "damage": 2, "triggered": false}]
	var state: Dictionary = combat.create_combat(86077, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": ["threaded_path"], "relics": [], "hand_size": 1, "heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["threaded_path"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_refresh_ui")
	_resolve_contextual_prompts(instance)
	await _settle_ui()
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	instance.call("_on_board_tile_hovered", goal)
	await _settle_ui()
	var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var path_tiles: Array = ((board.get("presentation") as Dictionary).get("path_tiles", []) as Array)
	_expect((board.get("move_tiles") as Array).has(goal), "Move-only cards should expose the destination tile")
	_expect(path_tiles.has(gear_tile), "Move-only routes should visibly detour through useful gear when range permits")
	_expect(not path_tiles.has(trap_tile), "Move-only routes should visibly avoid an avoidable trap")
	await _save_root_screenshot("%s/threaded_path_pickup_safe_route_v4.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame


func _capture_empty_center_aoe() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var combat := CombatEngine.new()
	var center := Vector2i(4, 4)
	var layout: Dictionary = _combat_layout("clear", Vector2i(5, 4))
	layout["name"] = "Empty-center AOE Proof"
	layout["element"] = "fire"
	layout["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 100, "max_hp": 100, "block": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 3), "hp": 100, "max_hp": 100, "block": 0},
	]
	var state: Dictionary = combat.create_combat(86088, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": ["ember_rain"], "relics": [], "hand_size": 1, "heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["ember_rain"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_refresh_ui")
	_resolve_contextual_prompts(instance)
	await _settle_ui()
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	instance.call("_on_board_tile_hovered", center)
	await _settle_ui()
	var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var focus_tiles: Array = presentation.get("focus_tiles", []) as Array
	_expect((board.get("attack_tiles") as Array).has(center), "Ember Rain should allow its cross pattern to anchor on an empty tile")
	_expect(focus_tiles.has(Vector2i(5, 4)) and focus_tiles.has(Vector2i(4, 3)), "The empty-center preview should show both enemies inside Ember Rain's cross")
	await _save_root_screenshot("%s/ember_rain_empty_center_v4.png" % OUTPUT_DIR)
	await instance.call("_on_board_tile_clicked", center)
	var resolved_state: Dictionary = instance.get("_combat_state") as Dictionary
	var resolved_enemies: Array = resolved_state.get("enemies", []) as Array
	_expect(resolved_enemies.size() == 2 and int((resolved_enemies[0] as Dictionary).get("hp", 100)) < 100 and int((resolved_enemies[1] as Dictionary).get("hp", 100)) < 100, "An empty-center Ember Rain should damage enemies on the other pattern squares")
	var light_sources: Array = (resolved_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	_expect(not light_sources.is_empty() and (light_sources[0] as Dictionary).get("pos", Vector2i(-1, -1)) == center, "Ember Rain should create Light at the selected empty center")
	_expect(int(instance.get("_selected_card_index")) < 0, "The empty-center AOE click should finish the card")
	instance.queue_free()
	await process_frame


func _resolve_contextual_prompts(instance: Node) -> void:
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")


func _combat_layout(umbra_stage: String, enemy_tile: Vector2i) -> Dictionary:
	return {
		"name": "Move Melee Shortcut Proof",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "air",
		"umbra_stage": umbra_stage,
		"grid": _open_grid(),
		"player_start": PLAYER_TILE,
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": enemy_tile,
			"hp": 100,
			"max_hp": 100,
			"block": 0
		}],
		"traps": [],
		"terrain": [],
		"loot": []
	}


func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid


func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame


func _save_root_screenshot(output_path: String) -> void:
	_expect(DisplayServer.get_name() != "headless", "Move-melee shortcut proof requires the real renderer")
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
	_expect(image != null, "Move-melee shortcut proof should capture a renderer image")
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	var proportional: bool = is_equal_approx(scale_x, scale_y) and is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	_expect(proportional, "Move-melee shortcut proof should preserve the 1920x1080 aspect ratio, got %s" % source_size)
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(output_path) == OK, "Move-melee shortcut proof should save %s" % output_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _clear_probe_output(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
