extends "res://tests/pre_battle_fixture.gd"

# emd-01 repro: after the opening boon (heirloom) is taken and its dialogue
# closes, no later refresh in the start room may restart the Emaciated Man's
# start-room narration.
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")

func _initialize() -> void:
	_setup()
	call_deferred("_run")

func _describe(scene: Node, tag: String) -> void:
	var script: Dictionary = scene.get("_dialogue_script")
	print("EMD01 %s: active=%s id=%s npc=%s map=%s text=%s" % [tag, scene.get("_dialogue_active"), script.get("id", ""), script.get("npc_id", ""), scene.get("_large_map_scrim").visible, scene.get("_dialogue_text_label").get_parsed_text().left(60)])

func _run() -> void:
	ProgressionStore.save_data(Fixture.profile(true))
	# Real-game shape: section maps on (the shared fixture turns them off).
	var state: Dictionary = Run.new().create_new_run(Fixture.PROOF_SEED, Fixture.profile(true))
	state[Boons.STATE_KEY]["offers"] = [{"boon": "heirloom", "item": Fixture.PROOF_HEIRLOOM, "column": "Build seed"}]
	var scene: Node = await _instance(state)
	_describe(scene, "loaded")
	scene.call("_speak_to_emaciated_man")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	_describe(scene, "offer")
	var modal: Control = scene.get("_opening_boon_flow").get("overlay")
	var pick: Control = modal.find_child("Boon_heirloom", true, false) if modal != null else null
	_expect(pick != null, "fixture offers the heirloom")
	if pick != null:
		pick.grab_focus()
		await _key(KEY_ENTER)
		await _settle()
	_describe(scene, "taken")
	_expect(not Boons.pending(scene.get("_run_state")), "heirloom taken")
	scene.call("_complete_current_dialogue_line")
	scene.call("_advance_dialogue")
	await _settle()
	_describe(scene, "after_taken_close")
	var restarted: bool = false
	for step: int in range(4):
		scene.call("_refresh_ui")
		await _settle()
		_describe(scene, "refresh_%d" % step)
		var script: Dictionary = scene.get("_dialogue_script")
		if bool(scene.get("_dialogue_active")) and not str(script.get("id", "")).begins_with("opening_boon"):
			restarted = true
	# Head for the first room the way a player does: through the map if it is up.
	if scene.get("_large_map_scrim").visible:
		var moves: Array = scene.get("_run_engine").available_moves(scene.get("_run_state"))
		print("EMD01 moves=%s" % [moves])
		if not moves.is_empty():
			var travel = scene.call("_on_large_map_room_selected", moves[0])
			for frame: int in range(600):
				await process_frame
				if scene.get("_run_state").get("current_room") != Vector2i.ZERO and frame % 30 == 0:
					_describe(scene, "arrived_frame_%d" % frame)
				var script: Dictionary = scene.get("_dialogue_script")
				if bool(scene.get("_dialogue_active")) and str(script.get("npc_id", "")) == "emaciated_man":
					restarted = true
					_describe(scene, "travel_frame_%d" % frame)
					break
			await _settle()
			_describe(scene, "after_travel room=%s" % [scene.get("_run_state").get("current_room")])
	_expect(not restarted, "start-room narration never restarts after the boon")
	print("EMD01 RESULT: %s" % ("FAIL" if _failed else "PASS"))
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(1 if _failed else 0)
