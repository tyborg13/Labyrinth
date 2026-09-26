extends "res://tests/ui_probe.gd"

# Focused production surfaces. SubViewport guarantees authored pixels even on a
# desktop whose usable window height is smaller than the review canvas.
const MATERIAL_OUTPUT: String = "user://probes/material_polish_v1"
var _material_failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://material_settings.json")
	ProgressionStore.set_storage_path("user://material_progression.json")
	ProgressionStore.set_run_storage_path("user://material_run.save")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = Vector2i(1920, 1080)
	_proof_viewport.msaa_2d = Viewport.MSAA_4X
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_proof_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_proof_viewport.add_child(instance)
	await create_timer(0.2).timeout
	instance.call("_load_run_state", RunEngine.new().create_new_run(123, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await create_timer(0.2).timeout
	await _capture_grimoire_snapshot(instance, MATERIAL_OUTPUT.path_join("01_grimoire_card.png"), "magick:pale_spark")
	await _capture_grimoire_snapshot(instance, MATERIAL_OUTPUT.path_join("02_grimoire_rules.png"), "combat:fatigue")
	await _capture_grimoire_snapshot(instance, MATERIAL_OUTPUT.path_join("03_grimoire_equipment.png"), "equipment:training_sword")
	instance.call("_open_menu_overlay")
	await create_timer(0.3).timeout
	await _material_capture("04_menu.png")
	var menu: Control = instance.get("_menu_dialog") as Control
	var original_rect: Rect2 = menu.get_global_rect()
	var finish: Node2D = menu.get_node_or_null("SurfaceFinish") as Node2D
	_require_material(finish != null, "Production menu should receive the retained finish")
	if finish != null:
		finish.visible = false
	await process_frame
	_require_material(menu.get_global_rect() == original_rect, "Material visibility must not affect panel layout")
	if finish != null:
		finish.visible = true
	var buttons: Array[Node] = menu.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		var button: Button = buttons[0] as Button
		button.grab_focus()
		await create_timer(0.35).timeout
		_require_material(button.has_focus(), "Material nodes must not intercept focus")
		await _material_capture("05_menu_focus.png")
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	instance.set("_settings", settings)
	await create_timer(0.35).timeout
	await _material_capture("06_menu_reduced.png")
	instance.call("_close_menu_overlay")
	await process_frame
	var source := preload("res://scripts/ui_tooltip_button.gd").new()
	var tooltip: Control = source.call("_make_custom_tooltip", "QUICK WITS\nOnce per combat, discard a card to gain @icon(draw) 1. Costs no @icon(card_play) or @icon(time).") as Control
	_require_material(tooltip != null, "Production tooltip should build")
	if tooltip != null:
		tooltip.position = Vector2(760.0, 430.0)
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		_proof_viewport.add_child(overlay)
		overlay.add_child(tooltip)
		await process_frame
		await process_frame
		_require_material(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(tooltip.get_global_rect()), "Tooltip must fit the authored canvas")
		await _material_capture("07_tooltip.png")
		tooltip.queue_free()
	source.free()
	instance.queue_free()
	await process_frame
	for failure: String in _material_failures:
		push_error(failure)
	print("MATERIAL POLISH PROBE: %s" % ("PASS" if _material_failures.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	quit(0 if _material_failures.is_empty() else 1)

func _material_capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = _proof_viewport.get_texture().get_image()
	_require_material(pixels.get_size() == Vector2i(1920, 1080), "Proof must use 1920x1080 at 100% UI scale")
	_require_material(pixels.save_png(MATERIAL_OUTPUT.path_join(filename)) == OK, "Screenshot must save")

func _require_material(ok: bool, message: String) -> void:
	if not ok:
		_material_failures.append(message)
