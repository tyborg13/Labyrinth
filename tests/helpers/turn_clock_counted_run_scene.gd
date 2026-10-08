extends "res://scripts/run_scene.gd"

# Count expensive paths rather than relying on machine-dependent microseconds.
var card_preview_reads: int = 0
var source_reads: int = 0
var source_snapshot: Dictionary = {}

func _turn_order_card_time_preview() -> Dictionary:
	card_preview_reads += 1
	return super._turn_order_card_time_preview()

func _pass_preview_source_state() -> Dictionary:
	source_reads += 1
	# Model the isolated snapshot required by an Umbra forecast.
	return source_snapshot.duplicate(true)
