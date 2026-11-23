extends RefCounted
## Use the exact candidate 4 shader with the live fixture's inputs.

const Art = preload("res://scripts/combat_art_treatment.gd")
const Pixels = preload("pixels.gd")
const BASE_SHADER: String = "res://.godot/fx38_base_art.gdshader"
const KINDLE_INCLUDE: String = "res://assets/shaders/kindle_cracks.gdshaderinc"

static func check_inactive_source() -> bool:
	var base: String = FileAccess.get_file_as_string(BASE_SHADER)
	var live: String = Art.SHADER.code.replace('#include "%s"\n' % KINDLE_INCLUDE, "")
	live = live.replace("\tkindle_gain = kindle_strength(art_profile);\n\tart_profile = kindle_art_profile(art_profile);\n", "")
	live = live.replace("vec4 texel = texture(TEXTURE, UV);\n\tvec4 source = texel;", "vec4 source = texture(TEXTURE, UV);")
	live = live.replace("\tKINDLE_BOOST(source, texel, UV, TEXTURE_PIXEL_SIZE)\n", "")
	var include: String = FileAccess.get_file_as_string(KINDLE_INCLUDE)
	var below_twelve: bool = include.contains(
		"if (profile >= 12.0) { return kindle_strengths.x; }\n\treturn 0.0;\n}") and include.contains(
		"if (profile >= 12.0) { return profile - 8.0; }\n\treturn profile;\n}") and include.contains(
		"if (kindle_gain > 0.0 && (texel).a > 0.0)")
	var ok: bool = not base.is_empty() and base == live and below_twelve
	print("FX-38 BASE SOURCE %s (profiles 0-11: same sampling, grading and output, zero Kindle gain)" % ["PASS" if ok else "FAIL"])
	return ok

static func material_for(board: Control, live: ShaderMaterial) -> ShaderMaterial:
	var baseline := Shader.new()
	baseline.code = FileAccess.get_file_as_string(BASE_SHADER)
	var material := ShaderMaterial.new()
	material.shader = baseline
	board._art_treatment.apply_to(material)
	material.set_shader_parameter("art_light_flicker", live.get_shader_parameter("art_light_flicker"))
	return material

static func check_floor(tree: SceneTree, board: Control) -> bool:
	var cache: SubViewport = board._static_render_cache_viewport
	var layer: Control = board._static_render_cache_layer
	if cache == null or layer == null or not board._static_render_cache_texture.visible: return false
	var live: ShaderMaterial = layer.material
	var base: ShaderMaterial = material_for(board, live)
	var updated: Image = await _rebake(tree, cache)
	layer.material = base
	var original: Image = await _rebake(tree, cache)
	layer.material = live
	await _rebake(tree, cache)
	if original == null or not original.get_used_rect().has_area(): return false
	return Pixels.identical("live floor bake", original, updated)

static func _rebake(tree: SceneTree, cache: SubViewport) -> Image:
	await tree.process_frame
	cache.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return cache.get_texture().get_image()
