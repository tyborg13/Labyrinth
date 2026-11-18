extends "res://tests/pre_battle_fixture.gd"

const LastLight = preload("res://tools/last_light_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const OUTPUT: String = "user://probes/chk-01/last_light_boosted_tooltip.png"
const LAST_LIGHT_BONUS: int = 4
const START_POINTER := Vector2(80, 80)
const POPUP_TIMEOUT_MSEC: int = 3000
const POLL_SECONDS: float = 0.05

func _initialize() -> void:
	_setup()
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	call_deferred("_run")

func _run() -> void:
	var run := RunEngine.new()
	var combat := Combat.new()
	var state: Dictionary = LastLight.build(run, combat, run.create_new_run(LastLight.FIXTURE_SEED, ProgressionStore.default_data()), {"last_light_case": "pre_battle"})
	var scene: Node = await _instance(state)
	scene.set("_prepared_pre_battle_factory", LastLight.prepared(run, combat, state))
	_expect(bool(scene.call("_show_pre_battle_preview")), "Last Light production pre-battle opens")
	await _settle()
	var panel: Control = scene.get("_pre_battle_panel")
	var foe: Control
	for candidate: Node in panel.find_children("PreBattleEnemyCard*", "Button", true, false):
		if candidate.get("enemy").get("type") == "wick_shade":
			foe = candidate
			break
	_expect(foe != null, "Last Light pre-battle roster has its Wick Shade control")
	if foe != null:
		var battle: Dictionary = scene.get("_pre_battle_preview_run_state")["combat_state"]
		var enemy: Dictionary = foe.get("enemy")
		var baseline: Dictionary = battle.duplicate(true)
		baseline.erase("difficulty_stats")
		var intents: Array = GameData.enemy_def("wick_shade")["intents"]
		var grasp: Dictionary = combat._intent_by_id(intents, "grasp")
		var normal: Dictionary = combat._scale_enemy_intent(grasp, int(battle["room_depth"]), baseline, enemy)
		var expected: int = int(normal["actions"][1]["damage"]) + LAST_LIGHT_BONUS
		if DisplayServer.get_name() == "headless":
			var tooltip: Control = scene.call("_build_pre_battle_enemy_inspection_panel", foe.get("enemy"))
			_assert_tooltip(tooltip, expected)
			tooltip.free()
		else:
			root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
			_viewport.gui_release_focus()
			await _pointer(START_POINTER)
			await _pointer(foe.get_global_rect().get_center())
			var popup: Window = await _hover_popup(foe)
			_expect(popup != null, "Pointer opens the native Wick Shade tooltip")
			if popup != null:
				_assert_tooltip(popup, expected)
				if not _failed: await _capture(OUTPUT)
	print("CHK01 TOOLTIP PROBE: %s (%s)" % ["FAIL" if _failed else "PASS", "headless dossier content" if DisplayServer.get_name() == "headless" else OUTPUT])
	quit(1 if _failed else 0)

func _assert_tooltip(node: Node, expected: int) -> void:
	var rows: Array[Node] = node.find_children("PreBattleMoveEffect", "Label", true, false)
	var wanted: String = "Melee %d" % expected
	var shown: String = "" if rows.is_empty() else (rows[0] as Label).text
	_expect(shown.contains(wanted), "Grasp must show %s. Got %s" % [wanted, shown])
	if shown.contains(wanted): print("CHK01 GRASP TOOLTIP: " + shown)

func _pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_viewport.push_input(event, true)
	await process_frame

func _hover_popup(foe: Control) -> Window:
	var deadline: int = Time.get_ticks_msec() + POPUP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		for child: Node in foe.find_children("*", "Window", true, false):
			var popup := child as Window
			if popup.visible and not popup.is_queued_for_deletion() and popup.theme_type_variation == &"TooltipPanel":
				return popup
		await create_timer(POLL_SECONDS).timeout
	return null
