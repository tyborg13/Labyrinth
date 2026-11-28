extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const RewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const DEADLINE_MS := 15000
const BOOT_DEADLINE_MS := 45000
const CHECKPOINT_PROBE_DELAY_MS := 120
const FPS := 60
const SAMPLE_SECONDS := "1"
const SAMPLE_INTERVAL_MS := "1"
const SIZE := Vector2i(1920, 1080)
const VICTIM_CROP_WIDTH := 200
const VICTIM_CROP_HEIGHT := 240
const VICTIM_CROP_BELOW_FEET := 35
const CHECKPOINT := "/Users/borgerding/workspace/Labyrinth.worktrees/fel-20/tools/fel20/captures/headless-descent/checkpoints/00059"
const ARCHIVED_CHECKPOINT := "/private/tmp/labyrinth_codex/fel20-final.ts2LiA/checkpoints/00059"

var inputs: RefCounted
var fixtures: GDScript
var output: String
var tool_root: String
var native: bool
var media: RefCounted
var recorder: AudioEffectRecord
var stop_at: String

func _initialize() -> void:
	Runtime.apply_from_environment()
	tool_root = OS.get_environment("FEL28_TOOLS")
	if tool_root.is_empty():
		tool_root = ProjectSettings.globalize_path("res://tools")
	output = OS.get_environment("FEL28_OUTPUT")
	native = DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	Engine.max_fps = FPS
	OS.low_processor_usage_mode = false
	if not native: process_frame.connect(_draw_boundary.call_deferred)
	call_deferred("_run")

