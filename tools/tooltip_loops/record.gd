extends SceneTree
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const FPS: int = 30
static var _vignette_weights := PackedFloat32Array()
static var _vignette_size := Vector2i.ZERO
const MIN_ACTION_FRAMES: int = 90
const NORMAL_MAX_ACTION_FRAMES: int = 126
const FAST_MAX_ACTION_FRAMES: int = 165
const BACKGROUND_CHANNEL_TOLERANCE: float = 2.0 / 255.0 # Debug readback tolerance.
const PLAYBACK_WATCHDOG_FRAMES: int = 900 # Debug runaway guard, not an authored duration.
var failures: Array[String]
var recording: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var semantics_only: bool = OS.get_cmdline_user_args().has("--semantics-only")
	var rehearsal: bool = OS.get_cmdline_user_args().has("--rehearsal")
	recording = not semantics_only and not rehearsal
	if recording and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty()):
		push_error("Use record.py on the design owner's window server for deterministic recording")
		quit(1); return
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	if rehearsal: Engine.max_fps = FPS
	root.size = Vector2i(16, 16) # The MovieWriter clock sink; footage comes from the full SubViewport.
	root.content_scale_size = root.size
	var viewport: SubViewport = Playback.canvas(self) if not semantics_only else null
	for row: Dictionary in Registry.entries():
		var fixture: Dictionary = Fixture.build(str(row["id"]))
		var engine := Combat.new()
		var result: Dictionary = Fixture.plan(fixture, engine)
		failures.append_array(Fixture.validate(fixture, result))
		print("TIP01 SEMANTICS %s: %s" % [row["id"], "PASS" if Fixture.validate(fixture, result).is_empty() else "FAIL"])
		if not semantics_only: await _record(viewport, fixture, result, row)
		if not failures.is_empty(): break
	for failure: String in failures: push_error(failure)
	print("TIP01 %s RESULT: %s (%d failures)" % ["SEMANTICS" if semantics_only else "REHEARSAL" if rehearsal else "RECORD", "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

static func action_frame_limit(speed: String = "normal") -> int:
	return FAST_MAX_ACTION_FRAMES if speed == "fast" else NORMAL_MAX_ACTION_FRAMES

func _record(viewport: SubViewport, fixture: Dictionary, result: Dictionary, row: Dictionary) -> void:
	var scene: Node = await Playback.instance(self, viewport, fixture, true, str(row.get("speed", "normal")))
	if scene == null:
		failures.append("Production run scene could not load"); return
	var completion: Dictionary = {"done": false}
	var board: Control = scene.get("board_view")
	var crop: Rect2i = Playback.crop_rect(board)
	var frames: int = 0
	var valid_recording: bool = true
	var background: Color = (scene.get_node("BoardUnderlay/BaseBackdrop") as ColorRect).color
	var file: FileAccess
	var temporary: String
	var proof_dir: String = OS.get_environment("TIP01_OUT")
	if proof_dir.is_empty(): proof_dir = "/private/tmp/labyrinth_codex/tip-02/record"
	var raw_path: String = proof_dir.path_join("raw").path_join(str(row["id"]) + ".tlp")
	temporary = raw_path + ".partial"
	if recording:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary.get_base_dir()))
		DirAccess.make_dir_recursive_absolute(proof_dir)
		file = FileAccess.open(temporary, FileAccess.WRITE)
		file.store_buffer("TLP1".to_ascii_buffer())
		for value: int in [282, 168, FPS, 0]: file.store_32(value)
	Playback.play(scene, result, completion)
	while frames < PLAYBACK_WATCHDOG_FRAMES and (not bool(completion["done"]) or frames < MIN_ACTION_FRAMES):
		if bool(board.presentation.get("board_backdrop_visible", true)):
			failures.append("%s frame %d lacks the production dark-background paint contract" % [row["id"], frames])
			valid_recording = false
			break
		if recording:
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			if image == null or image.get_size() != Playback.SIZE:
				failures.append("Recorder requires a real 1920x1080 renderer image"); valid_recording = false; break
			if not Rect2i(Vector2i.ZERO, Playback.SIZE).encloses(crop):
				failures.append("The fixed 4x3 crop must fit inside the SubViewport"); valid_recording = false; break
			if frames == 0 and not background_is_settled(image, crop, background):
				failures.append("%s frame zero still has an unsettled background; recording rejected" % row["id"])
				valid_recording = false
				break
			if frames in [0, 45, 89]:
				var proof: String = proof_dir.path_join("%s_%03d_1920x1080.png" % [row["id"], frames])
				image.save_png(proof)
				print(proof)
			var picture: Image = image.get_region(crop)
			picture.resize(282, 168, Image.INTERPOLATE_LANCZOS)
			picture.convert(Image.FORMAT_RGB8)
			bake_vignette(picture)
			file.store_buffer(picture.get_data())
		frames += 1
		await process_frame
	var completed: bool = bool(completion["done"])
	var limit: int = action_frame_limit(str(row.get("speed", "normal")))
	if completed and frames > limit:
		failures.append("%s needs %d frames (%.3f s) at %s speed; exceeds %.1f s. Recording rejected; no beats skipped." % [row["id"], frames, float(frames) / FPS, row.get("speed", "normal"), float(limit) / FPS])
	if not completed:
		if frames >= PLAYBACK_WATCHDOG_FRAMES: failures.append("%s real playback hit the 30-second debug watchdog; recording rejected" % row["id"])
		# Keep the scene alive until its real coroutines finish, outside the asset.
		while not bool(completion["done"]): await process_frame
	if recording:
		file.seek(16)
		file.store_32(frames)
		file.close()
		if completed and valid_recording and frames <= limit:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(raw_path))
			var provenance: Dictionary = {
				"fixture": "res://tools/tooltip_loops/fixture.gd", "id": row["id"],
				"actions": var_to_str(result["beats"]), "initial_state": var_to_str(fixture["state"]),
				"renderer": {"engine": Engine.get_version_info(), "method": RenderingServer.call("get_current_rendering_method") if RenderingServer.has_method("get_current_rendering_method") else ProjectSettings.get_setting("rendering/renderer/rendering_method"), "launch_arguments": OS.get_cmdline_args(), "driver": RenderingServer.get_video_adapter_name(), "viewport": [1920, 1080], "ui_scale": 1.0, "cel_look": preload("res://scripts/cel_look.gd").mode},
				"commit": OS.get_environment("TIP01_COMMIT"), "source_dirty": OS.get_environment("TIP01_DIRTY"),
				"source_sha256": _source_hashes(), "crop": var_to_str(crop), "fps": FPS,
				"background_settled_before_frame_zero": valid_recording, "action_frames": frames, "timing_within_brief": frames <= limit, "action_frame_limit": limit, "hold_seconds": 0.6, "crossfade_seconds": 0.25,
				"speed": row.get("speed", "normal"), "action_seconds": float(frames) / FPS, "format": "TLP1 lossless RGB8, streamed", "vignette_baked": true, "vignette": {"ink": Palette.INK_0.to_html(), "corner_alpha": 0.45, "curve": "squared radial distance"}, "asset_sha256": FileAccess.get_sha256(raw_path)}
			FileAccess.open(raw_path + ".json", FileAccess.WRITE).store_string(JSON.stringify(provenance, "\t"))
		else: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	print("TIP02 PLAYBACK %s: %s (%d frames at 30 fps; %.3f s; speed=%s)" % [row["id"], "PASS" if completed and valid_recording and frames <= limit else "FAIL", frames, float(frames) / FPS, row.get("speed", "normal")])
	scene.queue_free()
	await process_frame

