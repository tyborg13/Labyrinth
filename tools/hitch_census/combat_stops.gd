extends RefCounted
## Fixture configuration and coverage checks for live combat playback.
const ROUND_COUNT: int = 3
const INTENT_HOLD_SECONDS: float = 0.5
const ROUND_GUARD_SECONDS: float = 60.0
const FIXTURE_HEALTH: int = 100
const CASES: Dictionary = {
	"lightning_storm": {"scenario": "snare", "snare_biome": "lightning"},
	"gust": {"scenario": "snare", "snare_biome": "air"},
	"tharokh": {"scenario": "dragon", "dragon_id": "tharokh"},
	"craghide": {"scenario": "guardian", "guardian_id": "craghide"},
}
const BOSS_CYCLES: Dictionary = {"tharokh": "dragon_cycle", "craghide": "guardian_cycle"}
const EXPECTED_ACTIVATIONS: Dictionary = {"lightning_storm": 3, "gust": 3, "tharokh": 3, "craghide": 4}
const EXPECTED_INTENTS: Dictionary = {
	"tharokh": ["stonewake", "worldspine_claw", "bedrock_breath"],
	"craghide": ["upheaval", "groundsplit", "crushing_rush"],
}

static func play(host: SceneTree, stop: String) -> void:
	var initial: Dictionary = witness(host.scene, stop)
	if not initial["ready"] or initial["activations"] < 0:
		host.errors.append(stop + ": fixture did not install the expected rule or live boss at a player turn")
		return
	var current: Dictionary = initial
	var intents: Array[String]
	for round_index: int in range(ROUND_COUNT):
		if host.finished: return
		if BOSS_CYCLES.has(stop):
			intents.append(current["intent"])
		host.mark(stop, "enemy_round")
		# Use the ordinary Pass handler. It resolves the live rule, plays the
		# generated steps, and applies the accepted state through RunScene.
		host.scene.call("_on_pass_turn_pressed")
		var deadline: int = Time.get_ticks_usec() + int(ROUND_GUARD_SECONDS * 1000000)
		while not host.finished and Time.get_ticks_usec() < deadline:
			await host.process_frame
			current = witness(host.scene, stop)
			if current["turn"] > initial["turn"] + round_index and current["ready"]: break
			if str(host.scene.get("_run_state").get("mode", "")) != "combat": break
		if host.finished: return
		if current["turn"] != initial["turn"] + round_index + 1 or not current["ready"]:
			host.errors.append("%s: pass %d did not return to a player turn" % [stop, round_index + 1])
			return
		host.mark(stop, "round_complete")
		# Give the new announcement one visible rest window before the next Pass.
		await host.hold(INTENT_HOLD_SECONDS)
	if host.finished: return
	var rounds: int = current["turn"] - initial["turn"]
	var activations: int = current["activations"] - initial["activations"]
	var coverage: Dictionary = {"rounds": rounds, "activations": activations}
	if not intents.is_empty(): coverage["intents_before_pass"] = intents
	host.coverage["playback:" + stop] = coverage
	if activations != EXPECTED_ACTIVATIONS[stop]:
		host.errors.append("%s: expected %d activations, observed %d" % [stop, EXPECTED_ACTIVATIONS[stop], activations])
	var expected_intents: Array = EXPECTED_INTENTS.get(stop, [])
	if intents != expected_intents:
		host.errors.append("%s: expected intents %s, observed %s" % [stop, expected_intents, intents])

static func witness(scene: Node, stop: String) -> Dictionary:
	var battle: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	var ready: bool = (
		str(scene.get("_run_state").get("mode", "")) == "combat"
		and not battle.is_empty()
		and engine.is_player_turn(battle)
		and not bool(scene.get("_animation_lock"))
	)
	var activations: int = -1
	var intent: String = ""
	if BOSS_CYCLES.has(stop):
		for unit: Dictionary in battle.get("enemies", []):
			if str(unit.get("type", "")) == stop and int(unit.get("hp", 0)) > 0:
				activations = int(unit.get(BOSS_CYCLES[stop], -1))
				intent = str(unit.get("intent", {}).get("id", ""))
				break
	else:
		var rule: Dictionary = battle.get("battlefield_rule", {})
		if str(rule.get("rule", "")) == stop: activations = int(rule.get("beats_fired", 0))
	return {"turn": int(battle.get("turn", 0)), "ready": ready, "activations": activations, "intent": intent}
