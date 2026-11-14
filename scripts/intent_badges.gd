extends RefCounted
## Read-only end-now presentation. No resolver or scheduling state is retained.

const Data = preload("res://scripts/game_data.gd")
const WarbandRules = preload("res://scripts/warband_combat_rules.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ChipPlacement = preload("res://scripts/intent_chip_placement.gd")
const Settings = preload("res://scripts/settings_store.gd")
const HudGroups = preload("res://scripts/board_hud_group_placement.gd")

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
var _cache_inputs: Array = []
var _focus_key: String = ""
var _focused_cache: Dictionary = {}
var _orders_memo := preload("res://scripts/combat_preview_memo.gd").new()

func presentation_for_state(engine: RefCounted, committed: Dictionary, preview: Dictionary, focus_key: String = "", known_source: Callable = Callable()) -> Dictionary:
	var started: int = Time.get_ticks_usec() if engine._runtime_performance_instrumentation_enabled else 0
	# Focus changes only opacity. Never resolve the board again to isolate a badge.
	var definitions: Array
	for enemy: Dictionary in committed.get("enemies", []): definitions.append(Data.enemies().get(str(enemy.get("type", "")), {}))
	var inputs: Array = [committed, preview, definitions, engine._relic_effects(preview), engine.get_script()]
	var key: int = hash(inputs)
	if key != _cache_key or _cache.is_empty() or _cache_inputs != inputs:
		_cache_key = key
		_cache_inputs = inputs.duplicate(true)
		_cache = build(engine, committed, preview, "", known_source.call() if known_source.is_valid() else preview, _orders_for(engine, preview), _orders_for(engine, committed))
		_focused_cache = {}
		engine._record_runtime_performance_phase("rest_badges_build", started)
	if focus_key.is_empty(): return _cache.duplicate(true)
	if focus_key == _focus_key and not _focused_cache.is_empty(): return _focused_cache.duplicate(true)
	_focus_key = focus_key
	# Internal variants may share plans; every published result owns its full
	# nested data so a caller cannot mutate another focus or a future cache hit.
	_focused_cache = _cache.duplicate(false)
	for field: String in ["badges", "threats"]:
		var values: Array[Dictionary]
		for original: Dictionary in _cache[field]:
			var value: Dictionary = original.duplicate(false)
			value["alpha"] = float(original["alpha"]) * (ISOLATED_ALPHA if str(original["key"]) != focus_key else 1.0)
			values.append(value)
		_focused_cache[field] = values
	return _focused_cache.duplicate(true)

func _orders_for(engine: RefCounted, state: Dictionary) -> Dictionary:
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(Data.enemies().get(str(enemy.get("type", "")), {}))
	return _orders_memo.resolve([state, definitions, engine._relic_effects(state), engine.get_script()], func() -> Dictionary: return enemy_orders(engine, state))

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

static func build(engine: RefCounted, committed: Dictionary, preview: Dictionary, focus_key: String = "", known_preview: Dictionary = {}, preview_orders: Variant = null, original_orders: Variant = null) -> Dictionary:
	var orders: Dictionary = enemy_orders(engine, preview) if preview_orders == null else preview_orders
	var state_changed: bool = committed != preview
	var committed_orders: Dictionary = orders if not state_changed else enemy_orders(engine, committed) if original_orders == null else original_orders
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
		var primary: Dictionary = preload("res://scripts/enemy_mechanics/marked_strike.gd").presentation_action(engine, known_preview, enemy, primary_action(intent))
		if primary.is_empty():
			continue
		var actor_key: String = "enemy_%d" % id
		var threat: Dictionary = {}
		for index: int in range(known_enemies.size()):
			if int((known_enemies[index] as Dictionary).get("id", -2)) == id:
				threat = engine.enemy_threat_tiles(known_preview, index)
				break
		var repeated_action: Dictionary = {}
		if WarbandRules.active(known_preview) and is_attack(primary) and not (threat.get("projected_attack_action", {}) as Dictionary).is_empty():
			# Command is measured at the attack origin after movement, using the
			# same action as the threat plan and resolver. Retain repeat identity.
			repeated_action = primary
			primary = preload("res://scripts/enemy_mechanics/marked_strike.gd").presentation_action(engine, known_preview, enemy, threat["projected_attack_action"])
		var acting: bool = orders.has(actor_key)
		var attacking: bool = is_attack(primary)
		var cancelled: bool = projected.is_empty() or int(projected.get("hp", 0)) <= 0
		if attacking:
			cancelled = cancelled or int(projected.get("shock", 0)) > 0 or int(projected.get("freeze", 0)) > 0
			cancelled = cancelled or (threat.get("projected_attack", []) as Array).is_empty()
			# Stagger past the hero suppresses the announced attack in this preview.
			cancelled = cancelled or (state_changed and not acting and committed_orders.has(actor_key))
		var badge: Dictionary = descriptor(primary, intent, repeated_action)
		badge.merge({"key": actor_key, "order": "·".join(orders.get(actor_key, PackedStringArray())),
			"repeats": (orders.get(actor_key, PackedStringArray()) as PackedStringArray).size(),
			"acting": acting, "cancelled": cancelled,
			"danger": attacking and acting and not cancelled and (threat.get("projected_attack", []) as Array).has((preview.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))),
			"alpha": (1.0 if acting else INACTIVE_ALPHA) * (ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0)}, true)
		badges.append(badge)
		if attacking and acting and not cancelled:
			threats.append({"key": actor_key, "tiles": threat.get("projected_attack", []),
				"alpha": ISOLATED_ALPHA if not focus_key.is_empty() and focus_key != actor_key else 1.0,
				"area": is_area_intent(intent), "order": badge["order"], "attacker_tile": projected.get("pos", enemy.get("pos", Vector2i(-1, -1))), "plan": threat})
	return {"badges": badges, "threats": threats, "hero_tile": (preview.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))}