static func vignette_alpha(uv: Vector2) -> float:
	# Exact curve of the removed CanvasItem shader, now evaluated offline.
	var radius: Vector2 = (uv - Vector2.ONE * 0.5) * 2.0
	return clampf(radius.length_squared() * 0.5, 0.0, 1.0) * 0.45

static func bake_vignette(picture: Image) -> void:
	var dimensions: Vector2i = picture.get_size()
	if _vignette_size != dimensions:
		_vignette_size = dimensions
		_vignette_weights.resize(dimensions.x * dimensions.y)
		for y: int in range(dimensions.y):
			for x: int in range(dimensions.x):
				_vignette_weights[y * dimensions.x + x] = vignette_alpha(Vector2((float(x) + 0.5) / dimensions.x, (float(y) + 0.5) / dimensions.y))
	var pixels: PackedByteArray = picture.get_data()
	var ink: Color = Palette.INK_0
	for pixel: int in range(_vignette_weights.size()):
		var amount: float = _vignette_weights[pixel]
		var offset: int = pixel * 3
		pixels[offset] = roundi(lerpf(float(pixels[offset]), float(ink.r8), amount))
		pixels[offset + 1] = roundi(lerpf(float(pixels[offset + 1]), float(ink.g8), amount))
		pixels[offset + 2] = roundi(lerpf(float(pixels[offset + 2]), float(ink.b8), amount))
	picture.set_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGB8, pixels)

static func background_is_settled(image: Image, crop: Rect2i, expected: Color) -> bool:
	# The patch is inset from all four corners; these are production board fill,
	# not units/floor. Reject the SubViewport's grey clear frame before saving it.
	for point: Vector2i in [crop.position, crop.position + Vector2i(crop.size.x - 1, 0), crop.position + Vector2i(0, crop.size.y - 1), crop.end - Vector2i.ONE]:
		var pixel: Color = image.get_pixelv(point)
		if absf(pixel.r - expected.r) > BACKGROUND_CHANNEL_TOLERANCE or absf(pixel.g - expected.g) > BACKGROUND_CHANNEL_TOLERANCE or absf(pixel.b - expected.b) > BACKGROUND_CHANNEL_TOLERANCE: return false
	return true

func _source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["data/tooltip_loops.json", "scripts/settings_store.gd", "tools/tooltip_loops/record.gd", "tools/tooltip_loops/fixture.gd", "tools/tooltip_loops/playback.gd", "tools/tooltip_loops/record_board.gd", "scripts/run_scene.gd", "scripts/combat_board_view.gd", "data/cards.json", "data/enemies.json"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes
