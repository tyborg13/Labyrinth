extends Node2D
## Pixel ground samples the authored GRD-07 atlas on a board-anchored grid.

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Field = preload("res://scripts/board_pixel_surface_field.gd")
const Decals = preload("res://scripts/board_pixel_surface_decals.gd")
const Depth = preload("res://scripts/board_pixel_surface_depth.gd")
const Sheet = preload("res://scripts/board_ground_fx_sheet.gd")
const SHADER = preload("res://shaders/ground_surface_field.gdshader")
const STYLE_PATH: String = "res://data/ground_surface_style.json"
const MODE_ENV: String = "LABYRINTH_GROUND_FX"
const PATCH_AREA: float = 0.80
const FRINGE_TEXELS: float = 2.0
const EDGE_RUN_TEXELS: float = 6.0
const EDGE_AMPLITUDE_TEXELS: float = 2.0
const EDGE_LOBES_PER_SIDE: float = 2.0
# Same first still as the approved GRD-07 contact sheet.
const ATLAS_STILL_SECONDS: float = 12.0
const FIRE_SCROLL_STEP: float = 0.25
const ELECTRIC_PULSE := Vector2(1.2, 0.15)
const ICE_GLINT_SECONDS: float = 0.35

static var _style: Dictionary = {}
static var _atlases: Dictionary = {}

var field := Field.new()
var depth := Depth.new()
var sheet := Sheet.new()
var decals := Decals.new()
var texel: float
var render_texel: float
var framebuffer_pixel: float
var _tile_projection: Transform2D
var _floor: ColorRect
var _material: ShaderMaterial
var _elapsed: float
var reduced_motion: bool
var _tile_data: ImageTexture
var _shape: ImageTexture
var _atlas_projection: Transform2D
var _atlas_field: Image
var _insets: Dictionary = {}

static func enabled() -> bool:
	var mode: String = OS.get_environment(MODE_ENV)
	if mode == "pixel" or mode == "off":
		return mode == "pixel"
	_load_style()
	return _style.get("default_mode", "off") == "pixel"

static func _load_style() -> void:
	if _style.is_empty():
		_style = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH)) as Dictionary

static func ramp_id(kind: String) -> String:
	return "neutral" if kind == "rubble" else Pixel.surface_ramp_id(kind)

static func ramp(kind: int) -> PackedColorArray:
	return Pixel.ramp_for(ramp_id(Decals.KIND_NAMES[kind]))

func _ready() -> void:
	hide()
	set_process(false)
	get_viewport().size_changed.connect(_sync_sheet_size)

func _process(delta: float) -> void:
	set_motion_time(_elapsed + delta)

func set_motion_time(seconds: float) -> void:
	_elapsed = seconds
	_material.set_shader_parameter("motion_seconds", -1.0 if reduced_motion else _elapsed)
	if sheet.ink != null:
		sheet.set_time(_elapsed, reduced_motion)

func present_field(state: Dictionary, rendered_tiles: Array[Vector2i], tile_visible: Callable) -> void:
	if not field.rebuild(state, rendered_tiles, tile_visible):
		return
	visible = not field.tiles.is_empty()
	if not visible:
		set_process(false)
		depth.clear()
		sheet.clear()
		return
	if _floor == null:
		_create_floor()
	_tile_data = ImageTexture.create_from_image(field.image)
	_rebuild_regions()

func present_projection(origin: Vector2, tile_width: float) -> void:
	var half_width: float = tile_width * 0.5
	var half_height: float = half_width * 0.5
	_tile_projection = Transform2D(Vector2(half_width, half_height), Vector2(-half_width, half_height), origin)
	var bounds := Rect2(origin, Vector2.ZERO)
	var first: bool = true
	for tile: Vector2i in field.tiles:
		var center: Vector2 = _tile_projection * Vector2(tile)
		var half_tile := Vector2(half_width, half_height)
		var tile_bounds := Rect2(center - half_tile, half_tile * 2.0)
		bounds = tile_bounds if first else bounds.merge(tile_bounds)
		first = false
	_floor.position = bounds.position
	_floor.size = bounds.size

