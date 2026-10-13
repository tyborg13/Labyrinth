extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Dive = preload("res://scripts/enemy_mechanics/dive.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
var _errors: Array[String]

func _initialize() -> void:
	var engine := Combat.new()
	for element: String in ["none", "ice", "air"]:
		var mirror: Dictionary = Fixtures.state([Fixtures.enemy("glacial_mirror", 1, Vector2i(5, 4), "refraction"), Fixtures.enemy("crawler", 2, Vector2i(3, 4))], Vector2i(1, 4), element)
		var action: Dictionary = mirror["enemies"][0]["intent"]["actions"][0]
		var before: Dictionary = engine.enemy_threat_tiles(mirror, 0)
		var after: Dictionary = engine._resolve_enemy_action(mirror.duplicate(true), 0, action)
		_expect(before["projected_attack"] == Reflect.line(engine, mirror, 0, action), "%s Refraction uses the same elemental room geometry" % element)
		_expect(after["player"]["hp"] < mirror["player"]["hp"] and after["enemies"][1]["hp"] < mirror["enemies"][1]["hp"], "%s Refraction still strikes both teams" % element)
		var shrike: Dictionary = Fixtures.state([Fixtures.enemy("gust_shrike", 1, Vector2i(2, 4), "dive"), Fixtures.enemy("crawler", 2, Vector2i(3, 4))], Vector2i(6, 4), element)
		action = shrike["enemies"][0]["intent"]["actions"][0]
		after = engine._resolve_enemy_action(shrike.duplicate(true), 0, action)
		_expect(engine._enemy_distance_to_tile(after["enemies"][0], after["player"]["pos"]) == 1 and after["player"]["hp"] < shrike["player"]["hp"], "%s Dive strikes and ends adjacent" % element)
		var plan: Dictionary = Dive.plan(engine, shrike, 0, shrike["enemies"][0]["intent"])
		_expect(engine.enemy_threat_tiles(shrike, 0)["projected_attack"] == plan["dive_tiles"], "%s Dive telegraph matches resolution geometry" % element)
	for error: String in _errors: push_error(error)
	print("EN05 ELEMENTAL INTEGRATION: %s (12 checks, %d failures; neutral, ice, air)" % ["PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
