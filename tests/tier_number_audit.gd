extends SceneTree
## Presentation witness values are compared with committed resolver results,
## with defense removed where a nominal hit is being checked against HP loss.
const Combat = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Inspector = preload("res://scripts/pre_battle_inspection_view.gd")
const Foes = preload("res://scripts/pre_battle_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Chips = preload("res://scripts/intent_badges.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const LastLight = preload("res://tests/suites/last_light_suite.gd")
const Guardians = preload("res://tests/suites/guardian_suite.gd")
const Hoarder = preload("res://tests/suites/hoarder_suite.gd")
const GoalHud = preload("res://scripts/combat_objective_hud.gd")
const Warband = preload("res://tests/suites/warband_suite.gd")
const BurstView = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Beats = preload("res://scripts/battlefield_rules/dispatcher.gd")
const RulesRows = preload("res://scripts/battlefield_rules/intent_rows.gd")
const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")
const Settings = preload("res://scripts/settings_store.gd")
const HERO := Vector2i(4, 3)
const ATTACKER := Vector2i(3, 3)
const STARTING_HP: int = 100
const LOCAL_DEPTH: int = 2
const GUARDIAN_ROOM_DEPTH: int = 10
const CAPTAIN_POSITIONS = [Vector2i(3, 1), Vector2i(1, 1)]
const HOUND_START := Vector2i(1, 3)
const HOUND_MOVE_RANGE: int = 2
const LEGACY_NEGATIVE_TRAP_DAMAGE: int = -1
const GRID_SIZE: int = 9
const TRAP_DAMAGE: int = 7
const HOARDER_SEED: int = 83

var engine := Combat.new()
var scene := RunScene.new()
var board := Board.new()
var counts: Dictionary = {}
var failures: Array[String]
var setup_failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.apply_settings(Settings.default_settings(), null, false)
	var last_light: Dictionary = LastLight.combat_for(LastLight.layout_for("shadow", LOCAL_DEPTH))
	var guardian: Dictionary = Guardians.new().guardian_fixture("storm_cantor", GUARDIAN_ROOM_DEPTH)
	var warband: Dictionary = Warband.battle("air", LOCAL_DEPTH)
	_health("Last Light", last_light, 100)
	_health("Guardian", guardian, 125)
	_health("Warband", warband, 110)
	_health("Hoarder", Hoarder.battle_for("fire", LOCAL_DEPTH, HOARDER_SEED), 115)

	var shade: Dictionary = _arena(last_light, "wick_shade", "grasp")
	_hit("Last Light Grasp", shade, 6, "melee", true)
	_forecast(shade, "Pass")
	var hovered: Dictionary = shade.duplicate(true)
	var before: Vector2i = HERO + Vector2i.RIGHT
	hovered["player"]["pos"] = before
	# Use the same source builder as the Pass panel for a hovered walk.
	scene.set("_combat_state", hovered)
	scene.set("_player_movement_selected", true)
	scene.set("_player_movement_target_tiles", engine._vector2i_values([HERO]))
	scene.set("_player_movement_action", {"type": "move", "range": 1})
	var hover_source: Dictionary = scene._build_pass_preview_source_state_for_tile(HERO, false)
	_require(hover_source.get("player", {}).get("pos") == HERO, "Hovered movement source reaches the intended tile")
	if hover_source.get("player", {}).get("pos") == HERO: _forecast(hover_source, "Hovered destination")
	scene.set("_player_movement_selected", false)

	var air: Dictionary = LastLight.combat_for(LastLight.layout_for("air", LOCAL_DEPTH))
	_hit("Last Light Dive", _arena(air, "gust_shrike", "dive"), 8, "melee", false)
	var fire: Dictionary = LastLight.combat_for(LastLight.layout_for("fire", LOCAL_DEPTH))
	_death_burst(_arena(fire, "ember_tick", "scuttle"))
	_trap(shade)
	_rule_beat(guardian)
	_summon(shade, guardian)
	_command()
	_icefall()
	_lob(fire)

	var total: int = 0
	for surface: String in counts:
		print("CHK01 SURFACE: %s = %d" % [surface, counts[surface]])
		total += int(counts[surface])
	for failure: String in failures + setup_failures: push_error(failure)
	print("CHK01 AUDIT: %d displayed numbers checked, %d mismatches, %d setup failures" % [total, failures.size(), setup_failures.size()])
	board.free()
	scene.free()
	quit(0 if failures.is_empty() and setup_failures.is_empty() else 1)

func _health(room_name: String, state: Dictionary, percent: int) -> void:
	_require(int(state["difficulty_stats"]["hp_percent"]) == percent, room_name + " frozen Health percent")
	board.combat_state = state
	scene.set("_pre_battle_preview_run_state", {"combat_state": state})
	var units: Array[Dictionary] = board._build_visible_units()
	var objective: Dictionary = state["objective"]
	var objective_hud := GoalHud.new()
	for enemy: Dictionary in state["enemies"]:
		var hp: int = int(enemy["hp"])
		var maximum: int = int(enemy["max_hp"])
		var key: String = engine._enemy_key(enemy)
		var hud: Dictionary = {}
		for unit: Dictionary in units:
			if str(unit.get("key", "")) == key: hud = unit
		_compare("Board Health", room_name + " " + key + " current", board._health_bar_fill_hp(hud, {}), hp)
		_compare("Board Health", room_name + " " + key + " maximum", hud.get("max_hp"), maximum)
		var card: Control = Foes.build_foe(scene, enemy, Vector2.ZERO)
		var health: Control = card.find_child("PreBattleEnemyHealth", true, false)
		_compare("Pre-battle roster Health", room_name + " " + key, health.get_child(0).get_child(1).text, str(hp) if hp == maximum else "%d/%d" % [hp, maximum])
		card.free()
		var dossier: Control = Inspector.build(scene, enemy, true)
		var dossier_hp: String = dossier.find_child("PreBattleEnemyHpLine", true, false).text
		var amounts: PackedStringArray = dossier_hp.trim_prefix("HP ").split("/")
		_compare("Dossier Health", room_name + " " + key + " current", amounts[0], str(hp))
		_compare("Dossier Health", room_name + " " + key + " maximum", amounts[1] if amounts.size() > 1 else "", str(maximum))
		dossier.free()
		if int(objective.get("leader_id", -1)) == int(enemy["id"]):
			var detail: String = objective_hud._live_detail(state, objective)
			_compare("Objective Health", room_name + " " + key, detail.ends_with("%d/%d HP" % [hp, maximum]), true)
	objective_hud.free()

func _arena(source: Dictionary, kind: String, intent_id: String) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	var found: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		if enemy["type"] == kind:
			found = enemy
			break
	_require(not found.is_empty(), "Seeded roster contains " + kind)
	if found.is_empty(): return {}
	state["enemies"] = [found]
	state.erase("umbra")
	for key: String in ["terrain", "traps", "illusions"]: state[key] = []
	state["surfaces"] = {}
	var grid: Array = []
	for y: int in range(GRID_SIZE):
		var row: Array = []
		for x: int in range(GRID_SIZE):
			row.append("wall" if x in [0, GRID_SIZE - 1] or y in [0, GRID_SIZE - 1] else "stone")
		grid.append(row)
	state["grid"] = grid
	state["player"].merge({"pos": HERO, "hp": STARTING_HP, "max_hp": STARTING_HP, "block": 0, "stoneskin": 0}, true)
	found["pos"] = ATTACKER
	found["intent"] = _intent(state, found, intent_id)
	state["turn_queue"] = [engine._enemy_actor_entry(state, found, int(state.get("initiative_clock", 0)) + 1, 1)]
	return state

func _intent(state: Dictionary, enemy: Dictionary, id: String) -> Dictionary:
	var catalog: Array = preload("res://scripts/game_data.gd").enemy_def(enemy["type"])["intents"]
	return engine._intent_by_id(engine._scaled_enemy_intents(catalog, int(state["room_depth"]), state, enemy), id)

func _hit(context: String, state: Dictionary, expected: int, icon: String, dossier: bool) -> void:
	if state.is_empty(): return
	var enemy: Dictionary = state["enemies"][0]
	var key: String = engine._enemy_key(enemy)
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var dealt: int = _loss(state, result)
	_require(dealt == expected, "%s resolver hit should be %d, got %d" % [context, expected, dealt])
	var compass: Dictionary = Compass.descriptors_for_state(state)
	_compare("Details compass", context, compass.get(key, {}).get("value"), dealt)
	var badges: Array = Chips.build(engine, state, state)["badges"]
	_compare("Intent chip", context, badges[0].get("number") if not badges.is_empty() else null, str(dealt))
	board.combat_state = state
	board.presentation = {"expanded_enemy_actor_keys": [key]}
	var unit: Dictionary = _board_enemy(enemy)
	var move_rows: Array = board._enemy_intent_rows_for_display(unit, unit["intent"])
	_compare("Board move row and rail inspection", context, _number(move_rows, icon), dealt)
	if dossier:
		scene.set("_pre_battle_preview_run_state", {"combat_state": state})
		var panel: Control = Inspector.build(scene, enemy)
		var rows: Array[Node] = panel.find_children("PreBattleMoveEffect", "Label", true, false)
		var expected_text: String = "%s %d" % [Icons.label(icon), dealt]
		_compare("Dossier tooltip", context, (rows[0] as Label).text.contains(expected_text) if not rows.is_empty() else false, true)
		panel.free()

func _forecast(source: Dictionary, context: String) -> void:
	var scheduled: Dictionary = RedTiles.schedule(engine, source)
	var preview: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var committed: Dictionary = engine.advance_to_next_player_turn_with_steps(scheduled)["state"]
	var amount: int = _loss(source, committed)
	_require(amount > 0, context + " fixture resolves a hit before the next player turn")
	var summary: Dictionary = scene._pass_preview_summary_for_phase_result(source, preview)
	var entries: Array[Dictionary] = scene._pass_preview_forecast_entries(summary)
	for entry: Dictionary in entries:
		if entry["name"] == "PassPreviewHpLoss":
			_compare(context, "displayed Health loss", entry["text"], "-%d" % amount)
			return
	_require(false, context + " must display a Health-loss number")

func _death_burst(state: Dictionary) -> void:
	if state.is_empty(): return
	var enemy: Dictionary = state["enemies"][0]
	var after: Dictionary = engine._damage_enemy(state.duplicate(true), 0, int(enemy["hp"]), true)
	var events: Array = after.get("death_burst_events", [])
	_require(events.size() == 1, "Ember Tick detonates once")
	if events.is_empty(): return
	var dealt: int = _loss(state, after)
	_require(dealt == int(events[0]["damage"]) and dealt > 0, "Burst event amount matches HP loss")
	var base: Dictionary = state.duplicate(true)
	base.erase("difficulty_stats")
	_require(_loss(base, engine._damage_enemy(base.duplicate(true), 0, int(enemy["hp"]), true)) == dealt, "Last Light does not add to death-burst damage")
	_compare("Burst badge", "Ember Tick", BurstView.badges(enemy)[0]["count"], dealt)
	_compare("Burst tooltip", "Ember Tick", BurstView.trait_token(enemy)["value"], "Bursts %d" % dealt)

func _trap(source: Dictionary) -> void:
	if source.is_empty(): return
	var state: Dictionary = source.duplicate(true)
	# The foe's melee chooses a stronger trap on the hero's tile.
	var trap: Dictionary = {"pos": HERO, "element": "fire", "base_damage": TRAP_DAMAGE}
	state["traps"] = [trap]
	var after: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var dealt: int = _loss(state, after)
	_require(after["traps"].is_empty() and dealt == TRAP_DAMAGE, "Foe-triggered trap keeps its own damage")
	board.combat_state = state
	_compare("Trap tooltip", "enemy source", board._trap_tooltip_text(trap).contains("%d damage to the unit" % dealt), true)
	var legacy_trap: Dictionary = {"element": "fire", "damage": LEGACY_NEGATIVE_TRAP_DAMAGE}
	var clamped: int = engine.trap_damage(state, legacy_trap)
	_compare("Trap tooltip", "legacy clamped payload", board._trap_tooltip_text(legacy_trap).contains("%d damage to the unit" % clamped), true)

func _rule_beat(source: Dictionary) -> void:
	var state: Dictionary = source.duplicate(true)
	var enemy: Dictionary = state["enemies"][0]
	var intent: Dictionary = _intent(state, enemy, "peal")
	preload("res://scripts/board_surface_rules.gd").place(state, state["player"]["pos"], "electrified")
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	var after: Dictionary = Beats.fire(engine, state.duplicate(true))
	var dealt: int = _loss(state, after)
	_require(dealt > 0, "Enemy-owned Lightning Storm hits the hero")
	var boosted: Dictionary = state.duplicate(true)
	boosted["difficulty_stats"]["damage_bonus"] = 4
	_require(_loss(boosted, Beats.fire(engine, boosted.duplicate(true))) == dealt, "Enemy-owned rule beat keeps its own damage under a +4 tier")
	_compare("Battlefield-rule move row", "Lightning Storm", _number([RulesRows.tokens(boosted, enemy, intent)], "lightning_strikes"), dealt)
	_compare("Dossier rule row", "Lightning Storm", _number(Inspector.move_rows(intent, enemy, boosted), "lightning_strikes"), dealt)

func _summon(shade: Dictionary, guardian: Dictionary) -> void:
	if shade.is_empty(): return
	for source: Dictionary in [shade, guardian]:
		var state: Dictionary = source.duplicate(true)
		var old: Dictionary = source.duplicate(true)
		old.erase("difficulty_stats")
		var action: Dictionary = {"minion_type": "wick_shade", "count": 1, "summon_cap": 99}
		var before: int = state["enemies"].size()
		state = engine._enemy_summon_minions(state, 0, action)
		old = engine._enemy_summon_minions(old, 0, action)
		_require(state["enemies"].size() == before + 1 and old["enemies"].size() == before + 1, "Summon fixture has a free tile")
		if state["enemies"].size() <= before or old["enemies"].size() <= before: continue
		var minion: Dictionary = state["enemies"].back()
		var expected: int = ceili(float(old["enemies"].back()["max_hp"]) * int(state["difficulty_stats"]["hp_percent"]) / 100.0)
		board.combat_state = state
		var unit: Dictionary = _board_enemy(minion)
		_compare("Arrival Health", str(state["room_type"]) + " current", unit.get("hp"), expected)
		_compare("Arrival Health", str(state["room_type"]) + " maximum", unit.get("max_hp"), expected)
		if source == shade:
			minion["pos"] = ATTACKER
			state["enemies"] = [minion]
			_require(minion["intent"].get("id") == "grasp", "Summoned Shade reveals scaled Grasp")
			_hit("Last Light summoned Grasp", state, 6, "melee", false)

func _command() -> void:
	for captain: Vector2i in CAPTAIN_POSITIONS:
		var state: Dictionary = Warband.arena()
		state["enemies"].resize(2)
		state["player"]["pos"] = HERO
		state["enemies"][0]["pos"] = captain
		var hound: Dictionary = state["enemies"][1]
		hound["type"] = "ash_hound"
		hound["pos"] = HOUND_START
		hound["intent"] = _intent(state, hound, "bite")
		hound["intent"]["actions"][0]["range"] = HOUND_MOVE_RANGE
		var dealt: int = _loss(state, engine.resolve_enemy_turn_with_steps(state, 1)["state"])
		var opening: int = int(preload("res://scripts/warband_combat_rules.gd").intent(state, hound, hound["intent"])["actions"][1]["damage"])
		_require(opening != dealt, "Moving Hound crosses the Command boundary: " + str(captain))
		board.combat_state = state
		var unit: Dictionary = _board_enemy(hound)
		_compare("Warband move row", str(captain), _number(board._move_rows_for_unit(unit, unit["intent"]), "melee"), dealt)
		scene.set("_pre_battle_preview_run_state", {"combat_state": state})
		var dossier: Control = Inspector.build(scene, hound)
		var row: Label = dossier.find_child("PreBattleMoveEffect", true, false)
		_compare("Warband dossier move row", str(captain), row.text.contains("Melee %d" % dealt), true)
		dossier.free()

func _icefall() -> void:
	var state: Dictionary = Warband.arena()
	state["enemies"][0]["pos"] = ATTACKER + Vector2i.UP
	var enemy: Dictionary = state["enemies"][1]
	enemy["type"] = "hoarfrost_seer"
	enemy["pos"] = ATTACKER
	state["player"]["pos"] = HERO
	var mark: Dictionary = _intent(state, enemy, "icefall")
	enemy["intent"] = _intent(state, enemy, "icefall_land")
	enemy["icefall_tiles"] = engine._vector2i_values([HERO])
	var dealt: int = _loss(state, engine.resolve_enemy_turn_with_steps(state, 1)["state"])
	_require(dealt > 5, "Icefall fixture includes Command")
	board.combat_state = state
	_compare("Icefall tile badge", "Warband", Icefall.landing_damage(state, enemy), dealt)
	var tooltip: Array = preload("res://scripts/board_tile_tooltip.gd").mark_entries(board).get(HERO, [])
	_compare("Icefall tile tooltip", "Warband", str(tooltip).contains("%d damage." % dealt), true)
	_compare("Dossier mark row", "Warband Icefall", _number(Inspector.move_rows(mark, enemy, state), "icefall"), dealt)
	enemy["intent"] = mark
	_compare("Details compass", "Warband Icefall", Compass.descriptors_for_state(state)[engine._enemy_key(enemy)]["value"], dealt)

func _lob(state: Dictionary) -> void:
	# Inject a real summon into the generated Last Light room to test the
	# separately scaled centre/arm fields even outside the normal roster.
	state = engine._enemy_summon_minions(state.duplicate(true), 0, {"minion_type": "slag_mortar", "count": 1, "summon_cap": 99})
	if state["enemies"].back()["type"] != "slag_mortar":
		_require(false, "Slag Mortar summon has an open tile")
		return
	state = _arena(state, "slag_mortar", "slag_lands")
	var enemy: Dictionary = state["enemies"][0]
	for center: Vector2i in [HERO, HERO + Vector2i.RIGHT]:
		enemy["lob_center"] = center
		enemy["lob_centers"] = engine._vector2i_values([center])
		enemy["lob_tiles"] = engine._vector2i_values([center, HERO])
		board.combat_state = state
		var amount: int = _loss(state, engine.resolve_enemy_turn_with_steps(state, 0)["state"])
		var mark: Dictionary = preload("res://scripts/enemy_mechanics/lob_view.gd").marks(board).get(HERO, {})
		_compare("Lob tile badge", str(center), mark.get("damage"), amount)
		if center == HERO:
			_compare("Lob intent chip", str(center), Chips.build(engine, state, state)["badges"][0]["number"], str(amount))
		var action: Dictionary = enemy["intent"]["actions"][0]
		_require(amount > 4, "Lob fixture resolves a tier-boosted hit")
		_compare("Lob tooltip", str(center), board.enemy_intent_tooltip(engine._enemy_key(enemy)).contains("%d %s" % [amount, "in the centre" if center == HERO else "around it"]), true)
		_require(int(action["center_damage" if center == HERO else "arm_damage"]) == amount, "Lob announced action matches each contact")

func _board_enemy(enemy: Dictionary) -> Dictionary:
	for unit: Dictionary in board._build_visible_units():
		if unit.get("key") == engine._enemy_key(enemy): return unit
	return {}

func _number(rows: Array, icon: String) -> Variant:
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("icon", "")) == icon and token.has("value"): return token["value"]
	return null

func _loss(before: Dictionary, after: Dictionary) -> int:
	return int(before["player"]["hp"]) - int(after["player"]["hp"])

func _compare(surface: String, context: String, actual: Variant, expected: Variant) -> void:
	counts[surface] = int(counts.get(surface, 0)) + 1
	if actual != expected: failures.append("%s [%s]: displayed %s, resolved %s" % [surface, context, str(actual), str(expected)])

func _require(ok: bool, message: String) -> void:
	if not ok: setup_failures.append(message)
