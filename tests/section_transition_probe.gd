extends SceneTree
## Real-renderer proof; seeking uses the live overlay's exact presentation clock.
const Suite = preload("res://tests/suites/section_transition_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Run = preload("res://scripts/run_engine.gd")
const Transition = preload("res://scripts/section_transition.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://probes/section_transition"
const SIZE := Vector2i(1920, 1080)
const LEGACY_PROOF_MILESTONE_SUFFIX: String = ":legacy_no_offer_probe:%s"
const SKIP_PROOF_TIMES: Array = [0.40, 0.43, 0.46, 0.49, 0.51, 0.53]
const SKIP_STRIP_COLUMNS: int = 3
const SKIP_STRIP_CELL := Vector2i(640, 360)
var host: Node
var canvas: SubViewport
var failures: Array[String]
var evidence: Array[Dictionary]
var semantics_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	semantics_only = OS.get_cmdline_user_args().has("--semantics-only")
	if DisplayServer.get_name() == "headless" and semantics_only:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not semantics_only:
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
	if OS.get_cmdline_user_args().has("--qa66-skip"):
		await _skip_strip()
		for failure: String in failures: push_error(failure)
		print("QA66 SKIP PROBE: %d failures; captures %s" % [failures.size(), ProjectSettings.globalize_path(OUTPUT)])
		host.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	await _strip(false, 0, "normal", [0.3, 0.9, 1.5, 2.4, 2.8, 3.0])
	await _strip(true, 0, "reduced", [0.15, 0.9, 1.5, 1.85, 2.0, 2.1])
	await _strip(false, 4, "section_vi", [1.5])
	await _failed_entry(false)
	await _failed_entry(true)
	await _failed_entry(false, true)
	await _failed_entry(true, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("timeline.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t"))
	for failure: String in failures: push_error(failure)
	if semantics_only: print("SECTION TRANSITION PROBE SEMANTICS: %d failures; no renderer captures" % failures.size())
	else: print("SECTION TRANSITION PROBE: %d failures; captures %s" % [failures.size(), ProjectSettings.globalize_path(OUTPUT)])
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
		if is_instance_valid(transition): transition.advance(seconds - float(transition.get("elapsed")))
		var name: String = "%s_%04d.png" % [prefix, roundi(seconds * 1000.0)]
		var active: bool = is_instance_valid(transition) and bool(transition.get("active"))
		var heading: Label = transition.get("_title") if is_instance_valid(transition) else null
		var numeral: Label = transition.get("_eyebrow") if is_instance_valid(transition) else null
		if active and not root.get_node("CursorFeedback").call("glyph_visibility_suppressed"):
			failures.append("Cursor glyph suppressed during transition: " + name)
		var row: Dictionary = {"image": name, "seconds_from_continue": seconds, "reduced_motion": reduced, "map_visible": host.get("_large_map_scrim").visible, "map_alpha": host.get("_large_map_scrim").modulate.a}
		if is_instance_valid(transition):
			row.merge({"title": heading.text, "numeral": numeral.text, "heading_rect": str(heading.get_global_rect()), "numeral_rect": str(numeral.get_global_rect()), "painting_scale": str(transition.get("_painting").scale), "painting_rect": str(transition.get("_painting").get_global_rect()), "entered": transition.get("_entered")})
		evidence.append(row)
		if heading != null and seconds >= 1.4 and seconds < Transition.arrival_at(reduced):
			if not is_equal_approx(heading.get_global_rect().get_center().y, 540.0): failures.append("Heading centred at y540")
			if not is_equal_approx(numeral.get_global_rect().get_center().y, 470.0): failures.append("Numeral centred at y470")
		if active and seconds >= Transition.reward_fade_seconds(reduced) and not transition.get("_entered"):
			for field: String in ["_relic_choice_host", "_relic_choice_banner", "_relic_choice_title"]:
				if not is_zero_approx(host.get(field).modulate.a): failures.append("Reward and banner fade together: " + name)
		await _capture(name)
		if seconds < Transition.arrival_at(reduced) and host.get("_large_map_scrim").visible: failures.append("No map before the title-to-map handoff: " + name)
		if seconds >= Transition.arrival_at(reduced) and not host.get("_large_map_scrim").visible: failures.append("Arrival cross-fades directly into the map: " + name)
	if is_instance_valid(transition): transition.cancel()
	await process_frame

func _skip_strip() -> void:
	host.get("_settings")["reduced_motion"] = false
	Settings.apply_settings(host.get("_settings"), root, false)
	await Suite.install(self, host, Suite.fixture())
	host.find_child("DragonRewardContinue", true, false).pressed.emit()
	var transition: Node = host.get("_section_transition")
	if transition == null:
		failures.append("CONTINUE starts the skip proof")
		return
	transition.set_process(false)
	transition.advance(Transition.SKIP_AT)
	transition.contain_input(Suite._skip_input("Enter"))
	var images: Array[Image]
	for seconds: float in SKIP_PROOF_TIMES:
		if is_instance_valid(transition): transition.advance(seconds - float(transition.get("elapsed")))
		var backdrop: TextureRect = host.get("_large_map_view").call("transition_backdrop")
		var map: ColorRect = host.get("_large_map_scrim")
		if not backdrop.visible or not is_equal_approx(map.color.a, 1.0): failures.append("Skip exposes the real backdrop during the fade at " + str(seconds))
		evidence.append({"seconds": seconds, "map_alpha": map.modulate.a, "scrim_alpha": map.color.a, "backdrop_visible": backdrop.visible, "transition_active": is_instance_valid(transition) and transition.active})
		await _capture("skip_%04d.png" % roundi(seconds * 1000.0))
		if not semantics_only: images.append(canvas.get_texture().get_image())
	if not images.is_empty():
		var strip := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		for index: int in range(images.size()):
			var thumb: Image = images[index]
			thumb.resize(SKIP_STRIP_CELL.x, SKIP_STRIP_CELL.y, Image.INTERPOLATE_LANCZOS)
			strip.blit_rect(thumb, Rect2i(Vector2i.ZERO, SKIP_STRIP_CELL), Vector2i(index % SKIP_STRIP_COLUMNS, index / SKIP_STRIP_COLUMNS) * SKIP_STRIP_CELL)
		var path: String = OUTPUT.path_join("skip_contact_strip.png")
		if strip.save_png(path) != OK: failures.append("Skip contact strip saves")
		print("Saved " + ProjectSettings.globalize_path(path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("skip_timeline.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t"))
	print("QA66 SKIP TIMELINE: " + JSON.stringify(evidence))

func _failed_entry(reduced: bool, legacy: bool = false) -> void:
	host.get("_settings")["reduced_motion"] = reduced
	Settings.apply_settings(host.get("_settings"), root, false)
	var offered: Dictionary = Suite.fixture()
	if legacy:
		# The old save has neither a reward summary nor its local offer event.
		# Only the saved dragon/relic identities may appear after reversal.
		offered["pending_reward"]["milestone_id"] += LEGACY_PROOF_MILESTONE_SUFFIX % str(reduced)
		var claimed: Dictionary = Run.new().continue_dragon_reward(offered)
		preload("res://scripts/progression_store.gd").save_run_state(claimed)
		host.call("_load_run_state", claimed)
		var summary: Dictionary = host.get("_run_state")[Transition.CLAIMED_REWARD_KEY]
		if summary.has("ember_amount") or summary.has("moltshards"): failures.append("Legacy proof has no matching offer totals")
	else:
		await Suite.install(self, host, offered)
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
	Suite.assert_reward_screen(host, str(offered["pending_reward"]["boss_id"]), str(offered["pending_reward"]["relic_id"]), not legacy, func(ok: bool, message: String) -> void:
		if not ok: failures.append(prefix + ": " + message))

func _capture(name: String) -> void:
	await process_frame
	if semantics_only: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(name)
	var image: Image = canvas.get_texture().get_image()
	if image.get_size() != SIZE or image.save_png(path) != OK: failures.append("Exact-size capture saves: " + name)
	print("Saved " + ProjectSettings.globalize_path(path))
