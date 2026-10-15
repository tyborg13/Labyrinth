extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/glossary_fixture.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const BeforeStack = preload("res://tests/glossary_card_stack_before.gd")
const Glossary = preload("res://scripts/glossary.gd")

const OUTPUT_DIR: String = "user://glossary_tooltip_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const CARD_POSITION := Vector2(700, 320)
const CARD_SIZE := Vector2(250, 352)
const POINTER_PARK := Vector2(8, 8)
const CARD_SETTLE_SECONDS: float = 0.5
const FOUR_COLUMN_PROOF_RELIC: String = "witchglass_lantern"
const OUTER_FLOW_PROOF_RELIC: String = "breaking_wheel"
var _failures: Array[String]
var _logic_only: bool = false
var _viewport: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ParallelRuntime.apply_from_environment()
	_logic_only = OS.get_cmdline_user_args().has("--verify-logic")
	if DisplayServer.get_name() == "headless" and not _logic_only:
		push_error("Glossary capture requires a real renderer")
		quit(1)
		return
	ProgressionStore.set_storage_path("user://glossary_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://glossary_probe_run.save")
	SettingsStore.set_storage_path("user://glossary_probe_settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.apply_settings(settings, root, false)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _settle()
	await _relics()
	await _card_identity()
	for failure: String in _failures: push_error(failure)
	print("GLOSSARY_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("GLOSSARY %s RESULT: %s" % ["PROBE LOGIC" if _logic_only else "VISUAL PROOF", "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _relics() -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	var state: Dictionary = Fixture.treasure_state()
	scene.call("_load_run_state", state)
	if scene.has_method("_close_dialogue"): scene.call("_close_dialogue")
	for _step: int in range(Fixture.REVEAL_STEPS):
		if not bool(scene.get("_treasure_reveal_active")): break
		await create_timer(Fixture.REVEAL_POLL_SECONDS).timeout
	await _settle()
	var choices: Control = scene.get("_relic_choice_bar") as Control
	var choice: Control = choices.get_node_or_null("RelicChoice_iron_lung") as Control
	_expect(choice != null, "Treasure fixture exposes Iron Lung")
	if choice != null:
		await _pointer(choice.get_global_rect().get_center())
		await _validate_and_capture(scene, choice, "relic_choice_hover")
		await _pointer(POINTER_PARK)
		await _focus_next_to(choice)
		await _validate_and_capture(scene, choice, "relic_choice_keyboard")
		_viewport.gui_release_focus()
		await _controller_focus(scene, choice)
		await _validate_and_capture(scene, choice, "relic_choice_controller")
	_viewport.gui_release_focus()
	for id: String in ["ember_lens", "pilgrim_boots"]:
		var other: Control = choices.get_node_or_null("RelicChoice_" + id) as Control
		_expect(other != null, "Additional choice exists: " + id)
		if other != null:
			await _pointer(other.get_global_rect().get_center())
			await _validate_and_capture(scene, other, "relic_choice_" + ("middle" if id == "ember_lens" else "right"))
	await _pointer(POINTER_PARK)
	await _all_relic_choice_positions(scene)
	state["mode"] = "room"
	state["pending_relics"] = []
	state["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	scene.call("_load_run_state", state)
	await _settle()
	scene.call("_close_large_map")
	await _settle()
	var badge: Control = scene.call("_relic_frame_for_id", "iron_lung") as Control
	_expect(badge != null, "Owned relic fixture exposes Iron Lung")
	if badge != null:
		await _pointer(badge.get_global_rect().get_center())
		await _validate_and_capture(scene, badge, "owned_relic_hover")
		await _pointer(POINTER_PARK)
		await _focus_next_to(badge)
		await _validate_and_capture(scene, badge, "owned_relic_keyboard")
		_viewport.gui_release_focus()
		await _controller_focus(scene, badge)
		await _validate_and_capture(scene, badge, "owned_relic_controller")
	scene.queue_free()
	await _settle()

func _validate_and_capture(scene: Node, owner: Control, name: String) -> void:
	await _settle()
	_validate_stack(scene, owner, name)
	await _save(name)

func _validate_stack(scene: Node, owner: Control, name: String) -> void:
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	_expect(stack.visible and stack._follow_target == owner, name + " uses live owner")
	var expected_keys: Array[String]
	var is_choice: bool = owner.has_meta("glossary_choice_row")
	if not is_choice: expected_keys.append("relic")
	var relic: Dictionary = owner.get_meta("glossary_relic") as Dictionary
	for id: String in Glossary.ids_in_text(str(relic["description"]), Glossary.MAX_RELIC_PANELS):
		expected_keys.append(str(Glossary.lookup(id)["icon"]))
	_expect(stack.entry_icon_keys() == expected_keys, name + " exact glossary order")
	var bounds: Rect2 = stack.get_global_rect()
	var owner_rect: Rect2 = Stack._visual_global_rect(owner)
	_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(bounds), name + " stack remains on screen " + str(bounds))
	_expect(not bounds.intersects(owner_rect), name + " stack does not overlap its owner")
	if is_choice:
		var row: Control = scene.get("_relic_choice_bar") as Control
		var choices: Array[Control]
		var row_bottom: float = owner_rect.end.y
		for child: Node in row.get_children():
			if child is Control and child.has_meta("glossary_relic"):
				choices.append(child as Control)
				var card_rect: Rect2 = Stack._visual_global_rect(child as Control)
				row_bottom = maxf(row_bottom, card_rect.end.y)
				_expect(not bounds.intersects(card_rect), name + " avoids relic card " + str(child.name))
		var banner: Control = scene.get("_relic_choice_banner") as Control
		_expect(not bounds.intersects(Stack._visual_global_rect(banner)), name + " avoids Claim your treasure banner")
		var panel_nodes: Array[Node] = stack.find_children("CardFocusTooltip_*", "PanelContainer", true, false)
		var column_height: float = 0.0
		var column_width: float = 0.0
		var actual_keys: Array[String]
		for panel_node: Node in panel_nodes:
			var panel: Control = panel_node as Control
			actual_keys.append(str(panel.get_meta("icon_key")))
			var minimum: Vector2 = panel.get_combined_minimum_size()
			column_height += minimum.y + (Stack.STACK_SEPARATION if column_height > 0.0 else 0.0)
			column_width = maxf(column_width, minimum.x)
			_expect(panel.size.is_equal_approx(minimum), name + " preserves natural panel size")
			_expect(bounds.encloses(panel.get_global_rect()), name + " encloses every panel")
		_expect(actual_keys == expected_keys, name + " rendered panels preserve first appearance order")
		var column_fits: bool = owner_rect.position.y + column_height <= VIEWPORT_SIZE.y - Stack.RELIC_CHOICE_SCREEN_MARGIN
		var left_fits: bool = owner == choices.front() and owner_rect.position.x >= column_width + Stack.RELIC_CHOICE_SIDE_CLEARANCE
		var right_fits: bool = owner == choices.back() and VIEWPORT_SIZE.x - owner_rect.end.x >= column_width + Stack.RELIC_CHOICE_SIDE_CLEARANCE
		var columns: int = int(stack.get_meta("glossary_choice_columns"))
		if columns < Stack.RELIC_CHOICE_FALLBACK_COLUMNS:
			_expect(bounds.end.y <= VIEWPORT_SIZE.y - Stack.RELIC_CHOICE_SCREEN_MARGIN, name + " respects 24 px bottom margin " + str(bounds))
		else:
			# Four columns are the director's final fallback. Require every
			# panel on screen; report fractional margin shortfalls explicitly.
			var first_row_height: float = 0.0
			var second_row_height: float = 0.0
			for index: int in range(panel_nodes.size()):
				var height: float = (panel_nodes[index] as Control).get_combined_minimum_size().y
				if index < Stack.RELIC_CHOICE_FLOW_COLUMNS:
					first_row_height = maxf(first_row_height, height)
				else:
					second_row_height = maxf(second_row_height, height)
			var three_column_height: float = first_row_height + second_row_height + (Stack.RELIC_CHOICE_GAP if second_row_height > 0.0 else 0.0)
			_expect(row_bottom + Stack.RELIC_CHOICE_GAP + three_column_height > VIEWPORT_SIZE.y - Stack.RELIC_CHOICE_SCREEN_MARGIN, name + " four columns only when three exceed bottom margin")
			var clearance: float = VIEWPORT_SIZE.y - bounds.end.y
			if clearance < Stack.RELIC_CHOICE_SCREEN_MARGIN:
				print("GLOSSARY FOUR-COLUMN BOTTOM CLEARANCE: %s %.4f px" % [name, clearance])
		if column_fits and (left_fits or right_fits):
			_expect(columns == 1, name + " fitting outer stack stays a column")
			_expect(is_equal_approx(bounds.position.y, owner_rect.position.y), name + " outer column top aligns")
			_expect(is_equal_approx(bounds.end.x, owner_rect.position.x - Stack.RELIC_CHOICE_GAP) if left_fits else is_equal_approx(bounds.position.x, owner_rect.end.x + Stack.RELIC_CHOICE_GAP), name + " outer column gap")
		else:
			_expect(columns in [3, 4], name + " below-row flow uses three or four columns")
			_expect(is_equal_approx(bounds.position.y, row_bottom + Stack.RELIC_CHOICE_GAP), name + " below entire row")
			var expected_left: float = clampf(owner_rect.get_center().x - bounds.size.x * 0.5, Stack.RELIC_CHOICE_SCREEN_MARGIN, VIEWPORT_SIZE.x - Stack.RELIC_CHOICE_SCREEN_MARGIN - bounds.size.x)
			_expect(is_equal_approx(bounds.position.x, expected_left), name + " flow centered and clamped")
			_expect(bounds.position.x >= Stack.RELIC_CHOICE_SCREEN_MARGIN and bounds.end.x <= VIEWPORT_SIZE.x - Stack.RELIC_CHOICE_SCREEN_MARGIN, name + " flow respects horizontal margin")
		_validate_panel_order(panel_nodes, columns, name)

	else:
		_expect(is_equal_approx(bounds.position.y, owner_rect.end.y + Stack.OWNED_RELIC_GAP), name + " eight pixels below owned icon")
		var expected_left: float = clampf(owner_rect.position.x, Stack.SAFE_MARGIN, VIEWPORT_SIZE.x - Stack.SAFE_MARGIN - bounds.size.x)
		_expect(is_equal_approx(bounds.position.x, expected_left), name + " owned left alignment and screen clamp")
		var tray: Control = scene.get("relic_bar") as Control
		_expect(not bounds.intersects(Stack._visual_global_rect(tray)), name + " avoids owned tray")
		var room_title: Control = scene.get("room_title") as Control
		_expect(not bounds.intersects(Stack._visual_global_rect(room_title)), name + " avoids room title")

func _validate_panel_order(panels: Array[Node], columns: int, name: String) -> void:
	var row_bottom: float = 0.0
	var previous_bottom: float = 0.0
	var row_left: float = (panels[0] as Control).get_global_rect().position.x if not panels.is_empty() else 0.0
	var gap: float = Stack.STACK_SEPARATION if columns == 1 else Stack.RELIC_CHOICE_GAP
	for index: int in range(panels.size()):
		var rect: Rect2 = (panels[index] as Control).get_global_rect()
		if index % columns == 0:
			_expect(is_equal_approx(rect.position.x, row_left), name + " rows share left edge")
			if index > 0:
				_expect(is_equal_approx(rect.position.y, previous_bottom + gap), name + " next row gap")
			row_bottom = rect.end.y
		else:
			var previous: Rect2 = (panels[index - 1] as Control).get_global_rect()
			_expect(is_equal_approx(rect.position.x, previous.end.x + gap), name + " first-appearance horizontal order and gap")
			_expect(is_equal_approx(rect.position.y, previous.position.y), name + " row top alignment")
			row_bottom = maxf(row_bottom, rect.end.y)
		previous_bottom = row_bottom
		for other_index: int in range(index):
			_expect(not rect.intersects((panels[other_index] as Control).get_global_rect()), name + " panels never overlap")

func _all_relic_choice_positions(scene: Node) -> void:
	var row: Control = scene.get("_relic_choice_bar") as Control
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	var cases: int = 0
	var layouts: Dictionary = {1: 0, 3: 0, 4: 0}
	var before_failures: int = _failures.size()
	for id: String in GameData.relics():
		stack.hide_stack()
		for child: Node in row.get_children():
			row.remove_child(child)
			child.queue_free()
		# Repeat the actual relic to exercise its authored card height in every
		# slot, with the same production layout and typography as normal offers.
		for _position: int in range(3):
			scene.call("_add_relic_choice", id, GameData.relic_def(id))
		await _settle()
		scene.call("_layout_relic_choice_overlay")
		await _settle()
		for position: int in range(3):
			var owner: Control = row.get_child(position) as Control
			owner.mouse_entered.emit()
			await _settle()
			_validate_stack(scene, owner, "%s choice position %d" % [id, position])
			var columns: int = int(stack.get_meta("glossary_choice_columns", 1))
			layouts[columns] = int(layouts[columns]) + 1
			if id == FOUR_COLUMN_PROOF_RELIC and position == 1:
				await _save("relic_choice_flow_four")
			if id == OUTER_FLOW_PROOF_RELIC and position == 0:
				await _save("relic_choice_outer_flow")
			owner.mouse_exited.emit()
			cases += 1
	print("GLOSSARY ALL-RELIC CHOICE FIT: %s (%d relics, %d positions, 1920x1080)" % ["PASS" if _failures.size() == before_failures else "FAIL", GameData.relics().size(), cases])
	print("GLOSSARY CHOICE LAYOUTS: column=%d, three=%d, four=%d" % [layouts[1], layouts[3], layouts[4]])

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)
	await _settle()

func _focus_next_to(target: Control) -> void:
	# Seed keyboard traversal at the target's preceding control, then use Tab.
	# Where the scene has no predecessor, focus still uses its production signal.
	var previous: Control = target.find_prev_valid_focus()
	if previous != null:
		previous.grab_focus()
		previous.focus_next = previous.get_path_to(target)
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = true
		_viewport.push_input(event, true)
		event = InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = false
		_viewport.push_input(event, true)
	else:
		target.grab_focus()
	await _settle()
	_expect(target.has_focus(), "Keyboard navigation reaches relic")

func _controller_focus(scene: Node, target: Control) -> void:
	scene.call("_controller_set_focus_candidate", {"kind": "relic", "key": str(target.get_path()), "control": target}, false)
	await _settle()
	_expect(target.has_focus(), "Controller candidate routing reaches relic")

func _card_identity() -> void:
	# Same focused card and frame for both renders. The legacy stack is frozen
	# from the base revision; baseline copy is independent of glossary.json.
	var surface := Control.new()
	_viewport.add_child(surface)
	var card: CardWidget = load("res://scenes/card_widget.tscn").instantiate()
	card.position = CARD_POSITION
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.configure("quick_stab")
	surface.add_child(card)
	await _settle()
	card.focus_mode = Control.FOCUS_ALL
	card.grab_focus()
	await create_timer(CARD_SETTLE_SECONDS).timeout
	_freeze_presentation(card)
	var definition: Dictionary = GameData.card_def("quick_stab")
	var rows: Array = ActionIcons.rows_for_card(definition)
	var entries: Array[Dictionary] = ActionIcons.tooltip_entries_for_rows(rows, ["time"])
	_expect(entries.any(func(entry: Dictionary) -> bool: return entry["icon"] == "follow_up"), "Focused card includes Follow-up keyword")
	var before_copy: Dictionary = {}
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tests/glossary_card_copy_before.json")):
		before_copy[str(entry["id"])] = entry
	var legacy_entries: Array = entries.duplicate(true)
	for entry: Dictionary in legacy_entries:
		var copy: Dictionary = before_copy.get(str(entry["icon"]), {}) as Dictionary
		if not copy.is_empty() and str(entry["tooltip"]) == ActionIcons.tooltip(str(entry["icon"])):
			entry["title"] = copy["name"]
			entry["description"] = copy["definition"]
	var before := BeforeStack.new()
	surface.add_child(before)
	before.show_for(card, legacy_entries)
	await _settle()
	var before_image: Image = await _save("card_keywords_before")
	before.hide_stack()
	before.queue_free()
	await _settle()
	var after := Stack.new()
	surface.add_child(after)
	after.show_for(card, entries)
	await _settle()
	var after_image: Image = await _save("card_keywords_after")
	if not _logic_only and before_image != null and after_image != null:
		var equal: bool = before_image.get_data() == after_image.get_data()
		_expect(equal, "Card keyword before/after pixels are identical")
		print("CARD KEYWORD PIXEL IDENTITY: %s" % ("PASS (exact RGBA equality)" if equal else "FAIL"))
	surface.queue_free()
	await _settle()

func _freeze_presentation(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children(): _freeze_presentation(child)

func _save(name: String) -> Image:
	if _logic_only: return null
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == VIEWPORT_SIZE, "Native 1920x1080 capture: " + name)
	if image != null:
		var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(name + ".png"))
		_expect(image.save_png(path) == OK, "Capture saved: " + name)
		print("GLOSSARY_CAPTURE=" + path)
	return image

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
