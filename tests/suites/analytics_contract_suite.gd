extends RefCounted
## Analytics-only witnesses: production resolution, no renderer or REPL.
const Store = preload("res://scripts/analytics_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Console = preload("res://tools/headless_playtest.gd")
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tick = preload("res://tests/suites/en01_enemies_suite.gd")
const Summons = preload("res://tests/suites/summon_card_play_suite.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const FIXTURE_SEED: int = 611
const FIXTURE_COMBAT_ID: String = "qa28_contract"

class TurnQueueHost:
	extends "res://scripts/run_scene.gd"
	var boundaries: Array[String]
	var fail_save: bool = false
	func _persist_committed_boundary(boundary: String = "") -> bool:
		boundaries.append(boundary)
		return not fail_save
	func _refresh_ui(_force: bool = false, _refresh_hand: bool = true, _refresh_map: bool = true) -> void:
		pass

class FailOnceStore:
	extends "res://scripts/analytics_store.gd"
	var fail_once: bool = true
	func write_events_durable(events: Array) -> bool:
		if fail_once:
			fail_once = false
			return false
		return super.write_events_durable(events)

class PartialAppendStore:
	extends "res://scripts/analytics_store.gd"
	var fail_once: bool = true
	func _append_records_at(path: String, records: Array) -> bool:
		if fail_once:
			fail_once = false
			super._append_records_at(path, records.slice(0, 1))
			return _append_failed(path)
		return super._append_records_at(path, records)

class DebugVictoryHost:
	extends "res://scripts/run_scene.gd"
	func _animate_relic_acquisition_flourish(_id: String, _rect: Rect2, _accent: Color, _dest: Control = null) -> void: pass
	func _animate_relic_acquired(_id: String) -> void: pass
	func _play_reward_collect_sfx() -> void: pass
	func _treasure_sequence_is_current(_epoch: int) -> bool: return true
	func _refresh_ui(_sliced: bool = false, _unlock: bool = false, _wave: bool = false) -> void: pass
	func _maybe_present_section_map(_fade: bool = true) -> void: pass

static func host(caller: String, state: Dictionary) -> Object:
	var node: Object = Scene.new() if caller == "UI" else Console.new()
	var run: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Progression.default_data())
	run["analytics"] = {"run_id": "qa28_run"}
	run["mode"] = "combat"
	run["combat_state"] = state.duplicate(true)
	node.set("_analytics_store", Store.new())
	node.set("_run_state", run)
	node.set("_combat_state", state.duplicate(true))
	node.set("_progression", run["progression"])
	return node

static func run(check: Callable, evidence: Dictionary) -> void:
	_context_and_snapshots(check, evidence)
	_phase_order(check, evidence)
	_burst(check, evidence)
	_summon_and_wait(check, evidence)
	_rule_beats(check, evidence)
	_wait_delivery_and_movement(check, evidence)
	_player_death(check, evidence)
	_mechanic_actions(check, evidence)
	_turn_end_queue(check, evidence)
	_final_dragon_end(check, evidence)
	_embrace_end(check, evidence)
	_failed_turn_order(check, evidence)
	_ordered_receipt_batches(check, evidence)
	_debug_victory(check, evidence)

static func _context_and_snapshots(check: Callable, evidence: Dictionary) -> void:
	var state: Dictionary = Tick.fixture(["crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	var ui: Object = host("UI", state)
	var console: Object = host("headless", state)
	var ui_context: Dictionary = ui._analytics_context_from_states(ui.get("_run_state"), state)
	var console_context: Dictionary = console._analytics_context(state)
	for field: String in ui_context:
		check.call(console_context.get(field) == ui_context[field], "headless context matches " + field)
	for boundary: String in ["started", "ended"]:
		Store.clear_storage()
		if boundary == "started": ui._analytics_log_run_started()
		else: ui._analytics_log_run_ended("defeat")
		var expected: Dictionary = Store.load_all_events()[0]["payload"]
		Store.clear_storage()
		if boundary == "started": console._log_run_started()
		else: console._log_run_ended("defeat")
		var actual: Dictionary = Store.load_all_events()[0]["payload"]
		evidence["headless_run_" + boundary] = actual
		for field: String in expected:
			check.call(actual.get(field) == expected[field], "headless run_%s.%s" % [boundary, field])
	var after: Dictionary = Combat.new().apply_player_action(state, {"type": "block", "amount": 3})
	var targets: Array[Vector2i]
	var expected_card: Dictionary = ui._analytics_card_play_payload("brace", state, after, [{"type": "block", "amount": 3}], targets)
	var actual_card: Dictionary = console._card_play_payload("brace", state, after, [{"type": "block", "amount": 3}], targets)
	for field: String in expected_card:
		if field in ["enemy_status_applied", "player_status_applied"]:
			for status: String in expected_card[field]: check.call(actual_card[field].get(status) == expected_card[field][status], "headless card status " + status)
		else: check.call(actual_card.get(field) == expected_card[field], "headless card_played." + field)
	evidence["headless_card"] = actual_card
	var chilled: Dictionary = state.duplicate(true)
	preload("res://scripts/board_surface_rules.gd").place(chilled, chilled["enemies"][0]["pos"], "ice")
	chilled = Combat.new()._surface_contact(chilled, "enemy", int(chilled["enemies"][0]["id"]), Vector2i(-1, -1), true)
	check.call(bool(chilled["enemies"][0].get("chilled", false)), "Ice contact oracle actually chills the enemy")
	var chill_payload: Dictionary = ui._analytics_card_play_payload("frostbite", state, chilled, [], targets)
	check.call(chill_payload["enemy_status_applied"].get("chilled") == 1, "UI card summary includes the documented Chilled delta")
	evidence["chilled_after"] = chill_payload["enemy_status_applied"]
	ui.free()
	console.free()

static func _phase_order(check: Callable, evidence: Dictionary) -> void:
	var state: Dictionary = Tick.fixture(["crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	# Losses and identity are fixed oracle values, independent of the adapter.
	var steps: Array = [
		{"kind": "move", "actor_key": "enemy_1", "intent_id": "test", "path": [Vector2i(2, 4), Vector2i(3, 4)]},
		{"kind": "status_damage", "actor_key": "enemy_1", "label": "Bleed", "amount": 2, "trigger": "action", "action_type": "melee"},
		{"kind": "melee", "actor_key": "enemy_1", "target_losses": [{"key": "player", "hp_loss": 3}]},
		{"kind": "status", "action_type": "gain_charge", "actor_key": "enemy_2", "amount": 1},
		{"kind": "status", "guardian_mechanic": true, "action_type": "guardian_light_restore", "actor_key": "enemy_3"},
	]
	var phase: Dictionary = {"state": state, "steps": steps}
	var expected_types: Array = ["enemy_action_resolved", "enemy_status_tick", "enemy_action_resolved", "enemy_action_resolved", "enemy_action_resolved"]
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var node: Object = host(caller, state)
		if caller == "UI": node._analytics_log_enemy_phase_events(phase)
		elif node.has_method("_log_enemy_phase_events"): node._log_enemy_phase_events(phase, state)
		else: node._log_enemy_status_ticks(phase, state)
		var records: Array = Store.load_all_events()
		evidence[caller + "_phase"] = records
		check.call(records.size() == expected_types.size(), caller + " phase emits five action/status records")
		for index: int in range(mini(records.size(), expected_types.size())):
			check.call(records[index]["event_type"] == expected_types[index], caller + " preserves resolver action/status order " + str(index))
		if records.size() == expected_types.size():
			check.call(records[1]["payload"].get("trigger") == "action" and records[1]["payload"].get("amount") == 2, caller + " owns Bleed timing and amount")
			check.call(records[2]["payload"]["target_losses"].size() == 1 and records[2]["payload"]["target_losses"][0]["key"] == "player" and int(records[2]["payload"]["target_losses"][0]["hp_loss"]) == 3, caller + " owns attack losses")
		node.free()

static func _burst(check: Callable, evidence: Dictionary) -> void:
	var engine := Combat.new()
	var state: Dictionary = Tick.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	for index: int in range(3):
		state["enemies"][index]["pos"] = Vector2i(3 + index, 3)
		if index > 0: state["enemies"][index]["hp"] = 4
	state["enemies"][3]["pos"] = Vector2i(5, 4)
	state["enemies"][3]["hp"] = 20
	state["player"]["block"] = 3
	state["damage_context"] = {"actor_kind": "player", "player_card": true}
	var after: Dictionary = engine._damage_enemy(state.duplicate(true), 0, 6)
	check.call(after["player"]["hp"] == 21 and after["death_bonus_card_plays_this_turn"] == 1, "Burst oracle retains actual damage and single card kill credit")
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var node: Object = host(caller, after)
		if caller == "UI":
			node._analytics_flush_surface_events(after)
			node._analytics_flush_surface_events(after)
		elif node.has_method("_flush_surface_analytics"):
			node._flush_surface_analytics(after)
			node._flush_surface_analytics(after)
		var records: Array = Store.load_all_events()
		evidence[caller + "_burst"] = records
		var deaths: Array = records.filter(func(event: Dictionary) -> bool: return event.get("payload", {}).get("kind") == "actor_death")
		check.call(deaths.size() == 3, caller + " Burst emits each FIFO death exactly once")
		if deaths.size() == 3:
			for index: int in range(3):
				check.call(int(deaths[index]["payload"]["id"]) == index + 1, caller + " Burst preserves FIFO source order")
				check.call(deaths[index]["payload"]["player_card"] == (index == 0), caller + " Burst attributes card versus cascade")
		var resumed: Object = host(caller, after)
		if caller == "UI": resumed._analytics_flush_surface_events(after)
		elif resumed.has_method("_flush_surface_analytics"): resumed._flush_surface_analytics(after)
		check.call(Store.load_all_events().size() == records.size(), caller + " surface retry/restart is idempotent")
		resumed.free()
		node.free()

static func _summon_and_wait(check: Callable, evidence: Dictionary) -> void:
	var engine := Combat.new()
	var before: Dictionary = Summons.fixture("zekarion")
	before["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	var phase: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)
	var grants: Array = (phase["steps"] as Array).filter(func(step: Dictionary) -> bool: return bool(step.get("granted_card_play", false)))
	check.call(grants.size() == 1, "scripted production summon grants exactly one play")
	var started: Dictionary = phase["state"].duplicate(true)
	phase["player_turn_before_state"] = started
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var node: Object = host(caller, started)
		if caller == "UI": node._analytics_log_enemy_phase_events(phase)
		elif node.has_method("_log_enemy_phase_events"): node._log_enemy_phase_events(phase, started)
		else: node._log_enemy_status_ticks(phase, started)
		var records: Array = Store.load_all_events()
		evidence[caller + "_summon"] = records
		var paid: Array = records.filter(func(event: Dictionary) -> bool: return bool(event.get("payload", {}).get("granted_card_play", false)))
		check.call(paid.size() == 1, caller + " authored summon records its granted play")
		check.call(not records.is_empty() and records.back()["event_type"] == "player_turn_started" and records.back()["payload"].get("summon_card_plays") == 1, caller + " summon start follows enemy actions with consumed bonus")
		node.free()
	var waiting: Dictionary = Tick.fixture(["crawler"])
	waiting["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	var scheduled: Dictionary = Commit.finish_player_activation(engine, waiting)
	var payload: Dictionary = preload("res://scripts/player_turn_analytics.gd").payload(engine, waiting, scheduled, "pass")
	evidence["wait"] = payload
	check.call(payload["end_reason"] == "pass" and payload["plays_made"] == 0 and payload["base_plays_waited"] == engine.base_plays_waited(waiting) and payload["wait_time"] == engine.pending_wait_time(waiting), "Wait reports unused base plays and actual paid Time")

static func _rule_beats(check: Callable, evidence: Dictionary) -> void:
	var engine := Combat.new()
	var guardian_fixture := preload("res://tests/suites/guardian_suite.gd").new()
	for kind: String in ["guardian", "dragon"]:
		var before: Dictionary = guardian_fixture.guardian_fixture("ashen_reaver") if kind == "guardian" else preload("res://tests/suites/dragon_element_rules_suite.gd").beat_fixture("vyraketh")
		before["analytics"] = {"combat_id": FIXTURE_COMBAT_ID + kind}
		var after: Dictionary = preload("res://scripts/battlefield_rules/dispatcher.gd").fire(engine, before.duplicate(true))
		for caller: String in ["UI", "headless"]:
			Store.clear_storage()
			var node: Object = host(caller, after)
			if caller == "UI": node._analytics_flush_surface_events(after)
			elif node.has_method("_flush_surface_analytics"): node._flush_surface_analytics(after)
			var records: Array = Store.load_all_events()
			evidence[caller + "_" + kind + "_rule"] = records
			var beats: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "battlefield_rule_fired")
			check.call(beats.size() == 1, caller + " " + kind + " beat emits once")
			if beats.size() == 1:
				check.call(beats[0]["payload"]["source_kind"] == "enemy" and beats[0]["payload"]["source_type"] == before["enemies"][0]["type"] and beats[0]["payload"]["beat_index"] == 1, caller + " rule actor and beat index")
			node.free()

static func _wait_delivery_and_movement(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var state: Dictionary = Tick.fixture(["crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	var console: Object = host("headless", state)
	console.set("_session_path", "user://qa28-wait.save")
	console._analytics_initialize_combat_tracker(state)
	console._resolve_enemy_round("pass")
	var records: Array = Store.load_all_events()
	evidence["headless_wait_delivery"] = records
	var ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "player_turn_ended")
	check.call(ends.size() == 1, "console Wait emits one activation end from the committed scheduler")
	if ends.size() == 1:
		check.call(ends[0]["payload"]["end_reason"] == "pass" and int(ends[0]["payload"]["plays_made"]) == 0, "console Wait payload describes the activation that ended")
		var enemy_actions: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] in ["enemy_action_resolved", "enemy_status_tick"])
		check.call(not enemy_actions.is_empty() and ends[0]["sequence"] < enemy_actions[0]["sequence"], "console persists/appends activation end before enemy actions")
		# Append-before-ack recovery: replay a durably staged copy of this event.
		var saved: Dictionary = console.get("_run_state").duplicate(true)
		saved["progression"] = Progression.queue_progression_analytics_event(saved["progression"], "player_turn_ended", ends[0]["idempotency_key"], {}, ends[0]["payload"])
		console.set("_run_state", saved)
		check.call(console._write_session_snapshot(), "console retry fixture saves pending outbox")
		check.call(console._load_session(), "console resumes the pending activation-end receipt")
		check.call(Store.load_all_events().size() == records.size(), "console resume never duplicates an appended activation end")
		check.call(Progression.progression_analytics_outbox(console.get("_run_state")["progression"]).is_empty(), "console acknowledges the durable receipt")
	console.free()
	# Refunded Light movement still travels. A zero-distance resolved interruption
	# is the separate negative witness; no gameplay numbers are changed.
	var after: Dictionary = state.duplicate(true)
	after["player"]["pos"] += Vector2i.RIGHT
	after["last_player_movement"] = {"resolved": true, "origin": state["player"]["pos"], "destination": after["player"]["pos"], "spent": 0, "light_refunds": 1}
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var node: Object = host(caller, state)
		if caller == "UI": node._analytics_log_player_moved(state, after)
		else: node._log_player_moved(state, after)
		var moved: Array = Store.load_all_events()
		check.call(moved.size() == 1 and moved[0]["event_type"] == "player_moved" and int(moved[0]["payload"]["spent"]) == 0 and int(moved[0]["payload"]["light_refunds"]) == 1, caller + " refunded movement is a move with its actual cost")
		after["player"]["pos"] = state["player"]["pos"]
		after["last_player_movement"]["destination"] = state["player"]["pos"]
		if caller == "UI": node._analytics_log_player_moved(state, after)
		else: node._log_player_moved(state, after)
		moved = Store.load_all_events()
		check.call(moved.size() == 2 and moved[1]["event_type"] == "player_movement_interrupted", caller + " zero-step interruption keeps its distinct event")
		evidence[caller + "_movement"] = moved
		after["player"]["pos"] += Vector2i.RIGHT
		after["last_player_movement"]["destination"] = after["player"]["pos"]
		node.free()

static func _mechanic_actions(check: Callable, evidence: Dictionary) -> void:
	var engine := Combat.new()
	var ui: Object = host("UI", {})
	var hoarder: Dictionary = Tick.fixture(["ember_hoarder"])
	var retreat: Dictionary = {"kind": "move", "actor_key": "enemy_1", "actor_name": "Ember Hoarder", "intent_id": "kindle", "from": Vector2i(5, 1), "to": Vector2i(4, 1)}
	var retreat_phase: Dictionary = {"state": hoarder, "steps": [retreat]}
	var retreat_before: Dictionary = retreat_phase.duplicate(true)
	var retreat_events: Array = ui._analytics_enemy_action_events(retreat_phase, {})
	check.call(retreat_events.size() == 1 and retreat_events[0]["payload"]["enemy_type"] == "ember_hoarder" and retreat_events[0]["payload"]["intent_id"] == "kindle", "preliminary Hoarder retreat retains actor identity and committed intent")
	check.call(retreat_phase == retreat_before, "identity fallback never mutates the resolved phase or RNG")
	evidence["hoarder_retreat_after"] = retreat_events
	var legacy: Object
	var baseline_path: String = OS.get_environment("QA28_BEFORE_ADAPTER")
	if not baseline_path.is_empty(): legacy = load(baseline_path).new()
	for type: String in ["burrow_grub", "ember_tick", "storm_capacitor", "hollow_mimic"]:
		var state: Dictionary = Tick.fixture([type])
		if type == "ember_tick": state["enemies"][0]["intent"] = preload("res://scripts/game_data.gd").enemy_def(type)["intents"][1].duplicate(true)
		if type == "hollow_mimic":
			for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def(type)["intents"]:
				if intent["id"] == "echo": state["enemies"][0]["intent"] = intent.duplicate(true)
		state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID + type}
		for activation: int in range(2 if type == "burrow_grub" else 1):
			var before: Dictionary = state.duplicate(true)
			var phase: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
			state = phase["state"]
			var action: String = "erupt" if activation == 1 else {"burrow_grub": "burrow", "ember_tick": "kindle", "storm_capacitor": "gain_charge", "hollow_mimic": "retaliate"}[type]
			var events: Array = ui._analytics_enemy_action_events(phase, {})
			var matching: Array = events.filter(func(event: Dictionary) -> bool: return event["payload"]["action_type"] == action)
			check.call(matching.size() == 1, action + " is one ordinary enemy action")
			var statuses: Array = ui._analytics_enemy_status_tick_events(phase, {})
			check.call(not statuses.any(func(event: Dictionary) -> bool: return event["payload"].get("action_type") == action), action + " is not a timed status tick")
			if matching.size() == 1:
				check.call(matching[0]["payload"]["actor_key"] == "enemy_1" and matching[0]["payload"]["enemy_type"] == type, action + " retains the actual actor")
				if action in ["kindle", "gain_charge"]:
					var field: String = "kindled_bonus" if action == "kindle" else "charge"
					check.call(int(matching[0]["payload"].get("amount", -1)) == int(state["enemies"][0].get(field, 0)) - int(before["enemies"][0].get(field, 0)), action + " reports its realized gain")
				if action == "erupt":
					var losses: Array = matching[0]["payload"]["target_losses"]
					check.call(losses.size() == 1 and int(losses[0]["hp_loss"]) == 6, "Erupt records its actual six Health hit")
				if action == "retaliate":
					check.call(int(matching[0]["payload"].get("amount", -1)) == int(state["enemies"][0].get("retaliate", {}).get("amount", 0)), "Echo records the actual gained Retaliate amount")
			evidence[action + "_after"] = events
			if legacy != null:
				evidence[action + "_before"] = {"actions": legacy._analytics_enemy_action_events(phase, {}), "statuses": legacy._analytics_enemy_status_tick_events(phase, {})}
	ui.free()
	legacy = null

static func _player_death(check: Callable, evidence: Dictionary) -> void:
	var engine := Combat.new()
	var state: Dictionary = Tick.fixture(["crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	state["player"]["hp"] = 1
	state["defiance_remaining"] = 0
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "source_kind": "direct_attack", "player_card": false}
	var after: Dictionary = engine._damage_player(state.duplicate(true), 3, false)
	check.call(engine.combat_outcome(after) == "defeat", "scripted player death reaches the production defeat boundary")
	for caller: String in ["UI", "headless"]:
		Store.clear_storage()
		var node: Object = host(caller, state)
		var previous: Dictionary = node.get("_run_state").duplicate(true)
		var ended: Dictionary = Run.new().finish_combat(previous, after)
		node.set("_run_state", ended)
		node.set("_combat_state", {})
		if caller == "UI": node._analytics_log_combat_transition(previous, "death", after)
		else: node._log_combat_transition(previous, "death", after)
		var records: Array = Store.load_all_events()
		evidence[caller + "_death"] = records
		var deaths: Array = records.filter(func(event: Dictionary) -> bool: return event.get("payload", {}).get("kind") == "actor_death" and event["payload"].get("actor_kind") == "player")
		var combat_ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "combat_ended")
		var run_ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "run_ended")
		check.call(deaths.size() == 1 and combat_ends.size() == 1 and run_ends.size() == 1, caller + " death emits actor, combat and run outcomes once")
		if deaths.size() == 1 and combat_ends.size() == 1 and run_ends.size() == 1:
			check.call(deaths[0]["sequence"] < combat_ends[0]["sequence"] and combat_ends[0]["sequence"] < run_ends[0]["sequence"], caller + " death precedes combat end and run end")
			check.call(combat_ends[0]["payload"]["outcome"] == "defeat" and int(combat_ends[0]["payload"]["remaining_player_hp"]) == 0, caller + " defeat reports actual outcome/health")
		node.free()

static func _turn_end_queue(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var engine := Combat.new()
	var state: Dictionary = Tick.fixture(["crawler"])
	state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID}
	var scheduled: Dictionary = Commit.finish_player_activation(engine, state)
	var node := TurnQueueHost.new()
	var run: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Progression.default_data())
	run["analytics"] = {"run_id": "qa28_run"}
	run["mode"] = "combat"
	node.set("_analytics_store", Store.new())
	node.set("_progression", run["progression"])
	run = node._stage_player_turn_ended_analytics(run, state, scheduled, "pass")
	node.set("_run_state", run)
	node.set("_combat_state", scheduled)
	check.call(node._has_pending_combat_skill_event_analytics(), "activation-end-only outbox wakes the ordinary combat analytics queue")
	node._request_skill_event_analytics()
	var records: Array = Store.load_all_events()
	var ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "player_turn_ended")
	check.call(ends.size() == 1 and node.boundaries.has("combat_skill_event_outbox") and node.boundaries.has("combat_skill_event_ack"), "ordinary combat queue saves, appends and acknowledges activation ends without a skill trigger")
	evidence["ui_wait_queue"] = records
	node.free()

static func _final_dragon_end(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var fixtures := preload("res://tests/dragon_rewards_test.gd").new()
	var reward: Dictionary = fixtures._claim_fixture("noctyrax", FIXTURE_SEED)
	check.call(Progression.save_data(reward["progression"]) and Progression.save_run_state(reward), "final dragon fixture saves its actual pending milestone")
	var node: Object = fixtures._claim_host(reward)
	var claim: Dictionary = reward["pending_reward"].duplicate(true)
	var staged: Dictionary = node._stage_dragon_reward_claim(Run.new().continue_dragon_reward(reward), claim)
	var retry: Array[Dictionary] = Progression.progression_analytics_outbox(staged["progression"])
	check.call(node._commit_dragon_reward_continue(), "final Continue commits without starting any reward animation")
	var records: Array = Store.load_all_events()
	var ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "run_ended")
	check.call(ends.size() == 1 and ends[0]["payload"]["outcome"] == "victory" and int(ends[0]["payload"]["held_embers"]) == 0, "final victory is durable before presentation, with the original settled-wallet payload")
	check.call(Store.new().write_events(retry), "terminal append-before-ack replay succeeds")
	check.call(Store.load_all_events().filter(func(event: Dictionary) -> bool: return event["event_type"] == "run_ended").size() == 1, "replaying the terminal receipt never duplicates victory")
	evidence["final_dragon_end_after"] = records
	node.free()
	fixtures.free()

static func _embrace_end(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Progression.default_data())
	state["analytics"] = {"run_id": "qa28_embrace"}
	state["mode"] = "campfire"
	state = engine.set_held_embers(state, 214)
	var node := TurnQueueHost.new()
	node.set("_analytics_store", Store.new())
	node.set("_run_state", state)
	node.set("_progression", state["progression"])
	node._on_campfire_embrace_pressed()
	var records: Array = Store.load_all_events()
	var ends: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] == "run_ended")
	check.call(ends.size() == 1 and ends[0]["payload"]["outcome"] == "embrace" and int(ends[0]["payload"]["held_embers"]) == 214, "saved Embrace emits its authored outcome and actual held Embers")
	check.call(Progression.load_data()["embers"] == 214 and not Progression.has_saved_run(), "Embrace instrumentation preserves banking and run clearing")
	evidence["embrace_end_after"] = records
	node.free()

