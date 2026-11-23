extends Node2D
## Prepares indexed sheets outside acquisition playback and owns each burst until it expires.

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const SHADER = preload("res://shaders/acquisition_burst.gdshader")
const DATA_PATH := "res://data/acquisition_bursts.json"
const PICKUP_RADIUS := 96.0
const CARD_MARGIN := 64.0
const PICKUP_Z := 1600
const CARD_POP_SCALE := 1.20
const DEEP_TARGET := 0x0e080aff
const DARK_TARGET := 0x140a0cff
const LIGHT_TARGET := 0xfff2c7ff
const HOT := 0xfffae4ff
const RELIC_FALLBACK_ACCENT := 0xd8b25aff
const Data = preload("res://scripts/game_data.gd")
const Elements = preload("res://scripts/element_data.gd")
const GAIN_LAYER := "GainBursts"
const GAIN_PROXY_Z_OFFSET := 2

static var _data: Dictionary

class Stamp extends Node2D:
	var frame: int = 0
	var fit := Vector2i.ZERO
	var card_radius: float
	var _age: float
	var _birth_frame: int
	var _frame_count: int
	var _fps: float
	var _card: Control
	var _held_seconds: float

	func _ready() -> void:
		_birth_frame = Engine.get_process_frames()

	func _draw() -> void:
		draw_rect(Rect2(-Vector2.ONE, Vector2(2.0, 2.0)), Color.WHITE)

	func _process(delta: float) -> void:
		if Engine.get_process_frames() == _birth_frame: return
		_age += delta
		var next: int = floori(_age * _fps + 0.000001)
		if next >= _frame_count:
			hide()
			queue_free()
		elif _held_seconds > 0.0:
			if _age >= _held_seconds: hide()
		elif next != frame:
			set_frame(next)

	func set_frame(next: int) -> void:
		frame = next
		set_instance_shader_parameter("frame", frame)

	func follow_card(card: Control) -> void:
		_card = card
		card.item_rect_changed.connect(_follow_card_position)

	func stop_following() -> void:
		if is_instance_valid(_card) and _card.item_rect_changed.is_connected(_follow_card_position):
			_card.item_rect_changed.disconnect(_follow_card_position)
		_card = null

	func _follow_card_position() -> void:
		position = _card.position + _card.pivot_offset

var _room := Vector2i(-1, -1)
var _height: int
var _stretch: float
var _ui_scale: float
var _target := PackedInt32Array()
var _last_pickup: bool
var _last_reward_size: Vector2
var _last_hover_scale: float
var _last_relic_size: Vector2
var _textures: Dictionary
var _pending := PackedInt32Array()
var _loader: Thread
var _gain_layer: Node2D
var _gain_owner: Control

static func metadata() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	return _data

static func choice_for(radius_px: float, render_height: int) -> Vector2i:
	var cell_px: int = Pixel.grid_px(render_height)
	var sizes: Array = metadata()["sizes"]
	var nearest: int = 0
	for index: int in range(1, sizes.size()):
		if absf(float(sizes[index]["radius_cells"]) * cell_px - radius_px) < absf(float(sizes[nearest]["radius_cells"]) * cell_px - radius_px):
			nearest = index
	return Vector2i(cell_px, nearest)

static func card_radius(card_size: Vector2) -> float:
	return card_size.length() * CARD_POP_SCALE * 0.5 + CARD_MARGIN

static func palette_for(accent: Color) -> PackedColorArray:
	accent.a = 1.0
	return PackedColorArray([
		Color.TRANSPARENT, accent.lerp(Color.hex(DEEP_TARGET), 0.78), accent.lerp(Color.hex(DARK_TARGET), 0.42),
		accent, accent.lerp(Color.hex(LIGHT_TARGET), 0.55), Color.hex(HOT),
	])

func _ready() -> void:
	set_process(false)

func _exit_tree() -> void:
	if _loader != null:
		_loader.wait_to_finish()
		_loader = null

func enter_room(room: Vector2i) -> void:
	if room == _room: return
	_room = room
	clear()

