extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR := "user://probes/aoe_targeting_preview_v2"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const BOARD_PATH := "BoardUnderlay/CombatBoard"
const PLAYER_TILE := Vector2i(2, 4)
const AIM_TILE := Vector2i(4, 4)

var _capture_viewport: SubViewport
var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://aoe_targeting_preview_progression.json")
	ProgressionStore.set_run_storage_path("user://aoe_targeting_preview_run.save")
	SettingsStore.set_storage_path("user://aoe_targeting_preview_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()
	await _capture_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("AOE TARGETING PREVIEW PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AOE TARGETING PREVIEW PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_states() -> void:
	_assert_complete_aimed_pattern_inventory()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "AOE targeting proof should load the production run scene")
	if packed == null:
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "AoeTargetingPreview1920x1080"
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	instance.set("_settings", settings)
	_resolve_contextual_prompts(instance)
	await _capture_single_target_reference(instance)
	await _capture_aoe_idle_reference(instance)
	await _capture_aoe_card(
		instance,
		"cinderburst",
		"10_center_cross.png",
		_aimed_tiles([Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])
	)
	await _capture_aoe_card(
		instance,
		"rime_shard",
		"20_line2_east.png",
		_aimed_tiles([Vector2i(0, 0), Vector2i(1, 0)]),
		"21_line2_north.png",
		_aimed_tiles([Vector2i(0, 0), Vector2i(0, -1)])
	)
	await _capture_aoe_card(
		instance,
		"thunderline",
		"30_line3_east.png",
		_aimed_tiles([Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]),
		"31_line3_north.png",
		_aimed_tiles([Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)])
	)
	await _capture_aoe_card(
		instance,
		"squall_shot",
		"40_sparse_corner_east.png",
		_aimed_tiles([Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2)]),
		"41_sparse_corner_north.png",
		_aimed_tiles([Vector2i(0, 0), Vector2i(0, -2), Vector2i(2, 0)])
	)
	await _capture_aoe_card(
		instance,
		"wildfire_halo",
		"50_large_halo.png",
		_aimed_tiles([
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		])
	)
	instance.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	_capture_viewport = null
	await process_frame


func _capture_single_target_reference(instance: Node) -> void:
	await _install_combat_fixture(instance, "bone_dart", 9900)
	await _arm_printed_card(instance)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle()
	var board: Control = instance.get_node_or_null(BOARD_PATH) as Control
	_expect(board != null, "Single-target reference should expose the production combat board")
	if board != null:
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var effect: Dictionary = presentation.get("effect", {}) as Dictionary
		_expect(str(effect.get("kind", "")) == "ranged", "Single-target reference should use the ranged preview")
		_expect(bool(effect.get("preview", false)), "Single-target reference should remain a preview")
		_expect(not bool(presentation.get("player_aoe_preview_active", false)), "Single-target reference should retain its ordinary attack-target treatment")
	await _save_screenshot("%s/00_single_target.png" % OUTPUT_DIR)
	instance.call("_on_cancel_requested")
	await _settle()


func _capture_aoe_idle_reference(instance: Node) -> void:
	await _install_combat_fixture(instance, "cinderburst", 9905)
	await _arm_printed_card(instance)
	instance.call("_on_board_tile_hovered", Vector2i(-1, -1))
	await _settle()
	_assert_aoe_legal_centers_visible(instance, "before hover")
	await _save_screenshot("%s/05_legal_aoe_centers.png" % OUTPUT_DIR)
	instance.call("_on_board_tile_hovered", AIM_TILE)
	await _settle()
	var board: Control = instance.get_node_or_null(BOARD_PATH) as Control
	_expect(
		board != null and bool((board.get("presentation") as Dictionary).get("player_aoe_preview_active", false)),
		"A valid AOE hover should switch from legal centers to the concrete footprint"
	)
	instance.call("_on_board_tile_hovered", Vector2i(-1, -1))
	await _settle()
	_assert_aoe_legal_centers_visible(instance, "after pointer exit")
	instance.call("_on_cancel_requested")
	await _settle()


