extends RefCounted
## Translate the submitted masks, live rig pieces, and HUD controls into screen space.

const Assets = preload("res://scripts/asset_loader.gd")
const Ink = preload("res://tools/fel30/ink.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const SCREEN := Rect2(0, 0, 1920, 1080)

var rows: Array[Dictionary]
var _images: Dictionary
var _used_rects: Dictionary
var _missing: Dictionary
var _serial: int
var _viewports: Dictionary
var _viewport_images: Dictionary
var _rasterizing: bool
const Coverage = preload("res://tools/fel30/coverage.gd")
var _outlines: Dictionary
var _content: Dictionary
var _board: Control


func collect(scene: Node) -> Array[Dictionary]:
	_board = scene.board_view
	rows.clear()
	_viewports.clear()
	_viewport_images.clear()
	_used_rects.clear()
	_outlines.clear()
	_content.clear()
	_serial = 0
	var silhouettes: Node = _board.get("_occlusion_silhouettes")
	var units: Array = _board.call("_visible_units")
	for unit: Dictionary in units:
		var renderer: Node = _board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer) and is_instance_valid(renderer.get("viewport")):
			var viewport: SubViewport = renderer.get("viewport")
			_viewports[viewport.get_texture().get_instance_id()] = viewport
	if is_instance_valid(silhouettes):
		for entry: Dictionary in silhouettes.entries.values(): _outline(entry)
		for key: String in silhouettes.team.entries: _outline(silhouettes.team.entries[key], key)
		for data: Dictionary in silhouettes._content_tiles.values():
			if data.has("painter") and is_instance_valid(data["painter"]): _content[data["painter"]] = data
	_walk(_board, 0, 1.0)
	_floor(silhouettes)
	_hud(scene)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["z"] != b["z"]: return a["z"] < b["z"]
		return a["serial"] < b["serial"])
	for index: int in rows.size(): rows[index]["order"] = index
	return rows


func _identity(kind: String, what: String, tile: Vector2i = Vector2i(-1, -1), actor: String = "") -> Dictionary:
	return {"kind": kind, "what": what, "tile": tile, "actor": actor}


func _walk(node: Node, parent_z: int, parent_alpha: float) -> void:
	if node is Viewport: return
	var canvas: CanvasItem = node as CanvasItem
	var z: int = parent_z
	var alpha: float = parent_alpha
	if canvas != null:
		if not canvas.is_visible_in_tree() or canvas.is_queued_for_deletion(): return
		z = clampi((parent_z if canvas.z_as_relative and not canvas.top_level else 0) + canvas.z_index, -4096, 4096)
		alpha *= canvas.modulate.a
	if alpha <= 0.0: return
	# Behind-parent children draw before the parent's commands at equal z.
	for child: Node in node.get_children():
		if child is CanvasItem and child.show_behind_parent: _walk(child, z, alpha)
	if canvas != null:
		canvas.set_meta("fel30_order", [_serial, z])
		var own_alpha: float = alpha * canvas.self_modulate.a
		var tx: Transform2D = canvas.get_global_transform_with_canvas()
		var parent: Control = canvas.get_parent() as Control
		var clip := Rect2()
		if parent != null and parent.clip_contents:
			clip = parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size)
		for record: Dictionary in canvas.get_meta(Ink.ROWS, []):
			if parent != null and parent.clip_contents and not clip.has_area(): continue
			var part: Dictionary = record.duplicate()
			if clip.has_area(): part["clip"] = clip
			_add(part, tx * record["matrix"], z + int(record["z"]), own_alpha)
		if _outlines.has(canvas):
			_sprite(canvas, _outlines[canvas], tx, z, own_alpha)
		if _content.has(canvas): _show_through(_content[canvas], tx, z, own_alpha)
		if canvas is Label and _board.is_ancestor_of(canvas):
			_label(canvas, z, own_alpha)
		if canvas is PanelContainer and str(canvas.get_parent().name) == "SnareSealChips":
			_panel(canvas, "tag_backing", str(canvas.name), z)
		_serial += 1
	for child: Node in node.get_children():
		if not child is CanvasItem or not child.show_behind_parent: _walk(child, z, alpha)