static func primary_action(intent: Dictionary) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if is_attack(action): return action
	return Compass._primary_action(intent)

static func is_attack(action: Dictionary) -> bool:
	var kind: String = str(action.get("type", ""))
	return kind in Compass.MELEE_TYPES or kind in Compass.RANGED_TYPES or kind in Compass.AREA_TYPES or kind in ["push", "upheaval_mark"]

static func descriptor(action: Dictionary, intent: Dictionary = {}, repeated_action: Dictionary = {}) -> Dictionary:
	var kind: String = str(action.get("type", ""))
	if kind in ["lob_mark", "lob_land"]:
		return {"icon": "lob", "number": Icons.token_value_text({"value": action["center_damage"]}), "secondary_icon": "", "secondary_number": "", "family": "attack"}
	var number: String = ""
	for field: String in ["damage", "amount", "count"]:
		if action.has(field):
			# Shared EN06 formatter: JSON numeric fields must never print as 4.0.
			number = ("+" if kind == "gain_charge" else "") + Icons.token_value_text({"value": action[field]})
			break
	if kind in ["lob_mark", "lob_land", "upheaval_mark"]: number = Icons.token_value_text({"value": Compass.value_for_action(action)})
	if kind in Compass.MOVEMENT_TYPES: number = ""
	var hits: int = int(action.get("hits", 1))
	if hits > 1 and not number.is_empty():
		number += "×%d" % hits
	else:
		var repeats: int = 0
		for other: Dictionary in intent.get("actions", []):
			if other == (action if repeated_action.is_empty() else repeated_action):
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
		"secondary_icon": str(secondary.get("icon", "")), "secondary_number": Icons.token_value_text(secondary),
		"family": "movement" if kind in Compass.MOVEMENT_TYPES else Compass.FAMILY_SUPPORT if kind == "upheaval_mark" else "attack" if is_attack(action) else Compass.family_for_action(action)}

static func secondary_rider(riders: Array) -> Dictionary:
	for icon: String in SECONDARY_PRIORITY:
		for rider: Dictionary in riders:
			if str(rider.get("icon", "")) == icon: return rider
	return {}

static func is_area_intent(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if is_attack(action) and (str(action.get("type", "")) in Compass.AREA_TYPES or str(action.get("type", "")) == "upheaval_mark" or action.has("pattern") or action.has("pattern_footprint")):
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
	var cached: Dictionary = board.get("_hud_health_rects_cache")
	var key: String = str(unit.get("key", ""))
	if cached.has(key): return cached[key]
	var anchor: Rect2 = board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit))
	return board.get("_status_plate_layout").resolve(board, unit, anchor)["frame"]

