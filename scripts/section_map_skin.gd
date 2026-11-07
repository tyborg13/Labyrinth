extends RefCounted
class_name SectionMapSkin

const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const ART: String = "res://assets/art/ui/section_map/"
const UNKNOWN_GLYPH_SCALE: float = 1.25
const UNKNOWN_GLYPH_OUTLINE: int = 2
# An unknown room's pool of Umbra drifts at the board billows' two phase speeds.
const UMBRA_FLOW_RATE: float = 0.58
const UMBRA_COUNTER_RATE: float = 0.44
# The legend, door markers and reduced motion hold the pool at one still moment.
const UMBRA_STILL_TIME: float = 5.6
const UMBRA_SOFT_SIZE: int = 64

static var _textures: Dictionary = {}
static var _unknown_glyph_anchor: Dictionary = {}
static var _umbra_soft: ImageTexture
static var _medallion_outline := PackedVector2Array()
static var _medallion_normals := PackedVector2Array()
static var _medallion_rim: ArrayMesh
const MEDALLION_SEGMENTS: int = 96

static func _processed_image(image: Image, name: String) -> Image:
	if image == null or image.is_empty(): return null
	if name == "action_frame":
		image = image.get_region(Rect2i(24, 212, 1944, 328))
		image.resize(512, 86, Image.INTERPOLATE_LANCZOS)
	elif name == "medallion":
		image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	elif name == "panel_frame":
		image.resize(720, 240, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return image

static func prepare_initial_assets_for(root: Node, present_frame: Callable, still_active: Callable) -> void:
	for name: String in ["action_frame", "medallion", "panel_frame"]:
		if _textures.has(name): continue
		var source: Image = _owned_texture_image(Assets.load_texture(ART + name + ".png"))
		var image: Image = (await Assets.prepare_cpu_value_for(root, _processed_image.bind(source, name), present_frame, still_active)) as Image
		if not bool(still_active.call()): return
		if image != null and not _textures.has(name): _textures[name] = ImageTexture.create_from_image(image)

	# Private CPU copies are obtained on the main thread. A single owned worker makes
	# every exact 128px map icon; GPU publication remains bounded on the main.
	var sources: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	for id: String in Icons.all_icon_ids():
		var key: String = "icon_" + id
		if _textures.has(key): continue
		var texture: Texture2D = Icons.icon_texture(id)
		if texture != null:
			var image: Image = _owned_texture_image(texture)
			if image != null and not image.is_empty(): sources[key] = image
		if Time.get_ticks_usec() - started >= 4000:
			await present_frame.call()
			if not bool(still_active.call()): return
			started = Time.get_ticks_usec()
	if sources.is_empty(): return
	var result: Variant = await Assets.prepare_cpu_value_for(root, _process_icon_images.bind(sources), present_frame, still_active)
	if not bool(still_active.call()) or not result is Dictionary: return
	var images: Dictionary = result
	started = Time.get_ticks_usec()
	for key: String in images:
		if not _textures.has(key): _textures[key] = ImageTexture.create_from_image(images[key])
		if Time.get_ticks_usec() - started >= 4000:
			await present_frame.call()
			if not bool(still_active.call()): return
			started = Time.get_ticks_usec()

static func _owned_texture_image(texture: Texture2D) -> Image:
	if texture == null: return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return null
	# Dummy texture readback returns its stored Image itself, unlike native
	# readback. Never let a worker resize a texture-owned/shared Image. Duplicate
	# on the main thread, preserving its format and every byte (including mips).
	return image.duplicate() as Image

static func _process_icon_images(sources: Dictionary) -> Dictionary:
	var images: Dictionary = {}
	for key: String in sources:
		var image: Image = sources[key]
		# A texture may exist without readable CPU pixels (Dummy/readback failure).
		# Omit it exactly like an absent icon; never publish a failed cache entry.
		if image == null or image.is_empty(): continue
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		images[key] = image
	return images

static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var image: Image = _processed_image(Assets.load_texture(ART + name + ".png").get_image(), name)
		_textures[name] = ImageTexture.create_from_image(image)
	return _textures[name]

static func icon_texture(id: String) -> Texture2D:
	var key: String = "icon_" + id
	if not _textures.has(key):
		var source: Texture2D = Icons.icon_texture(id)
		if source == null:
			return null
		var image: Image = _owned_texture_image(source)
		if image == null or image.is_empty(): return null
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

# An undiscovered room wears the same medallion as every other room, with a
# carved question mark where the emblem would be, sitting in a small pool of the
# Umbra. The map, its legend and the markers above physical doors all draw it
# here, so they always match. Map rooms pass their running Umbra time; a room
# that must keep the pool beneath its own ring draws the pool first itself.
static func draw_unknown_room(canvas: CanvasItem, center: Vector2, radius: float, glyph: Color, frame_tint: Color = Color.WHITE, umbra_time: float = UMBRA_STILL_TIME, umbra_strength: float = 1.0, with_pool: bool = true) -> void:
	if with_pool: draw_unknown_pool(canvas, center, radius, umbra_time, umbra_strength * frame_tint.a)
	var ink := Color(Palette.INK_0, frame_tint.a)
	canvas.draw_circle(center, radius - 2, ink)
	canvas.draw_texture_rect(_texture("medallion"), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, frame_tint)
	# A dark aperture, like the emblems' own backgrounds, so lit seals stay one
	# family; a faint violet haze low in it reads as Umbra rather than plain black.
	canvas.draw_circle(center, radius * 0.735, ink)
	_draw_umbra_lobe(canvas, center + Vector2(0.0, radius * 0.26), radius * 0.62, Vector2(0.85, 1.15), PI * 0.5, Color(Palette.UMBRA, 0.18 * umbra_strength * frame_tint.a))
	canvas.draw_mesh(medallion_rim_mesh(), _texture("medallion"), Transform2D(Vector2(radius, 0), Vector2(0, radius), center), frame_tint)
	var font: Font = unknown_glyph_font()
	var size: int = roundi(radius * UNKNOWN_GLYPH_SCALE)
	# Place the mark's optical centre, not its advance width, on the seal's
	# centre. Glyphs land on whole screen pixels, so take the whole-pixel pen
	# nearest that for wherever this canvas item sits on screen.
	var origin: Vector2 = canvas.get_global_transform_with_canvas().origin
	var baseline: Vector2 = (origin + center - unknown_glyph_anchor(font, size)).round() - origin.round()
	canvas.draw_string_outline(font, baseline, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, UNKNOWN_GLYPH_OUTLINE, Color(Palette.INK_0, glyph.a))
	canvas.draw_string(font, baseline, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, glyph)

# The lighter cut of the map's serif family keeps the mark one family with the
# map's lettering without the display cut's heavy strokes.
static func unknown_glyph_font() -> Font:
	return Typography.text_font()

# The "?" glyph's side bearings are uneven, so its advance box sits off its ink,
# and its bowl swings right of the stem and dot the eye reads as its axis. The
# optical centre, relative to the pen, sits midway between the inked box's
# centre and the dot's, at the box's vertical middle (dot included). Measured
# once per size from the pixels the text server rasterises.
static func unknown_glyph_anchor(font: Font, size: int) -> Vector2:
	var key := "%d:%d" % [font.get_instance_id(), size]
	if _unknown_glyph_anchor.has(key): return _unknown_glyph_anchor[key]
	var anchor := Vector2(font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, -size * 0.35)
	var server: TextServer = TextServerManager.get_primary_interface()
	var rids: Array[RID] = font.get_rids()
	if not rids.is_empty():
		var cache := Vector2i(size, 0)
		var glyph: int = server.font_get_glyph_index(rids[0], size, "?".unicode_at(0), 0)
		server.font_render_glyph(rids[0], cache, glyph)
		var uv := Rect2i(server.font_get_glyph_uv_rect(rids[0], cache, glyph))
		var atlas: Image = server.font_get_texture_image(rids[0], cache, server.font_get_glyph_texture_idx(rids[0], cache, glyph))
		if atlas != null and uv.size.x > 0 and uv.size.y > 0:
			var bitmap: Image = atlas.get_region(uv)
			var low := Vector2i(bitmap.get_width(), bitmap.get_height())
			var high := Vector2i(-1, -1)
			var inked_rows: Dictionary = {}
			for y: int in range(bitmap.get_height()):
				for x: int in range(bitmap.get_width()):
					if bitmap.get_pixel(x, y).a < 0.5: continue
					low = Vector2i(mini(low.x, x), mini(low.y, y))
					high = Vector2i(maxi(high.x, x), maxi(high.y, y))
					inked_rows[y] = true
			if high.x >= low.x:
				var offset: Vector2 = server.font_get_glyph_offset(rids[0], cache, glyph)
				var middle: Vector2 = offset + Vector2(low + high + Vector2i.ONE) * 0.5
				# The dot is everything below the last empty row above the baseline.
				var gap: int = high.y
				while gap > low.y and inked_rows.has(gap): gap -= 1
				var weight: float = 0.0
				var moment: float = 0.0
				for y: int in range(gap + 1, high.y + 1):
					for x: int in range(bitmap.get_width()):
						var alpha: float = bitmap.get_pixel(x, y).a
						weight += alpha
						moment += alpha * (float(x) + 0.5)
				var dot: float = offset.x + moment / weight if gap > low.y and weight > 0.0 else middle.x
				anchor = Vector2((middle.x + dot) * 0.5, middle.y)
	_unknown_glyph_anchor[key] = anchor
	return anchor

# An unknown room sits in a small pool of the Umbra seeping out from under its
# seal: deep violet-black lobes low on each side and a violet roll beneath, in
# the board's billow colours, drifting and swelling at the board's rates.
static func draw_unknown_pool(canvas: CanvasItem, center: Vector2, radius: float, time: float = UMBRA_STILL_TIME, strength: float = 1.0) -> void:
	if strength <= 0.0: return
	var flow: float = time * UMBRA_FLOW_RATE
	var counter: float = time * UMBRA_COUNTER_RATE
	var swell: float = 0.5 + 0.5 * sin(flow)
	for side: float in [-1.0, 1.0]:
		var angle: float = PI * 0.5 - side * (0.85 + 0.2 * sin(counter + side * 1.3))
		var reach: float = radius * (0.95 + 0.07 * cos(flow + side * 0.9))
		var size: float = radius * ((0.97 + 0.11 * swell) if side < 0.0 else (0.9 + 0.11 * (1.0 - swell)))
		_draw_umbra_lobe(canvas, center + Vector2.from_angle(angle) * reach, size, Vector2(0.75, 1.15), angle, Color(Palette.UMBRA_DEEP, strength))
	var roll: float = PI * 0.5 + 0.3 * sin(counter + 0.6)
	_draw_umbra_lobe(canvas, center + Vector2.from_angle(roll) * radius * 0.95, radius * (0.74 + 0.08 * (1.0 - swell)), Vector2(0.9, 1.7), roll, Color(Palette.UMBRA_VIOLET, 0.95 * strength))

# One soft lobe: an ellipse with `reach` along `angle` and `reach * stretch.y`
# across it, filled with the board's billow falloff.
static func _draw_umbra_lobe(canvas: CanvasItem, center: Vector2, reach: float, stretch: Vector2, angle: float, color: Color) -> void:
	if color.a <= 0.0: return
	var along: Vector2 = Vector2.from_angle(angle) * reach * stretch.x
	var across: Vector2 = Vector2.from_angle(angle).orthogonal() * reach * stretch.y
	var points := PackedVector2Array([center - along - across, center + along - across, center + along + across, center - along + across])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	canvas.draw_polygon(points, PackedColorArray([color]), uvs, _umbra_soft_texture())

# The board stacks ten fading discs per billow (CombatBoardView's soft lobes).
# Bake that falloff once, smoothed and normalised so a colour's alpha is the
# lobe's peak.
static func _umbra_soft_texture() -> ImageTexture:
	if _umbra_soft != null: return _umbra_soft
	var image := Image.create_empty(UMBRA_SOFT_SIZE, UMBRA_SOFT_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = UMBRA_SOFT_SIZE * 0.5
	var peak: float = _umbra_billow_alpha(0.0)
	for y: int in range(UMBRA_SOFT_SIZE):
		for x: int in range(UMBRA_SOFT_SIZE):
			var distance: float = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			image.set_pixel(x, y, Color(Color.WHITE, _umbra_billow_alpha(distance) / peak))
	_umbra_soft = ImageTexture.create_from_image(image)
	return _umbra_soft

static func _umbra_billow_alpha(distance: float) -> float:
	var clear: float = 1.0
	for layer: int in range(1, 11):
		var t: float = float(layer) / 10.0
		var cover: float = clampf((0.12 + t * 0.88 - distance) / 0.08 + 0.5, 0.0, 1.0)
		clear *= 1.0 - cover * (0.028 + pow(1.0 - t, 0.76) * 0.082)
	return 1.0 - clear

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

# Guardian emblems contain their own painted rims. Derive their outlines from
# those exact textures, rather than the unrelated ordinary-room brass frame.
static var _icon_contours: Dictionary = {}
static func icon_edge(id: String, index: int) -> Vector2:
	if not _icon_contours.has(id):
		var source: Texture2D = icon_texture(id)
		if source == null: return Vector2.from_angle(TAU*float(index)/MEDALLION_SEGMENTS)
		var image: Image = source.get_image()
		var half: float = float(image.get_width())*.5
		var points := PackedVector2Array()
		for ray: int in range(MEDALLION_SEGMENTS):
			var direction := Vector2.from_angle(TAU*float(ray)/MEDALLION_SEGMENTS)
			var edge: float = half*.8
			for sample: int in range(ceili(half*1.42),0,-1):
				var pixel := Vector2i(Vector2.ONE*half+direction*float(sample))
				if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height(): continue
				if image.get_pixelv(pixel).a>.55:
					edge=float(sample)
					break
			points.append(direction*edge/half)
		_icon_contours[id]=points
	return (_icon_contours[id] as PackedVector2Array)[posmod(index,MEDALLION_SEGMENTS)]

static func icon_contour(id: String, center: Vector2, radius: float, gap: float, closed: bool = true) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(MEDALLION_SEGMENTS):
		var tangent: Vector2 = icon_edge(id,index+1)-icon_edge(id,index-1)
		var normal := Vector2(tangent.y,-tangent.x).normalized()
		points.append(center+icon_edge(id,index)*radius+normal*gap)
	if closed: points.append(points[0])
	return points