func clear() -> void:
	if is_instance_valid(_gain_layer): _gain_layer.clear()
	for child: Node in get_children():
		if child is Stamp and child._frame_count > 0 and not child.is_queued_for_deletion():
			child.hide()
			child.queue_free()

## The reward widget's hover/focus can change the proxy size even between frames.
## Prepare every nearest sheet across that range, then select using the actual proxy.
func prepare(pickup: bool, reward_size: Vector2, reward_hover_scale: float, relic_size: Vector2 = Vector2.ZERO) -> void:
	var viewport: Viewport = get_viewport()
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var height: int = roundi(viewport.get_visible_rect().size.y * stretch.y)
	var ui_scale: float = get_window().content_scale_factor
	var resized: bool = _height > 0 and (height != _height or stretch.x != _stretch or ui_scale != _ui_scale)
	_height = height
	_stretch = stretch.x
	_ui_scale = ui_scale
	if pickup or reward_size != Vector2.ZERO or relic_size != Vector2.ZERO:
		_last_pickup = pickup
		_last_reward_size = reward_size
		_last_hover_scale = reward_hover_scale
		_last_relic_size = relic_size
	elif resized and get_child_count() > 0:
		# The claim can leave a live reward burst in the same room.
		pickup = _last_pickup
		reward_size = _last_reward_size
		reward_hover_scale = _last_hover_scale
		relic_size = _last_relic_size
	else:
		return
	var requested := PackedInt32Array()
	if pickup:
		requested.append(_fit_for(0.0).y)
	elif reward_size != Vector2.ZERO:
		var first: int = _fit_for(card_radius(reward_size)).y
		var last: int = _fit_for(card_radius(reward_size * reward_hover_scale)).y
		for index: int in range(first, last + 1):
			requested.append(index)
	if relic_size != Vector2.ZERO:
		requested.append(_fit_for(_relic_radius(relic_size)).y)
	if requested != _target:
		_target = requested
		if resized or _loader != null:
			_request_missing()
		else:
			var missing: Dictionary = _missing_sheets()
			_adopt(_load_sheets(missing))
	if resized: _refit_active()

func spawn_pickup(center: Vector2, accent: Color) -> void:
	_spawn(center, accent, PICKUP_Z, 0.0)

func spawn_card(center: Vector2, accent: Color, proxy: Control) -> Stamp:
	var stamp: Stamp = _spawn(center, accent, proxy.z_index - 1, card_radius(proxy.size * proxy.scale))
	if stamp != null:
		stamp.follow_card(proxy)
	return stamp

## The reward refresh removes the offer before delivery starts. Keep the last
## displayed pose and absolute draw order without retaining the offer control.
func relic_launch(icon: Control, accent: String) -> Callable:
	var layer_z: int = icon.z_index
	var item: CanvasItem = icon
	while item.z_as_relative and item.get_parent() is CanvasItem:
		item = item.get_parent() as CanvasItem
		layer_z += item.z_index
	var ink: Color = Color.from_string(accent, Color.hex(RELIC_FALLBACK_ACCENT))
	return _spawn_relic.bind(icon.get_global_rect(), ink, layer_z - 1)

func _spawn_relic(icon_rect: Rect2, accent: Color, layer_z: int) -> void:
	_spawn(to_local(icon_rect.get_center()), accent, layer_z, _relic_radius(icon_rect.size))

static func _relic_radius(icon_size: Vector2) -> float:
	return icon_size.length() * 0.5 + CARD_MARGIN

## Separate sheet targets and screen lifetime from board pickups and relic offers.
func gain_layer() -> Node2D:
	if not is_instance_valid(_gain_layer):
		_gain_layer = get_script().new()
		_gain_layer.name = GAIN_LAYER
		# Keep the legacy resize check scoped to its own stamps and prewarm nodes.
		add_child(_gain_layer, false, Node.INTERNAL_MODE_BACK)
	return _gain_layer

func clear_gains_for(screen: Control) -> void:
	if is_instance_valid(_gain_owner) and _gain_owner == screen:
		clear()
		_gain_owner = null