static func order_anchor_rect(board: Control, unit: Dictionary) -> Rect2:
	if bool(unit.get("boss_bar", false)):
		var global_frame: Rect2 = (board.get("presentation") as Dictionary).get("boss_health_frame_global_rect", Rect2())
		if global_frame.has_area():
			return board.get_global_transform_with_canvas().affine_inverse() * global_frame if board.is_inside_tree() else global_frame
	return board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit))

static func place_chip(anchor: Vector2, badge: Dictionary, font: Font, obstacles: Array, previous: Array, bounds: Rect2 = Rect2(), silhouettes: Array = []) -> Dictionary:
	var center: Vector2 = anchor + FEET_OFFSET
	var rect: Rect2 = chip_rect(center, badge, font)
	var left_center := Vector2(anchor.x - FEET_OFFSET.x - (rect.end.x - center.x), anchor.y + FEET_OFFSET.y)
	var left_rect: Rect2 = chip_rect(left_center, badge, font)
	var owner_key: String = str(badge.get("key", ""))
	var prefer_left: bool = ChipPlacement.coverage(rect, silhouettes, owner_key) - ChipPlacement.coverage(left_rect, silhouettes, owner_key) > rect.get_area() * ChipPlacement.SIDE_MARGIN
	var sole_obstacle: Rect2 = ChipPlacement.owner_sole_obstacle(silhouettes, owner_key)
	if sole_obstacle.has_area():
		obstacles = obstacles.duplicate()
		obstacles.append(sole_obstacle)
	for left: bool in [prefer_left, not prefer_left]:
		var candidate: Rect2 = left_rect if left else rect
		if (not bounds.has_area() or bounds.encloses(candidate)) and not _overlaps(candidate, obstacles, previous):
			return {"center": left_center if left else center, "rect": candidate, "placement": "lower_left" if left else "lower_right", "above_everything": false}
		# Exhaust this home's local search before trying the other side. The
		# original homes, 24px radius and solver tie-breaking stay unchanged.
		var clear: Dictionary = ChipPlacement.find_clear(rect, left_rect, obstacles, previous, bounds, left, true)
		if not clear.is_empty():
			return {"center": center + (clear["rect"] as Rect2).position - rect.position, "rect": clear["rect"], "placement": clear["placement"], "above_everything": false}
	return {"center": left_center if prefer_left else center, "rect": left_rect if prefer_left else rect, "placement": "lower_left" if prefer_left else "lower_right", "above_everything": true}

static func fixed_order_rects(board: Control, units: Array, badges: Array = []) -> Array[Rect2]:
	var result: Array[Rect2]
	if badges.is_empty(): badges = (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", [])
	if badges.is_empty(): return result
	var by_key: Dictionary = {}
	for unit: Dictionary in units: by_key[str(unit.get("key", ""))] = unit
	for badge: Dictionary in badges:
		var unit: Dictionary = by_key.get(str(badge.get("key", "")), {})
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		# Health frames remain anchored. Do not consult last submission's cache
		# while building this submission's fixed geometry.
		var frame: Rect2 = order_anchor_rect(board, unit)
		var rect: Rect2 = order_rect(frame, str(badge.get("order", "")), Typography.ui_font())
		if rect.has_area(): result.append(rect)
	return result

static func _overlaps(rect: Rect2, obstacles: Array, previous: Array) -> bool:
	for occupied: Rect2 in obstacles:
		if rect.intersects(occupied): return true
	for chip: Dictionary in previous:
		if rect.intersects(chip["rect"]): return true
	return false

static func boss_health_rect(board: Control) -> Rect2:
	var frame: Rect2 = (board.get("presentation") as Dictionary).get("boss_health_frame_global_rect", Rect2())
	return health_rect(board, {"boss_bar": true}) if frame.has_area() else Rect2()

static func death_health_rect(board: Control, unit: Dictionary) -> Rect2:
	# Match CombatBoardView._draw_health_bar_entry: only the fading frame is
	# drawn, without status/defense pills, text, crests or an order disc.
	if not bool(unit.get("death_animation", false)): return Rect2()
	if not (board.call("_umbra_actor_clip_for_unit", unit) as Dictionary).is_empty(): return Rect2()
	if bool((board.call("_enemy_render_definition", str(unit.get("type", ""))) as Dictionary).get("boss_bar", false)): return Rect2()
	var tint: Color = board.call("_death_animation_tint", unit)
	if tint.a <= 0.0: return Rect2()
	var dead: Dictionary = unit.duplicate(false)
	dead["hp"] = 0
	var anchor: Rect2 = board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit))
	return board.get("_status_plate_layout").resolve(board, dead, anchor)["frame"]

