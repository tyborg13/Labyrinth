extends RefCounted
## Read-only end-now presentation. No resolver or scheduling state is retained.

const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const HEIGHT: float = 26.0
const HEALTH_BAR_GAP: float = 8.0
const RADIUS: int = 5
const PRIMARY_ICON_SIZE: float = 20.0
const SECONDARY_ICON_SIZE: float = 16.0
const PRIMARY_FONT_SIZE: int = 19
const SECONDARY_FONT_SIZE: int = 15
const ORDER_FONT_SIZE: int = 14
const ORDER_DIAMETER: float = 22.0
const ORDER_OVERLAP: float = 4.0
const STACK_STEP: float = 30.0
const MAX_STACK_LEVEL: int = 2
const INACTIVE_ALPHA: float = 0.55
const ISOLATED_ALPHA: float = 0.40
const HORIZONTAL_PADDING: float = 8.0
const ORDER_CONTENT_PADDING: float = 4.0
const PRIMARY_NUMBER_GAP: float = 4.0
const SECONDARY_ICON_GAP: float = 7.0
const SECONDARY_NUMBER_GAP: float = 3.0
const SECONDARY_PRIORITY: Array = ["push", "pull", "immobilize", "freeze", "chilled", "shock", "bleed", "expose", "stagger"]
const STACK_HORIZONTAL_GAP: float = 6.0
const BOSS_VISUAL_GAP: float = 8.0
const BOSS_HEADER_GAP: float = 8.0

var _cache_key: int = 0
var _cache: Dictionary = {}

func presentation_for_state(engine: RefCounted, committed: Dictionary, preview: Dictionary, focus_key: String = "", known_source: Callable = Callable()) -> Dictionary:
	var key: int = hash([committed, preview, focus_key])
	if key == _cache_key and not _cache.is_empty():
		return _cache
	_cache_key = key
	_cache = build(engine, committed, preview, focus_key, known_source.call() if known_source.is_valid() else preview)
	return _cache

static func enemy_orders(engine: RefCounted, state: Dictionary) -> Dictionary:
	var scheduled: Dictionary = engine.finish_player_activation(state) if engine.is_player_turn(state) else state
	# current_turn_order emits the queue and one follow-up per actor. Avoid its
	# ten-entry disclosure cap without adding a different clock projection.
	var limit: int = 2 * (scheduled.get("turn_queue", []) as Array).size() + 2
	var orders: Dictionary = {}
	var ordinal: int = 0
	for entry: Dictionary in engine.current_turn_order(scheduled, limit):
		if str(entry.get("kind", "")) == "player":
			break
		if str(entry.get("kind", "")) != "enemy":
			continue
		ordinal += 1
		if bool(entry.get("hidden_by_umbra", false)):
			continue
		var actor_key: String = str(entry.get("actor_key", "enemy_%d" % int(entry.get("enemy_id", -1))))
		if not orders.has(actor_key):
			orders[actor_key] = PackedStringArray()
		var values: PackedStringArray = orders[actor_key]
		values.append(str(ordinal))
		orders[actor_key] = values
	return orders

