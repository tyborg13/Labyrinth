extends RefCounted

## Context and change events own visibility. The clock sleeps at rest and only
## invalidates HUD paint while an opacity is changing (never during a hold).
const Settings = preload("res://scripts/settings_store.gd")
const Ghost = preload("res://scripts/health_ghost_tracker.gd")
const Plates = preload("res://scripts/board_status_plates.gd")
const Countdown = preload("res://scripts/board_snare_countdown.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const FADE_IN: float = 0.12
const FADE_OUT: float = 0.20
const CHANGE_HOLD: float = 1.2
const FEET_RAISE: float = 0.22
const ROW_GAP: float = 4.0
const FRIENDLY_ORDER_BADGE: String = ""

signal changed
signal inspection_changed
var board: Control
var pointer_keys: Dictionary = {}
var inspected_keys: Dictionary = {}
var external_keys: Dictionary = {}
var _entries: Dictionary = {}
var _observed: Dictionary = {}
var _scope: Array = []
var redraw_requests: int = 0
var _last_setting: String = Settings.DEFAULT_BOARD_HEALTH_BARS

var _clock: VisibilityClock

class VisibilityClock extends Node:
	var controller: RefCounted
	func _process(delta: float) -> void: controller.advance(delta)

func attach_to(view: Control) -> void:
	board = view
	_clock = VisibilityClock.new()
	_clock.name = "BoardPlateVisibilityClock"
	_clock.controller = self
	view.add_child(_clock)
	_clock.set_process(_active())

func _set_active() -> void:
	if is_instance_valid(_clock): _clock.set_process(_active())

func observe(state: Dictionary, source: Dictionary) -> void:
	var scope: Array = [state.get("seed"), state.get("room_coord")]
	if scope != _scope:
		_scope = scope
		_observed.clear()
		_entries.clear()
	var units: Dictionary = {}
	if not (state.get("player", {}) as Dictionary).is_empty(): units["player"] = state["player"]
	for group: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(group, []):
			units[("enemy_" if group == "enemies" else "illusion_") + str(unit.get("id", -1))] = unit
	for terrain: Dictionary in state.get("terrain", []):
		if int(terrain.get("max_hp", 0)) > 0: units[terrain_key(terrain)] = terrain
	for key: String in units:
		var unit: Dictionary = units[key]
		var signature: Array = [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))]
		# Only real durability/status producers; position, animation and preview
		# dictionaries cannot masquerade as a change event.
		for field: String in ["block", "stoneskin", "bleed", "expose", "freeze", "petrify", "shock", "frost_armor", "charge", "kindled_bonus", "reflect", "retaliate", "wind"]:
			signature.append(unit.get(field, 0))
		for field: String in ["chilled", "immobilize", "burrowed", "flying"]:
			signature.append(bool(unit.get(field, false)))
		signature.append(unit.get("keyword_badges", []))
		if key == "player":
			signature.append(preload("res://scripts/combat_hud_forecast.gd").keyword_badges(state))
			if is_instance_valid(board): signature.append(board.call("_player_display_statuses", unit, state.get("player_turn_restrictions", {})))
			signature.append(source.get("umbra_truesight_activations", 0))
			signature.append(source.get("umbra_truesight_conditional", false))
		elif key.begins_with("illusion_"):
			signature.append(preload("res://scripts/illusion_card_rules.gd").illusion_badges(unit))
		# Props reveal for real Health changes only; their status icons remain
		# inspectable without opening a bar on an unrelated status event.
		if key.begins_with("terrain_"): signature.resize(2)
		if _observed.has(key) and _observed[key] != signature:
			var animation: float = 0.0
			if int(signature[0]) < int(_observed[key][0]):
				animation = Ghost.REDUCED_MOTION_SECONDS if bool(source.get("reduced_motion", false)) else Ghost.HOLD_SECONDS + Ghost.DRAIN_SECONDS
			elif int(signature[0]) > int(_observed[key][0]): animation = Ghost.HEAL_FLASH_SECONDS
			if key.begins_with("terrain_"): animation = 0.0
			var entry: Dictionary = _entry(key)
			# A status/defense event during a draining health ghost must not
			# shorten the ghost's existing after-animation hold.
			entry["hold"] = animation + CHANGE_HOLD if animation > 0.0 else maxf(float(entry["hold"]), CHANGE_HOLD)
		_observed[key] = signature.duplicate(true)
	for key: String in _observed.keys():
		if not units.has(key):
			_entry(key)["hold"] = Ghost.HOLD_SECONDS + Ghost.DRAIN_SECONDS + CHANGE_HOLD
			_observed.erase(key)

