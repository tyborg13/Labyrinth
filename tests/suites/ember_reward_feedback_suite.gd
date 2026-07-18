extends RefCounted

const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const EmberRewardFeedback = preload("res://scripts/ember_reward_feedback.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	_test_roll_values_and_audio_contract(expect)
	await _test_live_header_feedback(tree, expect)
	await _test_reduced_motion_completion(tree, expect)

static func _test_roll_values_and_audio_contract(expect: Callable) -> void:
	var small_roll: Array = EmberRewardFeedback.roll_values(5, 8)
	var large_roll: Array = EmberRewardFeedback.roll_values(20, 100)
	expect.call(small_roll == [6, 7, 8], "Small ember rewards should visibly roll through each gained ember")
	expect.call(large_roll.size() == 6 and int(large_roll.back()) == 100, "Large ember rewards should reach the exact total in a fixed, brief number of counter steps")
	for index: int in range(1, large_roll.size()):
		expect.call(int(large_roll[index]) > int(large_roll[index - 1]), "Ember counter roll values should increase monotonically")
	expect.call(EmberRewardFeedback.total_amount([{"embers": 8}, {"embers": 10}, {"embers": 0}]) == 18, "Multi-kill ember rewards should combine into one exact counter gain")
	expect.call(not AttackSfxLibrary.SFX.has("reward.ember_collect"), "Enemy ember rewards should not retain a registered collect sound")

static func _test_live_header_feedback(tree: SceneTree, expect: Callable) -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(run_scene != null, "Run scene should load for ember reward feedback coverage")
	if run_scene == null:
		return
	var instance: Node = run_scene.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	instance.call("_close_dialogue")
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	var stats: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel") as Label
	var sfx_count_before: int = (instance.get("_sfx_players") as Array).size()
	var sprite_count_before: int = _direct_sprite_count(fx_layer)
	var death_states: Dictionary = _aggregated_death_reward_states(instance)
	var completion: Dictionary = {"done": false}
	_track_run_scene_death_rewards(instance, death_states.get("before", {}), death_states.get("after", {}), completion)
	await tree.create_timer(0.07).timeout
	await tree.process_frame
	var gain_label: Label = _ember_gain_label(fx_layer)
	expect.call(gain_label != null and gain_label.text == "+18", "A multi-kill should use one terse +N label for the combined ember reward")
	if gain_label != null:
		expect.call(stats.get_global_rect().grow(20.0).intersects(gain_label.get_global_rect()), "Ember gain feedback should stay attached to the header counter")
	expect.call(_direct_sprite_count(fx_layer) == sprite_count_before, "Ember gain feedback should not spawn board-traveling sprites")
	expect.call((instance.get("_sfx_players") as Array).size() == sfx_count_before, "Ember gain feedback should not acquire or play an SFX channel")
	await tree.create_timer(0.23).timeout
	await tree.process_frame
	var expected_total: int = int(death_states.get("expected_total", 58))
	expect.call(stats.text.ends_with("EMBERS %d" % expected_total), "The ember counter should reach the exact combined death-reward total")
	expect.call(stats.scale.is_equal_approx(Vector2.ONE) and stats.modulate.is_equal_approx(Color.WHITE), "The ember counter should settle quickly back to its normal presentation")
	expect.call(_ember_gain_label(fx_layer) == null, "Ember gain feedback should clear in under a third of a second")
	await tree.create_timer(0.20).timeout
	expect.call(bool(completion.get("done", false)), "RunScene death-reward feedback should return after its visuals settle")
	expect.call(not bool(instance.get("_animation_lock")), "Completed death-reward feedback should let the caller release the combat animation lock")
	instance.queue_free()
	await tree.process_frame

static func _track_run_scene_death_rewards(instance: Node, before_state: Dictionary, after_state: Dictionary, completion: Dictionary) -> void:
	instance.set("_animation_lock", true)
	await instance.call("_animate_death_rewards", before_state, after_state)
	instance.set("_animation_lock", false)
	completion["done"] = true

static func _test_reduced_motion_completion(tree: SceneTree, expect: Callable) -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var fx_layer := Control.new()
	host.add_child(fx_layer)
	var stats := Label.new()
	stats.text = "LV 1 EMBERS 40"
	stats.size = Vector2(240.0, 40.0)
	fx_layer.add_child(stats)
	var completion: Dictionary = {"done": false, "value": 40}
	_track_reduced_motion_feedback(host, fx_layer, stats, completion)
	await tree.create_timer(0.35).timeout
	expect.call(bool(completion.get("done", false)), "Reduced-motion ember feedback should return after its counter roll")
	expect.call(int(completion.get("value", -1)) == 48, "Reduced-motion ember feedback should settle on the exact rewarded total")
	host.queue_free()
	await tree.process_frame

static func _track_reduced_motion_feedback(host: Node, fx_layer: Control, stats: Label, completion: Dictionary) -> void:
	await EmberRewardFeedback.play(
		host,
		fx_layer,
		stats,
		8,
		40,
		48,
		true,
		func(value: int) -> void: completion["value"] = value
	)
	completion["done"] = true

static func _aggregated_death_reward_states(instance: Node) -> Dictionary:
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

static func _direct_sprite_count(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Sprite2D:
			count += 1
	return count

static func _ember_gain_label(node: Node) -> Label:
	for child: Node in node.get_children():
		if child is Label and not child.is_queued_for_deletion() and bool(child.get_meta("ember_counter_feedback", false)):
			return child as Label
	return null
