extends "res://tools/inspection_fixture.gd"

## Owner evidence: resume a real fixture through RunScene's normal boot path.
## Root-window readback; no render rerouting, camera/pose override or frozen clock.
## Forked from pt14-03; fix-18 accepts the director's physical-window clamp.
const CaptureSettings = preload("res://scripts/settings_store.gd")
const CaptureTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CaptureBiomes = preload("res://scripts/biome_library.gd")
const CapturePaths = preload("res://scripts/path_utils.gd")
const CaptureBadges = preload("res://scripts/intent_badges.gd")
const CaptureProtagonist = preload("res://scripts/protagonist_cutout/renderer.gd")
const CaptureActorPresentation = preload("res://scripts/actor_presentation.gd")
const FRAME_SIZE := Vector2i(1920, 1080)
const MIN_FRAME_SIZE := Vector2i(1600, 900)
const OUTPUT_ENV := "LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT"
const CROP_MARGIN_PX: float = 24.0
const ALIGNMENT_TOLERANCE_PX: float = 1.0
const SETTLE_TIMEOUT_SECONDS: float = 20.0
const STABLE_LAYOUT_FRAMES: int = 8
const CONTAINMENT_FOLLOWUP_FRAMES: int = 30
const RESIZE_DIAGNOSTIC_SIZE := Vector2i(1600, 900)
const FIXTURE_FLAGS: Array = ["enemy_types", "enemy_positions", "player_position", "biome", "seed", "hand", "enemy_intents", "relics", "equipped_items"]

var _capture_errors: Array[String]
var _capture_scene: Node
var _capture_board: Control
var _capture_label: String = ""
var _capture_output: String = "user://probes/real_fight"
var _validate_only: bool = false
var _crop_requests: Array[Dictionary]
var _manifest: Dictionary = {}
var _requested_actors: Dictionary = {}
var _capture_offsets: Array[int] = _int_array([0])
var _sample_offset: int = 0
var _continue_frame: int = 0
var _hud_bounds: Dictionary = {}
var _resize_diagnostic: bool = false
var _frame_stage: String = ""
var _frame_size: Vector2i = FRAME_SIZE

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_capture_run")

