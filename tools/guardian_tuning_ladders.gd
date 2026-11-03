extends RefCounted
## Director-authored cumulative values, applied in an isolated measurement PID.
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const PLAN: String = "res://spec/peer_benchmark/encounter_redesign/bos_03_feedback_1_ladders.json"
const BASE: String = "res://tests/fixtures/bos_03_round0_tuning_base.json"
const EXTENSIONS: String = "res://spec/peer_benchmark/encounter_redesign/bos_03_feedback_2_ladders.json"
const FINAL: String = "res://spec/peer_benchmark/encounter_redesign/bos_03_feedback_3_ladders.json"

static func apply(guardian: String, rung: int) -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	assert(plan.has(guardian) and rung>=1 and rung<=(plan[guardian] as Array).size())
	for id: String in baseline["enemies"]: Data.enemies()[id] = baseline["enemies"][id].duplicate(true)
	# This helper was unchanged in the round-0 fixture; do not leak production
	# rung 12 into reproduction of an earlier ladder.
	Data.enemies()["bell_tender"].erase("guardian_intent_action_overrides")
	Rules.data()["instances"]["storm_cantor"] = baseline["storm_cantor_rule"].duplicate(true)
	_apply_changes(guardian,(plan[guardian] as Array).slice(0,rung))

static func apply_extended(guardian: String, rung: int) -> void:
	var extensions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXTENSIONS))
	var ladder: Dictionary = extensions[guardian]
	var start: int = int(ladder["start_rung"])
	assert(rung>start and rung<=start+(ladder["rungs"] as Array).size())
	apply(guardian,start)
	_apply_changes(guardian,(ladder["rungs"] as Array).slice(0,rung-start))

static func _apply_changes(guardian: String, changes: Array) -> void:
	for change: Dictionary in changes:
		var definition: Dictionary = Data.enemies()[guardian]
		definition.merge(change.get("fields",{}),true)
		for intent: Dictionary in definition["intents"]:
			var overrides: Dictionary = change.get("intents",{}).get(str(intent["id"]),{})
			for action: Dictionary in intent["actions"]:
				action.merge(overrides.get(str(action["type"]),{}),true)
		for helper: String in change.get("helper_fields",{}): Data.enemies()[helper].merge(change["helper_fields"][helper],true)
		var rule: Dictionary = Rules.data()["instances"].get(guardian,{})
		if change.has("rule"):
			rule["dials"].merge(change["rule"].get("dials",{}),true)
			if change["rule"].has("sentence"): rule["sentence"] = change["rule"]["sentence"]

static func apply_final(guardian: String, rung: int) -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINAL))
	var ladder: Dictionary = plan[guardian]
	var start: int = int(ladder["start_rung"])
	assert(rung>start and rung<=start+(ladder["rungs"] as Array).size())
	apply_extended(guardian,start)
	_apply_changes(guardian,ladder["repairs"])
	_apply_changes(guardian,(ladder["rungs"] as Array).slice(0,rung-start))
