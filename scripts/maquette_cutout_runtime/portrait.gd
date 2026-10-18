extends RefCounted

## Reuse the exact board renderer inside existing UI geometry. The atlas trims
## only its transparent action-canvas padding; no second art/animation pipeline.
const Presentation = preload("presentation.gd")
const Renderer = preload("renderer.gd")
const Assets = preload("res://scripts/asset_loader.gd")

static func rest_path(type: String) -> String:
	return Presentation.asset_directory(type).path_join("front/rest.png")

## Also used by LiveActor's source TextureRect: retain the approved 255px
## source canvas and opaque bounds without creating a second live renderer.
static func source_texture(renderer: Node, type: String, crop_to_paint: bool = false) -> AtlasTexture:
	var rest: Texture2D = Assets.load_texture_source_first(rest_path(type))
	var used: Rect2i = Assets.texture_used_rect(rest)
	var atlas := AtlasTexture.new()
	atlas.atlas = renderer.texture()
	atlas.region = Rect2(Renderer.SOURCE_OFFSET + Vector2(used.position), Vector2(used.size)) if crop_to_paint else Rect2(Renderer.SOURCE_OFFSET, Renderer.SOURCE_SIZE)
	atlas.set_meta("asset_source_path", rest_path(type))
	Assets.cache_texture_used_rect(atlas, Rect2i(Vector2i.ZERO, used.size) if crop_to_paint else used)
	return atlas

static func bind(portrait: TextureRect, type: String, reduced: bool, crop_to_paint: bool = false) -> void:
	if not Presentation.handles(type) or portrait.has_node("MaquettePortraitRenderer"): return
	var renderer: Node = Presentation.renderer_script(type).new()
	renderer.name = "MaquettePortraitRenderer"
	var install: Callable = func() -> void:
		var atlas: AtlasTexture = source_texture(renderer, type, crop_to_paint)
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
