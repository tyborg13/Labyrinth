extends RefCounted
## Patch only cached script resources in this probe process. Exact source
## anchors fail closed if a release painter changes under the census.

const TRACE_PATH := "res://tools/fel14/paint_trace.gd"
const TRACE := 'preload("' + TRACE_PATH + '")'
const BOARD := "combat_board_view"
const RUN := "run_scene"
const PRIMITIVES := "draw_(?:string(?:_outline)?|texture(?:_rect(?:_region)?)?|rect|circle|arc|line|polyline|colored_polygon|polygon|style_box|set_transform(?:_matrix)?)"
const BOARD_FUNCTIONS := [
	"_draw_health_bar", "_draw_health_bar_text", "_draw_health_damage_preview", "_draw_terrain_health_bar",
	"_draw_unit_statuses", "_draw_enemy_intent_layout", "_draw_enemy_intent_title", "_draw_token_row",
	"_draw_token_modifier_marker", "_draw_aoe_token_tile", "_draw_keyword_icon", "_draw_outlined_string", "_draw_leader_marker",
	"_draw_npc_nameplate", "_draw_noctyrax_brazier_markers", "_draw_objective_exit_icon", "_draw_objective_leader_beacon",
	"_draw_meteor_mark_badges", "_draw_collision_markers", "_draw_lethal_preview_icon", "_draw_floating_text_popup",
	"_draw_movement_risk_chip", "_draw_status_text", "_draw_ground_items_below_path", "_draw_world_texture",
	"_draw_trap_marker", "_draw_elemental_trap_floor_overlay", "_draw_equipment_pickup", "_draw_enemy_intent_compass", "_draw_controller_door_chevron"
]
const PAINTERS := {
	"board_status_plates": ["draw_entry"],
	"board_plate_visibility": ["draw_pips"],
	"board_layer_slices": ["draw_intent_chip"],
	"intent_badges": ["_draw_chip", "_draw_tab", "_draw_disc", "_draw_icon", "_draw_repeat_pip", "_draw_number", "_draw_rule_rider"],
	"intent_callouts": ["draw"],
	"board_contour_text": ["draw_title"],
	"section_map_skin": ["draw_medallion", "draw_unknown_room"],
	"enemy_mechanics/icefall_view": ["draw_badges"],
	"enemy_mechanics/burrow_view": ["draw_badges"],
	"enemy_mechanics/lob_view": ["draw_mark_badge"],
	"enemy_mechanics/capacitor_view": ["draw_telegraphs"],
}
static var failure: String
static var _raised_labels: bool

