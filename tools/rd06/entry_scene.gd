extends "res://scripts/run_scene.gd"

## Proof-only fresh entry from the certified pre-battle save. Production combat
## creation is used, without loading an already-running fight.
func _boot_run() -> void:
	_progression = ProgressionStore.load_data()
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_run_engine = preload("res://tools/rd06/entry_engine.gd").new()
	_load_run_state(_run_engine.begin_pre_battle_combat(saved))
