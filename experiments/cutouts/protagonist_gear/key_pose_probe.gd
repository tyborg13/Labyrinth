extends SceneTree

const Viewer = preload("res://tools/cutout_pipeline/viewer.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const BASE := "res://experiments/cutouts/protagonist_gear/"
const OUTPUT := "user://probes/protagonist_gear_keys"
var surface: SubViewport
var manifest: Array = []
var failures: Array[String]
var source_hashes: Dictionary = {}


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.set_storage_path("user://gear_motion_study_settings.json")
	Settings.save_settings(settings)
	call_deferred("_run")


func _run() -> void:
	root.size = SIZE
	surface = SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var studies: Dictionary = {
		"heavy_v01": {"attack_heavy": [0.0, 0.12, 0.30, 0.36, 0.42, 0.48, 0.58, 0.72, 0.90, 1.0]},
		"stab_v01": {"attack_stab": [0.0, 0.30, 0.42, 0.54, 0.90]},
		"shield_v01": {"block_shield": [0.0, 0.14, 0.25, 0.32], "cast": [0.42], "shoot": [0.42], "walk": [0.15, 0.65], "hit": [0.15], "attack": [0.42]},
	}
	for case_name: String in studies:
		var case_directory: String = BASE + case_name + "/"
		for input: String in ["cutout.json", "motion.gd", "layouts/front.json", "layouts/rear.json"]:
			source_hashes[case_name + "/" + input] = FileAccess.get_sha256(case_directory + input)
		var viewer := Viewer.new()
		viewer.case_file = ProjectSettings.globalize_path(BASE + case_name + "/cutout.json")
		viewer.size = Vector2(SIZE)
		surface.add_child(viewer)
		viewer.set_playing(false)
		await viewer.bake_references()
		for facing: String in ["front", "rear"]:
			for clip: String in studies[case_name]:
				viewer.select(facing, clip)
				for phase: float in studies[case_name][clip]:
					viewer.rig.apply_pose(clip, phase)
					if clip == "walk":
						var info: Dictionary = viewer.rig.sampler.walk_cycle_info(viewer.rig.layout, facing)
						viewer.board.presentation["puppet_travel_source_px"] = Vector2(info["travel_per_cycle"]) * phase
						viewer.board._rebuild_hud_health_rects_cache()
						viewer.board._sync_dynamic_render_state(false, false, ["presentation", "_hud_health_rects_cache", "_hud_layout_entries_cache"])
						viewer.board._queue_dynamic_redraw()
					viewer.status.text = "%s • %s • authored phase %.2f • 100%% UI scale" % [facing, clip, phase]
					var folder: String = OUTPUT.path_join(case_name)
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
					var file: String = "%s_%s_%03d" % [facing, clip, roundi(phase * 100)]
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var pose: Image = viewer.puppet.get_texture().get_image()
					var board: Image = surface.get_texture().get_image()
					_check(pose.get_size() == Vector2i(512, 512) and board.get_size() == SIZE, "Exact SubViewport capture sizes")
					_check(pose.save_png(folder.path_join(file + "_pose.png")) == OK, "Save native key pose")
					_check(board.save_png(folder.path_join(file + "_board.png")) == OK, "Save 1920x1080 board key")
					manifest.append({"case": case_name, "facing": facing, "clip": clip, "phase": phase, "file": file})
		viewer.queue_free()
		await process_frame
	for input: String in source_hashes:
		_check(FileAccess.get_sha256(BASE + input) == source_hashes[input], "Case source changed during key capture")
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "source_sha256": source_hashes, "phase_basis": "exact authored phase, no frame snapping", "keys": manifest, "errors": failures}, "\t"))
	file.close()
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("GEAR_KEY_POSE_PROBE: " + ("PASS" if failures.is_empty() else "FAIL") + " (50 exact-phase native poses and 1920x1080 board captures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
