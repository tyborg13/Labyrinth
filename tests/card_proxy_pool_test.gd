extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RunScene = preload("res://scripts/run_scene.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var run_scene: Node = RunScene.new()
	# The live scene builds both visible FX and the hidden proxy pool beneath its
	# UI root. Mirror that ownership boundary in this focused fixture so pooling
	# is tested against the same parent/reparent lifecycle as gameplay.
	var ui_root := Control.new()
	ui_root.name = "CardProxyPoolTestUiRoot"
	root.add_child(ui_root)
	run_scene.set("ui_root", ui_root)
	run_scene.call("_build_card_fx_layer")
	var source_rect := Rect2(Vector2(24.0, 38.0), Vector2(180.0, 254.0))
	var first_proxy: Control = run_scene.call("_spawn_card_proxy", "quick_stab", source_rect) as Control
	run_scene.call("_mount_card_proxy", first_proxy, root, source_rect)
	await process_frame
	_assert(_vector2_near(_proxy_visual_center(first_proxy), source_rect.get_center(), 0.5), "A fresh mounted proxy should share the source card center")
	var first_widget: Control = first_proxy.get_child(0) as Control
	var first_proxy_id: int = first_proxy.get_instance_id()
	var first_widget_id: int = first_widget.get_instance_id()
	var mouse_connection_count: int = first_widget.mouse_entered.get_connections().size()

	first_proxy.rotation = 0.4
	first_proxy.pivot_offset = Vector2(37.0, 51.0)
	first_proxy.modulate = Color(0.4, 0.5, 0.6, 0.2)
	first_proxy.self_modulate = Color(0.7, 0.6, 0.5, 0.3)
	first_widget.set("_left_pressed", true)
	first_widget.set("_drag_emitted", true)
	first_widget.set("_local_hovered", true)
	first_widget.set("_ready_wave_progress", 0.7)
	first_widget.set("_ready_wave_active", true)
	first_widget.set_meta("ready_wave_active", true)
	first_widget.call("_ensure_ready_wave_glow")
	var first_ready_wave_glow: Control = first_widget.get("_ready_wave_glow") as Control
	first_ready_wave_glow.visible = true
	first_ready_wave_glow.modulate = Color(1.0, 1.0, 1.0, 0.82)
	first_ready_wave_glow.scale = Vector2(1.028, 1.028)
	var first_glow: Node = first_widget.get("_intensity_active_glow") as Node
	first_glow.set("_pulse_phase", 0.73)
	run_scene.call("_release_card_proxy", first_proxy)
	var pool: Array = run_scene.get("_card_proxy_pool") as Array
	_assert(pool.size() == 1, "Releasing a completed proxy should retain one bounded reusable instance")
	_assert(not first_proxy.visible, "A pooled proxy should be hidden immediately")
	_assert(first_proxy.process_mode == Node.PROCESS_MODE_DISABLED, "A pooled proxy subtree should not spend frame time while hidden")
	_assert(first_proxy.get_parent() == run_scene.get("_card_proxy_pool_host"), "A pooled proxy should leave every visible FX/drag layer")

	var reused_proxy: Control = run_scene.call("_spawn_card_proxy", "quick_stab", source_rect) as Control
	var reused_widget: Control = reused_proxy.get_child(0) as Control
	_assert(reused_proxy.get_instance_id() == first_proxy_id, "The next card effect should reuse the released proxy node")
	_assert(reused_widget.get_instance_id() == first_widget_id, "Proxy reuse should retain the expensive CardWidget subtree")
	run_scene.call("_mount_card_proxy", reused_proxy, root, source_rect)
	_assert(reused_proxy.visible and reused_proxy.top_level and reused_proxy.process_mode == Node.PROCESS_MODE_INHERIT, "Mounted proxies should restore visible top-level effect processing")
	_assert(_vector2_near(reused_proxy.size * reused_proxy.scale, source_rect.size, 1.0), "A reused proxy should mount at the requested visual size instead of inheriting a giant parent transform")
	_assert(reused_widget.size == Vector2(250.0, 352.0), "A reused proxy widget should remain at its native geometry instead of doubling through stale stretch anchors")
	_assert(_vector2_near(_proxy_visual_center(reused_proxy), source_rect.get_center(), 0.5), "A reused mounted proxy should remain centered over its source rect")
	_assert(is_zero_approx(reused_proxy.rotation) and reused_proxy.pivot_offset == reused_proxy.size * 0.5, "Reacquired proxies should clear consumed-card rotation and restore a centered motion pivot")
	_assert(reused_proxy.modulate == Color.WHITE and reused_proxy.self_modulate == Color.WHITE, "Reacquired proxies should clear prior fade/tint state")
	_assert(not bool(reused_widget.get("_interactive")), "FX proxies should remain noninteractive after reuse")
	_assert(not bool(reused_widget.get("_left_pressed")) and not bool(reused_widget.get("_drag_emitted")) and not bool(reused_widget.get("_local_hovered")), "Reused widgets should clear every transient input state")
	_assert(is_zero_approx(float(reused_widget.get("_ready_wave_progress"))) and not bool(reused_widget.get("_ready_wave_active")), "Reused widgets should clear every transient pose state")
	var reused_ready_wave_glow: Control = reused_widget.get("_ready_wave_glow") as Control
	_assert(not reused_widget.has_meta("ready_wave_active"), "Reused widgets should clear the ready-wave activity marker")
	_assert(not reused_ready_wave_glow.visible and is_zero_approx(reused_ready_wave_glow.modulate.a), "Reused widgets should hide and clear the transient ready-wave glow")
	var reused_glow: Node = reused_widget.get("_intensity_active_glow") as Node
	_assert(is_zero_approx(float(reused_glow.get("_pulse_phase"))), "Reused widgets should restart decorative glow animation at the fresh-instance phase")
	reused_widget.visible = false
	reused_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reused_widget.set("_interactive", true)
	reused_widget.call("prepare_for_pool")
	reused_widget.call("set_interaction_state", false, false, true, false, true, true)
	_assert(reused_widget.visible, "Pool preparation should restore a card hidden during its prior hand animation")
	_assert(reused_widget.mouse_filter == Control.MOUSE_FILTER_STOP, "Lightweight pooled-card reconfiguration should restore live mouse input after a selection wrapper made the subtree inert")
	await process_frame
	run_scene.call("_release_card_proxy", reused_proxy)

	var next_rect := Rect2(Vector2(91.0, 63.0), Vector2(126.0, 178.0))
	reused_proxy = run_scene.call("_spawn_card_proxy", "guarded_step", next_rect) as Control
	reused_widget = reused_proxy.get_child(0) as Control
	_assert(str(reused_widget.get("card_id")) == "guarded_step", "Reused CardWidgets should be fully reconfigured for the next card")
	run_scene.call("_mount_card_proxy", reused_proxy, root, next_rect)
	await process_frame
	_assert(_vector2_near(reused_proxy.size * reused_proxy.scale, next_rect.size, 1.0), "Repeated proxy reuse should preserve the requested card dimensions")
	_assert(reused_widget.size == Vector2(250.0, 352.0), "Repeated proxy reuse should keep the CardWidget native rect stable")
	_assert(_vector2_near(_proxy_visual_center(reused_proxy), next_rect.get_center(), 0.5), "Repeated proxy reuse should preserve destination center geometry")
	_assert(reused_widget.mouse_entered.get_connections().size() == mouse_connection_count, "Reusing a CardWidget should not duplicate its input signal connections")
	var title_label: Label = reused_widget.get_node("Margin/VBox/TopRow/Title") as Label
	_assert(title_label.text == "Guarded Step", "Reused proxy visuals should display the newly configured card")

	# The pool is deliberately tiny: combat only needs one drag ghost and one serial FX
	# proxy, and retaining more full CardWidget trees would trade one pressure source for another.
	run_scene.call("_release_card_proxy", reused_proxy)
	var racing_proxy: Control = run_scene.call("_spawn_card_proxy", "quick_stab", source_rect) as Control
	run_scene.call("_mount_card_proxy", racing_proxy, root, source_rect)
	var racing_tween: Tween = create_tween()
	racing_tween.tween_interval(5.0)
	racing_proxy.set_meta("active_card_proxy_tween", racing_tween)
	run_scene.call("_release_card_proxy", racing_proxy)
	pool = run_scene.get("_card_proxy_pool") as Array
	_assert(pool.is_empty() and racing_proxy.is_queued_for_deletion(), "A proxy with a racing snapback tween should be freed instead of becoming reusable")
	racing_tween.kill()
	await process_frame

	var pooled_a: Control = run_scene.call("_spawn_card_proxy", "quick_stab", source_rect) as Control
	var pooled_b: Control = run_scene.call("_spawn_card_proxy", "guarded_step", next_rect) as Control
	var overflow: Control = run_scene.call("_spawn_card_proxy", "quick_stab", source_rect) as Control
	run_scene.call("_mount_card_proxy", pooled_a, root, source_rect)
	run_scene.call("_mount_card_proxy", pooled_b, root, next_rect)
	run_scene.call("_mount_card_proxy", overflow, root, source_rect)
	run_scene.call("_release_card_proxy", pooled_a)
	run_scene.call("_release_card_proxy", pooled_b)
	run_scene.call("_release_card_proxy", overflow)
	pool = run_scene.get("_card_proxy_pool") as Array
	_assert(pool.size() == 2, "The card proxy pool should never retain more than its two-instance limit")
	_assert(overflow.is_queued_for_deletion(), "Overflow proxies should be queued for deletion instead of retained")

	run_scene.free()
	ui_root.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TEST RESULT: PASS — bounded card proxy reuse and reset semantics")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d card proxy pool failure(s)" % _failures.size())
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _vector2_near(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return absf(actual.x - expected.x) <= tolerance and absf(actual.y - expected.y) <= tolerance

func _proxy_visual_center(proxy: Control) -> Vector2:
	return proxy.get_global_transform() * proxy.pivot_offset
