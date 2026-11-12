extends "res://tools/ptf08/action_checks.gd"

# Headless regressions for the five owner/review repros. Fixture setup may use
# scene helpers; defect 5's selection and stationary pointer use only real input.
const SETTLE_FRAMES: int = 20
const HIDDEN_TILE := Vector2i(5, 4)

func _initialize() -> void:
	_initialize_test_storage()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await hidden_mutations()
	await winning_kill()
	await shortcut_hover()
	await surface_commit()
	await lifecycle_exits()
	await pointer_confirmation()
	print("PTF08 ORIGINAL DEFECT RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	unseen_floor_mutations()
	known_floor_sources()
	print("PTF08 PRIOR DEFECT RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	loss_row_repros()
	await pointer_exit_repros()
	print("PTF08 ROUND2 DEFECT RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	recovery_ruling_checks()
	scene.queue_free()
	await process_frame
	for failure: String in _failures: print("FAIL: " + failure)
	print("PTF08 DEFECT RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func hidden_fixture() -> Dictionary:
	var fog: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("danger")
	fog["umbra"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("umbra")["umbra"]
	fog["deck"]["hand"] = ["patch_up"]
	fog["enemies"][0]["type"] = "briar_weaver"
	for intent: Dictionary in GameData.enemy_def("briar_weaver")["intents"]:
		if intent["id"] == "root_mend": fog["enemies"][0]["intent"] = intent.duplicate(true)
	fog["turn_queue"][0]["type"] = "briar_weaver"
	fog["turn_queue"][0]["name"] = "Briar Weaver"
	var unseen: Dictionary = fog["enemies"][0].duplicate(true)
	unseen.merge({"id": 2, "type": "crawler", "pos": HIDDEN_TILE, "hp": 14}, true)
	fog["enemies"].append(unseen)
	fog["turn_queue"].append({"kind": "enemy", "enemy_id": 2, "actor_key": "enemy_2", "name": "Tunnel Crawler", "type": "crawler", "time": 100, "seq": 2, "pos": HIDDEN_TILE})
	var second: Dictionary = unseen.duplicate(true)
	second.merge({"id": 3, "pos": Vector2i(6, 5)}, true)
	fog["enemies"].append(second)
	fog["turn_queue"].append({"kind": "enemy", "enemy_id": 3, "actor_key": "enemy_3", "time": 101, "seq": 3, "pos": Vector2i(6, 5)})
	return fog

func hidden_mutations() -> void:
	var baseline: Array = []
	for actor: int in [1, 2]:
		for mutation: Dictionary in [{}, {"hp": 5}, {"pos": Vector2i(7, 4)}, {"intent": {}}, {"bleed": 12, "stagger": 9}]:
			var fog: Dictionary = hidden_fixture()
			fog["enemies"][actor].merge(mutation, true)
			if mutation.has("pos"): fog["turn_queue"][actor]["pos"] = mutation["pos"]
			_install_pass_preview_chip_state(scene, fog)
			scene.call("_on_card_pressed", 0)
			scene.call("_refresh_selected_card_forecast")
			var rows: Array = chip().get_meta("forecast_rows", []).duplicate(true)
			if baseline.is_empty(): baseline = rows
			_assert(not scene.get("_combat_engine").is_enemy_visible_to_player(fog, fog["enemies"][actor]), "D1 mutated actor remains undisclosed")
			_assert(rows == baseline, "D1 identical panel rows for hidden actor %d mutation %s" % [actor, str(mutation)])
			_assert(scene.call("_pass_preview_source_state")["enemies"].size() == 1, "D1 numeric source contains only the disclosed Weaver")
			print("D1 actor=", actor, " mutation=", mutation, " hp_loss=", scene.call("_pass_preview_summary").get("hp_loss"), " rows=", rows)

func winning_kill() -> void:
	var limited_rows: Array = []
	for variant: String in ["limited", "limited_hidden", "full"]:
		var limited: bool = variant != "full"
		var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("danger")
		if limited: state["umbra"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("umbra")["umbra"]
		state["player"]["hp"] = 10
		state["deck"]["hand"] = ["quick_stab"]
		state["deck"]["draw"] = []
		state["enemies"][0]["hp"] = 6
		if variant == "limited_hidden":
			state["enemies"].append(hidden_fixture()["enemies"][1])
			state["turn_queue"].append(hidden_fixture()["turn_queue"][1])
		_install_pass_preview_chip_state(scene, state)
		scene.call("_on_card_pressed", 0)
		scene.call("_on_board_tile_hovered", ENEMY_TILE)
		scene.call("_refresh_board_hover_presentation")
		var summary: Dictionary = scene.call("_pass_preview_summary")
		var engine: RefCounted = scene.get("_combat_engine")
		var actual: Dictionary = engine.prepare_player_card(state, 0)
		var actions: Array = engine.card_play_actions("quick_stab", actual)
		actual = engine.finish_player_card(engine.apply_player_action(actual, actions[0], ENEMY_TILE), 0)
		_assert(engine.combat_outcome(actual) == ("" if variant == "limited_hidden" else "victory") and actual["player"]["hp"] == 10, "D2 committing ends only when no hidden foe remains, retaining 10 HP")
		_assert(not summary.is_empty() and summary["hp_loss"] == 0 and summary["fatigue_loss"] == 0 and not summary["defeat"], "D2 winning kill never forecasts loss or defeat")
		if limited:
			_assert(bool(summary.get("umbra_unknown_before_player", false)), "D2 limited sight cannot disclose victory")
			_assert(not str(chip().get_meta("forecast_rows", [])).contains("Safe"), "D2 limited victory shows ? without Safe")
		if variant == "limited": limited_rows = chip().get_meta("forecast_rows", []).duplicate(true)
		if variant == "limited_hidden": _assert(chip().get_meta("forecast_rows", []) == limited_rows, "D2 hidden foe presence cannot be inferred from panel rows")
		print("D2 variant=", variant, " summary=", summary, " actual=", engine.combat_outcome(actual))

func shortcut_hover() -> void:
	var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("danger")
	state["deck"]["hand"] = ["sidestep_slash"]
	state["enemies"][0]["pos"] = Vector2i(4, 4)
	state["turn_queue"][0]["pos"] = Vector2i(4, 4)
	_install_pass_preview_chip_state(scene, state)
	scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Vector2i(4, 4))
	scene.call("_refresh_board_hover_presentation")
	var plan: Dictionary = scene.call("_shortcut_plan_for_tile", scene.call("_active_card_preview"), Vector2i(4, 4))
	_assert(not plan.is_empty(), "D3 shortcut exists")
	check_panel("D3 shortcut hover")
	var source: Dictionary = scene.call("_pass_preview_source_state")
	_assert(source["enemies"][0]["hp"] < 14 and source["player"]["pos"] != HERO_TILE, "D3 shortcut source includes movement and strike")
	print("D3 trigger=", Presentation.preview_active(scene), " panel=", chip().get_meta("pass_forecast_active", false))

func surface_commit() -> void:
	await install("brace", 14)
	scene.get("_combat_state")["skill_ids"] = ["prismatic_instinct"]
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_begin_surface_skill_selection", "prismatic_instinct")
	var tile: Vector2i = scene.get("_surface_skill_tiles")[0]
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	var panel: Control = chip().get_node("PassForecastFocusTooltip")
	var fade: Node = panel.get_node("ForecastFade")
	fade.call("sample", int(fade.get("started_usec")) + 120000)
	_assert(panel.modulate.a == 1.0, "D4 surface preview starts fully visible")
	scene.call("_commit_surface_skill_tile", tile)
	await create_timer(0.20).timeout
	_assert(not bool(chip().get_meta("pass_forecast_active", true)) and panel.modulate.a == 0.0 and not panel.visible, "D4 commit fades panel out within 200 ms")
	for badge: Control in chip().get_meta("forecast_fade_badges", []):
		_assert(not badge.visible and badge.modulate.a == 0.0, "D4 badge fades with panel")
	print("D4 lock=", scene.get("_animation_lock"), " active=", chip().get_meta("pass_forecast_active", false), " alpha=", panel.modulate.a)
	await create_timer(0.8).timeout

func lifecycle_exits() -> void:
	for transition: String in ["cancel", "deselect", "lock", "turn_end", "fight_end", "dialogue", "drag"]:
		await install("brace", 14, "second_move")
		scene.call("_on_card_pressed", 0)
		scene.call("_refresh_selected_card_forecast")
		var panel: Control = chip().get_node("PassForecastFocusTooltip")
		var fade: Node = panel.get_node("ForecastFade")
		fade.call("sample", int(fade.get("started_usec")) + 120000)
		var badges: Array = chip().get_meta("forecast_fade_badges", [])
		_assert(not badges.is_empty(), "D4 " + transition + " uses real repeat badges")
		match transition:
			"cancel": scene.call("_cancel_card_selection")
			"deselect": scene.set("_selected_card_index", -1)
			"lock": scene.set("_animation_lock", true)
			"turn_end": scene.get("_combat_state")["current_actor"] = {"kind": "enemy"}
			"fight_end": scene.get("_run_state")["mode"] = "room"
			"dialogue": scene.set("_dialogue_active", true)
			"drag": scene.set("_drag_card_index", 0)
		await process_frame
		await process_frame
		_assert(float(fade.get("target")) == 0.0 and not bool(chip().get_meta("pass_forecast_active", true)), "D4 " + transition + " starts fade without hover refresh")
		fade.call("sample", int(fade.get("started_usec")) + 120000)
		_assert(not panel.visible and panel.modulate.a == 0.0, "D4 " + transition + " finishes 0.12 s fade")
		for badge: Control in badges:
			if is_instance_valid(badge): _assert(not badge.visible and badge.modulate.a == 0.0, "D4 " + transition + " fades rail badge")
		scene.set("_dialogue_active", false)
		scene.set("_drag_card_index", -1)

func pointer_confirmation() -> void:
	await install("brace", 14)
	var card: Control = scene.call("_hand_card_control", 0) as Control
	var point: Vector2 = card.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	for _frame: int in range(SETTLE_FRAMES): await process_frame
	var panel: Control = chip().get_node("PassForecastFocusTooltip")
	_assert(bool(scene.call("_pending_card_requires_confirmation")), "D5 real pointer click selects Brace confirmation")
	_assert(bool(chip().get_meta("pass_forecast_active", false)) and panel.is_visible_in_tree() and is_equal_approx(panel.modulate.a, 1.0), "D5 stationary pointer over Brace shows fully visible panel")
	_assert(int(scene.call("_pass_preview_summary")["block_loss"]) == 6, "D5 real path retains Block -6 summary")
	print("D5 selected=", scene.get("_selected_card_index"), " confirm=", scene.call("_pending_card_requires_confirmation"), " active=", chip().get_meta("pass_forecast_active", false), " visible=", panel.is_visible_in_tree(), " alpha=", panel.modulate.a)

# Fixture-only movement budget exposes an unseen intermediate tile as well as
# the review's original destination. Actual route tiles determine the matrix.
const FLOOR_DESTINATIONS: Array[Vector2i] = Array([Vector2i(2, 2), Vector2i(2, 1)], TYPE_VECTOR2I, "", null)
const FLOOR_PROOF_MOVEMENT: int = 4
const FLOOR_PROOF_ID: int = 77

class FloorCombat extends CombatEngine:
	func player_movement_capacity(_state: Dictionary) -> int:
		return FLOOR_PROOF_MOVEMENT

func floor_fixture() -> Dictionary:
	var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("danger")
	state["umbra"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("umbra")["umbra"]
	state["deck"]["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	state["deck"]["draw"] = []
	state["equipped_items"] = []
	state["loot"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["player_movement_remaining"] = FLOOR_PROOF_MOVEMENT
	state["player_movement_capacity"] = FLOOR_PROOF_MOVEMENT
	return state

func floor_preview(state: Dictionary, destination: Vector2i) -> Dictionary:
	_install_pass_preview_chip_state(scene, state)
	scene.call("_begin_player_movement_selection")
	scene.call("_on_board_tile_hovered", destination)
	scene.call("_refresh_board_hover_presentation")
	return scene.call("_pass_preview_summary")

func unseen_floor_mutations() -> void:
	scene.set("_combat_engine", FloorCombat.new())
	for destination: Vector2i in FLOOR_DESTINATIONS:
		var empty: Dictionary = floor_fixture()
		var summary: Dictionary = floor_preview(empty, destination)
		var baseline: Array = chip().get_meta("forecast_rows", []).duplicate(true)
		var engine: RefCounted = scene.get("_combat_engine")
		var movement: Dictionary = engine.movement_plan_for_player_action(empty, scene.get("_player_movement_action"))
		var path: Array = movement.get("paths", {}).get(destination, [])
		_assert(not path.is_empty() and path.has(destination), "D6 matrix uses the real movement path")
		_assert(summary["hp_loss"] == 15 and summary["fatigue_loss"] == 15, "D6 empty unseen destination has the review's Health/Fatigue loss")
		_assert(not bool(summary.get("umbra_unknown_before_player", false)), "D6 unseen empty ground adds no ?")
		for tile: Vector2i in path:
			if engine.is_tile_visible_to_player(empty, tile): continue
			for content: String in ["loot", "traps", "surfaces"]:
				for operation: String in ["add", "change", "remove"]:
					var state: Dictionary = empty.duplicate(true)
					if operation != "remove":
						match content:
							"loot": state["loot"] = [{"id": FLOOR_PROOF_ID, "kind": "item", "card_id": "crimson_draught" if operation == "add" else "mossglass_elixir", "pos": tile, "claimed": false}]
							"traps": state["traps"] = [{"id": "floor_privacy", "pos": tile, "element": "fire" if operation == "add" else "ice", "damage": 4 if operation == "add" else 12}]
							"surfaces": state["surfaces"][BoardSurfaceRules.tile_key(tile)] = {"elemental": "fire" if operation == "add" else "ice", "rubble": operation == "change"}
					summary = floor_preview(state, destination)
					_assert(chip().get_meta("pass_forecast_active", false), "D6 mutated hidden ground retains movement panel %s %s %s %s" % [str(destination), str(tile), content, operation])
					_assert(chip().get_meta("forecast_rows", []) == baseline, "D6 identical rows destination=%s tile=%s %s %s" % [str(destination), str(tile), content, operation])
					_assert(not bool(summary.get("umbra_unknown_before_player", false)), "D6 hidden ground adds no ?")
					print("D6 destination=", destination, " tile=", tile, " content=", content, " operation=", operation, " hp_loss=", summary.get("hp_loss"), " fatigue=", summary.get("fatigue_loss"), " unknown=", summary.get("umbra_unknown_before_player"))

func known_floor_sources() -> void:
	var hidden := Vector2i(2, 2)
	# Every action path shares the same builder. Confirm raw PASS, confirmation,
	# targeted cards and skills also retain no undisclosed floor causes.
	for action: String in ["pass", "brace", "bone_dart", "surface"]:
		var baseline: Array = []
		for populated: bool in [false, true]:
			scene.call("_cancel_player_movement_selection")
			var state: Dictionary = floor_fixture()
			state["deck"]["hand"] = ["brace" if action in ["pass", "surface"] else action]
			state["skill_ids"] = ["prismatic_instinct"]
			if populated:
				state["loot"] = [{"id": FLOOR_PROOF_ID, "kind": "item", "card_id": "crimson_draught", "pos": hidden, "claimed": false}]
				state["traps"] = [{"id": "floor_privacy", "pos": hidden, "element": "fire", "damage": 12}]
				state["surfaces"][BoardSurfaceRules.tile_key(hidden)] = {"elemental": "fire"}
				state["terrain"] = [{"id": "floor_box", "kind": "wooden_box", "pos": hidden, "hp": 30, "max_hp": 30}]
				state["meteor_marks"] = [{"tiles": [hidden], "damage": 12, "element": "fire", "surface": "fire", "placed_turn": 1}]
			_install_pass_preview_chip_state(scene, state)
			if action == "surface":
				scene.call("_begin_surface_skill_selection", "prismatic_instinct")
				scene.call("_on_board_tile_hovered", HERO_TILE)
			elif action != "pass":
				scene.call("_on_card_pressed", 0)
				if action == "bone_dart": scene.call("_on_board_tile_hovered", ENEMY_TILE)
			scene.call("_refresh_selected_card_forecast")
			var source: Dictionary = scene.call("_pass_preview_source_state")
			for collection: String in ["loot", "traps", "terrain"]:
				var has_hidden: bool = false
				for entry: Dictionary in source.get(collection, []):
					if entry.get("pos") == hidden: has_hidden = true
				_assert(not has_hidden, "D6 " + action + " source omits hidden " + collection)
			_assert(not source.get("surfaces", {}).has(BoardSurfaceRules.tile_key(hidden)) and source.get("meteor_marks", []).is_empty(), "D6 " + action + " source omits hidden ground/marks")
			var rows: Array = chip().get_meta("forecast_rows", []).duplicate(true)
			if not populated: baseline = rows
			else: _assert(rows == baseline, "D6 " + action + " rows ignore combined hidden floor content")
			if action == "surface": scene.call("_cancel_surface_skill_selection")
	# A mixed mark keeps its seen portion; caller state is never mutated.
	var mixed: Dictionary = floor_fixture()
	mixed["meteor_marks"] = [{"tiles": [HERO_TILE, hidden], "damage": 4}]
	mixed["illusions"] = [{"id": 77, "pos": hidden, "hp": 1}]
	mixed["npcs"] = [{"id": 77, "pos": hidden}]
	var unchanged: Dictionary = mixed.duplicate(true)
	var known: Dictionary = scene.call("_surface_preview_information_state", mixed)
	_assert(mixed == unchanged, "D6 shared builder preserves caller state")
	_assert(known["meteor_marks"][0]["tiles"] == [HERO_TILE], "D6 mixed marks retain only board-visible tiles")
	_assert(known["illusions"].is_empty() and known["npcs"].is_empty(), "D6 hidden positional actors are absent from shared known state")
	_assert(known["grid"] == mixed["grid"], "D6 public board geometry is retained")

	# Known pickups still happen. Privacy must not disable ordinary visible loot.
	var visible_pickup: Dictionary = floor_fixture()
	visible_pickup["loot"] = [{"id": FLOOR_PROOF_ID, "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(2, 3), "claimed": false}]
	var visible_summary: Dictionary = floor_preview(visible_pickup, Vector2i(2, 3))
	_assert(visible_summary["fatigue_loss"] == 0 and visible_summary["hp_loss"] == 0, "D6 visible pickup retains its actual hand/fatigue consequence")
	_assert(scene.call("_pass_preview_source_state")["deck"]["hand"].has("crimson_draught"), "D6 visible pickup is retained in resolved source")

	# Moving out of sight does not erase a committed, announced ranged attack.
	# Its known damage receipts and its known intent use the same disclosure set.
	var ranged: Dictionary = floor_fixture()
	ranged["player"]["block"] = 2
	ranged["enemies"][0]["intent"] = {"id": "floor_proof_ranged", "name": "Floor proof ranged", "time": 10, "actions": [{"type": "ranged", "range": 8, "damage": 6}]}
	var ranged_summary: Dictionary = floor_preview(ranged, Vector2i(2, 2))
	_assert(ranged_summary["hp_loss"] == 19 and ranged_summary["block_loss"] == 2, "D6 known ranged loss plus Fatigue is retained outside simulated sight")
	_assert(not bool(ranged_summary["umbra_unknown_before_player"]), "D6 moving out of sight adds no false intent uncertainty")
	print("D6 announced ranged hp_loss=", ranged_summary["hp_loss"], " block_loss=", ranged_summary["block_loss"], " fatigue=", ranged_summary["fatigue_loss"], " unknown=", ranged_summary["umbra_unknown_before_player"])

func loss_row_repros() -> void:
	scene.call("_cancel_player_movement_selection")
	scene.set("_combat_engine", CombatEngine.new())
	for kind: String in ["hit", "bleed", "burn", "fatigue", "block_health", "stone_health", "all_defenses", "defeat", "defiance", "stone_only", "safe"]:
		var fixture_kind: String = "danger"
		if kind in ["bleed", "defeat", "safe"]: fixture_kind = "safe"
		if kind in ["burn", "fatigue", "defiance"]: fixture_kind = kind
		var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture(fixture_kind)
		match kind:
			"bleed": state["player"].merge({"hp": 10, "bleed": 1}, true)
			"defeat": state["player"].merge({"hp": 1, "bleed": 1}, true)
			"block_health": state["player"]["block"] = 2
			"stone_health": state["player"]["stoneskin"] = 2
			"all_defenses": state["player"].merge({"block": 1, "stoneskin": 1}, true)
			"stone_only": state["player"]["stoneskin"] = 6
		scene.call("_cancel_player_movement_selection")
		_install_pass_preview_chip_state(scene, state)
		if kind in ["bleed", "defeat"]:
			scene.call("_begin_player_movement_selection")
			scene.call("_on_board_tile_hovered", Vector2i(2, 3))
			scene.call("_refresh_board_hover_presentation")
		else: chip().emit_signal("mouse_entered")
		var summary: Dictionary = scene.call("_pass_preview_summary")
		var parts: Array = []
		for row: Dictionary in chip().get_meta("forecast_rows", []): parts.append_array(row["parts"])
		var health: int = 0
		var fatigue: int = 0
		var stone: int = 0
		var safe: bool = false
		var health_text: String = ""
		var icons: Array[String]
		for part: Dictionary in parts:
			var icon: String = str(part["icon"])
			var loss: int = str(part["text"]).trim_prefix("−").split(" ")[0].to_int()
			if icon == "health":
				health = loss
				health_text = str(part["text"])
			if icon == "fatigue": fatigue = loss
			if icon == "stoneskin":
				stone = loss
				_assert(part["color"] == scene.call("_pass_preview_damage_entries", {"stoneskin": 1})[0]["color"], "D7 Stoneskin uses existing ink")
			if icon in ["block", "stoneskin", "health"]: icons.append(icon)
			if part["text"] == "Safe": safe = true
		var expected: int = int(state["player"]["hp"]) - int(summary["projected_hp"])
		_assert(health + fatigue == expected, "D7 " + kind + " Health plus Fatigue equals actual pre-action HP decline")
		var nothing_lost: bool = int(summary["block_loss"]) == 0 and int(summary["stoneskin_loss"]) == 0 and expected == 0 and int(summary["fatigue_loss"]) == 0 and not bool(summary["defeat"])
		_assert(safe == nothing_lost, "D7 " + kind + " Safe exactly matches no losses or defeat")
		var ordered: Array[String]
		for key: String in ["block", "stoneskin", "health"]:
			if icons.has(key): ordered.append(key)
		_assert(icons == ordered, "D7 " + kind + " loss parts follow Block/Stoneskin/Health order")
		if kind == "defeat":
			var actual: Dictionary = scene.get("_combat_engine").apply_player_movement(state, Vector2i(2, 3))
			_assert(actual["player"]["hp"] == 0 and summary["defeat"] and health_text == "−1 → 0", "D7 lethal movement agrees with actual defeat and displays Health -1 to 0")
		if kind == "stone_only": _assert(stone == 5 and not safe, "D7 Stoneskin-only loss is -5 instead of Safe")
		if kind == "defiance": _assert(not health_text.contains("→ 0") and int(summary["defiance_spent"]) > 0, "D7 Defiance retains its row without a death arrow")
		print("D7 ", kind, " before=", state["player"]["hp"], " after=", summary["projected_hp"], " health=", health, " fatigue=", fatigue, " stoneskin=", stone, " safe=", safe, " health_text=", health_text)
		chip().emit_signal("mouse_exited")

func proof_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	for _frame: int in range(3): await process_frame

func pointer_exit_repros() -> void:
	for kind: String in ["movement", "skill", "card"]:
		scene.call("_cancel_player_movement_selection")
		await install("quick_stab", 14, "second_move")
		if kind == "movement": scene.call("_begin_player_movement_selection")
		elif kind == "skill":
			scene.get("_combat_state")["skill_ids"] = ["prismatic_instinct"]
			scene.call("_mark_combat_preview_state_changed")
			scene.call("_begin_surface_skill_selection", "prismatic_instinct")
		else: scene.call("_on_card_pressed", 0)
		for _frame: int in range(6): await process_frame
		var board: Control = scene.get("board_view")
		var tile := Vector2i(3, 4) if kind == "card" else Vector2i(2, 3)
		if kind == "skill": tile = scene.get("_surface_skill_tiles")[0]
		var point: Vector2 = board.get_global_transform() * board.call("world_position_for_tile", tile)
		for destination: String in ["hud", "hand", "window"]:
			await proof_motion(point)
			await create_timer(0.2).timeout
			_assert(scene.get("_hovered_board_tile") == tile and chip().get_meta("pass_forecast_active", false), "D8 " + kind + " return restores board and panel")
			if destination == "window": scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
			else:
				var control: Control = scene.get("_section_map_hud_button") if destination == "hud" else scene.call("_hand_card_control", 0)
				await proof_motion(control.get_global_rect().get_center())
			await create_timer(0.25).timeout
			var panel: Control = chip().get_node("PassForecastFocusTooltip")
			_assert(scene.get("_hovered_board_tile").x < 0 and board.get("_hover_tile").x < 0, "D8 " + kind + " " + destination + " clears both hover owners")
			_assert(not chip().get_meta("pass_forecast_active", true) and panel.modulate.a == 0.0, "D8 " + kind + " " + destination + " fades panel")
			for badge: Control in chip().get_meta("forecast_fade_badges", []):
				_assert(not badge.visible and badge.modulate.a == 0.0, "D8 pointer exit fades repeat badges")
			print("D8 ", kind, " exit=", destination, " tile=", scene.get("_hovered_board_tile"), " alpha=", panel.modulate.a)
		await proof_motion(point)
		await create_timer(0.2).timeout
		_assert(chip().get_meta("pass_forecast_active", false), "D8 final return restores panel")
		var router: Node = root.get_node("InputRouter")
		router.call("set_modality", "controller")
		for _frame: int in range(6): await process_frame
		scene.call("_controller_set_board_tile", tile, true)
		for _frame: int in range(3): await process_frame
		var controller_tile: Vector2i = scene.get("_hovered_board_tile")
		_assert(controller_tile.x >= 0 and chip().get_meta("pass_forecast_active", false), "D8 " + kind + " controller control starts active")
		scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
		await create_timer(0.2).timeout
		_assert(scene.get("_hovered_board_tile") == controller_tile and chip().get_meta("pass_forecast_active", false), "D8 " + kind + " native pointer exit preserves controller target")
		router.call("set_modality", "pointer")
		if kind == "skill": scene.call("_cancel_surface_skill_selection")
		elif kind == "movement": scene.call("_cancel_player_movement_selection")
		else: scene.call("_cancel_card_selection")

# Director feedback 3: Fatigue remains the applied cost; Health excludes it,
# nets healing, and never exceeds the committed HP. No signed-gain row exists.
func recovery_ruling_checks() -> void:
	for kind: String in ["fatigue_lethal", "bleed_fatigue", "surface_fatigue", "heal_full", "heal_partial", "heal_full_umbra", "fatigue_heal", "defiance_gain", "fatigue_defiance"]:
		scene.set("_combat_engine", CombatEngine.new())
		scene.call("_cancel_player_movement_selection")
		var fixture_kind: String = "danger"
		if kind in ["fatigue_lethal", "fatigue_heal", "fatigue_defiance"]: fixture_kind = kind
		if kind in ["bleed_fatigue", "surface_fatigue"]: fixture_kind = "fatigue_lethal"
		if kind == "defiance_gain": fixture_kind = "defiance"
		var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture(fixture_kind)
		if kind in ["bleed_fatigue", "surface_fatigue"]:
			state["player"]["hp"] = 10
			state["player"]["block"] = 0
			if kind == "bleed_fatigue": state["player"]["bleed"] = 1
			else:
				state["player"]["block"] = 0
				state["surfaces"][BoardSurfaceRules.tile_key(HERO_TILE)] = {"elemental": "fire"}
		if kind in ["heal_full", "heal_partial", "heal_full_umbra"]:
			state["active_rites"] = [{"card_id": "ruling_recovery", "effects": [{"type": "turn_start_reward", "rewards": [{"type": "heal", "amount": 2 if kind == "heal_partial" else 5}]}]}]
		if kind == "heal_full_umbra":
			state["umbra"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("umbra")["umbra"]
			state["enemies"].append(hidden_fixture()["enemies"][1])
			var opaque: Dictionary = hidden_fixture()["turn_queue"][1].duplicate(true)
			opaque["time"] = 1
			state["turn_queue"].append(opaque)
		if kind == "defiance_gain": state["player"]["hp"] = 1
		_install_pass_preview_chip_state(scene, state)
		if kind == "bleed_fatigue":
			scene.call("_begin_player_movement_selection")
			scene.call("_on_board_tile_hovered", Vector2i(2, 3))
			scene.call("_refresh_board_hover_presentation")
		else: chip().emit_signal("mouse_entered")
		var summary: Dictionary = scene.call("_pass_preview_summary")
		var rows: Array = chip().get_meta("forecast_rows", [])
		var health_text: String = ""
		var fatigue_text: String = ""
		var defiance_text: String = ""
		var death_arrows: int = 0
		var safe: bool = false
		for row: Dictionary in rows:
			for part: Dictionary in row["parts"]:
				var text: String = str(part["text"])
				if text.contains(" → 0"): death_arrows += 1
				if part["icon"] == "health": health_text = text
				if part["icon"] == "fatigue": fatigue_text = text
				if part["icon"] == "defiance": defiance_text = text
				if text == "Safe": safe = true
		var health: int = health_text.trim_prefix("−").split(" ")[0].to_int()
		var fatigue: int = fatigue_text.trim_prefix("−").split(" ")[0].to_int()
		_assert(health <= int(state["player"]["hp"]), "D9 " + kind + " Health never exceeds current HP")
		_assert(fatigue == int(summary["fatigue_loss"]), "D9 " + kind + " Fatigue retains the applied cost")
		if summary["defeat"]:
			_assert(int(summary["projected_hp"]) == 0 and death_arrows == 1, "D9 " + kind + " defeat has one zero projection")
		elif int(summary["defiance_spent"]) > 0:
			_assert(death_arrows == 0 and defiance_text.ends_with(" → %d/%d" % [int(summary["projected_hp"]), int(summary["projected_max_hp"])]), "D9 " + kind + " Defiance is the only matching projection")
		elif kind != "fatigue_heal" and not bool(summary["umbra_unknown_before_player"]):
			_assert(health + fatigue == int(summary["source_hp"]) - int(summary["projected_hp"]), "D9 " + kind + " survivor Health/Fatigue matches HP decline")
		match kind:
			"fatigue_lethal": _assert(health_text.is_empty() and fatigue_text == "−15 → 0", "D9 lethal Fatigue alone owns the death arrow")
			"bleed_fatigue": _assert(health_text == "−1 → 0" and fatigue_text == "−15", "D9 Bleed plus lethal Fatigue keeps the death arrow on Health")
			"surface_fatigue": _assert(health_text == "−3 → 0" and fatigue_text == "−15", "D9 turn-start fire remains Health before lethal Fatigue")
			"heal_full": _assert(health_text.is_empty() and safe, "D9 full recovery omits Health and permits Safe")
			"heal_full_umbra": _assert(health_text.is_empty() and safe and summary["umbra_unknown_before_player"] and int(summary["projected_hp"]) < 0, "D9 public healing nets known loss while hidden projection stays unknown")
			"heal_partial": _assert(health_text == "−3" and not safe, "D9 partial recovery shows only net Health -3")
			"fatigue_heal": _assert(health_text.is_empty() and fatigue_text == "−15" and not safe, "D9 healing offsets Health without concealing applied Fatigue")
			"defiance_gain": _assert(health_text.is_empty() and int(summary["projected_hp"]) > int(summary["source_hp"]), "D9 Defiance net gain has no Health-loss part")
		print("D9 ", kind, " source=", summary["source_hp"], " projected=", summary["projected_hp"], " health=", health_text, " fatigue=", fatigue_text, " defiance=", defiance_text, " safe=", safe)
		chip().emit_signal("mouse_exited")
