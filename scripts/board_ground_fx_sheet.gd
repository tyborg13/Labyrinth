extends RefCounted
## Baked Fire and Electrified rows. The floor field supplies the same visible
## membership and fight seed used by the patches.

const Assets = preload("res://scripts/asset_loader.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Field = preload("res://scripts/board_pixel_surface_field.gd")
const Stamp = preload("res://scripts/board_ground_fx_stamp.gd")
const SHADER = preload("res://shaders/ground_fx_sheet.gdshader")
const DATA_PATH: String = "res://data/ground_fx_atlas.json"
const ATLAS_DIR: String = "res://assets/art/effects/ground"
const PALETTE_CAPACITY: int = 16
const STILL_FRAME: int = 3
const FIRE: int = 1

static var _data: Dictionary = {}
static var _textures: Array[Texture2D]
static var _palette := PackedColorArray()
static var _sheet_tile_widths := PackedInt32Array()

var ink: ShaderMaterial
var tick: int = -1
var fps: int
var frames: int
var bounds: Rect2
var cell_px: int
var sheet_index: int = -1
var _physical_scale := Vector2.ZERO
var _layout_tile_width: float
var _render_height: int
var _cull_bounds: Rect2
var stamps: Dictionary = {}
var _rows: Array[Dictionary]

static func add_texture_manifest(manifest: Dictionary) -> void:
	_load_metadata()
	for size: Dictionary in _data["sizes"]:
		manifest[ATLAS_DIR.path_join(size["atlas"])] = false

static func prepare_textures() -> void:
	if not _textures.is_empty():
		return
	_load_metadata()
	for size: Dictionary in _data["sizes"]:
		var texture: Texture2D = Assets.load_texture(ATLAS_DIR.path_join(size["atlas"]))
		assert(texture != null, "Missing ground FX sheet: " + str(size["atlas"]))
		_textures.append(texture)

static func _load_metadata() -> void:
	if not _data.is_empty():
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for size: Dictionary in _data["sizes"]:
		_sheet_tile_widths.append(int(size["tile_cells"][0]))
	for color: String in _data["palette"]:
		_palette.append(Color(color))
	_palette.resize(PALETTE_CAPACITY)

func setup() -> void:
	if ink != null:
		return
	assert(not _textures.is_empty(), "Prepare ground FX with the board's effect textures")
	frames = int(_data["frames"])
	fps = int(_data["fps"])
	var authored_rows: Dictionary = _data["rows"]
	for variant: int in 2:
		var suffix: String = "_%d" % variant
		var rows: Dictionary = {}
		for name_with_variant: String in authored_rows:
			if name_with_variant.ends_with(suffix):
				rows[name_with_variant.trim_suffix(suffix)] = int(authored_rows[name_with_variant])
		_rows.append(rows)
	ink = ShaderMaterial.new()
	ink.shader = SHADER
	ink.set_shader_parameter("palette", _palette)
	ink.set_shader_parameter("frames", frames)
	ink.set_shader_parameter("still_frame", STILL_FRAME)

func set_time(seconds: float, reduced: bool) -> void:
	var next: int = -1 if reduced else floori(seconds * fps)
	if next != tick:
		tick = next
		ink.set_shader_parameter("tick", tick)

func frame_at(phase: int) -> int:
	return STILL_FRAME if tick < 0 else (tick + phase) % frames

static func phase(seed_value: int, tile: Vector2i) -> int:
	# Reserve two bits for a seeded 2x2 checker pattern so all eight
	# neighbours have distinct phases, even when the tile hashes collide.
	var parity: int = (tile.x & 1) | ((tile.y & 1) << 1)
	return (Field.world_hash(seed_value, tile, 0, 0, 0) & 12) | (parity ^ (hash(seed_value) & 3))

static func variant_for(seed_value: int, tile: Vector2i) -> int:
	return Field.world_hash(seed_value, tile, 0, 0, 1) & 1

func rows_for(flags: int, variant: int, occupied: bool, grounded: bool, front: bool) -> Vector2i:
	var rows: Dictionary = _rows[variant]
	var fire: int = -1
	var electric: int = -1
	if Field.tile_kind(flags, FIRE):
		if grounded:
			fire = rows["fire_full_front"] if front else rows["fire_full_rear"]
		else:
			fire = rows["fire_low_front"] if front else rows["fire_low_rear"]
	if (flags & Field.STORMCOAL) != 0:
		electric = rows["electrified_storm_front"] if front else rows["electrified_storm_rear"]
	elif Field.has_electrified_decal(flags):
		if front:
			electric = rows["electrified_front"] if occupied else rows["electrified_front_quiet"]
		else:
			electric = rows["electrified_rear"]
	return Vector2i(fire, electric)

func sync_size(layout_tile_width: float, physical_scale: Vector2, render_height: int) -> void:
	if _layout_tile_width == layout_tile_width and _physical_scale == physical_scale and _render_height == render_height:
		return
	_layout_tile_width = layout_tile_width
	_physical_scale = physical_scale
	_render_height = render_height
	var choice: Vector2i = Pixel.choose_sheet_size(layout_tile_width * physical_scale.x, render_height, _sheet_tile_widths)
	if choice.y != sheet_index:
		sheet_index = choice.y
		var size: Dictionary = _data["sizes"][sheet_index]
		var cells := Vector2i(size["frame_cells"][0], size["frame_cells"][1])
		var center := Vector2i(size["tile_centre_cell"][0], size["tile_centre_cell"][1])
		bounds = Rect2(-center, cells)
		ink.set_shader_parameter("atlas", _textures[sheet_index])
		ink.set_shader_parameter("frame_cells", cells)
		ink.set_shader_parameter("centre_cell", center)
	if choice.x != cell_px:
		cell_px = choice.x
		ink.set_shader_parameter("cell_px", float(cell_px))
	# The vertex shader can move the frame at most half a framebuffer pixel
	# when it snaps the centre. The retained rect covers that exact envelope.
	var local_cell: Vector2 = Vector2.ONE * cell_px / physical_scale
	var snap_margin: Vector2 = Vector2(0.5, 0.5) / physical_scale
	_cull_bounds = Rect2(bounds.position * local_cell - snap_margin, bounds.size * local_cell + snap_margin * 2.0)
	for stamp: Stamp in stamps.values():
		if is_instance_valid(stamp):
			stamp.set_cull_bounds(_cull_bounds)

func framebuffer_rect(center: Vector2) -> Rect2:
	return Rect2(center.round() + bounds.position * cell_px, bounds.size * cell_px)

func sync(board: Control, field: Field, projection: Transform2D, occupants: Dictionary) -> void:
	var rear: Dictionary = board.get("_scene_back_effect_render_layers_by_tile")
	var front: Dictionary = board.get("_scene_front_effect_render_layers_by_tile")
	for tile: Vector2i in field.tiles:
		var flags: int = field.tiles[tile]
		if not Field.tile_kind(flags, FIRE) and not Field.has_electrified_decal(flags):
			continue
		var actor: Dictionary = occupants.get(tile, {})
		var occupied: bool = not actor.is_empty()
		var grounded: bool = bool(actor.get("grounded", false))
		var body: CanvasItem = actor.get("canvas")
		var center: Vector2 = projection * Vector2(tile)
		var variant: int = variant_for(field.seed, tile)
		var offset: int = phase(field.seed, tile)
		for pass_index: int in 2:
			var forward: bool = pass_index == 1
			var parent: CanvasItem = (front if forward else rear).get(tile)
			if not is_instance_valid(parent):
				continue
			# Ground shares the effect slots but paints before their overlays.
			var behind: bool = true
			# Normally the tile's own slots bracket the body and its outline.
			# Moving and large actors can be hosted on a different tile.
			if is_instance_valid(body):
				var body_index: int = body.get_parent().get_index()
				if (forward and body_index > parent.get_index()) or (not forward and body_index < parent.get_index()):
					parent = body
					behind = not forward
			var key := Vector3i(tile.x, tile.y, int(forward))
			var stamp: Stamp = stamps.get(key)
			if not is_instance_valid(stamp) or stamp.is_queued_for_deletion():
				stamp = Stamp.new()
				stamp.name = "GroundFxFront" if forward else "GroundFxRear"
				stamp.material = ink
				parent.add_child(stamp, true)
				stamp.set_cull_bounds(_cull_bounds)
				stamps[key] = stamp
			elif stamp.get_parent() != parent:
				stamp.reparent(parent, false)
			stamp.show_behind_parent = behind
			if behind and parent == body:
				var shadow: Node = body.get_node_or_null("PixelContactShadow")
				if shadow != null and stamp.get_index() > shadow.get_index():
					body.move_child(stamp, shadow.get_index())
			stamp.present(center, rows_for(flags, variant, occupied, grounded, forward), offset, tick, flags, field.seed)
	for key: Vector3i in stamps.keys():
		var flags: int = field.tiles.get(Vector2i(key.x, key.y), 0)
		if not Field.tile_kind(flags, FIRE) and not Field.has_electrified_decal(flags):
			_remove(key)

func clear() -> void:
	for key: Vector3i in stamps.keys():
		_remove(key)

func _remove(key: Vector3i) -> void:
	var stamp: Stamp = stamps[key]
	if is_instance_valid(stamp):
		stamp.hide()
		stamp.queue_free()
	stamps.erase(key)