func _assert_aoe_legal_centers_visible(instance: Node, context: String) -> void:
	var board: Control = instance.get_node_or_null(BOARD_PATH) as Control
	_expect(board != null, "AOE %s should expose the production combat board" % context)
	if board == null:
		return
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var active_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var legal_targets: Array = active_preview.get("target_tiles", []) as Array
	_expect(not legal_targets.is_empty(), "AOE %s should retain discoverable legal centers" % context)
	_expect(
		_same_tiles(board.get("attack_tiles") as Array, legal_targets),
		"AOE %s should submit every legal center to the board" % context
	)
	_expect((presentation.get("focus_tiles", []) as Array).is_empty(), "AOE %s should not imply a footprint" % context)
	_expect((presentation.get("effect", {}) as Dictionary).is_empty(), "AOE %s should not draw a cast path" % context)
	_expect(not bool(presentation.get("player_aoe_preview_active", false)), "AOE %s should keep legal-center guidance visible" % context)
	_expect(not bool(presentation.get("pulse_attack_tiles", false)), "AOE legal centers should remain static")


func _capture_aoe_card(
	instance: Node,
	card_id: String,
	east_file: String,
	east_tiles: Array,
	north_file: String = "",
	north_tiles: Array = []
) -> void:
	await _install_combat_fixture(instance, card_id, 9910 + card_id.length())
	await _arm_printed_card(instance)
	instance.call("_on_board_tile_hovered", AIM_TILE)
	await _settle()
	_assert_aoe_preview(instance, card_id, east_tiles, "east")
	await _save_screenshot("%s/%s" % [OUTPUT_DIR, east_file])
	if not north_file.is_empty():
		instance.call("_rotate_aoe_aim", -1)
		instance.call("_on_board_tile_hovered", AIM_TILE)
		await _settle()
		_assert_aoe_preview(instance, card_id, north_tiles, "north")
		await _save_screenshot("%s/%s" % [OUTPUT_DIR, north_file])
	instance.call("_on_cancel_requested")
	await _settle()


func _assert_aoe_preview(instance: Node, card_id: String, expected_tiles: Array, direction: String) -> void:
	var board: Control = instance.get_node_or_null(BOARD_PATH) as Control
	_expect(board != null, "%s %s proof should expose the production combat board" % [card_id, direction])
	if board == null:
		return
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var effect: Dictionary = presentation.get("effect", {}) as Dictionary
	var focus_tiles: Array = presentation.get("focus_tiles", []) as Array
	var effect_tiles: Array = effect.get("tiles", []) as Array
	var active_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var active_action: Dictionary = active_preview.get("action", {}) as Dictionary
	var legal_targets: Array = active_preview.get("target_tiles", []) as Array
	_expect(
		str(effect.get("kind", "")) == "aoe",
		"%s %s should render an AOE preview (effect=%s, action=%s, pending=%d, label=%s)" % [
			card_id,
			direction,
			effect,
			active_action,
			int(instance.get("_pending_action_index")),
			str(instance.get("_selected_card_label_override")),
		]
	)
	_expect(bool(effect.get("preview", false)), "%s %s should remain a non-committing preview" % [card_id, direction])
	_expect(
		bool(presentation.get("player_aoe_preview_active", false))
		and bool(board.call("_player_aoe_preview_active")),
		"%s %s should suppress the broad legal-center wash while its footprint is active" % [card_id, direction]
	)
	_expect(
		_same_tiles(board.get("attack_tiles") as Array, legal_targets),
		"%s %s should preserve its legal centers as interaction data while hiding their paint" % [card_id, direction]
	)
	_expect(
		legal_targets.has(AIM_TILE) and legal_targets.size() > expected_tiles.size(),
		"%s %s should keep a larger legal-center set behind the focused footprint" % [card_id, direction]
	)
	_expect(
		(instance.get("_pending_target_tiles") as Array).has(AIM_TILE),
		"%s %s should keep the focused center legal for confirmation" % [card_id, direction]
	)
	_expect(
		_same_tiles(focus_tiles, expected_tiles),
		"%s %s focus should preserve its complete authored pattern: %s" % [card_id, direction, focus_tiles]
	)
	_expect(
		_same_tiles(effect_tiles, expected_tiles),
		"%s %s effect payload should preserve its complete authored pattern: %s" % [card_id, direction, effect_tiles]
	)
	_expect(
		not bool(board.call("_preview_effect_needs_continuous_redraw", effect)),
		"%s %s targeting should stay static like direct ranged targeting" % [card_id, direction]
	)


