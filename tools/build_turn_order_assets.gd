extends SceneTree

const PORTRAIT_SIZE := 128
const ICON_SIZE := 64

# Turn-order and pre-battle portraits: an exact 1:1, 128x128 cut of each
# unit's current in-game art (cutout rest bakes and guardian sprites), centred
# on the head and shoulders. No rescaling keeps pixel art crisp. The rail shows
# the middle 128x96 band of each portrait, so "focus" is the centre of the bust.
const PORTRAITS := [
	{"key": "ash_hound", "source": "res://assets/units/ash_hound.png", "out": "res://assets/art/portraits/guardians/ash_hound_portrait.png", "focus": Vector2i(72, 148)},
	{"key": "ashen_reaver", "source": "res://assets/units/ashen_reaver.png", "out": "res://assets/art/portraits/guardians/ashen_reaver_portrait.png", "focus": Vector2i(136, 64)},
	{"key": "bell_tender", "source": "res://assets/units/bell_tender.png", "out": "res://assets/art/portraits/guardians/bell_tender_portrait.png", "focus": Vector2i(118, 86)},
	{"key": "craghide", "source": "res://assets/units/craghide.png", "out": "res://assets/art/portraits/guardians/craghide_portrait.png", "focus": Vector2i(78, 158)},
	{"key": "gallows_roc", "source": "res://assets/units/gallows_roc.png", "out": "res://assets/art/portraits/guardians/gallows_roc_portrait.png", "focus": Vector2i(98, 96)},
	{"key": "last_lamplighter", "source": "res://assets/units/last_lamplighter.png", "out": "res://assets/art/portraits/guardians/last_lamplighter_portrait.png", "focus": Vector2i(140, 62)},
	{"key": "rime_spitter", "source": "res://assets/units/rime_spitter.png", "out": "res://assets/art/portraits/guardians/rime_spitter_portrait.png", "focus": Vector2i(64, 148)},
	{"key": "rime_whelp", "source": "res://assets/units/rime_whelp.png", "out": "res://assets/art/portraits/guardians/rime_whelp_portrait.png", "focus": Vector2i(66, 138)},
	{"key": "rimejaw", "source": "res://assets/units/rimejaw.png", "out": "res://assets/art/portraits/guardians/rimejaw_portrait.png", "focus": Vector2i(62, 140)},
	{"key": "roc_fledgling", "source": "res://assets/units/roc_fledgling.png", "out": "res://assets/art/portraits/guardians/roc_fledgling_portrait.png", "focus": Vector2i(90, 110)},
	{"key": "stoneback_mite", "source": "res://assets/units/stoneback_mite.png", "out": "res://assets/art/portraits/guardians/stoneback_mite_portrait.png", "focus": Vector2i(96, 168)},
	{"key": "storm_cantor", "source": "res://assets/units/storm_cantor.png", "out": "res://assets/art/portraits/guardians/storm_cantor_portrait.png", "focus": Vector2i(128, 64)},
	{"key": "wick_shade", "source": "res://assets/units/wick_shade.png", "out": "res://assets/art/portraits/guardians/wick_shade_portrait.png", "focus": Vector2i(104, 62)},
	{"key": "player", "source": "res://assets/units/protagonist_cutout/front/front_assembled_rest_v9.png", "out": "res://assets/art/portraits/player_reaver.png", "focus": Vector2i(125, 60)},
	{"key": "crawler", "source": "res://assets/units/crawler_cutout/front/rest.png", "out": "res://assets/art/portraits/tunnel_crawler.png", "focus": Vector2i(84, 116)},
	{"key": "acolyte", "source": "res://assets/units/acolyte_cutout/front/rest.png", "out": "res://assets/art/portraits/dust_acolyte.png", "focus": Vector2i(110, 74)},
	{"key": "veilbound_acolyte", "source": "res://assets/units/veilbound_acolyte_cutout/front/rest.png", "out": "res://assets/art/portraits/veilbound_acolyte.png", "focus": Vector2i(116, 70)},
	{"key": "harrier", "source": "res://assets/units/harrier_cutout/front/rest.png", "out": "res://assets/art/portraits/bone_harrier.png", "focus": Vector2i(112, 74)},
	{"key": "grave_surgeon", "source": "res://assets/units/grave_surgeon_cutout/front/rest.png", "out": "res://assets/art/portraits/grave_surgeon.png", "focus": Vector2i(138, 66)},
	{"key": "warden", "source": "res://assets/units/stone_warden_cutout/front/rest.png", "out": "res://assets/art/portraits/stone_warden.png", "focus": Vector2i(128, 62)},
	{"key": "bile_bloomer", "source": "res://assets/units/bile_bloomer_cutout/front/rest.png", "out": "res://assets/art/portraits/bile_bloomer.png", "focus": Vector2i(126, 72)},
	{"key": "chainbound_gaoler", "source": "res://assets/units/chainbound_gaoler_cutout/front/rest.png", "out": "res://assets/art/portraits/chainbound_gaoler.png", "focus": Vector2i(138, 58)},
	{"key": "zekarion", "source": "res://assets/units/zekarion_cutout/front/rest.png", "out": "res://assets/art/portraits/zekarion.png", "focus": Vector2i(76, 116)},
	{"key": "tharokh", "source": "res://assets/units/tharokh_cutout/front/rest.png", "out": "res://assets/art/portraits/tharokh.png", "focus": Vector2i(76, 128)},
	{"key": "vyraketh", "source": "res://assets/units/vyraketh_cutout/front/rest.png", "out": "res://assets/art/portraits/vyraketh.png", "focus": Vector2i(72, 126)},
	{"key": "vaeloryx", "source": "res://assets/units/vaeloryx_cutout/front/rest.png", "out": "res://assets/art/portraits/vaeloryx.png", "focus": Vector2i(80, 120)},
	{"key": "iskaldra", "source": "res://assets/units/iskaldra_cutout/front/rest.png", "out": "res://assets/art/portraits/iskaldra.png", "focus": Vector2i(72, 120)},
	{"key": "noctyrax", "source": "res://assets/units/noctyrax_cutout/front/rest.png", "out": "res://assets/art/portraits/noctyrax.png", "focus": Vector2i(88, 96)},
	{"key": "lightning_wisp", "source": "res://assets/units/lightning_wisp_cutout/front/rest.png", "out": "res://assets/art/portraits/lightning_wisp.png", "focus": Vector2i(118, 128)},
	{"key": "frostglass_lancer", "source": "res://assets/units/frostglass_lancer_cutout/front/rest.png", "out": "res://assets/art/portraits/frostglass_lancer.png", "focus": Vector2i(116, 60)},
	{"key": "cinder_ooze", "source": "res://assets/units/cinder_ooze_cutout/front/rest.png", "out": "res://assets/art/portraits/cinder_ooze.png", "focus": Vector2i(112, 140)},
	{"key": "cinder_droplet", "source": "res://assets/units/cinder_droplet_cutout/front/rest.png", "out": "res://assets/art/portraits/cinder_droplet.png", "focus": Vector2i(100, 148)},
]