static func terrain_health_rects(board: Control) -> Array[Rect2]:
	var result: Array[Rect2]
	var textures: Dictionary = board.get("_terrain_textures")
	for terrain: Dictionary in (board.get("combat_state") as Dictionary).get("terrain", []):
		var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		if tile.x < 0 or not bool(board.call("_board_tile_is_visible_to_player", tile)): continue
		if not bool(board.call("_should_show_terrain_health_bar", terrain)): continue
		var kind: String = board.call("_terrain_art_kind", str(terrain.get("kind", "")))
		var texture: Texture2D = textures.get(kind, null)
		# The renderer draws neither the prop nor its bar without its texture.
		if texture == null: continue
		var body: Rect2 = board.call("_terrain_rect_for_tile", tile, texture, kind)
		if body.size.y <= 0.0: continue
		var size: Vector2 = board.TERRAIN_HEALTH_BAR_SIZE
		result.append(Rect2(Vector2(body.get_center().x - size.x * 0.5, body.position.y - board.TERRAIN_HEALTH_BAR_TOP_OFFSET), size))
	return result

static func layouts(board: Control, badges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if badges.is_empty(): return result
	if Settings._applied_board_health_bars == Settings.BOARD_HEALTH_CONTEXTUAL: return contextual_layouts(board, badges)
	var font: Font = Typography.ui_font()
	var sorted_badges: Array = badges.duplicate(true)
	sorted_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _first_order(str(a.get("order", ""))) < _first_order(str(b.get("order", ""))))
	var units: Array = board.call("_visible_units")
	# sb-01: the same plates/pills that reserve callout and intent space.
	var hud_rects: Array[Rect2]
	hud_rects.append_array(HudGroups.screen_reservations(board))
	hud_rects.append_array(fixed_order_rects(board, units, sorted_badges))
	hud_rects.append_array(terrain_health_rects(board))
	var boss_frame: Rect2 = boss_health_rect(board)
	if boss_frame.has_area(): hud_rects.append(boss_frame)
	var units_by_key: Dictionary = board.call("_units_by_key", units)
	var hud_entries: Array = board.get("_hud_layout_entries_cache")
	if hud_entries.is_empty(): hud_entries = board.call("_build_hud_layout_data", board.call("_hud_layout_units"))["entries"]
	var hud_by_key: Dictionary = {}
	for entry: Dictionary in hud_entries:
		var actor: Dictionary = units_by_key.get(str(entry.get("actor_key", "")), {})
		if not actor.is_empty() and not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var layout: Dictionary = entry.get("layout", {})
		hud_by_key[str(entry.get("actor_key", ""))] = layout
		for line: Rect2 in layout.get("line_rects", []): hud_rects.append(line)
	for actor: Dictionary in board.call("_hud_layout_units"):
		if bool(actor.get("death_animation", false)):
			var death_frame: Rect2 = death_health_rect(board, actor)
			if death_frame.has_area(): hud_rects.append(death_frame)
			continue
		if actor.get("role") == "npc" or not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var health: Rect2 = health_rect(board, actor)
		if not bool(actor.get("boss_bar", false)): hud_rects.append_array(board.call("_health_bar_collision_rects", actor, health))
		elif health.has_area() and not hud_rects.has(health): hud_rects.append(health)
		var crest: Rect2 = board.call("_leader_marker_rect", actor, health, hud_by_key.get(str(actor.get("key", "")), {}).get("intent_rect", Rect2()))
		if crest.has_area(): hud_rects.append(crest)
	# HUD and the owner's sole contact reserve chip space. Coverage chooses a
	# side using cached rest silhouettes; animated bounds made the board jitter.
	var silhouettes: Array[Dictionary] = ChipPlacement.rest_silhouettes(board, units)
	for badge: Dictionary in sorted_badges:
		var unit: Dictionary = {}
		for candidate: Dictionary in units:
			if str(candidate.get("key", "")) == str(badge["key"]) and str(candidate.get("role", "")) == "enemy":
				unit = candidate
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		var layout: Dictionary = badge.duplicate(true)
		layout.merge(place_chip(board.call("_unit_center", unit), badge, font, hud_rects, result, board.call("_enemy_hud_viewport_bounds"), silhouettes), true)
		layout["order_rect"] = order_rect(order_anchor_rect(board, unit), str(badge.get("order", "")), font)
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

