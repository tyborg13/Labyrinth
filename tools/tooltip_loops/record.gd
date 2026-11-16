extends SceneTree
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const PatchChecks = preload("res://tools/tooltip_loops/patch_checks.gd")
const FPS: int = 30
const MAX_LEAD_FRAMES: int = 11 # <=0.4 s including one renderer submission boundary.
static var _vignette_weights := PackedFloat32Array()
static var _vignette_size := Vector2i.ZERO
const NORMAL_MAX_ACTION_FRAMES: int = 126
const FAST_MAX_ACTION_FRAMES: int = 165
const BACKGROUND_CHANNEL_TOLERANCE: float = 2.0 / 255.0 # Debug readback tolerance.
const PLAYBACK_WATCHDOG_FRAMES: int = 900 # Debug runaway guard, not an authored duration.
var failures: Array[String]
var recording: bool = false
var design_pending: int = 0

static func selected_entries() -> Array:
	var ids: PackedStringArray = OS.get_environment("TOOLTIP_LOOP_IDS").split(",", false)
	return Registry.entries().filter(func(row: Dictionary) -> bool: return ids.is_empty() or ids.has(str(row["id"])))

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
	for row: Dictionary in selected_entries():
		var fixture: Dictionary = Fixture.build(str(row["id"]))
		var engine := Combat.new()
		var result: Dictionary = Fixture.plan(fixture, engine)
		failures.append_array(Fixture.validate(fixture, result))
		print("TIP01 SEMANTICS %s: %s" % [row["id"], "FAIL" if not Fixture.validate(fixture, result).is_empty() else "TODO_DESIGN" if not str(result.get("todo_design", "")).is_empty() else "PASS"])
		if not str(result.get("todo_design", "")).is_empty():
			design_pending += 1
			print(result["todo_design"])
			continue
		if not semantics_only and Fixture.validate(fixture, result).is_empty(): await _record(viewport, fixture, result, row)
	for failure: String in failures: push_error(failure)
	print("TIP01 %s RESULT: %s (%d failures)" % ["SEMANTICS" if semantics_only else "REHEARSAL" if rehearsal else "RECORD", "PASS" if failures.is_empty() else "FAIL", failures.size()])
	print("TIP03 DESIGN PENDING: %d loops (excluded from recording)" % design_pending)
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
	var audit := PatchChecks.new()
	audit.drawn_floor(board, fixture["state"], fixture["id"], "start")
	var frames: int = 0
	var terminal_frames: int = 0
	var last_picture: Image
	var source_first_motion_saved: bool = false
	var hero_crop_ok: bool = true
	var valid_recording: bool = true
	var background: Color = (scene.get_node("BoardUnderlay/BaseBackdrop") as ColorRect).color
	var file: FileAccess
	var temporary: String
	var proof_dir: String = OS.get_environment("TIP01_OUT")
	if proof_dir.is_empty(): proof_dir = "/private/tmp/labyrinth_codex/tip-05/record"
	var raw_path: String = proof_dir.path_join("raw").path_join(str(row["id"]) + ".tlp")
	temporary = raw_path + ".partial"
	if recording:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary.get_base_dir()))
		DirAccess.make_dir_recursive_absolute(proof_dir)
		file = FileAccess.open(temporary, FileAccess.WRITE)
		file.store_buffer("TLP1".to_ascii_buffer())
		for value: int in [282, 168, FPS, 0]: file.store_32(value)
	board.begin_capture(str(row["id"]))
	Playback.play(scene, result, completion)
	while frames < PLAYBACK_WATCHDOG_FRAMES:
		board.capture_frame = frames
		if bool(completion["done"]):
			terminal_frames += 1
			if terminal_frames > 1: break
		if bool(board.presentation.get("board_backdrop_visible", true)):
			failures.append("%s frame %d lacks the production dark-background paint contract" % [row["id"], frames])
			valid_recording = false
			break
		board.audit_frame()
		if not recording: audit.observe(board, crop, fixture["id"])
		if row["id"] == "marked_lob_slag":
			for unit: Dictionary in board._visible_units():
				if unit.get("role") != "player": continue
				var body: Rect2 = board.get_global_transform_with_canvas() * board._unit_draw_rect_for_center(unit, board._unit_center(unit))
				if not Rect2(crop).encloses(body): hero_crop_ok = false
		if recording:
			await RenderingServer.frame_post_draw
			# Frame-margin proof observes the pose actually submitted for this image.
			audit.observe(board, crop, fixture["id"])
			var image: Image = viewport.get_texture().get_image()
			if image == null or image.get_size() != Playback.SIZE:
				failures.append("Recorder requires a real 1920x1080 renderer image"); valid_recording = false; break
			if not Rect2i(Vector2i.ZERO, Playback.SIZE).encloses(crop):
				failures.append("The fixed 4x3 crop must fit inside the SubViewport"); valid_recording = false; break
			if frames == 0 and not background_is_settled(image, crop, background):
				failures.append("%s frame zero still has an unsettled background; recording rejected" % row["id"])
				valid_recording = false
				break
			last_picture = image
			if frames == 0 or (int(board.first_visible_frame) >= 0 and not source_first_motion_saved):
				var label: String = "source_start" if frames == 0 else "source_first_motion"
				if frames != 0: source_first_motion_saved = true
				var proof: String = proof_dir.path_join("%s_%s_1920x1080.png" % [row["id"], label])
				image.save_png(proof)
				print(proof)
			var picture: Image = image.get_region(crop)
			picture.resize(282, 168, Image.INTERPOLATE_LANCZOS)
			picture.convert(Image.FORMAT_RGB8)
			bake_vignette(picture)
			file.store_buffer(picture.get_data())
		frames += 1
		await process_frame
	if not hero_crop_ok:
		failures.append("Lob Slag hero body leaves the capture patch")
		valid_recording = false
	audit.drawn_floor(board, result["final"], fixture["id"], "end")
	var visibility: Dictionary = audit.finish(fixture["id"])
	audit.terrain.finish(board, fixture, result, crop)
	if recording and fixture["id"] == "rule_upheaval": await audit.terrain.native_final(scene, viewport, last_picture, crop, Fixture.Tip05.CRAWLER, proof_dir)
	audit.failures.append_array(audit.terrain.failures)
	visibility["terrain"] = audit.terrain.report()
	if fixture["id"] == "rule_upheaval":
		audit.failures.append_array(audit.upheaval.finish(board.seen_numbers, fixture, result))
		visibility["upheaval"] = audit.upheaval.report()
	failures.append_array(audit.failures)
	if not audit.failures.is_empty(): valid_recording = false
	print("TIP04 PATCH VISIBILITY %s: %s %s" % [fixture["id"], "PASS" if audit.failures.is_empty() else "FAIL", JSON.stringify(visibility)])
	var source_frames: int = frames
	var first: int = maxi(0, int(board.first_visible_frame) - MAX_LEAD_FRAMES)
	var last: int = mini(frames - 1, int(board.last_visible_frame) + 1)
	if int(board.first_visible_frame) < 0:
		failures.append("No visible action observed: " + str(row["id"]))
		valid_recording = false
	frames = maxi(1, last - first + 1)
	var timing: Dictionary = {"id": row["id"], "source_frames": source_frames, "recording_frames": frames, "action_seconds": float(frames) / FPS, "first_visible_frame": int(board.first_visible_frame), "last_visible_frame": int(board.last_visible_frame), "trim_start_frames": first, "trim_end_frames": source_frames - last - 1, "first_motion_seconds": float(int(board.first_visible_frame) - first) / FPS, "tail_seconds": float(last - int(board.last_visible_frame)) / FPS, "seen_numbers": board.seen_numbers.keys(), "hero_crop_ok": hero_crop_ok, "patch_visibility": visibility}
	if row["id"] == "rule_upheaval" and (float(timing["tail_seconds"]) > 0.2 or float(timing["action_seconds"]) > 4.5):
		failures.append("Upheaval must end <=0.2 s after settling, with action <=4.5 s")
		valid_recording = false
	print("TIP03 TIMING " + JSON.stringify(timing))
	DirAccess.make_dir_recursive_absolute(proof_dir)
	FileAccess.open(proof_dir.path_join(str(row["id"]) + "_timing.json"), FileAccess.WRITE).store_string(JSON.stringify(timing, "\t"))
	if row["id"] == "charge_storm_capacitor":
		if not board.seen_numbers.has("player:-6") or not board.seen_numbers.has("enemy_2:-5"):
			failures.append("Arc Burst must present both production loss numbers")
			valid_recording = false
	if row["id"] == "rule_frostbite" and not board.seen_numbers.has("enemy_1:-%d" % (int(fixture["state"]["enemies"][0]["hp"]) - int(result["final"]["enemies"][0]["hp"]))):
		failures.append("Frostbite must show the production Ice hit number")
		valid_recording = false
	if row["id"] == "freeze_status":
		if not board.seen_numbers.has("enemy_1:-7") or not board.seen_numbers.has("enemy_1:-18"):
			failures.append("Freeze must show Frozen Bite and full tripled Quick Stab numbers")
			valid_recording = false
	var completed: bool = bool(completion["done"])
	var limit: int = mini(action_frame_limit(str(row.get("speed", "normal"))), int(row.get("max_recording_frames", FAST_MAX_ACTION_FRAMES)))
	if completed and frames > limit:
		failures.append("%s needs %d frames (%.3f s) at %s speed; exceeds %.1f s. Recording rejected; no beats skipped." % [row["id"], frames, float(frames) / FPS, row.get("speed", "normal"), float(limit) / FPS])
	if not completed:
		if source_frames >= PLAYBACK_WATCHDOG_FRAMES: failures.append("%s real playback hit the 30-second debug watchdog; recording rejected" % row["id"])
		# Keep the scene alive until its real coroutines finish, outside the asset.
		while not bool(completion["done"]): await process_frame
	if recording:
		file.seek(16)
		file.store_32(frames)
		file.close()
		if completed and valid_recording and not trim_raw(temporary, first, frames):
			failures.append("Could not retain the contiguous recording window: " + str(row["id"]))
			valid_recording = false
		if last_picture != null:
			var proof: String = proof_dir.path_join(str(row["id"]) + "_source_end_1920x1080.png")
			last_picture.save_png(proof)
			print(proof)
		if completed and valid_recording and frames <= limit:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(raw_path))
			var provenance: Dictionary = {
				"fixture": "res://tools/tooltip_loops/fixture.gd", "id": row["id"],
				"actions": var_to_str(result["beats"]), "initial_state": var_to_str(fixture["state"]),
				"renderer": {"engine": Engine.get_version_info(), "method": RenderingServer.call("get_current_rendering_method") if RenderingServer.has_method("get_current_rendering_method") else ProjectSettings.get_setting("rendering/renderer/rendering_method"), "launch_arguments": OS.get_cmdline_args(), "driver": RenderingServer.get_video_adapter_name(), "viewport": [1920, 1080], "ui_scale": 1.0, "cel_look": preload("res://scripts/cel_look.gd").mode},
				"commit": OS.get_environment("TIP01_COMMIT"), "source_dirty": OS.get_environment("TIP01_DIRTY"),
				"source_sha256": _source_hashes(), "crop": var_to_str(crop), "fps": FPS,
				"background_settled_before_frame_zero": valid_recording, "motion_timing": timing, "action_frames": frames, "timing_within_brief": frames <= limit, "action_frame_limit": limit, "hold_seconds": 0.6, "crossfade_seconds": 0.25,
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
	for path: String in ["data/tooltip_loops.json", "scripts/settings_store.gd", "tools/tooltip_loops/record.gd", "tools/tooltip_loops/fixture.gd", "tools/tooltip_loops/tip03_fixture.gd", "tools/tooltip_loops/tip04_fixture.gd", "tools/tooltip_loops/tip05_fixture.gd", "tools/tooltip_loops/tip05_checks.gd", "tools/tooltip_loops/terrain_checks.gd", "scripts/battlefield_rule_hud.gd", "scripts/displacement_throw.gd", "scripts/battlefield_rules/upheaval.gd", "scripts/snare_pressure_rules.gd", "scripts/snare_pressure_view.gd", "scripts/enemy_mechanics/burrow.gd", "data/special_encounters.json", "tools/tooltip_loops/patch_checks.gd", "tools/tooltip_loops/sprite_margin.gd", "scripts/battlefield_rules/gust.gd", "scripts/battlefield_rules/frostbite.gd", "scripts/battlefield_rules/wildfire.gd", "scripts/battlefield_rules/shadowstep.gd", "scripts/battlefield_rule_view.gd", "scripts/enemy_mechanics/stalker.gd", "scripts/enemy_mechanics/stalker_view.gd", "tools/tooltip_loops/playback.gd", "tools/tooltip_loops/record_board.gd", "scripts/run_scene.gd", "scripts/combat_board_view.gd", "data/cards.json", "data/enemies.json", "data/battlefield_rules.json", "scripts/battlefield_rules/dispatcher.gd", "scripts/battlefield_rules/lightning_storm.gd", "scripts/board_surface_rules.gd", "scripts/enemy_mechanics/chain_hit_feedback.gd", "assets/units/storm_capacitor_cutout/actions.gd", "scripts/enemy_mechanics/capacitor_view.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

static func trim_raw(path: String, first: int, count: int) -> bool:
	# Contiguous leading/trailing idle only. No action frames are resampled.
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	const HEADER_BYTES: int = 20
	const STRIDE: int = 282 * 168 * 3
	const COPY_BYTES: int = 1024 * 1024 # Debug/offline IO chunk only.
	if file == null: return false
	if first < 0 or count <= 0 or HEADER_BYTES + (first + count) * STRIDE > file.get_length():
		file.close()
		return false
	var copied: int = 0
	while copied < count * STRIDE:
		file.seek(HEADER_BYTES + first * STRIDE + copied)
		var chunk: PackedByteArray = file.get_buffer(mini(COPY_BYTES, count * STRIDE - copied))
		if chunk.is_empty():
			file.close()
			return false
		file.seek(HEADER_BYTES + copied)
		file.store_buffer(chunk)
		copied += chunk.size()
	file.resize(HEADER_BYTES + count * STRIDE)
	file.seek(16)
	file.store_32(count)
	file.close()
	return true
