extends SceneTree
## Real-renderer proof; seeking uses the live overlay's exact presentation clock.
const Suite = preload("res://tests/suites/section_transition_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Run = preload("res://scripts/run_engine.gd")
const Transition = preload("res://scripts/section_transition.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://probes/section_transition"
const SIZE := Vector2i(1920, 1080)
var host: Node
var canvas: SubViewport
var failures: Array[String]
var evidence: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Section transition proof requires the real windowed renderer")
		quit(1)
		return
	Suite.prepare_storage()
	root.size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	host = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(host)
	await Suite.settle(self)
	await _strip(false, 0, "normal", [0.3, 0.9, 1.5, 2.4, 3.0])
	await _strip(true, 0, "reduced", [0.15, 0.9, 1.5, 2.1])
	await _strip(false, 4, "section_vi", [1.5])
	await _failed_entry(false)
	await _failed_entry(true)
	await _failed_entry(false, true)
	await _failed_entry(true, true)
	var file := FileAccess.open(OUTPUT.path_join("timeline.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t"))
	for failure: String in failures: push_error(failure)
	print("SECTION TRANSITION PROBE: %d failures; captures %s" % [failures.size(), ProjectSettings.globalize_path(OUTPUT)])
	print(ProjectSettings.globalize_path(OUTPUT))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _strip(reduced: bool, index: int, prefix: String, times: Array) -> void:
	host.get("_settings")["reduced_motion"] = reduced
	Settings.apply_settings(host.get("_settings"), root, false)
	await Suite.install(self, host, Suite.fixture(index))
	var button: Button = host.find_child("DragonRewardContinue", true, false)
	button.pressed.emit()
	var transition: Node = host.get("_section_transition")
	if transition == null:
		failures.append("CONTINUE starts the live transition: " + prefix)
		return
	transition.set_process(false)
	for seconds: float in times:
		transition.advance(seconds - float(transition.get("elapsed")))
		var name: String = "%s_%04d.png" % [prefix, roundi(seconds * 1000.0)]
		var heading: Label = transition.get("_title")
		var numeral: Label = transition.get("_eyebrow")
		var active: bool = bool(transition.get("active"))
		if active and not root.get_node("CursorFeedback").call("glyph_visibility_suppressed"):
			failures.append("Cursor glyph suppressed during transition: " + name)
		# Reduced motion has completed by the final entry-room sample. Copy the
		# evidence before that completed overlay leaves the tree on the next draw.
		evidence.append({"image": name, "seconds_from_continue": seconds, "reduced_motion": reduced, "title": heading.text, "numeral": numeral.text, "heading_rect": str(heading.get_global_rect()), "numeral_rect": str(numeral.get_global_rect()), "painting_scale": str(transition.get("_painting").scale), "entered": transition.get("_entered")})
		if seconds >= 1.4 and seconds < 2.0:
			if not is_equal_approx(heading.get_global_rect().get_center().y, 540.0): failures.append("Heading centred at y540")
			if not is_equal_approx(numeral.get_global_rect().get_center().y, 470.0): failures.append("Numeral centred at y470")
		if seconds >= Transition.reward_fade_seconds(reduced) and not transition.get("_entered"):
			for field: String in ["_relic_choice_host", "_relic_choice_banner", "_relic_choice_title"]:
				if not is_zero_approx(host.get(field).modulate.a): failures.append("Reward and banner fade together: " + name)
		await _capture(name)
		if active and host.get("_large_map_scrim").visible: failures.append("No intervening map: " + name)
	if is_instance_valid(transition): transition.cancel()
	await process_frame

func _failed_entry(reduced: bool, legacy: bool = false) -> void:
	host.get("_settings")["reduced_motion"] = reduced
	Settings.apply_settings(host.get("_settings"), root, false)
	await Suite.install(self, host, Suite.fixture())
	if legacy:
		# The old save lacks the summary field. Its existing local offer event is
		# the source of exact presentation totals; no combat or claim is replayed.
		host.call("_analytics_log_reward_offered", {}, "section_transition_legacy_proof")
		var claimed: Dictionary = Run.new().continue_dragon_reward(host.get("_run_state"))
		preload("res://scripts/progression_store.gd").save_run_state(claimed)
		host.call("_load_run_state", claimed)
	else:
		host.find_child("DragonRewardContinue", true, false).pressed.emit()
	var transition: Node = host.get("_section_transition")
	transition.set_process(false)
	var blocker: String = ProjectSettings.globalize_path("user://section_transition_run.save.tmp")
	DirAccess.make_dir_absolute(blocker)
	transition.advance(Transition.arrival_at(reduced) + Transition.ARRIVAL_FADE_SECONDS + Suite.BOUNDARY_EPSILON_SECONDS)
	DirAccess.remove_absolute(blocker)
	var prefix: String = "failure_reduced" if reduced else "failure_normal"
	if legacy: prefix = "legacy_" + prefix
	transition.advance(Transition.reward_fade_seconds(reduced) * 0.5)
	await _capture(prefix + "_reverse.png")
	transition.advance(Transition.reward_fade_seconds(reduced) * 0.5 + Suite.BOUNDARY_EPSILON_SECONDS)
	await _capture(prefix + "_reward.png")
	var retry: Button = host.find_child("DragonRewardContinue", true, false)
	if retry == null or not retry.is_visible_in_tree() or host.get("_run_state")["notice"] != "Could not save. Your rewards are still here; try Continue again.":
		failures.append("Save failure returns to the post-claim reward and approved notice: " + prefix)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(name)
	var image: Image = canvas.get_texture().get_image()
	if image.get_size() != SIZE or image.save_png(path) != OK: failures.append("Exact-size capture saves: " + name)
	print("Saved " + ProjectSettings.globalize_path(path))
