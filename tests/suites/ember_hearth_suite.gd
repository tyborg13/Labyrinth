extends RefCounted
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Sfx = preload("res://scripts/run_sfx_library.gd")
const Loader = preload("res://scripts/asset_loader.gd")
const Scene = preload("res://tests/fixtures/ember_hearth_run_scene.gd")

static func setup(instance: Node, hp: int = 356, embers: int = 180, reduced: bool = false, section_map: bool = false) -> Dictionary:
	var progression: Dictionary = Store.set_embers(Store.default_data(), embers)
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(721, progression, section_map)
	var coord := Vector2i(0, 2)
	if section_map:
		# Use a real graph node, not room_metadata's legacy fallback outside the graph.
		for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
			if str(node.get("type", "")) == "campfire" and int(node.get("section_index", -1)) == 0:
				coord = node.get("coord", coord)
				break
	var room: Dictionary = engine.room_metadata(state, coord)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	state["rooms"]["%d,%d" % [coord.x, coord.y]] = room
	state["current_room"] = coord
	if section_map:
		(state["map_sections"] as Array)[0]["entered"] = true
		preload("res://scripts/section_map_graph.gd").refresh_knowledge(state)
	state["current_room_layout"] = engine.call("_display_layout_for_room", 721, room, Vector2i(1, 0))
	state["mode"] = "campfire"
	state["player_hp"] = hp
	state["player_max_hp"] = 360
	state["held_embers"] = embers
	state["unbanked_embers"] = embers
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = reduced
	instance.set("_settings", settings)
	instance.set("_progression", progression)
	instance.call("_load_run_state", state)
	return (instance.get("_run_state") as Dictionary).duplicate(true)

static func panel(instance: Node, index: int) -> Control:
	return (instance.get("_relic_choice_bar") as HBoxContainer).get_child(index) as Control

static func activate(instance: Node, index: int, keyboard: bool = false) -> void:
	var target: Control = panel(instance, index)
	var event: InputEvent
	if keyboard:
		var key := InputEventAction.new()
		key.action = "ui_accept"
		key.pressed = true
		event = key
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		event = click
	instance.call("_on_campfire_choice_gui_input", event, str(target.get_meta("choice_id")), target, target.get_meta("choice_accent"))

static func wait_ready(tree: SceneTree) -> void:
	await tree.create_timer(0.65).timeout