func _entry(key: String) -> Dictionary:
	if not _entries.has(key): _entries[key] = {"alpha": 0.0, "target": false, "hold": 0.0}
	return _entries[key]

func refresh() -> void:
	if not is_instance_valid(board): return
	var dirty: bool = _last_setting != Settings._applied_board_health_bars
	_last_setting = Settings._applied_board_health_bars
	var aim: Array = board.presentation.get("plate_aim_actor_keys", [])
	var focus: Vector2i = board.get("_controller_focus_tile")
	var all_plates: bool = Settings._applied_board_health_bars == Settings.BOARD_HEALTH_ALWAYS or bool(board.presentation.get("show_all_enemy_intents", false))
	var inspected: Dictionary = {}
	for unit: Dictionary in actors():
		var key: String = str(unit.get("key", ""))
		var entry: Dictionary = _entry(key)
		var footprint: Array = board.call("_unit_footprint_tiles", unit)
		var previous: bool = bool(entry["target"])
		var inspecting: bool = external_keys.has(key) or (focus.x < 0 and pointer_keys.has(key)) or footprint.has(focus)
		if inspecting: inspected[key] = true
		entry["target"] = all_plates or aim.has(key) or inspecting
		dirty = dirty or previous != bool(entry["target"])
		# Always restores today's rendering immediately, including mid-fight.
		if Settings._applied_board_health_bars == Settings.BOARD_HEALTH_ALWAYS: entry["alpha"] = 1.0
	if inspected != inspected_keys:
		inspected_keys = inspected
		inspection_changed.emit()
		dirty = true
	_set_active()
	if dirty: _invalidate()

func set_external(key: String, active: bool, source: String = "external") -> void:
	var sources: Dictionary = external_keys.get(key, {})
	if active: sources[source] = true
	else: sources.erase(source)
	if sources.is_empty(): external_keys.erase(key)
	else: external_keys[key] = sources
	refresh()

static func terrain_key(terrain: Dictionary) -> String:
	return "terrain_" + str(terrain.get("id", ""))

func actors() -> Array[Dictionary]:
	var result: Array[Dictionary]
	if not is_instance_valid(board): return result
	result.assign(board.call("_visible_units"))
	for terrain: Dictionary in board.combat_state.get("terrain", []):
		if int(terrain.get("hp", 0)) <= 0 or int(terrain.get("max_hp", 0)) <= 0: continue
		if not board.call("_board_tile_is_visible_to_player", terrain.get("pos", Vector2i(-1, -1))): continue
		var actor: Dictionary = terrain.duplicate(false)
		actor["key"] = terrain_key(terrain)
		actor["role"] = "terrain"
		result.append(actor)
	return result

func status_entries(unit: Dictionary) -> Array[Dictionary]:
	if str(unit.get("role", "")) != "terrain":
		var layout: Dictionary = board.get("_status_plate_layout").resolve(board, unit, board.call("_unit_health_bar_rect", unit, board.call("_unit_center", unit)))
		var fixed: Array[Dictionary] = rest_entries(layout, Rect2())
		fixed.append_array(Countdown.entries(board, unit))
		return fixed
	var kind: String = board.call("_terrain_art_kind", str(unit.get("kind", "")))
	var texture: Texture2D = board.get("_terrain_textures").get(kind)
	var result: Array[Dictionary]
	if texture == null: return result
	var body: Rect2 = board.call("_terrain_rect_for_tile", unit.pos, texture, kind)
	var frame := Rect2(Vector2(body.get_center().x - board.TERRAIN_HEALTH_BAR_SIZE.x * 0.5, body.position.y - board.TERRAIN_HEALTH_BAR_TOP_OFFSET), board.TERRAIN_HEALTH_BAR_SIZE)
	var insets: Vector4 = board.TERRAIN_HEALTH_CONTENT_INSETS
	var fill := Rect2(frame.position + frame.size * Vector2(insets.x, insets.y), frame.size * Vector2(1.0 - insets.x - insets.z, 1.0 - insets.y - insets.w))
	result.append_array(Plates.defense_entries(unit, frame, board.call("_terrain_damage_preview", unit)))
	result.append_array(Plates.status_entries(board.call("_unit_status_presentation_badges", unit), fill.grow(-Plates.HEALTH_BAR_BORDER_WIDTH), false))
	return result

