extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const START := Vector2i(2, 4)


static func run(expect: Callable) -> void:
	_test_authored_card_matrix(expect)
	_test_flurry_and_health_costs(expect)
	_test_root_summary_edges(expect)
	_test_limited_movement_targets(expect)
	_test_limited_movement_allowances(expect)
	_test_limited_movement_footprints(expect)
	_test_limited_movement_preserves_full_routes(expect)
	_test_cache_invalidation_and_guards(expect)
	_test_injected_full_previews(expect)


static func _test_authored_card_matrix(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	var card_ids: Array = GameData.cards().keys()
	card_ids.sort()
	var observed_playable: bool = false
	var observed_unavailable: bool = false
	for fixture_name: String in ["open", "blocked", "dense", "heart", "frozen", "shocked", "immobilized", "surface_ready", "surface_spent"]:
		var base: Dictionary = _fixture(combat, fixture_name)
		for card_id_var: Variant in card_ids:
			var card_id: String = str(card_id_var)
			var state: Dictionary = base.duplicate(true)
			_set_hand(state, [card_id])
			var playable: bool = _assert_card_matches_full_walk(scene, combat, state, 0, expect, "%s/%s" % [fixture_name, card_id])
			observed_playable = observed_playable or playable
			observed_unavailable = observed_unavailable or not playable
	expect.call(observed_playable and observed_unavailable, "The complete authored-card matrix must exercise both playable and unavailable cards")
	scene.free()


# The oracle calls the original default root walk directly; it must never call
# the summary wrapper or read its cache. Full payload construction follows the
# summary, proving a representative target cannot leak into click/drag data.
static func _assert_card_matches_full_walk(scene: Node, combat: CombatEngine, state: Dictionary, index: int, expect: Callable, label: String) -> bool:
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	var source_before: Dictionary = state.duplicate(true)
	var reference: Dictionary = _reference_preview(scene, combat, state, index)
	var sanitized: Dictionary = scene.call("_sanitize_preview_for_umbra_information", reference)
	var expected: bool = bool(sanitized.get("playable", false))
	var summary: Dictionary = scene.call("_card_playability_for_index", index)
	_assert_flags(summary, expected, expect, label)
	expect.call(not summary.has("play") and not summary.has("target_tiles"), "%s summary must contain flags without a partial interaction payload" % label)
	expect.call((scene.get("_card_preview_cache") as Dictionary).is_empty() and (scene.get("_card_play_options_cache") as Dictionary).is_empty(), "%s summary must not populate either full-preview cache" % label)
	_assert_flags(scene.call("_card_playability_for_index", index), expected, expect, "%s warm summary" % label)
	var full: Dictionary = scene.call("_card_preview_for_index", index)
	expect.call(full == reference, "%s full preview after summary must preserve all targets, actions, completion state and resolved state" % label)
	var options: Dictionary = scene.call("_card_play_options_for_index", index)
	_assert_flags(options, expected, expect, "%s full options" % label)
	expect.call((options.get("play", {}) as Dictionary) == sanitized, "%s click/drag options must retain the complete information-safe preview" % label)
	expect.call(state == source_before, "%s preview paths must not mutate committed state, RNG, charges, surfaces or event history" % label)
	return expected


static func _reference_preview(scene: Node, combat: CombatEngine, state: Dictionary, index: int) -> Dictionary:
	if state.is_empty():
		return {}
	if combat.cards_remaining_this_turn(state) <= 0:
		return {"playable": false}
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", []) as Array
	if index < 0 or index >= hand.size():
		return {}
	var card_id: String = str(hand[index])
	var prepared: Dictionary = combat.prepare_player_card(state, index, "play")
	var actions: Array = combat.card_play_actions(card_id, prepared)
	return scene.call("_card_preview_from_state", card_id, prepared, actions, 0)


static func _assert_flags(actual: Dictionary, expected: bool, expect: Callable, label: String) -> void:
	expect.call(bool(actual.get("printed_playable", false)) == expected, "%s printed playability must equal the full walk plus committed-information filtering" % label)
	expect.call(bool(actual.get("any_playable", false)) == expected, "%s any playability must equal the existing printed-card option" % label)


static func _test_flurry_and_health_costs(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var definition: Dictionary = GameData.card_def(card_id)
		if bool(definition.get("flurry", false)):
			for repeat_count: int in [1, 4, 10, 20]:
				var state: Dictionary = _fixture(combat, "dense")
				state["cards_per_turn"] = repeat_count
				_set_hand(state, [card_id])
				var actions: Array = combat.card_play_actions(card_id, state)
				expect.call(combat.card_plays_spent_for_actions(actions) == repeat_count, "%s fixture must generate %d actual Flurry repetitions" % [card_id, repeat_count])
				_assert_card_matches_full_walk(scene, combat, state, 0, expect, "%s/%d repetitions" % [card_id, repeat_count])
		if int(definition.get("health_cost", 0)) > 0:
			var low_health: Dictionary = _fixture(combat, "open")
			low_health["player"]["hp"] = 1
			_set_hand(low_health, [card_id])
			# Costs are paid at card completion. Summary must not introduce a new
			# upfront affordability gate that the existing preview never used.
			_assert_card_matches_full_walk(scene, combat, low_health, 0, expect, "%s health below printed cost" % card_id)
	scene.free()


static func _test_root_summary_edges(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	var hidden := Vector2i(7, 4)
	var visible := Vector2i(3, 4)
	var concealed: Dictionary = _fixture(combat, "heart")
	concealed["enemies"] = [_enemy(1, hidden)]
	var vision_actions: Array = [{"type": "vision", "amount": 6, "duration": 1}, {"type": "ranged", "damage": 1, "range": 9, "required": true}]
	var hidden_reference: Dictionary = _assert_root_matches_full_walk(scene, concealed, vision_actions, expect, "Vision cannot make a concealed required target printed-playable")
	expect.call((hidden_reference.get("target_tiles", []) as Array).has(hidden), "Vision privacy fixture must have a raw simulated hidden target")
	var safe: Dictionary = scene.call("_sanitize_preview_for_umbra_information", hidden_reference)
	expect.call(not bool(safe.get("playable", false)), "Committed Umbra must conceal the only simulated Vision target")
	var optional_vision: Array = vision_actions.duplicate(true)
	optional_vision[1]["required"] = false
	var optional_reference: Dictionary = _assert_root_matches_full_walk(scene, concealed, optional_vision, expect, "All simulated targets hidden with a playable skip")
	safe = scene.call("_sanitize_preview_for_umbra_information", optional_reference)
	expect.call(bool(optional_reference.get("skip_allowed", false)) and bool(safe.get("playable", false)), "Skipping a concealed attack must preserve the already applied Vision effect")
	var no_move: Array = [{"type": "move", "range": 0, "optional": true}, {"type": "illusion", "range": 2, "required": true}]
	var no_move_reference: Dictionary = _assert_root_matches_full_walk(scene, concealed, no_move, expect, "Umbra deferred movement with no raw destination and a playable skip")
	expect.call((no_move_reference.get("target_tiles", []) as Array).is_empty() and bool(no_move_reference.get("skip_allowed", false)) and not bool(no_move_reference.get("playable", false)), "The deferred-movement branch must preserve its existing unavailable result despite a playable skip")
	concealed["enemies"].append(_enemy(2, visible))
	var mixed_reference: Dictionary = _assert_root_matches_full_walk(scene, concealed, vision_actions, expect, "Known target after a concealed first candidate")
	var mixed_targets: Array = mixed_reference.get("target_tiles", []) as Array
	expect.call(mixed_targets.size() >= 2 and mixed_targets[0] == hidden and mixed_targets.has(visible), "Mixed knowledge fixture must enumerate a hidden candidate before a known candidate")
	safe = scene.call("_sanitize_preview_for_umbra_information", mixed_reference)
	expect.call(bool(safe.get("playable", false)), "A later known target must keep a Vision sequence playable")

	var followup: Dictionary = _fixture(combat, "open")
	followup["enemies"] = [_enemy(1, Vector2i(8, 4))]
	Surface.place(followup, Vector2i(5, 4), "fire")
	# Attack suffixes deliberately preserve every move as a shortcut choice.
	# A required Illusion exercises the actual continuation-search branch.
	var mandatory: Array = [{"type": "move", "range": 2, "required": true}, {"type": "illusion", "range": 1, "required": true, "requires_surface": {"surface": "fire", "subject": "target"}}]
	var followup_reference: Dictionary = _assert_root_matches_full_walk(scene, followup, mandatory, expect, "Movement with a mandatory surface-gated Illusion continuation")
	var complete_targets: Array = followup_reference.get("target_tiles", []) as Array
	var raw_moves: Array = combat.valid_targets_for_player_action(followup, mandatory[0])
	expect.call(not complete_targets.is_empty() and complete_targets.size() < raw_moves.size() and not complete_targets.has(raw_moves[0]), "Mandatory continuation fixture must reject its first legal move and accept a later move")
	for spent: bool in [false, true]:
		var dangerous: Dictionary = followup.duplicate(true)
		dangerous["skill_ids"] = ["sure_footed"]
		dangerous["skill_flags"] = {"used:sure_footed": spent}
		dangerous["player"]["hp"] = 3
		dangerous["traps"] = [{"id": "required_route", "pos": Vector2i(3, 4), "element": "fire", "damage": 20}]
		_assert_root_matches_full_walk(scene, dangerous, mandatory, expect, "Required trap route charge spent=%s" % str(spent))
		dangerous["player"]["bleed"] = 4
		_assert_root_matches_full_walk(scene, dangerous, mandatory, expect, "Required movement with lethal Bleed charge spent=%s" % str(spent))

	var surfaces: Dictionary = _fixture(combat, "surface_ready")
	var surface_cases: Array = [
		[{"type": "move", "range": 4, "requires_surface": {"surface": "fire", "subject": "target"}}],
		[{"type": "move", "range": 4, "requires_surface": {"surface": "ice", "subject": "player"}}],
		[{"type": "move", "range": 3, "_origin_tile": Vector2i(5, 3)}],
		[{"type": "melee", "range": 1, "damage": 5, "_surface_relic_modes": ["cross"]}],
		[{"type": "ranged", "range": 5, "damage": 5, "_surface_relic_modes": ["remote"], "_origin_tile": Vector2i(5, 3)}],
		[{"type": "ranged", "range": 6, "damage": 5, "chain": 2, "_surface_relic_modes": ["swap"]}],
		[{"type": "aoe", "range": 4, "damage": 2, "pattern": [[0, 0], [1, 0], [0, 1]], "rotate": false}],
		[{"type": "aoe", "range": 0, "damage": 2, "pattern": [[0, 0], [1, 0]], "rotate": false}],
		[{"type": "melee", "range": 0, "damage": 1}, {"type": "block", "amount": 2}],
	]
	for case_index: int in range(surface_cases.size()):
		_assert_root_matches_full_walk(scene, surfaces, surface_cases[case_index], expect, "Surface or automatic-action edge %d" % case_index)
	var no_surfaces: Dictionary = _fixture(combat, "open")
	_assert_root_matches_full_walk(scene, no_surfaces, surface_cases[0], expect, "Target-surface requirement with no matching floor")
	_assert_root_matches_full_walk(scene, no_surfaces, surface_cases[1], expect, "Player-surface requirement with no matching floor")
	scene.free()


static func _assert_root_matches_full_walk(scene: Node, state: Dictionary, actions: Array, expect: Callable, label: String) -> Dictionary:
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	var state_before: Dictionary = state.duplicate(true)
	var actions_before: Array = actions.duplicate(true)
	var reference: Dictionary = scene.call("_card_preview_from_state", "quick_stab", state, actions, 0)
	var summary_preview: Dictionary = scene.call("_card_preview_from_state", "quick_stab", state, actions, 0, false, true, true, true)
	var reference_safe: Dictionary = scene.call("_sanitize_preview_for_umbra_information", reference)
	var summary_safe: Dictionary = scene.call("_sanitize_preview_for_umbra_information", summary_preview)
	expect.call(bool(summary_safe.get("playable", false)) == bool(reference_safe.get("playable", false)), "%s summary root must preserve full-walk playability" % label)
	expect.call(state == state_before and actions == actions_before, "%s summary and full walks must leave their borrowed inputs unchanged" % label)
	return reference


# Compare the existence result with the default complete enumeration, filtering
# the caller's predicate independently so both paths cannot share an early exit.
static func _assert_limited_movement_matches_full(combat: CombatEngine, state: Dictionary, action: Dictionary, expect: Callable, label: String, accept_target: Callable = Callable()) -> Array[Vector2i]:
	var state_before: Dictionary = state.duplicate(true)
	var action_before: Dictionary = action.duplicate(true)
	var full: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	var accepted: Array[Vector2i]
	for tile: Vector2i in full:
		if not accept_target.is_valid() or bool(accept_target.call(tile)):
			accepted.append(tile)
	var expected: Array[Vector2i]
	if not accepted.is_empty():
		expected.append(accepted[0])
	var limited: Array[Vector2i] = combat.valid_targets_for_player_action(state, action, 1, accept_target)
	expect.call(limited == expected, "%s limited query must return exactly the first accepted full target" % label)
	expect.call(combat.valid_targets_for_player_action(state, action) == full, "%s later full enumeration must retain every target in its original order" % label)
	expect.call(state == state_before and action == action_before, "%s target queries must preserve borrowed state and action data" % label)
	return limited


static func _test_limited_movement_targets(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _fixture(combat, "open")
	state["enemies"] = []
	var action: Dictionary = {"type": "move", "range": 3}
	var later_tile := START + Vector2i.RIGHT * 2
	var full: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	expect.call(full.size() > 1 and full[0] != later_tile and full.has(later_tile), "Limited movement predicate fixture must reject an earlier reachable destination")
	var accept_later: Callable = func(tile: Vector2i) -> bool: return tile == later_tile
	var limited: Array[Vector2i] = _assert_limited_movement_matches_full(combat, state, action, expect, "Later accepted movement destination", accept_later)
	expect.call(limited.size() == 1 and limited[0] == later_tile, "Rejecting early movement destinations must still find the later accepted tile")
	var reject_all: Callable = func(_tile: Vector2i) -> bool: return false
	limited = _assert_limited_movement_matches_full(combat, state, action, expect, "All movement destinations rejected", reject_all)
	expect.call(limited.is_empty(), "A predicate rejecting every reachable destination must leave movement unavailable")
	Surface.place(state, later_tile, "fire")
	var gated: Dictionary = action.duplicate(true)
	gated["requires_surface"] = {"surface": "fire", "subject": "target"}
	limited = _assert_limited_movement_matches_full(combat, state, gated, expect, "Later surface-gated movement destination")
	expect.call(limited.size() == 1 and limited[0] == later_tile, "Surface acceptance must run before navigation stops on an earlier bare tile")
	gated["requires_surface"] = {"surface": "ice", "subject": "target"}
	limited = _assert_limited_movement_matches_full(combat, state, gated, expect, "No matching movement surface")
	expect.call(limited.is_empty(), "A missing required surface must reject every movement destination")


static func _test_limited_movement_allowances(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _fixture(combat, "open")
	state["enemies"] = []
	Surface.place(state, START, "rubble")
	state["player_movement_remaining"] = 1
	expect.call(combat.player_movement_capacity(state) > 1, "Rubble allowance fixture must have an already spent movement pool")
	var pool_action: Dictionary = {"type": "move", "range": 1, "_movement_pool": true}
	var limited: Array[Vector2i] = _assert_limited_movement_matches_full(combat, state, pool_action, expect, "Partly spent pool leaving Rubble")
	expect.call(limited.is_empty(), "A partly spent one-point pool cannot restart minimum progress to leave Rubble")
	var card_action: Dictionary = {"type": "move", "range": 1}
	limited = _assert_limited_movement_matches_full(combat, state, card_action, expect, "Fresh one-point card allowance leaving Rubble")
	expect.call(not limited.is_empty(), "A separate one-point Move card must permit its first expensive Rubble step")
	state["player_movement_remaining"] = combat.player_movement_capacity(state)
	pool_action["range"] = combat.player_movement_remaining(state)
	limited = _assert_limited_movement_matches_full(combat, state, pool_action, expect, "Fresh movement pool leaving Rubble")
	expect.call(not limited.is_empty(), "A fresh movement pool must retain its legal Rubble exit")
	for movement_pool: bool in [false, true]:
		var zero_action: Dictionary = {"type": "move", "range": 0, "_movement_pool": movement_pool}
		limited = _assert_limited_movement_matches_full(combat, state, zero_action, expect, "Zero movement budget pool=%s" % str(movement_pool))
		expect.call(limited.is_empty(), "Minimum progress must never invent a step for a zero movement budget")


static func _test_limited_movement_footprints(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _fixture(combat, "open")
	state["enemies"] = []
	state["player"]["footprint"] = Vector2i(2, 2)
	# Every adjacent origin is floor, but the first two destinations have a
	# blocked far footprint cell. Only the downward corridor fits the full body.
	state["grid"][3][3] = "wall"
	state["grid"][5][1] = "wall"
	state["terrain"] = [{"id": "footprint_corner", "kind": "wooden_box", "pos": Vector2i(4, 5), "hp": 60, "max_hp": 60}]
	var action: Dictionary = {"type": "move", "range": 1}
	var limited: Array[Vector2i] = _assert_limited_movement_matches_full(combat, state, action, expect, "Large body with one fitting corridor")
	expect.call(limited.size() == 1 and limited[0] == START + Vector2i.DOWN, "Existence must skip passable origins whose far footprint intersects a wall or terrain")
	state["grid"][6][3] = "wall"
	limited = _assert_limited_movement_matches_full(combat, state, action, expect, "Large body with no fitting corridor")
	expect.call(limited.is_empty(), "Passable adjacent origins must not admit a large body when every full footprint is blocked")
	state = _fixture(combat, "open")
	state["enemies"] = []
	state["player"]["pos"] = Vector2i(8, 6)
	state["player"]["footprint"] = Vector2i(2, 2)
	var full: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	expect.call(not full.has(Vector2i(9, 6)) and not full.has(Vector2i(8, 7)), "Large-body edge fixture must reject origins whose far footprint enters the boundary wall")
	_assert_limited_movement_matches_full(combat, state, action, expect, "Large body beside board edges")


static func _test_limited_movement_preserves_full_routes(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _fixture(combat, "open")
	state["enemies"] = []
	var hazardous_tile := START + Vector2i.RIGHT
	var destination := START + Vector2i.RIGHT * 2
	Surface.place(state, hazardous_tile, "fire")
	var action: Dictionary = {"type": "move", "range": 4}
	var full: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	var plan_before: Dictionary = combat.movement_plan_for_player_action(state, action, full)
	var preferred_path: Array[Vector2i] = combat.path_from_player_movement_plan(plan_before, destination)
	expect.call(preferred_path.size() == 5 and not preferred_path.has(hazardous_tile), "Route fixture must prefer a later four-step safe route over the first two-step Fire route")
	var accept_destination: Callable = func(tile: Vector2i) -> bool: return tile == destination
	var limited: Array[Vector2i] = _assert_limited_movement_matches_full(combat, state, action, expect, "Early hazardous route with a later safe route", accept_destination)
	expect.call(limited.size() == 1 and limited[0] == destination, "Existence may accept a reachable endpoint before its preferred route is finalized")
	# Supplying the representative result must not turn later interaction into
	# a one-target plan or preserve the incomplete search's first harmful route.
	var plan_after: Dictionary = combat.movement_plan_for_player_action(state, action, limited)
	expect.call(plan_after == plan_before, "Full planning after an existence query must preserve all destinations, costs, paths and source data")
	expect.call(combat.path_from_player_movement_plan(plan_after, destination) == preferred_path, "The later plan must retain the preferred safe route to the accepted endpoint")
	expect.call(combat.path_for_player_action(state, action, destination) == preferred_path, "Direct interaction path lookup must also retain the complete safe-route search")


static func _test_cache_invalidation_and_guards(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	var base: Dictionary = _fixture(combat, "open")
	_set_hand(base, ["guarded_step", "quick_stab", "cinder_fusillade"])
	for fixture_name: String in ["open", "frozen", "open", "heart", "open"]:
		var state: Dictionary = _fixture(combat, fixture_name)
		_set_hand(state, (base.get("deck", {}) as Dictionary).get("hand", []) as Array)
		scene.set("_combat_state", state)
		scene.call("_mark_combat_preview_state_changed")
		for index: int in range(3):
			var reference: Dictionary = scene.call("_sanitize_preview_for_umbra_information", _reference_preview(scene, combat, state, index))
			var expected: bool = bool(reference.get("playable", false))
			_assert_flags(scene.call("_card_playability_for_index", index), expected, expect, "Revised %s card %d" % [fixture_name, index])
			scene.call("_mark_preview_selection_changed")
			_assert_flags(scene.call("_card_playability_for_index", index), expected, expect, "Selection-only revision %s card %d" % [fixture_name, index])
		_assert_flags(scene.call("_card_playability_for_index", -1), false, expect, "Negative hand index")
		_assert_flags(scene.call("_card_playability_for_index", 3), false, expect, "Past-end hand index")
	var depleted: Dictionary = base.duplicate(true)
	depleted["cards_played_this_turn"] = int(depleted.get("cards_per_turn", 4))
	for index: int in range(3):
		_assert_card_matches_full_walk(scene, combat, depleted, index, expect, "Depleted card %d" % index)
	var enemy_turn: Dictionary = base.duplicate(true)
	enemy_turn["current_actor"] = {"kind": "enemy", "id": 1, "key": "enemy:1"}
	_assert_card_matches_full_walk(scene, combat, enemy_turn, 0, expect, "Enemy activation")
	scene.set("_combat_state", {})
	scene.call("_mark_combat_preview_state_changed")
	_assert_flags(scene.call("_card_playability_for_index", 0), false, expect, "Empty combat state")
	scene.free()


static func _test_injected_full_previews(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	var state: Dictionary = _fixture(combat, "open")
	_set_hand(state, ["guarded_step"])
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	_assert_flags(scene.call("_card_playability_for_index", 0), true, expect, "Initial summary before injected preview")
	var cache: Dictionary = scene.get("_card_preview_cache") as Dictionary
	cache[scene.call("_card_preview_cache_key", 0, "play")] = {"playable": false, "complete": true, "target_tiles": []}
	_assert_flags(scene.call("_card_playability_for_index", 0), false, expect, "A full preview installed after a summary must take precedence")
	var option_cache: Dictionary = scene.get("_card_play_options_cache") as Dictionary
	option_cache[scene.call("_card_preview_cache_key", 0, "options")] = {"printed_playable": true, "any_playable": true}
	_assert_flags(scene.call("_card_playability_for_index", 0), true, expect, "Existing full options must take precedence over lower-level snapshots")

	state = _fixture(combat, "heart")
	state["enemies"] = [_enemy(1, Vector2i(7, 4))]
	_set_hand(state, ["pale_spark"])
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	var actions: Array = [{"type": "vision", "amount": 6, "duration": 1}, {"type": "ranged", "damage": 4, "range": 9, "required": true}]
	var injected: Dictionary = scene.call("_card_preview_from_state", "pale_spark", state, actions, 0)
	expect.call(bool(injected.get("playable", false)) and not (injected.get("target_tiles", []) as Array).is_empty(), "Injected privacy preview must contain a real simulated target")
	cache = scene.get("_card_preview_cache") as Dictionary
	cache[scene.call("_card_preview_cache_key", 0, "play")] = injected
	_assert_flags(scene.call("_card_playability_for_index", 0), false, expect, "Injected full preview must still respect committed Umbra")
	scene.free()


static func _fixture(combat: CombatEngine, name: String) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": "Card Playability Summary", "coord": Vector2i.ZERO, "type": "combat", "element": "air",
		"umbra_stage": "heart" if name == "heart" else "clear", "grid": grid, "player_start": START,
		"enemies": [_enemy(1, Vector2i(3, 4)), _enemy(2, Vector2i(7, 4))], "traps": [], "loot": [], "terrain": []
	}
	var state: Dictionary = combat.create_combat(88420, layout, {"hp": 200, "max_hp": 200, "deck_cards": ["quick_stab"], "relics": [], "hand_size": 1})
	state["player"] = {"pos": START, "hp": 200, "max_hp": 200, "block": 0, "stoneskin": 0}
	state["enemies"] = (layout.get("enemies", []) as Array).duplicate(true)
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_per_turn"] = 4
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_restrictions"] = {}
	if name in ["frozen", "shocked", "immobilized"]:
		state["player_turn_restrictions"] = {name: true}
	if name == "blocked":
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var tile: Vector2i = START + offset
			state["grid"][tile.y][tile.x] = "wall"
		state["enemies"] = [_enemy(1, Vector2i(7, 4))]
	if name == "dense":
		var enemies: Array = []
		for y: int in range(2, 7):
			for x: int in range(3, 10):
				if (x + y) % 2 == 0:
					enemies.append(_enemy(enemies.size() + 1, Vector2i(x, y)))
		state["enemies"] = enemies
		state["terrain"] = [{"id": "summary_box", "kind": "wooden_box", "pos": Vector2i(4, 3), "hp": 60, "max_hp": 60}]
	if name in ["surface_ready", "surface_spent"]:
		state["relics"] = ["coalheart_crucible", "thunder_relay", "thornmail_brooch", "worldroot_idol"]
		state["skill_ids"] = ["sure_footed"]
		state["skill_flags"] = {"used:sure_footed": name == "surface_spent"}
		state["player"]["stoneskin"] = 4
		state["player"]["bleed"] = 2
		state["traps"] = [{"id": "summary_trap", "pos": Vector2i(2, 3), "element": "fire", "damage": 30}]
		var large: Dictionary = _enemy(3, Vector2i(5, 5))
		large["footprint"] = Vector2i(2, 2)
		state["enemies"].append(large)
		for x: int in range(2, 8):
			Surface.place(state, Vector2i(x, 3), "fire")
			Surface.place(state, Vector2i(x, 4), "electrified")
		for x: int in range(2, 6):
			Surface.place(state, Vector2i(x, 3), "rubble")
		Surface.place(state, START, "ice")
		Surface.place(state, START, "rubble")
		Surface.place(state, Vector2i(3, 4), "rubble")
	return state


static func _set_hand(state: Dictionary, cards: Array) -> void:
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = cards.duplicate()
	deck["draw"] = ["brace", "quick_stab", "bone_dart"]
	deck["discard"] = ["guarded_step"]
	deck["burned"] = []
	deck["consumed"] = []
	state["deck"] = deck


static func _enemy(id: int, tile: Vector2i) -> Dictionary:
	return {"id": id, "type": "crawler", "pos": tile, "hp": 300, "max_hp": 300, "block": 0, "stoneskin": 0}
