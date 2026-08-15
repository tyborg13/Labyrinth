extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/card_role_emblems"
const SAMPLES: Array = [
	{"card": "quick_stab", "label": "SPARSE MELEE"},
	{"card": "bone_dart", "label": "SPARSE RANGED"},
	{"card": "brace", "label": "BLOCK"},
	{"card": "shadow_step", "label": "ILLUSION"},
	{"card": "dawnstep", "label": "MOBILITY"},
	{"card": "spark_focus", "label": "DENSE RIDERS"},
]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	var background := ColorRect.new()
	background.color = Color("17110d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root.add_child(background)
	var heading := Label.new()
	heading.text = "CARD ROLE EMBLEMS — ACTUAL-SIZE CARDWIDGETS"
	heading.position = Vector2(0.0, 72.0)
	heading.size = Vector2(1920.0, 42.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("d9c29b"))
	heading.add_theme_color_override("font_outline_color", Color("0d0805"))
	heading.add_theme_constant_override("outline_size", 3)
	root.add_child(heading)
	var widgets: Array = []
	var card_width: float = 250.0
	var gap: float = 42.0
	var row_width: float = float(SAMPLES.size()) * card_width + float(SAMPLES.size() - 1) * gap
	var start_x: float = (1920.0 - row_width) * 0.5
	for index: int in range(SAMPLES.size()):
		var sample: Dictionary = SAMPLES[index]
		var card_id: String = str(sample.get("card", ""))
		var position := Vector2(start_x + float(index) * (card_width + gap), 178.0)
		var label := Label.new()
		label.text = str(sample.get("label", ""))
		label.position = position + Vector2(0.0, -35.0)
		label.size = Vector2(card_width, 26.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color("c9ad80"))
		root.add_child(label)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.position = position
		widget.custom_minimum_size = Vector2(250.0, 352.0)
		widget.size = Vector2(250.0, 352.0)
		root.add_child(widget)
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		widgets.append(widget)
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("Card role emblem probe requires a real renderer.")
		quit(1)
		return
	var stamp: int = int(Time.get_unix_time_from_system())
	var viewport_image: Image = root.get_viewport().get_texture().get_image()
	var overview_image: Image = viewport_image.duplicate()
	overview_image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var overview_path: String = "%s/card_role_emblems_overview_%d.png" % [OUTPUT_DIR, stamp]
	overview_image.save_png(overview_path)
	print(ProjectSettings.globalize_path(overview_path))
	for index: int in range(widgets.size()):
		var sample: Dictionary = SAMPLES[index]
		var card_id: String = str(sample.get("card", ""))
		var card_image: Image = _crop_to_control(viewport_image, widgets[index] as Control)
		card_image.resize(250, 352, Image.INTERPOLATE_LANCZOS)
		var card_path: String = "%s/card_role_emblem_%s_%d.png" % [OUTPUT_DIR, card_id, stamp]
		card_image.save_png(card_path)
		print(ProjectSettings.globalize_path(card_path))
	quit()

func _crop_to_control(image: Image, control: Control) -> Image:
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	var image_scale := Vector2(float(image.get_width()) / viewport_rect.size.x, float(image.get_height()) / viewport_rect.size.y)
	var control_rect: Rect2 = control.get_global_rect()
	var crop_rect := Rect2i(
		Vector2i(int(round(control_rect.position.x * image_scale.x)), int(round(control_rect.position.y * image_scale.y))),
		Vector2i(int(round(control_rect.size.x * image_scale.x)), int(round(control_rect.size.y * image_scale.y)))
	)
	return image.get_region(crop_rect)

func _clear_probe_output(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".png"):
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
