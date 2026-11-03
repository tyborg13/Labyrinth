extends RefCounted
## Shared draw/proof geometry, using the renderer's already placed actor HUDs.

const Badges = preload("res://scripts/intent_badges.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const HUD_GAP: float = 6.0
const STATUS_ICON_GAP: float = 6.0

static func layouts(board: Control, entries: Array, font: Font, font_size: int, outline: float) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if entries.is_empty(): return result
	var units: Array = board.call("_hud_layout_units")
	var hud_entries: Array = board.get("_hud_layout_entries_cache")
	if hud_entries.is_empty(): hud_entries = board.call("_build_hud_layout_data", units).get("entries", [])
	var actors: Dictionary = {}
	var hud_by_actor: Dictionary = {}
	for hud: Dictionary in hud_entries: hud_by_actor[str(hud.get("actor_key", ""))] = hud
	var obstacles: Array[Rect2]
	obstacles.assign(board.call("_fixed_hud_collision_rects", units, font))
	for unit: Dictionary in units:
		if str(unit.get("role", "")) == "npc": continue
		var health: Rect2 = Badges.health_rect(board, unit)
		var key: String = str(unit.get("key", ""))
		actors[key] = {"health": health, "intents": []}
		if str(unit.get("role", "")) == "enemy":
			var layout: Dictionary = hud_by_actor.get(key, {}).get("layout", {})
			# Use the renderer's complete geometry, including leader crests,
			# status/defense badges and the full placed intent contour.
			obstacles.append_array(board.call("_enemy_hud_collision_rects", unit, health, layout.get("intent_rect", Rect2())))
	for hud: Dictionary in hud_entries:
		var key: String = str(hud.get("actor_key", ""))
		var lines: Array = (hud.get("layout", {}) as Dictionary).get("line_rects", [])
		if actors.has(key): actors[key]["intents"] = lines.duplicate()
	for badge: Dictionary in Badges.layouts(board, (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", [])):
		for field: String in ["rect", "order_rect"]:
			var rect: Rect2 = badge.get(field, Rect2())
			if rect.has_area(): obstacles.append(rect)
			if actors.has(str(badge["key"])): actors[str(badge["key"])]["intents"].append(rect)
	for entry: Dictionary in entries:
		var actor: Dictionary = actors.get(str(entry.get("actor_key", "")), {})
		if actor.is_empty(): continue
		result.append(place(entry, actor["health"], actor["intents"], obstacles, font, font_size, outline))
	return result

static func place(entry: Dictionary, health: Rect2, intents: Array, obstacles: Array, font: Font, font_size: int, outline: float) -> Dictionary:
	var text: String = str(entry.get("text", ""))
	var ink: Rect2 = _ink_rect(text, font, font_size)
	var cap: Rect2 = _ink_rect("H", font, font_size)
	var top: float = health.position.y
	for rect: Rect2 in intents:
		if rect.has_area(): top = minf(top, rect.position.y)
	var baseline := Vector2(health.get_center().x - ink.get_center().x, top - HUD_GAP - ink.end.y - outline)
	var text_rect := Rect2(baseline + ink.position, ink.size).grow(outline)
	var icon_rect := Rect2()
	if not str(entry.get("icon", "")).is_empty():
		icon_rect = Rect2(Vector2(text_rect.position.x - STATUS_ICON_GAP - cap.size.y, baseline.y + cap.position.y), Vector2.ONE * cap.size.y)
	var bounds: Rect2 = text_rect.merge(icon_rect) if icon_rect.has_area() else text_rect
	var lift: float = 0.0
	# Adjacent actors can put another bar above the acting enemy's bar. Keep
	# centring fixed and lift only as far as required, with the same 6px gap.
	# Reserve the entire existing upward float so later frames cannot enter HUD.
	for _pass: int in range(obstacles.size() + 1):
		var moved: bool = false
		for obstacle: Rect2 in obstacles:
			var swept := Rect2(bounds.position + Vector2(0.0, lift - FloatingText.ARC_RISE_HEIGHT), bounds.size + Vector2(0.0, FloatingText.ARC_RISE_HEIGHT))
			if obstacle.has_area() and swept.intersects(obstacle):
				lift = obstacle.position.y - HUD_GAP - bounds.end.y
				moved = true
		if not moved: break
	var motion: Vector2 = entry.get("motion_offset", Vector2.ZERO)
	var offset := Vector2(0.0, lift + minf(0.0, motion.y))
	return {"entry": entry, "health_rect": health, "anchor_top": top,
		"baseline": baseline + offset, "text_rect": Rect2(text_rect.position + offset, text_rect.size),
		"icon_rect": Rect2(icon_rect.position + offset, icon_rect.size), "rect": Rect2(bounds.position + offset, bounds.size)}

static func _ink_rect(text: String, font: Font, font_size: int) -> Rect2:
	var line := TextLine.new()
	line.add_string(text, font, font_size)
	var server: TextServer = TextServerManager.get_primary_interface()
	var bounds := Rect2()
	var cursor: float = 0.0
	# Use the same shaped glyphs, offsets and advances as draw_string, including
	# bearings and ligatures. Logical advance/line boxes are not visible edges.
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = glyph["font_rid"]
		for _repeat: int in range(int(glyph["repeat"])):
			if rid.is_valid():
				var cache_size := Vector2i(int(glyph["font_size"]), 0)
				var offset: Vector2 = server.font_get_glyph_offset(rid, cache_size, int(glyph["index"]))
				var size: Vector2 = server.font_get_glyph_size(rid, cache_size, int(glyph["index"]))
				var rect := Rect2(Vector2(cursor, 0.0) + (glyph["offset"] as Vector2) + offset, size)
				if rect.has_area(): bounds = bounds.merge(rect) if bounds.has_area() else rect
			cursor += float(glyph["advance"])
	return bounds
