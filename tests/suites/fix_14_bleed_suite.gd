extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Feedback = preload("res://tests/suites/fix_14_feedback_suite.gd")
const Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
const Trace = preload("res://scripts/reaction_presentation_trace.gd")
# Reviewer fixtures and an early lethal-payment guard, all test-only.
const BLEED: int = 2
const SURVIVING_HP: int = 10
const LETHAL_ATTACK_HP: int = 8
const PARTNER := Vector2i(6, 4)
const HERO := Vector2i(4, 4)
const STATUS_TICK_AMOUNT: int = 3
const OTHER_HP_LOSS: int = 2

static func check_status_tick_feedback(scene: Control, expect: Callable) -> void:
	for actor: String in ["player", "enemy_1"]:
		for label: String in ["Fire", "Bleed"]:
			var step: Dictionary = {"kind": "status_damage", "actor_key": actor, "tile": HERO, "amount": STATUS_TICK_AMOUNT, "label": label}
			if actor != "player": step["enemy_losses"] = [{"key": actor, "tile": HERO, "hp_loss": STATUS_TICK_AMOUNT, "block_loss": 2, "stoneskin_loss": 1}]
			var floats: Array = scene._floating_texts_for_step(step)
			var icon: String = "surface_fire" if label == "Fire" else "bleed"
			expect.call(not floats.is_empty(), "%s %s produces its existing loss numbers" % [actor, label])
			for entry: Dictionary in floats:
				expect.call(entry.get("icon", "") == icon, "%s %s decorates every owned Health/Block/Stoneskin loss" % [actor, label])
	var before: Dictionary = Base.Fixtures.state([])
	before["player"].merge({"hp": 10, "bleed": STATUS_TICK_AMOUNT, "block": 0, "stoneskin": 0}, true)
	var after: Dictionary = Base.Combat.new()._trigger_player_bleed_for_action(before.duplicate(true), {"type": "move"})
	var bleed: Array = scene._player_loss_floating_texts(before, after)
	expect.call(bleed.size() == 1 and bleed[0].get("icon", "") == "bleed" and bleed[0]["text"] == "-3", "An actual hero Bleed payment carries the Bleed cause icon")
	var mixed: Dictionary = after.duplicate(true)
	mixed["player"]["hp"] -= OTHER_HP_LOSS
	var mixed_floats: Array = scene._player_loss_floating_texts(before, mixed)
	expect.call(mixed_floats.size() == 2 and mixed_floats[0]["text"] == "-3" and mixed_floats[0].get("icon", "") == "bleed" and mixed_floats[1]["text"] == "-2" and not mixed_floats[1].has("icon"), "Mixed damage attributes only the actual Bleed payment, preserving the total loss")
	var ordinary: Array = scene._player_loss_floating_texts(after, mixed)
	expect.call(ordinary.size() == 1 and not ordinary[0].has("icon"), "An earlier Bleed payment cannot label later damage")
	var same_tile: Dictionary = {"kind": "status_damage", "label": "Fire", "actor_key": "enemy_1", "tile": HERO, "reaction_after": {}, "enemy_losses": [{"key": "enemy_1", "tile": HERO, "hp_loss": 3}, {"key": "enemy_2", "tile": HERO, "hp_loss": 1}]}
	var cascade: Array = scene._floating_texts_for_step(same_tile)
	expect.call(cascade.size() == 2 and cascade[0].get("icon", "") == "surface_fire" and not cascade[1].has("icon"), "A traced cascade never inherits another actor's cause icon on the same tile")
	var previous_run_path: String = Base.Fixtures.Store._run_storage_path
	Base.Fixtures.Store.set_run_storage_path("user://status_tick_receipts_test.save")
	var saved_run: Dictionary = Base.Fixtures.Run.new().create_new_run(Base.Fixtures.TEST_SEED, Base.Fixtures.Store.default_data())
	saved_run["mode"] = "combat"
	saved_run["combat_state"] = after
	expect.call(Base.Fixtures.Store.save_run_state(saved_run), "Additive status receipt save succeeds")
	expect.call(Base.Fixtures.Store.load_saved_run().get("combat_state", {}).get("player_bleed_loss_totals", {}) == after["player_bleed_loss_totals"], "Status receipts survive save/load without replaying a payment")
	Base.Fixtures.Store.set_run_storage_path(previous_run_path)

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func run(expect: Callable) -> void:
	var engine := Base.Combat.new()
	for case: Dictionary in cases():
		for mode: String in ["turn", "commits", "phase"]:
			var before: Dictionary = case["state"]
			var phase: Dictionary = engine.resolve_enemy_phase_with_steps(before) if mode == "phase" else engine.resolve_enemy_turn_with_steps(before, 0, mode == "commits")
			var label: String = "%s/%s" % [case["name"], mode]
			Totals.check_phase(expect, before, phase, label)
			Feedback._check_intermediates(expect, before, phase, label)
			var payments: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return bool(step.get("traced_bleed", false)))
			var early_death: bool = before["enemies"][0]["hp"] == BLEED
			expect.call(payments.size() == (1 if early_death else 2), "%s: each charged Bleed has one owning step" % label)
			if payments.is_empty(): continue
			expect.call(payments[0]["action_type"] == "move_toward" and payments[0]["reaction_after"]["enemies"][0]["pos"] == before["enemies"][0]["pos"], "%s: move Bleed plays at the original tile" % label)
			if not early_death and payments.size() == 2:
				var attack_index: int = phase["steps"].find(payments[1])
				var arrival_indices: Array[int]
				for index: int in range(phase["steps"].size()):
					if phase["steps"][index].has("cascade") or bool(phase["steps"][index].get("traced_arrival", false)): arrival_indices.append(index)
				expect.call(not arrival_indices.is_empty() and arrival_indices.all(func(index: int) -> bool: return index < attack_index), "%s: attack Bleed follows every arrival boundary" % label)
				expect.call(payments[1]["action_type"] == "ranged" and payments[1]["reaction_after"]["enemies"][0]["pos"] == phase["state"]["enemies"][0]["pos"], "%s: attack Bleed owns the post-move snapshot" % label)
			var survives: bool = before["enemies"][0]["hp"] == SURVIVING_HP
			expect.call(phase["state"]["enemies"][0]["hp"] == (1 if survives else 0), "%s: reviewer final actor HP" % label)
			var attacks: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("actor_key", "")) == "enemy_1" and (step.has("en03_after") or step.has("en06_after")))
			expect.call(attacks.size() == (1 if survives else 0), "%s: lethal Bleed has no later actor attack" % label)
			for attack: Dictionary in attacks:
				expect.call(Base.hp_loss(attack.get("target_losses", []), "enemy_1") == 0, "%s: attack losses start after attack Bleed" % label)
			_check_defeats(expect, before, phase, label)
			if mode == "turn": print("FIX-14 BLEED TRACE: %s; actor %d->%d; payments=%s; attacks=%d" % [case["name"], before["enemies"][0]["hp"], phase["state"]["enemies"][0]["hp"], payments.map(func(step: Dictionary) -> int: return int(step["amount"])), attacks.size()])

