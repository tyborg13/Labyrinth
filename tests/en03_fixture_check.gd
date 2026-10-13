extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Veil = preload("res://scripts/enemy_mechanics/veil.gd")
var _errors: Array[String]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: en03_fixture_check.gd -- <thralls|stalker> <saved-run-path>")
		quit(1)
		return
	var file := FileAccess.open(args[1], FileAccess.READ)
	if file == null:
		push_error("Cannot open fixture save %s" % args[1])
		quit(1)
		return
	var run_state: Dictionary = file.get_var(false)
	file.close()
	var state: Dictionary = run_state.get("combat_state", {})
	var combat := Combat.new()
	_expect(run_state.get("mode", "") == "combat" and combat.is_player_turn(state), "Fixture opens before the enemy activation")
	if args[0] == "thralls":
		var enemies: Array = state.get("enemies", [])
		_expect(enemies.size() == 3 and enemies[0]["type"] == "arc_thrall" and enemies[1]["type"] == "arc_thrall" and enemies[2]["type"] == "crawler", "Fixture has exactly the authored pair and pushable crawler")
		var tether_time: int = -1
		var crawler_time: int = -1
		for slot: Dictionary in state.get("turn_queue", []):
			if int(slot.get("enemy_id", -1)) == 1: tether_time = int(slot["time"])
			if int(slot.get("enemy_id", -1)) == 3: crawler_time = int(slot["time"])
		_expect(tether_time > 0 and tether_time <= crawler_time and enemies[2]["intent"]["id"] == "lunge", "Fixture crawler stays in the beam until Tether resolves")
		var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
		_expect(threat["projected_attack"].has(Vector2i(4, 5)) and threat["projected_path"].size() == 1, "Fixture beam is clear and already aligned")
		var pushed: Dictionary = combat.apply_player_action(state, Data.card_def("buffet")["actions"][0], Vector2i(4, 4))
		_expect(pushed["enemies"][2]["pos"] == Vector2i(4, 5) and int(pushed["enemies"][2]["hp"]) > 0, "Fixture crawler can be pushed onto the beam and survives the push")
		var intent: Dictionary = pushed["enemies"][0]["intent"]
		var result: Dictionary = combat._resolve_enemy_action(pushed.duplicate(true), 0, intent["actions"][0], null, {}, [], combat.enemy_intent_plan(pushed, 0))
		_expect(result["enemies"][2]["hp"] == maxi(0, pushed["enemies"][2]["hp"] - 4), "Fixture Tether strikes the pushed crawler")
	elif args[0] == "stalker":
		var enemy: Dictionary = state["enemies"][0]
		_expect(enemy["type"] == "gloam_stalker" and enemy["intent"]["id"] == "fade" and not bool(enemy.get("veiled", false)), "Fixture stalker is about to Fade")
		_expect(Veil.destination(combat, state, enemy) != enemy["pos"], "Fixture Fade has a free Blink destination")
	else:
		_errors.append("Unknown fixture case %s" % args[0])
	if not _errors.is_empty():
		print("EN03 FIXTURE DIAGNOSTIC grid=%s terrain=%s" % [state.get("grid", []), state.get("terrain", [])])
	for error: String in _errors: push_error(error)
	print("EN03 FIXTURE %s: %s" % [args[0], "PASS" if _errors.is_empty() else "FAIL"])
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
