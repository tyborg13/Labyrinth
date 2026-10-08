extends RefCounted

const RecordedBanner = preload("res://tests/helpers/turn_clock_recorded_banner.gd")
const RoundEngine = preload("res://tests/helpers/turn_clock_round_engine.gd")

# Exercise the complete production round and next player-turn presentation.
# Sampling the banner label per frame could miss the erroneous initial flash.
static func run(tree: SceneTree, scene: Node, fixture: Dictionary, install: Callable, play: Callable, expect: Callable) -> void:
	var original_engine: RefCounted = scene.get("_combat_engine")
	var engine := RoundEngine.new()
	scene.set("_combat_engine", engine)
	var original_banner: Control = scene.get("_turn_banner") as Control
	var parent: Node = original_banner.get_parent()
	parent.remove_child(original_banner)
	var banner := RecordedBanner.new()
	banner.z_index = original_banner.z_index
	banner.z_as_relative = original_banner.z_as_relative
	parent.add_child(banner)
	scene.set("_turn_banner", banner)
	for phase: String in ["pass_enemy_first", "fast_back_to_back", "hourglass_immediate", "enemy_then_hero"]:
		var state: Dictionary = fixture.duplicate(true)
		if phase in ["fast_back_to_back", "enemy_then_hero"]:
			state = play.call(engine, state, "brace")
			state = play.call(engine, state, "quick_stab", Vector2i(3, 4))
		if phase == "hourglass_immediate":
			state["relics"] = ["borrowed_hourglass"]
		if phase == "enemy_then_hero":
			for entry: Dictionary in state["turn_queue"]:
				if int(entry.get("enemy_id", -1)) == 1:
					entry["time"] = 11
		# Predictable, non-damaging authored intent keeps the test focused on the
		# clock and hand-off; the engine still resolves and reschedules the enemy.
		for enemy: Dictionary in state["enemies"]:
			enemy["intent"] = {"name": "Wait", "time": 1, "actions": []}
		await install.call(tree, scene, state)
		scene.call("_set_action_banner", "")
		expect.call(not bool(scene.call("_turn_banner_blocked")), "%s: banner is not suppressed by a boss or action label" % phase)
		banner.shown_texts.clear()
		engine.activation_kinds.clear()
		engine.finish_calls = 0
		var expected_texts: Array[String]
		var enemy_first: bool = phase in ["pass_enemy_first", "enemy_then_hero"]
		if enemy_first:
			expected_texts.append("ENEMY TURN")
		expected_texts.append("YOUR TURN")
		var completion: Dictionary = {"done": false}
		_resolve_round(scene, completion)
		expect.call(engine.finish_calls == 1, "%s: round schedules the ended activation exactly once before its first await" % phase)
		expect.call(banner.shown_texts.size() == (1 if enemy_first else 0) and (not enemy_first or banner.shown_texts[0] == "ENEMY TURN"), "%s: enemy-first banner appears immediately; back-to-back turn shows no enemy banner" % phase)
		var deadline: int = Time.get_ticks_msec() + 15000
		while not bool(completion["done"]) and Time.get_ticks_msec() < deadline:
			await tree.process_frame
			if DisplayServer.get_name() == "headless":
				# The dummy renderer emits no draw-completion ticks. Release the
				# production round's render awaits without changing its code/cadence.
				RenderingServer.frame_post_draw.emit()
		expect.call(bool(completion["done"]), "%s: complete round and next player-turn start finish" % phase)
		expect.call(banner.shown_texts == expected_texts, "%s: whole-round banner sequence is exactly %s, observed %s" % [phase, expected_texts, banner.shown_texts])
		print("TURN CLOCK BANNER SEQUENCE: %s: %s" % [phase, banner.shown_texts])
		var final_state: Dictionary = scene.get("_combat_state")
		var expected_clock: int = 0 if phase == "hourglass_immediate" else 19 if phase == "pass_enemy_first" else 12
		expect.call(not bool(scene.get("_animation_lock")) and engine.is_player_turn(final_state) and int(final_state.get("initiative_clock", -1)) == expected_clock, "%s: input unlocks on the next real player activation at Time %d" % [phase, expected_clock])
		if not enemy_first:
			expect.call(engine.activation_kinds.size() == 1 and engine.activation_kinds[0] == "player", "%s: real round contains only the next player activation" % phase)
		elif phase == "enemy_then_hero":
			expect.call(engine.activation_kinds.size() == 2 and engine.activation_kinds[0] == "enemy" and engine.activation_kinds[1] == "player", "%s: exactly one enemy activates before hero, with the second enemy still waiting" % phase)
		else:
			expect.call(engine.activation_kinds.size() > 1 and engine.activation_kinds[0] == "enemy" and engine.activation_kinds.back() == "player", "%s: real enemy activation precedes the next player turn" % phase)
		if not bool(completion["done"]):
			# A stalled asynchronous round still owns this scene. Avoid installing
			# another fixture over it; the caller reports all assertions above.
			break
	scene.set("_combat_engine", original_engine)
	parent.remove_child(banner)
	banner.free()
	parent.add_child(original_banner)
	scene.set("_turn_banner", original_banner)

static func _resolve_round(scene: Node, completion: Dictionary) -> void:
	await scene.call("_resolve_enemy_round", "pass")
	completion["done"] = true
