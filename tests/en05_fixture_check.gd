extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Dive = preload("res://scripts/enemy_mechanics/dive.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
var _errors: Array[String]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: en05_fixture_check.gd -- <mirror|shrike> <saved-run-path>")
		quit(1); return
	var file := FileAccess.open(args[1], FileAccess.READ)
	var run: Dictionary = file.get_var()
	file.close()
	var state: Dictionary = run.get("combat_state", {})
	var engine := Combat.new()
	_expect(run.get("mode") == "combat" and state["enemies"].size() == 2, "Fixture opens directly in combat with exactly two actors")
	if args[0] == "mirror":
		_expect(state["enemies"][0]["type"] == "glacial_mirror" and state["enemies"][1]["type"] == "acolyte", "Mirror fixture roster is authored")
		var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
		_expect(engine._enemy_support_target_index(state, 0, action) == 1, "Mirror is about to guard adjacent Acolyte")
		_expect(state["deck"]["hand"].has("pale_spark"), "Ranged card is in hand")
		_expect(Reflect.reflects(engine, state, Data.card_def("pale_spark")["actions"][0], state["player"]["pos"], 0), "Ranged card would reflect from current hero tile")
	else:
		_expect(state["enemies"][0]["type"] == "gust_shrike" and state["enemies"][1]["type"] == "crawler", "Shrike fixture includes the Crawler")
		var plan: Dictionary = Dive.plan(engine, state, 0, state["enemies"][0]["intent"])
		_expect(plan["path"].size() == 1 and plan["attack_available"] and plan["projected_attack"].has(state["enemies"][1]["pos"]), "Shrike is lined up through Crawler before Dive")
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, state["enemies"][0]["intent"]["actions"][0])
		_expect(engine._enemy_distance_to_tile(after["enemies"][0], after["player"]["pos"]) == 1, "Fixture Dive has a legal adjacent landing")
	for error: String in _errors: push_error(error)
	print("EN05 FIXTURE %s: %s" % [args[0], "PASS" if _errors.is_empty() else "FAIL"])
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