func draw_terrain_statuses(view: Control, terrain: Dictionary) -> void:
	if terrain.has("destruction_progress"): return
	var unit: Dictionary = terrain.duplicate(false)
	unit["role"] = "terrain"
	unit["key"] = terrain_key(terrain)
	for entry: Dictionary in status_entries(unit):
		Plates.draw_entry(view, entry, view.get("_keyword_icon_textures").get(str(entry["icon"])), 1.0, -1.0, false, view.presentation)

func inspected(key: String) -> bool:
	return inspected_keys.has(key)

func tooltip_at(point: Vector2) -> String:
	if not is_instance_valid(board): return ""
	# Countdown chips share fixed-status hit testing and UiTooltipPanel styling.
	# Always keeps ordinary statuses on their original painted-region path.
	for unit: Dictionary in actors():
		for entry: Dictionary in status_entries(unit):
			if Settings._applied_board_health_bars == Settings.BOARD_HEALTH_ALWAYS and not bool(entry.get("countdown_chip", false)): continue
			if (entry["rect"] as Rect2).has_point(point): return str(entry.get("tooltip", ""))
	return ""

func unfurled(key: String) -> bool:
	var focus: Vector2i = board.get("_controller_focus_tile")
	var live_tile: Vector2i = focus if focus.x >= 0 else board.get("_hover_tile")
	var owner_tile: Vector2i = board.presentation.get("hover_owner_tile", live_tile)
	# Stage hover paint coalesces until the deferred flush. Retire an old
	# reverse-lookup disc immediately when its input owner has already left.
	var current_owner: bool = owner_tile == live_tile or (owner_tile.x < 0 and live_tile.x < 0)
	var isolated: bool = current_owner and (board.presentation.get("isolated_enemy_actor_keys", []) as Array).has(key)
	return Settings._applied_board_health_bars == Settings.BOARD_HEALTH_ALWAYS or inspected(key) or isolated or bool(board.presentation.get("show_all_enemy_intents", false))

func update_pointer(point: Vector2, tile: Vector2i) -> void:
	if not is_instance_valid(board): return
	var next: Dictionary = {}
	# Fixed status geometry is authoritative for both input and painting. It is
	# independent of the visibility alpha and does not move out from the pointer.
	for unit: Dictionary in actors():
		if str(unit.get("role", "")) == "npc" or bool(unit.get("death_animation", false)): continue
		for entry: Dictionary in status_entries(unit):
			if (entry["rect"] as Rect2).has_point(point): next[str(unit["key"])] = true
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if (badge["rect"] as Rect2).has_point(point): next[str(badge["key"])] = true
	if next.is_empty():
		# Footprints take precedence over overlapping tall sprites/prop canvases.
		for actor: Dictionary in actors():
			if (board.call("_unit_footprint_tiles", actor) as Array).has(tile): next[str(actor["key"])] = true
	if next.is_empty():
		# Owner 2026-11-12: inspection is tile-based. Sprite bodies never claim a
		# tile behind them; a prop with Health is inspected on its own tile.
		for terrain: Dictionary in board.combat_state.get("terrain", []):
			if int(terrain.get("hp", 0)) <= 0 or int(terrain.get("max_hp", 0)) <= 0: continue
			if terrain.get("pos", Vector2i(-1, -1)) != tile: continue
			if not board.call("_board_tile_is_visible_to_player", tile): continue
			next[terrain_key(terrain)] = true
	if next != pointer_keys:
		pointer_keys = next
		refresh()

func opacity(key: String) -> float:
	if Settings._applied_board_health_bars == Settings.BOARD_HEALTH_ALWAYS: return 1.0
	return float(_entries.get(key, {}).get("alpha", 0.0))

func _active() -> bool:
	for entry: Dictionary in _entries.values():
		var target: float = 1.0 if bool(entry["target"]) or float(entry["hold"]) > 0.0 else 0.0
		if float(entry["hold"]) > 0.0 or not is_equal_approx(float(entry["alpha"]), target): return true
	return false

