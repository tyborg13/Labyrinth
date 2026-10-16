extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport: SubViewport = create_viewport(root)
	viewport.add_child(load("res://tools/demo_clips/demo_clip.tscn").instantiate())

static func create_viewport(host: Viewport) -> SubViewport:
	# Root-window textures follow native backing size on HiDPI displays. Keep
	# probe rendering/input coordinates independent of that window's pixels.
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = false
	host.add_child(container)
	var viewport := SubViewport.new()
	viewport.name = "DemoProbeViewport"
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_2d = host.msaa_2d
	container.add_child(viewport)
	return viewport
