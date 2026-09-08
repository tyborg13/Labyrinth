extends SceneTree

const Viewer = preload("res://tools/cutout_pipeline/viewer.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/cutout_workflow"
var viewer: Viewer
var surface: SubViewport
var failures: Array[String] = []
var manifest: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "clips": [], "roundtrip": [], "errors": []}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.set_storage_path("user://cutout_workflow_settings.json")
	Settings.save_settings(settings)
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var case_index: int = arguments.find("--case")
	if case_index < 0 or case_index + 1 >= arguments.size():
		push_error("Use -- --case /absolute/path/cutout.json [--interactive]")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	surface = SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	viewer = Viewer.new()
	viewer.case_file = arguments[case_index+1]
	viewer.size = Vector2(SIZE)
	surface.add_child(viewer)
	if not viewer.rig.load_errors.is_empty():
		quit(1)
		return
	await viewer.bake_references()
	if arguments.has("--interactive"):
		# Forward input through the actual SubViewportContainer during inspection.
		root.remove_child(surface)
		var container := SubViewportContainer.new()
		container.size = Vector2(SIZE)
		root.add_child(container)
		container.add_child(surface)
		viewer.set_playing(true)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	manifest["character_id"] = viewer.rig.config["character_id"]
	manifest["case_file"] = viewer.case_file
	manifest["timing_basis"] = "sampled native poses at case-declared playback duration; character study, not real-action gameplay capture"
	for facing: String in viewer.rig.config["layouts"]:
		viewer.select(facing, viewer.animation)
		var rest: Image = viewer.rest_cache[facing].get_image()
		_check(rest.save_png(OUTPUT.path_join(facing + "_rest.png")) == OK, "Save assembled rest")
		var scene_path: String = OUTPUT.path_join(facing + ".tscn")
		_check(viewer.rig.save_editable(scene_path) == OK, "Save editable scene")
		for clip_name: String in viewer.rig.config["clips"]:
			viewer.select(facing, clip_name)
			var specification: Dictionary = viewer.rig.config["clips"][clip_name]
			var frame_count: int = int(specification["frames"])
			var count: int = viewer.timeline_frames()
			var folder: String = facing + "_" + clip_name
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
			var clip_record: Dictionary = {"facing": facing, "clip": clip_name, "folder": folder, "frames": count, "cycle_frames": frame_count, "frame_seconds": float(specification["duration"]) / float(frame_count), "poses": []}
			var anchors: Dictionary = {}
			for index: int in range(count):
				viewer.show_frame(index)
				_check(viewer.rig.load_errors.is_empty(), "Rig or travel contract failed: " + str(viewer.rig.load_errors))
				await _draw()
				var pose_image: Image = viewer.puppet.get_texture().get_image()
				var bounds: Rect2i = pose_image.get_used_rect()
				_check(bounds.has_area() and bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, "Pose clips the action canvas: " + folder + "/" + str(index))
				var board_image: Image = surface.get_texture().get_image()
				_check(board_image.save_jpg(OUTPUT.path_join(folder).path_join("board_%04d.jpg" % index), 0.95) == OK, "Save board frame")
				if index < frame_count:
					_check(pose_image.save_png(OUTPUT.path_join(folder).path_join("pose_%04d.png" % index)) == OK, "Save pose frame")
					clip_record["poses"].append(_measure(clip_name, index, anchors))
					viewer.rig.set_slot_visible("cloak", false)
					await _draw()
					_check(viewer.puppet.get_texture().get_image().save_png(OUTPUT.path_join(folder).path_join("pose_without_cloak_%04d.png" % index)) == OK, "Save exposed cycle pose")
					viewer.rig.set_slot_visible("cloak", true)
				if index in [0, frame_count / 2, count - 1]:
					_check(board_image.save_png(OUTPUT.path_join(folder + "_%04d.png" % index)) == OK, "Save full board proof")
			manifest["clips"].append(clip_record)
			await _roundtrip(scene_path, clip_name, int(frame_count * 0.43))
		viewer.rig.set_slot_visible("cloak", false)
		viewer.show_frame(0)
		await _draw()
		_check(surface.get_texture().get_image().save_png(OUTPUT.path_join(facing + "_without_cloak.png")) == OK, "Save exposed anatomy proof")
		viewer.rig.set_slot_visible("cloak", true)
	viewer.select(str(viewer.rig.config["default_facing"]), str(viewer.rig.config["clips"].keys()[0]))
	viewer.pause_button.grab_focus()
	await _draw()
	_check(surface.get_texture().get_image().save_png(OUTPUT.path_join("keyboard_focus.png")) == OK, "Save keyboard focus proof")
	# Real control signals and step state are also covered; this is not an input-device certification.
	viewer.clip_select.select(viewer.rig.config["clips"].size()-1)
	viewer.clip_select.item_selected.emit(viewer.clip_select.selected)
	_check(viewer.animation == str(viewer.rig.config["clips"].keys()[-1]), "Clip control switches animation")
	viewer.step(1)
	_check(not viewer.playing and viewer.frame_index == 1, "Stepping pauses on the requested frame")
	manifest["errors"] = failures
	var file := FileAccess.open(OUTPUT.path_join("render_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("CUTOUT_WORKFLOW_RENDER: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _measure(clip_name: String, index: int, anchors: Dictionary) -> Dictionary:
	var rig: Node2D = viewer.rig
	var specification: Dictionary = viewer.rig.config["clips"][clip_name]
	var progress: float = float(index) / float(int(specification["frames"]) if specification["loop"] else int(specification["frames"])-1)
	var phase: float = viewer.rig.playback_phase(clip_name, progress)
	var matrices: Dictionary = {}
	var rigid_error: float = 0.0
	for name: String in viewer.rig.bones:
		var bone: Bone2D = viewer.rig.bones[name]
		var world: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform
		_check(world.is_finite(), "Nonfinite transform: " + name)
		matrices[name] = [world.x.x, world.x.y, world.y.x, world.y.y, world.origin.x, world.origin.y]
		if name in viewer.rig.config.get("rigid_bones", []):
			rigid_error = maxf(rigid_error, maxf(absf(world.x.length()-1), maxf(absf(world.y.length()-1), absf(world.x.dot(world.y)))))
	_check(rigid_error < 0.001, "Rigid terminal paint was stretched or sheared")
	var target_error: float = 0.0
	var support_drift: float = 0.0
	if str(specification.get("travel", "none")) == "motion" and not viewer.rig.config.get("contact_feet", []).is_empty():
		_check(viewer.rig.sampler.has_method("walk_foot_state"), "Travel motion must expose its support-foot contract")
		if viewer.rig.sampler.has_method("walk_foot_state"):
			for foot: String in viewer.rig.config.get("contact_feet", []):
				var state: Dictionary = viewer.rig.sampler.call("walk_foot_state", phase, foot, viewer.rig.layout, viewer.rig.facing)
				var point: Vector2 = rig.to_local((viewer.rig.bones[foot] as Bone2D).global_position)
				target_error = maxf(target_error, point.distance_to(state["target"]))
				if state["contact"]:
					var grounded: Vector2 = point + viewer.rig.travel_for_frame(clip_name, index)
					if not anchors.has(foot) or float(state["cycle_phase"]) < float(anchors[foot]["phase"]):
						anchors[foot] = {"point": grounded, "phase": state["cycle_phase"]}
					support_drift = maxf(support_drift, grounded.distance_to(anchors[foot]["point"]))
					anchors[foot]["phase"] = state["cycle_phase"]
				else:
					anchors.erase(foot)
	_check(target_error < 0.2 and support_drift < 0.02, "Foot target or ground support contract failed")
	return {"frame": index, "phase": phase, "bones": matrices, "rigid_basis_error": rigid_error, "target_error": target_error, "support_drift": support_drift}

func _roundtrip(scene_path: String, clip_name: String, index: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: PackedScene = load(scene_path) as PackedScene
	var saved: Node = scene.instantiate()
	viewport.add_child(saved)
	var animator: AnimationPlayer = saved.get_node("Animations") as AnimationPlayer
	animator.play(clip_name)
	animator.pause()
	var spec: Dictionary = viewer.rig.config["clips"][clip_name]
	animator.seek(float(index) * float(spec["duration"]) / float(spec["frames"]), true)
	viewer.show_frame(index)
	await _draw()
	var identical: bool = viewport.get_texture().get_image().get_data() == viewer.puppet.get_texture().get_image().get_data()
	_check(identical, "Saved editable scene differs: " + viewer.rig.facing + "/" + clip_name)
	manifest["roundtrip"].append({"facing": viewer.rig.facing, "clip": clip_name, "frame": index, "pixel_identical": identical})
	viewport.queue_free()
	await process_frame

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
