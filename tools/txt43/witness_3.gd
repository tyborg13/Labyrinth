extends "res://tools/txt43/witness.gd"

const En01 = preload("res://tests/suites/en01_enemies_suite.gd")
const REFRACT_GUARD_ENEMY: String = "frostglass_lancer"

func _run() -> void:
	_refract_guard()
	En01._test_erupt(_erupt_check)
	_kindle_burst()
	_brazier_copy()
	print("TXT43 ROUND 3 WITNESS: %s" % ("FAIL" if _failed else "PASS"))
	quit(int(_failed))

func _refract_guard() -> void:
	var state: Dictionary = Fight.state(REFRACT_GUARD_ENEMY, "refract_guard")
	var hero: Vector2i = state["player"]["pos"]
	Surface.place(state, ORIGIN, "ice", {})
	for direction: Vector2i in Paths.DIRS_4:
		Surface.place(state, ORIGIN + direction, "ice", {})
	Surface.place(state, hero, "ice", {})
	var plan: Dictionary = _engine.enemy_intent_plan(state, 0)
	var landing: Vector2i = plan["destination"]
	var landing_ice: bool = Surface.has_surface(state, landing, "ice")
	var after: Dictionary = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var enemy_tile: Vector2i = after["enemies"][0]["pos"]
	var enemy_ground: String = Surface.element_at(after, enemy_tile)
	var hero_ground: String = Surface.element_at(after, hero)
	_expect(enemy_tile == landing and landing_ice and enemy_ground.is_empty() and hero_ground == "ice",
		"REFRACT GUARD EXPEND", {"Lancer_start": ORIGIN, "Lancer_end": enemy_tile,
			"forecast": landing, "destination_had_ice": landing_ice, "Lancer_ground_after": enemy_ground,
			"hero_tile": hero, "hero_ground_after": hero_ground})

func _erupt_check(ok: bool, message: String) -> void:
	_expect(ok, "ERUPT", message)

func _kindle_burst() -> void:
	var state: Dictionary = Fight.state("ember_hoarder", "kindle")
	state["player"]["pos"] = ADJACENT_HERO
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var charged: Dictionary = _engine._resolve_enemy_action(state.duplicate(true), 0, action)
	var attack: Dictionary = {"type": "melee", "range": 1, "damage": state["enemies"][0]["hp"]}
	var normal: Dictionary = _engine.apply_player_action(state, attack, ORIGIN)
	var kindled: Dictionary = _engine.apply_player_action(charged, attack, ORIGIN)
	var health: int = int(state["player"]["hp"])
	var normal_loss: int = health - int(normal["player"]["hp"])
	var kindled_loss: int = health - int(kindled["player"]["hp"])
	_expect(normal_loss > 0 and kindled_loss - normal_loss == int(action["amount"]), "EMBER HOARDER KINDLE",
		{"base_burst": normal_loss, "kindled_burst": kindled_loss, "Kindle": action["amount"]})

func _brazier_copy() -> void:
	var state: Dictionary = Fight.state("noctyrax", "night_coil")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var board_tooltip: String = Icons.brazier_rule_tooltip(action)
	var row_tooltip: String
	for token: Dictionary in Icons.tokens_for_guardian_rule(action):
		if str(token.get("value", "")).ends_with("Snuff brazier"):
			row_tooltip = Icons.token_tooltip(token)
	_expect(row_tooltip == "Puts out the Marked brazier."
		and board_tooltip == "Night Coil puts out the Marked brazier. Enter that brazier's tile to relight the brazier before Eclipse.",
		"NIGHT COIL COPY", {"move_chip": row_tooltip, "brazier": board_tooltip})
