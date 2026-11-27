extends Node2D

const TeamOutlines = preload("res://scripts/board_unit_team_outlines.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Outline = preload("res://scripts/board_occlusion_silhouettes.gdshader")
const Reveal = preload("res://scripts/board_occlusion_reveal.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const UNIT_ON: float = 0.30
const UNIT_OFF: float = 0.22
const FADE_SECONDS: float = 0.15
const WIDTH: float = 2.0
const UNIT_ALPHA: float = 0.85
const UNIT_FILL_ALPHA: float = 0.75 # On-cell alpha of the dither.
const CONTENT_SHOW_ALPHA: float = 0.75
const OBJECT_ALPHA: float = 0.70
# The production shaders still compute the original texture and palette
# colours. Their content variants apply this last, in board-local coordinates.
const CONTENT_MASK_CODE = """
uniform sampler2DArray hidden_mask : filter_nearest, repeat_disable;
uniform sampler2D content_factors : filter_nearest, repeat_disable;
uniform vec2 hidden_origin;
uniform vec2 content_offset;
uniform vec4 grid;
uniform float content_alpha;
uniform int hidden_layers;
uniform int floor_layers;
uniform int content_subject = -1;
uniform bool grid_probe = false;
varying vec2 content_point;

bool content_grid_on() {
	vec2 cell = floor((content_point - grid.xy) / grid.zw);
	return mod(cell.x + cell.y, 2.0) == 0.0;
}

float content_cover() {
	ivec2 pixel = ivec2(floor(content_point - hidden_origin));
	ivec2 size = textureSize(hidden_mask, 0).xy;
	if (any(lessThan(pixel, ivec2(0))) || any(greaterThanEqual(pixel, size))) return 0.0;
	float cover = 0.0;
	for (int subject = hidden_layers - 1; subject >= 0; subject--) {
		int blocker = int(texelFetch(hidden_mask, ivec3(pixel, subject), 0).r);
		if (blocker == 0) continue;
		if (grid_probe) return 1.0;
		float fade = texelFetch(content_factors, ivec2(subject, 0), 0).r;
		float reveal = texelFetch(content_factors, ivec2(blocker - 1, 1), 0).r;
		if (fade <= 0.0 || reveal <= 0.0) continue;
		// The frontmost opaque pickup uses the whole checker slot. Painting
		// the floor under it would apply the slot opacity twice.
		if (subject >= floor_layers) return subject == content_subject ? fade * reveal : 0.0;
		if (content_subject < 0) cover = max(cover, fade * reveal);
	}
	return cover;
}

"""
const CONTENT_VERTEX := "content_point = VERTEX + content_offset;"
const CONTENT_FRAGMENT_START := """
	bool content_on_cell = content_grid_on();
	if (!content_on_cell && !grid_probe) discard;
	float content_strength = content_cover();
	if (content_strength <= 0.0) discard;
	if (grid_probe) {
		COLOR = vec4(content_on_cell ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), 0.5);
	} else {
"""
const CONTENT_FRAGMENT_END := """
		if (content_subject >= 0 && COLOR.a < 0.5) discard;
		COLOR.a *= content_alpha * content_strength;
	}
"""
const CONTENT_PAINTER := "content_show_through"
const CONTENT_FLOOR := "content_show_through_floor"
const CONTENT_OBJECT := "content_show_through_object"
const CONTENT_FLOOR_FIELDS := ["_tile_textures", "_floor_texture_variants", "_biome_id",
	"_biome_light_color", "_pillar_torch_light_texture", "_grid_tile_ids_cache",
	"_floor_variant_by_tile", "_moss_tiles_by_surface", "_element_overlay_texture_variants", "_submission_cache_valid"]
const CONTENT_PAINT_FIELDS := ["_objective_exit_tiles_lookup_cache", "exit_tiles"]
const PixelField = preload("res://scripts/board_pixel_surface_field.gd")


class ContentStamp extends Node2D:
	var bounds: Rect2

	func set_bounds(value: Rect2) -> void:
		if bounds == value: return
		bounds = value
		queue_redraw()

	func _draw() -> void:
		draw_rect(bounds, Color.WHITE)

var team := TeamOutlines.new()
var _unit_alpha_overrides: Dictionary = {}
var alpha_masks := Alpha.new()
var _pose_sets: Array = []
var _mask_room: Variant
var board: Control
var entries: Dictionary = {}
var coverage_dirty: bool = true
var pose_tiles: Dictionary = {}
var ground_dirty: bool = false
var coverage_builds: int = 0
var pose_updates: int = 0
var tool_enabled: bool = true
# Painter-order rest-mask sources, shared with the occ-02 focus reveal.
var latest_sources: Array[Dictionary]
var sources_revision: int = 0
var _sources_stale: bool = true
var _fill_atlas: ImageTexture
var _fill_regions: Dictionary = {}
var _fill_signature: Array
var _fill_room: Variant
var _content_shaders: Dictionary = {}
var _content_tiles: Dictionary = {}
var _content_order: Array[Vector2i]
var content_show_through_enabled: bool = true:
	set(value):
		content_show_through_enabled = value
		for tile: Vector2i in _content_tiles:
			var screen: Dictionary = _content_tiles[tile]
			if not is_instance_valid(screen.get("painter")): continue
			screen["painter"].visible = value and board._board_tile_is_visible_to_player(tile)
			if value: _queue_content_tile(screen)
		if value and _content_pixels_animating(): set_process(true)
var _content_entries: Dictionary = {}
var _content_fading: bool = false
var _rims_fading: bool = false

func attach(owner_board: Control) -> void:
	board = owner_board
	name = "OcclusionSilhouettes"
	owner_board.add_child(self)
	team.attach(owner_board, self)
	invalidate()

func _ready() -> void:
	get_viewport().size_changed.connect(invalidate)

func invalidate() -> void:
	coverage_dirty = true
	_sources_changed()
	set_process(tool_enabled)

func _sources_changed() -> void:
	_sources_stale = true
	var reveal: Node = board.get("_occlusion_reveal") if is_instance_valid(board) else null
	if is_instance_valid(reveal): reveal.invalidate()

# The current sources without a rebuild when nothing invalidated them.
func current_sources() -> Array[Dictionary]:
	if _sources_stale: _collect_sources()
	return latest_sources

func _collect_sources() -> Array[Dictionary]:
	var room: Variant = (board.get("combat_state") as Dictionary).get("room_coord")
	if _mask_room != room:
		alpha_masks = Alpha.new()
		_mask_room = room
	latest_sources = Sources.collect(board)
	alpha_masks.prepare(latest_sources)
	_sources_stale = false
	sources_revision += 1
	return latest_sources

func submission_changed(structural: bool, changes: Dictionary, registrations: Dictionary) -> void:
	if not tool_enabled:
		coverage_dirty = true
		_sources_changed()
		return
	team.sync()
	_order_content_tiles()
	if structural or changes.has("umbra_visible_tiles") or changes.has("umbra_stage"):
		for tile: Vector2i in _content_order:
			var painter: Variant = _content_tiles.get(tile, {}).get("painter")
			if is_instance_valid(painter) and not board._board_tile_is_visible_to_player(tile): painter.hide()
	if changes.has("unit_outline_alpha_multipliers"):
		for key: String in entries: _refresh_ink(entries[key])
		for key: String in team.entries: team.refresh_alpha(key)
	if structural or not registrations.is_empty():
		invalidate()
		return
	for key: String in ["surface_feedback_events", "throw_surface_frames", "combat_feel_surface_frames", "surface_feedback_progress", "unit_world_positions", "unit_footprint_world_positions", "unit_draw_tiles", "unit_texture_origins",
		"visible_enemy_ids", "umbra_visible_tiles", "umbra_stage", "umbra_action_actor_clips", "scene_props", "death_animation_units", "missed_equipment_ids", "equipped_equipment", "static_enemy_facings", "death_site_embers", "objective_exit_target_tiles", "threats_at_rest", "floor_threats_at_rest", "reduced_motion"]:
		if changes.has(key):
			invalidate()
			return
	# Motion phase is intentionally absent: only a clip/facing set transition
	# invalidates occupancy. The retained shader follows intervening live poses.
	for key: String in changes:
		if key.ends_with("_motion"):
			var next_sets: Array = Sources.pose_set_signature(board)
			if next_sets != _pose_sets: invalidate()
			break

func invalidate_pose(tile: Vector2i, ground: bool = false) -> void:
	if not ground: team.refresh_tile(tile)
	if not tool_enabled or entries.is_empty(): return
	pose_tiles[tile] = true
	ground_dirty = ground_dirty or ground
	set_process(true)

# Tool-only comparison switch. It neither changes saves nor the normal art pass.
func set_tool_enabled(enabled: bool) -> void:
	tool_enabled = enabled
	visible = enabled
	team.set_enabled(enabled)
	for key: String in team.entries: team.refresh_alpha(key)
	if enabled: invalidate()
	else:
		_clear_content()
		set_process(false)

static func switched_on(coverage: float, was_on: bool, _unit: bool) -> bool:
	return coverage >= (UNIT_OFF if was_on else UNIT_ON)

static func team_color(entry: Dictionary) -> Color:
	if str(entry["kind"]) != "unit": return Color(Palette.TEXT, OBJECT_ALPHA)
	return Color(Palette.DANGER if str((entry["data"] as Dictionary).get("role", "")) == "enemy" else Palette.ALLY, UNIT_ALPHA)


func sync_coverage() -> void:
	coverage_dirty = false
	coverage_builds += 1
	var sources: Array[Dictionary] = _collect_sources()
	_pose_sets = Sources.pose_set_signature(board)
	team.sync()
	var masks: Array[Dictionary] = _fill_sources(sources)
	var fill_grid: Vector4 = _board_fill_grid()
	_sync_content(sources, masks, fill_grid)
	var retained: Dictionary = {}
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		if not bool(source["eligible"]): continue
		var key: String = source["key"]
		var kind: String = source["kind"]
		if kind not in ["unit", "loot", "trap"]: continue
		var unit: bool = kind == "unit"
		var amount: float = alpha_masks.coverage_for(sources, index)
		var previous: Dictionary = entries.get(key, {})
		var on: bool = switched_on(amount, bool(previous.get("on", false)), unit)
		if not on and previous.is_empty(): continue
		var entry: Dictionary = previous
		if entry.is_empty():
			var sprite := Sprite2D.new()
			var ink := ShaderMaterial.new()
			ink.shader = Outline
			sprite.material = ink
			sprite.self_modulate.a = 0.0
			add_child(sprite)
			entry = {"sprite": sprite, "alpha": 0.0}
		entry.merge({"source": source, "coverage": amount, "on": on}, true)
		if not unit: entry["rim_blockers"] = _later_rim_blockers(sources, index)
		if unit:
			var blockers: Array[Dictionary] = _fill_blockers(source, index, masks)
			entry["fill_blockers"] = blockers
			if not blockers.is_empty():
				var ink: ShaderMaterial = (entry["sprite"] as Sprite2D).material
				ink.set_shader_parameter("fill_grid", fill_grid)
			_update_fill(entry)
		_update_pose(entry)
		retained[key] = entry
	for key: String in entries:
		# Privacy/death/removal is immediate, even partway through a fade.
		if not retained.has(key):
			(entries[key]["sprite"] as Sprite2D).visible = false
			(entries[key]["sprite"] as Sprite2D).queue_free()
	entries = retained
	_rims_fading = not entries.is_empty()
	for key: String in team.entries: team.refresh_alpha(key)

func _board_fill_grid() -> Vector4:
	var viewport: Viewport = board.get_viewport()
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var board_scale: Vector2 = board.get_global_transform().get_scale().abs() * stretch
	var render_height: int = roundi(viewport.get_visible_rect().size.y * stretch.y)
	# The FX-13 Block shield uses the same pixel-sheet fit as tile bursts.
	var fit: Vector2i = preload("res://scripts/tile_burst_fx.gd").choice_for(board._tile_width() * board_scale.x, render_height)
	var cell: Vector2 = Vector2.ONE * float(fit.x) / board_scale
	var origin: Vector2 = board._board_origin()
	return Vector4(origin.x, origin.y, cell.x, cell.y)

# A later unit can trigger the rim but never contributes fill pixels. The
# masks list comes from _fill_sources and contains standing objects only.
func _fill_blockers(source: Dictionary, index: int, masks: Array[Dictionary]) -> Array[Dictionary]:
	var blockers: Array[Dictionary]
	if str((source["data"] as Dictionary).get("role", "")) == "illusion": return blockers
	var reach: Rect2 = source["rect"]
	var drawing: Dictionary = Sources.drawing(board, source)
	if not drawing.is_empty(): reach = reach.merge(drawing["rect"])
	for mask: Dictionary in masks:
		if int(mask["index"]) > index and reach.intersects(mask["rect"]): blockers.append(mask)
	return blockers

# Build a shared atlas from the actual prop art when its geometry changes.
# Each rim binds only its later, intersecting objects. Idle pose updates keep
# their existing live alpha source and never rebuild or scan the prop masks.
func _fill_sources(sources: Array[Dictionary]) -> Array[Dictionary]:
	var masks: Array[Dictionary]
	var assets: Dictionary = {}
	var grid: Array = (board.get("combat_state") as Dictionary).get("grid", [])
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		if source["kind"] not in ["prop", "terrain"]: continue
		var tile: Vector2i = source["tile"]
		var mask: Dictionary = {"index": index, "tile": tile, "kind": source["kind"],
			"category": Reveal.category_for(source), "rect": source["rect"], "min_alpha": 0.0}
		var texture: Texture2D = source.get("mask_texture")
		var region: Rect2i = source.get("mask_region", Rect2i())
		var key: Variant
		var terrain: Dictionary = source.get("data", {})
		var kind: String = terrain.get("kind", "")
		if kind in ["crag_outcrop", "dragon_spire"]:
			var rise: float = board._procedural_terrain_rise(terrain)
			var width: float = board._tile_width()
			key = [kind, tile, width, rise]
			assets[key] = {"kind": kind, "tile": tile, "width": width, "rise": rise}
			mask["min_alpha"] = board.PROCEDURAL_TERRAIN_REVEAL_FLOOR
			mask["origin"] = board._tile_center(tile)
		else:
			var door: Dictionary = Sources.opening_door_mask(board, grid, source)
			if not door.is_empty():
				mask["rect"] = door["rect"]
				mask["coverage_override"] = alpha_masks.mask_for(door)
				texture = door["mask_texture"]
				region = Rect2i()
			if texture == null: continue
			key = [texture, region]
			assets[key] = {"texture": texture, "region": region}
		mask["key"] = key
		masks.append(mask)
	var signature: Array = assets.keys()
	if _fill_room != _mask_room or signature != _fill_signature:
		_fill_room = _mask_room
		_fill_signature = signature
		_build_fill_atlas(assets)
	var drawable: Array[Dictionary]
	for mask: Dictionary in masks:
		var asset: Dictionary = _fill_regions.get(mask["key"], {})
		if asset.is_empty(): continue
		mask["region"] = asset["region"]
		mask["kind"] = sources[mask["index"]]["kind"]
		mask["coverage_source"] = sources[mask["index"]]
		if mask.has("origin"):
			var bounds: Rect2 = asset["bounds"]
			bounds.position += Vector2(mask["origin"])
			mask["rect"] = bounds
		var actual: Dictionary = mask["coverage_source"].duplicate(false)
		actual["rect"] = mask["rect"]
		if asset.has("coverage") or mask.has("coverage_override"):
			actual["mask"] = asset.get("coverage", mask.get("coverage_override", {}))
		mask["coverage_source"] = actual
		drawable.append(mask)
	return drawable

func _build_fill_atlas(assets: Dictionary) -> void:
	_fill_regions.clear()
	_fill_atlas = null
	var images: Dictionary = {}
	for key: Variant in assets:
		var asset: Dictionary = assets[key]
		var image: Image
		if asset.has("kind"):
			var shape: Dictionary = _procedural_mask(asset)
			if shape.is_empty(): continue
			image = shape["image"]
			_fill_regions[key] = {"bounds": shape["bounds"], "coverage": alpha_masks.mask_from_image(image, str(key))}
		else:
			image = Assets.texture_source_image(asset["texture"])
			if image == null or image.is_empty(): continue
			image = image.duplicate() as Image
			if image.is_compressed() and image.decompress() != OK: continue
			if (asset["region"] as Rect2i).has_area(): image = image.get_region(asset["region"])
			image.convert(Image.FORMAT_RGBA8)
		images[key] = image
	if images.is_empty(): return
	var packed: Dictionary = _pack_atlas(images)
	_fill_atlas = packed["texture"]
	for key: Variant in packed["regions"]:
		var asset: Dictionary = _fill_regions.get(key, {})
		asset["region"] = packed["regions"][key]
		_fill_regions[key] = asset

func _procedural_mask(asset: Dictionary) -> Dictionary:
	return Sources.procedural_mask(board, asset)

static func _pack_atlas(images: Dictionary) -> Dictionary:
	var area: int = 0
	var widest: int = 0
	for image: Image in images.values():
		var padded: Vector2i = image.get_size() + Vector2i(2, 2)
		area += padded.x * padded.y
		widest = maxi(widest, padded.x)
	# A clear texel between images keeps their edges independent under filtering.
	var width: int = maxi(widest, ceili(sqrt(float(area))))
	var cursor := Vector2i.ONE
	var row_height: int = 0
	var regions: Dictionary = {}
	for key: Variant in images:
		var size: Vector2i = images[key].get_size()
		if cursor.x + size.x >= width and row_height > 0:
			cursor = Vector2i(1, cursor.y + row_height)
			row_height = 0
		regions[key] = Rect2i(cursor, size)
		cursor.x += size.x + 2
		row_height = maxi(row_height, size.y + 2)
	var atlas := Image.create_empty(width, cursor.y + row_height - 1, false, Image.FORMAT_RGBA8)
	for key: Variant in images:
		var region: Rect2i = regions[key]
		atlas.blit_rect(images[key], Rect2i(Vector2i.ZERO, region.size), region.position)
	return {"texture": ImageTexture.create_from_image(atlas), "regions": regions}

func _later_rim_blockers(sources: Array[Dictionary], index: int) -> Array[Dictionary]:
	var blockers: Array[Dictionary]
	var reach: Rect2 = (sources[index]["rect"] as Rect2).grow(WIDTH * 2.0 * float(board.get("_navigation_zoom")))
	for later: int in range(index + 1, sources.size()):
		var source: Dictionary = sources[later]
		if source["kind"] in ["unit", "prop", "terrain"] and reach.intersects(source["rect"]):
			blockers.append(source)
	return blockers

func _blocker_alpha(blocker: Dictionary) -> float:
	var reveal: Node = board.get("_occlusion_reveal")
	var category: String = blocker.get("category", Reveal.category_for(blocker))
	if not is_instance_valid(reveal) or category.is_empty(): return 1.0
	if category == "unit": return reveal.unit_alpha(str(blocker["key"]))
	return reveal.prop_alpha(category, blocker["tile"])

func _update_fill(entry: Dictionary) -> void:
	var ink: ShaderMaterial = (entry["sprite"] as Sprite2D).material
	var blockers: Array = entry["fill_blockers"]
	var source: Dictionary = entry["source"]
	var opacity: float = UNIT_FILL_ALPHA * unit_alpha_multiplier(str(source["key"])) if not blockers.is_empty() else 0.0
	ink.set_shader_parameter("fill_alpha", opacity)
	ink.set_shader_parameter("fill_count", blockers.size())
	if blockers.is_empty(): return
	var reveal: Node = board.get("_occlusion_reveal")
	var alphas := PackedFloat32Array()
	for blocker: Dictionary in blockers:
		var alpha: float = reveal.prop_alpha(blocker["category"], blocker["tile"]) if is_instance_valid(reveal) else 1.0
		alphas.append(maxf(alpha, blocker["min_alpha"]))
	var signature: Array = [_fill_atlas, blockers, alphas]
	if entry.get("fill_signature", []) == signature: return
	entry["fill_signature"] = signature
	var data := Image.create_empty(3, blockers.size(), false, Image.FORMAT_RGBAF)
	for row: int in range(blockers.size()):
		var rect: Rect2 = blockers[row]["rect"]
		var region: Rect2 = Rect2(blockers[row]["region"])
		data.set_pixel(0, row, Color(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		data.set_pixel(1, row, Color(region.position.x, region.position.y, region.size.x, region.size.y))
		data.set_pixel(2, row, Color(alphas[row], 0.0, 0.0, 0.0))
	ink.set_shader_parameter("fill_atlas", _fill_atlas)
	ink.set_shader_parameter("fill_objects", ImageTexture.create_from_image(data))
	ink.set_shader_parameter("fill_opaque_threshold", Alpha.OPAQUE_ALPHA)

func _update_pose(entry: Dictionary) -> void:
	var draw: Dictionary = Sources.drawing(board, entry["source"])
	if draw.is_empty(): return
	var sprite: Sprite2D = entry["sprite"]
	var color: Color = rim_color(entry["source"])
	if entry.has("rim_blockers"):
		var opacity: float = 0.0
		for blocker: Dictionary in entry["rim_blockers"]: opacity = maxf(opacity, _blocker_alpha(blocker))
		color.a *= opacity
	var signature: Array = [draw["texture"], draw["rect"], board.get("_navigation_zoom"), color]
	if signature == entry.get("pose_signature", []): return
	entry["pose_signature"] = signature
	var texture: Texture2D = draw["texture"]
	var rect: Rect2 = draw["rect"]
	sprite.texture = texture
	sprite.position = rect.get_center()
	sprite.scale = rect.size / Vector2(texture.get_size())
	var ink: ShaderMaterial = sprite.material
	ink.set_shader_parameter("silhouette_texture", (texture as AtlasTexture).atlas if texture is AtlasTexture else texture)
	ink.set_shader_parameter("rim_color", color)
	configure_rim(ink, texture, rect)
	ink.set_shader_parameter("object_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	pose_updates += 1

static func uv_region(texture: Texture2D) -> Rect2:
	if not texture is AtlasTexture: return Rect2(Vector2.ZERO, Vector2.ONE)
	var atlas: AtlasTexture = texture
	return Rect2(atlas.region.position / Vector2(atlas.atlas.get_size()), atlas.region.size / Vector2(atlas.atlas.get_size()))

func configure_rim(ink: ShaderMaterial, texture: Texture2D, rect: Rect2) -> void:
	ink.set_shader_parameter("silhouette_texture", (texture as AtlasTexture).atlas if texture is AtlasTexture else texture)
	var region: Rect2 = uv_region(texture)
	ink.set_shader_parameter("radius_source", Vector2(texture.get_size()) * WIDTH * float(board.get("_navigation_zoom")) / rect.size)
	ink.set_shader_parameter("mask_min", region.position)
	ink.set_shader_parameter("mask_max", region.end)
	ink.set_shader_parameter("radius_uv", region.size * WIDTH * float(board.get("_navigation_zoom")) / rect.size)

func xray_opacity(key: String) -> float:
	if not tool_enabled or not entries.has(key): return 0.0
	return float(entries[key]["alpha"]) * UNIT_ALPHA * unit_alpha_multiplier(key)

# Rims follow the supplied hook value and the unit's occ-02 reveal alpha.
func unit_alpha_multiplier(key: String) -> float:
	return supplied_alpha_multiplier(key) * reveal_alpha(key)

func supplied_alpha_multiplier(key: String) -> float:
	var supplied: Dictionary = (board.get("presentation") as Dictionary).get("unit_outline_alpha_multipliers", {})
	return clampf(float(_unit_alpha_overrides.get(key, supplied.get(key, 1.0))), 0.0, 1.0)

func reveal_alpha(key: String) -> float:
	var reveal: Node = board.get("_occlusion_reveal")
	return float(reveal.unit_alpha(key)) if is_instance_valid(reveal) else 1.0

# A focus-reveal fade step: rims, rim cut-outs and team rims follow it.
func reveal_changed() -> void:
	for entry: Dictionary in entries.values(): _refresh_ink(entry)
	_update_content_reveal()
	for key: String in team.entries: team.refresh_alpha(key)

func set_unit_alpha_multiplier(key: String, value: float) -> void:
	_unit_alpha_overrides[key] = clampf(value, 0.0, 1.0)
	for entry: Dictionary in entries.values(): _refresh_ink(entry)
	team.refresh_alpha(key)

func _refresh_ink(entry: Dictionary) -> void:
	if entry.has("fill_blockers"): _update_fill(entry)
	_update_pose(entry)

func rim_color(source: Dictionary) -> Color:
	var result: Color = team_color(source)
	if str(source["kind"]) == "unit": result.a *= unit_alpha_multiplier(str(source["key"]))
	else:
		# An object's rim fades with the object when the focus reveal fades it.
		var reveal: Node = board.get("_occlusion_reveal")
		var category: String = Reveal.category_for(source)
		if is_instance_valid(reveal) and not category.is_empty(): result.a *= float(reveal.prop_alpha(category, source["tile"]))
	return result

func _process(delta: float) -> void:
	if not tool_enabled: return
	var instrumented: bool = bool(board.get("_submission_performance_instrumentation_enabled"))
	var started: int = Time.get_ticks_usec() if instrumented else 0
	if coverage_dirty: sync_coverage()
	if _content_fading: _content_fading = _fade_content(delta)
	var animated_pixels: bool = _content_pixels_animating()
	if animated_pixels: _advance_content_pixels()
	if _rims_fading or not pose_tiles.is_empty() or ground_dirty:
		_rims_fading = _advance_rims(delta)
	set_process(_rims_fading or _content_fading or coverage_dirty or animated_pixels)
	if instrumented: board.call("_record_render_frame_section", Engine.get_process_frames(), "occlusion_silhouettes", Time.get_ticks_usec() - started)

func _advance_rims(delta: float) -> bool:
	var fading: bool = false
	var finished: Array[String]
	for key: String in entries:
		var entry: Dictionary = entries[key]
		var source: Dictionary = entry["source"]
		if pose_tiles.has(source["tile"]) or (ground_dirty and bool(source.get("ground", false))): _update_pose(entry)
		var target: float = 1.0 if bool(entry["on"]) else 0.0
		var alpha: float = move_toward(float(entry["alpha"]), target, delta / FADE_SECONDS)
		entry["alpha"] = alpha
		(entry["sprite"] as Sprite2D).self_modulate.a = alpha
		fading = fading or alpha != target
		if alpha == 0.0 and not bool(entry["on"]): finished.append(key)
	for key: String in finished:
		(entries[key]["sprite"] as Sprite2D).queue_free()
		entries.erase(key)
	for key: String in team.entries: team.refresh_alpha(key)
	pose_tiles.clear()
	ground_dirty = false
	return fading

# Static checker and pale rim have separate gates: a character counts toward
# the rim, while only standing props can activate the checker.
func _sync_content(sources: Array[Dictionary], masks: Array[Dictionary], grid: Vector4) -> void:
	var wanted: Dictionary = {}
	var tiles: Dictionary = {}
	_content_fading = false
	for index: int in sources.size():
		var source: Dictionary = sources[index]
		if not bool(source.get("fill", false)): continue
		var key: String = source["key"]
		var prior: Dictionary = _content_entries.get(key, {})
		var blockers: Array[Dictionary] = _fill_blockers(source, index, masks)
		if blockers.is_empty(): continue
		var silhouettes: Array[Dictionary]
		for blocker: Dictionary in blockers: silhouettes.append(blocker["coverage_source"])
		var protected: Array[Dictionary]
		for later: int in range(index + 1, sources.size()):
			var foreground: Dictionary = sources[later]
			if not (source["rect"] as Rect2).intersects(foreground["rect"]): continue
			if foreground["kind"] == "unit":
				if source["kind"] in ["trap", "loot"]: silhouettes.append(foreground)
				protected.append(foreground)
			elif foreground["kind"] == "loot" and not bool(foreground.get("ground", false)):
				# The blocker's own floating gear may share its draw canvas.
				protected.append(foreground)
		var coverage: float = alpha_masks.coverage_cached(source, silhouettes, key + ":content")
		var on: bool = switched_on(coverage, prior.get("on", false), false)
		if (not on and prior.is_empty()) or source.get("mask", {}).is_empty(): continue
		var opacity: float = prior.get("alpha", 0.0)
		var entry := {"source": source, "fill_geometry": alpha_masks.fill_geometry(source),
			"blockers": blockers, "protected": protected, "on": on, "alpha": opacity, "coverage": coverage}
		_content_fading = _content_fading or opacity != float(on)
		wanted[key] = entry
		var tile: Vector2i = source["tile"]
		if not tiles.has(tile): tiles[tile] = []
		tiles[tile].append(entry)
	_content_entries = wanted

	for tile: Vector2i in tiles:
		var screen: Dictionary = _content_tiles.get(tile, {})
		if screen.is_empty() or not is_instance_valid(screen["painter"]):
			screen = {}
			_content_tiles[tile] = screen
		var subjects: Array = tiles[tile]
		var floors: Array = subjects.filter(func(entry: Dictionary) -> bool: return entry["source"].has("diamond"))
		var objects: Array = subjects.filter(func(entry: Dictionary) -> bool: return not entry["source"].has("diamond"))
		screen["subjects"] = floors + objects
		screen["floor_count"] = floors.size()
		_sync_hidden_mask(screen)
		var layer: Control = board.get("_scene_render_layers_by_tile").get(screen.get("last_tile"))
		if not is_instance_valid(layer):
			_retire_content_tile(tile)
			continue
		if not screen.has("painter"):
			_create_content_tile(tile, layer, screen)
		elif screen["painter"].get_parent() != layer:
			screen["painter"].reparent(layer, false)
		screen["grid"] = grid
		_bind_content_factors(screen)
		_configure_content_painter(tile, screen)
	for tile: Vector2i in _content_tiles.keys():
		if not tiles.has(tile): _retire_content_tile(tile)
	_content_order.clear()
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		if _content_tiles.has(tile): _content_order.append(tile)
	_order_content_tiles()

func _sync_hidden_mask(screen: Dictionary) -> void:
	var signature: Array = []
	var blockers: Dictionary = {}
	var bounds := Rect2()
	var subjects: Array = screen["subjects"]
	for entry: Dictionary in subjects:
		var source: Dictionary = entry["fill_geometry"]
		var subject_geometry: Array = Alpha._geometry(source)
		for blocker: Dictionary in entry["blockers"]:
			blockers[blocker["index"]] = blocker
			var overlap: Rect2 = source["rect"].intersection(blocker["rect"])
			if overlap.has_area(): bounds = bounds.merge(overlap) if bounds.has_area() else overlap
			subject_geometry.append([blocker["index"], Alpha._geometry(blocker["coverage_source"])])
		for item: Dictionary in entry["protected"]: subject_geometry.append(Alpha._geometry(item))
		signature.append(subject_geometry)
	screen["blockers"] = blockers.values()
	if screen.get("signature") == signature: return
	screen["signature"] = signature
	screen.erase("last_tile")
	if not bounds.has_area(): return
	var origin := Vector2i(bounds.position.floor())
	var size := Vector2i(bounds.end.ceil()) - origin
	var indices: Dictionary = {}
	for index: int in blockers: indices[index] = indices.size() + 1
	var planes: Array[Image]
	var last_index: int = -1
	for entry: Dictionary in subjects:
		var pixels := PackedFloat32Array()
		pixels.resize(size.x * size.y)
		var source: Dictionary = entry["fill_geometry"]
		var front_to_back: Array = entry["blockers"].duplicate()
		front_to_back.reverse()
		for blocker: Dictionary in front_to_back:
			var overlap: Rect2 = source["rect"].intersection(blocker["rect"])
			if not overlap.has_area(): continue
			var start := Vector2i(overlap.position.floor()) - origin
			var end := Vector2i(overlap.end.ceil()) - origin
			var coverage: Dictionary = blocker["coverage_source"]
			var row: float = indices[blocker["index"]]
			for y: int in range(start.y, end.y):
				for x: int in range(start.x, end.x):
					var offset: int = y * size.x + x
					if pixels[offset] != 0.0: continue
					var point := Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5)
					if not Alpha.fill_contains(source, point) or not Alpha.opaque_at(coverage, point): continue
					if _content_protected_at(entry["protected"], point): continue
					pixels[offset] = row
					if int(blocker["index"]) > last_index:
						last_index = blocker["index"]
						screen["last_tile"] = blocker["tile"]
		planes.append(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, pixels.to_byte_array()))
	if last_index < 0: return
	var mask := Texture2DArray.new()
	if mask.create_from_images(planes) != OK:
		screen.erase("signature")
		screen.erase("last_tile")
		return
	screen["mask"] = mask
	screen["bounds"] = Rect2(Vector2(origin), Vector2(size))

static func _content_protected_at(protected: Array, point: Vector2) -> bool:
	for item: Dictionary in protected:
		if Alpha.opaque_at(item, point): return true
	return false

func _create_content_tile(tile: Vector2i, layer: Control, screen: Dictionary) -> void:
	var painter: Control = _content_painter(layer, tile, CONTENT_PAINTER, "ContentShowThrough_%d_%d" % [tile.x, tile.y])
	var floor_painter: Control = _content_painter(painter, tile, CONTENT_FLOOR, "Floor")
	floor_painter.show_behind_parent = true
	var art: ShaderMaterial = board.get("_art_treatment").material
	screen["painter"] = painter
	screen["floor"] = floor_painter
	screen["ink"] = _content_material(art)
	screen["floor_ink"] = _content_material(board.get("_art_treatment").cache_bake_material)
	screen["pixel_items"] = {}
	screen["object_items"] = {}
	painter.material = screen["ink"]
	floor_painter.material = screen["floor_ink"]
	painter.visible = content_show_through_enabled

func _content_painter(parent: Control, tile: Vector2i, kind: String, label: String) -> Control:
	var child: Control = board.get_script().new()
	child.name = label
	child.set("_is_dynamic_render_layer", true)
	child.set("_render_instrumentation_owner", board)
	child.set("_render_layer_kind", kind)
	child.set("_render_layer_tile", tile)
	child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	child.focus_mode = Control.FOCUS_NONE
	parent.add_child(child)
	return child

# Preserve each production shader's colour calculation. The sheet is the
# only vertex stage that moves its quad, so the appended assignment sees
# its snapped local geometry as well as the stamp's board-local origin.
func _content_material(source: ShaderMaterial) -> ShaderMaterial:
	var shader: Shader = _content_shaders.get(source.shader)
	if shader == null:
		var code: String = source.shader.code
		code = code.replace("void vertex() {", CONTENT_MASK_CODE + "\nvoid vertex() {")
		var vertex_end: int = code.find("\n}", code.find("void vertex() {")) + 1
		code = code.insert(vertex_end, "\t" + CONTENT_VERTEX + "\n")
		if source.shader == preload("res://shaders/ground_surface_field.gdshader"):
			code = code.replace("bool rubble = (flags & RUBBLE) != 0 && patch_visible(point, tile, RUBBLE, int(record.b), outline_cell);", "bool rubble = false;")
		code = code.replace("void fragment() {", "void fragment() {" + CONTENT_FRAGMENT_START)
		code = code.insert(code.rfind("}"), CONTENT_FRAGMENT_END)
		shader = Shader.new()
		shader.code = code
		_content_shaders[source.shader] = shader
	var ink := ShaderMaterial.new()
	ink.shader = shader
	return ink

static func _copy_ink(source: ShaderMaterial, destination: ShaderMaterial) -> void:
	for uniform: Dictionary in source.shader.get_shader_uniform_list():
		var name: String = uniform["name"]
		destination.set_shader_parameter(name, source.get_shader_parameter(name))

func _order_content_tiles() -> void:
	# Children draw after the scene tile's prop commands, before its body
	# children, and before the next scene/effect slot. Preserve source order
	# when several tiles redraw in the same slot.
	var next_slot: Dictionary = {}
	for tile: Vector2i in _content_order:
		var painter: Variant = _content_tiles.get(tile, {}).get("painter")
		if not is_instance_valid(painter) or painter.get_parent() == null: continue
		var layer: Node = painter.get_parent()
		var index: int = next_slot.get(layer, 0)
		if painter.get_index() != index: layer.move_child(painter, index)
		next_slot[layer] = index + 1

func _bind_content_mask(screen: Dictionary, ink: ShaderMaterial) -> void:
	ink.set_shader_parameter("hidden_mask", screen["mask"])
	ink.set_shader_parameter("hidden_origin", (screen["bounds"] as Rect2).position)
	ink.set_shader_parameter("hidden_layers", screen["subjects"].size())
	ink.set_shader_parameter("floor_layers", screen["floor_count"])
	ink.set_shader_parameter("content_factors", screen["factors"])
	ink.set_shader_parameter("grid", screen["grid"])
	ink.set_shader_parameter("content_alpha", CONTENT_SHOW_ALPHA)

func _bind_content_factors(screen: Dictionary) -> void:
	var subjects: Array = screen["subjects"]
	var blockers: Array = screen["blockers"]
	var factors := PackedFloat32Array()
	var width: int = maxi(subjects.size(), blockers.size())
	factors.resize(width * 2)
	for row: int in subjects.size(): factors[row] = subjects[row]["alpha"]
	for row: int in blockers.size(): factors[width + row] = _blocker_alpha(blockers[row])
	if screen.get("factor_values") == factors: return
	screen["factor_values"] = factors
	var image := Image.create_from_data(width, 2, false, Image.FORMAT_RF, factors.to_byte_array())
	screen["factors"] = ImageTexture.create_from_image(image)
	for ink: ShaderMaterial in [screen["ink"], screen["floor_ink"]]:
		ink.set_shader_parameter("content_factors", screen["factors"])
	for item: Dictionary in screen["pixel_items"].values():
		if is_instance_valid(item["canvas"]):
			item["canvas"].material.set_shader_parameter("content_factors", screen["factors"])
	for child: Control in screen["object_items"].values():
		child.material.set_shader_parameter("content_factors", screen["factors"])

func _configure_content_painter(tile: Vector2i, screen: Dictionary) -> void:
	var painter: Control = screen["painter"]
	var floor_painter: Control = screen["floor"]
	var art: RefCounted = board.get("_art_treatment")
	for child: Control in [floor_painter, painter]:
		child.size = board.size
		board.call("_copy_resolved_board_layout_to", child)
		child.set("_art_treatment", art)
		child.set("_art_treatment_enabled", board.get("_art_treatment_enabled"))
		_bind_content_mask(screen, child.material)
	for field: String in CONTENT_FLOOR_FIELDS: floor_painter.set(field, board.get(field))
	_copy_ink(art.material, painter.material)
	_copy_ink(art.cache_bake_material, floor_painter.material)
	var floor_kinds: Dictionary = {}
	for row: int in int(screen["floor_count"]):
		var source: Dictionary = screen["subjects"][row]["source"]
		floor_kinds[source["kind"]] = source.get("surface_kind", "")
	painter.set("_content_floor_kinds", floor_kinds)
	floor_painter.visible = not floor_kinds.is_empty()
	_sync_content_pixels(tile, screen, floor_kinds.get("surface", ""))
	_sync_content_objects(tile, screen, art.material)
	_queue_content_tile(screen)
	painter.visible = content_show_through_enabled
	floor_painter.queue_redraw()

func _sync_content_objects(tile: Vector2i, screen: Dictionary, art: ShaderMaterial) -> void:
	var items: Dictionary = screen["object_items"]
	var retained: Dictionary = {}
	var subjects: Array = screen["subjects"]
	for row: int in range(screen["floor_count"], subjects.size()):
		var source: Dictionary = subjects[row]["source"]
		var key: String = source["key"]
		var child: Control = items.get(key)
		if not is_instance_valid(child):
			child = _content_painter(screen["painter"], tile, CONTENT_OBJECT, "Object")
			child.material = _content_material(art)
		_copy_ink(art, child.material)
		_bind_content_mask(screen, child.material)
		child.material.set_shader_parameter("content_subject", row)
		child.set("_content_object_source", source)
		child.set("_art_treatment", board.get("_art_treatment"))
		retained[key] = child
	for key: String in items:
		if retained.has(key): continue
		items[key].hide()
		items[key].queue_free()
	screen["object_items"] = retained

func _queue_content_tile(screen: Dictionary, check_motion: bool = false) -> void:
	var painter: Variant = screen.get("painter")
	if not is_instance_valid(painter) or not painter.is_inside_tree(): return
	painter.set("combat_state", board.get("combat_state"))
	painter.set("presentation", board.get("presentation"))
	painter.set("_idle_elapsed", board.get("_idle_elapsed"))
	for field: String in CONTENT_PAINT_FIELDS: painter.set(field, board.get(field))
	board.get("_art_treatment").apply_motion_to(painter.material)
	painter.queue_redraw()
	var floor_painter: Control = screen["floor"]
	floor_painter.set("combat_state", painter.combat_state)
	floor_painter.set("presentation", painter.presentation)
	for child: Control in screen["object_items"].values():
		var source: Dictionary = child.get("_content_object_source")
		var draw: Dictionary = Sources.drawing(board, source)
		if not draw.is_empty() and not bool(source.get("ground", false)):
			if check_motion and source["rect"] != draw["rect"]:
				# Reproject bobbing gear on its normal scene redraw cadence.
				coverage_dirty = true
				set_process(tool_enabled)
			draw["rect"] = source["rect"]
		child.set("_content_object_draw", draw)
		board.get("_art_treatment").apply_motion_to(child.material)
		child.queue_redraw()

func redraw_content_for_layer(kind: String, tile: Vector2i) -> void:
	if _content_tiles.is_empty() or not content_show_through_enabled: return
	match kind:
		"scene_tile":
			var screen: Dictionary = _content_tiles.get(tile, {})
			if not screen.is_empty(): _queue_content_tile(screen, true)
		"ground", "overlays":
			for screen: Dictionary in _content_tiles.values(): _queue_content_tile(screen)

func _sync_content_pixels(tile: Vector2i, screen: Dictionary, surface_kind: String) -> void:
	var ground: Node2D = board.get("_pixel_ground")
	var retained: Dictionary = {}
	if not surface_kind.is_empty() and is_instance_valid(ground) and ground.field.tiles.has(tile):
		var half_tile := Vector2(board._tile_width(), board._tile_height()) * 0.5
		var field_rect := Rect2(board._tile_center(tile) - half_tile, half_tile * 2.0)
		_retain_content_pixel(screen, retained, "field", ground._floor, field_rect)
		for key: Variant in ground.depth.stamps:
			if not key is Array or key.size() < 2 or not key[0] is Vector2i or key[0] != tile: continue
			if key[1] != PixelField.ELEMENT_IDS[surface_kind]: continue
			var stamp: Node2D = ground.depth.stamps[key]
			if not stamp.visible or stamp.material.get_shader_parameter("reflection"): continue
			_retain_content_pixel(screen, retained, key, stamp, stamp.rect)
		for pass_index: int in 2:
			var stamp: Node2D = ground.sheet.stamps.get(Vector3i(tile.x, tile.y, pass_index))
			if is_instance_valid(stamp):
				_retain_content_pixel(screen, retained, pass_index, stamp, Rect2(Vector2.ZERO, Vector2.ONE))
	for key: Variant in screen["pixel_items"]:
		if not retained.has(key):
			var canvas: Node2D = screen["pixel_items"][key]["canvas"]
			canvas.hide()
			canvas.queue_free()
	screen["pixel_items"] = retained

func _retain_content_pixel(screen: Dictionary, retained: Dictionary, key: Variant,
		source: CanvasItem, rect: Rect2) -> void:
	var entry: Dictionary = screen["pixel_items"].get(key, {})
	var canvas: ContentStamp = entry.get("canvas")
	if not is_instance_valid(canvas):
		canvas = ContentStamp.new()
		canvas.show_behind_parent = true
		canvas.material = _content_material(source.material)
		(screen["painter"] as Control).add_child(canvas)
		entry = {"canvas": canvas}
	var ink: ShaderMaterial = canvas.material
	_bind_content_mask(screen, ink)
	_copy_ink(source.material, ink)
	if key is String:
		# The crop is submitted directly in board coordinates.
		ink.set_shader_parameter("floor_origin", Vector2.ZERO)
	elif key is int:
		canvas.position = source.position
		ink.set_shader_parameter("content_offset", canvas.position)
		canvas.set_instance_shader_parameter("row_pairs", source.get_instance_shader_parameter("row_pairs"))
		canvas.set_instance_shader_parameter("phase_and_switch", source.get_instance_shader_parameter("phase_and_switch"))
		RenderingServer.canvas_item_set_custom_rect(canvas.get_canvas_item(), true, source.get("_cull_bounds"))
	canvas.set_bounds(rect)
	var parent: Node = canvas.get_parent()
	var order: int = retained.size() + 1 # Floor is the first child.
	if canvas.get_index() != order: parent.move_child(canvas, order)
	retained[key] = entry

func _content_pixels_animating() -> bool:
	if not content_show_through_enabled or _content_tiles.is_empty(): return false
	var ground: Node2D = board.get("_pixel_ground")
	if not is_instance_valid(ground) or not ground.is_processing(): return false
	for screen: Dictionary in _content_tiles.values():
		if is_instance_valid(screen.get("painter")) and not screen["pixel_items"].is_empty(): return true
	return false

func _advance_content_pixels() -> void:
	var ground: Node2D = board.get("_pixel_ground")
	for screen: Dictionary in _content_tiles.values():
		if not is_instance_valid(screen.get("painter")): continue
		for key: Variant in screen["pixel_items"]:
			var item: Dictionary = screen["pixel_items"][key]
			if key is String:
				item["canvas"].material.set_shader_parameter("motion_seconds", ground._elapsed)
			elif key is int and item.get("tick") != ground.sheet.tick:
				item["tick"] = ground.sheet.tick
				item["canvas"].material.set_shader_parameter("tick", ground.sheet.tick)

func _update_content_reveal() -> void:
	for screen: Dictionary in _content_tiles.values(): _bind_content_factors(screen)

func _fade_content(delta: float) -> bool:
	var fading: bool = false
	var finished: Array[String]
	var changed: Dictionary = {}
	for key: String in _content_entries:
		var entry: Dictionary = _content_entries[key]
		var target: float = 1.0 if entry["on"] else 0.0
		var alpha: float = move_toward(entry["alpha"], target, delta / FADE_SECONDS)
		if alpha != entry["alpha"]:
			entry["alpha"] = alpha
			changed[entry["source"]["tile"]] = true
		fading = fading or alpha != target
		if alpha == 0.0 and target == 0.0: finished.append(key)
	for key: String in finished: _content_entries.erase(key)
	for tile: Vector2i in changed:
		var screen: Dictionary = _content_tiles.get(tile, {})
		if screen.is_empty(): continue
		if screen["subjects"].all(func(entry: Dictionary) -> bool: return not entry["on"] and entry["alpha"] == 0.0):
			_retire_content_tile(tile)
		else:
			_bind_content_factors(screen)
			if not finished.is_empty(): invalidate()
	return fading

func _retire_content_tile(tile: Vector2i) -> void:
	var screen: Dictionary = _content_tiles.get(tile, {})
	var painter: Variant = screen.get("painter")
	if is_instance_valid(painter):
		painter.hide()
		painter.queue_free()
	_content_tiles.erase(tile)

func _clear_content() -> void:
	for tile: Vector2i in _content_tiles.keys(): _retire_content_tile(tile)
	_content_entries.clear()
	_content_fading = false
