extends RefCounted
## Borrows loaded game resources. In particular, ResourceLoader.load() can
## wait for a threaded dependency even when the warmer only wants a reference.

const UiTypography = preload("res://scripts/ui_typography.gd")
const Recipes = preload("res://scripts/canvas_pipeline_recipes.gd")
const Geometry = preload("res://scripts/canvas_pipeline_geometry.gd")
const SAMPLE_IMAGE_SIZE := Vector2i(24, 24)

static func build(recipe: Dictionary, sample_texture: Texture2D, draw_witness: Callable = Callable()) -> CanvasItem:
	var path: String = recipe.get("path", "")
	var resource: Resource = ResourceLoader.get_cached_ref(path) if not path.is_empty() else null
	if not path.is_empty() and resource == null: return null
	var shape: String = recipe.get("draw", "texture_rect")
	var source: Resource
	if recipe.has("source"):
		source = ResourceLoader.get_cached_ref(recipe["source"])
		if source == null: return null

	var sample: CanvasItem
	match shape:
		"surface":
			var particle: MeshInstance2D = resource.new()
			particle.configure(Geometry.BOX.get_center(), Geometry.BOX.size, 0.0, Color.WHITE)
			particle.texture = sample_texture
			Geometry.witness_mesh(particle, draw_witness)
			return particle
		"electric":
			return Geometry.electric(resource, draw_witness)
		"banner":
			var font := ResourceLoader.get_cached_ref(UiTypography.DISPLAY_FONT_PATH) as Font
			if font == null: return null
			var label := Label.new()
			label.text = Recipes.COVER_MESSAGE + "..."
			label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
			label.add_theme_font_override("font", font)
			UiTypography.set_label_size(label, UiTypography.role_size(UiTypography.ROLE_BANNER))
			label.add_theme_constant_override("outline_size", Recipes.COVER_OUTLINE_SIZE)
			if draw_witness.is_valid():
				label.draw.connect(func() -> void:
					draw_witness.call("glyph_quads", {"msdf": font.multichannel_signed_distance_field, "outline": label.get_theme_constant("outline_size") > 0}))
			sample = label
		_:
			sample = Geometry.build(shape, sample_texture, draw_witness)
	if recipe.has("blend"):
		var canvas_material := CanvasItemMaterial.new()
		canvas_material.blend_mode = recipe["blend"]
		sample.material = canvas_material
	elif resource != null:
		var shader: Shader = resource as Shader
		if recipe.has("factory"):
			shader = resource.call(recipe["factory"], source) if source != null else resource.call(recipe["factory"])
		var shader_material := ShaderMaterial.new()
		shader_material.shader = shader
		if recipe.get("factory") == "portrait_shader":
			shader_material.set_shader_parameter("coverage", sample_texture)
			shader_material.set_shader_parameter("coverage_bit", 1)
		sample.material = shader_material
	return sample

static func texture_for_samples() -> ImageTexture:
	var image := Image.create_empty(SAMPLE_IMAGE_SIZE.x, SAMPLE_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
