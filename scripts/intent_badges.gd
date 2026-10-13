extends RefCounted
## Read-only end-now presentation. No resolver or scheduling state is retained.

const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const MEDALLION_DIAMETER: float = 32.0
const PLATE_HEIGHT: float = 22.0
const PRIMARY_ICON_SIZE: float = 24.0
const SECONDARY_ICON_SIZE: float = 16.0
const PRIMARY_FONT_SIZE: int = 19
const SECONDARY_FONT_SIZE: int = 15
const ORDER_FONT_SIZE: int = 15
const ORDER_DIAMETER: float = 24.0
const ORDER_HEALTH_OFFSET: float = 14.0
const FEET_OFFSET := Vector2(26.0, 4.0)
const PLATE_START: float = 6.0
const NUMBER_START: float = 24.0
const CONTENT_END_PADDING: float = 12.0
const SECONDARY_GAP: float = 6.0
const FINIAL_DIAMETER: float = 10.0
const INACTIVE_ALPHA: float = 0.55
const ISOLATED_ALPHA: float = 0.40
const DISC_FILL := Color("15100c")
const MEDALLION_FILL := Color("3a2d1f")
const PLATE_FILL := Color("140f0b")
const HALO_RADIUS: float = 6.0
const HALO_MIN: float = 0.35
const HALO_MAX: float = 0.75
const HALO_STEADY: float = 0.55
const PULSE_SECONDS: float = 1.1
# Numerical integration bounds; does not change the approved 6px blur radius.
const GAUSSIAN_KERNEL_SIGMAS: int = 3
const CIRCLE_SEGMENTS: int = 64
const SECONDARY_PRIORITY: Array = ["push", "pull", "immobilize", "freeze", "chilled", "shock", "bleed", "expose", "stagger"]
static var _halo_cache: Dictionary = {}

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

static func movement_preview(engine: RefCounted, committed: Dictionary, known: Dictionary) -> Dictionary:
	# The movement surface forecast resolves known causes before simulation.
	# Restore concealed actors solely for the existing clock/privacy boundary;
	# neither their intent nor their bounds can enter the visible rest layer.
	var result: Dictionary = known.duplicate(true)
	var enemies: Array = result.get("enemies", []) as Array
	for enemy: Dictionary in committed.get("enemies", []):
		if not engine.is_enemy_visible_to_player(committed, enemy): enemies.append(enemy.duplicate(true))
	result["enemies"] = enemies
	return result

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
		if intent.is_empty():
			continue
		var primary: Dictionary = primary_action(intent)
		if primary.is_empty():
			continue
		var actor_key: String = "enemy_%d" % id
		var threat: Dictionary = {}
		for index: int in range(known_enemies.size()):
			if int((known_enemies[index] as Dictionary).get("id", -2)) == id:
				threat = engine.enemy_threat_tiles(known_preview, index)
				break
		if str(primary.get("type", "")) == "mirror_last_attack": primary = threat.get("projected_attack_action", primary)
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
			"danger": attacking and acting and not cancelled and (threat.get("projected_attack", []) as Array).has((preview.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))),
			"alpha": (1.0 if acting else INACTIVE_ALPHA) * (ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0)}, true)
		badges.append(badge)
		if attacking and acting and not cancelled:
			threats.append({"key": actor_key, "tiles": threat.get("projected_attack", []),
				"alpha": ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0,
				"area": is_area_intent(intent), "order": badge["order"], "attacker_tile": projected.get("pos", enemy.get("pos", Vector2i(-1, -1)))})
	return {"badges": badges, "threats": threats, "hero_tile": (preview.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))}

static func primary_action(intent: Dictionary) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if is_attack(action): return action
	return Compass._primary_action(intent)

static func is_attack(action: Dictionary) -> bool:
	var kind: String = str(action.get("type", ""))
	return kind in Compass.MELEE_TYPES or kind in Compass.RANGED_TYPES or kind in Compass.AREA_TYPES or kind == "push"

static func descriptor(action: Dictionary, intent: Dictionary = {}) -> Dictionary:
	var kind: String = str(action.get("type", ""))
	var number: String = ""
	for field: String in ["damage", "amount", "count"]:
		if action.has(field):
			number = ("+%d" if kind == "gain_charge" else "%d") % int(action[field])
			break
	if kind in Compass.MOVEMENT_TYPES: number = ""
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
		"secondary_icon": str(secondary.get("icon", "")), "secondary_number": str(int(secondary["value"])) if secondary.has("value") else "",
		"family": "movement" if kind in Compass.MOVEMENT_TYPES else "attack" if is_attack(action) else Compass.family_for_action(action)}

