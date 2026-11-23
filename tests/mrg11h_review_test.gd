extends SceneTree

const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Echoes = preload("res://scripts/illusion_relic_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Empower = preload("res://scripts/card_empower_controller.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const HERO := Vector2i(1, 4)
const FIRST := Vector2i(2, 4)
const MIRROR := Vector2i(3, 4)
const LAST := Vector2i(4, 4)
const EXPOSE: int = 2
const BLOCK: int = 10

var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var engine := Combat.new()
	var scene: Control = RunScene.new()
	_reflect_amount(engine)
	_echo_retort(engine)
	_empower_panel(scene)
	_chain_route(engine)
	_flashsteam(engine, scene)
	_panels()
	scene.free()
	if OS.get_cmdline_user_args().has("--affected"):
		_run_affected()
	for failure: String in _failures:
		push_error(failure)
	print("MRG-11H REVIEW: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _run_affected() -> void:
	var suites: Dictionary = {
		"Reflect EN05": preload("res://tests/suites/en05_enemies_suite.gd"),
		"Illusion terrain": preload("res://tests/suites/illusion_terrain_suite.gd"),
		"Illusion relics U6": preload("res://tests/suites/relic_u6_suite.gd"),
		"Card keywords": preload("res://tests/suites/card_keywords_suite.gd"),
		"Forced movement relics U3": preload("res://tests/suites/relic_u3_suite.gd"),
		"Tempo relics U4": preload("res://tests/suites/relic_u4_suite.gd"),
	}
	for name: String in suites:
		var checks: int = _checks
		var failures: int = _failures.size()
		suites[name].run(_expect)
		print("MRG-11H %s: %d checks, %d failures" % [name, _checks - checks, _failures.size() - failures])

func _reflect_amount(engine: RefCounted) -> void:
	var state: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, MIRROR), Fixtures.enemy("glacial_mirror", 2, Vector2i(5, 4), "refraction")], HERO)
	Surface.place(state, MIRROR, "ice", {})
	state["enemies"][0]["expose"] = EXPOSE
	var action: Dictionary = state["enemies"][1]["intent"]["actions"][0]
	var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 1, action)
	var threat: Dictionary = engine.enemy_threat_tiles(state, 1)
	var rows: Array = ReflectView.intent_rows(state["enemies"][1]["intent"], int(threat.get("reflect_return_damage", 0)))
	_expect(rows[-1][0].get("icon") == "reflect" and int(rows[-1][0].get("value", 0)) == 6, "1 enemy Refraction intent shows its exact returned damage")
	_expect(Reflect.bounces_between(state, after).any(func(event: Dictionary) -> bool: return event["damage"] == 6) and after["enemies"][0]["expose"] == EXPOSE, "1 enemy Refraction counts Mirror Expose without spending it")
	_expect(after["enemies"][1]["hp"] == state["enemies"][1]["hp"] - 6, "1 enemy caster takes 6 before defense")

	state = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, MIRROR)], HERO)
	Surface.place(state, MIRROR, "ice", {})
	Surface.place(state, MIRROR, "rubble", {})
	state["enemies"][0]["expose"] = EXPOSE
	state["relics"] = ["venom_signet"]
	state["player"]["block"] = BLOCK
	state["player"]["expose"] = EXPOSE
	action = engine.card_play_actions("frostbolt", state)[0]
	after = engine.apply_player_action(state, action, MIRROR)
	var preview: Dictionary = engine.surface_preview_for_player_action(state, action, MIRROR)["state"]
	_expect(after["player"]["block"] == BLOCK - 7 and preview["player"]["block"] == BLOCK - 7 and after["enemies"][0]["expose"] == EXPOSE and after["player"]["expose"] == EXPOSE, "1 Frostbolt returns 7 with Quarry Signet and Mirror Expose in live play and preview")

	# Compare the exact outcome of each repeated hit with an otherwise identical
	# adjacent target. Both keyword variants and live defense state use real actions.
	for setup: Dictionary in [
		{"id": "hurl_spear", "empowered": true, "follow_up": false},
		{"id": "rimefang", "empowered": false, "follow_up": true},
	]:
		_compare_keyword_hit(engine, setup)

