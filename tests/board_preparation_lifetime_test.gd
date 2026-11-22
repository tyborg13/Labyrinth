extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Element = preload("res://scripts/element_data.gd")
const Preparation = preload("res://scripts/encounter_asset_preparation.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const TRAP_TILE := Vector2i.ZERO
const TRAP_DEPTH: int = 1
const TRAP_FRAME_COUNT: int = 16


class DeferredErrorLog extends Logger:
	var opening_board_errors: int = 0
	var opening_objective_errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var message: String = "%s %s" % [code, rationale]
		if not message.contains("Error calling deferred method:"): return
		if message.contains("::prepare_opening_board_for"): opening_board_errors += 1
		if message.contains("::prepare_opening_objective_for"): opening_objective_errors += 1


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await process_frame
	var trap_assets_retained: bool = _check_trap_assets()
	var freed_scene_safe: bool = await _check_freed_scene()
	var passed: bool = trap_assets_retained and freed_scene_safe
	print("TEST RESULT: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)


func _check_trap_assets() -> bool:
	var trap: Dictionary = Rooms.new()._trap_for_tile(TRAP_TILE, Element.FIRE, TRAP_DEPTH)
	var state: Dictionary = {"grid": [["stone"]], "traps": [trap]}
	var shown: Dictionary = {"reduced_motion": true}
	var board := Board.new()
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	var marker: Texture2D = board._trap_idle_texture(trap)
	var idle: Array[Texture2D] = board._trap_idle_frames_for_element(Element.FIRE)
	var activation: Array[Texture2D] = board._trap_activation_frames_for_element(Element.FIRE)
	var prepared: bool = marker != null and idle.size() == TRAP_FRAME_COUNT and activation.size() == TRAP_FRAME_COUNT
	root.add_child(board)
	var retained_at_ready: bool = _has_prepared_trap_assets(board, trap, marker, idle, activation)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	var retained_after_resubmission: bool = _has_prepared_trap_assets(board, trap, marker, idle, activation)
	board.queue_free()
	print("DETACHED TRAP ASSETS: prepared=%s, retained at ready=%s, retained after unchanged submission=%s" % [
		prepared, retained_at_ready, retained_after_resubmission,
	])
	return prepared and retained_at_ready and retained_after_resubmission


func _has_prepared_trap_assets(board: Control, trap: Dictionary, marker: Texture2D,
		idle: Array[Texture2D], activation: Array[Texture2D]) -> bool:
	return (
		board._trap_idle_texture(trap) == marker
		and board._trap_idle_frames_for_element(Element.FIRE) == idle
		and board._trap_activation_frames_for_element(Element.FIRE) == activation
	)


func _check_freed_scene() -> bool:
	var errors := DeferredErrorLog.new()
	OS.add_logger(errors)
	var scene := RunScene.new()
	var combat: Dictionary = {"room_type": "guardian"}
	scene._schedule_opening_hand_pool_preparation(combat)
	var alive: Callable = Preparation.hand_active.bind(scene, scene._encounter_preparation_generation, scene._opening_hand_pool_preparation_revision)
	Preparation.prepare_opening_objective_for.call_deferred(scene, combat, Preparation.present_frame.bind(self), alive)
	scene.free()
	await process_frame
	OS.remove_logger(errors)
	print("FREED SCENE DEFERRED ERRORS: opening board=%d, opening objective=%d" % [
		errors.opening_board_errors, errors.opening_objective_errors,
	])
	return errors.opening_board_errors == 0 and errors.opening_objective_errors == 0
