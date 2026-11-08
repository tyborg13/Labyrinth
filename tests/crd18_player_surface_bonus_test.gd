extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Rite = preload("res://scripts/rite_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
const PLAYER := Vector2i(2, 3)
const LANDING := Vector2i(3, 3)
const TARGET := Vector2i(4, 3)
const ELSEWHERE := Vector2i(2, 2)

var _checks: int = 0
var _failures: Array[String]
var _engine := Combat.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok: _failures.append(message)

func _state(rite_active: bool) -> Dictionary:
	var state: Dictionary = Fixture.fixture(_engine)
	state["deck"]["hand"] = ["kindle"]
	state["deck"]["draw"] = ["brace", "brace"]
	state["deck"]["discard"] = []
	if rite_active:
		_expect(Rite.start(state, "salamander_heart", Data.card_def("salamander_heart")), "Salamander Heart starts via production Rite API")
	return state

func _run() -> void:
	var baseline: bool = OS.get_cmdline_user_args().has("--before")
	for rite_active: bool in [false, true]:
		_test_kindle(rite_active)
		_test_shared_melee(rite_active)
		if not baseline:
			_test_wall(rite_active)
			_test_rush(rite_active)
	if not baseline:
		_test_faces()
		_test_surface_subject_prefixes()
	for failure: String in _failures: push_error(failure)
	print("CRD18 %s RESULT: %s (%d checks, %d failures)" % ["BEFORE" if baseline else "PLAYER SURFACE BONUS", "PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_kindle(rite_active: bool) -> void:
	for own_tile: bool in [false, true]:
		var state: Dictionary = _state(rite_active)
		var actions: Array = _engine.card_play_actions("kindle", state)
		_expect(_engine.valid_targets_for_player_action(state, actions[0]).has(PLAYER), "Kindle already allows own tile")
		var target: Vector2i = PLAYER if own_tile else ELSEWHERE
		var initial_hand: int = state["deck"]["hand"].size()
		for action: Dictionary in actions:
			state = _engine.apply_player_action(state, action, target)
		_expect(Surface.has_surface(state, PLAYER, "fire") == own_tile, "Kindle puts Fire on chosen tile, including self")
		_expect(state["deck"]["hand"].size() == initial_hand + 1, "Kindle still draws one after placement")
		# Polar Guard's exact player-subject check with Fire as its surface.
		var guard: Dictionary = (Data.card_def("polar_guard")["actions"][0] as Dictionary).duplicate(true)
		guard["surface_bonus"]["surface"] = "fire"
		var before: Dictionary = state.duplicate(true)
		var after: Dictionary = _engine.apply_player_action(state, guard)
		_expect(int(after["player"]["block"]) - int(before["player"]["block"]) == (9 if own_tile else 6), "Polar-style check uses player Fire independently of Salamander Heart")

func _test_shared_melee(rite_active: bool) -> void:
	for on_fire: bool in [false, true]:
		var state: Dictionary = _state(rite_active)
		state["player"]["pos"] = LANDING
		Surface.place(state, LANDING if on_fire else TARGET, "fire")
		var action: Dictionary = {"type": "melee", "range": 1, "damage": 6, "element": "fire", "surface_bonus": {"surface": "fire", "subject": "player", "present": true, "damage": 3}}
		var expected: int = 9 if on_fire else 6
		_expect(_engine.final_damage_for_player_action(state, action) == expected, "Shared melee forecast already supports player-subject Fire")
		var after: Dictionary = _engine.apply_player_action(state, action, TARGET)
		_expect(int(state["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) == expected, "Shared melee resolver checks player, not target")

func _test_wall(rite_active: bool) -> void:
	for through_player: bool in [false, true]:
		var state: Dictionary = _state(rite_active)
		var actions: Array = _engine.card_play_actions("cinder_wall", state)
		var target: Vector2i = PLAYER if through_player else ELSEWHERE
		for action: Dictionary in actions:
			state = _engine.apply_player_action(state, action, target)
		_expect(Surface.has_surface(state, PLAYER, "fire") == through_player, "Cinder Wall places its line before checking Block")
		_expect(int(state["player"]["block"]) == (8 if through_player else 4), "Cinder Wall grants 8/4 Block with/without player Fire, with either Rite state")

func _test_rush(rite_active: bool) -> void:
	for lands_on_fire: bool in [false, true]:
		var state: Dictionary = _state(rite_active)
		# Opposite origin/destination conditions detect a premature bonus snapshot.
		Surface.place(state, LANDING if lands_on_fire else PLAYER, "fire")
		var actions: Array = _engine.card_play_actions("hearth_rush", state)
		state = _engine.apply_player_action(state, actions[0], LANDING)
		_expect(state["player"]["pos"] == LANDING, "Hearth Rush resolves Move before strike")
		_expect(int(state["player"]["hp"]) == (998 if lands_on_fire and not rite_active else 1000), "Entering Fire retains its existing 2 damage and Salamander immunity")
		var expected: int = 9 if lands_on_fire else 6
		var before: Dictionary = state.duplicate(true)
		_expect(_engine.final_damage_for_player_action(state, actions[1]) == expected, "Hearth Rush forecast uses post-Move player tile")
		_expect(state == before, "Damage forecast leaves live state unchanged")
		var forecast: Dictionary = _engine.apply_prevalidated_player_action(state, actions[1], TARGET)
		state = _engine.apply_player_action(state, actions[1], TARGET)
		_expect(state == forecast, "Hearth Rush forecast and commitment agree")
		_expect(int(before["enemies"][0]["hp"]) - int(state["enemies"][0]["hp"]) == expected, "Hearth Rush deals 9/6 at strike independently of Salamander Heart")
		_expect(Surface.has_surface(state, TARGET, "fire"), "Hearth Rush retains Fire beneath target")

func _test_faces() -> void:
	var block: Dictionary = Data.card_def("cinder_wall")["actions"][1]
	var melee: Dictionary = Data.card_def("hearth_rush")["actions"][1]
	var guard: Dictionary = (Data.card_def("polar_guard")["actions"][0] as Dictionary).duplicate(true)
	guard["surface_bonus"] = block["surface_bonus"].duplicate(true)
	_expect(Icons.tokens_for_surface_bonus(block) == Icons.tokens_for_surface_bonus(guard), "Cinder Wall uses Polar Guard's exact conditional token pattern")
	var scorch: Dictionary = (Data.card_def("scorch")["actions"][0] as Dictionary).duplicate(true)
	scorch["type"] = "melee"
	scorch["range"] = 1
	scorch["surface_bonus"]["subject"] = "player"
	_expect(Icons.tokens_for_surface_bonus(melee) == Icons.tokens_for_surface_bonus(scorch), "Hearth Rush uses Scorch's damage bonus pattern with player subject")
	for action: Dictionary in [block, melee]:
		var tokens: Array = Icons.tokens_for_surface_bonus(action)
		_expect(tokens[0]["surface_condition"]["subject"] == "player", "Face condition retains player subject")
		_expect(str(tokens[0]["tooltip"]).contains("if on Fire"), "Face condition tooltip identifies player on Fire")
		_expect(Icons.rows_for_card({"actions": [action]}).has(tokens), "Face includes its conditional bonus row")

func _test_surface_subject_prefixes() -> void:
	for present: bool in [false, true]:
		var placement: String = "on" if present else "off"
		var player: Dictionary = Icons.surface_condition_token({"surface": "fire", "subject": "player", "present": present})
		_expect(player["prefix"] == "you " + placement, "Player face explicitly says you on/off")
		_expect(Icons.plain_text_for_tokens([player]) == "if %s Fire:" % placement, "Player plain text is unchanged")
		_expect(player["tooltip"] == "if %s Fire:" % placement, "Player tooltip is unchanged")
		var target: Dictionary = Icons.surface_condition_token({"surface": "fire", "subject": "target", "present": present})
		_expect(target["prefix"] == placement, "Target face retains its on/off prefix")
		_expect(Icons.plain_text_for_tokens([target]) == "Target %s Fire:" % placement and target["tooltip"] == "Target %s Fire:" % placement, "Target plain text and tooltip are unchanged")
	var affected: Array[String]
	for id: String in Data.cards():
		if bool(Data.card_def(id).get("retired", false)): continue
		for row: Array in Icons.rows_for_card(Data.card_def(id)):
			for token: Dictionary in row:
				if str(token.get("kind", "")) != "surface_condition" or str(token.get("surface_condition", {}).get("subject", "")) != "player": continue
				_expect(token["prefix"] == ("you on" if bool(token["surface_condition"].get("present", true)) else "you off"), id + " identifies player on its face")
				if not affected.has(id): affected.append(id)
	affected.sort()
	# crd-09 (owner-approved 2026-11-08) moved Hotfoot onto the same player-subject check.
	_expect(affected == ["cinder_wall", "hearth_rush", "hotfoot", "polar_guard", "worldroot_stride"], "All live player-subject surface faces are covered")
	print("CRD18 PLAYER-SUBJECT FACES: " + ", ".join(affected))
