extends "res://tests/controller_screen_sweep.gd"
## ui-28: one semantic/capture matrix for the old bar and the attached badges.
## --before records the baseline without asserting the new presentation.
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Scenario = preload("res://scripts/guided_combat_scenario.gd")
const SMALL_SIZE := Vector2i(1280, 800)
const SMALL_UI_SCALE: float = 1.15
const CAPTURE_SETTLE_SECONDS: float = 0.35
const PROBE_OUTPUT: String = "/private/tmp/labyrinth_codex/ui-28"
var _proof_size := Vector2i(1920, 1080)
var _proof_scale: float = 1.0
var _records: Array[Dictionary]
var _logic_only: bool = false
var _header_collisions: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_before = args.has("--before")
	_logic_only = args.has("--logic-only")
	if args.has("--small"):
		_proof_size = SMALL_SIZE
		_proof_scale = SMALL_UI_SCALE
	_output_dir = PROBE_OUTPUT.path_join("before" if _before else "after").path_join("%dx%d" % [_proof_size.x, _proof_size.y])
	if args.has("--output-dir"): _output_dir = args[args.find("--output-dir") + 1]
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not _logic_only:
		push_error("Renderer captures require window-server access; use --logic-only for headless semantics.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	Store.set_storage_path("user://ui28_profile.json")
	Store.set_run_storage_path("user://ui28_run.save")
	Settings.set_storage_path("user://ui28_settings.json")
	Analytics.set_storage_dir("user://ui28_analytics")
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	Store.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = _proof_scale
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = PROOF_SIZE
	root.size = _proof_size
	root.content_scale_factor = _proof_scale
	_viewport = SubViewport.new()
	_viewport.size = _proof_size
	# Match the production Window's logical envelope at this physical UI scale.
	var fit: float = minf(float(_proof_size.x) / PROOF_SIZE.x, float(_proof_size.y) / PROOF_SIZE.y) * _proof_scale
	_viewport.size_2d_override = Vector2i(Vector2(_proof_size) / fit)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	if _logic_only: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_router = root.get_node("InputRouter")
	_router.set_forced_state_for_test("controller", "xbox")
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set("_defer_initial_run_presentation", true)
	_viewport.add_child(_scene)
	_scene.set("_defer_initial_run_presentation", false)
	await _settle()
	await _load(_combat_state())
	await _pair("combat_hand")
	_scene.call("_controller_set_hand_focused", false)
	await _pair("combat_collapsed")
	_scene.call("_controller_set_hand_focused", true)
	await _scene.call("_on_card_pressed", 0)
	await _pair("combat_targeting")
	await _load(_combat_state())
	_scene.call("_controller_enter_board", true)
	await _scene.call("_on_board_tile_clicked", _scene.get("_combat_state")["player"]["pos"])
	await _pair("combat_movement")
	var empowered_fixture: Dictionary = _combat_state()
	empowered_fixture["combat_state"]["deck"]["hand"] = ["bloody_lunge"]
	_scene.call("_cancel_player_movement_selection")
	_scene.call("_cancel_card_selection")
	await _load(empowered_fixture)
	_scene.set("_controller_region", "hand")
	_scene.call("_controller_set_hand_focused", true)
	_scene.call("_controller_set_hand_index", 0)
	await _pair("combat_empower")
	await _load(_base_state())
	await _pair("room")
	_scene.call("_open_large_map")
	await _pair("map")
	await _load(_legacy_room_state())
	_scene.call("_open_large_map")
	await _pair("map_legacy_zoom")
	var pre: Dictionary = _base_state()
	for room: Dictionary in pre["rooms"].values():
		if str(room.get("type")) == "combat":
			pre["current_room"] = room["coord"]
			pre["mode"] = Run.MODE_PRE_BATTLE
			pre["pre_battle_pending"] = true
			pre["pre_battle_travel_dir"] = Vector2i(1, 0)
			break
	await _load(pre)
	await _pair("pre_battle")
	await _load(_character_state())
	for tab: String in ["equipment", "magic", "skills"]:
		_scene.call("_open_character_overlay", tab)
		await _pair("upgrade_" + tab)
		_scene.call("_close_card_upgrade_overlay")
	_scene.call("_open_grimoire_overlay")
	await _pair("gui_grimoire")
	_scene.call("_close_grimoire_overlay")
	await _load(EventFixture.fixture("hanged_knight", true))
	_scene.get("_event_view").finish_animation_for_test()
	await _pair("event_choice")
	_scene.get("_event_view")._activate_focused()
	await create_timer(CAPTURE_SETTLE_SECONDS).timeout
	_scene.get("_event_view").finish_animation_for_test()
	await _pair("event_result")
	await _load(GraftFixture.fixture())
	await _pair("graftwright_intro")
	var graft: Control = _scene.get("_graftwright_view")
	graft.find_child("GraftBrowse", true, false).pressed.emit()
	graft.select_donor("patched_cloak")
	(graft.find_child("SourceCard_0", true, false) as Control).grab_focus()
	await _pair("graftwright")
	graft.find_child("ChooseSacrifice", true, false).pressed.emit()
	await _pair("graftwright_picker_inspect")
	graft.request_leave()
	await _load(_shop_state())
	await _pair("scavenger")
	_scene.call("_open_magic_purge", "scavenger")
	await _pair("purge")
	var purge: Control = _scene.get("_magic_purge_overlay")
	purge.call("select_card", "spark_dart")
	await _pair("purge_confirmation")
	_scene.call("_close_magic_purge", false)
	_scene.call("_on_merchant_hide_pressed")
	await create_timer(CAPTURE_SETTLE_SECONDS).timeout
	_scene.call("_close_large_map")
	await _pair("room_shop")
	await _tutorial_matrix()
	var file := FileAccess.open(_output_dir.path_join("states.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"logic_only": _logic_only, "before": _before, "size": str(_proof_size), "ui_scale": _proof_scale, "states": _records, "failures": _failures}, "\t") + "\n")
	if not _logic_only: _write_contact_sheet()
	for failure: String in _failures: push_error(failure)
	print("HEADER NOTIFICATION OVERLAPS: " + str(_header_collisions))
	print("CONTROLLER GLYPH BADGE PROBE: %s (%d states; %s)" % ["PASS" if _failures.is_empty() else "FAIL", _records.size(), "HEADLESS SEMANTICS ONLY" if _logic_only else "NATIVE CAPTURES"])
	print(_output_dir)
	_scene.queue_free()
	await _settle()
	quit(0 if _failures.is_empty() else 1)

func _shop_state() -> Dictionary:
	var state: Dictionary = _base_state()
	for room: Dictionary in state["rooms"].values():
		if str(room.get("merchant_kind", "")) != "scavenger" and str(room.get("type", "")) != "scavenger": continue
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = true
		room[Run.MERCHANT_STOCK_KEY] = ["grave_mortar", "boiled_leather", "crimson_draught"]
		state["current_room"] = room["coord"]
		state["current_room_layout"] = Run.new().call("_display_layout_for_room", FIXTURE_SEED, room, Vector2i(1, 0))
		break
	state["mode"] = "room"
	state["held_embers"] = FIXTURE_BUDGET
	state["unbanked_embers"] = FIXTURE_BUDGET
	state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "grave_mortar"]
	return state

func _tutorial_matrix() -> void:
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = Tutorial.default_state()
	Store.save_data(profile)
	_scene.set("_progression", profile)
	var state: Dictionary = _combat_state()
	state["progression"] = profile
	state = Scenario.mark_run_eligible(state)
	state["combat_state"] = Scenario.prepare_for_run(state, state["combat_state"])
	await _load(state)
	for phase: String in Tutorial.phase_ids():
		_scene.set("_guided_tutorial_phase_id", phase)
		await _pair("tutorial_" + phase)
		if not _before:
			var prompt: Control = _scene.get("_contextual_combat_prompt")
			var action: Control = prompt.get("_controller_action")
			var requires_continue: bool = bool(Tutorial.phase_definition(phase).get("requires_continue", false))
			var badges: Array = _scene.get("_controller_glyph_badges").badges_snapshot()
			_expect(action.visible or (requires_continue and badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_accept")), phase + " retains its taught glyph inside the callout")
	var reduced: Dictionary = Settings.load_settings()
	reduced["reduced_motion"] = true
	_scene.call("_on_settings_changed", reduced)
	await _pair("tutorial_pass_turn_reduced_motion")

func _pair(label: String) -> void:
	for modality: String in ["controller", "pointer"]:
		_router.set_forced_state_for_test(modality, "steam_deck")
		_scene.call("_refresh_controller_prompts")
		await create_timer(CAPTURE_SETTLE_SECONDS).timeout
		await _settle()
		if label.begins_with("tutorial_"):
			_show_tutorial_catalog(label.trim_prefix("tutorial_").trim_suffix("_reduced_motion"))
			await _settle()
		var record: Dictionary = {"context": label, "modality": modality}
		if not _before:
			_expect(_scene.find_child("ControllerPromptBar", true, false) == null, label + " has no in-run bar node")
			var badges: Array = _scene.get("_controller_glyph_badges").badges_snapshot()
			record["badges"] = badges
			if modality == "pointer": _expect(badges.is_empty(), label + " pointer hides all controller badges")
			if modality == "controller":
				_assert_header_corners(record)
				_assert_badge_geometry(record)
				if label == "graftwright":
					var source: Control = _scene.get("_graftwright_view").find_child("SourceCard_0", true, false)
					var glyph: Control = source.find_child("GlyphBadge_controller_pass", true, false)
					_expect(source.has_focus() and glyph != null, "Focused inspectable Graftwright card has Y")
					if glyph != null: _assert_inset_corner(glyph, false, "Graftwright Inspect")
				if label == "graftwright_picker_inspect": _expect(not badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_pass"), "Equipment browser has no unavailable Inspect glyph")
				if label == "map_legacy_zoom": _expect(not badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_map_zoom"), "Legacy map drops zoom prompt")
				if label == "room_shop": _expect(not badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_hand_toggle"), "Rooms drop X Shop prompt")
			if modality == "controller" and label.begins_with("combat"):
				_expect(badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_pass"), label + " has Y on Pass")
				_expect(badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_hand_toggle"), label + " always has X on the hand")
				if label == "combat_empower": _expect(badges.any(func(badge: Dictionary) -> bool: return badge["action"] == "controller_empower"), "Available Empower has a seal glyph")
			for badge: Dictionary in badges:
				_expect(badge["family"] == "steam_deck", label + " uses the active controller family")
				_expect(not badge.has("label"), label + " has no redundant badge text")
				if label.begins_with("combat"):
					_expect(badge["action"] not in ["controller_accept", "controller_cancel", "controller_dpad", "controller_move"], label + " has no combat A/B/navigation glyph")
		var filename: String = label + "_" + modality + ".png"
		record["capture"] = filename if not _logic_only else "UNAVAILABLE: window-server access required"
		_records.append(record)
		print("GLYPH STATE: %s %s" % [label, modality])
		if not _logic_only:
			await RenderingServer.frame_post_draw
			var captured: Image = _viewport.get_texture().get_image()
			_expect(captured != null and captured.get_size() == _proof_size, filename + " exact physical resolution")
			if captured != null: _expect(captured.save_png(_output_dir.path_join(filename)) == OK, filename + " saves")
	_router.set_forced_state_for_test("controller", "steam_deck")

func _assert_inset_corner(badge: Control, bottom: bool, label: String) -> void:
	var target: Control = badge.target
	var parent: Control = badge.get_parent()
	var parent_scale: Vector2 = parent.get_global_transform().get_scale().abs()
	var corner: Vector2 = target.size if bottom else Vector2(target.size.x, 0.0)
	var inset := Vector2(-6.0, -6.0 if bottom else 6.0) / parent_scale
	var expected: Vector2 = parent.get_global_transform() * (corner + inset)
	var safe: Rect2 = badge.get_viewport_rect().grow(-4.0)
	var half: Vector2 = badge.visual_rect().size * 0.5
	expected = expected.clamp(safe.position + half, safe.end - half)
	_expect(badge.visual_rect().get_center().distance_to(expected) < 0.01, label + " centre is 6 UI pixels inward, clamped only on clipped axes to the 4-pixel viewport margin")
	_expect(is_equal_approx(badge.get_global_rect().size.y, 30.0), label + " has 30 UI-pixel height")
	_expect(badge.get_node_or_null("Label") == null, label + " has no action label")

func _assert_header_corners(record: Dictionary) -> void:
	var rects: Dictionary = {}
	for target: Control in [_scene.get("menu_button"), _scene.get("_section_map_hud_button")]:
		if target == null or not target.is_visible_in_tree(): continue
		var action: String = "controller_menu" if target == _scene.get("menu_button") else "controller_map"
		var badge: Control = target.get_node_or_null("GlyphBadge_" + action)
		_expect(badge != null and badge.is_visible_in_tree(), target.name + " carries its shortcut")
		if badge == null: continue
		var target_rect: Rect2 = target.get_global_rect()
		var badge_rect: Rect2 = badge.get_global_rect()
		var clamped_right: bool = absf(badge_rect.end.x - (_scene.get_viewport().get_visible_rect().end.x - 4.0)) < 0.5
		_expect(absf(badge_rect.get_center().x - target_rect.get_center().x) < 0.5 or clamped_right, target.name + " badge is centred on the button's bottom edge (or clamped to the viewport margin)")
		_expect(absf(badge_rect.get_center().y - target_rect.end.y) < 0.5, target.name + " badge centre sits on the button's bottom edge")
		for neighbour: Control in (target.get_parent() as Control).get_children():
			if neighbour is Control and neighbour != target and (neighbour as Control).is_visible_in_tree() and neighbour is BaseButton:
				_expect(not badge_rect.intersects((neighbour as Control).get_global_rect()), target.name + " badge clears neighbouring button " + str(neighbour.name))
		rects[str(target.name)] = badge_rect
		for property: String in ["_loadout_badge", "_grimoire_badge"]:
			var notification: Control = _scene.get(property)
			if notification != null and notification.is_visible_in_tree() and badge.get_global_rect().intersects(notification.get_global_rect()):
				var conflict: String = str(target.name) + " / " + property
				if not _header_collisions.has(conflict): _header_collisions.append(conflict)
	record["header_badge_rects"] = rects
	record["header_notification_overlaps"] = _header_collisions.duplicate()

func _assert_badge_geometry(record: Dictionary) -> void:
	var geometry: Array[Dictionary]
	var hand_badges: Dictionary = {}
	var manager: Node = _scene.get("_controller_glyph_badges")
	var safe: Rect2 = _scene.get_viewport_rect().grow(-4.0)
	for badge: Control in manager._badges.values():
		if not badge.is_visible_in_tree(): continue
		var rect: Rect2 = badge.visual_rect()
		var label: String = str(record["context"]) + " " + str(badge.action_name)
		_expect(_scene.get_viewport_rect().encloses(rect), label + " stays fully in the viewport")
		if badge.mode.begins_with("corner"):
			_expect(safe.grow(0.01).encloses(rect), label + " clears the 4-pixel viewport margin")
		var z: int = _effective_z(badge)
		var target_z: int = _effective_z(badge.target)
		_expect(badge.get_canvas() == badge.target.get_canvas() and z > target_z, label + " draws above its target in the same canvas")
		var ancestor: Node = badge.get_parent()
		while ancestor is CanvasItem:
			if ancestor is Control and ancestor.clip_contents:
				var clip_rect: Rect2 = ancestor.get_global_transform() * Rect2(Vector2.ZERO, ancestor.size)
				_expect(clip_rect.grow(0.01).encloses(rect), label + " is not clipped by " + str(ancestor.name))
			ancestor = ancestor.get_parent()
		geometry.append({"action": str(badge.action_name), "rect": rect, "z": z, "target_z": target_z})
		if badge.action_name in [&"controller_hand_toggle", &"controller_hand_previous"]:
			hand_badges[badge.action_name] = badge
	record["badge_geometry"] = geometry
	if not hand_badges.has(&"controller_hand_toggle") or _scene.hand_box.get_child_count() == 0: return
	var card: Control = _scene.call("_hand_card_control", 0)
	var medallion: Control = card.get_node("TimeCostBadge")
	var medallion_rect: Rect2 = medallion.get_global_transform() * Rect2(Vector2.ZERO, medallion.size)
	var strip: Control = _scene.get("_turn_order_landing_strip")
	var strip_rect: Rect2 = strip.get_global_rect() if strip.is_visible_in_tree() else Rect2()
	var x: Control = hand_badges[&"controller_hand_toggle"]
	var x_rect: Rect2 = x.visual_rect()
	var expected_x := Vector2(medallion_rect.position.x - 6.0 - x_rect.size.x, medallion_rect.get_center().y - x_rect.size.y * 0.5)
	expected_x = expected_x.clamp(safe.position, safe.end - x_rect.size)
	_expect(x_rect.position.distance_to(expected_x) < 0.01, str(record["context"]) + " X sits 6 pixels left, centred on the medallion, with viewport clamping")
	var hand_z: int = _highest_z(_scene.hand_box)
	for badge: Control in hand_badges.values():
		var rect: Rect2 = badge.visual_rect()
		_expect(_effective_z(badge) > hand_z, str(badge.action_name) + " draws above the entire hand, including its cost medallions")
		_expect(not rect.intersects(medallion_rect), str(badge.action_name) + " clears the medallion")
		_expect(not strip_rect.has_area() or not rect.intersects(strip_rect), str(badge.action_name) + " clears the turn-order preview strip")
	if hand_badges.has(&"controller_hand_previous"):
		var l1_rect: Rect2 = hand_badges[&"controller_hand_previous"].visual_rect()
		_expect(not x_rect.intersects(l1_rect), "X never overlaps L1")
		var below: bool = is_equal_approx(l1_rect.position.y, x_rect.end.y + 6.0) and is_equal_approx(l1_rect.end.x, x_rect.end.x)
		# A collapsed hand at the screen's bottom leaves no room below X.
		var beside: bool = is_equal_approx(l1_rect.end.x, x_rect.position.x - 6.0) and absf(l1_rect.get_center().y - x_rect.get_center().y) < 0.5
		_expect(below or beside, "L1 sits 6 UI pixels below X (right edges shared), or 6 UI pixels left of X when there is no room below")
	record["hand_clearance"] = {"medallion": medallion_rect, "strip": strip_rect, "highest_hand_z": hand_z}

func _effective_z(item: CanvasItem) -> int:
	var result: int = 0
	while item != null:
		result += item.z_index
		if not item.z_as_relative or item.top_level: break
		item = item.get_parent() as CanvasItem
	return result

func _highest_z(item: CanvasItem) -> int:
	var result: int = _effective_z(item)
	for child: Node in item.get_children():
		if child is CanvasItem: result = maxi(result, _highest_z(child))
	return result

func _show_tutorial_catalog(phase: String) -> void:
	# Component catalog, separate from the authentic walkthrough in
	# contextual_combat_tutorial_probe.gd. A fixture spotlight keeps each authored
	# callout visible without synthesizing its gameplay prerequisites.
	_scene.set_process(false)
	_scene.set("_guided_tutorial_phase_id", phase)
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var host: Control = _scene.get("_contextual_combat_prompt_host")
	var anchor: Control = _scene.find_child("PassPreviewChip", true, false)
	host.show()
	prompt.configure(Tutorial.phase_definition(phase), [anchor.get_global_rect()], [], bool(_scene.call("_reduced_motion_enabled")))
	_scene.call("_refresh_controller_prompts")

func _write_contact_sheet() -> void:
	# Proof-only thumbnails; all individual PNGs retain their native resolution.
	const THUMB_WIDTH: int = 480
	const COLUMNS: int = 4
	var thumb_height: int = roundi(float(THUMB_WIDTH) * _proof_size.y / _proof_size.x)
	var sheet: Image = Image.create(THUMB_WIDTH * COLUMNS, thumb_height * ceili(float(_records.size()) / COLUMNS), false, Image.FORMAT_RGB8)
	for index: int in range(_records.size()):
		var thumb: Image = Image.load_from_file(_output_dir.path_join(str(_records[index]["capture"])))
		thumb.convert(Image.FORMAT_RGB8)
		thumb.resize(THUMB_WIDTH, thumb_height, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, thumb.get_size()), Vector2i(index % COLUMNS * THUMB_WIDTH, index / COLUMNS * thumb_height))
	sheet.save_png(_output_dir.path_join("contact_sheet.png"))
