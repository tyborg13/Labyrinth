extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const U4 = preload("res://tests/suites/relic_u4_suite.gd")
const RelicRules = preload("res://scripts/tempo_relic_rules.gd")
const TurnAnalytics = preload("res://scripts/player_turn_analytics.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const ActivationSelectionSuite = preload("res://tests/suites/turn_clock_activation_selection_suite.gd")

static func run(expect: Callable) -> void:
	U4.install_fixtures()
	for time: int in [2, 4, 5, 6]:
		var card: Dictionary = GameData.card_def("u4_guard").duplicate(true)
		card["time"] = time
		GameData.cards()["wait_guard_%d" % time] = card
	var engine := CombatEngine.new()
	_test_payments(engine, expect)
	_test_freeze_and_saves(engine, expect)
	_test_borrowed_and_sundial(engine, expect)
	_test_projections(engine, expect)
	_test_late_agreement(engine, expect)
	ActivationSelectionSuite.run(engine, U4.state(engine), expect)
	_test_analytics(engine, expect)
	for id: String in U4.FIXTURES:
		GameData.cards().erase(id)
	for time: int in [2, 4, 5, 6]:
		GameData.cards().erase("wait_guard_%d" % time)

static func _scheduled_time(state: Dictionary) -> int:
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "player":
			return int(entry["time"])
	return -1

static func _expect_time(engine: CombatEngine, expect: Callable, state: Dictionary, time: int, label: String) -> void:
	expect.call(U4.hero_projection(engine, state) == time, "%s: exact projected Time %d" % [label, time])
	expect.call(_scheduled_time(engine.finish_player_activation(state)) == time, "%s: exact scheduled Time %d" % [label, time])

static func _test_payments(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = U4.state(engine)
	_expect_time(engine, expect, state, 19, "Pass")
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 18, "One Time-4 card")
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 17, "Two Time-4 cards remain unchanged")
	expect.call(_scheduled_time(engine.finish_player_activation(state)) == engine.player_base_initiative(state) + int(state["player_turn_time_spent"]), "A full ordinary turn preserves the former base-plus-card-Time rule")
	state = U4.play(engine, U4.state(engine), "u4_flurry")
	expect.call(state["cards_played_this_turn"] == 2 and engine.pending_wait_time(state) == 0, "Flurry spends all snapped slots and never waits")
	_expect_time(engine, expect, state, 13, "Flurry pays printed Time once")
	state = U4.state(engine)
	state["enemies"][0]["hp"] = 3
	state = U4.play(engine, state, "u4_strike", U4.TARGET)
	expect.call(state["death_bonus_card_plays_this_turn"] == 1, "Kill fixture earns a real refunded play")
	_expect_time(engine, expect, state, 18, "Kill refund left unused adds no extra Wait")
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 17, "Kill refund plus ordinary play clears Wait")
	state = U4.state(engine, ["whirling_sash"])
	state = U4.play(engine, U4.play(engine, state, "wait_guard_4"), "wait_guard_4")
	expect.call(engine.cards_remaining_this_turn(state) == 1, "Sash's third play is still available")
	_expect_time(engine, expect, state, 17, "Unused Sash third play never waits")
	state = U4.state(engine)
	state["card_play_bonus_this_turn"] = 1
	state = U4.play(engine, U4.play(engine, state, "wait_guard_4"), "wait_guard_4")
	_expect_time(engine, expect, state, 17, "Unused card-granted play never waits")
	state = U4.state(engine)
	state["skill_ids"] = ["measured_breath"]
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 18, "Measured Breath still pays Wait")
	var ended: Dictionary = engine.finish_player_activation(state)
	expect.call(ended["banked_plays"] == 1, "Measured Breath banks the unused play")
	var banked: Dictionary = engine.prepare_next_player_turn(ended)
	expect.call(engine.cards_remaining_this_turn(banked) == 3 and engine.pending_wait_time(banked) == 10, "Banked play adds no Wait next activation")
	banked = U4.play(engine, U4.play(engine, banked, "wait_guard_4"), "wait_guard_4")
	_expect_time(engine, expect, banked, 17, "Two plays clear Wait even with a banked bonus")
	state = U4.play(engine, U4.state(engine, ["quick_draw_bandolier"]), "u4_item")
	expect.call(state["cards_played_this_turn"] == 0, "Bandolier item spends no play")
	_expect_time(engine, expect, state, 24, "Bandolier pays four item Time plus one surcharge and both Waits")
	state = U4.play(engine, U4.state(engine, ["liturgy_of_ash"]), "u4_rite")
	expect.call(state["cards_played_this_turn"] == 0, "Free Rite spends no play")
	_expect_time(engine, expect, state, 23, "Free Rite pays Time and both Waits")
	state["current_actor"] = {"kind": "enemy"}
	expect.call(engine.base_plays_waited(state) == 0 and engine.pending_wait_time(state) == 0, "Wait helpers return zero outside the hero activation")