func _install_combat_fixture(instance: Node, card_id: String, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
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
	combat_state["traps"] = []
	combat_state["terrain"] = []
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		enemy["hp"] = 100
		enemy["max_hp"] = 100
		enemy["block"] = 0
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = false
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	_resolve_contextual_prompts(instance)
	await _settle()


func _arm_printed_card(instance: Node) -> void:
	await instance.call("_on_card_pressed", 0)
	await _settle()
	if int(instance.get("_card_action_choice_index")) == 0:
		await instance.call("_on_card_action_choice_pressed", "play")
		await _settle()
	_expect(int(instance.get("_selected_card_index")) == 0, "Probe card should enter its printed targeting flow")


func _resolve_contextual_prompts(instance: Node) -> void:
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")


func _assert_complete_aimed_pattern_inventory() -> void:
	var observed: Dictionary = {}
	for card_var: Variant in GameData.cards().values():
		if typeof(card_var) != TYPE_DICTIONARY:
			continue
		for action_var: Variant in (card_var as Dictionary).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) != "aoe" or int(action.get("range", 0)) <= 0:
				continue
			observed[_pattern_signature(action)] = true
	var expected: Dictionary = {}
	for card_id: String in ["cinderburst", "rime_shard", "thunderline", "squall_shot", "wildfire_halo"]:
		for action_var: Variant in GameData.card_def(card_id).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) > 0:
				expected[_pattern_signature(action)] = true
	_expect(
		observed.size() == expected.size(),
		"AOE targeting proof should cover every unique aimed pattern (observed %d, covered %d)" % [observed.size(), expected.size()]
	)
	for signature: String in observed.keys():
		_expect(expected.has(signature), "AOE targeting proof is missing aimed pattern %s" % signature)


func _pattern_signature(action: Dictionary) -> String:
	var offsets: Array = []
	for offset_var: Variant in action.get("pattern", []):
		if typeof(offset_var) != TYPE_ARRAY or (offset_var as Array).size() < 2:
			continue
		var offset: Array = offset_var as Array
		offsets.append("%d:%d" % [int(offset[0]), int(offset[1])])
	offsets.sort()
	return "%s|%s" % ["rotate" if bool(action.get("rotate", false)) else "fixed", ";".join(PackedStringArray(offsets))]


func _aimed_tiles(offsets: Array) -> Array:
	var tiles: Array = []
	for offset_var: Variant in offsets:
		if typeof(offset_var) == TYPE_VECTOR2I:
			tiles.append(AIM_TILE + (offset_var as Vector2i))
	return tiles


func _same_tiles(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for tile: Variant in expected:
		if not actual.has(tile):
			return false
	return true


func _room_layout() -> Dictionary:
	var enemy_positions: Array = [
		Vector2i(5, 4),
		Vector2i(4, 2),
		Vector2i(6, 4),
		Vector2i(4, 6),
		Vector2i(6, 2),
	]
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 100,
			"max_hp": 100,
			"block": 0,
		})
	return {
		"name": "AOE Targeting Preview Proof",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"umbra_stage": "clear",
		"grid": _simple_grid(),
		"player_start": PLAYER_TILE,
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": [],
	}


func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid


func _save_screenshot(output_path: String) -> void:
	if _capture_viewport == null:
		_expect(false, "Screenshot viewport should exist for %s" % output_path.get_file())
		return
	RenderingServer.force_draw()
	await process_frame
	var image: Image = _capture_viewport.get_texture().get_image()
	_expect(image != null, "AOE targeting proof should capture %s" % output_path.get_file())
	if image == null:
		return
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should render at 1920x1080" % output_path.get_file())
	_expect(image.save_png(output_path) == OK, "Should save %s" % output_path.get_file())


func _settle() -> void:
	await process_frame
	await process_frame


func _clear_probe_output() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
