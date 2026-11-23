extends SceneTree

const Burst = preload("res://scripts/acquisition_burst.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const LOADED_CARD_SIZE := Vector2(292.0, 411.136)
const CENTER := Vector2(941.375, 479.625)
const CARD_HOVER_SCALE := 1.10
const RESIZE_SIZE := Vector2i(1280, 720)
const RESIZE_WAIT_FRAMES := 180
const RESIZE_WAIT_SECONDS := 0.002
const TEST_FPS := 60.0
const CASES := [
	[Vector2i(1280, 720), Vector2i(1, 3), Vector2i(1, 8)],
	[Vector2i(1280, 800), Vector2i(1, 3), Vector2i(1, 8)],
	[Vector2i(1920, 1080), Vector2i(2, 0), Vector2i(2, 7)],
	[Vector2i(2560, 1440), Vector2i(3, 0), Vector2i(3, 7)],
	[Vector2i(3840, 2160), Vector2i(4, 0), Vector2i(4, 7)],
]
# Independent sRGB channel results for the three preview colour families.
const PALETTES := [
	[0xf0c978ff, 0x403222ff, 0x94794bff, 0xf8e0a3ff],
	[0x78cfffff, 0x253440ff, 0x4e7c99ff, 0xc2e2e0ff],
	[0xc084e8ff, 0x35233bff, 0x78518cff, 0xe3c0d6ff],
]

var _checks: int
var _failures: int

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_verify")

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition: return
	_failures += 1
	push_error(label)

func _verify() -> void:
	_verify_sizes()
	_verify_bake()
	await _verify_playback()
	print("FND-01 VERIFY: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _verify_sizes() -> void:
	for entry: Array in CASES:
		var output: Vector2i = entry[0]
		var stretch: float = minf(float(output.x) / VIEWPORT_SIZE.x, float(output.y) / VIEWPORT_SIZE.y)
		var pickup: Vector2i = Burst.choice_for(96.0, output.y)
		var card: Vector2i = Burst.choice_for(Burst.card_radius(LOADED_CARD_SIZE) * stretch, output.y)
		_expect(pickup == entry[1], "Pickup sheet and cell for %s" % output)
		_expect(card == entry[2], "Reward sheet and cell for %s" % output)
		print("FND-01 FIT %dx%d: cell=%d pickup=%d card=%d" % [
			output.x, output.y, pickup.x,
			int(Burst.metadata()["sizes"][pickup.y]["radius_cells"]),
			int(Burst.metadata()["sizes"][card.y]["radius_cells"]),
		])

func _verify_bake() -> void:
	var data: Dictionary = Burst.metadata()
	_expect(int(data["frames"]) == 16 and int(data["fps"]) == 30, "Authored playback is 16 frames at 30 fps")
	for sheet: Dictionary in data["sizes"]:
		var path: String = sheet["atlas"]
		var texture: Texture2D = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
		var image: Image = texture.get_image() if texture != null else Image.load_from_file(path)
		var side: int = int(sheet["radius_cells"]) * 2
		_expect(image != null and image.get_size() == Vector2i(side * 16, side), "%s uses square frames" % path)
		if image == null: continue
		# Hash the indexed bytes, including every authored frame and transparent cell.
		image.convert(Image.FORMAT_L8)
		var bytes: PackedByteArray = image.get_data()
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		_expect(hash.finish().hex_encode() == sheet["sha256_pixels"], "%s matches the director's bake" % path)
		_expect(bytes.has(5) and not bytes.has(6), "%s uses the authored palette indices" % path)
		var last: PackedByteArray = image.get_region(Rect2i(side * 15, 0, side, side)).get_data()
		_expect(last.count(0) == last.size(), "%s has a transparent warm-up frame" % path)
	for entry: Array in PALETTES:
		var accent: Color = Color.hex(entry[0])
		accent.a = 0.25
		var colors: PackedColorArray = Burst.palette_for(accent)
		_expect(colors.size() == 6 and colors[0].a == 0.0, "Index zero is empty")
		var expected: Array[int] = [entry[1], entry[2], entry[0], entry[3], 0xfffae4ff]
		for index: int in range(1, colors.size()):
			var want: Color = Color.hex(expected[index - 1])
			var actual: Color = colors[index]
			var difference := Vector3(absf(want.r - actual.r), absf(want.g - actual.g), absf(want.b - actual.b))
			_expect(difference[difference.max_axis_index()] <= 0.5 / 255.0 + 0.000001 and actual.a == 1.0,
				"Index %d maps to the sRGB recipe for %s (%s vs %s)" % [index, str(entry[0]), actual.to_html(), want.to_html()])

func _verify_playback() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	root.content_scale_factor = 1.0
	var host := Burst.new()
	viewport.add_child(host)
	host.enter_room(Vector2i.ONE)
	host.prepare(true, Vector2.ZERO, CARD_HOVER_SCALE)
	_expect(host._textures.size() == 1 and host._textures.has(0), "Pickup sheet is prepared before the effect")
	var icon := Control.new()
	icon.z_index = 1602
	viewport.add_child(icon)
	host.spawn_pickup(CENTER, Color.WHITE)
	var pickup: Burst.Stamp = host.get_child(0) as Burst.Stamp
	_expect(pickup.z_index == 1600 and pickup.z_index < icon.z_index, "Pickup is behind the icon")
	_expect(pickup.position == CENTER and pickup.frame == 0 and pickup.fit == Vector2i(2, 0), "Pickup starts in place on frame 0")
	icon.queue_free()
	await process_frame
	_expect(not is_instance_valid(icon) and is_instance_valid(pickup), "Removing the icon leaves its burst alive")
	var lifetime_ticks: int = roundi(TEST_FPS * 16.0 / 30.0)
	for tick: int in range(1, lifetime_ticks):
		await process_frame
		_expect(is_instance_valid(pickup), "Pickup survives before 16/30 seconds, tick %d" % tick)
		if not is_instance_valid(pickup): break
	# process_frame fires before node processing. At the last observation the
	# node has consumed 31 ticks; the next observation sees the end of tick 32.
	_expect(is_instance_valid(pickup) and pickup.frame == 15, "Pickup presents the final authored frame")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(pickup), "Pickup frees itself at the end of its clock")

	host.prepare(false, LOADED_CARD_SIZE, CARD_HOVER_SCALE)
	_expect(host._textures.size() == 2 and host._textures.has(7) and host._textures.has(8), "Resting and hovered reward sheets are prepared")
	var proxy := Control.new()
	proxy.size = LOADED_CARD_SIZE
	proxy.pivot_offset = proxy.size * 0.5
	proxy.position = CENTER - proxy.pivot_offset
	proxy.z_index = 1602
	viewport.add_child(proxy)
	var card: Burst.Stamp = host.spawn_card(CENTER, Color.WHITE, proxy)
	_expect(card.z_index == proxy.z_index - 1 and not card.z_as_relative, "Reward burst is behind the proxy")
	proxy.position.y -= 13.25
	_expect(card.position == proxy.position + proxy.pivot_offset, "Reward follows the same proxy lift")
	card.stop_following()
	var final_center: Vector2 = card.position
	proxy.hide()
	proxy.position = Vector2.ZERO
	_expect(card.position == final_center, "Releasing a proxy leaves the burst at the end of its lift")
	host.enter_room(Vector2i.ZERO)
	await process_frame
	_expect(not is_instance_valid(card), "Moving rooms drops live bursts")

	host.prepare(true, Vector2.ZERO, CARD_HOVER_SCALE)
	host.spawn_pickup(CENTER, Color.WHITE)
	viewport.size = RESIZE_SIZE
	host.prepare(true, Vector2.ZERO, CARD_HOVER_SCALE)
	_expect(host._loader != null and host._pending == PackedInt32Array([3]), "Resize requests the new sheet on a thread")
	for frame: int in RESIZE_WAIT_FRAMES:
		if host._loader == null: break
		await create_timer(RESIZE_WAIT_SECONDS, true, false, true).timeout
	_expect(host._textures.size() == 1 and host._textures.has(3), "Resize adopts the requested sheet")
	host.clear()
	await process_frame
	host.spawn_pickup(CENTER, Color.WHITE)
	pickup = host.get_child(0) as Burst.Stamp
	_expect(pickup.fit == Vector2i(1, 3), "After resize the pickup uses the newly prepared pixel grid")
	viewport.queue_free()
	await process_frame
	_expect(not is_instance_valid(host) and not is_instance_valid(pickup), "Scene teardown drops live bursts")
