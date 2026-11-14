extends "res://tools/run_hunt.gd"
## atk-02 proof helper: a seeded run-hunt (real Health with --health 0) that saves
## the real run at idle decision points with one card play and two or more
## movement left, so a native proof can resume "move, then the last card"
## (or, with ATK02_HUNT=final_move, no card play and movement left).
## Writes <output>/repro/<seed>-<n>/{run.save,progression.json,combat_state.txt}.
const SAVE_LIMIT: int = 60
var saved: int = 0
var seen_state: Dictionary = {}

func _tick() -> void:
	if saved < SAVE_LIMIT and _candidate():
		_save_point()
	super._tick()

func _candidate() -> bool:
	if finished or busy or policy == null or not is_instance_valid(scene): return false
	if bool(scene.get("_animation_lock")) or settle_frames > 0 or bool(scene.get("_dialogue_active")): return false
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat": return false
	if int(scene.get("_selected_card_index")) >= 0 or bool(scene.get("_player_movement_selected")): return false
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	if state.is_empty() or state == seen_state or not engine.is_player_turn(state) or not engine.combat_outcome(state).is_empty(): return false
	seen_state = state
	if int(state["player"]["hp"]) < 8: return false
	# ATK02_HUNT=final_move: card plays spent, movement left (the last walk ends the turn).
	if OS.get_environment("ATK02_HUNT") == "final_move":
		return engine.cards_remaining_this_turn(state) == 0 and engine.player_movement_remaining(state) >= 1
	return engine.cards_remaining_this_turn(state) == 1 and engine.player_movement_remaining(state) >= 2

func _save_point() -> void:
	saved += 1
	var directory: String = output.path_join("repro").path_join("%d-%d" % [hunt_seed, saved])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	scene.call("_save_run_progress")
	for name: String in ["run.save", "progression.json"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(output.path_join(name)), ProjectSettings.globalize_path(directory.path_join(name)))
	var file := FileAccess.open(directory.path_join("combat_state.txt"), FileAccess.WRITE)
	file.store_string(var_to_str(scene.get("_combat_state")))
	file.close()
