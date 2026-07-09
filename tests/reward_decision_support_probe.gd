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
	await _capture_reward_state(
		packed,
		open_state,
		"ATTUNED 4/6 | 2 OPEN | CLAIMS -> RESERVE",
		"spark_dart",
		"frostbolt",
		false,
		"%s/reward_injured_open_new_duplicate_v3.png" % OUTPUT_DIR
	)
	await _capture_reward_state(
		packed,
		full_state,
		"ATTUNED 6/6 | FULL | CLAIMS -> RESERVE",
		"spark_dart",
		"white_silence",
		true,
		"%s/reward_full_health_full_attunement_v3.png" % OUTPUT_DIR
	)

func _capture_reward_state(packed: PackedScene, state: Dictionary, expected_context: String, duplicate_card_id: String, new_card_id: String, expect_fully_wasted_heal: bool, output_path: String) -> void:
	ProgressionStore.clear_saved_run()
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await _show_reward_state(instance, state)
	_assert_reward_layout(instance, expected_context)
	_assert_badge(instance, duplicate_card_id, "DUPLICATE", "reserve")
	_assert_badge(instance, new_card_id, "NEW", "reserve")
	var heal_choice: PanelContainer = instance.find_child("RewardHealChoice", true, false) as PanelContainer
	if heal_choice == null or not heal_choice.is_visible_in_tree():
		_fail("Reward visual fixture should render the Recover choice")
	elif expect_fully_wasted_heal and int(heal_choice.get_meta("reward_heal_wasted", -1)) != RunEngine.REWARD_HEAL:
		_fail("Full-health visual fixture should expose all Recover healing as wasted")
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path, instance)
	instance.queue_free()
	await process_frame
	await process_frame

func _show_reward_state(instance: Node, state: Dictionary) -> void:
	instance.set("_run_state", state.duplicate(true))
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
	var visible_card_widgets: int = 0
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		if absf(slot.get_global_rect().position.y - first_rect.position.y) > 1.0:
			_fail("Five reward choices should remain vertically aligned")
		if str(slot.get_meta("reward_card_id", "")).is_empty():
			continue
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var ownership_badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		var destination_badge: Control = slot.find_child("RewardDestinationBadge", true, false) as Control
		if card_widget == null or not card_widget.is_visible_in_tree() or card_widget.modulate.a <= 0.1 or card_widget.get_global_rect().size.x <= 1.0:
			_fail("Each reward card slot should contain a visibly rendered card widget")
			continue
		visible_card_widgets += 1
		if ownership_badge == null or not ownership_badge.is_visible_in_tree() or ownership_badge.modulate.a <= 0.1 or not card_widget.get_global_rect().intersects(ownership_badge.get_global_rect()):
			_fail("Each reward card should visibly render its New/Duplicate badge")
		if destination_badge == null or not destination_badge.is_visible_in_tree() or destination_badge.modulate.a <= 0.1 or not card_widget.get_global_rect().intersects(destination_badge.get_global_rect()):
			_fail("Each reward card should visibly render its destination badge")
	if visible_card_widgets != 4:
		_fail("Expected all four reward card widgets to be visible")

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

func _save_root_screenshot(output_path: String, instance: Node) -> void:
	RenderingServer.force_draw(true, 0.0)
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert_screenshot_choice_pixels(instance, image)
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _assert_screenshot_choice_pixels(instance: Node, image: Image) -> void:
	var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var visible_cards: int = 0
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot == null or str(slot.get_meta("reward_card_id", "")).is_empty():
			continue
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var ownership_badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		var destination_badge: Control = slot.find_child("RewardDestinationBadge", true, false) as Control
		if _image_region_has_content(image, card_widget):
			visible_cards += 1
		else:
			_fail("Captured framebuffer is missing visible card pixels for %s" % str(slot.get_meta("reward_card_id", "")))
		if not _image_region_has_content(image, ownership_badge, 0.035):
			_fail("Captured framebuffer is missing ownership badge pixels for %s" % str(slot.get_meta("reward_card_id", "")))
		if not _image_region_has_content(image, destination_badge, 0.035):
			_fail("Captured framebuffer is missing destination badge pixels for %s" % str(slot.get_meta("reward_card_id", "")))
	if visible_cards != 4:
		_fail("Captured framebuffer should visibly contain all four reward cards")
	var heal_choice: Control = instance.find_child("RewardHealChoice", true, false) as Control
	if not _image_region_has_content(image, heal_choice):
		_fail("Captured framebuffer is missing the Recover choice pixels")

func _image_region_has_content(image: Image, control: Control, minimum_ratio: float = 0.12) -> bool:
	if image == null or image.is_empty() or control == null:
		return false
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var scale := Vector2(float(image.get_width()) / viewport_size.x, float(image.get_height()) / viewport_size.y)
	var control_rect: Rect2 = control.get_global_rect()
	var left: int = clampi(int(floor(control_rect.position.x * scale.x)), 0, image.get_width() - 1)
	var top: int = clampi(int(floor(control_rect.position.y * scale.y)), 0, image.get_height() - 1)
	var right: int = clampi(int(ceil(control_rect.end.x * scale.x)), left + 1, image.get_width())
	var bottom: int = clampi(int(ceil(control_rect.end.y * scale.y)), top + 1, image.get_height())
	var sample_step: int = maxi(1, mini(right - left, bottom - top) / 28)
	var samples: int = 0
	var content_samples: int = 0
	for y: int in range(top, bottom, sample_step):
		for x: int in range(left, right, sample_step):
			var pixel: Color = image.get_pixel(x, y)
			samples += 1
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) >= 0.08:
				content_samples += 1
	return samples > 0 and float(content_samples) / float(samples) >= minimum_ratio

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
