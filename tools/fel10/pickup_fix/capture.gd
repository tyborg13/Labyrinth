extends SceneTree
## Replay the census pickup through Continue on either copy of the project.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Clock = preload("res://scripts/presentation_clock.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Driver = preload("res://tools/fel10/combat_inputs.gd")
const Media = preload("res://tools/fel10/pickup_fix/media.gd")
const READY_SECONDS := 10
const ACTION_SECONDS := 20
const INPUT_SETTLE_FRAMES := 8
const NATIVE_WARM_FRAMES := 90
const TRAIL_NAME := "LoadoutAcquisitionTrail"
const BEAM_NAME := "LoadoutAcquisitionBeam"

var _scene: Node
var _viewport: SubViewport
var _media := Media.new()
var _dry: bool
var _movie: bool
var _reduced: bool
var _fps: int
var _seen_burst: bool
var _seen_pulse: bool
var _seen_travel: bool
var _seen_taper: bool
var _seen_receipt: bool
var _flight_ended: bool
var _finished: bool
var _movie_frames: int
var _last_movie_frame: int = -1
var _last_icon_center: Vector2
var _pulse_image: Image
var _input_index: int
var _error: String


class HeadlessDraw extends Node:
	func _process(_delta: float) -> void:
		RenderingServer.frame_post_draw.emit()


class FrameHitStop extends "res://scripts/combat_hit_stop.gd":
	var fps: int

	func request(damage: int, killed: bool = false, hero: bool = false, reduced: bool = false, allowed: bool = true, now_usec: int = -1) -> bool:
		return super.request(damage, killed, hero, reduced, allowed, now_usec if now_usec >= 0 else _frame_usec())

	func poll(now_usec: int = -1) -> void:
		super.poll(now_usec if now_usec >= 0 else _frame_usec())

	func _frame_usec() -> int:
		return roundi(Engine.get_process_frames() * 1000000.0 / fps)


class HeadlessPacing extends "res://scripts/combat_pacing.gd":
	var fps: int

	func install(host: Node) -> void:
		super.install(host)
		hit_stop.free()
		hit_stop = FrameHitStop.new()
		hit_stop.name = "CombatHitStop"
		hit_stop.fps = fps
		hit_stop.restore_scale = current_scale
		hit_stop.scale_changing.connect(_sync_clock)
		hit_stop.stop_ended.connect(_release_flashes)
		add_child(hit_stop)

	func _sync_clock() -> void:
		_clock_usec += _movie_clock.advance(Engine.get_process_frames(), 1.0 / fps, Engine.time_scale, is_inside_tree() and get_tree().paused)


func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()


func _run() -> void:
	_dry = DisplayServer.get_name() == "headless"
	_movie = OS.get_environment("FEL10_FIX_PASS") == "movie"
	_reduced = OS.get_environment("FEL10_FIX_PASS") == "reduced"
	_fps = 30 if _movie else 60
	if _dry:
		var draw := HeadlessDraw.new()
		draw.process_priority = 1000
		root.add_child(draw)
	_media.side = OS.get_environment("FEL10_FIX_SIDE")
	_media.output = OS.get_environment("FEL10_FIX_OUTPUT")
	if not _dry and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != _fps):
		_fail("native renderer requires the fixed frame clock")
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = _reduced
	Settings.set_storage_path("user://fel10_pickup_settings.json")
	var source: String = OS.get_environment("FEL10_FIX_CHECKPOINT")
	var working: String = ProjectSettings.globalize_path("user://fel10_pickup")
	if not Settings.save_settings(settings) or not Checkpoint.stage(source, working):
		_fail("could not stage the census checkpoint or settings")
		return
	if not await _resume():
		_fail("Continue did not settle")
		return
	var differences: Dictionary = Checkpoint.compare(_scene, source)
	if not differences.is_empty():
		_fail("Continue changed " + str(differences))
		return
	var file := FileAccess.open(source.path_join("loot_pickup.inputs"), FileAccess.READ)
	var prefix: Variant = file.get_var(false) if file != null else null
	if not prefix is Array or prefix.is_empty():
		_fail("missing census pickup inputs")
		return
	if not _dry: RenderingServer.frame_post_draw.connect(_observe)
	if not await _drive(prefix):
		_fail(_error if not _error.is_empty() else "pickup replay did not complete")
		return
	if not _dry:
		RenderingServer.frame_post_draw.disconnect(_observe)
		var exported: bool = _media.finish_movie(_pulse_image) if _movie else _media.write_stills()
		if not exported:
			_fail(_media.problem)
			return
	if _reduced:
		print("FEL10 FIX REDUCED PASS inputs=%d receipt=yes flight=no trail=no" % _input_index)
	elif _movie:
		print("FEL10 FIX MOVIE %s PASS inputs=%d frames=%d fps=%d size=1920x1080 burst=yes arrival=yes" % [
			"DRY" if _dry else "NATIVE", _input_index, _movie_frames, _fps])
	else:
		var midpoint: Vector2 = _media.positions[_media.middle()]
		var distance: float = _media.start.distance_to(_media.target)
		print("FEL10 FIX %s PASS side=%s inputs=%d flight_frames=%d strip_frames=%d midpoint=%.3f" % [
			"DRY" if _dry else "NATIVE", _media.side, _input_index, _media.positions.size(), Media.SAMPLES,
			midpoint.distance_to(_media.start) / distance])
	quit()