static func build(engine: RefCounted, committed: Dictionary, preview: Dictionary, focus_key: String = "", known_preview: Dictionary = {}) -> Dictionary:
	var orders: Dictionary = enemy_orders(engine, preview)
	var preview_enemies: Dictionary = {}
	for enemy: Dictionary in preview.get("enemies", []):
		preview_enemies[int(enemy.get("id", -1))] = enemy
	var badges: Array[Dictionary]
	var threats: Array[Dictionary]
	# Visibility is always the committed information boundary. A hover cannot
	# reveal a concealed enemy or use it to shape a visible attack's geometry.
	if known_preview.is_empty(): known_preview = preview
	var known_enemies: Array = known_preview.get("enemies", []) as Array
	for enemy: Dictionary in committed.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(committed, enemy):
			continue
		var id: int = int(enemy.get("id", -1))
		var projected: Dictionary = preview_enemies.get(id, {}) as Dictionary
		var intent: Dictionary = projected.get("intent", enemy.get("intent", {})) as Dictionary
		intent = preload("res://scripts/enemy_mechanics/bramble.gd").presentation_intent(known_preview, enemy, intent)
		if intent.is_empty():
			continue
		var primary: Dictionary = preload("res://scripts/enemy_mechanics/lob.gd").presentation_action(engine, known_preview, enemy, primary_action(intent))
		if primary.is_empty():
			continue
		var actor_key: String = "enemy_%d" % id
		var threat: Dictionary = {}
		for index: int in range(known_enemies.size()):
			if int((known_enemies[index] as Dictionary).get("id", -2)) == id:
				threat = engine.enemy_threat_tiles(known_preview, index)
				break
		var acting: bool = orders.has(actor_key)
		var attacking: bool = is_attack(primary)
		var cancelled: bool = projected.is_empty() or int(projected.get("hp", 0)) <= 0
		if attacking:
			cancelled = cancelled or int(projected.get("shock", 0)) > 0 or int(projected.get("freeze", 0)) > 0
			cancelled = cancelled or (threat.get("projected_attack", []) as Array).is_empty()
			# Stagger past the hero suppresses the announced attack in this preview.
			cancelled = cancelled or (committed != preview and not acting and enemy_orders(engine, committed).has(actor_key))
		var badge: Dictionary = descriptor(primary, intent)
		badge.merge({"key": actor_key, "order": "·".join(orders.get(actor_key, PackedStringArray())),
			"acting": acting, "cancelled": cancelled,
			"alpha": (1.0 if acting else INACTIVE_ALPHA) * (ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0)}, true)
		badges.append(badge)
		if attacking and acting and not cancelled:
			threats.append({"key": actor_key, "tiles": threat.get("projected_attack", []),
				"alpha": ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0})
	return {"badges": badges, "threats": threats, "hero_tile": (preview.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))}

static func primary_action(intent: Dictionary) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if is_attack(action): return action
	return Compass._primary_action(intent)

static func is_attack(action: Dictionary) -> bool:
	var kind: String = str(action.get("type", ""))
	return kind in Compass.MELEE_TYPES or kind in Compass.RANGED_TYPES or kind in Compass.AREA_TYPES or kind in ["push", "grow_bramble"]

static func descriptor(action: Dictionary, intent: Dictionary = {}) -> Dictionary:
	var kind: String = str(action.get("type", ""))
	var number: String = ""
	for field: String in ["damage", "amount", "count"]:
		if action.has(field):
			number = str(action[field])
			break
	if kind in ["lob_mark", "lob_land", "grow_bramble"]: number = str(Compass.value_for_action(action))
	var hits: int = int(action.get("hits", 1))
	if hits > 1 and not number.is_empty():
		number += "×%d" % hits
	else:
		var repeats: int = 0
		for other: Dictionary in intent.get("actions", []):
			if other == action:
				repeats += 1
		if repeats > 1 and not number.is_empty():
			number += "×%d" % repeats
	var riders: Array[Dictionary]
	for token: Dictionary in Icons.tokens_for_action(action):
		if str(token.get("icon", "")) in ["bleed", "chilled", "push", "pull", "shock", "freeze", "immobilize", "expose", "stagger"] and (str(token.get("icon", "")) != Icons.action_icon_key(action) or (kind in ["push", "pull"] and int(action.get("damage", 0)) > 0)):
			riders.append(token)
	if int(action.get("chilled", 0)) > 0: riders.append({"icon": "chilled", "value": action["chilled"]})
	var secondary: Dictionary = secondary_rider(riders)
	return {"icon": Icons.action_icon_key(action), "number": number,
		"secondary_icon": str(secondary.get("icon", "")), "secondary_number": str(secondary.get("value", "")),
		"family": "movement" if kind in Compass.MOVEMENT_TYPES else "attack" if is_attack(action) else Compass.family_for_action(action)}

static func secondary_rider(riders: Array) -> Dictionary:
	for icon: String in SECONDARY_PRIORITY:
		for rider: Dictionary in riders:
			if str(rider.get("icon", "")) == icon: return rider
	return {}

static func content_left_padding(badge: Dictionary) -> float:
	return HORIZONTAL_PADDING + (ORDER_CONTENT_PADDING if not str(badge.get("order", "")).is_empty() else 0.0)

