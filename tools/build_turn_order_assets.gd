extends SceneTree

const PORTRAIT_SIZE := 128
const PORTRAIT_FIT := 124
const ICON_SIZE := 64

const PORTRAITS := [
	{
		"source": "res://assets/placeholders/units/player_reaver.png",
		"out": "res://assets/art/portraits/player_reaver.png",
		"crop": Rect2i(72, 8, 108, 112)
	},
	{
		"source": "res://assets/placeholders/units/crawler_anime_trial.png",
		"out": "res://assets/art/portraits/tunnel_crawler.png",
		"crop": Rect2i(35, 52, 125, 115)
	},
	{
		"source": "res://assets/placeholders/units/acolyte_anime_trial.png",
		"out": "res://assets/art/portraits/dust_acolyte.png",
		"crop": Rect2i(48, 24, 150, 128)
	},
	{
		"source": "res://assets/placeholders/units/acolyte_anime_trial.png",
		"out": "res://assets/art/portraits/veilbound_acolyte.png",
		"crop": Rect2i(76, 26, 96, 105)
	},
	{
		"source": "res://assets/placeholders/units/harrier_anime_trial.png",
		"out": "res://assets/art/portraits/bone_harrier.png",
		"crop": Rect2i(61, 25, 110, 115)
	},
	{
		"source": "res://assets/placeholders/units/warden_anime_trial.png",
		"out": "res://assets/art/portraits/stone_warden.png",
		"crop": Rect2i(70, 17, 110, 115)
	},
	{
		"source": "res://assets/placeholders/units/zekarion.png",
		"out": "res://assets/art/portraits/zekarion.png",
		"crop": Rect2i(22, 25, 125, 125)
	},
	{
		"source": "res://assets/placeholders/units/lightning_wisp.png",
		"out": "res://assets/art/portraits/lightning_wisp.png",
		"crop": Rect2i(73, 65, 112, 130)
	},
	{
		"source": "res://assets/art/enemies/bile_bloomer.png",
		"out": "res://assets/art/portraits/bile_bloomer.png",
		"crop": Rect2i(55, 8, 145, 135)
	},
	{
		"source": "res://assets/art/enemies/chainbound_gaoler.png",
		"out": "res://assets/art/portraits/chainbound_gaoler.png",
		"crop": Rect2i(72, 10, 105, 115)
	},
	{
		"source": "res://assets/art/enemies/grave_surgeon.png",
		"out": "res://assets/art/portraits/grave_surgeon.png",
		"crop": Rect2i(60, 20, 115, 120)
	},
	{
		"source": "res://assets/art/enemies/frostglass_lancer.png",
		"out": "res://assets/art/portraits/frostglass_lancer.png",
		"crop": Rect2i(65, 18, 105, 120)
	},
	{
		"source": "res://assets/art/enemies/cinder_ooze.png",
		"out": "res://assets/art/portraits/cinder_ooze.png",
		"crop": Rect2i(25, 55, 165, 135)
	},
	{
		"source": "res://assets/art/enemies/cinder_droplet.png",
		"out": "res://assets/art/portraits/cinder_droplet.png",
		"crop": Rect2i(54, 70, 150, 130)
	},
	{
		"source": "res://assets/art/enemies/iskaldra.png",
		"out": "res://assets/art/portraits/iskaldra.png",
		"crop": Rect2i(42, 65, 125, 125)
	},
	{
		"source": "res://assets/art/enemies/noctyrax.png",
		"out": "res://assets/art/portraits/noctyrax.png",
		"crop": Rect2i(55, 55, 130, 125)
	},
	{
		"source": "res://assets/art/enemies/tharokh.png",
		"out": "res://assets/art/portraits/tharokh.png",
		"crop": Rect2i(35, 55, 130, 125)
	},
	{
		"source": "res://assets/art/enemies/vaeloryx.png",
		"out": "res://assets/art/portraits/vaeloryx.png",
		"crop": Rect2i(45, 42, 130, 125)
	},
	{
		"source": "res://assets/art/enemies/vyraketh.png",
		"out": "res://assets/art/portraits/vyraketh.png",
		"crop": Rect2i(40, 55, 130, 125)
	}
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
	var crop: Rect2i = config.get("crop", Rect2i(Vector2i.ZERO, source.get_size()))
	crop = _clamp_rect(crop, source.get_size())
	var cutout := Image.create_empty(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	cutout.fill(Color(0, 0, 0, 0))
	cutout.blit_rect(source, crop, Vector2i.ZERO)
	var scale: float = minf(float(PORTRAIT_FIT) / float(maxi(1, cutout.get_width())), float(PORTRAIT_FIT) / float(maxi(1, cutout.get_height())))
	var scaled_size := Vector2i(maxi(1, int(roundf(float(cutout.get_width()) * scale))), maxi(1, int(roundf(float(cutout.get_height()) * scale))))
	cutout.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create_empty(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dest := Vector2i((PORTRAIT_SIZE - cutout.get_width()) / 2, (PORTRAIT_SIZE - cutout.get_height()) / 2)
	canvas.blend_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), dest)
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
