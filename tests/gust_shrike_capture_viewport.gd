extends RefCounted

## Capture geometry is independent of Retina desktop/window constraints.
const SIZE := Vector2i(1920, 1080)

static func create(parent: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	return viewport