func _compare_keyword_hit(engine: RefCounted, setup: Dictionary) -> void:
	var id: String = setup["id"]
	var state: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, MIRROR)], HERO)
	state["player"]["hp"] = BLOCK * 3
	state["player"]["max_hp"] = BLOCK * 3
	state["turn_flags"] = {"cards_finished": 1}
	state["enemies"][0]["hp"] = BLOCK * 3
	state["enemies"][0]["max_hp"] = BLOCK * 3
	state["enemies"][0]["expose"] = EXPOSE
	var card: Dictionary = engine.card_def(id, state)
	var action: Dictionary = Keywords.actions_with_modifiers(card, setup)[0]
	var bounced: Dictionary = state
	for hit: int in range(2):
		var adjacent: Dictionary = bounced.duplicate(true)
		adjacent["player"]["pos"] = FIRST
		var landed: Dictionary = engine.apply_player_action(adjacent, action, MIRROR)
		var after: Dictionary = engine.apply_player_action(bounced, action, MIRROR)
		var amount: int = int(adjacent["enemies"][0]["hp"]) - int(landed["enemies"][0]["hp"])
		var events: Array[Dictionary] = Reflect.bounces_between(bounced, after)
		_expect(amount > 0 and events.size() == 1 and int(events[0]["damage"]) == amount and int(bounced["player"]["hp"]) - int(after["player"]["hp"]) == amount, "1 %s keyword-resolved hit %d returns the adjacent hit's full damage" % [id, hit + 1])
		bounced = after

func _echo_retort(engine: RefCounted) -> void:
	var state: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, LAST)], MIRROR)
	state["relics"] = ["mirror_triptych"]
	state = engine._create_illusion(state, HERO, 8, {"reflect": true})
	var action: Dictionary = engine.card_play_actions("frostbolt", state)[0]
	var after: Dictionary = engine.apply_player_action(state, action, LAST)
	Echoes.note_attack(engine, after, action)
	var echoed: Dictionary = Echoes.finish_echoes(engine, after.duplicate(true))
	_expect(echoed["enemies"][0]["hp"] == state["enemies"][0]["hp"] - 6 and echoed["illusions"][0]["hp"] == 5, "2 a bounced Frostbolt echo triggers Reflected Threat and then pays echo wear")

func _empower_panel(scene: Control) -> void:
	scene._combat_state = {"player": {"block": 1}, "relics": ["anchor_chain"]}
	var card: Dictionary = Data.card_def_for_progression("wind_shear", scene._combat_state)
	var rule: String = Empower._tooltip_for_card(scene, -1, card)
	_expect(rule.contains("Push each target 3 tiles instead."), "3 Wind Shear Empower seal shows the live Push 3")
	var preview: Dictionary = Display.for_card("wind_shear", scene._combat_state, card)
	var panels: Array[Dictionary] = Icons.tooltip_entries_for_rows(preview["summary_rows"])
	_expect(panels.any(func(panel: Dictionary) -> bool: return panel["title"] == "Empower" and panel["description"].contains("Push each target 3 tiles instead.")), "3 Wind Shear hand panel uses the same live Push number")
	var primed: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, MIRROR)], HERO)
	Tempo.gain_next_attack(primed, {"element": "lightning", "chain": 1, "immediate": true}, "Test")
	var chain: Dictionary = Data.card_def_for_progression("chain_bolt", primed)
	_expect(str(Display.empower_panel(chain, primed)["card_tooltip"]).contains("Chain 5."), "3 Chain Bolt Empower includes the live next-attack Chain once")

