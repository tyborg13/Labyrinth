extends RefCounted

const Recorder = preload("res://tests/helpers/fix_15_resolver_recorder.gd")
const Trace = preload("res://scripts/reaction_presentation_trace.gd")
const Scene = preload("res://scripts/run_scene.gd")
# Independent, exact path allow-list. Never exclude actors, statuses, charges,
# gameplay history, RNG, or other board state. The final comparison excludes none.
const DEFERRED_FIELDS: Dictionary = {
	"damage_context": "The enclosing hit/death scope restores its caller's cause after owner capture.",
	"_surface_damage_batch": "The enclosing compound hit closes its synchronous damage batch after owner capture.",
	"_surface_pending_deaths": "The death flush drains this private queue after the causing hit is captured.",
	"_death_burst_queue": "The enclosing FIFO drains queued bursts after owner capture.",
	"_death_burst_running": "The enclosing FIFO clears its reentrancy guard after owner capture.",
	"death_burst_events": "The legacy burst journal is applied after explicit traced burst feedback to prevent replay.",
	"enemies[].death_burst_resolved": "The FIFO's per-enemy reentrancy guard is published after burst resolution, at turn cleanup.",
}

static func serialized(state: Dictionary, complete: bool = false) -> String:
	var value: Dictionary = state.duplicate(true)
	if not complete:
		for field: String in DEFERRED_FIELDS: value.erase(field)
		for enemy: Dictionary in value.get("enemies", []): enemy.erase("death_burst_resolved")
	return canonical(value)

