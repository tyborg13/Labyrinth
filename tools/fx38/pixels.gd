extends RefCounted
## Offline reference and native readback for the same core, halo and alpha partition.

const Art = preload("res://scripts/combat_art_treatment.gd")
const Cel = preload("res://scripts/cel_look.gd")
const TICK_ART: Array[String] = ["res://assets/art/enemies/ember_tick.png", "res://assets/art/enemies/ember_tick_rear.png"]
# At an exact texel centre, nearest sampling resolves the normalized diagonals
# of the two-texel radius to (+/-1, +/-1).
const TAPS: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
]
const ORANGE := Color("ff8a3a")
const LOW: float = 0.35
const HIGH: float = 0.55
const BG := Color("22252a")

static func check_reference() -> bool:
	var ok: bool = true
	for path: String in TICK_ART:
		var source: Image = _decode(path)
		ok = _reference_case(source, "off/" + path.get_file()) and ok
		var variant: String = Cel.variant_path(path)
		if Cel.mode == "all":
			ok = _reference_case(_decode(variant), "all/" + path.get_file()) and ok
	return ok

static func _decode(path: String) -> Image:
	if path.is_empty(): return null
	var image := Image.new()
	return image if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK else null

static func _reference_case(source: Image, label: String) -> bool:
	if source == null or source.is_empty(): return false
	var frames: Array[Image]
	for strength: float in [0.0, LOW, HIGH]:
		var frame: Image = Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in source.get_height():
			for x: int in source.get_width():
				var pixel: Color = source.get_pixel(x, y)
				var gain: float = strength * _mask(source, Vector2i(x, y)) if strength > 0.0 else 0.0
				var hot := Color(minf(pixel.r + ORANGE.r * gain, 1.0), minf(pixel.g + ORANGE.g * gain, 1.0), minf(pixel.b + ORANGE.b * gain, 1.0), pixel.a)
				frame.set_pixel(x, y, BG.blend(hot))
		frames.append(frame)
	return _compare(source, frames, "CPU reference " + label)

class Sample extends Node2D:
	var sprite: Texture2D
	var profile: int
	func _draw() -> void:
		# Translation belongs to the canvas. Each shader receives identical
		# local vertices so the light profile samples the same points.
		Art.draw_rect(self, sprite, Rect2(Vector2.ZERO, sprite.get_size()), Color.WHITE, profile)

static func renderer(tree: SceneTree, live_texture: Texture2D, board_material: ShaderMaterial, base: ShaderMaterial, subject: String) -> bool:
	var source: Image = live_texture.get_image() if live_texture != null else null
	if source == null or source.is_empty(): return false
	var material: ShaderMaterial = board_material.duplicate()
	material.set_shader_parameter("kindle_pulse", 1.0)
	var materials: Array[ShaderMaterial] = [material, material, material, base]
	var profiles: Array[int]
	var kindle: Script = load("res://scripts/enemy_mechanics/kindle_view.gd")
	for bonus: int in [0, 2, 4]:
		profiles.append(kindle.sprite_profile({"type": "ember_tick", "hp": 1, "kindled_bonus": bonus}, Art.ACTOR))
	profiles.append(Art.ACTOR)
	var frames: Array[Image] = await _render_samples(tree, source, materials, profiles)
	if frames.size() != profiles.size(): return false
	var unchanged: bool = identical("Tick bonus=0 " + subject, frames[3], frames[0])
	return _compare(source, frames, "renderer " + Cel.mode + "/" + subject) and unchanged

static func check_non_kindle(tree: SceneTree, texture: Texture2D, board_material: ShaderMaterial, base: ShaderMaterial) -> bool:
	var source: Image = texture.get_image() if texture != null else null
	if source == null or source.is_empty(): return false
	var materials: Array[ShaderMaterial] = [base, board_material]
	var profiles: Array[int] = [Art.ACTOR, Art.ACTOR]
	var frames: Array[Image] = await _render_samples(tree, source, materials, profiles)
	return frames.size() == profiles.size() and identical("non-Kindle unit (hero)", frames[0], frames[1])

