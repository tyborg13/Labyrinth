extends SceneTree
## spx-09 native proof: the Ember Hoarder at 1920x1080, 100% UI scale.
## Captures pre-battle, the rule panel on the first and last turns, the fight
## after it slips away (Defeat All) and the catch reward. Windowed only; the
## headless semantics live in tests/hoarder_test.gd.
const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const Fixture = preload("res://tools/hoarder_inspection.gd")
const Rules = preload("res://scripts/hoarder_room_rules.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const OUTPUT: String = "user://probes/spx09"
const SETTLE_SECONDS: float = 0.25
const READY_TIMEOUT_SECONDS: float = 20.0
const CAPTURE_VISION_BONUS: int = Combat.UMBRA_UNLIMITED_RADIUS
# Debug-only endurance so staged turns never end the proof fight early.
const PROOF_PLAYER_HP: int = 100
const VARIANTS: Array = [{"biome": "fire", "tier": 2}, {"biome": "ice", "tier": 1}]
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Ember Hoarder visual proof requires the native renderer; use tools/visual_probe_runner.py --no-headless")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://spx09-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	canvas = SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.gui_embed_subwindows = true
	root.add_child(canvas)
	for variant: Dictionary in VARIANTS: await _variant(variant)
	var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	_expect(file != null, "Capture facts manifest is writable")
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": PROOF_UI_SCALE, "seed": Fixture.FIXTURE_SEED, "capture_vision_bonus": CAPTURE_VISION_BONUS, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Ember Hoarder native proof: %d captures, %d failures" % [captures.size(), failures.size()])
	print("Ember Hoarder captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

static func fixture_state(engine: RefCounted, combat: RefCounted, variant: Dictionary) -> Dictionary:
	var state: Dictionary = Fixture.build(engine, combat, engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"hoarder_biome": variant["biome"], "hoarder_tier": variant["tier"]})
	var battle: Dictionary = state["combat_state"]
	battle["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	battle["player"]["hp"] = PROOF_PLAYER_HP
	battle["player"]["max_hp"] = PROOF_PLAYER_HP
	return state

func _variant(variant: Dictionary) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var label: String = "%s_tier%d" % [variant["biome"], variant["tier"]]
	var state: Dictionary = fixture_state(engine, combat, variant)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(RenderProof.DrawCheckedBoard)
	canvas.add_child(scene)
	await process_frame
	# Pre-battle through the production factory contract.
	var pre: Dictionary = state.duplicate(true)
	pre["mode"] = "pre_battle"
	pre["pre_battle_pending"] = true
	pre["pre_battle_travel_dir"] = Fixture.FIXTURE_TRAVEL
	pre["combat_state"] = {}
	scene.set("_run_state", pre)
	var prepared: Dictionary = Fixture.prepared(engine, combat, pre)
	prepared["combat_state"]["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	scene.set("_prepared_pre_battle_factory", prepared)
	_expect(bool(scene.call("_show_pre_battle_preview")), "Hoarder pre-battle opens: " + label)
	await create_timer(SETTLE_SECONDS).timeout
	await _capture(label, "pre_battle", {"objective": prepared["combat_state"]["objective"]["name"]})
	scene.call("_close_pre_battle_preview")
	# First turn: the rule sentence and its turns left above the objective.
	await _show(scene, state, state["combat_state"])
	var clock: int = int(state["combat_state"]["objective"]["escape_after_player_turns"])
	_expect_panel(scene, Rules.rule_sentence(state["combat_state"]["objective"]), " · %d TURNS LEFT" % clock, label + " first turn")
	await _capture(label, "first_turn", _facts(state["combat_state"]))
	# Last turn before it slips away.
	var battle: Dictionary = state["combat_state"]
	for turn: int in range(clock - 1): battle = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
	_expect(Rules.at_large(battle) and combat.combat_outcome(battle) == "", "Proof survives to the last turn: " + label)
	await _show(scene, state, battle)
	_expect_panel(scene, Rules.rule_sentence(battle["objective"]), " · 1 TURN LEFT", label + " last turn")
	await _capture(label, "last_turn", _facts(battle))
	# After it slips away: Defeat All against the brood, no rule panel.
	var slipped: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
	_expect(bool(slipped["objective"]["hoarder_escaped"]) and str(slipped["objective"]["type"]) == "kill_all", "Hoarder slipped away: " + label)
	if combat.combat_outcome(slipped) == "":
		await _show(scene, state, slipped)
		var panel: Control = scene.get("ui_root").get_node("BattlefieldRuleHud")
		_expect(not panel.visible, "Rule panel hides once it slips away: " + label)
		await _capture(label, "slipped_away", _facts(slipped))
	# Catch on the first turn and its reward.
	var caught_state: Dictionary = fixture_state(engine, combat, variant)
	var caught: Dictionary = combat._damage_enemy(caught_state["combat_state"], 0, 999, true, true, false, false)
	_expect(combat.combat_outcome(caught) == "victory" and bool(caught["objective"]["hoarder_caught"]), "Catch wins at once: " + label)
	var reward: Dictionary = engine.finish_combat(caught_state, caught)
	var room: Dictionary = engine.room_metadata(caught_state, caught_state["current_room"])
	var hoard: int = Rules.hoard_embers(room, caught)
	_expect(int(reward["pending_reward"]["ember_amount"]) == Specials.reward_embers(room, caught) + hoard, "Catch pays x1.5 plus the hoard: " + label)
	scene.call("_load_run_state", reward)
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var row: Control = null
	while Time.get_ticks_msec() < deadline:
		row = scene.find_child("RewardCardRow", true, false) as Control
		if not bool(scene.call("_reward_intro_pending")) and not bool(scene.get("_reward_intro_in_progress")) and row != null and row.is_visible_in_tree() and row.get_child_count() == 4: break
		await process_frame
	_expect(row != null and row.is_visible_in_tree() and row.get_child_count() == 4, "Catch reward shows four cards: " + label)
	await create_timer(SETTLE_SECONDS).timeout
	await _capture(label, "caught_reward", {"ember_amount": reward["pending_reward"]["ember_amount"], "hoard": hoard, "notice": reward.get("notice", ""), "reward_line": reward["pending_reward"].get("special_bonus_line", "")})
	scene.queue_free()
	await process_frame

func _show(scene: Node, state: Dictionary, battle: Dictionary) -> void:
	var shown: Dictionary = state.duplicate(true)
	shown["combat_state"] = battle
	scene.call("_load_run_state", shown)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await _await_units_drawn(scene.get("board_view"), battle)
	await create_timer(SETTLE_SECONDS).timeout

func _expect_panel(scene: Node, sentence: String, turns_suffix: String, context: String) -> void:
	var panel: Control = scene.get("ui_root").get_node("BattlefieldRuleHud")
	var kicker: Label = panel.find_child("RuleKicker", true, false) as Label
	var detail: Label = panel.find_child("RuleSentence", true, false) as Label
	_expect(panel.visible and detail != null and detail.text == sentence, "Rule panel shows the sentence: " + context)
	_expect(kicker != null and kicker.text.ends_with(turns_suffix), "Rule panel shows the turns left: " + context)

func _facts(battle: Dictionary) -> Dictionary:
	var hoarder: Dictionary = Rules.hoarder_unit(battle)
	return {"objective": battle["objective"].duplicate(true), "hoarder": hoarder.duplicate(true), "turns_left": Rules.turns_left(battle), "panel": Rules.panel(battle)}

func _capture(label: String, study: String, facts: Dictionary) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == PROOF_SIZE, "Capture is exactly 1920x1080")
	var output: String = OUTPUT.path_join(label)
	var path: String = output.path_join(study + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_expect(image.save_png(path) == OK, "Capture writes " + path)
	var recorded: Dictionary = facts.duplicate(true)
	recorded.merge({"path": path, "case": study, "variant": label})
	captures.append(recorded)
	print("Ember Hoarder capture: " + ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _await_units_drawn(board: Node, state: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		errors = RenderProof.renderer_readiness_errors(board, state)
		if errors.is_empty():
			board.drawn_unit_keys.clear()
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var required: Array[String]
			required.append("player")
			for enemy: Dictionary in state["enemies"]:
				if int(enemy["hp"]) > 0: required.append("enemy_%d" % int(enemy["id"]))
			for key: String in required:
				if not board.drawn_unit_keys.has(key): errors.append(key + " body was not drawn")
			if errors.is_empty(): return
		await process_frame
	_expect(false, "Every native actor must be prepared and drawn: " + "; ".join(errors))