# Type-preserving, dictionary-order-independent encoding. Variant bytes retain
# exact scalar bits; empty container bytes retain their declared element types.
static func canonical(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var empty: Dictionary = value.duplicate()
		empty.clear()
		var entries: Array[String]
		for key: Variant in value: entries.append(frame(canonical(key)) + frame(canonical(value[key])))
		entries.sort()
		return "D" + var_to_bytes(empty).hex_encode() + ":" + "".join(entries)
	if typeof(value) == TYPE_ARRAY:
		var empty: Array = value.duplicate()
		empty.clear()
		var entries: Array[String]
		for item: Variant in value: entries.append(frame(canonical(item)))
		return "A" + var_to_bytes(empty).hex_encode() + ":" + "".join(entries)
	return var_to_bytes(value).hex_encode()

# Length framing avoids JSON coercion and repeated escaping of nested strings.
static func frame(encoded: String) -> String:
	return str(encoded.length()) + ":" + encoded

static func check_types(expect: Callable) -> void:
	var typed: Array[Vector2i]
	typed.append(Vector2i(2, 3))
	var untyped: Array = [Vector2i(2, 3)]
	for pair: Array in [[Vector2i(2, 3), "(2, 3)"], [1, 1.0], [0.0, 1.0e-18], [9007199254740992, 9007199254740993], [{1: "value"}, {"1": "value"}], [typed, untyped], [{"nested": [Vector2i(2, 3)]}, {"nested": ["(2, 3)"]}]]:
		expect.call(canonical(pair[0]) != canonical(pair[1]), "Type-exact state comparison distinguishes Variant types, container declarations and exact values")
	expect.call(canonical({"a": 1, "b": Vector2i(2, 3)}) == canonical({"b": Vector2i(2, 3), "a": 1}), "Type-exact state comparison ignores dictionary insertion order")
	for complete: bool in [false, true]:
		expect.call(serialized({"player": {"pos": Vector2i(2, 3)}}, complete) != serialized({"player": {"pos": "(2, 3)"}}, complete), "Vector-to-String corruption fails intermediate and terminal state equality")

static func payload(step: Dictionary) -> Dictionary:
	return step.get("trace_state_after", step.get("reaction_after", step.get("en03_after", step.get("en06_after", {}))))

static func oracle(recorder: RefCounted, step: Dictionary) -> Dictionary:
	var id: int = int(step.get("_resolver_boundary_id", -1))
	return recorder.resolved_states[id] if id >= 0 and id < recorder.resolved_states.size() else {}

static func check_step(expect: Callable, scene: Control, animated: Dictionary, step: Dictionary, recorder: RefCounted, label: String) -> bool:
	var snapshot: Dictionary = payload(step)
	if snapshot.is_empty() and not step.has("_resolver_boundary_id"):
		scene._apply_animation_step(animated, step)
		return true
	var complete: bool = bool(step.get("trace_state_complete", false))
	var expected: Dictionary = oracle(recorder, step)
	expect.call(not expected.is_empty(), "%s: traced step has an independent resolver boundary" % label)
	if expected.is_empty(): return false
	var valid: bool = snapshot.is_empty() or serialized(snapshot, complete) == serialized(expected, complete)
	expect.call(valid, "%s: complete snapshot equals independently resolved serialized state" % label)
	if not valid: return false # A deliberate missing-player/enemies mutant must fail assertions, not crash the observer.
	scene._apply_animation_step(animated, step)
	var matches: bool = serialized(animated, complete) == serialized(expected, complete)
	expect.call(matches, "%s: presented equals resolved after traced step" % label)
	return matches

static func owner_kind(step: Dictionary) -> String:
	if bool(step.get("trace_state_complete", false)): return "complete"
	if step.get("kind", "") == "intent": return "intent"
	if bool(step.get("traced_bleed", false)): return "bleed_move" if step["action_type"] in ["move_toward", "move_away"] else "bleed_attack"
	if step.has("cascade"): return str(step["action_type"])
	if step.get("action_type", "") in ["retaliate", "illusion_retort", "activation_fire"]: return str(step["action_type"])
	if step.has("en03_after"): return "action"
	if step.get("kind", "") == "move" or bool(step.get("traced_arrival", false)): return "move"
	return "skip"

static func check_order(expect: Callable, recorder: RefCounted, submissions: Array[Dictionary], label: String) -> void:
	var expected: Array = recorder.journal.events
	expect.call(recorder.journal.stack.is_empty(), "%s: independent ordered resolver scopes are balanced" % label)
	expect.call(submissions.size() == expected.size(), "%s: owning steps match independent resolver journal one to one (%d presented, %d resolved)" % [label, submissions.size(), expected.size()])
	for index: int in mini(submissions.size(), expected.size()):
		var actual: Dictionary = submissions[index]
		var entry: Dictionary = expected[index]
		var kind: String = owner_kind(actual["step"])
		var correct_owner: bool = kind == entry["owner"]["kind"]
		if entry["owner"].has("id"):
			var id: int = int(actual["step"].get("cascade", {}).get("id", str(actual["step"].get("actor_key", "")).trim_prefix("enemy_").to_int()))
			correct_owner = correct_owner and id == int(entry["owner"]["id"])
		expect.call(correct_owner, "%s: owning step %d follows independent resolver journal order (expected %s, actual %s)" % [label, index, entry["owner"], kind])
		var equal: bool = serialized(actual["state"], bool(entry["complete"])) == entry["serialized"]
		expect.call(equal, "%s: ordered presented state equals resolver post-event state at %d (%s)" % [label, index, entry["owner"]])
		if not equal: print("ORDERED STATE DIFF: ", label, " index=", index, " expected=", entry["owner"], " fields=", nearest_fields({"presented": actual["state"]}, entry["state"]))

static func check_phase(expect: Callable, before: Dictionary, phase: Dictionary, recorder: RefCounted, case: Dictionary, mode: String) -> void:
	var label: String = "%s/%s" % [case["name"], mode]
	var scene := Scene.new()
	var animated: Dictionary = before.duplicate(true)
	var ordered: Array[Dictionary]
	var valid: bool = true
	for step: Dictionary in phase["steps"]:
		if step.get("kind", "") == "commit": continue # Persistence commits precede feedback; production playback ignores them.
		if step.has("move_step"):
			valid = check_step(expect, scene, animated, step["move_step"], recorder, label + "/embedded_move") and valid
			ordered.append({"step": step["move_step"], "state": animated.duplicate(true)})
		valid = check_step(expect, scene, animated, step, recorder, label + "/" + str(step.get("action_type", step["kind"]))) and valid
		if not payload(step).is_empty(): ordered.append({"step": step, "state": animated.duplicate(true)})
		if not valid: break
	check_order(expect, recorder, ordered, label)
	if valid: expect.call(serialized(animated, true) == serialized(phase["state"], true), "%s: presented equals resolved at turn end with no exceptions" % label)
	if bool(case.get("spawn", false)):
		expect.call(phase["state"]["enemies"].size() == before["enemies"].size() + preload("res://tests/suites/fix_15_board_cases.gd").DROPLETS, "%s: reviewer Ooze split resolves both droplets" % label)
		var spawn_steps: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return step.get("action_type", "") == "surface_death" and payload(step).get("enemies", []).size() > before["enemies"].size())
		expect.call(not spawn_steps.is_empty(), "%s: spawn-only death owns a presented roster boundary" % label)
		if not spawn_steps.is_empty(): expect.call(spawn_steps[0].get("target_losses", []).is_empty() and spawn_steps[0].get("enemy_losses", []).is_empty() and bool(spawn_steps[0].get("cascade_bookkeeping", false)), "%s: spawn bookkeeping invents no damage or burst cue" % label)
	if case.has("spawn_arrival_damage"):
		var Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
		var Base = preload("res://tests/suites/fix_12_suite.gd")
		var damage: int = int(case["spawn_arrival_damage"])
		var born: Dictionary = Totals.lifetimes(before, phase)["enemy_4"]
		expect.call(born["hp"] == preload("res://tests/suites/fix_15_board_cases.gd").NEWBORN_SPAWN_HP and phase["state"]["enemies"][3]["hp"] == born["hp"] - damage, "%s: newborn lifetime starts at spawn HP before arrival contact" % label)
		var owners: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return Base.hp_loss(step.get("enemy_losses", []), "enemy_4") > 0)
		expect.call(owners.size() == 1 and owners[0]["action_type"] == "spawn_arrival" and Base.hp_loss(owners[0]["enemy_losses"], "enemy_4") == damage, "%s: newborn arrival owns its entire realized loss exactly once" % label)
		Totals.check_phase(expect, before, phase, label)
	if case.has("consumed_status"):
		var field: String = case["consumed_status"]
		var fire: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return step.get("action_type", "") == "activation_fire")
		var skip: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return step.get("label", "") in ["Frozen", "Petrified"])
		expect.call(not fire.is_empty() and not skip.is_empty(), "%s: Fire and skipped activation keep separate boundaries" % label)
		if not fire.is_empty() and not skip.is_empty(): expect.call(payload(fire[0]).get("enemies", [{}])[0].get(field) == 1 and payload(skip[0]).get("enemies", [{}])[0].get(field) == 0, "%s: skip owns consumed %s counter" % [label, field])
	if bool(case.get("charge_growth", false)): expect.call(int(phase["state"].get("retaliate", {}).get("amount", 0)) > int(before["retaliate"]["amount"]), "%s: fixture changes Retaliate charges inside the trace" % label)
	if bool(case.get("illusion_mid_trace", false)):
		var death_index: int = -1
		for index: int in phase["steps"].size():
			var after: Dictionary = payload(phase["steps"][index])
			if not after.is_empty() and (after.get("illusions", []) as Array).all(func(unit: Dictionary) -> bool: return unit["id"] != before["illusions"][0]["id"] or int(unit.get("hp", 0)) <= 0):
				death_index = index
				break
		expect.call(death_index >= 0 and (phase["steps"] as Array).slice(death_index + 1).any(func(step: Dictionary) -> bool: return step.get("action_type", "") == "death_burst"), "%s: illusion is destroyed before a later traced burst" % label)
	scene.free()

