extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const VisualRect = preload("res://scripts/card_focus_tooltip_stack.gd")

const NATIVE_SIZE := Vector2i(1920, 1080)
const COMPACT_SIZE := Vector2i(1280, 800)
const UI_SCALE := 1.0
const PROOF_OVERSAMPLING := 1.0
const FRAME_RATE := 60
const CAPTURE_STRIDE := 2
const SETTLE_FRAMES := 30
const OBSERVE_FRAMES := 24
const TURN_FRAME_LIMIT := 720
const ROOM_SIDE := 8
const COMBAT_SEED := 77104
const HERO_HP := 20
const ENEMY_HP := 20
const HERO_START := Vector2i(2, 5)
const ENEMY_TILES := [Vector2i(5, 5), Vector2i(5, 4), Vector2i(4, 3), Vector2i(6, 5), Vector2i(5, 6)]
const DEFAULT_OUTPUT := "/private/tmp/labyrinth_codex/pol-61/headless-after"
const HAND := ["shadow_step", "brace", "quick_stab"]
const DRAW := ["patch_up", "lantern_shot", "shadow_step"]
const DESELECT_CARD := 0
const TURN_POINTER_CARD := 1
const PROJECTION_CARD := 1
const PROJECTION_ENEMY_FIRST_TIME := 12
const CARD_POINT_X_RATIOS := [0.5, 0.4, 0.3, 0.2, 0.6, 0.7, 0.8]

var _headless: bool
var _baseline: bool
var _output: String
var _viewport: SubViewport
var _scene: Control
var _fan: Control
var _records: FileAccess
var _failures: int = 0
var _capture: bool = true
var _pointer := Vector2.ZERO

func _initialize() -> void:
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_baseline = args.has("--baseline")
	var output_index: int = args.find("--output-dir")
	_output = args[output_index + 1] if output_index >= 0 and output_index + 1 < args.size() else DEFAULT_OUTPUT
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = FRAME_RATE
	root.size = NATIVE_SIZE
	root.content_scale_size = NATIVE_SIZE
	root.content_scale_factor = UI_SCALE
	Settings.set_storage_path("user://pol61-settings.json")
	Progression.set_storage_path("user://pol61-progression.json")
	Progression.set_run_storage_path("user://pol61-run.save")
	Progression.save_data(Tutorial.complete_tutorial(Progression.default_data()))
	Progression.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(_output)
	_records = FileAccess.open(_output.path_join("frames.jsonl"), FileAccess.WRITE)
	if _records == null:
		push_error("POL-61 could not open frame log")
		quit(1)
		return
	if not _headless:
		var cel = preload("res://scripts/cel_look.gd")
		_check(cel.mode == "all" and not cel._files.is_empty(), "Approved cel look is available")
	await _open_combat(NATIVE_SIZE)
	for method: String in ["click", "right", "escape", "board"]:
		await _deselect(method)
	await _close_combat()
	await _open_combat(NATIVE_SIZE)
	await _pass(false)
	await _close_combat()
	_capture = false
	await _open_combat(NATIVE_SIZE, 1, true)
	await _pass(true)
	await _close_combat()
	await _open_combat(NATIVE_SIZE)
	await _relayouts()
	await _close_combat()
	_capture = true
	await _open_combat(NATIVE_SIZE, 5)
	await _projection("projection_1920")
	await _close_combat()
	_capture = false
	await _open_combat(COMPACT_SIZE, 5)
	await _projection("projection_1280")
	await _close_combat()
	_records.close()
	print("POL-61 %s %s: %d fixture failures" % [
		"BASELINE" if _baseline else "AFTER", "HEADLESS" if _headless else "NATIVE", _failures])
	print("Frame trace: ", _output.path_join("frames.jsonl"))
	quit(0 if _failures == 0 else 1)

