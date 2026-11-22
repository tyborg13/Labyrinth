extends RefCounted
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func enemy(type: String) -> Dictionary:
	return {"kind": "enemy", "id": type}

static func card_panel_for_text(text: String, source: Dictionary, term_hint: String = "", icon_key: String = "") -> Control:
	if not term_hint.is_empty(): return panel_for_text(text, source, term_hint, icon_key)
	var title: String = text.get_slice("\n", 0).strip_edges()
	var term: String = str(Glossary.lookup(title).get("id", ""))
	var row: Dictionary = Registry.find(term, source)
	var match_source: Dictionary = row.get("source_match", {})
	if not (row.get("exact_keyword", false) or match_source.has("id") or match_source.has("ids")) or not Registry.media_available(row):
		return null
	return panel_for_text(text, source, term)

static func enemy_unit(unit: Dictionary) -> Dictionary:
	var source: Dictionary = enemy(str(unit.get("type", "")))
	if source["id"] == "slag_mortar" and bool(unit.get("is_leader", false)): source["variant"] = "slagmaster"
	return source

static func term_in(text: String, source: Dictionary) -> String:
	# A canonical heading identifies the panel. Definitions never affect routing.
	var title: String = str(Glossary.lookup(text.get_slice("\n", 0).strip_edges()).get("id", ""))
	return title if not Registry.find(title, source).is_empty() else ""

static func panel_for_text(text: String, source: Dictionary, term_hint: String = "", icon_key: String = "") -> Control:
	var started: int = Time.get_ticks_usec()
	var term: String = term_hint if not term_hint.is_empty() else term_in(text, source)
	var row: Dictionary = Registry.find(term, source)
	if row.is_empty() or not FileAccess.file_exists(str(row["asset_path"])): return null
	var lines: PackedStringArray = text.split("\n", false)
	var title: String = lines[0] if not lines.is_empty() else ""
	var body := PackedStringArray()
	for i: int in range(1, lines.size()): body.append(lines[i])
	var texture: Texture2D = Icons.icon_texture(icon_key if not icon_key.is_empty() else term)
	var panel: Control = load("res://scripts/ui_tooltip_panel.gd").make_icon_lines(texture, title, body, term, source)
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

static func _status_route(view: Control, text: String) -> Dictionary:
	for unit: Dictionary in view.plate_visibility.actors():
		for entry: Dictionary in view.plate_visibility.status_entries(unit):
			if str(entry.get("tooltip", "")) == text and (entry["rect"] as Rect2).has_point(view._last_pointer_position):
				return {"loop_source": actor_source(view, str(unit.get("key", ""))), "loop_term": entry.get("icon", "")}
	return {}

static func board_source(view: Control, text: String) -> Dictionary:
	return board_route(view, text).get("loop_source", {})

static func board_route(view: Control, text: String) -> Dictionary:
	if view.plate_visibility.tooltip_at(view._last_pointer_position) == text:
		return _status_route(view, text)
	# Follow the same hit order as the native board tooltip.
	for canvas: Control in tooltip_sources(view):
		for index: int in range(canvas._tooltip_regions.size() - 1, -1, -1):
			var region: Dictionary = canvas._tooltip_regions[index]
			if str(region.get("tooltip", "")) == text and (region.get("rect", Rect2()) as Rect2).has_point(view._last_pointer_position):
				return _status_route(view, text) if region.get("loop_term", "").is_empty() and region.get("loop_source", {}).is_empty() else region
	return {}

static func actor_source(view: Control, key: String) -> Dictionary:
	for unit: Dictionary in view.combat_state.get("enemies", []):
		if "enemy_%d" % int(unit.get("id", -1)) == key: return enemy_unit(unit)
	return {}

static func badge_term(view: Control, key: String, source: Dictionary) -> String:
	if not Registry.has_source(source): return ""
	for unit: Dictionary in view.combat_state.get("enemies", []):
		if "enemy_%d" % int(unit.get("id", -1)) == key:
			return intent_term(view._intent_display_name(unit.get("intent", {})), source)
	return ""

static func register_badge(view: Control, badge: Dictionary, source: Dictionary) -> void:
	var key: String = str(badge.get("key", ""))
	var term: String = badge_term(view, key, source)
	if not term.is_empty(): view._register_tooltip(badge.get("rect", Rect2()), view.enemy_intent_tooltip(key), term)

static func intent_term(title: String, source: Dictionary, move_rows: Variant = null) -> String:
	for row: Dictionary in Registry.entries():
		if row.get("keyword_only", false) or row["source_match"].get("kind") != "enemy" or Registry.find(str(row["term"]), source).get("id") != row["id"]: continue
		var titles: Variant = row.get("intent_titles", [])
		if titles is Array and titles.has(title): return str(row["term"])
		# In combat the intent includes traits. Known Moves supplies the
		# move's own rows, so a wildcard clip needs a matching keyword there.
		if titles is String and titles == "*" and (move_rows == null or _move_shows_loop(move_rows, source, row["id"])):
			return str(row["term"])
	return ""

static func _move_shows_loop(rows: Array, source: Dictionary, loop_id: String) -> bool:
	for tokens: Array in rows:
		for token: Dictionary in tokens:
			var term: String = str(token.get("glossary_key", token.get("icon", "")))
			if Registry.find(term, source).get("id") == loop_id: return true
	return false

static func register_title(view: Control, rect: Rect2, title: String, source: Dictionary) -> void:
	var term: String = intent_term(title, source)
	if term.is_empty(): return
	var text: String = Icons.tooltip(term)
	if title in ["Fade", "Lob Slag", "Erupt", "Icefall"]:
		var actor_key: String = str(view.get("_tooltip_loop_actor_key"))
		var detail: String = view.enemy_intent_tooltip(actor_key)
		if not detail.is_empty(): text = title + "\n" + detail
	view._register_tooltip(rect, text, term)

static func outer_popup_window(source: Dictionary) -> Control:
	for row: Dictionary in Registry.entries():
		if row.get("keyword_only", false) or row["source_match"].get("kind") != "enemy": continue
		var loop: Dictionary = Registry.find(str(row["term"]), source)
		if loop.get("keyword_only", false) or not Registry.media_available(loop): continue
		var window := preload("res://scripts/tooltip_loop_view.gd").new()
		window.asset_path = str(loop["asset_path"])
		window.set_meta("tooltip_loop_id", loop["id"])
		window.fit_to_content_width()
		return window
	return null
