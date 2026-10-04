extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixtures = preload("res://tests/suites/surface_relic_suite.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Dialogue = preload("res://scripts/dialogue_engine.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
var failed: int = 0

func _initialize() -> void:
	Store.set_storage_path("user://dragon_rewards_profile.json")
	Store.set_run_storage_path("user://dragon_rewards_run.save")
	_test_milestones()
	_test_claim_outbox()
	_test_wallet_recovery()
	_test_wallet_event_context()
	_test_gift_write_failure()
	_test_relics()
	_test_worldheart_secondary_damage()
	_test_dialogue()
	if failed == 0: print("Dragon rewards, gifts, wallet recovery and relic hooks passed.")
	quit(1 if failed else 0)

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _test_milestones() -> void:
	var engine := Run.new()
	var combat := Combat.new()
	for id: String in Bosses.BOSS_RELICS:
		var options := {"dragon_id":id, "dragon_depth":24 if id == "noctyrax" else 4}
		var original: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
		var battle: Dictionary = original["combat_state"].duplicate(true)
		battle["player"]["hp"] = 10
		for index: int in range(battle["enemies"].size()): battle = combat._damage_enemy(battle, index, 999, true, true)
		var state: Dictionary = engine.finish_combat(original, battle)
		var reward: Dictionary = state["pending_reward"]
		expect(engine.is_dragon_reward(state) and not bool(state["victory"]), "%s holds a nonterminal milestone" % id)
		expect(str(reward["relic_id"]) == Bosses.relic_for_boss(id), "%s grants its own relic" % id)
		expect(int(reward["ember_amount"]) == int(battle["room_embers"]) + Run.BOSS_VICTORY_EMBERS and engine.held_embers(state) - engine.held_embers(original) == int(reward["ember_amount"]), "Displayed Embers equal the actual credited payout")
		expect(int(reward["healed_amount"]) == int(state["player_hp"]) - 10 and int(reward["moltshards"]) == (0 if id == "noctyrax" else 1), "Milestone records actual healing and only the first-dragon shard")
		expect(engine.finish_combat(state, battle) == state, "Repeated dragon resolution changes no rewards, health, or currency")
		expect(engine.skip_reward_for_heal(state) == state and engine.claim_card_reward(state, "frostbolt") == state and engine.reroll_card_reward(state) == state, "Ordinary reward actions cannot consume a milestone")
		expect(Store.save_run_state(state) and Store.load_saved_run() == state, "Milestone round-trips with the final board and payout")
		var next: Dictionary = engine.continue_dragon_reward(state)
		expect(engine.continue_dragon_reward(next) == next and engine.finish_combat(next, battle) == next, "Acknowledgment and stale combat replay are idempotent")
		if id == "noctyrax":
			expect(next["mode"] == "victory" and bool(next["victory"]), "Final milestone acknowledgment ends the descent")
			var profile: Dictionary = next["progression"]
			var receiving: Dictionary = engine.create_new_run(123456, Store.prepare_for_new_run(profile))
			expect((receiving["relics"] as Array).has("eclipse_mantle"), "Noctyrax's trophy shapes the next descent")
			var consumed: Dictionary = Store.acknowledge_starting_relic_gifts(profile, receiving["starting_relic_gift_ids"])
			consumed = Store.award_starting_relic_gift(consumed, reward["milestone_id"], "eclipse_mantle")
			expect(Store.pending_starting_relic_gifts(consumed).is_empty(), "A consumed gift cannot be reissued by replaying its award")
			expect(not (engine.create_new_run(654321, Store.prepare_for_new_run(consumed))["relics"] as Array).has("eclipse_mantle"), "The gift lasts for one descent")
		else:
			expect(next["mode"] == "room" and (next["relics"] as Array).has(reward["relic_id"]), "An elemental trophy stays in the current run")
	var offer_state: Dictionary = engine.create_new_run(701, Store.default_data())
	for x: int in range(20):
		for relic: String in engine._generate_relic_choices(offer_state, Vector2i(x, 1)):
			expect(str(Data.relic_def(relic).get("exclusive_boss", "")).is_empty(), "Dragon trophies do not enter random relic offers")

func _claim_fixture(id: String, seed: int) -> Dictionary:
	var engine := Run.new()
	var options := {"dragon_id":id, "dragon_depth":24 if id == "noctyrax" else 4, "dragon_case":"reward", "seed":seed}
	var state: Dictionary = Factory.build(engine, Combat.new(), engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
	state["analytics"] = {"run_id":"dragon_claim_%d" % seed, "combat_counter":1}
	return state

func _claim_host(state: Dictionary) -> RunScene:
	var scene := RunScene.new()
	scene.set("_run_state", state)
	scene.set("_progression", state.get("progression", Store.load_data()))
	return scene

func _claim_count(key: String) -> int:
	var count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("idempotency_key", "")) == key: count += 1
	return count

func _test_claim_outbox() -> void:
	const EVENT_DIR: String = "user://dragon_claim_events"
	const BLOCKED_EVENTS: String = "user://dragon_claim_blocked"
	Analytics.set_storage_dir(EVENT_DIR)
	Analytics.clear_storage()
	var blocker: FileAccess = FileAccess.open(BLOCKED_EVENTS, FileAccess.WRITE)
	expect(blocker != null, "Claim analytics failure fixture creates its blocker")
	if blocker != null:
		blocker.store_string("blocked")
		blocker.close()
	var engine := Run.new()
	var reward_state: Dictionary = _claim_fixture("vyraketh", 919001)
	var reward: Dictionary = reward_state["pending_reward"]
	var key: String = "reward_claimed|%s" % reward["milestone_id"]
	var held: int = engine.held_embers(reward_state)
	expect(Store.save_data(Store.set_embers(reward_state["progression"], 0)), "Claim fixture saves an unbanked profile")
	var host: RunScene = _claim_host(reward_state)
	var candidate: Dictionary = host.call("_stage_dragon_reward_claim", engine.continue_dragon_reward(reward_state), reward)
	expect((host.get("_run_state") as Dictionary) == reward_state, "Staging the claim does not mutate the visible milestone")
	var saved: Dictionary = host.call("_persist_run_state_snapshot", candidate, false, "claim_crash_before_append")
	expect(bool(saved["saved"]) and _claim_count(key) == 0, "Continue and pending claim persist before any append")
	host.free()
	var restored: Dictionary = Store.load_saved_run()
	expect(restored["mode"] == "room" and Store.progression_analytics_outbox(restored["progression"]).size() == 1, "Crash after Continue keeps its replay source in the run")
	Analytics.set_storage_dir(BLOCKED_EVENTS)
	host = _claim_host(restored)
	expect(not bool(host.call("_reconcile_progression_analytics_outbox")), "Append failure leaves the claim pending")
	host.free()
	expect(Store.progression_analytics_outbox(Store.load_saved_run()["progression"]).size() == 1, "Failed append cannot erase the saved receipt")

	Analytics.set_storage_dir(EVENT_DIR)
	var blocked_profile: String = ProjectSettings.globalize_path("user://dragon_rewards_profile.json.tmp")
	DirAccess.make_dir_absolute(blocked_profile)
	host = _claim_host(Store.load_saved_run())
	expect(not bool(host.call("_reconcile_progression_analytics_outbox")), "Append can succeed while its profile acknowledgment fails")
	expect(_claim_count(key) == 1 and Store.progression_analytics_outbox(host.get("_progression")).size() == 1, "Failed acknowledgment retains an already appended claim")
	host.free()
	DirAccess.remove_absolute(blocked_profile)
	host = _claim_host(Store.load_saved_run())
	expect(bool(host.call("_reconcile_progression_analytics_outbox")), "Recovered claim acknowledgment succeeds")
	host.call("_sync_progression_analytics_outbox_to_run")
	expect(bool(host.call("_persist_committed_boundary", "claim_test_ack")), "Intermediate claim acknowledgment saves to the run")
	expect(_claim_count(key) == 1 and Store.progression_analytics_outbox(Store.load_saved_run()["progression"]).is_empty(), "Crash replay emits exactly one claim and clears the receipt")
	expect(engine.held_embers(host.get("_run_state")) == held and int(Store.load_data()["embers"]) == 0, "Claim recovery never banks or repeats the reward payout")
	expect(not bool(host.call("_commit_dragon_reward_continue")), "Repeated Continue after commitment does nothing")
	host.free()

	reward_state = _claim_fixture("vyraketh", 929101)
	key = "reward_claimed|%s" % reward_state["pending_reward"]["milestone_id"]
	expect(Store.save_run_state(reward_state), "Save-failure fixture retains its original milestone")
	var blocked_run: String = ProjectSettings.globalize_path("user://dragon_rewards_run.save.tmp")
	DirAccess.make_dir_absolute(blocked_run)
	host = _claim_host(reward_state)
	expect(not bool(host.call("_commit_dragon_reward_continue")), "Failed run save rejects Continue")
	expect(engine.is_dragon_reward(host.get("_run_state")) and _claim_count(key) == 0, "Failed Continue keeps the milestone and emits no premature claim")
	DirAccess.remove_absolute(blocked_run)
	expect(bool(host.call("_commit_dragon_reward_continue")) and _claim_count(key) == 1, "Retry commits the claim once")
	expect(not bool(host.call("_commit_dragon_reward_continue")) and _claim_count(key) == 1, "Repeated UI activation cannot duplicate the claim")
	host.free()

	reward_state = _claim_fixture("noctyrax", 939201)
	key = "reward_claimed|%s" % reward_state["pending_reward"]["milestone_id"]
	held = engine.held_embers(reward_state)
	expect(Store.save_data(Store.set_embers(reward_state["progression"], 0)) and Store.save_run_state(reward_state), "Final milestone fixture persists its gift and resume state")
	Analytics.set_storage_dir(BLOCKED_EVENTS)
	host = _claim_host(reward_state)
	expect(bool(host.call("_commit_dragon_reward_continue")), "Final Continue succeeds despite unavailable analytics storage")
	var profile: Dictionary = Store.load_data()
	expect(not Store.has_saved_run() and Store.progression_analytics_outbox(profile).size() == 1, "Final Continue transfers the claim to the profile before clearing the run")
	expect(int(profile["embers"]) == held and Store.pending_starting_relic_gifts(profile).size() == 1, "Final outbox merge preserves the bank and one-descent trophy gift")
	host.free()
	Analytics.set_storage_dir(EVENT_DIR)
	host = _claim_host({})
	expect(bool(host.call("_reconcile_progression_analytics_outbox")) and _claim_count(key) == 1, "A new boot emits the final claim without needing a saved run")
	profile = Store.load_data()
	expect(Store.progression_analytics_outbox(profile).is_empty() and int(profile["embers"]) == held and Store.pending_starting_relic_gifts(profile).size() == 1, "Final claim acknowledgment preserves all earned rewards")
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKED_EVENTS))
	# The terminal profile write has different side effects from an intermediate
	# run save: exercise both a live UI retry and a boot from its fallback.
	for reload_fallback: bool in [false, true]:
		reward_state = _claim_fixture("noctyrax", 949301 if reload_fallback else 959401)
		key = "reward_claimed|%s" % reward_state["pending_reward"]["milestone_id"]
		held = engine.held_embers(reward_state)
		expect(Store.save_data(Store.set_embers(reward_state["progression"], 0)) and Store.save_run_state(reward_state), "Terminal profile-failure fixture saves its starting state")
		DirAccess.make_dir_absolute(blocked_profile)
		host = _claim_host(reward_state)
		expect(not bool(host.call("_commit_dragon_reward_continue")) and _claim_count(key) == 0, "Failed terminal profile save emits no claim")
		var fallback: Dictionary = Store.load_saved_run()
		expect(fallback["mode"] == "victory" and Store.progression_analytics_outbox(fallback["progression"]).size() == 1, "Failed terminal profile write retains a resumable terminal receipt")
		if reload_fallback:
			host.free()
			host = _claim_host(fallback)
			host.set("_progression", Store.load_data())
			var blocked_retry: Dictionary = host.call("_persist_run_state_snapshot", fallback, false, "terminal_claim_still_blocked")
			expect(not bool(blocked_retry["saved"]) and Store.has_saved_run() and _claim_count(key) == 0, "Blocked recovery keeps its fallback without a premature claim")
		else:
			host.call("_sync_progression_from_run")
		DirAccess.remove_absolute(blocked_profile)
		if reload_fallback:
			var recovered: Dictionary = host.call("_persist_run_state_snapshot", fallback, false, "terminal_claim_recovered")
			expect(bool(recovered["saved"]), "Reloaded terminal fallback commits after storage recovers")
			host.set("_run_state", recovered["state"])
			host.call("_sync_progression_from_run")
			expect(bool(host.call("_reconcile_progression_analytics_outbox")), "Recovered terminal profile flushes its claim")
		else:
			expect(bool(host.call("_commit_dragon_reward_continue")), "Same-host terminal retry commits after a failed-action UI sync")
		profile = Store.load_data()
		expect(_claim_count(key) == 1 and not Store.has_saved_run(), "Either terminal retry path finishes with exactly one claim")
		expect(int(profile["embers"]) == held and Store.pending_starting_relic_gifts(profile).size() == 1, "Terminal retries preserve the exact bank and single gift")
		var result_count: int = 0
		for result: Dictionary in profile.get("completed_run_results", []):
			if result.get("result_id", "") == Run.run_result_id(reward_state): result_count += 1
		expect(result_count == 1, "Terminal retries record the run result once")
		host.free()

