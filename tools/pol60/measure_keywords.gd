extends SceneTree

const Layout = preload("res://tools/pol60/keyword_layout.gd")
const SIZE := Vector2i(1920, 1080)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	root.add_child(viewport)
	await Layout.sweep(viewport)
	quit()
