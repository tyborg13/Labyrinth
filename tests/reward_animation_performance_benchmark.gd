extends SceneTree

const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PostCombatRewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://performance/reward_animation_benchmark"
const WORKLOAD_ID: String = "post_combat_reward_sequence_v1"
const OFFERED_CARDS: Array[String] = ["spark_dart", "frostbolt", "firebrand_volley"]
const IDLE_FRAMES: int = 120

class FrameSampler:
	extends Node

	var active: bool = false
	var previous_tick_usec: int = 0
	var frame_intervals_ms: Array[float] = []
	var process_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var objects_in_frame: Array[float] = []
	var primitives_in_frame: Array[float] = []

	func _ready() -> void:
		process_priority = 1000
		set_process(true)

	func begin() -> void:
		frame_intervals_ms.clear()
		process_ms.clear()
		draw_calls.clear()
		objects_in_frame.clear()
		primitives_in_frame.clear()
		previous_tick_usec = Time.get_ticks_usec()
		active = true

	func finish() -> Dictionary:
		active = false
		return {
			"frame_interval_ms": frame_intervals_ms.duplicate(),
			"process_ms": process_ms.duplicate(),
			"draw_calls": draw_calls.duplicate(),
			"objects_in_frame": objects_in_frame.duplicate(),
			"primitives_in_frame": primitives_in_frame.duplicate(),
		}

	func _process(_delta: float) -> void:
		if not active:
			return
		var now_tick: int = Time.get_ticks_usec()
		frame_intervals_ms.append(float(now_tick - previous_tick_usec) / 1000.0)
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		previous_tick_usec = now_tick

class RenderPulse:
	extends Control

	var phase: bool = false

	func pulse() -> void:
		phase = not phase
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.001 if phase else 0.002
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 1.0, 1.0, alpha), true)

