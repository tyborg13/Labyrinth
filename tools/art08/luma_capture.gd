extends RefCounted
## Export measurement geometry from the same viewport as the native stills.
## Alpha files use a non-PNG suffix so the still contract only sees game frames.

const Fight = preload("fight.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const Treatment = preload("res://scripts/combat_art_treatment.gd")
const Check = preload("mound_check.gd")
const Clock = preload("res://scripts/presentation_clock.gd")

static func records(name: String) -> bool:
	return name in [Fight.STILLS[0], Fight.STILLS[1], Fight.STILLS[3], Fight.STILLS[5]]

static func capture(fight: RefCounted, name: String, crop: Rect2i, row: Dictionary, out: String, dry: bool, check: Callable) -> Dictionary:
	var board: Control = fight.board
	var origin: Transform2D = board.get_global_transform_with_canvas()
	origin.origin -= Vector2(crop.position)
	var unit: Dictionary = fight.grub_unit()
	var buried: bool = bool(unit.get("burrowed", false))
	var texture: Texture2D = board._texture_for_unit(unit)
	var body_profile: int = Treatment.actor_profile(unit, texture)
	var profile: int = body_profile
	var draw_rect: Rect2
	if buried:
		var submission: Dictionary = Check.mound_submission(board, unit)
		if not check.call(not submission.is_empty(), "sample submits one mound texture: " + name): return {}
		profile = submission["profile"]
		check.call(profile == body_profile, "mound and live Grub profiles match: " + name)
		check.call((submission["tint"] as Color).is_equal_approx(Color.WHITE), "proof mound remains untinted: " + name)
		draw_rect = submission["rect"]
		if dry and row.has("breath_phase_msec"):
			draw_rect = Burrow.mound_draw_rect(board, unit["pos"], submission["texture"], Burrow.breath_scale(row["breath_phase_msec"], false))
	else:
		draw_rect = _body_rect(board, unit)
	var art: RefCounted = board.get("_art_treatment")
	var uniforms: Dictionary = art.get("_parameters")
	var lights: int = art.get("source_count")
	var flicker: PackedFloat32Array = uniforms.get("art_light_flicker", PackedFloat32Array())
	var body_canvas: Control = board.get("_occlusion_silhouettes").team.bodies.get(Fight.ACTOR_KEY)
	var body_alpha: float = 1.0
	var same_world_material: bool = is_instance_valid(body_canvas) and body_canvas.material == art.material
	var layer: CanvasItem = body_canvas
	while layer != null:
		body_alpha *= layer.modulate.a
		layer = layer.get_parent() as CanvasItem
	if is_instance_valid(body_canvas): body_alpha *= body_canvas.self_modulate.a
	var paint: Dictionary = {"rect": _rect(origin * draw_rect), "profile": profile}
	if buried:
		paint["asset"] = Burrow.MOUND_PATH.trim_prefix("res://")
	elif not dry:
		paint["mask"] = _write_mask(texture, out, name, Fight.ACTOR_KEY, check)

	print("ART-08 PROFILE %s %s=%s(%d) live_grub=%s(%d) lights=%d ambient=%.4f flicker=%s canvas_alpha=%.4f shared_material=%s" % [
		name, "mound" if buried else "erupt", _profile_name(profile), profile, _profile_name(body_profile), body_profile,
		lights, float(uniforms.get("art_ambient_level", 0.0)), str(flicker.slice(0, lights)), body_alpha, same_world_material])

	var measure: Dictionary = {"subject": paint, "floor_tiles": _floor_ring(board, unit["pos"], origin),
		"lights": lights, "ambient": uniforms.get("art_ambient_level"), "flicker": Array(flicker.slice(0, lights)),
		"canvas_alpha": body_alpha, "shared_material": same_world_material, "ui": _ui_masks(board, origin)}
	if dry: return measure
	var units: Array = []
	for other: Dictionary in board._visible_units():
		var key: String = str(other.get("key", ""))
		if key == Fight.ACTOR_KEY: continue
		var other_texture: Texture2D = board._texture_for_unit(other)
		if other_texture == null: continue
		var mask: String = _write_mask(other_texture, out, name, key, check)
		units.append({"rect": _rect(origin * _body_rect(board, other)), "mask": mask})
	measure["other_units"] = units
	return measure

static func _body_rect(board: Control, unit: Dictionary) -> Rect2:
	var rect: Rect2 = board._unit_texture_draw_rect(unit, board._unit_center(unit))
	var shake: float = board._unit_impact_shake_strength(unit)
	if shake > 0.0: rect.position.x += sin(Clock.ticks_msec() * 0.09) * 3.0 * shake
	return rect

static func _floor_ring(board: Control, tile: Vector2i, origin: Transform2D) -> Array:
	var polys: Array = []
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if x == 0 and y == 0: continue
			var poly: Array = []
			for vertex: Vector2 in board._tile_polygon(tile + Vector2i(x, y)):
				var pixel: Vector2 = origin * vertex
				poly.append([pixel.x, pixel.y])
			polys.append(poly)
	return polys

static func _ui_masks(board: Control, origin: Transform2D) -> Array:
	var result: Array = []
	var units: Dictionary = board._units_by_key(board._visible_units())
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		var unit: Dictionary = units.get(entry.get("actor_key", ""), {})
		var health: Rect2 = entry.get("health_rect", Rect2())
		if not unit.is_empty() and health.has_area():
			for rect: Rect2 in board._health_bar_collision_rects(unit, health):
				result.append(_rect(origin * rect))
		for rect: Rect2 in entry.get("layout", {}).get("occupied_rects", []):
			result.append(_rect(origin * rect))
	var hud: Control = board.get("_hud_render_layer")
	var canvases: Array[Node]
	canvases.append(hud)
	canvases.append_array(hud.find_children("*", "Control", true, false))
	for canvas: Node in canvases:
		if canvas.get_script() != board.get_script() or not canvas.is_visible_in_tree(): continue
		for region: Dictionary in canvas.get("_tooltip_regions"):
			var rect: Rect2 = region.get("rect", Rect2())
			if rect.has_area(): result.append(_rect(origin * rect))
	return result

static func _write_mask(texture: Texture2D, out: String, name: String, key: String, check: Callable) -> String:
	var image: Image = texture.get_image() if texture != null else null
	if not check.call(image != null and not image.is_empty(), "reads live alpha: " + name + " " + key): return ""
	var filename: String = name + "." + key + ".mask"
	var file := FileAccess.open(out.path_join(filename), FileAccess.WRITE)
	if not check.call(file != null, "writes live alpha: " + filename): return ""
	file.store_buffer(image.save_png_to_buffer())
	file.close()
	return filename

static func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func _profile_name(profile: int) -> String:
	match profile:
		Treatment.ACTOR: return "ACTOR"
		Treatment.ACTOR_ATLAS: return "ACTOR_ATLAS"
		Treatment.PROP: return "PROP"
	return str(profile)
