extends "res://tools/fx12/native_capture.gd"
## Shadow contact stills on the production board and HUD.

const Clock = preload("res://scripts/presentation_clock.gd")
const FixedPacing = preload("res://tools/fx15/native_capture.gd").FixedPacing
const CRAWLER_TILE := Hero + AimDirection * 2
const FLOOR_TILE := Hero + Vector2i(1, 1)
const FAMILY_LEFT := Hero + Vector2i.LEFT
const FAMILY_RIGHT := Hero + Vector2i.RIGHT
const DARK_STAGE: String = "heart"
const BEFORE_ENEMY: String = "hollow_mimic"
const BEFORE_INTENT: String = "shade_bolt"
const BEFORE_LEAD_TICKS: int = 1
const SAMPLE_MS: Array[int] = [0, 33, 100, 200, 300, 400]
const SAMPLE_TICKS: Array[int] = [0, 2, 6, 12, 18, 24]
const EVIDENCE_MS: int = 100
const ZOOM_FACTOR: int = 2
const ZOOM_FILES: Dictionary = {
	"hero-hit": "hero-hit-100ms-2x.png",
	"family": "family-100ms-2x.png",
}
const TAKES: Dictionary = {
	"hero-hit": [Hero, "hit", false],
	"crawler-hit": [CRAWLER_TILE, "hit", false],
	"empty-floor": [FLOOR_TILE, "floor", false],
	"dark-hero-hit": [Hero, "hit", true],
	"dark-crawler-hit": [CRAWLER_TILE, "hit", true],
	"dark-empty-floor": [FLOOR_TILE, "floor", true],
	"family": [Hero, "hit", false],
	"before": [Hero, "", false],
}

var _post_process: PostProcess

class PostProcess extends Node:
	signal presented
	func _process(_delta: float) -> void: presented.emit()

