extends SceneTree
## Release/worktree comparison. Only the fixtures and presentation clock are synthetic.
const BoardView = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Card = preload("res://scripts/card_widget.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const Run = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SIZE := Vector2i(1920, 1080)
const SEED: int = 59059
const EVENT_SEED: int = 421
const DOOR_SEEDS: Array = [81, 84, 85]
const BOARD_SIZE: int = 8
const HERO_TILE := Vector2i(3, 4)
const VICTIM_TILE := Vector2i(4, 4)
const BOSS_TILE := Vector2i(4, 2)
const SPARE_TILE := Vector2i(6, 6)
const VICTIM_KEY: String = "enemy_1"
const VICTIM_HP: int = 1
const SPARE_HP: int = 99
const SETTLE_FRAMES: int = 8
const HIT_DEADLINE_FRAMES: int = 360
const STRIP_STEP: int = 2
const TAIL_SECONDS: float = 0.50
const SHORT_CAPTION: String = "Stonewake"
const LONG_CAPTION: String = "Tharokh, the Worldspine: Stonewake"
const RELEASE_CAPTION_MIN_WIDTH: float = 360.0
const RELEASE_NOCTYRAX_RESERVE_WIDTH: float = 560.0
const RESERVE_OBSTACLE_MARGIN: float = 4.0
const RELEASE_TARGETLESS_BOWS: Array = ["white_silence", "revealing_glare"]

var _headless: bool
var _before: bool
var _out: String
var _scene: RunScene
var _board: BoardView
var _canvas: SubViewport
var _failures: PackedStringArray
var _semantics: Dictionary = {}
var _files: PackedStringArray
var _run_engine := Run.new()
var _combat := Combat.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_before = args.has("--before")
	_headless = DisplayServer.get_name() == "headless"
	var output_index: int = args.find("--output-dir")
	assert(output_index >= 0 and output_index + 1 < args.size(), "Provide --output-dir")
	_out = args[output_index + 1]
	assert(_headless == args.has("--dry-run"), "Use --dry-run only with the headless driver")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.set_storage_path("user://pol59_settings.json")
	Store.set_storage_path("user://pol59_profile.json")
	Store.set_run_storage_path("user://pol59_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	settings["board_health_bars"] = Settings.BOARD_HEALTH_ALWAYS
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	if not _headless: DisplayServer.window_set_size(SIZE)
	_canvas = SubViewport.new()
	_canvas.size = SIZE
	_canvas.msaa_2d = root.msaa_2d
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate() as RunScene
	_canvas.add_child(_scene)
	if _headless: process_frame.connect(_headless_draw_boundary)
	await _settle()
	_board = _scene.board_view
	_check(_canvas.size == SIZE and is_equal_approx(Typography.ui_scale(_board), 1.0), "Exact 1920×1080 SubViewport at 100% UI")
	_check(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Cel look enabled")
	await _kill_strip(false)
	await _kill_strip(true)
	await _doors()
	await _events()
	await _watermarks()
	await _captions()
	var file := FileAccess.open(_out.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"variant": "before" if _before else "after", "headless": _headless, "viewport": [SIZE.x, SIZE.y],
		"ui_scale": Typography.ui_scale(_board), "cel_look": OS.get_environment("LABYRINTH_CEL_LOOK"),
		"samples": _semantics, "images": _files, "failures": _failures
	}, "\t") + "\n")
	file.close()
	print("POL59 OUTPUT: ", _out.path_join("semantics.json"))
	print("POL59 CAPTURE: %s (%s, %d %s, %d errors)" % [
		"PASS" if _failures.is_empty() else "FAIL", "before" if _before else "after",
		_files.size(), "planned PNGs" if _headless else "PNG files", _failures.size()
	])
	_canvas.queue_free()
	await _settle()
	for failure: String in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _headless_draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _settle() -> void:
	for frame: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
		print("POL59 CHECK FAILED: ", message)

func _capture(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_files.append(path)
	if _headless: return
	var image: Image = _canvas.get_texture().get_image()
	_check(image != null and image.get_size() == SIZE, "Exact native canvas for " + name)
	if image == null: return
	_check(image.save_png(path) == OK, "Saved " + path)
	print(path)

func _grid() -> Array:
	var grid: Array = []
	for y: int in BOARD_SIZE:
		var row: Array = []
		for x: int in BOARD_SIZE:
			row.append("wall" if x in [0, BOARD_SIZE - 1] or y in [0, BOARD_SIZE - 1] else "stone")
		grid.append(row)
	return grid

func _enemy(id: int, tile: Vector2i, hp: int, type: String = "crawler") -> Dictionary:
	return {"id": id, "type": type, "pos": tile, "hp": hp, "max_hp": maxi(hp, int(Data.enemy_def(type).get("max_hp", hp))), "block": 0}

func _install_combat(seed_value: int, hand: Array, enemies: Array, grid: Array, hero_tile: Vector2i = HERO_TILE) -> Dictionary:
	var run: Dictionary = _run_engine.create_new_run(seed_value, Store.default_data())
	var layout: Dictionary = {
		"name": "Cinder Crossing", "coord": run["current_room"], "type": "combat", "element": "none",
		"grid": grid, "player_start": hero_tile, "enemies": enemies, "traps": [], "terrain": [], "loot": []
	}
	var state: Dictionary = _combat.create_combat(seed_value, layout, {
		"hp": run["player_hp"], "max_hp": run["player_max_hp"], "deck_cards": hand, "relics": [], "hand_size": hand.size()
	})
	state["deck"]["hand"] = hand.duplicate()
	state["deck"]["draw"] = []
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	_scene.call("_load_run_state", run)
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	return _scene.get("_combat_state")

func _kill_strip(meteor: bool) -> void:
	var scenario: String = "meteorfall" if meteor else "normal"
	var state: Dictionary = _install_combat(SEED, ["meteorfall"] if meteor else ["quick_stab"],
		[_enemy(1, VICTIM_TILE, VICTIM_HP), _enemy(2, SPARE_TILE, SPARE_HP)], _grid())
	if meteor:
		var action: Dictionary = _combat.card_play_actions("meteorfall", state)[0].duplicate(true)
		action["orientation"] = Vector2i.DOWN
		state = _combat.apply_player_action(state, action, VICTIM_TILE)
		_scene.set("_combat_state", state)
		_scene.get("_run_state")["combat_state"] = state
		_scene.call("_refresh_ui")
		_check(not (state.get("meteor_marks", []) as Array).is_empty(), "Meteorfall marked the live victim")
	await _settle()
	var old_pacing: Node = _scene.get("_combat_pacing")
	old_pacing.free()
	var pacing: Node = TestClock.install_pacing(_scene, Pacing)
	_scene.set("_combat_pacing", pacing)
	if meteor:
		var steps: Array[Dictionary]
		var result: Dictionary = _combat.prepare_next_player_turn(_combat.finish_player_activation(state), steps)
		_check(int(result["enemies"][0]["hp"]) <= 0, "Meteorfall turn-start resolver kills the marked victim")
		_check(steps.any(func(step: Dictionary) -> bool: return step.get("trigger") == "meteor_marks"), "Meteorfall emitted a landing presentation step")
		_scene.call("_animate_enemy_phase_steps", state.duplicate(true), steps, result)
	else:
		_scene.call("_on_card_pressed", 0)
		_scene.call("_on_board_tile_clicked", VICTIM_TILE)
	var hit: int = -1
	var end: int = -1
	var intermediate: int = 0
	var tail_frames: int = ceili(TAIL_SECONDS / TestClock.STEP_SECONDS)
	var rows: Array[Dictionary]
	for frame: int in HIT_DEADLINE_FRAMES:
		await RenderingServer.frame_post_draw
		var effect: Node = _board.get("_enemy_shadow_dissolve_effects_by_key").get(VICTIM_KEY)
		var progress: float = effect.dissolve_progress() if is_instance_valid(effect) else -1.0
		var units := _board._visible_units()
		var alpha: float = 0.0
		var bar: bool = false
		for entry: Dictionary in _board.call("_health_bar_draw_entries", units):
			var unit: Dictionary = entry["unit"]
			if unit.get("key", "") != VICTIM_KEY: continue
			bar = true
			alpha = float(_board.call("_health_bar_owner_alpha", unit)) * float(_board.call("_plate_opacity", unit))
			break
		if hit < 0 and progress >= 0.0: hit = frame
		if hit < 0: continue
		var offset: int = frame - hit
		if end < 0 and progress >= 1.0: end = offset
		if progress > 0.0 and progress < 1.0: intermediate += 1
		if progress >= 0.0:
			_check(bar and is_equal_approx(alpha, 1.0 - progress), "%s frame %d bar follows body's shader progress" % [scenario, offset])
		elif end >= 0:
			_check(not bar, "%s frame %d has no bar after body removal" % [scenario, offset])
		rows.append({"frame": offset, "body_progress": progress, "bar_alpha": alpha, "bar_entry": bar})
		if offset % STRIP_STEP == 0: _capture("%s_%03d" % [scenario, offset])
		# Keep sampling to the next even frame if the endpoint lands on an odd one.
		if end >= 0 and offset >= end + tail_frames and offset % STRIP_STEP == 0: break
	_check(hit >= 0 and end >= 0 and intermediate > 0 and rows.size() > end + tail_frames, "Complete %s strip" % scenario)
	_semantics[scenario] = {"seed": SEED, "dissolve_end_frame": end, "tail_frames": tail_frames, "samples": rows}
	print("POL59 KILL %s seed=%d dissolve-end=%d intermediate=%d post-end=%d" % [scenario, SEED, end, intermediate, rows.size() - 1 - end])
	var clock: Node = _scene.get_node_or_null("PresentationTestClock")
	if clock != null: clock.free()
	pacing.free()
	pacing = Pacing.new()
	pacing.install(_scene)
	_scene.set("_combat_pacing", pacing)
	Engine.time_scale = 1.0

func _doors() -> void:
	var rows: Array[Dictionary]
	for seed_value: int in DOOR_SEEDS:
		var door := Vector2i(4, BOARD_SIZE - 1)
		var actor := Vector2i(3, BOARD_SIZE - 2)
		var grid: Array = _grid()
		grid[door.y][door.x] = "door"
		var state: Dictionary = _install_combat(seed_value, ["quick_stab"], [_enemy(1, actor, SPARE_HP)], grid)
		await _settle()
		_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {door: Vector2i(0, 1)}, {door: "unknown"})
		await _settle()
		var texture: Texture2D = _board.call("_door_texture_for_tile", grid, door)
		var door_rect: Rect2 = _board.call("_prop_draw_rect", texture, _board.call("_door_rect_for_tile", door, grid))
		var tint: Color = _board.call("_foreground_blocker_tint_uncached", "door", door, door_rect, _board.get("_foreground_obstruction_entries_cache"))
		var reveal: Node = _board.get("_occlusion_reveal")
		_board.call("set_controller_focus_tile", actor)
		reveal._process(reveal.FADE_IN)
		await _settle()
		tint = _board.call("_occlusion_reveal_tint", "door", door, tint)
		_check(_board.exit_icon_ids.get(door) == "unknown", "Unknown room medallion is routed for the door")
		_check(tint.a < 1.0 and _board.call("_door_destination_medallion_visible", door), "Seed %d has a see-through door with a medallion" % seed_value)
		var source: String = TestClock.method_source(BoardView, "_draw_tile_stone_props")
		_check(source.contains('_draw_door_icon(icon_texture, icon_id, door_texture, draw_rect, Color(tint, 1.0))'), "The actual door draw separates medallion alpha")
		rows.append({"seed": seed_value, "door": str(door), "actor": str(actor), "door_alpha": tint.a, "medallion_alpha": 1.0})
		print("POL59 DOOR seed=%d tile=%s actor=%s door=%.2f medallion=1.00" % [seed_value, door, actor, tint.a])
		if seed_value == DOOR_SEEDS[0]: _capture("door")
	_semantics["doors"] = rows

func _events() -> void:
	var rows: Array[Dictionary]
	var template: Dictionary = _run_engine.create_new_run(EVENT_SEED, Store.default_data())
	for id: String in Data.events():
		for choice: Dictionary in Data.event_def(id).get("choices", []):
			if not (choice.get("effects", []) as Array).any(func(effect: Dictionary) -> bool: return effect.get("type") == "card_choice"):
				continue
			var choice_id: String = choice["id"]
			var state: Dictionary = EventFixture.fixture(id, true, template)
			state = _run_engine.resolve_map_event(state, choice_id)
			state = _run_engine.resolve_map_event(state, "continue")
			_check(state.get("mode") == "reward", "Reward route " + id + "/" + choice_id)
			if state.get("mode") != "reward": continue
			_scene.call("_load_run_state", state)
			await _settle()
			var reward_bar: Control = _scene.get("_relic_choice_bar")
			var skip: Button = reward_bar.find_child("RewardSkipButton", true, false) as Button
			if skip == null:
				print("POL59 MISSING EVENT SKIP ", id, " reward=", state.get("pending_reward"), " scene=", _scene.get("_run_state").get("mode"))
			_check(skip != null and skip.is_visible_in_tree() and skip.text == "SKIP", "Live SKIP for " + id + "/" + choice_id)
			if skip == null: continue
			rows.append({"event": id, "choice": choice_id, "skip": skip.text, "producer_label": state["pending_reward"].get("skip_label")})
			if rows.size() == 1: _capture("event_reward")
	_check(not rows.is_empty(), "Loaded authored event reward paths")
	_semantics["events"] = {"seed": EVENT_SEED, "samples": rows}
	print("POL59 EVENT seed=", EVENT_SEED, " ", JSON.stringify(rows))

func _watermarks() -> void:
	var hand: Array = ["searing_light", "stoke"] + RELEASE_TARGETLESS_BOWS
	var state: Dictionary = _install_combat(SEED, hand, [_enemy(1, VICTIM_TILE, SPARE_HP)], _grid())
	await _settle()
	var rows: Array[Dictionary]
	var hand_box: Control = _scene.get("hand_box")
	for card_id: String in hand:
		var definition: Dictionary = _combat.card_def(card_id, state)
		var role: String = Icons.card_role_emblem_key(definition)
		var aims: bool = _combat.card_play_actions(card_id, state).any(_combat.player_action_needs_target)
		var path: String = Icons.card_role_emblem_path(definition)
		var painted: bool = false
		for widget: Node in hand_box.find_children("*", "Control", true, false):
			if not widget is Card or widget.card_id != card_id: continue
			var emblem: Control = widget.get("_role_emblem")
			painted = emblem.is_visible_in_tree() and emblem.emblem_path == path
			break
		# Director 2026-11-23: all-enemies cards keep the bow (they reach past the next tile).
		var expected: String = "attack_ranged" if card_id in RELEASE_TARGETLESS_BOWS else "attack_melee"
		_check(not aims and role == expected, "Targetless watermark matches the expected role for " + card_id)
		_check(painted, "Live hand uses that emblem for " + card_id)
		rows.append({"id": card_id, "role": role, "path": path, "aims": aims, "hand_emblem_visible": painted})
	_semantics["watermarks"] = {"seed": SEED, "samples": rows}
	print("POL59 WATERMARK seed=", SEED, " ", JSON.stringify(rows))
	_capture("watermarks")

func _captions() -> void:
	_install_combat(SEED, ["quick_stab"], [_enemy(1, BOSS_TILE, SPARE_HP, "tharokh")], _grid())
	await _settle()
	var caption: Label = _scene.get("action_banner")
	var scrim: Control = caption.get_node("ActionCaptionScrim")
	var rows: Array[Dictionary]
	_scene.call("_set_action_banner", LONG_CAPTION)
	var long_text: String = LONG_CAPTION
	# Keep the boss's usual short caption via production prefix removal. A
	# helper's full speaker prefix is the long case.
	_check(caption.text == SHORT_CAPTION, "Boss caption uses its real move name")
	for name: String in ["short", "long"]:
		if name == "long":
			_scene.call("_set_action_banner", long_text.replace(": ", " — "))
		await _settle()
		var text_size: float = caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x
		var side_pad: float = _scene.ACTION_BANNER_SIDE_PADDING
		var wanted: float = text_size + side_pad * 2.0
		var width: float = (scrim.call("caption_scrim_rect") as Rect2).size.x
		var scrim_pad: float = (scrim.call("caption_scrim_rect") as Rect2).size.x - (scrim.call("caption_text_rect") as Rect2).size.x
		var release_width: float = maxf(RELEASE_CAPTION_MIN_WIDTH, ceilf(text_size * 0.5) * 2.0 + side_pad * 2.0)
		_check(is_equal_approx(width, (release_width if _before else wanted) + scrim_pad), "Caption shade width for " + name)
		rows.append({"case": name, "text": caption.text, "text_width": text_size, "label_width": caption.size.x, "shade_width": width, "shade_extra": scrim_pad})
		_capture("caption_" + name)
	_install_combat(SEED, ["quick_stab"], [_enemy(1, BOSS_TILE, SPARE_HP, "noctyrax")], _grid())
	await _settle()
	_scene.call("_set_action_banner", "")
	await _settle()
	var obstacles := _scene._board_hud_obstacles({"type": "noctyrax"})
	var reserve: float = obstacles[1].size.x - RESERVE_OBSTACLE_MARGIN * 2.0 if obstacles.size() >= 2 else 0.0
	_check(reserve == RELEASE_NOCTYRAX_RESERVE_WIDTH, "Noctyrax reserve floor is unchanged")
	_semantics["captions"] = {"seed": SEED, "samples": rows, "noctyrax_reserve": reserve}
	print("POL59 CAPTIONS seed=", SEED, " ", JSON.stringify(_semantics["captions"]))
