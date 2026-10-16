extends "res://tests/pre_battle_fixture.gd"

const Rules = preload("res://scripts/combat_objective_rules.gd")
const MIXED_ROSTER: Array[String] = ["crawler", "burrow_grub", "crawler", "noctyrax", "gust_shrike", "hoarfrost_seer"]
const PERFORMANCE_ROSTER: Array[String] = ["crawler", "acolyte", "harrier", "warden", "ash_hound", "gust_shrike"]

func _living_fixture() -> Node:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	return await _instance(state)

func _set_roster(instance: Node, roster: Array[String], objective: Dictionary, use_static: bool = false) -> Control:
	var preview: Dictionary = (instance.get("_pre_battle_preview_run_state") as Dictionary).duplicate(true)
	var enemies: Array[Dictionary]
	for identity: String in roster:
		var hp: int = int(GameData.enemy_def(identity).get("max_hp", 1))
		enemies.append({"type": identity, "hp": hp, "max_hp": hp, "id": enemies.size() + 1})
	preview["combat_state"]["enemies"] = enemies
	preview["combat_state"]["objective"] = objective.duplicate(true)
	instance.set("_pre_battle_preview_run_state", preview)
	# Benchmark/proof cases deliberately rebuild, including identical ABBA cases.
	# Production's unchanged-section retention is exercised by its own suite.
	instance.set("_live_pre_battle_view_key", {})
	instance.call("_rebuild_pre_battle_overlay")
	var panel := instance.get("_pre_battle_panel") as Control
	if use_static:
		# Matched before workload: remove only the new live presentations and show
		# their original stills. Same scene, layout, foes, pool, badges and kit.
		for live: Node in panel.find_children("PreBattleEnemyLiveActor", "Control", true, false):
			(live.get_parent().get_node("PreBattleEnemyArt") as Control).show()
			live.free()
	await _settle()
	_assert_pre_battle_body_inside_panel(panel, "pb-01")
	_assert_foe_fit(panel, roster.size())
	var title := panel.find_child("PreBattleObjectiveTitle", true, false) as Label
	_expect(title != null and title.text == "OBJECTIVE · " + Rules.title_for_objective(objective), "Heading must be exact")
	_expect(panel.find_child("PreBattleObjectiveDescription", true, false) == null, "Every objective is heading-only at 1920x1080 / UI100")
	var tooltip_text: String = (Rules.title_for_objective(objective) + "\n" + Rules.description_for_objective(objective)).strip_edges()
	_expect(title.tooltip_text == tooltip_text and title.get_line_count() == 1 and title.mouse_filter == Control.MOUSE_FILTER_STOP, "Heading exposes exact rule tooltip without wrapping or ignoring hover")
	return panel

func _living_snapshots(panel: Control) -> Array[Dictionary]:
	var snapshots: Array[Dictionary]
	for live: Node in panel.find_children("PreBattleEnemyLiveActor", "Control", true, false):
		snapshots.append(live.call("snapshot"))
	return snapshots