func _take() -> void:
	var id: String = _arg("--case")
	_output = _arg("--out")
	_plan = OS.get_cmdline_user_args().has("--plan")
	if not TAKES.has(id) or _output.is_empty() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx21/stills.sh with a known take.")
		return
	if _plan:
		if DisplayServer.get_name() != "headless":
			_fail("The plan uses the headless runner.")
			return
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		_post_process = PostProcess.new()
		_post_process.process_priority = 1000
		root.add_child(_post_process)
	elif DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS:
		_fail("Native stills require the visual probe runner and the 60 fps movie clock.")
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	if not Settings.save_settings(settings):
		_fail("Could not save proof settings.")
		return
	var fixture: Dictionary = _shadow_fixture(id)
	if _failed: return
	if not await _start(fixture):
		_fail("RunScene did not resume with the 1920x1080 combat HUD at 100% UI scale.")
		return
	if _plan and id == "before":
		# Headless has no MovieWriter. Keep the real enemy playback on its fixed-tick equivalent.
		_run._combat_pacing.free()
		_run._combat_pacing = FixedPacing.new()
		_run._combat_pacing.install(_run)
	var report: Dictionary = await _observe_stills(id)
	if _failed: return
	var path: String = _output.path_join("take.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write " + path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("FX-21 %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(report)])
	print(path)
	_viewport.queue_free()
	await process_frame
	quit(0)

func _shadow_fixture(id: String) -> Dictionary:
	var dark: bool = TAKES[id][2]
	var before: bool = id == "before"
	var family: bool = id == "family"
	_options = {
		"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER, "draw": FILLER_DRAW,
		"player_hp": HERO_HP, "player_max_hp": HERO_HP, "player_position": _coord(Hero),
		"enemy_types": BEFORE_ENEMY if before else "crawler,crawler" if family else "crawler",
		"enemy_intents": BEFORE_INTENT if before else "",
		"enemy_positions": "%s,%s" % [_coord(FAMILY_LEFT), _coord(FAMILY_RIGHT)] if family else _coord(CRAWLER_TILE),
		"umbra_stage": DARK_STAGE if dark else "clear",
	}
	var progression: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if _failed: return {}
	if run.is_empty():
		_fail("Could not build a proof fight.")
		return {}
	var state: Dictionary = run["combat_state"]
	var proof_tiles: Array[Vector2i]
	proof_tiles.assign([Hero, FAMILY_LEFT, FAMILY_RIGHT] if family else [Hero, CRAWLER_TILE, FLOOR_TILE])
	for tile: Vector2i in proof_tiles:
		if not Paths.is_passable(state["grid"], tile):
			_fail("Proof tile is outside playable floor: " + _coord(tile))
			return {}
	# Keep the comparison tiles free of breakable props.
	state = _clear_fixture_occupant_tiles(state, proof_tiles)
	if before:
		var scheduled: Dictionary = _combat_engine.prepare_player_activation_end(state)
		var next_hero: int = -1
		for actor: Dictionary in scheduled["turn_queue"]:
			if actor["kind"] == "player": next_hero = int(actor["time"])
		if next_hero < BEFORE_LEAD_TICKS:
			_fail("Missing next hero turn for the single-hit comparison.")
			return {}
		for actor: Dictionary in state["turn_queue"]:
			actor["time"] = next_hero - BEFORE_LEAD_TICKS
	run["combat_state"] = state
	return {"run": run, "profile": progression}

func _observe_stills(id: String) -> Dictionary:
	var board: Control = _run.board_view
	var layer: Fx = board._tile_bursts
	var tile: Vector2i = TAKES[id][0]
	var dark: bool = TAKES[id][2]
	var before: bool = id == "before"
	if layer == null or _viewport.size != CanvasSize:
		_fail("Missing tile-burst player or exact-size SubViewport.")
		return {}
	if not board._board_tile_is_visible_to_player(tile) or (dark and not _is_umbra_edge_take(board, tile)):
		_fail("Expected a visible contact tile at the requested Umbra setting: " + _coord(tile))
		return {}
	var crop: Rect2i = _tile_crop(board, tile)
	var specs: Array[Dictionary]
	if not before:
		if id == "family":
			specs.assign([_spec("shadow", FAMILY_LEFT, true), _spec("ice", Hero, true), _spec("fire", FAMILY_RIGHT, true)])
		else:
			specs.append(_spec("shadow", tile, TAKES[id][1] == "hit"))
		for spec: Dictionary in specs:
			var spec_center: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(spec["center"])
			if not crop.has_point(Vector2i(spec_center.round())) or not _check_occupancy(board, spec):
				_fail("Burst tile is outside the crop or has the wrong occupant: " + str(spec))
				return {}

	var contact: int = -1
	var snap: int = 0
	var crops: Array[String]
	var strip: Image
	if not _plan:
		strip = Image.create_empty(CropSize.x * SAMPLE_TICKS.size(), CropSize.y, false, Image.FORMAT_RGB8)
	var hero_hp_before: int = int(_run._combat_state["player"]["hp"])
	var contact_hp_loss: int = 0
	if before: _play("")
	for tick: int in TAKE_LIMIT:
		await process_frame
		if contact < 0 and not before:
			var state: Dictionary = board.combat_state
			layer.spawn(board, specs, state, state, false)
			# Bias exact frame boundaries against floating-point round-off.
			layer.advance(Fx.CLOCK_QUANTUM_SECONDS, -1)
			contact = tick
		if _plan: await _post_process.presented
		else: await RenderingServer.frame_post_draw
		if before and contact < 0 and _is_shadow_contact(board.presentation):
			contact = tick
			contact_hp_loss = int(board.presentation["effect"].get("hp_loss", 0))
		if contact < 0 or tick - contact != SAMPLE_TICKS[snap]: continue
		if not _check_samples(layer, specs, SAMPLE_TICKS[snap]):
			return {}
		crop = _tile_crop(board, tile)
		if not Rect2i(Vector2i.ZERO, CanvasSize).encloses(crop):
			_fail("Centered crop exceeds framebuffer: " + str(crop))
			return {}
		crops.append(str(crop))
		if not _plan and not _capture_sample(id, crop, strip, snap):
			return {}
		snap += 1
		if snap == SAMPLE_TICKS.size(): break

	if snap != SAMPLE_TICKS.size():
		_fail("Contact samples incomplete for %s (contact=%d, samples=%d)." % [id, contact, snap])
		return {}
	var hp_lost: int = 0
	if before:
		for frame: int in TEARDOWN_FRAMES:
			if not _working and not _run._animation_lock: break
			await process_frame
		hp_lost = hero_hp_before - int(_run._combat_state["player"]["hp"])
		if _working or _run._animation_lock or contact_hp_loss <= 0 or hp_lost != contact_hp_loss:
			_fail("Expected one Shade Bolt hit. Contact HP loss=%d, total HP loss=%d." % [contact_hp_loss, hp_lost])
			return {}

	if _plan:
		var native: String = _output.get_base_dir().get_base_dir().path_join("native").path_join(id)
		for name: String in ["strip.png", "native-evidence.png", "take.json", "manifest.json"]:
			print("FX-21 PLANNED " + native.path_join(name))
		if ZOOM_FILES.has(id): print("FX-21 PLANNED " + native.path_join(ZOOM_FILES[id]))
	elif not _save(strip, "strip.png"):
		return {}
	return {
		"case": id, "viewport": str(_viewport.size), "ui_scale": 1.0, "tile": _coord(tile),
		"umbra": board.presentation.get("umbra_stage", "clear"), "crops": crops,
		"contact_tick": contact, "offsets_ms": SAMPLE_MS, "sample_ticks": SAMPLE_TICKS,
		"bursts": specs.size(), "hp_lost": hp_lost,
	}

func _spec(burst: String, tile: Vector2i, hit: bool) -> Dictionary:
	return {
		"name": burst, "tiles": [tile], "center": tile,
		"contact_hits": {tile: true} if hit else {},
	}

func _tile_crop(board: Control, tile: Vector2i) -> Rect2i:
	var center: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(tile)
	return Rect2i(Vector2i(center.round()) - CropSize / 2, CropSize)

func _check_occupancy(board: Control, spec: Dictionary) -> bool:
	var tile: Vector2i = spec["center"]
	var occupied: bool = board.combat_state["player"]["pos"] == tile
	for enemy: Dictionary in board.combat_state["enemies"]:
		occupied = occupied or (enemy["pos"] == tile and int(enemy["hp"]) > 0 and enemy["type"] == "crawler")
	return occupied == spec["contact_hits"].has(tile)

func _is_umbra_edge_take(board: Control, tile: Vector2i) -> bool:
	if board.presentation.get("umbra_stage") != DARK_STAGE: return false
	var grid: Array = board.combat_state["grid"]
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var edge: Vector2i = tile + direction
		# The hero is at the centre of its own small light radius.
		if tile == Hero: edge += direction * _combat_engine.effective_umbra_radius(board.combat_state)
		if Paths.is_passable(grid, edge) and not board._board_tile_is_visible_to_player(edge): return true
	return false

func _is_shadow_contact(shown: Dictionary) -> bool:
	var effect: Dictionary = shown.get("effect", {})
	return effect.get("intent_id") == BEFORE_INTENT and effect.get("element") == "shadow" \
		and effect.get("to") == Hero and _is_contact(effect, shown, "ranged")

func _check_samples(layer: Fx, specs: Array[Dictionary], tick: int) -> bool:
	var rows: Dictionary = Fx.metadata()["rows"]
	var frame: int = floori(float(tick) * float(Fx.metadata()["fps"]) / FPS)
	var expected: Dictionary = {}
	for spec: Dictionary in specs:
		var tile: Vector2i = spec["center"]
		var name: String = spec["name"] + ("_hit" if spec["contact_hits"].has(tile) else "_floor")
		expected[tile] = {false: rows[name + "_rear"], true: rows[name + "_front"]}
	for stamp: Fx.Stamp in layer._stamps:
		if not stamp.visible or stamp.sample.x != frame or expected.get(stamp.tile, {}).get(stamp.front, -1) != stamp.sample.y:
			_fail("Unexpected stamp at tick %d: tile=%s sample=%s expected frame=%d." % [tick, stamp.tile, stamp.sample, frame])
			return false
		expected[stamp.tile].erase(stamp.front)
	if layer._stamps.size() != specs.size() * 2:
		_fail("Wrong number of contact stamp halves at tick %d: %d." % [tick, layer._stamps.size()])
		return false
	return true

func _capture_sample(id: String, crop: Rect2i, strip: Image, snap: int) -> bool:
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != CanvasSize:
		_fail("Native framebuffer differs from 1920x1080.")
		return false
	image.convert(Image.FORMAT_RGB8)
	strip.blit_rect(image, crop, Vector2i(snap * CropSize.x, 0))
	if SAMPLE_MS[snap] != EVIDENCE_MS: return true
	if not _save(image, "native-evidence.png"): return false
	if ZOOM_FILES.has(id):
		var zoom: Image = image.get_region(crop)
		zoom.resize(CropSize.x * ZOOM_FACTOR, CropSize.y * ZOOM_FACTOR, Image.INTERPOLATE_NEAREST)
		return _save(zoom, ZOOM_FILES[id])
	return true