static func secondary_rider(riders: Array) -> Dictionary:
	for icon: String in SECONDARY_PRIORITY:
		for rider: Dictionary in riders:
			if str(rider.get("icon", "")) == icon: return rider
	return {}

static func is_area_intent(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if is_attack(action) and (str(action.get("type", "")) in Compass.AREA_TYPES or action.has("pattern") or action.has("pattern_footprint")):
			return true
	return false

static func plate_end(badge: Dictionary, font: Font) -> float:
	var number: String = str(badge.get("number", ""))
	if number.is_empty(): return 0.0
	var end: float = NUMBER_START + font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, PRIMARY_FONT_SIZE).x
	if not str(badge.get("secondary_icon", "")).is_empty():
		end += SECONDARY_GAP + SECONDARY_ICON_SIZE
		end += font.get_string_size(str(badge.get("secondary_number", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, SECONDARY_FONT_SIZE).x
	return end + CONTENT_END_PADDING

static func chip_rect(center: Vector2, badge: Dictionary, font: Font) -> Rect2:
	var right: float = MEDALLION_DIAMETER * 0.5
	if not str(badge.get("number", "")).is_empty():
		right = plate_end(badge, font) + 1.0 + FINIAL_DIAMETER * 0.5
	return Rect2(center - Vector2.ONE * MEDALLION_DIAMETER * 0.5, Vector2(right + MEDALLION_DIAMETER * 0.5, MEDALLION_DIAMETER))

static func order_rect(health: Rect2, order: String, font: Font) -> Rect2:
	if order.is_empty(): return Rect2()
	var width: float = ORDER_DIAMETER
	if order.contains("·"):
		# Extend the circle by the added text width, retaining its single-digit inset.
		width += font.get_string_size(order, HORIZONTAL_ALIGNMENT_LEFT, -1, ORDER_FONT_SIZE).x - font.get_string_size(order.get_slice("·", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, ORDER_FONT_SIZE).x
	var center := Vector2(health.position.x - ORDER_HEALTH_OFFSET, health.get_center().y)
	return Rect2(center - Vector2(width, ORDER_DIAMETER) * 0.5, Vector2(width, ORDER_DIAMETER))

static func health_rect(board: Control, unit: Dictionary) -> Rect2:
	if bool(unit.get("boss_bar", false)):
		var global_frame: Rect2 = (board.get("presentation") as Dictionary).get("boss_health_frame_global_rect", Rect2())
		if global_frame.has_area():
			var inverse: Transform2D = board.get_global_transform_with_canvas().affine_inverse() if board.is_inside_tree() else Transform2D.IDENTITY
			return inverse * global_frame
	return (board.get("_hud_health_rects_cache") as Dictionary).get(str(unit.get("key", "")), board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit)))

static func place_chip(anchor: Vector2, badge: Dictionary, font: Font, obstacles: Array, previous: Array) -> Dictionary:
	var center: Vector2 = anchor + FEET_OFFSET
	var rect: Rect2 = chip_rect(center, badge, font)
	if not _overlaps(rect, obstacles, previous):
		return {"center": center, "rect": rect, "placement": "lower_right", "above_everything": false}
	var left_center := Vector2(anchor.x - FEET_OFFSET.x - (rect.end.x - center.x), anchor.y + FEET_OFFSET.y)
	var left_rect: Rect2 = chip_rect(left_center, badge, font)
	if not _overlaps(left_rect, obstacles, previous):
		return {"center": left_center, "rect": left_rect, "placement": "lower_left", "above_everything": false}
	return {"center": center, "rect": rect, "placement": "lower_right", "above_everything": true}

static func _overlaps(rect: Rect2, obstacles: Array, previous: Array) -> bool:
	for occupied: Rect2 in obstacles:
		if rect.intersects(occupied): return true
	for chip: Dictionary in previous:
		if rect.intersects(chip["rect"]): return true
	return false

static func layouts(board: Control, badges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var font: Font = Typography.ui_font()
	var sorted_badges: Array = badges.duplicate(true)
	sorted_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _first_order(str(a.get("order", ""))) < _first_order(str(b.get("order", ""))))
	var units: Array = board.call("_visible_units")
	# These are the actual renderer's prop bounds, already clipped by Umbra.
	var props: Array = board.call("_foreground_obstruction_candidates")
	for badge: Dictionary in sorted_badges:
		var unit: Dictionary = {}
		var obstacles: Array[Rect2]
		for candidate: Dictionary in units:
			if str(candidate.get("key", "")) == str(badge["key"]) and str(candidate.get("role", "")) == "enemy":
				unit = candidate
			else:
				obstacles.append(board.call("_unit_draw_rect", candidate))
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		for prop: Dictionary in props:
			var tile: Vector2i = prop.get("tile", Vector2i(-1, -1))
			if bool(board.call("_board_tile_is_visible_to_player", tile)):
				obstacles.append(prop.get("rect", Rect2()))
		var layout: Dictionary = badge.duplicate(true)
		layout.merge(place_chip(board.call("_unit_center", unit), badge, font, obstacles, result), true)
		layout["order_rect"] = order_rect(health_rect(board, unit), str(badge.get("order", "")), font)
		result.append(layout)
	return result

static func _first_order(order: String) -> int:
	return 2147483647 if order.is_empty() else int(order.get_slice("·", 0))

static func ring_color(badge: Dictionary) -> Color:
	if bool(badge.get("danger", false)): return Palette.DANGER
	return Palette.GOLD_DIM if str(badge.get("family", "")) in ["defense", "support", "movement"] else Palette.GOLD

static func halo_alpha(seconds: float, reduced_motion: bool) -> float:
	if reduced_motion: return HALO_STEADY
	return HALO_MIN + (HALO_MAX - HALO_MIN) * (0.5 - 0.5 * cos(TAU * seconds / PULSE_SECONDS))

static func needs_pulse(presentation: Dictionary) -> bool:
	if bool(presentation.get("reduced_motion", false)): return false
	for badge: Dictionary in (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []):
		if bool(badge.get("danger", false)): return true
	return false

static func details_discloses_compass(presentation: Dictionary, actor_key: String) -> bool:
	return bool(presentation.get("show_all_enemy_intents", false)) or (presentation.get("expanded_enemy_actor_keys", []) as Array).has(actor_key)

static func draw(board: Control, badges: Array) -> void:
	var font: Font = Typography.ui_font()
	var presentation: Dictionary = board.get("presentation") as Dictionary
	# A debug-only fixed clock makes peak-pulse renderer proof deterministic.
	var seconds: float = float(presentation.get("threats_proof_seconds", float(Time.get_ticks_msec()) / 1000.0))
	var measured: Array[Dictionary] = layouts(board, badges)
	for badge: Dictionary in measured:
		var rect: Rect2 = badge["order_rect"]
		if rect.has_area(): draw_order_disc(board, rect, str(badge["order"]), float(badge["alpha"]), font)
	for on_top: bool in [false, true]:
		for badge: Dictionary in measured:
			if bool(badge["above_everything"]) == on_top:
				_draw_chip(board, badge, font, seconds, bool(presentation.get("reduced_motion", false)))

static func draw_order_disc(board: Control, rect: Rect2, order: String, alpha: float, font: Font) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DISC_FILL, 0.94 * alpha)
	style.border_color = Color(Palette.GOLD, alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(ORDER_DIAMETER * 0.5))
	style.anti_aliasing = true
	board.draw_style_box(style, rect)
	_draw_centered_text(board, font, order, rect, ORDER_FONT_SIZE, Color(Palette.GOLD_BRIGHT, alpha))