# Owner 2026-11-12: the floor compass shows only with Details [I] on, never on
# hover, rail hover or threat isolation.
static func details_discloses_compass(presentation: Dictionary, _actor_key: String) -> bool:
	return bool(presentation.get("show_all_enemy_intents", false))

static func draw(board: Control, badges: Array, triangle_batch: RefCounted = null) -> void:
	var font: Font = Typography.ui_font()
	var presentation: Dictionary = board.get("presentation") as Dictionary
	# A debug-only fixed clock makes peak-pulse renderer proof deterministic.
	var seconds: float = float(presentation.get("threats_proof_seconds", float(preload("res://scripts/presentation_clock.gd").ticks_msec()) / 1000.0))
	var measured: Array[Dictionary] = layouts(board, badges)
	for on_top: bool in [false, true]:
		for badge: Dictionary in measured:
			if bool(badge["above_everything"]) == on_top:
				if bool(badge.get("contextual", false)): draw_contextual_chip(board, badge, triangle_batch)
				else: _draw_chip(board, badge, font, seconds, bool(presentation.get("reduced_motion", false)), triangle_batch)

static func draw_order_disc(board: Control, rect: Rect2, order: String, alpha: float, font: Font) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DISC_FILL, 0.94 * alpha)
	style.border_color = Color(Palette.GOLD, alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(ORDER_DIAMETER * 0.5))
	style.anti_aliasing = true
	board.draw_style_box(style, rect)
	_draw_centered_text(board, font, order, rect, ORDER_FONT_SIZE, Color(Palette.GOLD_BRIGHT, alpha))

static func _draw_chip(board: Control, badge: Dictionary, font: Font, seconds: float, reduced_motion: bool, triangle_batch: RefCounted = null) -> void:
	var center: Vector2 = badge["center"]
	var alpha: float = float(badge.get("alpha", 1.0))
	var ring: Color = ring_color(badge)
	var end: float = plate_end(badge, font)
	if bool(badge.get("danger", false)):
		var halo: Dictionary = halo_texture(end)
		board.draw_texture(halo["texture"], center + (halo["offset"] as Vector2), Color(Palette.DANGER, halo_alpha(seconds, reduced_motion) * alpha))
	_draw_tab(board, badge, font)
	_draw_disc(board, badge, triangle_batch)

static func _draw_tab(board: Control, badge: Dictionary, font: Font) -> void:
	var center: Vector2 = badge["center"]
	var alpha: float = float(badge.get("alpha", 1.0))
	var ring: Color = ring_color(badge)
	var end: float = plate_end(badge, font)
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

static func _draw_disc(board: Control, badge: Dictionary, triangle_batch: RefCounted = null) -> void:
	var center: Vector2 = badge["center"]
	var alpha: float = float(badge.get("alpha", 1.0))
	var ring: Color = ring_color(badge)
	if triangle_batch != null:
		triangle_batch.circle(center, MEDALLION_DIAMETER * 0.5, Color(MEDALLION_FILL, alpha), true)
		triangle_batch.flush(board)
	else:
		board.draw_circle(center, MEDALLION_DIAMETER * 0.5, Color(MEDALLION_FILL, alpha), true, -1.0, true)
	board.draw_arc(center, MEDALLION_DIAMETER * 0.5 - 1.0, 0.0, TAU, CIRCLE_SEGMENTS, Color(ring, alpha), 2.0, true)
	board.draw_arc(center, MEDALLION_DIAMETER * 0.5 - 4.0, 0.0, TAU, CIRCLE_SEGMENTS, Color(ring.r * 0.5, ring.g * 0.5, ring.b * 0.5, alpha), 1.0, true)
	var icon_rect := Rect2(center - Vector2.ONE * PRIMARY_ICON_SIZE * 0.5, Vector2.ONE * PRIMARY_ICON_SIZE)
	_draw_icon(board, str(badge["icon"]), icon_rect, alpha)
	if bool(badge.get("cancelled", false)):
		board.draw_line(Vector2(icon_rect.position.x, icon_rect.end.y), Vector2(icon_rect.end.x, icon_rect.position.y), Color(Palette.TEXT_2, alpha), 2.0, true)
	_draw_repeat_pip(board, badge, center, alpha)

