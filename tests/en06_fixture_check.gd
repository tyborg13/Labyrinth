extends SceneTree
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
var _failures: Array[String]
func _initialize() -> void:
	Runtime.apply_from_environment()
	var value: Dictionary = Store.load_saved_run().get("combat_state", {})
	var capacitor: bool = OS.get_cmdline_user_args().has("--capacitor")
	if value.is_empty(): _failures.append("Fixture has no saved combat")
	else:
		var enemies: Array = value.get("enemies", [])
		if capacitor:
			if enemies.size() != 4 or enemies[0].get("type", "") != "storm_capacitor" or int(enemies[0].get("charge", -1)) != 2: _failures.append("Capacitor fixture requires exactly two Charge and three crawlers")
			for index: int in range(1, enemies.size()):
				var delta: Vector2i = Vector2i(enemies[index]["pos"]) - Vector2i(enemies[0]["pos"])
				if enemies[index].get("type", "") != "crawler" or absi(delta.x) + absi(delta.y) != 1: _failures.append("Crawler is not adjacent to the capacitor")
		else:
			if enemies.is_empty() or enemies[0].get("type", "") != "hollow_mimic": _failures.append("Mimic fixture lacks its enemy")
			if not value.get("deck", {}).get("hand", []).has("whirlwind_slash"): _failures.append("Mimic fixture needs the area card in hand")
	for failure: String in _failures: push_error(failure)
	print("EN06 %s FIXTURE CHECK: %s" % ["CAPACITOR" if capacitor else "MIMIC", "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)