func sync_contacts(board: Control, study_reduced_motion: Variant = null) -> void:
	if field.tiles.is_empty() or _tile_projection.x.x <= 0.0:
		return
	reduced_motion = bool((board.get("presentation") as Dictionary).get("reduced_motion", false)) if study_reduced_motion == null else bool(study_reduced_motion)
	var animating: bool = not reduced_motion and (field.kind_mask & 0b1110) != 0
	if animating != is_processing():
		set_process(animating)
	if (field.kind_mask & 0b1010) != 0:
		sheet.setup()
		_sync_sheet_size()
	set_motion_time(_elapsed)
	var units: Array[Dictionary] = board.call("_visible_units")
	texel = _tile_projection.x.x * 2.0 / Field.HERO_TEXELS_PER_TILE
	for unit: Dictionary in units:
		if not Depth.visible_actor(board, unit):
			continue
		var center: Vector2 = board.call("_unit_center", unit)
		var body: Texture2D = board.call("_texture_for_unit", unit)
		if body != null and body.get_width() > 0 and body.get_height() > 0:
			var drawn: Rect2 = board.call("_unit_texture_draw_rect", unit, center)
			var unit_texel: Vector2 = drawn.size / body.get_size()
			texel = minf(texel, minf(unit_texel.x, unit_texel.y))
	var physical: Vector2 = (board.get_viewport().get_stretch_transform() * get_global_transform_with_canvas()).get_scale().abs()
	framebuffer_pixel = 1.0 / maxf(maxf(physical.x, physical.y), 0.00001)
	# The floor, Ice, and Rubble share the existing one-pixel lower bound.
	render_texel = maxf(texel, framebuffer_pixel)
	_sync_atlas(board)
	_material.set_shader_parameter("floor_origin", _floor.position)
	bind_region(_material)
	depth.sync(board, self, units)

func _sync_sheet_size() -> void:
	if sheet.ink == null or field.tiles.is_empty():
		return
	var viewport: Viewport = get_viewport()
	# Sample settled layout and display scaling. The shader cancels the canvas
	# basis and snaps the final screen position during camera and board travel.
	var physical: Vector2 = (viewport.get_stretch_transform() * get_global_transform()).get_scale().abs()
	sheet.sync_size(_tile_projection.x.x * 2.0, physical, roundi(Pixel.viewport_pixels(viewport).y))

func bind_region(material: ShaderMaterial) -> void:
	var inverse: Transform2D = _tile_projection.affine_inverse() if _tile_projection.determinant() != 0.0 else Transform2D.IDENTITY
	material.set_shader_parameter("tile_data", _tile_data)
	material.set_shader_parameter("tile_origin", field.area.position)
	material.set_shader_parameter("tile_size", field.area.size)
	material.set_shader_parameter("tile_at_origin", inverse.origin)
	material.set_shader_parameter("tile_per_x", inverse.x)
	material.set_shader_parameter("tile_per_y", inverse.y)
	material.set_shader_parameter("ground_origin", _tile_projection.origin)
	material.set_shader_parameter("ground_texel", render_texel)
	material.set_shader_parameter("shape_data", _shape)
	material.set_shader_parameter("edge_amplitude", EDGE_AMPLITUDE_TEXELS)
	material.set_shader_parameter("edge_lobes", EDGE_LOBES_PER_SIDE)
	material.set_shader_parameter("edge_fringe", FRINGE_TEXELS)
	material.set_shader_parameter("world_seed", hash(field.seed) & 0x7fffffff)

func edge_inset() -> float:
	return (1.0 - sqrt(PATCH_AREA)) * 0.5

func _sync_atlas(board: Control) -> void:
	var height: int = roundi(Pixel.viewport_pixels(board.get_viewport()).y)
	var grain: float = maxf(render_texel, framebuffer_pixel * Pixel.grid_px(height))
	var projection := Transform2D(_tile_projection.x / grain, _tile_projection.y / grain, Vector2.ZERO)
	if _atlas_field == field.image and _atlas_projection.is_equal_approx(projection):
		return
	_atlas_field = field.image
	_atlas_projection = projection
	var zoom: float = 1.0 if bool((board.get("presentation") as Dictionary).get("board_targeting", false)) else float(board.get("_navigation_zoom"))
	var min_zoom: float = float(board.call("navigation_snapshot")["min_zoom"])
	var placement_projection: Transform2D = projection.scaled(Vector2.ONE * min_zoom / zoom)
	decals.rebuild(field, _style, _atlases, projection, placement_projection)
	_material.set_shader_parameter("decal_data", ImageTexture.create_from_image(decals.image))
	_material.set_shader_parameter("decal_dx", projection.x)
	_material.set_shader_parameter("decal_dy", projection.y)
	_material.set_shader_parameter("atlas_texel", grain / framebuffer_pixel)