func _sprite(sprite: Sprite2D, identity: Dictionary, tx: Transform2D, z: int, alpha: float) -> void:
	if sprite.texture == null: return
	var region: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	region.size /= Vector2(sprite.hframes, sprite.vframes)
	region.position += Vector2(sprite.frame_coords) * region.size
	if sprite.flip_h: region.position.x += region.size.x; region.size.x *= -1.0
	if sprite.flip_v: region.position.y += region.size.y; region.size.y *= -1.0
	var row: Dictionary = identity.duplicate()
	row.merge({"texture": sprite.texture, "rect": sprite.get_rect(), "region": region}, true)
	if row.has("rim"):
		var shader: ShaderMaterial = sprite.material
		var radius: Variant = shader.get_shader_parameter("radius_source")
		var rim_color: Variant = shader.get_shader_parameter("rim_color")
		if not radius is Vector2 or not rim_color is Color: return
		row["radius"] = radius
		var over: Variant = shader.get_shader_parameter("over_alpha")
		row["over_alpha"] = float(over) if over != null else 0.0
		row["rim_alpha"] = rim_color.a
	_add(row, tx, z, alpha)


func _mesh(node: Polygon2D, identity: Dictionary, tx: Transform2D, z: int, alpha: float) -> void:
	if node.polygon.size() < 3: return
	var points: PackedVector2Array = node.polygon.duplicate()
	if not node.skeleton.is_empty(): _skin(node, points)
	if not node.offset.is_zero_approx():
		for index: int in points.size(): points[index] += node.offset
	var groups: Array = node.polygons
	if groups.is_empty():
		var indices := PackedInt32Array()
		for index: int in points.size(): indices.append(index)
		groups = [indices]
	var uv: PackedVector2Array = node.uv
	if uv.size() != points.size(): uv = node.polygon
	for group: PackedInt32Array in groups:
		var piece := PackedVector2Array()
		var coords := PackedVector2Array()
		for index: int in group:
			piece.append(points[index])
			coords.append(node.texture_offset + uv[index].rotated(node.texture_rotation) * node.texture_scale)
		var row: Dictionary = identity.duplicate()
		row.merge({"polygon": piece, "uv": coords, "texture": node.texture, "alpha": node.color.a}, true)
		_add(row, tx, z, alpha)


func _skin(node: Polygon2D, points: PackedVector2Array) -> void:
	var skeleton: Skeleton2D = node.get_node_or_null(node.skeleton)
	if skeleton == null: return
	var summed := PackedVector2Array()
	summed.resize(points.size())
	var totals := PackedFloat32Array()
	totals.resize(points.size())
	var to_skeleton: Transform2D = skeleton.global_transform.affine_inverse() * node.global_transform
	var from_skeleton: Transform2D = to_skeleton.affine_inverse()
	for index: int in node.get_bone_count():
		var bone: Bone2D = skeleton.get_node_or_null(node.get_bone_path(index))
		if bone == null: continue
		var nudge: Transform2D = from_skeleton * skeleton.global_transform.affine_inverse() * bone.global_transform * bone.get_skeleton_rest().affine_inverse() * to_skeleton
		var weights: PackedFloat32Array = node.get_bone_weights(index)
		for vertex: int in mini(points.size(), weights.size()):
			var weight: float = weights[vertex]
			if weight <= 0.0: continue
			summed[vertex] += (nudge * points[vertex]) * weight
			totals[vertex] += weight
	for vertex: int in points.size():
		if totals[vertex] > 0.0: points[vertex] = summed[vertex] / totals[vertex]


func _outline(entry: Dictionary, fallback_key: String = "") -> void:
	var sprite: Sprite2D = entry.get("sprite")
	if not is_instance_valid(sprite): return
	var source: Dictionary = entry.get("source", {})
	var kind: String = str(source.get("kind", "unit"))
	var key: String = str(source.get("key", fallback_key))
	var data: Dictionary = source.get("data", entry.get("unit", {}))
	var row: Dictionary = _identity("edge", str(data.get("type", "occlusion edge")), source.get("tile", entry.get("tile", Vector2i(-1, -1))), key)
	row["rim"] = true
	if kind == "unit" and entry.has("fill_blockers"):
		var material: ShaderMaterial = sprite.material
		var parts: Array[Dictionary]
		var atlas: Texture2D = material.get_shader_parameter("fill_atlas")
		var image: Image = _image(atlas) if atlas != null else null
		var signature: Array = entry.get("fill_signature", [])
		for index: int in (entry["fill_blockers"] as Array).size():
			if image == null or signature.size() < 3: continue
			var blocker: Dictionary = entry["fill_blockers"][index]
			parts.append({"rect": blocker["rect"], "region": Rect2(blocker["region"]), "image": image, "alpha": signature[2][index]})
		var grid: Variant = material.get_shader_parameter("fill_grid")
		var fill: Variant = material.get_shader_parameter("fill_alpha")
		row["xray"] = {"alpha": float(fill) if fill != null else 0.0, "grid": grid if grid is Vector4 else Vector4.ZERO,
			"parts": parts, "screen_to_board": _board.get_global_transform_with_canvas().affine_inverse()}
	_outlines[sprite] = row