## Prepare the range of sheets a ware can select while its shelf pose changes.
func prepare_gains(card_size: Vector2, art_sizes: PackedVector2Array, max_source_scale: float = 1.0, min_source_scale: float = 1.0) -> void:
	var viewport: Viewport = get_viewport()
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var height: int = roundi(viewport.get_visible_rect().size.y * stretch.y)
	var resized: bool = height != _height or stretch.x != _stretch
	_height = height
	_stretch = stretch.x
	_ui_scale = get_window().content_scale_factor
	var requested := PackedInt32Array()
	if card_size != Vector2.ZERO:
		_append_gain_range(requested, card_radius(card_size * min_source_scale), card_radius(card_size * max_source_scale))
	for art_size: Vector2 in art_sizes:
		_append_gain_range(requested, _relic_radius(art_size * min_source_scale), _relic_radius(art_size * max_source_scale))
	if requested == _target and not resized: return
	_target = requested
	_adopt(_load_sheets(_missing_sheets()))

func _append_gain_range(requested: PackedInt32Array, first_radius: float, last_radius: float) -> void:
	for index: int in range(_fit_for(first_radius).y, _fit_for(last_radius).y + 1):
		if not requested.has(index): requested.append(index)

static func gain_accent(kind: String, id: String) -> Color:
	match kind:
		"card": return Elements.accent(Data.card_element(id))
		"item": return Color(Data.card_rarity_accent(Data.card_rarity(id)))
		"equipment": return Color(Data.equipment_accent(id))
	return Color.from_string(str(Data.relic_def(id).get("accent", "")), Color.hex(RELIC_FALLBACK_ACCENT))

static func _effective_z(proxy: CanvasItem) -> int:
	var layer_z: int = proxy.z_index
	while proxy.z_as_relative and proxy.get_parent() is CanvasItem:
		proxy = proxy.get_parent() as CanvasItem
		layer_z += proxy.z_index
	return layer_z

func spawn_gain(screen: Control, art: Rect2, proxy: Control, accent: Color, card: bool, reduced: bool) -> Stamp:
	return _spawn_gain(screen, art, _effective_z(proxy) - 1, accent, card, reduced)

func dragon_launch(screen: Control, artwork: TextureRect, accent: Color, reduced: bool) -> Callable:
	var rect: Rect2 = artwork.get_global_rect()
	if artwork.texture != null:
		var art_size: Vector2 = artwork.texture.get_size()
		art_size *= minf(rect.size.x / art_size.x, rect.size.y / art_size.y)
		rect = Rect2(rect.get_center() - art_size * 0.5, art_size)
	return _spawn_gain.bind(screen, rect, _effective_z(artwork) - 1, accent, false, reduced)

func _spawn_gain(screen: Control, art: Rect2, layer_z: int, accent: Color, card: bool, reduced: bool) -> Stamp:
	if _gain_owner != screen:
		clear()
		_gain_owner = screen
	var radius: float = card_radius(art.size) if card else _relic_radius(art.size)
	var stamp: Stamp = _spawn(to_local(art.get_center()), accent, layer_z, radius)
	if stamp != null and reduced:
		stamp._held_seconds = float(metadata()["reduced_motion_seconds"])
		stamp.set_frame(int(metadata()["reduced_motion_frame"]))
	return stamp

func _spawn(center: Vector2, accent: Color, layer_z: int, radius: float) -> Stamp:
	if _textures.is_empty(): return null
	var fit: Vector2i = _fit_for(radius)
	if not _textures.has(fit.y):
		# A resize can land on the same frame as an acquisition. Use the closest
		# prepared sheet at the new pixel grid until the worker publishes its result.
		fit.y = _closest_loaded(fit.y)
	var stamp := Stamp.new()
	stamp.name = "AcquisitionBurst"
	stamp.position = center
	stamp.z_as_relative = false
	stamp.z_index = layer_z
	stamp.card_radius = radius
	stamp._frame_count = int(metadata()["frames"])
	stamp._fps = float(metadata()["fps"])
	var ink := ShaderMaterial.new()
	ink.shader = SHADER
	ink.set_shader_parameter("palette", palette_for(accent))
	stamp.material = ink
	add_child(stamp, true)
	_place(stamp, fit)
	return stamp

