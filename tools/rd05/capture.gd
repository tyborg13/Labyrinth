extends SceneTree

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ROOT: String = "/private/tmp/labyrinth_codex/rd-05"
const OUTSIDE_POINTER := Vector2(-1000, -1000)
const SETTLE_FRAMES: int = 20
const SETTLED_SECONDS: float = 3.0
const FPS: int = 30
const CLIP_FRAMES: int = 120
const SELECT_FRAME: int = 6
const TARGET_FRAME: int = 12
const HIT_FRAME: int = 14
var scene: Node
var board: Control
var canvas: SubViewport
var output: String
var clip: bool = false
var zekarion: bool = false
var samples: Array[Dictionary]
var failures: Array[String]
var target: Vector2i
var target_key: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("RD05 native capture is for the design owner; use plate_visibility_proof.gd headlessly")
		quit(1); return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	clip = args.has("--clip")
	zekarion = args.has("--zekarion")
	output = ROOT.path_join("clip" if clip else "zekarion" if zekarion else "stills")
	DirAccess.make_dir_recursive_absolute(output)
	var manifest: String = ROOT.path_join("zekarion.json" if zekarion else "inspection.json")
	if args.has("--fixture-manifest"): manifest = args[args.find("--fixture-manifest") + 1]
	Fixture.install_save(manifest)
	canvas = Fixture.make_canvas(self)
	scene = Fixture.resume(self, canvas)
	await _settle(SETTLE_FRAMES)
	board = scene.get("board_view")
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "UI scale is 100%")
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("role")) == "enemy": target = unit["pos"]; target_key = unit["key"]; break
	if clip:
		_check(not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == FPS, "Native MovieWriter at 30fps required")
		await _movie()
	elif zekarion:
		_clear_hover()
		await _pair("06_zekarion_rest")
	else:
		_clear_hover()
		await _pair("01_five_foe_rest")
		await scene.call("_on_card_pressed", 0)
		Fixture.pointer(self, board, board.call("world_position_for_tile", target))
		await _settle(SETTLE_FRAMES)
		await _pair("02_ranged_aim_hover")
		await scene.call("_on_cancel_requested")
		await scene.call("_on_card_pressed", 1)
		await _settle(SETTLE_FRAMES)
		await _pair("03_area_aim")
		await scene.call("_on_cancel_requested")
		Fixture.pointer(self, board, board.call("world_position_for_tile", target))
		await _settle(SETTLE_FRAMES)
		await _pair("04_foe_hover")
		_clear_hover()
		scene.call("_on_enemy_intent_toggle_toggled", true)
		await _settle(SETTLE_FRAMES)
		await _pair("05_details")
		await _rail_crop()
	var file := FileAccess.open(output.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture": manifest, "movie": clip, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "samples": samples, "failures": failures, "size": [1920, 1080]}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("RD05 NATIVE CAPTURE: %s (%d samples, 1920x1080, 100%% UI)" % ["PASS" if failures.is_empty() else "FAIL", samples.size()])
	print(output)
	quit(0 if failures.is_empty() else 1)

func _pair(label: String) -> void:
	# Freeze the complete production pose/animation tree for the pair. Viewport
	# rendering continues; only the preference and its settled opacity change.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var pose: Dictionary = board.presentation.duplicate(true)
	for value: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
		_setting(value)
		board.plate_visibility.advance(SETTLED_SECONDS)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(state == scene.get("_combat_state") and pose == board.presentation, "Same frozen gameplay and presentation frame for " + label)
		var filename: String = label + "_" + value + ".png"
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == Fixture.SIZE and picture.save_png(output.path_join(filename)) == OK, "Native pair capture: " + filename)
		samples.append({"name": filename, "setting": value, "plate_opacity": board.plate_visibility.opacity(target_key), "frozen_pose": true})
	scene.process_mode = Node.PROCESS_MODE_INHERIT

func _rail_crop() -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var rail: Control = scene.get("_turn_order_panel")
	var image: Image = canvas.get_texture().get_image()
	var rect: Rect2i = Rect2i(rail.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_check(rect.has_area(), "Rail crop has native coverage")
	if rect.has_area():
		image.get_region(rect).save_png(output.path_join("07_rail_crop.png"))
		var file := FileAccess.open(output.path_join("rail_crop.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"source": "05_details_on_hover_and_aim.png", "native_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "resampled": false}))
		file.close()
	scene.process_mode = Node.PROCESS_MODE_INHERIT

func _movie() -> void:
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	_clear_hover()
	var before_hp: int = _target_hp()
	var previous_usec: int = -1
	for frame: int in range(CLIP_FRAMES):
		if frame == SELECT_FRAME: scene.call("_on_card_pressed", 0)
		if frame == TARGET_FRAME: scene.call("_on_board_tile_clicked", target)
		if frame == HIT_FRAME:
			scene.call("_on_confirm_card_play_pressed")
			_clear_hover()
		await RenderingServer.frame_post_draw
		var now: int = Clock.ticks_usec()
		if previous_usec >= 0: _check(absi(now - previous_usec - 33333) <= 1, "Consecutive native movie frame at 1/30s")
		previous_usec = now
		samples.append({"frame": frame, "draw_frame": Engine.get_frames_drawn(), "clock_usec": now, "hp": _target_hp(), "opacity": board.plate_visibility.opacity(target_key), "ghost": board.health_ghost_tracker.sample(target_key)})
	_check(_target_hp() < before_hp, "Production card hit the foe")
	_check(board.plate_visibility.opacity(target_key) == 0.0, "Changed plate completed its hold and fade in the clip")
	canvas.get_texture().get_image().save_png(output.path_join("last_frame.png"))

func _target_hp() -> int:
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("key")) == target_key: return int(unit.get("hp", 0))
	return 0

func _clear_hover() -> void:
	board.call("_update_hover_at", OUTSIDE_POINTER)
	board.call("set_controller_focus_tile", Vector2i(-1, -1))
	board.plate_visibility.pointer_keys.clear()
	board.plate_visibility.external_keys.clear()
	board.plate_visibility.refresh()

func _setting(value: String) -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["board_health_bars"] = value
	Settings.apply_settings(settings, null, false)

func _settle(frames: int) -> void:
	for frame: int in range(frames): await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