func _open_combat(dimensions: Vector2i, enemy_count: int = 1, reduced_motion: bool = false) -> void:
	_pointer = Vector2.ZERO
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = reduced_motion
	Settings.save_settings(settings)
	_viewport = SubViewport.new()
	_viewport.size = dimensions
	_viewport.oversampling_override = PROOF_OVERSAMPLING
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	_fan = _scene.get("hand_box")
	await _wait_frames(SETTLE_FRAMES)
	_scene.call("_close_dialogue")
	var grid: Array = []
	for y: int in range(ROOM_SIDE):
		var row: Array = []
		for x: int in range(ROOM_SIDE):
			row.append("wall" if x in [0, ROOM_SIDE - 1] or y in [0, ROOM_SIDE - 1] else "stone")
		grid.append(row)
	var enemies: Array[Dictionary]
	for index: int in range(enemy_count):
		enemies.append({"id": index + 1, "type": "crawler", "pos": ENEMY_TILES[index], "hp": ENEMY_HP, "max_hp": ENEMY_HP, "block": 0})
	var room: Dictionary = {
		"name": "POL-61 Proof", "coord": Vector2i(4, 1), "type": "combat",
		"grid": grid, "player_start": HERO_START, "enemies": enemies, "loot": [],
	}
	var state: Dictionary = Combat.new().create_combat(COMBAT_SEED, room, {
		"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": HAND + DRAW, "relics": [], "hand_size": HAND.size(),
	})
	state["objective"] = {"type": "kill_all"}
	state["draw_per_turn"] = 2
	state["deck"]["hand"] = HAND.duplicate()
	state["deck"]["draw"] = DRAW.duplicate()
	state["deck"]["discard"] = []
	if enemy_count == ENEMY_TILES.size():
		for entry: Dictionary in state["turn_queue"]:
			if entry.get("kind") == "enemy":
				entry["time"] = PROJECTION_ENEMY_FIRST_TIME + int(entry["enemy_id"])
	var run: Dictionary = _scene.get("_run_state")
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["combat_state"] = state.duplicate(true)
	_scene.set("_combat_state", state)
	_scene.call("_refresh_ui")
	await _wait_frames(SETTLE_FRAMES)
	_check(_fan.get_child_count() == HAND.size(), "Real combat hand is provisioned")
	_check(_scene.call("_reduced_motion_enabled") == reduced_motion, "Reduced-motion fixture applied")

func _close_combat() -> void:
	_viewport.queue_free()
	await _wait_frames(2)

func _deselect(method: String) -> void:
	var name: String = "deselect_" + method
	_move(_card_point(DESELECT_CARD))
	await _wait_frames(SETTLE_FRAMES)
	_check(int(_scene.get("_hovered_card_index")) == DESELECT_CARD, name + " has a hovered card")
	_click(_pointer)
	await _wait_frames(SETTLE_FRAMES)
	_check(int(_scene.get("_selected_card_index")) == DESELECT_CARD, name + " has a selected card")
	if method == "board":
		var board: Control = _scene.get("board_view")
		_move(board.get_global_rect().get_center())
		await _wait_frames(2)
	_record(name, -1)
	await _capture_frame(name, 0, "selected")
	match method:
		"click": _click(_pointer)
		"right", "board": _click(_pointer, MOUSE_BUTTON_RIGHT)
		"escape": _escape()
	for frame: int in range(OBSERVE_FRAMES):
		await _next_frame()
		_record(name, frame)
		await _capture_frame(name, frame)
	_check(int(_scene.get("_selected_card_index")) == -1, name + " deselection reached production input")

