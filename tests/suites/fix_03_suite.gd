extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const SkillFixture = preload("res://tests/suites/skill_combat_suite.gd")
const BurrowView = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const KindleView = preload("res://scripts/enemy_mechanics/kindle_view.gd")
const CapacitorView = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Mantle = preload("res://scripts/maneuver_rules.gd")
const TEST_EXPOSE: int = 3
const TEST_DEFENSE: int = 100
const TEST_DAMAGE: int = 2
const LATER_CYCLE: int = 2
const TOKEN_CAPTIONS: Dictionary = {
	"burrow": "Burrow", "erupt": "Erupt 6", "kindle": "Kindle +2",
	"gain_charge": "+1", "chain_discharge": "4"
}

static func run(expect: Callable) -> void:
	_test_fatigue(expect)
	_test_skill_hud(expect)
	_test_tokens(expect)

static func _test_fatigue(expect: Callable) -> void:
	var engine := Combat.new()
	for statuses: Dictionary in [{}, {"expose": TEST_EXPOSE}, {"chilled": true}, {"freeze": 1}, {"expose": TEST_EXPOSE, "chilled": true, "freeze": 1}]:
		for cycle: int in [0, LATER_CYCLE]:
			var state: Dictionary = SkillFixture._state(engine, [], ["quick_stab"])
			state["player"].merge(statuses, true)
			state["player"]["block"] = TEST_DEFENSE
			state["player"]["stoneskin"] = TEST_DEFENSE
			state["deck"] = SkillFixture._deck([], [], ["quick_stab"])
			state["deck"]["fatigue_base"] = Combat.FATIGUE_BASE_DAMAGE
			state["deck"]["cycles"] = cycle
			var hp_before: int = state["player"]["hp"]
			var normalized_before: Dictionary = engine._normalized_player(state["player"])
			var received_before: int = state["run_stats"].get("damage_received", 0)
			var expected: int = Combat.FATIGUE_BASE_DAMAGE + cycle
			state = engine._draw_cards_in_place(state, 1)
			var context: String = "Fatigue %s cycle %d" % [statuses, cycle + 1]
			expect.call(hp_before - int(state["player"]["hp"]) == expected, context + " costs exactly base plus cycle")
			expect.call(int(state["run_stats"].get("damage_received", 0)) - received_before == expected, context + " records actual health loss")
			expect.call(state["player"]["block"] == TEST_DEFENSE and state["player"]["stoneskin"] == TEST_DEFENSE, context + " bypasses defenses without consuming them")
			for key: String in statuses:
				expect.call(state["player"][key] == normalized_before[key], context + " preserves normalized " + key)
			expect.call(state["deck"]["hand"] == ["quick_stab"] and state["deck"]["cycles"] == cycle + 1, context + " reshuffles and draws")
	var mantle_state: Dictionary = SkillFixture._state(engine, [], ["quick_stab"])
	mantle_state["deck"] = SkillFixture._deck([], [], ["quick_stab"])
	mantle_state["deck"]["fatigue_base"] = Combat.FATIGUE_BASE_DAMAGE
	Mantle.gain_mantle(mantle_state, 1)
	var mantle_hp: int = mantle_state["player"]["hp"]
	mantle_state = engine._draw_cards_in_place(mantle_state, 1)
	expect.call(mantle_hp - int(mantle_state["player"]["hp"]) == Combat.FATIGUE_BASE_DAMAGE and mantle_state["player"][Mantle.MANTLE_FIELD] == 1, "Fatigue is health loss and leaves Crystal Mantle intact")
	var attacked: Dictionary = SkillFixture._state(engine, [], ["quick_stab"])
	attacked["player"].merge({"expose": TEST_EXPOSE, "chilled": true, "freeze": 1}, true)
	var attack_hp: int = attacked["player"]["hp"]
	attacked = engine._damage_player(attacked, TEST_DAMAGE, true)
	expect.call(attack_hp - int(attacked["player"]["hp"]) == (TEST_DAMAGE + TEST_EXPOSE) * preload("res://scripts/board_surface_rules.gd").FROZEN_MULTIPLIER, "Attack amplification remains unchanged")
	expect.call(attacked["player"]["expose"] == 0, "An attack still consumes Expose")

