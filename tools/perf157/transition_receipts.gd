extends RefCounted

const Paint = preload("res://tools/perf148/paint_receipts.gd")

static func capture(probe: SceneTree, trigger: String) -> void:
	if trigger not in ["B_cancel", "A_confirm"]: return
	var enemies: Array = probe._scene._combat_state.get("enemies", [])
	var is_tharokh: bool = enemies.any(func(unit: Dictionary) -> bool: return unit.get("type") == "tharokh")
	var room: String = "tharokh" if is_tharokh else "normal"
	var action: String = "cancel" if trigger == "B_cancel" else "confirm"
	var path: String = probe._output.path_join("%s-%s.png" % [room, action])
	var image: Image = probe._canvas.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	if image.save_png(path) != OK: probe._errors.append("Failed to save " + path)
	else: print(path)

# Record the routed depth commands, cached prop commands and resolved sprite /
# outline inputs. Live viewport pixels and wall-clock shader passes require the
# native proof. Report those owners separately from these deterministic inputs.
static func collect(board: Control) -> Dictionary:
	var tiles: Dictionary = {}
	var bodies: Dictionary = {}
	for layer: Control in board._scene_render_layers:
		var tile: Vector2i = layer._render_layer_tile
		var id: String = "%d,%d/%d" % [tile.x, tile.y, layer._render_layer_scene_effect_pass]
		var paint: Array = []
		var sources: Array = [layer]
		sources.append_array(layer._layer_slices.canvases)
		for source: Control in sources:
			if not source.is_visible_in_tree(): continue
			for operation: Array in source._render_slice_ops:
				var content: Variant = _tile_operation(board, source, tile, operation)
				if content != null: paint.append([content, source.get_meta("rd04_alpha", 1.0)])
		if not paint.is_empty(): tiles[id] = paint
	var team = board._occlusion_silhouettes.team
	for key: String in team.bodies:
		var canvas: Control = team.bodies[key]
		if not canvas.is_visible_in_tree(): continue
		var unit: Dictionary = canvas._unit_outline_actor
		var entry: Dictionary = team.entries.get(key, {})
		var sprite: Sprite2D = entry.get("sprite")
		var body: Dictionary = {
			"tile": canvas._render_layer_tile,
			"role": unit.get("role", ""),
			"texture": _texture(canvas._texture_for_unit(unit)),
			"rect": canvas._unit_draw_rect(unit),
			"compass": canvas._intent_compass_paint_descriptor(unit, canvas.presentation),
			"clip": canvas._umbra_actor_clip_for_unit(unit),
			"impact": canvas._unit_impact_strength(unit),
			"shadow": canvas._unit_shadow_alpha_scale(unit),
			"burrowed": bool(unit.get("burrowed", false)),
			"aim_tint": _aim_tint(board, canvas),
			"reveal_alpha": canvas.modulate.a,
		}
		if is_instance_valid(sprite):
			body["rim"] = [sprite.visible, sprite.position, sprite.scale,
				_texture(sprite.texture), entry.get("alpha_signature", [])]
		bodies[key] = body
	var clock_tiles: Array = []
	for tile: Vector2i in board.LayerRedraws.targeting_clock_tiles(board):
		clock_tiles.append("%d,%d/0" % [tile.x, tile.y])
	clock_tiles.sort()
	return Paint._stable({"scene_tiles": tiles, "bodies": bodies, "clock_tiles": clock_tiles})

static func _tile_operation(board: Control, source: Control, tile: Vector2i, operation: Array) -> Variant:
	match str(operation[0]):
		"_draw_isolated_props":
			var commands: Array = []
			for slot: Dictionary in source._prop_command_cache._slots.values():
				commands.append_array(slot["commands"])
			return [operation[0], commands] if not commands.is_empty() else null
		"_draw_board_surface":
			var surface: Dictionary = source.combat_state.get("surfaces", {}).get(source._tile_paint_inputs.surface_key(tile), {})
			var events: Array = []
			for event: Dictionary in source.presentation.get("surface_preview_events", []):
				if event.get("tile") == tile or (event.get("tiles", []) as Array).has(tile): events.append(event)
			return [operation[0], surface, events] if not surface.is_empty() or not events.is_empty() else null
		"_draw_noctyrax_refuge_tile":
			var braziers: Array = source.combat_state.get("guardian_braziers", [])
			return [operation[0], braziers] if not braziers.is_empty() else null
		"_draw_elemental_scene_depth_pass":
			if not board._elemental_scene_depth_tiles_for_presentation(source.presentation).has(tile): return null
			return [operation, source.presentation.get("effect", {}), source.presentation.get("effect_progress", 1.0)]
	return operation

static func _aim_tint(board: Control, body: Control) -> Variant:
	for record: Dictionary in board._aim_focus.canvases.values():
		if bool(record.hud) or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		if canvas.get_parent() == body and canvas.visible:
			return canvas.get_meta("rd03_target", canvas.self_modulate)
	return Color.WHITE

static func _texture(texture: Texture2D) -> Variant:
	if texture is AtlasTexture:
		return [_texture(texture.atlas), texture.region, texture.margin]
	return Paint._stable(texture)
