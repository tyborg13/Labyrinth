extends RefCounted
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func enemy(type: String) -> Dictionary:
	return {"kind": "enemy", "id": type}

static func term_in(text: String, source: Dictionary) -> String:
	for term: String in Glossary.ids_in_text(text):
		if not Registry.find(term, source).is_empty(): return term
	return ""

static func panel_for_text(text: String, source: Dictionary) -> Control:
	var started: int = Time.get_ticks_usec()
	var term: String = term_in(text, source)
	if term.is_empty(): return null
	var row: Dictionary = Registry.find(term, source)
	if not FileAccess.file_exists(str(row["asset_path"])): return null
	var lines: PackedStringArray = text.split("\n", false)
	var title: String = lines[0] if not lines.is_empty() else ""
	var body := PackedStringArray()
	for i: int in range(1, lines.size()): body.append(lines[i])
	var panel: Control = load("res://scripts/ui_tooltip_panel.gd").make_icon_lines(Icons.icon_texture(term), title, body, term, source)
	panel.set_meta("tooltip_loop_build_usec", Time.get_ticks_usec() - started)
	return panel

static func tooltip_sources(view: Control) -> Array:
	# Same front-to-back hit-test order as CombatBoardView._get_tooltip.
	# Per-actor HUD commands always route to aim-focus canvases, even at rest.
	var sources: Array = view._retained_render_layers().duplicate()
	for record: Dictionary in view._aim_focus.canvases.values():
		if is_instance_valid(record.canvas) and record.canvas.visible and record.hud: sources.append(record.canvas)
	sources.reverse()
	sources.append(view)
	return sources

static func board_source(view: Control, text: String) -> Dictionary:
	# Registrations carry the actor at draw time, so identical definitions on
	# another enemy cannot inherit the hovered actor's loop.
	for canvas: Control in tooltip_sources(view):
		for index: int in range(canvas._tooltip_regions.size() - 1, -1, -1):
			var region: Dictionary = canvas._tooltip_regions[index]
			if str(region.get("tooltip", "")) == text and (region.get("rect", Rect2()) as Rect2).has_point(view._last_pointer_position):
				return region.get("loop_source", {})
	return {}

static func actor_source(view: Control, key: String) -> Dictionary:
	for unit: Dictionary in view.combat_state.get("enemies", []):
		if "enemy_%d" % int(unit.get("id", -1)) == key: return enemy(str(unit.get("type", "")))
	return {}

static func register_badge(view: Control, badge: Dictionary, source: Dictionary) -> void:
	if not Registry.has_source(source): return
	var text: String = view.enemy_intent_tooltip(str(badge.get("key", "")))
	if not term_in(text, source).is_empty(): view._register_tooltip(badge.get("rect", Rect2()), text)

static func register_title(view: Control, rect: Rect2, title: String, source: Dictionary) -> void:
	for row: Dictionary in Registry.entries():
		if Registry.find(str(row["term"]), source).is_empty(): continue
		var titles: Variant = row.get("intent_titles", [])
		if (titles is String and titles == "*") or (titles is Array and titles.has(title)):
			view._register_tooltip(rect, Icons.tooltip(str(row["term"])))
			return

static func outer_popup_window(source: Dictionary) -> Control:
	for row: Dictionary in Registry.entries():
		var loop: Dictionary = Registry.find(str(row["term"]), source)
		if loop.is_empty() or not FileAccess.file_exists(str(loop["asset_path"])): continue
		var window := preload("res://scripts/tooltip_loop_view.gd").new()
		window.asset_path = str(loop["asset_path"])
		window.set_meta("tooltip_loop_id", loop["id"])
		window.fit_to_content_width()
		return window
	return null