static func _failed_turn_order(check: Callable, evidence: Dictionary) -> void:
	for caller: String in ["headless", "UI"]:
		for failure: String in ["save", "append"]:
			Store.clear_storage()
			var state: Dictionary = Tick.fixture(["crawler"])
			state["analytics"] = {"combat_id": FIXTURE_COMBAT_ID + "_" + caller + "_" + failure}
			var node: Object
			if caller == "headless": node = host(caller, state)
			else:
				node = TurnQueueHost.new()
				var run: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Progression.default_data())
				run["analytics"] = {"run_id": "qa28_order"}
				run["mode"] = "combat"
				node.set("_run_state", run)
				node.set("_combat_state", state)
				node.set("_progression", run["progression"])
			node.set("_analytics_store", FailOnceStore.new() if failure == "append" else Store.new())
			if caller == "UI": node.get("_analytics_store").deferred_writes = true
			if caller == "headless":
				node.set("_session_path", "user://qa28-missing-directory/session.save" if failure == "save" else "user://qa28-order.save")
				node._analytics_initialize_combat_tracker(state)
				node._resolve_enemy_round("pass")
			else:
				var engine := Combat.new()
				var scheduled: Dictionary = Commit.finish_player_activation(engine, state)
				var run: Dictionary = node._stage_player_turn_ended_analytics(node.get("_run_state"), state, scheduled, "pass")
				node.set("_run_state", Run.new().set_combat_state(run, scheduled))
				node.set("_combat_state", scheduled)
				node.set("fail_save", failure == "save")
				node._request_skill_event_analytics()
				var phase: Dictionary = Commit.advance_to_player(engine, scheduled)
				node.set("_combat_state", phase["state"])
				node._analytics_log_enemy_phase_events(phase)
			var label: String = caller + " " + failure
			check.call(Store.load_all_events().is_empty(), label + " failure holds later phase records behind the activation end")
			# A later single-record emitter must obey the same barrier as batches.
			var tail_context: Dictionary = {"run_id": "qa28_order_tail"}
			node.get("_analytics_store").write_event("qa28_order_tail", tail_context, {"owned": true})
			tail_context["run_id"] = "mutated_after_emit"
			if caller == "headless":
				node.set("_session_path", "user://qa28-order.save")
				node._save_session()
			else:
				node.set("fail_save", false)
				node._request_skill_event_analytics()
			var records: Array = Store.load_all_events()
			evidence["ordered_retry_" + caller + "_" + failure] = records
			var turns: Array = records.filter(func(event: Dictionary) -> bool: return event["event_type"] in ["player_turn_ended", "enemy_action_resolved", "enemy_status_tick", "player_turn_started", "qa28_order_tail"])
			var types: Array[String]
			for event: Dictionary in turns: types.append(event["event_type"])
			check.call(types == ["player_turn_ended", "enemy_action_resolved", "enemy_action_resolved", "player_turn_started", "qa28_order_tail"], label + " recovery preserves activation end, enemy actions, next start and tail order: " + str(types))
			if not turns.is_empty():
				check.call(turns.back()["run_id"] == "qa28_order_tail", label + " queued record owns its original context")
			for index: int in range(1, turns.size()):
				check.call(int(turns[index]["sequence"]) > int(turns[index - 1]["sequence"]), label + " sequence matches disk order")
			if caller == "headless": node._save_session()
			else: node._request_skill_event_analytics()
			check.call(Store.load_all_events().size() == records.size(), label + " repeated recovery never duplicates records")
			node.free()

