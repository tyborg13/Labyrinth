extends SceneTree

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-03/feedback1/stills"
const COMBAT: String = "/private/tmp/labyrinth_codex/rd-03/feedback1/combat.json"
const DRAGON: String = "/private/tmp/labyrinth_codex/rd-03/feedback1/dragon.json"
const SETTLE_FRAMES: int = 16
const PAIR_SETTLE_SECONDS: float = 0.16
const CLIP_FRAMES: int = 90
const FPS: int = 30
const SELECT_FRAME: int = 6
const CANCEL_FRAME: int = 72
var scene: Node
var canvas: SubViewport
var samples: Array[Dictionary]
var check_only: bool = false
var clip: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	check_only = OS.get_cmdline_user_args().has("--check-only")
	clip = OS.get_environment("RD03_CLIP") == "1"
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	assert(check_only or DisplayServer.get_name() != "headless", "Native capture belongs to the design owner")
	assert(not clip or check_only or (not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == FPS), "MovieWriter must run at 30 fps")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	Fixture.install_save(COMBAT)
	canvas = Fixture.make_canvas(self)
	canvas.gui_embed_subwindows = true
	scene = Fixture.resume(self, canvas)
	await _settle()
	_validate_composition()
	if clip:
		await _movie()
	else:
		await _select("quick_stab")
		_validate_reach(1)
		await _still("01_melee_one_foe", _first_target())
		await scene.call("_on_cancel_requested")
		await _select("dull_bolt")
		_validate_reach(2)
		await _still("02_ranged_two_foes", _first_target())
		await scene.call("_on_cancel_requested")
		await _select("ember_rain")
		_validate_reach(2)
		await _still("03_area_two_foes", _first_target())
		await scene.call("_on_cancel_requested")
		await _select("dull_bolt")
		var trap: Vector2i = scene.get("_combat_state").traps[0].pos
		await _still("05_trap_choosing", trap)
		assert(str(scene.get("board_view").call("controller_tooltip_for_tile", trap)).is_empty(), "Choosing suppresses trap")
		await scene.call("_on_cancel_requested")
		await _still("06_trap_idle", trap, true)
		assert(not str(scene.get("board_view").call("controller_tooltip_for_tile", trap)).is_empty(), "Idle restores trap")
		scene.queue_free()
		await process_frame
		_install_dragon()
		scene = Fixture.resume(self, canvas)
		await _settle()
		await _select("quick_stab")
		var dragon: Vector2i = _first_enemy()
		assert((scene.call("_active_card_preview") as Dictionary).get("target_tiles", []).has(dragon), "Certified hero is beside Zekarion")
		await _still("04_zekarion_melee", dragon)
	var file := FileAccess.open(OUTPUT.path_join("movie_semantics.json" if clip else "semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"movie": clip, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "samples": samples, "size": [1920,1080], "ui_scale": 1.0}, "\t"))
	print("RD03 REAL CAPTURE: PASS (%d states, 1920x1080, 100%% UI%s)" % [samples.size(), ", headless setup only" if check_only else ""])
	quit()

func _select(card: String) -> void:
	var cards: Array = scene.call("_combat_hand_cards", scene.get("_combat_state"))
	assert(cards.has(card), "Certified card exists")
	await scene.call("_on_card_pressed", cards.find(card))
	await _settle()

func _first_target() -> Vector2i:
	var preview: Dictionary = scene.call("_active_card_preview")
	assert(not preview.get("target_tiles", []).is_empty(), "Card has valid targets")
	for enemy: Dictionary in scene.get("_combat_state").enemies:
		for tile: Vector2i in scene.call("_enemy_footprint_tiles", enemy):
			if preview.target_tiles.has(tile): return tile
	assert(false, "Card has a valid foe target")
	return Vector2i(-1, -1)

func _first_enemy() -> Vector2i:
	return scene.get("_combat_state").enemies[0].pos

func _still(label: String, tile: Vector2i, tooltip: bool = false) -> void:
	var board: Control = scene.get("board_view")
	Fixture.pointer(self, board, board.call("world_position_for_tile", tile))
	await _settle()
	await create_timer(PAIR_SETTLE_SECONDS).timeout
	if tooltip: await create_timer(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5) + 0.2).timeout
	if tooltip:
		# Build the production board-hover popup explicitly, embedded in the
		# capture viewport. OS tooltip timers do not fire for injected pointers
		# on every native backend; use the same resolver/builder and text.
		var text: String = board.call("_get_tooltip", board.call("world_position_for_tile", tile))
		assert(text.begins_with("tile-effects:"), "Idle trap hover resolves its production terrain stack")
		var popup := PopupPanel.new()
		popup.name = "RD03ProofHoverPopup"
		popup.theme_type_variation = &"TooltipPanel"
		var content: Control = board.call("_make_custom_tooltip", text) as Control
		assert(content != null)
		popup.add_child(content)
		board.add_child(popup)
		var point: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", tile)
		popup.popup(Rect2i(Vector2i(point), Vector2i(content.get_combined_minimum_size())))
		await _settle()
	if label == "05_trap_choosing":
		assert(str(board.call("_get_tooltip", board.call("world_position_for_tile", tile))).is_empty(), "Choosing trap hover opens no tooltip")
	await _pair(label, tile)

func _pair(label: String, tile: Vector2i) -> void:
	# No process tick, gameplay redraw, hover change or layout pass between
	# paired exposures. The only altered renderer properties are aim modulates.
	if not check_only: await RenderingServer.frame_post_draw
	var board: Control = scene.get("board_view")
	var frame: int = Engine.get_process_frames()
	var saved: Array[Dictionary]
	for record: Dictionary in board.get("_aim_focus").canvases.values():
		if is_instance_valid(record.canvas): saved.append({"canvas": record.canvas, "tint": record.canvas.self_modulate})
	if not check_only: _save(label + "_on")
	for record: Dictionary in saved: record.canvas.self_modulate = Color.WHITE
	if not check_only:
		RenderingServer.force_draw(false)
		_save(label + "_off")
	assert(Engine.get_process_frames() == frame, "On/off exposures share the same simulation frame")
	for record: Dictionary in saved: record.canvas.self_modulate = record.tint
	samples.append({"name": label, "tile": str(tile), "focus": board.get("_aim_focus").active, "process_frame": frame, "same_frame_pair": true})

func _save(label: String) -> void:
	var picture: Image = canvas.get_texture().get_image()
	assert(picture.get_size() == Fixture.SIZE)
	var path: String = OUTPUT.path_join(label + ".png")
	assert(picture.save_png(path) == OK)
	print(path)

func _validate_reach(expected: int) -> void:
	var board: Control = scene.get("board_view")
	var focus: RefCounted = board.get("_aim_focus")
	assert(focus.active, "Capture card has a board-target step")
	var count: int = 0
	for unit: Dictionary in board.call("_visible_units"):
		if unit.get("role", "") == "enemy" and focus.full_strength(board, unit): count += 1
	assert(count == expected, "Proof card must reach exactly %d of five foes; got %d" % [expected, count])
	print("RD03 REACH: ", count, "/5 foes")

func _validate_composition() -> void:
	var board: Control = scene.get("board_view")
	var clear: int = 0
	var behind: int = 0
	var hero_clear: bool = false
	var grid: Array = scene.get("_combat_state").grid
	for unit: Dictionary in board.call("_visible_units"):
		var pos: Vector2i = unit.pos
		var blocked: bool = false
		# Both screen-forward neighbours in the isometric grid.
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var front: Vector2i = pos + offset
			if front.y < grid.size() and front.x < grid[front.y].size() and grid[front.y][front.x] == "pillar": blocked = true
		if blocked: behind += 1
		else:
			clear += 1
			if unit.get("role", "") == "player": hero_clear = true
	assert(clear >= 3 and behind >= 1 and hero_clear, "Three clear units including hero; at least one behind pillar")
	print("RD03 COMPOSITION: ", clear, " clear including hero; ", behind, " behind pillar")

func _movie() -> void:
	var board: Control = scene.get("board_view")
	var enemies: Array = scene.get("_combat_state").enemies
	var from: Vector2 = board.call("world_position_for_tile", enemies[0].pos)
	var to: Vector2 = board.call("world_position_for_tile", enemies[1].pos)
	for frame: int in range(CLIP_FRAMES):
		if frame == SELECT_FRAME:
			var cards: Array = scene.call("_combat_hand_cards", scene.get("_combat_state"))
			await scene.call("_on_card_pressed", cards.find("dull_bolt"))
		if frame == CANCEL_FRAME: await scene.call("_on_cancel_requested")
		Fixture.pointer(self, board, from.lerp(to, clampf(float(frame - SELECT_FRAME) / float(CANCEL_FRAME - SELECT_FRAME), 0.0, 1.0)))
		if check_only: await process_frame
		else: await RenderingServer.frame_post_draw
		samples.append({"frame": frame, "draw_frame": Engine.get_frames_drawn(), "clock_usec": Clock.ticks_usec()})
		if not check_only and frame < CLIP_FRAMES - 1: await process_frame
	print("RD03 MOVIE CONTRACT: 90 consecutive frames / 30 fps = 3 seconds; select, sweep two targets, cancel")

func _install_dragon() -> void:
	# real_fixture's save installer deliberately accepts only scenario=combat.
	# Reuse its production canvas/resume, with equivalent certified dragon copies.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DRAGON))
	assert(manifest.get("verified", false) and manifest.get("scenario", "") == "dragon")
	var run_id: String = manifest.run_id
	var source: String = str(manifest.verification.godot_home_root).path_join(run_id).path_join("Library/Application Support/Escape the Umbra Parallel " + run_id)
	for name: String in ["progression.json", "current_run.save"]:
		assert(DirAccess.copy_absolute(source.path_join(name), ProjectSettings.globalize_path("user://" + name)) == OK)
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings.ui_scale = 1.0
	settings.reduced_motion = false
	Settings.save_settings(settings)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
