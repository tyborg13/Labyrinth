extends "res://tests/retained_character_inventory_equivalence_test.gd"

func _run() -> void:
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(Reference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	var engine := Run.new()
	var profile: Dictionary = Tutorial.complete_tutorial(Profile.default_data())
	var state: Dictionary = engine.create_new_run(84217, profile)
	state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier"]
	state["magic_inventory"] = ["frostbolt", "spark_dart", "frostbolt"]
	for scene: Node in scenes:
		scene._initial_ui_complete = false
		scene._load_run_state(state.duplicate(true))
		scene._close_dialogue()
		scene._pre_battle_scrim.hide()
		scene._large_map_scrim.hide()
	for mode: String in ["equipment", "magic", "skills"]:
		for level: int in [1, 6, 14, Data.max_progression_level()]:
			profile["level"] = level
			profile = Profile.normalized_data(profile)
			Profile.save_data(profile)
			state = engine.apply_progression_update(state, profile)
			for notice: String in ["", "Skill point gained. Spend it now or save it for later.", "The level could not be saved. No embers were spent; try again. This longer notice checks wrapping and the final Skills geometry."]:
				var previous_frame: Node = scenes[0]._upgrade_dialog.find_child("CharacterBodyFrame", true, false)
				var previous_mode: String = str(scenes[0]._live_character_view_key.get("mode", ""))
				var before: Dictionary = state.duplicate(true)
				for scene: Node in scenes:
					scene._run_state = state.duplicate(true)
					scene._progression_overlay_mode = mode
					scene._progression_overlay_notice = notice
					scene._progression_overlay_notice_is_error = notice.begins_with("The level")
					# Hidden pack preparation invalidates its cache marker while
					# leaving the complete live Skills body in its final parent.
					if mode == "skills": scene._live_character_view_key.clear()
					scene._rebuild_progression_overlay()
					scene._upgrade_scrim.show()
				await _settle(8)
				var actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
				var expected: Dictionary = _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog)
				var label: String = "%s / level %d / %s" % [mode, level, notice]
				if actual != expected: _print_differences(actual, expected, label)
				_check(actual == expected, "Header and Skills body must match original complete geometry, rules, art and callbacks: " + label)
				_check(state == before and scenes[0]._run_state == scenes[1]._run_state, "Header refresh must preserve committed state: " + label)
				if previous_mode == mode: _check(scenes[0]._upgrade_dialog.find_child("CharacterBodyFrame", true, false) == previous_frame, "A complete same-mode Character body must retain its final parent: " + label)
				cases += 1
	# Multiple commits can rebuild this surface before the queued deletions
	# flush. Clear/re-add notices and change unread badges without an await.
	for mode: String in ["equipment", "magic", "skills"]:
		for scene: Node in scenes:
			scene._progression_overlay_mode = mode
			scene._progression_overlay_notice = "Before"
			scene._rebuild_progression_overlay()
		await _settle(8)
		for phase: int in range(4):
			for scene: Node in scenes:
				scene._run_state[Run.UNREAD_LOADOUT_EQUIPMENT_KEY] = ["iron_cleaver"] if phase % 2 == 0 else []
				scene._run_state[Run.UNREAD_LOADOUT_MAGIC_KEY] = ["frostbolt"] if phase % 2 == 0 else []
				scene._progression_overlay_notice = "" if phase % 2 == 0 else "Latest notice"
				scene._progression_overlay_notice_is_error = phase == 3
				scene._rebuild_progression_overlay()
			for scene: Node in scenes:
				var tabs: Control = scene._upgrade_dialog.find_child("CharacterTabs", true, false) as Control
				_check(tabs != null and not tabs.is_queued_for_deletion(), "Each synchronous header update must expose its current named tabs")
				_check(tabs.find_children("*LoadoutTabBadge", "", true, false).size() == (2 if phase % 2 == 0 else 0), "Actual unread badges must update before the next rendered frame")
				if mode == "skills": _check(scene._skill_tree_view._external_tab_target == tabs.find_child("CharacterSkillsTab", true, false), "Skills navigation must bind the current live tab")
		await _settle(8)
		var actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
		var expected: Dictionary = _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog)
		if actual != expected: _print_differences(actual, expected, mode + " repeated synchronous header updates")
		_check(actual == expected, "Consecutive same-frame notices and unread tabs must equal the original: " + mode)
		_check(scenes[0]._upgrade_dialog.find_children("CharacterTabs", "", true, false).size() == 1, "Repeated tab updates must preserve one stable named row")
		var notice: Label = scenes[0]._upgrade_dialog.find_child("ProgressionOverlayNotice", true, false) as Label
		_check(notice != null and notice.text == "Latest notice" and not notice.is_queued_for_deletion(), "The final same-frame notice must remain alive")
		cases += 1
	# The production skill-learn cleanup hides/queues its old notice before
	# another synchronous rebuild. A replacement must own a fresh live label.
	for scene: Node in scenes:
		var previous_notice: Node = scene._upgrade_dialog.find_child("ProgressionOverlayNotice", true, false)
		scene._queue_free_node_now(previous_notice)
		scene._progression_overlay_notice = "Replacement after learned skill"
		scene._rebuild_progression_overlay()
		var replacement: Label = scene._upgrade_dialog.find_child("ProgressionOverlayNotice", true, false) as Label
		_check(replacement != null and replacement != previous_notice and not replacement.is_queued_for_deletion(), "Queued skill-learn notice must never be revived")
	await _settle(8)
	var queued_actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
	var queued_original: Dictionary = _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog)
	if queued_actual != queued_original: _print_differences(queued_actual, queued_original, "queued skill-learn replacement")
	_check(queued_actual == queued_original, "Skill-learn notice replacement must match the original whole builder")
	cases += 1
	# A catalog-complete parked dialog must survive a changed actual header.
	# Compare the full original output and assert that this ready owner is used.
	for mode: String in ["equipment", "magic"]:
		for scene: Node in scenes: scene._close_card_upgrade_overlay()
		_capture_preparation_inputs()
		await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
		_check(scenes[0]._character_inventory_rows._views.has(mode), "Hidden preparation must finish the requested header fixture")
		var prepared: Control = scenes[0]._character_inventory_rows._views[mode]["node"]
		state[Run.UNREAD_LOADOUT_MAGIC_KEY] = ["frostbolt"] if mode == "equipment" else []
		await _compare(state, mode, "prepared header reconciliation " + mode)
		_check(scenes[0]._upgrade_dialog == prepared, "A changed current header must reconcile on the actual ready dialog in " + mode)
	for scene: Node in scenes: scene.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Header retention must dispose all owned controls")
	print("CHARACTER HEADER RESULT: ", JSON.stringify({"cases": cases, "differences": differences, "errors": errors, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)
