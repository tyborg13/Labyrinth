extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/floating_combat_v4"
const PROGRESSION_PATH: String = "user://floating_damage_probe_progression.json"
const RUN_PATH: String = "user://floating_damage_probe_run.save"
const SETTINGS_PATH: String = "user://floating_damage_probe_settings.json"
const LEGACY_GATE_GAMBIT_SERIAL_SECONDS: float = 4.03
const LEGACY_LOADED_TOSS_SERIAL_SECONDS: float = 3.91
const TARGET_MULTI_EFFECT_DURATION_RATIO: float = 0.50

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Floating damage proof should load the run scene")
	if packed != null:
		await _capture_config(packed, {"size": Vector2i(1920, 1080), "scale": 1.0})
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("FLOATING DAMAGE PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FLOATING DAMAGE PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_config(packed: PackedScene, config: Dictionary) -> void:
	var screenshot_size: Vector2i = config.get("size", Vector2i(1920, 1080))
	var ui_scale: float = float(config.get("scale", 1.0))
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)

	var viewport := SubViewport.new()
	viewport.name = "FloatingDamage_%dx%d_ui%d" % [
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
	]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = logical_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	instance.set("_settings", settings.duplicate(true))
	var combat_state: Dictionary = _install_combat_fixture(instance)
	await _settle()
	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(logical_size),
		"%s @ %d%% should expose logical viewport %s" % [
			screenshot_size,
			roundi(ui_scale * 100.0),
			logical_size,
		]
	)
	_hide_log(instance)
	_assert_arc_continuity()

	var enemy_damage: Array = [
		FloatingCombatText.damage_entry(Vector2i(5, 3), "-13", Color("f39779")),
	]
	for arc_capture: Dictionary in [
		{"name": "enemy_arc_impact.png", "elapsed": 0.0},
		{"name": "enemy_arc_rise.png", "elapsed": FloatingCombatText.ANIMATION_DURATION_SECONDS * 0.17},
		{"name": "enemy_arc_apex.png", "elapsed": FloatingCombatText.ANIMATION_DURATION_SECONDS * FloatingCombatText.ARC_APEX_PROGRESS},
		{"name": "enemy_arc_fall.png", "elapsed": FloatingCombatText.ANIMATION_DURATION_SECONDS * 0.78},
	]:
		await _capture_popup_state(
			instance,
			viewport,
			combat_state,
			enemy_damage,
			float(arc_capture.get("elapsed", 0.0)),
			false,
			["enemy_2"],
			"%s/%s" % [output_dir, str(arc_capture.get("name", ""))],
			screenshot_size
		)

	await _capture_popup_state(
		instance,
		viewport,
		combat_state,
		[{
			"tile": Vector2i(3, 3),
			"text": "+1 play",
			"color": Color("ffe27a"),
			"offset": -6.0,
		}],
		0.0,
		false,
		["player"],
		"%s/player_card_play_local.png" % output_dir,
		screenshot_size
	)
	await _capture_popup_state(
		instance,
		viewport,
		combat_state,
		[
			FloatingCombatText.damage_entry(Vector2i(2, 4), "-9", Color("f0c85c")),
		],
		FloatingCombatText.ANIMATION_DURATION_SECONDS * 0.18,
		false,
		[],
		"%s/terrain_damage_local.png" % output_dir,
		screenshot_size
	)
	var effect_words: Array = [
		{"tile": Vector2i(4, 2), "text": "Draw", "color": Color("ffe27a")},
		{"tile": Vector2i(5, 3), "text": "Play", "color": Color("a8e6ff")},
	]
	for effect_capture: Dictionary in [
		{"name": "effect_words_impact.png", "elapsed": 0.0, "reduced": false},
		{"name": "effect_words_settled.png", "elapsed": FloatingCombatText.ANIMATION_DURATION_SECONDS * FloatingCombatText.DAMAGE_SETTLE_PROGRESS, "reduced": false},
		{"name": "effect_words_reduced_motion.png", "elapsed": FloatingCombatText.ANIMATION_DURATION_SECONDS * FloatingCombatText.DAMAGE_SETTLE_PROGRESS, "reduced": true},
	]:
		await _capture_popup_state(
			instance,
			viewport,
			combat_state,
			effect_words,
			float(effect_capture.get("elapsed", 0.0)),
			bool(effect_capture.get("reduced", false)),
			["enemy_1", "enemy_2"],
			"%s/%s" % [output_dir, str(effect_capture.get("name", ""))],
			screenshot_size
		)

	var compound_entries: Array = [
		FloatingCombatText.damage_entry(Vector2i(5, 3), "-13", Color("f39779")),
		{
			"tile": Vector2i(5, 3),
			"text": "-4 B",
			"color": Color("90d9ff"),
			"width": 112.0,
		},
		{
			"tile": Vector2i(5, 3),
			"text": "Bleed",
			"color": Color("f1d18b"),
			"width": 112.0,
		},
	]
	for pop_index: int in range(3):
		await _capture_popup_state(
			instance,
			viewport,
			combat_state,
			compound_entries,
			0.03 + float(pop_index) * FloatingCombatText.STAGGER_SECONDS,
			false,
			["enemy_2"],
			"%s/compound_pop_%d.png" % [output_dir, pop_index + 1],
			screenshot_size
		)
	await _capture_popup_state(
		instance,
		viewport,
		combat_state,
		compound_entries,
		0.03 + FloatingCombatText.STAGGER_SECONDS * 2.0,
		true,
		["enemy_2"],
		"%s/reduced_motion_stack.png" % output_dir,
		screenshot_size
	)
	await _capture_multi_effect_card_timelines(
		instance,
		viewport,
		combat_state,
		output_dir,
		screenshot_size
	)
	await _verify_actual_multi_effect_resolution_pacing(instance, combat_state)

	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame


