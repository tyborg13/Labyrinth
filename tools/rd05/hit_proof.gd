extends SceneTree

## Exercise the movie's production input/commit path with no window or pixels.
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Capture = preload("res://tools/rd05/capture.gd")
const MANIFEST: String = "/private/tmp/labyrinth_codex/rd-05/inspection.json"
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-05/hit-proof.json"
var failures: Array[String]
var scene: Node
var board: Control
var samples: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = Capture.FPS
	Fixture.install_save(MANIFEST)
	var canvas: SubViewport = Fixture.make_canvas(self)
	scene = Fixture.resume(self, canvas)
	for frame: int in range(Capture.SETTLE_FRAMES): await process_frame
	board = scene.get("board_view")
	var settings: Dictionary = Settings.default_settings()
	settings["board_health_bars"] = Settings.BOARD_HEALTH_CONTEXTUAL
	Settings.apply_settings(settings, null, false)
	var foe: Dictionary
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("role")) == "enemy": foe = unit; break
	var key: String = foe["key"]
	var before: int = int(foe["hp"])
	var saw_ghost: bool = false
	var saw_plate: bool = false
	var saw_fade: bool = false
	for frame: int in range(Capture.CLIP_FRAMES):
		if frame == Capture.SELECT_FRAME: scene.call("_on_card_pressed", 0)
		if frame == Capture.TARGET_FRAME: scene.call("_on_board_tile_clicked", foe["pos"])
		if frame == Capture.HIT_FRAME:
			scene.call("_on_confirm_card_play_pressed")
			board.call("_update_hover_at", Capture.OUTSIDE_POINTER)
			board.call("set_controller_focus_tile", Vector2i(-1, -1))
			board.plate_visibility.pointer_keys.clear()
			board.plate_visibility.external_keys.clear()
			board.plate_visibility.refresh()
		await process_frame
		var alpha: float = board.plate_visibility.opacity(key)
		var ghost: Dictionary = board.health_ghost_tracker.sample(key)
		var interval: Vector2 = ghost.get("ghost_range", Vector2.ZERO)
		saw_plate = saw_plate or is_equal_approx(alpha, 1.0)
		saw_ghost = saw_ghost or interval.y > interval.x
		if saw_ghost and alpha > 0.0 and alpha < 1.0: saw_fade = true
		samples.append({"frame": frame, "opacity": alpha, "ghost": ghost, "selected": scene.get("_selected_card_index"), "confirm": scene.call("_pending_card_requires_confirmation"), "locked": scene.get("_animation_lock"), "effect": board.presentation.get("effect", {})})
	var after: int = before
	for enemy: Dictionary in (scene.get("_combat_state") as Dictionary).get("enemies", []):
		if int(enemy.get("id", -1)) == int(foe["id"]): after = int(enemy["hp"])
	_check(after < before, "Real selected card hits the foe")
	_check(saw_plate and saw_ghost and saw_fade, "Plate appears, ghost drains, and opacity fades")
	_check(is_zero_approx(board.plate_visibility.opacity(key)), "Plate is gone by the end of four seconds")
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"before_hp": before, "after_hp": after, "samples": samples, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("RD05 HIT PATH: %s (120 frames at 30fps, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