func _pass(reduced: bool) -> void:
	var name: String = "pass_reduced" if reduced else "pass"
	var point: Vector2 = _card_point(TURN_POINTER_CARD)
	var pass_button: Button = _scene.find_child("PassPreviewChip", true, false)
	_move(pass_button.get_global_rect().get_center())
	await _wait_frames(3)
	_record(name, -1)
	await _capture_frame(name, 0, "ready")
	_click(_pointer)
	_check(bool(_scene.get("_animation_lock")), name + " clicked the real Pass button")
	_move(point)
	var unlocked: int = -1
	var saw_cache: bool = false
	var cache: RefCounted = _scene.get("_locked_hand_render_cache")
	for frame: int in range(TURN_FRAME_LIMIT):
		await _next_frame()
		_record(name, frame)
		var locked: bool = _scene.get("_animation_lock")
		if not locked and unlocked < 0: unlocked = frame
		if cache.get("active"):
			saw_cache = true
			_check(_cache_tints_match(cache), "Cache snapshots match the live hand on frame %d" % frame)
		await _capture_frame(name, frame)
		if unlocked >= 0 and frame - unlocked >= OBSERVE_FRAMES:
			break
	_check(unlocked >= 0, name + " returns control")
	_check(_fan.get_child_count() > HAND.size(), name + " dealt new cards")
	if not _headless: _check(saw_cache, name + " exercised the real cache swap")

func _relayouts() -> void:
	# The fixture changes deck contents, while the production refresh lays out
	# the real hand under an unchanged input endpoint.
	_move(_card_point(TURN_POINTER_CARD))
	await _wait_frames(SETTLE_FRAMES)
	var state: Dictionary = _scene.get("_combat_state")
	var deck: Dictionary = state["deck"]
	for name: String in ["draw", "discard"]:
		_record(name, -1)
		if name == "draw":
			deck["hand"].append(deck["draw"].pop_front())
		else:
			deck["discard"].append(deck["hand"].pop_front())
		(_scene.get("_run_state") as Dictionary)["combat_state"] = state.duplicate(true)
		_scene.call("_mark_combat_preview_state_changed")
		_scene.call("_refresh_ui", false, true, true)
		for frame: int in range(OBSERVE_FRAMES):
			await _next_frame()
			_record(name, frame)
	# Leaving through an actual targetless play with both clicks through input.
	_move(_card_point(0))
	await _wait_frames(SETTLE_FRAMES)
	_click(_pointer)
	await _wait_frames(SETTLE_FRAMES)
	_check(int(_scene.get("_selected_card_index")) == 0, "Play fixture selected Brace")
	_record("play", -1)
	_click(_pointer)
	_move(_card_point(1))
	var unlocked: int = -1
	for frame: int in range(TURN_FRAME_LIMIT):
		await _next_frame()
		_record("play", frame)
		if not _scene.get("_animation_lock") and unlocked < 0: unlocked = frame
		if unlocked >= 0 and frame - unlocked >= OBSERVE_FRAMES: break
	_check(_fan.get_child_count() == HAND.size() - 1, "Played card left the real hand")

func _projection(name: String) -> void:
	_record(name, -1)
	await _capture_frame(name, 0, "rest")
	_move(_card_point(PROJECTION_CARD))
	for frame: int in range(OBSERVE_FRAMES):
		await _next_frame()
		_record(name, frame)
		await _capture_frame(name, frame)
	_check(int(_scene.get("_hovered_card_index")) == PROJECTION_CARD, name + " hovered the intended card")
	_check(not _projected_rects().is_empty(), name + " has a painted projection")
	_check((_scene.get("_combat_state")["enemies"] as Array).size() == 5, name + " has five enemies")

func _cache_tints_match(cache: RefCounted) -> bool:
	var watched: Array = cache.get("_appearance_watched")
	var snapshots: Array = cache.get("_appearance_snapshots")
	if watched.size() != snapshots.size() or watched.is_empty(): return false
	for index: int in range(watched.size()):
		var item: CanvasItem = watched[index]
		if not item.modulate.is_equal_approx(snapshots[index][0]): return false
	return true

