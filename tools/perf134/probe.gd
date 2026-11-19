extends SceneTree
## Matched combat route and single-state native captures. Headless mode
## validates the input route and capture setup without producing frame evidence.
const Fixture = preload("res://tools/hitch_census/fixtures.gd")
const View = preload("res://tools/ptf09/real_fixture.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const EncounterPreparation = preload("res://scripts/encounter_asset_preparation.gd")
const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const SEED: int = 102
const SIZE := Vector2i(1920, 1080)
const NORMAL_ENEMIES: String = "crawler,acolyte,harrier"
const HAND: String = "flowing_step,stone_plate,pale_spark"
const WALK_CARD: String = "guarded_step"
const GUARDIAN: String = "ashen_reaver"
const WARBAND_BIOME: String = "earth"
const WARBAND_TIER: int = 2
const SKYBREAK_DRAGON: String = "zekarion"
const DRAGON_DEPTH: int = 4
const REPEAT_FIRST_TIME: int = 3
const REPEAT_COUNT: int = 2
const FIXTURE_SCHEMA: int = 3
const SETTLE_FRAMES: int = 90
const IDLE_FRAMES: int = 60
const CAPTURE_SETTLE_FRAMES: int = 72
const CAPTURE_FPS: int = 60
const WINDOW_SIZE := Vector2i(1280, 720)
const HOVER_SWEEPS: int = 2
const ACTION_TIMEOUT_SECONDS: float = 30.0
const CAPTURE_MOTION_PHASE: float = 0.5
const CAPTURE_MOVE_RANGE: int = 1
const CAPTURES: Dictionary = {
	"idle": "normal", "hover": "normal", "targeting": "normal", "enemy-mid-frame": "normal",
	"umbra": "umbra", "tharokh": "tharokh", "guardian": "guardian", "warband": "warband",
	"umbra-hover-light": "umbra", "umbra-hover-dark": "umbra", "second-activation": "second-activation",
	"burrow-marks": "burrow-marks", "skybreak-marks": "skybreak-marks", "walk-destination": "walk-destination",
}

var _scene: Control
var _board: Control
var _canvas: SubViewport
var _headless: bool
var _unfocused_frames: int = 0
var _sample: bool = false
var _previous_usec: int = 0
var _previous_cohort: String = ""
var _frames: Dictionary = {}
var _render_samples: Array[Array]
var _errors: Array[String]
var _output: String
var _capture: String
var _detail: bool
var _fixtures: Dictionary
var _fixture_digest: String
var _glyph_slice_started: int
var _glyph_longest_slice: int
var _glyph_slice_count: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	_output = _argument("--output=")
	_capture = _argument("--capture=")
	var capture_all: bool = OS.get_cmdline_user_args().has("--capture-all")
	_detail = OS.get_cmdline_user_args().has("--detail")
	if _output.is_empty() or (not _capture.is_empty() and not CAPTURES.has(_capture)) or (capture_all and (not _headless or not _capture.is_empty())) or _headless != OS.get_cmdline_user_args().has("--headless-check"):
		_finish("Supply --output=DIR and optionally --capture=STATE or headless --capture-all. Headless requires --headless-check.")
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	settings["reduced_motion"] = false
	if not View.Settings.save_settings(settings):
		_finish("Isolated settings could not be saved.")
		return
	var prepare: String = _argument("--prepare-fixtures=")
	if not prepare.is_empty():
		_prepare_fixtures(prepare)
		_finish()
		return
	var fixture_path: String = _argument("--fixtures=")
	var input_bytes: PackedByteArray = FileAccess.get_file_as_bytes(fixture_path)
	var prepared: Variant = bytes_to_var(input_bytes) if not input_bytes.is_empty() else null
	if not prepared is Dictionary or prepared.get("schema") != FIXTURE_SCHEMA or prepared.get("seed") != SEED or not prepared.get("cases") is Dictionary:
		_finish("A valid shared --fixtures bundle is required")
		return
	_fixtures = prepared["cases"]
	_fixture_digest = FileAccess.get_sha256(fixture_path)
	if not _capture.is_empty() and not _headless and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != CAPTURE_FPS):
		_finish("Native screenshots require the 60 fps movie presentation clock")
		return
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	_make_canvas()
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	if not _headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(_canvas.get_viewport_rid(), true)
		RenderingServer.frame_post_draw.connect(_sample_rendered_frame)

	if not _capture.is_empty() or capture_all:
		var states: Array = CAPTURES.keys() if capture_all else [_capture]
		for state: String in states:
			_capture = state
			await _capture_state()
			if is_instance_valid(_scene):
				_scene.queue_free()
				await _wait_frames(2)
			if not _errors.is_empty(): break
		_finish()
		return
	var controller_route_path: String = _argument("--board-redraw-route=")
	var controller_route: GDScript = load(controller_route_path) if not controller_route_path.is_empty() else null
	var results: Dictionary = {}
	for kind: String in ["normal", "tharokh"]:
		if not await _open(kind): break
		if OS.get_cmdline_user_args().has("--opening-glyphs"):
			results[kind] = await _measure_opening_glyphs()
		elif controller_route != null:
			results[kind] = await controller_route.run(self)
		else:
			results[kind] = await _route()
		_scene.queue_free()
		await _wait_frames(2)
	var adapter: GDScript = preload("res://scripts/input_router.gd")
	var report: Dictionary = {"workload": "perf-135", "headless": _headless, "seed": SEED,
		"size": [_canvas.size.x, _canvas.size.y], "window_size": [root.size.x, root.size.y],
		"fixture_sha256": _fixture_digest, "ui_scale": settings["ui_scale"], "deck": adapter.platform_is_steam_deck(),
		"display": DisplayServer.get_name(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info()["string"], "frame_cap": Engine.max_fps,
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"errors": _errors, "cases": results}
	if not _headless or _errors.is_empty():
		var file := FileAccess.open(_output.path_join("summary.json"), FileAccess.WRITE)
		if file == null: _errors.append("Could not write summary.json")
		else: file.store_string(JSON.stringify(report, "\t"))
	_finish()

func _make_canvas() -> void:
	# A standalone viewport keeps its render/input coordinate system independent
	# of Retina backing scale, desktop bounds, and native pointer events.
	root.mode = Window.MODE_WINDOWED
	root.size = WINDOW_SIZE
	_canvas = SubViewport.new()
	_canvas.size = SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	View.Settings.inherit_edge_smoothing(_canvas, root)
	if not _headless:
		var preview := TextureRect.new()
		preview.texture = _canvas.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(preview)

func _prepare_fixtures(path: String) -> void:
	var fixture := Fixture.new()
	var states: Dictionary = {}
	for kind: String in CAPTURES.values():
		if states.has(kind): continue
		seed(SEED)
		var scenario: String = "combat"
		var extras: Dictionary = {"hand": HAND}
		match kind:
			"tharokh", "skybreak-marks":
				scenario = "dragon"
				extras.merge({"dragon_id": "tharokh" if kind == "tharokh" else SKYBREAK_DRAGON,
					"dragon_depth": DRAGON_DEPTH, "dragon_case": "encounter", "dragon_build": "balanced"})
			"guardian":
				scenario = "guardian"
				extras.merge({"guardian_id": GUARDIAN, "guardian_case": "encounter"})
			"warband":
				scenario = "warband"
				extras.merge({"warband_biome": WARBAND_BIOME, "warband_tier": WARBAND_TIER})
			_:
				extras["umbra_stage"] = "deep" if kind == "umbra" else "clear"
				extras["enemy_types"] = NORMAL_ENEMIES
				if kind == "walk-destination": extras["hand"] = "%s,stone_plate,pale_spark" % WALK_CARD
				if kind == "burrow-marks":
					extras.merge({"enemy_types": "burrow_grub,burrow_grub", "enemy_intents": "erupt,erupt"}, true)
				if kind == "second-activation":
					extras.merge({"enemy_types": "burrow_grub", "enemy_intents": "burrow"}, true)
		var state: Dictionary = fixture.make(scenario, SEED, extras)
		if state.is_empty():
			_errors.append("Fixture %s failed: %s" % [kind, fixture.census_error])
			break
		_stage_capture_fixture(kind, state["combat_state"])
		states[kind] = state
	fixture.free()
	if not _errors.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write fixture bundle: " + path)
		return
	file.store_buffer(var_to_bytes({"schema": FIXTURE_SCHEMA, "seed": SEED, "cases": states}))
	print("PERF-135 FIXTURES: saved %d combat states" % states.size())

func _stage_capture_fixture(kind: String, combat: Dictionary) -> void:
	var engine := preload("res://scripts/combat_engine.gd").new()
	match kind:
		"second-activation":
			# Burrow itself is harmless. Only the scheduled repeat can Erupt.
			combat["turn_queue"][0]["time"] = REPEAT_FIRST_TIME
		"burrow-marks":
			var hero: Vector2i = combat["player"]["pos"]
			var mark_tiles: Array[Vector2i]
			mark_tiles.append(hero)
			for direction: Vector2i in preload("res://scripts/path_utils.gd").DIRS_4:
				var tile: Vector2i = hero + direction
				if engine._tile_is_passable(combat, tile) and engine._terrain_index_at_tile(combat, tile) < 0:
					mark_tiles.append(tile)
					break
			if mark_tiles.size() != combat["enemies"].size():
				_errors.append("Burrow fixture could not stage two distinct marks")
				return
			for index: int in range(mark_tiles.size()):
				combat["enemies"][index]["burrowed"] = true
				combat["enemies"][index]["erupt_tile"] = mark_tiles[index]
		"skybreak-marks":
			var index: int = 0
			for enemy: Dictionary in combat["enemies"]:
				if enemy["type"] == SKYBREAK_DRAGON:
					var cycle: Array = engine.GameData.enemy_def(SKYBREAK_DRAGON)["cycle_order"]
					enemy["dragon_cycle"] = cycle.find("skybreak") - 1
					var rng := RandomNumberGenerator.new()
					rng.seed = SEED
					engine._assign_enemy_intent(combat, index, rng)
					return
				index += 1
			_errors.append("Skybreak fixture could not find Zekarion")

func _open(kind: String) -> bool:
	var state: Dictionary = _fixtures.get(kind, {}).duplicate(true)
	if state.is_empty():
		_errors.append("Missing shared combat fixture: " + kind)
		return false
	seed(SEED)
	if not View.Store.save_data(state["progression"]) or not View.Store.save_run_state(state):
		_errors.append("Could not install %s fixture in isolated storage" % kind)
		return false
	if not _capture.is_empty() and not _headless:
		# Anchor the movie clock at the fixture boot, before any scene can tick.
		Clock.ticks_usec()
		Clock._frame = Engine.get_process_frames()
		Clock._scaled_usec = 1.0
		Clock._unscaled_usec = 1.0
	_scene = View.resume(self, _canvas)
	await _wait_frames(SETTLE_FRAMES)
	_board = _scene.get("board_view")
	var combat: Dictionary = _scene.get("_combat_state")
	var enemies: Array = combat.get("enemies", [])
	var scale: float = preload("res://scripts/ui_typography.gd").ui_scale(_scene)
	var mode: String = str(_scene.get("_run_state").get("mode", ""))
	var locked: bool = bool(_scene.get("_animation_lock"))
	var dialogue: bool = bool(_scene.get("_dialogue_active"))
	var valid: bool = mode == "combat" and not locked and not dialogue and _canvas.size == SIZE and is_equal_approx(scale, 1.0)
	valid = valid and not enemies.is_empty() and enemies.size() == (state["combat_state"]["enemies"] as Array).size()
	if kind == "umbra": valid = valid and _board.presentation.get("umbra_stage") == "deep"
	if combat.get("deck") != state.get("combat_state", {}).get("deck"):
		_errors.append("%s did not resume with the exact archived hand and piles" % kind)
		valid = false
	if not valid:
		_errors.append("%s boot: mode=%s lock=%s dialogue=%s enemies=%d viewport=%s window=%s UI scale=%s" % [
			kind, mode, locked, dialogue, enemies.size(), _canvas.size, root.size, scale])
	return valid

func _route() -> Dictionary:
	var combat: Dictionary = _scene.get("_combat_state")
	var initial_turn: int = int(combat.get("turn", 0))
	var initial_combat_digest: String = _combat_digest(combat)
	_scene.call("set_runtime_performance_instrumentation_enabled", true)
	_board.call("set_submission_performance_instrumentation_enabled", true)
	_board.call("reset_render_instrumentation")
	if _detail and _board.has_method("_begin_stage_submission_detail"):
		_board.set("_submission_detail_enabled", true)
	_frames = {}
	var empty_render_samples: Array[Array]
	_render_samples = empty_render_samples
	_previous_usec = 0
	_unfocused_frames = 0
	_sample = not _headless
	await _wait_frames(IDLE_FRAMES)
	var submissions_before_hover: int = _board_submission_count()
	var floor: Array[Vector2i] = _board.call("_rendered_tiles_in_draw_order")
	for sweep: int in range(HOVER_SWEEPS):
		for tile: Vector2i in floor:
			_hover(tile)
			await _wait_frames(1)
	var submissions_before_card: int = _board_submission_count()
	if submissions_before_card == submissions_before_hover:
		_errors.append("Idle sweep did not reach combat hover presentation")
	var submissions_before_pass: int = submissions_before_card
	if await _select_card():
		var targets: Array[Vector2i] = _targets()
		for tile: Vector2i in targets:
			_hover(tile)
			await _wait_frames(1)
		submissions_before_pass = _board_submission_count()
		if not targets.is_empty():
			var destination: Vector2i = targets.back()
			_click(_board_point(destination))
			if not await _wait_for_action():
				_errors.append("Target click did not complete its card action")
			elif _scene.get("_selected_card_index") >= 0 or _scene.get("_combat_state").get("player", {}).get("pos") != destination:
				_errors.append("Selected card did not move the hero to the target")
	var submissions_after_card: int = _board_submission_count()
	_scene.clear_runtime_animation_clock_snapshot()
	var enemy_round_started: int = Time.get_ticks_usec()
	var pass_chip: Button = _scene.find_child("PassPreviewChip", true, false)
	if is_instance_valid(pass_chip) and pass_chip.is_visible_in_tree() and not pass_chip.disabled:
		pass_chip.grab_focus()
		for pressed: bool in [true, false]:
			var accept := InputEventAction.new()
			accept.action = &"ui_accept"
			accept.pressed = pressed
			_canvas.push_input(accept)
		if not await _wait_for_action(): _errors.append("Focused Pass did not complete an enemy round")
	elif int(_scene.get("_combat_state").get("turn", 0)) <= initial_turn:
		_errors.append("No actionable Pass chip or automatic pass")
	if int(_scene.get("_combat_state").get("turn", 0)) <= initial_turn:
		_errors.append("Enemy round did not advance the turn")
	var enemy_round_elapsed: int = Time.get_ticks_usec() - enemy_round_started
	var submissions_at_enemy_round_end: int = _board_submission_count()
	await _wait_frames(IDLE_FRAMES)
	_sample = false
	var sections: Dictionary = _scene.call("runtime_performance_instrumentation_snapshot")
	var render: Dictionary = _board.call("render_instrumentation_snapshot")
	for required: String in ["stage_board_submission", "hover_stage_refresh_total", "refresh_ui_total",
		"card_preview_refresh_total", "animation_lock_ui_total", "enemy_round_final_refresh_ui_wall_total"]:
		if int(sections.get(required, {}).get("count", 0)) <= 0: _errors.append("Route did not sample " + required)
	return {"initial_combat_sha256": initial_combat_digest, "initial_turn": initial_turn, "final_turn": _scene.get("_combat_state").get("turn", 0),
		"sections": sections, "frame_usec": _frames, "render_samples": _render_samples, "render": render,
		"unfocused_frames": _unfocused_frames,
		"board_submission": _board.call("submission_performance_instrumentation_snapshot"),
		"stage_submission_top": _board.get("_submission_detail_top") if _detail else [],
		"runtime_top_frames": _scene.runtime_performance_frame_instrumentation_snapshot()["top_frames"] if _detail else [],
		"draw_categories": _board.get("_submission_draw_categories") if _detail else {},
		"enemy_round_clock": _scene.runtime_animation_clock_snapshot(),
		"enemy_round_elapsed_usec": enemy_round_elapsed,
		"settle_submissions": _board_submission_count() - submissions_at_enemy_round_end,
		"board_submissions_by_phase": {"idle_hover": submissions_before_card - submissions_before_hover,
			"card_targeting": submissions_before_pass - submissions_before_card,
			"hero_action": submissions_after_card - submissions_before_pass,
			"enemy_round_and_rest": _board_submission_count() - submissions_after_card},
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}

func _measure_opening_glyphs() -> Dictionary:
	var state: Dictionary = _scene.get("_combat_state")
	var hud: Control = _scene.get("_combat_objective_hud")
	_glyph_longest_slice = 0
	_glyph_slice_count = 0
	_glyph_slice_started = Time.get_ticks_usec()
	var jobs: Array[Dictionary] = hud.opening_glyph_preparation_jobs(EncounterPreparation.opening_objective_hud_state(_scene, state))
	var collect_usec: int = Time.get_ticks_usec() - _glyph_slice_started
	await Glyphs.prepare_jobs_for(_scene, jobs, _next_glyph_slice, func() -> bool: return is_instance_valid(_scene))
	_record_glyph_slice()
	print("PERF-137 GLYPHS: %s collect=%d us, longest combined slice=%d us, frames=%d" % [state["room_name"], collect_usec, _glyph_longest_slice, _glyph_slice_count])
	return {"collect_usec": collect_usec, "max_usec": _glyph_longest_slice, "frames": _glyph_slice_count}

func _next_glyph_slice() -> void:
	_record_glyph_slice()
	await EncounterPreparation.present_frame(self)
	_glyph_slice_started = Time.get_ticks_usec()

func _record_glyph_slice() -> void:
	_glyph_longest_slice = maxi(_glyph_longest_slice, Time.get_ticks_usec() - _glyph_slice_started)
	_glyph_slice_count += 1

func _board_submission_count() -> int:
	var counts: Dictionary = _board.get("_submission_performance_counts")
	return int(counts.get("identical", 0)) + int(counts.get("diff", 0))

func _capture_state() -> void:
	var kind: String = CAPTURES[_capture]
	if not await _open(kind): return
	var expected_hover := Vector2i(-1, -1)
	if _capture == "hover":
		expected_hover = _visible_foe_hover()
		if expected_hover.x < 0: return
	elif _capture in ["targeting", "walk-destination"]:
		if not await _select_card(): return
		var targets: Array[Vector2i] = _targets()
		if _capture == "walk-destination":
			targets.erase(_board.combat_state["player"]["pos"])
		if targets.is_empty():
			_errors.append("Capture has no legal destination for %s" % _capture)
			return
		targets.sort()
		expected_hover = _capture_target_hover(targets)
		if expected_hover.x < 0: return
	elif _capture == "enemy-mid-frame" and not _submit_enemy_sample():
		return
	elif _capture == "tharokh":
		_scene.call("_set_show_all_enemy_intents", true)
	elif _capture in ["umbra-hover-light", "umbra-hover-dark"]:
		expected_hover = _umbra_hover(_capture == "umbra-hover-light")
		if expected_hover.x < 0: return
	elif _capture == "second-activation":
		var pass_chip: Button = _scene.find_child("PassPreviewChip", true, false)
		if not is_instance_valid(pass_chip) or not pass_chip.is_visible_in_tree() or pass_chip.disabled:
			_errors.append("The repeated activation fixture has no actionable Pass")
			return
		_motion(pass_chip.get_global_rect().get_center())
	await _wait_frames(CAPTURE_SETTLE_FRAMES)
	var live_hover: Vector2i = _scene.get("_hovered_board_tile")
	if expected_hover.x >= 0 and live_hover != expected_hover:
		_errors.append("Requested hover %s reached %s" % [expected_hover, live_hover])
		return
	var shown: Dictionary = _board.presentation
	var details: bool = bool(shown.get("show_all_enemy_intents", false))
	var threats: Dictionary = shown.get("threats_at_rest", {})
	var threat_tiles: Dictionary = _board.get("_rest_threat_tile_alphas")
	var expanded: Array = shown.get("enemy_threat_previews", [])
	var hud: Control = _board.get("_hud_render_layer")
	var overlays: Control = _board.get("_overlay_render_layer")
	var intent_details: Dictionary = _retained_intent_details(hud)
	var labels: Array[String]
	for detail: Dictionary in intent_details.values(): labels.append(detail["name"])
	labels.sort()
	if _capture == "tharokh" and (
		not details or expanded.size() < 2 or threat_tiles.is_empty()
		or not labels.has("Stonewake") or not labels.has("Gnaw")
		or hud.presentation.get("enemy_threat_previews", []) != expanded
		or overlays.get("_rest_threat_tile_alphas") != threat_tiles
	):
		_errors.append("Tharokh retained HUD/overlay: details=%s labels=%s expanded=%d red_tiles=%d" % [details, labels, expanded.size(), threat_tiles.size()])
		return
	var combat: Dictionary = _scene.get("_combat_state")
	var witness: Dictionary = _capture_witness(combat, shown, live_hover, labels)
	var deck: Dictionary = combat.get("deck", {})
	var pile_labels: Dictionary = {}
	for pile: String in ["draw", "discard", "burned"]:
		var label_name: String = "burn_count" if pile == "burned" else pile + "_count"
		var label: Label = _scene.get(label_name)
		pile_labels[pile] = label.text
		if label.text != str(deck.get(pile, []).size()):
			_errors.append("%s label %s does not match the fixture pile" % [pile, label.text])
	if not _errors.is_empty(): return
	var receipt: Dictionary = {
		"state": _capture, "fixture_sha256": _fixture_digest,
		"combat_sha256": _combat_digest(combat), "deck": deck, "pile_labels": pile_labels,
		"intent_labels": labels, "intent_details": intent_details, "witness": witness,
		"hover": [live_hover.x, live_hover.y], "details": details,
		"selected_card": _scene.get("_selected_card_index"), "expanded_plans": expanded.size(),
		"threats": threats.get("threats", []).size(), "threat_tiles": threat_tiles.size(),
		"clock_usec": Clock.ticks_usec() if not _headless else 0,
		"clock_fps": CAPTURE_FPS, "probe_size": [SIZE.x, SIZE.y], "masks": [],
	}
	var file := FileAccess.open(_output.path_join(_capture + "-state.json"), FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write capture state receipt")
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	print("PERF-135 CAPTURE STATE: %s details=%s expanded=%d red_tiles=%d" % [
		_capture, details, expanded.size(), threat_tiles.size()])
	if _headless or not _errors.is_empty(): return
	var path: String = _output.path_join(_capture + ".png")
	var picture: Image = _canvas.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8)
	if picture.save_png(path) != OK:
		_errors.append("PNG failed: " + path)
	else:
		print(path)

func _retained_intent_details(hud: Control) -> Dictionary:
	var canvases: Array = [hud]
	canvases.append_array(hud.get("_layer_slices").canvases)
	var details: Dictionary = {}
	for canvas: Control in canvases:
		for op: Array in canvas.get("_render_slice_ops"):
			if op[0] != "_draw_unit_hud_details": continue
			for entry: Dictionary in canvas.get("_hud_layout_entries_cache"):
				var layout: Dictionary = entry.get("layout", {})
				var label: String = str(layout.get("intent_name", ""))
				if label.is_empty() or layout.get("line_rects", []).is_empty(): continue
				var rows: Array = []
				for row: Array in layout.get("rows", []):
					var tokens: Array = []
					for token: Dictionary in row:
						tokens.append([token.get("icon", ""), token.get("value", "")])
					rows.append(tokens)
				details[entry["actor_key"]] = {"name": label, "rows": rows}
	return details

func _visible_foe_hover() -> Vector2i:
	var tiles: Array[Vector2i]
	for unit: Dictionary in _scene.get("_combat_state").get("enemies", []):
		tiles.append(unit["pos"])
	return _capture_target_hover(tiles)

func _umbra_hover(visible: bool) -> Vector2i:
	var ids: Array = _board.presentation.get("visible_enemy_ids", [])
	var tiles: Array[Vector2i]
	for enemy: Dictionary in _board.combat_state["enemies"]:
		if ids.has(enemy["id"]) == visible and _board._board_tile_is_visible_to_player(enemy["pos"]) == visible:
			tiles.append(enemy["pos"])
	return _capture_target_hover(tiles)

func _capture_witness(combat: Dictionary, shown: Dictionary, hover: Vector2i, labels: Array[String]) -> Dictionary:
	var witness: Dictionary = {}
	var pass_chip: Button = _scene.find_child("PassPreviewChip", true, false)
	match _capture:
		"guardian":
			witness["guardian"] = combat.get("guardian_id", "")
			var units: Array[Dictionary] = _board._visible_units()
			if witness["guardian"] != GUARDIAN or not units.any(func(unit: Dictionary) -> bool: return unit.get("type") == GUARDIAN):
				_errors.append("Guardian fixture did not present its live Guardian")
		"warband":
			var leader: Dictionary = preload("res://scripts/warband_view.gd").command_leader(_board)
			witness["banner_leader"] = leader.get("key", "")
			witness["banner_tile"] = leader.get("pos")
			if leader.is_empty() or not _board._board_tile_is_visible_to_player(leader["pos"]):
				_errors.append("Warband fixture has no visible Command leader")
		"umbra-hover-light", "umbra-hover-dark":
			var at_tile: Dictionary = {}
			for enemy: Dictionary in combat["enemies"]:
				if enemy["pos"] == hover:
					at_tile = enemy
					break
			var visible: bool = _capture == "umbra-hover-light"
			var key: String = "enemy_%d" % int(at_tile.get("id", -1))
			var label: String = str(at_tile.get("intent", {}).get("name", ""))
			witness = {"foe": key, "foe_visible": shown.get("visible_enemy_ids", []).has(at_tile.get("id")), "lit": _board._board_tile_is_visible_to_player(hover)}
			if at_tile.is_empty() or witness["foe_visible"] != visible or witness["lit"] != visible or labels.has(label) != visible:
				_errors.append("Umbra hover disclosed the wrong intent for %s: %s %s" % [_capture, witness, labels])
		"second-activation":
			var summary: Dictionary = pass_chip.get_meta("pass_forecast_summary", {})
			var first: Dictionary = combat["enemies"][0]
			var key: String = "enemy_%d" % int(first["id"])
			witness = {"first_intent": first["intent"]["id"], "activations": summary.get("enemy_activations", {}).get(key, 0),
				"hp_loss": int(summary.get("hp_loss", 0)), "tone": summary.get("tone", ""), "enemy_hit": summary.get("enemy_hits", {}).has(key)}
			if not bool(pass_chip.get_meta("pass_pointer_hover", false)) or witness["first_intent"] != "burrow" or witness["activations"] != REPEAT_COUNT or not witness["enemy_hit"] or witness["tone"] != "danger" or witness["hp_loss"] <= 0:
				_errors.append("Pass plate did not show the second activation's Health loss: %s" % witness)
		"burrow-marks":
			var marks: Array[Dictionary] = preload("res://scripts/enemy_mechanics/burrow_view.gd").marks(_board.combat_state)
			witness["burrow_marks"] = marks
			if marks.size() != 2 or marks[0]["tile"] == marks[1]["tile"] or marks.any(func(mark: Dictionary) -> bool: return not _board._board_tile_is_visible_to_player(mark["tile"])):
				_errors.append("Expected two distinct, visible Burrow marks")
		"skybreak-marks":
			for enemy: Dictionary in _board.combat_state["enemies"]:
				if enemy["type"] != SKYBREAK_DRAGON: continue
				witness["intent"] = enemy.get("intent", {}).get("id")
				witness["marks"] = preload("res://scripts/boss_area_marks.gd").tiles(_board.combat_state, enemy)
			if witness.get("intent") != "skybreak" or (witness.get("marks", []) as Array).is_empty():
				_errors.append("Skybreak fixture has no announced mark field")
		"walk-destination":
			var summary: Dictionary = pass_chip.get_meta("pass_forecast_summary", {}) if is_instance_valid(pass_chip) else {}
			witness["card"] = combat["deck"]["hand"][0]
			witness["forecast_tile"] = shown.get("threats_at_rest", {}).get("hero_tile")
			witness["forecast_tone"] = summary.get("tone")
			witness["movement_preview"] = is_instance_valid(pass_chip) and bool(pass_chip.get_meta("pass_movement_preview", false))
			if witness["card"] != WALK_CARD or int(_scene.get("_selected_card_index")) != 0 or witness["forecast_tile"] != hover or not witness["movement_preview"] or summary.is_empty():
				_errors.append("Walk aim did not publish a destination forecast: %s" % witness)
	return witness

func _capture_target_hover(tiles: Array[Vector2i]) -> Vector2i:
	for tile: Vector2i in tiles:
		var point: Vector2 = _board.world_position_for_tile(tile)
		if _board.call("_tile_at_point", point) != tile: continue
		_hover(tile)
		return tile
	_errors.append("Fixture has no hittable capture tile")
	return Vector2i(-1, -1)

func _combat_digest(combat: Dictionary) -> String:
	# RunScene assigns a separate analytics run/combat ID to each sandbox.
	# Compare the complete gameplay snapshot without that session bookkeeping.
	var gameplay: Dictionary = combat.duplicate(false)
	gameplay.erase("analytics")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(gameplay))
	return digest.finish().hex_encode()

