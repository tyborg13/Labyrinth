extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Chest = preload("res://scripts/relic_chest_prop.gd")

static func run(expect: Callable) -> void:
	_test_trap_aspect_uses_texture(expect)
	_test_live_trap_envelope(expect)
	_test_fixed_rect_pixel_density(expect)
	_test_chest_registration(expect)

static func _test_trap_aspect_uses_texture(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(960, 680)
	var trap := {"element": "fire", "pos": Vector2i(2, 2)}
	expect.call(is_equal_approx((board.call("_trap_draw_rect", trap["pos"]) as Rect2).size.aspect(), 122.0 / 80.0), "Unloaded traps keep the original 80/122 source height aspect")
	for size: Vector2i in [Vector2i(122, 80), Vector2i(248, 162), Vector2i(310, 210)]:
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var texture := ImageTexture.create_from_image(image)
		board.set("_trap_textures", {"fire": texture})
		var rect: Rect2 = board.call("_trap_visual_draw_rect", trap)
		expect.call(is_equal_approx(rect.size.y / rect.size.x, float(size.y) / size.x), "Trap geometry uses actual rounded frame dimensions: " + str(size))
		expect.call((board.call("_trap_draw_rect", trap["pos"]) as Rect2).is_equal_approx(rect), "Trap default geometry shares the loaded static plate aspect")
	board.free()

static func _test_live_trap_envelope(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(960, 680)
	for element: String in ["air", "earth", "fire", "ice", "lightning"]:
		var image := Image.load_from_file("res://assets/art/traps/trap_%s.png" % element)
		var used: Rect2i = image.get_used_rect()
		var texture := ImageTexture.create_from_image(image)
		board.set("_trap_textures", {element: texture})
		var rect: Rect2 = board.call("_trap_visual_draw_rect", {"element": element, "pos": Vector2i(2, 2)})
		var visible: Vector2 = rect.size * Vector2(used.size) / Vector2(image.get_size())
		expect.call(used.size.x > 0 and used.size.y > 0, "Live trap has nonempty alpha bounds: " + element)
		# Same perspective/margin contracts as the native elemental trap probe.
		expect.call(absi(used.size.x - used.size.y * 2) <= 2, "Live trap keeps 2:1 perspective within integer rounding: " + element)
		expect.call(visible.x <= float(board.call("_tile_width")) * 0.75 and visible.y <= float(board.call("_tile_height")) * 0.75, "Live trap keeps the approved stone margin: " + element)
	board.free()

static func _test_fixed_rect_pixel_density(expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(960, 680)
	board.call("_load_assets", false)
	var tile_size := Vector2(float(board.call("_tile_width")), float(board.call("_tile_height")))
	var hero_pixel: float = (board.call("_unit_size") as Vector2).x / 255.0
	var pillar: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar", null)
	expect.call(pillar != null, "Live pillar texture loads for fixed moss-rect proof")
	if pillar == null:
		board.free()
		return
	var pillar_rect: Rect2 = board.call("_prop_draw_rect", pillar, board.call("_prop_rect_for_tile", Vector2i(2, 2)))
	var moss_rect: Rect2 = board.call("_pillar_moss_rect", pillar_rect)
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/assets/board_pixel_density/registry.json"))
	for entry: Dictionary in registry["entries"]:
		var id: String = str(entry["id"])
		if not id.contains("floor") and id != "moss_pillar_overlay":
			continue
		var fixed_size: Vector2 = moss_rect.size if id == "moss_pillar_overlay" else tile_size
		for path: String in entry["paths"]:
			var image := Image.load_from_file("res://" + path)
			expect.call(not image.is_empty(), "Fixed-rect paint loads: " + path)
			if image.is_empty():
				continue
			var pixel_size: Vector2 = fixed_size / Vector2(image.get_size())
			expect.call(absf(pixel_size.x / hero_pixel - 1.0) < 0.01 and absf(pixel_size.y / hero_pixel - 1.0) < 0.01, "Both fixed-rect pixel axes match hero density within canvas rounding: " + path)
			if id.contains("floor"):
				expect.call(image.get_size() == Vector2i(248, 124), "All floor paint uses the 2:1 density canvas: " + path)
				expect.call(is_equal_approx(pixel_size.x, pixel_size.y), "Floor fitting keeps square on-screen source pixels: " + path)
	board.free()

static func _test_chest_registration(expect: Callable) -> void:
	var closed := Image.load_from_file("res://assets/art/tiles/relic_chest.png")
	var body := Image.load_from_file(Chest.ROOT + "body.png")
	var lid := Image.load_from_file(Chest.ROOT + "lid_exterior.png")
	var closed_bounds := Rect2(closed.get_used_rect())
	closed_bounds.position /= Vector2(closed.get_size())
	closed_bounds.size /= Vector2(closed.get_size())
	var composite_bounds := Rect2(body.get_used_rect().merge(lid.get_used_rect()))
	# UVs stretch every padded paint layer into the authored canvas. Its logical
	# offsets/hinges are registration data, independent of density PNG dimensions.
	var to_authored: Vector2 = Chest.CANVAS_SIZE / Vector2(body.get_size())
	composite_bounds.position = (composite_bounds.position * to_authored - Chest.CANVAS_OFFSET) / Chest.LOGICAL_SIZE
	composite_bounds.size = composite_bounds.size * to_authored / Chest.LOGICAL_SIZE
	var pixel_tolerance: float = maxf(to_authored.x / Chest.LOGICAL_SIZE.x, to_authored.y / Chest.LOGICAL_SIZE.y)
	expect.call(composite_bounds.position.distance_to(closed_bounds.position) <= pixel_tolerance and composite_bounds.end.distance_to(closed_bounds.end) <= pixel_tolerance, "Progress-zero opening composite covers the closed chest screen rect within one rounded output pixel")
	for projection: float in [0.16, 0.45, 1.0]:
		expect.call(Chest.project_lid_point(Chest.HINGE_LEFT, projection).is_equal_approx(Chest.HINGE_LEFT) and Chest.project_lid_point(Chest.HINGE_RIGHT, projection).is_equal_approx(Chest.HINGE_RIGHT), "Chest hinge registration stays planted at opening endpoints")
	# The stationary body uses projection 1 at both open_progress 0 and 1.
	expect.call(Chest.project_lid_point(Vector2(0, 96), 1.0).is_equal_approx(Vector2(0, 96)), "Open chest body keeps the closed logical baseline")
