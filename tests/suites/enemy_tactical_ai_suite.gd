extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	_test_non_boss_roster_has_explicit_roles(expect)
	_test_out_of_range_stationary_shot_is_rejected(expect)
	_test_close_skirmisher_prefers_retreat(expect)
	_test_frontliner_advances_instead_of_bracing_far_away(expect)
	_test_wounded_ally_makes_support_heal_decisive(expect)
	_test_support_holds_a_legal_back_line_position(expect)
	_test_low_health_support_heals_instead_of_attacking_at_close_range(expect)
	_test_warden_guards_threatened_squadmates_and_advances_when_safe(expect)
	_test_tactical_evaluation_is_read_only_and_bounded(expect)
	_test_resolved_steps_identify_tactical_policy(expect)
	_test_seeded_variation_remains_between_sensible_attacks(expect)

static func _test_non_boss_roster_has_explicit_roles(expect: Callable) -> void:
	var expected_profiles := {
		"crawler": "frontliner",
		"acolyte": "artillery",
		"harrier": "skirmisher",
		"warden": "protector",
		"cinder_ooze": "frontliner",
		"cinder_droplet": "skirmisher",
		"bile_bloomer": "artillery",
		"chainbound_gaoler": "controller",
		"grave_surgeon": "support",
		"frostglass_lancer": "skirmisher",
		"veilbound_acolyte": "skirmisher",
		"lightning_wisp": "skirmisher",
	}
	for enemy_type_var: Variant in expected_profiles.keys():
		var enemy_type: String = str(enemy_type_var)
		var profile: Dictionary = GameData.enemy_def(enemy_type).get("ai_profile", {}) as Dictionary
		expect.call(str(profile.get("role", "")) == str(expected_profiles[enemy_type]), "%s should declare its tactical squad role" % enemy_type)
		expect.call(int(profile.get("preferred_range", 0)) >= 1, "%s should declare a positive preferred engagement range" % enemy_type)