func _submit_enemy_sample() -> bool:
	var state: Dictionary = _scene.get("_combat_state")
	var engine: RefCounted = _scene.get("_combat_engine")
	for index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = state["enemies"][index]
		if str(enemy["type"]) != "crawler": continue
		var records: Array[Dictionary] = engine._enemy_actual_path_records(state, enemy, CAPTURE_MOVE_RANGE)
		var from_tile: Vector2i = enemy["pos"]
		var to_tile: Vector2i = from_tile
		for record: Dictionary in records:
			var path: Array = record["path"]
			if path.size() >= 2 and path[0] == from_tile:
				to_tile = path[1]
				break
		if to_tile == from_tile: continue
		var actor: String = "enemy_%d" % int(enemy["id"])
		var before: Vector2 = _board.world_position_for_unit_origin(enemy, from_tile)
		var after: Vector2 = _board.world_position_for_unit_origin(enemy, to_tile)
		_scene.set("_animation_lock", true)
		_scene.call("_refresh_enemy_round_lock_ui")
		var shown: Dictionary = _scene.call("_movement_actor_frame_presentation", {}, actor,
			before.lerp(after, CAPTURE_MOTION_PHASE), _board.draw_tile_for_unit_origin(enemy, to_tile), to_tile)
		var phase_distance: float = before.distance_to(after) * CAPTURE_MOTION_PHASE / _board.source_pixel_scale_for_type("crawler")
		shown["crawler_motion"] = {actor: {"clip": "walk", "direction": to_tile - from_tile,
			"phase": phase_distance / preload("res://scripts/crawler_cutout/renderer.gd").walk_cycle_distance()}}
		_scene.call("_render_board_state", state, shown)
		if (_board.presentation.get("unit_world_positions", {}) as Dictionary).has(actor): return true
		break
	_errors.append("No legal crawler movement sample was rendered")
	return false

