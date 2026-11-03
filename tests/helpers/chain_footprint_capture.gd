extends RefCounted
## Windowed-only production playback proof, called by chain_attack_visual_probe.
const Cases = preload("res://tests/suites/chain_footprint_cases.gd")
const Suite = preload("res://tests/suites/chain_attack_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const SETTLE_SECONDS: float = 0.20
const PLAYBACK_DEADLINE_MS: int = 5000

static func capture(tree: SceneTree, viewport: SubViewport, output: String, side: int, reverse: bool, reduced: bool, expect: Callable) -> void:
	var combat := preload("res://scripts/combat_engine.gd").new()
	var before: Dictionary = Cases.fixture(combat, Suite.fixture(combat), Cases.SIDES[side])
	var attack: Dictionary = Cases.action(2)
	var target: Vector2i = Cases.SIDES[side] if reverse else Cases.DRAGON_ANCHOR
	var result: Dictionary = combat.resolve_player_action_for_presentation(before, attack, target)
	var hits: Array = result["chain_hits"]
	expect.call(hits.size() == 2, "Footprint visual proof requires exactly two actor hits")
	if hits.size() != 2: return
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = reduced
	settings["music_volume"] = 0.0
	instance.set("_settings", settings)
	var progression: Dictionary = instance.get("_progression")
	for prompt: String in Tutorials.prompt_ids(): progression = Tutorials.resolve_progression(progression, prompt)
	instance.set("_progression", progression)
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = before
	run["current_room"] = before["room_coord"]
	run["current_room_layout"] = {"grid": before["grid"], "coord": before["room_coord"], "type": "combat", "name": "Chain feedback proof"}
	instance.set("_run_state", run)
	instance.set("_combat_state", before)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	instance.call("_refresh_contextual_combat_tutorial")
	instance.set("_animation_lock", true)
	await tree.create_timer(SETTLE_SECONDS).timeout
	var samples: Dictionary = {}
	var board: Node = instance.get("board_view")
	instance.set_meta("chain_footprint_done", false)
	_play(instance, before, result, attack, target)
	var deadline: int = Time.get_ticks_msec() + PLAYBACK_DEADLINE_MS
	while not bool(instance.get_meta("chain_footprint_done")) and Time.get_ticks_msec() < deadline:
		var presentation: Dictionary = board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		if str(effect.get("kind", "")) == "chain" and int(effect.get("chain_index", 0)) == 1:
			expect.call(effect["from"] == hits[1]["from"] and effect["to"] == hits[1]["to"], "Drawn footprint arc matches the resolver endpoints")
			var contacted: bool = reduced or float(presentation.get("effect_progress", 0.0)) >= 0.42
			var shown: Dictionary = board.get("combat_state")
			var expected_hp: int = Suite.hp(result["state"] if contacted else before, int(hits[1]["enemy_id"]))
			expect.call(Suite.hp(shown, int(hits[1]["enemy_id"])) == expected_hp, "Footprint target changes health only at arc contact")
			var key: String = "contact" if contacted else "travel"
			if not samples.has(key): samples[key] = {"state": shown.duplicate(true), "presentation": presentation.duplicate(true)}
		await tree.process_frame
	expect.call(bool(instance.get_meta("chain_footprint_done")) and samples.has("contact") and (reduced or samples.has("travel")), "Footprint playback supplies bounded natural travel/contact samples")
	var prefix: String = "footprint_%s_%d%s" % ["target" if reverse else "head", side, "_reduced" if reduced else ""]
	for key: String in samples:
		instance.call("_render_board_state", samples[key]["state"], samples[key]["presentation"])
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		expect.call(image.get_size() == Vector2i(1920, 1080), "Footprint capture is native1080 UI100")
		expect.call(image.save_png("%s/%s_%s.png" % [output, prefix, key]) == OK, "Footprint capture writes its PNG")
	instance.queue_free()
	await tree.process_frame

static func _play(instance: Node, before: Dictionary, result: Dictionary, attack: Dictionary, target: Vector2i) -> void:
	instance.call("_begin_player_popup_timeline")
	await instance.call("_animate_player_action_step", before, result["state"], "chain_bolt", attack, target, result["chain_hits"])
	await instance.call("_finish_player_popup_timeline", result["state"])
	instance.set_meta("chain_footprint_done", true)