func _record(name: String, frame: int) -> void:
	var widgets: Array[Dictionary]
	var cache: RefCounted = _scene.get("_locked_hand_render_cache")
	for index: int in range(_fan.get_child_count()):
		var card: Control = _scene.call("_hand_card_control", index)
		if card == null: continue
		var slot: Control = _fan.get_child(index)
		widgets.append({
			"id": card.get("card_id"), "control": card.get_instance_id(), "visible": card.is_visible_in_tree(),
			"modulate": _color(card.modulate), "slot_modulate": _color(slot.modulate),
		})
	var proxies: Array[Array]
	for proxy: Control in _scene.get("_draw_hand_transition_proxies"):
		proxies.append(_color(proxy.modulate))
	var objective: Control = _scene.get("_combat_objective_hud")
	var rail: Control = _scene.get("_turn_order_panel")
	var strip: Control = _scene.get("_turn_order_landing_strip")
	var sprite: Sprite2D = cache.get("_texture")
	_records.store_line(JSON.stringify({
		"case": name, "frame": frame, "point": [_pointer.x, _pointer.y],
		"selected": _scene.get("_selected_card_index"), "hovered": _scene.get("_hovered_card_index"),
		"lifted": _fan.call("emphasized_index"), "strength": _fan.call("emphasis_strength"),
		"under": _scene.call("_hand_index_under_pointer"), "allowed": _scene.call("_hand_pointer_hover_allowed"),
		"sliding": _fan.call("is_sliding"), "locked": _scene.get("_animation_lock"),
		"pending_layout": _scene.get("_hand_layout_pending_revision"),
		"proxy_count": (_scene.get("_draw_hand_transition_proxies") as Array).size(),
		"cache": cache.get("active"), "cache_first_draw": cache.get("_first_capture_draw"),
		"cache_tints_match": _cache_tints_match(cache) if cache.get("active") else null,
		"cache_sprite_modulate": _color(sprite.modulate) if sprite != null else [],
		"cards": widgets, "proxies": proxies, "objective": _rect(objective.get_global_rect()), "rail": _rect(rail.get_global_rect()),
		"projected": _projected_rects(), "landing_strip": _rect(strip.get_global_rect()) if is_instance_valid(strip) and strip.visible else [],
	}))

func _projected_rects() -> Array[Array]:
	var rects: Array[Array]
	var rail: Control = _scene.get("_turn_order_panel")
	for descendant: Node in rail.find_children("*", "Control", true, false):
		if not str(descendant.get_meta("turn_order_projection_card_name", "")).is_empty() and (descendant as Control).is_visible_in_tree():
			rects.append(_rect(VisualRect._visual_global_rect(descendant)))
	return rects

func _card_point(index: int) -> Vector2:
	var card: Control = _scene.call("_hand_card_control", index)
	for ratio: float in CARD_POINT_X_RATIOS:
		var point: Vector2 = card.get_global_transform_with_canvas() * (card.size * Vector2(ratio, 0.5))
		if _fan.call("card_index_at_point", point) == index:
			return point
	return VisualRect._visual_global_rect(card).get_center()

func _move(point: Vector2) -> void:
	_pointer = point
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_viewport.push_input(event, true)

func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)

func _escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		_viewport.push_input(event, true)

func _next_frame() -> void:
	await process_frame
	if _headless:
		# The headless renderer never sends the draw signal awaited by the
		# real enemy round. Advance that boundary without replacing the round.
		RenderingServer.frame_post_draw.emit()
	else:
		await RenderingServer.frame_pre_draw

func _wait_frames(count: int) -> void:
	for frame: int in range(count): await _next_frame()

func _capture_frame(name: String, frame: int, part: String = "frame") -> void:
	if not _capture or frame % CAPTURE_STRIDE != 0: return
	var path: String = _output.path_join("%s_%s_%04d.png" % [name, part, frame])
	if _headless:
		print("Capture planned: ", path)
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_check(image != null and image.get_size() == NATIVE_SIZE, "Exact-size capture " + path)
	if image != null and image.get_size() == NATIVE_SIZE:
		_check(image.save_png(path) == OK, "Saved " + path)
		print(path)

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _color(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("POL-61 fixture: " + message)
