extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
# Point at an already generated and verified isolated inspection fixture.
# The probe copies it privately, so capture never spends the playable opening.
var viewport: SubViewport
var scene: Node

func _initialize() -> void:
	var source_directory: String = OS.get_environment("LABYRINTH_INSPECTION_SOURCE")
	assert(not source_directory.is_empty(), "Set LABYRINTH_INSPECTION_SOURCE to the verified fixture user directory")
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_run_storage_path("user://inspection_run.save")
	Store.set_storage_path("user://inspection_profile.json")
	assert(DirAccess.copy_absolute(source_directory.path_join("current_run.save"), ProjectSettings.globalize_path("user://inspection_run.save")) == OK)
	assert(DirAccess.copy_absolute(source_directory.path_join("progression.json"), ProjectSettings.globalize_path("user://inspection_profile.json")) == OK)
	Settings.set_storage_path("user://inspection_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_2d = Viewport.MSAA_4X
	root.add_child(viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await create_timer(0.5).timeout
	assert(str((scene.get("_run_state") as Dictionary).get("mode")) == "combat")
	assert(((scene.get("_combat_state") as Dictionary).get("deck") as Dictionary).get("hand").size() == 7)
	await capture("00_inspection_start")
	await scene.call("_on_card_pressed", 0)
	scene.set("_hovered_board_tile", Vector2i(4, 4))
	scene.call("_refresh_stage_view")
	await capture("01_push_decision")
	await scene.call("_on_board_cancel_requested")
	await scene.call("_on_card_pressed", 6)
	scene.set("_hovered_board_tile", Vector2i(6, 4))
	scene.call("_refresh_stage_view")
	await capture("02_conduction_decision")
	await scene.call("_on_board_cancel_requested")
	scene.call("_begin_surface_skill_selection", "prismatic_instinct")
	await capture("03_ability_choice")
	await scene.call("_on_board_cancel_requested")
	assert(not (scene.get("_surface_aim") as RefCounted).call("active"))
	await capture("04_cancelled_without_payment")
	print("INSPECTION NATIVE PROBE: PASS")
	viewport.queue_free()
	await process_frame
	quit()

func capture(label: String) -> void:
	for frame: int in range(12): await process_frame
	if int(scene.get("_selected_card_index")) >= 0:
		var target: Vector2i = scene.get("_hovered_board_tile")
		if target.x >= 0:
			scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", target))
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("user://probes/inspection")
	DirAccess.make_dir_recursive_absolute(folder)
	var screenshot: Image = viewport.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(folder.path_join(label + ".png")) == OK)
