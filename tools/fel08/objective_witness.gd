extends RefCounted

const DoorWitness = preload("res://tools/fel08/door_witness.gd")
const Store = preload("res://scripts/progression_store.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const ObjectiveHud = preload("res://scripts/combat_objective_hud.gd")

const DESCRIPTION := "Reach a marked tile to escape."
const LEGACY_DESCRIPTION := "Reach a marked door to escape."
const SINGLE_DETAIL := "Reach the marked tile"
const DOUBLE_DETAIL := "Reach any of 2 marked tiles"
const WILDFIRE_SENTENCE := "On each Wildfire beat, after your turn, each Fire tile spreads 1 tile away from the entry."
const SNARE_REWARD := "Normal combat reward, plus 6 Embers per open door."
const OTHER_OBJECTIVES := [
	["defeat_all", {"type": Objectives.KILL_ALL}, "DEFEAT ALL ENEMIES"],
	["defeat_leader", {"type": Objectives.KILL_LEADER}, "DEFEAT THE LEADER"],
	["survive", {"type": Objectives.SURVIVE}, "SURVIVE"],
	["last_light", {"type": Objectives.SURVIVE, "special_type": "last_light"}, "SURVIVE UNTIL DAWN"],
	["hoarder", {"type": Objectives.KILL_LEADER, "special_type": "ember_hoarder"}, "DEFEAT THE HOARDER"],
	["warband", {"type": Objectives.KILL_LEADER, "special_type": "warband", "special_variant": "ice", "leader_display_name": "The Rime Oracle"}, "DEFEAT THE RIME ORACLE"]
]


static func run(probe: SceneTree) -> bool:
	if not _other_objectives(probe): return false
	Store.set_run_storage_path("user://fel08_legacy_objective.save")
	Store.set_storage_path("user://fel08_objective_profile.json")
	var path: String = probe.FIXTURES.path_join(probe.DOOR).path_join(probe.Checkpoint.RUN_FILE)
	var single: Dictionary = Store._load_run_dictionary(path)
	if single.is_empty() or DoorWitness._ordinary_fixture(single).is_empty():
		return _fail(probe, "missing the one-exit fixture")
	if not await _combat_case(probe, single, 1, SINGLE_DETAIL, "objective-one-exit.png"): return false

	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Snare.FIXTURE_SEED, Store.default_data())
	var fresh: Dictionary = Snare.pre_battle(engine, combat, source)
	if not await _fresh_case(probe, fresh): return false

	var legacy: Dictionary = Snare.build(engine, combat, source, {"snare_case": "first_seal"})
	legacy["current_room_layout"]["objective"]["description"] = LEGACY_DESCRIPTION
	legacy["combat_state"]["objective"]["description"] = LEGACY_DESCRIPTION
	legacy["combat_state"]["umbra"]["vision_bonus"] = DoorWitness.VISION_BONUS
	legacy = engine.set_combat_state(legacy, legacy["combat_state"])
	if not await _combat_case(probe, legacy, 2, DOUBLE_DETAIL, "objective-two-exits-resumed.png", true): return false
	print("FEL08 OBJECTIVE WITNESS PASS status_counts=1,2 fresh=true continued=true")
	return true


static func _fresh_case(probe: SceneTree, fresh: Dictionary) -> bool:
	var stored: String = fresh["current_room_layout"]["objective"]["description"]
	var scene: Node = await DoorWitness._mount(probe, fresh)
	if scene == null: return false
	var panel: Control = scene.get("_pre_battle_panel")
	var heading: Label = panel.find_child("PreBattleObjectiveTitle", true, false) as Label if panel != null else null
	if heading == null or not heading.is_visible_in_tree():
		return _fail(probe, "fresh room has no visible pre-battle objective")
	var displayed: String = heading.tooltip_text.get_slice("\n", 1)
	if stored != DESCRIPTION or displayed != DESCRIPTION:
		return _fail(probe, "fresh room stored=%s displayed=%s" % [stored, displayed])
	if not heading.tooltip_text.ends_with("\n" + WILDFIRE_SENTENCE + "\n" + SNARE_REWARD):
		return _fail(probe, "pre-battle tooltip lost the Wildfire or Snare reward line")
	print("FEL08 OBJECTIVE fresh pre-battle description: " + displayed)
	heading.grab_focus()
	await probe._settle()
	var tooltip: Control = heading.get_node_or_null("PreBattleObjectiveFocusTooltip") as Control
	if tooltip == null or not tooltip.is_visible_in_tree():
		return _fail(probe, "fresh pre-battle description panel did not open")
	if not await _capture(probe, "objective-pre-battle.png"): return false
	heading.release_focus()
	await probe.process_frame
	await DoorWitness._unmount(probe)
	return true


