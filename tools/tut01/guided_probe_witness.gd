extends "res://tests/contextual_combat_tutorial_probe.gd"

const Data = preload("res://scripts/game_data.gd")
const COMBAT_FIXTURE_SEED: int = 90211

var _assertions_checked: int = 0


func _initialize() -> void:
	_run_headless.call_deferred()


func _run_headless() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("Use the task runner in headless mode for the guided probe witness.")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--combat-receipt"):
		_witness_combat_variants()
		return
	# Drive presentation awaits in the same manner as the headless HUD tests.
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	await super._initialize()
	print("TUT-01 guided probe assertions checked: %d" % _assertions_checked)


func _assert(condition: bool, message: String) -> void:
	_assertions_checked += 1
	super._assert(condition, message)


func _save_root_screenshot(path: String) -> void:
	var checkpoint: String = path.get_file().get_basename()
	if checkpoint not in ["02_exact_move_pulse", "10_bone_dart_target", "11_first_play_spent", "14_kill_refund"]:
		return
	var scene: Node = root.get_node("RunScene")
	var fight: Dictionary = scene.get("_combat_state")
	var combat: RefCounted = scene.get("_combat_engine")
	var pale_spark: Dictionary = combat.card_def(GuidedCombatScenario.PREVIEW_CARD_ID, fight)
	var quick_stab: Dictionary = combat.card_def(GuidedCombatScenario.KILL_CARD_ID, fight)
	print("TUT-01 %s: phase=%s crawler_hp=%d pale_spark=%d quick_stab=%d legacy=%s hand=%s collected=%s" % [
		checkpoint, scene.get("_guided_tutorial_phase_id"), _enemy_hp(fight, GuidedCombatScenario.TARGET_ENEMY_ID),
		int(pale_spark["actions"][0]["damage"]), int(quick_stab["actions"][0]["damage"]),
		fight.get(Data.LEGACY_STARTER_CARDS_KEY, false), fight["deck"]["hand"], fight.get("collected_equipment", []),
	])


func _witness_combat_variants() -> void:
	var engine := RunEngine.new()
	var combat := CombatEngine.new()
	for legacy: bool in [false, true]:
		var profile: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
		var run: Dictionary = GuidedCombatScenario.mark_run_eligible(engine.create_new_run(COMBAT_FIXTURE_SEED, profile))
		if legacy:
			run.erase(RunEngine.FIRST_COMBAT_WON_KEY)
			run[Data.LEGACY_STARTER_CARDS_KEY] = true
		for destination: Vector2i in engine.available_moves(run):
			if engine.room_metadata(run, destination).get("type") == "combat":
				run = engine.move_to_room(run, destination)
				break
		var fight: Dictionary = run.get("combat_state", {})
		if not GuidedCombatScenario.is_authored(fight):
			_fail("Witness requires a production guided room")
			quit(1)
			return
		var hand: Array = fight["deck"]["hand"].duplicate()
		var before: int = _enemy_hp(fight, GuidedCombatScenario.TARGET_ENEMY_ID)
		fight = combat.apply_player_movement(fight, GuidedCombatScenario.move_tile(fight))
		var collected: Array = fight.get("collected_equipment", []).duplicate()
		var target: Vector2i = GuidedCombatScenario.target_tile(fight)
		fight = _resolve_witness_card(combat, fight, GuidedCombatScenario.PREVIEW_CARD_ID, target)
		var after_spark: int = _enemy_hp(fight, GuidedCombatScenario.TARGET_ENEMY_ID)
		fight = _resolve_witness_card(combat, fight, GuidedCombatScenario.KILL_CARD_ID, target)
		var after_stab: int = _enemy_hp(fight, GuidedCombatScenario.TARGET_ENEMY_ID)
		print("TUT-01 combat receipt: starter=%s crawler_hp=%d -> %d -> %d pale_spark_dealt=%d collected=%s hand=%s" % [
			"legacy" if legacy else "current", before, after_spark, after_stab, before - after_spark, collected, hand,
		])
		_assert(before == (12 if legacy else 9) and before - after_spark == 3 and after_stab == 0, "Both starter variants preserve the scripted two-card kill")
		_assert(combat.cards_remaining_this_turn(fight) == 1, "Both starter variants refund one card play after the kill")
	print("TUT-01 COMBAT RECEIPT: %s" % ("FAIL" if _failed else "PASS"))
	quit(int(_failed))


func _resolve_witness_card(combat: RefCounted, fight: Dictionary, card_id: String, target: Vector2i) -> Dictionary:
	var index: int = fight["deck"]["hand"].find(card_id)
	var ready: Dictionary = combat.prepare_player_card(fight, index, "play")
	var action: Dictionary = combat.card_play_actions(card_id, ready)[0]
	var resolved: Dictionary = combat.apply_player_action(ready, action, target)
	return combat.finish_player_card(resolved, index, 1, {"play_mode": "play"})
