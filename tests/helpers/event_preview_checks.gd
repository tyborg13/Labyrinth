extends RefCounted

const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Depth = preload("res://scripts/depth_rules.gd")
const History = preload("res://scripts/recent_event_store.gd")
const PREVIEW_SEEDS: int = 50
const PREVIEW_DEPTHS: Array = [0, 3, 6]
const FIXTURE_COORD: Vector2i = Vector2i(1, 0)
const FIXTURE_HP: int = 99
const FIXTURE_EMBERS: int = 999
const FIXTURE_SPELLS: Array = ["guiding_flare", "cinder_bloom", "pale_spark"]

static func run(engine: RefCounted, expect: Callable) -> void:
	for id: String in Data.events():
		for choice: Dictionary in Data.event_def(id)["choices"]:
			expect.call(not JSON.stringify(choice).to_lower().contains("random"), "Director catalog has no dice or random text: " + id)
	var rejected: Array[String]
	Events._validate_effects([{"type": "random", "outcomes": []}], "retired_dice", rejected)
	expect.call(rejected == _strings(["Unknown effect: retired_dice"]), "Validator explicitly rejects retired random effects")
	preload("res://tests/helpers/recent_event_checks.gd").run(engine, expect)
	_rotation(engine, expect)
	_legacy_pages(engine, expect)
	_named_lines(engine, expect)
	empty_card_pools(engine, expect)
	_exhaustive(engine, expect)

static func fixture(engine: RefCounted) -> Dictionary:
	var state: Dictionary = engine.create_new_run(421, Store.default_data())
	state.erase("current_room_layout")
	state["rooms"] = {Graph.key(FIXTURE_COORD): {"coord": FIXTURE_COORD, "type": "event", "depth": 1, "section_index": 0, "cleared": false}}
	state["current_room"] = FIXTURE_COORD
	state["mode"] = "event"
	state["player_hp"] = FIXTURE_HP
	state["player_max_hp"] = FIXTURE_HP
	state["held_embers"] = FIXTURE_EMBERS
	state["unbanked_embers"] = FIXTURE_EMBERS
	state["item_inventory"] = Data.item_card_ids()
	state["attuned_magic_cards"] = FIXTURE_SPELLS.duplicate()
	return state

static func set_event(state: Dictionary, id: String) -> void:
	Graph.room(state, state["current_room"])["event_id"] = id
	state["event_state"] = {"event_id": id, "page": "choices", "choice_id": "", "result_text": "", "outcomes": []}

static func _exhaustive(engine: RefCounted, expect: Callable) -> void:
	var base: Dictionary = fixture(engine)
	var cases: int = 0
	var substitutions: int = 0
	for exhausted: bool in [false, true]:
		var template: Dictionary = base.duplicate(true)
		if exhausted:
			template["relics"] = Data.relic_ids()
			template["equipment_inventory"] = Data.equipment().keys()
		for depth: int in PREVIEW_DEPTHS:
			for seed_value: int in range(PREVIEW_SEEDS):
				var state: Dictionary = template.duplicate(true)
				state["seed"] = seed_value
				state[Depth.STATE_KEY] = depth
				Graph.room(state, FIXTURE_COORD)["section_index"] = depth / 2
				for id: String in Data.events():
					set_event(state, id)
					for choice: Dictionary in Data.event_def(id)["choices"]:
						var cid: String = str(choice["id"])
						if not Events.choice_available(state, id, cid): continue
						var before: PackedByteArray = var_to_bytes(state)
						var preview: Array[Dictionary] = Events.preview_choice(state, cid)
						expect.call(var_to_bytes(state) == before, "Preview never mutates state, including inventories, progression, map outbox or RNG inputs")
						var result: Dictionary = engine.resolve_map_event(state, cid)
						expect.call(preview == result["event_state"]["outcomes"], "Preview equals result: %s/%s seed=%d depth=%d exhausted=%s" % [id, cid, seed_value, depth, exhausted])
						for outcome: Dictionary in preview:
							if outcome.has("substitution_for"): substitutions += 1
						cases += 1
			print("Event preview matrix: depth=%d exhausted=%s complete" % [depth, exhausted])
	expect.call(substitutions > 0, "Preview matrix exercises real empty relic, equipment and reforge pools")
	print("Event preview equals result: %d choices; %d seeds × %d depths × fresh/exhausted; %d substitutions" % [cases, PREVIEW_SEEDS, PREVIEW_DEPTHS.size(), substitutions])

