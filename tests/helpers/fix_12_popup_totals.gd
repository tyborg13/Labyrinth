extends RefCounted

static func actors(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"player": state["player"]}
	for enemy: Dictionary in state.get("enemies", []): result["enemy_%d" % int(enemy["id"])] = enemy
	for illusion: Dictionary in state.get("illusions", []): result["illusion_%d" % int(illusion["id"])] = illusion
	for terrain: Dictionary in state.get("terrain", []): result["terrain_%s" % str(terrain["id"])] = terrain
	return result

# First presentation boundary is the creation baseline, before arrival damage.
# Do not infer a newborn's starting HP from its already-damaged final entry.
static func lifetimes(before: Dictionary, phase: Dictionary) -> Dictionary:
	var result: Dictionary = actors(before).duplicate(true)
	for step: Dictionary in phase.get("steps", []):
		var snapshots: Array = [step.get("move_after", {}), step.get("reaction_after", step.get("en03_after", step.get("en06_after", step.get("trace_state_after", {}))))]
		for after: Dictionary in snapshots:
			if not after.has("player"): continue
			for key: String in actors(after):
				if not result.has(key): result[key] = actors(after)[key].duplicate(true)
	return result

static func defiance_restoration(entry: Dictionary) -> int:
	# String.to_int() also collects later digits in the remaining-charge caption.
	return str(entry["text"]).get_slice("+", 1).get_slice(" ", 0).to_int()

static func check(expect: Callable, before: Dictionary, resolved: Dictionary, animated: Dictionary, submissions: Array, label: String, lifetime_baselines: Dictionary = {}) -> void:
	var totals: Dictionary = {}
	var shown_restoration: int = 0
	for popup: Dictionary in submissions:
		var entry: Dictionary = popup["entry"]
		if entry.get("icon", "") == "defiance": shown_restoration += defiance_restoration(entry)
		var key: String = str(entry.get("reaction_actor_key", ""))
		var field: String = "hp" if str(entry.get("kind", "")) == "damage" else "block" if str(entry.get("text", "")).ends_with(" B") else "stoneskin" if str(entry.get("text", "")).ends_with(" S") else ""
		if field.is_empty(): continue
		if not totals.has(key): totals[key] = {}
		totals[key][field] = int(totals[key].get(field, 0)) + str(entry["text"]).trim_prefix("-").to_int()
	var initial: Dictionary = actors(before) if lifetime_baselines.is_empty() else lifetime_baselines
	var final: Dictionary = actors(resolved)
	var shown: Dictionary = actors(animated)
	expect.call(shown.keys() == final.keys(), "%s: presented actor roster matches resolved spawns, deaths and illusions" % label)
	for key: String in final:
		if not actors(before).has(key): expect.call(shown.get(key, {}) == final[key], "%s: presented spawned actor retains its resolved state" % label)
	var restored: int = 0
	for event: Dictionary in new_defiance_events(before, resolved): restored += int(event["restored_hp"])
	expect.call(shown_restoration == restored, "%s: revival popup total matches current Defiance events" % label)
	for key: String in initial:
		for field: String in ["hp", "block", "stoneskin"]:
			var loss: int = maxi(0, int(initial[key].get(field, 0)) - int(final.get(key, {}).get(field, 0)) + (restored if key == "player" and field == "hp" else 0))
			expect.call(int(totals.get(key, {}).get(field, 0)) == loss, "%s: popup totals match %s %s loss" % [label, key, field])
		expect.call(int(shown.get(key, {}).get("hp", 0)) == int(final.get(key, {}).get("hp", 0)), "%s: animated HP matches %s" % [label, key])
	for key: String in totals: expect.call(initial.has(key), "%s: popup belongs to an actor with a creation baseline" % label)
	for field: String in ["defiance_events", "defiance_event_revision", "defiance_remaining", "defiance_capacity"]:
		expect.call(animated.get(field) == resolved.get(field), "%s: animated %s matches resolver" % [label, field])

static func new_defiance_events(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for event: Dictionary in after.get("defiance_events", []):
		if int(event["revision"]) > int(before.get("defiance_event_revision", 0)): result.append(event)
	return result

# Check the entire enemy turn, rather than just the beam/reaction under test.
# Action analytics expands embedded arrival moves; status analytics owns each
# reaction and cascade. The same comparison therefore checks event attribution.
static func check_phase(expect: Callable, before: Dictionary, phase: Dictionary, label: String) -> void:
	var scene := preload("res://scripts/run_scene.gd").new()
	var events: Array[Dictionary] = scene._analytics_enemy_action_events(phase, {})
	events.append_array(scene._analytics_enemy_status_tick_events(phase, {}))
	var submissions: Array[Dictionary]
	for event: Dictionary in events:
		for group: String in ["target_losses", "enemy_losses", "terrain_losses"]:
			for loss: Dictionary in event["payload"].get(group, []):
				if int(loss.get("defiance_restored", 0)) > 0: submissions.append({"entry": {"icon": "defiance", "text": "DEFIANCE +%d" % int(loss["defiance_restored"])}})
				for field: String in ["hp", "block", "stoneskin"]:
					var amount: int = int(loss.get(field + "_loss", 0))
					if amount <= 0: continue
					submissions.append({"entry": {"reaction_actor_key": loss["key"], "kind": "damage" if field == "hp" else "defense", "text": "-%d%s" % [amount, " B" if field == "block" else " S" if field == "stoneskin" else ""]}})
	check(expect, before, phase["state"], phase["state"], submissions, label + " whole-turn analytics", lifetimes(before, phase))
	scene.free()