static func _draw_chip(board: Control, badge: Dictionary, font: Font, seconds: float, reduced_motion: bool) -> void:
	var center: Vector2 = badge["center"]
	var alpha: float = float(badge.get("alpha", 1.0))
	var ring: Color = ring_color(badge)
	var end: float = plate_end(badge, font)
	if bool(badge.get("danger", false)):
		var halo: Dictionary = halo_texture(end)
		board.draw_texture(halo["texture"], center + (halo["offset"] as Vector2), Color(Palette.DANGER, halo_alpha(seconds, reduced_motion) * alpha))
	if end > 0.0:
		var plate := Rect2(center + Vector2(PLATE_START, -PLATE_HEIGHT * 0.5), Vector2(end - PLATE_START, PLATE_HEIGHT))
		board.draw_rect(plate, Color(PLATE_FILL, 0.92 * alpha))
		board.draw_line(plate.position, Vector2(plate.end.x, plate.position.y), Color(ring, 230.0 / 255.0 * alpha), 1.0, true)
		board.draw_line(Vector2(plate.position.x, plate.end.y), plate.end, Color(ring, 230.0 / 255.0 * alpha), 1.0, true)
		var finial: Vector2 = center + Vector2(end + 1.0, 0.0)
		board.draw_colored_polygon(PackedVector2Array([finial + Vector2(0, -5), finial + Vector2(5, 0), finial + Vector2(0, 5), finial + Vector2(-5, 0)]), Color(ring, alpha))
		var x: float = _draw_number(board, font, str(badge["number"]), center.x + NUMBER_START, center.y + 1.0, PRIMARY_FONT_SIZE, alpha)
		if not str(badge.get("secondary_icon", "")).is_empty():
			x += SECONDARY_GAP
			_draw_icon(board, str(badge["secondary_icon"]), Rect2(Vector2(x, center.y - SECONDARY_ICON_SIZE * 0.5), Vector2.ONE * SECONDARY_ICON_SIZE), alpha)
			_draw_number(board, font, str(badge.get("secondary_number", "")), x + SECONDARY_ICON_SIZE, center.y + 1.0, SECONDARY_FONT_SIZE, alpha)
	board.draw_circle(center, MEDALLION_DIAMETER * 0.5, Color(MEDALLION_FILL, alpha), true, -1.0, true)
	board.draw_arc(center, MEDALLION_DIAMETER * 0.5 - 1.0, 0.0, TAU, CIRCLE_SEGMENTS, Color(ring, alpha), 2.0, true)
	board.draw_arc(center, MEDALLION_DIAMETER * 0.5 - 4.0, 0.0, TAU, CIRCLE_SEGMENTS, Color(ring.r * 0.5, ring.g * 0.5, ring.b * 0.5, alpha), 1.0, true)
	var icon_rect := Rect2(center - Vector2.ONE * PRIMARY_ICON_SIZE * 0.5, Vector2.ONE * PRIMARY_ICON_SIZE)
	_draw_icon(board, str(badge["icon"]), icon_rect, alpha)
	if bool(badge.get("cancelled", false)):
		board.draw_line(Vector2(icon_rect.position.x, icon_rect.end.y), Vector2(icon_rect.end.x, icon_rect.position.y), Color(Palette.TEXT_2, alpha), 2.0, true)

