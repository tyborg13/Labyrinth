extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

const SEED: int = 73021
const FIRST_ROOM: Vector2i = Vector2i(1, 0)
const FIRST_BOSS_ROOM: Vector2i = Vector2i(4, 0)

static func run(expect: Callable) -> void:
	_test_new_run_ignores_retired_growth(expect)
	_test_discerning_eye(expect)
	_test_sequence_limited_skills_refresh_after_boss(expect)
	_test_deferred_choice(expect)
	_test_salvager(expect)
	_test_true_bearing(expect)
	_test_retired_layaway_migration(expect)
	_test_curators_patience(expect)
	_test_open_arsenal(expect)
	_test_last_door(expect)
	_test_first_boss_moltshard_is_idempotent(expect)
	_test_first_boss_moltshard_survives_torn_save(expect)
	_test_boss_notice_keeps_moltshard_and_missed_equipment(expect)
	_test_reset_preserves_spent_state_and_earned_pending(expect)
	_test_combat_snapshot_progression_repair_preserves_use_history(expect)
	_test_progression_revision_reconciliation(expect)
	_test_torn_level_up_reconciliation_spends_embers(expect)

static func _test_new_run_ignores_retired_growth(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var forged: Dictionary = ProgressionStore.default_data()
	forged["stats"] = {"vigor": 99, "focus": 99}
	forged["purchased_upgrades"] = ["unknown_upgrade"]
	forged["card_mods"] = {"quick_stab": [{"type": "damage", "amount": 500, "cost_paid": 1}]}
	var state: Dictionary = engine.create_new_run(SEED, forged)
	expect.call(int(state.get("player_max_hp", 0)) == RunEngineScript.BASE_MAX_HP, "New runs should always begin with base maximum health")
	expect.call(int(state.get("hand_size", 0)) == RunEngineScript.BASE_HAND_SIZE, "New runs should always begin with the base hand size")
	expect.call(int(state.get("heal_bonus", -1)) == 0, "New runs should not retain permanent healing bonuses")
	var embedded: Dictionary = state.get("progression", {}) as Dictionary
	expect.call(not embedded.has("stats") and not embedded.has("card_mods") and not embedded.has("purchased_upgrades"), "New runs should sanitize every retired numeric-growth field")
	var learned: Dictionary = _valid_profile(["quick_wits"], 1, 0, 2)
	state["progression"] = learned
	state["mode"] = "combat"
	state["combat_state"] = {"skill_ids": [], "stats": {"agility": 99}, "card_mods": {"quick_stab": []}}
	var repaired: Dictionary = engine.repair_loaded_run_state(state)
	var repaired_combat: Dictionary = repaired.get("combat_state", {}) as Dictionary
	expect.call((repaired_combat.get("skill_ids", []) as Array).has("quick_wits"), "Resumed combat should receive the migrated embedded skill build")
	expect.call(not repaired_combat.has("stats") and not repaired_combat.has("card_mods"), "Resumed combat should remove retired numeric-growth fields")

static func _test_discerning_eye(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["discerning_eye"])
	var original_cards: Array = ["rime_shard", "static_lash", "gust_step"]
	state["mode"] = "reward"
	state["pending_reward"] = {
		"cards": original_cards.duplicate(),
		"heal_amount": 60,
		"ember_amount": 8
	}
	var rerolled: Dictionary = engine.reroll_card_reward(state)
	var rerolled_cards: Array = ((rerolled.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
	expect.call(rerolled_cards.size() == 3, "Discerning Eye should replace a three-card reward with three cards")
	expect.call(rerolled_cards != original_cards, "Discerning Eye should produce a different deterministic reward set")
	for card_id: String in original_cards:
		expect.call(not rerolled_cards.has(card_id), "Discerning Eye should exclude every card from the original offer")
	expect.call(engine.run_skill_used_this_sequence(rerolled, "discerning_eye"), "Discerning Eye should spend its sequence use after a successful reroll")
	var trigger_events: Array[Dictionary] = engine.run_skill_events(rerolled)
	expect.call(trigger_events.size() == 1 and str(trigger_events[0].get("skill_id", "")) == "discerning_eye", "Discerning Eye should emit one durable run-skill trigger event")
	var repeated: Dictionary = engine.reroll_card_reward(rerolled)
	expect.call(repeated.get("pending_reward", {}) == rerolled.get("pending_reward", {}), "Discerning Eye should not reroll twice in one sequence")
	expect.call(engine.run_skill_events(repeated).size() == 1, "Repeating a spent run skill should not duplicate its trigger event")

static func _test_sequence_limited_skills_refresh_after_boss(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["discerning_eye"])
	var depth_three := Vector2i(3, 0)
	state = _set_current_room(state, depth_three, "combat")
	state["mode"] = "combat"
	state = engine.finish_combat(state, _combat_result(depth_three, "combat", true))
	state = engine.reroll_card_reward(state)
	var used_by_sequence: Dictionary = ((state.get("skill_state", {}) as Dictionary).get("used_by_sequence", {}) as Dictionary)
	expect.call(bool(used_by_sequence.get("0:discerning_eye", false)), "Using Discerning Eye before the first boss should spend sequence zero")
	expect.call(not engine.run_skill_is_ready(state, "discerning_eye"), "Discerning Eye should remain spent before crossing the boss boundary")
	var offered_cards: Array = ((state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
	if not offered_cards.is_empty():
		state = engine.claim_card_reward(state, str(offered_cards[0]))

	state = _set_current_room(state, FIRST_BOSS_ROOM, "boss")
	state["mode"] = "combat"
	state = engine.finish_combat(state, _combat_result(FIRST_BOSS_ROOM, "boss", true))
	expect.call(not engine.run_skill_is_ready(state, "discerning_eye"), "The first boss reward boundary itself should still belong to sequence zero")

	var depth_five := Vector2i(5, 0)
	state = _set_current_room(state, depth_five, "combat")
	state["mode"] = "combat"
	state = engine.finish_combat(state, _combat_result(depth_five, "combat", true))
	expect.call(engine.run_skill_is_ready(state, "discerning_eye"), "A sequence-limited skill should refresh in the first reward after the boss")
	state = engine.reroll_card_reward(state)
	used_by_sequence = ((state.get("skill_state", {}) as Dictionary).get("used_by_sequence", {}) as Dictionary)
	expect.call(bool(used_by_sequence.get("0:discerning_eye", false)) and bool(used_by_sequence.get("1:discerning_eye", false)), "Sequence refresh should retain both historical use keys")
	var trigger_events: Array[Dictionary] = engine.run_skill_events(state)
	var discerning_triggers: int = 0
	for event: Dictionary in trigger_events:
		if str(event.get("skill_id", "")) == "discerning_eye":
			discerning_triggers += 1
	expect.call(discerning_triggers == 2, "Using Discerning Eye once on each side of a boss should emit exactly two durable trigger events")

static func _test_deferred_choice(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["deferred_choice"])
	state["mode"] = "reward"
	state["player_hp"] = 100
	state["player_max_hp"] = 360
	state["pending_reward"] = {
		"cards": ["rime_shard", "static_lash", "gust_step"],
		"heal_amount": 60,
		"ember_amount": 8
	}
	state = engine.skip_reward_for_heal(state, "rime_shard")
	var skill_state: Dictionary = state.get("skill_state", {}) as Dictionary
	expect.call(str(skill_state.get("pending_card", "")) == "rime_shard", "Deferred Choice should remember one card from the skipped reward")
	expect.call(int(state.get("player_hp", 0)) == 160 and str(state.get("mode", "")) == "room", "Skipping a reward should keep the existing heal flow")
	var deferred_events: Array[Dictionary] = engine.run_skill_events(state)
	expect.call(deferred_events.size() == 1 and str(deferred_events[0].get("skill_id", "")) == "deferred_choice", "Storing a deferred card should emit one durable run-skill event")
	var repeated_skip: Dictionary = engine.skip_reward_for_heal(state, "rime_shard")
	expect.call(engine.run_skill_events(repeated_skip).size() == 1, "A repeated no-op reward skip should not duplicate Deferred Choice analytics")
	state = _set_current_room(state, FIRST_ROOM, "combat")
	state["mode"] = "combat"
	var rewarded: Dictionary = engine.finish_combat(state, _combat_result(FIRST_ROOM, "combat", true))
	var next_cards: Array = ((rewarded.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
	expect.call(next_cards.has("rime_shard"), "Deferred Choice should place the remembered card into the next reward")
	expect.call(str((rewarded.get("skill_state", {}) as Dictionary).get("pending_card", "")) == "", "The remembered card should clear when it enters an offer")

static func _test_salvager(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["salvager"])
	state = _set_current_room(state, FIRST_ROOM, "combat")
	state["mode"] = "combat"
	var first_loot: Array = [_equipment_loot("stitcher_apron", Vector2i(3, 3))]
	var first_result: Dictionary = _combat_result(FIRST_ROOM, "combat", true, first_loot)
	state = engine.finish_combat(state, first_result)
	expect.call((state.get("equipment_inventory", []) as Array).has("stitcher_apron"), "Salvager should recover the first unclaimed equipment reward")
	expect.call(engine.run_skill_used_this_sequence(state, "salvager"), "Salvager should spend its sequence use after recovering equipment")
	expect.call(str(engine.run_skill_events(state)[0].get("skill_id", "")) == "salvager", "Salvager should emit a durable automatic trigger event")
	var second_room := Vector2i(1, 1)
	state = _set_current_room(state, second_room, "combat")
	state["mode"] = "combat"
	var second_loot: Array = [_equipment_loot("rimeplate_harness", Vector2i(4, 3))]
	state = engine.finish_combat(state, _combat_result(second_room, "combat", true, second_loot))
	expect.call(not (state.get("equipment_inventory", []) as Array).has("rimeplate_harness"), "Salvager should not recover a second item in the same sequence")

static func _test_true_bearing(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["true_bearing"])
	state = _set_current_room(state, FIRST_ROOM, "combat")
	state["mode"] = RunEngineScript.MODE_PRE_BATTLE
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = Vector2i.RIGHT
	var preview: Dictionary = engine.pre_battle_preview_state(state)
	var authored_start: Vector2i = (((preview.get("combat_state", {}) as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
	var choices: Array[Vector2i] = engine.pre_battle_start_tiles(state)
	expect.call(not choices.is_empty(), "True Bearing should expose legal starting tiles before combat")
	var chosen_start: Vector2i = authored_start
	for tile: Vector2i in choices:
		if tile != authored_start:
			chosen_start = tile
			break
	expect.call(chosen_start != authored_start, "True Bearing should offer at least one alternative to the authored entrance")
	var rejected: Dictionary = engine.set_pre_battle_start(state, Vector2i.ZERO)
	expect.call(not rejected.has("pre_battle_start"), "True Bearing should reject an impassable distant tile")
	expect.call(engine.run_skill_events(rejected).is_empty(), "Rejecting a True Bearing tile should not emit a trigger event")
	state = engine.set_pre_battle_start(state, chosen_start)
	var true_bearing_events: Array[Dictionary] = engine.run_skill_events(state)
	expect.call(true_bearing_events.size() == 1 and str(true_bearing_events[0].get("skill_id", "")) == "true_bearing", "Changing the pre-battle tile should emit one durable True Bearing event")
	var repeated_selection: Dictionary = engine.set_pre_battle_start(state, chosen_start)
	expect.call(engine.run_skill_events(repeated_selection).size() == 1, "Selecting the current pre-battle tile should not duplicate True Bearing analytics")
	var begun: Dictionary = engine.begin_pre_battle_combat(state)
	var actual_start: Vector2i = (((begun.get("combat_state", {}) as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
	expect.call(actual_start == chosen_start, "True Bearing should apply the selected starting tile to the opening combat state")
	expect.call(not begun.has("pre_battle_start"), "The pre-battle selection should clear after combat begins")

static func _test_retired_layaway_migration(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var legacy_skill_ids: Array[String] = [
		"measured_breath",
		"discerning_eye",
		"deferred_choice",
		"layaway",
	]
	var legacy_profile: Dictionary = ProgressionStore.default_data()
	legacy_profile["progression_schema"] = 6
	legacy_profile["level"] = 5
	legacy_profile["skill_ids"] = legacy_skill_ids.duplicate()
	legacy_profile["progression_revision"] = 7
	var migrated_profile: Dictionary = ProgressionStore.normalized_data(legacy_profile)
	expect.call(int(migrated_profile.get("progression_schema", 0)) == ProgressionStore.PROGRESSION_SCHEMA, "Retiring Layaway should advance legacy profiles to the current progression schema")
	expect.call(not ProgressionStore.selected_skill_ids(migrated_profile).has("layaway"), "Retiring Layaway should strip its learned id from the migrated profile")
	expect.call(ProgressionStore.unspent_skill_points(migrated_profile) == 1, "Retiring Layaway should refund its learned point instead of silently spending it elsewhere")
	expect.call(int(migrated_profile.get("progression_revision", 0)) == 8, "A retired-skill refund should advance progression revision exactly once")
	expect.call(ProgressionStore.normalized_data(migrated_profile) == migrated_profile, "Retired-skill profile migration should be idempotent")

	var state: Dictionary = engine.create_new_run(SEED, ProgressionStore.default_data())
	var origin := Vector2i(3, 0)
	var destination := Vector2i(3, 1)
	state = _with_room(state, origin, "scavenger", true, [
		"rime_shard", "static_lash", "gust_step",
		"stitcher_apron", "rimeplate_harness", "sunken_anchor",
		"crimson_draught", "nail_bomb", "jaw_trap",
	])
	state = _with_room(state, destination, "scavenger", false, [
		"frostbolt", "spark_dart", "dawnstep",
		"witchglass_aegis", "sunken_anchor", "rimeplate_harness",
		"smoke_bomb", "storm_jar", "mossglass_elixir",
	])
	state["current_room"] = origin
	state["mode"] = "combat"
	state["progression"] = legacy_profile.duplicate(true)
	state[RunEngineScript.RUN_CONTENT_SCHEMA_KEY] = 2
	state["combat_state"] = {"skill_ids": legacy_skill_ids.duplicate()}
	state[RunEngineScript.COMBAT_CONTINUATION_KEY] = [{
		"state": {"skill_ids": legacy_skill_ids.duplicate()},
	}]
	state["skill_state"] = {
		"used_by_sequence": {"0:layaway": true},
		"reserved_merchant": {
			"kind": "scavenger",
			"item_id": "stitcher_apron",
			"origin_coord": origin,
		},
	}
	var repaired: Dictionary = engine.repair_loaded_run_state(state)
	expect.call(int(repaired.get(RunEngineScript.RUN_CONTENT_SCHEMA_KEY, 0)) == RunEngineScript.RUN_CONTENT_SCHEMA, "Retired-skill run repair should stamp the current run-content schema")
	expect.call(not engine.run_skill_ids(repaired).has("layaway"), "Retired Layaway should not remain active in a repaired run")
	expect.call(ProgressionStore.unspent_skill_points(repaired.get("progression", {}) as Dictionary) == 1, "A repaired run should retain the profile's refunded Layaway point")
	var repaired_combat: Dictionary = repaired.get("combat_state", {}) as Dictionary
	expect.call(not (repaired_combat.get("skill_ids", []) as Array).has("layaway"), "Retired Layaway should be stripped from resumed combat skill ids")
	var repaired_checkpoints: Array = repaired.get(RunEngineScript.COMBAT_CONTINUATION_KEY, []) as Array
	var checkpoint_state: Dictionary = ((repaired_checkpoints[0] as Dictionary).get("state", {}) as Dictionary) if not repaired_checkpoints.is_empty() else {}
	expect.call(not (checkpoint_state.get("skill_ids", []) as Array).has("layaway"), "Retired Layaway should be stripped from pending combat checkpoints")
	var repaired_reservation: Dictionary = ((repaired.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) as Dictionary)
	expect.call(str(repaired_reservation.get("item_id", "")) == "stitcher_apron", "Run repair should preserve stock already held before Layaway was retired")

	repaired["mode"] = "room"
	repaired["combat_state"] = {}
	var arrived: Dictionary = engine.move_to_room(repaired, destination)
	var destination_stock: Array = engine.merchant_offer_ids(arrived, "scavenger")
	expect.call(arrived.get("current_room", Vector2i.ZERO) == destination, "The deterministic merchant fixture should permit travel to the next visit")
	expect.call(destination_stock.has("stitcher_apron"), "Stock held before Layaway retirement should return at the next Scavenger visit")
	expect.call((arrived.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) == {}, "The legacy reservation should clear after returning once")
	var attempted_hold: Dictionary = engine.reserve_merchant_offer(arrived, str(destination_stock[0]) if not destination_stock.is_empty() else "")
	expect.call((attempted_hold.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) == {}, "A migrated run must not create a new Layaway reservation")

static func _test_curators_patience(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["curators_patience"])
	var origin := Vector2i(3, 0)
	var destination := Vector2i(3, 1)
	state = _with_room(state, origin, "treasure", true)
	state = _with_room(state, destination, "treasure", false)
	state["current_room"] = origin
	state["mode"] = "treasure"
	state["pending_relics"] = ["iron_lung", "flint_edge", "coffin_nails"]
	state = engine.claim_relic(state, "iron_lung", "flint_edge")
	expect.call(str((state.get("skill_state", {}) as Dictionary).get("pending_relic", "")) == "flint_edge", "Curator's Patience should remember one unchosen relic")
	var curator_events: Array[Dictionary] = engine.run_skill_events(state)
	expect.call(curator_events.size() == 1 and str(curator_events[0].get("skill_id", "")) == "curators_patience", "Storing a deferred relic should emit one durable Curator's Patience event")
	var repeated_claim: Dictionary = engine.claim_relic(state, "iron_lung", "flint_edge")
	expect.call(engine.run_skill_events(repeated_claim).size() == 1, "A repeated invalid relic claim should not duplicate Curator's Patience analytics")
	var arrived: Dictionary = engine.move_to_room(state, destination)
	expect.call((arrived.get("pending_relics", []) as Array).has("flint_edge"), "Curator's Patience should place the remembered relic into the next offer")
	expect.call(str((arrived.get("skill_state", {}) as Dictionary).get("pending_relic", "")) == "", "The remembered relic should clear when it enters an offer")

static func _test_open_arsenal(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["open_arsenal"])
	var original_trinket: String = str((state.get("equipped_equipment", {}) as Dictionary).get("trinket", ""))
	state["equipment_inventory"] = ["stitcher_apron"]
	var collected: Array = state.get("collected_equipment", []).duplicate()
	collected.append("stitcher_apron")
	state["collected_equipment"] = collected
	var native_state: Dictionary = state.duplicate(true)
	(native_state.get("equipment_inventory", []) as Array).append("ember_pendant")
	(native_state.get("collected_equipment", []) as Array).append("ember_pendant")
	native_state = engine.equip_equipment(native_state, "ember_pendant", "trinket")
	expect.call(engine.run_skill_events(native_state).is_empty(), "A legal native-slot equip should not claim an Open Arsenal activation")
	var equipped: Dictionary = engine.equip_equipment(state, "stitcher_apron", "trinket")
	expect.call(str((equipped.get("equipped_equipment", {}) as Dictionary).get("trinket", "")) == "stitcher_apron", "Open Arsenal should allow armor in the trinket slot")
	expect.call((equipped.get("equipment_inventory", []) as Array).has(original_trinket), "Wild-slot equip should stow the displaced trinket")
	var arsenal_events: Array[Dictionary] = engine.run_skill_events(equipped)
	expect.call(arsenal_events.size() == 1 and str(arsenal_events[0].get("skill_id", "")) == "open_arsenal", "Open Arsenal should emit one run activation after a successful off-slot equip")
	var repeated: Dictionary = engine.equip_equipment(equipped, "stitcher_apron", "trinket")
	expect.call(engine.run_skill_events(repeated).size() == 1, "Repeating an already-equipped Open Arsenal choice should not emit a duplicate activation")
	var without_skill: Dictionary = ProgressionStore.default_data()
	without_skill["embers"] = int(equipped.get("held_embers", 0))
	var repaired: Dictionary = engine.apply_progression_update(equipped, without_skill)
	expect.call(str((repaired.get("equipped_equipment", {}) as Dictionary).get("trinket", "")) == original_trinket, "Removing Open Arsenal should restore a native trinket")
	expect.call((repaired.get("equipment_inventory", []) as Array).has("stitcher_apron"), "Removing Open Arsenal should safely stow off-slot equipment")
	var sold_state: Dictionary = equipped.duplicate(true)
	var sold_inventory: Array = (sold_state.get("equipment_inventory", []) as Array).duplicate()
	sold_inventory.erase(original_trinket)
	sold_state["equipment_inventory"] = sold_inventory
	var sold_collected: Array = (sold_state.get("collected_equipment", []) as Array).duplicate()
	sold_collected.erase(original_trinket)
	sold_state["collected_equipment"] = sold_collected
	var repaired_after_sale: Dictionary = engine.apply_progression_update(sold_state, without_skill)
	expect.call(str((repaired_after_sale.get("equipped_equipment", {}) as Dictionary).get("trinket", "")) == "", "Removing Open Arsenal must leave the trinket slot empty when every native trinket was sold")
	expect.call((repaired_after_sale.get("equipment_inventory", []) as Array).has("stitcher_apron"), "Removing Open Arsenal after a sale should still stow the off-slot equipment")
	expect.call(not (repaired_after_sale.get("equipment_inventory", []) as Array).has(original_trinket) and not (repaired_after_sale.get("collected_equipment", []) as Array).has(original_trinket), "Removing Open Arsenal must not recreate sold starter equipment")
	var reloaded_after_sale: Dictionary = engine.repair_loaded_run_state(repaired_after_sale)
	expect.call(str((reloaded_after_sale.get("equipped_equipment", {}) as Dictionary).get("trinket", "")) == "", "An intentionally empty trinket slot should remain empty after save repair")
	expect.call(not (reloaded_after_sale.get("equipment_inventory", []) as Array).has(original_trinket), "Save repair must not recreate a sold native trinket")

static func _test_last_door(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, ["last_door"])
	state = _set_current_room(state, FIRST_ROOM, "combat")
	state["mode"] = "combat"
	state = engine.set_held_embers(state, 91)
	state["equipped_items"] = ["crimson_draught"]
	state = engine.consume_equipped_item_card(state, "crimson_draught")
	var skill_state: Dictionary = (state.get("skill_state", {}) as Dictionary).duplicate(true)
	skill_state["previous_room"] = Vector2i.ZERO
	state["skill_state"] = skill_state
	var retreated: Dictionary = engine.finish_combat(state, _combat_result(FIRST_ROOM, "combat", false))
	expect.call(retreated.get("current_room", Vector2i(-1, -1)) == Vector2i.ZERO, "Last Door should return a defeated player to the previous room")
	expect.call(int(retreated.get("player_hp", 0)) == GameData.fixed_point_amount(1), "Last Door should return the player at exactly 1 health")
	expect.call(str(retreated.get("mode", "")) == "room" and not bool(retreated.get("game_over", true)), "Last Door should avert non-boss defeat")
	expect.call(engine.held_embers(retreated) == 91, "Last Door should preserve embers held during the failed encounter")
	expect.call(not (retreated.get("equipped_items", []) as Array).has("crimson_draught") and not (retreated.get("item_inventory", []) as Array).has("crimson_draught"), "Last Door should not restore a consumed item")
	expect.call(engine.run_skill_used_this_sequence(retreated, "last_door"), "Last Door should spend its sequence use after retreating")
	expect.call(str(engine.run_skill_events(retreated)[0].get("skill_id", "")) == "last_door", "Last Door should emit a durable automatic trigger event")
	retreated["current_room"] = FIRST_ROOM
	retreated["mode"] = "combat"
	var defeated: Dictionary = engine.finish_combat(retreated, _combat_result(FIRST_ROOM, "combat", false))
	expect.call(str(defeated.get("mode", "")) == "defeat" and bool(defeated.get("game_over", false)), "Last Door should not refresh within the same sequence")

static func _test_first_boss_moltshard_is_idempotent(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, [])
	state = _set_current_room(state, FIRST_BOSS_ROOM, "boss")
	state["mode"] = "combat"
	var boss_result: Dictionary = _combat_result(FIRST_BOSS_ROOM, "boss", true)
	var rewarded: Dictionary = engine.finish_combat(state, boss_result)
	var first_progression: Dictionary = rewarded.get("progression", {}) as Dictionary
	expect.call(ProgressionStore.moltshard_count(first_progression) == 1, "The first boss victory should award one Moltshard")
	expect.call((rewarded.get("item_inventory", []) as Array).is_empty(), "A Moltshard should remain progression currency rather than entering run inventory")
	expect.call(str(rewarded.get("notice", "")).contains("Moltshard acquired"), "The boss reward should tell the player that a Moltshard was acquired")
	var first_revision: int = int(first_progression.get("progression_revision", 0))
	var repeated: Dictionary = engine.finish_combat(rewarded, boss_result)
	var repeated_progression: Dictionary = repeated.get("progression", {}) as Dictionary
	expect.call(ProgressionStore.moltshard_count(repeated_progression) == 1, "Repeating boss resolution should not award another Moltshard")
	expect.call(int(repeated_progression.get("progression_revision", 0)) == first_revision, "Idempotent boss resolution should not advance progression twice")

static func _test_first_boss_moltshard_survives_torn_save(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var stale_run: Dictionary = _new_run(engine, [])
	stale_run = _set_current_room(stale_run, FIRST_BOSS_ROOM, "boss")
	stale_run["mode"] = "combat"
	var boss_result: Dictionary = _combat_result(FIRST_BOSS_ROOM, "boss", true)
	var first_resolution: Dictionary = engine.finish_combat(stale_run, boss_result)
	var saved_profile: Dictionary = first_resolution.get("progression", {}) as Dictionary
	var resumed_stale_run: Dictionary = engine.reconcile_progression_revision(stale_run, saved_profile)
	var replayed_resolution: Dictionary = engine.finish_combat(resumed_stale_run, boss_result)
	var replayed_profile: Dictionary = replayed_resolution.get("progression", {}) as Dictionary
	expect.call(ProgressionStore.moltshard_count(replayed_profile) == 1, "A profile-first torn save must not duplicate the first-boss Moltshard on replay")
	expect.call((replayed_profile.get(ProgressionStore.MOLTSHARD_AWARD_IDS_KEY, []) as Array).size() == 1, "The Moltshard award ledger should retain exactly one source id after replay")
	expect.call(bool((replayed_resolution.get("skill_state", {}) as Dictionary).get("moltshard_awarded", false)), "Replaying a torn boss snapshot should repair its run-local award marker")

static func _test_boss_notice_keeps_moltshard_and_missed_equipment(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var state: Dictionary = _new_run(engine, [])
	state = _set_current_room(state, FIRST_BOSS_ROOM, "boss")
	state["mode"] = "combat"
	var boss_result: Dictionary = _combat_result(FIRST_BOSS_ROOM, "boss", true, [_equipment_loot("stitcher_apron", Vector2i(4, 4))])
	var rewarded: Dictionary = engine.finish_combat(state, boss_result)
	var notice: String = str(rewarded.get("notice", ""))
	expect.call(notice.contains("Moltshard acquired"), "A boss notice should retain Moltshard acquisition feedback when equipment was missed")
	expect.call(notice.contains(RunEngineScript.MISSED_EQUIPMENT_NOTICE), "A boss notice should also retain the missed-equipment warning")

static func _test_reset_preserves_spent_state_and_earned_pending(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var original_order: Array = [
		"quick_wits", "measured_breath", "ghost_stride", "discerning_eye",
		"deferred_choice", "sure_footed", "curators_patience", "true_bearing", "layaway"
	]
	var profile: Dictionary = _valid_profile(original_order, 9, 1, 4)
	var reshaped: Dictionary = ProgressionStore.reset_skills(profile)
	expect.call(ProgressionStore.moltshard_count(reshaped) == 0, "A full reset should consume exactly one Moltshard")
	expect.call(ProgressionStore.selected_skill_ids(reshaped).is_empty() and ProgressionStore.unspent_skill_points(reshaped) == 9, "Reset should clear every skill and refund every earned point")
	var state: Dictionary = engine.create_new_run(SEED, profile)
	state["skill_state"] = {
		"used_by_sequence": {"0:discerning_eye": true, "0:layaway": true},
		"pending_card": "rime_shard",
		"pending_relic": "flint_edge",
		"reserved_merchant": {"kind": "scavenger", "item_id": "stitcher_apron", "origin_coord": Vector2i(3, 0)},
		"previous_room": Vector2i.ZERO,
		"moltshard_awarded": false
	}
	state["pre_battle_start"] = Vector2i(3, 4)
	var updated: Dictionary = engine.apply_progression_update(state, reshaped)
	var updated_skill_state: Dictionary = updated.get("skill_state", {}) as Dictionary
	expect.call(str(updated_skill_state.get("pending_card", "")) == "rime_shard", "Reset should preserve a card already earned through Deferred Choice")
	expect.call(str(updated_skill_state.get("pending_relic", "")) == "flint_edge", "Reset should preserve a relic already earned through Curator's Patience")
	expect.call(str((updated_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "Reset should preserve stock already held through Layaway")
	expect.call(not updated.has("pre_battle_start"), "Removing True Bearing should clear its pending starting tile")
	expect.call(bool((updated_skill_state.get("used_by_sequence", {}) as Dictionary).get("0:layaway", false)), "Reset should retain prior use history instead of refreshing removed skills if they are relearned")
	var repaired: Dictionary = engine.repair_loaded_run_state(updated)
	var repaired_skill_state: Dictionary = repaired.get("skill_state", {}) as Dictionary
	expect.call(str(repaired_skill_state.get("pending_card", "")) == "rime_shard" and str(repaired_skill_state.get("pending_relic", "")) == "flint_edge", "Save repair should preserve valid earned deferrals after their source skills are removed")
	expect.call(str((repaired_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "stitcher_apron", "Save repair should preserve a valid earned merchant reservation")

	var card_redemption: Dictionary = _set_current_room(updated, FIRST_ROOM, "combat")
	card_redemption["mode"] = "combat"
	card_redemption = engine.finish_combat(card_redemption, _combat_result(FIRST_ROOM, "combat", true))
	expect.call((((card_redemption.get("pending_reward", {}) as Dictionary).get("cards", []) as Array).has("rime_shard")), "An earned deferred card should redeem once after its source skill is removed")
	expect.call(str((card_redemption.get("skill_state", {}) as Dictionary).get("pending_card", "")) == "", "The removed-skill card redemption should clear after entering an offer")
	card_redemption["mode"] = "reward"
	card_redemption = engine.skip_reward_for_heal(card_redemption, "rime_shard")
	expect.call(str((card_redemption.get("skill_state", {}) as Dictionary).get("pending_card", "")) == "", "Without Deferred Choice, a later skipped reward must not create a new pending card")

	var origin := Vector2i(3, 0)
	var destination := Vector2i(3, 1)
	var relic_redemption: Dictionary = _with_room(updated, origin, "treasure", true)
	relic_redemption = _with_room(relic_redemption, destination, "treasure", false)
	relic_redemption["current_room"] = origin
	relic_redemption["mode"] = "room"
	relic_redemption = engine.move_to_room(relic_redemption, destination)
	expect.call((relic_redemption.get("pending_relics", []) as Array).has("flint_edge"), "An earned deferred relic should redeem once after its source skill is removed")
	expect.call(str((relic_redemption.get("skill_state", {}) as Dictionary).get("pending_relic", "")) == "", "The removed-skill relic redemption should clear after entering an offer")
	var relic_choices: Array = relic_redemption.get("pending_relics", []) as Array
	var chosen_relic: String = str(relic_choices[0]) if not relic_choices.is_empty() else ""
	var other_relic: String = ""
	for relic_id_var: Variant in relic_choices:
		if str(relic_id_var) != chosen_relic:
			other_relic = str(relic_id_var)
			break
	if not chosen_relic.is_empty():
		relic_redemption = engine.claim_relic(relic_redemption, chosen_relic, other_relic)
	expect.call(str((relic_redemption.get("skill_state", {}) as Dictionary).get("pending_relic", "")) == "", "Without Curator's Patience, the redeemed offer must not create a new pending relic")

	var merchant_redemption: Dictionary = _with_room(updated, origin, "scavenger", true, [
		"rime_shard", "static_lash", "gust_step",
		"sunken_anchor", "rimeplate_harness",
		"crimson_draught", "nail_bomb", "jaw_trap",
	])
	merchant_redemption = _with_room(merchant_redemption, destination, "scavenger", false, [
		"frostbolt", "spark_dart", "dawnstep",
		"witchglass_aegis", "sunken_anchor", "rimeplate_harness",
		"smoke_bomb", "storm_jar", "mossglass_elixir",
	])
	merchant_redemption["current_room"] = origin
	merchant_redemption["mode"] = "room"
	merchant_redemption = engine.move_to_room(merchant_redemption, destination)
	var returned_stock: Array = engine.merchant_offer_ids(merchant_redemption, "scavenger")
	expect.call(returned_stock.has("stitcher_apron"), "Earned Layaway stock should return once after its source skill is removed")
	expect.call((merchant_redemption.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) == {}, "The removed-skill reservation should clear after returning")
	var attempted_hold: Dictionary = engine.reserve_merchant_offer(merchant_redemption, str(returned_stock[0]) if not returned_stock.is_empty() else "")
	expect.call((attempted_hold.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) == {}, "Without Layaway, a merchant visit must not create a new reservation")

static func _test_progression_revision_reconciliation(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var embedded: Dictionary = _valid_profile(["quick_wits"], 1, 0, 2)
	embedded["embers"] = 12
	var state: Dictionary = engine.create_new_run(SEED, embedded)
	state = engine.set_held_embers(state, 77)
	var newer: Dictionary = _valid_profile(["discerning_eye"], 1, 0, 3)
	newer["embers"] = 999
	var reconciled: Dictionary = engine.reconcile_progression_revision(state, newer)
	expect.call(engine.has_run_skill(reconciled, "discerning_eye") and not engine.has_run_skill(reconciled, "quick_wits"), "A newer profile revision should replace the embedded skill build")
	expect.call(int((reconciled.get("progression", {}) as Dictionary).get("progression_revision", 0)) == 3, "Revision reconciliation should retain the newer revision")
	expect.call(engine.held_embers(reconciled) == 77, "Revision reconciliation should preserve the run's held embers")
	var older: Dictionary = _valid_profile(["quick_wits"], 1, 0, 1)
	var unchanged: Dictionary = engine.reconcile_progression_revision(reconciled, older)
	expect.call(engine.has_run_skill(unchanged, "discerning_eye"), "An older profile revision should not replace the embedded build")

static func _test_torn_level_up_reconciliation_spends_embers(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var embedded: Dictionary = _valid_profile(["quick_wits"], 1, 0, 2)
	embedded["embers"] = 0
	var stale_run: Dictionary = engine.create_new_run(SEED, embedded)
	var level_cost: int = ProgressionStore.next_level_cost(embedded)
	stale_run = engine.set_held_embers(stale_run, level_cost + 17)
	stale_run["mode"] = "campfire"
	stale_run["player_hp"] = int(stale_run.get("player_max_hp", 1)) - GameData.fixed_point_amount(3)
	var health_before_reconciliation: int = int(stale_run.get("player_hp", 0))
	var purchase_source: Dictionary = ProgressionStore.set_embers(embedded, engine.held_embers(stale_run))
	var purchased: Dictionary = ProgressionStore.purchase_level(purchase_source)
	expect.call(int(purchased.get("level", 0)) == int(embedded.get("level", 0)) + 1, "Torn-save fixture should contain a completed profile-first level purchase")
	var reconciled: Dictionary = engine.reconcile_progression_revision(stale_run, purchased)
	expect.call(engine.held_embers(reconciled) == int(purchased.get("embers", -1)), "Resuming after a profile-first level-up must retain the post-purchase ember total")
	expect.call(engine.held_embers(reconciled) == 17, "A torn level-up must not restore the embers already spent on that level")
	expect.call(not engine.has_run_skill(reconciled, "measured_breath"), "A torn level-up should not invent a skill choice")
	expect.call(ProgressionStore.unspent_skill_points(reconciled.get("progression", {}) as Dictionary) == 1, "A torn level-up should retain its newly earned unspent point")
	expect.call(str(reconciled.get("mode", "")) == "room", "A torn level-up must consume the stale campfire choice on resume")
	expect.call(int(reconciled.get("player_hp", 0)) == health_before_reconciliation, "Torn level-up recovery must not also grant the campfire heal")

static func _test_combat_snapshot_progression_repair_preserves_use_history(expect: Callable) -> void:
	var engine = RunEngineScript.new()
	var original: Dictionary = _valid_profile([
		"quick_wits", "measured_breath", "discerning_eye", "pain_remembers", "prismatic_instinct"
	], 5, 1, 2)
	var alternate: Dictionary = _valid_profile([
		"ghost_stride", "discerning_eye", "sure_footed", "deferred_choice", "salvager"
	], 5, 0, 3)
	var state: Dictionary = engine.create_new_run(SEED, original)
	state["mode"] = "combat"
	state["combat_state"] = {
		"skill_ids": ProgressionStore.selected_skill_ids(original),
		"skill_flags": {
			"used:quick_wits": true,
			"prismatic_armed": true,
			"prismatic_target_card_id": "rime_shard",
			"prismatic_resolving": true,
			"burn_preserve_armed": true,
			"item_preserve_armed": true,
			"guard_carry_armed": true,
			"pain_recall_primed": true
		},
		"banked_plays": 1,
		"banked_play_active": 1,
		"banked_play_spent_this_activation": 1
	}
	var changed: Dictionary = engine.apply_progression_update(state, alternate)
	var changed_combat: Dictionary = changed.get("combat_state", {}) as Dictionary
	var changed_flags: Dictionary = changed_combat.get("skill_flags", {}) as Dictionary
	expect.call((changed_combat.get("skill_ids", []) as Array) == ProgressionStore.selected_skill_ids(alternate), "Applying a newer profile should repair the saved combat skill build")
	expect.call(bool(changed_flags.get("used:quick_wits", false)), "Combat snapshot repair should preserve use history for removed skills")
	expect.call(not changed_flags.has("prismatic_armed") and not changed_flags.has("prismatic_target_card_id") and not changed_flags.has("prismatic_resolving") and not changed_flags.has("burn_preserve_armed") and not changed_flags.has("item_preserve_armed") and not changed_flags.has("guard_carry_armed") and not changed_flags.has("pain_recall_primed"), "Removing skills should clear their unspent pending combat benefits")
	expect.call(int(changed_combat.get("banked_plays", -1)) == 0 and int(changed_combat.get("banked_play_active", -1)) == 0 and int(changed_combat.get("banked_play_spent_this_activation", -1)) == 0, "Removing Measured Breath should clear banked plays and their spent accounting")
	var restored: Dictionary = engine.apply_progression_update(changed, original)
	var restored_flags: Dictionary = ((restored.get("combat_state", {}) as Dictionary).get("skill_flags", {}) as Dictionary)
	expect.call(bool(restored_flags.get("used:quick_wits", false)), "Re-adding a spent skill should not refresh its combat use")

static func _new_run(engine, skills: Array) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	var preference: Array[String]
	var target_count: int = 0
	for skill_id_var: Variant in skills:
		var skill_id: String = str(skill_id_var)
		_append_skill_path(skill_id, preference)
		target_count = maxi(target_count, SkillTreeLibrary.minimum_owned(skill_id) + 1)
	target_count = maxi(target_count, preference.size())
	progression["level"] = target_count + 1
	progression["skill_ids"] = SkillTreeLibrary.repaired_selection([], target_count, preference)
	return engine.create_new_run(SEED, progression)

static func _append_skill_path(skill_id: String, preference: Array[String]) -> void:
	for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
		_append_skill_path(prerequisite_id, preference)
	if not preference.has(skill_id):
		preference.append(skill_id)

static func _valid_profile(preferred_order: Array, skill_count: int, moltshards: int, revision: int) -> Dictionary:
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = skill_count + 1
	profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], skill_count, preferred_order)
	profile["moltshards"] = moltshards
	profile["progression_revision"] = revision
	return ProgressionStore.normalized_data(profile)

static func _set_current_room(state: Dictionary, coord: Vector2i, room_type: String) -> Dictionary:
	var next_state: Dictionary = _with_room(state, coord, room_type, false)
	next_state["current_room"] = coord
	return next_state

static func _with_room(state: Dictionary, coord: Vector2i, room_type: String, cleared: bool, stock: Array = []) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var room: Dictionary = {
		"coord": coord,
		"depth": maxi(absi(coord.x), absi(coord.y)),
		"type": room_type,
		"merchant_kind": room_type if room_type in ["blacksmith", "arcanist", "scavenger"] else "",
		"element": "fire" if room_type == "combat" else "none",
		"npcs": [{"id": room_type, "pos": Vector2i(3, 4)}] if room_type in ["blacksmith", "arcanist", "scavenger"] else [],
		"revealed": true,
		"visited": true,
		"cleared": cleared,
		"sealed": false
	}
	if not stock.is_empty():
		room["merchant_stock"] = stock.duplicate()
		room["merchant_sold_items"] = []
		room["merchant_purchased_items"] = []
		room["merchant_refill_count"] = 0
	var rooms: Dictionary = (next_state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	next_state["rooms"] = rooms
	return next_state

static func _combat_result(coord: Vector2i, room_type: String, victory: bool, loot: Array = []) -> Dictionary:
	var hp: int = GameData.fixed_point_amount(20) if victory else 0
	return {
		"player": {"hp": hp, "max_hp": GameData.fixed_point_amount(36), "pos": Vector2i(2, 4)},
		"enemies": [],
		"room_name": "Run Skill Test",
		"room_coord": coord,
		"room_depth": maxi(absi(coord.x), absi(coord.y)),
		"room_type": room_type,
		"room_element": "fire" if room_type == "combat" else "none",
		"room_embers": 8,
		"grid": _grid(),
		"moss": {},
		"loot": loot.duplicate(true),
		"traps": [],
		"terrain": [],
		"collected_equipment": [],
		"missed_equipment": [],
		"run_stats": RunEngineScript.normalized_run_stats({})
	}

static func _equipment_loot(equipment_id: String, pos: Vector2i) -> Dictionary:
	return {
		"kind": "equipment",
		"equipment_id": equipment_id,
		"pos": pos,
		"claimed": false,
		"resolution": ""
	}

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String]
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

static func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
