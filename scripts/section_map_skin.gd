extends RefCounted
class_name SectionMapSkin

const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ART: String = "res://assets/art/ui/section_map/"

static var _textures: Dictionary = {}
static var _medallion_outline := PackedVector2Array()
static var _medallion_normals := PackedVector2Array()
static var _medallion_rim: ArrayMesh
const MEDALLION_SEGMENTS: int = 96

static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var image: Image = Assets.load_texture(ART + name + ".png").get_image()
		if name == "action_frame":
			image = image.get_region(Rect2i(24, 212, 1944, 328))
			image.resize(512, 86, Image.INTERPOLATE_LANCZOS)
		elif name == "medallion":
			image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		elif name == "panel_frame":
			image.resize(720, 240, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		_textures[name] = ImageTexture.create_from_image(image)
	return _textures[name]

static func icon_texture(id: String) -> Texture2D:
	var key: String = "icon_" + id
	if not _textures.has(key):
		var source: Texture2D = Icons.icon_texture(id)
		if source == null:
			return null
		var image: Image = source.get_image()
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]

static func panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _texture("panel_frame")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	# Preserve the painted corner details without inflating the native layout.
	style.texture_margin_left = 26
	style.texture_margin_right = 26
	style.texture_margin_top = 26
	style.texture_margin_bottom = 26
	return style

static func button(button: Button, variant: String = "standard") -> void:
	# Action controls share the game's native forged-metal proportions and states;
	# painted art remains on the map's frames, medallions, and room identities.
	var skin := preload("res://scripts/ui_skin.gd").new()
	skin.apply_button_stylebox_overrides(button, variant)
	skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_BODY_LARGE)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func section_tab(button: Button) -> void:
	# Section navigation keeps its painted bronze seals; action-button cleanup
	# must not replace the user-approved identity of these tabs.
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = _texture("medallion")
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.modulate_color = Color(0.75, 0.71, 0.63)
		if state in ["hover", "hover_pressed"]: style.modulate_color = Color(1.35, 1.22, 0.96)
		if state == "pressed": style.modulate_color = Color(1.1, 0.95, 0.68)
		if state == "disabled": style.modulate_color = Color(0.32, 0.34, 0.37)
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe3a0")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(36)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	Typography.apply_button_role(button, Typography.ROLE_BODY_LARGE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("eddbb4"))
	button.add_theme_color_override("font_disabled_color", Color("827b6f"))
	button.add_theme_color_override("font_outline_color", Color("09090d"))
	button.add_theme_constant_override("outline_size", 2)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# The painted frame is an offset oval. Its alpha edge owns every room-state
# outline; the first brass pixels own the inner rim. Cache this geometry once
# from the same resized texture used to draw the frame, including its padding.
static func _ensure_medallion_geometry() -> void:
	if not _medallion_outline.is_empty(): return
	var image: Image = _texture("medallion").get_image()
	var half: float = float(image.get_width()) * 0.5
	var origin := Vector2.ONE * half
	var outer_radii := PackedFloat32Array()
	var inner_radii := PackedFloat32Array()
	for index: int in range(MEDALLION_SEGMENTS):
		var direction := Vector2.from_angle(TAU * float(index) / MEDALLION_SEGMENTS)
		var outer_radius: float = half * 0.94
		var inner_radius: float = half * 0.69
		for distance: int in range(int(half) - 1, int(half * 0.5), -1):
			var sample: Vector2i = Vector2i(origin + direction * distance)
			if image.get_pixelv(sample).a > 0.5:
				outer_radius = float(distance)
				break
		for distance: int in range(int(half * 0.55), int(half * 0.86)):
			var sample: Vector2i = Vector2i(origin + direction * distance)
			var color: Color = image.get_pixelv(sample)
			if color.a > 0.5 and color.r > 0.39 and color.r > color.g * 1.04 and color.g > color.b * 1.2:
				# Include the dark inset immediately inside the gold lip. Drawing
				# the rim last then protects every pixel of the painted frame.
				inner_radius = float(distance) - 1.0
				break
		outer_radii.append(outer_radius / half)
		inner_radii.append(inner_radius / half)
	var inner_points := PackedVector2Array()
	for index: int in range(MEDALLION_SEGMENTS):
		var direction := Vector2.from_angle(TAU * float(index) / MEDALLION_SEGMENTS)
		var before: int = posmod(index - 1, MEDALLION_SEGMENTS)
		var after: int = (index + 1) % MEDALLION_SEGMENTS
		_medallion_outline.append(direction * (outer_radii[before] + outer_radii[index] * 2.0 + outer_radii[after]) * 0.25)
		inner_points.append(direction * (inner_radii[before] + inner_radii[index] * 2.0 + inner_radii[after]) * 0.25)
	for index: int in range(MEDALLION_SEGMENTS):
		var tangent: Vector2 = _medallion_outline[(index + 1) % MEDALLION_SEGMENTS] - _medallion_outline[posmod(index - 1, MEDALLION_SEGMENTS)]
		_medallion_normals.append(Vector2(tangent.y, -tangent.x).normalized())
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in range(MEDALLION_SEGMENTS):
		var direction := Vector2.from_angle(TAU * float(index) / MEDALLION_SEGMENTS)
		var outside: Vector2 = direction / maxf(absf(direction.x), absf(direction.y))
		for point: Vector2 in [inner_points[index], outside]:
			vertices.append(Vector3(point.x, point.y, 0))
			uvs.append((point + Vector2.ONE) * 0.5)
		var current: int = index * 2
		var next: int = ((index + 1) % MEDALLION_SEGMENTS) * 2
		indices.append_array(PackedInt32Array([current, current + 1, next + 1, current, next + 1, next]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_medallion_rim = ArrayMesh.new()
	_medallion_rim.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func medallion_contour(center: Vector2, radius: float, gap: float = 0.0, closed: bool = true) -> PackedVector2Array:
	_ensure_medallion_geometry()
	var points := PackedVector2Array()
	for index: int in range(MEDALLION_SEGMENTS):
		points.append(center + _medallion_outline[index] * radius + _medallion_normals[index] * gap)
	if closed: points.append(points[0])
	return points

static func medallion_edge(index: int) -> Vector2:
	_ensure_medallion_geometry()
	return _medallion_outline[posmod(index, MEDALLION_SEGMENTS)]

static func medallion_rim_mesh() -> ArrayMesh:
	_ensure_medallion_geometry()
	return _medallion_rim

# Shared room seals keep opaque art inside the same painted rim on the map,
# in its legend, and above physical doors. All geometry stays native and editable.
static func draw_medallion(canvas: CanvasItem, center: Vector2, radius: float, icon: Texture2D, icon_tint: Color = Color.WHITE, frame_tint: Color = Color.WHITE, glint_alpha: float = 0.0) -> void:
	canvas.draw_texture_rect(_texture("medallion"), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, frame_tint)
	if icon != null:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for index: int in range(64):
			var direction := Vector2.from_angle(TAU * float(index) / 64.0)
			points.append(center + direction * radius * 0.735)
			uvs.append(Vector2.ONE * 0.5 + direction * 0.5)
		canvas.draw_polygon(points, PackedColorArray([icon_tint]), uvs, icon)
	if glint_alpha > 0.0:
		canvas.draw_circle(center, radius * 0.74, Color(1.0, 0.88, 0.63, glint_alpha))
	canvas.draw_mesh(medallion_rim_mesh(), _texture("medallion"), Transform2D(Vector2(radius, 0), Vector2(0, radius), center), frame_tint)
