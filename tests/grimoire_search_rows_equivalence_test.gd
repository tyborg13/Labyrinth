extends "res://tests/retained_character_inventory_equivalence_test.gd"

const SearchReference = preload("res://tests/fixtures/grimoire_search_rows_reference.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const SearchRows = preload("res://scripts/grimoire_search_rows.gd")
var row_preparation_owner: Node
var row_preparation_frames: int = 0
var row_preparation_active: bool = true
var cancel_row_preparation_at: int = -1
var free_row_preparation_at: int = -1

func _run() -> void:
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(SearchReference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(84217, Tutorial.complete_tutorial(Profile.default_data()))
	var ids: Array[String]
	for entry: Dictionary in Library.entries(): ids.append(str(entry.get("id", "")))
	state[Library.UNLOCKED_KEY] = ids.duplicate()
	state[Library.UNREAD_KEY] = []
	state["progression"][Library.UNLOCKED_KEY] = ids.duplicate()
	state["progression"][Library.UNREAD_KEY] = []
	for scene: Node in scenes: scene._run_state = state.duplicate(true)
	var before: Dictionary = scenes[0]._run_state.duplicate(true)
	var selected: String = scenes[0]._grimoire_selected_entry
	row_preparation_owner = scenes[0]
	await SearchRows.prepare_current_for(scenes[0], scenes[0]._grimoire_row_preparation_revision, _present_rows, _rows_active)
	_check(scenes[0]._run_state == before and scenes[0]._grimoire_selected_entry == selected, "Hidden row preparation must not mutate run or selection")
	_check(scenes[0]._grimoire_search_retained_rows.size() == ids.size(), "Preparation must own exactly the current discovered entry rows")
	for scene: Node in scenes: scene._open_grimoire_overlay()
	for query: String in ["r", "re", "res", "resh", "res", "reshuffle", "damage", "fire", "heath c", "initiative", "purple banana", ""]:
		await _compare_search(query, "query " + query)
	for query: String in ["reshuffle", "initiative", "damage"]:
		for length: int in range(1, query.length() + 1):
			await _compare_search(query.left(length), "typed query %s/%d" % [query, length])
	await _compare_search("damage", "initial repeated query")
	var retained: Dictionary = scenes[0]._grimoire_search_retained_rows.duplicate()
	for scene: Node in scenes:
		if scene._grimoire_search_result_buttons.size() > 1: scene._grimoire_search_result_buttons[1].grab_focus()
	await _compare_search("damage", "focused repeated query")
	var reused: int = 0
	for id: String in retained:
		if scenes[0]._grimoire_search_retained_rows[id]["node"] == retained[id]["node"]: reused += 1
	_check(reused > 0, "Repeated search must retain unchanged result controls")
	for scene: Node in scenes:
		scene._run_state[Library.UNREAD_KEY] = ["combat:fatigue"]
	await _compare_search("reshuffle", "new unread marker")
	for scene: Node in scenes:
		scene._on_grimoire_entry_pressed("combat:fatigue")
	await _compare_search("reshuffle", "selection and unread cleared")
	# Emulate the native accessibility sequence: toggle state first, then emit
	# pressed, with no pointer press attempt to force a fresh-row fallback.
	for scene: Node in scenes:
		var selected_button: Button = scene._grimoire_search_result_buttons[0]
		selected_button.set_pressed_no_signal(false)
		selected_button.pressed.emit()
	await _compare_search("reshuffle", "accessibility reactivation of selected result")
	_check(scenes[0]._grimoire_search_result_buttons[0].button_pressed, "Accessibility reactivation must restore selected result state")
	root.size = Vector2i(1600, 900)
	await _compare_search("damage", "changed viewport")
	root.size = Vector2i(1920, 1080)
	await _compare_search("damage", "restored viewport")
	await _compare_search("", "return to browsing")
	_check(_hidden_rows_have_no_focus(scenes[0]), "Browsing must hide prepared result rows and exclude them from keyboard focus")
	await _compare_search("damage", "search after browsing")
	for scene: Node in scenes:
		scene._reset_grimoire_search()
	await _compare_search("fire", "search after reset")
	await _exercise_row_preparation_cancellation(state, ids)
	for scene: Node in scenes: scene.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Result retention teardown must leave no orphan nodes")
	print("GRIMOIRE ROW RETENTION RESULT: ", JSON.stringify({"cases": cases, "differences": differences, "errors": errors, "reused_rows": reused, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _compare_search(query: String, label: String) -> void:
	for scene: Node in scenes: scene._on_grimoire_search_text_changed(query)
	await _settle(8)
	for field: String in ["_grimoire_section_list", "_grimoire_detail_content"]:
		var a: Control = scenes[0].get(field)
		var b: Control = scenes[1].get(field)
		var actual: Dictionary = _filter_hidden_rows(a, _snapshot(a, a))
		var expected: Dictionary = _filter_hidden_rows(b, _snapshot(b, b))
		if actual != expected: _print_differences(actual, expected, label + field)
		_check(actual == expected, "Retained result geometry, styles, text and callbacks must match original: " + label + field)
	_check(scenes[0]._grimoire_search_results == scenes[1]._grimoire_search_results, "Search results and ranking must match original: " + label)
	_check(scenes[0]._grimoire_search_retained_rows.size() <= scenes[0]._grimoire_known_row_ids().size(), "Result cache must be bounded by the current discovered entry set: " + label)
	_check(scenes[0]._grimoire_entry_scroll.scroll_vertical == scenes[1]._grimoire_entry_scroll.scroll_vertical, "Search must preserve original scroll behavior: " + label)
	cases += 1

func _filter_hidden_rows(node: Node, snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate()
	var children: Array[Dictionary]
	var nodes: Array[Node] = node.get_children()
	var snapshots: Array = snapshot.get("children", [])
	for index: int in nodes.size():
		var child: Node = nodes[index]
		# Future controls are explicitly hidden, nonfocusable, scene-owned rows;
		# they are the implementation under test, not additional visible content.
		if child.has_meta("grimoire_prepared_search_row") and not (child as Control).visible: continue
		children.append(_filter_hidden_rows(child, snapshots[index]))
	result["children"] = children
	return result

func _hidden_rows_have_no_focus(scene: Node) -> bool:
	for entry: Dictionary in scene._grimoire_search_retained_rows.values():
		var row: Variant = entry.get("node")
		if not is_instance_valid(row) or row.get_parent() != scene._grimoire_section_list: return false
		if not row.visible:
			var button: Button = row.get_child(0) as Button
			if button.has_focus() or button.focus_mode != Control.FOCUS_NONE or row.process_mode != Node.PROCESS_MODE_DISABLED: return false
	return true

func _exercise_row_preparation_cancellation(state: Dictionary, ids: Array[String]) -> void:
	row_preparation_owner = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(row_preparation_owner)
	await _settle(8)
	row_preparation_owner._run_state = state.duplicate(true)
	row_preparation_frames = 0
	cancel_row_preparation_at = 2
	await SearchRows.prepare_current_for(row_preparation_owner, row_preparation_owner._grimoire_row_preparation_revision, _present_rows, _rows_active)
	_check(not row_preparation_active and row_preparation_owner._grimoire_search_retained_rows.size() > 0 and row_preparation_owner._grimoire_search_retained_rows.size() < ids.size(), "Cancellation must interrupt a partially published preparation")
	_check(_hidden_rows_have_no_focus(row_preparation_owner), "Cancelled published rows must stay scene owned and nonfocusable")
	cancel_row_preparation_at = -1
	row_preparation_active = true
	await SearchRows.prepare_current_for(row_preparation_owner, row_preparation_owner._grimoire_row_preparation_revision, _present_rows, _rows_active)
	_check(row_preparation_owner._grimoire_search_retained_rows.size() == ids.size(), "Restart must complete the exact bounded row set")
	var subset: Array[String]
	subset.append(ids[0])
	row_preparation_owner._prune_grimoire_search_rows(subset)
	_check(row_preparation_owner._grimoire_search_retained_rows.size() == 1, "Source shrink must discard rows no longer owned")
	row_preparation_frames = 0
	free_row_preparation_at = 2
	await SearchRows.prepare_current_for(row_preparation_owner, row_preparation_owner._grimoire_row_preparation_revision, _present_rows, _rows_active)
	_check(not is_instance_valid(row_preparation_owner), "Freeing the owner must safely cancel preparation at a frame boundary")
	free_row_preparation_at = -1
	row_preparation_owner = null
	cases += 3

func _present_rows() -> void:
	await _settle(1)
	row_preparation_frames += 1
	if row_preparation_frames == cancel_row_preparation_at: row_preparation_active = false
	if row_preparation_frames == free_row_preparation_at and is_instance_valid(row_preparation_owner): row_preparation_owner.free()

func _rows_active() -> bool:
	return row_preparation_active
