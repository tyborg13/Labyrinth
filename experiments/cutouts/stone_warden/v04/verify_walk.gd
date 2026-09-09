extends SceneTree

# Native proof of the two inspected gait fixes and preservation of accepted clips.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/stone_warden_walk"
var failures: Array[String]
var measurements: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _surface() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _sole(rig: Node2D, side: String) -> Vector2:
	var joint: Array = rig.layout["joints"]["foot_" + side]["position"]
	var sole: Array = rig.layout["landmarks"]["sole_" + side]
	return rig.to_local(rig.bones["foot_" + side].global_position) + Vector2(float(sole[0])-float(joint[0]), float(sole[1])-float(joint[1]))

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var case_index: int = args.find("--case")
	var baseline_index: int = args.find("--baseline")
	if case_index < 0 or baseline_index < 0:
		push_error("Use --case <v03/cutout.json> --baseline <v02/cutout.json>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var current_surface: SubViewport = _surface()
	var baseline_surface: SubViewport = _surface()
	var current := Rig.new()
	var previous := Rig.new()
	current.position = Vector2(128, 128)
	previous.position = Vector2(128, 128)
	current_surface.add_child(current)
	baseline_surface.add_child(previous)
	_check(current.configure(args[case_index+1]), "Candidate rig loads")
	_check(previous.configure(args[baseline_index+1]), "Accepted rig loads")
	var preserved: int = 0
	for facing: String in ["front", "rear"]:
		current.set_facing(facing)
		previous.set_facing(facing)
		for clip: String in ["idle", "attack"]:
			# Begin with the changed layers active; then test resetting into the accepted clip.
			current.show_frame("walk", 16)
			for index: int in range(int(current.config["clips"][clip]["frames"])):
				current.show_frame(clip, index)
				previous.show_frame(clip, index)
				await _draw()
				_check(current_surface.get_texture().get_image().get_data() == baseline_surface.get_texture().get_image().get_data(), "Accepted pixels changed: %s/%s/%d" % [facing, clip, index])
				preserved += 1
		var advances: Dictionary = {}
		for index: int in range(32):
			current.show_frame("walk", index)
			var right: Vector2 = _sole(current, "r")
			var left: Vector2 = _sole(current, "l")
			var phase: float = float(index) / 32.0
			var rs: Dictionary = current.sampler.call("walk_foot_state", phase, "foot_r", current.layout, facing)
			var ls: Dictionary = current.sampler.call("walk_foot_state", phase, "foot_l", current.layout, facing)
			var near: String = "r" if right.y+float(rs["lift_px"]) >= left.y+float(ls["lift_px"]) else "l"
			var far: String = "l" if near == "r" else "r"
			var nodes: Dictionary = current._draw_order_targets()
			_check(nodes["Skin_leg_"+near].z_index > nodes["foot_"+far].z_index, "Far boot drew above near shin: %s/%d" % [facing,index])
			_check(nodes["foot_"+near].z_index > nodes["Skin_leg_"+far].z_index, "Far shin drew above near boot: %s/%d" % [facing,index])
			if index in [0,16]:
				var sign_forward: float = 1.0 if facing == "front" else -1.0
				var advance: float = (right.y-left.y if index == 0 else left.y-right.y) * sign_forward
				advances["right" if index == 0 else "left"] = advance
				_check(advance > 8.0, "Leading foot only reaches even with the other: %s/%d" % [facing,index])
		measurements[facing] = {"advancing_sole_y_pixels": advances}
		var info: Dictionary = current.sampler.call("walk_cycle_info", current.layout, facing)
		var old_info: Dictionary = previous.sampler.call("walk_cycle_info", previous.layout, facing)
		var duration: float = float(current.config["clips"]["walk"]["duration"])
		var old_duration: float = float(previous.config["clips"]["walk"]["duration"])
		var travel: float = Vector2(info["travel_per_cycle"]).length()
		var old_travel: float = Vector2(old_info["travel_per_cycle"]).length()
		_check(duration > old_duration*1.4 and travel > old_travel*1.4, "Longer step must reduce required cadence")
		_check(absf(travel/duration/(old_travel/old_duration)-1.0) < 0.05, "Accepted board speed should remain close")
	measurements["preserved_native_idle_attack_frames"] = preserved
	# At left-forward rear crossing, render the two complete legs separately.
	# Every opaque overlap pixel must come from the nearer right leg.
	current.set_facing("rear")
	current.show_frame("walk", 16)
	var layers: Dictionary = current._draw_order_targets()
	for node: CanvasItem in layers.values():
		_check(node is Sprite2D or node is Polygon2D, "Draw order must target paint, not a same-named bone")
	var visibility: Dictionary = {}
	for node: Node in current.find_children("*", "CanvasItem", true, false):
		if node is Sprite2D or node is Polygon2D:
			visibility[node] = node.visible
			node.visible = layers.values().has(node)
	await _draw()
	var combined: Image = current_surface.get_texture().get_image()
	combined.save_png(OUTPUT.path_join("rear_overlap_combined.png"))
	# Retain the old split boot/shin ordering as a counterexample at the same pose.
	for part_name: String in layers:
		layers[part_name].z_index = current._layer_defaults[part_name]
	await _draw()
	var legacy: Image = current_surface.get_texture().get_image()
	legacy.save_png(OUTPUT.path_join("rear_overlap_legacy_order.png"))
	current._apply_draw_order("walk", 0.5)
	for part_name: String in layers:
		layers[part_name].visible = part_name.ends_with("_r")
	await _draw()
	var near_image: Image = current_surface.get_texture().get_image()
	near_image.save_png(OUTPUT.path_join("rear_overlap_near_right.png"))
	for part_name: String in layers:
		layers[part_name].visible = part_name.ends_with("_l")
	await _draw()
	var far_image: Image = current_surface.get_texture().get_image()
	far_image.save_png(OUTPUT.path_join("rear_overlap_far_left.png"))
	var overlap: int = 0
	var incorrect: int = 0
	var legacy_leaks: int = 0
	for y: int in range(512):
		for x: int in range(512):
			var near_color: Color = near_image.get_pixel(x,y)
			if near_color.a > 0.99 and far_image.get_pixel(x,y).a > 0.99:
				overlap += 1
				var actual: Color = combined.get_pixel(x,y)
				# The native transparent viewport emits ~253/255 alpha for solid paint.
				# Allow only that residual source-over contribution plus 2/255 rounding.
				var tolerance: float = 1.0-near_color.a + 2.0/255.0
				if _color_error(actual, near_color) > tolerance:
					incorrect += 1
				if _color_error(legacy.get_pixel(x,y), near_color) > tolerance:
					legacy_leaks += 1
	_check(overlap > 10 and incorrect == 0, "Rear left leg leaks through right at overlap: %d/%d" % [incorrect,overlap])
	_check(legacy_leaks > 0, "Overlap fixture must expose the old split-layer error")
	measurements["legacy_order_leak_pixels"] = legacy_leaks
	measurements["rear_crossing_near_opaque_overlap_pixels"] = overlap
	measurements["pixel_tolerance"] = "Remaining foreground transparency plus 2/255 rounding; native solid alpha is approximately 253/255"
	measurements["incorrect_overlap_pixels"] = incorrect
	for node: CanvasItem in visibility:
		node.visible = visibility[node]
	_check(current.load_errors.is_empty(), "Rig errors: " + str(current.load_errors))
	measurements["ok"] = failures.is_empty()
	measurements["errors"] = failures
	var file := FileAccess.open(OUTPUT.path_join("walk_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t"))
	file.close()
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("WARDEN_WALK: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _color_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))
