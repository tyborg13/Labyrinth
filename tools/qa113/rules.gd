extends "res://tools/ui33/layout_sweep.gd"
## Sweep the existing catalog and keep the exact displayed copy and panel height.

func _extra_fixtures() -> void:
	if baseline and selected_case in ["reach_exit/undo", "reach_exit/held_undo"]:
		await _baseline_undo(selected_case)
		return
	if not native or not selected_case.is_empty():
		await super._extra_fixtures()
		if selected_case.is_empty(): await _prebattle_leader()
		return
	var builder := Fixtures.new()
	await _visit_rule(builder, "reach_exit/undo")
	for id: String in Rules.data()["instances"]:
		await _visit_rule(builder, id)
		if Rules.data()["instances"][id].has("at_half_health"):
			await _visit_rule(builder, id + "/half_health")
	for tier: int in [1, 2, 3]:
		await _visit_rule(builder, "ember_hoarder/%d" % tier)
	builder.free()
	await _prebattle_leader()

func _prebattle_leader() -> void:
	var run: Dictionary = preload("res://tools/qa110/encounters.gd").pre_battle("tharokh")
	if run.is_empty():
		errors.append("Tharokh pre-battle fixture unavailable")
		return
	await _enter_scene("res://scenes/run_scene.tscn")
	scene.set("_progression", run["progression"])
	scene._load_run_state(run)
	scene._close_dialogue()
	await settle()
	await create_timer(SETTLE_SECONDS).timeout
	var panel: Control = scene.get("_pre_battle_panel")
	var heading: Label = panel.find_child("PreBattleLeaderLabel", true, false) if is_instance_valid(panel) else null
	if heading == null or not heading.is_visible_in_tree() or heading.text != "LEADER":
		errors.append("Tharokh pre-battle requires a visible LEADER heading")
		return
	print("QA113 LEADER: profile=%s heading=%s" % [profile, heading.text])
	if native:
		var surfaces: Array[Node]
		await snapshot("tharokh-leader", "", {}, surfaces)

func _visit_rule(builder: Fixtures, key: String) -> void:
	var count: int = states
	await super._visit_rule(builder, key)
	if states == count: return
	var objective: Control = scene.get("_combat_objective_hud")
	var headings: Dictionary = {}
	for name_key: String in ["ObjectiveTitle", "ObjectiveIntroTitle"]:
		var label: Label = objective.find_child(name_key, true, false)
		if label == null or label.text.is_empty() or label.text != label.text.to_upper():
			errors.append(key + ": missing or mixed-case " + name_key)
		if label != null: headings[name_key] = label.text
	var hud: Control = scene.get("_battlefield_rule_hud")
	var row: Dictionary = {"case": key, "headings": headings, "panel_height": hud.size.y,
		"sentence": hud.find_child("RuleSentence", true, false).text}
	print("QA113 RULE ", JSON.stringify(row))
	record("qa113_rule", row)
	if key in ["reach_exit/undo", "reach_exit/held_undo"]: _measure_physical_undo(key)

func _baseline_undo(key: String) -> void:
	var builder := Fixtures.new()
	var run: Dictionary = builder.make("reach_exit", run_seed)
	builder.free()
	if run.is_empty():
		errors.append("Baseline Reach the Exit fixture unavailable")
		return
	await _enter_scene("res://scenes/run_scene.tscn")
	scene.set("_progression", run["progression"])
	scene._load_run_state(run)
	scene._close_dialogue()
	await settle()
	await create_timer(SETTLE_SECONDS).timeout
	if key.ends_with("/held_undo"): _hold_hand_layout()
	if not await _make_reversible_walk():
		errors.append("Baseline could not trigger Undo with a reversible walk")
		return
	states += 1
	_measure_physical_undo(key)

func _measure_physical_undo(key: String) -> void:
	var undo: Control = scene.get("_movement_undo_button")
	var rect: Rect2 = Check.bounds(undo, root)
	var scale_y: float = root.get_stretch_transform().y.length()
	var logical_margin: float = root.get_visible_rect().end.y - rect.end.y
	var pixel_margin: float = logical_margin * scale_y
	var row: Dictionary = {"case": key, "profile": profile, "visible": undo.is_visible_in_tree(), "baseline": baseline,
		"logical_margin": logical_margin, "pixel_margin": pixel_margin, "scale_y": scale_y}
	print("QA113 UNDO ", JSON.stringify(row))
	record("qa113_undo", row)
	if not baseline and (not undo.is_visible_in_tree() or pixel_margin + RECT_TOLERANCE < REQUIRED_BOTTOM_MARGIN):
		errors.append("%s: Undo margin %.3f backing pixels, expected at least %.0f" % [key, pixel_margin, REQUIRED_BOTTOM_MARGIN])

