extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://reward_decision_support_probe"
const OFFERED_CARDS: Array[String] = ["spark_dart", "frostbolt", "firebrand_volley", "threaded_path"]

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_reward_decision_support_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_reward_decision_support_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_reward_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_reward_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for reward decision-support probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var engine := RunEngine.new()
	var open_state: Dictionary = engine.create_new_run(7319, ProgressionStore.default_data())
	open_state["mode"] = "reward"
	open_state["player_hp"] = 180
	open_state["player_max_hp"] = 360
	open_state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	open_state["magic_inventory"] = ["spark_dart"]
	open_state["reward_cards"] = ["spark_dart"]
	open_state["pending_reward"] = {
		"cards": OFFERED_CARDS.duplicate(),
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	await _show_reward_state(instance, open_state)
	_assert_reward_layout(instance, "ATTUNED 4/6 | 2 OPEN | CLAIMS -> RESERVE")
	_assert_badge(instance, "spark_dart", "DUPLICATE", "reserve")
	_assert_badge(instance, "frostbolt", "NEW", "reserve")
	await _save_root_screenshot("%s/reward_injured_open_new_duplicate_v2.png" % OUTPUT_DIR)

	var full_state: Dictionary = open_state.duplicate(true)
	full_state["player_hp"] = 360
	full_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "threaded_path", "stone_plate"]
	full_state["magic_inventory"] = ["spark_dart"]
	full_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "threaded_path", "stone_plate"]
	full_state["pending_reward"] = {
		"cards": ["spark_dart", "white_silence", "wildfire_halo", "royal_bramble"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	await _show_reward_state(instance, full_state)
	_assert_reward_layout(instance, "ATTUNED 6/6 | FULL | CLAIMS -> RESERVE")
	_assert_badge(instance, "spark_dart", "DUPLICATE", "reserve")
	_assert_badge(instance, "white_silence", "NEW", "reserve")
	var heal_choice: PanelContainer = instance.find_child("RewardHealChoice", true, false) as PanelContainer
	if heal_choice == null or int(heal_choice.get_meta("reward_heal_wasted", -1)) != RunEngine.REWARD_HEAL:
		_fail("Full-health visual fixture should expose all Recover healing as wasted")
	await _save_root_screenshot("%s/reward_full_health_full_attunement_v2.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _show_reward_state(instance: Node, state: Dictionary) -> void:
	instance.set("_run_state", state)
	instance.set("_combat_state", {})
	instance.set("_selected_card_index", -1)
	instance.set("_drag_card_index", -1)
	instance.call("_refresh_ui")
	var settled_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	settled_state["notice"] = ""
	settled_state["grimoire_notice"] = ""
	settled_state["grimoire_unread"] = []
	var progression: Dictionary = (settled_state.get("progression", {}) as Dictionary).duplicate(true)
	progression["grimoire_unread"] = []
	settled_state["progression"] = progression
	instance.set("_run_state", settled_state)
	instance.call("_refresh_ui")
	root.warp_mouse(Vector2(8.0, 8.0))
	await process_frame
	await process_frame
	await process_frame

func _assert_reward_layout(instance: Node, expected_context: String) -> void:
	var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var hand_scroll: ScrollContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll")
	if hand_box.get_child_count() != 5:
		_fail("Expected four cards plus Recover in the reward row")
		return
	var context_label: Label = instance.find_child("RewardAttunementContextLabel", true, false) as Label
	if context_label == null or context_label.text != expected_context:
		_fail("Expected reward attunement context: %s" % expected_context)
	var first_rect: Rect2 = (hand_box.get_child(0) as Control).get_global_rect()
	var last_rect: Rect2 = (hand_box.get_child(4) as Control).get_global_rect()
	var scroll_rect: Rect2 = hand_scroll.get_global_rect()
	if first_rect.position.x < scroll_rect.position.x - 1.0 or last_rect.end.x > scroll_rect.end.x + 1.0:
		_fail("Five reward choices should remain fully visible without horizontal overflow")
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot != null and absf(slot.get_global_rect().position.y - first_rect.position.y) > 1.0:
			_fail("Five reward choices should remain vertically aligned")

func _assert_badge(instance: Node, card_id: String, expected_status: String, expected_destination: String) -> void:
	var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot == null or str(slot.get_meta("reward_card_id", "")) != card_id:
			continue
		if str(slot.get_meta("reward_status", "")).to_upper() != expected_status:
			_fail("%s should display %s" % [card_id, expected_status])
		if str(slot.get_meta("reward_destination", "")) != expected_destination:
			_fail("%s should display destination %s" % [card_id, expected_destination])
		return
	_fail("Missing reward choice slot for %s" % card_id)

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var directory := DirAccess.open(absolute_dir)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
