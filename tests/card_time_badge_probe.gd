extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://probes")
	var background := ColorRect.new()
	background.color = Color("20170f")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root.add_child(background)
	var slot := Control.new()
	slot.position = Vector2(86.0, 70.0)
	slot.custom_minimum_size = Vector2(250.0, 352.0)
	slot.size = Vector2(250.0, 352.0)
	root.add_child(slot)
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = Vector2(250.0, 352.0)
	widget.size = Vector2(250.0, 352.0)
	slot.add_child(widget)
	await process_frame
	widget.configure("quick_stab")
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		widget.call("_on_local_mouse_entered")
		await create_timer(0.12).timeout
		widget.call("_on_local_mouse_exited")
		print("card time badge probe: headless renderer, screenshot skipped")
		slot.queue_free()
		background.queue_free()
		await process_frame
		quit()
		return
	var stamp: int = int(Time.get_unix_time_from_system())
	var idle_path: String = "user://probes/card_time_badge_idle_%d.png" % stamp
	_save_card_screenshot(idle_path, widget)
	widget.call("_on_local_mouse_entered")
	await create_timer(0.30).timeout
	await process_frame
	var hover_path: String = "user://probes/card_time_badge_hover_%d.png" % stamp
	_save_card_screenshot(hover_path, widget)
	print(ProjectSettings.globalize_path(idle_path))
	print(ProjectSettings.globalize_path(hover_path))
	slot.queue_free()
	background.queue_free()
	await process_frame
	quit()

func _save_card_screenshot(output_path: String, widget: CardWidget) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image = _crop_to_control(image, widget, 22.0)
	image.save_png(output_path)

func _crop_to_control(image: Image, control: Control, padding: float) -> Image:
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return image
	var scale := Vector2(float(image.get_width()) / viewport_rect.size.x, float(image.get_height()) / viewport_rect.size.y)
	var control_rect: Rect2 = control.get_global_rect().grow(padding)
	var crop_rect := Rect2i(
		Vector2i(
			maxi(0, int(floor(control_rect.position.x * scale.x))),
			maxi(0, int(floor(control_rect.position.y * scale.y)))
		),
		Vector2i(
			int(ceil(control_rect.size.x * scale.x)),
			int(ceil(control_rect.size.y * scale.y))
		)
	)
	crop_rect.size.x = mini(crop_rect.size.x, image.get_width() - crop_rect.position.x)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return image
	return image.get_region(crop_rect)
