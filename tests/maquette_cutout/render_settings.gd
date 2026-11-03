extends RefCounted

# Production's root window uses project.godot's 4x MSAA; the renderer creates
# bare SubViewports (MSAA disabled). Other 2D settings retain engine defaults.
const PRODUCTION_MSAA_2D: int = Viewport.MSAA_4X
const PRODUCTION_OFFSCREEN_MSAA_2D: int = Viewport.MSAA_DISABLED
const PRODUCTION_FILTER: int = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
const PRODUCTION_REPEAT: int = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_REPEAT_DISABLED
const PRODUCTION_HDR_2D: bool = false
const PRODUCTION_SNAP_TRANSFORMS: bool = false
const PRODUCTION_SNAP_VERTICES: bool = false

static func apply(viewport: Viewport) -> void:
	viewport.msaa_2d = PRODUCTION_OFFSCREEN_MSAA_2D if viewport is SubViewport else PRODUCTION_MSAA_2D
	viewport.canvas_item_default_texture_filter = PRODUCTION_FILTER
	viewport.canvas_item_default_texture_repeat = PRODUCTION_REPEAT
	viewport.use_hdr_2d = PRODUCTION_HDR_2D
	viewport.snap_2d_transforms_to_pixel = PRODUCTION_SNAP_TRANSFORMS
	viewport.snap_2d_vertices_to_pixel = PRODUCTION_SNAP_VERTICES
	assert(matches(viewport), "Rig proof viewport differs from pinned production rendering settings")

static func matches(viewport: Viewport) -> bool:
	var msaa: int = PRODUCTION_OFFSCREEN_MSAA_2D if viewport is SubViewport else PRODUCTION_MSAA_2D
	return (viewport.msaa_2d == msaa
		and viewport.canvas_item_default_texture_filter == PRODUCTION_FILTER
		and viewport.canvas_item_default_texture_repeat == PRODUCTION_REPEAT
		and viewport.use_hdr_2d == PRODUCTION_HDR_2D
		and viewport.snap_2d_transforms_to_pixel == PRODUCTION_SNAP_TRANSFORMS
		and viewport.snap_2d_vertices_to_pixel == PRODUCTION_SNAP_VERTICES)
