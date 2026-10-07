extends SceneTree
const MapPanel = preload("res://scripts/section_map_panel.gd")
const Reference = preload("res://tests/fixtures/section_map_panel_reference.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var cases: int = 0
var actual: Control
var original: Control
func _initialize() -> void:
	Parallel.apply_from_environment()
	Settings.set_storage_path("user://retained_map_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["fullscreen"] = false
	Settings.save_settings(settings)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()
func _run() -> void:
	actual = MapPanel.new()
	original = Reference.new()
	for panel: Control in [actual, original]:
		panel.size = Vector2(1864, 1024)
		root.add_child(panel)
	await _settle()
	var engine := RunEngineScript.new()
	for seed: int in [81, 90429, 84217]:
		var state: Dictionary = engine.create_new_run(seed, Progression.default_data())
		await _compare(state)
		var first_ids: Dictionary = _identities()
		for mode: String in ["pre_battle", "combat", "room"]:
			state["mode"] = mode
			await _compare(state)
			_check(first_ids == _identities(), "Mode changes must retain exactly the same displayed controls")
		var choices: Array[Vector2i] = actual.available_destinations()
		var focused: Control = actual.node_buttons[choices[0]]
		focused.grab_focus()
		actual.center_on_current()
		_check(root.gui_get_focus_owner() == focused and actual.selected_coord == choices[0], "Refresh must preserve native room focus and its preview")
		actual.reset_interaction()
		# A pointer preview has no focused room to trigger focus_entered again.
		root.gui_release_focus()
		var hover_coord: Vector2i = choices[0]
		actual.node_buttons[hover_coord].mouse_entered.emit()
		await _settle()
		var preview: Control = actual._preview
		var old_position: Vector2 = preview.position
		actual.size += Vector2(500, 150)
		await _settle()
		_check(actual._preview == preview and actual.selected_coord == hover_coord, "Resize must retain the existing pointer preview")
		_check(preview.position != old_position, "Pointer preview must follow its retained node on resize")
		var expected_position: Vector2 = preview.position
		actual._position_preview(hover_coord)
		_check(preview.position == expected_position, "Deferred resize preview must use the current node geometry")
		actual.size = original.size
		actual.reset_interaction()
		await _settle()
		for step: int in range(3):
			var current: Dictionary = Graph.room(state, state["current_room"])
			state["current_room"] = current["connections"][0]["coord"]
			Graph.room(state, state["current_room"])["visited"] = true
			Graph.refresh_knowledge(state)
			await _compare(state)
		# Reveals, recovery badges, and removals update the same retained view.
		for room: Dictionary in state["rooms"].values():
			if int(room.get("section_index", -1)) != 0: continue
			room["map_outline"] = true
		await _compare(state)
		for room: Dictionary in state["rooms"].values():
			if int(room.get("section_index", -1)) != 0 or room["coord"] == state["current_room"]: continue
			room["revealed"] = false
			room["map_outline"] = false
			room["recovery_marker"] = true
			room["recovery_amount"] = 7
			await _compare(state)
			room["recovery_marker"] = false
			await _compare(state)
			break
		for panel: Control in [actual, original]:
			panel.scout_targeting = true
			panel._refresh_actions()
		_check(_snapshot(actual) == _snapshot(original), "Scout targets, focus routes, and action states must match")
		for panel: Control in [actual, original]: panel.reset_interaction()
		# Jump to a later real generated section, then inspect reached history.
		state["current_room"] = Graph.section(state, 2)["entry"]
		Graph.room(state, state["current_room"])["visited"] = true
		Graph.refresh_knowledge(state)
		await _compare(state)
		for section: int in [0, 1, 2]:
			for panel: Control in [actual, original]: panel.select_section(section)
			await _settle()
			_check(_snapshot(actual) == _snapshot(original), "Section history must match original geometry and state")
			_check(actual._nodes.get_child_count() == actual.node_buttons.size(), "Only the current section's displayed nodes may remain parented")
			cases += 1
	actual.free()
	original.free()
	await _settle()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Retained map teardown must leave no orphan nodes")
	print("RETAINED SECTION MAP EQUIVALENCE RESULT: " + JSON.stringify({"errors": errors, "cases": cases}))
	quit(0 if errors.is_empty() else 1)
func _compare(state: Dictionary) -> void:
	for panel: Control in [actual, original]: panel.set_run_state(state.duplicate(true))
	await _settle()
	_check(_snapshot(actual) == _snapshot(original), "Retained map must match original for case %d" % cases)
	_check(actual._tabs.get_child_count() == 6, "Retained tabs must remain bounded at six")
	for button: Control in actual.node_buttons.values():
		_check(button.get_signal_connection_list("pressed").size() == 1, "Room activation must have exactly one signal handler")
		_check(button.get_signal_connection_list("mouse_entered").size() == 2, "Hover must have exactly the redraw and inspection handlers")
	cases += 1
func _snapshot(panel: Control) -> Dictionary:
	var nodes: Dictionary = {}
	for coord: Vector2i in panel.node_buttons:
		var button: Control = panel.node_buttons[coord]
		var neighbors: Array[String]
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var path: NodePath = button.get_focus_neighbor(side)
			var target: Node = button.get_node_or_null(path) if not path.is_empty() else null
			neighbors.append(str(target.name) if target != null else "")
		nodes[coord] = [button.position, button.size, button.room_data, button.route_state, button.reduced_motion, button.actionable, button.scout_target, button.visual_radius(), button.pulse_scale(), button.mouse_default_cursor_shape, neighbors]
	var tabs: Array
	for tab: Button in panel._tabs.get_children():
		tabs.append([tab.text, tab.size, tab.position, tab.disabled, tab.button_pressed, tab.tooltip_text])
	return {"nodes": nodes, "tabs": tabs, "title": panel._title.text, "progress": panel._progress.text, "scout": [panel._scout.text, panel._scout.disabled, panel._scout.tooltip_text], "continue": panel._continue.visible, "event": panel._event_panel.visible, "background": panel._background.texture.get_instance_id(), "state": panel._canvas.state, "positions": panel._canvas.positions, "radii": panel._canvas.radii, "selected": panel._canvas.selected, "fog": panel._fog.material.get_shader_parameter("openings")}
func _identities() -> Dictionary:
	var result: Dictionary = {}
	for coord: Vector2i in actual.node_buttons: result[coord] = actual.node_buttons[coord].get_instance_id()
	for tab: Node in actual._tabs.get_children(): result[str(tab.name)] = tab.get_instance_id()
	return result
func _settle() -> void:
	for frame: int in range(6): await process_frame
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