static func _rotation(engine: RefCounted, expect: Callable) -> void:
	var profile: Dictionary = Store.default_data()
	History.set_storage_path("user://evt01_rotation_history.json")
	var recent: Array[String]
	recent.assign(["bloodletters_basin", "hanged_knight"])
	expect.call(History.save_recent_events(recent), "Rotation fixture writes independent memory")
	var state: Dictionary = engine.create_new_run(421, profile)
	recent.append("name_collector")
	expect.call(History.save_recent_events(recent), "External history change saves")
	expect.call(state["event_memory"] == ["bloodletters_basin", "hanged_knight"], "New runs own a frozen snapshot of the separate history file")
	state = fixture(engine)
	var definitions: Dictionary = Data.events()
	var candidates: Array[String]
	for id: String in definitions:
		var event: Dictionary = definitions[id]
		if str(event["pool"]) in ["any", Events.section_element(state)] and int(event["min_section"]) == 0: candidates.append(id)
	candidates.sort()
	var memory: Array[String] = candidates.slice(6)
	state["event_memory"] = memory
	for seed_value: int in range(PREVIEW_SEEDS):
		state["seed"] = seed_value
		expect.call(not memory.has(Events.select_event(state)), "Exactly six remaining candidates honour memory")
	# Five remaining ignores memory, using the exact original sorted draw.
	state["event_memory"] = candidates.slice(5)
	var without: Dictionary = state.duplicate(true)
	without["event_memory"] = []
	expect.call(Events.select_event(state) == Events.select_event(without), "Fewer than six candidates ignores memory before existing fallback order")
	state["seen_events"] = candidates.slice(0, 1)
	expect.call(Events.select_event(state) != candidates[0], "Seen events remain excluded when memory is ignored")
	var legacy: Dictionary = fixture(engine)
	legacy.erase("event_memory")
	expect.call(engine.repair_loaded_run_state(legacy)["event_memory"] == [], "Old saves load an empty run memory instead of consulting history")
	state = fixture(engine)
	set_event(state, "bloodletters_basin")
	var result: Dictionary = engine.resolve_map_event(state, "reach")
	expect.call(result["progression"] == state["progression"] and result["event_memory"] == state["event_memory"], "Event resolution preserves progression and its frozen memory")
	History.set_storage_path(History.DEFAULT_STORAGE_PATH)

static func _legacy_pages(engine: RefCounted, expect: Callable) -> void:
	Store.set_run_storage_path("user://evt01_legacy_event.save")
	var state: Dictionary = fixture(engine)
	set_event(state, "bloodletters_basin")
	state["event_state"].merge({"page": "result", "choice_id": "reach", "result_text": "Stored legacy outcome.", "outcomes": [{"type": "hp", "amount": -3}]}, true)
	var stored: Dictionary = state["event_state"].duplicate(true)
	expect.call(Store.save_run_state(state), "Old result page saves")
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(loaded["event_state"] == stored and Events.outcome_lines(loaded) == _strings(["Lost 3 @icon(health)."]), "Legacy dice result retains stored text and concrete outcomes")
	expect.call(engine.resolve_map_event(loaded, "reach")["event_state"] == stored, "Legacy random result never rerolls or applies the rewritten choice")
	expect.call(engine.resolve_map_event(loaded, "continue")["mode"] == "room", "Legacy result continues normally")
	set_event(state, "bloodletters_basin")
	expect.call(Store.save_run_state(state), "Old choices page saves")
	loaded = engine.repair_loaded_run_state(Store.load_saved_run())
	var result: Dictionary = engine.resolve_map_event(loaded, "reach")
	expect.call(result["event_state"]["outcomes"][0] == {"type": "hp", "amount": -2} and result["event_state"]["outcomes"][1]["type"] == "relic", "Legacy choices page uses rewritten deterministic choices")
	Store.clear_saved_run()

