extends "res://tools/fel08/before_after/session.gd"
## Use the same held viewport hover and renderer on both sides.

const Objectives = preload("res://scripts/combat_objective_rules.gd")


func _capture_case(case: Dictionary) -> Dictionary:
	var sample: Dictionary = await super._capture_case(case)
	if sample.is_empty(): return sample
	var name: String = case["name"]
	var hud := _viewport.gui_get_hovered_control()
	if hud == null or hud.name != &"CombatObjectiveHud":
		return _fail_case(name, "viewport pointer did not rest on the Objective panel")
	var scene: Node = _viewport.get_node("RunScene")
	var objective: Dictionary = scene.get("_combat_state").get("objective", {})
	if scene.get("_run_state")["mode"] != "combat" or hud.get("intro_active"):
		return _fail_case(name, "the Objective panel did not settle in combat")
	if objective.get("type") != case["objective_type"] or str(objective.get("special_type", "")) != case["special_type"]:
		return _fail_case(name, "unexpected objective in the mounted encounter")
	if case.has("exit_count") and Objectives.exit_target_tiles(objective).size() != int(case["exit_count"]):
		return _fail_case(name, "wrong number of live exit targets")
	if hud.mouse_filter != Control.MOUSE_FILTER_STOP or hud.focus_mode != Control.FOCUS_NONE:
		return _fail_case(name, "the Objective panel must stop clicks and skip focus")
	var title: Label = hud.find_child("ObjectiveTitle", true, false) as Label
	var detail: Label = hud.find_child("ObjectiveLiveDetail", true, false) as Label
	var icon: TextureRect = hud.find_child("ObjectiveIcon", true, false) as TextureRect
	if title == null or detail == null or not detail.is_visible_in_tree() or icon == null or icon.texture == null:
		return _fail_case(name, "permanent Objective content is missing")
	sample["title"] = title.text
	sample["detail"] = detail.text
	return sample
