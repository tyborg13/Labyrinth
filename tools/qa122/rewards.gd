extends RefCounted
## Compare event text with committed rewards and exercise omen and relic hooks.

const Fx = preload("res://tools/qa122/fixture.gd")
const Cards = preload("res://tools/qa122/cards.gd")
const Data = Fx.Data
const Events = preload("res://scripts/event_rules.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Difficulty = preload("res://scripts/difficulty_tier_rules.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const PatternRules = preload("res://scripts/pattern_text.gd")
const SeedOffsets: Array = [0, 1, 2]
const TightHealthMargin: int = 1
const FullDrop: int = 10
const RelicCards: Array = ["quick_stab", "wild_lunge", "throwing_net", "seers_candle",
	"crimson_draught", "brace", "bone_dart", "shadow_step", "guarded_step", "pale_spark",
	"storm_jar", "magma_vent", "crystal_mantle", "caltrops", "petrify"]
const RunFields: Array = ["player_hp", "player_max_hp", "held_embers", "defiance_remaining",
	"item_inventory", "equipped_items", "equipped_equipment", "equipment_inventory",
	"relics", "reward_cards", "attuned_magic_cards", "omens"]

static func _run_fields(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in RunFields:
		if state.has(field): result[field] = state[field]
	return result

static func events(filter: String) -> Array:
	var result: Array = []
	var run := Runs.new()
	var template: Dictionary = run.create_new_run(Fx.Seed, preload("res://scripts/progression_store.gd").default_data())
	for id: String in Data.events():
		if not filter.is_empty() and id != filter: continue
		for seed_offset: int in SeedOffsets:
			var state: Dictionary = EventFixture.fixture(id, true, template)
			state["seed"] = Fx.Seed + seed_offset
			var maximum: int = int(state["player_max_hp"])
			state["player_hp"] = [maximum >> 1, maximum - TightHealthMargin, TightHealthMargin][seed_offset]
			for choice: Dictionary in Data.event_def(id)["choices"]:
				var key: String = str(choice["id"])
				var blocked: String = Events.choice_block_reason(state, id, key)
				var row: Dictionary = {"id": id, "choice": key, "seed": state["seed"], "hp": state["player_hp"],
					"max_hp": maximum, "blocked": blocked}
				if blocked.is_empty():
					var resolved: Dictionary = Events.choose_event(state, key, run)
					var continued: Dictionary = Events.continue_event(resolved)
					row.merge({"preview": Events.preview_lines(state, id, key),
						"outcome_lines": Events.outcome_lines(resolved), "outcomes": resolved["event_state"].get("outcomes", []),
						"delta": Fx.delta(_run_fields(state), _run_fields(resolved)),
						"pending_reward": continued.get("pending_reward", {})})
				result.append(row)
	return result

static func omen_catalog(engine: RefCounted, filter: String) -> Array:
	var result: Array = []
	var baseline: Dictionary = Fx.state(engine)
	for id: String in Data.omens():
		if not filter.is_empty() and id != filter: continue
		var gained: Dictionary = Omens.add({"seed": Fx.Seed}, id)
		var definition: Dictionary = Omens.active(gained)[0]
		var started: Dictionary = Fx.state(engine, Fx.Foe, "crawler", gained)
		var duration: Array = []
		var ticking: Dictionary = gained
		while not Omens.active(ticking).is_empty():
			duration.append(Omens.active(ticking)[0]["fights_left"])
			ticking = Omens.tick(ticking)
		var row: Dictionary = {"id": id, "text": Inline.plain_text(definition["description"]),
			"fights": definition["fights_left"], "countdown": duration,
			"start": Fx.delta(Fx.receipt(baseline), Fx.receipt(started)),
			"drop_base": FullDrop, "drop": Omens.ember_drop(started, FullDrop)}
		if id == "hunted": row["roster"] = _hunted(engine, gained)
		if id == "deepening_dark":
			var dark_layout: Dictionary = Fx.layout()
			var edge: String = engine.UMBRA_STAGE_ORDER[-2]
			dark_layout["umbra_stage"] = edge
			var dark: Dictionary = engine.create_combat(Fx.Seed, dark_layout, gained.merged({"hp": Fx.Health, "max_hp": Fx.Health}))
			row["dark_stage"] = [edge, dark["umbra"]["stage"]]
		result.append(row)
	return result

static func _hunted(engine: RefCounted, gained: Dictionary) -> Array:
	var rooms := Rooms.new()
	var result: Array = []
	for capped: bool in [false, true]:
		var layout: Dictionary = Fx.layout()
		layout["objective"] = {"initial_enemy_count": 1}
		if capped:
			var max_starters: int = Difficulty.MAX_STARTERS
			for index: int in range(1, max_starters):
				layout["enemies"].append(Fx.enemy(Vector2i(index + 1, 2), index + 1))
		var before: int = layout["enemies"].size()
		var room: Dictionary = {"type": "combat", "coord": layout["coord"], "depth": 1,
			"element": "none", "omen_extra_enemies": Omens.amount(gained, "extra_enemies")}
		rooms._add_omen_enemies(layout, room, Fx.Seed)
		Difficulty.finalize(layout)
		var combat: Dictionary = engine.create_combat(Fx.Seed, layout, {"hp": Fx.Health, "max_hp": Fx.Health})
		result.append({"capped": capped, "before": before, "after": layout["enemies"].size(),
			"compensations": layout.get("omen_enemy_hp_compensations", 0), "foe_hp": combat["enemies"][0]["max_hp"]})
	return result

static func relics(engine: RefCounted, filter: String) -> Array:
	var result: Array = []
	var baseline: Dictionary = Fx.state(engine)
	var baseline_end: Dictionary = engine.finish_player_activation(baseline)
	for id: String in Data.relic_ids():
		if not filter.is_empty() and id != filter: continue
		var definition: Dictionary = Data.relic_def(id)
		var started: Dictionary = Fx.state(engine, Fx.Foe, "crawler", {"relics": [id]})
		var ended: Dictionary = engine.finish_player_activation(started)
		var trials: Array = []
		for card_id: String in RelicCards:
			if not Data.cards().has(card_id): continue
			trials.append(Cards.play(engine, card_id, [], "primed", "play", id))
		result.append({"id": id, "text": Inline.plain_text(PatternRules.display_rules(definition["description"])),
			"effect_types": Data.relic_effects(id).map(func(effect: Dictionary) -> String: return str(effect["type"])),
			"start": Fx.delta(Fx.receipt(baseline), Fx.receipt(started)),
			"end": Fx.delta(Fx.receipt(baseline_end), Fx.receipt(ended)), "cards": trials,
			"special": _relic_witness(engine, id, started.duplicate(true))})
	return result


static func _relic_witness(engine: RefCounted, id: String, started: Dictionary) -> Dictionary:
	match id:
		"hobnail_cleats":
			Fx.Surface.place(started, Fx.Hero, "ice")
			var naked: Dictionary = started.duplicate(true)
			naked["relics"] = []
			var action: Dictionary = {"type": "aoe", "damage": 0, "element": "ice", "_battlefield_frostbite": true}
			return {"without": Fx.receipt(engine._surface_freeze_actor(naked, "player", -1, action))["hero"],
				"with": Fx.receipt(engine._surface_freeze_actor(started, "player", -1, action))["hero"]}
		"crown_of_surplus":
			return Cards.play(engine, "quick_stab", [], "neutral", "empower", id)
		"whirling_sash":
			return Cards.play(engine, "quick_stab", [], "neutral", "play", id, {"turn_flags": {"cards_finished": 2}})
		"borrowed_hourglass":
			started["player_turn_time_spent"] = 2
			var ended: Dictionary = engine.finish_player_activation(started)
			return {"wait": engine.pending_wait_time(started), "paid": started["player_turn_time_spent"],
				"debt": ended["tempo_turn_time_debt"], "queue": ended["turn_queue"]}
		"quartermasters_ledger", "quick_draw_bandolier", "alchemists_retort":
			return {"attack": Cards.play(engine, "throwing_net", [], "neutral", "play", id),
				"heal": Cards.play(engine, "crimson_draught", [], "neutral", "play", id)}
	return {}
