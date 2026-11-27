extends SceneTree
## Compare production board paint operations headless, or capture the same
## states in the native renderer. Instrumentation delegates real draws intact.

const Fixtures = preload("res://tools/fel11/fixtures.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const READY_TIMEOUT_MSEC: int = 10000
const SETTLE_FRAMES: int = 3
const EXPECTED_ROOM_EXITS: int = 3
const NO_TILE := Vector2i(-1, -1)
const MARK_OPERATIONS := [
	"_draw_exit_tile_pulse", "_draw_objective_exit_ring", "_draw_objective_exit_icon",
	"_draw_controller_door_pulse", "_draw_controller_door_chevron",
]

var fixtures := Fixtures.new()
var view: SubViewport
var scene: Node
var board: Control
var revision: String
var output: String
var native: bool
var failures: Array[String]
var controls: Dictionary = {}
var reference: Dictionary = {}
var capture_count: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	native = DisplayServer.get_name() != "headless"
	revision = OS.get_environment("FEL11_REVISION")
	if revision.is_empty(): revision = "branch"
	output = OS.get_environment("FEL11_OUTPUT")
	if output.is_empty(): output = "user://fel11"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path: String = output.path_join("base-controls.dat")
	if revision == "branch" and FileAccess.file_exists(path):
		reference = FileAccess.open(path, FileAccess.READ).get_var()
	_setup_view()
	if await _setup_scene():
		var source: Dictionary = fixtures.pre_battle()
		var opened: Dictionary = fixtures.snare(source)
		await _snare_cases(opened)
		await _victory_case(opened)
		await _ordinary_controls(fixtures.ordinary_states(source))
	if revision == "base":
		var file := FileAccess.open(path, FileAccess.WRITE)
		_expect(file != null, "Baseline paint operations are writable")
		if file != null: file.store_var(controls)
	view.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("FEL11 %s %s: %d failures, %d PNGs" % [revision.to_upper(), "NATIVE" if native else "HEADLESS", failures.size(), capture_count])
	quit(0 if failures.is_empty() else 1)

func _setup_view() -> void:
	Settings.set_storage_path("user://fel11-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	view = SubViewport.new()
	view.size = SIZE
	view.gui_embed_subwindows = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

func _setup_scene() -> bool:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	board = scene.get_node("BoardUnderlay/CombatBoard")
	var base_dir: String = OS.get_environment("FEL11_BASE_DIR")
	var board_path: String = "res://scripts/combat_board_view.gd"
	if revision == "base":
		var base_run: GDScript = load(base_dir.path_join("run_scene.gd"))
		if base_run == null or not base_run.can_instantiate():
			_expect(false, "Staged baseline run scene compiles")
			scene.free()
			return false
		scene.set_script(base_run)
		board_path = base_dir.path_join("combat_board_view.gd")
	var painter := GDScript.new()
	painter.resource_path = "res://tools/fel11/proof_board.gd"
	painter.source_code = "extends %s\n" % JSON.stringify(board_path) + """
var sampling_door: bool
var door_paint: Array = []

func _draw_world_texture(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE, profile: int = CombatArtTreatment.PROP, source: Rect2 = Rect2()) -> void:
	if sampling_door:
		door_paint.append(["body", texture.resource_path, rect, tint, profile, source])
	else:
		super._draw_world_texture(texture, rect, tint, profile, source)

func _draw_rect_ground_shadow(tile: Vector2i, rect: Rect2, width_scale: float, height_scale: float, cast_scale: float) -> void:
	if not sampling_door: super._draw_rect_ground_shadow(tile, rect, width_scale, height_scale, cast_scale)

func _draw_door_icon(icon_texture: Texture2D, icon_id: String, texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if sampling_door:
		door_paint.append(["medallion", icon_id, rect, tint])
	else:
		super._draw_door_icon(icon_texture, icon_id, texture, rect, tint)
"""
	if painter.reload() != OK:
		_expect(false, "Door paint observer compiles")
		scene.free()
		return false
	board.set_script(painter)
	view.add_child(scene)
	await process_frame
	return true

func _load(state: Dictionary) -> void:
	scene._load_run_state(state)
	if scene._dialogue_active: scene._close_dialogue()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_expect(view.size == SIZE and is_equal_approx(Typography.ui_scale(scene), UI_SCALE), "Viewport is 1920x1080 at 100%")

func _snare_cases(opened: Dictionary) -> void:
	var battle: Dictionary = opened["combat_state"]
	var exits: Array = battle["objective"]["exits"]
	var jailer: Dictionary = exits[0]
	var timed: Dictionary = exits[1]
	_expect(exits.size() == Fixtures.SNARE_EXIT_COUNT and jailer["role"] == "jailer" and timed["role"] == "sealing", "Natural Snare formation has a jailer and one timed exit")
	await _load(opened)
	var open_timed: Dictionary = _marks(timed)
	var open_jailer: Dictionary = _marks(jailer)
	_expect(_open_marks(open_timed) and _open_marks(open_jailer), "Both exits have active membership, gold fill, pulse, medallion, ring and icon")
	_expect(_chip(timed) == "Seals · %d" % int(timed["seal_after_player_turns"]), "Timed open exit has its real countdown")
	_control("timed_open", open_timed)
	_control("jailer_open", open_jailer)
	await _capture("snare-open")

	var sealed: Dictionary = fixtures.after_deadline(opened, false)
	var objective: Dictionary = sealed["combat_state"]["objective"]
	_expect(objective["exits"][1]["sealed"] and objective["player_turns_completed"] == timed["seal_after_player_turns"], "Actual player/enemy rounds reach the seal")
	_expect(fixtures.combat.is_player_turn(sealed["combat_state"]), "Seal proof is the next player turn")
	await _load(sealed)
	var sealed_marks: Dictionary = _marks(timed)
	_expect(sealed_marks["body"] and sealed_marks["tint"] == board.SNARE_SEALED_DOOR_MODULATE, "Sealed boundary retains the dark Umbra body")
	_expect(not sealed_marks["medallion"] and _chip(timed).is_empty(), "Sealed exit has no medallion or chip")
	_expect(sealed_marks["threshold_fills"] == [Color(Palette.UMBRA, 0.30)] and sealed_marks["threshold_fx"].is_empty(), "Sealed threshold retains only the violet fill")
	var false_door_marks: bool = sealed_marks["gold"] and sealed_marks["pulse"] and sealed_marks["chevron"]
	if revision == "base":
		_expect(false_door_marks and sealed_marks["marked"] and sealed_marks["active"], "Baseline reproduces the sealed door's gold/pulse/controller chevron and active membership")
	else:
		_expect(not sealed_marks["gold"] and not sealed_marks["pulse"] and not sealed_marks["chevron"] and not sealed_marks["marked"] and not sealed_marks["active"], "Sealed door has no exit paint or active membership")
	_control("jailer_after_seal", _marks(jailer))
	await _capture("snare-sealed")
	await _map_case(opened, sealed, timed, jailer)
	print("FEL11 sealed boundary: gold=%s pulse=%s chevron=%s active=%s violet=%s" % [sealed_marks["gold"], sealed_marks["pulse"], sealed_marks["chevron"], sealed_marks["active"], sealed_marks["threshold_fills"]])

	var kept: Dictionary = fixtures.after_deadline(opened, true)
	_expect(kept["combat_state"]["objective"]["exits"][1]["kept_open"] and not kept["combat_state"]["objective"]["exits"][1]["sealed"], "Sealbinder death keeps its exit open past the deadline")
	await _load(kept)
	var kept_marks: Dictionary = _marks(timed)
	_expect(_open_marks(kept_marks) and _chip(timed).is_empty(), "Kept-open door retains its marks and loses its countdown")
	_control("kept_open", kept_marks)

func _map_case(opened: Dictionary, sealed: Dictionary, timed: Dictionary, jailer: Dictionary) -> void:
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test("controller", "xbox")
	scene._open_large_map()
	var panel: Control = scene._large_map_view
	var coord: Vector2i = timed["coord"]
	var jailer_coord: Vector2i = jailer["coord"]
	panel.set_run_state(opened)
	_expect(panel.can_activate_room(coord) and panel.can_activate_room(jailer_coord), "Map offers either open destination before the seal")
	panel.set_run_state(sealed)
	await process_frame
	var button: Control = panel.node_buttons.get(coord)
	_expect(button != null and button.is_visible_in_tree(), "Sealed destination remains visible for inspection")
	if button != null: button.grab_focus()
	await process_frame
	scene._refresh_large_map_navigation_hint()
	var action: String = panel.controller_action_label()
	var baseline: bool = revision == "base"
	_expect(panel.can_activate_room(coord) == baseline and action == ("Show exit" if baseline else "Inspect"), "Map action follows the current exit state even if the room data is unchanged")
	_expect(button != null and button.actionable == baseline, "Map node advertises the same availability as the action")
	_expect(panel.can_activate_room(jailer_coord), "Jailer destination remains actionable")
	await _capture("sealed-destination-map")
	await panel.activate_room(coord)
	_expect(scene._large_map_scrim.visible != baseline, "Only the baseline can activate Show exit for the sealed destination")
	if baseline: _expect(scene._hovered_board_tile == timed["door_tile"], "Baseline action highlights the sealed door")
	else:
		await panel.activate_room(jailer_coord)
		_expect(not scene._large_map_scrim.visible and scene._hovered_board_tile == jailer["door_tile"], "Jailer action still highlights the open door")
	print("FEL11 sealed map destination: %s" % action)
	scene._close_large_map()
	router.clear_forced_state_for_test()

func _victory_case(opened: Dictionary) -> void:
	var poised: Dictionary = fixtures.before_exit_step(opened)
	await _load(poised)
	var exits: Array = poised["combat_state"]["objective"]["exits"]
	var selected: Dictionary = exits[0]
	var other: Dictionary = exits[1]
	var overlay: Control = scene._post_combat_victory_overlay
	scene._begin_player_movement_selection()
	_expect(scene._player_movement_target_tiles.has(selected["target_tile"]), "The real movement selector offers the threshold")
	scene._commit_player_movement(selected["target_tile"])
	_expect(await _until(func() -> bool: return overlay.visible), "Live victory overlay appears")
	_expect(scene._run_state["mode"] == "combat", "First VICTORY frame precedes reward installation")
	_post_win_marks("VICTORY first frame", selected, other)
	scene._refresh_stage_view()
	_post_win_marks("VICTORY stage refresh", selected, other)
	var row_ready := func() -> bool:
		var row: Control = scene.find_child("RewardCardRow", true, false)
		return scene._run_state["mode"] == "reward" and row != null and row.is_visible_in_tree() and not scene._animation_lock
	_expect(await _until(row_ready), "Production reward reveal completes")
	var reward: Dictionary = scene._run_state
	var pending: Dictionary = reward.get("pending_escape", {})
	if pending.is_empty():
		_expect(false, "Production finish_combat records the pending escape")
		return
	var won: Dictionary = pending["board_state"]
	_expect(fixtures.combat.combat_outcome(won) == "victory" and fixtures.combat.snare_escape_context(won)["doors_open_at_escape"] == Fixtures.SNARE_EXIT_COUNT, "A legal threshold step wins with both doors open")
	_post_win_marks("reward", selected, other)
	await _capture("escape-reward")

	var escape: Dictionary = fixtures.engine.skip_reward_for_heal(reward)
	_expect(escape["mode"] == Fixtures.Run.MODE_ESCAPE and escape["pending_escape"]["board_state"] == won, "Reward skip retains the saved combat board")
	# Observe escape before the production continuation starts opening the door.
	scene._run_state = escape
	scene._sync_combat_state_from_run()
	scene._refresh_stage_view()
	_post_win_marks("escape", selected, other)
	scene._continue_pending_escape_after_reward()
	var door: Vector2i = selected["door_tile"]
	_expect(await _until(func() -> bool: return board._door_opening_texture_for_tile(board.combat_state["grid"], door) != null), "Opening sheet plays for the selected door")
	var opening: Dictionary = _marks(selected)
	_expect(opening["body"] and not opening["medallion"], "Opening frame replaces the selected closed body and medallion")
	_control("opening_door", opening)
	_expect(await _until(func() -> bool: return scene._run_state["current_room"] == pending["destination"] and not scene._escape_transition_in_progress), "Live escape completes")
	var continued: Dictionary = scene._run_state
	_expect(continued["current_room"] == pending["destination"] and continued["pending_escape"].is_empty(), "Continuation reaches the selected destination and clears pending escape")
	print("FEL11 continuation: door=%s destination=%s mode=%s" % [pending["door_tile"], continued["current_room"], continued["mode"]])

func _post_win_marks(label: String, selected: Dictionary, other: Dictionary) -> void:
	var kept: Dictionary = _marks(selected)
	var alternative: Dictionary = _marks(other)
	_expect(_open_marks(kept), label + " keeps the selected door and threshold marks")
	if revision == "base":
		_expect(alternative["gold"] and alternative["pulse"] and alternative["medallion"] and not alternative["threshold_fx"].is_empty(), label + " reproduces painted unselected exit")
	else:
		_expect(alternative["body"] and alternative["tint"] == Color.WHITE and not alternative["active"] and alternative["locked"], label + " presents the unselected exit as a plain locked door")
		_expect(not alternative["gold"] and not alternative["pulse"] and not alternative["marked"] and not alternative["medallion"] and not alternative["chevron"] and _chip(other).is_empty(), label + " removes alternative boundary markers")
		_expect(alternative["threshold_fills"].is_empty() and alternative["threshold_fx"].is_empty(), label + " removes all alternative threshold markers")
	print("FEL11 %s alternative: gold=%s pulse=%s medallion=%s threshold_fx=%s chip=%s" % [label, alternative["gold"], alternative["pulse"], alternative["medallion"], alternative["threshold_fx"], _chip(other)])

func _ordinary_controls(states: Dictionary) -> void:
	if states.is_empty():
		_expect(false, "Legacy ordinary Reach the Exit fixture exists")
		return
	await _load(states["fight"])
	var objective: Dictionary = board.combat_state["objective"]
	_expect(objective["type"] == "reach_exit" and not objective.has("special_type"), "Ordinary fight has the legacy Reach the Exit objective")
	var fight: Array[Dictionary]
	for exit: Dictionary in objective.get("exits", []):
		var marks: Dictionary = _marks(exit)
		_expect(_open_marks(marks), "Ordinary combat exit retains the full marker set")
		fight.append(marks)
	_expect(not fight.is_empty(), "Ordinary fight exercises at least one objective exit")
	_control("ordinary_reach_exit", fight)
	await _load(states["room"])
	var room: Dictionary = {}
	for tile: Vector2i in board.exit_tiles:
		var marks: Dictionary = _marks({"door_tile": tile})
		_expect(marks["gold"] and marks["pulse"] and marks["medallion"] and marks["active"] and marks["chevron"], "Ordinary room has the original active door marks")
		room[tile] = marks
	_expect(room.size() == EXPECTED_ROOM_EXITS, "Ordinary room exercises three exits")
	_control("ordinary_room", room)
	print("FEL11 controls: %d ordinary combat exits, %d ordinary room exits" % [fight.size(), room.size()])

func _marks(exit: Dictionary) -> Dictionary:
	var door: Vector2i = exit["door_tile"]
	var threshold: Vector2i = exit.get("target_tile", NO_TILE)
	var door_ops: Dictionary = _overlay(door)
	var floor_ops: Dictionary = _overlay(threshold)
	var prop: Array = _door_paint(door)
	var tint: Color = prop[0][3] if not prop.is_empty() else Color.TRANSPARENT
	return {
		"marked": board.exit_tiles.has(door),
		"active": board.presentation["active_door_tiles"].has(door),
		"locked": board.presentation["locked_door_tiles"].has(door),
		"body": not prop.is_empty(), "tint": tint, "medallion": prop.any(func(op: Array) -> bool: return op[0] == "medallion"),
		"gold": door_ops["fills"].has(board.EXIT_HIGHLIGHT), "pulse": door_ops["fx"].has("_draw_exit_tile_pulse"),
		"chevron": door_ops["fx"].has("_draw_controller_door_chevron"),
		"threshold_fills": floor_ops["fills"], "threshold_fx": floor_ops["fx"],
		"door_operations": door_ops, "prop_operations": prop,
	}

func _overlay(tile: Vector2i) -> Dictionary:
	var fills: Array[Color]
	var fx: Array[String]
	if tile.x < 0: return {"fills": fills, "fx": fx}
	var operations: Array = board._slice_operations
	var building: bool = board._slice_building
	var focus: Vector2i = board._controller_focus_tile
	var hover: Vector2i = board._hover_tile
	board._slice_operations = []
	board._slice_building = true
	board._controller_focus_tile = NO_TILE
	board._hover_tile = NO_TILE
	board._draw_tile_overlays(tile)
	for op: Array in board._slice_operations:
		if op[0] == "draw_colored_polygon":
			if op[1][1] in [board.EXIT_HIGHLIGHT, Color(Palette.UMBRA, 0.30), Color(0.15, 0.70, 0.72, 0.30)]: fills.append(op[1][1])
		elif op[0] in MARK_OPERATIONS: fx.append(op[0])
	# Use the focus paint route directly so physics of the lifted layer and
	# the current input device cannot hide an erroneous exit chevron.
	board._slice_operations = []
	board._draw_ground_focus_tile(tile, board._tile_polygon(tile), NO_TILE, tile)
	for op: Array in board._slice_operations:
		if op[0] in MARK_OPERATIONS: fx.append(op[0])
	board._controller_focus_tile = focus
	board._hover_tile = hover
	board._slice_building = building
	board._slice_operations = operations
	return {"fills": fills, "fx": fx}

func _door_paint(tile: Vector2i) -> Array:
	if not board._door_is_visible(tile): return []
	board.door_paint = []
	board.sampling_door = true
	board._draw_tile_stone_props(board.combat_state["grid"], tile, "door", [])
	board.sampling_door = false
	return board.door_paint

func _open_marks(marks: Dictionary) -> bool:
	return marks["marked"] and marks["active"] and marks["gold"] and marks["pulse"] and marks["medallion"] and marks["threshold_fx"].has("_draw_objective_exit_ring") and marks["threshold_fx"].has("_draw_objective_exit_icon")

func _chip(exit: Dictionary) -> String:
	var chip: Control = board.get_node_or_null("SnareSealChips/Door%d" % int(exit.get("sealbinder_id", -1)))
	return chip.get_node("Title").text if chip != null and chip.is_visible_in_tree() else ""

func _control(label: String, observed: Variant) -> void:
	controls[label] = observed
	if not reference.is_empty():
		_expect(observed == reference.get(label), "%s paints the same operations as baseline" % label)
		if observed == reference.get(label): print("FEL11 control matches base: " + label)

func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while not bool(condition.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(condition.call())

func _capture(label: String) -> void:
	if not native: return
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	var bitmap: Image = view.get_texture().get_image()
	var path: String = output.path_join("%s-%s.png" % [revision, label])
	_expect(bitmap.get_size() == SIZE and bitmap.save_png(path) == OK, "Native capture writes " + label)
	capture_count += 1
	print(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
