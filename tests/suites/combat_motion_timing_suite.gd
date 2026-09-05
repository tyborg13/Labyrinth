extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const OUTPUT_DIR: String = "user://probes/combat_motion_polish_v1"

static func run(tree: SceneTree, expect: Callable, capture: bool = false) -> void:
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for reduced_motion: bool in [false, true]:
		var capture_viewport: SubViewport
		if capture:
			capture_viewport = SubViewport.new()
			capture_viewport.size = Vector2i(1920, 1080)
			capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			capture_viewport.disable_3d = true
			tree.root.add_child(capture_viewport)
		var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
		if capture_viewport != null:
			capture_viewport.add_child(instance)
		else:
			tree.root.add_child(instance)
		await tree.process_frame
		await tree.process_frame
		_install_fixture(instance, reduced_motion)
		for _frame: int in range(3):
			await tree.process_frame
		await _test_card_resolution_overlap(tree, instance, expect, capture, reduced_motion)
		await _test_combined_counter_rewards(tree, instance, expect, capture, reduced_motion)
		await _test_intensity_motion(tree, instance, expect, reduced_motion)
		instance.queue_free()
		if capture_viewport != null:
			capture_viewport.queue_free()
		await tree.process_frame
	if capture:
		print(ProjectSettings.globalize_path(OUTPUT_DIR))

