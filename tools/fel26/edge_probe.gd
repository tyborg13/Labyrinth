extends RefCounted
## CPU witness and native paired check for the production Continue fixtures.

const TAGS := ["P3", "04-s0-seed8-0--3_2-t5", "10-s3-seed12-3-13_-2-t4", "P2", "P8"]
const TODO_DESIGN_P8_CRATE_LOOT_FIXTURE := "P2" # Fel-16's authored crate/loot window.
const STILLS := {"P3": "P3", "04-s0-seed8-0--3_2-t5": "04-s0-seed8-0--3_2-t5",
	"10-s3-seed12-3-13_-2-t4": "10-s3-seed12-3-13_-2-t4",
	TODO_DESIGN_P8_CRATE_LOOT_FIXTURE: "crate-loot", "P8": "P8-hero-pillar"}
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const LegacyOutline = preload("res://scripts/board_occlusion_silhouettes.gdshader")
const CROP_PILLAR_TILE := Vector2i(5, 3)

func audit(board: Control, fixture: String) -> bool:
	var overlay: Node = board.get("_occlusion_silhouettes")
	var variant: String = OS.get_environment("LABYRINTH_OCCLUDER_EDGE")
	var release: bool = OS.get_environment("FEL26_RELEASE_BASELINE") == "1"
	var edges: Array = [] if release else overlay.get("_edges")
	var size: int = 0
	var ok: bool = release or overlay.get("edge_mode") == variant
	if variant == "off":
		ok = ok and edges.is_empty()
		for entry: Dictionary in overlay.entries.values():
			ok = ok and entry["sprite"].material.shader == LegacyOutline
		if not release:
			ok = ok and overlay.get("_edge_sprites").is_empty()
	else:
		var atlas: Texture2D = overlay.get("_edge_atlas")
		var image: Image = atlas.get_image() if atlas != null else null
		var sources: Array = overlay.current_sources()
		var windows: Dictionary = _windows(overlay) if variant == "window" else {}
		var layers: Dictionary = board.get("_scene_render_layers_by_tile")
		var sprite_by_id: Dictionary = overlay.get("_edge_sprites")
		var front_count: int = 0
		for source: Dictionary in sources:
			if source.get("prop_kind") in ["pillar", "door"] or (source.get("data", {}) as Dictionary).get("kind") == "wooden_crate":
				if layers.has(source["tile"]): front_count += 1
		if edges.size() != front_count:
			print("FEL26 EDGE COUNTS ", edges.size(), " expected ", front_count)
			ok = false
		for edge: Dictionary in edges:
			var source: Dictionary = sources[edge["index"]]
			var texture: Texture2D = source["mask_texture"]
			var opening: Dictionary = Sources.opening_door_mask(board, board.combat_state["grid"], source)
			if not opening.is_empty(): texture = opening["mask_texture"]
			var original: Image = Assets.texture_source_image(texture)
			if original == null or image == null:
				ok = false
				continue
			if original.is_compressed() and original.decompress() != OK:
				ok = false
				continue
			original.convert(Image.FORMAT_RGBA8)
			var region: Rect2i = edge["edge_region"]
			var sprite: Sprite2D = sprite_by_id.get(edge["edge_id"])
			if sprite == null:
				ok = false
				continue
			var strength: float = 1.0 if variant == "always" else windows.get(edge["index"], 0.0)
			var active: bool = strength > 0.0
			ok = ok and original.get_size() + Vector2i(2, 2) == region.size
			ok = ok and sprite.get_parent() == layers[edge["tile"]]
			ok = ok and is_equal_approx(sprite.self_modulate.a, strength) and sprite.visible == active
			ok = ok and sprite.material == null and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			var texel_size: Vector2 = Rect2(edge["rect"]).size / Vector2(original.get_size())
			ok = ok and sprite.scale.is_equal_approx(texel_size)
			ok = ok and sprite.position.is_equal_approx(Rect2(edge["rect"]).position - texel_size)
			for body: Control in overlay.team.bodies.values():
				if body.get_parent() == sprite.get_parent() and sprite.get_index() >= body.get_index():
					print("FEL26 DEPTH MISMATCH ", sprite.get_path(), " body=", body.get_path())
					ok = false
			var checked: Vector2i = _check_texels(original, image, region)
			if checked.y != 0:
				print("FEL26 MASK MISMATCH ", edge["edge_id"], " texels=", checked.y)
				ok = false
			if not is_equal_approx(sprite.self_modulate.a, strength) or sprite.visible != active:
				print("FEL26 FADE MISMATCH ", edge["edge_id"], " actual=", sprite.self_modulate.a, " expected=", strength)
			if active: size += checked.x
	_print_checker_signature(overlay, fixture)
	print("FEL26 EDGE %s %s edge_texels=%d %s" %
		[variant, fixture, size, "PASS" if ok else "FAIL"])
	return ok