func _floor(silhouettes: Node) -> void:
	if not is_instance_valid(silhouettes): return
	for source: Dictionary in silhouettes.current_sources():
		var kind: String = source["kind"]
		if kind not in ["surface", "refuge", "exit"]: continue
		var tile: Vector2i = source["tile"]
		var layer: CanvasItem = _board.get("_pixel_ground") if kind == "surface" else _board.get("_overlay_render_layer")
		if not is_instance_valid(layer): layer = _board.get("_scene_render_layers_by_tile").get(tile)
		if not is_instance_valid(layer) or not layer.has_meta("fel30_order"): continue
		var order: Array = layer.get_meta("fel30_order")
		var name: String = str(source.get("surface_kind", ""))
		var row: Dictionary = _identity("surface" if kind == "surface" else "hazard" if kind == "refuge" else "objective_floor", kind if name.is_empty() else name, tile)
		row.merge({"polygon": source["diamond"], "diamond": true, "serial": order[0]})
		_add(row, _board.get_global_transform_with_canvas(), order[1], 1.0)


func _show_through(data: Dictionary, tx: Transform2D, z: int, alpha: float) -> void:
	var planes: Array = data.get("fel30_planes", [])
	if planes.is_empty(): return
	var bounds: Rect2 = data["bounds"]
	var grid: Vector4 = data["grid"]
	var subjects: Array = data["subjects"]
	var factors: PackedFloat32Array = data["factor_values"]
	for index: int in subjects.size():
		var source: Dictionary = subjects[index]["source"]
		var kind: String = source["kind"]
		var row: Dictionary = _identity("show_through", kind, source["tile"])
		row.merge({"rect": bounds, "mask_planes": planes, "mask_index": index, "floor_count": data["floor_count"],
			"mask_factors": factors, "mask_grid": grid, "restores": kind})
		var painter: CanvasItem = data["object_items"].get(source["key"], data["painter"])
		if is_instance_valid(painter) and painter.visible: _add(row, tx, z, alpha * 0.75)


func _label(node: Label, z: int, alpha: float) -> void:
	if node.text.is_empty(): return
	var host: String = str(node.get_parent().name)
	if not (node.text.begins_with("Seals") or host.begins_with("IntentTab")): return
	var font: Font = node.get_theme_font("font")
	var size: int = node.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var row: Dictionary = _identity("intent_label" if host.begins_with("IntentTab") else "tag_chip", host)
	row.merge({"text": node.text, "rect": Rect2(Vector2.ZERO, text_size.min(node.size))})
	_add(row, node.get_global_transform_with_canvas(), z, alpha)


func _hud(scene: Node) -> void:
	# The rail and hand are frameless. Use occupied slots, never empty layout boxes.
	var rail: Control = scene.get("_turn_order_bar")
	if is_instance_valid(rail):
		for child: Node in rail.get_children():
			if child is Control: _panel(child, "hud", "turn-order rail")
	var hand: Control = scene.get("hand_box")
	var scroll: Control = scene.get("hand_scroll")
	var hand_clip: Rect2 = Rect2() if scroll == null else scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scroll.size)
	if is_instance_valid(hand):
		for child: Node in hand.get_children():
			var widget: Control = scene._card_widget_descendant(child)
			if widget != null: _panel(widget, "hud", "hand", 4097, hand_clip)
	for field: String in ["mini_map_overlay", "log_overlay", "_boss_health_overlay", "left_action_stack", "top_bar", "relic_bar", "piles_bar"]:
		var control: Control = scene.get(field)
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		if field in ["top_bar", "left_action_stack", "relic_bar", "piles_bar"]:
			_hud_children(control, field.trim_prefix("_"))
		else: _panel(control, "hud", field.trim_prefix("_"))


