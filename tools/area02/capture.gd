extends "res://tools/atk13/capture.gd"
## Native proof from unmodified natural fight witnesses.
const Cantor = preload("res://tools/area02/cantor_witness.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const RuleView = preload("res://scripts/battlefield_rule_view.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const SurfaceVisibility = preload("res://scripts/board_surface_visibility.gd")
const ThreatPaint = preload("res://scripts/board_layer_slices.gd")
const PROOF_NATIVE_FRAME_LIMIT: int = 14400
const PROOF_HEADLESS_TIME_SCALE: float = 16.0
const PROOF_HEADLESS_FRAME_LIMIT: int = 1800
# Cap-06's exposed lower-left edge has no pillar or actor over the outline.
const CANTOR_FRINGE_TILE := Vector2i(5, 5)
const CANTOR_FRINGE_EDGE: int = 2
const FRINGE_SAMPLE_COUNT: int = 9
const FRINGE_REQUIRED_RED_SAMPLES: int = 7
const FRINGE_PIXEL_RADIUS: int = 2
const FRINGE_RED_MARGIN: float = 0.15
var playback_done: bool = false
var hero_frames: Dictionary = {}
var cantor_pass_tiles: Dictionary = {}
var cantor_fringe_red_samples: int = 0

func _run() -> void:
	var folder: String = _arg("--save-dir")
	var out: String = _arg("--out")
	var scenario: String = _arg("--case", "cantor")
	if not FileAccess.file_exists(folder.path_join("run_state.txt")):
		push_error("Missing native witness: " + folder)
		quit(1)
		return
	var run: Dictionary = str_to_var(FileAccess.get_file_as_string(folder.path_join("run_state.txt")))
	if scenario == "cantor" and not Cantor.real_health(run.get("combat_state", {}).get("player", {})):
		push_error("CAP-06: Cantor proof requires a living hero from the 24-Health ladder preset")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://area02-proof-profile.json")
	Store.set_run_storage_path("user://area02-proof-run.save")
	Settings.set_storage_path("user://area02-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	native_scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(native_scene)
	for frame: int in range(PROOF_BOOT_FRAMES): await process_frame
	native_scene.set("_progression", run["progression"].duplicate(true))
	native_scene.call("_load_run_state", run)
	native_scene.call("_close_dialogue")
	native_scene.call("_close_large_map")
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	var before: Dictionary = (native_scene.get("_combat_state") as Dictionary).duplicate(true)
	var engine: RefCounted = native_scene.get("_combat_engine")
	var board: Control = native_scene.get("board_view")
	var pass_red: Dictionary = Rules.forecast(engine, before, SurfaceVisibility.projection_input(board.get("presentation")))
	if scenario == "cantor":
		var visible: Array[Vector2i]
		for tile: Vector2i in Surface.tiles(before, "electrified"):
			if Surface.can_place(before, tile) and board.call("_board_tile_is_visible_to_player", tile): visible.append(tile)
		_check(not visible.is_empty() and _shown_rule_red(board.get("presentation")) == visible,
			"Pass red exactly matches the drawable Electrified field")
		_check(pass_red["tiles"]["strike"] == visible and board.get("_rule_threat_tiles").keys() == visible,
			"Pass strike projection and topmost ground outlines match the drawable field")
		await _cantor_picture(board, out, "pass")
		cantor_pass_tiles = _cantor_pass_tiles(board, engine)
	else:
		await _picture(out.get_basename() + "_pass.png")
	var result: Dictionary = Cantor.resolve_pass(engine, before)
	var steps: Array[Dictionary] = result["steps"]
	var beat_steps: Array[Dictionary]
	for step: Dictionary in steps:
		if bool(step.get("battlefield_rule_step", false)): beat_steps.append(step)
	_check(not beat_steps.is_empty(), "production phase contains a rule beat")
	var laid: Array[Vector2i]
	var strike_tiles: Array[Vector2i]
	var new_ground_sources: Dictionary = {}
	if scenario == "cantor":
		var peal: Dictionary = Cantor.peal(engine, before, steps)
		_check(not peal.is_empty(), "Peal strikes the entire live Electrified field, including new Bell Tender tiles, and the hero survives")
		laid.assign(peal.get("laid", []))
		strike_tiles.assign(peal.get("strike", []))
		new_ground_sources = peal.get("new_ground_sources", {})
		for tile: Vector2i in strike_tiles:
			if not cantor_pass_tiles.has(str(tile)):
				cantor_pass_tiles[str(tile)] = _cantor_pass_tile(board, engine, tile, _shown_rule_red(board.get("presentation")))
	var headless: bool = DisplayServer.get_name() == "headless"
	var fast_headless: bool = headless and scenario != "cantor"
	# At accelerated playback the contact frame can pass between process samples.
	if fast_headless: Engine.time_scale = PROOF_HEADLESS_TIME_SCALE
	native_scene.set("_animation_lock", true)
	_play(before.duplicate(true), steps, result["state"])
	var tender_seen: bool = false
	var strike_seen: bool = false
	var spread_seen: bool = false
	var rise_seen: bool = false
	var gust_seen: bool = false
	for frame: int in range(PROOF_HEADLESS_FRAME_LIMIT if fast_headless else PROOF_NATIVE_FRAME_LIMIT):
		var displayed: Dictionary = board.get("combat_state")
		var shown: Dictionary = board.get("presentation")
		var effect: Dictionary = shown.get("effect", {})
		if scenario == "cantor":
			if not tender_seen and not shown.has("battlefield_rule_caption"):
				var visible_laid: Array[Vector2i] = Cantor.new_tender_tiles(engine, before, displayed)
				visible_laid.assign(visible_laid.filter(func(tile: Vector2i) -> bool: return laid.has(tile)))
				if not visible_laid.is_empty():
					var red: Array = _shown_rule_red(shown)
					_check(visible_laid.all(func(tile: Vector2i) -> bool: return red.has(tile)), "Bell Tender tiles turn red on their first visible board update")
					tender_seen = true
					await _cantor_picture(board, out, "tender")
			if tender_seen and not strike_seen and bool(shown.get("rule_contact", false)) and _strike_peak(effect, float(shown.get("effect_progress", 0.0))):
				strike_seen = true
				var drawn: Array = effect.get("tiles", [])
				_check(drawn.size() == strike_tiles.size() and strike_tiles.all(func(tile: Vector2i) -> bool: return drawn.has(tile)), "strike VFX includes the entire live field, including Bell Tender tiles")
				await _cantor_picture(board, out, "strike")
		elif scenario == "upheaval":
			if not rise_seen and (displayed.get("terrain", []) as Array).size() > (before.get("terrain", []) as Array).size():
				rise_seen = true
				await _picture(out.get_basename() + "_rise.png")
		elif scenario == "gust":
			if str(effect.get("en02_mechanic", "")) == "wind_push" and not gust_seen and (headless or float(shown.get("effect_progress", 0.0)) >= PROOF_CONTACT_SAMPLE_PROGRESS):
				gust_seen = true
				_check(beat_steps.any(func(beat: Dictionary) -> bool: return beat.get("action_direction") == effect.get("action_direction")), "Gust playback uses the resolved direction")
				await _picture(out.get_basename() + "_blow.png")
		else:
			if not spread_seen and Surface.tiles(displayed, "fire") != Surface.tiles(before, "fire") and shown.has("battlefield_rule_caption"):
				spread_seen = true
				await _picture(out.get_basename() + "_spread.png")
		if playback_done: break
		await process_frame
	_check(playback_done, "production playback completes")
	_check({"cantor": tender_seen and strike_seen, "wildfire": spread_seen, "upheaval": rise_seen, "gust": gust_seen}.get(scenario, false), "required native timeline states observed")
	var report: Dictionary = {"pass_red": pass_red, "strike_tiles": strike_tiles, "new_tender_ground": laid, "tender_seen": tender_seen, "strike_seen": strike_seen, "spread_seen": spread_seen, "rise_seen": rise_seen, "gust_seen": gust_seen}
	if scenario == "cantor":
		report["hero_frames"] = hero_frames
		report["pass_tiles"] = cantor_pass_tiles
		report["new_ground_sources"] = new_ground_sources
		if not headless and _arg("--fringe-witness") == "true": report["fringe_red_samples"] = cantor_fringe_red_samples
	_finish_capture(out, report, "area02-" + scenario)

func _cantor_pass_tiles(board: Control, engine: RefCounted) -> Dictionary:
	var red: Array = _shown_rule_red(board.get("presentation"))
	var result: Dictionary = {}
	for tile: Vector2i in Surface.tiles(board.get("combat_state"), "electrified"):
		result[str(tile)] = _cantor_pass_tile(board, engine, tile, red)
	return result

func _cantor_pass_tile(board: Control, engine: RefCounted, tile: Vector2i, red: Array) -> Dictionary:
	var state: Dictionary = board.get("combat_state")
	var layers: Dictionary = board.get("_scene_render_layers_by_tile")
	var layer: Control = layers.get(tile)
	var electric: Node2D = layer.find_child("SurfaceElectric", true, false) if layer != null else null
	var center: Vector2 = board.get_global_transform_with_canvas() * board.call("_tile_center", tile)
	return {
		"electrified": Surface.has_surface(state, tile, "electrified"),
		"in_engine_sight": engine.is_tile_visible_to_player(state, tile),
		"passes_board_visibility": board.call("_board_tile_is_visible_to_player", tile),
		"surface_child_visible": electric != null and electric.is_visible_in_tree() if DisplayServer.get_name() != "headless" else null,
		"rule_red": red.has(tile),
		"threat_paint": not ThreatPaint.threat_paint(board, tile, {}).is_empty(),
		"screen_center": [roundi(center.x), roundi(center.y)],
	}

func _cantor_picture(board: Control, out: String, frame: String) -> void:
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless: await RenderingServer.frame_post_draw
	var state: Dictionary = board.get("combat_state")
	var player: Dictionary = state.get("player", {})
	var tile: Vector2i = player.get("pos", Vector2i(-1, -1))
	var units: Array[Dictionary] = board.call("_visible_units")
	var tile_center: Vector2 = board.call("_tile_center", tile)
	var screen_point: Vector2 = board.get_global_transform_with_canvas() * tile_center
	var visible: bool = board.is_visible_in_tree() and board.get_viewport_rect().has_point(screen_point) \
		and units.any(func(unit: Dictionary) -> bool: return unit.get("key") == "player" and unit.get("pos") == tile)
	var real_health: bool = Cantor.real_health(player)
	hero_frames[frame] = {"hp": player.get("hp"), "max_hp": player.get("max_hp"), "tile": tile, "visible": visible}
	_check(real_health, "%s hero is alive at or below the real 24 Health maximum" % frame)
	_check(visible, "%s hero is in the visible board roster and inside the viewport" % frame)
	if not real_health or not visible or headless: return
	var path: String = "%s_%s.png" % [out.get_basename(), frame]
	var picture: Image = canvas.get_texture().get_image()
	if frame == "pass" and _arg("--fringe-witness") == "true":
		cantor_fringe_red_samples = _fringe_red_samples(board, picture)
		_check(cantor_fringe_red_samples >= FRINGE_REQUIRED_RED_SAMPLES, "Cantor Pass has a red outline on the exposed Electrified fringe")
	var saved: bool = picture.get_size() == SIZE and picture.save_png(path) == OK
	_check(saved, "native 1920x1080 PNG " + path)
	if saved: print(path)

func _fringe_red_samples(board: Control, picture: Image) -> int:
	var paint: Dictionary = ThreatPaint.threat_paint(board, CANTOR_FRINGE_TILE, {})
	if paint.is_empty(): return 0
	var inner: PackedVector2Array = paint["inner"]
	var screen: Transform2D = board.get_global_transform_with_canvas()
	var from: Vector2 = screen * inner[CANTOR_FRINGE_EDGE]
	var to: Vector2 = screen * inner[CANTOR_FRINGE_EDGE + 1]
	var hits: int = 0
	for index: int in range(1, FRINGE_SAMPLE_COUNT + 1):
		var point := Vector2i(from.lerp(to, float(index) / float(FRINGE_SAMPLE_COUNT + 1)).round())
		if _is_red_near(picture, point): hits += 1
	return hits

func _is_red_near(picture: Image, point: Vector2i) -> bool:
	var bounds := Rect2i(Vector2i.ZERO, picture.get_size())
	for y: int in range(-FRINGE_PIXEL_RADIUS, FRINGE_PIXEL_RADIUS + 1):
		for x: int in range(-FRINGE_PIXEL_RADIUS, FRINGE_PIXEL_RADIUS + 1):
			var sample: Vector2i = point + Vector2i(x, y)
			if not bounds.has_point(sample): continue
			var pixel: Color = picture.get_pixelv(sample)
			if pixel.r - maxf(pixel.g, pixel.b) >= FRINGE_RED_MARGIN: return true
	return false

func _shown_rule_red(presentation: Dictionary) -> Array:
	for threat: Dictionary in presentation.get("threats_at_rest", {}).get("threats", []):
		if str(threat["key"]) == RuleView.THREAT_KEY: return threat["tiles"]
	return []

func _play(state: Dictionary, steps: Array[Dictionary], after: Dictionary) -> void:
	await native_scene.call("_animate_enemy_phase_steps", state, steps, after)
	playback_done = true

func _picture(out: String) -> void:
	await super._picture(out)
	# The validated visual runner discovers only paths emitted by the probe.
	if DisplayServer.get_name() != "headless": print(out)
