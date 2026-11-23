extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const PassChecks = preload("res://tests/helpers/pass_forecast_checks.gd")
const PresentationClock = preload("res://tests/helpers/presentation_test_clock.gd")

const OUTPUT_DIR: String = "user://probes/pass_preview"
const PROBE_VIEWPORT := Vector2i(1920, 1080)
# Match the shared Pass test's 11 → 20 Crawler schedule: one move before +19.
const SINGLE_MOVE_TIME: int = 11
const FOLLOWUP_MOVE_TIME: int = 12
const REPEAT_MOVE_TIME: int = 1

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# The qa-27 renderer proof uses the reference viewport, not host fullscreen.
	SettingsStore.set_storage_path("user://pass_preview_probe_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_pass_preview_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_pass_preview_probe_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_pass_preview_states()
	print("PASS PREVIEW CAPTURES: skipped (headless)" if DisplayServer.get_name() == "headless" else ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_pass_preview_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var viewport := SubViewport.new()
	viewport.size = PROBE_VIEWPORT
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await process_frame
	await process_frame

	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_room_coord_of_type(run_engine, run_state, "combat")
	if combat_coord != Vector2i.ZERO:
		run_state = run_engine.move_to_room(run_state, combat_coord)
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame

	var base_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var danger_state: Dictionary = _pass_preview_probe_state(base_state, "danger")
	_install_pass_preview_probe_state(instance, danger_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "danger", ["+10", "−5"])

	await instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	_check_targeting_panel(instance, "selected_card", false)
	await _save_screenshot(viewport, "selected_card")

	var move_target: Vector2i = _pass_preview_probe_move_target(instance.get("_pending_target_tiles") as Array, Vector2i(3, 4))
	_expect(move_target.x >= 0, "Guarded Step should offer a move target.")
	if move_target.x >= 0:
		instance.call("_on_board_tile_hovered", move_target)
		await PresentationClock.rendered_frames(self, 1)
		_check_targeting_panel(instance, "selected_move_hover", true)
		await _save_screenshot(viewport, "selected_move_hover")

	var attack_hover_state: Dictionary = _pass_preview_probe_state(base_state, "danger")
	_weaken_first_enemy_for_pass_preview_probe(attack_hover_state, 8)
	_install_pass_preview_probe_state(instance, attack_hover_state)
	await process_frame
	await process_frame
	await instance.call("_on_card_pressed", 1)
	await process_frame
	await process_frame
	var attack_target := Vector2i(3, 4)
	var has_attack_target: bool = (instance.get("_pending_target_tiles") as Array).has(attack_target)
	_expect(has_attack_target, "Quick Stab should offer the adjacent Crawler as a target.")
	if has_attack_target:
		instance.call("_on_board_tile_hovered", attack_target)
		await PresentationClock.rendered_frames(self, 1)
		_check_targeting_panel(instance, "selected_attack_hover", true)
		await _save_screenshot(viewport, "selected_attack_hover")

	var after_card_state: Dictionary = _pass_preview_probe_after_guarded_step(instance, danger_state)
	_install_pass_preview_probe_state(instance, after_card_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "after_card", ["+5", "Safe"])

	var safe_state: Dictionary = _pass_preview_probe_state(base_state, "safe")
	_install_pass_preview_probe_state(instance, safe_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "safe", ["+10", "Safe"])

	var layered_state: Dictionary = _pass_preview_probe_state(base_state, "layered")
	_install_pass_preview_probe_state(instance, layered_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "layered", ["+10", "−3", "−4", "−5"])

	var defiance_state: Dictionary = _pass_preview_probe_state(base_state, "defiance_followup")
	_install_pass_preview_probe_state(instance, defiance_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "defiance_followup", ["+10", "−1", "−1 → 4/24"])

	var defiance_umbra_state: Dictionary = _pass_preview_probe_state(base_state, "defiance_umbra")
	_install_pass_preview_probe_state(instance, defiance_umbra_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "defiance_umbra", ["+10", "−1 → ?/?", "?"])

	# Four Crawler turns: out-of-range Claw, Lunge for 3, and two Skitter
	# Strikes for 5 each after pla-07 moved Bleed into the hits. No Ice or
	# Stagger is present, and there is no delayed Bleed row.
	var repeat_state: Dictionary = _pass_preview_probe_state(base_state, "counted_repeat")
	_install_pass_preview_probe_state(instance, repeat_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "counted_repeat", ["+10", "−13", "×4"])

	var lethal_state: Dictionary = _pass_preview_probe_state(base_state, "lethal")
	_install_pass_preview_probe_state(instance, lethal_state)
	await process_frame
	await process_frame
	await _check_pass_state(instance, viewport, "lethal", ["+10", "−24 → 0"])

	instance.queue_free()
	await PresentationClock.rendered_frames(self, 1)
	viewport.queue_free()
	await process_frame

func _first_available_room_coord_of_type(run_engine: RunEngine, run_state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _install_pass_preview_probe_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_card_play_count_override", -1)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _pass_preview_probe_state(base_state: Dictionary, kind: String) -> Dictionary:
	var state: Dictionary = base_state.duplicate(true)
	var has_defiance_followup: bool = kind in ["defiance_followup", "defiance_umbra"]
	var counted_repeat: bool = kind == "counted_repeat"
	var enemy_pos: Vector2i = Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	if kind == "safe" or counted_repeat:
		enemy_pos = Vector2i(6, 4)
	elif kind == "layered":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 12, "range": 1}]}
	elif kind == "lethal":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 30, "range": 1}]}
	elif has_defiance_followup:
		enemy_intent = {"name": "Lethal Claw", "time": 1, "actions": [{"type": "melee", "damage": 6, "range": 1}]}
	var starting_hp: int = 5 if has_defiance_followup else 24
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": starting_hp,
		"max_hp": 24,
		"block": 3 if kind == "layered" else 0,
		"stoneskin": 4 if kind == "layered" else 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []}
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []},
		"intent": enemy_intent
	}]
	if has_defiance_followup:
		var followup_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["enemies"].append({
			"id": 2,
			"type": "crawler",
			"pos": followup_pos,
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0,
			"expose": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {"damage": 0, "trigger": 0, "stacks": []},
			"intent": {"name": "Follow-up", "time": 1, "actions": [{"type": "melee", "damage": 2, "range": 1}]}
		})
	state["defiance_capacity"] = 1 if has_defiance_followup else 0
	state["defiance_remaining"] = 1 if has_defiance_followup else 0
	state["defiance_events"] = []
	state["defiance_event_revision"] = 0
	state["illusions"] = []
	state["traps"] = []
	state["terrain"] = []
	state["grid"] = _pass_preview_probe_simple_grid()
	state["deck"] = {
		"hand": ["guarded_step", "quick_stab"],
		"draw": ["patch_up", "bone_dart"],
		"discard": ["sidestep_slash"],
		"burned": [],
		"cycles": 0,
		"fatigue_base": 15
	}
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 2
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if counted_repeat else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["pending_player_trap_restriction"] = ""
	state["turn_flags"] = {"first_attack_bonus_used": false, "first_move_bonus_used": false}
	state["initiative_clock"] = 0
	state["activation_seq"] = 1
	state["current_actor"] = {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": 0,
		"seq": 0
	}
	state["turn_queue"] = [{
		"kind": "enemy",
		"actor_key": "enemy_1",
		"enemy_id": 1,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"team": "enemy",
		"time": REPEAT_MOVE_TIME if counted_repeat else SINGLE_MOVE_TIME,
		"seq": 1,
		"pos": enemy_pos
	}]
	if has_defiance_followup:
		var followup_queue_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["turn_queue"].append({
			"kind": "enemy",
			"actor_key": "enemy_2",
			"enemy_id": 2,
			"type": "crawler",
			"name": "Tunnel Crawler",
			"team": "enemy",
			"time": FOLLOWUP_MOVE_TIME,
			"seq": 2,
			"pos": followup_queue_pos
		})
	if kind == "defiance_umbra":
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = "eclipse"
		umbra["stage_reduction"] = 0
		state["umbra"] = umbra
	return state