static func skill_states() -> Array[Dictionary]:
	var engine := Combat.new()
	var before: Dictionary = SkillFixture._state(engine, ["sunpath", "dawnbrand"], ["quick_stab"])
	var after: Dictionary = engine.apply_player_action(before, {"type": "move", "range": 4}, Vector2i(5, 4))
	after = engine.apply_player_action(after, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(5, 2))
	after = engine.apply_player_action(after, {"type": "ranged", "damage": 1, "range": 6}, Vector2i(5, 2))
	var next_turn: Dictionary = engine.prepare_next_player_turn(after)
	var result: Array[Dictionary]
	result.append(before)
	result.append(after)
	result.append(next_turn)
	return result

static func _test_skill_hud(expect: Callable) -> void:
	var scene := RunScene.new()
	scene.set("_run_state", {"mode": "combat"})
	var states: Array[Dictionary] = skill_states()
	for index: int in range(states.size()):
		scene.set("_combat_state", states[index])
		for skill: String in ["sunpath", "dawnbrand"]:
			expect.call(scene._skill_hud_status(skill) == ("SPENT" if index == 1 else "WAITING"), "%s HUD follows real rule activation and next-turn reset (%d)" % [skill, index])
	scene.free()

static func token_cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for action: Dictionary in [{"type": "burrow"}, {"type": "erupt", "damage": 6}, {"type": "kindle", "amount": 2}]:
		var key: String = Icons.action_icon_key(action)
		result.append({"name": "library_" + action["type"], "tokens": Icons.tokens_for_action(action), "icon": key, "caption": TOKEN_CAPTIONS[action["type"]]})
		var rows: Array = KindleView.rows({"actions": [action]}) if action["type"] == "kindle" else BurrowView.rows({"actions": [action]})
		result.append({"name": "intent_" + action["type"], "tokens": rows[0], "icon": key, "caption": TOKEN_CAPTIONS[action["type"]]})
	for action: Dictionary in [{"type": "gain_charge", "amount": 1}, {"type": "chain_discharge", "damage": 4}]:
		var rows: Array = CapacitorView.rows({"actions": [action]})
		result.append({"name": "intent_" + action["type"], "tokens": rows[0], "icon": "charge" if action["type"] == "gain_charge" else "chain", "caption": TOKEN_CAPTIONS[action["type"]]})
	result.append({"name": "lightning_strikes", "tokens": Icons.tokens_for_action({"type": "lightning_strikes", "damage": 3, "count": 4}), "icon": "lightning_strikes"})
	var board := Board.new()
	var relight_rows: Array = board._intent_rows({"actions": [], "restore_braziers": true})
	result.append({"name": "brazier_relight", "tokens": relight_rows[0], "icon": "illuminate", "caption": "Braziers relight afterward"})
	board.free()
	return result

static func _test_tokens(expect: Callable) -> void:
	for entry: Dictionary in token_cases():
		if entry.has("caption"):
			expect.call(Icons.plain_text_for_tokens(entry["tokens"]) == entry["caption"], entry["name"] + " preserves authored summary text")
		var found: bool = false
		for token: Dictionary in entry["tokens"]:
			if token.get("icon", "") == entry["icon"]:
				found = true
				expect.call(token.get("kind", "") != "text", entry["name"] + " reaches the icon renderer")
				expect.call(Icons.icon_texture(entry["icon"]) != null, entry["name"] + " has a loadable approved icon")
				expect.call(not Icons.token_tooltip(token).contains("<"), entry["name"] + " tooltip has no unfilled placeholder")
				if str(entry["name"]).begins_with("intent_gain_charge") or str(entry["name"]).begins_with("intent_chain_discharge"):
					expect.call(Icons.token_tooltip(token) == "Charge\nGains Charge each use. At 3, its next intent is Arc Burst: lightning jumping between nearby units. Shock removes 1.", entry["name"] + " uses the approved Charge definition")
			if entry["name"] == "lightning_strikes":
				expect.call(token.get("icon", "") != "shock", "Lightning Strikes count does not imply Shock")
		expect.call(found, entry["name"] + " includes its concept icon")
