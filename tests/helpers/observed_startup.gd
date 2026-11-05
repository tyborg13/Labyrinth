extends "res://scripts/startup.gd"
## Observe the production fade without substituting its tween or advancing time.
## Wall timestamps can omit the first tween step when a loaded frame starts it.

signal fade_completed_for_test

var fade_records: Array[Dictionary]

func _fade(target: CanvasItem, alpha: float, seconds: float) -> void:
	var before: Array[Tween] = get_tree().get_processed_tweens()
	var initial_alpha: float = target.modulate.a
	var completion: Dictionary = {"done": false}
	_complete_production_fade(target, alpha, seconds, completion)
	var created: Array[Tween]
	for tween: Tween in get_tree().get_processed_tweens():
		if not before.has(tween): created.append(tween)
	if not bool(completion["done"]):
		await fade_completed_for_test
	var elapsed: float = created[0].get_total_elapsed_time() if created.size() == 1 else 0.0
	fade_records.append({"seconds": seconds, "tweens": created.size(), "elapsed": elapsed, "from": initial_alpha, "to": target.modulate.a})

func _complete_production_fade(target: CanvasItem, alpha: float, seconds: float, completion: Dictionary) -> void:
	await super._fade(target, alpha, seconds)
	completion["done"] = true
	fade_completed_for_test.emit()
