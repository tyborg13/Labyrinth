extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://relic_damage_feedback_probe"
const PROGRESSION_PATH: String = "user://relic_damage_feedback_progression.json"
const RUN_PATH: String = "user://relic_damage_feedback_run.save"
const SETTINGS_PATH: String = "user://relic_damage_feedback_settings.json"
const INVALID_TARGET_TILE := Vector2i(-1, -1)

var _failures: Array[String]


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Relic damage feedback proof should load the run scene")
	if packed != null:
		for config: Dictionary in [
			{"size": Vector2i(1920, 1080), "scale": 1.0},
			{"size": Vector2i(1280, 720), "scale": 1.25}
		]:
			for reduced_motion: bool in [false, true]:
				await _capture_config(packed, config, reduced_motion)

	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("RELIC DAMAGE FEEDBACK PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RELIC DAMAGE FEEDBACK PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_config(packed: PackedScene, config: Dictionary, reduced_motion: bool) -> void:
	var screenshot_size: Vector2i = config.get("size", Vector2i(1920, 1080))
	var ui_scale: float = float(config.get("scale", 1.0))
	print("Capture %s %s" % [_size_label(screenshot_size, ui_scale), "reduced" if reduced_motion else "normal"])
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = reduced_motion
	SettingsStore.save_settings(settings)

	var viewport := SubViewport.new()
	viewport.name = "RelicDamage_%dx%d_ui%d_%s" % [
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
		"reduced" if reduced_motion else "normal"
	]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = logical_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	await _capture_ion_spool(packed, viewport, screenshot_size, ui_scale, reduced_motion)
	await _capture_direct_attack(packed, viewport, screenshot_size, ui_scale, reduced_motion)
	await _capture_movement_trap(packed, viewport, screenshot_size, ui_scale, reduced_motion)
	await _capture_thornmail(packed, viewport, screenshot_size, ui_scale, reduced_motion)
	viewport.queue_free()
	await _settle()


func _capture_ion_spool(
	packed: PackedScene,
	viewport: SubViewport,
	screenshot_size: Vector2i,
	ui_scale: float,
	reduced_motion: bool
) -> void:
	var instance: Node = await _new_run_scene(packed, viewport, 97310, ui_scale, reduced_motion)
	var layout: Dictionary = _combat_layout([
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 5), "hp": 20, "max_hp": 20, "block": 2},
		{"id": 3, "type": "acolyte", "pos": Vector2i(4, 6), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 2}
	])
	var combat := CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(97310, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["static_lash"],
		"relics": ["ion_spool"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	before_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 3})
	_install_combat_state(instance, before_state, layout)
	await _settle()

	var action: Dictionary = {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1}
	var after_state: Dictionary = combat.apply_player_action(before_state, action)
	_expect(_enemy_hp_loss(before_state, after_state, 1) == 4, "Ion Spool should deal four HP damage to the undefended enemy")
	_expect(
		_enemy_hp_loss(before_state, after_state, 2) == 2
		and _enemy_defense_loss(before_state, after_state, 2, "block") == 2,
		"Ion Spool should visibly split damage across Block and HP"
	)
	_expect(
		_enemy_hp_loss(before_state, after_state, 3) == 2
		and _enemy_defense_loss(before_state, after_state, 3, "stoneskin") == 2,
		"Ion Spool should visibly split damage across Stoneskin and HP"
	)
	instance.call(
		"_animate_player_action_step",
		before_state.duplicate(true),
		after_state,
		"static_lash",
		action,
		INVALID_TARGET_TILE
	)
	var setup_captured: bool = await _wait_for_primary_feedback(
		instance,
		"Lightning 2",
		before_state,
		after_state
	)
	print("  Ion setup: %s" % setup_captured)
	_expect(setup_captured, "Ion Spool should retain pre-hit durability throughout its threshold-consumption feedback")
	if setup_captured:
		await _save_screenshot(
			viewport,
			"%s/ion_setup_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	var impact_captured: bool = await _wait_for_damage_feedback(
		instance,
		{"-4": 1, "-2": 2, "-2 B": 1, "-2 S": 1},
		3,
		reduced_motion,
		after_state
	)
	print("  Ion impact: %s" % impact_captured)
	_expect(impact_captured, "Ion Spool should expose exact HP, Block, and Stoneskin losses plus three hit reactions")
	if impact_captured:
		await _save_screenshot(
			viewport,
			"%s/ion_impact_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	await create_timer(0.9).timeout
	instance.queue_free()
	await _settle()


func _capture_direct_attack(
	packed: PackedScene,
	viewport: SubViewport,
	screenshot_size: Vector2i,
	ui_scale: float,
	reduced_motion: bool
) -> void:
	var instance: Node = await _new_run_scene(packed, viewport, 97312, ui_scale, reduced_motion)
	var layout: Dictionary = _combat_layout([
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20, "block": 2}
	])
	var combat := CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(97312, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bone_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_install_combat_state(instance, before_state, layout)
	await _settle()

	var action: Dictionary = {"type": "ranged", "damage": 4, "range": 8}
	var target_tile: Vector2i = ((before_state.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO)
	var after_state: Dictionary = combat.apply_player_action(before_state, action, target_tile)
	_expect(
		_enemy_hp_loss(before_state, after_state, 1) == 2
		and _enemy_defense_loss(before_state, after_state, 1, "block") == 2,
		"A direct attack should split its four damage across Block and HP"
	)
	instance.call(
		"_animate_player_action_step",
		before_state.duplicate(true),
		after_state,
		"bone_dart",
		action,
		target_tile
	)
	var windup_captured: bool = await _wait_for_action_windup(instance, "ranged", before_state)
	print("  Attack wind-up: %s" % windup_captured)
	_expect(windup_captured, "A direct attack should retain pre-hit durability throughout its wind-up")
	if windup_captured:
		await _save_screenshot(
			viewport,
			"%s/attack_windup_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	var impact_captured: bool = await _wait_for_damage_feedback(
		instance,
		{"-2": 1, "-2 B": 1},
		1,
		reduced_motion,
		after_state
	)
	print("  Attack impact: %s" % impact_captured)
	_expect(impact_captured, "A direct attack should switch to post-hit durability with its damage numbers and hit reaction")
	if impact_captured:
		await _save_screenshot(
			viewport,
			"%s/attack_impact_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	await create_timer(0.9).timeout
	instance.queue_free()
	await _settle()


func _capture_movement_trap(
	packed: PackedScene,
	viewport: SubViewport,
	screenshot_size: Vector2i,
	ui_scale: float,
	reduced_motion: bool
) -> void:
	var trap: Dictionary = {
		"id": "timing_trap",
		"element": ElementData.LIGHTNING,
		"pos": Vector2i(3, 4),
		"base_damage": 6,
		"damage": 6,
		"armed": true
	}
	var layout: Dictionary = _combat_layout(
		[{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 2}],
		Vector2i(2, 4),
		[trap]
	)
	var instance: Node = await _new_run_scene(packed, viewport, 97313, ui_scale, reduced_motion)
	var combat := CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(97313, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["threaded_path"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player_before: Dictionary = (before_state.get("player", {}) as Dictionary).duplicate(true)
	player_before["block"] = 2
	before_state["player"] = player_before
	_install_combat_state(instance, before_state, layout)
	await _settle()

	var action: Dictionary = {"type": "move", "range": 2}
	var target_tile := Vector2i(3, 4)
	var after_state: Dictionary = combat.apply_player_action(before_state, action, target_tile)
	var triggered_traps: Array = instance.call("_triggered_traps_between", before_state, after_state) as Array
	var player_after: Dictionary = after_state.get("player", {})
	var player_hp_loss: int = int(player_before.get("hp", 0)) - int(player_after.get("hp", 0))
	var player_block_loss: int = int(player_before.get("block", 0)) - int(player_after.get("block", 0))
	var enemy_hp_loss: int = _enemy_hp_loss(before_state, after_state, 1)
	var enemy_block_loss: int = _enemy_defense_loss(before_state, after_state, 1, "block")
	_expect(
		triggered_traps.size() == 1
		and player_hp_loss > 0
		and player_block_loss > 0
		and enemy_hp_loss > 0
		and enemy_block_loss > 0,
		"The movement trap fixture should damage player and enemy durability"
	)
	instance.call(
		"_animate_player_action_step",
		before_state.duplicate(true),
		after_state,
		"threaded_path",
		action,
		target_tile
	)
	var setup_captured: bool = await _wait_for_movement_trap_setup(instance, before_state, after_state)
	print("  Trap setup: %s" % setup_captured)
	_expect(setup_captured, "Movement should resolve its destination while retaining pre-trap durability")
	if setup_captured:
		await _save_screenshot(
			viewport,
			"%s/trap_setup_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	var expected_text_counts: Dictionary = {}
	_increment_text_count(expected_text_counts, "-%d" % player_hp_loss)
	_increment_text_count(expected_text_counts, "-%d B" % player_block_loss)
	_increment_text_count(expected_text_counts, "-%d" % enemy_hp_loss)
	_increment_text_count(expected_text_counts, "-%d B" % enemy_block_loss)
	var impact_captured: bool = await _wait_for_damage_feedback(
		instance,
		expected_text_counts,
		2,
		reduced_motion,
		after_state,
		1
	)
	print("  Trap impact: %s" % impact_captured)
	_expect(impact_captured, "Movement trap impact should switch player and enemy durability with its hit feedback")
	if impact_captured:
		await _save_screenshot(
			viewport,
			"%s/trap_impact_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	await create_timer(0.9).timeout
	instance.queue_free()
	await _settle()


func _capture_thornmail(
	packed: PackedScene,
	viewport: SubViewport,
	screenshot_size: Vector2i,
	ui_scale: float,
	reduced_motion: bool
) -> void:
	var instance: Node = await _new_run_scene(packed, viewport, 97311, ui_scale, reduced_motion)
	var layout: Dictionary = _combat_layout([
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 5), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 2), "hp": 20, "max_hp": 20, "block": 0}
	], Vector2i(3, 5))
	var combat := CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(97311, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate"],
		"relics": ["thornmail_brooch"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_install_combat_state(instance, before_state, layout)
	await _settle()

	var action: Dictionary = {"type": "stoneskin", "amount": 8}
	var after_state: Dictionary = combat.apply_player_action(before_state, action)
	_expect(_enemy_hp_loss(before_state, after_state, 1) == 4, "Thornmail should damage the first adjacent enemy")
	_expect(_enemy_hp_loss(before_state, after_state, 2) == 4, "Thornmail should damage the second adjacent enemy")
	_expect(_enemy_hp_loss(before_state, after_state, 3) == 0, "Thornmail should leave the distant enemy undamaged")
	instance.call(
		"_animate_player_action_step",
		before_state.duplicate(true),
		after_state,
		"stone_plate",
		action,
		INVALID_TARGET_TILE
	)
	var captured: bool = await _wait_for_damage_feedback(
		instance,
		{"-4": 2},
		2,
		reduced_motion,
		after_state
	)
	print("  Thornmail impact: %s" % captured)
	_expect(captured, "Thornmail Brooch should expose two damage numbers and two hit reactions")
	if captured:
		await _save_screenshot(
			viewport,
			"%s/thornmail_%s_%s.png" % [
				OUTPUT_DIR,
				_size_label(screenshot_size, ui_scale),
				"reduced" if reduced_motion else "normal"
			],
			screenshot_size
		)
	await create_timer(0.9).timeout
	instance.queue_free()
	await _settle()


func _new_run_scene(
	packed: PackedScene,
	viewport: SubViewport,
	seed: int,
	ui_scale: float,
	reduced_motion: bool
) -> Node:
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	instance.call("_load_run_state", RunEngine.new().create_new_run(seed, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await _settle()
	return instance


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


func _wait_for_primary_feedback(
	instance: Node,
	expected_text: String,
	expected_durability_state: Dictionary,
	expected_resolved_state: Dictionary
) -> bool:
	for _attempt: int in range(240):
		var board: Control = instance.get("board_view") as Control
		if board != null:
			var presentation: Dictionary = board.get("presentation") as Dictionary
			if (
				_floating_text_count(presentation.get("floating_texts", []), expected_text) == 1
				and (presentation.get("impact_actor_keys", []) as Array).is_empty()
			):
				var display_state: Dictionary = board.get("combat_state") as Dictionary
				_expect(
					_enemy_durability_matches(display_state, expected_durability_state),
					"Primary action feedback should retain exact pre-hit enemy durability"
				)
				_expect(
					_intensity_matches(display_state, expected_resolved_state),
					"Primary action feedback should retain the already-resolved elemental intensity"
				)
				return true
		await create_timer(0.02).timeout
	return false


func _wait_for_action_windup(instance: Node, expected_effect_kind: String, expected_state: Dictionary) -> bool:
	for _attempt: int in range(240):
		var board: Control = instance.get("board_view") as Control
		if board != null:
			var presentation: Dictionary = board.get("presentation") as Dictionary
			var effect: Dictionary = presentation.get("effect", {}) as Dictionary
			if (
				str(effect.get("kind", "")) == expected_effect_kind
				and float(presentation.get("effect_progress", 1.0)) < 1.0
				and (presentation.get("floating_texts", []) as Array).is_empty()
				and (presentation.get("impact_actor_keys", []) as Array).is_empty()
			):
				_expect(
					_enemy_durability_matches(board.get("combat_state") as Dictionary, expected_state),
					"Attack wind-up should retain exact pre-hit enemy durability"
				)
				return true
		await create_timer(0.02).timeout
	return false


func _wait_for_movement_trap_setup(
	instance: Node,
	expected_durability_state: Dictionary,
	expected_resolved_state: Dictionary
) -> bool:
	var expected_player_pos: Vector2i = (expected_resolved_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var expected_traps: Array = expected_resolved_state.get("traps", [])
	for _attempt: int in range(240):
		var board: Control = instance.get("board_view") as Control
		if board != null:
			var presentation: Dictionary = board.get("presentation") as Dictionary
			var display_state: Dictionary = board.get("combat_state") as Dictionary
			if (
				(display_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == expected_player_pos
				and (display_state.get("traps", []) as Array) == expected_traps
				and (presentation.get("floating_texts", []) as Array).is_empty()
				and (presentation.get("impact_actor_keys", []) as Array).is_empty()
				and (presentation.get("trap_effects", []) as Array).is_empty()
			):
				_expect(
					_enemy_durability_matches(display_state, expected_durability_state)
					and _player_durability_matches(display_state, expected_durability_state),
					"Post-movement trap setup should retain exact pre-hit player and enemy durability"
				)
				return true
		await create_timer(0.01).timeout
	return false


func _wait_for_damage_feedback(
	instance: Node,
	expected_text_counts: Dictionary,
	expected_impact_count: int,
	reduced_motion: bool,
	expected_state: Dictionary,
	expected_trap_count: int = 0
) -> bool:
	for _attempt: int in range(240):
		var board: Control = instance.get("board_view") as Control
		if board != null:
			var presentation: Dictionary = board.get("presentation") as Dictionary
			var observed_text_counts: Dictionary = {}
			for floating_text_var: Variant in presentation.get("floating_texts", []):
				if typeof(floating_text_var) != TYPE_DICTIONARY:
					continue
				var floating_text: String = str((floating_text_var as Dictionary).get("text", ""))
				observed_text_counts[floating_text] = int(observed_text_counts.get(floating_text, 0)) + 1
			var impact_keys: Array = presentation.get("impact_actor_keys", [])
			var expected_texts_present: bool = true
			for expected_text_var: Variant in expected_text_counts.keys():
				var expected_text: String = str(expected_text_var)
				if int(observed_text_counts.get(expected_text, 0)) != int(expected_text_counts.get(expected_text, 0)):
					expected_texts_present = false
					break
			if (
				expected_texts_present
				and impact_keys.size() == expected_impact_count
				and (presentation.get("trap_effects", []) as Array).size() == expected_trap_count
			):
				_expect(
					_enemy_durability_matches(board.get("combat_state") as Dictionary, expected_state)
					and _player_durability_matches(board.get("combat_state") as Dictionary, expected_state),
					"Impact feedback should switch player and enemy to exact post-hit durability"
				)
				_expect(
					bool(presentation.get("reduced_motion", false)) == reduced_motion,
					"Damage feedback should preserve the active reduced-motion setting"
				)
				_expect(
					float(presentation.get("impact_progress", 1.0)) < 1.0,
					"Damage feedback should capture an active standard hit response"
				)
				_expect(
					float(board.call("_unit_impact_strength", {"key": str(impact_keys[0])})) > 0.0,
					"An impacted enemy should receive nonzero hit-response strength"
				)
				if expected_trap_count == 0:
					_expect(
						(presentation.get("impact_decals", []) as Array).size() == expected_impact_count,
						"Every impacted enemy should receive the established impact decal"
					)
				var shake_strength: float = float(board.call(
					"_unit_impact_shake_strength",
					{"key": str(impact_keys[0])}
				))
				_expect(
					is_zero_approx(shake_strength) if reduced_motion else shake_strength > 0.0,
					"Reduced motion should suppress hit shake while normal motion keeps it"
				)
				if reduced_motion:
					for floating_text_var: Variant in presentation.get("floating_texts", []):
						if typeof(floating_text_var) != TYPE_DICTIONARY:
							continue
						var floating_text: Dictionary = floating_text_var
						_expect(
							is_zero_approx(float(floating_text.get("rise", 0.0)))
							and is_equal_approx(float(floating_text.get("alpha", 1.0)), 1.0),
							"Reduced-motion damage numbers should remain static and fully visible"
						)
				return true
		await create_timer(0.02).timeout
	return false


func _floating_text_count(floating_texts: Array, expected_text: String) -> int:
	var count: int = 0
	for floating_text_var: Variant in floating_texts:
		if typeof(floating_text_var) != TYPE_DICTIONARY:
			continue
		if str((floating_text_var as Dictionary).get("text", "")) == expected_text:
			count += 1
	return count


func _increment_text_count(text_counts: Dictionary, text_value: String) -> void:
	text_counts[text_value] = int(text_counts.get(text_value, 0)) + 1


func _enemy_durability_matches(display_state: Dictionary, expected_state: Dictionary) -> bool:
	var displayed_by_id: Dictionary = {}
	for enemy_var: Variant in display_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		displayed_by_id[int(enemy.get("id", -1))] = enemy
	for expected_var: Variant in expected_state.get("enemies", []):
		if typeof(expected_var) != TYPE_DICTIONARY:
			continue
		var expected_enemy: Dictionary = expected_var as Dictionary
		var enemy_id: int = int(expected_enemy.get("id", -1))
		if not displayed_by_id.has(enemy_id):
			return false
		var displayed_enemy: Dictionary = displayed_by_id[enemy_id] as Dictionary
		for field: String in ["hp", "block", "stoneskin"]:
			if int(displayed_enemy.get(field, 0)) != int(expected_enemy.get(field, 0)):
				return false
	return true


func _player_durability_matches(display_state: Dictionary, expected_state: Dictionary) -> bool:
	var displayed_player: Dictionary = display_state.get("player", {})
	var expected_player: Dictionary = expected_state.get("player", {})
	for field: String in ["hp", "block", "stoneskin"]:
		if int(displayed_player.get(field, 0)) != int(expected_player.get(field, 0)):
			return false
	return true


func _intensity_matches(display_state: Dictionary, expected_state: Dictionary) -> bool:
	var combat := CombatEngine.new()
	for element_id: String in ElementData.all_elements():
		if (
			combat.elemental_intensity(display_state, element_id)
			!= combat.elemental_intensity(expected_state, element_id)
		):
			return false
	return true


func _combat_layout(
	enemies: Array,
	player_start: Vector2i = Vector2i(3, 4),
	traps: Array = []
) -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Relic Damage Feedback",
		"coord": Vector2i(1, 0),
		"depth": 3,
		"type": "combat",
		"element": ElementData.LIGHTNING,
		"grid": grid,
		"player_start": player_start,
		"enemies": enemies.duplicate(true),
		"loot": [],
		"traps": traps.duplicate(true)
	}


func _intensities(overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		result[element_id] = int(overrides.get(element_id, 0))
	return result


func _enemy_hp_loss(before_state: Dictionary, after_state: Dictionary, enemy_id: int) -> int:
	var before_hp: int = -1
	for enemy_var: Variant in before_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			before_hp = int((enemy_var as Dictionary).get("hp", 0))
			break
	if before_hp < 0:
		return 0
	for enemy_var: Variant in after_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			return maxi(0, before_hp - int((enemy_var as Dictionary).get("hp", 0)))
	return 0


func _enemy_defense_loss(
	before_state: Dictionary,
	after_state: Dictionary,
	enemy_id: int,
	field: String
) -> int:
	var before_value: int = 0
	for enemy_var: Variant in before_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			before_value = int((enemy_var as Dictionary).get(field, 0))
			break
	for enemy_var: Variant in after_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			return maxi(0, before_value - int((enemy_var as Dictionary).get(field, 0)))
	return before_value


func _size_label(size: Vector2i, ui_scale: float) -> String:
	return "%dx%d_ui%d" % [size.x, size.y, roundi(ui_scale * 100.0)]


func _save_screenshot(viewport: SubViewport, output_path: String, expected_size: Vector2i) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var image: Image = viewport.get_texture().get_image()
	_expect(image.get_size() == expected_size, "%s should render exactly %s" % [output_path, expected_size])
	var error: Error = image.save_png(output_path)
	_expect(error == OK, "Should save %s" % output_path)


func _settle() -> void:
	for _frame: int in range(4):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."] or dir.current_is_dir():
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir.path_join(entry)))
	dir.list_dir_end()
