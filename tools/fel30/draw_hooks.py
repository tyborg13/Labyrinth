"""Anchors into retained painter code. Each insertion observes an existing paint."""
import re

INK = 'const Fel30Ink = preload("res://tools/fel30/ink.gd")\n'
COMMANDS = (
    "draw_texture_rect_region", "draw_texture_rect", "draw_texture", "draw_polygon",
    "draw_colored_polygon", "draw_rect", "draw_style_box", "draw_string",
    "draw_set_transform_matrix", "draw_set_transform",
)
BOARD_SCOPES = {
    "_draw_unit_sprite": '"unit", str(unit["type"]), unit["pos"], str(unit["key"])',
    "_draw_enemy_intent_compass": '"intent_icon", "intent compass", unit["pos"], str(unit["key"])',
    "_draw_enemy_intent_layout": '"intent_label", "expanded intent", Vector2i(-1, -1), str(layout.get("actor_key", ""))',
    "_draw_slice_intent_chip": '"intent_icon", str(badge.get("icon", "intent chip")), badge.get("tile", Vector2i(-1, -1)), str(badge.get("key", ""))',
    "_draw_npc_nameplate": '"name_label", "name plate", unit["pos"], str(unit["key"])',
    "_draw_trap_marker": '"trap", str(trap.get("element", "trap")), trap["pos"], str(trap.get("id", ""))',
    "_draw_objective_exit_icon": '"objective", "objective exit", tile',
    "_draw_objective_leader_beacon": '"objective", "objective leader", tile',
    "_draw_death_site_embers": '"pickup", "dropped embers", tile, "death_site_embers"',
    "_draw_terrain_object": '"prop", str(terrain.get("kind", "terrain")), terrain["pos"]',
    "_draw_terrain_health_bar": '"prop_health", str(terrain.get("kind", "terrain")), terrain["pos"]',
    "_draw_terrain_destruction": '"prop", str(terrain.get("kind", "terrain")), terrain["pos"]',
    "_draw_enemy_hud_connector": '"decoration", "intent connector"',
    "_draw_health_bar": '"health_bar", "health bar", unit["pos"], str(unit["key"])',
    "_draw_floating_text_popup": '"floating_number", "floating combat text", popup["entry"].get("tile", Vector2i(-1, -1))',
    "_draw_isolated_burrow_mark": '"telegraph", "burrow", tile',
    "_draw_slice_icefall": '"telegraph", "icefall", tile',
    "_draw_tile_damage_numeral": '"tile_number", "damage numeral"',
    "_draw_unit_statuses": '"status_owner", "status", unit["pos"], str(unit["key"])',
    "_draw_friendly_damage_chips": '"tag_chip", "friendly damage"',
    "_draw_movement_risk_chip": '"tag_chip", kind',
}


def function_start(source, name, code, replace):
    pattern = rf"^((?:static )?func {name}\([^\n]*\) -> [^\n]+:\n)"
    match = re.search(pattern, source, re.M)
    if not match:
        raise ValueError(f"Missing function {name}")
    return replace(source, match[0], match[0] + code)


def instrument(source, scopes, replace, view="self"):
    for name, args in scopes.items():
        source = function_start(source, name, f"\tvar _fel30_scope = Fel30Ink.scope({view}, {args})\n", replace)
    return source


def wrap(source, receivers):
    commands = "|".join(COMMANDS)
    if "self" in receivers:
        source = re.sub(rf'(?<![.\w"\'])\b({commands})\(', r"Fel30Ink.\1(self, ", source)
    for receiver in receivers:
        if receiver != "self":
            source = re.sub(rf"\b{receiver}\.({commands})\(", rf"Fel30Ink.\1({receiver}, ", source)
    return source


