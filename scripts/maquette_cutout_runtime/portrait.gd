extends RefCounted

## Reuse the exact board renderer inside existing UI geometry. The atlas trims
## only its transparent action-canvas padding; no second art/animation pipeline.
const Presentation = preload("presentation.gd")
const Renderer = preload("renderer.gd")
const Assets = preload("res://scripts/asset_loader.gd")

static func rest_path(type: String) -> String:
	return "res://assets/units/" + str(Presentation.CREATURES[type]) + "_cutout/front/rest.png"

static func bind(portrait: TextureRect, type: String, reduced: bool, crop_to_paint: bool = false) -> void:
	if not Presentation.handles(type) or portrait.has_node("MaquettePortraitRenderer"): return
	var renderer := Renderer.new()
	renderer.name = "MaquettePortraitRenderer"
	renderer.character_id = Presentation.CREATURES[type]
	var rest: Texture2D = Assets.load_texture_source_first(rest_path(type))
	var used: Rect2i = Assets.texture_used_rect(rest)
	var region := Rect2(Renderer.SOURCE_OFFSET, Renderer.SOURCE_SIZE)
	if crop_to_paint:
		region = Rect2(Renderer.SOURCE_OFFSET + Vector2(used.position), Vector2(used.size))
	var install: Callable = func() -> void:
		var atlas := AtlasTexture.new()
		atlas.atlas = renderer.texture()
		atlas.region = region
		atlas.set_meta("asset_source_path", rest_path(type))
		Assets.cache_texture_used_rect(atlas, Rect2i(Vector2i.ZERO, used.size) if crop_to_paint else used)
		portrait.texture = atlas
		# Slots are often built outside the tree. Their deferred child ready
		# must also update the retained defeat shader source to the live atlas.
		var host: Node = portrait.get_parent()
		while host != null:
			if host.has_meta("turn_order_portrait_texture"):
				host.set_meta("turn_order_portrait_texture", atlas)
				break
			host = host.get_parent()
		renderer.present({}, reduced)
	renderer.ready.connect(install, CONNECT_ONE_SHOT)
	portrait.add_child(renderer)
