extends RefCounted

const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const TEST_DRAW_CARDS: Array = ["quick_stab", "quick_stab", "brace"]
const TEST_DISCARD_CARDS: Array = ["quick_stab", "quick_stab", "quick_stab", "brace"]
# Combat deliberately shows one pooled card per copy. Only Purge uses a
# medallion count, so duplicate combat cards must remain separate and unbadged.

static func run(fixture: SceneTree, expect: Callable, capture: bool = false) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = fixture.call("_run_with_available_combat", engine)
	expect.call(not state.is_empty(), "Combat pile fixture finds a real combat")
	if state.is_empty(): return
	var coord: Vector2i = fixture.call("_first_available_combat_coord", engine, state)
	state = engine.move_to_room(state, coord)
	var combat: Dictionary = state["combat_state"]
	combat["deck"]["draw"] = TEST_DRAW_CARDS.duplicate()
	combat["deck"]["discard"] = TEST_DISCARD_CARDS.duplicate()
	var instance: Node = await fixture.call("_instance", state)
	instance.set("_animation_lock", false)
	var output_dir: String = "user://probes/purge_02_pile_%d/1920x1080_ui100" % int(Time.get_unix_time_from_system())
	for pile_kind: String in ["draw", "discard"]:
		instance.call("_open_pile_view", pile_kind)
		await fixture.call("_settle")
		expect.call(instance.get("_pile_scrim").visible, "Combat duplicate fixture opens the " + pile_kind + " viewer")
		var expected: Array = TEST_DRAW_CARDS.duplicate() if pile_kind == "draw" else TEST_DISCARD_CARDS.duplicate()
		var represented: Array = []
		for entry: Dictionary in instance.get("_pile_dialog_card_pool"):
			var cell: Control = entry["button"]
			if not cell.visible: continue
			var card_id: String = str(entry["widget"].get("card_id"))
			represented.append(card_id)
		represented.sort()
		expected.sort()
		expect.call(represented == expected, "Combat viewer shows one card per copy in " + pile_kind)
		expect.call(instance.get("_pile_dialog").find_child("PileCopyCount", true, false) == null, "Combat viewer draws no copy-count badges in " + pile_kind)
		for failure: String in Presentation.text_fit_failures(instance.get("_pile_dialog")): expect.call(false, failure)
		if capture:
			await fixture.call("_capture", "%s/combat_%s_duplicates.png" % [output_dir, pile_kind])
		instance.call("_close_pile_view")
	if capture: print(ProjectSettings.globalize_path(output_dir))
	instance.queue_free()
	for _frame: int in range(Presentation.TEARDOWN_FRAMES): await fixture.process_frame