func _test_wallet_recovery() -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	profile["embers"] = 100
	profile["moltshards"] = 3
	profile[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	profile["run_counter"] = 5
	var original: Dictionary = engine.create_new_run(902, profile)
	var id: String = Run.run_result_id(original)
	var exchanged: Dictionary = Store.transact_run_wallet(profile, id, 1, "moltshard_exchange", "emaciated_man")
	expect(int(exchanged["embers"]) == 350 and int(exchanged["moltshards"]) == 2, "A trade spends one shard for 250 Embers")
	expect(Store.transact_run_wallet(exchanged, id, 1, "moltshard_exchange", "emaciated_man") == exchanged, "The same transaction cannot spend twice")
	var recovered: Dictionary = engine.reconcile_progression_revision(original, exchanged)
	expect(engine.held_embers(recovered) == 350 and int(recovered["wallet_transaction_sequence"]) == 1, "Profile-first exchange recovery restores the lost run credit")
	var purchased: Dictionary = Store.transact_run_wallet(exchanged, id, 2, "level_up", "emaciated_man")
	var both_recovered: Dictionary = engine.reconcile_progression_revision(original, purchased)
	expect(int(purchased["level"]) == 2 and engine.held_embers(both_recovered) == 170, "Exchange then purchase recovers the latest debit, not the old credit")
	both_recovered = engine.add_held_embers(both_recovered, 50)
	var learned: Dictionary = Store.learn_skill(purchased, "quick_wits")
	both_recovered = engine.reconcile_progression_revision(both_recovered, learned)
	expect(engine.held_embers(both_recovered) == 220, "Later profile revisions cannot replay an acknowledged wallet receipt over ordinary earnings")
	var camp: Dictionary = original.duplicate(true)
	camp["mode"] = "campfire"
	var funded: Dictionary = Store.set_embers(profile, 300)
	var camp_purchase: Dictionary = Store.transact_run_wallet(funded, id, 1, "level_up", "campfire")
	var camp_recovered: Dictionary = engine.reconcile_progression_revision(camp, camp_purchase)
	expect(camp_recovered["mode"] == "room" and engine.held_embers(camp_recovered) == 120, "Interrupted campfire purchase consumes its choice without healing")
	expect(recovered["mode"] == "room" and engine.can_use_emaciated_services(recovered), "Entrance purchases keep the service available")
	var empty: Dictionary = Store.default_data()
	expect(Store.transact_run_wallet(empty, id, 1, "moltshard_exchange", "emaciated_man") == empty, "An unfunded trade changes nothing")

func _test_wallet_event_context() -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	profile["level"] = 3
	profile["embers"] = 1000
	profile["moltshards"] = 2
	var original: Dictionary = engine.create_new_run(906, profile)
	var id: String = Run.run_result_id(original)
	var scene := RunScene.new()
	scene.set("_run_state", original)
	scene.set("_progression", profile)
	# A finished combat may still be retained in the scene at the campfire.
	scene.set("_combat_state", {"defiance_capacity":0, "defiance_remaining":0})
	var purchased: Dictionary = Store.transact_run_wallet(profile, id, 1, "level_up", "emaciated_man")
	purchased = scene.call("_queue_wallet_transaction_analytics", profile, purchased)
	var entry: Dictionary = Store.progression_analytics_outbox(purchased)[0]
	var context: Dictionary = entry["context"]
	expect(int(context["progression_level"]) == 4 and int(context["defiance_capacity"]) == 1 and int(context["defiance_remaining"]) == 1, "Level-up outbox context records resulting level and newly earned Defiance")
	expect(int(entry["payload"]["level_after"]) == int(context["progression_level"]), "Wallet payload and top-level context agree")
	var exchanged: Dictionary = Store.transact_run_wallet(profile, id, 1, "moltshard_exchange", "emaciated_man")
	exchanged = scene.call("_queue_wallet_transaction_analytics", profile, exchanged)
	entry = Store.progression_analytics_outbox(exchanged)[0]
	expect(int(entry["context"]["moltshards"]) == 1 and int(entry["payload"]["held_embers_after"]) == 1250, "Exchange outbox records the post-spend shard count and credited Embers")
	expect(scene.get("_run_state") == original, "Staging transaction analytics does not mutate the live run before persistence")
	scene.free()

func _test_gift_write_failure() -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.award_starting_relic_gift(Store.default_data(), "gift-failure-witness", "eclipse_mantle")
	profile = Store.prepare_for_new_run(profile)
	var receiving: Dictionary = engine.create_new_run(202609, profile)
	expect(Store.save_data(profile) and Store.save_run_state(receiving), "Gift failure fixture saves its original profile and receiving run")
	var blocked_path: String = ProjectSettings.globalize_path("user://dragon_rewards_profile.json.tmp")
	DirAccess.make_dir_absolute(blocked_path)
	var scene := RunScene.new()
	scene.set("_progression", profile)
	expect(not bool(scene.call("_acknowledge_saved_starting_relic_gift", receiving)), "A blocked profile temp path simulates failed gift acknowledgment")
	var active: Dictionary = scene.get("_progression")
	expect(Store.pending_starting_relic_gifts(active).is_empty() and Store.pending_starting_relic_gifts(Store.load_data()).size() == 1, "Failed profile acknowledgment still retains consumption in the active progression")
	var continued: Dictionary = engine.reconcile_progression_revision(receiving, active)
	expect(Store.save_run_state(continued), "The active run carries gift consumption through a later checkpoint")
	DirAccess.remove_absolute(blocked_path)
	continued["mode"] = "victory"
	continued["victory"] = true
	var finished: Dictionary = scene.call("_finalize_terminal_committed_state", continued)
	expect(Store.pending_starting_relic_gifts(finished["progression"]).is_empty(), "Terminal persistence cannot resurrect a gift after its first acknowledgment failed")
	expect(Store.save_data(finished["progression"]), "Recovered terminal profile saves")
	Store.clear_saved_run()
	var another: Dictionary = engine.create_new_run(202610, Store.prepare_for_new_run(Store.load_data()))
	expect(not (another["relics"] as Array).has("eclipse_mantle"), "Failed acknowledgement followed by completion cannot grant the gift twice")
	scene.free()

func _relic_fixture(combat: Combat, ids: Array) -> Dictionary:
	var state: Dictionary = Fixtures.fixture(combat, ids)
	state["deck"]["hand"] = []
	state["deck"]["draw"] = ["brace", "brace", "brace", "brace", "brace", "brace", "brace", "brace"]
	return state

func _test_relics() -> void:
	var combat := Combat.new()
	var state: Dictionary = _relic_fixture(combat, ["crowncoal_heart"])
	state = combat.apply_player_action(state, {"type":"ranged", "damage":2, "range":5}, Vector2i(4,3))
	expect(Surface.has_surface(state, Vector2i(4,3), "fire"), "Crowncoal's first real hit paints Fire")
	Surface.remove(state, Vector2i(4,3), "fire", "test")
	state = combat.apply_player_action(state, {"type":"ranged", "damage":2, "range":5}, Vector2i(4,3))
	expect(not Surface.has_surface(state, Vector2i(4,3), "fire"), "Crowncoal direct fire is once per turn")
	state["player"]["pos"] = Vector2i(3,3)
	Surface.place(state, Vector2i(3,3), "fire")
	Surface.place(state, Vector2i(4,3), "fire")
	state = combat.apply_player_action(state, {"type":"detonate", "damage":10, "range":5, "pattern":[[0,0],[1,0]], "rotate":false}, Vector2i(3,3))
	expect(int(state["player"]["hp"]) == 990 and int(state["player"]["stoneskin"]) == 6, "Crowncoal grants Stoneskin after shared blast damage, never shields its own detonation")
	Surface.place(state, Vector2i(3,3), "fire")
	Surface.place(state, Vector2i(4,3), "fire")
	state = combat.apply_player_action(state, {"type":"detonate", "damage":1, "range":5, "pattern":[[0,0],[1,0]], "rotate":false}, Vector2i(3,3))
	expect(int(state["player"]["stoneskin"]) == 5, "A second qualifying blast does not grant another six Stoneskin")
	state = _relic_fixture(combat, ["worldheart"])
	state["player"]["pos"] = Vector2i(3,3)
	state["player"]["block"] = 10
	state = combat._trigger_activation_end_relics(state)
	expect(int(state["player"]["block"]) == 8 and int(state["player"]["stoneskin"]) == 2 and int(state["enemies"][0]["hp"]) == 999, "Worldheart converts at most two Block and deals half to adjacent enemies")
	state = combat.apply_player_action(state, {"type":"stoneskin", "amount":20})
	expect(int(state["enemies"][0]["hp"]) == 995, "Worldheart thorns cap at four damage per Stoneskin gain")
	# Pinion distance, collision and resumed-turn limits are covered by RelicU3Suite.
	state = _relic_fixture(combat, ["crowncoal_heart", "winters_hour"])
	state = combat.apply_player_action(state, {"type":"ranged", "damage":1, "range":5, "element":"ice", "surface":"ice"}, Vector2i(4,3))
	expect(Surface.has_surface(state, Vector2i(4,3), "ice"), "Crowncoal preserves the attack's own Ice setup")
	state = combat.apply_player_action(state, {"type":"ranged", "damage":1, "range":5, "element":"ice"}, Vector2i(4,3))
	expect(Surface.has_surface(state, Vector2i(4,3), "ice"), "Crowncoal also preserves existing Ice under a later attack")
	state["enemies"].append(Base.enemy(2, Vector2i(5,3)))
	state = combat.apply_player_action(state, {"type":"ranged", "damage":1, "range":5}, Vector2i(5,3))
	expect(Surface.has_surface(state, Vector2i(5,3), "fire"), "Skipped elemental ground leaves Crowncoal available for another hit")
	state = _relic_fixture(combat, ["winters_hour"])
	state["deck"]["hand"] = ["rime_shard", "pale_spark"]
	state = combat.finish_player_card(state,0)
	expect(int(combat.card_def("pale_spark",state)["time"]) == 1, "Winter's Hourglass makes the next non-Ice card cheaper")
	state = combat.finish_player_card(state,0)
	expect(int(state["relic_time_reserve"]["winters_hour"]) == 1, "Winter's Hourglass spends only the needed Time")
	state = _relic_fixture(combat, ["stormroad_coil"])
	state["enemies"][0]["pos"] = Vector2i(6,3)
	Surface.place(state,Vector2i(4,3),"electrified")
	state = combat.apply_player_action(state,{"type":"ranged","range":2,"damage":3},Vector2i(6,3))
	expect(int(state["enemies"][0]["hp"]) == 997 and Surface.has_surface(state,Vector2i(4,3),"electrified"), "Stormroad extends a ranged attack once through reusable Electrified ground")
	state = _relic_fixture(combat, ["eclipse_mantle"])
	state = combat.apply_player_action(state, {"type":"blink", "range":4}, Vector2i(3,4))
	expect((state["illusions"] as Array).size() == 1 and int(state["illusions"][0]["hp"]) == 2 and state["illusions"][0]["pos"] == Vector2i(2,3), "Eclipse Mantle leaves a two-health decoy at the Blink origin")
	expect(combat._illusion_light_radius(state) == 2, "Eclipse Mantle's illusion supplies Light radius two")

func _test_worldheart_secondary_damage() -> void:
	var combat := Combat.new()
	var state: Dictionary = _relic_fixture(combat, ["worldheart", "frost_prism"])
	state["player"]["pos"] = Vector2i(3,3)
	state["enemies"][0]["hp"] = 5
	state["enemies"][0]["freeze"] = 1
	state = combat.apply_player_action(state, {"type":"stoneskin", "amount":20, "_card_id":"stone_plate"})
	expect(int(state["enemies"][0]["hp"]) == 1, "Worldheart's capped four-damage pulse does not multiply against Frozen")
	state = combat.apply_player_action(state, {"type":"stoneskin", "amount":4, "_card_id":"stone_plate"})
	_expect_worldheart_death(state)
	expect(Surface.tiles(state, "rubble").is_empty(), "A secondary Worldheart kill cannot trigger a direct Frozen-kill trophy")
	state = _relic_fixture(combat, ["worldheart"])
	state["player"]["pos"] = Vector2i(3,3)
	state["player"]["block"] = 6
	state["enemies"][0]["hp"] = 1
	var previous_context := {"actor_kind":"player", "source_kind":"direct_attack", "player_card":true, "card_id":"needle_thrust"}
	state["damage_context"] = previous_context.duplicate(true)
	state = combat._trigger_activation_end_relics(state)
	_expect_worldheart_death(state)
	expect(state["damage_context"] == previous_context, "Worldheart restores the enclosing damage context after a turn-end pulse")

func _expect_worldheart_death(state: Dictionary) -> void:
	var death: Dictionary = {}
	for event: Dictionary in state.get("surface_events", []):
		if str(event.get("kind", "")) == "actor_death": death = event
	expect(int(state["enemies"][0]["hp"]) == 0 and int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "Worldheart kills without granting a direct-card death play")
	expect(str(death.get("source_kind", "")) == "relic" and not bool(death.get("player_card", true)) and str((death.get("source", {}) as Dictionary).get("relic_id", "")) == "worldheart", "Worldheart death events retain the exact relic source")

func _test_dialogue() -> void:
	var dialogue := Dialogue.new()
	var profile: Dictionary = Store.default_data()
	var offer: Dictionary = dialogue.emaciated_service_dialogue(profile)
	var options: Array = offer["lines"][0]["options"]
	expect(bool(options[0]["disabled"]) and bool(options[1]["disabled"]) and not bool(options[2].get("disabled", false)), "Empty-wallet entrance offers clearly disable unavailable purchases and keep Leave usable")
	profile["moltshards"] = 1
	profile["embers"] = 180
	offer = dialogue.emaciated_service_dialogue(profile)
	expect(not bool(offer["lines"][0]["options"][0]["disabled"]) and not bool(offer["lines"][0]["options"][1]["disabled"]), "Funded entrance trade and level are enabled")
