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
		_expect(cache.active and cache.get("_viewport").get_instance_id() == target_id, "Repeated capture must reuse one render target")
		repeated.append(delta)
		cache.restore()
		await _render_frozen_cache_proof_frame()
		_expect(hand.get_parent() == original_parent and target.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Restore retains the disabled target and live hand ownership")
		var restored_delta: Dictionary = _image_channel_difference(direct.get_region(crop), _root_screenshot_image().get_region(crop))
		_expect(float(restored_delta.get("mean_channel_delta", 255.0)) <= 0.2, "Restore preserves the original changed hand pixels")
	var clock_proof: Dictionary = await _verify_locked_hand_clock_animation(instance)
	# Two captures separated by an immediate restore may overlap their awaits.
	cache.capture(hand, instance)
	cache.restore()
	cache.capture(hand, instance)
	await _render_frozen_cache_proof_frame()
	_expect(cache.active and hand.get_parent() == target, "Cancelled capture cannot invalidate its replacement")
	cache.restore()
	var second_host := Control.new()
	second_host.size = Vector2(1920, 1080)
	second_host.theme = instance.theme
	root.add_child(second_host)
	cache.capture(hand, second_host)
	await _render_frozen_cache_proof_frame()
	var replacement_target: SubViewport = cache.get("_viewport") as SubViewport
	_expect(not is_instance_valid(target) and replacement_target.get_parent() == second_host, "Changing hosts frees the previous target")
	cache.restore()
	second_host.queue_free()
	await process_frame
	await process_frame
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
	print("HAND CACHE LIFECYCLE RESULT: " + JSON.stringify({"animated_clock": clock_proof, "repeated": repeated, "errors": _errors}))
	print("TEST RESULT: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)