var _errors: Array[String] = []
var _render_pulse: RenderPulse = null
var _focus_observations: int = 0
var _unfocused_observations: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	ProgressionStore.set_storage_path("user://labyrinth_progression_reward_animation_performance.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_reward_animation_performance.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_reward_animation_performance.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	_render_pulse = RenderPulse.new()
	_render_pulse.name = "RewardPerformanceRenderPulse"
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.size = Vector2.ONE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "RunScene must load for reward animation performance proof")
	if packed == null:
		_finish({})
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	var sampler := FrameSampler.new()
	root.add_child(sampler)
	var initially_focused: bool = await _acquire_probe_window_focus()
	_expect(initially_focused, "native reward animation probe window must become focused")
	await _settle_render_frames(8)

	var reward_state: Dictionary = _reward_state()
	_expect(str(reward_state.get("mode", "")) == "reward", "reward workload must enter card reward mode")
	await _show_reward_state(instance, reward_state)
	var initial_nodes: int = _subtree_node_count(instance)
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var idle: Dictionary = await _measure_idle(sampler)
	var victory_overlay: Control = instance.get("_post_combat_victory_overlay") as Control
	var board_state: Dictionary = ((reward_state.get("pending_reward", {}) as Dictionary).get("board_state", {}) as Dictionary)
	_expect(victory_overlay != null and not board_state.is_empty(), "victory workload must retain the completed combat board")
	_reset_board_instrumentation(instance)
	sampler.begin()
	var victory_started_usec: int = Time.get_ticks_usec()
	await PostCombatRewardSequence.play_victory(victory_overlay, false)
	var victory: Dictionary = _phase_result(sampler.finish())
	victory["completion_ms"] = float(Time.get_ticks_usec() - victory_started_usec) / 1000.0
	victory["board_instrumentation"] = _board_instrumentation(instance)
	_expect(not victory_overlay.visible, "victory animation must finish hidden")

	var per_card_flips: Dictionary = {}
	var flip_parts: Dictionary = await _prepare_reward_reveal(instance)
	var flip_slots: Array[Control] = flip_parts.get("slots", []) as Array[Control]
	PostCombatRewardSequence.settle_banner(
		flip_parts.get("banner") as TextureRect,
		flip_parts.get("title") as Label
	)
	for slot: Control in flip_slots:
		PostCombatRewardSequence.show_card_back(slot)
	await _settle_render_frames(4)
	for index: int in range(flip_slots.size()):
		_reset_board_instrumentation(instance)
		sampler.begin()
		var flip_started_usec: int = Time.get_ticks_usec()
		await PostCombatRewardSequence._flip_card(flip_slots[index])
		var flip_result: Dictionary = _phase_result(sampler.finish())
		flip_result["completion_ms"] = float(Time.get_ticks_usec() - flip_started_usec) / 1000.0
		flip_result["board_instrumentation"] = _board_instrumentation(instance)
		per_card_flips["card_%d" % (index + 1)] = flip_result
	_expect(_visible_reward_face_count(flip_slots) == flip_slots.size(), "isolated card flips must reveal every reward face")

	var reveal_parts: Dictionary = await _prepare_reward_reveal(instance)
	var reveal_slots: Array[Control] = reveal_parts.get("slots", []) as Array[Control]
	var nodes_before_reveal: int = _subtree_node_count(instance)
	_reset_board_instrumentation(instance)
	sampler.begin()
	var reveal_started_usec: int = Time.get_ticks_usec()
	await PostCombatRewardSequence.play_reward_reveal(
		instance.get("stage_root") as Control,
		reveal_parts.get("banner") as TextureRect,
		reveal_parts.get("title") as Label,
		reveal_slots,
		reveal_parts.get("secondary_actions") as Control,
		false
	)
	var reward_reveal: Dictionary = _phase_result(sampler.finish())
	reward_reveal["completion_ms"] = float(Time.get_ticks_usec() - reveal_started_usec) / 1000.0
	reward_reveal["board_instrumentation"] = _board_instrumentation(instance)
	instance.set("_reward_reveal_pending", false)
	_expect(_visible_reward_face_count(reveal_slots) == reveal_slots.size(), "production reward reveal must finish with every card face visible")
	_expect(_reward_transforms_are_settled(reveal_slots), "production reward reveal must restore authored card transforms")
	var nodes_after_reveal: int = _subtree_node_count(instance)
	_expect(nodes_after_reveal <= nodes_before_reveal, "reward reveal must not grow the prepared scene tree")

	await _settle_render_frames(6)
	await _save_root_screenshot("reward_animation_settled.png")
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var finally_focused: bool = DisplayServer.window_is_focused()
	_expect(finally_focused and _unfocused_observations == 0, "reward animation frame proof must remain focused")
	_expect(final_orphans <= initial_orphans, "reward animation workload must not increase orphan nodes")
	var throttle_samples: Array[Dictionary] = []
	_collect_throttle_samples(idle, "idle", throttle_samples)
	_collect_throttle_samples(victory, "victory", throttle_samples)
	_collect_throttle_samples(per_card_flips, "per_card_flips", throttle_samples)
	_collect_throttle_samples(reward_reveal, "reward_reveal", throttle_samples)
	_expect(throttle_samples.is_empty(), "reward animation proof must not contain a >=500 ms delivery-throttle signature")

	var results: Dictionary = {
		"schema_version": 1,
		"workload_id": WORKLOAD_ID,
		"viewport": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"probe_low_processor_usage_mode": OS.low_processor_usage_mode,
		"probe_low_processor_usage_mode_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
		"probe_foreground_window": initially_focused and finally_focused and _unfocused_observations == 0,
		"probe_focus_observations": _focus_observations,
		"probe_unfocused_observations": _unfocused_observations,
		"probe_throttle_threshold_ms": 500.0,
		"probe_throttle_samples": throttle_samples,
		"probe_window_mode": "windowed",
		"probe_render_pulse": true,
		"idle": idle,
		"victory": victory,
		"per_card_flips": per_card_flips,
		"reward_reveal": reward_reveal,
		"initial_nodes": initial_nodes,
		"nodes_before_reveal": nodes_before_reveal,
		"nodes_after_reveal": nodes_after_reveal,
		"initial_orphan_nodes": initial_orphans,
		"final_orphan_nodes": final_orphans,
		"final_objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"semantic_errors": _errors,
	}
	instance.queue_free()
	sampler.queue_free()
	await process_frame
	_finish(results)

func _finish(results: Dictionary) -> void:
	if _errors.is_empty():
		print("REWARD ANIMATION PERF RESULT: %s" % JSON.stringify(results))
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		push_error("REWARD ANIMATION PERF RESULT: FAIL %s" % JSON.stringify(results))
	ProgressionStore.clear_saved_run()
	quit(0 if _errors.is_empty() else 1)

