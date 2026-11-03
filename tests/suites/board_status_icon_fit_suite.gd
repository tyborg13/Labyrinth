extends RefCounted

const Plates = preload("res://scripts/board_status_plates.gd")
const Fixture = preload("res://tests/status_icon_fixture.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Board = preload("res://scripts/combat_board_view.gd")
# Test-only subpixel movement, scan threshold fixtures and comparison epsilon.
const OFFSETS: PackedVector2Array = [Vector2.ZERO, Vector2(0.25, -0.5), Vector2(-140.75, 22.75)]
const EPSILON: float = 0.0001
const SYNTHETIC_SIZE := Vector2i(40, 40)
const SYNTHETIC_VISIBLE := Rect2i(23, 5, 7, 29)
const SYNTHETIC_FITTING := Rect2i(23, 3, 7, 34)
const FITTING_OFFSET := Vector2(0, 0.5)
const LOW_ALPHA: float = 0.09
const HIGH_ALPHA: float = 0.11

static func run(expect: Callable) -> void:
	_test_inventory(expect)
	_test_load_time_prewarm(expect)
	var checked: int = 0
	for icon: String in Fixture.ICON_KEYS:
		var texture: Texture2D = Icons.icon_texture(icon)
		expect.call(texture != null, "Status fit inventory resolves approved texture: " + icon)
		if texture == null: continue
		var bounds: Rect2i = _scan(texture.get_image())
		expect.call(bounds.has_area() and Plates.icon_visible_bounds(texture) == bounds, "Status fit measures alpha > 10%: " + icon)
		for kind: String in Fixture.KINDS:
			for offset: Vector2 in OFFSETS:
				var entry: Dictionary = Fixture.entry(icon, kind)
				entry["rect"] = Rect2((entry["rect"] as Rect2).position + offset, (entry["rect"] as Rect2).size)
				_check_draw(expect, entry, texture, Rect2(bounds), icon + "/" + kind)
				checked += 1
	_test_threshold_and_cache(expect)
	print("STATUS ICON FIT COVERAGE: %d icons x 3 presentations x 3 positions = %d draws" % [Fixture.ICON_KEYS.size(), checked])

static func _test_load_time_prewarm(expect: Callable) -> void:
	expect.call(Plates.BOARD_ICON_KEYS == Fixture.ICON_KEYS, "Status prewarm covers the independently verified board inventory")
	Plates._icon_visible_bounds.clear()
	for icon: String in Fixture.ICON_KEYS:
		Assets._texture_used_rect_cache.erase(Assets._texture_processing_cache_key(Icons.icon_texture(icon)))
	var board := Board.new()
	var before: int = Plates.icon_bounds_computations
	board._load_assets(false)
	expect.call(Plates.icon_bounds_computations - before == Fixture.ICON_KEYS.size(), "Board asset loading computes each status icon's bounds before any draw")
	var prepared: int = Plates.icon_bounds_computations
	var source_cache_size: int = Assets._texture_used_rect_cache.size()
	for icon: String in Fixture.ICON_KEYS:
		var texture: Texture2D = board._keyword_icon_textures.get(icon)
		expect.call(texture != null and Plates._icon_visible_bounds.has(texture), "Board loading prewarms visible bounds for " + icon)
		expect.call(Assets._texture_used_rect_cache.has(Assets._texture_processing_cache_key(texture)), "Board loading prewarms source bounds for " + icon)
		for kind: String in Fixture.KINDS:
			Plates.draw_entry(Fixture.Recorder.new(), Fixture.entry(icon, kind), texture)
		expect.call(Plates.icon_bounds_computations == prepared, "Prewarmed full/compact/plate draws never compute bounds for " + icon)
	expect.call(Assets._texture_used_rect_cache.size() == source_cache_size, "Prewarmed draws never compute new source bounds")
	# The staged loader consumes these exact jobs. Re-running them must hit the
	# same per-texture cache rather than rescanning on each board/layer load.
	for job: Callable in board._initial_asset_jobs(false):
		if str(job.get_method()) == "_load_keyword_icon_asset": job.call()
	expect.call(Plates.icon_bounds_computations == prepared, "Staged/repeated icon loading reuses the prepared bounds")
	board.free()

static func _check_draw(expect: Callable, entry: Dictionary, texture: Texture2D, bounds: Rect2, label: String) -> void:
	var before: Dictionary = entry.duplicate(true)
	var recorder := Fixture.Recorder.new()
	Plates.draw_entry(recorder, entry, texture)
	expect.call(entry == before, "Status fit preserves all entry geometry/text/metadata: " + label)
	expect.call(recorder.textures.size() == 1, "Status fit paints exactly once: " + label)
	if recorder.textures.size() != 1: return
	var painted: Dictionary = recorder.textures[0]
	var visible: Rect2 = Fixture.visible_from_draw(painted, bounds)
	# Independent oracle: old nominal slot intersected with the border's inner
	# edge plus the brief's 1 px clearance. Do not use production fit geometry.
	var rect: Rect2 = entry["rect"]
	var plate: bool = bool(entry.get("defense_plate", false))
	var side: float = 20.0 if plate else 18.0
	var slot := Rect2(rect.position + Vector2(4.0 if plate else 3.0, 2.0), Vector2.ONE * side)
	var fit: Rect2 = slot.intersection(rect.grow(-3.0))
	expect.call(Plates.icon_fit_box(entry) == fit, "Status fit keeps the original icon slot with border clearance: " + label)
	expect.call(fit.grow(EPSILON).encloses(visible), "Status fit has 0 px visible overrun: " + label)
	var delta: Vector2 = (visible.get_center() - fit.get_center()).abs()
	expect.call(delta.x <= 1.0 and delta.y <= 1.0, "Status fit visible bounds centered within 1 px: " + label)
	expect.call(visible.position.is_equal_approx(visible.position.round()), "Status fit snaps visible origin to whole pixels: " + label)
	var source: Rect2 = painted["source"]
	var scale: Vector2 = (painted["rect"] as Rect2).size / source.size
	var nominal: float = side / maxf(source.size.x, source.size.y)
	expect.call(is_equal_approx(scale.x, scale.y) and scale.x <= nominal + EPSILON, "Status fit preserves aspect and never scales up: " + label)
	var pixel_size: Vector2 = fit.end - fit.position.ceil()
	var expected: float = minf(nominal, minf(pixel_size.x / bounds.size.x, pixel_size.y / bounds.size.y))
	expect.call(is_equal_approx(scale.x, expected), "Status fit retains current scale whenever visible art already fits: " + label)
	expect.call(source == Rect2(Assets.texture_used_rect(texture)) and painted["color"] == Color(1.0, 1.0, 1.0, float(entry["presentation_alpha"])), "Status fit preserves texture source, full color and prediction opacity: " + label)

static func _scan(image: Image) -> Rect2i:
	if image.is_compressed(): image.decompress()
	# Independent threshold oracle using a binary mask and Godot's used rect.
	var mask := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1: mask.set_pixel(x, y, Color.WHITE)
	return mask.get_used_rect()

static func _test_threshold_and_cache(expect: Callable) -> void:
	var image := Image.create(SYNTHETIC_SIZE.x, SYNTHETIC_SIZE.y, false, Image.FORMAT_RGBAF)
	image.fill(Color(1.0, 1.0, 1.0, LOW_ALPHA))
	image.fill_rect(SYNTHETIC_VISIBLE, Color(1.0, 1.0, 1.0, HIGH_ALPHA))
	var texture := ImageTexture.create_from_image(image)
	var before: int = Plates.icon_bounds_computations
	expect.call(Plates.icon_visible_bounds(texture) == SYNTHETIC_VISIBLE, "Status fit ignores padding below 10% alpha")
	expect.call(Plates.icon_bounds_computations == before + 1, "Unanticipated textures retain the per-texture bounds fallback")
	var cached: int = Plates._icon_visible_bounds.size()
	for kind: String in Fixture.KINDS:
		var entry: Dictionary = Fixture.entry("immobilize", kind)
		entry["presentation_alpha"] = 0.7
		_check_draw(expect, entry, texture, Rect2(SYNTHETIC_VISIBLE), "asymmetric-alpha/" + kind)
		Plates.icon_visible_bounds(texture)
	expect.call(Plates._icon_visible_bounds.size() == cached, "Status fit reuses per-texture bounds across pills and plates")
	expect.call(Plates.icon_bounds_computations == before + 1, "Fallback textures compute bounds once across every presentation")
	image.fill(Color(1.0, 1.0, 1.0, LOW_ALPHA))
	image.fill_rect(SYNTHETIC_FITTING, Color.WHITE)
	var fitting := ImageTexture.create_from_image(image)
	var fitting_entry: Dictionary = Fixture.entry("immobilize", "compact")
	fitting_entry["rect"] = Rect2((fitting_entry["rect"] as Rect2).position + FITTING_OFFSET, (fitting_entry["rect"] as Rect2).size)
	_check_draw(expect, fitting_entry, fitting, Rect2(SYNTHETIC_FITTING), "already-fitting-subpixel")
	var geometry: Dictionary = Plates.icon_geometry(fitting_entry, fitting)
	expect.call(is_equal_approx((geometry["rect"] as Rect2).size.x / (geometry["source"] as Rect2).size.x, 18.0 / SYNTHETIC_SIZE.x), "Status fit does not shrink already-fitting art merely to snap its far edge")
	# All-transparent/subthreshold art must never divide by zero or paint a phantom.
	image.fill(Color(1.0, 1.0, 1.0, LOW_ALPHA))
	var empty := ImageTexture.create_from_image(image)
	var recorder := Fixture.Recorder.new()
	var entry: Dictionary = Fixture.entry("chilled", "compact")
	Plates.draw_entry(recorder, entry, empty)
	Plates.draw_entry(recorder, entry, null)
	expect.call(recorder.textures.is_empty(), "Status fit omits null and entirely subthreshold textures")

static func _test_inventory(expect: Callable) -> void:
	# Traverse actual badge producers, including arbitrary keyword-status icons,
	# rather than relying solely on the hand-maintained proof sheet inventory.
	var board := Board.new()
	board.presentation = {"umbra_truesight_activations": -1}
	var unit: Dictionary = {"role": "player", "freeze": 1, "petrify": 1, "shock": 1, "immobilize": true, "bleed": 2, "expose": 2, "frost_armor": 2, "chilled": true, "hp": 24, "charge": 2, "burrowed": true}
	var keywords: Array[Dictionary]
	for icon: String in ["retaliate", "quicken", "next_attack", "ranged"]: keywords.append({"icon": icon})
	for icon: String in Icons.SELF_FLAG_ICON_KEYS.values(): keywords.append({"icon": icon})
	unit["keyword_badges"] = keywords
	var shown: Dictionary = {"block": true, "stoneskin": true}
	for type: String in ["glacial_mirror", "gale_herald", "gust_shrike", "storm_capacitor", "veilbound_acolyte", "burrow_grub", "ember_tick"]:
		unit["type"] = type
		for badge: Dictionary in board._unit_status_badges(unit): shown[str(badge["icon"])] = true
	unit["freeze"] = 0
	for badge: Dictionary in board._unit_status_badges(unit): shown[str(badge["icon"])] = true
	for icon: String in shown: expect.call(Fixture.ICON_KEYS.has(icon), "Status fit sheet covers live board icon: " + icon)
	for icon: String in Fixture.ICON_KEYS: expect.call(shown.has(icon), "Status fit inventory has live board provenance: " + icon)
	board.free()