func _capture_run() -> void:
	_options = _parse_capture_args(OS.get_cmdline_user_args())
	if _failed:
		return
	if not OS.get_environment(OUTPUT_ENV).is_empty():
		_capture_output = OS.get_environment(OUTPUT_ENV)
	if not _prepare_output():
		await _capture_finish()
		return
	var filenames: Array[String]
	filenames.append(_capture_label + ".json")
	for offset: int in _capture_offsets:
		_sample_offset = offset
		filenames.append(_frame_filename())
		for crop: Dictionary in _crop_requests:
			filenames.append(_crop_filename(crop))
	_sample_offset = 0
	if _resize_diagnostic:
		for stage: String in ["resized", "restored"]:
			filenames.append(_capture_label + "_" + stage + ".png")
	for filename: String in filenames:
		_check(not FileAccess.file_exists(_capture_output.path_join(filename)), "Refusing to overwrite evidence: " + filename)
	if not _capture_errors.is_empty():
		await _capture_finish()
		return
	if DisplayServer.get_name() == "headless" and not _validate_only:
		_fail("Captures require windowed tools/visual_probe_runner.py; use --validate-only headlessly.")
		return
	if ParallelRuntime.current_namespace().is_empty():
		_fail("Run through the task runner or visual probe runner for isolated saves.")
		return
	var progression: Dictionary = _build_progression()
	for prompt: String in CaptureTutorial.prompt_ids():
		progression = CaptureTutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if _failed:
		return
	_check_positions(run.get("combat_state", {}))
	_requested_actors["player"] = {"pos": run["combat_state"]["player"]["pos"], "type": "player"}
	for enemy: Dictionary in run["combat_state"]["enemies"]:
		_requested_actors["enemy_%d" % int(enemy["id"])] = {"pos": enemy["pos"], "type": enemy["type"]}
	if not _capture_errors.is_empty():
		await _capture_finish()
		return
	# Persist before instantiation: the same resume metadata used by MainMenu.
	_check(ProgressionStore.save_data(progression), "Save isolated progression")
	_check(ProgressionStore.save_run_state(run), "Save isolated combat fixture")
	var settings: Dictionary = CaptureSettings.default_settings()
	settings["display_mode"] = CaptureSettings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	_check(CaptureSettings.save_settings(settings), "Save isolated 100% UI settings")
	CaptureSettings.apply_settings(settings, root, false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = FRAME_SIZE
	root.content_scale_factor = 1.0
	root.mode = Window.MODE_WINDOWED
	root.size = FRAME_SIZE
	# Set up the real window before MainMenu/Continue. Never resize a regular
	# fight after RunScene exists: rig-v2 uses its root viewport's transforms.
	# Continue owns the staged asset/UI preparation and reveal. Directly adding
	# RunScene skips that real launch path and can sample pre-layout actor pixels.
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	_continue_frame = Engine.get_process_frames()
	menu.call("_on_continue_button_pressed")
	var launch_deadline: int = Time.get_ticks_msec() + int(SETTLE_TIMEOUT_SECONDS * 1000.0)
	while current_scene == null or not current_scene.has_method("initial_presentation_is_ready"):
		await process_frame
		if Time.get_ticks_msec() >= launch_deadline:
			_check(false, "Timed out in the production Continue transition")
			await _retain_launch_failure()
			await _capture_finish()
			return
	_capture_scene = current_scene
	_capture_board = _capture_scene.get("board_view") as Control
	await _settle_capture()
	_prepare_manifest()
	await _sample_frames()
	if _resize_diagnostic: await _sample_resize_diagnostic()
	_write_manifest()
	await _capture_finish()

func _retain_launch_failure() -> void:
	# There may be no RunScene yet. Preserve the actual loading/failure canvas
	# rather than losing the only native evidence of a failed Continue launch.
	_prepare_manifest()
	if not _validate_only:
		await RenderingServer.frame_post_draw
		_save_frame(root.get_texture().get_image())
	_write_manifest()

func _sample_frames() -> void:
	var offsets: Array[int] = _int_array(_capture_offsets)
	if not offsets.has(CONTAINMENT_FOLLOWUP_FRAMES): offsets.append(CONTAINMENT_FOLLOWUP_FRAMES)
	offsets.sort()
	var samples: Array[Dictionary]
	var first_frame: int = -1
	for offset: int in offsets:
		while first_frame >= 0 and Engine.get_process_frames() < first_frame + offset:
			await process_frame
		# Sample after this frame's actual draw, not before node _process calls.
		# Headless validation records state only; it never claims rendered pixels.
		if not _validate_only: await RenderingServer.frame_post_draw
		if first_frame < 0: first_frame = Engine.get_process_frames()
		_sample_offset = offset
		samples.append(_collect_sample(_capture_offsets.has(offset)))
	_manifest["samples"] = samples
	_manifest["capture_offsets"] = _capture_offsets
	_manifest["containment_policy"] = "report_only" if _resize_diagnostic or DisplayServer.get_name() == "headless" else "required"
	_manifest["sync_observation"] = {"forced_sync": false, "note": "Normal scene processing remains enabled. Alignment fields are recorded; an identical MaquettePresentation.sync write cannot be observed without instrumentation."}
	_manifest["capture_source"] = "root_viewport"
	# Retain the first frame's convenient top-level fields, including its crops.
	for field: String in ["frame", "actors", "overlay_alignment", "hud_bounds", "crops", "intent_count"]:
		_manifest[field] = samples[0][field]

static func _int_array(values: Array) -> Array[int]:
	var result: Array[int]
	for value: int in values: result.append(value)
	return result

func _collect_sample(captured: bool) -> Dictionary:
	_frame_size = root.size
	_check(is_equal_approx(root.content_scale_factor, 1.0), "Capture uses 100% UI scale")
	_inspect_capture()
	_manifest["frame"] = {"filename": _frame_filename(), "sha256": "", "size": []}
	if captured and not _validate_only:
		# Keep failed frames, including wrong-size root-window readbacks.
		_save_frame(root.get_texture().get_image())
	return {"relative_frame": _sample_offset, "process_frame": Engine.get_process_frames(), "rendered_frame": Engine.get_frames_drawn(), "frames_after_continue": Engine.get_process_frames() - _continue_frame, "capture_requested": captured, "frame": _manifest["frame"].duplicate(true) if captured else {}, "actors": _manifest["actors"].duplicate(true), "overlay_alignment": _manifest["overlay_alignment"].duplicate(true), "hud_bounds": _hud_bounds.duplicate(true), "crops": _manifest["crops"].duplicate(true) if captured else [], "intent_count": _manifest["intent_count"], "expected_size": [_frame_size.x, _frame_size.y], "window_backing_size": [root.size.x, root.size.y], "window_logical_size": [root.size.x, root.size.y]}

func _sample_resize_diagnostic() -> void:
	# Separate real-window scenario. Observe normal processing after each resize;
	# never force a maquette sync, geometry refresh or actor correction.
	var stages: Array[Dictionary]
	var baseline: Dictionary = _manifest["samples"][0].duplicate(true)
	baseline["stage"] = "before_resize"
	stages.append(baseline)
	for stage: String in ["resized", "restored"]:
		_frame_stage = stage
		_frame_size = RESIZE_DIAGNOSTIC_SIZE if stage == "resized" else FRAME_SIZE
		root.size = _frame_size
		await _settle_capture()
		if not _validate_only: await RenderingServer.frame_post_draw
		_sample_offset = Engine.get_process_frames() - int(baseline["process_frame"])
		var sample: Dictionary = _collect_sample(true)
		sample["stage"] = stage
		stages.append(sample)
	_manifest["resize_diagnostic"] = {"report_only": true, "requested_sizes": [[FRAME_SIZE.x, FRAME_SIZE.y], [RESIZE_DIAGNOSTIC_SIZE.x, RESIZE_DIAGNOSTIC_SIZE.y], [FRAME_SIZE.x, FRAME_SIZE.y]], "stages": stages}
	print("REAL FIGHT RESIZE FOOTING (report only): " + JSON.stringify(stages.map(func(sample: Dictionary) -> Dictionary: return {"stage": sample["stage"], "frame": sample["frame"], "actors": sample["actors"]})))
	_frame_stage = ""
	_frame_size = root.size
	# Resize evidence must not replace the first-frame convenience fields.
	for field: String in ["frame", "actors", "overlay_alignment", "hud_bounds", "crops", "intent_count"]:
		_manifest[field] = baseline[field]

func _check_actor_footing(actor: Dictionary, native_renderer: bool) -> void:
	if native_renderer and not _resize_diagnostic:
		_check(bool(actor["floor_center_in_rest_rect"]), "Actor rest draw rect contains floor tile centre: " + str(actor["actor_key"]))

func _capture_canvas_transform(item: CanvasItem) -> Transform2D:
	# Canvas-items stretch maps logical canvas coordinates to root-texture pixels,
	# including the smaller window in the report-only resize diagnostic.
	return root.get_final_transform() * item.get_global_transform_with_canvas()

func _parse_capture_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {"seed": DEFAULT_SEED, "scenario": "combat"}
	var index: int = 0
	while index < args.size():
		var flag: String = args[index]
		if flag in ["--validate-only", "--resize-diagnostic"]:
			if flag == "--validate-only": _validate_only = true
			else: _resize_diagnostic = true
			index += 1
			continue
		if not flag.begins_with("--") or index + 1 >= args.size() or args[index + 1].begins_with("--"):
			_fail("Missing value or invalid option: " + flag)
			return parsed
		var value: String = args[index + 1]
		var key: String = flag.trim_prefix("--").replace("-", "_")
		if key == "label":
			_capture_label = value
		elif key == "capture_offsets":
			var offsets: Array[int]
			for entry: String in value.split(",", true):
				if not entry.is_valid_int() or int(entry) < 0 or offsets.has(int(entry)):
					_fail("Invalid --capture-offsets; use unique nonnegative frame offsets starting at 0.")
					return parsed
				offsets.append(int(entry))
			offsets.sort()
			if offsets.is_empty() or offsets[0] != 0:
				_fail("--capture-offsets must include the first settled frame (0).")
				return parsed
			_capture_offsets = offsets
		elif key == "crop":
			var pair: PackedStringArray = value.split(":")
			if pair.size() != 2 or not pair[1].is_valid_int() or int(pair[1]) <= 0:
				_fail("Invalid --crop; use actor_key[+hero]:positive_integer_scale.")
				return parsed
			var actor_keys: Array[String]
			for raw_key: String in pair[0].split("+", true):
				var actor_key: String = "player" if raw_key == "hero" else raw_key
				if not _safe_name(actor_key) or actor_keys.has(actor_key):
					_fail("Invalid --crop; actor keys must be unique, with hero aliasing player.")
					return parsed
				actor_keys.append(actor_key)
			var sorted_keys: Array[String] = _string_array(actor_keys)
			sorted_keys.sort()
			for previous: Dictionary in _crop_requests:
				if previous["sorted_keys"] == sorted_keys and previous["scale"] == int(pair[1]):
					_fail("Duplicate --crop: " + value)
					return parsed
			_crop_requests.append({"actor_key": actor_keys[0], "actor_keys": actor_keys, "crop_key": "+".join(actor_keys), "sorted_keys": sorted_keys, "scale": int(pair[1])})
		elif FIXTURE_FLAGS.has(key):
			if key == "seed" and not value.is_valid_int():
				_fail("--seed must be an integer")
				return parsed
			if key == "biome" and not CaptureBiomes.ids().has(value):
				_fail("Unknown biome: " + value)
				return parsed
			if key in ["player_position", "enemy_positions"]:
				for entry: String in value.split(","):
					var pair: PackedStringArray = entry.split(":")
					if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int():
						_fail("Invalid " + flag + "; use integer x:y coordinates")
						return parsed
			parsed[key] = int(value) if key == "seed" else value
		else:
			_fail("Unknown option: " + flag)
			return parsed
		index += 2
	if not _safe_name(_capture_label):
		_fail("--label is required; use letters, digits, underscores or hyphens")
	var intents: Array[String] = _string_list(str(parsed.get("enemy_intents", "")))
	if intents.size() > _string_list(str(parsed.get("enemy_types", ""))).size():
		_fail("--enemy-intents requires matching --enemy-types")
	return parsed

static func _safe_name(value: String) -> bool:
	if value.is_empty(): return false
	for character: String in value:
		if not (character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true

func _check_positions(state: Dictionary) -> void:
	var occupied: Dictionary = {}
	var actors: Array = [state.get("player", {})]
	actors.append_array(state.get("enemies", []))
	_check(actors.size() > 1, "Combat has requested enemies")
	for actor: Dictionary in actors:
		var pos: Vector2i = actor.get("pos", INVALID_COORD)
		_check(int(actor.get("hp", 0)) > 0, "Requested actor is alive")
		var footprint: Vector2i = actor.get("footprint", Vector2i.ONE)
		for y: int in range(footprint.y):
			for x: int in range(footprint.x):
				var tile: Vector2i = pos + Vector2i(x, y)
				_check(CapturePaths.is_passable(state.get("grid", []), tile), "Legal actor floor tile: " + str(tile))
				_check(not occupied.has(tile), "No overlapping actor tiles: " + str(tile))
				occupied[tile] = true

func _settle_capture() -> void:
	var deadline: int = Time.get_ticks_msec() + int(SETTLE_TIMEOUT_SECONDS * 1000.0)
	var stable: int = 0
	var previous: Array = []
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not _capture_scene.call("initial_presentation_is_ready"):
			continue
		var state: Dictionary = _capture_scene.get("_combat_state")
		var ready: bool = not state.is_empty() and _combat_engine.is_player_turn(state) and not bool(_capture_scene.get("_animation_lock")) and not bool(_capture_scene.get("_dialogue_active")) and int(_capture_scene.get("_animating_hand_card_index")) < 0 and _actors_are_idle()
		var snapshot: Array = []
		_layout_snapshot(_capture_scene, snapshot)
		if ready and snapshot == previous:
			stable += 1
		else:
			stable = 0
		previous = snapshot
		if stable >= STABLE_LAYOUT_FRAMES:
			return
	_check(false, "Timed out waiting for live player turn and settled production layout")

func _actors_are_idle() -> bool:
	var presentation: Dictionary = _capture_board.get("presentation")
	if not (presentation.get("death_animation_units", []) as Array).is_empty(): return false
	if not (presentation.get("floating_texts", []) as Array).is_empty(): return false
	if not (presentation.get("effect", {}) as Dictionary).is_empty() and float(presentation.get("effect_progress", 1.0)) < 1.0: return false
	for key: String in presentation:
		if not key.ends_with("_motion") or not presentation[key] is Dictionary: continue
		var motions: Dictionary = presentation[key]
		if motions.has("clip"):
			if str(motions["clip"]) not in ["idle", "rest"]: return false
		else:
			for motion: Variant in motions.values():
				if motion is Dictionary and str(motion.get("clip", "idle")) not in ["idle", "rest"]: return false
	return true

func _layout_snapshot(node: Node, snapshot: Array) -> void:
	if node == _capture_board: return
	if node is Control and node.is_visible_in_tree():
		snapshot.append(node.get_global_transform_with_canvas())
		snapshot.append(node.size)
	for child: Node in node.get_children():
		_layout_snapshot(child, snapshot)

func _inspect_capture() -> void:
	_hud_bounds = {"checked_elements": 0, "violations": []}
	_manifest.merge({"actors": [], "crops": [], "intent_count": 0, "overlay_alignment": {}}, true)
	var floor_layer: Control = _capture_board.get("_static_render_cache_layer") as Control
	var overlay: Control = _capture_board.get("_overlay_render_layer") as Control
	_check(is_instance_valid(floor_layer) and is_instance_valid(overlay), "Production floor and overlay layers exist")
	if not is_instance_valid(floor_layer) or not is_instance_valid(overlay): return
	# Floor pixels are baked through the cache viewport and composited back by
	# its Sprite2D. Include BOTH transforms, rather than assuming local identity.
	var floor_texture: CanvasItem = _capture_board.get("_static_render_cache_texture") as CanvasItem
	var floor_viewport: SubViewport = _capture_board.get("_static_render_cache_viewport") as SubViewport
	var floor_transform: Transform2D = _capture_canvas_transform(floor_texture) * floor_viewport.global_canvas_transform * floor_layer.get_global_transform()
	var overlay_transform: Transform2D = _capture_canvas_transform(overlay)
	var tiles: Array = _capture_board.get("_board_layout_cache_tiles")
	var max_error: float = 0.0
	var worst_tile := Vector2i(-1, -1)
	# Check the shared polygon source across the whole rendered board, covering
	# every active overlay kind without changing the danger stroke's inset.
	for tile: Vector2i in tiles:
		var error: float = overlay_alignment_error(floor_layer.call("_tile_polygon", tile), floor_transform, overlay.call("_tile_polygon", tile), overlay_transform)
		if error > max_error:
			max_error = error
			worst_tile = tile
	_check(max_error <= ALIGNMENT_TOLERANCE_PX, "Overlay/floor alignment at %s: %.3f px (maximum across %d tiles)" % [worst_tile, max_error, tiles.size()])
	var counts: Dictionary = overlay_counts_by_kind(overlay)
	var checked_overlays: int = 0
	for count: int in counts.values(): checked_overlays += count
	_manifest["overlay_alignment"] = {"checked_tiles": tiles.size(), "checked_overlays": checked_overlays, "counts_by_kind": counts, "max_error_px": max_error, "tolerance_px": ALIGNMENT_TOLERANCE_PX}
	_check(not tiles.is_empty() and checked_overlays > 0, "At least one drawn tile overlay was checked")
	_check(overlay.is_visible_in_tree(), "Overlay layer is visible")
	_check_hud_controls(_capture_scene)
	var visible: Dictionary = {}
	var actors: Array[Dictionary]
	var transform: Transform2D = _capture_canvas_transform(_capture_board)
	var status_layout: RefCounted = _capture_board.get("_status_plate_layout")
	for unit: Dictionary in _capture_board.call("_visible_units"):
		var key: String = str(unit.get("key", ""))
		visible[key] = unit
		var actor: Dictionary = _rendered_actor_record(unit)
		actors.append(actor)
		if _requested_actors.has(key): _check_actor_footing(actor, DisplayServer.get_name() != "headless")
		var group: Dictionary = status_layout.call("cached_group", key)
		for hud_rect: Rect2 in group.get("group_rects", []):
			_check_in_frame(transform * hud_rect, "Actor HUD " + key)
	var state: Dictionary = _capture_scene.get("_combat_state")
	var run_state: Dictionary = _capture_scene.get("_run_state")
	_manifest["resolved"] = {"hand": (state.get("deck", {}) as Dictionary).get("hand", []), "relics": run_state.get("relics", []), "equipped_items": run_state.get("equipped_items", [])}
	_check(visible.has("player"), "Hero exists on screen")
	for key: String in _requested_actors:
		_check(visible.has(key), "Requested actor exists on screen: " + key)
		if visible.has(key):
			_check(visible[key]["pos"] == _requested_actors[key]["pos"] and visible[key]["type"] == _requested_actors[key]["type"], "Requested actor tile and identity: " + key)
	var presentation: Dictionary = _capture_board.get("presentation")
	var badges: Array = (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", [])
	_manifest["intent_count"] = badges.size()
	for badge: Dictionary in CaptureBadges.layouts(_capture_board, badges):
		_check_in_frame(transform * (badge["rect"] as Rect2), "Intent badge " + str(badge["key"]))
		_check_in_frame(transform * (badge["order_rect"] as Rect2), "Intent order " + str(badge["key"]))
	_manifest["actors"] = actors
	var crops: Array[Dictionary]
	for request: Dictionary in _crop_requests:
		var key: String = request["actor_key"]
		var rest := Rect2()
		var members_exist: bool = true
		for member: String in request["actor_keys"]:
			_check(visible.has(member), "Crop actor exists: " + member)
			if not visible.has(member):
				members_exist = false
				continue
			var member_rect := Rect2()
			for actor: Dictionary in actors:
				if actor["actor_key"] == member:
					var values: Array = actor["rest_draw_rect"]
					member_rect = Rect2(values[0], values[1], values[2], values[3])
			rest = rest.merge(member_rect) if rest.has_area() else member_rect
		if not members_exist: continue
		var grown: Rect2 = rest.grow(CROP_MARGIN_PX)
		var box := Rect2i(Vector2i(grown.position.floor()), Vector2i(grown.end.ceil() - grown.position.floor()))
		var contained_centers: Array[String]
		for actor: Dictionary in actors:
			if box.has_point(Vector2i(actor["center"][0], actor["center"][1])):
				contained_centers.append(actor["actor_key"])
		crops.append({"actor_key": key, "actor_keys": request["actor_keys"], "crop_key": request["crop_key"], "scale": request["scale"], "box": [box.position.x, box.position.y, box.size.x, box.size.y], "in_frame": Rect2i(Vector2i.ZERO, _frame_size).encloses(box), "saved": false, "contained_actor_centers": contained_centers, "filename": _crop_filename(request), "source_frame_sha256": ""})
	_manifest["crops"] = crops

func _rendered_actor_record(unit: Dictionary) -> Dictionary:
	# Follow _draw_unit_bodies_for_tile's retained dictionary, then the precise
	# _draw_unit_body texture submission. Remove only transparent canvas padding.
	var key: String = unit["key"]
	var tile: Vector2i = _capture_board.call("_effective_unit_tile", unit)
	var layer: Control = (_capture_board.get("_scene_render_layers_by_tile") as Dictionary).get(tile, _capture_board)
	var draw_unit: Dictionary = unit
	var cached: bool = bool(layer.get("_submission_cache_valid"))
	if cached:
		for candidate: Dictionary in (layer.get("_units_by_draw_tile_cache") as Dictionary).get(tile, []):
			if str(candidate.get("key", "")) == key: draw_unit = candidate
	var center: Vector2 = layer.call("_unit_center", draw_unit)
	var texture_rect: Rect2 = layer.call("_unit_texture_draw_rect", draw_unit, center)
	var renderer: Node = layer.call("unit_cutout_renderer", draw_unit)
	var local_rest: Rect2 = texture_rect
	if is_instance_valid(renderer):
		var geometry: Dictionary = renderer.call("canvas_geometry") if renderer.has_method("canvas_geometry") else {"offset": CaptureProtagonist.SOURCE_OFFSET, "size": CaptureProtagonist.CANVAS_SIZE}
		var pixel_scale: Vector2 = texture_rect.size / Vector2(geometry["size"])
		local_rest = Rect2(texture_rect.position + (geometry["offset"] as Vector2) * pixel_scale, CaptureProtagonist.SOURCE_SIZE * pixel_scale)
	var presentation: Dictionary = layer.get("presentation")
	var origin: Vector2 = (presentation.get("unit_texture_origins", {}) as Dictionary).get(key, center)
	var registration: Vector2 = origin
	if CaptureActorPresentation.has_profile(str(draw_unit["type"])) and is_instance_valid(renderer):
		registration = local_rest.position + CaptureActorPresentation.floor_anchor(str(draw_unit["type"]), str(renderer.get("facing")), bool(renderer.get("mirrored"))) * local_rest.size / CaptureActorPresentation.SOURCE_SIZE
	var transform: Transform2D = _capture_canvas_transform(layer)
	var rect: Rect2 = transform * local_rest
	var screen_center: Vector2 = transform * registration
	var floor_center: Vector2 = _capture_canvas_transform(_capture_board) * (_capture_board.call("world_position_for_tile", draw_unit["pos"]) as Vector2)
	var offset: Vector2 = screen_center - floor_center
	return {"actor_key": key, "type": unit["type"], "tile": _tile_json(unit["pos"]), "center": [screen_center.x, screen_center.y], "floor_center": [floor_center.x, floor_center.y], "offset_from_floor": [offset.x, offset.y], "floor_center_in_rest_rect": rect.has_point(floor_center), "rest_draw_rect": _rect_json(rect), "texture_draw_rect": _rect_json(transform * texture_rect), "in_frame": Rect2(Vector2.ZERO, Vector2(_frame_size)).encloses(rect), "sampled_process_frame": Engine.get_process_frames(), "sampled_rendered_frame": Engine.get_frames_drawn(), "relative_frame": _sample_offset, "draw_layer": str(layer.get_path()), "uses_cached_draw_unit": cached, "presentation_world_position": _vector_json((presentation.get("unit_world_positions", {}) as Dictionary).get(key, center)), "presentation_texture_origin": _vector_json(origin), "facing": str(renderer.get("facing")) if is_instance_valid(renderer) else "", "mirrored": bool(renderer.get("mirrored")) if is_instance_valid(renderer) else false}

static func overlay_counts_by_kind(overlay: Control) -> Dictionary:
	# Counts are unique drawn tile footprints per kind, not fill/stroke calls.
	# These selectors mirror _draw_tile_overlays, using its retained-layer state.
	var counts: Dictionary = {"danger": 0, "move_reachable": 0, "targeting": 0, "hero": 0, "hover": 0, "controller_focus": 0, "exit": 0}
	if not overlay.is_visible_in_tree(): return counts
	var state: Dictionary = overlay.get("combat_state")
	var hero: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
	var selected: Vector2i = overlay.get("selected_tile")
	var threats: Dictionary = overlay.get("_rest_threat_tile_alphas")
	var move_lookup: Dictionary = overlay.get("_move_tiles_lookup_cache")
	var target_lookups: Array = []
	for field: String in ["_focus_tiles_lookup_cache", "_ability_tiles_lookup_cache", "_attack_tiles_lookup_cache", "_projected_attack_tiles_lookup_cache", "_summon_tiles_lookup_cache", "_projected_destination_tiles_lookup_cache", "_confirmation_target_tiles_lookup_cache"]:
		target_lookups.append(overlay.get(field))
	for tile: Vector2i in overlay.call("_rendered_tiles_in_draw_order"):
		if float(threats.get(tile, 0.0)) > 0.0 and overlay.call("_board_tile_is_visible_to_player", tile): counts["danger"] += 1
		if move_lookup.has(tile): counts["move_reachable"] += 1
		var targeting: bool = tile == selected and selected != hero
		for lookup: Variant in target_lookups:
			if lookup is Dictionary and lookup.has(tile): targeting = true
		if targeting: counts["targeting"] += 1
		if tile == selected and selected == hero: counts["hero"] += 1
		if tile == overlay.get("_hover_tile") and (overlay.get("_controller_focus_tile") as Vector2i).x < 0: counts["hover"] += 1
		if tile == overlay.get("_controller_focus_tile"): counts["controller_focus"] += 1
		if (overlay.get("exit_tiles") as Dictionary).has(tile): counts["exit"] += 1
	return counts

func _frame_stem() -> String:
	if not _frame_stage.is_empty(): return _capture_label + "_" + _frame_stage
	return _capture_label if _sample_offset == 0 else "%s_plus_%04d" % [_capture_label, _sample_offset]

func _frame_filename() -> String:
	return _frame_stem() + ".png"

func _crop_filename(crop: Dictionary) -> String:
	return "%s_%s_%dx.png" % [_frame_stem(), crop["crop_key"], int(crop["scale"])]

static func overlay_alignment_error(floor_polygon: PackedVector2Array, floor_transform: Transform2D, overlay_polygon: PackedVector2Array, overlay_transform: Transform2D) -> float:
	if floor_polygon.is_empty() or floor_polygon.size() != overlay_polygon.size(): return INF
	var error: float = 0.0
	for index: int in range(floor_polygon.size()):
		error = maxf(error, (floor_transform * floor_polygon[index]).distance_to(overlay_transform * overlay_polygon[index]))
	return error

func _check_hud_controls(node: Node) -> void:
	if node == _capture_board: return
	if node is Control and node.is_visible_in_tree() and node.modulate.a > 0.0 and node.self_modulate.a > 0.0:
		# Layout-only Controls can exceed the frame without painting anything.
		if node is Label or node is RichTextLabel or node is BaseButton or node is TextureRect or node is ColorRect or node is Panel or node is PanelContainer:
			var rect: Rect2 = _capture_canvas_transform(node) * Rect2(Vector2.ZERO, node.size)
			var parent: Node = node.get_parent()
			while parent != null and parent != root:
				if parent is Control and parent.clip_contents:
					rect = rect.intersection(_capture_canvas_transform(parent) * Rect2(Vector2.ZERO, parent.size))
				parent = parent.get_parent()
			_check_in_frame(rect, "HUD " + str(node.get_path()))
	for child: Node in node.get_children():
		_check_hud_controls(child)

func _check_in_frame(rect: Rect2, description: String) -> void:
	if rect.has_area():
		_hud_bounds["checked_elements"] = int(_hud_bounds.get("checked_elements", 0)) + 1
		var inside: bool = Rect2(Vector2.ZERO, Vector2(_frame_size)).encloses(rect)
		if not inside: (_hud_bounds["violations"] as Array).append({"element": description, "rect": _rect_json(rect)})
		_check(inside, description + " extends past frame: " + str(rect))

func _prepare_manifest() -> void:
	var git_output: Array = []
	var result: int = OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), git_output)
	_check(result == 0, "Read git HEAD")
	var diff_output: Array = []
	OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"]), diff_output)
	_manifest.merge({"schema_version": 4, "label": _capture_label, "options": _options.duplicate(true), "user_args": Array(OS.get_cmdline_user_args()), "git_head": "".join(git_output).strip_edges(), "git_dirty": not "".join(diff_output).strip_edges().is_empty(), "validate_only": _validate_only, "native_renderer": DisplayServer.get_name() != "headless", "size": [root.size.x, root.size.y], "requested_size": [FRAME_SIZE.x, FRAME_SIZE.y], "window_logical_size": [root.size.x, root.size.y], "frame_size_policy": "window_logical_minimum_1600x900", "ui_scale": 1.0, "window_backing_size": [root.size.x, root.size.y], "content_scale_factor": root.content_scale_factor, "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y], "content_scale_mode": root.content_scale_mode, "frame": {"filename": _capture_label + ".png", "sha256": "", "size": []}, "errors": _capture_errors}, true)

func _save_frame(frame: Image) -> void:
	if not _prepare_output(): return
	if frame == null or frame.is_empty():
		_check(false, "Renderer returned an empty frame")
		return
	var path: String = _capture_output.path_join(_manifest["frame"]["filename"])
	_check(frame.save_png(path) == OK, "Save full frame")
	_manifest["frame"]["size"] = [frame.get_width(), frame.get_height()]
	# Check the SAVED image, never the platform window's backing dimensions.
	var saved: Image = Image.load_from_file(path)
	_check(saved != null and valid_frame_size(saved.get_size(), _frame_size), "Saved frame equals the logical window at 100%% UI scale, at least %dx%d: expected %s" % [MIN_FRAME_SIZE.x, MIN_FRAME_SIZE.y, _frame_size])
	var hash: String = FileAccess.get_sha256(path)
	_manifest["frame"]["sha256"] = hash
	print(ProjectSettings.globalize_path(path))
	for crop: Dictionary in _manifest.get("crops", []):
		var values: Array = crop["box"]
		var box := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		if not Rect2i(Vector2i.ZERO, frame.get_size()).encloses(box): continue
		var image: Image = frame.get_region(box)
		image.resize(box.size.x * int(crop["scale"]), box.size.y * int(crop["scale"]), Image.INTERPOLATE_NEAREST)
		var crop_path: String = _capture_output.path_join(crop["filename"])
		crop["saved"] = image.save_png(crop_path) == OK
		_check(crop["saved"], "Save crop " + str(crop["actor_key"]))
		crop["source_frame_sha256"] = hash
		print(ProjectSettings.globalize_path(crop_path))

func _prepare_output() -> bool:
	var absolute: String = ProjectSettings.globalize_path(_capture_output).simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if absolute == project or absolute.begins_with(project + "/"):
		var ignored: int = OS.execute("git", PackedStringArray(["-C", project, "check-ignore", "--quiet", absolute.path_join("capture.png")]))
		_check(ignored == 0, "Capture output inside project must be gitignored")
		if ignored != 0: return false
	var created: bool = DirAccess.make_dir_recursive_absolute(absolute) == OK
	_check(created, "Create output directory")
	return created

func _write_manifest() -> void:
	if not _prepare_output(): return
	var path: String = _capture_output.path_join(_capture_label + ".json")
	if FileAccess.file_exists(path):
		_check(false, "Refusing to overwrite manifest: " + path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Open manifest")
	if file != null:
		file.store_string(JSON.stringify(_manifest, "\t"))
		file.close()
		print("REAL_FIGHT_CAPTURE_MANIFEST " + ProjectSettings.globalize_path(path))

static func valid_frame_size(saved: Vector2i, logical_window: Vector2i) -> bool:
	return saved == logical_window and saved.x >= MIN_FRAME_SIZE.x and saved.y >= MIN_FRAME_SIZE.y

static func _rect_json(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func _tile_json(tile: Vector2i) -> Array:
	return [tile.x, tile.y]

static func _vector_json(value: Vector2) -> Array:
	return [value.x, value.y]

func _check(condition: bool, message: String) -> void:
	if not condition: _capture_errors.append(message)

func _capture_finish() -> void:
	for error: String in _capture_errors: push_error(error)
	print("REAL FIGHT CAPTURE %s: %s" % ["VALIDATION" if _validate_only else "PROBE", "PASS" if _capture_errors.is_empty() else "FAIL"])
	if is_instance_valid(_capture_scene):
		_capture_scene.queue_free()
		await process_frame
	quit(0 if _capture_errors.is_empty() else 1)
