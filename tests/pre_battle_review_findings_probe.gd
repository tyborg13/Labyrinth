extends "res://tests/pre_battle_view_test.gd"

const UiSuite = preload("res://tests/suites/pre_battle_ui_suite.gd")
const OUTPUT: String = "user://probes/pre_battle_review_findings"

func _initialize() -> void:
	_setup()
	await _run_input_proof()
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var instance: Node = await _instance(state)
	await _identity_stage(instance, ["acolyte", "warden", "zekarion"], [
		["Heal", "heal"], ["Guard", "guard_ally"], ["Area", "lightning_strikes"]
	], "registry_identities")
	await _identity_stage(instance, ["tharokh", "vyraketh", "craghide"], [], "terrain_cinders")
	var wrapped_roster: Array = ["zekarion", "warden", "crawler", "zekarion", "vyraketh", "tharokh"]
	for count: int in range(1, 7):
		await _identity_stage(instance, wrapped_roster.slice(0, count), [], "wrapped_names_%d_foes" % count)
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PRE-BATTLE REVIEW FINDINGS PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _identity_stage(instance: Node, enemy_types: Array, identities: Array, filename: String) -> void:
	var preview: Dictionary = instance.get("_pre_battle_preview_run_state").duplicate(true)
	var enemies: Array = []
	for enemy_type: String in enemy_types:
		var hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
		enemies.append({"type": enemy_type, "hp": hp, "max_hp": hp, "id": enemies.size() + 1})
	preview["combat_state"]["enemies"] = enemies
	instance.set("_pre_battle_preview_run_state", preview)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	var panel := instance.get("_pre_battle_panel") as Control
	_assert_pre_battle_body_inside_panel(panel, filename)
	_assert_foe_fit(panel, enemy_types.size())
	var flow := panel.find_child("PreBattleEnemyFlow", true, false) as Control
	for index: int in range(identities.size()):
		var identity: Array = identities[index] as Array
		var tags := flow.get_child(index).find_child("PreBattleMoveTags", true, false) as Control
		UiSuite._assert_tag_identity(tags, str(identity[0]), str(identity[1]), _expect, str(enemy_types[index]))
		for tag: Control in tags.get_children():
			if str(tag.get_meta("tag_word", "")) == str(identity[0]) and not tag.is_visible_in_tree():
				var hidden_count: int = int(tags.get("base_overflow"))
				for candidate: Control in tags.get_children():
					if candidate.has_meta("tag_word") and not candidate.is_visible_in_tree():
						hidden_count += 1
				var overflow := tags.get_node("Overflow") as Label
				_expect(overflow.is_visible_in_tree() and overflow.text == "+%d" % hidden_count, "%s hidden tag must be represented by the exact overflow count" % enemy_types[index])
	await _capture("%s/%s.png" % [OUTPUT, filename])