func _weaken_first_enemy_for_pass_preview_probe(state: Dictionary, hp: int) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemies.is_empty():
		return
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemies[0] = enemy
	state["enemies"] = enemies

func _pass_preview_probe_simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _pass_preview_probe_after_guarded_step(instance: Node, source_state: Dictionary) -> Dictionary:
	var combat_engine = instance.get("_combat_engine")
	var state: Dictionary = source_state.duplicate(true)
	var actions: Array = GameData.card_def("guarded_step").get("actions", [])
	for action_index: int in range(actions.size()):
		if typeof(actions[action_index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[action_index]
		if combat_engine.player_action_needs_target(action):
			var target_tiles: Array = combat_engine.valid_targets_for_player_action(state, action)
			var move_target: Vector2i = _pass_preview_probe_move_target(target_tiles, Vector2i(3, 4))
			if move_target.x >= 0:
				state = combat_engine.apply_player_action(state, action, move_target)
		else:
			state = combat_engine.apply_player_action(state, action)
	return combat_engine.finish_player_card(state, 0)

func _pass_preview_probe_move_target(target_tiles: Array, enemy_pos: Vector2i) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for tile_var: Variant in target_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var distance: int = absi(tile.x - enemy_pos.x) + absi(tile.y - enemy_pos.y)
		if distance > best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _check_pass_state(instance: Node, viewport: SubViewport, label: String, expected_values: Array) -> void:
	PassChecks.assert_rows(instance, _expect, label)
	var chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	if chip == null:
		return
	var meter: Control = instance.get("_play_meter") as Control
	var card_play_copy: Label = instance.get("_play_meter_count") as Label
	var turn_rail: Control = instance.get("_turn_order_panel") as Control
	if chip.disabled or chip.focus_mode == Control.FOCUS_NONE or chip.find_child("CombinedPassButton", true, false) != null:
		_fail("Pass forecast should remain one focusable, actionable end-turn control during %s." % label)
	var pass_art: TextureRect = chip.get_node_or_null("PassForecastFrameArtHost") as TextureRect
	if pass_art == null or pass_art.texture == null or pass_art.z_index < 1:
		_fail("Pass forecast is missing the pending raster frame-art hook during %s." % label)
	var meter_art: TextureRect = meter.get_node_or_null("CardPlayFrameArtHost") as TextureRect if meter != null else null
	if meter == null or meter_art == null or meter_art.texture == null or meter_art.z_index < 1:
		_fail("Card-play dock is missing its raster frame-art hook during %s." % label)
	# ux-04 (66c75a74a) uses glossary case and a singular label for one play.
	if card_play_copy == null or not (card_play_copy.text.ends_with(" Card Play") or card_play_copy.text.ends_with(" Card Plays")):
		_fail("Card-play dock should use the compact Card Play(s) copy during %s." % label)
	if turn_rail != null and turn_rail.visible and turn_rail.get_global_rect().intersects(chip.get_global_rect()):
		_fail("Combined Pass dock should start below, not overlap, the dense turn rail during %s." % label)
	_assert_pass_interaction_states(chip, label)
	chip.mouse_entered.emit()
	var rows: Control = chip.get_node_or_null("PassForecastFocusTooltip/ForecastRows") as Control
	_expect(bool(chip.get_meta("pass_forecast_active", false)) and rows != null and rows.is_visible_in_tree(), "%s: hovering Pass shows the forecast panel" % label)
	var texts := PackedStringArray()
	if rows != null:
		for row: Node in rows.get_children():
			for child: Node in row.get_children():
				if child is RichTextLabel:
					texts.append((child as RichTextLabel).get_parsed_text())
	print("%s: %s" % [label, " | ".join(texts)])
	_expect(texts == PackedStringArray(expected_values), "%s: expected forecast values %s, got %s." % [label, expected_values, texts])
	await _save_screenshot(viewport, label)
	chip.mouse_exited.emit()

func _check_targeting_panel(instance: Node, label: String, open: bool) -> void:
	var chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_expect(chip != null and chip.disabled, "%s: Pass is disabled while a card is selected." % label)
	if chip == null:
		return
	_assert_pass_interaction_states(chip, label)
	_expect(bool(chip.get_meta("pass_forecast_active", false)) == open, "%s: expected forecast panel active=%s." % [label, open])

func _assert_pass_interaction_states(chip: Button, label: String) -> void:
	var focus_edge: Control = chip.get_node_or_null("PassForecastContent/PassFocusEdgeCue") as Control
	var art: TextureRect = chip.get_node_or_null("PassForecastFrameArtHost") as TextureRect
	var content: Control = chip.get_node_or_null("PassForecastContent") as Control
	if focus_edge == null or art == null:
		_fail("Pass control should expose native art states plus a narrow keyboard-focus edge during %s." % label)
		return
	if chip.disabled:
		if chip.focus_mode != Control.FOCUS_NONE or str(chip.get_meta("pass_interaction_state", "")) != "disabled":
			_fail("Disabled Pass forecast should not be focusable or activatable during %s." % label)
		return
	chip.mouse_entered.emit()
	if str(chip.get_meta("pass_interaction_state", "")) != "hover" or art.texture == null or str(art.get_meta("pass_forecast_art_state", "")) != "hover" or focus_edge.visible:
		_fail("Pass control should expose its authored hover frame without a colored overlay during %s." % label)
	chip.button_down.emit()
	if str(chip.get_meta("pass_interaction_state", "")) != "pressed" or art.texture == null or str(art.get_meta("pass_forecast_art_state", "")) != "pressed" or (content != null and content.position.y > 2.0):
		_fail("Pass control should expose its authored pressed frame with no more than subtle travel during %s." % label)
	chip.button_up.emit()
	chip.mouse_exited.emit()
	chip.focus_entered.emit()
	var focus_style: StyleBoxFlat = focus_edge.get_theme_stylebox("panel") as StyleBoxFlat
	if str(chip.get_meta("pass_interaction_state", "")) != "focus" or art.texture == null or str(art.get_meta("pass_forecast_art_state", "")) != "hover" or not focus_edge.visible or focus_style == null or focus_style.bg_color.a > 0.001 or focus_style.border_width_left > 2 or focus_style.shadow_size != 0:
		_fail("Pass control should expose authored focus art plus a narrow, wash-free keyboard/controller edge during %s." % label)
	chip.focus_exited.emit()

func _save_screenshot(viewport: SubViewport, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(ForecastPanel.FADE_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var path: String = "%s/%s.png" % [OUTPUT_DIR, name]
	if image == null or image.get_size() != PROBE_VIEWPORT or image.save_png(path) != OK:
		_fail("Could not save the 1920x1080 Pass preview capture %s." % path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

func _clear_probe_output_absolute(absolute_dir: String) -> void:
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
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