static func wait_finished(tree: SceneTree, instance: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + 3000
	while bool(instance.get("_campfire_choice_action_pending")) and Time.get_ticks_msec() < deadline:
		await tree.process_frame

static func run(tree: SceneTree, expect: Callable) -> void:
	var previous_profile_path: String = Store._storage_path
	var previous_run_path: String = Store._run_storage_path
	Store.set_storage_path("user://hearth_suite_profile.json")
	Store.set_run_storage_path("user://hearth_suite_run.save")
	for id: String in [Sfx.HEARTH_ARRIVAL_ID, Sfx.HEARTH_FOCUS_ID, Sfx.HEARTH_SELECT_ID, Sfx.HEARTH_RECOVER_ID, Sfx.HEARTH_STRENGTH_ID, Sfx.HEARTH_DEPART_ID]:
		var entry: Dictionary = Sfx.entry(id)
		var stream: AudioStream = Loader.load_audio_stream(entry.get("path", ""))
		expect.call(stream != null and absf(stream.get_length() - float(entry.get("trimmed_duration", 0.0))) < 0.002, "Hearth cues load and play their complete authored waveform: " + id)
		expect.call(entry.get("bus", "") == Settings.UI_SFX_BUS, "Hearth interaction cues honor UI sound volume: " + id)
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	instance.set_script(Scene)
	tree.root.add_child(instance)
	await tree.process_frame
	setup(instance, 358, 0)
	activate(instance, 0)
	expect.call(not bool(instance.get("_campfire_choice_action_pending")), "Invisible arrival choices cannot be activated")
	await wait_ready(tree)
	var linger: Control = panel(instance, 0)
	var embrace: Control = panel(instance, 1)
	var strength: Control = panel(instance, 2)
	expect.call(str((instance.get("room_title") as Label).text) == "Ember Hearth", "Room uses the chosen Ember Hearth name")
	expect.call(linger.get_node(linger.focus_neighbor_left) == embrace and linger.get_node(linger.focus_next) == embrace, "Focus order skips unaffordable Strength and wraps available choices")
	activate(instance, 2, true)
	expect.call(not bool(instance.get("_campfire_choice_action_pending")), "Unavailable Strength does not spend or start feedback")
	linger.grab_focus()
	instance.call("_set_campfire_choice_hovered", linger, Color("efb35f"), true)
	instance.call("_set_campfire_choice_hovered", linger, Color("efb35f"), false)
	expect.call(bool(linger.get_meta("hearth_emphasized", false)), "Pointer exit preserves keyboard focus emphasis")
	var arrivals: int = (instance.get("heard_cues") as Array).count(Sfx.HEARTH_ARRIVAL_ID)
	instance.call("_refresh_ui")
	await tree.process_frame
	expect.call((instance.get("heard_cues") as Array).count(Sfx.HEARTH_ARRIVAL_ID) == arrivals, "Refreshing the same hearth does not replay arrival audio")
	activate(instance, 0, true)
	activate(instance, 0)
	await tree.create_timer(0.36).timeout
	var committed: Dictionary = Store.load_saved_run()
	expect.call(int(committed.get("player_hp", 0)) == 360 and committed.get("mode", "") == "room", "Linger persists the capped heal before its visible result")
	expect.call(bool(instance.get("_animation_lock")), "Travel remains gated while the result is visible")
	expect.call(not bool(instance.call("_map_shortcut_can_open")), "Route map cannot cover the healing result")
	var presentation: Dictionary = (instance.get("board_view") as Node).get("presentation")
	expect.call((presentation.get("effect", {}) as Dictionary).get("kind", "") == "heal", "Linger reuses the character healing effect")
	await wait_finished(tree, instance)
	expect.call((instance.get("heard_cues") as Array).count(Sfx.HEARTH_SELECT_ID) == 1 and (instance.get("heard_cues") as Array).has(Sfx.HEARTH_RECOVER_ID), "Duplicate activation produces one selection cue and an actual recovery sound")
	expect.call(not bool(instance.get("_animation_lock")) and int((instance.get("_run_state") as Dictionary).get("player_hp", 0)) == 360, "Duplicate activation heals once and releases input after feedback")
	setup(instance, 360, 180, true)
	await wait_ready(tree)
	expect.call(panel(instance, 0).scale == Vector2.ONE, "Reduced motion leaves option geometry stationary")
	activate(instance, 0)
	await tree.create_timer(0.22).timeout
	presentation = (instance.get("board_view") as Node).get("presentation")
	expect.call(not presentation.has("effect"), "Full-health Linger does not pretend to restore HP")
	await wait_finished(tree, instance)
	setup(instance, 350, 180, true)
	await wait_ready(tree)
	activate(instance, 2, true)
	await tree.create_timer(0.22).timeout
	committed = Store.load_saved_run()
	expect.call(int((committed.get("progression", {}) as Dictionary).get("level", 0)) == 2 and int(committed.get("held_embers", -1)) == 0, "Strength commits one purchased level before its result")
	await wait_finished(tree, instance)
	expect.call((instance.get("heard_cues") as Array).has(Sfx.HEARTH_STRENGTH_ID), "Purchased Strength plays its result cue")
	expect.call((instance.get("_upgrade_scrim") as Control).visible, "Strength ends in the existing skill tree")
	var skill_tree: Node = instance.get("_skill_tree_view")
	var learn: Button = skill_tree.get("_detail_action") as Button
	expect.call(learn != null and not learn.disabled, "The earned point is immediately spendable after Strength finishes")
	if learn != null and not learn.disabled: learn.pressed.emit()
	expect.call((Store.load_data().get("skill_ids", []) as Array).has("quick_wits"), "The skill tree can persist the point earned from Strength")
	instance.call("_close_card_upgrade_overlay")
	expect.call((instance.get("_run_state") as Dictionary).get("mode", "") == "room", "Closing Skills preserves the consumed hearth choice")
	# Invalidate a pending selection and prove it cannot heal a newly loaded run.
	setup(instance, 350, 180)
	await wait_ready(tree)
	activate(instance, 0)
	setup(instance, 100, 0)
	await tree.create_timer(0.40).timeout
	expect.call(int((instance.get("_run_state") as Dictionary).get("player_hp", 0)) == 100 and not bool(instance.get("_animation_lock")), "Loading a run cancels stale selection without mutating the new state")
	setup(instance, 350, 180, true)
	await wait_ready(tree)
	activate(instance, 1)
	await tree.create_timer(0.22).timeout
	expect.call(bool(instance.get("_campfire_embrace_committed")) and not Store.has_saved_run(), "Embrace banks and clears the run before departure")
	instance.call("_save_run_progress")
	expect.call(not Store.has_saved_run() and int(Store.load_data().get("embers", 0)) == 180, "OS close during Embrace cannot resurrect the banked run")
	await tree.create_timer(0.9).timeout
	expect.call((instance.get("heard_cues") as Array).has(Sfx.HEARTH_DEPART_ID), "Banked Embrace plays its departure cue")
	expect.call(instance.get("requested_scene") == "res://scenes/main_menu.tscn", "Embrace returns to the menu after the departure cue")
	instance.queue_free()
	await tree.process_frame
	Store.set_storage_path(previous_profile_path)
	Store.set_run_storage_path(previous_run_path)