func _reward_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7319, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_room_coord_of_type(engine, state, "combat")
	if combat_coord == Vector2i.ZERO:
		_expect(false, "reward workload run must expose an available combat room")
		return state
	state = engine.move_to_room(state, combat_coord)
	if str(state.get("mode", "")) == RunEngine.MODE_PRE_BATTLE:
		state = engine.begin_pre_battle_combat(state)
	if str(state.get("mode", "")) != "combat":
		_expect(false, "reward workload must enter combat before constructing its reward")
		return state
	state = engine.finish_combat(state, _victory_combat_state(state.get("combat_state", {}) as Dictionary))
	state["player_hp"] = 12
	state["player_max_hp"] = 24
	state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	state["magic_inventory"] = ["spark_dart"]
	state["reward_cards"] = ["spark_dart"]
	var pending_reward: Dictionary = (state.get("pending_reward", {}) as Dictionary).duplicate(true)
	pending_reward["cards"] = OFFERED_CARDS.duplicate()
	pending_reward["heal_amount"] = RunEngine.REWARD_HEAL
	pending_reward["ember_amount"] = 0
	pending_reward["intro_pending"] = false
	state["pending_reward"] = pending_reward
	return state

func _victory_combat_state(combat_state: Dictionary) -> Dictionary:
	var victory: Dictionary = combat_state.duplicate(true)
	var objective: Dictionary = victory.get("objective", {}) as Dictionary
	var objective_type: String = str(objective.get("type", CombatObjectiveRules.KILL_ALL))
	if objective_type == CombatObjectiveRules.REACH_EXIT:
		var target_tiles: Array[Vector2i] = _vector2i_array(CombatObjectiveRules.exit_target_tiles(objective))
		if not target_tiles.is_empty():
			var player: Dictionary = (victory.get("player", {}) as Dictionary).duplicate(true)
			player["pos"] = target_tiles[0]
			victory["player"] = player
		return victory
	if objective_type == CombatObjectiveRules.SURVIVE:
		victory["initiative_clock"] = int(objective.get("target_clock", victory.get("initiative_clock", 0)))
		return victory
	var enemies: Array = (victory.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	victory["enemies"] = enemies
	return victory

func _show_reward_state(instance: Node, state: Dictionary) -> void:
	root.gui_release_focus()
	root.warp_mouse(root.get_viewport().get_visible_rect().size - Vector2(2.0, 2.0))
	instance.call("_load_run_state", state)
	await _settle_render_frames(5)
	var settled_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	settled_state["notice"] = ""
	settled_state["grimoire_notice"] = ""
	settled_state["grimoire_unread"] = []
	var progression: Dictionary = (settled_state.get("progression", {}) as Dictionary).duplicate(true)
	progression["grimoire_unread"] = []
	settled_state["progression"] = progression
	var pending_reward: Dictionary = (settled_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	pending_reward["intro_pending"] = false
	settled_state["pending_reward"] = pending_reward
	instance.set("_run_state", settled_state)
	instance.set("_reward_intro_suppressed", false)
	instance.set("_reward_reveal_pending", false)
	instance.call("_refresh_ui")
	PostCombatRewardSequence.hide_victory(instance.get("_post_combat_victory_overlay") as Control)
	await _settle_render_frames(6)

func _prepare_reward_reveal(instance: Node) -> Dictionary:
	instance.set("_reward_intro_suppressed", false)
	instance.set("_reward_reveal_pending", true)
	instance.call("_refresh_ui")
	await _settle_render_frames(5)
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var slots: Array[Control] = []
	if card_row != null:
		for child: Node in card_row.get_children():
			if child is Control:
				slots.append(child as Control)
	_expect(slots.size() == OFFERED_CARDS.size(), "prepared reward reveal must contain exactly three card slots")
	return {
		"slots": slots,
		"banner": instance.get("_relic_choice_banner") as TextureRect,
		"title": instance.get("_relic_choice_title") as Label,
		"secondary_actions": instance.find_child("RewardSecondaryActions", true, false) as Control,
	}

func _measure_idle(sampler: FrameSampler) -> Dictionary:
	sampler.begin()
	for _frame: int in range(IDLE_FRAMES):
		await _await_render_frame()
	return _phase_result(sampler.finish())

func _phase_result(sampled: Dictionary) -> Dictionary:
	var intervals: Array[float] = sampled.get("frame_interval_ms", []) as Array[float]
	var process_samples: Array[float] = sampled.get("process_ms", []) as Array[float]
	var draw_samples: Array[float] = sampled.get("draw_calls", []) as Array[float]
	var object_samples: Array[float] = sampled.get("objects_in_frame", []) as Array[float]
	var primitive_samples: Array[float] = sampled.get("primitives_in_frame", []) as Array[float]
	return {
		"measurement_class": "rendered_frame_interval",
		"sample_count": intervals.size(),
		"frame_interval_ms": _stats(intervals),
		"process_ms": _stats(process_samples),
		"draw_calls": _stats(draw_samples),
		"objects_in_frame": _stats(object_samples),
		"primitives_in_frame": _stats(primitive_samples),
		"frames_over_16_67_ms": _count_over(intervals, 16.67),
		"frames_over_20_ms": _count_over(intervals, 20.0),
		"frames_over_33_33_ms": _count_over(intervals, 33.33),
		"raw_frame_intervals_ms": intervals,
		"raw_process_ms": process_samples,
		"raw_draw_calls": draw_samples,
		"raw_objects_in_frame": object_samples,
		"raw_primitives_in_frame": primitive_samples,
	}

func _stats(source: Array[float]) -> Dictionary:
	if source.is_empty():
		return {"mean": 0.0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var values: Array[float] = source.duplicate()
	values.sort()
	var sum: float = 0.0
	for value: float in values:
		sum += value
	return {
		"mean": sum / float(values.size()),
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[values.size() - 1],
	}

func _percentile(values: Array[float], percentile: float) -> float:
	var index: int = clampi(int(ceil(float(values.size()) * percentile)) - 1, 0, values.size() - 1)
	return values[index]

func _count_over(values: Array[float], threshold: float) -> int:
	var count: int = 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count

func _visible_reward_face_count(slots: Array[Control]) -> int:
	var count: int = 0
	for slot: Control in slots:
		var widget: Control = slot.find_child("CardWidget", true, false) as Control
		var back: TextureRect = slot.find_child(PostCombatRewardSequence.CARD_BACK_NAME, true, false) as TextureRect
		_expect(widget != null and back != null and widget.visible != back.visible, "reward slot must show exactly one face")
		if widget != null and widget.visible:
			count += 1
	return count

func _reward_transforms_are_settled(slots: Array[Control]) -> bool:
	for slot: Control in slots:
		var scaler: Control = slot.find_child(PostCombatRewardSequence.CARD_FRAME_NAME, true, false) as Control
		if scaler == null:
			return false
		var base_position: Vector2 = scaler.get_meta("reward_reveal_base_position", scaler.position) as Vector2
		var base_scale: Vector2 = scaler.get_meta("reward_reveal_base_scale", scaler.scale) as Vector2
		if not scaler.position.is_equal_approx(base_position) or not scaler.scale.is_equal_approx(base_scale):
			return false
	return true

func _reset_board_instrumentation(instance: Node) -> void:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board != null and board.has_method("reset_render_instrumentation"):
		board.call("reset_render_instrumentation")

func _board_instrumentation(instance: Node) -> Dictionary:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null or not board.has_method("render_instrumentation_snapshot"):
		return {}
	return board.call("render_instrumentation_snapshot") as Dictionary

func _collect_throttle_samples(value: Variant, path: String, result: Array[Dictionary]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value as Dictionary
		for key_var: Variant in dictionary:
			var key: String = str(key_var)
			if key == "raw_frame_intervals_ms":
				for sample_var: Variant in dictionary[key_var] as Array:
					var sample: float = float(sample_var)
					if sample >= 500.0:
						result.append({"path": "%s.%s" % [path, key], "value_ms": sample})
				continue
			_collect_throttle_samples(dictionary[key_var], "%s.%s" % [path, key], result)
	elif typeof(value) == TYPE_ARRAY:
		var values: Array = value as Array
		for index: int in range(values.size()):
			_collect_throttle_samples(values[index], "%s[%d]" % [path, index], result)

func _first_available_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in engine.available_moves(state):
		if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _vector2i_array(values: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if values is Array:
		for value: Variant in values as Array:
			if value is Vector2i:
				result.append(value)
	return result

func _await_render_frame() -> void:
	if _render_pulse != null:
		_render_pulse.pulse()
	await RenderingServer.frame_post_draw
	_focus_observations += 1
	if not DisplayServer.window_is_focused():
		_unfocused_observations += 1

func _acquire_probe_window_focus() -> bool:
	for _attempt: int in range(30):
		DisplayServer.window_move_to_foreground()
		await _await_render_frame()
		if DisplayServer.window_is_focused():
			return true
	return false

func _settle_render_frames(count: int) -> void:
	for _frame: int in range(count):
		await _await_render_frame()

func _save_root_screenshot(file_name: String) -> void:
	await _settle_render_frames(3)
	var image: Image = root.get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s must capture a renderer frame" % file_name)
	if image == null or image.is_empty():
		return
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.get_size() == VIEWPORT_SIZE, "%s must capture 1920x1080" % file_name)
	_expect(image.save_png("%s/%s" % [OUTPUT_DIR, file_name]) == OK, "%s could not be saved" % file_name)

func _subtree_node_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _subtree_node_count(child)
	return count

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