static func _check_defeats(expect: Callable, before: Dictionary, phase: Dictionary, label: String) -> void:
	var current: Dictionary = Trace.snapshot(before)
	var defeats: Dictionary = {}
	for step: Dictionary in phase["steps"]:
		var after: Dictionary = step.get("reaction_after", step.get("en03_after", step.get("en06_after", {})))
		if after.is_empty(): continue
		for key: String in Totals.actors(current):
			var hp: int = int(Totals.actors(current)[key].get("hp", 0))
			var next_hp: int = int(Totals.actors(after)[key].get("hp", 0))
			expect.call(next_hp <= hp, "%s: snapshots never resurrect %s" % [label, key])
			if hp > 0 and next_hp <= 0: defeats[key] = int(defeats.get(key, 0)) + 1
		current = after
	for key: String in Totals.actors(before):
		var died: bool = int(Totals.actors(phase["state"])[key].get("hp", 0)) <= 0
		expect.call(int(defeats.get(key, 0)) == (1 if died else 0), "%s: one owning defeat boundary for %s" % [label, key])

static func check_playback(expect: Callable, before: Dictionary, phase: Dictionary, scene: Control, label: String) -> void:
	if not label.contains("bleed_"): return
	var bleed_popups: Array = (scene.get("popup_submissions") as Array).filter(func(popup: Dictionary) -> bool: return str(popup["phase"]).begins_with("bleed_") and popup["entry"].get("kind", "") == "damage" and popup["entry"].get("reaction_actor_key", "") == "enemy_1")
	var early_death: bool = before["enemies"][0]["hp"] == BLEED
	expect.call(bleed_popups.size() == (1 if early_death else 2), "%s: production plays each Bleed popup once" % label)
	for popup: Dictionary in bleed_popups:
		expect.call(popup["entry"].get("icon", "") == "bleed", "%s: production retains the existing Bleed popup icon" % label)
	for move: Dictionary in scene.get("move_starts"):
		expect.call(int(move["hp"]) > 0 and move["tile"] == move["from"], "%s: production movement starts alive at its actual source tile" % label)
	if early_death: expect.call((scene.get("move_starts") as Array).is_empty(), "%s: lethal move Bleed prevents movement" % label)
	if phase["state"]["enemies"][0]["hp"] == 0:
		expect.call((scene.get("defeat_owners") as Array).has({"key": "enemy_1", "phase": "bleed_move" if early_death else "bleed_attack"}), "%s: production defeat belongs to lethal Bleed" % label)
	var shown_loss: int = 0
	for popup: Dictionary in scene.get("popup_submissions"):
		if popup["entry"].get("kind", "") == "damage" and popup["entry"].get("reaction_actor_key", "") == "enemy_1": shown_loss += str(popup["entry"]["text"]).trim_prefix("-").to_int()
	print("FIX-14 BLEED PLAYBACK: %s; actor %d->%d; shown loss=%d; Bleed popups=%s; moves=%s; defeats=%s" % [label, before["enemies"][0]["hp"], phase["state"]["enemies"][0]["hp"], shown_loss, bleed_popups.map(func(popup: Dictionary) -> String: return str(popup["entry"]["text"])), scene.get("move_starts"), scene.get("defeat_owners")])
