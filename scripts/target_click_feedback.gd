extends CanvasLayer
## Presentation only: never widens the engine's accepted targets.
const Path = preload("res://scripts/path_utils.gd")
const Text = preload("res://scripts/board_contour_text.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const REASON_FONT_SIZE: int = 26
const IN_SECONDS: float = 0.14
const HOLD_SECONDS: float = 0.9
const FADE_SECONDS: float = 0.28
const REASON_RISE_IN: float = 8.0
const REASON_RISE_OUT: float = 6.0
const REASON_FRONT_GAP: float = 10.0
# Director 2026-11-11: a hovered foe's intent popup can hang below its tile, so
# a reason on that tile drops under the popup, decided once at click time.
const REASON_POPUP_GAP: float = 8.0
const ATTACK_TYPES := ["melee", "ranged", "aoe", "push", "pull", "meteor_marks", "petrify", "detonate", "burst_terrain", "discharge"]
var host: Node
var reason_label: Text
var reason_tile := Vector2i(-1, -1)
var reason_started_usec: int = -1
var reason_drop: float = 0.0

func _init() -> void:
	reason_label = _notice("RejectedClickReason", REASON_FONT_SIZE)

func _notice(id: String, pixels: int) -> Text:
	var notice := Text.new()
	notice.name = id
	notice.font_size = pixels
	notice.hide()
	add_child(notice)
	return notice

func _ready() -> void:
	# Framing can move after process; sample final geometry again before drawing.
	RenderingServer.frame_pre_draw.connect(_update_labels)

func show_reason(value: String, tile: Vector2i) -> void:
	reason_label.text = value
	reason_tile = tile
	reason_drop = 0.0
	var rest: Rect2 = reason_rest_rect()
	var board: Control = host.get("board_view") if host != null else null
	var state_var: Variant = host.get("_combat_state") if host != null else null
	if board != null and state_var is Dictionary and host.has_method("_enemy_footprint_tiles"):
		for enemy: Dictionary in (state_var as Dictionary).get("enemies", []):
			if int(enemy.get("hp", 0)) <= 0 or not (host.call("_enemy_footprint_tiles", enemy) as Array).has(tile): continue
			var intent: Rect2 = board.call("enemy_intent_visual_global_rect", "enemy_%d" % int(enemy.get("id", -1)))
			if intent.has_area() and intent.intersects(rest): reason_drop = intent.end.y + REASON_POPUP_GAP - rest.position.y
	reason_started_usec = Clock.ticks_usec(false)
	_update_labels(reason_started_usec)

func _process(_delta: float) -> void:
	_update_labels()

static func reason_frame(seconds: float, reduced: bool) -> Vector2:
	# x is alpha, y is the rise relative to the rest position.
	if seconds < 0.0 or seconds >= IN_SECONDS + HOLD_SECONDS + FADE_SECONDS: return Vector2.ZERO
	if seconds < IN_SECONDS:
		var eased: float = 1.0 - pow(1.0 - seconds / IN_SECONDS, 3.0)
		return Vector2(eased, 0.0 if reduced else REASON_RISE_IN * (1.0 - eased))
	if seconds < IN_SECONDS + HOLD_SECONDS: return Vector2(1.0, 0.0)
	var eased: float = pow((seconds - IN_SECONDS - HOLD_SECONDS) / FADE_SECONDS, 2.0)
	return Vector2(1.0 - eased, 0.0 if reduced else -REASON_RISE_OUT * eased)

func _update_labels(now_usec: int = -1) -> void:
	if host == null: return
	var board: Control = host.get("board_view")
	if board == null: return
	var now: int = Clock.ticks_usec(false) if now_usec < 0 else now_usec
	var reduced: bool = bool((host.get("_settings") as Dictionary).get("reduced_motion", false))
	var reason_sample: Vector2 = reason_frame(float(now - reason_started_usec) / 1000000.0, reduced) if reason_started_usec >= 0 else Vector2.ZERO
	reason_label.position = reason_rest_rect().position + Vector2(0, reason_sample.y)
	reason_label.modulate.a = reason_sample.x
	reason_label.visible = reason_started_usec >= 0 and now - reason_started_usec < int((IN_SECONDS + HOLD_SECONDS + FADE_SECONDS) * 1000000.0)

func reason_rest_rect() -> Rect2:
	# Bind to the click's tile identity, never its pointer position. Re-project
	# its actual floor diamond each frame so board pan/zoom stay authoritative.
	if host == null: return Rect2()
	var board: Control = host.get("board_view")
	if board == null: return Rect2()
	reason_label.fit_text()
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var centre: Vector2 = transform * board.call("_tile_center", reason_tile)
	var polygon: PackedVector2Array = board.call("_tile_polygon", reason_tile)
	var front: Vector2 = transform * polygon[2]
	return Rect2(Vector2(centre.x - reason_label.size.x * 0.5, front.y + REASON_FRONT_GAP + reason_drop), reason_label.size)

static func reason(engine: RefCounted, state: Dictionary, raw_action: Dictionary, tile: Vector2i) -> String:
	if raw_action.is_empty(): return "Not a valid target"
	var action: Dictionary = engine.call("_resolved_surface_action", state, raw_action)
	var kind: String = str(action.get("type", ""))
	var origin: Vector2i = action.get("_origin_tile", state.get("player", {}).get("pos", Vector2i.ZERO))
	if not engine.call("is_tile_visible_to_player", state, tile): return "Can't see there"
	if kind in ["move", "blink", "surface"]:
		if not engine.call("_tile_is_passable", state, tile): return "Blocked"
		if kind in ["move", "blink"] and (engine.call("_player_blocking_tiles", state) as Dictionary).has(tile): return "Blocked"
	var reach: int = int(action.get("range", 0))
	if kind == "move": reach += int(engine.call("_move_bonus_for_current_turn", state))
	if action.has("range") and Path.manhattan(origin, tile) > reach:
		return "Too far" if kind in ["move", "blink"] else "Out of range"
	if kind not in ["move", "blink"] and not engine.call("combat_line_of_sight", state, origin, tile): return "No line of sight"
	if kind == "move":
		# A passable destination can still cost too much because of detours.
		var extended: Dictionary = action.duplicate(true)
		extended["range"] = (state.get("grid", []) as Array).size() * (state.get("grid", [[]])[0] as Array).size()
		if (engine.call("valid_targets_for_player_action", state, extended) as Array).has(tile): return "Too far"
		return "Blocked"
	return "Not a valid target"

static func reach_tiles(engine: RefCounted, state: Dictionary, raw_action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not str(raw_action.get("type", "")) in ATTACK_TYPES: return result
	var action: Dictionary = engine.call("_resolved_surface_action", state, raw_action)
	var origin: Vector2i = action.get("_origin_tile", state.get("player", {}).get("pos", Vector2i.ZERO))
	for tile: Vector2i in Path.diamond_tiles(origin, int(action.get("range", 0)), state.get("grid", [])):
		if engine.call("is_tile_visible_to_player", state, tile) and engine.call("combat_line_of_sight", state, origin, tile): result.append(tile)
	return result
