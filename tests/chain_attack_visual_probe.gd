extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Suite = preload("res://tests/suites/chain_attack_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/chain_attack"
var failures: Array[String]
var viewport: SubViewport
var completed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://chain_progression.json")
	Progression.set_run_storage_path("user://chain_run.save")
	Progression.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_2d = Viewport.MSAA_4X
	root.add_child(viewport)
	await _capture(false)
	await _capture(true)
	await _capture(false, true)
	await _capture(true, true)
	for failure: String in failures:
		push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT))
	print("CHAIN ATTACK VISUAL PROBE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _capture(reduced: bool, trapped: bool = false) -> void:
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await create_timer(0.15).timeout
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	instance.set("_settings", settings)
	var progression: Dictionary = instance.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids():
		progression = Tutorials.resolve_progression(progression, prompt)
	instance.set("_progression", progression)
	var combat := Combat.new()
	var before: Dictionary = Suite.trap_fixture(combat) if trapped else Suite.fixture(combat)
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = before
	run["current_room"] = before.get("room_coord")
	run["current_room_layout"] = {"grid": before.get("grid"), "coord": before.get("room_coord"), "type": "combat", "name": "Chain feedback proof"}
	instance.set("_run_state", run)
	instance.set("_combat_state", before)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	instance.call("_refresh_contextual_combat_tutorial")
	instance.set("_animation_lock", true)
	await create_timer(0.20).timeout
	var action: Dictionary = {"type": "ranged", "damage": 4, "range": 7, "chain": 2, "_card_element": "lightning"}
	if trapped:
		action = Suite.razor_action()
	var result: Dictionary = combat.resolve_player_action_for_presentation(before, action, Vector2i(4, 4))
	var board: Node = instance.get("board_view") as Node
	var samples: Dictionary = {}
	var seen_ids: Array[int]
	var trap_seen: bool = false
	var trap_sound_seen: bool = false
	var terrain_completed: bool = false
	completed = false
	_play(instance, before, result, action)
	var deadline: int = Time.get_ticks_msec() + 5000
	while not completed and Time.get_ticks_msec() < deadline:
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var effect: Dictionary = presentation.get("effect", {}) as Dictionary
		var t: float = float(presentation.get("effect_progress", 0.0))
		var kind: String = str(effect.get("kind", ""))
		var index: int = int(effect.get("chain_index", 0))
		var shown: Dictionary = board.get("combat_state") as Dictionary
		if trapped:
			var trap_effects: Array = presentation.get("trap_effects", []) as Array
			if not trap_effects.is_empty():
				trap_seen = true
				_remember(samples, "04_trap_during_chain", shown, presentation)
			for unit: Dictionary in presentation.get("terrain_destruction_units", []):
				if float(unit.get("destruction_progress", 0.0)) >= 0.99:
					terrain_completed = true
					_remember(samples, "05_terrain_complete", shown, presentation)
			for player: AudioStreamPlayer in instance.get("_sfx_players") as Array:
				if player.playing and str(player.get_meta("sfx_id", "")).contains("fire"):
					trap_sound_seen = true
			if kind == "chain" and not seen_ids.has(index):
				seen_ids.append(index)
			await process_frame
			continue
		if kind == "chain":
			if not seen_ids.has(index):
				seen_ids.append(index)
			if index == 1 and t < 0.42 and not reduced:
				_expect(Suite.hp(shown, 3) == Suite.hp(before, 3), "Next target must retain its health while the first hop is traveling")
				_remember(samples, "01_hop_travel", shown, presentation)
			if index == 1 and (t >= 0.42 or reduced):
				_expect(Suite.hp(shown, 3) == Suite.hp(before, 3) - 4 and Suite.hp(shown, 2) == Suite.hp(before, 2), "First hop must update target2 while target3 waits")
				_remember(samples, "02_hop_contact", shown, presentation)
			if index == 2 and (t >= 0.42 or reduced):
				_expect(Suite.hp(shown, 2) == Suite.hp(before, 2) - 4, "Second hop must update target3 on contact")
				_remember(samples, "03_final_contact", shown, presentation)
		elif kind == "ranged" and t >= 0.30:
			_expect(Suite.hp(shown, 1) == Suite.hp(before, 1) - 4 and Suite.hp(shown, 3) == Suite.hp(before, 3), "Initial strike must not damage the next chain target early")
			_remember(samples, "00_initial_contact", shown, presentation)
		await process_frame
	_expect(completed, "Chain animation must complete within its bounded natural duration")
	if trapped:
		_expect(seen_ids == [1] and trap_seen and trap_sound_seen, "A relic chain with forced movement must retain its trap VFX and production sound")
		_expect(terrain_completed, "Trap-destroyed terrain must reach its final frame before cleanup")
	else:
		_expect(seen_ids == [1, 2], "Normal and reduced-motion playback must expose both actual hops in order")
		_expect(samples.has("00_initial_contact") and samples.has("02_hop_contact") and samples.has("03_final_contact"), "Native live playback must produce readable first, second and third contacts")
	# Save real live-sampled presentations after playback, so PNG readback cannot
	# consume a hop's short timing window or change which states were observed.
	for name: String in samples:
		var sample: Dictionary = samples[name] as Dictionary
		instance.call("_render_board_state", sample.get("state"), sample.get("presentation"))
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		_expect(image.get_size() == Vector2i(1920, 1080), "Chain proof must render at native1080 UI100")
		image.save_png("%s/%s_%s.png" % [OUTPUT, ("trap_" if trapped else "") + ("reduced" if reduced else "normal"), name])
	instance.queue_free()
	await process_frame

func _play(instance: Node, before: Dictionary, result: Dictionary, action: Dictionary) -> void:
	instance.call("_begin_player_popup_timeline")
	await instance.call("_animate_player_action_step", before, result.get("state"), "chain_bolt", action, Vector2i(4, 4), result.get("chain_hits"))
	await instance.call("_finish_player_popup_timeline", result.get("state"))
	completed = true

func _remember(samples: Dictionary, key: String, state: Dictionary, presentation: Dictionary) -> void:
	if not samples.has(key):
		samples[key] = {"state": state.duplicate(true), "presentation": presentation.duplicate(true)}

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