func _resume() -> bool:
	_viewport = SubViewport.new()
	_viewport.size = Media.SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.gui_embed_subwindows = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = RunScene.instantiate()
	# Match fel-03's headless pacing at both proof rates.
	if _dry:
		_scene._combat_pacing.free()
		var pacing := HeadlessPacing.new()
		pacing.fps = _fps
		_scene._combat_pacing = pacing
		pacing.install(_scene)
	_viewport.add_child(_scene)
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(-1, -1)
	pointer.global_position = pointer.position
	_viewport.push_input(pointer, true)
	for frame: int in READY_SECONDS * _fps:
		await process_frame
		if not _dry and frame < NATIVE_WARM_FRAMES: continue
		if not _scene.has_installed_run() or not _scene.initial_presentation_is_ready(): continue
		var centering: Tween = _scene._board_centering_tween
		if _scene._animation_lock or (centering != null and centering.is_running()): continue
		return _scene._reduced_motion_enabled() == _reduced and is_equal_approx(Typography.ui_scale(_scene), 1.0)
	return false


func _drive(prefix: Array) -> bool:
	var driver := Driver.new()
	for action: Dictionary in prefix:
		_input_index += 1
		if not driver.replay(_scene, action):
			_error = "could not dispatch census input %d" % _input_index
			return false
		for frame: int in ACTION_SECONDS * _fps:
			await process_frame
			if _dry: _observe()
			if not _error.is_empty(): return false
			if _finished: return _input_index == prefix.size()
			if _input_index < prefix.size() and frame >= INPUT_SETTLE_FRAMES and not _scene._animation_lock:
				break
	_error = "pickup did not settle (inputs=%d burst=%s flight=%s arrival=%s)" % [
		_input_index, _seen_burst, _flight_ended, _seen_pulse]
	return false


func _observe() -> void:
	if _finished or not _error.is_empty(): return
	var layer: Control = _scene._card_fx_layer
	if layer == null: return
	var icon: Control = layer.get_node_or_null("EquipmentAcquisitionIcon")
	var beam: Node = layer.get_node_or_null(BEAM_NAME)
	var trail: Node = layer.get_node_or_null(TRAIL_NAME)
	if _reduced:
		if beam != null or trail != null:
			_error = "reduced motion created a flight effect"
		if icon != null and layer.get_node_or_null("PickupDestinationReceipt") != null:
			_seen_receipt = true
			if _center(icon).distance_to(_center(_scene.loadout_button)) > 1.0:
				_error = "reduced-motion icon left the pickup destination"
		if _seen_receipt and icon == null: _finished = true
		return
	if _media.side == "branch" and beam != null:
		_error = "branch created the legacy full-length pickup beam"
		return
	if _media.side == "release" and trail != null:
		_error = "release contains the branch trail"
		return
	if not _seen_burst:
		if icon == null or (not _dry and _scene.find_child("AcquisitionBurst", true, false) == null): return
		_seen_burst = true
	var arrival: Control = _scene.loadout_button
	var target: Vector2 = _center(arrival)
	var image: Image
	if not _dry:
		image = _viewport.get_texture().get_image()
		if image == null or image.get_size() != Media.SIZE:
			_error = "expected a 1920x1080 framebuffer"
			return
	if icon != null:
		var center: Vector2 = _center(icon)
		var marker: Node = trail if _media.side == "branch" else beam
		if not _seen_travel and marker != null:
			_seen_travel = true
			_media.start = _last_icon_center
			_media.target = target
			_media.path = Rect2(_media.start, Vector2.ZERO).expand(target).grow(icon.size.x * icon.scale.x * 0.5)
		if _seen_travel and not _flight_ended:
			_flight_ended = center.distance_to(_media.target) <= 0.01
			if not _movie:
				_media.capture_flight(image, center)
				if image != null and trail != null and float(trail.get_meta("remaining_length", 1.0)) == 1.0:
					_media.capture_trail(image, center)
		_last_icon_center = center
	if trail != null and float(trail.get_meta("remaining_length", 1.0)) < 1.0:
		_seen_taper = true
	var pulsing: bool = not arrival.modulate.is_equal_approx(Color.WHITE)
	if pulsing and not _seen_pulse:
		_seen_pulse = true
		_pulse_image = image
	if _movie and not (_seen_pulse and not pulsing):
		var frame: int = Engine.get_process_frames()
		if _last_movie_frame >= 0 and frame != _last_movie_frame + 1:
			_error = "movie skipped a fixed-clock frame"
			return
		_last_movie_frame = frame
		_movie_frames += 1
		if image != null and not _media.capture_movie(image): _error = _media.problem
	if not _seen_pulse or pulsing: return
	if not _flight_ended or (_media.side == "branch" and (not _seen_taper or trail != null)):
		_error = "flight or complete trail retraction was not observed"
	elif not _movie and _media.positions.size() < Media.SAMPLES:
		_error = "fewer than 12 flight frames"
	else:
		_finished = true


func _center(item: Control) -> Vector2:
	return _viewport.get_stretch_transform() * item.get_global_transform_with_canvas() * (item.size * 0.5)


func _fail(message: String) -> void:
	printerr("FEL10 FIX FAIL %s %s" % [_media.side, message])
	quit(1)