def scripts(path, replace):
    source = (path / "combat_board_view.gd").read_text()
    source = wrap(source, ["self"])
    # Keep the paint's contour calls, and measure its single foreground baseline.
    contour = "Fel30Ink.draw_string(self, font, baseline + direction * outline_size, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline)"
    source = replace(source, contour, contour.replace("Fel30Ink.draw_string(self, ", "draw_string("))
    source = re.sub(
        r"Fel30Ink.draw_string\(self, (font, (?:text|value)_baseline \+ INTENT_CONTOUR_SHADOW_OFFSET, [^\n]+)",
        r"draw_string(\1", source,
    )
    source = source.replace("ImageTexture.create_from_image(", "Fel30Ink.image_texture(")
    source = re.sub(r"AssetLoader.flip_texture_h\((texture|wall_row_texture|door_texture)\)", r"Fel30Ink.note_flip(AssetLoader.flip_texture_h(\1), \1)", source)
    source = instrument(source, BOARD_SCOPES, replace)
    source = function_start(source, "_draw", "\tFel30Ink.begin(self)\n", replace)
    stone = '\tif tile_id in ["pillar", "wall"]:\n\t\t_prop_command_cache.paint'
    source = replace(source, stone, '\tvar _fel30_stone = Fel30Ink.scope(self, "prop", tile_id, tile) if tile_id in ["pillar", "wall", "door"] else null\n' + stone)
    prop = '\t\tprop_index += 1\n\t\tvar prop: Dictionary = prop_var\n\t\tvar texture: Texture2D = _texture_for_scene_prop(prop)\n'
    source = replace(source, prop, prop + '\t\tvar _fel30_prop = Fel30Ink.scope(self, "prop", str(prop.get("kind", "scene prop")), tile)\n')
    ground = '\t\t_draw_world_texture(loot_texture, loot_rect)\n'
    source = replace(source, ground, '\t\tvar _fel30_loot = Fel30Ink.scope(self, "pickup", str(loot.get("kind", "pickup")), tile, str(loot.get("id", "")))\n' + ground)
    start = '\tvar bobbed_rect: Rect2 = Rect2(loot_rect.position + _equipment_pickup_bob_offset(pulse), loot_rect.size)\n'
    source = replace(source, start, start + '\tvar _fel30_loot: RefCounted\n')
    reveal = '\t\tif opacity > 0.0:\n\t\t\t_draw_world_texture(loot_texture, bobbed_rect, Color(Color.WHITE, opacity))'
    source = replace(source, reveal, reveal.replace('\n\t\t\t_draw', '\n\t\t\t_fel30_loot = Fel30Ink.scope(self, "pickup", str(loot.get("kind", "pickup")), tile, str(loot.get("id", "")))\n\t\t\t_draw'))
    bobbed = '\t_draw_world_texture(loot_texture, bobbed_rect)\n'
    source = replace(source, bobbed, '\t_fel30_loot = Fel30Ink.scope(self, "pickup", str(loot.get("kind", "pickup")), tile, str(loot.get("id", "")))\n' + bobbed)
    label = '\tfont.draw_string(canvas, local_text_pos, text, alignment, label_width, font_size, color)\n'
    source = replace(source, label, '\tFel30Ink.text(self, font, text_pos + local_text_pos * font_scale, text, alignment, label_width, font_size, color, 13)\n' + label)
    # Store the exact original text transform. Font dimensions scale with the popup.
    source = source.replace('Fel30Ink.text(self, font, text_pos + local_text_pos * font_scale, text, alignment, label_width, font_size, color, 13)', 'Fel30Ink.popup(self, font, text_pos, local_text_pos, text, alignment, label_width, font_size, font_scale, color)')
    mark = '\t\tif mark_icon != null:\n\t\t\tFel30Ink.draw_texture_rect(self, mark_icon, rect, false, Color.WHITE)\n'
    source = replace(source, mark, '\t\tvar _fel30_mark = Fel30Ink.scope(self, "marked", "Meteorfall", tile)\n' + mark)
    icon = '\t\t\t_slice_op("draw_texture_rect", [summon_icon, Rect2(_tile_center(tile)-Vector2.ONE*icon_side*0.5, Vector2.ONE*icon_side), false, Color(0.76, 1.0, 0.72)])'
    source = replace(source, icon, '\t\t\t_slice_op("_fel30_summon", [tile, summon_icon, icon_side])')
    source += '''
func _fel30_summon(tile: Vector2i, icon: Texture2D, side: float) -> void:
	var _fel30_scope = Fel30Ink.scope(self, "summon", "summon marker", tile)
	Fel30Ink.draw_texture_rect(self, icon, Rect2(_tile_center(tile)-Vector2.ONE*side*0.5, Vector2.ONE*side), false, Color(0.76, 1.0, 0.72))

func _fel30_threat(tile: Vector2i, inner: PackedVector2Array, alpha: float, hero: bool) -> void:
	var _fel30_scope = Fel30Ink.scope(self, "telegraph", "enemy telegraph", tile)
	Fel30Ink.diamond(self, _tile_polygon(tile))
	if hero: _draw_slice_threat_fill(inner, alpha)
	else: draw_colored_polygon(inner, Color(UiPaletteTokens.DANGER, ThreatTiles.FILL_ALPHA * alpha))
'''
    bar = '\tvar content_rect: Rect2 = _health_bar_content_rect(unit, rect)\n\tvar ghost: Dictionary'
    source = replace(source, bar, '\tvar content_rect: Rect2 = _health_bar_content_rect(unit, rect)\n\tFel30Ink.shape(self, content_rect, bar_alpha)\n\tvar ghost: Dictionary')
    numeral = '\t_label_ink.submit_number(font, baseline, text, width, font_size, fill, outline, outline_size, centered)\n'
    source = replace(source, numeral, numeral + '\tFel30Ink.text(self, font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, width, font_size, fill, 8)\n')
    terrain_bar = '\tvar preview: Dictionary = {} if terrain.has("destruction_progress") else _terrain_damage_preview(terrain)\n'
    source = replace(source, terrain_bar, '\tFel30Ink.shape(self, bar_rect, bar_alpha)\n' + terrain_bar)
    # Prop cache submits the tagged UVs originally produced by the art shader.
    cached = '\t\t"polygon": Fel30Ink.draw_polygon(self, command[1], command[2], command[3], command[4])'
    source = replace(source, cached, '\t\t"polygon":\n\t\t\tFel30Ink.art_polygon(self, command[1], command[2], command[3], command[4])\n\t\t\tdraw_polygon(command[1], command[2], command[3], command[4])')
    yield "combat_board_view.gd", source.replace("class_name CombatBoardView\n", "class_name CombatBoardView\n\n" + INK)

    source = (path / "board_layer_slices.gd").read_text()
    hero = 'board.call("_slice_op", "_draw_slice_threat_fill", [paint["inner"], alpha],'
    flat = 'board.call("_slice_op", "draw_colored_polygon", [paint["inner"], Color(Palette.DANGER, Threats.FILL_ALPHA * alpha)])'
    source = replace(source, hero, 'board.call("_slice_op", "_fel30_threat", [board._tile_at_world_point(paint["center"]), paint["inner"], alpha, true],')
    source = replace(source, flat, 'board.call("_slice_op", "_fel30_threat", [board._tile_at_world_point(paint["center"]), paint["inner"], alpha, false])')
    # The original paint already records its exact owning tile.
    source = source.replace('board._tile_at_world_point(paint["center"])', 'paint["fel30_tile"]')
    # All fill callers supply tile explicitly, including lifted painting.
    source = source.replace('_threat_fill_operations(board, paint)', '_threat_fill_operations(board, paint, tile)').replace(
        '_threat_fill_operations(board: Control, paint: Dictionary) -> void:', '_threat_fill_operations(board: Control, paint: Dictionary, tile: Vector2i) -> void:').replace('paint["fel30_tile"]', 'tile')
    yield "board_layer_slices.gd", wrap(source, ["board"]).replace("extends RefCounted\n", "extends RefCounted\n\n" + INK, 1)

    source = (path / "board_occlusion_silhouettes.gd").read_text()
    source = source.replace("ImageTexture.create_from_image(atlas)", "preload(\"res://tools/fel30/ink.gd\").image_texture(atlas)")
    yield "board_occlusion_silhouettes.gd", replace(source, 'screen["mask"] = mask', 'screen["fel30_planes"] = planes\n\tscreen["mask"] = mask')

    for name, receiver, scopes in [
        ("intent_badges.gd", "board", {
            "_draw_icon": '"intent_icon", key',
            "_draw_chip": '"intent_icon", str(badge.get("icon", "intent chip")), badge.get("tile", Vector2i(-1, -1)), str(badge.get("key", ""))',
        }),
        ("intent_callouts.gd", "board", {}),
        ("board_contour_text.gd", "canvas", {}),
        ("board_status_plates.gd", "view", {"draw_entry": '"status_chip", str(entry["icon"])'}),
        ("combat_art_treatment.gd", "canvas", {}),
        ("enemy_mechanics/burrow_view.gd", "view", {"draw_body": '"unit", str(unit["type"]), unit["pos"], str(unit["key"])',
            "_draw_badge": '"telegraph_icon", "Erupt", tile'}),
    ]:
        source = (path / name).read_text()
        if name == "combat_art_treatment.gd":
            source = replace(source, "var tagged: PackedVector2Array = uvs.duplicate()", "Fel30Ink.polygon(canvas, points, colors, uvs, texture)\n\tvar tagged: PackedVector2Array = uvs.duplicate()")
            source = wrap(source, ["canvas"]).replace("Fel30Ink.draw_polygon(canvas, points, colors, tagged, texture)", "canvas.draw_polygon(points, colors, tagged, texture)")
        elif name == "board_contour_text.gd":
            fill = 'canvas.draw_string(display_font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, Palette.BOARD_TITLE_FILL)'
            source = replace(source, fill, wrap(fill, ["canvas"]))
        else:
            source = wrap(source, [receiver])
        if name == "intent_callouts.gd":
            entry = '\t\tvar entry: Dictionary = layout["entry"]\n\t\tvar text: String'
            source = replace(source, entry, '\t\tvar entry: Dictionary = layout["entry"]\n'
                '\t\tvar _fel30_callout = Fel30Ink.scope(board, "intent_label", "intent callout", entry.get("tile", Vector2i(-1, -1)), str(entry.get("actor_key", "")))\n'
                '\t\tvar text: String')
        if name == "intent_badges.gd":
            tab = '\tfunc _draw() -> void:\n\t\tif painter.is_valid()'
            source = replace(source, tab, '\tfunc _draw() -> void:\n\t\tFel30Ink.begin(self)\n'
                '\t\tvar _fel30_tab = Fel30Ink.scope(self, "intent_icon", "intent tab", badge.get("tile", Vector2i(-1, -1)), str(badge.get("key", "")))\n'
                '\t\tif painter.is_valid()')
        source = instrument(source, scopes, replace, receiver)
        newline = source.index("\n")
        yield name, source[:newline + 1] + "\n" + INK + source[newline + 1:]

    source = (path / "asset_loader.gd").read_text()
    replacement = 'preload("res://tools/fel30/ink.gd").image_texture('
    yield "asset_loader.gd", source.replace("ImageTexture.create_from_image(", replacement)