func _draw_boundary() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("set FEL28_OUTPUT to a writable directory")
		return
	inputs = load(tool_root.path_join("fel20/input_driver.gd")).new(root)
	fixtures = load(tool_root.path_join("fel28/fixtures.gd"))
	stop_at = OS.get_environment("FEL28_QUIT_AT")
	if native:
		media = load(tool_root.path_join("fel20/media.gd")).new()
		recorder = AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), recorder)
	var test_case: String = OS.get_environment("FEL28_CASE")
	if test_case.is_empty(): test_case = "shadow"
	var scene: Node = await _setup(test_case, output)
	if scene == null:
		_fail("could not open combat checkpoint")
		return
	if not test_case in ["shadow", "reduced"]:
		fixtures.stage(scene, test_case)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	var result: Dictionary = await _take(scene, test_case)
	var file := FileAccess.open(output.path_join("take.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	if result.get("ready_ms", -1) < 0 and not result.get("stopped", false):
		_fail("input did not reach the requested boundary")
		return
	print("FEL28 SAMPLE ", test_case, " ", result["beats"], " ready_ms=", result["ready_ms"])
	await scene.prepare_application_quit("fel28_probe")
	var saved := FileAccess.open(output.path_join("quit-save.json"), FileAccess.WRITE)
	saved.store_string(JSON.stringify(Store.load_saved_run(), "\t") + "\n")
	saved.close()
	if stop_at.is_empty():
		scene.queue_free()
		for i: int in range(4): await process_frame
	quit()

func _setup(test_case: String, directory: String) -> Node:
	var checkpoint: String = OS.get_environment("FEL28_CHECKPOINT")
	if checkpoint.is_empty():
		checkpoint = CHECKPOINT if FileAccess.file_exists(CHECKPOINT.path_join("run.save")) else ARCHIVED_CHECKPOINT
	for name: String in ["run.save", "progression.json"]:
		if DirAccess.copy_absolute(checkpoint.path_join(name), directory.path_join(name)) != OK: return null
	Store.set_run_storage_path(directory.path_join("run.save"))
	Store.set_storage_path(directory.path_join("progression.json"))
	Settings.set_storage_path(directory.path_join("settings.json"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(directory.path_join("analytics"))
	var preferences: Dictionary = Settings.default_settings()
	preferences["ui_scale"] = 1.0
	if native: preferences["display_mode"] = Settings.DISPLAY_WINDOWED
	preferences["reduced_motion"] = test_case == "reduced"
	Settings.save_settings(preferences)
	OS.set_environment("LABYRINTH_CEL_LOOK", "all")
	var continued: bool = not native
	var scene_path: String = "res://scenes/main_menu.tscn"
	if continued:
		# Use the menu's real resume contract with the dummy renderer. The
		# headless combat actions still enter through viewport input.
		root.set_meta("labyrinth_resume_saved_run", true)
		scene_path = "res://scenes/run_scene.tscn"
	if change_scene_to_file(scene_path) != OK: return null
	var deadline: int = Time.get_ticks_msec() + BOOT_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var scene: Node = current_scene
		if scene == null: continue
		if not continued and "continue_button" in scene and inputs.available(scene.continue_button):
			var button: Dictionary = inputs.control(scene.continue_button)
			inputs.prepare(button)
			inputs.send(button)
			continued = true
		if scene.has_method("has_installed_run") and scene.has_installed_run() and not scene._animation_lock and not scene._dialogue_active and scene._run_state.get("mode") == "combat":
			return scene
	if is_instance_valid(current_scene) and current_scene.has_method("has_installed_run"):
		print("FEL28 BOOT installed=", current_scene.has_installed_run(), " lock=", current_scene._animation_lock,
			" dialogue=", current_scene._dialogue_active, " mode=", current_scene._run_state.get("mode"))
	return null

func _take(scene: Node, test_case: String) -> Dictionary:
	var at: Dictionary
	if test_case == "enemy_turn":
		at = inputs.key(KEY_P)
	else:
		inputs.send(inputs.key(KEY_6 if test_case in ["shadow", "reduced"] else KEY_1))
		await RenderingServer.frame_post_draw
		at = inputs.board_tile(scene, scene._combat_state["player"]["pos"], "confirm")
	inputs.prepare(at)
	await RenderingServer.frame_post_draw
	scene.set_runtime_performance_instrumentation_enabled(true)
	if native and not media.begin(output, 1, root, recorder):
		media.discard()
		_fail(media.problem)
		return {}
	var telemetry: Node
	var draw_timing: Dictionary = {}
	if OS.get_environment("LABYRINTH_HITCH_TRACE") == "1":
		telemetry = root.get_node("PerformanceTelemetry")
		telemetry.take_hitch_events()
		telemetry.take_hitch_phases()
		scene.board_view._submission_detail_enabled = true
		scene.board_view.set_submission_performance_instrumentation_enabled(true)
		RenderingServer.frame_pre_draw.connect(func() -> void: draw_timing["started"] = Time.get_ticks_usec())
	if OS.get_environment("FEL28_SAMPLE") == "1":
		OS.create_process("/usr/bin/sample", [str(OS.get_process_id()), SAMPLE_SECONDS, SAMPLE_INTERVAL_MS,
			"-file", output.path_join("godot.sample.txt")])
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	inputs.send(at)
	var beats: Dictionary = {}
	var rows: Array[Dictionary]
	if native: rows.append({"ms": 0.0, "gap_ms": 0.0, "phase": "input", "changed": false})
	var ready_ms: float = -1.0
	var stopped: bool = false
	var rail_before: Array = _rail_keys(scene)
	var first_victory_frame: int = -1
	var last_death_frame: int = -1
	var first_reveal_frame_ms: float = -1.0
	var visual_ready: bool = false
	var burst_count: int = 0
	var terrain_seen: bool = false
	var victims: Dictionary = {}
	var regions: Dictionary = {}
	while Time.get_ticks_usec() - started < DEADLINE_MS * 1000:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - started) / 1000.0
		var deaths: Array = scene.board_view.presentation.get("death_animation_units", [])
		var phase: String = "action"
		var progress: float = float(deaths[0].get("death_progress", -1.0)) if not deaths.is_empty() else -1.0
		if progress >= 0.0: phase = "death"
		if scene._post_combat_victory_overlay.visible:
			phase = "victory"
			if stop_at == "checkpoint": Store._run_writer.probe_delay_msec = CHECKPOINT_PROBE_DELAY_MS
		if stop_at == "checkpoint" and scene._save_in_progress and scene._committed_run_state_override.get("mode") == "reward":
			phase = "checkpoint"
		if scene._relic_choice_overlay.visible and (scene._reward_reveal_pending or scene._run_state.get("mode") == "reward"): phase = "reveal"
		var frame: int = Engine.get_process_frames()
		if phase == "victory" and first_victory_frame < 0: first_victory_frame = frame
		if phase == "death": last_death_frame = frame
		if phase == "reveal" and first_reveal_frame_ms < 0: first_reveal_frame_ms = (now - previous) / 1000.0
		for unit: Dictionary in deaths:
			var actor_key: String = str(unit["key"])
			victims[actor_key] = str(unit["type"])
			if native and not regions.has(actor_key):
				var point: Vector2 = inputs.tile_point(scene, unit["pos"])
				var crop := Rect2i(int(point.x) - VICTIM_CROP_WIDTH / 2, int(point.y) - VICTIM_CROP_HEIGHT,
					VICTIM_CROP_WIDTH, VICTIM_CROP_HEIGHT + VICTIM_CROP_BELOW_FEET)
				crop = crop.intersection(Rect2i(Vector2i.ZERO, SIZE))
				if crop.has_area(): regions[actor_key] = [crop.position.x, crop.position.y, crop.size.x, crop.size.y]
		burst_count = maxi(burst_count, int(scene.board_view.presentation.get("burst_playback_count", 0)))
		terrain_seen = terrain_seen or not scene.board_view.presentation.get("terrain_destruction_units", []).is_empty()
		var changed: bool = false
		var capture_begin: int = Time.get_ticks_usec()
		if native:
			changed = media.frame(root)
			if not media.problem.is_empty():
				media.discard()
				_fail(media.problem)
				return {}
		var capture_ms: float = (Time.get_ticks_usec() - capture_begin) / 1000.0
		var rail_reflow: bool = false
		if phase in ["death", "action"] and not victims.is_empty():
			var shown_rail: Array = _rail_keys(scene)
			for dead_key: String in victims:
				if dead_key in rail_before and not dead_key in shown_rail: rail_reflow = true
		if not beats.has(phase): beats[phase] = ms
		if phase == "death": beats["last_death"] = ms
		if progress > 0.0 and not beats.has("dissolve"): beats["dissolve"] = ms
		rows.append({"ms": ms, "gap_ms": (now - previous) / 1000.0, "phase": phase, "progress": progress, "rail": rail_reflow,
			"prepared": scene._victory_reward_preparation._ready, "frame": frame, "changed": changed, "capture_ms": capture_ms})
		if telemetry != null:
			if draw_timing.has("started"):
				rows[-1]["pre_to_post_draw_ms"] = (now - int(draw_timing["started"])) / 1000.0
			var phases: Dictionary = telemetry.take_hitch_phases()
			var loads: Dictionary = telemetry.take_hitch_events()
			if not phases.is_empty(): rows[-1]["hitch_phases"] = phases
			if not loads.is_empty(): rows[-1]["hitch_events"] = loads
		previous = now
		if stop_at == phase and _at_quit_sample(scene, phase, ms - float(beats[phase]), progress):
			stopped = true
			break
		if test_case == "midfight" and not scene._animation_lock and not victims.is_empty():
			ready_ms = ms
			break
		if scene._run_state.get("mode") == "reward" and not scene._animation_lock:
			if not visual_ready:
				var button: Control = scene.find_child("RewardRecoverButton", true, false)
				var reward_input: Dictionary = inputs.control(button)
				var widgets: Array[Node] = scene._relic_choice_bar.find_children("CardWidget", "Control", true, false)
				if not widgets.is_empty(): reward_input = inputs.control(widgets[0])
				if not reward_input.is_empty():
					inputs.prepare(reward_input)
					visual_ready = true
					continue
			else:
				if root.gui_get_hovered_control() != null and scene._relic_choice_bar.is_ancestor_of(root.gui_get_hovered_control()):
					ready_ms = ms
					break
	var result: Dictionary = {"beats": beats, "frames": rows, "ready_ms": ready_ms, "stopped": stopped,
		"victims": victims, "death_regions": regions.values(), "burst_count": burst_count, "terrain_seen": terrain_seen, "last_death_frame": last_death_frame,
		"first_victory_frame": first_victory_frame, "first_reveal_frame_ms": first_reveal_frame_ms,
		"performance": scene.runtime_performance_frame_instrumentation_snapshot()}
	if telemetry != null:
		result["board_submissions"] = scene.board_view._submission_detail_top.duplicate(true)
	if native:
		result.merge({"id": "kill.reward", "action": 1, "flags": []})
		if not media.finish(result): _fail(media.problem)
	return result

func _at_quit_sample(scene: Node, phase: String, elapsed_ms: float, progress: float) -> bool:
	match phase:
		"death":
			return progress > 0.0
		"victory":
			var hold_sample: float = RewardSequence.VICTORY_UNFURL_SECONDS + RewardSequence.VICTORY_SETTLE_SECONDS + RewardSequence.VICTORY_HOLD_SECONDS * 0.5
			return elapsed_ms >= hold_sample * 1000.0
		"reveal":
			return scene._relic_choice_banner.modulate.a > 0.0 and scene._reward_reveal_pending
		"checkpoint":
			return true
	return false

func _rail_keys(scene: Node) -> Array:
	return scene._turn_order_rendered_entries.map(func(entry: Dictionary) -> String: return str(entry.get("actor_key", "")))

func _fail(message: String) -> void:
	printerr("FEL28 FAIL ", message)
	quit(1)