static func _draw_centered_text(board: Control, font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var baseline: float = rect.get_center().y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	board.draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

static func _draw_icon(board: Control, key: String, rect: Rect2, alpha: float) -> void:
	var texture: Texture2D = Icons.icon_texture(key)
	if texture != null: board.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))

static func _draw_number(board: Control, font: Font, number: String, x: float, center_y: float, font_size: int, alpha: float) -> float:
	var width: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	board.draw_string(font, Vector2(x, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.TEXT, alpha))
	return x + width

static func halo_texture(plate_end_x: float) -> Dictionary:
	var end: int = ceili(plate_end_x)
	if _halo_cache.has(end): return _halo_cache[end]
	# Reproduce make_d.py's 19px halo circle and rounded plate mask, then
	# convolve in both axes with a normalised Gaussian (sigma/radius 6px).
	var kernel_radius: int = int(HALO_RADIUS) * GAUSSIAN_KERNEL_SIGMAS
	var padding: int = 19 + kernel_radius
	var width: int = maxi(19, end + 8) + padding + kernel_radius + 1
	var height: int = padding * 2 + 1
	var mask := PackedFloat32Array()
	mask.resize(width * height)
	var kernel := PackedFloat32Array()
	var sum: float = 0.0
	for offset: int in range(-kernel_radius, kernel_radius + 1):
		var weight: float = exp(-float(offset * offset) / (2.0 * HALO_RADIUS * HALO_RADIUS))
		kernel.append(weight)
		sum += weight
	for index: int in range(kernel.size()): kernel[index] /= sum
	for y: int in range(height):
		for x: int in range(width):
			var point := Vector2(x - padding, y - padding)
			var value: float = 1.0 if point.length_squared() <= 19.0 * 19.0 else 0.0
			if end > 0:
				var box_center := Vector2((PLATE_START + end + 8) * 0.5, 0)
				var half_size := Vector2((end + 8 - PLATE_START) * 0.5, PLATE_HEIGHT * 0.5 + 3)
				var corner: Vector2 = (point - box_center).abs() - half_size + Vector2.ONE * 6
				if corner.max(Vector2.ZERO).length() + minf(maxf(corner.x, corner.y), 0.0) <= 6.0: value = 200.0 / 255.0
			mask[y * width + x] = value
	var horizontal: PackedFloat32Array = mask.duplicate()
	for y: int in range(height):
		for x: int in range(width):
			var value: float = 0.0
			for offset: int in range(-kernel_radius, kernel_radius + 1):
				var source_x: int = x + offset
				if source_x >= 0 and source_x < width: value += mask[y * width + source_x] * kernel[offset + kernel_radius]
			horizontal[y * width + x] = value
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var value: float = 0.0
			for offset: int in range(-kernel_radius, kernel_radius + 1):
				var source_y: int = y + offset
				if source_y >= 0 and source_y < height: value += horizontal[source_y * width + x] * kernel[offset + kernel_radius]
			image.set_pixel(x, y, Color(1, 1, 1, value))
	var result: Dictionary = {"texture": ImageTexture.create_from_image(image), "offset": -Vector2.ONE * padding}
	_halo_cache[end] = result
	return result
