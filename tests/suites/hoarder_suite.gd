extends RefCounted
## spx-09 Ember Hoarder: one focused check per requirement, plus the brief's
## mutations (each check must reject its mutated input). Expected values are
## independent literals copied from the brief, never read back from production.
const Rules = preload("res://scripts/hoarder_room_rules.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const WarbandRooms = preload("res://scripts/warband_room_rules.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Fixture = preload("res://tools/hoarder_inspection.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const DeathBursts = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Hud = preload("res://scripts/battlefield_rule_hud.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
const BIOMES: Array = ["earth", "fire", "air", "ice", "lightning", "shadow"]
const MATRIX_SEEDS: int = 40
const TEST_HP: int = 100
# Brief literals (spx-09).
const EXPECTED_HP_MULTIPLIER: int = 3
const EXPECTED_CLOCK_BY_TIER: Array = [5, 4, 4]
const EXPECTED_SENTENCE_BY_TIER: Array = [
	"The Hoarder slips away with its hoard after your 5th turn.",
	"The Hoarder slips away with its hoard after your 4th turn.",
	"The Hoarder slips away with its hoard after your 4th turn."]
const EXPECTED_TITLE: String = "Defeat the Ember Hoarder before it escapes!"
const EXPECTED_DESCRIPTION: String = "Catch the Hoarder before it slips away."
const EXPECTED_TOOLTIP: String = "Catch the Ember Hoarder before it slips away with its hoard."
const EXPECTED_EMBLEM: String = "res://assets/art/icons/map/ember_hoarder.png"
const EXPECTED_REWARD_LINE: String = "The Hoarder's hoard: +%d embers"
const SPECIAL_EMBER_MULTIPLIER: float = 1.5
const ALLOWED_HOARDER_ACTIONS: Array = ["kindle", "move_away"]

static func run(expect: Callable) -> void:
	_data(expect)
	_unit(expect)
	_tick_rig_alias(expect)
	_matrix(expect)
	_objective_and_panel(expect)
	_keep_away(expect)
	_never_attacks(expect)
	_clock_and_escape(expect)
	_catch(expect)
	_rewards(expect)
	_analytics(expect)
	_batch_api(expect)
	_map_and_measurement(expect)
	_fixture(expect)
	_natural_entry(expect)
	_native_probe_contract(expect)

static func snapshot() -> Dictionary:
	return {"hp": TEST_HP, "max_hp": TEST_HP, "deck_cards": Data.starting_deck(), "equipped_equipment": Data.starting_equipped_equipment()}

static func layout_for(biome: String, tier: int, seed: int, section: int = 0, umbra: int = 0) -> Dictionary:
	var room: Dictionary = Fixture.room_spec(biome, tier)
	room["depth"] = tier + 4 * section
	room["section_index"] = section
	if umbra > 0: room["umbra_depth"] = umbra
	return Rooms.new().generate_room(seed, room, Paths.DIRS_4[seed % 4])

static func battle_for(biome: String, tier: int, seed: int) -> Dictionary:
	return Combat.new().create_combat(seed, layout_for(biome, tier, seed), snapshot())

static func hoarder_index(state: Dictionary) -> int:
	for index: int in range(state["enemies"].size()):
		if str(state["enemies"][index]["type"]) == "ember_hoarder": return index
	return -1

# int-09: director-approved rig alias; all source assets and scale are reused.
static func _tick_rig_alias(expect: Callable) -> void:
	var presentation: GDScript = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
	var action: GDScript = preload("res://scripts/maquette_cutout_runtime/action.gd")
	var actor: GDScript = preload("res://scripts/actor_presentation.gd")
	expect.call(presentation.CREATURES["ember_hoarder"] == "ember_tick" and presentation.asset_directory("ember_hoarder") == presentation.asset_directory("ember_tick"), "Hoarder uses the Tick articulated rig")
	expect.call(presentation.renderer_script("ember_hoarder") == presentation.renderer_script("ember_tick") and action.data_for("ember_hoarder") == action.data_for("ember_tick"), "Hoarder uses the Tick renderer and all motion data")
	expect.call(actor.PROFILES["ember_hoarder"] == actor.PROFILES["ember_tick"] and actor.body_envelope("ember_hoarder") == actor.body_envelope("ember_tick"), "Hoarder uses the Tick floor, height and action bounds")
	expect.call(Data.enemy_def("ember_hoarder")["art_scale"] == Data.enemy_def("ember_tick")["art_scale"], "Hoarder uses the Tick scale")
	var step: Dictionary = {"intent_id": "kindle", "action_type": "status", "enemy_after": {}}
	var clip: String = action.clip_for(step, {"type": "ember_tick"})
	expect.call(not clip.is_empty() and action.clip_for(step, {"type": "ember_hoarder"}) == clip, "Hoarder uses the Tick Kindle clip selector")

# ---------------------------------------------------------------- checks used by mutations

static func data_failures(definition: Dictionary) -> Array[String]:
	var failures: Array[String]
	if not bool(definition.get("enabled", false)): failures.append("not enabled")
	for key: String in ["spill_embers_per_hit", "variants", "how", "gang", "twist", "marks", "move_tiles", "hp_by_tier", "start_distance"]:
		if _has_key(definition, key): failures.append("stub field " + key)
	return failures

static func _has_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		if (value as Dictionary).has(key): return true
		for child: Variant in (value as Dictionary).values():
			if _has_key(child, key): return true
	elif value is Array:
		for child: Variant in value:
			if _has_key(child, key): return true
	return false

static func hp_matches(layout: Dictionary, multiplier: int) -> bool:
	var hoarder: Dictionary = layout["enemies"][0]
	var tick: Dictionary = layout["enemies"][1]
	return str(tick["type"]) == "ember_tick" and int(hoarder["max_hp"]) == multiplier * int(tick["max_hp"]) and int(hoarder["hp"]) == int(hoarder["max_hp"])

static func clock_matches(objective: Dictionary, tier: int) -> bool:
	return int(objective.get("escape_after_player_turns", -1)) == int(EXPECTED_CLOCK_BY_TIER[tier - 1])

static func attack_free(definition: Dictionary) -> bool:
	for intent: Dictionary in definition.get("intents", []):
		for action: Dictionary in intent.get("actions", []):
			if not ALLOWED_HOARDER_ACTIONS.has(str(action.get("type", ""))) or int(action.get("damage", 0)) > 0: return false
	return true

static func dissolve_clean(before: Dictionary, after: Dictionary) -> bool:
	var index: int = hoarder_index(after)
	var hoarder: Dictionary = after["enemies"][index]
	return int(hoarder["hp"]) == 0 and bool(hoarder.get("snare_dissolved", false)) and not bool(hoarder.get("death_burst_resolved", false)) \
		and (after.get("death_burst_events", []) as Array).size() == (before.get("death_burst_events", []) as Array).size() \
		and int(after.get("room_embers", 0)) == int(before.get("room_embers", 0)) and (after.get("death_rewards", []) as Array).size() == (before.get("death_rewards", []) as Array).size()

static func catch_clean(after: Dictionary) -> bool:
	var hoarder_id: int = int(after["enemies"][hoarder_index(after)]["id"])
	for event: Dictionary in after.get("death_burst_events", []):
		if int(event["id"]) != hoarder_id: return false
	for enemy: Dictionary in after["enemies"]:
		if int(enemy["id"]) != hoarder_id and str(enemy["type"]) == "ember_tick" and bool(enemy.get("death_burst_resolved", false)): return false
	return true

static func escape_reward_standard(result: Dictionary, battle_value: Dictionary) -> bool:
	var reward: Dictionary = result["pending_reward"]
	return int(reward["ember_amount"]) == int(battle_value["room_embers"]) and (reward["cards"] as Array).size() == 3 and not reward.has("special_bonus_line") \
		and not str(result.get("notice", "")).contains("hoard")

# ---------------------------------------------------------------- 1. data / enable

static func _data(expect: Callable) -> void:
	var definition: Dictionary = Library.definition("ember_hoarder")
	expect.call(data_failures(definition).is_empty(), "Hoarder data is enabled with no stub fields: %s" % [data_failures(definition)])
	var mutated: Dictionary = definition.duplicate(true)
	mutated["hoarder"]["spill_embers_per_hit"] = 3
	expect.call(not data_failures(mutated).is_empty(), "Mutation: a leftover spill_embers_per_hit fails")
	expect.call(Library.enabled_types().has("ember_hoarder") and Library.enabled_types().has("last_light"), "int-09 enables both approved specials")
	var staged: String = FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/spx/special_encounters.json")
	expect.call(preload("res://tests/helpers/brs01_catalog.gd").matches(staged, FileAccess.get_file_as_string("res://data/special_encounters.json")), "Staged director copy plus the four brs-01 title fields matches the live catalog")
	expect.call(definition["bonus"]["kind"] == "hoard_embers" and float(definition["bonus"]["standard_fight_embers"]) == 1.0, "New hoard_embers bonus kind at one standard fight")
	print("Hoarder data: enabled, stub fields removed, staged bytes retained except four brs-01 title fields")

# ---------------------------------------------------------------- 2. the unit

static func _unit(expect: Callable) -> void:
	var hoarder: Dictionary = Data.enemy_def("ember_hoarder")
	var tick: Dictionary = Data.enemy_def("ember_tick")
	expect.call(hoarder["name"] == "Ember Hoarder", "Hoarder name")
	for field: String in ["art_path", "art_rear_path", "art_scale", "element", "death_burst", "accent"]:
		expect.call(hoarder.get(field) == tick.get(field), "Hoarder shares the Ember Tick's " + field)
	var intents: Array = hoarder["intents"]
	expect.call(intents.size() == 2, "Hoarder has exactly Kindle and Scurry")
	var kindle: Dictionary = {}
	for intent: Dictionary in tick["intents"]:
		if intent["id"] == "kindle": kindle = intent
	expect.call(intents[0] == kindle and int(intents[0]["weight"]) == 1, "Kindle is the Ember Tick's, weight 1")
	var scurry: Array = intents[1]["actions"]
	expect.call(intents[1]["id"] == "scurry" and intents[1]["name"] == "Scurry" and int(intents[1]["time"]) == 4 and int(intents[1]["weight"]) == 2 and scurry.size() == 1 and scurry[0]["type"] == "move_away" and int(scurry[0]["range"]) == 2, "Scurry is move_away 2, Time 4, weight 2: %s" % [intents[1]])
	expect.call(attack_free(hoarder), "Hoarder has no attack")
	var mutated: Dictionary = hoarder.duplicate(true)
	mutated["intents"][1]["actions"].append({"type": "melee", "damage": 2, "range": 1})
	expect.call(not attack_free(mutated), "Mutation: the Hoarder attacking fails (data)")
	print("Hoarder unit: Ember Tick art/element/burst, Kindle + Scurry, no attack")

# ---------------------------------------------------------------- 2/3. generation matrix

static func _matrix(expect: Callable) -> void:
	var generator := Rooms.new()
	var count: int = 0
	for biome: String in BIOMES:
		for tier: int in [1, 2, 3]:
			for seed: int in range(MATRIX_SEEDS):
				var section: int = seed % 6
				var umbra: int = 2 if seed % 5 == 0 else 0
				var layout: Dictionary = layout_for(biome, tier, seed, section, umbra)
				var context: String = "%s/%d/%d/s%d/u%d" % [biome, tier, seed, section, umbra]
				var types: Array = []
				for enemy: Dictionary in layout["enemies"]: types.append(enemy["type"])
				expect.call(types.slice(0, 4) == ["ember_hoarder", "ember_tick", "ember_tick", "ember_tick"], "Roster: Hoarder plus 3 Ember Ticks: " + context)
				var expected_tick: int = DepthHelper.final_hp(generator, layout, "ember_tick")
				for index: int in range(1, 4):
					expect.call(int(layout["enemies"][index]["max_hp"]) == expected_tick, "Brood Ember Tick scaled normally: " + context)
				expect.call(hp_matches(layout, EXPECTED_HP_MULTIPLIER), "Hoarder Health is 3x the Ember Tick's: " + context)
				var sliced: Dictionary = layout.duplicate(true)
				sliced["enemies"] = (layout["enemies"] as Array).slice(0, 4)
				expect.call(WarbandRooms.validate(sliced, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Back-line, screened Warband captain placement: " + context)
				var hoarder: Dictionary = layout["enemies"][0]
				expect.call(bool(hoarder["is_leader"]) and hoarder["display_name"] == "Ember Hoarder" and int(hoarder["stoneskin"]) == 0, "Leader nameplate, no generic leader bonus: " + context)
				expect.call(int(layout["objective"]["leader_id"]) == int(hoarder["id"]) and clock_matches(layout["objective"], tier), "Objective leader and clock: " + context)
				count += 1
	var reference: Dictionary = layout_for("fire", 2, 7)
	var two_x: Dictionary = reference.duplicate(true)
	two_x["enemies"][0]["max_hp"] = 2 * int(two_x["enemies"][1]["max_hp"])
	two_x["enemies"][0]["hp"] = two_x["enemies"][0]["max_hp"]
	expect.call(hp_matches(reference, EXPECTED_HP_MULTIPLIER) and not hp_matches(two_x, EXPECTED_HP_MULTIPLIER), "Mutation: Health 2x fails")
	print("Hoarder generation: %d rooms (6 biomes x 3 tiers x %d seeds, sections I-VI, Umbra depth) checked" % [count, MATRIX_SEEDS])

class DepthHelper:
	static func final_hp(generator: RefCounted, layout: Dictionary, type: String) -> int:
		var hp: int = generator._scaled_enemy_max_hp(type, int(layout["depth"]))
		return preload("res://scripts/depth_rules.gd").enemy_hp(layout, {"type": type}, hp)

# ---------------------------------------------------------------- 4/7. objective, rule and clock display

static func _objective_and_panel(expect: Callable) -> void:
	for tier: int in [1, 2, 3]:
		var battle: Dictionary = battle_for("ice", tier, 11)
		var objective: Dictionary = battle["objective"]
		expect.call(objective["type"] == "kill_leader" and Objectives.title_for_objective(objective) == EXPECTED_TITLE and Objectives.description_for_objective(objective) == EXPECTED_DESCRIPTION, "Objective title and description: tier %d" % tier)
		var panel: Dictionary = Rules.panel(battle)
		expect.call(panel["name"] == "Slip Away" and panel["icon_path"] == EXPECTED_EMBLEM, "Director Slip Away panel identity")
		expect.call(panel["sentence"] == EXPECTED_SENTENCE_BY_TIER[tier - 1], "Rule sentence above the objective: tier %d" % tier)
		var clock: int = int(EXPECTED_CLOCK_BY_TIER[tier - 1])
		expect.call(str(panel["kicker"]).ends_with(" · %d TURNS LEFT" % clock), "Turns left on the rule panel: tier %d" % tier)
		expect.call(clock_matches(objective, tier), "Clock: tier %d" % tier)
	var tier_two: Dictionary = battle_for("ice", 2, 11)["objective"]
	var wrong: Dictionary = tier_two.duplicate(true)
	wrong["escape_after_player_turns"] = 5
	expect.call(clock_matches(tier_two, 2) and not clock_matches(wrong, 2), "Mutation: clock 5 at tier 2 fails")
	var hud := Hud.new()
	var state: Dictionary = battle_for("fire", 2, 3)
	expect.call(hud.set_combat_state(state, Combat.new()) and hud.visible and hud.rule_id == "ember_hoarder", "Rule panel docks for the Hoarder")
	expect.call(_find_label(hud, "RuleSentence") == EXPECTED_SENTENCE_BY_TIER[1], "Rule panel shows the sentence")
	expect.call(_find_label(hud, "RuleKicker").ends_with("· 4 TURNS LEFT"), "Rule panel shows the turns left")
	state["objective"]["player_turns_completed"] = 3
	hud.set_combat_state(state, Combat.new())
	expect.call(_find_label(hud, "RuleKicker").ends_with("· 1 TURN LEFT"), "Rule panel singular turn")
	Rules.slip_away(state)
	expect.call(Rules.panel(state).is_empty(), "Rule panel clears once the Hoarder slips away")
	hud.free()
	print("Hoarder objective, rule sentence and clock checked for all tiers")

static func _find_label(root: Node, name: String) -> String:
	var found: Node = root.find_child(name, true, false)
	return (found as Label).text if found is Label else ""

# ---------------------------------------------------------------- 2. keep-away step

static func _keep_away(expect: Callable) -> void:
	var engine := Combat.new()
	var checked: int = 0
	for biome: String in BIOMES:
		for seed: int in range(6):
			var battle: Dictionary = battle_for(biome, 2, seed)
			var index: int = hoarder_index(battle)
			var hoarder: Dictionary = battle["enemies"][index]
			var occupied: Dictionary = {}
			for enemy: Dictionary in battle["enemies"]: occupied[enemy["pos"]] = true
			for tile: Vector2i in Paths.reachable_tiles(battle["grid"], hoarder["pos"], 2, occupied):
				battle["player"]["pos"] = tile
				var path: Array[Vector2i] = Rules.retreat_path(engine, battle, hoarder)
				var captain_room: Dictionary = battle.duplicate(true)
				captain_room["objective"] = {"special_type": "warband", "keep_distance": {"trigger_range": 2, "step_tiles": 1}}
				expect.call(path == Warband.retreat_path(engine, captain_room, captain_room["enemies"][index]), "Hoarder uses the captain's keep-away step: %s/%d" % [biome, seed])
				if path.size() < 2: continue
				expect.call(path.size() == 2 and Paths.manhattan(path[1], tile) > Paths.manhattan(hoarder["pos"], tile), "Steps exactly 1 tile away: %s/%d" % [biome, seed])
				var plan: Dictionary = engine.enemy_intent_plan(battle, index)
				expect.call(plan.get("warband_retreat", []) == path, "Preview plan includes the keep-away step: %s/%d" % [biome, seed])
				var after: Dictionary = engine.resolve_enemy_turn_with_steps(battle, index)["state"]
				expect.call(Paths.manhattan(after["enemies"][index]["pos"], tile) >= Paths.manhattan(path[1], tile), "Activation takes the step before its intent: %s/%d" % [biome, seed])
				checked += 1
				break
			battle["player"]["pos"] = hoarder["pos"] + Vector2i(3, 0)
	expect.call(checked > 0, "Keep-away step exercised")
	print("Hoarder keep-away: %d staged activations match the Warband captain step" % checked)

# ---------------------------------------------------------------- 2. no attack (behaviour)

static func hoarder_damage_over_rounds(battle: Dictionary, rounds: int) -> int:
	var engine := Combat.new()
	var state: Dictionary = battle.duplicate(true)
	var index: int = hoarder_index(state)
	# Only the Hoarder acts, beside the hero, so any HP loss is the Hoarder's.
	for enemy_index: int in range(state["enemies"].size()):
		if enemy_index != index: state["enemies"][enemy_index]["hp"] = 0
	var dealt: int = 0
	for round: int in range(rounds):
		var neighbours: Array[Vector2i] = Paths.reachable_tiles(state["grid"], state["enemies"][index]["pos"], 1, {})
		if not neighbours.is_empty(): state["player"]["pos"] = neighbours[0]
		var before: int = int(state["player"]["hp"])
		state = engine.resolve_enemy_turn_with_steps(state, index)["state"]
		dealt += before - int(state["player"]["hp"])
	return dealt

static func _never_attacks(expect: Callable) -> void:
	var total: int = 0
	for biome: String in BIOMES:
		for seed: int in range(4):
			total += hoarder_damage_over_rounds(battle_for(biome, 3, seed), 6)
	expect.call(total == 0, "The Hoarder never attacks (behaviour)")
	var mutated: Dictionary = battle_for("fire", 3, 1)
	var index: int = hoarder_index(mutated)
	mutated["enemies"][index]["intent"] = {"id": "mutant_bite", "name": "Bite", "time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}]}
	var engine := Combat.new()
	var neighbours: Array[Vector2i] = Paths.reachable_tiles(mutated["grid"], mutated["enemies"][index]["pos"], 1, {})
	mutated["player"]["pos"] = neighbours[0]
	mutated["objective"]["keep_distance"]["trigger_range"] = 0
	var bitten: Dictionary = engine.resolve_enemy_turn_with_steps(mutated, index, true, false)["state"]
	expect.call(int(bitten["player"]["hp"]) < TEST_HP, "Mutation: the Hoarder attacking fails (behaviour check detects damage)")
	print("Hoarder never attacks across 24 staged fights; attacking mutation detected")

# ---------------------------------------------------------------- 4. clock, dissolve, Defeat All

static func advance(engine: RefCounted, state: Dictionary) -> Dictionary:
	return engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]

static func _clock_and_escape(expect: Callable) -> void:
	var engine := Combat.new()
	for tier: int in [1, 2, 3]:
		for biome: String in BIOMES:
			var state: Dictionary = battle_for(biome, tier, 21)
			var clock: int = int(EXPECTED_CLOCK_BY_TIER[tier - 1])
			var context: String = "%s/%d" % [biome, tier]
			for turn: int in range(1, clock):
				state = advance(engine, state)
				expect.call(Rules.at_large(state) and Rules.turns_left(state) == clock - turn, "Hoarder still at large after turn %d: %s" % [turn, context])
			var before: Dictionary = state.duplicate(true)
			var ended: Dictionary = engine.finish_player_activation(state)
			expect.call(not Rules.at_large(ended) and bool(ended["objective"]["hoarder_escaped"]), "Slips away at the end of player turn %d: %s" % [clock, context])
			expect.call(dissolve_clean(before, ended), "Sealbinder dissolve: no death burst, no reward: " + context)
			expect.call(ended["objective"]["type"] == "kill_all" and Objectives.title_for_objective(ended["objective"]) == "Defeat All Enemies" and Objectives.description_for_objective(ended["objective"]) == "Defeat every enemy.", "Fight continues as Defeat All: " + context)
			expect.call(engine.combat_outcome(ended) == "" and not bool(ended["objective"]["goal_met"]), "Remaining brood keep the fight going: " + context)
			var silent: Dictionary = preload("res://scripts/snare_room_rules.gd").sound_snapshot(ended, {})
			expect.call(not (silent["state"]["enemies"] as Array).any(func(enemy: Dictionary) -> bool: return str(enemy["type"]) == "ember_hoarder"), "Slipping away is silent: " + context)
			var later: Dictionary = advance(engine, ended)
			expect.call(int(later["objective"]["player_turns_completed"]) == clock and int(later["enemies"][hoarder_index(later)]["hp"]) == 0, "Escape is final: " + context)
	var reference_before: Dictionary = battle_for("fire", 2, 21)
	for turn: int in range(3): reference_before = advance(engine, reference_before)
	var reference_after: Dictionary = engine.finish_player_activation(reference_before)
	var burst: Dictionary = DeathBursts.on_death(engine, reference_after.duplicate(true), reference_after["enemies"][hoarder_index(reference_after)])
	expect.call(dissolve_clean(reference_before, reference_after) and not dissolve_clean(reference_before, burst), "Mutation: a death burst on dissolve fails")
	print("Hoarder clock: 18 biome/tier fights slip away after turns 5/4/4, silently, then Defeat All")

# ---------------------------------------------------------------- 5. catch

static func _catch(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in BIOMES:
		for tier: int in [1, 2, 3]:
			var state: Dictionary = battle_for(biome, tier, 31)
			var index: int = hoarder_index(state)
			# A 1-HP brood Tick beside the Hoarder: were it not scattered first, the
			# Hoarder's own burst would kill it and its burst would register.
			_adjacent_brood(state, index)
			var caught: Dictionary = engine._damage_enemy(state, index, 999, true, true, false, false)
			var context: String = "%s/%d" % [biome, tier]
			expect.call(engine.combat_outcome(caught) == "victory" and bool(caught["objective"]["hoarder_caught"]) and bool(caught["objective"]["goal_met"]), "Killing the Hoarder wins at once: " + context)
			expect.call(int(caught["objective"]["hoarder_caught_turn"]) == 1, "Catch turn recorded: " + context)
			var fled: int = 0
			for enemy: Dictionary in caught["enemies"]:
				if str(enemy["type"]) == "ember_tick" and bool(enemy.get("warband_fled", false)): fled += 1
			expect.call(fled == 3 and bool(caught["objective"]["completed_by_leader"]), "Brood scatters by the Warband break: " + context)
			var own: Array = (caught.get("death_burst_events", []) as Array).filter(func(event: Dictionary) -> bool: return int(event["id"]) == int(state["enemies"][index]["id"]))
			expect.call(own.size() == 1 and int(own[0]["damage"]) == 4, "Hoarder's own death burst fires as an Ember Tick's: " + context)
			expect.call(catch_clean(caught), "Brood death bursts suppressed after the catch: " + context)
	var reference: Dictionary = engine._damage_enemy(battle_for("fire", 2, 31), 0, 999, true, true, false, false)
	var leaked: Dictionary = DeathBursts.on_death(engine, reference.duplicate(true), reference["enemies"][1])
	expect.call(catch_clean(reference) and not catch_clean(leaked), "Mutation: brood bursts after a catch fail")
	# Batched simultaneous deaths: the queued brood burst cannot outlive the break.
	var batch: Dictionary = battle_for("lightning", 2, 5)
	batch["_surface_damage_batch"] = true
	batch = engine._damage_enemy(batch, 1, 999, true, true, false, false)
	batch = engine._damage_enemy(batch, 0, 999, true, true, false, false)
	batch["_surface_damage_batch"] = false
	batch = engine._flush_surface_deaths(batch)
	expect.call(engine.combat_outcome(batch) == "victory" and catch_clean(batch), "Batched brood/Hoarder deaths: brood burst suppressed")
	print("Hoarder catch: 18 fights win at once, brood scatter silently, own burst fires")

static func _adjacent_brood(state: Dictionary, index: int) -> void:
	var occupied: Dictionary = {state["player"]["pos"]: true}
	for enemy: Dictionary in state["enemies"]: occupied[enemy["pos"]] = true
	for direction: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = state["enemies"][index]["pos"] + direction
		if occupied.has(tile) or not Paths.is_passable(state["grid"], tile): continue
		state["enemies"][1]["pos"] = tile
		state["enemies"][1]["hp"] = 1
		return

# ---------------------------------------------------------------- 6. rewards

static func _rewards(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for tier: int in [1, 2, 3]:
		var run: Dictionary = Fixture.build(engine, combat, source, {"hoarder_biome": "earth", "hoarder_tier": tier})
		var battle_value: Dictionary = combat._damage_enemy(run["combat_state"], 0, 999, true, true, false, false)
		var room: Dictionary = engine.room_metadata(run, run["current_room"])
		var base: int = int(room["special_starting_reward_embers"])
		var result: Dictionary = engine.finish_combat(run, battle_value)
		var hoard: int = base
		var expected: int = int(floor(base * SPECIAL_EMBER_MULTIPLIER + 0.5)) + hoard
		expect.call(int(result["pending_reward"]["ember_amount"]) == expected, "Caught: x1.5 embers plus the hoard (one standard fight): tier %d" % tier)
		expect.call((result["pending_reward"]["cards"] as Array).size() == 4 and (result["pending_reward"]["cards"] as Array).any(func(id: String) -> bool: return Data.card_rarity(id) in ["rare", "epic", "legendary"]), "Caught: 4 card choices with a Rare: tier %d" % tier)
		expect.call(result["pending_reward"].get("special_bonus_line", "") == EXPECTED_REWARD_LINE % hoard and str(result["notice"]).contains(EXPECTED_REWARD_LINE % hoard), "Reward line: tier %d" % tier)
		expect.call(engine.finish_combat(result, battle_value) == result, "The hoard cannot pay twice: tier %d" % tier)
		# Escape: standard rewards and no special bonus.
		var escaped_run: Dictionary = Fixture.build(engine, combat, source, {"hoarder_biome": "earth", "hoarder_tier": tier})
		var escaped: Dictionary = escaped_run["combat_state"]
		Rules.slip_away(escaped)
		for index: int in range(escaped["enemies"].size()):
			if int(escaped["enemies"][index]["hp"]) > 0: escaped = combat._damage_enemy(escaped, index, 999, true, true, false, false)
		expect.call(combat.combat_outcome(escaped) == "victory" and int(escaped["room_embers"]) > 0, "Escaped fight is won as Defeat All: tier %d" % tier)
		var standard: Dictionary = engine.finish_combat(escaped_run, escaped)
		expect.call(escape_reward_standard(standard, escaped), "Escape pays standard rewards, no hoard: tier %d" % tier)
		var forced: Dictionary = escaped.duplicate(true)
		forced["objective"]["goal_met"] = true
		var paid: Dictionary = engine.finish_combat(escaped_run, forced)
		expect.call(not escape_reward_standard(paid, escaped), "Mutation: the hoard paid on escape fails: tier %d" % tier)
	print("Hoarder rewards: caught pays 4 cards, x1.5 and the hoard; escape pays standard")

# ---------------------------------------------------------------- 9. analytics

static func _analytics(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	var caught_run: Dictionary = Fixture.build(engine, combat, source, {"hoarder_biome": "air", "hoarder_tier": 2})
	caught_run["combat_state"] = advance(combat, caught_run["combat_state"])
	var caught: Dictionary = combat._damage_enemy(caught_run["combat_state"], 0, 999, true, true, false, false)
	var escaped_run: Dictionary = Fixture.build(engine, combat, source, {"hoarder_biome": "air", "hoarder_tier": 2})
	var escaped: Dictionary = escaped_run["combat_state"]
	Rules.slip_away(escaped)
	for index: int in range(escaped["enemies"].size()):
		if int(escaped["enemies"][index]["hp"]) > 0: escaped = combat._damage_enemy(escaped, index, 999, true, true, false, false)
	expect.call(Rules.analytics(caught) == {"hoarder_result": "caught", "hoarder_caught_turn": 2}, "Analytics: caught on turn 2")
	expect.call(Rules.analytics(escaped) == {"hoarder_result": "escaped", "hoarder_caught_turn": 0}, "Analytics: escaped")
	expect.call(Rules.analytics(battle_for("air", 2, 1)) == {"hoarder_result": "", "hoarder_caught_turn": 0}, "Analytics: still at large")
	expect.call(Rules.analytics({"objective": {"type": "kill_all"}}) == {"hoarder_result": "", "hoarder_caught_turn": 0}, "Analytics: outside a Hoarder")
	var previous_dir: String = Analytics.storage_dir()
	Analytics.set_storage_dir("user://spx09-analytics")
	for pair: Array in [[caught_run, caught, "caught", 2], [escaped_run, escaped, "escaped", 0]]:
		var result: Dictionary = engine.finish_combat(pair[0], pair[1])
		for caller: String in ["UI", "console"]:
			Analytics.clear_storage()
			var store := Analytics.new()
			var host = preload("res://scripts/run_scene.gd").new() if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
			host.set("_analytics_store", store)
			host.set("_progression", pair[0]["progression"].duplicate(true))
			host.set("_run_state", result.duplicate(true))
			host.set("_combat_state", {})
			if caller == "UI": host._analytics_log_combat_transition(pair[0], "hoarder_test", pair[1])
			else: host._log_combat_transition(pair[0], "hoarder_test", pair[1])
			var count: int = 0
			for event: Dictionary in Analytics.load_all_events():
				if event["event_type"] != "combat_ended": continue
				count += 1
				expect.call(event["payload"]["hoarder_result"] == pair[2] and int(event["payload"]["hoarder_caught_turn"]) == int(pair[3]) and str(event.get("special_type", "")) == "ember_hoarder", "Additive Hoarder analytics fields (%s): %s" % [pair[2], caller])
			expect.call(count == 1, "One combat_ended event: " + caller)
			host.free()
	Analytics.clear_storage()
	Analytics.set_storage_dir(previous_dir)
	print("Hoarder analytics: caught/escaped and catch turn on UI and console combat_ended")

# ---------------------------------------------------------------- batch API

static func _batch_api(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle_for("shadow", 2, 9)
	var first: Dictionary = engine.resolve_enemy_phase_with_steps(state)["state"]
	expect.call(int(first["objective"]["player_turns_completed"]) == 1 and not bool(first["objective"]["enemy_round_pending"]), "Batch API advances the clock once")
	var through: Dictionary = engine.finish_player_activation(state)
	var resumed: Dictionary = engine.resolve_enemy_phase_with_steps(through)["state"]
	expect.call(int(resumed["objective"]["player_turns_completed"]) == 1, "Batch API after activation end does not double count")
	print("Hoarder legacy batch API shares the clock")

# ---------------------------------------------------------------- 8/10. map and measurement cohort

static func _map_and_measurement(expect: Callable) -> void:
	var definition: Dictionary = Library.definition("ember_hoarder")
	expect.call(definition["break_line"] == "The brood scatters!", "Director brood scatter line")
	expect.call(definition["emblem"] == EXPECTED_EMBLEM and FileAccess.file_exists(EXPECTED_EMBLEM), "Existing approved emblem")
	expect.call(preload("res://scripts/room_icon_library.gd").ROOM_TYPE_ICON_PATHS.get("special_ember_hoarder", "") == EXPECTED_EMBLEM, "Map room icon registry uses the emblem")
	var node: Dictionary = {"type": "special", "special_type": "ember_hoarder", "special_variant": "fire"}
	expect.call(Library.display_name(node) == "Ember Hoarder" and Library.tooltip_line(node) == EXPECTED_TOOLTIP, "Map name and tooltip")
	for type: String in ["last_light", "ember_hoarder"]:
		expect.call(Sweep.special_cohort(type, 7) and not Sweep.special_cohort(type, 6), "Unified measurement cohort respects first layout revision: " + type)
		expect.call(Sweep.room_matches({"type": "special", "special_type": type}, type), "Unified measurement cohort matches: " + type)
	expect.call(Sweep.special_cohort("snare", 6) and Sweep.special_cohort("umbral_snare", 6) and not Sweep.special_cohort("warband", 7), "Unified API retains the Snare alias and baseline bins")
	expect.call(Sweep.special_cohort("ember_hoarder", 7) and Sweep.room_matches(node, "ember_hoarder") and not Sweep.room_matches(node, "warband"), "Measurement cohort selects Hoarder rooms")
	var found: int = 0
	var placed_sections: int = 0
	for seed: int in range(1, 13):
		var map: Dictionary = Sweep.map_for_seed(seed, 7)
		found += Sweep.samples(map, PackedStringArray(["ember_hoarder"])).size()
		for section: Dictionary in map["map_sections"]:
			for room: Dictionary in map["rooms"].values():
				if int(room["section_index"]) == int(section["index"]) and str(room.get("special_type", "")) == "ember_hoarder":
					placed_sections += 1
					expect.call(int(room["map_step"]) >= 3, "Hoarder obeys the special first step")
					break
	expect.call(found > 0 and placed_sections > 0, "Revision-7 maps place Ember Hoarders (%d sections, %d samples)" % [placed_sections, found])
	var frozen: Array[String] = Library._enabled_types(Library.catalog(), 6)
	expect.call(not frozen.has("ember_hoarder") and frozen.has("warband") and frozen.has("umbral_snare") and Library._enabled_types(Library.catalog(), 7).has("ember_hoarder"), "Only the current map revision places the Hoarder")
	for seed: int in range(1, 13):
		var legacy: Dictionary = Sweep.map_for_seed(seed, 6)
		expect.call(not legacy["rooms"].values().any(func(room: Dictionary) -> bool: return str(room.get("special_type", "")) == "ember_hoarder"), "Saved revision-6 maps regenerate without a Hoarder: seed %d" % seed)
	print("Hoarder map: emblem, tooltip, placement and measurement cohort checked (%d sections over 12 seeds)" % placed_sections)

# ---------------------------------------------------------------- 11. inspection fixture

static func _fixture(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	expect.call(not Fixture.validate({"hoarder_biome": "moon"}).is_empty() and not Fixture.validate({"hoarder_tier": 4}).is_empty() and not Fixture.validate({"hoarder_case": "break"}).is_empty(), "Fixture rejects unknown options")
	for biome: String in BIOMES:
		for tier: int in [1, 2, 3]:
			for study: String in ["pre_battle", "encounter"]:
				var state: Dictionary = Fixture.build(engine, combat, source, {"hoarder_biome": biome, "hoarder_tier": tier, "hoarder_case": study})
				var context: String = "%s/%d/%s" % [biome, tier, study]
				var layout: Dictionary = state["current_room_layout"]
				expect.call(str(layout["special_type"]) == "ember_hoarder" and str(layout["enemies"][0]["type"]) == "ember_hoarder", "Fixture builds a Hoarder room: " + context)
				if study == "pre_battle":
					expect.call(state["mode"] == "pre_battle" and bool(state["pre_battle_pending"]) and state["combat_state"].is_empty(), "Pre-battle fixture: " + context)
					var prepared: Dictionary = Fixture.prepared(engine, combat, state)
					expect.call(Rules.active(prepared["combat_state"]), "Pre-battle prepared combat: " + context)
				else:
					expect.call(state["mode"] == "combat" and Rules.at_large(state["combat_state"]), "Encounter fixture: " + context)
	print("Hoarder inspection fixture: 6 biomes x 3 tiers x pre_battle/encounter")

# ---------------------------------------------------------------- production entry

static func _natural_entry(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var run: Dictionary = {}
	var selected: Dictionary = {}
	for seed: int in range(1, 30):
		run = engine.create_new_run(seed, Store.default_data())
		for room: Dictionary in run["rooms"].values():
			if room.get("special_type", "") != "ember_hoarder": continue
			for parent: Dictionary in run["rooms"].values():
				for link: Dictionary in parent["connections"]:
					if link["coord"] == room["coord"]:
						selected = room
						run["current_room"] = parent["coord"]
						parent["cleared"] = true
						break
				if not selected.is_empty(): break
			if not selected.is_empty(): break
		if not selected.is_empty(): break
	expect.call(not selected.is_empty(), "Enabled Hoarder appears on a production map")
	if selected.is_empty(): return
	run["mode"] = "room"
	run = engine.move_to_pre_battle(run, selected["coord"])
	expect.call(run["mode"] == "pre_battle", "Natural Hoarder uses normal pre-battle entry")
	var prepared: Dictionary = engine.prepare_pre_battle_combat(run)
	expect.call(engine.prepared_pre_battle_matches_input(prepared, run), "Natural Hoarder prepared layout matches input")
	run = engine.begin_pre_battle_combat(run, prepared)
	expect.call(Rules.at_large(run["combat_state"]), "Natural Hoarder combat starts at large")
	var caught: Dictionary = combat._damage_enemy(run["combat_state"], hoarder_index(run["combat_state"]), 999, true, true, false, false)
	var result: Dictionary = engine.finish_combat(run, caught)
	expect.call(result["pending_reward"]["cards"].size() == 4 and result["pending_reward"].has("special_bonus_line"), "Natural Hoarder catch meets its special goal")
	print("Hoarder production entry: map node, pre-battle, combat and catch reward")

# ---------------------------------------------------------------- native probe (headless preconditions)

static func _native_probe_contract(expect: Callable) -> void:
	var probe: GDScript = load("res://tests/hoarder_probe.gd")
	expect.call(probe != null and probe.can_instantiate(), "Native probe compiles")
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/proof_contracts/spx09_hoarder.json"))
	expect.call(int(contract["min_images"]) == 10 and (contract["required_images"] as Array).size() == 10, "Proof contract requires all ten captures")
	var engine := Run.new()
	var combat := Combat.new()
	for variant: Dictionary in probe.VARIANTS:
		var state: Dictionary = probe.fixture_state(engine, combat, variant)
		var battle: Dictionary = state["combat_state"]
		var clock: int = int(battle["objective"]["escape_after_player_turns"])
		for turn: int in range(clock - 1): battle = advance(combat, battle)
		expect.call(Rules.at_large(battle) and Rules.turns_left(battle) == 1, "Probe reaches its last-turn capture: %s" % [variant])
		var slipped: Dictionary = advance(combat, battle)
		expect.call(bool(slipped["objective"]["hoarder_escaped"]) and combat.combat_outcome(slipped) == "", "Probe's slipped-away capture has brood left: %s" % [variant])
	print("Hoarder native probe: compiles; headless preconditions for all ten captures hold")