func _capture_multi_effect_card_timelines(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	output_dir: String,
	screenshot_size: Vector2i
) -> void:
	var loaded_toss_types: Array[String] = _card_action_types("loaded_toss")
	var gate_gambit_types: Array[String] = _card_action_types("gate_gambit")
	_expect(
		loaded_toss_types == ["ranged", "draw", "card_play"],
		"Loaded Toss should remain the attack, draw, and card-play overlap fixture"
	)
	_expect(
		gate_gambit_types == ["draw", "card_play", "block"],
		"Gate Gambit should remain the three-utility-effect overlap fixture"
	)
	var player_tile := Vector2i(3, 3)
	var loaded_toss_groups: Array[Dictionary] = [
		FloatingCombatText.timeline_group([
			FloatingCombatText.damage_entry(Vector2i(5, 3), "-3", Color("f39779")),
		], 0.0),
		FloatingCombatText.timeline_group([{
			"tile": player_tile,
			"text": "+1 draw",
			"color": Color("f1d18b"),
		}], FloatingCombatText.ACTION_ADVANCE_SECONDS),
		FloatingCombatText.timeline_group([{
			"tile": player_tile,
			"text": "+1 play",
			"color": Color("ffe27a"),
		}], FloatingCombatText.ACTION_ADVANCE_SECONDS * 2.0),
	]
	for capture: Dictionary in [
		{
			"name": "loaded_toss_attack_draw_overlap.png",
			"elapsed": FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.02,
			"reduced": false,
		},
		{
			"name": "loaded_toss_draw_play_overlap.png",
			"elapsed": FloatingCombatText.ACTION_ADVANCE_SECONDS * 2.0 + 0.02,
			"reduced": false,
		},
		{
			"name": "loaded_toss_reduced_overlap.png",
			"elapsed": FloatingCombatText.ACTION_ADVANCE_SECONDS * 2.0 + 0.02,
			"reduced": true,
		},
	]:
		await _capture_timeline_state(
			instance,
			viewport,
			combat_state,
			loaded_toss_groups,
			float(capture.get("elapsed", 0.0)),
			bool(capture.get("reduced", false)),
			["player", "enemy_2"],
			"%s/%s" % [output_dir, str(capture.get("name", ""))],
			screenshot_size
		)
	var gate_gambit_groups: Array[Dictionary] = [
		FloatingCombatText.timeline_group([{
			"tile": player_tile,
			"text": "+3 draw",
			"color": Color("f1d18b"),
		}], 0.0),
		FloatingCombatText.timeline_group([{
			"tile": player_tile,
			"text": "+2 play",
			"color": Color("ffe27a"),
		}], FloatingCombatText.ACTION_ADVANCE_SECONDS),
		FloatingCombatText.timeline_group([{
			"tile": player_tile,
			"text": "+3 block",
			"color": Color("90d9ff"),
		}], FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.29),
	]
	for capture: Dictionary in [
		{
			"name": "gate_gambit_draw_play_overlap.png",
			"elapsed": FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.02,
		},
		{
			"name": "gate_gambit_play_block_overlap.png",
			"elapsed": FloatingCombatText.ACTION_ADVANCE_SECONDS + 0.31,
		},
	]:
		await _capture_timeline_state(
			instance,
			viewport,
			combat_state,
			gate_gambit_groups,
			float(capture.get("elapsed", 0.0)),
			false,
			["player"],
			"%s/%s" % [output_dir, str(capture.get("name", ""))],
			screenshot_size
		)


