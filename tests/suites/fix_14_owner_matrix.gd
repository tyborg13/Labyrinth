extends RefCounted

const Cases = preload("res://tests/suites/fix_14_owner_matrix_cases.gd")
const Base = Cases.Base
const Trace = preload("res://scripts/reaction_presentation_trace.gd")
const Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
const Feedback = preload("res://tests/suites/fix_14_feedback_suite.gd")
const Defiance = preload("res://tests/suites/fix_15_defiance_cases.gd")
const BoardCases = preload("res://tests/suites/fix_15_board_cases.gd")
const StateInvariant = preload("res://tests/helpers/fix_15_state_invariant.gd")
const PLAYBACK_TIMEOUT_SECONDS: float = 20.0
const OWNER_PHASE: Dictionary = {"arrival": "move", "move_bleed": "bleed_move", "attack_bleed": "bleed_attack", "action": "beam", "retaliate": "retaliate", "reflection": "illusion_retort", "activation_fire": "activation_fire", "cascade": "death_burst"}

static func cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = Cases.cases()
	result.append_array(Defiance.cases())
	return result

static func state_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = cases()
	result.append_array(BoardCases.cases())
	return result

static func phase_name(step: Dictionary) -> String:
	if bool(step.get("traced_bleed", false)): return "bleed_move" if step["action_type"] in ["move_toward", "move_away"] else "bleed_attack"
	if step.has("cascade"): return str(step["action_type"])
	if step.get("kind", "") == "move" or bool(step.get("traced_arrival", false)): return "move"
	if step.get("action_type", "") in ["retaliate", "illusion_retort", "activation_fire"]: return step["action_type"]
	return "beam"

