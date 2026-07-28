extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://reward_composition_v1_proof"
const OFFERED_CARDS: Array[String] = ["spark_dart", "frostbolt", "firebrand_volley"]
const OFFERED_RELICS: Array[String] = ["iron_lung", "ember_lens", "pilgrim_boots"]
const OWNED_CARD_ID: String = "spark_dart"
const NEW_CARD_ID: String = "frostbolt"
const PROOF_VERSION: String = "v1"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_reward_composition_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_reward_composition_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_reward_composition_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	_clear_probe_output(OUTPUT_DIR)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Reward composition proof must run with a real display renderer")
	else:
		await _capture_configuration(Vector2i(1920, 1080), 1.00)
		await _capture_configuration(Vector2i(1280, 720), 1.00)
		await _capture_configuration(Vector2i(1280, 800), 1.25)
	var defaults: Dictionary = SettingsStore.default_settings()
	SettingsStore.save_settings(defaults)
	SettingsStore.apply_settings(defaults, root, false)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_configuration(resolution: Vector2i, ui_scale: float) -> void:
	await _configure_window(resolution, ui_scale)
	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		resolution.x,
		resolution.y,
		roundi(ui_scale * 100.0)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for reward composition proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()

	await _show_state(instance, _reward_state(false))
	var reward_parts: Dictionary = _assert_reward_layout(instance, resolution, ui_scale, false)
	await _save_root_screenshot(
		"%s/card_reward_injured_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_card_focus(
		reward_parts.get("new_card") as Control,
		"%s/card_reward_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_button_focus(
		reward_parts.get("recover_button") as Button,
		"%s/card_reward_recover_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	await _show_state(instance, _reward_state(true))
	_assert_reward_layout(instance, resolution, ui_scale, true)
	await _save_root_screenshot(
		"%s/card_reward_full_health_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	await _show_state(instance, _treasure_state())
	var relic_parts: Dictionary = _assert_relic_layout(instance, resolution, ui_scale)
	await _save_root_screenshot(
		"%s/relic_reward_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)
	await _capture_relic_focus(
		relic_parts.get("middle_relic") as Control,
		"%s/relic_reward_focused_%s.png" % [output_dir, PROOF_VERSION],
		resolution
	)

	instance.queue_free()
	await _settle()

func _configure_window(resolution: Vector2i, ui_scale: float) -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle()
	root.size = resolution
	await _settle()
	print("Reward proof viewport=%s window=%s target=%s ui=%d" % [
		root.get_viewport().get_visible_rect().size,
		root.size,
		resolution,
		roundi(ui_scale * 100.0)
	])

func _reward_state(full_health: bool) -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7319, ProgressionStore.default_data())
	state["mode"] = "reward"
	state["player_hp"] = 24 if full_health else 12
	state["player_max_hp"] = 24
	state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	state["magic_inventory"] = [OWNED_CARD_ID]
	state["reward_cards"] = [OWNED_CARD_ID]
	state["pending_reward"] = {
		"cards": OFFERED_CARDS.duplicate(),
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	return state

func _treasure_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7321, ProgressionStore.default_data())
	var treasure_coord: Vector2i = _first_room_coord_of_type(engine, state, "treasure")
	if treasure_coord == Vector2i.ZERO:
		_fail("Reward proof run should include a treasure room")
		return state
	var room: Dictionary = engine.room_metadata(state, treasure_coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [treasure_coord.x, treasure_coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = treasure_coord
	state["current_room_layout"] = engine.call(
		"_display_layout_for_room",
		int(state.get("seed", 0)),
		room,
		Vector2i(1, 0)
	)
	state["mode"] = "treasure"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = OFFERED_RELICS.duplicate()
	return state

func _show_state(instance: Node, state: Dictionary) -> void:
	root.warp_mouse(Vector2(8.0, 8.0))
	instance.call("_load_run_state", state)
	await _settle()
	var settled_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	settled_state["notice"] = ""
	settled_state["grimoire_notice"] = ""
	settled_state["grimoire_unread"] = []
	var progression: Dictionary = (settled_state.get("progression", {}) as Dictionary).duplicate(true)
	progression["grimoire_unread"] = []
	settled_state["progression"] = progression
	instance.set("_run_state", settled_state)
	instance.call("_refresh_ui")
	await _freeze_reward_title(instance)
	await _settle()

func _freeze_reward_title(instance: Node) -> void:
	await create_timer(0.12).timeout
	var title_effect: Node = instance.get("_relic_choice_title_effect") as Node
	if title_effect != null:
		title_effect.set_process(false)
		title_effect.set("phase", 0.0)
		title_effect.call("_animate_labels")

func _assert_reward_layout(instance: Node, resolution: Vector2i, ui_scale: float, full_health: bool) -> Dictionary:
	var result: Dictionary = {}
	var label: String = "%dx%d @ %d%%" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var overlay: Control = instance.get("_relic_choice_overlay") as Control
	var backdrop: ColorRect = instance.get("_relic_choice_backdrop") as ColorRect
	var banner: TextureRect = instance.get("_relic_choice_banner") as TextureRect
	var title: Label = instance.get("_relic_choice_title") as Label
	var stack: VBoxContainer = instance.find_child("RewardChoiceStack", true, false) as VBoxContainer
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var recover_button: Button = instance.find_child("RewardRecoverButton", true, false) as Button
	var hand_row: Control = instance.get_node(
		"UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow"
	) as Control
	if overlay == null or not overlay.visible:
		_fail("%s card reward should show the stage selection overlay" % label)
	if backdrop == null or not backdrop.visible or backdrop.color.a < 0.60:
		_fail("%s card reward should visibly dim the room behind the decision" % label)
	if banner == null or not banner.visible or banner.texture == null:
		_fail("%s card reward should put its instruction text on a raster foreground banner" % label)
	if title == null or title.text != "GROW YOUR POWER" or not title.visible:
		_fail("%s card reward should keep the game-native selection title" % label)
	elif title.get_theme_font_size("font_size") > 32 or title.get_theme_constant("outline_size") > 2:
		_fail("%s card reward should use restrained runtime text on the raster banner" % label)
	if hand_row == null or hand_row.visible:
		_fail("%s card reward should not occupy the combat hand strip" % label)
	if stack == null or card_row == null or card_row.get_child_count() != 3:
		_fail("%s should show one centered stack with exactly three card choices" % label)
		return result
	if recover_button == null:
		_fail("%s should place Recover in a button below the three cards" % label)
		return result
	var title_rect: Rect2 = title.get_global_rect()
	var banner_rect: Rect2 = banner.get_global_rect()
	var row_rect: Rect2 = card_row.get_global_rect()
	var button_rect: Rect2 = recover_button.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if title_rect.end.y > row_rect.position.y + 2.0:
		_fail("%s selection title should sit above the card row" % label)
	if button_rect.position.y < row_rect.end.y - 2.0:
		_fail("%s Recover should sit beneath the card row" % label)
	if button_rect.size.x >= row_rect.size.x:
		_fail("%s Recover should remain visually subordinate to the offer row" % label)
	if (
		banner_rect.get_center().distance_to(title_rect.get_center()) > 2.0
		or title_rect.size.x > banner_rect.size.x + 2.0
		or title_rect.size.y > banner_rect.size.y + 2.0
	):
		_fail("%s instruction text should read as part of its banner" % label)
	var composition_rect: Rect2 = banner_rect.merge(row_rect).merge(button_rect)
	if absf(composition_rect.get_center().x - viewport_rect.get_center().x) > viewport_rect.size.x * 0.06:
		_fail("%s reward composition should remain horizontally centered" % label)
	if absf(composition_rect.get_center().y - viewport_rect.get_center().y) > viewport_rect.size.y * 0.18:
		_fail("%s reward composition should sit in the central foreground" % label)
	if not viewport_rect.encloses(banner_rect) or not viewport_rect.encloses(row_rect) or not viewport_rect.encloses(button_rect):
		_fail("%s reward stack should fit the visible viewport" % label)
	if not recover_button.text.contains("SKIP & RECOVER"):
		_fail("%s Recover should make the skipped-card consequence explicit" % label)
	var expected_projection: String = "24 → 24" if full_health else "12 → 15"
	if not recover_button.text.contains("+%d HP" % RunEngine.REWARD_HEAL) or not recover_button.text.contains(expected_projection):
		_fail("%s Recover should show exact healing and %s" % [label, expected_projection])
	if recover_button.focus_mode != Control.FOCUS_ALL or recover_button.focus_neighbor_top == NodePath():
		_fail("%s Recover should expose visible focus and return navigation to the cards" % label)
	var visible_cards: int = 0
	for child: Node in card_row.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		var card_id: String = str(slot.get_meta("reward_card_id", ""))
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		if card_id.is_empty() or card_widget == null or badge == null:
			_fail("%s reward slot should contain card identity and ownership state" % label)
			continue
		visible_cards += 1
		if card_widget.focus_mode != Control.FOCUS_ALL or card_widget.focus_neighbor_bottom == NodePath():
			_fail("%s card %s should support focus navigation to Recover" % [label, card_id])
		if not viewport_rect.encloses(card_widget.get_global_rect()):
			_fail("%s card %s should fit the visible viewport" % [label, card_id])
		if card_id == OWNED_CARD_ID:
			result["owned_card"] = card_widget
			_assert_badge_text(badge, "OWNED", label)
		elif card_id == NEW_CARD_ID:
			result["new_card"] = card_widget
			_assert_badge_text(badge, "NEW", label)
	if visible_cards != 3:
		_fail("%s should visibly render all three reward cards" % label)
	result["recover_button"] = recover_button
	return result

func _assert_relic_layout(instance: Node, resolution: Vector2i, ui_scale: float) -> Dictionary:
	var result: Dictionary = {}
	var label: String = "%dx%d @ %d%%" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var overlay: Control = instance.get("_relic_choice_overlay") as Control
	var backdrop: ColorRect = instance.get("_relic_choice_backdrop") as ColorRect
	var banner: TextureRect = instance.get("_relic_choice_banner") as TextureRect
	var title: Label = instance.get("_relic_choice_title") as Label
	var bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if overlay == null or not overlay.visible:
		_fail("%s relic reward should show the stage selection overlay" % label)
	if backdrop == null or not backdrop.visible or backdrop.color.a < 0.60:
		_fail("%s relic reward should visibly dim the room behind the decision" % label)
	if banner == null or not banner.visible or banner.texture == null:
		_fail("%s relic reward should put its instruction text on a raster foreground banner" % label)
	if title == null or title.text != "CLAIM YOUR TREASURE" or not title.visible:
		_fail("%s relic reward should keep the game-native selection title" % label)
	if bar == null or bar.get_child_count() != 3:
		_fail("%s relic reward should show exactly three centered relic choices" % label)
		return result
	var first_choice: Control = bar.get_child(0) as Control
	var middle_choice: Control = bar.get_child(1) as Control
	var last_choice: Control = bar.get_child(2) as Control
	var row_rect: Rect2 = first_choice.get_global_rect().merge(last_choice.get_global_rect())
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if title.get_global_rect().end.y > row_rect.position.y + 2.0:
		_fail("%s treasure title should sit directly above the relic offer row" % label)
	if not viewport_rect.encloses(row_rect):
		_fail("%s relic offer row should fit the visible viewport" % label)
	var relic_choices: Array[Control] = []
	relic_choices.append(first_choice)
	relic_choices.append(middle_choice)
	relic_choices.append(last_choice)
	for choice: Control in relic_choices:
		if choice.focus_mode != Control.FOCUS_ALL:
			_fail("%s relic choices should be keyboard/controller focusable" % label)
		if choice.focus_neighbor_left == NodePath() or choice.focus_neighbor_right == NodePath():
			_fail("%s relic choices should expose complete horizontal focus navigation" % label)
	if banner != null:
		var composition_rect: Rect2 = banner.get_global_rect().merge(row_rect)
		if absf(composition_rect.get_center().x - viewport_rect.get_center().x) > viewport_rect.size.x * 0.06:
			_fail("%s relic composition should remain horizontally centered" % label)
		if absf(composition_rect.get_center().y - viewport_rect.get_center().y) > viewport_rect.size.y * 0.18:
			_fail("%s relic composition should sit in the central foreground" % label)
	result["middle_relic"] = middle_choice
	return result

func _capture_card_focus(card_widget: Control, output_path: String, resolution: Vector2i) -> void:
	if card_widget == null:
		_fail("Missing New reward card for focus proof")
		return
	card_widget.grab_focus()
	await create_timer(0.16).timeout
	if not card_widget.has_focus() or card_widget.z_index != 20:
		_fail("Focused reward card should use the same visible lift as pointer hover")
	await _save_root_screenshot(output_path, resolution)
	card_widget.release_focus()
	await create_timer(0.16).timeout

func _capture_button_focus(button: Button, output_path: String, resolution: Vector2i) -> void:
	if button == null:
		_fail("Missing Recover button for focus proof")
		return
	button.grab_focus()
	await _settle()
	if not button.has_focus():
		_fail("Recover button should accept visible keyboard/controller focus")
	await _save_root_screenshot(output_path, resolution)
	button.release_focus()
	await _settle()

func _capture_relic_focus(choice: Control, output_path: String, resolution: Vector2i) -> void:
	if choice == null:
		_fail("Missing middle relic for focus proof")
		return
	choice.grab_focus()
	await _settle()
	if not choice.has_focus() or choice.z_index != 40:
		_fail("Focused relic should use the same visible emphasis as pointer hover")
	await _save_root_screenshot(output_path, resolution)
	choice.release_focus()
	await _settle()

func _assert_badge_text(badge: Control, expected: String, label: String) -> void:
	if _label_with_text(badge, expected) == null:
		_fail("%s reward badge should read %s" % [label, expected])

func _save_root_screenshot(output_path: String, resolution: Vector2i) -> void:
	RenderingServer.force_draw(true, 0.0)
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != resolution:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested proof viewport. Preserve that real Metal render and
		# downsample it to the exact review resolution.
		image.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot: %s" % output_path)

func _first_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO

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
		var child_path: String = absolute_dir.path_join(file_name)
		if directory.current_is_dir():
			_clear_probe_output("%s/%s" % [output_dir, file_name])
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()
