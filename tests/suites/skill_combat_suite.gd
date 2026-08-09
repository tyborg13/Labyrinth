extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	_test_quick_wits(expect)
	_test_rehearsed_escape_and_pain_remembers(expect)
	_test_measured_breath_borrowed_time_and_guard(expect)
	_test_ghost_stride_afterimage_and_plunder(expect)
	_test_makeshift_tool(expect)
	_test_preservation_on_winning_blow(expect)
	_test_sure_footed(expect)
	_test_last_reserve(expect)
	_test_living_shadow(expect)
	_test_prismatic_instinct_and_confluence(expect)
	_test_radiance_branch(expect)
	_test_encore(expect)

static func _test_quick_wits(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["quick_wits"], ["quick_stab", "brace"])
	state["deck"] = _deck(["quick_stab"], ["brace"], [])
	state = combat.use_quick_wits(state, 0)
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	expect.call((deck.get("hand", []) as Array) == ["brace"], "Quick Wits should replace the chosen hand card with one draw")
	expect.call((deck.get("discard", []) as Array).has("quick_stab"), "Quick Wits should put the chosen card in discard")
	expect.call(int(state.get("cards_played_this_turn", 0)) == 0 and int(state.get("player_turn_time_spent", 0)) == 0, "Quick Wits should cost neither a play nor Time")
	expect.call(combat.skill_was_used(state, "quick_wits"), "Quick Wits should be spent after use")

	var full_state: Dictionary = _state(combat, ["quick_wits", "pain_remembers"], ["quick_stab", "brace", "brace", "brace", "brace", "brace", "brace", "bone_dart"])
	var full_hand: Array = ["quick_stab", "brace", "brace", "brace", "brace", "brace", "brace"]
	full_state["deck"] = _deck(full_hand, ["bone_dart"], [])
	full_state = combat._damage_player(full_state, GameData.fixed_point_amount(1), true)
	full_state = combat.use_quick_wits(full_state, 0)
	var full_deck: Dictionary = full_state.get("deck", {}) as Dictionary
	expect.call((full_deck.get("hand", []) as Array).size() == CombatEngine.MAX_HAND_SIZE and (full_deck.get("hand", []) as Array).has("bone_dart"), "Quick Wits should complete its replacement draw at the hand cap")
	expect.call((full_deck.get("discard", []) as Array).has("quick_stab"), "A full hand should defer the primed Pain Remembers recall")
	expect.call(not combat.skill_was_used(full_state, "pain_remembers") and bool((full_state.get("skill_flags", {}) as Dictionary).get("pain_recall_primed", false)), "Pain Remembers should stay primed until a later discard has room to return")

	var cycle_state: Dictionary = _state(combat, ["quick_wits", "pain_remembers"], ["quick_stab", "brace"])
	cycle_state["deck"] = _deck(["quick_stab"], [], ["brace"])
	cycle_state = combat._damage_player(cycle_state, GameData.fixed_point_amount(1), true)
	cycle_state = combat.use_quick_wits(cycle_state, 0)
	var cycle_deck: Dictionary = cycle_state.get("deck", {}) as Dictionary
	expect.call((cycle_deck.get("hand", []) as Array).has("quick_stab"), "Pain Remembers should recall Quick Wits' promised discard before a deck-cycle shuffle can lose its identity")
	expect.call((cycle_deck.get("hand", []) as Array).has("brace"), "Quick Wits should still draw a replacement after the primed recall resolves")
	expect.call(combat.skill_was_used(cycle_state, "pain_remembers"), "A deck-cycle shuffle should not silently defer a Pain Remembers recall when the hand has room")

static func _test_rehearsed_escape_and_pain_remembers(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["rehearsed_escape", "pain_remembers"], ["patch_up", "quick_stab"])
	state["deck"] = _deck(["patch_up"], ["quick_stab"], [])
	state = combat._damage_player(state, GameData.fixed_point_amount(1), true)
	expect.call(_skill_event_count(combat, state, "pain_remembers") == 0, "Priming Pain Remembers should not emit an activation event")
	state = combat.arm_rehearsed_escape(state)
	expect.call(bool((state.get("skill_flags", {}) as Dictionary).get("burn_preserve_armed", false)), "Rehearsed Escape should preserve nothing until the player explicitly arms it")
	expect.call(not combat.skill_was_used(state, "rehearsed_escape"), "Rehearsed Escape should spend its charge only when it preserves a card")
	state = combat.finish_player_card(state, 0)
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	expect.call(not (deck.get("burned", []) as Array).has("patch_up"), "Rehearsed Escape should prevent the first non-item burn")
	expect.call((deck.get("hand", []) as Array).has("patch_up"), "Pain Remembers should return the next discarded non-item after health loss")
	expect.call(combat.skill_was_used(state, "rehearsed_escape") and combat.skill_was_used(state, "pain_remembers"), "Both linked defensive skills should spend their own combat charge")
	expect.call(_skill_event_count(combat, state, "pain_remembers") == 1, "Pain Remembers should emit one activation event when the recall resolves")
	var declined_state: Dictionary = _state(combat, ["rehearsed_escape"], ["patch_up"])
	declined_state["deck"] = _deck(["patch_up"], [], [])
	declined_state = combat.finish_player_card(declined_state, 0)
	expect.call((((declined_state.get("deck", {}) as Dictionary).get("burned", []) as Array).has("patch_up")), "Declining to arm Rehearsed Escape should preserve intentional combat-deck thinning")
	expect.call(not combat.skill_was_used(declined_state, "rehearsed_escape"), "Declining Rehearsed Escape should preserve its charge")
	var no_burn_state: Dictionary = _state(combat, ["rehearsed_escape"], ["quick_stab"])
	no_burn_state["deck"] = _deck(["quick_stab"], [], [])
	expect.call(not combat.skill_is_ready(no_burn_state, "rehearsed_escape"), "Rehearsed Escape should wait until a non-item Burn card is in hand")