static func _ordered_receipt_batches(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var store := PartialAppendStore.new()
	var first: Dictionary = {"event_type": "player_turn_ended", "context": {"turn": 1}, "payload": {"end_reason": "pass"}, "idempotency_key": "qa28-order-first"}
	var second: Dictionary = {"event_type": "player_turn_ended", "context": {"turn": 2}, "payload": {"end_reason": "pass"}, "idempotency_key": "qa28-order-second"}
	store.hold_ordered_receipts([first])
	store.write_event("enemy_action_resolved", {"turn": 1}, {"actor_key": "enemy_1"})
	store.hold_ordered_receipts([second])
	store.write_event("player_turn_started", {"turn": 3}, {"summon_card_plays": 0})
	check.call(not store.write_events_durable([first, second]), "ordered batch exposes a failed append after a written prefix")
	var prefix: Array = Store.load_all_events()
	check.call(prefix.size() == 1 and prefix[0]["event_type"] == "player_turn_ended", "failed prefix never writes later actions ahead of the receipt")
	store.write_event("qa28_order_tail", {}, {})
	check.call(store.write_events_durable([first, second]), "multi-turn ordered batch retries its original records")
	var events: Array = Store.load_all_events()
	var types: Array[String]
	for event: Dictionary in events: types.append(event["event_type"])
	check.call(types == ["player_turn_ended", "enemy_action_resolved", "player_turn_ended", "player_turn_started", "qa28_order_tail"], "a batch of two receipts cannot jump ahead of intervening events")
	check.call(not events.is_empty() and events[0]["event_id"] == prefix[0]["event_id"], "retry preserves the emitted record ID and deduplicates the durable prefix")
	evidence["ordered_partial_prefix"] = events
	# The barrier is shared by store instances but isolated by storage directory.
	Store.clear_storage()
	var directory: String = Store.storage_dir()
	store.hold_ordered_receipts([first])
	Store.new().write_event("qa28_order_tail", {}, {})
	check.call(not Store.new().has_idempotency_key(first["idempotency_key"]), "a peer store cannot acknowledge an undelivered receipt reservation")
	Store.set_storage_dir(directory + "-independent")
	Store.new().write_event("qa28_independent", {}, {})
	check.call(Store.load_all_events().size() == 1, "an unrelated analytics directory is not blocked")
	Store.set_storage_dir(directory)
	check.call(Store.load_all_events().is_empty(), "returning to a namespace retains its blocked FIFO")
	check.call(Store.new().write_events_durable([first]), "a peer store can deliver the persisted receipt and its following records")
	events = Store.load_all_events()
	check.call(events.size() == 2 and events[0]["event_type"] == "player_turn_ended" and events[1]["event_type"] == "qa28_order_tail", "peer instances and namespace changes preserve disk order")
	evidence["ordered_namespace"] = events

static func _debug_victory(check: Callable, evidence: Dictionary) -> void:
	Store.clear_storage()
	var fixtures := preload("res://tests/dragon_rewards_test.gd").new()
	var reward: Dictionary = fixtures._claim_fixture("noctyrax", FIXTURE_SEED)
	check.call(Progression.save_data(reward["progression"]) and Progression.save_run_state(reward), "debug victory fixture preserves an existing profile and run")
	var profile_hash: String = FileAccess.get_sha256(Progression._storage_path)
	var run_hash: String = FileAccess.get_sha256(Progression._run_storage_path)
	reward["debug_boss_run"] = true
	var node := DebugVictoryHost.new()
	node.set("_run_state", reward)
	node.set("_progression", reward["progression"])
	node.set("_analytics_store", Store.new())
	var progression_before: Dictionary = reward["progression"].duplicate(true)
	node._on_dragon_reward_continue()
	var records: Array = Store.load_all_events()
	evidence["debug_victory"] = records
	check.call(node.get("_run_state")["mode"] == "victory" and records.size() == 1 and records[0]["event_type"] == "run_ended" and records[0]["payload"]["outcome"] == "victory", "debug final-boss Continue emits exactly one victory run_ended")
	check.call(node.get("_progression") == progression_before and FileAccess.get_sha256(Progression._storage_path) == profile_hash and FileAccess.get_sha256(Progression._run_storage_path) == run_hash, "debug victory emits without saving or changing progression or the saved run")
	node._on_dragon_reward_continue()
	check.call(Store.load_all_events().size() == records.size(), "repeated debug Continue cannot emit another victory")
	node.free()
	fixtures.free()