func _initialize() -> void:
	_ensure_dir("res://assets/art/portraits")
	for config: Dictionary in PORTRAITS:
		_build_portrait(config)
	_copy_png("res://assets/art/icons/retreat.png", "res://assets/art/icons/stat_agility.png")
	_build_time_icon("res://assets/art/icons/time.png")
	quit(0)

func _ensure_dir(res_path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(absolute)

func _load_image(res_path: String) -> Image:
	var image := Image.new()
	var err: Error = image.load(res_path)
	if err != OK:
		push_error("Could not load image %s" % res_path)
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _build_portrait(config: Dictionary) -> void:
	var source: Image = _load_image(str(config.get("source", "")))
	var focus: Vector2i = config.get("focus", source.get_size() / 2)
	var half: int = PORTRAIT_SIZE / 2
	var canvas := Image.create_empty(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	# Copy the source window centred on the bust; any part beyond the sprite's
	# canvas stays transparent.
	var window := Rect2i(focus - Vector2i(half, half), Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE))
	var clipped: Rect2i = window.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	if clipped.size.x > 0 and clipped.size.y > 0:
		canvas.blit_rect(source, clipped, clipped.position - window.position)
	var err: Error = canvas.save_png(str(config.get("out", "")))
	if err != OK:
		push_error("Could not save portrait %s" % str(config.get("out", "")))

func _copy_png(source_path: String, out_path: String) -> void:
	var image: Image = _load_image(source_path)
	var err: Error = image.save_png(out_path)
	if err != OK:
		push_error("Could not save %s" % out_path)

func _build_time_icon(out_path: String) -> void:
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var shadow := Color("140d08")
	var dark := Color("332216")
	var bronze := Color("9d6e3b")
	var gold := Color("e7c172")
	var sand := Color("f2d88a")
	_fill_circle(image, Vector2i(32, 32), 27, Color(0, 0, 0, 0.42))
	_draw_circle_outline(image, Vector2i(32, 32), 25, shadow, 4)
	_draw_circle_outline(image, Vector2i(32, 32), 23, bronze, 3)
	_draw_circle_outline(image, Vector2i(32, 32), 19, dark, 2)
	_draw_line(image, Vector2i(22, 17), Vector2i(42, 17), gold, 3)
	_draw_line(image, Vector2i(22, 47), Vector2i(42, 47), gold, 3)
	_draw_line(image, Vector2i(24, 19), Vector2i(32, 32), gold, 3)
	_draw_line(image, Vector2i(40, 19), Vector2i(32, 32), gold, 3)
	_draw_line(image, Vector2i(24, 45), Vector2i(32, 32), gold, 3)
	_draw_line(image, Vector2i(40, 45), Vector2i(32, 32), gold, 3)
	_fill_triangle(image, Vector2i(28, 21), Vector2i(36, 21), Vector2i(32, 30), sand)
	_fill_triangle(image, Vector2i(26, 43), Vector2i(38, 43), Vector2i(32, 34), sand)
	_draw_line(image, Vector2i(32, 30), Vector2i(32, 35), sand, 1)
	var err: Error = image.save_png(out_path)
	if err != OK:
		push_error("Could not save time icon %s" % out_path)

func _clamp_rect(rect: Rect2i, size: Vector2i) -> Rect2i:
	var pos := Vector2i(clampi(rect.position.x, 0, maxi(0, size.x - 1)), clampi(rect.position.y, 0, maxi(0, size.y - 1)))
	var end := Vector2i(clampi(rect.end.x, pos.x + 1, size.x), clampi(rect.end.y, pos.y + 1, size.y))
	return Rect2i(pos, end - pos)

func _put_pixel(image: Image, point: Vector2i, color: Color) -> void:
	if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
		return
	var existing: Color = image.get_pixelv(point)
	image.set_pixelv(point, existing.blend(color))

func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var radius_squared: int = radius * radius
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var delta := Vector2i(x, y) - center
			if delta.length_squared() <= radius_squared:
				_put_pixel(image, Vector2i(x, y), color)

func _draw_circle_outline(image: Image, center: Vector2i, radius: int, color: Color, thickness: int) -> void:
	for y: int in range(center.y - radius - thickness, center.y + radius + thickness + 1):
		for x: int in range(center.x - radius - thickness, center.x + radius + thickness + 1):
			var delta := Vector2i(x, y) - center
			var distance_squared: int = delta.length_squared()
			if distance_squared <= (radius + thickness) * (radius + thickness) and distance_squared >= (radius - thickness) * (radius - thickness):
				_put_pixel(image, Vector2i(x, y), color)

func _draw_line(image: Image, start: Vector2i, end: Vector2i, color: Color, thickness: int) -> void:
	var delta: Vector2i = end - start
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_fill_circle(image, start, thickness, color)
		return
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		var point := Vector2i(roundi(lerpf(float(start.x), float(end.x), t)), roundi(lerpf(float(start.y), float(end.y), t)))
		_fill_circle(image, point, thickness, color)

func _fill_triangle(image: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color) -> void:
	var min_x: int = mini(a.x, mini(b.x, c.x))
	var max_x: int = maxi(a.x, maxi(b.x, c.x))
	var min_y: int = mini(a.y, mini(b.y, c.y))
	var max_y: int = maxi(a.y, maxi(b.y, c.y))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var point := Vector2i(x, y)
			if _point_in_triangle(point, a, b, c):
				_put_pixel(image, point, color)

func _point_in_triangle(point: Vector2i, a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var d1: int = _sign(point, a, b)
	var d2: int = _sign(point, b, c)
	var d3: int = _sign(point, c, a)
	var has_neg: bool = d1 < 0 or d2 < 0 or d3 < 0
	var has_pos: bool = d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)

func _sign(p1: Vector2i, p2: Vector2i, p3: Vector2i) -> int:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