static func plate_width(badge: Dictionary, font: Font) -> float:
	var width: float = content_left_padding(badge) + PRIMARY_ICON_SIZE + HORIZONTAL_PADDING
	var number: String = str(badge.get("number", ""))
	if not number.is_empty():
		width += PRIMARY_NUMBER_GAP + font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, PRIMARY_FONT_SIZE).x
	if not str(badge.get("secondary_icon", "")).is_empty():
		width += SECONDARY_ICON_GAP + SECONDARY_ICON_SIZE
		var secondary_number: String = str(badge.get("secondary_number", ""))
		if not secondary_number.is_empty():
			width += SECONDARY_NUMBER_GAP + font.get_string_size(secondary_number, HORIZONTAL_ALIGNMENT_LEFT, -1, SECONDARY_FONT_SIZE).x
	return width

static func boss_header_bottom(board: Control) -> float:
	var header: Rect2 = (board.get("presentation") as Dictionary).get("boss_header_global_rect", Rect2())
	if not header.has_area(): return 0.0
	var inverse: Transform2D = board.get_global_transform_with_canvas().affine_inverse() if board.is_inside_tree() else Transform2D.IDENTITY
	return (inverse * header).end.y

static func base_rect(board: Control, unit: Dictionary, width: float) -> Rect2:
	if bool(unit.get("boss_bar", false)):
		var visual: Rect2 = board.call("_unit_draw_rect", unit)
		var top: float = maxf(visual.position.y - BOSS_VISUAL_GAP - HEIGHT, boss_header_bottom(board) + BOSS_HEADER_GAP)
		return Rect2(Vector2(visual.get_center().x - width * 0.5, top), Vector2(width, HEIGHT))
	var health: Rect2 = (board.get("_hud_health_rects_cache") as Dictionary).get(str(unit.get("key", "")), board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit)))
	return Rect2(Vector2(health.get_center().x - width * 0.5, health.position.y - HEALTH_BAR_GAP - HEIGHT), Vector2(width, HEIGHT))

static func layouts(board: Control, badges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var font: Font = Typography.ui_font()
	var sorted_badges: Array = badges.duplicate(true)
	# Resolve collisions in action order; ties retain enemy/board roster order.
	sorted_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _first_order(str(a.get("order", ""))) < _first_order(str(b.get("order", ""))))
	var units: Array = board.call("_visible_units")
	for badge: Dictionary in sorted_badges:
		var unit: Dictionary = {}
		for candidate: Dictionary in units:
			if str(candidate.get("key", "")) == str(badge["key"]) and str(candidate.get("role", "")) == "enemy":
				unit = candidate
				break
		if unit.is_empty() or bool(unit.get("death_animation", false)):
			continue
		var rect: Rect2 = base_rect(board, unit, plate_width(badge, font))
		var level: int = 0
		while level < MAX_STACK_LEVEL and _overlaps(rect, str(badge["order"]), result):
			rect.position.y -= STACK_STEP
			if bool(unit.get("boss_bar", false)): rect.position.y = maxf(rect.position.y, boss_header_bottom(board) + BOSS_HEADER_GAP)
			level += 1
		if _overlaps(rect, str(badge["order"]), result):
			rect = resolve_horizontal_overflow(rect, str(badge["order"]), result, Rect2(Vector2.ZERO, board.size))
		var layout: Dictionary = badge.duplicate(true)
		layout.merge({"rect": rect, "stack_level": level})
		result.append(layout)
	return result

static func _first_order(order: String) -> int:
	return 2147483647 if order.is_empty() else int(order.get_slice("·", 0))

static func _envelope(rect: Rect2, order: String) -> Rect2:
	return rect if order.is_empty() else Rect2(rect.position - Vector2(ORDER_DIAMETER - ORDER_OVERLAP, 0), rect.size + Vector2(ORDER_DIAMETER - ORDER_OVERLAP, 0))

static func _overlaps(rect: Rect2, order: String, previous: Array[Dictionary]) -> bool:
	for other: Dictionary in previous:
		if _envelope(rect, order).intersects(_envelope(other["rect"], str(other["order"]))):
			return true
	return false

static func _overlap_width(rect: Rect2, order: String, previous: Array[Dictionary]) -> float:
	var width: float = 0.0
	var envelope: Rect2 = _envelope(rect, order)
	for other: Dictionary in previous:
		var occupied: Rect2 = _envelope(other["rect"], str(other["order"]))
		if envelope.intersects(occupied): width = maxf(width, envelope.intersection(occupied).size.x)
	return width

