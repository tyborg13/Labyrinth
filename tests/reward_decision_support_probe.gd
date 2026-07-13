extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://reward_simplification_v2_proof"
const OFFERED_CARDS: Array[String] = ["spark_dart", "frostbolt", "firebrand_volley", "threaded_path"]
const OWNED_CARD_ID: String = "spark_dart"
const NEW_CARD_ID: String = "frostbolt"
const PROOF_VERSION: String = "v7"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_reward_simplification_v2_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_reward_simplification_v2_probe.save")
	ProgressionStore.clear_saved_run()
	_clear_probe_output(OUTPUT_DIR)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Reward simplification proof must run with a real display renderer")
	else:
		for resolution_var: Variant in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			var resolution: Vector2i = resolution_var
			await _capture_resolution(resolution)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_resolution(resolution: Vector2i) -> void:
	await _configure_window(resolution)
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, resolution.x, resolution.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for reward simplification proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	var injured_state: Dictionary = _reward_state(false)
	await _show_reward_state(instance, injured_state)
	var slots: Dictionary = _assert_reward_layout(instance, resolution)
	var owned_slot: Control = slots.get(OWNED_CARD_ID) as Control
	var new_slot: Control = slots.get(NEW_CARD_ID) as Control
	_assert_ownership_badge(owned_slot, "OWNED")
	_assert_ownership_badge(new_slot, "NEW")
	_assert_injured_recover(instance)
	await _save_root_screenshot(
		"%s/reward_%dx%d_injured_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	await _save_root_screenshot(
		"%s/reward_%dx%d_new_before_hover_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	await _hover_card_and_capture(
		new_slot,
		"NEW",
		"%s/reward_%dx%d_new_hovered_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	await _save_root_screenshot(
		"%s/reward_%dx%d_owned_before_hover_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	await _hover_card_and_capture(
		owned_slot,
		"OWNED",
		"%s/reward_%dx%d_owned_hovered_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	await _show_reward_state(instance, _reward_state(true))
	_assert_reward_layout(instance, resolution)
	_assert_full_health_recover(instance)
	await _save_root_screenshot(
		"%s/reward_%dx%d_full_health_%s.png" % [output_dir, resolution.x, resolution.y, PROOF_VERSION],
		instance,
		resolution
	)
	instance.queue_free()
	await _settle()

func _configure_window(resolution: Vector2i) -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	await process_frame
	await process_frame
	root.size = resolution
	await process_frame
	print("Reward proof viewport=%s window=%s target=%s" % [root.get_viewport().get_visible_rect().size, root.size, resolution])

func _reward_state(full_health: bool) -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7319, ProgressionStore.default_data())
	state["mode"] = "reward"
	state["player_hp"] = 360 if full_health else 180
	state["player_max_hp"] = 360
	state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	state["magic_inventory"] = [OWNED_CARD_ID]
	state["reward_cards"] = [OWNED_CARD_ID]
	state["pending_reward"] = {
		"cards": OFFERED_CARDS.duplicate(),
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	return state

func _show_reward_state(instance: Node, state: Dictionary) -> void:
	root.warp_mouse(Vector2(8.0, 8.0))
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
	await _settle()
	await _freeze_reward_title(instance)

func _freeze_reward_title(instance: Node) -> void:
	await create_timer(0.70).timeout
	var title_effect: Node = instance.get("_relic_choice_title_effect") as Node
	if title_effect != null:
		title_effect.set_process(false)
		title_effect.set("phase", 0.0)
		title_effect.call("_animate_labels")
	await _settle()

func _assert_reward_layout(instance: Node, resolution: Vector2i) -> Dictionary:
	var slots: Dictionary = {}
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var hand_scroll: ScrollContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll")
	if hand_box.get_child_count() != 5:
		_fail("%s should show four reward cards plus Recover" % resolution)
		return slots
	var scroll_rect: Rect2 = hand_scroll.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	var first_rect: Rect2 = (hand_box.get_child(0) as Control).get_global_rect()
	var last_rect: Rect2 = (hand_box.get_child(4) as Control).get_global_rect()
	if first_rect.position.x < scroll_rect.position.x - 1.0 or last_rect.end.x > scroll_rect.end.x + 1.0:
		_fail("%s reward choices should fit the hand viewport without horizontal clipping" % resolution)
	var visible_cards: int = 0
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var slot_rect: Rect2 = slot.get_global_rect()
		if not viewport_rect.encloses(slot_rect):
			_fail("%s reward choice should fit the visible viewport: %s" % [resolution, slot_rect])
		if absf(slot_rect.position.y - first_rect.position.y) > 1.0:
			_fail("%s reward choices should remain vertically aligned" % resolution)
		var card_id: String = str(slot.get_meta("reward_card_id", ""))
		if card_id.is_empty():
			continue
		slots[card_id] = slot
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		if card_widget == null or not card_widget.is_visible_in_tree() or card_widget.get_global_rect().size.x <= 1.0:
			_fail("%s should visibly render reward card %s" % [resolution, card_id])
		else:
			visible_cards += 1
	if visible_cards != 4:
		_fail("%s should visibly render all four reward cards" % resolution)
	if instance.find_child("RewardAttunementContext", true, false) != null:
		_fail("Reward surface should not render attunement/loadout context")
	if instance.find_child("RewardDestinationBadge", true, false) != null:
		_fail("Reward surface should not render destination badges")
	var stage_root: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot") as Control
	if stage_root.size.y < float(resolution.y) * 0.32:
		_fail("%s reward choices should preserve meaningful room-state height" % resolution)
	return slots

func _assert_ownership_badge(slot: Control, expected_text: String) -> void:
	if slot == null:
		_fail("Missing reward slot for %s proof" % expected_text)
		return
	var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
	var badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
	if card_widget == null or badge == null:
		_fail("%s reward card should contain its ownership badge" % expected_text)
		return
	var label: Label = _label_with_text(badge, expected_text)
	if label == null:
		_fail("Ownership badge should read %s" % expected_text)
	if badge.get_parent() != card_widget:
		_fail("%s badge should be a direct child of CardWidget" % expected_text)
	if badge.mouse_filter != Control.MOUSE_FILTER_IGNORE or not _control_descendants_ignore_mouse(badge):
		_fail("%s badge should ignore all mouse input" % expected_text)
	if not badge.z_as_relative or badge.z_index <= 0:
		_fail("%s badge should inherit card z-order and draw above its face" % expected_text)
	if not card_widget.get_global_rect().encloses(badge.get_global_rect()):
		_fail("%s badge should remain physically inside the card presentation" % expected_text)
	var title: Control = card_widget.get_node_or_null("Margin/VBox/TopRow/Title") as Control
	var cost: Control = card_widget.find_child("TimeCostBadge", true, false) as Control
	if title != null and badge.get_global_rect().intersects(title.get_global_rect()):
		_fail("%s badge should not cover its card title" % expected_text)
	if cost != null and badge.get_global_rect().intersects(cost.get_global_rect()):
		_fail("%s badge should not cover its card cost" % expected_text)

func _hover_card_and_capture(slot: Control, expected_text: String, output_path: String, instance: Node, resolution: Vector2i) -> void:
	if slot == null:
		_fail("Missing %s slot for hover proof" % expected_text)
		return
	var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
	var badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
	if card_widget == null or badge == null:
		_fail("Missing %s card/badge for hover proof" % expected_text)
		return
	var initial_badge_position: Vector2 = badge.position
	var initial_badge_local_scale: Vector2 = badge.scale
	var initial_card_rect: Rect2 = card_widget.get_global_rect()
	var initial_badge_rect: Rect2 = badge.get_global_rect()
	var initial_badge_anchor: Vector2 = _rect_anchor_within(initial_badge_rect, initial_card_rect)
	root.warp_mouse(card_widget.get_global_rect().get_center())
	card_widget.mouse_entered.emit()
	await create_timer(0.22).timeout
	await process_frame
	var hovered_card_rect: Rect2 = card_widget.get_global_rect()
	var hovered_badge_rect: Rect2 = badge.get_global_rect()
	var card_growth: Vector2 = Vector2(
		hovered_card_rect.size.x / initial_card_rect.size.x,
		hovered_card_rect.size.y / initial_card_rect.size.y
	)
	var badge_growth: Vector2 = Vector2(
		hovered_badge_rect.size.x / initial_badge_rect.size.x,
		hovered_badge_rect.size.y / initial_badge_rect.size.y
	)
	if card_growth.x < 1.085 or card_growth.y < 1.085 or card_widget.z_index != 20:
		_fail("%s card should reach its real hover scale and z-order" % expected_text)
	if badge.position != initial_badge_position or badge.scale != initial_badge_local_scale:
		_fail("%s badge local attachment should remain exact during hover" % expected_text)
	if not card_growth.is_equal_approx(badge_growth):
		_fail("%s badge rendered bounds should enlarge by exactly the card hover ratio" % expected_text)
	if _rect_anchor_within(hovered_badge_rect, hovered_card_rect).distance_to(initial_badge_anchor) > 0.002:
		_fail("%s badge should preserve its exact rendered anchor within the hovered card" % expected_text)
	if hovered_badge_rect.get_center().distance_to(initial_badge_rect.get_center()) < 8.0:
		_fail("%s badge should visibly move with the hovered card" % expected_text)
	if badge.z_index <= card_widget.z_index:
		_fail("%s badge should remain above the hovered card face" % expected_text)
	var title: Control = card_widget.get_node_or_null("Margin/VBox/TopRow/Title") as Control
	var cost: Control = card_widget.find_child("TimeCostBadge", true, false) as Control
	if title != null and hovered_badge_rect.intersects(title.get_global_rect()):
		_fail("%s badge should stay clear of its title while enlarged" % expected_text)
	if cost != null and hovered_badge_rect.intersects(cost.get_global_rect()):
		_fail("%s badge should stay clear of its cost while enlarged" % expected_text)
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if not viewport_rect.encloses(card_widget.get_global_rect()):
		_fail("%s hovered card should remain inside %s" % [expected_text, resolution])
	await _save_root_screenshot(output_path, instance, resolution)
	root.warp_mouse(Vector2(8.0, 8.0))
	card_widget.mouse_exited.emit()
	await create_timer(0.22).timeout
	await process_frame
	if not card_widget.get_global_rect().is_equal_approx(initial_card_rect) or not badge.get_global_rect().is_equal_approx(initial_badge_rect) or card_widget.z_index != 0:
		_fail("%s card and badge should complete their return animation" % expected_text)

func _rect_anchor_within(child_rect: Rect2, parent_rect: Rect2) -> Vector2:
	if parent_rect.size.x <= 0.0 or parent_rect.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		(child_rect.get_center().x - parent_rect.position.x) / parent_rect.size.x,
		(child_rect.get_center().y - parent_rect.position.y) / parent_rect.size.y
	)