func _windows(overlay: Node) -> Dictionary:
	var result: Dictionary = {}
	for screen: Dictionary in overlay.get("_content_tiles").values():
		for row: int in screen["subjects"].size():
			var fade: float = screen["subjects"][row]["alpha"]
			for edge: Dictionary in screen["used_blockers"][row].values():
				result[edge["index"]] = maxf(result.get(edge["index"], 0.0), fade * overlay._blocker_alpha(edge))
	for entry: Dictionary in overlay.entries.values():
		var source: Dictionary = entry["source"]
		if source["kind"] != "unit": continue
		for edge: Dictionary in entry["edge_windows"]:
			var strength: float = entry["alpha"] * overlay.unit_alpha_multiplier(source["key"]) * overlay._blocker_alpha(edge)
			result[edge["index"]] = maxf(result.get(edge["index"], 0.0), strength)
	return result

func _check_texels(original: Image, atlas: Image, region: Rect2i) -> Vector2i:
	var counts := Vector2i.ZERO
	var bounds := Rect2i(Vector2i.ZERO, original.get_size())
	for y: int in region.size.y:
		for x: int in region.size.x:
			var texel := Vector2i(x - 1, y - 1)
			var exterior: bool = false
			if not bounds.has_point(texel) or original.get_pixelv(texel).a8 < 128:
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var neighbor: Vector2i = texel + Vector2i(dx, dy)
						if bounds.has_point(neighbor) and original.get_pixelv(neighbor).a8 >= 128: exterior = true
			var paint: Color = atlas.get_pixelv(region.position + Vector2i(x, y))
			if exterior:
				counts.x += 1
				if paint.a8 != 255 or Vector3i(paint.r8, paint.g8, paint.b8) != Vector3i(15, 11, 10):
					counts.y += 1
			elif paint.a8 != 0:
				counts.y += 1
	return counts

func _print_checker_signature(overlay: Node, fixture: String) -> void:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var content: Dictionary = overlay.get("_content_tiles")
	var unit_keys: Array = overlay.entries.keys()
	unit_keys.sort()
	for key: String in unit_keys:
		var entry: Dictionary = overlay.entries[key]
		var blockers: Array = entry.get("fill_blockers", [])
		var indices: Array = blockers.map(func(item: Dictionary) -> int: return item["index"])
		digest.update(var_to_bytes([key, entry["on"], entry["coverage"], indices]))
	var tiles: Array = content.keys()
	tiles.sort()
	for tile: Vector2i in tiles:
		var screen: Dictionary = content[tile]
		digest.update(var_to_bytes([tile, screen["grid"], screen["bounds"], screen["last_tile"]]))
		for entry: Dictionary in screen["subjects"]:
			var geometry: Dictionary = entry["fill_geometry"]
			var coverage: Array = entry["blockers"].map(func(blocker: Dictionary) -> Array:
				return [blocker["index"], blocker["rect"], blocker["coverage_source"]["mask"]["bits"]])
			digest.update(var_to_bytes([geometry["rect"], geometry.get("diamond", PackedVector2Array()),
				geometry["mask"]["bits"], entry["on"], coverage]))
		var mask: Texture2DArray = screen["mask"]
		for layer: int in mask.get_layers():
			var image: Image = mask.get_layer_data(layer)
			if image != null: digest.update(image.get_data())
	print("FEL26 CHECKER SIGNATURE %s %s" % [fixture, digest.finish().hex_encode()])

func stills(session: SceneTree) -> void:
	var output: String = OS.get_environment("FEL13_CAPTURE_DIR")
	var variant: String = OS.get_environment("LABYRINTH_OCCLUDER_EDGE")
	var legacy: Shader
	if not session.dry and variant == "off":
		var code: String = FileAccess.get_file_as_string(OS.get_environment("FEL26_BASELINE_SHADER"))
		if code.is_empty():
			session.fail("missing frozen release shader")
			return
		legacy = Shader.new()
		legacy.code = code
	var ok: bool = not session.dry or _pixel_diagnostics_check()
	for fixture: String in TAGS:
		if not await session.open_fixture(fixture):
			ok = false
			continue
		await session.settle()
		if session.dry:
			print("FEL26 STILL PLAN ", variant, " ", fixture, " ", STILLS[fixture], " frozen_draws=3 frame_step=0")
			if fixture == "P3" and variant == "always":
				var crop: Rect2i = _pillar_crop(session.board)
				print("FEL26 CROP PLAN P3 bbox=", crop)
				ok = crop.has_area() and ok
		else:
			ok = _capture_pair(session, fixture, variant, legacy, output) and ok
		await session.close_fixture()
	print("FEL26 STILLS %s variant=%s cases=%d" % ["PASS" if ok else "FAIL", variant, TAGS.size()])
	session.quit(0 if ok else 1)

