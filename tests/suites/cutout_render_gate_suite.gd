extends RefCounted

const Gate = preload("res://scripts/cutout_render_gate.gd")
const FIXTURE_VIEWPORT_SIZE := Vector2i(64, 64)

static func run(tree: SceneTree, expect: Callable) -> void:
	var viewport := SubViewport.new()
	viewport.size = FIXTURE_VIEWPORT_SIZE
	var rig := Node2D.new()
	viewport.add_child(rig)
	tree.root.add_child(viewport)
	var gate := Gate.new(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	gate._before_draw()
	expect.call(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "A fresh cutout pose still requests its original render")
	gate._before_draw()
	expect.call(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "An identical cutout pose still suppresses its redundant render")
	rig.position = Vector2.ONE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	gate._before_draw()
	expect.call(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "A changed cutout pose still requests a render")
	tree.root.remove_child(viewport)
	expect.call(not RenderingServer.frame_pre_draw.is_connected(gate._before_draw) and not tree.node_added.is_connected(gate._node_added), "Cutout teardown disconnects the original global subscriptions")
	expect.call(not viewport.tree_exiting.is_connected(gate._disconnect) and not viewport.size_changed.is_connected(gate.invalidate_geometry), "The exited viewport cannot call its disposed gate on a later exit")
	gate._disconnect()
	tree.root.add_child(viewport)
	viewport.free()
	gate._disconnect()
	expect.call(gate.get("_viewport") == null and gate.get("_scene_tree") == null, "Repeated teardown and detach/re-enter/free retain no viewport or tree")
