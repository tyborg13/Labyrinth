extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const COMBAT_READY_FRAME_LIMIT: int = 240
const CAPTURE_FRAME_LIMIT: int = 12

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://ember_reward_feedback_probe")
	ProgressionStore.set_storage_path("user://ember_reward_feedback_probe/progression.json")
	ProgressionStore.set_run_storage_path("user://ember_reward_feedback_probe/current_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_feedback()
	quit(0)

func _capture_feedback() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene did not load")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_load_run_state", RunEngine.new().create_new_run(456, ProgressionStore.default_data()))
	await process_frame
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		if str((run_engine.room_metadata(run_state, coord) as Dictionary).get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		_fail("Could not find a combat room for ember feedback proof")
		return
	instance.call("_on_map_view_room_selected", combat_coord, Vector2i(-1, -1), true)
	if not await _wait_for_combat_ready(instance):
		_fail("Combat UI did not become visibly ready without a pre-battle overlay")
		return
	instance.call("_close_dialogue")
	await process_frame
	await RenderingServer.frame_post_draw
	if not _viewport_shows_combat(instance):
		_fail("Combat nodes were ready, but the rendered viewport did not show the combat board")
		return
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	var stats: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel") as Label
	var sprite_count_before: int = _direct_sprite_count(fx_layer)
	var sfx_count_before: int = (instance.get("_sfx_players") as Array).size()
	var death_states: Dictionary = _aggregated_death_reward_states(instance)
	instance.call("_animate_death_rewards", death_states.get("before", {}), death_states.get("after", {}))
	await create_timer(0.07).timeout
	await process_frame
	var gain_label: Label = _ember_gain_label(fx_layer)
	if gain_label == null or gain_label.text != "+18":
		_fail("Expected one combined +18 header label for two death rewards")
		return
	if not stats.get_global_rect().grow(20.0).intersects(gain_label.get_global_rect()):
		_fail("Ember gain label was not attached to the header counter")
		return
	if _direct_sprite_count(fx_layer) != sprite_count_before:
		_fail("Ember feedback spawned a board-traveling sprite")
		return
	if (instance.get("_sfx_players") as Array).size() != sfx_count_before:
		_fail("Ember feedback acquired an SFX channel")
		return
	if not await _save_visible_combat_screenshot(instance, "user://ember_reward_feedback_probe/ember_counter_roll.png", true):
		_fail("Could not capture a visible combat frame while the +18 feedback was active")
		return
	await create_timer(0.28).timeout
	await process_frame
	var expected_total: int = int(death_states.get("expected_total", 58))
	if not stats.text.ends_with("EMBERS %d" % expected_total):
		_fail("Ember counter did not settle on the combined total of %d" % expected_total)
		return
	if _ember_gain_label(fx_layer) != null:
		_fail("Ember gain label lingered after the brief counter roll")
		return
	if not await _save_visible_combat_screenshot(instance, "user://ember_reward_feedback_probe/ember_counter_settled.png", false):
		_fail("Could not capture the visible settled combat frame")
		return
	print(ProjectSettings.globalize_path("user://ember_reward_feedback_probe"))
	instance.queue_free()
	await process_frame

func _aggregated_death_reward_states(instance: Node) -> Dictionary:
	var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var run_engine = instance.get("_run_engine")
	var held_embers: int = int(run_engine.call("held_embers", instance.get("_run_state")))
	before_state["room_embers"] = 40
	before_state["death_rewards"] = []
	var after_state: Dictionary = before_state.duplicate(true)
	after_state["room_embers"] = 58
	after_state["death_rewards"] = [
		{"embers": 8, "card_plays": 0, "tile": Vector2i(3, 4)},
		{"embers": 10, "card_plays": 0, "tile": Vector2i(5, 4)}
	]
	return {"before": before_state, "after": after_state, "expected_total": held_embers + 58}

func _direct_sprite_count(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Sprite2D:
			count += 1
	return count

func _ember_gain_label(node: Node) -> Label:
	for child: Node in node.get_children():
		if child is Label and not child.is_queued_for_deletion() and bool(child.get_meta("ember_counter_feedback", false)):
			return child as Label
	return null

func _wait_for_combat_ready(instance: Node) -> bool:
	for _frame: int in range(COMBAT_READY_FRAME_LIMIT):
		var current_run_state: Dictionary = instance.get("_run_state") as Dictionary
		var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
		var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
		var stats: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel") as Label
		var board_view: Control = instance.get("board_view") as Control
		var pre_battle_hidden: bool = pre_battle_scrim == null or not pre_battle_scrim.visible
		if str(current_run_state.get("mode", "")) == "combat" and not combat_state.is_empty() and not bool(instance.get("_animation_lock")) and pre_battle_hidden and stats.is_visible_in_tree() and board_view != null and board_view.is_visible_in_tree():
			await process_frame
			await RenderingServer.frame_post_draw
			return true
		await process_frame
	return false

func _save_visible_combat_screenshot(instance: Node, output_path: String, require_gain_label: bool) -> bool:
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	for _frame: int in range(CAPTURE_FRAME_LIMIT):
		await process_frame
		await RenderingServer.frame_post_draw
		var gain_label: Label = _ember_gain_label(fx_layer)
		if require_gain_label and (gain_label == null or not gain_label.is_visible_in_tree() or gain_label.modulate.a <= 0.05):
			continue
		if _viewport_shows_combat(instance):
			var image: Image = root.get_viewport().get_texture().get_image()
			return image.save_png(output_path) == OK
	return false

func _viewport_shows_combat(instance: Node) -> bool:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var board_view: Control = instance.get("board_view") as Control
	if board_view == null or not board_view.is_visible_in_tree():
		return false
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var board_rect: Rect2 = board_view.get_global_rect()
	var pixel_rect := Rect2i(
		int(board_rect.position.x * float(image.get_width()) / viewport_size.x),
		int(board_rect.position.y * float(image.get_height()) / viewport_size.y),
		int(board_rect.size.x * float(image.get_width()) / viewport_size.x),
		int(board_rect.size.y * float(image.get_height()) / viewport_size.y)
	).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if pixel_rect.size.x < 32 or pixel_rect.size.y < 32:
		return false
	var min_luma: float = 255.0
	var max_luma: float = 0.0
	var bright_samples: int = 0
	for sample_y: int in range(12):
		for sample_x: int in range(18):
			var pixel_x: int = pixel_rect.position.x + int((float(sample_x) + 0.5) * float(pixel_rect.size.x) / 18.0)
			var pixel_y: int = pixel_rect.position.y + int((float(sample_y) + 0.5) * float(pixel_rect.size.y) / 12.0)
			var color: Color = image.get_pixel(pixel_x, pixel_y)
			var luma: float = (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
			if luma >= 24.0:
				bright_samples += 1
	return max_luma - min_luma >= 36.0 and bright_samples >= 16

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