func _capture_pair(session: SceneTree, fixture: String, variant: String, legacy: Shader, output: String) -> bool:
	var overlay: Node = session.board.get("_occlusion_silhouettes")
	var shown: Array[Sprite2D]
	for sprite: Sprite2D in overlay.get("_edge_sprites").values():
		if sprite.visible: shown.append(sprite)
	var allowed: PackedByteArray
	if variant != "off": allowed = _project_edges(session, overlay, shown)

	# All readbacks run synchronously during the same SceneTree frame. A
	# zero-length render step also freezes shader TIME. Render signals have
	# game callbacks that read the wall clock even on a paused tree.
	var frame: int = Engine.get_process_frames()
	var was_paused: bool = session.paused
	var was_blocked: bool = RenderingServer.is_blocking_signals()
	session.paused = true
	RenderingServer.set_block_signals(true)
	var variant_image: Image = _frame_now(session)
	var originals: Dictionary = _use_reference_rims(overlay, legacy if variant == "off" else LegacyOutline, variant == "off")
	for sprite: Sprite2D in shown: sprite.hide()
	var reference: Image = _frame_now(session)
	for sprite: Sprite2D in originals: sprite.material = originals[sprite]
	for sprite: Sprite2D in shown: sprite.show()
	var control: Image = _frame_now(session)
	RenderingServer.set_block_signals(was_blocked)
	session.paused = was_paused

	if variant_image == null or reference == null or control == null:
		print("FEL26 CAPTURE FAIL ", fixture, " changed=unavailable bbox=unavailable missing readback")
		return false
	var ok: bool = true
	var stable: Dictionary = _pixel_diff(variant_image, control)
	if stable["changed"] != 0 or Engine.get_process_frames() != frame:
		print("FEL26 SNAPSHOT FAIL %s changed=%d bbox=%s" % [fixture, stable["changed"], stable["bounds"]])
		ok = false
	var diff: Dictionary = _pixel_diff(variant_image, reference, allowed)
	if variant == "off":
		var identical: bool = diff["changed"] == 0
		print("FEL26 OFF PIXELS %s %s changed=%d bbox=%s" % [
			fixture, "PASS" if identical else "FAIL", diff["changed"], diff["bounds"]])
		ok = identical and ok
	else:
		var expected: bool = fixture in ["P3", TODO_DESIGN_P8_CRATE_LOOT_FIXTURE, "P8"] and not shown.is_empty()
		var inside: bool = diff["outside"] == 0 and (diff["changed"] > 0 or not expected)
		print("FEL26 NATIVE DELTA %s %s changed=%d outside=%d bbox=%s outside_bbox=%s" % [
			"PASS" if inside else "FAIL", fixture, diff["changed"], diff["outside"], diff["bounds"], diff["outside_bounds"]])
		ok = inside and ok
	if not ok:
		reference.save_png(output.path_join(STILLS[fixture] + "-reference.png"))
		control.save_png(output.path_join(STILLS[fixture] + "-control.png"))
	var path: String = output.path_join(STILLS[fixture] + ".png")
	if variant_image.save_png(path) != OK: return session.fixture_failure("could not save capture " + path)
	print(path)
	if fixture == "P3" and variant == "always": ok = _write_crop(session.board, output) and ok
	return ok

func _frame_now(session: SceneTree) -> Image:
	RenderingServer.force_draw(false, 0.0)
	RenderingServer.force_sync()
	var image: Image = session.viewport.get_texture().get_image()
	if image == null or image.get_size() != session.SIZE: return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _use_reference_rims(overlay: Node, shader: Shader, all_rims: bool) -> Dictionary:
	var originals: Dictionary = {}
	for entry: Dictionary in overlay.entries.values():
		var sprite: Sprite2D = entry["sprite"]
		var material: ShaderMaterial = sprite.material
		if not all_rims and material.shader == shader: continue
		originals[sprite] = material
		var replacement := ShaderMaterial.new()
		replacement.shader = shader
		for uniform: Dictionary in shader.get_shader_uniform_list():
			var name: String = uniform["name"]
			replacement.set_shader_parameter(name, material.get_shader_parameter(name))
		sprite.material = replacement
	return originals

