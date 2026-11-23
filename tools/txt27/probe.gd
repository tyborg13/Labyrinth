extends SceneTree
## Candidate-4 witnesses replayed against the accepted txt-27 rules.

const F = preload("res://tools/txt27/fixture.gd")
const CombatProof = preload("res://tools/txt27/combat_proof.gd")
const BattlefieldProof = preload("res://tools/txt27/battlefield_proof.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const Events = preload("res://scripts/event_rules.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Hover = preload("res://scripts/event_reward_preview.gd")
const Run = preload("res://scripts/run_engine.gd")

const COST_DEPTH: int = 15
const DEFERRED_CARD: String = "shatterline"
const SPELL_CHOICES: Dictionary = {
	"cinder_supplicant": "hand",
	"moth_library": "search",
	"tempest_choir": "join",
	"twin_doors": "cold",
	"blind_scribe": "better",
	"kiln_of_names": "smash",
	"howling_gallery": "listen",
}
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
	print("TXT27 WITNESSES: %d passed, %d failed" % [witnessed, failed])
	quit(0 if failed == 0 else 1)

func _record(id: String, observed: bool, details: String) -> void:
	if observed: witnessed += 1
	else: failed += 1
	print("TXT27 %s %s | %s" % ["PASS" if observed else "FAIL", id, details])

func _event_costs() -> void:
	var engine := Run.new()
	var cases: Array = [["ossuary_gamblers", "wager_embers", COST_DEPTH, "Stake 65 Embers", 65],
		["whispering_well", "ember", 0, "Drop Embers in", 25]]
	for case: Array in cases:
		var state: Dictionary = EventFixture.fixture(case[0], true)
		state["umbra_depth"] = case[2]
		var choice: Dictionary = Events.choice_def(case[0], case[1])
		var lines: Array[String] = Events.choice_effect_lines(state, case[0], case[1])
		var result: Dictionary = Events.choose_event(state, case[1], engine)
		var cost: int = engine.held_embers(state) - engine.held_embers(result)
		_record(case[0] + "_cost", Events.choice_label(state, choice) == case[3] and lines[0] == "Pay %d Embers." % cost and cost == case[4],
			"Choice=%s; printed cost=%s; actual debit=%d." % [Events.choice_label(state, choice), lines[0], cost])

func _event_deferral() -> void:
	var engine := Run.new()
	for event_id: String in SPELL_CHOICES:
		var choice_id: String = SPELL_CHOICES[event_id]
		var state: Dictionary = EventFixture.fixture(event_id, true)
		state["progression"]["skill_ids"] = ["discerning_eye", "deferred_choice"]
		state["mode"] = "reward"
		state["pending_reward"] = {"cards": [DEFERRED_CARD], "heal_amount": 3}
		state = engine.skip_reward_for_heal(state, DEFERRED_CARD)
		state = Events.enter_event(state)
		var before: Dictionary = state.duplicate(true)
		var lines: Array[Dictionary] = Events.preview_lines(state, event_id, choice_id)
		var hover: Dictionary = Hover.hover_line(lines)
		var forecast: Array = Events.preview_choice(state, choice_id).filter(func(outcome: Dictionary) -> bool: return outcome["type"] == "card_choice")
		var result: Dictionary = engine.resolve_map_event(state, choice_id)
		var authored: Array = result["event_state"]["outcomes"].filter(func(outcome: Dictionary) -> bool: return outcome["type"] == "card_choice")
		var result_lines: Array[String] = Events.outcome_lines(result)
		result = engine.resolve_map_event(result, "continue")
		var offered: Array = result.get("pending_reward", {}).get("cards", [])
		var id: String = "event_hover_deferred_choice" if event_id == "cinder_supplicant" else event_id + "_deferred_offer"
		_record(id, state == before and offered.has(DEFERRED_CARD) and hover.get("ids", []) == offered and not forecast.is_empty() and forecast[0]["cards"] == offered and not authored.is_empty() and not authored[0]["cards"].has(DEFERRED_CARD) and result_lines.has("Next: choose 1 of %d spells." % offered.size()),
			"Cost and hover=%s; forecast=%s; reward=%s." % [hover, forecast, offered])
		var saved: String = str(offered.front()) if not offered.is_empty() else ""
		var skipped: Dictionary = engine.skip_reward_for_heal(result, saved)
		id = "deferred_choice_event_skip" if event_id == "cinder_supplicant" else event_id + "_deferred_skip"
		_record(id, not saved.is_empty() and skipped.get(Run.SKILL_STATE_KEY, {}).get("pending_card") == saved and skipped["pending_reward"].is_empty() and skipped["player_hp"] == result["player_hp"],
			"Skipped %s and saved %s." % [event_id, saved])

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
	_record("heirloom_last_run", declined[Boons.STATE_KEY].get("resolved", false) and retained[Boons.HEIRLOOM_END_KEY].get("done", false) and offer.get("item") == BoonFixture.PROOF_HEIRLOOM and sentence.contains("you left here.") and not sentence.contains("last run"),
		"Left %s in run %d, declined in run %d and left nothing, then run %d said: %s" % [BoonFixture.PROOF_HEIRLOOM, first["run_index"], second["run_index"], third["run_index"], sentence])