static func frames(phase: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for step: Dictionary in phase["steps"]:
		if step.has("move_after"): result.append({"step": step["move_step"], "after": step["move_after"], "phase": "move"})
		var after: Dictionary = step.get("reaction_after", step.get("en03_after", step.get("en06_after", {})))
		if not after.is_empty(): result.append({"step": step, "after": after, "phase": phase_name(step)})
	return result

static func run(expect: Callable) -> void:
	# Keep the shared snapshot assertions independent of either retired matrix.
	var historical: Dictionary = Cases.Mimic.state_for("firing", false)
	Defiance._enable(historical)
	historical["player"]["hp"] = Defiance.LETHAL_HP
	historical = Base.Combat.new()._damage_player(historical, Defiance.LETHAL_HP, false, false, "peer_history")
	var copied: Dictionary = Trace.snapshot(historical)
	for field: String in ["defiance_events", "defiance_event_revision", "defiance_remaining", "defiance_capacity"]:
		expect.call(copied.get(field) == historical.get(field), "Owner snapshot carries %s unchanged" % field)
	if copied.has("defiance_events"): copied["defiance_events"].clear()
	expect.call(not historical["defiance_events"].is_empty(), "Owner snapshot does not alias Defiance history")
	expect.call(Trace.snapshot({}).is_empty(), "Owner snapshot does not invent absent fields")
	print("FIX-14 MATRIX: retired Tether and Mirror compound cases; Echo/Retaliate covered by mim01")

static func check_phase(expect: Callable, before: Dictionary, phase: Dictionary, case: Dictionary, mode: String) -> void:
	var label: String = str(case["name"]) + "/" + mode
	Totals.check_phase(expect, before, phase, label)
	var current: Dictionary = Trace.snapshot(before)
	var deaths: Dictionary = {}
	var revivals: Array[Dictionary]
	var hero_damage: int = 0
	var owner_seen: bool = false
	for frame: Dictionary in frames(phase):
		var step: Dictionary = frame["step"]
		var after: Dictionary = frame["after"]
		var losses: Array = (step.get("target_losses", []) as Array).duplicate(true)
		losses.append_array(step.get("enemy_losses", []))
		losses.append_array(step.get("terrain_losses", []))
		hero_damage += Base.hp_loss(losses, "player")
		var events: Array[Dictionary] = Totals.new_defiance_events(current, after)
		var restored: int = 0
		for event: Dictionary in events:
			restored += int(event["restored_hp"])
			revivals.append({"phase": frame["phase"], "source_id": int(step.get("cascade", {}).get("id", -1)), "revision": event["revision"], "restored_hp": event["restored_hp"], "lethal_hp_loss": event["lethal_hp_loss"]})
		var hero_losses: Array = losses.filter(func(loss: Dictionary) -> bool: return loss["key"] == "player")
		var shown_restored: int = 0
		var triggers: int = 0
		for loss: Dictionary in hero_losses:
			shown_restored += int(loss.get("defiance_restored", 0))
			triggers += int(loss.get("defiance_trigger_count", 0))
		expect.call(shown_restored == restored and triggers == events.size(), "%s: each owner reports only its new Defiance events" % label)
		expect.call(int(after.get("defiance_event_revision", 0)) == int(current.get("defiance_event_revision", 0)) + events.size(), "%s: owner revision advances exactly with resolver events" % label)
		expect.call((after.get("defiance_events", []) as Array).slice(0, (current.get("defiance_events", []) as Array).size()) == current.get("defiance_events", []), "%s: owner preserves Defiance history unchanged" % label)
		for key: String in Totals.actors(current):
			var old_hp: int = int(Totals.actors(current)[key].get("hp", 0))
			var new_hp: int = int(Totals.actors(after).get(key, {}).get("hp", 0))
			expect.call(Base.hp_loss(losses, key) == maxi(0, old_hp - new_hp + (restored if key == "player" else 0)), "%s: each immediate owner matches %s HP including restoration" % [label, key])
			expect.call(new_hp <= old_hp or (key == "player" and restored > 0), "%s: HP rises only on its Defiance owner for %s" % [label, key])
			if old_hp > 0 and new_hp <= 0:
				expect.call(not deaths.has(key), "%s: sole defeat boundary for %s" % [label, key])
				deaths[key] = frame["phase"]
		if frame["phase"] == OWNER_PHASE[case["owner"]] and not losses.is_empty(): owner_seen = true
		if bool(step.get("traced_charge", false)):
			var victims: Array[Dictionary]
			victims.append_array(step.get("target_losses", []))
			victims.append_array(step.get("enemy_losses", []))
			expect.call(step.get("impact_actor_keys", []) == Base.Combat.new()._target_loss_keys(victims), "%s: charge impact victims belong only to the immediate owner" % label)
		current = after
	expect.call(owner_seen, "%s: requested owner actually resolves" % label)
	expect.call(deaths == case["expected_deaths"], "%s: defeats belong to the rule owner; expected=%s actual=%s" % [label, case["expected_deaths"], deaths])
	expect.call(revivals == case.get("expected_revivals", []), "%s: revivals belong once to their rule owner; expected=%s actual=%s" % [label, case.get("expected_revivals", []), revivals])
	for field: String in ["defiance_events", "defiance_event_revision", "defiance_remaining", "defiance_capacity"]:
		expect.call(current.get(field) == phase["state"].get(field), "%s: final owner retains resolver %s" % [label, field])
	if case.has("expected_player_hp"):
		expect.call(phase["state"]["player"]["hp"] == case["expected_player_hp"] and hero_damage == case["expected_player_damage"], "%s: independent reviewer HP and gross damage oracle" % label)
		if mode == "turn": print("FIX-15 REVIEWER TRACE: %s; hero %d->%d; damage=%d; revivals=%s" % [case["name"], before["player"]["hp"], phase["state"]["player"]["hp"], hero_damage, revivals])
	var resolved: Array[int] = Feedback.burst_ids(before, phase)
	expect.call(resolved == case["expected_bursts"], "%s: fixture resolves its required bursts" % label)
	var starts: Array[int]
	var hero_burst_loss: int = 0
	for step: Dictionary in phase["steps"]:
		if step.get("action_type", "") != "death_burst": continue
		if not bool(step.get("cascade_continuation", false)): starts.append(int(step["cascade"]["id"]))
		hero_burst_loss += Base.hp_loss(step.get("target_losses", []), "player")
	expect.call(starts == resolved, "%s: every burst has exactly one owning start" % label)
	if not case["expected_bursts"].is_empty(): expect.call(hero_burst_loss == int(case.get("expected_burst_hp", Cases.BURST_DAMAGE)), "%s: cascade owns its four hero HP (or fixture's realized lethal loss)" % label)
	if case["outcome"] == "hero_terminal": expect.call(phase["state"]["player"]["hp"] == 0 and Base.Combat.new().combat_outcome(phase["state"]) == "defeat", "%s: cascade ends combat" % label)

static func check_playback(expect: Callable, before: Dictionary, phase: Dictionary, scene: Control, case: Dictionary) -> void:
	var label: String = case["name"]
	var actual: Array = (scene.get("defeat_owners") as Array).duplicate(true)
	actual.append_array(scene.get("illusion_fades"))
	for key: String in Totals.lifetimes(before, phase):
		var owners: Array = actual.filter(func(value: Dictionary) -> bool: return value["key"] == key)
		var expected: String = str(case["expected_deaths"].get(key, ""))
		expect.call(owners.size() == (0 if expected.is_empty() else 1) and (owners.is_empty() or owners[0]["phase"] == expected), "%s: actual sole defeat/fade owner for %s" % [label, key])
	var expected_losses: Dictionary = {}
	for frame: Dictionary in frames(phase):
		for field: String in ["target_losses", "enemy_losses", "terrain_losses"]:
			for loss: Dictionary in frame["step"].get(field, []):
				var key: String = "%s/%s" % [frame["phase"], loss["key"]]
				expected_losses[key] = int(expected_losses.get(key, 0)) + int(loss.get("hp_loss", 0))
	var shown: Dictionary = {}
	for popup: Dictionary in scene.get("popup_submissions"):
		if popup["entry"].get("kind", "") != "damage": continue
		var key: String = "%s/%s" % [popup["phase"], popup["entry"].get("reaction_actor_key", "")]
		shown[key] = int(shown.get(key, 0)) + str(popup["entry"]["text"]).trim_prefix("-").to_int()
	for key: String in expected_losses: expect.call(int(shown.get(key, 0)) == expected_losses[key], "%s: actual popup loss belongs to %s" % [label, key])
	var revival_popups: Array = (scene.get("popup_submissions") as Array).filter(func(popup: Dictionary) -> bool: return popup["entry"].get("icon", "") == "defiance")
	var expected_revivals: Array = case.get("expected_revivals", [])
	expect.call(revival_popups.size() == expected_revivals.size(), "%s: actual revival shown exactly once per current event" % label)
	for index: int in mini(revival_popups.size(), expected_revivals.size()):
		var popup: Dictionary = revival_popups[index]
		var expected: Dictionary = expected_revivals[index]
		expect.call(popup["phase"] == expected["phase"] and popup["source_id"] == expected["source_id"] and Totals.defiance_restoration(popup["entry"]) == expected["restored_hp"], "%s: actual revival popup belongs to its rule owner" % label)
	if case.has("expected_player_hp"):
		var hero: Array = (scene.get("popup_submissions") as Array).filter(func(popup: Dictionary) -> bool: return popup["entry"].get("kind", "") == "damage" and popup["entry"].get("reaction_actor_key", "") == "player")
		print("FIX-15 REVIEWER PLAYBACK: %s; hero popups=%s; revival owners=%s" % [label, hero.map(func(popup: Dictionary) -> String: return "%s:%s" % [popup["phase"], popup["entry"]["text"]]), revival_popups.map(func(popup: Dictionary) -> String: return "%s/%s" % [popup["phase"], popup["source_id"]])])
	var ids: Array[int] = Feedback.burst_ids(before, phase)
	expect.call(scene.get("burst_sources") == ids, "%s: actual ring starts once per burst" % label)
	expect.call(scene.get("burst_cue_starts") == ids, "%s: actual cue starts once per burst" % label)
	print("FIX-14 MATRIX PLAYBACK: %s; expected defeats=%s actual=%s; rings=%s cues=%s" % [label, case["expected_deaths"], actual, scene.get("burst_sources"), scene.get("burst_cue_starts")])