static func _named_lines(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	for id: String in Data.events():
		set_event(state, id)
		for choice: Dictionary in Data.event_def(id)["choices"]:
			var cid: String = str(choice["id"])
			var before: PackedByteArray = var_to_bytes(state)
			var lines: Array[Dictionary] = Events.preview_lines(state, id, cid)
			expect.call(var_to_bytes(state) == before and lines.size() == choice["effects"].size(), "Named previews are pure and retain one row per authored effect: " + id + "/" + cid)
			for line: Dictionary in lines:
				expect.call(not str(line["text"]).to_lower().contains("random") and line.has("kind") and line.has("ids"), "All named lines expose concrete metadata and no probability wording")
			if not Events.choice_available(state, id, cid): continue
			var resolved: Dictionary = Events.apply_effects(state, choice["effects"], Events.rng_for(state, "choice|%s" % cid), engine)
			for index: int in range(lines.size()):
				var line: Dictionary = lines[index]
				var outcomes: Array = resolved["effect_outcomes"][index]
				var type: String = str(choice["effects"][index]["type"])
				var ids: Array = line["ids"]
				if type in ["relic", "equipment", "card", "lose_item", "item"]:
					var names: Array[String]
					for outcome: Dictionary in outcomes:
						if not outcome.has("id"): continue
						expect.call(ids.has(outcome["id"]), "Preview names the concrete acquired or lost id")
						names.append(_names(type, [outcome["id"]])[0])
					if not names.is_empty(): expect.call(line["text"] == ("Lose %s." if type == "lose_item" else "Gain %s.") % " and ".join(names), "Exact acquisition and loss name copy")
				elif type == "card_choice":
					expect.call(ids == outcomes[0]["cards"] and line["text"] == "Choose 1: %s." % _alternatives(_names("card", outcomes[0]["cards"])), "Card-choice line names the exact deferred offer in order")
				elif type == "reforge":
					expect.call(ids == [outcomes[0]["from"], outcomes[0]["to"]] and line["text"] == "Your %s becomes %s." % [_names(type, [outcomes[0]["from"]])[0], _names(type, [outcomes[0]["to"]])[0]], "Exact reforge from/to copy")
				elif type == "transform_magic":
					var expected: String = "%s becomes %s." % [_names(type, [outcomes[0]["from"]])[0], _names(type, [outcomes[0]["to"]])[0]] if outcomes.size() == 1 else "%d spells change: hover to see." % outcomes.size()
					expect.call(line["text"] == expected, "Exact single/plural transformation copy")
	# Empty magic pools must preview the same Ember substitution as commitment.
	var cards: Dictionary = Data.cards().duplicate(true)
	for id: String in Data.cards().keys():
		if not Data.card_is_item(id): Data.cards().erase(id)
	set_event(state, "moth_library")
	var preview: Array[Dictionary] = Events.preview_choice(state, "search")
	expect.call(preview == engine.resolve_map_event(state, "search")["event_state"]["outcomes"] and preview[0].get("substitution_for") == "card_choice", "Empty card-choice pool preview equals the result")
	expect.call(Events.preview_lines(state, "moth_library", "search")[0] == {"text": "Gain 40 Embers.", "kind": "plain", "ids": []}, "Substitution line has exact copy and no phantom ids")
	Data.cards().clear()
	Data.cards().merge(cards)

static func empty_card_pools(engine: RefCounted, expect: Callable) -> void:
	var definitions: Dictionary = Data.cards().duplicate(true)
	for id: String in Data.cards(): Data.cards()[id]["reward_pool"] = false
	var state: Dictionary = fixture(engine)
	var cases: int = 0
	for depth: int in PREVIEW_DEPTHS:
		state[Depth.STATE_KEY] = depth
		for seed_value: int in range(PREVIEW_SEEDS):
			state["seed"] = seed_value
			for id: String in Data.events():
				set_event(state, id)
				for choice: Dictionary in Data.event_def(id)["choices"]:
					if not (choice["effects"] as Array).any(func(effect: Dictionary) -> bool: return effect["type"] in ["card", "card_choice"]): continue
					var cid: String = str(choice["id"])
					if not Events.choice_available(state, id, cid): continue
					var before: PackedByteArray = var_to_bytes(state)
					var preview: Array[Dictionary] = Events.preview_choice(state, cid)
					expect.call(var_to_bytes(state) == before, "Empty card-pool preview never mutates state")
					expect.call(preview == engine.resolve_map_event(state, cid)["event_state"]["outcomes"], "Empty card pool equals result: %s/%s seed=%d depth=%d" % [id, cid, seed_value, depth])
					expect.call(preview.any(func(outcome: Dictionary) -> bool: return outcome.get("substitution_for", "") in ["card", "card_choice"]), "Empty direct-card/chooser pool substitutes actual Embers")
					cases += 1
	Data.cards().clear()
	Data.cards().merge(definitions)
	print("Event empty card preview equals result: %d choices; %d seeds × %d depths" % [cases, PREVIEW_SEEDS, PREVIEW_DEPTHS.size()])

static func _names(type: String, ids: Array) -> Array[String]:
	var names: Array[String]
	for id: String in ids:
		match type:
			"relic": names.append(str(Data.relic_def(id)["name"]))
			"equipment", "reforge": names.append(str(Data.equipment_def(id)["name"]))
			_: names.append(str(Data.card_def(id)["name"]))
	return names

static func _alternatives(names: Array[String]) -> String:
	if names.size() < 2: return "" if names.is_empty() else names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " or " + names.back()

static func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result
