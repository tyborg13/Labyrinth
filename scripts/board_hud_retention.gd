extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")
const Forecast = preload("res://scripts/combat_hud_forecast.gd")
const Pulse = preload("res://scripts/combat_preview_pulse.gd")
const Tooltip = preload("res://scripts/tooltip_loop_context.gd")
const Kindle = preload("res://scripts/enemy_mechanics/kindle_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func enabled(board: Control) -> bool:
	# The perf138 baseline retires unrouted children in its draw-time lifecycle.
	return board.get_script().resource_path == "res://scripts/combat_board_view.gd" and not board._confirm_draw_baseline() and not board._board_redraw_baseline()

static func health_method(method: String) -> bool:
	return method in ["_draw_health_bar_entry", "_draw_health_bar_text", "_draw_health_damage_preview"]

static func has_live_preview_clock(source: Control) -> bool:
	var shown: Dictionary = source.presentation
	return not bool(shown.get("reduced_motion", false)) and not shown.has("damage_preview_time_seconds") and (
		Forecast.needs_pulse(shown) or not source._damage_preview_map().is_empty())

static func piece_inputs(source: Control, method: String, args: Array, unit: Dictionary) -> Variant:
	var shown: Dictionary = source.presentation
	var alpha: float = source._plate_opacity(unit) if health_method(method) else 1.0
	if alpha <= 0.0: return [0.0]
	match method:
		"_draw_health_bar_entry":
			var entry: Dictionary = args[0]
			var frame: Rect2 = source._status_plate_layout.resolve(source, unit, entry["rect"])["frame"]
			var preview: Dictionary = source._unit_damage_preview(unit)
			var style: StringName = source._health_bar_visual_style(unit)
			var layout: Dictionary = entry.get("layout", {})
			return [alpha, frame, _health_text(source, unit, preview, shown), style,
				texture_inputs(source._health_bar_frame_textures.get(style)), source._health_bar_owner_alpha(unit), layout.get("connector"), layout.get("border"),
				source.health_ghost_tracker.sample(str(unit.get("key", "")))]
		"_draw_health_bar_text":
			return [alpha, args[1], args[3], _health_text(source, unit, args[2], shown)]
		"_draw_health_damage_preview":
			return [alpha, args[1], unit.get("hp"), unit.get("max_hp"), args[2], Pulse.alpha(shown, bool(args[2].get("lethal", false)))]
		"_draw_slice_intent_chip":
			return [chip_inputs(args[0]), badge_tooltip(source, args[0])]
		"_draw_unit_hud_details":
			return _details(source, unit)
	return null

static func texture_inputs(texture: Texture2D) -> Array:
	if texture == null: return []
	var inputs: Array = [texture, texture.get_size()]
	if texture is AtlasTexture: inputs.append_array([texture.region, texture.margin, texture.filter_clip, texture_inputs(texture.atlas)])
	return inputs

static func tab_inputs(badge: Dictionary) -> Array:
	var secondary: String = str(badge.get("secondary_icon", ""))
	var condition: String = str(badge.get("condition_icon", ""))
	return [badge.get("alpha", 1.0), badge.get("danger"), badge.get("family"), badge.get("number"),
		badge.get("secondary_number"), secondary, condition, texture_inputs(Icons.icon_texture(secondary)),
		texture_inputs(Icons.icon_texture(condition)), Typography.ui_font()]

static func chip_inputs(badge: Dictionary) -> Array:
	var contextual: bool = bool(badge.get("contextual", false))
	var inputs: Array = [contextual, badge["center"], badge.get("alpha", 1.0), badge.get("danger"), badge.get("family"),
		badge.get("cancelled", false), badge.get("repeats", 0), texture_inputs(Icons.icon_texture(str(badge["icon"]))), tab_inputs(badge)]
	if contextual:
		var rule: String = str(badge.get("rule_icon", ""))
		inputs.append_array([rule, texture_inputs(Icons.icon_texture(rule)), badge.get("unfurled", false)])
	return inputs

static func badge_tooltip(source: Control, badge: Dictionary) -> Array:
	var key: String = str(badge.get("key", ""))
	var loop_source: Dictionary = Tooltip.actor_source(source, key)
	var term: String = Tooltip.badge_term(source, key, loop_source)
	if term.is_empty(): return []
	var label: String = source.enemy_intent_tooltip(key)
	if label.is_empty(): return []
	return [{"rect": badge.get("rect", Rect2()), "tooltip": label, "loop_source": loop_source, "loop_term": term}] if (badge.get("rect", Rect2()) as Rect2).has_area() else []

static func environment(source: Control) -> Array:
	return [source.get_theme_default_font(), Typography.ui_font(), Typography.heavy_ui_font(), Typography.display_font(),
		Typography.ui_scale(source), source.material, source._art_treatment_enabled]

static func piece_unit(method: String, args: Array) -> Dictionary:
	if method == "_draw_health_bar_entry": return args[0]["unit"]
	if method == "_draw_unit_hud_details": return args[0][0]
	return args[0]

static func record_paint(canvas: Control) -> void:
	if not canvas.has_meta("rd03_canvas") or canvas._render_slice_ops.is_empty() or not enabled(canvas): return
	var operation: Array = canvas._render_slice_ops[0]
	var method: String = operation[0]
	if not health_method(method) and method not in ["_draw_slice_intent_chip", "_draw_unit_hud_details"]: return
	var paint: Variant = piece_inputs(canvas, method, operation[1], piece_unit(method, operation[1]))
	if paint != null:
		canvas.set_meta("perf148_painted_receipt", [environment(canvas), paint, canvas._tooltip_regions].duplicate(true))

static func _health_text(source: Control, unit: Dictionary, preview: Dictionary, shown: Dictionary) -> Array:
	return [source._health_bar_fill_hp(unit, preview), unit.get("max_hp"), str(unit.get("role", "")),
		preview.is_empty(), source._health_bar_defers_damage_preview(preview),
		Pulse.alpha(shown) if Forecast.field_is_preview(unit, "hp", preview) else 1.0]

static func _details(source: Control, unit: Dictionary) -> Variant:
	if source._hud_layout_entries_cache.is_empty(): return null
	if not source._umbra_actor_clip_for_unit(unit).is_empty(): return []
	var key: String = str(unit.get("key", ""))
	for entry: Dictionary in source._hud_layout_entries_cache:
		if entry.get("actor_key") != key: continue
		if entry["kind"] == "npc": return null
		var layout: Dictionary = entry.get("layout", {})
		var title: String = layout.get("intent_name", "")
		var live_tooltip: String = ""
		if title in ["Fade", "Lob Slag", "Erupt", "Icefall"] and not Tooltip.intent_term(title, layout.get("loop_source", {})).is_empty():
			live_tooltip = source.enemy_intent_tooltip(key)
		if entry["kind"] == "boss": return [layout, live_tooltip, source._keyword_icon_textures]
		var statuses: Dictionary = source._status_plate_layout.resolve(source, unit, entry["health_rect"])
		var clocks: Array = []
		var shown: Dictionary = source.presentation
		for pieces: Array in [statuses["defenses"], statuses["statuses"]]:
			for piece: Dictionary in pieces:
				if bool(piece.get("predicted", false)) or bool(piece.get("hud_forecast", false)): clocks.append(Pulse.alpha(shown))
		for piece: Dictionary in statuses["statuses"]:
			clocks.append(source.status_pop_tracker.progress(key, str(piece["icon"])))
		return [entry, statuses["frame"], statuses["defenses"], statuses["statuses"], clocks,
			unit.get("type"), unit.get("charge", 0), unit.get("is_leader", false),
			Kindle.badge_scale(shown, key), shown.get("reduced_motion", false), live_tooltip, source._keyword_icon_textures]
	return []

static func direct_inputs(source: Control, operations: Array) -> Variant:
	# Retain only empty direct groups. Terrain and special HUD painters use
	# their release draw paths, which can bind textures or sample a clock.
	for operation: Array in operations:
		match str(operation[0]):
			"_draw_noctyrax_brazier_markers":
				if not (source.combat_state.get("guardian_braziers", []) as Array).is_empty(): return null
			"_draw_slice_hud_chips":
				if not (source.presentation.get("friendly_damage_chips", []) as Array).is_empty() or not (source.presentation.get("en05_reflect_preview", {}) as Dictionary).is_empty(): return null
			_: return null
	return []