func _hud_children(control: Control, name: String) -> void:
	for child: Node in control.get_children():
		if not child is Control or not child.is_visible_in_tree(): continue
		if child is Container and not child is PanelContainer: _hud_children(child, name)
		elif child is Label or child is BaseButton or child is PanelContainer or child is TextureRect:
			_panel(child, "hud", name)


func _panel(control: Control, kind: String, name: String, z: int = 4097, clip: Rect2 = Rect2()) -> void:
	if not control.is_visible_in_tree(): return
	var row: Dictionary = _identity(kind, name)
	row["rect"] = Rect2(Vector2.ZERO, control.size)
	if clip.has_area(): row["clip"] = clip
	_add(row, control.get_global_transform_with_canvas(), z, control.modulate.a * control.self_modulate.a)


func _add(record: Dictionary, tx: Transform2D, z: int, alpha: float) -> void:
	var row: Dictionary = record.duplicate()
	row["z"] = z
	if not row.has("serial"): row["serial"] = _serial
	_serial += 1
	row["alpha"] = float(row.get("alpha", 1.0)) * alpha
	if float(row["alpha"]) <= 0.0 or is_zero_approx(tx.determinant()): return
	row["inverse"] = tx.affine_inverse()
	var texture: Texture2D = row.get("texture")
	if texture != null:
		row["image"] = _image(texture)
		if row["image"] == null:
			if not _missing.has(texture.get_instance_id()):
				_missing[texture.get_instance_id()] = true
				print("FEL30 NO ALPHA kind=%s what=%s texture=%s size=%s" % [row["kind"], row["what"], texture.get_class(), texture.get_size()])
			return
	if row.has("polygon") and row.has("image"): _axis_aligned_quad(row)
	if row.has("polygon"):
		var points: PackedVector2Array = row["polygon"]
		if points.size() < 3: return
		row["triangles"] = Geometry2D.triangulate_polygon(points)
		var rect := Rect2(tx * points[0], Vector2.ZERO)
		for point: Vector2 in points: rect = rect.expand(tx * point)
		row["bounds"] = rect
	else:
		var rect: Rect2 = row["rect"]
		if is_zero_approx(rect.get_area()): return
		var pixels: Rect2 = rect.abs()
		if row.has("radius"):
			var radius: Vector2 = row["radius"]
			pixels = pixels.grow_individual(radius.x, radius.y, radius.x, radius.y)
		elif row.has("image") and not row.get("transpose", false):
			pixels = _texture_bounds(row, rect)
		row["bounds"] = tx * pixels
	var bounds: Rect2 = row["bounds"]
	if row.has("clip"): bounds = bounds.intersection(row["clip"])
	if bounds.has_area() and bounds.is_finite():
		row["bounds"] = bounds
		rows.append(row)


func _axis_aligned_quad(row: Dictionary) -> void:
	var points: PackedVector2Array = row["polygon"]
	var uv: PackedVector2Array = row.get("uv", PackedVector2Array())
	var colors: PackedColorArray = row.get("colors", PackedColorArray())
	if points.size() != 4 or uv.size() != 4 or colors.size() > 1: return
	if points[0].y != points[1].y or points[0].x != points[3].x or points[2].x != points[1].x or points[2].y != points[3].y: return
	if uv[0].y != uv[1].y or uv[0].x != uv[3].x or uv[2].x != uv[1].x or uv[2].y != uv[3].y: return
	row["rect"] = Rect2(points[0], points[2] - points[0])
	row["region"] = Rect2(uv[0], uv[2] - uv[0])
	row.erase("polygon")


func _texture_bounds(row: Dictionary, rect: Rect2) -> Rect2:
	var image: Image = row["image"]
	var id: int = image.get_instance_id()
	if not _used_rects.has(id): _used_rects[id] = Rect2(image.get_used_rect())
	var region: Rect2 = row.get("region", Rect2())
	if is_zero_approx(region.get_area()): region = Rect2(Vector2.ZERO, Vector2(image.get_size()))
	var occupied: Rect2 = region.abs().intersection(_used_rects[id])
	if not occupied.has_area(): return Rect2()
	var first: Vector2 = (occupied.position - region.position) / region.size
	var last: Vector2 = (occupied.end - region.position) / region.size
	return Rect2(rect.position + first * rect.size, (last - first) * rect.size).abs()