func _select_card() -> bool:
	var rect: Rect2 = _scene.call("_hand_card_global_rect", 0)
	_click(rect.get_center())
	await _wait_frames(1)
	if int(_scene.get("_selected_card_index")) == 0: return true
	_errors.append("Viewport click did not select the fixture's opening card")
	return false

func _targets() -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(_scene.get("_pending_target_tiles"))
	if result.is_empty(): _errors.append("Fixture card has no legal targets")
	return result

func _board_point(tile: Vector2i) -> Vector2:
	return _board.get_global_transform_with_canvas() * Vector2(_board.world_position_for_tile(tile))

func _hover(tile: Vector2i) -> void:
	var point: Vector2 = _board.world_position_for_tile(tile)
	_motion(_board_point(tile))
	# A standalone viewport has no native mouse forwarding. If viewport GUI
	# dispatch didn't reach the board, deliver the same motion locally.
	var handled: Vector2 = _board.get("_last_pointer_position")
	if not handled.is_equal_approx(point):
		var event := InputEventMouseMotion.new()
		event.position = point
		_board.call("_gui_input", event)

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_canvas.push_input(event, true)

func _click(point: Vector2) -> void:
	_motion(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_canvas.push_input(event, true)

func _wait_frames(count: int) -> void:
	for index: int in range(count):
		if _headless: await process_frame
		else: await RenderingServer.frame_post_draw

func _wait_for_action() -> bool:
	var locked: bool = bool(_scene.get("_animation_lock"))
	var until: int = Time.get_ticks_usec() + int(ACTION_TIMEOUT_SECONDS * 1000000.0)
	while bool(_scene.get("_animation_lock")):
		await _wait_frames(1)
		if Time.get_ticks_usec() >= until: return false
	return locked

func _sample_rendered_frame() -> void:
	if not _sample: return
	var now: int = Time.get_ticks_usec()
	if not DisplayServer.window_is_focused(): _unfocused_frames += 1
	if _previous_usec > 0:
		var intervals: Array = _frames.get_or_add(_previous_cohort, [])
		intervals.append(now - _previous_usec)
		_render_samples.append([
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(_canvas.get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_gpu(_canvas.get_viewport_rid()),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		])
	_previous_usec = now
	_previous_cohort = "combat_animation" if bool(_scene.get("_animation_lock")) else "combat_targeting" if int(_scene.get("_selected_card_index")) >= 0 else "combat_idle"

func _argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func _finish(error: String = "") -> void:
	if not error.is_empty(): _errors.append(error)
	for failure: String in _errors: push_error(failure)
	print("PERF-135 PROBE: %s (%s, %d errors)" % [
		"PASS" if _errors.is_empty() else "FAIL", "headless setup" if _headless else "native", _errors.size()])
	quit(0 if _errors.is_empty() else 1)
