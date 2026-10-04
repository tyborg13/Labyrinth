extends "res://tests/pre_battle_view_test.gd"

const Cases = preload("res://tests/pre_battle_true_scale_cases.gd")
const OUTPUT: String = "user://probes/pre_battle_true_scale"

func _initialize() -> void:
	_setup()
	await _run_input_proof()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var instance: Node = await _instance(state)
	for case: Array in Cases.ROSTERS:
		var preview: Dictionary = instance.get("_pre_battle_preview_run_state").duplicate(true)
		var enemies: Array = []
		for enemy_type: String in case[1]:
			var hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
			enemies.append({"type": enemy_type, "hp": hp, "max_hp": hp, "id": enemies.size() + 1, "is_leader": enemy_type in ["zekarion", "noctyrax"]})
		preview["combat_state"]["enemies"] = enemies
		instance.set("_pre_battle_preview_run_state", preview)
		instance.call("_rebuild_pre_battle_overlay")
		await _settle()
		var panel := instance.get("_pre_battle_panel") as Control
		_assert_pre_battle_body_inside_panel(panel, str(case[0]))
		_assert_foe_fit(panel, enemies.size())
		var flow := panel.find_child("PreBattleEnemyFlow", true, false) as Control
		FoeSuite.assert_true_scale(flow, _expect, str(case[0]))
		await _capture("%s/%s.png" % [OUTPUT, str(case[0])])
	instance.queue_free()
	await process_frame
	router.call("clear_forced_state_for_test")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PRE-BATTLE TRUE SCALE PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
