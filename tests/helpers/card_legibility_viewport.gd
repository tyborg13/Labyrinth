extends RefCounted

# Match opening_boon_probe/pre_battle_fixture and rr37/native_capture: render
# native proof pixels in a SubViewport, independently of the Retina window.
const SIZE := Vector2i(1920, 1080)
const RETINA_REGRESSION_SIZE := Vector2i(3024, 1898)
const PRESENTATION_LAYER: int = 128

static func create(tree: SceneTree, present: bool = false) -> SubViewport:
	tree.root.mode = Window.MODE_WINDOWED
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	tree.root.content_scale_size = SIZE
	tree.root.content_scale_factor = 1.0
	tree.root.size = SIZE
	if DisplayServer.get_name().to_lower() != "headless": DisplayServer.window_set_size(SIZE)
	var viewport := SubViewport.new()
	viewport.name = "CardLegibilityProofViewport"
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	if present:
		var layer := CanvasLayer.new()
		layer.layer = PRESENTATION_LAYER
		tree.root.add_child(layer)
		var preview := TextureRect.new()
		preview.texture = viewport.get_texture()
		preview.size = Vector2(SIZE)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(preview)
		viewport.set_meta("presentation", layer)
	return viewport

static func image_matches(image: Image) -> bool:
	return image != null and image.get_width() == SIZE.x and image.get_height() == SIZE.y

static func verify(tree: SceneTree, viewport: SubViewport, expect: Callable) -> void:
	expect.call(viewport.size == SIZE and viewport.msaa_2d == Viewport.MSAA_4X, "Proof uses the existing native 1920x1080 SubViewport/MSAA setup")
	expect.call(tree.root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and tree.root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and tree.root.content_scale_factor == 1.0, "Proof window uses canvas-items/keep at 100% UI scale")
	if DisplayServer.get_name().to_lower() == "headless":
		var old_size: Vector2i = tree.root.size
		tree.root.size = RETINA_REGRESSION_SIZE
		expect.call(viewport.size == SIZE and viewport.get_visible_rect().size == Vector2(SIZE), "Retina window resizing cannot resize the captured viewport")
		tree.root.size = old_size
	# CPU-only image fixtures; no headless renderer readback or PNG generation.
	expect.call(image_matches(Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)), "Exact native proof dimensions are accepted")
	expect.call(not image_matches(Image.create_empty(RETINA_REGRESSION_SIZE.x, RETINA_REGRESSION_SIZE.y, false, Image.FORMAT_RGBA8)), "Retina-sized proof images are rejected")

static func dispose(viewport: SubViewport) -> void:
	if viewport.has_meta("presentation"): viewport.get_meta("presentation").free()
	viewport.free()
