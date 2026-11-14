extends Node2D

const TeamOutlines = preload("res://scripts/board_unit_team_outlines.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Outline = preload("res://scripts/board_occlusion_silhouettes.gdshader")
const Reveal = preload("res://scripts/board_occlusion_reveal.gd")
const UNIT_ON: float = 0.30
const UNIT_OFF: float = 0.22
const OBJECT_ON: float = 0.40
const OBJECT_OFF: float = 0.30
const FADE_SECONDS: float = 0.15
const WIDTH: float = 2.0
const UNIT_ALPHA: float = 0.85
const OBJECT_ALPHA: float = 0.70
# Shader slots for units painted in front of one object (front_texture_0..3).
const MAX_FRONT_UNITS: int = 4
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
var latest_sources: Array[Dictionary] = []
var sources_revision: int = 0
var _sources_stale: bool = true

func attach(owner_board: Control) -> void:
	board = owner_board
	name = "OcclusionSilhouettes"
	owner_board.add_child(self)
	team.attach(owner_board, self)
	invalidate()

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
	if changes.has("unit_outline_alpha_multipliers"):
		for key: String in entries: _update_pose(entries[key])
		for key: String in team.entries: team.refresh_alpha(key)
	if structural or not registrations.is_empty():
		invalidate()
		return
	for key: String in ["unit_world_positions", "unit_footprint_world_positions", "unit_draw_tiles", "unit_texture_origins",
		"visible_enemy_ids", "umbra_visible_tiles", "umbra_stage", "umbra_action_actor_clips", "scene_props", "death_animation_units", "missed_equipment_ids", "equipped_equipment", "static_enemy_facings"]:
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
	else: set_process(false)

static func switched_on(coverage: float, was_on: bool, unit: bool) -> bool:
	return coverage >= (UNIT_OFF if unit else OBJECT_OFF) if was_on else coverage >= (UNIT_ON if unit else OBJECT_ON)

static func team_color(entry: Dictionary) -> Color:
	if str(entry["kind"]) != "unit": return Color(Palette.TEXT, OBJECT_ALPHA)
	return Color(Palette.DANGER if str((entry["data"] as Dictionary).get("role", "")) == "enemy" else Palette.ALLY, UNIT_ALPHA)


func sync_coverage() -> void:
	coverage_dirty = false
	coverage_builds += 1
	var sources: Array[Dictionary] = _collect_sources()
	_pose_sets = Sources.pose_set_signature(board)
	team.sync()
	var retained: Dictionary = {}
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		if not bool(source["eligible"]): continue
		var key: String = source["key"]
		var unit: bool = str(source["kind"]) == "unit"
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
		entry.merge({"source": source, "coverage": amount, "on": on, "front": [] if unit else front_units(sources, index)}, true)
		_update_pose(entry)
		retained[key] = entry
	for key: String in entries:
		# Privacy/death/removal is immediate, even partway through a fade.
		if not retained.has(key):
			(entries[key]["sprite"] as Sprite2D).visible = false
			(entries[key]["sprite"] as Sprite2D).queue_free()
	entries = retained
	for key: String in team.entries: team.refresh_alpha(key)

# Units painted after an object whose live drawing can reach its rim; past the
# shader's slots, the largest overlaps win. Units hidden for privacy are not
# sources, so they never shape a rim.
func front_units(sources: Array[Dictionary], index: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var target: Rect2 = sources[index]["rect"]
	var reach: Rect2 = target.grow(WIDTH * 2.0 * float(board.get("_navigation_zoom")))
	for later: int in range(index + 1, sources.size()):
		var source: Dictionary = sources[later]
		if str(source["kind"]) != "unit": continue
		var draw: Dictionary = Sources.drawing(board, source)
		if not draw.is_empty() and reach.intersects(draw["rect"]): result.append(source)
	if result.size() > MAX_FRONT_UNITS:
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return target.intersection(a["rect"]).get_area() > target.intersection(b["rect"]).get_area())
		result.resize(MAX_FRONT_UNITS)
	return result

func _update_pose(entry: Dictionary) -> void:
	var draw: Dictionary = Sources.drawing(board, entry["source"])
	if draw.is_empty(): return
	var sprite: Sprite2D = entry["sprite"]
	var fronts: Array = []
	for front: Dictionary in entry.get("front", []):
		var front_draw: Dictionary = Sources.drawing(board, front)
		if not front_draw.is_empty(): fronts.append([front_draw["texture"], front_draw["rect"], front_ring(str(front["key"])), reveal_alpha(str(front["key"]))])
	var signature: Array = [draw["texture"], draw["rect"], board.get("_navigation_zoom"), rim_color(entry["source"]), fronts]
	if signature == entry.get("pose_signature", []): return
	entry["pose_signature"] = signature
	var texture: Texture2D = draw["texture"]
	var rect: Rect2 = draw["rect"]
	sprite.texture = texture
	sprite.position = rect.get_center()
	sprite.scale = rect.size / Vector2(texture.get_size())
	var ink: ShaderMaterial = sprite.material
	ink.set_shader_parameter("silhouette_texture", (texture as AtlasTexture).atlas if texture is AtlasTexture else texture)
	ink.set_shader_parameter("rim_color", rim_color(entry["source"]))
	configure_rim(ink, texture, rect)
	configure_front_mask(ink, rect, fronts)
	pose_updates += 1

static func uv_region(texture: Texture2D) -> Rect2:
	if not texture is AtlasTexture: return Rect2(Vector2.ZERO, Vector2.ONE)
	var atlas: AtlasTexture = texture
	return Rect2(atlas.region.position / Vector2(atlas.atlas.get_size()), atlas.region.size / Vector2(atlas.atlas.get_size()))

# Board-pixel width of the team-rim ring a front unit shows (0 without one);
# the object rim stops at that ring's outer edge.
func front_ring(key: String) -> float:
	return WIDTH * float(board.get("_navigation_zoom")) if team.entries.has(key) and unit_alpha_multiplier(key) > 0.0 else 0.0

# The shader samples each front unit's current texture, so live rig poses need
# no update here; frame/atlas or placement changes arrive through _process.
func configure_front_mask(ink: ShaderMaterial, rect: Rect2, fronts: Array) -> void:
	ink.set_shader_parameter("front_count", fronts.size())
	ink.set_shader_parameter("object_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	for slot: int in range(MAX_FRONT_UNITS):
		var texture: Texture2D = fronts[slot][0] if slot < fronts.size() else null
		var front: Rect2 = fronts[slot][1] if slot < fronts.size() else Rect2()
		var region: Rect2 = uv_region(texture) if texture != null else Rect2(Vector2.ZERO, Vector2.ONE)
		var ring: float = float(fronts[slot][2]) if slot < fronts.size() else 0.0
		# occ-02: a unit faded by the focus reveal hides only that share of the rim.
		ink.set_shader_parameter("front_alpha_%d" % slot, float(fronts[slot][3]) if slot < fronts.size() else 1.0)
		ink.set_shader_parameter("front_pad_%d" % slot, region.size * ring / front.size if ring > 0.0 else Vector2.ZERO)
		ink.set_shader_parameter("front_texture_%d" % slot, (texture as AtlasTexture).atlas if texture is AtlasTexture else texture)
		ink.set_shader_parameter("front_rect_%d" % slot, Vector4(front.position.x, front.position.y, front.size.x, front.size.y))
		ink.set_shader_parameter("front_region_%d" % slot, Vector4(region.position.x, region.position.y, region.end.x, region.end.y))

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
	for entry: Dictionary in entries.values(): _update_pose(entry)
	for key: String in team.entries: team.refresh_alpha(key)

func set_unit_alpha_multiplier(key: String, value: float) -> void:
	_unit_alpha_overrides[key] = clampf(value, 0.0, 1.0)
	# Object rims cut by this unit follow whether its team ring still shows.
	for entry: Dictionary in entries.values(): _update_pose(entry)
	team.refresh_alpha(key)

func rim_color(source: Dictionary) -> Color:
	var result: Color = team_color(source)
	if str(source["kind"]) == "unit": result.a *= unit_alpha_multiplier(str(source["key"]))
	else:
		# An object's rim fades with the object when the focus reveal fades it.
		var reveal: Node = board.get("_occlusion_reveal")
		var category: String = Reveal.category_for(source)
		if is_instance_valid(reveal) and not category.is_empty(): result.a *= float(reveal.prop_alpha(category, source["tile"]))
	return result

func _front_redrawn(entry: Dictionary) -> bool:
	for front: Dictionary in entry.get("front", []):
		if pose_tiles.has(front["tile"]): return true
	return false

func _process(delta: float) -> void:
	if not tool_enabled: return
	var instrumented: bool = bool(board.get("_submission_performance_instrumentation_enabled"))
	var started: int = Time.get_ticks_usec() if instrumented else 0
	if coverage_dirty: sync_coverage()
	var fading: bool = false
	var finished: Array[String]
	for key: String in entries:
		var entry: Dictionary = entries[key]
		var source: Dictionary = entry["source"]
		if pose_tiles.has(source["tile"]) or (ground_dirty and bool(source.get("ground", false))) or _front_redrawn(entry): _update_pose(entry)
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
	set_process(fading or coverage_dirty)
	if instrumented: board.call("_record_render_frame_section", Engine.get_process_frames(), "occlusion_silhouettes", Time.get_ticks_usec() - started)