static func _test_card_resolution_overlap(tree: SceneTree, instance: Node, expect: Callable, capture: bool, reduced_motion: bool) -> void:
	var before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	instance.call("_on_card_pressed", 0)
	var player_tile: Vector2i = (before.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	instance.call("_on_board_tile_clicked", player_tile)
	var deadline: int = Time.get_ticks_msec() + 6000
	var overlap_seen: bool = false
	var initial_lock_seen: bool = bool(instance.get("_animation_lock"))
	while Time.get_ticks_msec() < deadline and bool(instance.get("_animation_lock")):
		if not overlap_seen and bool(instance.get("_player_popup_timeline_active")) and _card_proxy_count(instance) > 0:
			overlap_seen = true
			if capture:
				await _capture(instance, "card_consequence_and_pile_%s.png" % _motion_name(reduced_motion))
		await tree.process_frame
	expect.call(initial_lock_seen, "A committed card must still lock input during resolution")
	expect.call(overlap_seen, "The board consequence must begin while the committed card is still flying to its pile")
	expect.call(not bool(instance.get("_animation_lock")), "Overlapping card and board motion must return input after completing")
	expect.call(_card_proxy_count(instance) == 0, "The pile flight must clean up every proxy before input returns")
	expect.call(int((instance.get("_combat_state") as Dictionary).get("player", {}).get("stoneskin", 0)) > int((before.get("player", {}) as Dictionary).get("stoneskin", 0)), "Overlapping presentation must preserve the committed stoneskin effect")
	# The final hand has its own deferred container fit; inspect the settled dock,
	# not the intentional short suppression while its fan bounds are recomputed.
	for _frame: int in range(16):
		if int(instance.get("_hand_layout_pending_revision")) != int(instance.get("_hand_layout_revision")):
			break
		await tree.process_frame
	expect.call((instance.get("_play_meter") as Control).is_visible_in_tree(), "The card-play meter must return after the new hand settles")
	if capture:
		await _capture(instance, "card_resolved_%s.png" % _motion_name(reduced_motion))

static func _test_combined_counter_rewards(tree: SceneTree, instance: Node, expect: Callable, capture: bool, reduced_motion: bool) -> void:
	var before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	before["room_embers"] = 40
	before["death_rewards"] = []
	var after: Dictionary = before.duplicate(true)
	after["room_embers"] = 58
	after["death_rewards"] = [
		{"embers": 5, "card_plays": 1},
		{"embers": 6, "card_plays": 1},
		{"embers": 7, "card_plays": 1}
	]
	var before_plays: int = int(instance.call("_card_play_count_for_resolution_state", before))
	var completion: Dictionary = {"done": false}
	_track_death_rewards(instance, before, after, completion)
	expect.call(int(instance.get("_card_play_count_override")) == before_plays + 3, "A multi-kill must expose its final card-play budget immediately, without counting each kill serially")
	var gain_label: Label = _gain_label(instance)
	expect.call(gain_label != null and gain_label.text == "+18", "The combined ember reward must begin alongside the card-play reward")
	var meter: Control = instance.get("_play_meter") as Control
	var deadline: int = Time.get_ticks_msec() + 1500
	var sampled: bool = false
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		if reduced_motion:
			expect.call(meter.scale.is_equal_approx(Vector2.ONE), "Reduced-motion card-play feedback must keep stable geometry")
		if capture and not sampled and meter.modulate != Color.WHITE:
			sampled = true
			await _capture(instance, "combined_rewards_%s.png" % _motion_name(reduced_motion))
		await tree.process_frame
	expect.call(bool(completion.get("done", false)), "Combined death rewards must complete as one short presentation")
	expect.call(int(instance.get("_card_play_count_override")) == before_plays + 3, "The aggregate card-play reward must retain its exact total after feedback")
	expect.call(meter.scale.is_equal_approx(Vector2.ONE) and meter.modulate.is_equal_approx(Color.WHITE), "The play meter must settle cleanly after the aggregate reward")
	expect.call(int(instance.get("_ember_count_override")) == -1, "The ember presentation override must be released after feedback")

static func _test_intensity_motion(tree: SceneTree, instance: Node, expect: Callable, reduced_motion: bool) -> void:
	var content: Control = (instance.get("_intensity_content_hosts") as Dictionary).get("fire") as Control
	var completion: Dictionary = {"done": false}
	_track_intensity(instance, completion)
	var deadline: int = Time.get_ticks_msec() + 1500
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		if reduced_motion:
			expect.call(content.scale.is_equal_approx(Vector2.ONE), "Reduced-motion intensity feedback must keep stable geometry")
		await tree.process_frame
	expect.call(bool(completion.get("done", false)), "Intensity feedback must complete")
	expect.call(content.scale.is_equal_approx(Vector2.ONE) and content.modulate.is_equal_approx(Color.WHITE), "Intensity feedback must settle cleanly")

static func _track_death_rewards(instance: Node, before: Dictionary, after: Dictionary, completion: Dictionary) -> void:
	await instance.call("_animate_death_rewards", before, after)
	completion["done"] = true

static func _track_intensity(instance: Node, completion: Dictionary) -> void:
	await instance.call("_animate_intensity_gain", "fire", 3)
	completion["done"] = true

static func _card_proxy_count(instance: Node) -> int:
	var count: int = 0
	for child: Node in (instance.get("_card_fx_layer") as Control).get_children():
		if child is Control and not child.is_queued_for_deletion() and bool(child.get_meta("scaled_card_proxy", false)):
			count += 1
	return count

static func _gain_label(instance: Node) -> Label:
	for child: Node in (instance.get("_card_fx_layer") as Control).get_children():
		if child is Label and not child.is_queued_for_deletion() and bool(child.get_meta("ember_counter_feedback", false)):
			return child as Label
	return null

static func _motion_name(reduced_motion: bool) -> String:
	return "reduced" if reduced_motion else "normal"

static func _capture(instance: Node, filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = instance.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/%s" % [OUTPUT_DIR, filename])

static func _install_fixture(instance: Node, reduced_motion: bool) -> void:
	instance.call("_close_dialogue")
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	settings["ui_scale"] = 1.0
	instance.set("_settings", settings)
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": "Cinder Crossing", "coord": Vector2i(4, 3), "type": "combat",
		"element": "fire", "grid": grid, "player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 140, "max_hp": 140, "block": 0}],
		"traps": [], "terrain": [], "loot": []
	}
	var state: Dictionary = CombatEngine.new().create_combat(9811, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": ["stone_plate", "quick_stab", "lantern_shot"],
		"relics": [], "hand_size": 3, "heal_bonus": 0
	})
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	deck["hand"] = ["stone_plate", "quick_stab", "lantern_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout["coord"]
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
