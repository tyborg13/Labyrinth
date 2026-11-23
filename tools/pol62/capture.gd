extends SceneTree
## Reproduction and native proof through the production RunScene and board.
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const AreaAim = preload("res://scripts/area_target_aim.gd")
const BoardSurfaces = preload("res://scripts/board_surface_rules.gd")
const SurfaceCards = preload("res://scripts/surface_card_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Controls = preload("res://scripts/pre_battle_controls.gd")
const LONG_NAMES: Array = ["rite_of_the_mountain", "shattered_reflection", "cinderweave_guard", "lodestone_reversal", "crimson_draught"]
const DIRECTIONS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const MODES: Array = ["pointer", "keyboard", "controller"]
const SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 16
const FIXED_FPS: int = 60
const AIM_FRAME_SAMPLES: int = 5
const PREVIEW_FRAMES: int = 40
const STRIP_INTERVAL: int = 2
const STRIP_END: int = 8
const MEASURE_COUNTS: Array = [1, 2, 10]
const NO_HIT_DISTANCE: int = 0x7fffffff
const NORTH_AIM_TARGET := Vector2i(3, 3)
const TIE_AIM_TARGET := Vector2i(6, 5)
const CRATE_TARGET := Vector2i(4, 6)
const BOX_TARGET := Vector2i(3, 5)
const OFF_TARGET := Vector2i(5, 5)
const CRATE_TILE := Vector2i(5, 6)
const BOX_TILE := Vector2i(3, 4)
const FOE_TILE := Vector2i(3, 6)
const PROOF_ROOT: String = "/private/tmp/labyrinth_codex/pol-62"

var canvas: SubViewport
var scene: Control
var board: Control
var engine: CombatEngine
var dry: bool
var output: String
var failures: int
var seed: int
var proof_root: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	dry = DisplayServer.get_name() == "headless"
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--before"):
		push_error("Run the before probe at the original POL-62 revision.")
		quit(1)
		return
	proof_root = OS.get_environment("LABYRINTH_POL62_PROOF_ROOT")
	if proof_root.is_empty(): proof_root = PROOF_ROOT
	output = proof_root.path_join("after")
	if not dry:
		_check(DirAccess.make_dir_recursive_absolute(output) == OK, "capture directory")
	_check(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "cel look is enabled")
	Engine.max_fps = FIXED_FPS
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.msaa_2d = root.msaa_2d
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	_check(canvas.size == SIZE, "exact capture viewport")
	for manifest: String in ["aim.json", "crate.json"]:
		if not FileAccess.file_exists(proof_root.path_join(manifest)):
			_check(false, "missing " + manifest + "; run native.sh --fixtures")
			quit(1)
			return
	var saved: Dictionary = Fixture.install_save(proof_root.path_join("aim.json"))
	await _resume(saved)
	await _line_openings(NORTH_AIM_TARGET)
	scene.free()
	saved = Fixture.install_save(proof_root.path_join("crate.json"))
	await _resume(saved)
	await _line_openings(TIE_AIM_TARGET)
	for mode: String in MODES:
		await _preview_sweep(mode, "crate", CRATE_TARGET, false)
		await _preview_sweep(mode, "box", BOX_TARGET, true)
	await _deck_view()
	print("POL62 %s: %s (%d failed checks)" % ["after", "PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func _resume(saved: Dictionary) -> void:
	scene = Fixture.resume(self, canvas)
	await _wait_frames(SETTLE_FRAMES)
	board = scene.get("board_view")
	engine = scene.get("_combat_engine")
	seed = int(saved["seed"])
	var state: Dictionary = scene.get("_combat_state")
	print("POL62 FIXTURE seed=%d grid=%s hero=%s enemies=%s terrain=%s" % [seed, state.get("grid", []), state["player"]["pos"], state["enemies"].map(func(enemy: Dictionary) -> Vector2i: return enemy["pos"]), state["terrain"]])
	_check(canvas.size == SIZE and is_equal_approx(Settings.load_settings()["ui_scale"], 1.0), "1920x1080, 100% UI scale")
	_check(str(scene.get("_run_state").get("mode", "")) == "combat" and not scene.get("_animation_lock"), "active production combat")
	_check(engine.is_player_turn(state), "fixture is on the player turn")

func _line_openings(capture_tile: Vector2i) -> void:
	var state: Dictionary = scene.get("_combat_state")
	var empty: Dictionary = state.duplicate(true)
	empty["enemies"] = []
	var volt: Dictionary = Data.card_def("volt_surge")["actions"][0]
	var empty_centers: Array[Vector2i] = engine.valid_targets_for_player_action(empty, volt)
	_check(AreaAim.placement(engine, empty, empty, volt, empty_centers, Vector2i.RIGHT)["direction"] == Vector2i.RIGHT,
		"no enemy keeps the default direction")
	var hand: Array = scene.call("_combat_hand_cards", state)
	for id: String in hand:
		var card: Dictionary = Data.card_def(id)
		var action: Dictionary = {}
		for step: Dictionary in card["actions"]:
			if AreaAim.is_line(engine._aoe_pattern_offsets(step)) and engine.player_action_needs_orientation(step):
				action = step
				break
		if action.is_empty(): continue
		var scores: Array = _scores(state, action)
		var expected: Vector2i = _expected_opening(scores, action.get("orientation", Vector2i.RIGHT))
		var modes: Array = MODES if id in ["volt_surge", "molten_reach", "thunderline"] else ["pointer"]
		for mode: String in modes:
			var index: int = hand.find(id)
			var input_frame: int = await _select_card(index, mode)
			var opening: Vector2i = scene.get("_aoe_aim_orientation")
			_check(int(scene.get("_selected_card_index")) == index, "%s selected %s" % [mode, id])
			_check(opening == expected, "%s %s opening expected %s, got %s" % [mode, id, expected, opening])
			if mode == "pointer" and id in ["volt_surge", "thunderline"]:
				_point(capture_tile)
				await _wait_frames(AIM_FRAME_SAMPLES)
				_check(scene.get("_hovered_board_tile") == capture_tile, "capture targets the intended tile")
				await _capture("aim_%d_%s" % [seed, id])
			print("POL62 AIM seed=%d card=%s input=%s frame=%d direction=%s scores=%s" % [seed, id, mode, input_frame, opening, scores])
			await _cancel()

func _scores(state: Dictionary, action: Dictionary) -> Array:
	if str(action["type"]) == "surface": return _surface_scores(state, action)
	if str(action["type"]) not in ["aoe", "meteor_marks"]: return []
	var result: Array = []
	for direction: Vector2i in DIRECTIONS:
		var aimed: Dictionary = action.merged({"orientation": direction}, true)
		var best := Vector2i(0, NO_HIT_DISTANCE)
		for target: Vector2i in engine.valid_targets_for_player_action(state, aimed):
			var tiles: Array[Vector2i] = engine.aoe_tiles_for_player_action(state, aimed, target)
			var indices: Array[int] = engine._enemy_indices_in_tiles(state, tiles)
			if indices.is_empty(): continue
			var after: Dictionary = engine.surface_preview_for_player_action(state, aimed, target, true)["state"]
			if str(action["type"]) == "meteor_marks":
				var surface = SurfaceCards
				after[surface.METEOR_STATE_KEY] = [surface.meteor_marks(after).back()]
				after = surface.resolve_meteor_marks(engine, after)
			var score := Vector2i(0, NO_HIT_DISTANCE)
			for i: int in indices:
				var enemy: Dictionary = state["enemies"][i]
				var after_index: int = engine._enemy_index_for_id(after, int(enemy["id"]))
				if after_index >= 0 and int(after["enemies"][after_index]["hp"]) >= int(enemy["hp"]): continue
				score.x += 1
				for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
					if tiles.has(tile): score.y = mini(score.y, PathUtils.manhattan(state["player"]["pos"], tile))
			if score.x > best.x or (score.x == best.x and score.y < best.y): best = score
		result.append(best if best.x > 0 else Vector2i.ZERO)
	return result

func _surface_scores(state: Dictionary, action: Dictionary) -> Array:
	# POL-56 opens utility surfaces over the most targets. Direction ties
	# keep the authored orientation, independently of target proximity.
	var result: Array
	for direction: Vector2i in DIRECTIONS:
		var aimed: Dictionary = action.merged({"orientation": direction}, true)
		var most_hits: int = 0
		for target: Vector2i in engine.valid_targets_for_player_action(state, aimed):
			var tiles: Array[Vector2i]
			for tile: Vector2i in engine._surface_action_tiles(state, aimed, target):
				if BoardSurfaces.can_place(state, tile): tiles.append(tile)
			most_hits = maxi(most_hits, engine._enemy_indices_in_tiles(state, tiles).size())
		result.append(Vector2i(most_hits, 0))
	return result

func _expected_opening(scores: Array, authored: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var direction: Vector2i = authored
	for i: int in range(scores.size()):
		var score: Vector2i = scores[i]
		if score.x > best.x or (score.x > 0 and score.x == best.x
				and (score.y < best.y or (score.y == best.y and DIRECTIONS[i] == authored))):
			best = score
			direction = DIRECTIONS[i]
	return direction

func _preview_sweep(mode: String, prop: String, target: Vector2i, vertical: bool) -> void:
	var state: Dictionary = scene.get("_combat_state")
	var index: int = scene.call("_combat_hand_cards", state).find("volt_surge")
	await _select_card(index, mode)
	var pointer: bool = mode == "pointer"
	# Entering a new center now selects its own opening orientation (POL-56).
	# Settle the center before rotating to the test's clear starting axis.
	if mode == "controller": scene.call("_controller_set_board_tile", target)
	else: _point(OFF_TARGET if pointer else target)
	await _wait_frames(AIM_FRAME_SAMPLES)
	var direction: Vector2i = scene.get("_aoe_aim_orientation")
	var on_axis: bool = (direction.x == 0) == vertical
	if on_axis != pointer: _turn(mode, true)
	await _wait_frames(AIM_FRAME_SAMPLES)
	var initial: Dictionary = _preview_presence()
	_check(not initial[prop] and not initial["enemy"], "%s/%s starts clear" % [mode, prop])
	var transitions: Dictionary = {}
	var paint_transitions: Dictionary = {}
	for phase: String in ["on", "off"]:
		var expected: bool = phase == "on"
		if pointer: _point(target if expected else OFF_TARGET)
		else: _turn(mode, expected)
		var started: int = Engine.get_process_frames()
		for frame: int in range(PREVIEW_FRAMES + 1):
			if not dry: await RenderingServer.frame_post_draw
			var sample: Dictionary = _preview_presence()
			var paint: Dictionary = _queued_preview_paint()
			for key: String in [prop, "enemy"]:
				var change: String = phase + "/" + key
				if not transitions.has(change) and sample[key] == expected: transitions[change] = frame
				if not paint_transitions.has(change) and paint[key] == expected: paint_transitions[change] = frame
			if pointer and prop == "crate" and frame <= STRIP_END and frame % STRIP_INTERVAL == 0:
				await _capture("crate_%s_%02d" % [phase, frame], false)
			await process_frame
		print("POL62 PREVIEW INPUT seed=%d mode=%s prop=%s phase=%s process_frame=%d" % [seed, mode, prop, phase, started])
	print("POL62 PREVIEW seed=%d input=%s prop=%s frame_transition=%s hud_paint_plan=%s" % [seed, mode, prop, transitions, paint_transitions])
	for edge: String in ["on", "off"]:
		var enemy_frame: int = transitions.get(edge + "/enemy", -1)
		_check(enemy_frame >= 0 and enemy_frame == transitions.get(edge + "/" + prop, -2), "%s/%s %s shared preview frame" % [mode, prop, edge])
		_check(enemy_frame == paint_transitions.get(edge + "/" + prop, -2) and enemy_frame == paint_transitions.get(edge + "/enemy", -2), "%s/%s %s shared HUD submission" % [mode, prop, edge])
	await _cancel()

func _preview_presence() -> Dictionary:
	var damage: Dictionary = board.call("_damage_preview_map")
	var result: Dictionary = {"enemy": false, "crate": false, "box": false}
	for enemy: Dictionary in board.get("combat_state").get("enemies", []):
		if enemy["pos"] == FOE_TILE: result["enemy"] = damage.has("enemy_%d" % int(enemy["id"]))
	for terrain: Dictionary in board.get("combat_state").get("terrain", []):
		if terrain["pos"] == CRATE_TILE: result["crate"] = not board.call("_terrain_damage_preview", terrain).is_empty()
		if terrain["pos"] == BOX_TILE: result["box"] = not board.call("_terrain_damage_preview", terrain).is_empty()
	return result

func _queued_preview_paint() -> Dictionary:
	var result: Dictionary = {"enemy": false, "crate": false, "box": false}
	var hud: Control = board.get("_hud_render_layer")
	for layer: Control in [hud] + hud.get("_layer_slices").canvases:
		for op: Array in layer.get("_render_slice_ops"):
			if op[0] == "_draw_health_damage_preview" and op[1][0].get("pos") == FOE_TILE:
				result["enemy"] = true
			elif op[0] == "_draw_health_bar_entry" and op[1][0]["terrain"]:
				var terrain: Dictionary = op[1][0]["unit"]
				var tile: Vector2i = terrain["pos"]
				if tile == CRATE_TILE: result["crate"] = not layer.call("_terrain_damage_preview", terrain).is_empty()
				if tile == BOX_TILE: result["box"] = not layer.call("_terrain_damage_preview", terrain).is_empty()
	return result

func _deck_view() -> void:
	var run: Dictionary = scene.get("_run_state")
	scene.set("_pre_battle_preview_run_state", run)
	scene.call("_rebuild_pre_battle_overlay")
	(scene.get("_pre_battle_scrim") as Control).show()
	await _wait_frames(SETTLE_FRAMES)
	var panel: Control = scene.get("_pre_battle_panel")
	var found: Array = []
	var scroll: ScrollContainer = panel.find_child("PreBattleDeckScroll", true, false)
	for row: Node in panel.find_children("*", "Button", true, false):
		if not row.has_meta("card_id") or row.card_id not in LONG_NAMES: continue
		found.append(row.card_id)
		var label: Label = row.get_node("Name")
		_check(is_equal_approx(row.size.x, Controls.CardStrip.LIST_WIDTH) and label.is_visible_in_tree() and scroll.get_global_rect().encloses(label.get_global_rect()), "fixed strip inside the deck viewport for " + row.card_id)
		_check(label.get_theme_font_size("font_size") == 12, "expected name size for " + row.card_id)
		print("POL62 DECK seed=%d id=%s row=%.2f inner=%.2f size=%d visible=%s" % [seed, row.card_id, row.size.x, label.size.x, label.get_theme_font_size("font_size"), label.is_visible_in_tree()])
	_check(found.size() == LONG_NAMES.size(), "all five names in the production deck view: %s" % [found])
	_measure_names()
	await _capture("deck")
	(scene.get("_pre_battle_scrim") as Control).hide()
	scene.call("_open_character_overlay", "equipment")
	await _wait_frames(SETTLE_FRAMES)
	var grid: Control = (scene.get("_upgrade_dialog") as Control).find_child("CharacterDeckGrid", true, false)
	found.clear()
	for row: Node in grid.find_children("CharacterCardStrip", "Button", true, false):
		if row.card_id not in LONG_NAMES: continue
		found.append(row.card_id)
		var label: Label = row.get_node("CardBadgeName")
		_check(is_equal_approx(row.size.x, Controls.CardStrip.LIST_WIDTH), "Character row width for " + row.card_id)
		_check(label.get_theme_font_size("font_size") == 12, "Character name size for " + row.card_id)
		print("POL62 CHARACTER DECK seed=%d id=%s row=%.2f inner=%.2f size=%d" % [seed, row.card_id, row.size.x, label.size.x, label.get_theme_font_size("font_size")])
	_check(found.size() == LONG_NAMES.size(), "all five names in the Character deck")

func _measure_names() -> void:
	var row := Controls.Strip.new()
	canvas.add_child(row)
	row.size = Vector2(Controls.CardStrip.LIST_WIDTH, 30)
	var label: Label = row.get_node("Name")
	var font: Font = label.get_theme_font("font")
	var ids: Array = Data.cards().keys()
	ids.sort()
	var report: Array = []
	for id: String in ids:
		var card: Dictionary = Data.card_def(id)
		var display_name: String = str(card.get("name", id))
		var line := PackedStringArray([id, display_name])
		for font_size: int in [13, 12]:
			line.append("%.2f" % font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		for count: int in MEASURE_COUNTS:
			row.setup(id, display_name, count, {"name": display_name})
			line.append("%.2f" % label.size.x)
			line.append(str(label.get_theme_font_size("font_size")))
		report.append("\t".join(line))
	row.free()
	var path: String = output + "-widths.tsv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("ID\tName\t13 px\t12 px\tInner (single)\tSize (single)\tInner (×2)\tSize (×2)\tInner (×10)\tSize (×10)")
	for line: String in report: file.store_line(line)
	print("POL62 WIDTHS %d rows %s" % [report.size(), path])

func _select_card(index: int, mode: String) -> int:
	var input_frame: int = Engine.get_process_frames()
	if mode == "keyboard":
		_key(KEY_1 + index)
	elif mode == "controller":
		scene.set("_controller_region", "hand")
		scene.call("_controller_set_hand_focused", true)
		scene.call("_controller_set_hand_index", index)
		_joy(JOY_BUTTON_A)
	else:
		# Dispatch the same signal a card click emits. The sweep injects
		# motion into the live board's GUI handler for deterministic tile hits.
		var card: Control = scene.call("_hand_card_control", index)
		card.emit_signal("activated")
	await _wait_frames(AIM_FRAME_SAMPLES)
	return input_frame

func _turn(mode: String, positive: bool) -> void:
	match mode:
		"keyboard": _key(KEY_RIGHT if positive else KEY_LEFT)
		"controller": _joy(JOY_BUTTON_RIGHT_SHOULDER if positive else JOY_BUTTON_LEFT_SHOULDER)
		_: scene.call("_rotate_aoe_aim", 1 if positive else -1)

func _cancel() -> void:
	await scene.call("_on_cancel_requested")
	await _wait_frames(AIM_FRAME_SAMPLES)

func _point(tile: Vector2i) -> void:
	var point: Vector2 = board.call("world_position_for_tile", tile)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = board.get_global_transform_with_canvas() * point
	board.call("_gui_input", motion)

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	canvas.push_input(event, true)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	canvas.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	canvas.push_input(event, true)

func _capture(label: String, wait_for_draw: bool = true) -> void:
	var path: String = output.path_join(label + ".png")
	if not dry:
		if wait_for_draw: await RenderingServer.frame_post_draw
		var image: Image = canvas.get_texture().get_image()
		_check(image != null and image.get_size() == SIZE and image.save_png(path) == OK, "capture %s" % label)
	print(path)

func _wait_frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		print("POL62 CHECK FAILED: " + description)