func advance(delta: float) -> void:
	var dirty: bool = false
	for entry: Dictionary in _entries.values():
		var before: float = float(entry["alpha"])
		var hold: float = float(entry["hold"])
		entry["hold"] = maxf(0.0, hold - delta)
		var show: bool = bool(entry["target"]) or float(entry["hold"]) > 0.0
		var step: float = delta if show or hold <= 0.0 else maxf(0.0, delta - hold)
		var next: float = move_toward(before, 1.0 if show else 0.0, step / (FADE_IN if show else FADE_OUT))
		# Do not let floating-point residue suppress the rest badge after the
		# clock sleeps: zero is also the paint gate, not just a visual alpha.
		if is_zero_approx(next): next = 0.0
		elif is_equal_approx(next, 1.0): next = 1.0
		entry["alpha"] = next
		dirty = dirty or not is_equal_approx(before, float(entry["alpha"]))
	if dirty: _invalidate()
	_set_active()

func _invalidate() -> void:
	redraw_requests += 1
	changed.emit()

func feet_rect(view: Control, unit: Dictionary, original: Rect2) -> Rect2:
	var front := Vector2(-INF, -INF)
	for tile: Vector2i in view.call("_unit_footprint_tiles", unit):
		for point: Vector2 in view.call("_tile_polygon", tile):
			if point.y > front.y: front = point
	var center: Vector2 = front - Vector2(0.0, FEET_RAISE * float(view.call("_tile_height")))
	return Rect2(center - original.size * 0.5, original.size)

func rest_entries(layout: Dictionary, _badge: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for field: String in ["statuses", "defenses"]:
		result.append_array(layout[field])
	return result

# Reuse the existing status painter without changing its art, layout, forecast
# pulse, or style cache. Only submitted ink alpha is multiplied during fades.
class OpacityInk extends RefCounted:
	var view: Object
	var alpha: float
	func tint(color: Color) -> Color: return Color(color, color.a * alpha)
	func draw_style_box(style: StyleBox, rect: Rect2) -> void:
		var copy: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		copy.bg_color = tint(copy.bg_color)
		copy.border_color = tint(copy.border_color)
		view.draw_style_box(copy, rect)
	func draw_line(a: Vector2, b: Vector2, color: Color, width: float, aa: bool) -> void: view.draw_line(a, b, tint(color), width, aa)
	func draw_texture_rect_region(texture: Texture2D, rect: Rect2, source: Rect2, color: Color) -> void: view.draw_texture_rect_region(texture, rect, source, tint(color))
	func draw_string_outline(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, outline: int, color: Color) -> void: view.draw_string_outline(font, pos, text, align, width, size, outline, tint(color))
	func draw_string(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, color: Color) -> void: view.draw_string(font, pos, text, align, width, size, tint(color))
	func draw_set_transform_matrix(transform: Transform2D) -> void: view.draw_set_transform_matrix(transform)
	func _register_tooltip(rect: Rect2, text: String) -> void: view._register_tooltip(rect, text)

func ink(view: Object, alpha: float) -> Object:
	if is_equal_approx(alpha, 1.0): return view
	var result := OpacityInk.new()
	result.view = view
	result.alpha = alpha
	return result

func draw_pips(view: Control, unit: Dictionary, frame: Rect2, alpha: float) -> void:
	if not Capacitor.Rules.is_capacitor(unit): return
	var centers: Array[Vector2] = Capacitor.pip_centers(frame, Capacitor.Rules.MAX_CHARGE)
	for index: int in range(centers.size()):
		var center: Vector2 = centers[index]
		var points := PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)])
		if index < int(unit.get("charge", 0)):
			view.draw_circle(center, Capacitor.PIP_SIZE * 0.5, Color(Capacitor.COLOR, Capacitor.GLOW_ALPHA * alpha))
			view.draw_colored_polygon(points, Color(Capacitor.COLOR, Capacitor.COLOR.a * alpha))
		else:
			points.append(points[0])
			view.draw_polyline(points, Color(Capacitor.EMPTY_COLOR, Capacitor.EMPTY_COLOR.a * alpha), 1.0, true)
