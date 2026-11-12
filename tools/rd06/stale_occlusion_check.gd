extends SceneTree

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const OUTPUT := "/private/tmp/labyrinth_codex/rd-06"
const IDLE_FRAMES := 120
const SETTLE_FRAMES := 16
var scene: Node
var canvas: SubViewport
var failures: Array[String]
var first: Dictionary = {}
var capture := false
var baseline := false
var phase := "resume"
const MAX_BOOT_FRAMES := 1800
# BoardFraming's one-pixel fallback precedes a renderable fight layout.
const STARTUP_TILE_WIDTH := 1.0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	capture = OS.get_cmdline_user_args().has("--capture")
	baseline = OS.get_environment("RD06_BASELINE") == "1"
	var args := OS.get_cmdline_user_args()
	if args.has("--phase"): phase = args[args.find("--phase") + 1]
	if DisplayServer.get_name() == "headless": process_frame.connect(_headless_boundary)
	call_deferred("_run")

func _headless_boundary() -> void:
	call_deferred("_first_frame")
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("Capture requires the design owner's window server")
		quit(1)
		return
	Fixture.install_save(OUTPUT.path_join("combat.json"))
	if phase != "resume": _install_briefing()
	canvas = Fixture.make_canvas(self)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	if phase == "fresh": scene.set_script(load("res://tools/rd06/entry_scene.gd"))
	if phase == "briefing": scene.set("_run_engine", preload("res://tools/rd06/entry_engine.gd").new())
	if baseline:
		scene.get_node("BoardUnderlay/CombatBoard").set_script(load("res://tools/rd06/_baseline_board.gd"))
	canvas.add_child(scene)
	# Observe the first render boundary with a visible submitted combat board.
	RenderingServer.frame_pre_draw.connect(_first_frame)
	if phase == "briefing":
		_check(bool(scene.get("_pre_battle_scrim").visible), "Real pre-fight briefing opens")
		await scene.call("_on_pre_battle_start_pressed")
	for frame: int in MAX_BOOT_FRAMES:
		if not first.is_empty(): break
		await process_frame
	_check(not first.is_empty(), "First combat boundary observed")
	for frame: int in SETTLE_FRAMES: await process_frame
	var board: Control = scene.get("board_view")
	if board == null:
		push_error("Production scene did not initialize")
		quit(1)
		return
	print("RD06 PHASE: ", phase)
	print("RD06 FIRST ", first)
	_check(bool(first.get("covered_hero", false)), "Fixture hero starts behind a pillar")
	_check(bool(first.get("actor_rects_current", false)), "First actor obstruction rectangles match presentation")
	var settled: Dictionary = _snapshot()
	_check(bool(settled.get("actor_rects_current", false)), "Settled actor obstruction rectangles match presentation")
	print("RD06 SETTLED ", settled)
	_check(first.get("tints") == settled.get("tints"), "First combat tint equals settled tint")
	var count: int = board.get("_full_dynamic_redraw_count")
	for frame: int in IDLE_FRAMES: await process_frame
	var delta: int = int(board.get("_full_dynamic_redraw_count")) - count
	print("RD06 IDLE: %d full redraws / %d frames" % [delta, IDLE_FRAMES])
	_check(delta == 0, "Idle must retain full board commands")
	await scene.call("_on_card_pressed", 0)
	for frame: int in SETTLE_FRAMES: await process_frame
	var refreshed: Dictionary = _snapshot()
	_tint_controls(board)
	print("RD06 REFRESHED ", refreshed)
	_check(first.get("tints") == refreshed.get("tints"), "First combat tint equals card-refresh tint")
	if capture:
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(OUTPUT.path_join("base" if baseline else "fix").path_join("selected.png"))
	var result := {"phase": phase, "base": baseline, "headless": DisplayServer.get_name() == "headless", "first": first, "refreshed": refreshed, "idle_frames": IDLE_FRAMES, "idle_full_redraws": delta, "failures": failures}
	var file := FileAccess.open(OUTPUT.path_join(("base" if baseline else "fix") + "_" + phase + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	if capture: print(OUTPUT.path_join("base" if baseline else "fix"))
	for failure: String in failures: push_error(failure)
	print("RD06 STALE OCCLUSION: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _first_frame() -> void:
	if not first.is_empty(): return
	var board: Control = scene.get("board_view")
	if board == null or board.combat_state.is_empty() or not board.is_visible_in_tree() or (scene.get("_run_state") as Dictionary).get("mode") != "combat": return
	if float(board.call("_tile_width")) <= STARTUP_TILE_WIDTH: return
	first = _snapshot()
	if capture: _capture_first()

func _capture_first() -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("base" if baseline else "fix")
	DirAccess.make_dir_recursive_absolute(path)
	canvas.get_texture().get_image().save_png(path.path_join("first.png"))

func _snapshot() -> Dictionary:
	var board: Control = scene.get("board_view")
	var entries: Array = board.get("_foreground_obstruction_entries_cache")
	var tints: Dictionary = {}
	var hero_entries: Array = []
	for unit: Dictionary in board.call("_visible_units"):
		if unit.key == "player": hero_entries.append({"actor_key": unit.key, "tile": board.call("_effective_unit_tile", unit), "rect": board.call("_unit_draw_rect", unit)})
	var covered_hero := false
	var actor_rects_current := true
	var hero_rect := Rect2()
	for unit: Dictionary in board.call("_visible_units"):
		var actual: Rect2 = board.call("_unit_draw_rect", unit)
		if unit.key == "player": hero_rect = actual
		var found := false
		for entry: Dictionary in entries:
			if entry.get("actor_key", "") == unit.key:
				found = true
				actor_rects_current = actor_rects_current and (entry.rect as Rect2).is_equal_approx(actual)
		actor_rects_current = actor_rects_current and found
	var grid: Array = board.combat_state.grid
	for y: int in grid.size():
		for x: int in grid[y].size():
			if grid[y][x] != "pillar": continue
			var tile := Vector2i(x, y)
			var rect: Rect2 = board.call("_prop_draw_rect", board.get("_prop_textures").get("pillar"), board.call("_prop_rect_for_tile", tile))
			if board.call("_foreground_blocker_tint_uncached", "pillar", tile, rect, hero_entries).a < 1.0: covered_hero = true
			tints[str(tile)] = board.call("_foreground_blocker_tint_uncached", "pillar", tile, rect, entries).a
	return {"actor_rects_current": actor_rects_current, "covered_hero": covered_hero, "tints": tints, "entries": entries.duplicate(true), "hero_rect": hero_rect}

func _install_briefing() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT.path_join("briefing.json")))
	assert(manifest.get("verified", false) and manifest.get("scenario") == "pre_battle")
	var run_id: String = manifest.run_id
	var source: String = str(manifest.verification.godot_home_root).path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	assert(DirAccess.copy_absolute(source.path_join("current_run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK)

func _check(value: bool, message: String) -> void:
	if not value:
		if capture and baseline and (message.begins_with("First combat tint") or message.contains("actor obstruction rectangles")):
			print("RD06 EXPECTED BASE MISMATCH: ", message)
		else: failures.append(message)

func _tint_controls(board: Control) -> void:
	# Existing overlap policy: same rectangle, earlier depth, actor vs ordinary
	# object. No pixels or new production tuning values are involved.
	var rect := Rect2(100, 100, 100, 100)
	var covered := {"tile": Vector2i(0, 0), "rect": rect}
	var actor: Dictionary = covered.duplicate()
	actor["actor_key"] = "proof_actor"
	_check(board.call("_foreground_blocker_tint_uncached", "pillar", Vector2i(1, 1), rect, [actor]) == board.PILLAR_ACTOR_OBSTRUCTION_TINT, "Existing pillar actor tint")
	_check(board.call("_foreground_blocker_tint_uncached", "terrain", Vector2i(1, 1), rect, [actor]) == board.FOREGROUND_ACTOR_OBSTRUCTION_TINT, "Existing foreground actor tint")
	_check(board.call("_foreground_blocker_tint_uncached", "pillar", Vector2i(1, 1), rect, [covered]) == board.FOREGROUND_OBSTRUCTION_TINT, "Existing ordinary prop tint")
	_check(board.call("_foreground_blocker_tint_uncached", "pillar", Vector2i(1, 1), rect, []) == Color.WHITE, "Unobstructed prop stays opaque")
	_check(board.call("_foreground_blocker_tint_uncached", "floor", Vector2i(1, 1), rect, [actor]) == Color.WHITE, "Only existing tall props fade")
