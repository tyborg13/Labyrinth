extends SceneTree

const Fixtures = preload("res://tools/ptf04/fixtures.gd")
const Map = preload("res://scripts/section_map_panel.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Builder = preload("res://scripts/item_preview_builders.gd")
const Store = preload("res://scripts/progression_store.gd")
const WALLET_CASES: Array = [[16, 18, 34], [145, 7, 152]]
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_path("user://ptf04_progression.json")
	Store.set_run_storage_path("user://ptf04_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://ptf04_analytics")
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	await preload("res://tests/suites/section_map_v7_suite.gd").test_panel_pointer(expect)
	preload("res://tests/suites/section_map_v2_suite.gd")._test_probe_fixture(expect)
	var expected: Dictionary = {
		"combat": "Defeat every foe.",
		"guardian": "A tough foe holds this room. Richer rewards.",
		"event": "A choice, often with a cost.",
		"scavenger": "Trade Embers for supplies.",
		"graftwright": "Bring two gear pieces of the same kind; one inherits the other's card.",
		"treasure": "Claim 1 of 3 relics.",
		"campfire": "Rest to heal, or bank your Embers and end the run.",
		"boss": "The section's dragon.",
		"unknown": "Anything could be here. Scout reveals it.",
	}
	for type: String in expected:
		expect(Map.type_description(type) == expected[type], "Pinned map description: " + type)
	var panel := Map.new()
	root.add_child(panel)
	panel.set_run_state(Fixtures.combat_run())
	for type: String in Map.LEGEND_ORDER:
		expect(not Map.type_description(type).is_empty(), "Description: " + type)
		panel._add_legend_item(type)
		var legend: Control = panel.get("_legend").get_child(panel.get("_legend").get_child_count() - 1)
		expect(legend.tooltip_text == Map.type_description(type), "Legend hover: " + type)
		if type.begins_with("special_"):
			expect(Map.type_description(type) == Specials.tooltip_line({"special_type": type.trim_prefix("special_")}), "Reuse special copy: " + type)
	var room: Dictionary = preload("res://scripts/section_map_graph.gd").room(panel.run_state, panel.run_state["current_room"])
	room["revealed"] = true
	for type: String in ["combat", "event", "scavenger", "graftwright", "treasure", "campfire", "boss", "guardian"]:
		room["type"] = type
		expect(panel.room_description(panel.run_state["current_room"]).contains(Map.type_description(type)), "Node hover: " + type)
	room["revealed"] = false
	expect(panel.room_description(panel.run_state["current_room"]).contains(Map.type_description("unknown")), "Hidden room stays unknown")
	panel.queue_free()

	var builder := Builder.new()
	builder.equipment_locked = true
	var board_tooltip: Control = builder.equipment_tooltip("training_sword", false, true)
	var character_tooltip: Control = builder.equipment_tooltip("training_sword")
	expect(_text(board_tooltip).contains(Builder.BOARD_GEAR_CLAIM_TEXT) and not _text(board_tooltip).contains("Locked in combat"), "Board gear explains claim and expiry")
	expect(_text(character_tooltip).contains("Locked in combat"), "Character gear retains combat lock")
	board_tooltip.free()
	character_tooltip.free()
	var strip := preload("res://scripts/ui_card_strip.gd").new()
	strip.setup("pale_spark", "Pale Spark", 2)
	expect(_text(strip).contains("×2") and not _text(strip).contains("+2"), "Shared deck strips use multiplication sign")
	strip.free()

	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var state: Dictionary = Fixtures.combat_run()
	# Exercise the registered production callback as well as the shared builder.
	# Menu inspections must never inherit the board-only claim/expiry footer.
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	await process_frame
	var live_board: Control = scene.get("board_view")
	var pickup_tip: Control = live_board.call("_make_custom_tooltip", "equipment:training_sword")
	var menu_tip: Control = scene.call("_build_equipment_tooltip_panel", "training_sword")
	expect(pickup_tip != null and _text(pickup_tip).contains(Builder.BOARD_GEAR_CLAIM_TEXT) and not _text(pickup_tip).contains("Locked in combat"), "Registered board callback uses only the pickup footer")
	expect(menu_tip != null and _text(menu_tip).contains("Locked in combat") and not _text(menu_tip).contains(Builder.BOARD_GEAR_CLAIM_TEXT), "Combat equip-menu callback keeps its lock without board-pickup copy")
	if pickup_tip != null: pickup_tip.free()
	if menu_tip != null: menu_tip.free()
	var engine := Fixtures.Run.new()
	for pair: Array in WALLET_CASES:
		var before: Dictionary = engine.set_held_embers(state, int(pair[0]))
		var combat: Dictionary = Fixtures.fatal_combat(before)
		combat["room_embers"] = int(pair[1])
		var terminal: Dictionary = engine.finish_combat(before, combat)
		var receipt: Dictionary = preload("res://scripts/analytics_snapshots.gd").run_ended(engine, terminal, "defeat")
		expect(int(receipt["held_embers"]) == int(pair[2]), "Existing run_ended wallet field includes fatal earnings")
		expect(engine.held_embers(terminal) == int(pair[2]), "Defeat settles HUD wallet: " + str(pair[2]))
		scene.set("_defeat_loss_processed", false)
		var settled: Dictionary = scene.call("_finalize_terminal_committed_state", terminal)
		expect(int(Store.recovery_marker(settled["progression"]).get("amount", 0)) == int(pair[2]), "Marker preserves fatal-fight earnings")
		expect(int(scene.get("_defeat_lost_amount")) == int(pair[2]), "Recap uses marker amount")
		var model: Dictionary = preload("res://scripts/run_end_recap_overlay.gd").build_model(settled, settled["progression"], "defeat", int(scene.get("_defeat_lost_amount")))
		expect(str(model["embers_text"]).begins_with("Embers lost %d." % int(pair[2])), "Death line states full HUD amount")
		expect(engine.held_embers(settled) == 0, "Terminal wallet clears after recording marker")
		var replay: Dictionary = scene.call("_finalize_terminal_committed_state", settled)
		expect(Store.recovery_marker(replay["progression"]) == Store.recovery_marker(settled["progression"]), "Settlement replay preserves marker")

	for spare: bool in [false, true]:
		for unread: bool in [false, true]:
			state["equipment_inventory"] = ["iron_cleaver"] if spare else []
			state[Fixtures.Run.UNREAD_LOADOUT_EQUIPMENT_KEY] = ["iron_cleaver"] if unread else []
			state[Fixtures.Run.UNREAD_LOADOUT_MAGIC_KEY] = ["pale_spark"]
			var button := Button.new()
			root.add_child(button)
			preload("res://scripts/pre_battle_view.gd")._add_equip_new_tag(scene, button, state)
			expect(button.get_node("PreBattleEquipNewTag").visible == (spare and unread), "Equip NEW tracks unread spare gear only")
			button.queue_free()

	var event_state: Dictionary = preload("res://tests/suites/event_view_suite.gd").fixture("hoarfrost_spring")
	event_state["event_state"]["page"] = "result"
	event_state["event_state"]["result_text"] = ""
	var view := preload("res://scripts/event_view.gd").new()
	root.add_child(view)
	view.present(event_state, true)
	view.finish_animation_for_test()
	expect(_text(view).contains("You move on."), "Empty event outcome has fallback")
	view.queue_free()
	scene.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("PTF04 FOCUSED CHECKS: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _text(node: Node) -> String:
	var text: String = node.get_parsed_text() if node is RichTextLabel else (str(node.get("text")) if node is Label else "")
	for child: Node in node.get_children(): text += "\n" + _text(child)
	return text