static func resolve_horizontal_overflow(rect: Rect2, order: String, previous: Array[Dictionary], viewport: Rect2) -> Rect2:
	var min_x: float = viewport.position.x + (ORDER_DIAMETER - ORDER_OVERLAP if not order.is_empty() else 0.0)
	var max_x: float = maxf(min_x, viewport.end.x - rect.size.x)
	var original: Rect2 = rect
	# Each step advances by the actual overlap width plus the authored gap.
	# If the rightward solution would be clamped, try left from the original.
	for direction: float in [1.0, -1.0]:
		rect = original
		var was_clamped: bool = false
		while _overlaps(rect, order, previous):
			var desired: float = rect.position.x + direction * (_overlap_width(rect, order, previous) + STACK_HORIZONTAL_GAP)
			rect.position.x = clampf(desired, min_x, max_x)
			if not is_equal_approx(desired, rect.position.x):
				was_clamped = true
				break
		if direction > 0.0 and was_clamped: continue
		if not _overlaps(rect, order, previous): return rect
	return rect

static func draw(board: Control, badges: Array) -> void:
	var font: Font = Typography.ui_font()
	for badge: Dictionary in layouts(board, badges):
		var rect: Rect2 = badge["rect"]
		var alpha: float = float(badge["alpha"])
		var border: Color = Palette.DANGER
		match str(badge["family"]):
			"defense": border = Palette.STEEL
			"support": border = Palette.GOLD
			"movement": border = Palette.TEXT_3
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.INK_0, 0.88 * alpha)
		style.border_color = Color(border, (1.0 if str(badge["family"]) == "movement" else 0.90) * alpha)
		style.set_border_width_all(1)
		style.set_corner_radius_all(RADIUS)
		board.draw_style_box(style, rect)
		var x: float = rect.position.x + content_left_padding(badge)
		var icon_rect := Rect2(Vector2(x, rect.get_center().y - PRIMARY_ICON_SIZE * 0.5), Vector2.ONE * PRIMARY_ICON_SIZE)
		_draw_icon(board, str(badge["icon"]), icon_rect, alpha)
		if bool(badge["cancelled"]):
			board.draw_line(Vector2(icon_rect.position.x, icon_rect.end.y), Vector2(icon_rect.end.x, icon_rect.position.y), Color(Palette.TEXT_2, alpha), 2.0, true)
		x += PRIMARY_ICON_SIZE
		if not str(badge["number"]).is_empty():
			x += PRIMARY_NUMBER_GAP
			x = _draw_number(board, font, str(badge["number"]), x, rect.get_center().y, PRIMARY_FONT_SIZE, alpha)
		if not str(badge["secondary_icon"]).is_empty():
			x += SECONDARY_ICON_GAP
			_draw_icon(board, str(badge["secondary_icon"]), Rect2(Vector2(x, rect.get_center().y - SECONDARY_ICON_SIZE * 0.5), Vector2.ONE * SECONDARY_ICON_SIZE), alpha)
			if not str(badge["secondary_number"]).is_empty():
				_draw_number(board, font, str(badge["secondary_number"]), x + SECONDARY_ICON_SIZE + SECONDARY_NUMBER_GAP, rect.get_center().y, SECONDARY_FONT_SIZE, alpha)
		var order: String = str(badge["order"])
		if not order.is_empty():
			var center := Vector2(rect.position.x - ORDER_DIAMETER * 0.5 + ORDER_OVERLAP, rect.get_center().y)
			board.draw_circle(center, ORDER_DIAMETER * 0.5, Color(Palette.INK_0, alpha))
			board.draw_arc(center, ORDER_DIAMETER * 0.5, 0.0, TAU, 32, Color(Palette.GOLD, alpha), 1.0, true)
			var baseline: float = center.y + (font.get_ascent(ORDER_FONT_SIZE) - font.get_descent(ORDER_FONT_SIZE)) * 0.5
			board.draw_string(font, Vector2(center.x - ORDER_DIAMETER * 0.5, baseline), order, HORIZONTAL_ALIGNMENT_CENTER, ORDER_DIAMETER, ORDER_FONT_SIZE, Color(Palette.GOLD_BRIGHT, alpha))

static func _draw_icon(board: Control, key: String, rect: Rect2, alpha: float) -> void:
	var texture: Texture2D = Icons.icon_texture(key)
	if texture != null: board.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))

static func _draw_number(board: Control, font: Font, number: String, x: float, center_y: float, font_size: int, alpha: float) -> float:
	var width: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	board.draw_string(font, Vector2(x, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.TEXT, alpha))
	return x + width