static func _test_measured_breath_borrowed_time_and_guard(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["measured_breath", "borrowed_time", "carry_the_guard"], ["quick_stab", "quick_stab", "quick_stab"])
	state["deck"] = _deck(["quick_stab", "quick_stab", "quick_stab"], [], [])
	state = combat.finish_player_card(state, 0)
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["block"] = GameData.fixed_point_amount(3)
	state["player"] = player
	expect.call(combat.skill_is_ready(state, "carry_the_guard"), "Carry the Guard should become ready when the player has block")
	var unarmed_state: Dictionary = combat.finish_player_activation(state)
	var unarmed_player: Dictionary = unarmed_state.get("player", {}) as Dictionary
	expect.call(int(unarmed_player.get("block", 0)) == GameData.fixed_point_amount(3) and int(unarmed_player.get("stoneskin", 0)) == 0, "Carry the Guard should never consume incidental block without the player's choice")
	expect.call(not combat.skill_was_used(unarmed_state, "carry_the_guard"), "Declining Carry the Guard should preserve its charge")
	var event_count_before_arm: int = _skill_event_count(combat, state, "carry_the_guard")
	state = combat.arm_carry_the_guard(state)
	expect.call(bool((state.get("skill_flags", {}) as Dictionary).get("guard_carry_armed", false)), "Carry the Guard should visibly arm for the current activation")
	expect.call(_skill_event_count(combat, state, "carry_the_guard") == event_count_before_arm, "Arming Carry the Guard should not emit a realized trigger")
	player = (state.get("player", {}) as Dictionary).duplicate(true)
	player["block"] = int(player.get("block", 0)) + GameData.fixed_point_amount(2)
	state["player"] = player
	state = combat.finish_player_activation(state)
	expect.call(int(state.get("banked_plays", 0)) == 1, "Measured Breath should bank one unused play at activation end")
	player = state.get("player", {}) as Dictionary
	expect.call(int(player.get("block", 0)) == 0 and int(player.get("stoneskin", 0)) == GameData.fixed_point_amount(5), "Armed Carry the Guard should include block gained after arming")
	expect.call(combat.skill_was_used(state, "carry_the_guard") and _skill_event_count(combat, state, "carry_the_guard") == event_count_before_arm + 1, "Carry the Guard should spend and emit exactly once when conversion resolves")
	expect.call(not (state.get("skill_flags", {}) as Dictionary).has("guard_carry_armed"), "Carry the Guard should clear its arm at activation end")
	state = combat.prepare_next_player_turn(state)
	var opening_budget: Dictionary = combat.card_play_budget(state)
	expect.call(int(opening_budget.get("ordinary_remaining", 0)) == 2 and int(opening_budget.get("banked_remaining", 0)) == 1, "The next activation should distinguish two ordinary plays from one banked play")
	state["deck"] = _deck(["quick_stab", "quick_stab", "quick_stab"], [], [])
	state = combat.finish_player_card(state, 0)
	var first_budget: Dictionary = combat.card_play_budget(state)
	expect.call(int(first_budget.get("ordinary_remaining", 0)) == 1 and int(first_budget.get("banked_remaining", 0)) == 1 and not bool(state.get("last_card_used_banked_play", true)), "Ordinary plays should be consumed before the banked play")
	state = combat.finish_player_card(state, 0)
	var second_budget: Dictionary = combat.card_play_budget(state)
	expect.call(int(second_budget.get("ordinary_remaining", 0)) == 0 and int(second_budget.get("banked_remaining", 0)) == 1 and not bool(state.get("last_card_used_banked_play", true)), "The final ordinary card should leave the banked play visibly next")
	var time_before_banked_card: int = int(state.get("player_turn_time_spent", 0))
	state = combat.finish_player_card(state, 0)
	expect.call(int(state.get("player_turn_time_spent", 0)) == time_before_banked_card, "Borrowed Time should remove Time from the card paid by the banked play")
	expect.call(combat.skill_was_used(state, "borrowed_time") and int(state.get("banked_play_spent_this_activation", 0)) == 1, "Borrowed Time should spend only when a banked play pays for a card")
	var spent_budget: Dictionary = combat.card_play_budget(state)
	expect.call(int(spent_budget.get("ordinary_remaining", -1)) == 0 and int(spent_budget.get("banked_remaining", -1)) == 0, "The budget should show the banked slot as spent")

	var grant_state: Dictionary = _state(combat, ["borrowed_time"], ["guarded_step"])
	grant_state["deck"] = _deck(["guarded_step"], [], [])
	grant_state["banked_play_active"] = 1
	grant_state["cards_played_this_turn"] = 2
	grant_state = combat.apply_player_action(grant_state, {"type": "card_play", "amount": 1})
	var grant_time_before: int = int(grant_state.get("player_turn_time_spent", 0))
	grant_state = combat.finish_player_card(grant_state, 0)
	expect.call(bool(grant_state.get("last_card_used_banked_play", false)), "A card's payment should be snapshotted before its own extra-play effect")
	expect.call(int(grant_state.get("player_turn_time_spent", 0)) == grant_time_before and combat.skill_was_used(grant_state, "borrowed_time"), "Borrowed Time should remove Time when the banked play paid for a card that grants a play")
	var grant_budget: Dictionary = combat.card_play_budget(grant_state)
	expect.call(int(grant_budget.get("ordinary_remaining", 0)) == 1 and int(grant_budget.get("banked_remaining", -1)) == 0, "A play granted by the banked-paying card should be tracked as ordinary")
	var grant_deck: Dictionary = (grant_state.get("deck", {}) as Dictionary).duplicate(true)
	grant_deck["hand"] = ["quick_stab"]
	grant_state["deck"] = grant_deck
	grant_state = combat.finish_player_card(grant_state, 0)
	expect.call(not bool(grant_state.get("last_card_used_banked_play", true)), "The ordinary play granted afterward must not reuse the already-spent banked slot")

	var zero_state: Dictionary = _state(combat, ["carry_the_guard"], ["quick_stab"])
	player = (zero_state.get("player", {}) as Dictionary).duplicate(true)
	player["block"] = GameData.fixed_point_amount(1)
	zero_state["player"] = player
	zero_state = combat.arm_carry_the_guard(zero_state)
	player = (zero_state.get("player", {}) as Dictionary).duplicate(true)
	player["block"] = 0
	zero_state["player"] = player
	zero_state = combat.finish_player_activation(zero_state)
	expect.call(not combat.skill_was_used(zero_state, "carry_the_guard") and not (zero_state.get("skill_flags", {}) as Dictionary).has("guard_carry_armed"), "An armed activation ending at zero block should clear the arm without spending the charge")

