extends "res://scripts/combat_pacing.gd"

var sync_clock: RefCounted

func _sync_clock() -> void:
	if sync_clock != null: _clock_usec = float(sync_clock.visual_usec)
