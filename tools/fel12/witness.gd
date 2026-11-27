extends SceneTree
## Geometry witness on the same production Noctyrax fixture used by DFX-03.

const Geometry = preload("res://tools/fel12/geometry.gd")
const DragonRules = preload("res://scripts/dragon_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Cases = preload("res://tools/fx18/cases.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const SEED: int = 7262026
const CAPTURE_SIZE := Vector2i(1920, 1080)
const SINK_SIZE := Vector2i(64, 64)
const UI_SCALE: float = 1.0
const READY_FRAMES: int = 360
const SETTLE_FRAMES: int = 12
const STATE_SETTLE_FRAMES: int = 4
const CROWDED_CASE: String = "hero_brazier_1_west"
const FRONT_CASE: String = "hero_in_front"
# In the isometric projection this advances straight down-screen.
const FRONT_STEP := Vector2i.ONE
const NATIVE_CASES := {"capture": "capture.png", CROWDED_CASE: "crowded.png", FRONT_CASE: "hero_in_front.png"}
const CARDINALS: Dictionary = {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}

var _run: Node
var _viewport: SubViewport

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run_witness")

func _arg(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _run_witness() -> void:
	if not await _open_fight():
		push_error("FEL12 could not open the production Noctyrax fixture")
		quit(1)
		return
	var baseline: bool = not _arg("--base-script").is_empty()
	var version: String = "base" if baseline else "branch"
	var original: Dictionary = _run._combat_state.duplicate(true)
	var states: Dictionary = _states(original)
	var native: bool = "--native" in OS.get_cmdline_user_args()
	var headless: bool = DisplayServer.get_name() == "headless"
	var output: String = _arg("--out")
	if native and (output.is_empty() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		push_error("FEL12 native proof requires an output directory and cel look all")
		quit(1)
		return
	var case_ids: Array = NATIVE_CASES.keys() if native else states.keys()
	var clear: int = 0
	var expanded: int = 0
	var compact: int = 0
	var crowded: int = 0
	var soft_only: int = 0
	var failures: int = 0
	for id: String in case_ids:
		var state: Dictionary = states[id]
		if id != "capture":
			_run._combat_state = state
			_run._run_state["combat_state"] = state
			_run._refresh_stage_view_with_state(state)
			for frame: int in STATE_SETTLE_FRAMES: await process_frame
		if not headless: await RenderingServer.frame_post_draw
		var result: Dictionary = _inspect(id, state, baseline)
		clear += int(result["clear"])
		var stage: int = result["stage"]
		expanded += int(stage >= 1)
		compact += int(stage >= 2)
		crowded += int(stage == 3)
		soft_only += int(result["hard_clear"] and not result["clear"])
		if not result["valid"] or (not baseline and not result["hard_clear"] and stage != 3):
			failures += 1
		if native and not _capture(output.path_join(NATIVE_CASES[id]), headless):
			failures += 1
	if not native and not baseline:
		var hud: Control = _run.board_view._hud_render_layer
		var fallbacks: bool = Geometry.check_fallbacks(hud, original["guardian_braziers"][0]["pos"])
		var crossing: bool = Geometry.check_crossing(hud)
		print("FEL12 solver checks expanded/compact/crowded=%s crossing=%s" % [fallbacks, crossing])
		failures += int(not fallbacks or not crossing)
	_viewport.queue_free()
	await process_frame
	var mode: String = "WITNESS"
	if native: mode = "NATIVE DRY RUN" if headless else "NATIVE CAPTURE"
	var passed: bool = failures == 0 and (native or not baseline or clear == case_ids.size())
	print("FEL12 %s %s: %s (%d/%d states with zero violations, %d soft-only, %d expanded, %d compact, %d crowded fallbacks, %d validation failures)" % [
		version, mode, "PASS" if passed else "FAIL", clear, case_ids.size(), soft_only, expanded, compact, crowded, failures])
	quit(0 if passed else 1)

func _capture(path: String, headless: bool) -> bool:
	if _viewport.size != CAPTURE_SIZE:
		return false
	if headless:
		print("FEL12 planned framebuffer: %s" % path)
		return true
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != CAPTURE_SIZE or image.save_png(path) != OK:
		push_error("FEL12 could not save a 1920x1080 framebuffer to " + path)
		return false
	print(path)
	return true

func _states(original: Dictionary) -> Dictionary:
	var states: Dictionary = {"capture": original}
	var combat := CombatEngine.new()
	var braziers: Array = original["guardian_braziers"]
	for brazier: Dictionary in braziers:
		var tile: Vector2i = brazier["pos"]
		for side: String in CARDINALS:
			var state: Dictionary = original.duplicate(true)
			var boss: Dictionary = state["enemies"][0]
			var hero_tile: Vector2i = tile + CARDINALS[side]
			state["player"]["pos"] = hero_tile
			if Surface.footprint_tiles(boss).has(hero_tile):
				boss["pos"] = _closest_boss_origin(state, Vector2i(-1, -1))
			states["hero_brazier_%d_%s" % [brazier["id"], side]] = state
	var close: Dictionary = original.duplicate(true)
	var lower: Vector2i = braziers[-1]["pos"]
	close["enemies"][0]["pos"] = _closest_boss_origin(close, lower)
	states["boss_adjacent"] = close
	var front: Dictionary = original.duplicate(true)
	front["player"]["pos"] = lower + FRONT_STEP
	states[FRONT_CASE] = front
	var threatened: Dictionary = original.duplicate(true)
	Cases._declare(combat, threatened, threatened["enemies"][0], "night_coil", SEED)
	states["threatened"] = threatened
	var eclipse: Dictionary = original.duplicate(true)
	Cases._declare(combat, eclipse, eclipse["enemies"][0], "last_eclipse", SEED)
	var legacy_snuff: Dictionary = eclipse["enemies"][0]["intent"]["actions"][0]
	legacy_snuff["snuff_brazier"] = true
	legacy_snuff["brazier_id"] = braziers[-1]["id"]
	states["dark_before_eclipse"] = eclipse
	var unlit: Dictionary = original.duplicate(true)
	unlit["guardian_braziers"][-1]["lit"] = false
	states["unlit"] = unlit
	var relights: Dictionary = unlit.duplicate(true)
	Cases._declare(combat, relights, relights["enemies"][0], "night_coil", SEED)
	var legacy_coil: Dictionary = relights["enemies"][0]["intent"]
	legacy_coil["restore_braziers"] = true
	for action: Dictionary in legacy_coil["actions"]:
		action.erase("snuff_brazier")
		action.erase("brazier_id")
	states["relights_after_coil"] = relights
	var relit: Dictionary = unlit.duplicate(true)
	relit["player"]["pos"] = lower
	DragonRules.relight_brazier(relit)
	states["relit_by_step"] = relit
	return states

func _closest_boss_origin(state: Dictionary, brazier_tile: Vector2i) -> Vector2i:
	var boss: Dictionary = (state["enemies"][0] as Dictionary).duplicate()
	var origin: Vector2i = boss["pos"]
	var nearest: Vector2i = Vector2i(-1, -1)
	var distance: int = 2147483647
	var grid: Array = state["grid"]
	var blocked: Array[Vector2i]
	blocked.append(state["player"]["pos"])
	for brazier: Dictionary in state["guardian_braziers"]: blocked.append(brazier["pos"])
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var candidate := Vector2i(x, y)
			boss["pos"] = candidate
			var tiles: Array[Vector2i] = Surface.footprint_tiles(boss)
			if tiles.any(func(tile: Vector2i) -> bool: return blocked.has(tile) or not Paths.is_passable(grid, tile)):
				continue
			if brazier_tile.x >= 0 and not tiles.any(func(tile: Vector2i) -> bool: return Paths.manhattan(tile, brazier_tile) == 1):
				continue
			var delta: int = Paths.manhattan(origin, candidate)
			if delta < distance:
				nearest = candidate
				distance = delta
	return nearest

func _inspect(id: String, state: Dictionary, baseline: bool) -> Dictionary:
	var board: Control = _run.board_view
	var hud: Control = board._hud_render_layer
	var hero: Vector2i = state["player"]["pos"]
	var boss: Vector2i = state["enemies"][0]["pos"]
	var markers: Array[Dictionary] = hud._noctyrax_brazier_markers()
	var valid: bool = (markers.size() == state["guardian_braziers"].size()
		and Paths.is_passable(state["grid"], hero) and Paths.is_passable(state["grid"], boss)
		and hud.combat_state["player"]["pos"] == hero and hud.combat_state["enemies"][0]["pos"] == boss)
	var stage: int = 0
	var hard_clear: bool = true
	var soft_hits := PackedStringArray()
	var painted: Dictionary = {}
	for index: int in hud._tile_tooltip_regions:
		var region: Dictionary = hud._tile_tooltip_regions[index]
		if region["tile_detail_key"] == "brazier":
			painted[region["tile"]] = hud._tooltip_regions[index]["rect"]
	var reports: Array[Dictionary] = Geometry.inspect(hud, board, markers, baseline)
	for i: int in range(markers.size()):
		var marker: Dictionary = markers[i]
		var report: Dictionary = reports[i]
		var rect: Rect2 = marker["rect"]
		var drawn: bool = painted.get(marker["tile"]) == rect
		valid = valid and drawn and report["braziers"] == state["guardian_braziers"].size()
		stage = maxi(stage, marker.get("stage", 0))
		var hits: PackedStringArray = report["hits"]
		var unit_hits: PackedStringArray = report["unit_hits"]
		hard_clear = hard_clear and hits.is_empty() and report["in_bounds"]
		soft_hits.append_array(unit_hits)
		print("FEL12 %s %s hero=%s boss=%s tile=%s %s / %s plate=%s tether=[%s -> %s] length=%.3f in_bounds=%s drawn=%s overlaps=%s soft_unit_crossings=%s" % [
			"base" if baseline else "branch", id, hero, boss, marker["tile"], marker["label"], marker["detail"], rect,
			report["start"], report["end"], report["length"], report["in_bounds"], drawn,
			"none" if hits.is_empty() else " | ".join(hits), "none" if unit_hits.is_empty() else " | ".join(unit_hits)])
	if stage == 3: print("FEL12 CROWDED %s had no clear compact layout. See the overlaps above." % id)
	if not baseline and not soft_hits.is_empty():
		print("FEL12 CROWDED %s soft unit crossings only where listed: %s" % [id, " | ".join(soft_hits)])
	return {"valid": valid, "clear": hard_clear and soft_hits.is_empty(), "hard_clear": hard_clear, "stage": stage}

func _open_fight() -> bool:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	if not Settings.save_settings(settings): return false
	var profile: Dictionary = Tutorial.dismiss_tutorial(Store.default_data())
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	var engine := RunEngine.new()
	var combat := CombatEngine.new()
	var fixture: Dictionary = Cases.fixture("starless_breath", engine, combat, profile, SEED, "")
	if fixture.is_empty() or not Store.save_data(fixture["profile"]) or not Store.save_run_state(fixture["run"]):
		return false
	root.size = SINK_SIZE
	root.content_scale_size = SINK_SIZE
	root.content_scale_factor = UI_SCALE
	# Headless has no post-draw event for startup waiters.
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_viewport = SubViewport.new()
	_viewport.size = CAPTURE_SIZE
	_viewport.gui_disable_input = true
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = RunScene.instantiate()
	var baseline: String = _arg("--base-script")
	if not baseline.is_empty():
		var base_script: Script = load(baseline)
		if base_script == null:
			_run.free()
			return false
		_run.get_node("BoardUnderlay/CombatBoard").set_script(base_script)
	_viewport.add_child(_run)
	_run._close_dialogue()
	for frame: int in READY_FRAMES:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()):
			for settle: int in SETTLE_FRAMES: await process_frame
			return _run._run_state.get("mode") == "combat" and _run.hand_scroll.is_visible_in_tree() and is_equal_approx(UiTypography.ui_scale(_run), UI_SCALE)
	return false