func _card_action_types(card_id: String) -> Array[String]:
	var action_types: Array[String] = []
	for action_var: Variant in GameData.card_def(card_id).get("actions", []):
		if typeof(action_var) == TYPE_DICTIONARY:
			action_types.append(str((action_var as Dictionary).get("type", "")))
	return action_types


func _verify_actual_multi_effect_resolution_pacing(instance: Node, combat_state: Dictionary) -> void:
	var no_targets: Array[Vector2i] = []
	var gate_gambit_started_usec: int = Time.get_ticks_usec()
	await instance.call(
		"_animate_player_card_resolution",
		combat_state.duplicate(true),
		"gate_gambit",
		(GameData.card_def("gate_gambit").get("actions", []) as Array).duplicate(true),
		no_targets
	)
	var gate_gambit_seconds: float = float(Time.get_ticks_usec() - gate_gambit_started_usec) / 1000000.0
	_expect(
		gate_gambit_seconds
		<= LEGACY_GATE_GAMBIT_SERIAL_SECONDS * TARGET_MULTI_EFFECT_DURATION_RATIO,
		"Gate Gambit's former 4.03-second serial presentation should resolve within half that time, got %.3f"
		% gate_gambit_seconds
	)
	var loaded_toss_targets: Array[Vector2i] = []
	loaded_toss_targets.append(Vector2i(5, 3))
	var loaded_toss_started_usec: int = Time.get_ticks_usec()
	await instance.call(
		"_animate_player_card_resolution",
		combat_state.duplicate(true),
		"loaded_toss",
		(GameData.card_def("loaded_toss").get("actions", []) as Array).duplicate(true),
		loaded_toss_targets
	)
	var loaded_toss_seconds: float = float(Time.get_ticks_usec() - loaded_toss_started_usec) / 1000000.0
	_expect(
		loaded_toss_seconds
		<= LEGACY_LOADED_TOSS_SERIAL_SECONDS * TARGET_MULTI_EFFECT_DURATION_RATIO,
		"Loaded Toss's former 3.91-second serial presentation should resolve within half that time, got %.3f"
		% loaded_toss_seconds
	)
	print(
		"MULTI-EFFECT POPUP PACING: Gate Gambit %.3fs, Loaded Toss %.3fs"
		% [gate_gambit_seconds, loaded_toss_seconds]
	)


func _capture_popup_state(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	base_entries: Array,
	elapsed_seconds: float,
	reduced_motion: bool,
	impact_keys: Array,
	path: String,
	expected_size: Vector2i
) -> void:
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var animated_entries: Array[Dictionary] = FloatingCombatText.animate_entries(
		base_entries,
		elapsed_seconds,
		reduced_motion
	)
	await _capture_animated_popup_state(
		instance,
		viewport,
		combat_state,
		animated_entries,
		elapsed_seconds,
		impact_keys,
		path,
		expected_size
	)


func _capture_timeline_state(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	groups: Array[Dictionary],
	elapsed_seconds: float,
	reduced_motion: bool,
	impact_keys: Array,
	path: String,
	expected_size: Vector2i
) -> void:
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var animated_entries: Array[Dictionary] = FloatingCombatText.animate_timeline(
		groups,
		elapsed_seconds,
		reduced_motion
	)
	await _capture_animated_popup_state(
		instance,
		viewport,
		combat_state,
		animated_entries,
		elapsed_seconds,
		impact_keys,
		path,
		expected_size
	)


