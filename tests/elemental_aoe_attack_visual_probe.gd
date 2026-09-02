extends SceneTree

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/elemental_aoe_attack_v2"
const PROBE_VIEWPORT := Vector2i(1920, 1080)
const PLAYER_TILE := Vector2i(2, 4)
const EMPTY_CENTER := Vector2i(4, 4)
const ENEMY_TILE := Vector2i(5, 4)

var _failures: Array[String]


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
	ProgressionStore.set_storage_path("user://labyrinth_progression_elemental_aoe_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_elemental_aoe_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_card("cinderburst", AttackFxLibrary.STYLE_DEFAULT, false, "travel")
	await _capture_card("cinderburst", AttackFxLibrary.STYLE_DEFAULT, false, "impact")
	await _capture_card("molten_reach", AttackFxLibrary.STYLE_FIREBALL, false)
	await _capture_card("rime_shard", AttackFxLibrary.STYLE_ICE_SHARDS, false)
	# Lightning's authored animation is only 0.345 seconds. Capture travel and
	# impact from independent casts so screenshot readback cannot consume the
	# second proof state.
	await _capture_card("thunderline", AttackFxLibrary.STYLE_LIGHTNING_BOLT, false, "travel")
	await _capture_card("thunderline", AttackFxLibrary.STYLE_LIGHTNING_BOLT, false, "impact")
	await _capture_card("rime_shard", AttackFxLibrary.STYLE_ICE_SHARDS, true)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("ELEMENTAL AOE ATTACK VISUAL PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ELEMENTAL AOE ATTACK VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_card(card_id: String, expected_style: String, reduced_motion: bool, capture_phase: String = "both") -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "%s proof should load RunScene" % card_id)
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var combat := CombatEngine.new()
	var layout: Dictionary = _combat_layout(GameData.card_element(card_id))
	var combat_state: Dictionary = combat.create_combat(87200 + card_id.length(), layout, {
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
	combat_state.erase("player_turn_restrictions")
	_install_combat_state(instance, combat_state, layout)
	_resolve_contextual_prompts(instance)
	await _settle_ui()

	var action: Dictionary = _aoe_action_for_card(card_id)
	var after_state: Dictionary = combat.apply_player_action(combat_state.duplicate(true), action, EMPTY_CENTER)
	_expect(_enemy_hp(after_state, 1) < _enemy_hp(combat_state, 1), "%s should damage the enemy beside its empty target center" % card_id)
	instance.call("_animate_player_action_step", combat_state.duplicate(true), after_state, card_id, action, EMPTY_CENTER)
	if reduced_motion:
		var reduced_presentation: Dictionary = await _wait_for_effect(instance, card_id, expected_style, 0.99)
		if not reduced_presentation.is_empty():
			_expect(bool(reduced_presentation.get("reduced_motion", false)), "%s should expose the reduced-motion presentation flag" % card_id)
			await _save_root_screenshot("%s/%s_80_reduced_motion.png" % [OUTPUT_DIR, card_id])
	else:
		if capture_phase in ["both", "travel"]:
			var travel_threshold: float = 0.12 if expected_style == AttackFxLibrary.STYLE_LIGHTNING_BOLT else 0.18
			var travel_presentation: Dictionary = await _wait_for_effect(instance, card_id, expected_style, travel_threshold)
			if not travel_presentation.is_empty():
				await _save_root_screenshot("%s/%s_20_travel.png" % [OUTPUT_DIR, card_id])
		if capture_phase in ["both", "impact"]:
			var impact_threshold: float = 0.52 if expected_style in [AttackFxLibrary.STYLE_DEFAULT, AttackFxLibrary.STYLE_LIGHTNING_BOLT] else 0.62
			var impact_presentation: Dictionary = await _wait_for_effect(instance, card_id, expected_style, impact_threshold)
			if not impact_presentation.is_empty():
				await _save_root_screenshot("%s/%s_40_impact.png" % [OUTPUT_DIR, card_id])
	await create_timer(1.35).timeout
	instance.queue_free()
	await process_frame


func _wait_for_effect(instance: Node, card_id: String, expected_style: String, minimum_progress: float) -> Dictionary:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	_expect(board != null, "%s proof should find the production combat board" % card_id)
	if board == null:
		return {}
	for _frame: int in range(180):
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var effect: Dictionary = presentation.get("effect", {}) as Dictionary
		var progress: float = float(presentation.get("effect_progress", -1.0))
		if (
			str(effect.get("kind", "")) == "aoe"
			and AttackFxLibrary.style_for_effect(effect) == expected_style
			and progress + 0.0001 >= minimum_progress
		):
			_expect(int(effect.get("range", 0)) > 0, "%s should carry its range into production animation" % card_id)
			var expects_authored_elemental: bool = expected_style != AttackFxLibrary.STYLE_DEFAULT
			_expect(
				AttackFxLibrary.uses_authored_elemental_attack(effect) == expects_authored_elemental,
				"%s should preserve its expected authored-elemental animation classification" % card_id
			)
			_expect(
				bool(board.call("_effect_uses_elemental_scene_depth", effect)) == expects_authored_elemental,
				"%s should preserve its expected scene-depth rendering path" % card_id
			)
			_expect(not board.has_method("_draw_target_reticle"), "%s should not retain the legacy resolved target reticle" % card_id)
			_expect(not board.has_method("_draw_aoe_line_effect"), "%s should not retain the legacy resolved line overlay" % card_id)
			_expect(not board.has_method("_draw_aoe_bolt_segment"), "%s should not retain the legacy procedural bolt segments" % card_id)
			var effect_tiles: Array = effect.get("tiles", []) as Array
			_expect(effect_tiles.has(EMPTY_CENTER) and effect_tiles.has(ENEMY_TILE), "%s should preserve its area pattern during the elemental animation" % card_id)
			var footprint_visibility: float = float(board.call("_aoe_resolution_footprint_visibility", effect, progress))
			if bool(presentation.get("reduced_motion", false)):
				_expect(footprint_visibility > 0.0, "%s reduced motion should retain a static resolved footprint" % card_id)
			elif progress < AttackFxLibrary.travel_end_progress(expected_style):
				_expect(is_zero_approx(footprint_visibility), "%s travel should use only its authored projectile, without an early board overlay" % card_id)
			else:
				_expect(footprint_visibility > 0.0, "%s impact should reveal the clean resolved footprint" % card_id)
			return presentation.duplicate(true)
		await process_frame
	_expect(false, "%s should expose its authored AOE effect at progress %.2f" % [card_id, minimum_progress])
	return {}


func _aoe_action_for_card(card_id: String) -> Dictionary:
	for action_var: Variant in GameData.card_def(card_id).get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		if str(action.get("type", "")) != "aoe":
			continue
		action["_card_element"] = GameData.card_element(card_id)
		action["orientation"] = Vector2i(1, 0)
		return action
	_expect(false, "%s should provide a production AOE action" % card_id)
	return {}


func _install_combat_state(instance: Node, combat_state: Dictionary, layout: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")


func _resolve_contextual_prompts(instance: Node) -> void:
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")


func _combat_layout(element_id: String) -> Dictionary:
	return {
		"name": "Elemental AOE Animation Proof",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": element_id,
		"umbra_stage": "clear",
		"grid": _open_grid(),
		"player_start": PLAYER_TILE,
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": ENEMY_TILE,
			"hp": 100,
			"max_hp": 100,
			"block": 0,
		}],
		"traps": [],
		"terrain": [],
		"loot": [],
	}


func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid


func _enemy_hp(combat_state: Dictionary, enemy_id: int) -> int:
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("id", -1)) == enemy_id:
			return int(enemy.get("hp", 0))
	return 0


func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame


func _save_root_screenshot(output_path: String) -> void:
	_expect(DisplayServer.get_name() != "headless", "Elemental AOE proof requires the real renderer")
	RenderingServer.force_draw()
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	_expect(image != null, "Elemental AOE proof should capture a renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var proportional: bool = is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	_expect(proportional, "Elemental AOE proof should preserve the 1920x1080 aspect ratio, got %s" % source_size)
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(output_path) == OK, "Elemental AOE proof should save %s" % output_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


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
