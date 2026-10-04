extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Atmosphere = preload("res://scripts/scavenger_atmosphere.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	var first := Atmosphere.new()
	var second := Atmosphere.new()
	check(first.get("_lantern_pool") == second.get("_lantern_pool") and first.get("_vignette") == second.get("_vignette"), "Atmosphere instances share both gradient textures")
	var pool: GradientTexture2D = first.get("_lantern_pool") as GradientTexture2D
	var vignette: GradientTexture2D = first.get("_vignette") as GradientTexture2D
	check(pool != null and pool.gradient.get_color(0) == Color(0.78, 0.45, 0.20, 0.16) and is_equal_approx(pool.gradient.get_offset(1), 0.9), "Cached lantern pool retains its authored colors and falloff")
	check(vignette != null and vignette.width == 512 and vignette.height == 512 and vignette.gradient.get_color(2) == Color(0.018, 0.012, 0.010, 0.28), "Cached vignette retains its size and edge tint")
	first.free()
	second.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	var tag := PriceTag.new()
	tag.amount = 175
	tag.size = Vector2(118, 60)
	viewport.add_child(tag)
	await process_frame
	var artwork: TextureRect = tag.get_node("HangingPriceTagArt") as TextureRect
	check(artwork.texture == Surface.mipmapped_texture(PriceTag.TAG_PATH), "Price tag uses the shared texture cache")
	check(artwork.texture.get_image().has_mipmaps() and artwork.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "Price tag minification has a real mip chain and preserves detail under uneven scaling")
	check((tag.find_child("PriceTagValue", true, false) as Label).text == "175", "Resource changes preserve the exact price")
	viewport.free()
	print("SCAVENGER RESOURCE CACHE TEST: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