static func _combat_case(probe: SceneTree, run_state: Dictionary, count: int, expected: String, filename: String, resume_saved: bool = false) -> bool:
	var scene: Node = await DoorWitness._mount(probe, run_state, resume_saved)
	if scene == null: return false
	var objective: Dictionary = (scene.get("_combat_state") as Dictionary).get("objective", {})
	var hud: Control = scene.get("_combat_objective_hud")
	var detail: Label = hud.find_child("ObjectiveLiveDetail", true, false) as Label
	if Objectives.exit_target_tiles(objective).size() != count or detail == null or not detail.is_visible_in_tree() or detail.text != expected:
		return _fail(probe, "expected %d exits with status %s" % [count, expected])
	print("FEL08 OBJECTIVE exits=%d status: %s" % [count, detail.text])
	if not _check_passive_hud(probe, hud, "exit"): return false
	if (scene.call("_controller_header_focus_controls") as Array).has(hud):
		return _fail(probe, "combat Objective is a controller focus stop")
	if resume_saved:
		if objective.get("description") != LEGACY_DESCRIPTION:
			return _fail(probe, "Continue did not load the legacy stored description")
		var battlefield: Control = scene.get("_battlefield_rule_hud")
		var sentence := battlefield.find_child("RuleSentence", true, false) as Label
		if sentence == null or not sentence.is_visible_in_tree() or sentence.text != WILDFIRE_SENTENCE:
			return _fail(probe, "Wildfire sentence missing from the Battlefield panel")
		print("FEL08 OBJECTIVE continued description stored: " + LEGACY_DESCRIPTION)
	var rect: Rect2 = hud.get_global_rect()
	var left_margin: float = hud.get_theme_stylebox("panel").get_margin(SIDE_LEFT)
	await probe._point(Vector2(rect.position.x + left_margin * 0.5, rect.get_center().y))
	await probe._settle(true)
	if probe._viewport.gui_get_hovered_control() != hud:
		return _fail(probe, "pointer could not reach the combat objective from " + str(probe._viewport.gui_get_hovered_control()))
	for popup: Window in probe._viewport.get_embedded_subwindows():
		if popup.visible and popup.theme_type_variation == &"TooltipPanel":
			return _fail(probe, "combat Objective hover opened a tooltip")
	print("FEL08 OBJECTIVE NO POPUP exits=%d hover=true focus=none" % count)
	if not await _capture(probe, filename): return false
	await probe._point(probe.NO_POINTER)
	await DoorWitness._unmount(probe)
	return true


static func _other_objectives(probe: SceneTree) -> bool:
	var hud := ObjectiveHud.new()
	for example: Array in OTHER_OBJECTIVES:
		hud.set_combat_state({"objective": example[1]})
		if (hud.find_child("ObjectiveTitle", true, false) as Label).text != example[2]:
			hud.free()
			return _fail(probe, "objective title mismatch for " + str(example[0]))
		if not _check_passive_hud(probe, hud, example[0]):
			hud.free()
			return false
	hud.free()
	return true


static func _check_passive_hud(probe: SceneTree, hud: Control, label: String) -> bool:
	if not hud.tooltip_text.is_empty() or hud.focus_mode != Control.FOCUS_NONE:
		return _fail(probe, label + " can expose a tooltip or receive focus")
	return true


static func _capture(probe: SceneTree, filename: String) -> bool:
	if probe._dry: return true
	await RenderingServer.frame_post_draw
	var path: String = probe._destination.path_join(filename)
	var image: Image = probe._viewport.get_texture().get_image()
	if image == null or image.get_size() != probe.Checkpoint.VIEWPORT_SIZE or image.save_png(path) != OK:
		return _fail(probe, "cannot save " + path)
	print(path)
	return true


static func _fail(probe: SceneTree, message: String) -> bool:
	probe._fail("FEL08 OBJECTIVE " + message)
	return false