func _assert_injured_recover(instance: Node) -> void:
	var heal_choice: PanelContainer = instance.find_child("RewardHealChoice", true, false) as PanelContainer
	if heal_choice == null:
		_fail("Injured proof should render Recover")
		return
	if int(heal_choice.get_meta("reward_heal_result_hp", -1)) != 240:
		_fail("Injured Recover should clamp to exactly 240 HP")
	_assert_recover_copy(heal_choice, "+60", "180 → 240")

func _assert_full_health_recover(instance: Node) -> void:
	var heal_choice: PanelContainer = instance.find_child("RewardHealChoice", true, false) as PanelContainer
	if heal_choice == null:
		_fail("Full-health proof should render Recover")
		return
	if int(heal_choice.get_meta("reward_heal_result_hp", -1)) != 360:
		_fail("Full-health Recover should remain clamped at exactly 360 HP")
	_assert_recover_copy(heal_choice, "+60", "360 → 360")

func _assert_recover_copy(heal_choice: PanelContainer, amount_text: String, projection_text: String) -> void:
	var labels: Array[Label] = _labels_under(heal_choice)
	if labels.size() != 2:
		_fail("Recover should contain only amount and HP projection labels")
	if _label_with_text(heal_choice, amount_text) == null:
		_fail("Recover should prominently show %s" % amount_text)
	if _label_with_text(heal_choice, projection_text) == null:
		_fail("Recover should show exact clamped values %s" % projection_text)
	if not heal_choice.tooltip_text.is_empty():
		_fail("Recover should not relocate explanatory copy into a tooltip")

