extends "res://tools/red04/campaign.gd"
## Save the exact settled board so the native capture can check Continue.

func _emit(event: String, data: Dictionary) -> void:
	super._emit(event, data)
	if event != "qa110_sample" or not data.has("red04_repro"): return
	var file := FileAccess.open(output.path_join("combat_state.txt"), FileAccess.WRITE)
	if file == null:
		push_error("RED04 could not write the Walk checkpoint")
		return
	file.store_string(var_to_str(scene._combat_state))
	file.close()
	if not data["red04_repro"]["ok"]: push_error("RED04 Walk replay did not reproduce the expected board")
