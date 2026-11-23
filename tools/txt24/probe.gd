extends SceneTree
## Report-only witnesses. An assertion is about reproducing the discrepancy.

const F = preload("res://tools/txt24/fixture.gd")
const CombatProof = preload("res://tools/txt24/combat_proof.gd")
const BattlefieldProof = preload("res://tools/txt24/battlefield_proof.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const Events = preload("res://scripts/event_rules.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Hover = preload("res://scripts/event_reward_preview.gd")
const Run = preload("res://scripts/run_engine.gd")

const COST_DEPTH: int = 15
const DEFERRED_CARD: String = "shatterline"
const EVENT_ID: String = "cinder_supplicant"
const EVENT_CHOICE: String = "hand"
var witnessed: int
var failed: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var engine := F.Combat.new()
	CombatProof.run(engine, _record)
	BattlefieldProof.run(engine, _record)
	_heirloom()
	_event_costs()
	_event_deferral()
	print("TXT24 WITNESSES: %d reproduced, %d failed" % [witnessed, failed])
	quit(0 if failed == 0 else 1)

func _record(id: String, observed: bool, details: String) -> void:
	if observed: witnessed += 1
	else: failed += 1
	print("TXT24 %s %s | %s" % ["REPRODUCED" if observed else "MISSING", id, details])

func _event_costs() -> void:
	var engine := Run.new()
	var cases: Array = [["ossuary_gamblers", "wager_embers", COST_DEPTH, "Stake 50 Embers", 65],
		["whispering_well", "ember", 0, "Drop an Ember in", 25]]
	for case: Array in cases:
		var state: Dictionary = EventFixture.fixture(case[0], true)
		state["umbra_depth"] = case[2]
		var choice: Dictionary = Events.choice_def(case[0], case[1])
		var lines: Array[String] = Events.choice_effect_lines(state, case[0], case[1])
		var result: Dictionary = Events.choose_event(state, case[1], engine)
		var cost: int = engine.held_embers(state) - engine.held_embers(result)
		_record(case[0] + "_cost", choice["label"] == case[3] and cost == case[4],
			"Choice=%s; printed cost=%s; actual debit=%d." % [choice["label"], lines[0], cost])

func _event_deferral() -> void:
	var engine := Run.new()
	var state: Dictionary = EventFixture.fixture(EVENT_ID, true)
	state["progression"]["skill_ids"] = ["discerning_eye", "deferred_choice"]
	state["mode"] = "reward"
	state["pending_reward"] = {"cards": [DEFERRED_CARD], "heal_amount": 3}
	state = engine.skip_reward_for_heal(state, DEFERRED_CARD)
	state = Events.enter_event(state)
	var lines: Array[Dictionary] = Events.preview_lines(state, EVENT_ID, EVENT_CHOICE)
	var hover: Dictionary = Hover.hover_line(lines)
	var result: Dictionary = engine.resolve_map_event(state, EVENT_CHOICE)
	result = engine.resolve_map_event(result, "continue")
	var offered: Array = result["pending_reward"]["cards"]
	_record("event_hover_deferred_choice", hover["ids"].size() == offered.size() and not hover["ids"].has(DEFERRED_CARD) and offered.has(DEFERRED_CARD),
		"Printed=%s Hover=%s; the actual reward offered=%s." % [hover["text"], hover["ids"], offered])
	var before: Dictionary = result.get(Run.SKILL_STATE_KEY, {}).duplicate(true)
	var skipped: Dictionary = engine.skip_reward_for_heal(result, DEFERRED_CARD)
	var unchanged: bool = before == skipped.get(Run.SKILL_STATE_KEY, {})
	_record("deferred_choice_event_skip", unchanged and skipped["pending_reward"].is_empty(),
		"Skipping the event reward with %s offered left skill state unchanged=%s and closed the reward." % [DEFERRED_CARD, unchanged])

func _heirloom() -> void:
	var engine := Run.new()
	var first: Dictionary = HeirloomFixture.equip(BoonFixture.state())
	first["mode"] = "defeat"
	var left: Dictionary = Boons.leave_heirloom(first, BoonFixture.PROOF_HEIRLOOM)
	var profile: Dictionary = left["progression"].duplicate(true)
	profile["run_counter"] = int(profile["run_counter"]) + 1
	var second: Dictionary = engine.create_new_run(F.SEED, profile)
	var declined: Dictionary = Boons.choose(engine, second, "")
	declined["mode"] = "defeat"
	var retained: Dictionary = Boons.leave_heirloom(declined, "")
	profile = retained["progression"].duplicate(true)
	profile["run_counter"] = int(profile["run_counter"]) + 1
	var third: Dictionary = engine.create_new_run(F.SEED, profile)
	var offer: Dictionary = Boons.available_offers(third)[0]
	var sentence: String = F.text(Boons.text(offer))
	_record("heirloom_last_run", declined[Boons.STATE_KEY].get("resolved", false) and retained[Boons.HEIRLOOM_END_KEY].get("done", false) and offer.get("item") == BoonFixture.PROOF_HEIRLOOM and sentence.contains("last run"),
		"Left %s in run %d, declined in run %d and left nothing, then run %d said: %s" % [BoonFixture.PROOF_HEIRLOOM, first["run_index"], second["run_index"], third["run_index"], sentence])