static func install() -> bool:
	failure = ""
	_raised_labels = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd").contains("func _draw_tile_damage_numeral(")
	if _raised_labels:
		var ink: Dictionary = load("res://scripts/board_label_ink.gd").get_script_constant_map()
		load(TRACE_PATH).set("numeral_band", ink["TILE_DAMAGE_Z"])
		load(TRACE_PATH).set("feedback_band", ink["FLOATING_TEXT_Z"])
	var qualified := RegEx.create_from_string("\\b(view|board|canvas)\\.(" + PRIMITIVES + ")\\(")
	var direct := RegEx.create_from_string("(?<![.\\w])(" + PRIMITIVES + ")\\(")
	var patches: Dictionary = PAINTERS.duplicate()
	patches[BOARD] = BOARD_FUNCTIONS
	for name: String in patches:
		var script: GDScript = load("res://scripts/" + name + ".gd")
		var body: String = script.source_code
		for method: String in patches[name]:
			var original: String = _method(body, method)
			if original.is_empty(): return false
			var next: String = qualified.sub(original, TRACE + ".$2($1, ", true)
			if name == BOARD:
				next = direct.sub(next, TRACE + ".$1(self, ", true)
				if _raised_labels and method == "_draw_floating_text_popup":
					next = next.replace("font.draw_string(canvas, ", TRACE + ".draw_rid_string(self, canvas, font, ")
					next = next.replace("RenderingServer.canvas_item_add_set_transform(canvas, ", TRACE + ".draw_rid_transform(self, canvas, ")
			body = body.replace(original, next)
		body = _group_hooks(name, body)
		if not _reload(script, body): return false
	for name: String in [RUN, "presentation_clock", "combat_pacing", "floating_combat_text", "combat_art_treatment"]:
		var script: GDScript = load("res://scripts/" + name + ".gd")
		var body: String = script.source_code
		match name:
			RUN:
				body = _before(body, "_animate_enemy_phase_steps", "\t\t_hero_facing.enemy_step = step", "next_beat(step)")
				body = _before(body, "_resolve_enemy_round", "\t\tawait preload(\"res://scripts/battlefield_rules/playback.gd\").animate(self, rule_display, beat)", "next_beat(beat)")
				body = _start(body, "_render_board_state", "submitted()")
				body = _before(body, "_resolve_enemy_round", "\tawait _combat_pacing.finish_enemies()", "end_beats()")
				body = _before(body, "_set_action_banner", "\taction_banner.visible = not text.is_empty()", 'submitted() if not text.is_empty() and text != action_banner.text else null')
			"presentation_clock":
				body = _replace(body, "if Engine.get_write_movie_path().is_empty(): return Time.get_ticks_usec()", "if Engine.get_write_movie_path().is_empty(): return " + TRACE + ".usec()")
				body = _replace(body, "if Engine.get_write_movie_path().is_empty(): return Time.get_ticks_msec()", "if Engine.get_write_movie_path().is_empty(): return " + TRACE + ".usec() / 1000")
			"combat_pacing":
				body = _replace(body, "var now: int = Time.get_ticks_usec()", "var now: int = " + TRACE + ".usec()")
			"combat_art_treatment":
				body = _before(body, "draw_rect", "\tdraw_polygon(canvas, points,", "texture_ink(canvas, sampled, rect, source_rect, tint.a)")
			"floating_combat_text":
				body = _before(body, "paint_icon", "\t\tRenderingServer.canvas_item_add_texture_rect(item, shadow_rect,", 'texture_ink(owner, ink["shadow"], shadow_rect, Rect2(), shadow_color.a, false)')
				body = _before(body, "paint_icon", "\t\tRenderingServer.canvas_item_add_texture_rect(item, outline_rect,", 'texture_ink(owner, ink["outline"], outline_rect, Rect2(), outline_color.a, false)')
				body = _before(body, "paint_icon", "\tRenderingServer.canvas_item_add_texture_rect(item, Rect2(origin", 'texture_ink(owner, texture, Rect2(origin + rect.position * scale, rect.size * scale), Rect2(), tint.a)')
		if not _reload(script, body): return false
	return true

static func _group_hooks(name: String, body: String) -> String:
	match name:
		BOARD:
			body = _start(body, "_draw", "clear(self)")
			body = _replace(body, '_slice_op("draw_texture_rect", [summon_icon,', '_slice_op("_fel14_summon_icon", [tile, summon_icon,')
			body += '\nfunc _fel14_summon_icon(tile_coord: Vector2i, texture: Texture2D, rect: Rect2, tiled: bool, tint: Color) -> void:\n'
			body += '\tvar _fel14_label = ' + TRACE + '.begin(self, "summon_marker", tile_coord)\n'
			body += '\t' + TRACE + '.draw_texture_rect(self, texture, rect, tiled, tint)\n'
			body = _start(body, "_draw_floating_text_popup", "popup(self, popup)", "var _fel14_label = ")
			var groups := {
				"_draw_health_bar": '"unit_health", unit',
				"_draw_health_bar_text": '"unit_health", unit',
				"_draw_terrain_health_bar": '"terrain_health", terrain',
				"_draw_enemy_intent_layout": '"expanded_intent", layout.get("actor_key", %s.boss_key(self))' % TRACE,
				"_draw_leader_marker": '"leader_crest", unit',
				"_draw_npc_nameplate": '"npc_name", unit',
				"_draw_objective_exit_icon": '"objective_threshold", tile',
				"_draw_objective_leader_beacon": '"objective_leader", tile',
				"_draw_trap_marker": '"trap_icon", trap',
				"_draw_equipment_pickup": '"loot_icon", loot',
				"_draw_status_text": '"board_status", "board"',
				"_draw_enemy_intent_compass": '"intent_compass", unit',
				"_draw_controller_door_chevron": '"door_focus_chevron", tile',
			}
			for method: String in groups: body = _start(body, method, "begin(self, " + groups[method] + ")", "var _fel14_label = ")
			body = _before(body, "_draw_health_bar", "\tSegmentedHealthBar.draw_bar(", "fill_ink(self, content_rect, bar_alpha)")
			body = _before(body, "_draw_elemental_trap_floor_overlay", "\t\t\tif PixelFxLayer.enabled()", 'begin(self, "trap_icon", trap, "activation")', "var _fel14_label = ")
			body = _before(body, "_draw_elemental_trap_floor_overlay", "\t\t\t\t_pixel_fx_layer.submit_raw(", "texture_ink(self, activation_texture, _trap_visual_draw_rect(trap), Rect2(), _trap_visual_modulate(trap).a)")
			body = _before(body, "_draw_terrain_health_bar", "\tSegmentedHealthBar.draw_bar(", "fill_ink(self, bar_rect, bar_alpha, true)")
			body = _before(body, "_draw_leader_marker", "\t_hud_triangles.circle(centre,", "circle_ink(self, centre, radius, UiPaletteTokens.INK_3.a)")
			body = _before(body, "_draw_slice_intent_chip", "\t_tooltip_loop_source = preload(", 'begin(self, "intent_badge", badge["key"], str(badge.get("icon", "")))', "var _fel14_label = ")
			body = _before(body, "_draw_noctyrax_brazier_markers", "\t\tvar plate :=", 'begin(self, "brazier_callout", tile)', "var _fel14_label = ")
			body = _before(body, "_draw_meteor_mark_badges", "\t\tvar center: Vector2 =", 'begin(self, "mark_medallion", tile, "Meteorfall")', "var _fel14_label = ")
			body = _before(body, "_draw_collision_markers", "\t\tvar rect := Rect2(center", 'begin(self, "collision_badge", tile)', "var _fel14_label = ")
			body = _before(body, "_draw_ground_items_below_path", "\t\t\t_draw_world_texture(loot_texture,", 'begin(self, "loot_icon", loot)', "var _fel14_label = ")
			body = _before(body, "_draw_tile_stone_props", "\t\t\t\t\t_draw_door_icon(", 'begin(self, "door_medallion", tile, icon_id)', "var _fel14_label = ")
			body = _before(body, "_draw_friendly_damage_chips", "\t\t_draw_movement_risk_chip(", 'begin(self, "friendly_damage_chip", chip.get("actor_key", ""))', "var _fel14_label = ")
			body = _before(body, "_draw_movement_risk_chips", "\t\t_draw_movement_risk_chip(", 'begin(self, "movement_risk_chip", tile)', "var _fel14_label = ")
			body = _before(body, "_draw_lethal_preview_icons", "\t\t_draw_lethal_preview_icon(_unit_draw_rect", 'begin(self, "lethal_icon", unit)', "var _fel14_label = ")
			body = _before(body, "_draw_lethal_preview_icons", "\t\t_draw_lethal_preview_icon(_terrain_rect_for_tile", 'begin(self, "lethal_icon", terrain)', "var _fel14_label = ")
			body = _before(body, "_draw_lethal_preview_icons", "\t\t\t_draw_lethal_preview_icon(_trap_visual_draw_rect", 'begin(self, "lethal_icon", trap)', "var _fel14_label = ")
			body = _before(body, "_draw_terrain_health_bar", "\tvar frame_texture:", "finish_glyphs()")
			body = _before(body, "_draw_health_bar", "\tvar frame_texture:", "finish_glyphs()")
			body = _before(body, "_draw_health_bar_text", "\tfor offset: Vector2 in [", "finish_glyphs()")
			body = _before(body, "_draw_health_bar_text", "\t" + TRACE + ".draw_string(self,", "resume_glyphs()")
			body = _before(body, "_draw_floating_text_popup", "\tif not shadow_offset.is_zero_approx():", "finish_glyphs()")
			var draw_fill: String = ".draw_rid_string(self, canvas, font, " if _raised_labels else ".draw_string(self, font, "
			body = _before(body, "_draw_floating_text_popup", "\t" + TRACE + draw_fill + "local_text_pos, text", "resume_glyphs()")
			if _raised_labels:
				body = _start(body, "_draw_tile_damage_numeral", "numeral(self, font, baseline, text, width, font_size, fill, outline, outline_size, centered)")
			body = _before(body, "_draw_outlined_string", "\tfor direction: Vector2 in", "finish_glyphs()")
			body = _before(body, "_draw_outlined_string", "\t" + TRACE + ".draw_string(self, font, baseline, text", "resume_glyphs()")
			body = _before(body, "_draw_enemy_intent_compass", "\t\tCombatArtTreatment.draw_ground_mark(self, base_texture,", "finish_glyphs()")
			body = _before(body, "_draw_enemy_intent_compass", "\t\tCombatArtTreatment.draw_ground_mark(self, emblem_texture,", "resume_glyphs()")
			body = _before(body, "_draw_enemy_intent_compass", "\tvar emblem_basis_x", "resume_glyphs()")
			body = _start(body, "_draw_unit_statuses", 'begin(self, "_owner", unit)', "var _fel14_owner = ")
		"board_status_plates":
			body = _start(body, "draw_entry", 'status(view, entry)', "var _fel14_label = ")
		"board_plate_visibility":
			body = _start(body, "draw_terrain_statuses", 'begin(view, "_owner", terrain)', "var _fel14_owner = ")
			body = _before(body, "draw_pips", "\t\tvar center:", 'begin(view, "charge_pip", unit, str(index + 1))', "var _fel14_label = ")
		"intent_badges":
			body = _before(body, "_draw_chip", "\tvar center:", 'begin(board, "intent_badge", badge["key"], str(badge.get("icon", "")))', "var _fel14_label = ")
			body = _before(body, "_draw_disc", "\t\ttriangle_batch.circle(", "circle_ink(board, center, MEDALLION_DIAMETER * 0.5, alpha)")
			body = _replace(body, "\t\tif painter.is_valid(): painter.call(self, badge, Typography.ui_font())", "\t\t" + TRACE + '.clear(self)\n\t\tvar _fel14_label = ' + TRACE + '.begin(self, "intent_tab", badge.get("key", ""), str(badge.get("icon", "")))\n\t\tif painter.is_valid(): painter.call(self, badge, Typography.ui_font())')
		"board_layer_slices":
			body = _before(body, "draw_intent_chip", "\t\ttriangle_batch.circle(", "circle_ink(board, center, Badges.MEDALLION_DIAMETER * 0.5, alpha)")
		"intent_callouts":
			body = _before(body, "draw", "\t\tvar icon:", 'begin(board, "intent_result", entry.get("actor_key", ""), text)', "var _fel14_label = ")
		"enemy_mechanics/icefall_view", "enemy_mechanics/burrow_view":
			body = _before(body, "draw_badges", "\t\tif not view._board_tile_is_visible_to_player(tile): continue", 'begin(view, "mark_medallion", tile, "' + ("Icefall" if "icefall" in name else "Burrow") + '")', "var _fel14_label = ")
		"board_contour_text":
			body = _start(body, "draw_title", "finish_glyphs()")
			body = _before(body, "draw_title", "\t" + TRACE + ".draw_string(canvas, display_font, baseline, value", "resume_glyphs()")
		"section_map_skin":
			body = _start(body, "draw_medallion", "finish_glyphs()")
			body = _before(body, "draw_medallion", "\tif icon != null:", "resume_glyphs()")
			body = _before(body, "draw_unknown_room", "\tif with_pool:", "finish_glyphs()")
			body = _before(body, "draw_unknown_room", "\tvar font: Font", "resume_glyphs()")
		"enemy_mechanics/capacitor_view":
			body = _before(body, "draw_telegraphs", "\t\t\tvar font:", 'begin(board, "tile_damage_badge", hit["to"], "Chain discharge")', "var _fel14_label = ")
		"enemy_mechanics/lob_view":
			body = _start(body, "draw_mark_badge", 'begin(view, "mark_medallion", tile, "Area mark" if damage == null else "Lob")', "var _fel14_label = ")
	return body

static func _method(body: String, method: String) -> String:
	var regex := RegEx.create_from_string("(?m)^(?:static )?func " + method + "\\(")
	var found: RegExMatch = regex.search(body)
	if found == null:
		failure = "missing painter " + method
		return ""
	var start: int = found.get_start()
	var end: int = body.find("\n\n", start)
	# Functions can contain blank lines; use the end of the indented body.
	var stop := RegEx.create_from_string("(?m)^\\S")
	var boundary: RegExMatch = stop.search(body, body.find("\n", start) + 1)
	if boundary != null: end = boundary.get_start()
	else: end = body.length()
	return body.substr(start, end - start)

static func _start(body: String, method: String, call: String, prefix: String = "") -> String:
	var function: String = _method(body, method)
	if function.is_empty(): return body
	var end: int = function.find("\n")
	return body.replace(function, function.insert(end + 1, "\t" + prefix + TRACE + "." + call + "\n"))

static func _before(body: String, method: String, anchor: String, call: String, prefix: String = "") -> String:
	var function: String = _method(body, method)
	if function.is_empty(): return body
	var offset: int = function.find("\n" + anchor)
	if offset < 0 or function.find("\n" + anchor, offset + 1) >= 0:
		failure = "missing or ambiguous trace anchor in " + method + ": " + anchor
		return body
	var indent: int = anchor.length() - anchor.lstrip("\t").length()
	return body.replace(function, function.insert(offset + 1, "\t".repeat(indent) + prefix + TRACE + "." + call + "\n"))

static func _replace(body: String, before: String, after: String) -> String:
	if body.count(before) != 1:
		failure = "missing or ambiguous trace anchor: " + before
		return body
	return body.replace(before, after)

static func _reload(script: GDScript, body: String) -> bool:
	if not failure.is_empty(): return false
	script.source_code = body
	var error: int = script.reload()
	if error != OK:
		failure = "cannot instrument %s (%d)" % [script.resource_path, error]
		return false
	return true