# atk-03 (director 2026-11-13): a foe due to act twice or more before the hero's
# next turn wears the rail's "×2" in the same violet display ink, about 60% of
# the rail badge (22 px; the caption floor is 14). Presentation only.
const REPEAT_PIP_OUTLINE: int = 3
static func _draw_repeat_pip(board: Control, badge: Dictionary, center: Vector2, alpha: float) -> void:
	var repeats: int = int(badge.get("repeats", 0))
	if repeats < 2: return
	var font: Font = Typography.display_font()
	var text: String = "×%d" % repeats
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.SIZE_CAPTION)
	var radius: float = MEDALLION_DIAMETER * 0.5
	# Centre the numeral on the ring's upper-right shoulder (45 degrees).
	var anchor: Vector2 = center + Vector2(radius, -radius) * 0.72
	var baseline := Vector2(anchor.x - size.x * 0.5, anchor.y + (font.get_ascent(Typography.SIZE_CAPTION) - font.get_descent(Typography.SIZE_CAPTION)) * 0.5)
	board.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.SIZE_CAPTION, REPEAT_PIP_OUTLINE, Color(Palette.TEXT_OUTLINE, alpha))
	board.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.SIZE_CAPTION, Color(Palette.FORECAST_UNKNOWN, alpha))

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

# Contextual markers never enter the legacy silhouette-placement solver. The
# full plate geometry is still reserved by that solver, preserving bar anchors.
static func contextual_layouts(board: Control, badges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var units: Dictionary = board.call("_units_by_key", board.call("_visible_units"))
	for source: Dictionary in badges:
		var key: String = str(source.get("key", ""))
		var unit: Dictionary = units.get(key, {})
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		var badge: Dictionary = source.duplicate(true)
		var center: Vector2 = ChipPlacement.compact_anchor(board, unit)
		var expanded: bool = board.get("plate_visibility").unfurled(key)
		var rect: Rect2 = chip_rect(center, badge, Typography.ui_font()) if expanded else Rect2(center - Vector2.ONE * MEDALLION_DIAMETER * 0.5, Vector2.ONE * MEDALLION_DIAMETER)
		badge.merge({"contextual": true, "unfurled": expanded, "center": center, "rect": rect, "order_rect": Rect2(), "placement": "footprint_front", "above_everything": false}, true)
		result.append(badge)
	return result

class TabInk extends Control:
	var badge: Dictionary = {}
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid(): painter.call(self, badge, Typography.ui_font())

class TabWindow extends Control:
	var ink: TabInk
	var width: float = 0.0
	var expanded: bool = false
	var motion: Tween
	var reveal: float = 0.0:
		set(value):
			reveal = value
			size.x = width * value
			if is_instance_valid(ink): ink.position.x = -width * (1.0 - value)

	func configure(badge: Dictionary, painter: Callable, end: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		show_behind_parent = true
		if ink == null:
			ink = TabInk.new()
			ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ink)
		width = maxf(0.0, end + 1.0 + FINIAL_DIAMETER * 0.5 - PLATE_START) if end > 0.0 else 0.0
		position = (badge["center"] as Vector2) + Vector2(PLATE_START, -MEDALLION_DIAMETER * 0.5)
		size.y = MEDALLION_DIAMETER
		var local: Dictionary = badge.duplicate(true)
		local["center"] = Vector2(-PLATE_START, MEDALLION_DIAMETER * 0.5)
		ink.badge = local
		ink.painter = painter
		ink.queue_redraw()
		reveal = reveal
		var next: bool = bool(badge.get("unfurled", false))
		if expanded == next: return
		expanded = next
		if motion != null and motion.is_valid(): motion.kill()
		motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_property(self, "reveal", 1.0 if next else 0.0, 0.12)

static func draw_contextual_chip(board: Control, badge: Dictionary, triangle_batch: RefCounted = null) -> void:
	var name: String = "IntentTab_" + str(badge["key"])
	var tab: TabWindow = board.get_node_or_null(NodePath(name)) as TabWindow
	if tab == null:
		tab = TabWindow.new()
		tab.name = name
		board.add_child(tab)
		tab.modulate = board.get_meta("rd03_target", board.self_modulate)
	tab.show()
	tab.configure(badge, _draw_tab, plate_end(badge, Typography.ui_font()))
	_draw_disc(board, badge, triangle_batch)
