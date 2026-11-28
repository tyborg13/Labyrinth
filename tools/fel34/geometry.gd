extends SceneTree
## Scoped placement and Noctyrax reservation proof without a window server.

const Placement = preload("res://scripts/action_caption_placement.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const CardData = preload("res://scripts/game_data.gd")
const SurfaceCards = preload("res://scripts/surface_card_rules.gd")
const MoveAttack = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const RulesFixture = preload("res://tests/suites/battlefield_rules_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const TestViewport := Vector2i(1920, 1080)
const NIGHT_COIL: String = "Night Coil"
const TEST_ZOOM: float = 1.4
const NIGHT_COIL_EDGE_OVERLAP: float = 16.0
const NIGHT_COIL_BLOCKED_EXTRA_WIDTH: float = 32.0
const SLASH_SEED: int = 9292026
const SLASH_MOVE := Vector2i(2, 3)
const SLASH_TARGET := Vector2i(3, 3)

var _failures: int = 0
var _cases: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 4 and args[0] == "--native-noctyrax":
		await _noctyrax(args[1], int(args[2]), args[3])
		quit(0 if _failures == 0 else 1)
		return
	if args.size() == 2 and args[0] == "--write-noctyrax":
		await _noctyrax("", 0, args[1])
		quit(0 if _failures == 0 else 1)
		return
	var caption := Rect2(100, 10, 40, 20)
	var subjects := {"body": [Rect2(119, 10, 2, 20)]}
	var geometry := {"caption": caption, "subjects": subjects, "hud": [], "limits": Vector2(0, 240)}
	_expect(Placement.place(geometry)["shift"] == 32.0, "Equal-distance clear positions prefer right")
	geometry["hud"] = [Rect2(151, 10, 50, 20)]
	_expect(Placement.place(geometry)["shift"] == -32.0, "Painted HUD blocks the right candidate")
	geometry["limits"] = Vector2(95, 145)
	_expect(Placement.place(geometry) == {"shift": 0.0, "fallback": true}, "No band candidate falls back to center")
	geometry["subjects"] = {"body": [Rect2(119, 50, 2, 20)]}
	_expect(Placement.place(geometry) == {"shift": 0.0, "fallback": false}, "Clear center retains its coordinates")
	_expect(Placement.covers(caption, [Rect2(147, 10, 1, 1)]), "One pixel counts")
	_expect(not Placement.covers(caption, [Rect2(148, 10, 1, 1)]), "Touching the padded edge stays clear")
	await _noctyrax()
	print("FEL34 GEOMETRY %s cases=%d failures=%d" % ["PASS" if _failures == 0 else "FAIL", _cases, _failures])
	quit(0 if _failures == 0 else 1)

func _noctyrax(output: String = "", rank: int = 0, fixture_path: String = "") -> void:
	Store.set_storage_path("user://fel34-geometry-profile.json")
	Store.set_run_storage_path("user://fel34-geometry-run.save")
	var viewport := SubViewport.new()
	viewport.size = TestViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	var options := {"dragon_id": "noctyrax", "dragon_depth": 24}
	var fixture: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
	scene._load_run_state(fixture)
	scene._close_dialogue()
	scene._close_large_map()
	await process_frame
	await process_frame
	var state: Dictionary = fixture["combat_state"]
	var boss: Dictionary = state["enemies"][0]
	var board: Control = scene.board_view
	if not output.is_empty():
		var fixture_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		_expect(fixture_data is Dictionary, "Night Coil has the shared staging fixture")
		if fixture_data is Dictionary:
			var position: Array = fixture_data["hero_position"]
			_install_night_coil(scene, state, Vector2(float(position[0]), float(position[1])))
			await RenderingServer.frame_post_draw
			_capture_night_coil(scene, viewport, output, rank)
	else:
		await _night_coil(scene, state, fixture_path)
	if not fixture_path.is_empty():
		viewport.queue_free()
		await process_frame
		return
	board.reset_navigation()
	scene._set_action_banner("")
	scene._render_board_state(state, {}, true)
	var before: Array = scene._board_hud_obstacles(boss)
	var markers: Array = board._noctyrax_brazier_markers()
	scene._set_action_banner("%s: %s" % [scene._boss_health_name.text, boss["intent"]["name"]])
	scene._render_board_state(state, {}, true)
	var after: Array = scene._board_hud_obstacles(boss)
	var actual: Rect2 = scene.action_banner.get_global_rect().grow(4.0)
	_expect(scene.action_banner.text == boss["intent"]["name"], "Boss retains its move-only caption")
	_expect(actual in after, "Board receives the actual caption rect")
	_expect(before[1] in after and (before[1] as Rect2).encloses(actual), "The fixed Noctyrax band stays reserved")
	var next_markers: Array = board._noctyrax_brazier_markers()
	_expect(markers.size() >= 2 and markers.size() == next_markers.size(), "Fixture presents the same braziers")
	for index: int in mini(markers.size(), next_markers.size()):
		_expect(markers[index]["rect"] == next_markers[index]["rect"], "Brazier %d holds its layout" % index)
		_expect(not (board.get_global_transform_with_canvas() * (next_markers[index]["rect"] as Rect2)).intersects(actual.grow(-4.0)),
			"Brazier %d clears the label" % index)
	var held: float = scene.action_banner.offset_left
	scene._layout_action_banner()
	_expect(scene.action_banner.offset_left == held, "Ordinary HUD layout retains the caption offset")
	await _meteorfall(scene, combat, state)
	await _card_and_storm(scene, combat)
	viewport.queue_free()
	await process_frame

func _meteorfall(scene: Control, combat: RefCounted, state: Dictionary) -> void:
	var action: Dictionary = CardData.card_def("meteorfall")["actions"][0]
	var target: Vector2i = state["player"]["pos"]
	var marked: Dictionary = SurfaceCards.place_meteor_marks(combat, state.duplicate(true), action, target)
	var steps: Array[Dictionary]
	SurfaceCards.resolve_meteor_marks(combat, marked.duplicate(true), steps)
	_expect(steps.size() == 1 and not steps[0]["focus_tiles"].is_empty(), "Authored Meteorfall produces a landing step")
	if steps.size() != 1:
		return
	await scene._animate_enemy_phase_steps(marked, steps)
	var placement: Dictionary = scene.action_banner.get_meta("caption_placement", {})
	_expect(scene.action_banner.text == "Meteorfall: Impact", "Meteorfall landing uses the shared caption")
	_expect(placement.get("context", {}).get("tiles") == steps[0]["focus_tiles"], "Meteorfall protects the actual landing diamonds")

func _night_coil(scene: Control, state: Dictionary, fixture_path: String) -> void:
	var board: Control = scene.board_view
	var label: Label = scene.action_banner
	scene._set_action_banner("")
	board.set_navigation_zoom(TEST_ZOOM)
	scene._set_action_banner(NIGHT_COIL)
	var nominal := Rect2(label.position, label.size)
	nominal.position.x -= float(label.get_meta("caption_placement", {}).get("shift", 0.0))
	var hero: Dictionary = board._units_by_key(board._visible_units()).get("player", {})
	var board_to_stage: Transform2D = scene.stage_root.get_global_transform_with_canvas().affine_inverse() * board.get_global_transform_with_canvas()
	var local_body: Rect2 = board._action_caption_body_rect(hero)
	var body: Rect2 = board_to_stage * local_body
	_expect(body.has_area(), "Night Coil fixture has a rendered hero body")
	if not body.has_area(): return
	var reserve: float = scene.ACTION_BANNER_RESERVE_WIDTH
	var default_rect: Rect2 = Placement.snapshot(scene, nominal, [], reserve)["caption"]
	var body_offset: Vector2 = local_body.get_center() - board._unit_center(hero)
	var original_scale: Vector2 = board.scale
	var clear_position := Vector2.ZERO
	for fallback: bool in [false, true]:
		var goal: Vector2 = default_rect.get_center()
		if fallback:
			# Widen the rendered board in this fixture so the centered body
			# spans both edge slots in the 560-pixel band.
			var width: float = reserve - 2.0 * (default_rect.size.x + Placement.CLEARANCE) + NIGHT_COIL_BLOCKED_EXTRA_WIDTH
			board.scale.x *= maxf(1.0, width / body.size.x)
			board_to_stage = scene.stage_root.get_global_transform_with_canvas().affine_inverse() * board.get_global_transform_with_canvas()
		else:
			goal.x = default_rect.end.x - NIGHT_COIL_EDGE_OVERLAP + body.size.x * 0.5
		var position: Vector2 = board_to_stage.affine_inverse() * goal - body_offset
		_install_night_coil(scene, state, position)
		var placement: Dictionary = label.get_meta("caption_placement")
		var geometry: Dictionary = Placement.snapshot(scene, nominal, [], reserve)
		var actual := Rect2(default_rect.position + Vector2(float(placement["shift"]), 0.0), default_rect.size)
		var limits: Vector2 = geometry["limits"]
		var in_band: bool = actual.position.x >= limits.x and actual.end.x <= limits.y
		var covers: bool = Placement.covers(default_rect, geometry["subjects"]["body"])
		_expect(label.text == NIGHT_COIL and covers and in_band and fallback == bool(placement["fallback"]), "Night Coil obeys the production band and fallback")
		_expect(fallback == is_zero_approx(float(placement["shift"])), "Night Coil shifts only when it finds a slot")
		print('FEL34R1 NOCTYRAX caption="Night Coil" default_covers=%d placed_in_band=%d fallback=%d' % [int(covers), int(in_band), int(placement["fallback"])])
		if not fallback: clear_position = position
	board.scale = original_scale
	if not fixture_path.is_empty():
		var file := FileAccess.open(fixture_path, FileAccess.WRITE)
		_expect(file != null, "Write the shared Night Coil stage")
		if file != null:
			file.store_line(JSON.stringify({"hero_position": [clear_position.x, clear_position.y]}))
	else:
		_install_night_coil(scene, state, clear_position)
		await _navigation(scene, nominal, reserve)
	scene._set_action_banner("")

func _install_night_coil(scene: Control, state: Dictionary, hero_position: Vector2) -> void:
	scene._set_action_banner("")
	scene.board_view.set_navigation_zoom(TEST_ZOOM)
	scene._render_board_state(state, {"unit_world_positions": {"player": hero_position}}, true)
	scene._set_action_banner(NIGHT_COIL)

func _navigation(scene: Control, nominal: Rect2, reserve: float) -> void:
	var label: Label = scene.action_banner
	var initial: float = label.offset_left
	var placed: Dictionary = label.get_meta("caption_placement")
	var board: Control = scene.board_view
	board.reset_navigation()
	var timer: Timer = label.get_node_or_null("CaptionNavigationTimer")
	_expect(timer != null and timer.time_left > 0.0 and label.offset_left == initial, "Zoom leaves the active caption at its prior x until idle")
	if timer == null: return
	await create_timer(Placement.NAVIGATION_SETTLE_SECONDS * 0.5, true, false, true).timeout
	var limits: Rect2 = board.navigation_snapshot()["pan_limits"]
	board.set_navigation_pan(limits.position, false)
	board.set_navigation_pan(limits.end, false)
	_expect(timer.time_left > Placement.NAVIGATION_SETTLE_SECONDS * 0.5 and label.offset_left == initial, "Subsequent transforms restart the 150ms debounce")
	await timer.timeout
	await process_frame
	var centered := Rect2(label.position - Vector2(float(placed["shift"]), 0.0), label.size)
	var expected: Dictionary = Placement.place(Placement.snapshot(scene, centered, [], reserve))
	_expect(is_same(placed, label.get_meta("caption_placement")) and placed["shift"] == expected["shift"] and centered.size == nominal.size and timer.is_stopped(), "A settled transform re-places the same caption once")
	print("FEL34R1 NAVIGATION settle_ms=150")

func _capture_night_coil(scene: Control, viewport: SubViewport, output: String, rank: int) -> void:
	var label: Label = scene.action_banner
	var image: Image = viewport.get_texture().get_image()
	var filename: String = output.path_join("%02d-noctyrax-night-coil.png" % rank)
	var scrim: Control = label.get_node("ActionCaptionScrim")
	var rect: Rect2 = scrim.get_global_transform_with_canvas() * scrim.caption_scrim_rect()
	_expect(label.is_visible_in_tree() and label.text == NIGHT_COIL, "Night Coil caption is present at capture")
	_expect(image != null and image.get_size() == TestViewport and image.save_png(filename) == OK, "Native 1920x1080 Night Coil frame is saved")
	var moments := FileAccess.open(output.path_join("moments.jsonl"), FileAccess.READ_WRITE)
	_expect(moments != null, "Night Coil appends to the replay manifest")
	if moments == null: return
	moments.seek_end()
	moments.store_line(JSON.stringify({"key": "noctyrax-night-coil", "text": label.text, "frame": filename,
		"actual_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}))
	print(filename)

func _card_and_storm(scene: Control, combat: CombatEngine) -> void:
	var state: Dictionary = MoveAttack._combat_state(combat, "sidestep_slash", SLASH_TARGET, SLASH_SEED)
	var actions: Array = combat.card_play_actions("sidestep_slash", state)
	var targets: Array[Vector2i] = TypedArrays.vector2i([SLASH_MOVE, SLASH_TARGET])
	scene._combat_state = state
	scene._set_action_banner("")
	scene._render_board_state(state, {}, true)
	await scene._animate_player_card_resolution(state, "sidestep_slash", actions, targets)
	var context: Dictionary = scene.action_banner.get_meta("caption_placement", {}).get("context", {})
	var strike_tiles: Array = (context.get("tiles", []) as Array).filter(func(tile: Vector2i) -> bool: return tile != SLASH_MOVE and tile.x >= 0)
	_expect(context.get("destinations", {}).get("player") == SLASH_MOVE and SLASH_TARGET in strike_tiles, "Sidestep Slash protects both the move destination and strike target")
	_print_tiles(scene, "SIDESTEP", strike_tiles)
	state = RulesFixture.battle(combat)
	Surfaces.place(state, state["player"]["pos"], "electrified")
	Rules.install(combat, state, RulesFixture.rule("lightning_storm", {"damage": RulesFixture.TEST_DAMAGE}))
	RulesFixture.mature_fuel(state)
	var steps: Array[Dictionary]
	Rules.fire(combat, state.duplicate(true), steps)
	scene._set_action_banner("")
	scene._render_board_state(state, {}, true)
	await scene._animate_enemy_phase_steps(state.duplicate(true), steps)
	context = scene.action_banner.get_meta("caption_placement", {}).get("context", {})
	var storm_tiles: Array = context.get("tiles", [])
	_expect(not storm_tiles.is_empty() and steps.any(func(step: Dictionary) -> bool: return step.get("tiles", []) == storm_tiles), "Lightning Storm uses its resolver-owned strike tiles")
	_print_tiles(scene, "STORM", storm_tiles)
	_hidden_health(scene, state)

func _print_tiles(scene: Control, key: String, tiles: Array) -> void:
	var label: Label = scene.action_banner
	var geometry: Dictionary = Placement.snapshot(scene, Rect2(label.position, label.size), tiles, 0.0)
	var overlap: bool = Placement.covers(geometry["caption"], geometry["subjects"]["tiles"])
	_expect(not tiles.is_empty() and not overlap, key + " strike tiles clear the caption")
	print("FEL34R1 %s strike_tiles=%d covers_after=%d" % [key, tiles.size(), int(overlap)])

func _hidden_health(scene: Control, state: Dictionary) -> void:
	var board: Control = scene.board_view
	var mode: String = Settings._applied_board_health_bars
	Settings._applied_board_health_bars = Settings.BOARD_HEALTH_ALWAYS
	scene._render_board_state(state, {}, true)
	var frame: Rect2 = board._hud_health_rects_cache.get("enemy_1", Rect2())
	var visible: Array = board.action_caption_rects([])["health"]
	Settings._applied_board_health_bars = Settings.BOARD_HEALTH_CONTEXTUAL
	board.plate_visibility._entries.erase("enemy_1")
	var hidden: Array = board.action_caption_rects([])["health"]
	var caption := Rect2(frame.position, frame.size)
	var geometry := {"caption": caption, "subjects": {"health": hidden}, "hud": [], "limits": Vector2(0, TestViewport.x)}
	var placement: Dictionary = Placement.place(geometry)
	_expect(frame.has_area() and frame in visible and frame not in hidden and placement["shift"] == 0.0, "An unpainted frame alone cannot move a caption")
	print("FEL34R1 HIDDEN_HEALTH shifted=%d" % int(placement["shift"] != 0.0))
	Settings._applied_board_health_bars = mode

func _expect(condition: bool, message: String) -> void:
	_cases += 1
	if not condition:
		_failures += 1
		push_error("FEL34 " + message)
