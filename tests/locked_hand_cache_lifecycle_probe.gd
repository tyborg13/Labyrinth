extends "res://tests/representative_combat_performance_benchmark.gd"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_profile = "middle"
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.size = _viewport_size
	_render_pulse = RenderPulse.new()
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.size = Vector2.ONE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://representative_profile.json")
	ProgressionStore.set_run_storage_path("user://representative_run.save")
	var settings_store = load("res://scripts/settings_store.gd")
	settings_store.set_storage_path("user://representative_settings.json")
	var settings: Dictionary = settings_store.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = OS.get_environment("LABYRINTH_RUNTIME_PERF_REDUCED_MOTION") == "1"
	settings_store.save_settings(settings)
	await process_frame
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	sampler.measured_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sampler.measured_viewport_rid, true)
	root.add_child(sampler)
	_expect(await _acquire_probe_window_focus(), "representative combat needs a foreground window")
	await _settle_probe_window()
	_install_stress_combat(instance, "specialists")
	await _settle_render_frames(WARMUP_FRAMES)
	instance.set("_hovered_card_index", -1)
	instance.set("_animation_lock", true)
	instance.call("_refresh_animation_lock_ui")
	await _settle_frames(20)
	var board: Control = instance.get("board_view") as Control
	board.process_mode = Node.PROCESS_MODE_DISABLED
	instance.call("_begin_locked_hand_render_cache")
	await _render_frozen_cache_proof_frame()
	instance.call("_end_locked_hand_render_cache")
	await _render_frozen_cache_proof_frame()
	var hand: Control = instance.get("hand_box") as Control
	var cache = instance.get("_locked_hand_render_cache")
	var target: SubViewport = cache.get("_viewport") as SubViewport
	var target_id: int = target.get_instance_id()
	var original_parent: Node = hand.get_parent()
	var first_card: Control = instance.call("_hand_card_control", 0) as Control
	var crop := Rect2i(Vector2i(0, 650), Vector2i(1920, 430))
	var repeated: Array[Dictionary]
	for index: int in range(3):
		first_card.visible = index != 1
		first_card.modulate = Color(0.7, 0.9, 1.0, 1.0) if index == 2 else Color.WHITE
		hand.call("refresh_layout")
		await _settle_frames(4)
		await _render_frozen_cache_proof_frame()
		var direct: Image = _root_screenshot_image()
		direct.save_png(ProjectSettings.globalize_path("%s/reuse_%d_direct.png" % [OUTPUT_DIR, index]))
		instance.call("_begin_locked_hand_render_cache")
		await _render_frozen_cache_proof_frame()
		var cached: Image = _root_screenshot_image()
		cached.save_png(ProjectSettings.globalize_path("%s/reuse_%d_cached.png" % [OUTPUT_DIR, index]))
		var delta: Dictionary = _image_channel_difference(direct.get_region(crop), cached.get_region(crop))
		_expect(float(delta.get("over_two_channel_ratio", 1.0)) <= 0.0001 and float(delta.get("mean_channel_delta", 255.0)) <= 0.25, "Reused target must clear old pixels and preserve changed hand appearance")
		_expect(hand.get_parent() == original_parent, "Capturing does not detach the Control subtree")
		_expect(hand.get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE and first_card.get_focus_mode_with_override() == Control.FOCUS_NONE, "Cached hand preserves pointer and focus lock")
		_expect(cache.active and cache.get("_viewport").get_instance_id() == target_id, "Repeated capture must reuse one render target")
		repeated.append(delta)
		cache.restore()
		await _render_frozen_cache_proof_frame()
		_expect(hand.get_parent() == original_parent and target.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Restore retains the disabled target and live hand ownership")
		var restored_delta: Dictionary = _image_channel_difference(direct.get_region(crop), _root_screenshot_image().get_region(crop))
		_expect(float(restored_delta.get("mean_channel_delta", 255.0)) <= 0.2, "Restore preserves the original changed hand pixels")
	var canvas_edges: Array[Dictionary] = await _verify_canvas_attachment_edges(instance, hand, cache, crop)
	var clock_proof: Dictionary = await _verify_locked_hand_clock_animation(instance)
	# Two captures separated by an immediate restore may overlap their awaits.
	cache.capture(hand, instance)
	cache.restore()
	cache.capture(hand, instance)
	await _render_frozen_cache_proof_frame()
	_expect(cache.active and hand.get_parent() == original_parent, "Cancelled capture cannot invalidate its replacement or change Control ownership")
	cache.restore()
	var second_host := Control.new()
	second_host.size = Vector2(1920, 1080)
	second_host.theme = instance.theme
	root.add_child(second_host)
	var before_host_free: Image = _root_screenshot_image()
	cache.capture(hand, second_host)
	await _render_frozen_cache_proof_frame()
	var replacement_target: SubViewport = cache.get("_viewport") as SubViewport
	_expect(not is_instance_valid(target) and replacement_target.get_parent() == second_host, "Changing hosts frees the previous target")
	second_host.queue_free()
	await process_frame
	await process_frame
	_expect(not cache.active and hand.get_parent() == original_parent and hand.is_visible_in_tree(), "Freeing an active capture host restores the surviving live hand")
	await _render_frozen_cache_proof_frame()
	var host_free_delta: Dictionary = _image_channel_difference(before_host_free.get_region(crop), _root_screenshot_image().get_region(crop))
	_expect(float(host_free_delta.get("mean_channel_delta", 255.0)) <= 0.2, "Host teardown restores rendered pixels before any recapture can repair them")
	# Teardown can occur while capture is suspended on its first render.
	var pending_host := Control.new()
	root.add_child(pending_host)
	var input_before: int = hand.mouse_behavior_recursive
	cache.capture(hand, pending_host)
	pending_host.free()
	await _render_frozen_cache_proof_frame()
	_expect(not cache.active and hand.get_parent() == original_parent and hand.mouse_behavior_recursive == input_before, "Pending capture host teardown restores ownership and input synchronously")
	var pending_host_delta: Dictionary = _image_channel_difference(before_host_free.get_region(crop), _root_screenshot_image().get_region(crop))
	_expect(float(pending_host_delta.get("mean_channel_delta", 255.0)) <= 0.2, "Pending host teardown preserves the surviving hand pixels")
	var original_index: int = hand.get_index()
	cache.capture(hand, instance)
	original_parent.remove_child(hand)
	_expect(not cache.active and hand.mouse_behavior_recursive == input_before, "Detaching the hand cancels a pending capture and restores its input flags")
	original_parent.add_child(hand)
	original_parent.move_child(hand, original_index)
	await _settle_frames(6)
	await _render_frozen_cache_proof_frame()
	var pending_detach_delta: Dictionary = _image_channel_difference(before_host_free.get_region(crop), _root_screenshot_image().get_region(crop))
	_expect(float(pending_detach_delta.get("mean_channel_delta", 255.0)) <= 0.2, "A detached pending capture restores the live canvas on reattachment")
	cache.capture(hand, instance)
	await _render_frozen_cache_proof_frame()
	_expect(cache.active and is_instance_valid(cache.get("_viewport")), "A freed host permits a fresh capture")
	cache.restore()
	var final_target: SubViewport = cache.get("_viewport") as SubViewport
	_expect(root.size == _viewport_size and root.get_texture().get_size() == Vector2(_viewport_size), "Native proof retains actual 1920x1080 backing pixels")
	instance.queue_free()
	sampler.queue_free()
	await process_frame
	await process_frame
	_expect(not is_instance_valid(final_target), "Scene teardown frees the retained target")
	print("HAND CACHE LIFECYCLE RESULT: " + JSON.stringify({"animated_clock": clock_proof, "repeated": repeated, "canvas_edges": canvas_edges, "host_free_delta": host_free_delta, "pending_host_delta": pending_host_delta, "pending_detach_delta": pending_detach_delta, "errors": _errors}))
	print("TEST RESULT: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _verify_canvas_attachment_edges(instance: Node, hand: Control, cache, crop: Rect2i) -> Array[Dictionary]:
	var results: Array[Dictionary]
	var parent: Control = hand.get_parent() as Control
	var card: Control = instance.call("_hand_card_control", 0) as Control
	var original_modulate: Color = parent.modulate
	var original_scale: Vector2 = hand.scale
	var original_rotation: float = hand.rotation
	for variant: String in ["ancestor_tint", "fractional_transform"]:
		if variant == "ancestor_tint": parent.modulate = Color(0.72, 0.87, 0.65, 0.74)
		else:
			hand.scale = Vector2(0.93, 1.02)
			hand.rotation = 0.0123
		await _render_frozen_cache_proof_frame()
		var direct: Image = _root_screenshot_image()
		direct.save_png(ProjectSettings.globalize_path("%s/%s_direct.png" % [OUTPUT_DIR, variant]))
		cache.capture(hand, instance)
		await process_frame
		RenderingServer.force_draw(true, 0.0)
		var first: Image = _root_screenshot_image()
		first.save_png(ProjectSettings.globalize_path("%s/%s_first_capture.png" % [OUTPUT_DIR, variant]))
		var delta: Dictionary = _image_channel_difference(direct.get_region(crop), first.get_region(crop))
		var expects_cache: bool = variant != "ancestor_tint"
		_expect(cache.active == expects_cache, "Opaque transformed hands cache; ancestor opacity preserves per-primitive blending through the live hand")
		_expect(float(delta.get("mean_channel_delta", 255.0)) <= 0.25 and float(delta.get("over_two_channel_ratio", 1.0)) <= 0.0001, "First capture preserves %s pixels" % variant)
		var selected_before: int = int(instance.get("_selected_card_index"))
		_routed_left_click(card, card.size * 0.5)
		_expect(int(instance.get("_selected_card_index")) == selected_before and cache.active == expects_cache, "Pointer input cannot activate or invalidate the locked hand")
		cache.restore()
		await process_frame
		RenderingServer.force_draw(true, 0.0)
		var restored: Dictionary = _image_channel_difference(direct.get_region(crop), _root_screenshot_image().get_region(crop))
		_expect(float(restored.get("mean_channel_delta", 255.0)) <= 0.2, "First restore preserves %s pixels" % variant)
		results.append({"variant": variant, "capture": delta, "restore": restored})
		parent.modulate = original_modulate
		hand.scale = original_scale
		hand.rotation = original_rotation
		await _render_frozen_cache_proof_frame()
	# These mutations target the nested CardWidget, not the outer fan slot.
	for mutation: String in ["visibility", "transform", "tint", "ancestor_opacity"]:
		var node: Control = parent if mutation == "ancestor_opacity" else card
		var property: String = "visible" if mutation == "visibility" else ("position" if mutation == "transform" else "modulate")
		var previous: Variant = node.get(property)
		var changed: Variant = false if mutation == "visibility" else (card.position + Vector2(7.25, -2.5) if mutation == "transform" else Color(0.55, 0.85, 0.72, 0.61))
		node.set(property, changed)
		await _render_frozen_cache_proof_frame()
		var expected: Image = _root_screenshot_image()
		node.set(property, previous)
		await _render_frozen_cache_proof_frame()
		cache.capture(hand, instance)
		await _render_frozen_cache_proof_frame()
		_expect(cache.active, "Mutation fixture must start with a retained hand")
		node.set(property, changed)
		await _render_frozen_cache_proof_frame()
		_expect(not cache.active, "Nested CardWidget %s invalidates the raster" % mutation)
		var delta: Dictionary = _image_channel_difference(expected.get_region(crop), _root_screenshot_image().get_region(crop))
		_expect(float(delta.get("mean_channel_delta", 255.0)) <= 0.2, "Nested %s must redraw through the live canvas immediately" % mutation)
		results.append({"variant": "nested_" + mutation, "restored": delta})
		node.set(property, previous)
		await _render_frozen_cache_proof_frame()
	# A deferred fit may already be suspended when the action starts.
	instance.call("_fit_current_hand_layout_to_visible_width", int(instance.get("_hand_layout_revision")))
	cache.capture(hand, instance)
	await _settle_frames(6)
	await _render_frozen_cache_proof_frame()
	var pending_fit: Image = _root_screenshot_image()
	cache.restore()
	await _render_frozen_cache_proof_frame()
	var fit_delta: Dictionary = _image_channel_difference(pending_fit.get_region(crop), _root_screenshot_image().get_region(crop))
	_expect(float(fit_delta.get("mean_channel_delta", 255.0)) <= 0.25, "Pending layout fit cannot leave a stale raster")
	results.append({"variant": "pending_fit", "restored": fit_delta})
	# Unsupported inherited materials and independently enabled input fail open.
	parent.material = CanvasItemMaterial.new()
	cache.capture(hand, instance)
	_expect(not cache.active, "Inherited material uses the live hand")
	parent.material = null
	card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
	cache.capture(hand, instance)
	_expect(not cache.active, "Independently enabled descendant input uses the live hand")
	card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	await _render_frozen_cache_proof_frame()
	return results