static func run(expect: Callable, cases: Array[Dictionary]) -> void:
	check_types(expect)
	expect.call(Trace.DEFERRED_FIELDS == DEFERRED_FIELDS, "Intermediate snapshot allow-list has explicit independently pinned reasons")
	for case: Dictionary in cases:
		for mode: String in ["turn", "commits", "phase"]:
			var recorder := Recorder.new()
			var before: Dictionary = case["state"]
			var phase: Dictionary = recorder.resolve_enemy_phase_with_steps(before) if mode == "phase" else recorder.resolve_enemy_turn_with_steps(before, 0, mode == "commits")
			check_phase(expect, before, phase, recorder, case, mode)
	print("FIX-15 STATE INVARIANT: %d cases x 3 APIs; full serialized state; final allow-list empty" % cases.size())

static func check_playback(expect: Callable, before: Dictionary, phase: Dictionary, animated: Dictionary, scene: Control, case: Dictionary) -> void:
	var recorder := Recorder.new()
	var independent: Dictionary = recorder.resolve_enemy_turn_with_steps(before, 0, false)
	var label: String = str(case["name"]) + "/production playback"
	expect.call(serialized(phase["state"], true) == serialized(independent["state"], true), "%s: independent resolver is deterministic" % label)
	var submissions: Array[Dictionary]
	submissions.append_array(scene.get("state_submissions"))
	check_order(expect, recorder, submissions, label)
	expect.call(not submissions.is_empty(), "%s: actual presented-state boundaries were observed" % label)
	expect.call(serialized(animated, true) == serialized(phase["state"], true), "%s: actual presented equals resolved at turn end with no exceptions" % label)

static func nearest_fields(presented: Dictionary, expected: Dictionary) -> Array:
	var best: Array = expected.keys()
	for value: Dictionary in presented.values():
		var fields: Array = expected.keys().filter(func(field: Variant) -> bool: return not value.has(field) or canonical(expected[field]) != canonical(value[field]))
		if fields.size() < best.size(): best = fields
	return best
