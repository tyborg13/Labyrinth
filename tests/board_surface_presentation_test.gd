extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Floor = preload("res://scripts/board_surface_presentation.gd")
const ChainFeedback = preload("res://scripts/chain_attack_feedback.gd")
const Aim = preload("res://scripts/surface_aim_flow.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var text: String = Icons.plain_text_for_tokens(Icons.tokens_for_action({"type": "surface", "surface": "ice", "range": 4}))
	assert("Ice" in text)
	assert("Fire" in Floor.tooltip({"surfaces": {"1,1": {"elemental": "fire", "rubble": true}}}, Vector2i.ONE))
	assert("Rubble" in Floor.tooltip({"surfaces": {"1,1": {"elemental": "fire", "rubble": true}}}, Vector2i.ONE))
	var native_hits: Array = [
		{"kind": "actor", "from": Vector2i(2, 2), "to": Vector2i(2, 2), "state": {"revision": 1}},
		{"kind": "actor", "from": Vector2i(3, 2), "to": Vector2i(3, 2), "state": {"revision": 2}},
		{"kind": "relay", "from": Vector2i(3, 2), "to": Vector2i(4, 2), "state": {"revision": 3}},
		{"kind": "conduction", "from": Vector2i(4, 2), "to": Vector2i(5, 2), "state": {"revision": 4}},
		{"kind": "conduction", "from": Vector2i(4, 2), "to": Vector2i(5, 3), "state": {"revision": 5}},
	]
	var beats: Array = ChainFeedback._presentation_beats(native_hits)
	assert(beats.size() == 3, "Native AoE and one component each share one beat, with one intervening relay")
	assert(int(beats[0]["state"]["revision"]) == 2 and int(beats[2]["state"]["revision"]) == 5)
	var scene := Scene.new()
	assert(not scene.call("_has_electrical_trace", native_hits.slice(0, 2)), "Native AoE never invents Chain lightning")
	assert(scene.call("_has_electrical_trace", native_hits))
	var leaving_ice: Array[Vector2i]
	leaving_ice.assign([Vector2i.ONE, Vector2i(2, 1)])
	assert(scene.call("_preview_path_hits_lookup", leaving_ice, {Vector2i.ONE: true}), "Leaving Ice must resolve Chill departure in previews")
	var analytics = preload("res://scripts/analytics_store.gd")
	var combat := preload("res://scripts/combat_engine.gd").new()
	await _test_board_surface_cancel(combat)
	_test_detonate_card_damage(scene, combat)
	analytics.set_storage_dir("user://surface_presentation_analytics")
	analytics.clear_storage()
	_test_rubble_stop_presentation(scene, combat)
	var state: Dictionary = preload("res://tests/suites/chain_attack_suite.gd").fixture(combat)
	state["analytics"] = {"combat_id": "surface_dedupe_proof"}
	var ground = preload("res://scripts/board_surface_rules.gd")
	ground.place(state, Vector2i(3, 4), "fire", {"card_id": "proof_card", "player_card": true})
	scene.call("_analytics_flush_surface_events", state)
	scene.call("_analytics_flush_surface_events", state)
	var events: Array = analytics.load_all_events()
	assert(events.size() == 1, "Repeated committed snapshots emit each ground event once")
	assert(int(events[0]["rules_version"]) == 4)
	assert(str(events[0]["payload"]["source"]["card_id"]) == "proof_card")
	ground.remove(state, Vector2i(3, 4), "fire", "detonate")
	scene.call("_analytics_flush_surface_events", state)
	assert(analytics.load_all_events().size() == 2, "Later events append without replaying the prior action")
	scene.free()
	var resumed := Scene.new()
	resumed.call("_analytics_flush_surface_events", state)
	assert(analytics.load_all_events().size() == 2, "Reopening the same combat retains durable deduplication")
	resumed.free()
	print("TEST RESULT: PASS board surface presentation")
	quit()

func _test_board_surface_cancel(combat: RefCounted) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	root.add_child(view)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_refresh_ui")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var aim: RefCounted = scene.get("_surface_aim")
	aim.call("begin", "prismatic_instinct", false)
	await scene.call("_on_board_cancel_requested")
	assert(not aim.call("active"), "Board right-click/B must cancel Prismatic targeting")
	aim.call("begin", "confluence", true)
	aim.set("origin", Vector2i(3, 4))
	await scene.call("_on_board_cancel_requested")
	assert(not aim.call("active") and aim.get("origin") == Vector2i(-1, -1), "Board right-click/B must discard Confluence's selected source")
	assert(scene.get("_combat_state") == before, "Cancelling ground selection must not spend the ability or change the board")
	view.queue_free()
	await process_frame

func _test_detonate_card_damage(scene: Node, combat: RefCounted) -> void:
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["relics"] = ["bloodglass_knife"]
	state["player"]["max_hp"] = 100
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	var action: Dictionary = preload("res://scripts/game_data.gd").card_def("rekindle_edge")["actions"][1]
	for health: int in [30, 100]:
		state["player"]["hp"] = health
		var display: Dictionary = scene.call("_card_widget_display", "rekindle_edge", state)
		var expected: int = combat.final_damage_for_player_action(state, action)
		assert((str(display["summary_bbcode"])).contains("Detonate %d" % expected), "Detonate card values must reflect active and inactive conditional damage bonuses")

func _test_rubble_stop_presentation(scene: Node, combat: RefCounted) -> void:
	var state: Dictionary = preload("res://tests/suites/board_surface_suite.gd").fixture(combat)
	state["enemies"][0]["pos"] = Vector2i(7, 3)
	state["traps"] = [{"id": "presentation_earth", "pos": Vector2i(3, 3), "element": "earth", "damage": 0}]
	var requested := Vector2i(4, 3)
	var action: Dictionary = combat.player_movement_action(state)
	var planned: Array = combat.path_for_player_action(state, action, requested)
	var grouped: Dictionary = combat.apply_player_movement(state, requested)
	var endpoint: Vector2i = grouped["player"]["pos"]
	assert(endpoint == Vector2i(3, 3) and int(grouped["player_movement_remaining"]) == 1)
	var shown: Array = scene.call("_resolved_movement_animation_path", state["player"]["pos"], endpoint, planned)
	assert(shown == [Vector2i(2, 3), Vector2i(3, 3)], "Grouped walk presentation must stop at the Earth trap before its newly painted Rubble")
	var bent: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(3, 3), bent) == bent.slice(0, 3), "Early-stop trimming must preserve intermediate corners for player and enemy paths")
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(2, 2), bent) == [Vector2i(2, 2)], "A stopped actor must not animate a zero-distance segment")
	var returning: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 2)]
	assert(scene.call("_resolved_movement_animation_path", Vector2i(2, 2), Vector2i(2, 2), returning) == returning, "A resolved enemy route through a lit pocket must retain its outward and returning segments")