static func _test_out_of_range_stationary_shot_is_rejected(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(Vector2i(1, 4), [_enemy("harrier", 1, Vector2i(6, 4))])
	var ids: Array[String] = _option_ids(combat.enemy_tactical_intent_options(state, 0))
	expect.call(not ids.has("pelt"), "A far skirmisher should reject a stationary ranged intent that cannot reach its target")
	expect.call(ids.has("darting_pelt"), "A far skirmisher should retain a move-and-shoot intent that reaches a legal firing lane")

static func _test_close_skirmisher_prefers_retreat(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(Vector2i(3, 4), [_enemy("harrier", 1, Vector2i(4, 4))])
	var options: Array[Dictionary] = combat.enemy_tactical_intent_options(state, 0)
	var ids: Array[String] = _option_ids(options)
	expect.call(ids == _string_array(["retreat_step"]), "An adjacent Bone Harrier should decisively retreat instead of randomly holding or rushing")
	if not options.is_empty():
		var path: Array[Vector2i] = _tiles(options[0].get("path", []))
		expect.call(path.size() > 1 and path[path.size() - 1].distance_to(Vector2i(3, 4)) > path[0].distance_to(Vector2i(3, 4)), "The chosen retreat should increase separation inside the same activation")

static func _test_frontliner_advances_instead_of_bracing_far_away(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(Vector2i(1, 4), [_enemy("crawler", 1, Vector2i(6, 4))])
	var ids: Array[String] = _option_ids(combat.enemy_tactical_intent_options(state, 0))
	expect.call(not ids.has("coil"), "A distant frontliner should not spend its activation on a defensive posture")
	expect.call(ids.has("lunge") or ids.has("skitter_strike"), "A distant frontliner should choose a purposeful closing attack")

static func _test_wounded_ally_makes_support_heal_decisive(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var surgeon: Dictionary = _enemy("grave_surgeon", 1, Vector2i(6, 4))
	var wounded_crawler: Dictionary = _enemy("crawler", 2, Vector2i(5, 4))
	wounded_crawler["hp"] = 2
	wounded_crawler["max_hp"] = 10
	var state: Dictionary = _state(Vector2i(1, 4), [surgeon, wounded_crawler])
	var options: Array[Dictionary] = combat.enemy_tactical_intent_options(state, 0)
	expect.call(_option_ids(options) == _string_array(["triage_suture"]), "A Grave Surgeon with a badly wounded ally in range should choose Triage Suture")
	if not options.is_empty():
		expect.call(int(options[0].get("heal_target_index", -1)) == 1, "The tactical heal should identify the most wounded reachable ally")

static func _test_support_holds_a_legal_back_line_position(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var surgeon: Dictionary = _enemy("grave_surgeon", 1, Vector2i(6, 4))
	var wounded_crawler: Dictionary = _enemy("crawler", 2, Vector2i(5, 4))
	wounded_crawler["hp"] = 4
	wounded_crawler["max_hp"] = 10
	var state: Dictionary = _state(Vector2i(1, 4), [surgeon, wounded_crawler])
	var intent: Dictionary = _intent("grave_surgeon", "triage_suture")
	var plan: Dictionary = combat.enemy_intent_plan(state, 0, intent)
	expect.call(_tiles(plan.get("path", [])).size() == 1, "A support-only intent with an ally already in range should hold position instead of drifting toward the player")
	var resolved: Dictionary = combat.call("_resolve_enemy_intent", state.duplicate(true), 0, intent)
	var resolved_enemies: Array = resolved.get("enemies", []) as Array
	expect.call((resolved_enemies[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(6, 4), "Resolved support movement should preserve the back-line anchor")
	expect.call(int((resolved_enemies[1] as Dictionary).get("hp", 0)) > 4, "Holding position should still resolve the authored ally heal")

static func _test_low_health_support_heals_instead_of_attacking_at_close_range(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var surgeon: Dictionary = _enemy("grave_surgeon", 1, Vector2i(4, 4))
	surgeon["hp"] = 2
	var state: Dictionary = _state(Vector2i(3, 4), [surgeon])
	var ids: Array[String] = _option_ids(combat.enemy_tactical_intent_options(state, 0))
	expect.call(ids == _string_array(["triage_suture"]), "A low-health Grave Surgeon beside the player should heal itself instead of defaulting to Saw Jab; options=%s" % str(ids))

static func _test_warden_guards_threatened_squadmates_and_advances_when_safe(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var safe_state: Dictionary = _state(Vector2i(1, 1), [
		_enemy("warden", 1, Vector2i(6, 5)),
		_enemy("grave_surgeon", 2, Vector2i(5, 6)),
	])
	var safe_ids: Array[String] = _option_ids(combat.enemy_tactical_intent_options(safe_state, 0))
	expect.call(not safe_ids.has("bulwark"), "A Stone Warden should advance instead of guarding allies who are outside the tactical threat band")
	expect.call(safe_ids.has("marching_blow") or safe_ids.has("crushing_step"), "A Stone Warden with a safe back line should close distance to screen it")

	var threatened_state: Dictionary = _state(Vector2i(2, 4), [
		_enemy("warden", 1, Vector2i(5, 4)),
		_enemy("grave_surgeon", 2, Vector2i(3, 4)),
	])
	var threatened_ids: Array[String] = _option_ids(combat.enemy_tactical_intent_options(threatened_state, 0))
	expect.call(threatened_ids == _string_array(["bulwark"]), "A Stone Warden should decisively choose Bulwark when a vulnerable squadmate is already exposed to the player; options=%s" % str(threatened_ids))

static func _test_tactical_evaluation_is_read_only_and_bounded(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(Vector2i(2, 4), [
		_enemy("warden", 1, Vector2i(4, 4)),
		_enemy("grave_surgeon", 2, Vector2i(5, 4)),
		_enemy("harrier", 3, Vector2i(4, 5)),
	])
	var enemies: Array = state.get("enemies", []) as Array
	var wounded_harrier: Dictionary = enemies[2] as Dictionary
	wounded_harrier["hp"] = 3
	enemies[2] = wounded_harrier
	state["enemies"] = enemies
	var before: Dictionary = state.duplicate(true)
	for enemy_index: int in range(enemies.size()):
		var options: Array[Dictionary] = combat.enemy_tactical_intent_options(state, enemy_index)
		var enemy_type: String = str(((state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("type", ""))
		var authored_count: int = (GameData.enemy_def(enemy_type).get("intents", []) as Array).size()
		expect.call(options.size() <= authored_count, "%s tactical evaluation should plan each authored intent at most once" % enemy_type)
	expect.call(state == before, "Tactical intent evaluation should be a read-only decision pass over the combat snapshot")

static func _test_resolved_steps_identify_tactical_policy(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var crawler: Dictionary = _enemy("crawler", 1, Vector2i(6, 4))
	crawler["intent"] = _intent("crawler", "lunge")
	var state: Dictionary = _state(Vector2i(1, 4), [crawler])
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
	var saw_tagged_action: bool = false
	for step_var: Variant in result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var as Dictionary
		if str(step.get("kind", "")) not in ["move", "melee"]:
			continue
		if str(step.get("enemy_type", "")) == "crawler" and str(step.get("ai_role", "")) == "frontliner" and str(step.get("intent_id", "")) == "lunge":
			saw_tagged_action = true
			break
	expect.call(saw_tagged_action, "Resolved enemy steps should identify the enemy type, tactical role, and revealed intent for analytics")

static func _test_seeded_variation_remains_between_sensible_attacks(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var selected: Dictionary = {}
	for seed: int in range(1, 65):
		var state: Dictionary = _state(Vector2i(3, 4), [_enemy("crawler", 1, Vector2i(4, 4))])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		combat.call("_assign_enemy_intent", state, 0, rng)
		var intent: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {}) as Dictionary
		selected[str(intent.get("id", ""))] = true
	expect.call(selected.has("skitter_strike") and selected.has("lunge"), "Seeded selection should retain replayable variation between sensible adjacent attacks")
	expect.call(not selected.has("coil"), "Seeded variation should not reintroduce a low-value defensive choice beside an immediately available attack")

static func _state(player_pos: Vector2i, enemies: Array) -> Dictionary:
	return {
		"grid": _grid(),
		"room_depth": 1,
		"player": {"pos": player_pos, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0},
		"enemies": enemies.duplicate(true),
		"illusions": [],
		"terrain": [],
		"traps": [],
		"objective": {},
		"log": [],
	}

static func _enemy(enemy_type: String, enemy_id: int, pos: Vector2i) -> Dictionary:
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	var max_hp: int = int(definition.get("max_hp", 10))
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"stoneskin": 0,
		"intent": {},
	}

static func _intent(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if str(intent.get("id", "")) == intent_id:
			return intent.duplicate(true)
	return {}

static func _option_ids(options: Array[Dictionary]) -> Array[String]:
	var result: Array[String]
	for option: Dictionary in options:
		result.append(str(option.get("intent_id", "")))
	return result

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values:
		result.append(str(value))
	return result
