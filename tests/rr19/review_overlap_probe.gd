extends SceneTree
const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
class FixedPacing extends "res://scripts/combat_pacing.gd":
    var now_usec: int = 0
    func presentation_usec() -> int: return now_usec
    func present_turn_order(_before: Array, _after: Array, _defeated: Dictionary = {}) -> void: pass
func _initialize() -> void:
    preload("res://scripts/parallel_runtime.gd").apply_from_environment()
    _run.call_deferred()
func _run() -> void:
    for types: Array in [["ember_tick"], ["ember_tick", "storm_capacitor"]]:
        var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
        scene.set_script(preload("res://tests/rr17/death_scene.gd"))
        scene._combat_pacing.free()
        var pacing := FixedPacing.new()
        scene._combat_pacing = pacing
        pacing.install(scene)
        root.add_child(scene)
        var units: Array[Dictionary]
        for index: int in range(types.size()): units.append(Fixtures.enemy(types[index], index + 1, Vector2i(index + 4, 3), "scuttle" if types[index] == "ember_tick" else "charge"))
        var before: Dictionary = Fixtures.state(units)
        for unit: Dictionary in before["enemies"]: unit["hp"] = 1
        preload("res://scripts/retaliate_rules.gd").gain(before, {"amount": 1}, "Review")
        var action: Dictionary = preload("res://scripts/game_data.gd").enemy_def("ember_tick")["intents"][0]["actions"][1]
        var resolved: Dictionary = Fixtures.resolve_action(before, action)
        var after: Dictionary = resolved["state"]
        var health: Array = []
        for unit: Dictionary in after["enemies"]: health.append({"type": unit["type"], "hp": unit["hp"]})
        print("RETALIATE RESOLVER ", health, " burst_events=", after.get("death_burst_events", []).size())
        pacing.enemies_active = true
        await scene._animate_turn_order_alongside_defeats(before, after)
        print("OVERLAP ", types, " queued duration_usec=", pacing._deaths[0]["duration"])
        for time: int in [883351, 900000, 1683367, 2436012]:
            pacing.now_usec = time
            var shown: Dictionary = {}
            pacing.decorate(after, shown)
            for unit: Dictionary in shown.get("death_animation_units", []):
                if unit["type"] == "ember_tick": print("  Tick at ", time, " usec: frame=", unit["death_frame"], " phase=", unit["death_progress"])
        scene.free()
    quit()