func _project_edges(session: SceneTree, overlay: Node, shown: Array[Sprite2D]) -> PackedByteArray:
	var permitted := PackedByteArray()
	permitted.resize(session.SIZE.x * session.SIZE.y)
	if shown.is_empty(): return permitted
	var atlas: Texture2D = overlay.get("_edge_atlas")
	var texels: Image = atlas.get_image()
	var projection: Transform2D = session.viewport.get_stretch_transform() * session.board.get_global_transform_with_canvas()
	var sprites: Dictionary = overlay.get("_edge_sprites")
	var viewport_rect := Rect2i(Vector2i.ZERO, session.SIZE)
	for edge: Dictionary in overlay.get("_edges"):
		if not shown.has(sprites[edge["edge_id"]]): continue
		var region: Rect2i = edge["edge_region"]
		var rect: Rect2 = edge["edge_rect"]
		var tile_size: Vector2 = rect.size / Vector2(region.size)
		for y: int in region.size.y:
			for x: int in region.size.x:
				if texels.get_pixelv(region.position + Vector2i(x, y)).a8 == 0: continue
				var pixel: Rect2 = projection * Rect2(rect.position + Vector2(x, y) * tile_size, tile_size)
				var bounds := Rect2i(Vector2i(pixel.position.floor()), Vector2i(pixel.end.ceil() - pixel.position.floor()))
				bounds = bounds.intersection(viewport_rect)
				for sy: int in range(bounds.position.y, bounds.end.y):
					for sx: int in range(bounds.position.x, bounds.end.x): permitted[sy * session.SIZE.x + sx] = 1
	return permitted

static func _pixel_diff(first: Image, second: Image, allowed: PackedByteArray = PackedByteArray()) -> Dictionary:
	var a: PackedByteArray = first.get_data()
	var b: PackedByteArray = second.get_data()
	var width: int = first.get_width()
	var changed: int = 0
	var outside: int = 0
	var bounds := Rect2i()
	var outside_bounds := Rect2i()
	if a != b:
		for pixel: int in width * first.get_height():
			var byte: int = pixel * 4
			if a.decode_u32(byte) == b.decode_u32(byte): continue
			var rect := Rect2i(pixel % width, pixel / width, 1, 1)
			bounds = rect if changed == 0 else bounds.merge(rect)
			changed += 1
			if allowed.is_empty() or allowed[pixel] != 0: continue
			outside_bounds = rect if outside == 0 else outside_bounds.merge(rect)
			outside += 1
	return {"changed": changed, "outside": outside, "bounds": bounds, "outside_bounds": outside_bounds}

static func _pixel_diagnostics_check() -> bool:
	var first := Image.create_empty(4, 3, false, Image.FORMAT_RGBA8)
	var second: Image = first.duplicate()
	# An alpha-only change is still a differing pixel.
	second.set_pixel(1, 0, Color.BLACK)
	second.set_pixel(3, 2, Color.WHITE)
	var allowed := PackedByteArray()
	allowed.resize(12)
	allowed[1] = 1
	var diff: Dictionary = _pixel_diff(first, second, allowed)
	var stable: Dictionary = _pixel_diff(first, first)
	var ok: bool = diff["changed"] == 2 and diff["outside"] == 1 and (
		diff["bounds"] == Rect2i(1, 0, 3, 3) and diff["outside_bounds"] == Rect2i(3, 2, 1, 1) and stable["changed"] == 0)
	print("FEL26 PIXEL DIAGNOSTICS %s changed=%d outside=%d bbox=%s outside_bbox=%s" %
		["PASS" if ok else "FAIL", diff["changed"], diff["outside"], diff["bounds"], diff["outside_bounds"]])
	return ok

func _pillar_crop(board: Control) -> Rect2i:
	var overlay: Node = board.get("_occlusion_silhouettes")
	for edge: Dictionary in overlay.get("_edges"):
		if edge["tile"] != CROP_PILLAR_TILE or edge["category"] != "pillar": continue
		var projection: Transform2D = board.get_viewport().get_stretch_transform() * board.get_global_transform_with_canvas()
		var crop: Rect2 = projection * Rect2(edge["edge_rect"])
		var start := Vector2i(crop.position.floor())
		return Rect2i(start, Vector2i(crop.end.ceil()) - start)
	return Rect2i()

func _write_crop(board: Control, output: String) -> bool:
	var crop: Rect2i = _pillar_crop(board)
	if not crop.has_area(): return false
	var file := FileAccess.open(output.path_join("P3-crop.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify([crop.position.x, crop.position.y, crop.end.x, crop.end.y]))
	return true
