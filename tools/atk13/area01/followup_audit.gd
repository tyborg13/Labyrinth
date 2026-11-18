extends "res://tools/atk13/area01/audit.gd"
## Per-action forecast receipts supplement atk-13's generic red-owner matrix.
func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	var result: Dictionary = super._check(engine,committed,mode,tile,point_id)
	var predicted: RefCounted = AreaObserver.new()
	predicted.observing = true
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile",tile)
	var forecast: Dictionary = _forecast_trace(predicted,committed,source)
	predicted.observing = false
	result["area01_followup_forecast_receipts"] = predicted.receipts
	return result