func region_inset(tile: Vector2i, kind: int) -> float:
	var insets: Color = _insets[tile]
	return insets[kind - 1]

func _create_floor() -> void:
	_load_style()
	if _atlases.is_empty():
		_atlases = Decals.load_atlases(_style)
	_floor = ColorRect.new()
	_floor.name = "SurfaceCells"
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fire_scroll_step", FIRE_SCROLL_STEP)
	_material.set_shader_parameter("electric_pulse", ELECTRIC_PULSE)
	_floor.material = _material
	add_child(_floor)
	for kind: int in Decals.DRAW_ORDER:
		var label: String = Decals.KIND_NAMES[kind]
		_material.set_shader_parameter(label + "_ramp", ramp(kind))
		if _atlases.has(kind):
			_material.set_shader_parameter(label + "_atlas", _atlases[kind]["texture"])

	_bind_ice_motion()
	_bind_still_phase()

func _bind_ice_motion() -> void:
	var ice: Dictionary = _style["ice"]
	_material.set_shader_parameter("ice_glint", Vector2(ice["rim_cycle_seconds"], ICE_GLINT_SECONDS))
	_material.set_shader_parameter("ice_sparkle_timing", Vector2(ice["sparkle_reseed_seconds"],
		float(ice["sparkle_frames"]) / float(ice["sparkle_fps"])))
	var count: Array = ice["sparkle_count_range"]
	_material.set_shader_parameter("ice_sparkle_count_range", Vector2i(count[0], count[1]))
	var ice_kind: int = Field.ELEMENT_IDS["ice"]
	if _atlases.has(ice_kind):
		_material.set_shader_parameter("ice_sparkle_texels", _atlases[ice_kind]["sparkles"])

func _bind_still_phase() -> void:
	var fire: Dictionary = _style["fire"]
	var ice: Dictionary = _style["ice"]
	var electric: Dictionary = _style["electrified"]
	var fps := Vector3i(fire["cycle_fps"], ice["fps"], electric["fps"])
	_material.set_shader_parameter("animation_fps", fps)
	_material.set_shader_parameter("steps", Vector3i((Vector3(fps) * ATLAS_STILL_SECONDS).floor()))
	_material.set_shader_parameter("fire_cycle_span", int(fire["cycle_span"]))
	var interval: Array = electric["strike_interval_range"]
	_material.set_shader_parameter("electrified_strike_interval_range", Vector2(interval[0], interval[1]))
	_material.set_shader_parameter("electrified_strike_frames", Vector3i(electric["crawl_frames"], electric["flash_frames"], electric["fade_frames"]))
	_material.set_shader_parameter("electrified_sector_count", int(electric["sector_count"]))
	_material.set_shader_parameter("electrified_sector_chance", float(electric["sector_chance"]))
	_material.set_shader_parameter("electrified_rest_core_step", floori(ATLAS_STILL_SECONDS * float(electric["rest_core_pulse_fps"])) & 1)

func _rebuild_regions() -> void:
	var shape := Image.create_empty(field.area.size.x, field.area.size.y, false, Image.FORMAT_RGBAF)
	_insets.clear()
	for kind: int in Decals.DRAW_ORDER:
		var visited: Dictionary = {}
		for tile: Vector2i in field.tiles:
			if visited.has(tile) or not Field.tile_kind(field.tiles[tile], kind):
				continue
			var region: Array[Vector2i]
			region.append(tile)
			visited[tile] = true
			var perimeter: int = 0
			var cursor: int = 0
			while cursor < region.size():
				var here: Vector2i = region[cursor]
				cursor += 1
				for direction: int in 4:
					var neighbor: Vector2i = here + Field.NEIGHBORS[direction]
					if not Field.tile_kind(field.tiles.get(neighbor, 0), kind):
						perimeter += 1
					elif not visited.has(neighbor):
						visited[neighbor] = true
						region.append(neighbor)
			var inset: float = minf(edge_inset() * 4.0 * region.size() / perimeter, 0.25)
			for here: Vector2i in region:
				var insets: Color = _insets.get(here, Color.TRANSPARENT)
				insets[kind - 1] = inset
				_insets[here] = insets
	for tile: Vector2i in _insets:
		shape.set_pixelv(tile - field.area.position, _insets[tile])
	_shape = ImageTexture.create_from_image(shape)