static func _render_samples(tree: SceneTree, source: Image, materials: Array[ShaderMaterial], profiles: Array[int]) -> Array[Image]:
	var size: Vector2i = source.get_size()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size.x * profiles.size(), size.y)
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var background := ColorRect.new()
	background.size = viewport.size
	background.color = BG
	viewport.add_child(background)
	var sprite: ImageTexture = ImageTexture.create_from_image(source)
	for slot: int in profiles.size():
		var sample := Sample.new()
		sample.sprite = sprite
		sample.position.x = slot * size.x
		sample.profile = profiles[slot]
		sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sample.material = materials[slot]
		viewport.add_child(sample)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var frames: Array[Image]
	if image != null and image.get_size() == viewport.size:
		for slot: int in profiles.size():
			frames.append(image.get_region(Rect2i(Vector2i(slot * size.x, 0), size)))
	viewport.queue_free()
	return frames

static func identical(label: String, base: Image, current: Image) -> bool:
	if base == null or current == null or base.is_empty() or current.get_size() != base.get_size(): return false
	base.convert(Image.FORMAT_RGBA8)
	current.convert(Image.FORMAT_RGBA8)
	var original: PackedByteArray = base.get_data()
	var updated: PackedByteArray = current.get_data()
	var changed: int = 0
	var max_delta: int = 0
	if original != updated:
		for pixel: int in range(0, original.size(), 4):
			var delta: int = 0
			for channel: int in 4:
				delta = maxi(delta, absi(original[pixel + channel] - updated[pixel + channel]))
			if delta > 0: changed += 1
			max_delta = maxi(max_delta, delta)
	print("FX-38 BASE PIXELS %s: changed=%d/%d max_delta=%d/255" % [label, changed, base.get_width() * base.get_height(), max_delta])
	return changed == 0

static func _compare(source: Image, frames: Array[Image], label: String) -> bool:
	var outside_changed: int
	var unmasked_max: int
	var halo_max: int
	var halo_changed: int
	var mask_pixels: int
	var brighter: int
	var darker: int
	var gain: float
	for y: int in source.get_height():
		for x: int in source.get_width():
			var base: Color = frames[0].get_pixel(x, y)
			var plus2: Color = frames[1].get_pixel(x, y)
			var plus4: Color = frames[2].get_pixel(x, y)
			var delta: int = maxi(_channel_delta(plus2, base), _channel_delta(plus4, base))
			if source.get_pixel(x, y).a == 0.0:
				if delta != 0: outside_changed += 1
				continue
			match _mask(source, Vector2i(x, y)):
				0.0: unmasked_max = maxi(unmasked_max, delta)
				0.5:
					halo_max = maxi(halo_max, delta)
					if delta > 0: halo_changed += 1
				1.0:
					mask_pixels += 1
					var change: float = plus4.get_luminance() - plus2.get_luminance()
					gain += change * 255.0
					if change > 0.0: brighter += 1
					if change < -1.0 / 255.0: darker += 1
	print("FX-38 PIXELS %s: outside_changed=%d outside_core_max=%d/255 outside_core_and_halo_max=%d/255 halo_changed=%d core_brighter=%d/%d core_darker=%d mean_core_luma_gain=%.3f/255" % [
		label, outside_changed, maxi(unmasked_max, halo_max), unmasked_max, halo_changed, brighter, mask_pixels, darker, gain / float(maxi(mask_pixels, 1))])
	return outside_changed == 0 and unmasked_max == 0 and brighter > 0 and darker == 0 and gain > 0.0

static func _mask(source: Image, point: Vector2i) -> float:
	var pixel: Color = source.get_pixelv(point)
	if pixel.a <= 0.0: return 0.0
	if _warm(pixel): return 1.0
	for tap: Vector2i in TAPS:
		var neighbor: Vector2i = (point + tap).clamp(Vector2i.ZERO, source.get_size() - Vector2i.ONE)
		if _warm(source.get_pixelv(neighbor)): return 0.5
	return 0.0

static func _warm(pixel: Color) -> bool:
	return pixel.a > 0.0 and pixel.h <= 45.0 / 360.0 and pixel.s >= 0.55 and pixel.v >= 0.30

static func _channel_delta(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), maxi(absi(a.b8 - b.b8), absi(a.a8 - b.a8)))