func _chain_route(engine: RefCounted) -> void:
	var state: Dictionary = Fixtures.state([Fixtures.enemy("crawler", 1, FIRST), Fixtures.enemy("glacial_mirror", 2, MIRROR), Fixtures.enemy("crawler", 3, LAST)], HERO)
	state["relics"] = ["storm_crown"]
	var action: Dictionary = engine.card_play_actions("chain_bolt", state)[0]
	var preview: Dictionary = engine.surface_preview_for_player_action(state, action, FIRST)
	var resolved: Dictionary = engine.resolve_player_action_for_presentation(state, action, FIRST)
	for trace: Dictionary in [preview, resolved]:
		var hits: Array = trace["chain_hits"]
		_expect(hits.any(func(hit: Dictionary) -> bool: return hit["from"] == FIRST and hit["to"] == MIRROR) and hits.any(func(hit: Dictionary) -> bool: return hit["kind"] == "rebound" and hit["from"] == LAST and hit["to"] == MIRROR), "5 Chain and Rebound routes both pass through the Mirror in preview and resolution")

func _flashsteam(engine: RefCounted, scene: Control) -> void:
	var state: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, MIRROR)], HERO)
	state["player"]["block"] = BLOCK
	Surface.place(state, FIRST, "ice", {})
	var actions: Array = engine.card_play_actions("flashsteam", state)
	var after: Dictionary = engine.apply_player_action(state, actions[0], FIRST)
	after = engine.apply_player_action(after, actions[1], FIRST)
	var preview: Dictionary = {"friendly_damage_chips": scene._friendly_damage_preview_chips(state, scene._damage_preview_between_states(state, after))}
	ReflectView.decorate_preview(scene, preview, state, after, actions[0], FIRST)
	var chips: Array = preview["friendly_damage_chips"]
	_expect(chips.size() == 2 and chips[0]["label"] == "↶ You: −3 Block" and chips[0]["tooltip"] == "Reflect\nYou take 3 damage.\nYou lose 3 Block." and chips[1]["label"] == "You: −4 Block" and chips[1]["tooltip"] == "Burst\nYou lose 4 Block.", "6 Flashsteam distinguishes the 3 reflected Block from the 4 Block lost to Burst")
	state["player"]["block"] = 4
	after = engine.apply_player_action(state, actions[0], FIRST)
	after = engine.apply_player_action(after, actions[1], FIRST)
	preview = {"friendly_damage_chips": scene._friendly_damage_preview_chips(state, scene._damage_preview_between_states(state, after))}
	ReflectView.decorate_preview(scene, preview, state, after, actions[0], FIRST)
	chips = preview["friendly_damage_chips"]
	_expect(chips.size() == 3 and chips.any(func(chip: Dictionary) -> bool: return chip["label"] == "You: −3 Health" and chip["tooltip"] == "Burst\nYou lose 3 Health.\nYou lose 1 Block."), "6 A Burst that breaks Block forecasts the remaining Health loss under Burst")

func _panels() -> void:
	var caltrops: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def("caltrops")))
	_expect(caltrops.all(func(panel: Dictionary) -> bool: return not str(panel["description"]).contains("Deal X damage")), "8 Caltrops has no damage panel")
	var refraction: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def("refraction")))
	_expect(refraction.any(func(panel: Dictionary) -> bool: return str(panel["description"]).contains("each other enemy adjacent")) and refraction.all(func(panel: Dictionary) -> bool: return not str(panel["description"]).contains("Health")), "8 Refraction explains the extra hit and shows no Illusion Health")
	if OS.get_cmdline_user_args().has("--sweep"):
		var amount := RegEx.create_from_string("\\bX\\b")
		var owners: Dictionary = {}
		for id: String in Data.cards():
			for panel: Dictionary in Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def(id))):
				var body: String = panel["description"]
				if amount.search(body) == null: continue
				var key: String = "%s | %s" % [panel["title"], body]
				if not owners.has(key): owners[key] = []
				owners[key].append(id)
		for key: String in owners:
			print("PANEL SWEEP ", key, " | ", owners[key])

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
