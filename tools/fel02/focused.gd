extends "res://tools/fel02/witness.gd"
## Focused checks on the real retained shader bindings and a synthetic overlap.

const Silhouettes = preload("res://scripts/board_occlusion_silhouettes.gd")
const PropCache = preload("res://scripts/board_prop_command_cache.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const SAMPLE := "res://tools/fel01/samples/01-s0-seed15-0-0_2-t2"
const TEST_MASK_SIZE := Vector2i(8, 4)
const GRID_TEST_PAN := Vector2(17, 11)
const SWORD_OCCLUDER_TILE := Vector2i(4, 6)

var _checks: int = 0

# The headless dummy has no paint surface. Record commands built by the exact
# retained callbacks before they would be submitted to a CanvasItem.
class RecordedPaint extends PropCache:
	func paint(_board: Control, _slot: String, _inputs: Array, build: Callable) -> void:
		commands.clear()
		recording = true
		build.call()
		recording = false


func _run() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel02_focused_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save focused settings")
		return
	if not await _fixture(ProjectSettings.globalize_path(SAMPLE)): return
	for failure: String in _failures: printerr("FEL02 " + failure)
	print("FEL02 FOCUSED %s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _capture_phases(scene: Node, id: String, tile: Vector2i) -> bool:
	var board: Control = scene.get("board_view")
	var overlay: Node = board.get("_occlusion_silhouettes")
	var reveal: Node = board.get("_occlusion_reveal")
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_running(): await process_frame
	await _settle()
	_check_draw_commands(board)
	_check_pair(overlay)
	_check_procedural_masks(board, overlay, tile)
	overlay.sync_coverage()
	_check_hero_gear(board, overlay)
	_check_shader_bindings(overlay, reveal, false)
	await _point(_tile_center(board, tile))
	await _settle()
	_check(_fade_is_settled(reveal, tile), id + " pointer reveal settles")
	_check_shader_bindings(overlay, reveal, true)
	await _point(NO_POINTER)
	await _settle()
	_check(reveal.targets.is_empty(), "focus exit restores the underlying props")
	_check_shader_bindings(overlay, reveal, false)
	_check_board_checker(board, overlay)
	return true


func _check_draw_commands(board: Control) -> void:
	var recorder := RecordedPaint.new()
	var original: RefCounted = board.get("_prop_command_cache")
	var grid: Array = board.get("combat_state")["grid"]
	var obstructions: Array = board.get("_foreground_obstruction_entries_cache")
	var checked: Dictionary = {}
	board.set("_prop_command_cache", recorder)
	for source: Dictionary in board.get("_occlusion_silhouettes").current_sources():
		var kind: String = source.get("prop_kind", source["kind"])
		if kind in ["pillar", "wall"]:
			recorder.paint(board, "stone", [], board._draw_tile_stone_props.bind(grid, source["tile"], kind, obstructions))
		elif kind == "terrain":
			board._draw_terrain_object(source["data"], obstructions)
		else:
			continue
		for command: Array in recorder.commands:
			var colors: PackedColorArray
			match str(command[0]):
				"polygon": colors = command[2]
				"texture":
					if command[1] != board.get("_art_treatment").contact_texture: colors.append(command[3])
				"region": colors.append(command[4])
			for color: Color in colors:
				_check(is_equal_approx(color.a, 1.0), "retained %s body paint is solid at rest" % kind)
				checked[kind] = true
	board.set("_prop_command_cache", original)
	_check(checked.has("pillar") and checked.has("terrain"), "exercised retained pillar and terrain paint commands")


func _check_pair(overlay: Node) -> void:
	var source: Dictionary
	for candidate: Dictionary in overlay.current_sources():
		if candidate["kind"] == "unit":
			source = candidate
			break
	_check(not source.is_empty(), "fixture provides a live silhouette")
	if source.is_empty(): return
	var pair: Array[Dictionary]
	pair.assign([source, source.duplicate()])
	var cover: float = Alpha.coverage(pair[0], [pair[1]])
	_check(Silhouettes.switched_on(cover, false, true), "opaque unit-on-unit coverage can still turn on an x-ray rim")
	var blockers: Array[Dictionary] = overlay._fill_blockers(pair[0], 0, overlay._fill_sources(pair))
	_check(blockers.is_empty(), "a later unit supplies no fill mask")

	var image := Image.create_empty(TEST_MASK_SIZE.x, TEST_MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, TEST_MASK_SIZE.x / 2, TEST_MASK_SIZE.y), Color.WHITE)
	var object: Dictionary = {"kind": "terrain", "tile": source["tile"], "rect": source["rect"],
		"mask_texture": ImageTexture.create_from_image(image)}
	pair.assign([object, source, object])
	var masks: Array[Dictionary] = overlay._fill_sources(pair)
	blockers = overlay._fill_blockers(source, 1, masks)
	_check(blockers.size() == 1 and blockers[0]["index"] == 2, "only the later solid prop can fill the unit")
	if blockers.size() != 1: return
	var region: Rect2i = blockers[0]["region"]
	var atlas: Image = (overlay.get("_fill_atlas") as Texture2D).get_image()
	_check(atlas.get_pixelv(region.position).a == 1.0 and atlas.get_pixelv(region.end - Vector2i.ONE).a == 0.0,
		"atlas preserves opaque pixels and transparent holes")
	var illusion: Dictionary = source.duplicate()
	illusion["data"] = (source["data"] as Dictionary).merged({"role": "illusion"}, true)
	_check(overlay._fill_blockers(illusion, 1, masks).is_empty(), "illusion is excluded even when a prop hides it")


func _check_procedural_masks(board: Control, overlay: Node, tile: Vector2i) -> void:
	for kind: String in ["crag_outcrop", "dragon_spire"]:
		var shape: Dictionary = overlay._procedural_mask({"kind": kind, "tile": tile,
			"width": board._tile_width(), "rise": 1.0})
		var image: Image = shape.get("image")
		_check(image != null and image.get_used_rect().has_area() and image.get_pixel(0, 0).a == 0.0,
			kind + " fill mask uses the drawn facets with transparent corners")

func _check_hero_gear(board: Control, overlay: Node) -> void:
	var sources: Array[Dictionary] = overlay.current_sources()
	var hero_index: int = sources.find_custom(func(source: Dictionary) -> bool: return source.get("key") == "player")
	_check(hero_index >= 0, "fixture 01 exposes the hero silhouette")
	if hero_index < 0: return
	var hero: Dictionary = sources[hero_index]
	var renderer: Node = board.unit_cutout_renderer(hero["data"])
	var rig: Node2D = renderer.rigs[renderer.facing]
	var weapon: Sprite2D = rig.get("_gear_base_parts")["weapon_r"]["node"]
	var live: Dictionary = Sources.drawing(board, hero)
	_check(weapon.is_visible_in_tree() and weapon.get_viewport() == renderer.viewport,
		"the visible equipped sword renders inside the live cutout viewport")
	_check(live["texture"] == renderer.viewport.get_texture() and hero["mask_texture"] == renderer.rest_texture(),
		"x-ray uses the gear-composited live viewport and the gear-aware rest mask")
	var pillar: Dictionary = {}
	for index: int in range(hero_index + 1, sources.size()):
		var blocker: Dictionary = sources[index]
		if blocker.get("prop_kind") == "pillar" and blocker["tile"] == SWORD_OCCLUDER_TILE:
			pillar = blocker
			break
	_check(not pillar.is_empty(), "the fixture 01 front pillar is painted after the hero")
	if pillar.is_empty(): return
	var image: Image = weapon.texture.get_image()
	var mask_size := Vector2(image.get_size())
	var weapon_rect: Rect2 = weapon.get_rect()
	var hero_rect: Rect2 = live["rect"]
	var hidden_texels: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= Alpha.OPAQUE_ALPHA: continue
			var local: Vector2 = weapon_rect.position + Vector2(x + 0.5, y + 0.5) / mask_size * weapon_rect.size
			var canvas_point: Vector2 = weapon.get_global_transform_with_canvas() * local
			var point: Vector2 = hero_rect.position + canvas_point / Vector2(renderer.viewport.size) * hero_rect.size
			if Alpha.opaque_at(pillar, point): hidden_texels += 1
	var masks: RefCounted = overlay.get("alpha_masks")
	var coverage: float = masks.coverage_for(sources, hero_index)
	var xray_on: bool = bool(overlay.get("entries").get("player", {}).get("on", false))
	_check(hidden_texels > 0, "projected sword texels overlap the opaque pillar mask")
	_check(xray_on == Silhouettes.switched_on(coverage, false, true), "hero x-ray follows the existing rest threshold")
	print("FEL02 HERO GEAR %s hidden_sword_texels=%d rest_coverage=%.6f xray=%s" %
		[renderer.get("_equipped")["weapon"], hidden_texels, coverage, "on" if xray_on else "off"])

func _check_board_checker(board: Control, overlay: Node) -> void:
	# Headless can verify the real shader wiring and material values. Sample
	# equivalent board points numerically at rest and after production pan.
	var code: String = Silhouettes.Outline.code
	_check(code.contains("vec2 cell = floor((point - fill_grid.xy) / fill_grid.zw);")
		and code.contains("if (mod(cell.x + cell.y, 2.0) == 0.0) {")
		and code.contains("vec2 point = object_rect.xy + (UV - mask_min) / (mask_max - mask_min) * object_rect.zw;"),
		"the production shader gates fill by parity in board space")
	var before: Vector4 = _check_grid_binding(board, overlay)
	board.set_navigation_pan(board.get("_navigation_pan") + GRID_TEST_PAN, false)
	overlay.sync_coverage()
	var panned: Vector4 = _check_grid_binding(board, overlay)
	_check(Vector2(panned.x, panned.y) != Vector2(before.x, before.y), "camera pan moves the board grid origin")
	_check(Vector2(panned.z, panned.w).is_equal_approx(Vector2(before.z, before.w)), "camera pan preserves game-pixel size")

func _check_grid_binding(board: Control, overlay: Node) -> Vector4:
	for entry: Dictionary in overlay.get("entries").values():
		if (entry.get("fill_blockers", []) as Array).is_empty(): continue
		var ink: ShaderMaterial = (entry["sprite"] as Sprite2D).material
		var grid: Vector4 = ink.get_shader_parameter("fill_grid")
		var origin := Vector2(grid.x, grid.y)
		var cell := Vector2(grid.z, grid.w)
		var viewport: Viewport = board.get_viewport()
		var scale: Vector2 = viewport.get_stretch_transform().get_scale() * board.get_global_transform().get_scale().abs()
		var shield_cell: int = board.get("_self_bursts").cell_px
		_check(shield_cell > 0 and (cell * scale).is_equal_approx(Vector2.ONE * shield_cell), "one fill cell matches one FX-13 Block cell")
		_check(origin.is_equal_approx(board._board_origin()), "shader origin is the real board origin")
		if cell.x <= 0.0 or cell.y <= 0.0: return grid
		for y: int in range(-1, 3):
			for x: int in range(-1, 3):
				var point: Vector2 = origin + cell * Vector2(x + 0.5, y + 0.5)
				var index: Vector2 = ((point - origin) / cell).floor()
				var on: bool = fposmod(index.x + index.y, 2.0) == 0.0
				_check(on == (posmod(x, 2) == posmod(y, 2)), "game pixels alternate horizontally and vertically with a two-cell repeat")
		return grid
	_check(false, "fixture has a filled rim for the game-pixel grid check")
	return Vector4.ZERO


func _check_shader_bindings(overlay: Node, reveal: Node, expect_fade: bool) -> void:
	var faded: int = 0
	for entry: Dictionary in overlay.get("entries").values():
		var blockers: Array = entry.get("fill_blockers", [])
		if blockers.is_empty(): continue
		var source: Dictionary = entry["source"]
		var key: String = source["key"]
		var sprite: Sprite2D = entry["sprite"]
		var ink: ShaderMaterial = sprite.material
		var texture: Texture2D = ink.get_shader_parameter("fill_objects")
		_check(texture != null and int(ink.get_shader_parameter("fill_count")) == blockers.size(), key + " binds each mask to the rim shader")
		if texture == null: continue
		var data: Image = texture.get_image()
		for row: int in range(blockers.size()):
			var blocker: Dictionary = blockers[row]
			var alpha: float = reveal.prop_alpha(blocker["category"], blocker["tile"])
			var mask_opacity: float = data.get_pixel(2, row).r
			_check(is_equal_approx(mask_opacity, alpha), key + " fill tracks real object reveal alpha")
			if mask_opacity < 1.0: faded += 1
		overlay.set_unit_alpha_multiplier(key, 0.5)
		var expected: float = Silhouettes.UNIT_FILL_ALPHA * 0.5 * reveal.unit_alpha(key)
		_check(is_equal_approx(float(ink.get_shader_parameter("fill_alpha")), expected), key + " fill uses the rim alpha multiplier")
		overlay.set_unit_alpha_multiplier(key, 1.0)
		_check(ink.get_shader_parameter("fill_objects") == texture, key + " unchanged object masks are retained")
	_check((faded > 0) == expect_fade, "fill metadata reflects the settled focus state")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	super._check(condition, message)