func _save_root_screenshot(output_path: String, instance: Node, resolution: Vector2i) -> void:
	RenderingServer.force_draw(true, 0.0)
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert_screenshot_regions(instance, image)
	if image.get_size() != resolution:
		image.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _assert_screenshot_regions(instance: Node, image: Image) -> void:
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	for child: Node in hand_box.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var card_id: String = str(slot.get_meta("reward_card_id", ""))
		if card_id.is_empty():
			continue
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		if not _image_region_has_content(image, card_widget, 0.10):
			_fail("Captured framebuffer is missing card pixels for %s" % card_id)
		if not _image_region_has_content(image, badge, 0.035):
			_fail("Captured framebuffer is missing ownership badge pixels for %s" % card_id)
	var heal_choice: Control = instance.find_child("RewardHealChoice", true, false) as Control
	if not _image_region_has_content(image, heal_choice, 0.08):
		_fail("Captured framebuffer is missing Recover pixels")

func _image_region_has_content(image: Image, control: Control, minimum_ratio: float) -> bool:
	if image == null or image.is_empty() or control == null:
		return false
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var image_scale := Vector2(float(image.get_width()) / viewport_size.x, float(image.get_height()) / viewport_size.y)
	var rect: Rect2 = control.get_global_rect()
	var left: int = clampi(int(floor(rect.position.x * image_scale.x)), 0, image.get_width() - 1)
	var top: int = clampi(int(floor(rect.position.y * image_scale.y)), 0, image.get_height() - 1)
	var right: int = clampi(int(ceil(rect.end.x * image_scale.x)), left + 1, image.get_width())
	var bottom: int = clampi(int(ceil(rect.end.y * image_scale.y)), top + 1, image.get_height())
	var step: int = maxi(1, mini(right - left, bottom - top) / 28)
	var samples: int = 0
	var content: int = 0
	for y: int in range(top, bottom, step):
		for x: int in range(left, right, step):
			var pixel: Color = image.get_pixel(x, y)
			samples += 1
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) >= 0.08:
				content += 1
	return samples > 0 and float(content) / float(samples) >= minimum_ratio

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _label_with_text(node: Node, text: String) -> Label:
	for label: Label in _labels_under(node):
		if label.text == text:
			return label
	return null

func _control_descendants_ignore_mouse(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _control_descendants_ignore_mouse(child):
			return false
	return true

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

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
		if directory.current_is_dir():
			_clear_probe_output("%s/%s" % [output_dir, file_name])
			directory.remove(file_name)
		else:
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