static func _test_freeze_and_saves(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = U4.state(engine)
	state["player"]["freeze"] = 1
	state = engine.prepare_next_player_turn(state)
	expect.call(state["plays_forfeited_this_turn"] == 2 and engine.cards_remaining_this_turn(state) == 0, "Start Freeze forfeits both plays")
	_expect_time(engine, expect, U4.resume(state), 19, "Frozen activation survives save/resume and waits twice")
	state = engine.prepare_next_player_turn(state)
	expect.call(state["plays_forfeited_this_turn"] == 0, "The next activation resets forfeits")
	state = U4.state(engine)
	state["deck"]["hand"] = ["wait_guard_4"]
	state = engine.prepare_player_card(state, 0)
	state = engine.apply_player_action(state, engine.card_play_actions("wait_guard_4", state)[0])
	state["player_turn_restrictions"]["frozen"] = true
	state = engine.finish_player_card(state, 0)
	expect.call(state["cards_played_this_turn"] == 2 and state["plays_forfeited_this_turn"] == 1, "Mid-card Freeze records only the remaining forfeit")
	engine._forfeit_remaining_card_plays(state)
	expect.call(state["plays_forfeited_this_turn"] == 1, "Repeated Freeze accounting cannot double count forfeits")
	_expect_time(engine, expect, U4.resume(state), 18, "Mid-turn Freeze after one Time-4 card")
	var legacy: Dictionary = U4.state(engine)
	legacy.erase("plays_forfeited_this_turn")
	legacy = U4.resume(legacy)
	_expect_time(engine, expect, legacy, 19, "Old save without forfeit field loads with zero default")
	legacy["cards_per_turn"] = 1
	_expect_time(engine, expect, legacy, 14, "Reduced base capacity waits only one play")

static func _test_borrowed_and_sundial(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = U4.play(engine, U4.state(engine, ["borrowed_hourglass"]), "wait_guard_4")
	_expect_time(engine, expect, state, 0, "Borrowed Hourglass keeps its immediate shortcut")
	var ended: Dictionary = U4.resume(engine.finish_player_activation(state))
	expect.call(ended[RelicRules.DEBT_KEY] == 9, "Borrowed debt includes four card Time and five Wait")
	var immediate: Dictionary = _ghost(engine, state)
	expect.call(immediate.get("projection_kind", "") == "end_now" and bool(immediate.get("projected_extra_turn", false)) and immediate.get("projected_carried_time", -1) == ended[RelicRules.DEBT_KEY], "Hourglass projection tags the immediate turn with exactly the scheduled carried Time")
	var projected_extra: Dictionary = engine._projected_next_entry_after_entry(ended, ended["turn_queue"].back())
	# The queue is sorted during presentation; find its scheduled hero explicitly.
	for entry: Dictionary in ended["turn_queue"]:
		if str(entry.get("kind", "")) == "player":
			projected_extra = engine._projected_next_entry_after_entry(ended, entry)
	expect.call(projected_extra.get("time", -1) == 28 and projected_extra.get("projected_wait_time", -1) == 10, "Scheduled extra-turn follow-up includes carried debt and refreshed Wait")
	expect.call(projected_extra.get("projection_kind", "") == "follow_up" and not bool(projected_extra.get("projected_extra_turn", false)), "Upcoming-activation projection is a follow-up, not an immediate Hourglass turn")
	var extra: Dictionary = engine.advance_one_activation_with_steps(ended)["state"]
	_expect_time(engine, expect, extra, 28, "Extra-turn pass pays carried debt and new Wait")
	extra = U4.play(engine, U4.play(engine, extra, "wait_guard_4"), "wait_guard_4")
	_expect_time(engine, expect, extra, 26, "Extra full turn pays carried debt once")
	expect.call(not engine.finish_player_activation(extra).has(RelicRules.DEBT_KEY), "Scheduling consumes carried debt")
	state = U4.state(engine, ["pocket_sundial"])
	_expect_time(engine, expect, state, 19, "Sundial pass earns no reduction")
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 18, "Sundial partial turn earns no reduction")
	state = U4.play(engine, state, "wait_guard_4")
	_expect_time(engine, expect, state, 15, "Sundial full turn earns exactly two Time")
	state = U4.state(engine, ["borrowed_hourglass", "pocket_sundial", "whirling_sash"])
	state = U4.play(engine, U4.play(engine, state, "wait_guard_4"), "wait_guard_4")
	ended = engine.finish_player_activation(state)
	expect.call(_scheduled_time(ended) == 0 and ended[RelicRules.DEBT_KEY] == 6, "Borrowed full turn with unused bonus carries eight card Time minus Sundial two")

static func _ghost(engine: CombatEngine, state: Dictionary) -> Dictionary:
	for entry: Dictionary in engine.current_turn_order(state, 20):
		if str(entry.get("kind", "")) == "player" and not bool(entry.get("active", false)):
			return entry
	return {}

static func _test_projections(engine: CombatEngine, expect: Callable) -> void:
	for played: int in [0, 1]:
		var state: Dictionary = U4.state(engine)
		if played == 1:
			state = U4.play(engine, state, "wait_guard_4")
		var idle: Dictionary = _ghost(engine, state)
		expect.call(idle.get("projection_kind", "") == "end_now" and not bool(idle.get("projected_extra_turn", false)), "Ordinary current-activation hero projection is tagged end_now")
		expect.call(idle.get("projected_wait_time", -1) == 10 - played * 5 and not idle.has("projected_time_delta"), "Idle ghost exposes end-now Wait without a card delta")
		for time: int in [2, 5, 6]:
			var preview: Dictionary = state.duplicate(true)
			preview["turn_order_preview_time_delta"] = time
			preview["turn_order_preview_plays_spent"] = 1
			preview["turn_order_preview_card_name"] = "Time %d" % time
			var ghost: Dictionary = _ghost(engine, preview)
			expect.call(ghost.get("projected_time_delta", 99) == time - 5, "Time-%d preview with %d plays made has delta %d" % [time, played, time - 5])
			expect.call(ghost.get("projected_time_cost", -1) == time and ghost.get("projected_wait_time", -1) == 5 - played * 5, "Card preview retains paid Time and exposes the remaining Wait")
			_expect_time(engine, expect, U4.play(engine, state, "wait_guard_%d" % time), int(ghost.get("time", -1)), "Preview equals commit")

static func _test_late_agreement(engine: CombatEngine, expect: Callable) -> void:
	for partner: String in ["", "pocket_sundial", "borrowed_hourglass"]:
		for played: int in [0, 1]:
			for offset: int in [-1, 0, 1]:
				var relics: Array = ["toll_late_bell"]
				if not partner.is_empty():
					relics.append(partner)
				var state: Dictionary = U4.state(engine, relics)
				if played == 1:
					state = U4.play(engine, state, "wait_guard_4")
				var hero_time: int = 18 if played == 0 else 17
				if partner == "pocket_sundial" and played == 1:
					hero_time -= 2
				state["turn_queue"][0]["time"] = hero_time + offset
				var preview: Dictionary = state.duplicate(true)
				preview["turn_order_preview_time_delta"] = 4
				preview["turn_order_preview_plays_spent"] = 1
				preview["turn_order_preview_card_name"] = "Strike"
				var marked: bool = false
				for entry: Dictionary in engine.current_turn_order(preview, 20):
					if int(entry.get("enemy_id", -1)) == 1 and not bool(entry.get("projected", false)):
						marked = entry.has("late_relic_id")
				var actions: Array = engine.card_play_actions("u4_strike", state)
				expect.call(actions[0]["_tempo_card_time"] == 4 and actions[0]["_tempo_plays_spent"] == 1, "Late action stamps pending payment before finish")
				var resolved: Dictionary = U4.play(engine, state, "u4_strike", U4.TARGET)
				var damage: int = 40 - int(resolved["enemies"][0]["hp"])
				expect.call(marked == (offset > 0) and damage == (6 if marked else 3), "Late preview and bonus agree for %s, %d prior plays, offset %d" % [partner, played, offset])
				if partner != "borrowed_hourglass":
					expect.call(_ghost(engine, preview)["time"] == hero_time and U4.hero_projection(engine, resolved) == hero_time, "Late threshold equals pending-card hero rail Time without double payment")

static func _test_analytics(engine: CombatEngine, expect: Callable) -> void:
	var old_dir: String = AnalyticsStore.storage_dir()
	var old_profile: String = ProgressionStore._storage_path
	var old_run: String = ProgressionStore._run_storage_path
	AnalyticsStore.set_storage_dir("user://turn_clock_wait_analytics")
	AnalyticsStore.clear_storage()
	ProgressionStore.set_storage_path("user://turn_clock_wait_profile.json")
	ProgressionStore.set_run_storage_path("user://turn_clock_wait_run.save")
	var progression: Dictionary = ProgressionStore.default_data()
	expect.call(ProgressionStore.save_data(progression), "Activation analytics fixture persists its profile")
	var run: Dictionary = RunEngine.new().create_new_run(4721, progression)
	run["mode"] = "combat"
	run["analytics"] = {"run_id": "wait_run"}
	var state: Dictionary = U4.state(engine)
	state["analytics"] = {"combat_id": "wait_combat"}
	run["combat_state"] = state
	var view := RunScene.new()
	view.set("_progression", progression)
	view.set("_run_state", run)
	view.set("_combat_state", state)
	engine.finish_player_activation(state)
	view.call("_pass_preview_summary")
	expect.call(AnalyticsStore.load_all_events().is_empty() and ProgressionStore.progression_analytics_outbox(view.get("_progression")).is_empty(), "Engine and Pass previews never stage or append activation-end events")
	for full: bool in [false, true]:
		if full:
			state["turn"] = int(state["turn"]) + 1
			state = U4.play(engine, U4.play(engine, state, "wait_guard_4"), "wait_guard_4")
		var scheduled: Dictionary = engine.finish_player_activation(state)
		var reason: String = "auto" if full else "pass"
		var staged: Dictionary = view.call("_stage_player_turn_ended_analytics", run, state, scheduled, reason)
		staged = view.call("_stage_player_turn_ended_analytics", staged, state, scheduled, reason)
		expect.call(ProgressionStore.progression_analytics_outbox(staged["progression"]).size() == 1, "Restaging the same activation leaves one durable outbox entry")
		var checkpoint: Dictionary = view.call("_run_state_for_combat_checkpoint", staged, scheduled)
		view.set("_run_state", checkpoint)
		view.call("_hold_committed_run_state", checkpoint, "wait_test_outbox")
		var saved: Dictionary = ProgressionStore.load_saved_run()
		expect.call(ProgressionStore.progression_analytics_outbox(saved["progression"]).size() == 1, "Activation checkpoint persists the outbox before append")
		expect.call(_turn_events().size() == (1 if full else 0), "Checkpoint staging alone never appends activation-end events")
		expect.call(bool(view.call("_reconcile_progression_analytics_outbox")), "Existing durable outbox appends and acknowledges activation end")
		# Replay the durable pre-ack checkpoint after append, as a crash would.
		view.set("_progression", saved["progression"])
		expect.call(bool(view.call("_reconcile_progression_analytics_outbox")), "Append-before-ack replay succeeds")
		var events: Array[Dictionary] = _turn_events()
		expect.call(events.size() == (2 if full else 1), "Exactly one player_turn_ended JSONL event per activation")
		var payload: Dictionary = events.back()["payload"]
		expect.call(events.back()["event_type"] == "player_turn_ended" and payload["end_reason"] == reason, "Activation event retains the committed end reason")
		expect.call(payload["plays_made"] == (2 if full else 0) and payload["base_plays_waited"] == (0 if full else 2) and payload["unused_bonus_plays"] == 0, "Pass/full activation event reports exact slot accounting")
		expect.call(payload["card_time"] == (8 if full else 0) and payload["wait_time"] == (0 if full else 10) and payload["next_turn_eta"] == (17 if full else 19), "Pass/full activation event reports exact Time accounting")
		expect.call(payload["sundial_reduction"] == 0 and not payload["borrowed_extra_turn"] and payload["enemy_activations_before_next_turn"] == 2, "Pass/full activation event counts the post-schedule enemy rail entries")
		view.call("_sync_progression_analytics_outbox_to_run")
		view.call("_release_committed_run_state")
		expect.call(bool(view.call("_persist_committed_boundary", "wait_test_ack")), "Acknowledgment uses the existing run checkpoint path")
		expect.call(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_saved_run()["progression"]).is_empty(), "Run checkpoint persists the acknowledged empty outbox")
		run["progression"] = view.get("_progression")
	state["player_turn_restrictions"]["frozen"] = true
	expect.call(TurnAnalytics.payload(engine, state, engine.finish_player_activation(state), "auto")["end_reason"] == "frozen", "Freeze takes precedence over auto/pass end reasons")
	var frozen_bonus: Dictionary = U4.state(engine, ["whirling_sash"])
	frozen_bonus["player"]["freeze"] = 1
	frozen_bonus = engine.prepare_next_player_turn(frozen_bonus)
	var frozen_payload: Dictionary = TurnAnalytics.payload(engine, frozen_bonus, engine.finish_player_activation(frozen_bonus), "auto")
	expect.call(frozen_payload["plays_made"] == 0 and frozen_payload["base_plays_waited"] == 2 and frozen_payload["unused_bonus_plays"] == 1 and frozen_payload["wait_time"] == 10, "Frozen bonus forfeit is unused, but never adds Wait")
	view.free()
	ProgressionStore.clear_saved_run()
	AnalyticsStore.set_storage_dir(old_dir)
	ProgressionStore.set_storage_path(old_profile)
	ProgressionStore.set_run_storage_path(old_run)

static func _turn_events() -> Array[Dictionary]:
	var events: Array[Dictionary]
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) == "player_turn_ended":
			events.append(event)
	return events