func _fit_for(radius: float) -> Vector2i:
	var wanted: float = PICKUP_RADIUS * _ui_scale if radius <= 0.0 else radius * _stretch
	return choice_for(wanted, _height)

func _closest_loaded(index: int) -> int:
	var sizes: Array = metadata()["sizes"]
	var wanted: int = int(sizes[index]["radius_cells"])
	var closest: int = -1
	var best: int = -1
	for candidate: int in _textures:
		var distance: int = absi(int(sizes[candidate]["radius_cells"]) - wanted)
		if best < 0 or distance < best:
			closest = candidate
			best = distance
	return closest

func _place(stamp: Stamp, fit: Vector2i) -> void:
	stamp.fit = fit
	var radius: int = int(metadata()["sizes"][fit.y]["radius_cells"])
	if _textures.has(fit.y):
		stamp.material.set_shader_parameter("atlas", _textures[fit.y])
	stamp.material.set_shader_parameter("radius_cells", radius)
	stamp.material.set_shader_parameter("cell_px", float(fit.x))
	var extent := Vector2.ONE * (radius * fit.x + 1.0) / _stretch
	RenderingServer.canvas_item_set_custom_rect(stamp.get_canvas_item(), true, Rect2(-extent, extent * 2.0))

func _refit_active() -> void:
	for child: Node in get_children():
		if child is Stamp and child._frame_count > 0 and not child.is_queued_for_deletion():
			var fit: Vector2i = _fit_for(child.card_radius)
			# The live material retains its sheet while the next one loads.
			if not _textures.has(fit.y): fit.y = child.fit.y
			_place(child, fit)

func _missing_sheets() -> Dictionary:
	var paths: Dictionary
	for index: int in _target:
		if not _textures.has(index):
			paths[index] = metadata()["sizes"][index]["atlas"]
	return paths

static func _load_sheets(paths: Dictionary) -> Dictionary:
	var loaded: Dictionary
	for index: int in paths:
		var path: String = paths[index]
		loaded[index] = ResourceLoader.load(path) if ResourceLoader.exists(path) else Image.load_from_file(path)
	return loaded

func _request_missing() -> void:
	if _loader != null: return
	var missing: Dictionary = _missing_sheets()
	if missing.is_empty():
		_adopt({})
		return
	_pending = _target.duplicate()
	_loader = Thread.new()
	if _loader.start(_load_sheets.bind(missing)) != OK:
		_loader = null
		push_error("Cannot start acquisition burst sheet loading.")
		return
	set_process(true)

func _process(_delta: float) -> void:
	if _loader.is_alive(): return
	var loaded: Dictionary = _loader.wait_to_finish()
	_loader = null
	set_process(false)
	_adopt(loaded)
	if _pending != _target: _request_missing()

func _adopt(loaded: Dictionary) -> void:
	for index: int in loaded:
		if not _target.has(index): continue
		var resource: Resource = loaded[index]
		if resource == null:
			push_error("Cannot load acquisition burst sheet %d." % index)
			continue
		_textures[index] = ImageTexture.create_from_image(resource) if resource is Image else resource
		_warm(index)
	if not _missing_sheets().is_empty(): return
	_refit_active()
	for index: int in _textures.keys():
		if not _target.has(index): _textures.erase(index)

func _warm(index: int) -> void:
	if DisplayServer.get_name() == "headless": return
	var stamp := Stamp.new()
	stamp.name = "AcquisitionBurstPrewarm"
	stamp.process_mode = Node.PROCESS_MODE_DISABLED
	stamp.position = get_viewport_rect().size * 0.5
	stamp.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	var ink := ShaderMaterial.new()
	ink.shader = SHADER
	ink.set_shader_parameter("palette", palette_for(Color.WHITE))
	stamp.material = ink
	add_child(stamp)
	stamp.set_frame(int(metadata()["frames"]) - 1)
	_place(stamp, Vector2i(Pixel.grid_px(_height), index))
	RenderingServer.frame_post_draw.connect(stamp.queue_free, CONNECT_ONE_SHOT)
