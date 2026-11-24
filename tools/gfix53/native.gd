extends SceneTree
## Render three committed combat states through the production RunScene.

const F = preload("res://tools/gfix53/fixture.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT: String = "user://gfix53"
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const PROOF_LEVEL: int = 3
const SETTLE_FRAMES: int = 3
const FRAMING_TIMEOUT_MSEC: int = 3000
const MIN_TILE_WIDTH: float = 24.0
const MIN_FLOOR_SAMPLES: int = 3
const MIN_FLOOR_LUMA: float = 0.04
const MIN_FLOOR_PIXEL_DELTA: float = 0.08
const SHADOWSTEP_ROOM := {"coord": Vector2i(2, 1), "depth": 22, "type": "guardian", "element": "shadow", "boss_id": "noctyrax"}
const SHADOWSTEP_GUARDIAN_TILE := Vector2i(7, 3)
const SUNPATH_STAGE: String = F.Combat.UMBRA_STAGE_DEEP

var _engine := F.Combat.new()
var _viewport: SubViewport
var _scene: Control
var _check_only: bool
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	if DisplayServer.get_name() == "headless":
		if not _check_only:
			push_error("GFIX-53 NATIVE requires a real renderer. Use native.sh --dry-run for headless checks.")
			quit(1)
			return
		# Headless Godot needs a frame boundary for RunScene's deferred work.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	_expect(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Cel Look is all")
	Settings.set_storage_path("user://gfix53_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://gfix53_profile.json")
	Store.set_run_storage_path("user://gfix53_run.save")
	Store.save_data(_profile([]))
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = RUN_SCENE.instantiate()
	_viewport.add_child(_scene)
	await _settle()

	await _shadowstep()
	await _ghost_stride()
	await _sunpath()

	_viewport.queue_free()
	_scene = null
	_viewport = null
	await _settle()
	print("GFIX-53 NATIVE %s: 3 combat cases, 1920x1080, UI scale 100%%, %d failures" %
		["DRY RUN" if _check_only else "CAPTURE", _failures])
	quit(int(_failures != 0))

func _shadowstep() -> void:
	var layout: Dictionary = Rooms.new().generate_room(F.SEED, SHADOWSTEP_ROOM, Vector2i.ZERO)
	# Stage the blocked landing in the authored Last Watch arena. The east
	# brazier is already snuffed, so its light cannot reveal the Shade early.
	layout["player_start"] = F.HERO
	layout["enemies"][0]["pos"] = SHADOWSTEP_GUARDIAN_TILE
	layout["enemies"][1]["pos"] = F.ENEMY
	layout["guardian_braziers"][1]["lit"] = false
	layout["umbra_stage"] = F.Combat.UMBRA_STAGE_ECLIPSE
	var before: Dictionary = _engine.create_combat(F.SEED, layout, {
		"hp": F.HEALTH, "max_hp": F.HEALTH, "deck_cards": F.Data.starting_deck()
	})
	before = _engine._create_illusion(before, F.NEAR, F.ILLUSION_HEALTH)
	before = _engine._create_umbra_light_source(before, F.AWAY_LIGHT, {"radius": F.LIGHT_RADIUS})
	var shade: Dictionary = before["enemies"][1]
	var occupied: Dictionary = _engine._enemy_blocking_tiles(before, int(shade["id"]))
	_expect(_engine.effective_umbra_stage(before) == F.Combat.UMBRA_STAGE_ECLIPSE
		and not _engine.is_enemy_visible_to_player(before, shade)
		and not _engine._enemy_can_occupy_anchor(before, shade, F.NEAR, occupied)
		and _engine.is_tile_visible_to_player(before, F.SECOND)
		and _engine._enemy_can_occupy_anchor(before, shade, F.SECOND, occupied),
		"The hidden Wick Shade has a blocked closer landing and an open farther landing in Eclipse")
	var after: Dictionary = F.Rules.after_player_turn(_engine, before)
	_expect(after["battlefield_rule"]["beats_fired"] == 1 and after["enemies"][1]["pos"] == F.ENEMY,
		"Last Lamplighter's Shadowstep beat fired and the Shade stayed")
	# Reveal the same position for inspection after proving it is hidden at the beat.
	after = F.light(_engine, after, F.SECOND)
	await _show_fight(after, [], layout)
	_expect(_scene.board_view.presentation["umbra_stage"] == F.Combat.UMBRA_STAGE_ECLIPSE,
		"Shadowstep capture retains Eclipse after the Light reveal")
	var shade_in_frame: bool = _unit_is_in_frame("wick_shade", F.ENEMY)
	var guardian_in_frame: bool = _unit_is_in_frame("last_lamplighter", SHADOWSTEP_GUARDIAN_TILE)
	_expect(shade_in_frame, "The revealed Wick Shade is in frame at its original tile")
	_expect(guardian_in_frame, "Last Lamplighter is in frame")
	print("GFIX-53 NATIVE SHADOWSTEP: beat=%d, Shade=%s, stage=%s, actors in frame=%s" %
		[after["battlefield_rule"]["beats_fired"], after["enemies"][1]["pos"], _scene.board_view.presentation["umbra_stage"],
		shade_in_frame and guardian_in_frame])
	await _capture("01_shadowstep_stayed")

func _ghost_stride() -> void:
	var armed: Dictionary = F.ghost_stride(_engine)
	await _show_fight(armed, ["ghost_stride"])
	_scene._begin_player_movement_selection()
	await _settle()
	var preview: Dictionary = _scene._active_card_preview()
	var action: Dictionary = preview.get("action", {})
	_expect(_scene._movement_meter_count.text.begins_with("1/") and action.get("type") == "blink"
		and action.get("range") == 2 and _scene.board_view.move_tiles.has(F.GHOST_TARGET),
		"The 1 Movement meter and Blink 2 landing are visible together")
	print("GFIX-53 NATIVE GHOST STRIDE: %s, Blink range=%s, marked landing=%s" %
		[_scene._movement_meter_count.text, action.get("range"), _scene.board_view.move_tiles.has(F.GHOST_TARGET)])
	await _capture("02_ghost_stride_blink_2")

func _sunpath() -> void:
	var before: Dictionary = F.fight(_engine, ["long_dawn", "sunpath"], [F.unit(F.SECOND + Vector2i.DOWN)])
	before["umbra"]["stage"] = SUNPATH_STAGE
	var after: Dictionary = _engine.apply_player_action(before, F.action(_engine, before, "trapdoor"), F.SUNPATH_TARGET)
	await _show_fight(after, ["long_dawn", "sunpath"])
	var sources: Array = _scene.board_view.presentation.get("umbra_light_sources", [])
	var positions: Array = sources.map(func(source: Dictionary) -> Vector2i: return source["pos"])
	_expect(_scene.board_view.combat_state["player"]["pos"] == F.SUNPATH_TARGET
		and positions == [F.HERO, F.NEAR, F.ENEMY, F.SUNPATH_TARGET], "The 3-tile Blink resolves and the production board receives all four Light sources")
	print("GFIX-53 NATIVE SUNPATH: landing=%s, Light sources=%s" % [after["player"]["pos"], positions])
	await _capture("03_sunpath_lit_line")

func _profile(skills: Array) -> Dictionary:
	var profile: Dictionary = Store.default_data()
	profile["level"] = PROOF_LEVEL
	profile["skill_ids"] = skills
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	return profile

func _show_fight(combat: Dictionary, skills: Array, layout: Dictionary = {}) -> void:
	var run: Dictionary = Run.new().create_new_run(F.SEED, _profile(skills))
	run["mode"] = "combat"
	run["combat_state"] = combat
	run["current_room"] = layout.get("coord", Vector2i(1, 0))
	run["current_room_layout"] = layout if not layout.is_empty() else F.room(combat["enemies"])
	_scene._progression = run["progression"]
	_scene._load_run_state(run)
	_scene._close_dialogue()
	await _wait_for_combat_framing()
	await _settle()
	_expect(_viewport.size == SIZE and is_equal_approx(Typography.ui_scale(_scene), UI_SCALE)
		and _scene.board_view.is_visible_in_tree(), "Production combat board is shown at 1920x1080 and 100% UI scale")

func _wait_for_combat_framing() -> void:
	# RunScene freezes its board fit after the deferred hand layout completes.
	# A fixed number of frames can capture the provisional 1-pixel fit.
	var deadline: int = Time.get_ticks_msec() + FRAMING_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var budget: RefCounted = _scene._active_board_hud_budget()
		var centering: Tween = _scene._board_centering_tween
		if _scene._hand_layout_pending_revision < 0 and budget.key == budget.environment(_scene) \
			and (centering == null or not centering.is_running()):
			return
		await process_frame
	_expect(false, "The production combat HUD budget did not settle")

func _unit_is_in_frame(kind: String, tile: Vector2i) -> bool:
	var board: Control = _scene.board_view
	for unit: Dictionary in board._visible_units():
		if unit["type"] != kind or unit["pos"] != tile:
			continue
		var body: Rect2 = board.get_global_transform_with_canvas() * board._unit_draw_rect(unit)
		return body.has_area() and _viewport.get_visible_rect().encloses(body)
	return false

func _floor_samples() -> PackedVector2Array:
	var board: Control = _scene.board_view
	var frame: Rect2 = _viewport.get_visible_rect()
	var grid: Array = board.combat_state["grid"]
	var points := PackedVector2Array()
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		if not board._tile_drawn_as_floor(grid, tile) or not board._board_tile_is_visible_to_player(tile):
			continue
		var center: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(tile)
		if frame.has_point(center):
			points.append(center)
	return points

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(label: String) -> void:
	var board: Control = _scene.board_view
	var hero_tile: Vector2i = board.combat_state["player"]["pos"]
	var hero_in_frame: bool = _unit_is_in_frame("player", hero_tile)
	var tile_width: float = board._tile_width()
	var floor: PackedVector2Array = _floor_samples()
	var floor_in_frame: bool = tile_width >= MIN_TILE_WIDTH and floor.size() >= MIN_FLOOR_SAMPLES
	_expect(hero_in_frame, label + " has the hero's rendered bounds inside the viewport")
	_expect(floor_in_frame, label + " has in-frame visible floor tiles at combat scale")
	print("GFIX-53 FRAME %s | fit=%s | tile width=%.1f | hero in frame=%s | visible floor tiles=%d" %
		[label, board.presentation["board_fit_rect"].size, tile_width, hero_in_frame, floor.size()])
	if _check_only or not hero_in_frame or not floor_in_frame:
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != SIZE:
		_expect(false, label + " has no 1920x1080 image")
		return
	# Compare the same composition with its board canvas hidden. The backdrop
	# and HUD alone cannot satisfy the floor check.
	board.hide()
	await RenderingServer.frame_post_draw
	var backdrop: Image = _viewport.get_texture().get_image()
	board.show()
	if not _has_floor_pixels(image, backdrop, floor):
		_expect(false, label + " has no rendered floor at the sampled tile centers")
		return
	var directory: String = ProjectSettings.globalize_path(OUTPUT)
	_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Capture directory exists")
	var path: String = directory.path_join(label + ".png")
	if image.save_png(path) != OK:
		_expect(false, label + " did not save")
		return
	print(path)

func _has_floor_pixels(image: Image, backdrop: Image, floor: PackedVector2Array) -> bool:
	if backdrop == null or backdrop.get_size() != SIZE:
		return false
	var changed: int = 0
	for center: Vector2 in floor:
		var pixel := Vector2i(center)
		var shown: Color = image.get_pixelv(pixel)
		var hidden: Color = backdrop.get_pixelv(pixel)
		var delta := Vector3(shown.r - hidden.r, shown.g - hidden.g, shown.b - hidden.b)
		if shown.get_luminance() >= MIN_FLOOR_LUMA and delta.length() >= MIN_FLOOR_PIXEL_DELTA:
			changed += 1
	return changed >= MIN_FLOOR_SAMPLES

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