func _image(texture: Texture2D) -> Image:
	var id: int = texture.get_instance_id()
	if _viewport_images.has(id): return _viewport_images[id]
	if _images.has(id): return _images[id]
	if texture is ViewportTexture:
		if not _viewports.has(id) or _rasterizing: return null
		if DisplayServer.get_name() == "headless": return _raster_viewport(id)
		var rendered: Image = texture.get_image()
		_viewport_images[id] = rendered
		return rendered
	var image: Image
	if texture is AtlasTexture:
		var backing: Image = _image(texture.atlas)
		if backing != null:
			image = Image.create_empty(texture.get_width(), texture.get_height(), false, Image.FORMAT_RGBA8)
			var section: Rect2i = Rect2i(texture.region)
			if not section.has_area(): section = Rect2i(Vector2i.ZERO, backing.get_size())
			image.blit_rect(backing, section, Vector2i(texture.margin.position))
	elif texture is CanvasTexture:
		if texture.diffuse_texture != null: image = _image(texture.diffuse_texture)
	elif texture.has_meta("fel30_flip_source"):
		var original: Image = _image(texture.get_meta("fel30_flip_source"))
		if original != null:
			image = original.duplicate()
			image.flip_x()
	elif texture.has_meta("fel30_image"):
		image = texture.get_meta("fel30_image")
	elif texture is ImageTexture and DisplayServer.get_name() == "headless":
		var path: String = str(texture.get_meta("asset_source_path", texture.resource_path))
		if not path.is_empty() and FileAccess.file_exists(path):
			image = Assets._load_source_image(path)
		elif texture.has_meta("gear_rest_image"):
			image = texture.get_meta("gear_rest_image")
	else:
		image = Assets.texture_source_image(texture)
	if image != null and image.is_compressed() and image.decompress() != OK: image = null
	_images[id] = image
	return image


func _raster_viewport(id: int) -> Image:
	var viewport: SubViewport = _viewports[id]
	var image := Image.new()
	var saved_rows: Array[Dictionary] = rows
	var saved_serial: int = _serial
	var pieces: Array[Dictionary]
	rows = pieces
	_rasterizing = true
	for child: Node in viewport.get_children(): _rig_pieces(child, 1.0)
	# Alpha over has the same result for every ordering of the rig's pieces.
	var pixels := PackedByteArray()
	pixels.resize(viewport.size.x * viewport.size.y * 4)
	var geometry := Coverage.new()
	var canvas := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for part: Dictionary in rows:
		var bounds: Rect2 = (part["bounds"] as Rect2).intersection(canvas)
		if not bounds.has_area(): continue
		var first := Vector2i(bounds.position.floor())
		var last := Vector2i(bounds.end.ceil())
		for y: int in range(first.y, last.y):
			for x: int in range(first.x, last.x):
				var alpha: float = geometry._alpha(part, Vector2(x + 0.5, y + 0.5))
				if alpha <= 0.0: continue
				var pixel: int = (y * viewport.size.x + x) * 4 + 3
				pixels[pixel] += roundi((255.0 - pixels[pixel]) * alpha)
	image.set_data(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8, pixels)
	_rasterizing = false
	rows = saved_rows
	_serial = saved_serial
	_viewport_images[id] = image
	return image


func _rig_pieces(node: Node, parent_alpha: float) -> void:
	var canvas: CanvasItem = node as CanvasItem
	var alpha: float = parent_alpha
	if canvas != null:
		if not canvas.is_visible_in_tree(): return
		alpha *= canvas.modulate.a
		var own_alpha: float = alpha * canvas.self_modulate.a
		if own_alpha > 0.0:
			var source: Transform2D = canvas.get_global_transform_with_canvas()
			var unit: Dictionary = _identity("unit", "rig piece")
			if canvas is Sprite2D: _sprite(canvas, unit, source, 0, own_alpha)
			elif canvas is Polygon2D: _mesh(canvas, unit, source, 0, own_alpha)
	for child: Node in node.get_children(): _rig_pieces(child, alpha)
