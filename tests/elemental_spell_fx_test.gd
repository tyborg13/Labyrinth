extends SceneTree

const AttackFxSuite = preload("res://tests/suites/attack_fx_suite.gd")
const ElementalSpellFx = preload("res://scripts/elemental_spell_fx.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures: Array[String] = []


# Headless submission exercises production draw paths, including repeated path
# points and collapsed travel. Fresh rendered screenshots remain visual proof.
class DrawExercise extends Node2D:
	var progress: float = 0.0
	var draw_count: int = 0

	func _draw() -> void:
		draw_count += 1
		var elements := PackedStringArray(["fire", "earth", "air", "lightning", "ice"])
		for index: int in range(elements.size()):
			var element: String = elements[index]
			var p := Vector2(200.0 + float(index) * 280.0, 300.0)
			var target: Vector2 = p + Vector2(150.0, 60.0)
			ElementalSpellFx.release(self, element, p, p + Vector2(0.0, 20.0), 100.0, progress, 1.0)
			ElementalSpellFx.travel(self, element, p, target, p, target, 100.0, progress, 1.0)
			ElementalSpellFx.travel(self, element, p, p, p, p, 100.0, progress, 1.0)
			for front: bool in [false, true]:
				ElementalSpellFx.impact(self, element, p, 150.0, progress, 1.0, false, front)
				ElementalSpellFx.impact(self, element, p, 150.0, progress, 1.0, true, front)


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")


func _run() -> void:
	AttackFxSuite.run(Callable(self, "_expect"))
	var exercise := DrawExercise.new()
	root.add_child(exercise)
	var ingredients: Array[Texture2D] = AttackFxSuite._spell_ingredients()
	for t: float in [0.0, 0.001, 0.04, 0.13, 0.38, 0.62, 0.90, 0.999, 1.0]:
		exercise.progress = t
		exercise.queue_redraw()
		await process_frame
		await process_frame
	_expect(exercise.draw_count >= 9, "Headless smoke coverage must actually invoke each requested draw state")
	_expect(AttackFxSuite._spell_ingredients() == ingredients, "Drawing every spell phase must retain the prewarmed texture cache")
	exercise.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ELEMENTAL SPELL FX TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ELEMENTAL SPELL FX TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
