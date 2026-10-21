extends SceneTree
const Suite = preload("res://tests/suites/warband_suite.gd")
const Identity = preload("res://scripts/enemy_identity.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Hud = preload("res://scripts/combat_objective_hud.gd")
const View = preload("res://scripts/pre_battle_view.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const WarbandView = preload("res://scripts/warband_view.gd")
const TEST_FOE_CARD_SIZE := Vector2(300, 400)
var failures: Array[String]

class SoundBank extends Node:
	var requests: Array[String]
	func play(cue: String, _options: Dictionary = {}) -> void: requests.append(cue)

class ReducedScene extends Node:
	var banner: String
	var rendered: bool = false
	func _set_action_banner(value: String) -> void: banner = value
	func _reduced_motion_enabled() -> bool: return true
	func _render_board_state(_state: Dictionary, _presentation: Dictionary) -> void: rendered = true

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	preload("res://tests/helpers/spx07_path_draw_cases.gd").run(_expect)
	preload("res://tests/helpers/spx07_catalog_cache_cases.gd").run(_expect)
	var probe: Script = load("res://tests/warband_probe.gd")
	_expect(probe != null and probe.can_instantiate(), "Native Warband probe parses headless")
	var host := preload("res://scripts/run_scene.gd").new()
	var board := Board.new()
	var hud := Hud.new()
	for biome: String in Suite.Library.definition("warband")["variants"]:
		var state: Dictionary = Suite.battle(biome)
		state.erase("umbra")
		var captain: Dictionary = state["enemies"][0]
		var title: String = Identity.display_name(captain)
		board.combat_state = state
		board.presentation = {}
		var units: Array[Dictionary] = board._build_visible_units()
		_expect(units.any(func(unit: Dictionary) -> bool: return unit.get("name", "") == title), "Board names/tooltips resolve captain title: " + biome)
		_expect(board._support_enemy_unit(captain)["name"] == title, "Support tooltip resolves captain title: " + biome)
		_expect(hud._live_detail(state, state["objective"]).begins_with(title + " · "), "Objective HP detail resolves title: " + biome)
		var foe: Control = View.build_foe(host, captain, TEST_FOE_CARD_SIZE, true)
		_expect((foe.find_child("PreBattleEnemyName", true, false) as Label).text == title, "Pre-battle foe card resolves title: " + biome)
		foe.free()
		host.set("_pre_battle_preview_run_state", {"combat_state": state})
		var inspection: Control = Inspection.build(host, captain)
		_expect(_labels(inspection).has(title), "Pre-battle inspection resolves title: " + biome)
		inspection.free()
		var heading: Control = View.build_objective(state)
		_expect(str(heading.find_child("PreBattleObjectiveChip", true, false).get_meta("objective_title")) == "Defeat " + Identity.running_name(title), "Pre-battle heading resolves title: " + biome)
		heading.free()
	var commanded: Dictionary = Suite.arena()
	commanded["enemies"][1]["intent"] = {"id": "command_ui", "time": 4, "actions": [{"type": "melee", "damage": 3}]}
	var chips: Dictionary = preload("res://scripts/intent_badges.gd").build(Suite.Combat.new(), commanded, commanded)
	_expect((chips["badges"] as Array).any(func(badge: Dictionary) -> bool: return badge["key"] == "enemy_2" and badge["number"] == "4"), "At-rest intent medallion shows Command +1")
	var compass: Dictionary = preload("res://scripts/enemy_intent_compass.gd").descriptors_for_state(commanded)
	_expect(int(compass["enemy_2"]["value"]) == 4, "Details intent compass shows Command +1")
	commanded["enemies"][0]["pos"] = Vector2i(1, 2)
	chips = preload("res://scripts/intent_badges.gd").build(Suite.Combat.new(), commanded, commanded)
	_expect((chips["badges"] as Array).any(func(badge: Dictionary) -> bool: return badge["key"] == "enemy_2" and badge["number"] == "3"), "At-rest medallion follows moving Command zone")
	_command_movement_displays()
	var before: Dictionary = Suite.arena()
	var after: Dictionary = Suite.Combat.new()._damage_enemy(before.duplicate(true), 0, Suite.TEST_PLAYER_HP, false, true)
	var concealed: Dictionary = after.duplicate(true)
	concealed["enemies"][1]["burrowed"] = true
	concealed["enemies"][1]["veiled"] = true
	var fleeing: Dictionary = WarbandView.flee_display_state(before, concealed)
	_expect(not fleeing["enemies"][1]["burrowed"] and not fleeing["enemies"][1]["veiled"] and concealed["enemies"][1]["burrowed"] and concealed["enemies"][1]["veiled"], "Concealed followers expose their fleeing bodies without changing committed mechanics")
	var reduced := ReducedScene.new()
	await WarbandView.animate_break(reduced, before, after, {})
	_expect(reduced.banner == after["objective"]["break_line"] and not reduced.rendered, "Reduced motion skips the entire escape run and retains the announcement")
	host.set("_settings", {"reduced_motion": true})
	for unit: Dictionary in host.call("_defeated_enemy_units_between_states", before, after):
		if not bool(unit.get("warband_fled", false)): continue
		var original: Dictionary = before["enemies"][int(unit["id"]) - 1]
		_expect(unit["pos"] == original["pos"], "Reduced motion dissolves followers at their original tile")
	# Two identical maquette types share one simultaneous escape frame; the
	# single-actor movement adapter must not replace another actor's maps.
	var walkers: Array[Dictionary]
	for id: int in [1, 2]:
		walkers.append({"id": id, "type": "lightning_wisp", "pos": Vector2i(id + 1, 2), "warband_flee_path": [Vector2i(id + 1, 2), Vector2i(id + 1, 1)]})
	var frame: Dictionary = WarbandView.break_frame(board, walkers, 0.5)
	_expect((frame["unit_world_positions"] as Dictionary).size() == 2 and (frame["unit_texture_origins"] as Dictionary).size() == 2 and (frame["lightning_wisp_motion"] as Dictionary).size() == 2, "Every follower keeps its own simultaneous movement/rig/root sample")
	var bank := SoundBank.new()
	var router := preload("res://scripts/sfx_cue_router.gd").new(bank)
	var audio_before: Dictionary = before.duplicate(true)
	audio_before["enemies"][0]["hp"] = 0
	router.baseline(audio_before)
	var fled_units: Array[Dictionary]
	for unit: Dictionary in host.call("_defeated_enemy_units_between_states", before, after):
		if bool(unit.get("warband_fled", false)): fled_units.append(unit)
	var silent: Dictionary = WarbandView.sound_snapshot(after, {"death_animation_units": fled_units})
	router.presentation(silent["state"], silent["shown"])
	_expect(bank.requests.is_empty(), "Flee and dissolve emit no follower hit/death/heal sound")
	bank.free()
	reduced.free()
	hud.free()
	board.free()
	host.free()
	await _live_fixture_surfaces()
	for failure: String in failures: push_error(failure)
	print("Warband UI semantics: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _labels(node: Node) -> Array[String]:
	var result: Array[String]
	if node is Label: result.append((node as Label).text)
	for child: Node in node.get_children(): result.append_array(_labels(child))
	return result

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _command_movement_displays() -> void:
	var engine := Suite.Combat.new()
	for enters: bool in [true, false]:
		var state: Dictionary = Suite.arena()
		state["enemies"].resize(2)
		state["player"]["pos"] = Vector2i(4, 3)
		state["enemies"][0]["pos"] = Vector2i(3, 1) if enters else Vector2i(1, 1)
		var hound: Dictionary = state["enemies"][1]
		hound["type"] = "ash_hound"
		hound["pos"] = Vector2i(1, 3)
		hound["intent"] = {"id": "closing_bite", "time": 4, "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 3, "range": 1}]}
		var expected: int = 4 if enters else 3
		var label: String = "entering" if enters else "leaving"
		var threat: Dictionary = engine.enemy_threat_tiles(state, 1)
		_expect(threat["projected_attack_from"] == Vector2i(3, 3) and int(threat["projected_attack_action"]["damage"]) == expected, "Moving Hound projected attack " + label + " Command")
		var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 1)["state"]
		_expect(Suite.TEST_PLAYER_HP - int(resolved["player"]["hp"]) == expected, "Moving Hound resolution " + label + " Command")
		var shown: Dictionary = preload("res://scripts/intent_badges.gd").build(engine, state, state)
		_expect((shown["badges"] as Array).any(func(badge: Dictionary) -> bool: return badge["key"] == "enemy_2" and badge["number"] == str(expected)), "Moving Hound medallion " + label + " Command equals projected/resolved damage")
		var compass: Dictionary = preload("res://scripts/enemy_intent_compass.gd").descriptors_for_state(state)
		_expect(int(compass["enemy_2"]["value"]) == expected, "Moving Hound Details " + label + " Command equals projected/resolved damage")
		hound["intent"]["actions"].append(hound["intent"]["actions"].back().duplicate(true))
		shown = preload("res://scripts/intent_badges.gd").build(engine, state, state)
		_expect((shown["badges"] as Array).any(func(badge: Dictionary) -> bool: return badge["key"] == "enemy_2" and badge["number"] == "%d×2" % expected), "Projected Command preserves repeated-hit medallions: " + label)
		resolved = engine.resolve_enemy_turn_with_steps(state, 1)["state"]
		_expect(Suite.TEST_PLAYER_HP - int(resolved["player"]["hp"]) == expected * 2, "Both repeated hits use projected Command: " + label)
	print("Warband moving Command displays: entering/leaving aura checked against projection and resolution")

func _live_fixture_surfaces() -> void:
	# Exercise the production combat and pre-battle surfaces from the same
	# serialized fixture shape used by the director, without a renderer capture.
	for biome: String in ["air", "lightning"]:
		var engine := Suite.Run.new()
		var combat := Suite.Combat.new()
		var tier: int = 2 if biome == "air" else 3
		var run: Dictionary = Suite.Fixture.build(engine, combat, engine.create_new_run(Suite.Fixture.FIXTURE_SEED, Suite.Store.default_data()), {"warband_biome": biome, "warband_tier": tier})
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		await process_frame
		scene.call("_load_run_state", run)
		if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
		_expect(scene.get("_combat_state")["objective"]["special_type"] == "warband", "Production scene loads a Warband combat save: " + biome)
		var preview: Dictionary = run.duplicate(true)
		preview["mode"] = "pre_battle"
		preview["pre_battle_pending"] = true
		preview["pre_battle_travel_dir"] = Vector2i.UP
		preview["combat_state"] = {}
		scene.set("_run_state", preview)
		scene.set("_prepared_pre_battle_factory", Suite.Fixture.prepared(engine, combat, preview))
		_expect(bool(scene.call("_show_pre_battle_preview")), "Production Warband pre-battle view opens from its factory: " + biome)
		var panel: Control = scene.get("_pre_battle_panel")
		_expect(_labels(panel).has(run["combat_state"]["enemies"][0]["display_name"]), "Production pre-battle shows the captain title: " + biome)
		scene.queue_free()
		await process_frame
	print("Warband live fixture surfaces: Stormcaller and Dynamo combat/pre-battle loaded headless")