static func _test_ghost_stride_afterimage_and_plunder(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["ghost_stride", "afterimage", "plunderers_step"], ["quick_stab"])
	var loot: Array = [{"kind": "healing_vial", "pos": Vector2i(3, 4), "amount": 10, "claimed": false}]
	state["loot"] = loot
	var move_action: Dictionary = combat.fallback_move_action(state, 2)
	expect.call(str(move_action.get("type", "")) == "move", "Ghost Stride should preserve the normal basic Move choice")
	expect.call(combat.skill_is_ready(state, "ghost_stride"), "Ghost Stride should be ready while a card play and legal visible Blink target remain")
	var no_hand_state: Dictionary = state.duplicate(true)
	no_hand_state["deck"] = _deck([], [], [])
	expect.call(not combat.skill_is_ready(no_hand_state, "ghost_stride"), "Ghost Stride should wait when no card is available for a basic Move")
	var no_play_state: Dictionary = state.duplicate(true)
	no_play_state["cards_played_this_turn"] = int(no_play_state.get("cards_per_turn", 0)) + int(no_play_state.get("card_play_bonus_this_turn", 0)) + int(no_play_state.get("banked_play_active", 0))
	expect.call(not combat.skill_is_ready(no_play_state, "ghost_stride"), "Ghost Stride should wait when no card play remains")
	for restriction_id: String in ["frozen", "immobilized"]:
		var restricted_state: Dictionary = state.duplicate(true)
		var restrictions: Dictionary = (restricted_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
		restrictions[restriction_id] = true
		restricted_state["player_turn_restrictions"] = restrictions
		expect.call(not combat.skill_is_ready(restricted_state, "ghost_stride"), "Ghost Stride should wait while %s prevents Blink" % restriction_id)
	var blocked_state: Dictionary = state.duplicate(true)
	var blocked_grid: Array = (blocked_state.get("grid", []) as Array).duplicate(true)
	var player_pos: Vector2i = (blocked_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	for y: int in range(blocked_grid.size()):
		var row: Array = (blocked_grid[y] as Array).duplicate()
		for x: int in range(row.size()):
			if Vector2i(x, y) != player_pos:
				row[x] = "wall"
		blocked_grid[y] = row
	blocked_state["grid"] = blocked_grid
	expect.call(not combat.skill_is_ready(blocked_state, "ghost_stride"), "Ghost Stride should wait when no legal visible Blink target exists")
	var moved_state: Dictionary = combat.apply_player_action(state, move_action, Vector2i(2, 5))
	expect.call(not combat.skill_was_used(moved_state, "ghost_stride"), "Choosing a normal Move should not spend Ghost Stride")
	var action: Dictionary = combat.fallback_blink_action(state, 2)
	expect.call(str(action.get("type", "")) == "blink", "Ghost Stride should expose a separate optional Blink choice")
	state = combat.apply_player_action(state, action, Vector2i(3, 4))
	expect.call(combat.skill_was_used(state, "ghost_stride"), "Ghost Stride should spend only after a legal Blink resolves")
	var illusions: Array = state.get("illusions", []) as Array
	expect.call(illusions.size() == 1 and (illusions[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Afterimage should leave an illusion at the Blink origin")
	expect.call(combat.skill_was_used(state, "afterimage"), "Afterimage should spend after creating its illusion")
	expect.call(int(state.get("card_play_bonus_this_turn", 0)) == 1 and combat.skill_was_used(state, "plunderers_step"), "Plunderer's Step should refund the first movement that collects loot")
	var pass_through_action: Dictionary = {"type": "move", "range": 2}
	expect.call(combat.valid_targets_for_player_action(state, pass_through_action).has(Vector2i(1, 4)), "A friendly Afterimage should not block a route back through its tile")
	state = combat.apply_player_action(state, pass_through_action, Vector2i(1, 4))
	expect.call((state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(1, 4), "The player should be able to retreat through an Afterimage")
	expect.call(int(((state.get("illusions", []) as Array)[0] as Dictionary).get("hp", 0)) > 0, "Passing through an Afterimage should leave the decoy in place")
	var end_on_action: Dictionary = {"type": "move", "range": 1}
	state = combat.apply_player_action(state, end_on_action, Vector2i(2, 4))
	expect.call(int(((state.get("illusions", []) as Array)[0] as Dictionary).get("hp", 0)) == 0, "Ending movement on a friendly illusion should dispel it instead of creating an overlap")

static func _test_makeshift_tool(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["makeshift_tool"], ["crimson_draught"])
	state["deck"] = _deck(["crimson_draught"], [], [])
	state = combat.arm_makeshift_tool(state)
	expect.call(not combat.skill_was_used(state, "makeshift_tool"), "Makeshift Tool should spend its charge only when it preserves an item")
	state = combat.finish_player_card(state, 0, 1, {"play_mode": "attack"})
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	expect.call((deck.get("discard", []) as Array).has("crimson_draught") and not (deck.get("consumed", []) as Array).has("crimson_draught"), "Makeshift Tool should preserve the first item used as a basic action")
	expect.call(combat.skill_was_used(state, "makeshift_tool"), "Makeshift Tool should spend its combat charge when it preserves an item")
	var declined_state: Dictionary = _state(combat, ["makeshift_tool"], ["crimson_draught"])
	declined_state["deck"] = _deck(["crimson_draught"], [], [])
	declined_state = combat.finish_player_card(declined_state, 0, 1, {"play_mode": "attack"})
	var declined_deck: Dictionary = declined_state.get("deck", {}) as Dictionary
	expect.call((declined_deck.get("consumed", []) as Array).has("crimson_draught"), "Declining to arm Makeshift Tool should preserve intentional consumable thinning")
	expect.call(not combat.skill_was_used(declined_state, "makeshift_tool"), "Declining Makeshift Tool should preserve its charge")
	var no_item_state: Dictionary = _state(combat, ["makeshift_tool"], ["quick_stab"])
	no_item_state["deck"] = _deck(["quick_stab"], [], [])
	expect.call(not combat.skill_is_ready(no_item_state, "makeshift_tool"), "Makeshift Tool should wait until an item is in hand")

	var blink_state: Dictionary = _state(combat, ["ghost_stride", "makeshift_tool"], ["smoke_bomb"])
	blink_state["deck"] = _deck(["smoke_bomb"], [], [])
	blink_state = combat.arm_makeshift_tool(blink_state)
	var blink_action: Dictionary = combat.fallback_blink_action(blink_state, 2)
	blink_state = combat.apply_player_action(blink_state, blink_action, Vector2i(3, 4))
	blink_state = combat.finish_player_card(blink_state, 0, 1, {
		"play_mode": "custom",
		"fallback_kind": str(blink_action.get("_fallback_kind", ""))
	})
	var blink_deck: Dictionary = blink_state.get("deck", {}) as Dictionary
	expect.call((blink_deck.get("discard", []) as Array).has("smoke_bomb") and not (blink_deck.get("consumed", []) as Array).has("smoke_bomb"), "Makeshift Tool should preserve an item used for Ghost Stride's semantic basic Move")
	expect.call(combat.skill_was_used(blink_state, "ghost_stride") and combat.skill_was_used(blink_state, "makeshift_tool"), "The combined Ghost Stride and Makeshift Tool use should spend both combat charges")

static func _test_preservation_on_winning_blow(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var escape_state: Dictionary = _state(combat, ["rehearsed_escape"], ["phoenix_cleave"])
	escape_state["deck"] = _deck(["phoenix_cleave"], [], [])
	escape_state = combat.arm_rehearsed_escape(escape_state)
	_set_single_enemy(escape_state, Vector2i(3, 4), GameData.fixed_point_amount(1))
	escape_state = combat.apply_player_action(escape_state, {"type": "melee", "damage": GameData.fixed_point_amount(2), "range": 1}, Vector2i(3, 4))
	expect.call(combat.combat_outcome(escape_state) == "victory", "The preservation regression should resolve from a winning blow")
	escape_state = combat.finish_player_card(escape_state, 0)
	var escape_deck: Dictionary = escape_state.get("deck", {}) as Dictionary
	expect.call((escape_deck.get("discard", []) as Array).has("phoenix_cleave") and not (escape_deck.get("burned", []) as Array).has("phoenix_cleave"), "Rehearsed Escape should preserve a burn card after its action wins combat")
	expect.call(combat.skill_was_used(escape_state, "rehearsed_escape"), "Rehearsed Escape should emit its winning-card activation")

	var tool_state: Dictionary = _state(combat, ["makeshift_tool"], ["nail_bomb"])
	tool_state["deck"] = _deck(["nail_bomb"], [], [])
	tool_state = combat.arm_makeshift_tool(tool_state)
	_set_single_enemy(tool_state, Vector2i(3, 4), GameData.fixed_point_amount(1))
	tool_state = combat.apply_player_action(tool_state, {"type": "melee", "damage": GameData.fixed_point_amount(2), "range": 1}, Vector2i(3, 4))
	expect.call(combat.combat_outcome(tool_state) == "victory", "The item preservation regression should resolve from a winning blow")
	tool_state = combat.finish_player_card(tool_state, 0, 1, {"play_mode": "attack"})
	var tool_deck: Dictionary = tool_state.get("deck", {}) as Dictionary
	expect.call((tool_deck.get("discard", []) as Array).has("nail_bomb") and not (tool_deck.get("consumed", []) as Array).has("nail_bomb"), "Makeshift Tool should preserve a basic-attack item after its action wins combat")
	expect.call(combat.skill_was_used(tool_state, "makeshift_tool"), "Makeshift Tool should emit its winning-card activation")

static func _test_sure_footed(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["sure_footed"], ["quick_stab"])
	state["traps"] = [{"pos": Vector2i(3, 4), "kind": "fire", "damage": GameData.fixed_point_amount(5)}]
	_set_single_enemy(state, Vector2i(4, 4), GameData.fixed_point_amount(10))
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.apply_player_action(state, {"type": "move", "range": 1}, Vector2i(3, 4))
	expect.call((state.get("traps", []) as Array).is_empty(), "Sure-Footed should still resolve and remove the first entered trap")
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == hp_before, "Sure-Footed should prevent the trap blast from affecting the player")
	expect.call(int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) < GameData.fixed_point_amount(10), "Sure-Footed should preserve the same trap blast against enemies")
	expect.call(combat.skill_was_used(state, "sure_footed"), "Sure-Footed should spend after preventing a player hit")

	var ranged_state: Dictionary = _state(combat, ["sure_footed"], ["bone_dart"])
	ranged_state["traps"] = [{"pos": Vector2i(4, 4), "kind": "fire", "damage": GameData.fixed_point_amount(5)}]
	ranged_state = combat.apply_player_action(ranged_state, {"type": "ranged", "damage": GameData.fixed_point_amount(1), "range": 3}, Vector2i(4, 4))
	expect.call((ranged_state.get("traps", []) as Array).is_empty(), "A safely triggered ranged trap should resolve normally")
	expect.call(not combat.skill_was_used(ranged_state, "sure_footed"), "A trap blast that cannot hit the player should not spend Sure-Footed")

	var push_state: Dictionary = _state(combat, ["sure_footed"], ["updraft"])
	_set_single_enemy(push_state, Vector2i(3, 4), GameData.fixed_point_amount(10))
	push_state["traps"] = [{"pos": Vector2i(4, 4), "kind": "fire", "damage": GameData.fixed_point_amount(5)}]
	push_state = combat.apply_player_action(push_state, {"type": "push", "amount": 1, "range": 1, "force_direction": Vector2i(1, 0)}, Vector2i(3, 4))
	expect.call((push_state.get("traps", []) as Array).is_empty(), "Player-forced enemy movement should still trigger the trap")
	expect.call(int(((push_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) < GameData.fixed_point_amount(10), "Sure-Footed should never suppress a useful forced-movement trap blast")
	expect.call(not combat.skill_was_used(push_state, "sure_footed"), "A safe forced-movement trap should preserve Sure-Footed for a later player hit")

	var enemy_push_state: Dictionary = _state(combat, ["sure_footed"], ["quick_stab"])
	enemy_push_state["traps"] = [
		{"pos": Vector2i(3, 4), "kind": "fire", "damage": GameData.fixed_point_amount(5)},
		{"pos": Vector2i(2, 3), "kind": "fire", "damage": GameData.fixed_point_amount(5)},
		{"pos": Vector2i(2, 5), "kind": "fire", "damage": GameData.fixed_point_amount(5)},
	]
	var pushed_hp_before: int = int((enemy_push_state.get("player", {}) as Dictionary).get("hp", 0))
	enemy_push_state = combat._move_player_from_source(enemy_push_state, Vector2i(1, 4), 1, true)
	expect.call(int((enemy_push_state.get("player", {}) as Dictionary).get("hp", 0)) == pushed_hp_before, "Sure-Footed should also protect against a trap reached through enemy-forced movement")
	expect.call(combat.skill_was_used(enemy_push_state, "sure_footed"), "An enemy-forced trap blast that would hit the player should spend Sure-Footed")

	var enemy_attack_state: Dictionary = _state(combat, ["sure_footed"], ["quick_stab"])
	enemy_attack_state["traps"] = [{"pos": Vector2i(3, 4), "kind": "fire", "damage": GameData.fixed_point_amount(5)}]
	var attacked_hp_before: int = int((enemy_attack_state.get("player", {}) as Dictionary).get("hp", 0))
	enemy_attack_state = combat._trigger_trap_at_index(enemy_attack_state, 0)
	expect.call(int((enemy_attack_state.get("player", {}) as Dictionary).get("hp", 0)) == attacked_hp_before, "Sure-Footed should protect when an enemy deliberately detonates a nearby trap")
	expect.call(combat.skill_was_used(enemy_attack_state, "sure_footed"), "An enemy-detonated blast that would hit the player should spend Sure-Footed")

static func _test_last_reserve(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["last_reserve"], ["quick_stab"])
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = GameData.fixed_point_amount(1)
	state["player"] = player
	state["draw_per_turn"] = 1
	state["deck"] = _deck([], [], ["quick_stab"])
	state = combat.prepare_next_player_turn(state)
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == GameData.fixed_point_amount(1), "Last Reserve should leave a lethal Fatigue draw at 1 health")
	expect.call(combat.skill_was_used(state, "last_reserve"), "Last Reserve should spend only after preventing lethal Fatigue")

static func _test_living_shadow(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["living_shadow"], ["quick_stab"])
	state["deck"] = _deck([], [], ["quick_stab"])
	state["illusions"] = [{"id": 7, "pos": Vector2i(3, 4), "hp": 10, "max_hp": 10}]
	state = combat._damage_illusion(state, 7, 10)
	expect.call((((state.get("deck", {}) as Dictionary).get("hand", []) as Array).has("quick_stab")), "Living Shadow should recall the latest non-item discard when an illusion falls")
	var hand_size: int = (((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size())
	state["deck"] = _deck((state.get("deck", {}) as Dictionary).get("hand", []) as Array, [], ["brace"])
	state["illusions"] = [{"id": 8, "pos": Vector2i(4, 4), "hp": 10, "max_hp": 10}]
	state = combat._damage_illusion(state, 8, 10)
	expect.call((((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()) == hand_size, "Living Shadow should trigger at most once per turn")

	var full_state: Dictionary = _state(combat, ["living_shadow"], ["quick_stab", "brace", "brace", "brace", "brace", "brace", "brace"])
	var full_hand: Array = ["quick_stab", "brace", "brace", "brace", "brace", "brace", "brace"]
	full_state["deck"] = _deck(full_hand, ["bone_dart"], ["patch_up"])
	full_state["illusions"] = [{"id": 9, "pos": Vector2i(3, 4), "hp": 10, "max_hp": 10}]
	full_state = combat._damage_illusion(full_state, 9, 10)
	var full_deck: Dictionary = full_state.get("deck", {}) as Dictionary
	expect.call((full_deck.get("hand", []) as Array) == full_hand, "Living Shadow should not exceed the hand cap")
	expect.call((full_deck.get("discard", []) as Array).is_empty() and (full_deck.get("draw", []) as Array).back() == "patch_up", "Living Shadow should put the recalled card atop draw when the hand is full")
	expect.call(_skill_event_message_contains(combat, full_state, "living_shadow", "atop the draw pile"), "Living Shadow should accurately announce its full-hand draw-pile fallback")

static func _test_prismatic_instinct_and_confluence(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var condition: Dictionary = {"type": "ranged", "damage": 10, "range": 5, "requires_intensity": {"element": "fire", "amount": 2}}
	var prismatic_state: Dictionary = _state(combat, ["prismatic_instinct"], ["rime_shard", "static_lash"])
	prismatic_state["deck"] = _deck(["rime_shard", "static_lash"], [], [])
	expect.call(not combat.action_intensity_requirement_met(prismatic_state, condition), "An unmet printed intensity requirement should remain locked before arming")
	prismatic_state = combat.arm_prismatic_instinct(prismatic_state, 0)
	expect.call(_skill_event_count(combat, prismatic_state, "prismatic_instinct") == 1, "Arming Prismatic Instinct should emit its sole activation event")
	expect.call(not combat.action_intensity_requirement_met(prismatic_state, condition), "An armed card should not grant global intensity outside its own printed play")
	var target_preview: Dictionary = combat.prepare_player_card(prismatic_state, 0, "play")
	expect.call(combat.action_intensity_requirement_met(target_preview, condition), "Prismatic Instinct should satisfy the selected card's elemental condition")
	var other_preview: Dictionary = combat.prepare_player_card(prismatic_state, 1, "play")
	expect.call(not combat.action_intensity_requirement_met(other_preview, condition), "Prismatic Instinct should not satisfy a different card's elemental condition")
	var fallback_preview: Dictionary = combat.prepare_player_card(prismatic_state, 0, "attack")
	expect.call(not combat.action_intensity_requirement_met(fallback_preview, condition), "A basic fallback use of the selected card should not receive Prismatic Instinct")
	var fallback_finished: Dictionary = combat.finish_player_card(fallback_preview, 0, 1, {"play_mode": "attack"})
	expect.call(bool((fallback_finished.get("skill_flags", {}) as Dictionary).get("prismatic_armed", false)), "A basic fallback use should not consume the Prismatic arm")
	expect.call(combat.elemental_intensity(prismatic_state, "fire") == 0, "Prismatic Instinct should not create real intensity")
	prismatic_state = combat.finish_player_card(other_preview, 1, 1, {"play_mode": "play"})
	expect.call(bool((prismatic_state.get("skill_flags", {}) as Dictionary).get("prismatic_armed", false)), "Playing a different printed card should preserve the Prismatic arm")
	prismatic_state = combat.prepare_player_card(prismatic_state, 0, "play")
	prismatic_state = combat.finish_player_card(prismatic_state, 0, 1, {"play_mode": "play"})
	expect.call(not bool((prismatic_state.get("skill_flags", {}) as Dictionary).get("prismatic_armed", false)), "Playing an elemental condition card should consume the Prismatic arm")
	expect.call(_skill_event_count(combat, prismatic_state, "prismatic_instinct") == 1, "Fulfilling Prismatic Instinct should not emit a duplicate activation event")
	var duplicate_state: Dictionary = _state(combat, ["prismatic_instinct"], ["rime_shard", "rime_shard"])
	duplicate_state["deck"] = _deck(["rime_shard", "rime_shard"], [], [])
	expect.call(combat.prismatic_target_hand_indices(duplicate_state) == [0], "Duplicate conditional card names should appear as one Prismatic choice")
	duplicate_state = combat.arm_prismatic_instinct(duplicate_state, 0)
	duplicate_state = combat.prepare_player_card(duplicate_state, 1, "play")
	expect.call(combat.action_intensity_requirement_met(duplicate_state, condition), "Prismatic Instinct should explicitly arm the named card type, including another copy")
	var confluence_state: Dictionary = _state(combat, ["confluence"], ["quick_stab"])
	confluence_state["elemental_intensity"] = {"fire": 0, "ice": 3, "lightning": 0, "air": 0, "earth": 0}
	expect.call(combat.action_intensity_requirement_met(confluence_state, condition), "Confluence should let the highest current intensity satisfy another element's condition")
	expect.call(combat.elemental_intensity(confluence_state, "fire") == 0, "Confluence should not alter actual element counters")
	var conditional_draw: Dictionary = {"type": "draw", "amount": 1, "requires_intensity": {"element": "fire", "amount": 2}}
	var fragile_player: Dictionary = (confluence_state.get("player", {}) as Dictionary).duplicate(true)
	fragile_player["hp"] = GameData.fixed_point_amount(1)
	confluence_state["player"] = fragile_player
	confluence_state["deck"] = _deck([], [], ["brace"])
	confluence_state = combat.apply_player_action(confluence_state, conditional_draw)
	expect.call(int((confluence_state.get("player", {}) as Dictionary).get("hp", 0)) == GameData.fixed_point_amount(1), "Confluence should never turn a previously unmet conditional draw into Fatigue")
	expect.call(((confluence_state.get("deck", {}) as Dictionary).get("discard", []) as Array) == ["brace"], "A Confluence-only draw should leave the discard untouched when no safe draw remains")
	expect.call(_skill_event_count(combat, confluence_state, "confluence") == 1, "Confluence should emit one activation when another element first satisfies a committed condition")
	var second_confluence_action: Dictionary = {"type": "card_play", "amount": 1, "requires_intensity": {"element": "fire", "amount": 2}}
	confluence_state = combat.apply_player_action(confluence_state, second_confluence_action)
	expect.call(int(confluence_state.get("card_play_bonus_this_turn", 0)) == 1, "Confluence should remain mechanically active after its analytics event fires")
	expect.call(_skill_event_count(combat, confluence_state, "confluence") == 1, "Confluence should emit at most one first-benefit activation per combat")
	var confluence_bonus_state: Dictionary = _state(combat, ["confluence"], ["quick_stab"])
	confluence_bonus_state["elemental_intensity"] = {"fire": 0, "ice": 3, "lightning": 0, "air": 0, "earth": 0}
	confluence_bonus_state = combat.apply_player_action(confluence_bonus_state, {
		"type": "block",
		"amount": 1,
		"intensity_bonus": {"element": "fire", "threshold": 2, "amount": 2}
	})
	expect.call(int((confluence_bonus_state.get("player", {}) as Dictionary).get("block", 0)) == 3, "Confluence should recognize a highest-intensity bonus as a real benefit boundary")
	expect.call(_skill_event_count(combat, confluence_bonus_state, "confluence") == 1, "A Confluence-enabled intensity bonus should emit its single combat activation")
	var invalid_target_state: Dictionary = _state(combat, ["confluence"], ["quick_stab"])
	invalid_target_state["elemental_intensity"] = {"fire": 0, "ice": 3, "lightning": 0, "air": 0, "earth": 0}
	invalid_target_state = combat.apply_player_action(invalid_target_state, {
		"type": "melee",
		"damage": 1,
		"range": 1,
		"requires_intensity": {"element": "fire", "amount": 2}
	}, Vector2i(-1, -1))
	expect.call(_skill_event_count(combat, invalid_target_state, "confluence") == 0, "Confluence should not emit for a targeted action that never commits")
	var native_draw_state: Dictionary = _state(combat, ["confluence"], ["quick_stab"])
	native_draw_state["elemental_intensity"] = {"fire": 2, "ice": 3, "lightning": 0, "air": 0, "earth": 0}
	fragile_player = (native_draw_state.get("player", {}) as Dictionary).duplicate(true)
	fragile_player["hp"] = GameData.fixed_point_amount(1)
	native_draw_state["player"] = fragile_player
	native_draw_state["deck"] = _deck([], [], ["brace"])
	native_draw_state = combat.apply_player_action(native_draw_state, conditional_draw)
	expect.call(combat.combat_outcome(native_draw_state) == "defeat", "Confluence should not suppress Fatigue when the card's own element already satisfies its draw condition")
	expect.call(_skill_event_count(combat, native_draw_state, "confluence") == 0, "Confluence should not claim an activation when the card's native element already satisfies its condition")

static func _test_encore(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = _state(combat, ["encore"], ["quick_stab"])
	state["deck"] = _deck([], [], ["quick_stab"])
	state = combat.use_encore(state, 0)
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	expect.call((deck.get("hand", []) as Array).has("quick_stab") and (deck.get("discard", []) as Array).is_empty(), "Encore should return the selected non-item discard to hand")
	expect.call(int(state.get("cards_played_this_turn", 0)) == 0 and int(state.get("player_turn_time_spent", 0)) == 0, "Encore should cost neither a play nor Time")
	expect.call(combat.skill_was_used(state, "encore"), "Encore should spend after use")

static func _test_radiance_branch(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var long_dawn_state: Dictionary = _state(combat, ["long_dawn"], ["quick_stab"])
	long_dawn_state = combat.apply_player_action(long_dawn_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(3, 4))
	long_dawn_state = combat.apply_player_action(long_dawn_state, {"type": "vision", "amount": 1, "duration": 2})
	long_dawn_state = combat.apply_player_action(long_dawn_state, {"type": "truesight", "duration": 2})
	var long_dawn_umbra: Dictionary = long_dawn_state.get("umbra", {}) as Dictionary
	expect.call(int(((long_dawn_umbra.get("light_sources", []) as Array)[0] as Dictionary).get("remaining_activations", 0)) == 3, "Long Dawn should extend temporary Light from two turns to three")
	expect.call(int(long_dawn_umbra.get("vision_bonus_activations", 0)) == 3 and int(long_dawn_umbra.get("truesight_activations", 0)) == 3, "Long Dawn should extend temporary Vision and Truesight through the same central duration rule")
	var permanent_state: Dictionary = _state(combat, ["long_dawn"], ["quick_stab"])
	permanent_state = combat.apply_player_action(permanent_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": -1}, Vector2i(3, 4))
	expect.call(int((((permanent_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array)[0] as Dictionary).get("remaining_activations", 0)) == -1, "Long Dawn should leave permanent Light permanent")

	var sunpath_state: Dictionary = _state(combat, ["sunpath", "long_dawn"], ["quick_stab"])
	sunpath_state = combat.apply_player_action(sunpath_state, {"type": "move", "range": 4}, Vector2i(5, 4))
	var sunpath_sources: Array = (sunpath_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(sunpath_sources.size() == 3, "Sunpath should leave one Light source on every entered tile of a three-tile Move")
	for source_var: Variant in sunpath_sources:
		expect.call(int((source_var as Dictionary).get("remaining_activations", 0)) == 3, "Sunpath Light should participate in Long Dawn's duration extension")
	var source_count_before_second_move: int = sunpath_sources.size()
	sunpath_state = combat.apply_player_action(sunpath_state, {"type": "move", "range": 4}, Vector2i(2, 4))
	expect.call(((sunpath_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == source_count_before_second_move, "Sunpath should trigger only on the first qualifying movement each turn")

	var blink_state: Dictionary = _state(combat, ["sunpath"], ["quick_stab"])
	blink_state = combat.apply_player_action(blink_state, {"type": "blink", "range": 4}, Vector2i(5, 4))
	var blink_sources: Array = (blink_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(blink_sources.size() == 2, "Sunpath should light only a Blink's origin and destination")

	var witchlight_state: Dictionary = _state(combat, ["witchlight"], ["quick_stab"])
	witchlight_state["illusions"] = [{"id": 51, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	expect.call(bool(combat.call("_light_source_covers_tile", witchlight_state, Vector2i(5, 4))), "Witchlight should make a living illusion a real radius-one Light source")
	expect.call(not bool(combat.call("_light_source_covers_tile", witchlight_state, Vector2i(6, 4))), "Witchlight should not exceed its authored radius")

	var dawnbrand_state: Dictionary = _state(combat, ["dawnbrand"], ["quick_stab"])
	dawnbrand_state = combat.apply_player_action(dawnbrand_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(5, 2))
	dawnbrand_state = combat.apply_player_action(dawnbrand_state, {"type": "ranged", "damage": 1, "range": 6}, Vector2i(5, 2))
	expect.call(int(((dawnbrand_state.get("enemies", []) as Array)[0] as Dictionary).get("expose", 0)) == 1, "Dawnbrand should Expose the first directly attacked enemy standing in Light")
	dawnbrand_state = combat.apply_player_action(dawnbrand_state, {"type": "ranged", "damage": 1, "range": 6}, Vector2i(5, 2))
	expect.call(int(((dawnbrand_state.get("enemies", []) as Array)[0] as Dictionary).get("expose", 0)) == 0 and _skill_event_count(combat, dawnbrand_state, "dawnbrand") == 1, "Dawnbrand should trigger at most once per turn; the second attack may consume the first Expose but must not reapply it")

	var afterglow_state: Dictionary = _state(combat, ["afterglow"], ["quick_stab"])
	afterglow_state["illusions"] = [{"id": 52, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	afterglow_state = combat._damage_illusion(afterglow_state, 52, 2)
	var afterglow_sources: Array = (afterglow_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(afterglow_sources.size() == 1 and (afterglow_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Afterglow should leave Light at an illusion's final tile when it is removed")

	var open_sky_state: Dictionary = _state(combat, ["open_sky"], ["quick_stab"])
	expect.call(not bool(combat.call("_player_has_truesight", open_sky_state)), "Open Sky should not grant Truesight outside Light")
	var player_pos: Vector2i = (open_sky_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	open_sky_state = combat.apply_player_action(open_sky_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, player_pos)
	expect.call(bool(combat.call("_player_has_truesight", open_sky_state)), "Open Sky should grant Truesight while the player stands in Light")

static func _state(combat: CombatEngine, skills: Array, cards: Array) -> Dictionary:
	return combat.create_combat(501, _room(), {
		"hp": GameData.fixed_point_amount(30),
		"max_hp": GameData.fixed_point_amount(30),
		"deck_cards": cards,
		"skill_ids": skills,
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})

static func _deck(hand: Array, draw: Array, discard: Array) -> Dictionary:
	return {
		"hand": hand.duplicate(),
		"draw": draw.duplicate(),
		"discard": discard.duplicate(),
		"burned": [],
		"consumed": [],
		"cycles": 0,
		"fatigue_base": CombatEngine.FATIGUE_BASE_DAMAGE
	}

static func _set_single_enemy(state: Dictionary, pos: Vector2i, hp: int) -> void:
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["pos"] = pos
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["block"] = 0
	enemy["stoneskin"] = 0
	enemies[0] = enemy
	state["enemies"] = enemies

static func _skill_event_count(combat: CombatEngine, state: Dictionary, skill_id: String) -> int:
	var count: int = 0
	for event: Dictionary in combat.skill_events(state):
		if str(event.get("skill_id", "")) == skill_id:
			count += 1
	return count

static func _skill_event_message_contains(combat: CombatEngine, state: Dictionary, skill_id: String, fragment: String) -> bool:
	for event: Dictionary in combat.skill_events(state):
		if str(event.get("skill_id", "")) == skill_id and fragment in str(event.get("message", "")):
			return true
	return false

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Skill Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 2), "hp": 100, "max_hp": 100, "block": 0}],
		"loot": [],
		"traps": []
	}