func _capture_animated_popup_state(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	animated_entries: Array[Dictionary],
	elapsed_seconds: float,
	impact_keys: Array,
	path: String,
	expected_size: Vector2i
) -> void:
	_expect(not animated_entries.is_empty(), "%s should expose at least one active popup" % path)
	instance.call("_render_board_state", combat_state, {
		"focus_actor_keys": impact_keys,
		"focus_actor_color": Color("f08c53"),
		"impact_actor_keys": impact_keys,
		"impact_progress": clampf(
			elapsed_seconds / FloatingCombatText.ANIMATION_DURATION_SECONDS,
			0.0,
			1.0
		),
		"floating_texts": animated_entries,
	})
	await _settle()
	var board: Control = instance.get("board_view") as Control
	_expect(board != null, "%s should expose the live combat board" % path)
	if board != null:
		var rendered_entries: Array = (board.get("presentation") as Dictionary).get("floating_texts", []) as Array
		_expect(
			rendered_entries.size() == animated_entries.size(),
			"%s should render every popup active at this stagger time" % path
		)
		for entry: Dictionary in animated_entries:
			var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
			var target_rect: Rect2 = board.call("_floating_text_target_rect", tile) as Rect2
			var rendered_width: float = float(board.call("_floating_text_rendered_width", entry)) * float(entry.get("font_scale", 1.0))
			var origin: Vector2 = board.call("_floating_text_local_origin", tile, rendered_width) as Vector2
			var anchor_delta_x: float = origin.x + rendered_width * 0.5 - target_rect.get_center().x
			_expect(
				anchor_delta_x >= 16.0 and anchor_delta_x <= 20.0,
				"%s popup center should begin at one consistent tiny right-side offset" % path
			)
			_expect(
				target_rect.grow(1.0).has_point(
					Vector2(origin.x + rendered_width * 0.5, target_rect.get_center().y)
				),
				"%s popup center should overlap its receiving actor or terrain target" % path
			)
			if FloatingCombatText.is_effect_entry(entry):
				var glyph_width: float = float(board.call("_floating_text_glyph_width", entry))
				var allocated_width: float = float(board.call("_floating_text_rendered_width", entry))
				_expect(
					allocated_width >= glyph_width + float(int(entry.get("outline_size", 0)) * 2),
					"%s should allocate every Draw/Play glyph plus its outline at this animation state" % path
				)
	await _save_screenshot(viewport, path, expected_size)


func _assert_arc_continuity() -> void:
	var base: Dictionary = FloatingCombatText.damage_entry(Vector2i(5, 3), "-13", Color("f39779"))
	var previous: Dictionary = FloatingCombatText.animate_entry(base, 0.0, false)
	for frame: int in range(1, 52):
		var elapsed_seconds: float = float(frame) * FloatingCombatText.TARGET_FRAME_SECONDS
		var progress: float = clampf(
			elapsed_seconds / FloatingCombatText.ANIMATION_DURATION_SECONDS,
			0.0,
			1.0
		)
		var current: Dictionary = FloatingCombatText.animate_entry(base, progress, false)
		var previous_motion: Vector2 = previous.get("motion_offset", Vector2.ZERO)
		var current_motion: Vector2 = current.get("motion_offset", Vector2.ZERO)
		_expect(
			previous_motion.distance_to(current_motion) < 6.0,
			"Display-frame popup samples should move continuously without positional jumps"
		)
		_expect(
			absf(
				FloatingCombatText.rendered_font_size(previous)
				- FloatingCombatText.rendered_font_size(current)
			) < 2.5 * FloatingCombatText.DAMAGE_PRESENTATION_SCALE + 0.01,
			"Display-frame popup samples should scale continuously without integer size jumps"
		)
		previous = current


func _install_combat_fixture(instance: Node) -> Dictionary:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(
		91370,
		layout,
		{
			"hp": 24,
			"max_hp": 24,
			"deck_cards": ["loaded_toss", "gate_gambit", "crank_reload"],
			"relics": [],
			"hand_size": 3,
			"heal_bonus": 0,
		}
	)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["loaded_toss", "gate_gambit", "crank_reload"]
	deck["draw"] = ["quick_stab", "brace", "whirlwind_slash", "patch_up"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	return combat_state


func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	return {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": Vector2i(3, 3),
		"enemies": [
			_enemy(1, Vector2i(4, 2), 30),
			_enemy(2, Vector2i(5, 3), 40),
			_enemy(3, Vector2i(6, 4), 50),
		],
		"traps": [],
		"terrain": [{
			"id": "probe_crate",
			"kind": "wooden_crate",
			"pos": Vector2i(2, 4),
			"hp": 18,
			"max_hp": 18,
		}],
		"loot": [],
	}


func _enemy(id: int, pos: Vector2i, hp: int) -> Dictionary:
	return {
		"id": id,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"stoneskin": 0,
		"base_initiative": 9,
	}


func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false


func _save_screenshot(viewport: SubViewport, path: String, expected_size: Vector2i) -> void:
	await _settle()
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should be exactly %s, got %s" % [path, expected_size, image.get_size()])
	_expect(_non_black_frame_coverage(image) >= 0.08, "%s should visibly render the combat scene" % path)
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)


func _non_black_frame_coverage(image: Image) -> float:
	var sampled: int = 0
	var non_black: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			sampled += 1
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.015:
				non_black += 1
	return float(non_black) / float(maxi(1, sampled))


func _settle() -> void:
	for _frame: int in range(5):
		await process_frame
	RenderingServer.force_draw(true)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
