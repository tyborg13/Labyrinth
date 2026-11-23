extends SceneTree
## Candidate 4 text inventory. Game formatters run headless on production data.

const F = preload("res://tools/txt24/fixture.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const SkillView = preload("res://scripts/skill_tree_view.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Events = preload("res://scripts/event_rules.gd")
const EventPreview = preload("res://scripts/event_reward_preview.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Run = preload("res://scripts/run_engine.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const WarbandRooms = preload("res://scripts/warband_room_rules.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Snare = preload("res://scripts/snare_room_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")

const HEIRLOOM_ITEM: String = "iron_cleaver"
const GLOSSARY_SAMPLE_AMOUNT: int = 3
const SNARE_SEAL_TURNS: int = 2
const WARBAND_TIER: int = 1
const OUTPUT_PATH: String = "res://tools/txt24/rendered_inventory.json"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_capture")

func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = OUTPUT_PATH if args.is_empty() else args[0]
	var sample: Dictionary = EventFixture.fixture("lost_cartographer", true)
	var inventory: Dictionary = {
		"skills": _skills(),
		"boons": _boons(sample),
		"upgrades": _upgrades(),
		"events": _events(sample),
		"event_omens": _omens(),
		"enemies": _enemies(),
		"encounter_variants": _variants(),
		"battlefield": _battlefield(),
		"glossary": _glossary(),
	}
	F.save_json(output, inventory)
	var choices: int = 0
	for choices_for_event: Dictionary in inventory["events"].values(): choices += choices_for_event.size()
	var intents: int = 0
	for enemy: Dictionary in inventory["enemies"].values(): intents += enemy["intents"].size()
	print("TXT24 INVENTORY: %d skills, %d boons, %d upgrades, %d events / %d choices, %d enemies / %d intents, %d battlefield instances, %d glossary definitions" % [
		inventory["skills"].size(), inventory["boons"].size(), inventory["upgrades"].size(),
		inventory["events"].size(), choices, inventory["enemies"].size(), intents,
		inventory["battlefield"].size(), inventory["glossary"].size()])
	quit()

func _skills() -> Dictionary:
	var view := SkillView.new()
	var rows: Dictionary = {}
	for id: String in Skills.ordered_ids():
		rows[id] = {
			"name": Skills.display_name(id),
			"description": F.text(Skills.description(id)),
			"requirements": view._requirements_text(id) if Skills.is_player_visible(id) else "",
			"retired": Skills.is_retired(id),
		}
	view.free()
	return rows

func _boons(sample: Dictionary) -> Dictionary:
	var state: Dictionary = sample.duplicate(true)
	state["equipped_equipment"] = F.Data.starting_equipped_equipment()
	var rng := RandomNumberGenerator.new()
	rng.seed = F.SEED
	var rows: Dictionary = {}
	for id: String in Boons.definitions()["boons"]:
		var roll: Dictionary = {"boon": id, "item": HEIRLOOM_ITEM} if id == "heirloom" else Boons.roll(id, state, rng)
		if not roll.is_empty(): rows[id] = F.text(Boons.text(roll))
	return rows

func _upgrades() -> Dictionary:
	var rows: Dictionary = {}
	for id: String in F.Data.upgrade_ids():
		rows[id] = {"name": F.Data.upgrade_def(id)["name"], "purchasable": id in F.Data.card_upgrade_ids()}
	return rows

func _events(sample: Dictionary) -> Dictionary:
	var rows: Dictionary = {}
	var engine := Run.new()
	for id: String in F.Data.events():
		var state: Dictionary = sample.duplicate(true)
		var definition: Dictionary = F.Data.event_def(id)
		_position_event_fixture(state, definition)
		Graph.room(state, state["current_room"])["event_id"] = id
		state = Events.enter_event(state)
		rows[id] = {}
		for choice: Dictionary in definition["choices"]:
			var cid: String = str(choice["id"])
			var lines: Array[Dictionary] = Events.preview_lines(state, id, cid)
			var printed: Array[String] = []
			for line: Dictionary in lines: printed.append(F.text(line["text"]))
			var hover: Dictionary = EventPreview.hover_line(lines)
			var blocked: String = Events.choice_block_reason(state, id, cid)
			var committed: Dictionary = engine.resolve_map_event(state, cid)
			var actual: Array = committed["event_state"]["outcomes"]
			var available: bool = blocked.is_empty()
			assert(not available or Events.preview_choice(state, cid) == actual, id + "/" + cid)
			var hover_description: String = ""
			if hover.get("kind") == "omen": hover_description = F.text(F.Data.omen_def(hover["ids"][0])["description"])
			rows[id][cid] = {"label": choice["label"], "lines": printed, "hover_kind": hover.get("kind", ""), "hover_ids": hover.get("ids", []),
				"hover_description": hover_description, "blocked": blocked,
				"transaction": _transaction(actual), "preview_matched": available}
	return rows

func _position_event_fixture(state: Dictionary, definition: Dictionary) -> void:
	var pool: String = str(definition["pool"])
	for room: Dictionary in state["rooms"].values():
		var section: int = int(room.get("section_index", -1))
		if section < int(definition["min_section"]) or section > int(definition["max_section"]): continue
		if str(room.get("type", "")) not in ["mystery", "event"]: continue
		var original: Vector2i = state["current_room"]
		state["current_room"] = room["coord"]
		if pool == "any" or pool == Events.section_element(state): return
		state["current_room"] = original

func _transaction(outcomes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in outcomes:
		var row: Dictionary = entry.duplicate(true)
		# The map proof needs a count, rather than platform vector serialization.
		if row.has("rooms"):
			row["rooms_revealed"] = (row["rooms"] as Array).size()
			row.erase("rooms")
		result.append(row)
	return result

func _omens() -> Dictionary:
	var rows: Dictionary = {}
	for id: String in F.Data.omens():
		var omen: Dictionary = F.Data.omen_def(id)
		rows[id] = {"name": omen["name"], "definition": F.text(omen["description"]), "fights": omen["fights"]}
	return rows

func _enemies() -> Dictionary:
	var board := Board.new()
	var engine := F.Combat.new()
	var rows: Dictionary = {}
	for id: String in F.Data.enemies():
		var definition: Dictionary = F.Data.enemy_def(id)
		var state: Dictionary = F.fight(engine, id)
		board.combat_state = state
		var entry: Dictionary = {"name": definition["name"], "intents": {}, "traits": {}}
		for intent: Dictionary in definition["intents"]:
			var actor: Dictionary = state["enemies"][0]
			actor["intent"] = intent.duplicate(true)
			if id == "burrow_grub":
				actor["burrowed"] = str(intent["id"]) == "erupt"
				if actor["burrowed"]: actor["erupt_tile"] = F.PLAYER
			if id == "storm_capacitor":
				actor["charge"] = int(definition["charge"]["max"]) if str(intent["id"]) == "discharge" else 0
			var unit: Dictionary = {}
			for visible: Dictionary in board._visible_units():
				if str(visible.get("role", "")) == "enemy": unit = visible
			assert(not unit.is_empty(), id)
			var shown: Dictionary = unit["intent"]
			var details: Array = board._intent_rows_for_unit(unit, shown)
			entry["intents"][intent["id"]] = _intent_text(board, engine, unit, shown, intent, details)
			for badge: Dictionary in board._unit_status_badges(unit):
				if badge.get("status_class", "") != "trait": continue
				var tooltip: String = F.text(badge.get("tooltip", ""))
				if not tooltip.is_empty(): entry["traits"][tooltip] = str(badge["icon"])
		rows[id] = entry
	board.free()
	return rows

func _intent_text(board: Control, engine: RefCounted, unit: Dictionary, shown: Dictionary, intent: Dictionary, details: Array) -> Dictionary:
	var state: Dictionary = board.combat_state
	var inspected: Dictionary = Lob.presentation_intent(engine, state, unit, intent)
	var inspection_rows: Array = Inspection.move_rows(inspected, unit, state)
	var inspection: String = Icons.plain_text_for_rows(inspection_rows, true)
	for action: Dictionary in inspected["actions"]:
		if Lob.is_lob(action): inspection = Icons.lob_diagram_text(action); break
	return {"name": board._intent_display_name(shown), "details": F.text(Icons.plain_text_for_rows(details, true)),
		"tooltip": F.text(board.enemy_intent_tooltip("enemy_0")), "inspection": F.text(inspection),
		"inspection_tooltip": F.text(Inspection.move_tooltip(inspection_rows)), "inspection_note": F.text(Guardians.intent_notes(inspected))}

func _variants() -> Dictionary:
	var engine := F.Combat.new()
	var board := Board.new()
	var rows: Dictionary = {}
	for element: String in Specials.definition("warband")["variants"]:
		var variant: Dictionary = Specials.variant("warband", element)
		var captain: String = str(variant["captain"])
		var state: Dictionary = F.fight(engine, captain)
		state["objective"] = WarbandRooms.objective({"special_variant": element}, WARBAND_TIER)
		state["enemies"][0]["is_leader"] = true
		Warband.initialize(engine, state)
		board.combat_state = state
		var moves: Dictionary = {}
		for intent: Dictionary in F.Data.enemy_def(captain)["intents"]:
			state["enemies"][0]["intent"] = intent
			var unit: Dictionary = {}
			for visible: Dictionary in board._visible_units():
				if visible.get("role") == "enemy": unit = visible
			var shown: Dictionary = unit["intent"]
			moves[intent["id"]] = _intent_text(board, engine, unit, shown, intent, board._intent_rows_for_unit(unit, shown))
		rows[element] = {"captain": captain, "order": F.text(Warband.order_line(state["objective"])), "moves": moves}
	board.free()
	rows["guardians"] = {"starting_wick_shade": Guardians.inspection_summary({"type": "wick_shade", "guardian_helper": true}),
		"summoned_wick_shade": Guardians.inspection_summary({"type": "wick_shade", "guardian_helper": true, "outage_owner": 0})}
	var seal_objective: Dictionary = {"exits": [{"sealbinder_id": 0, "seal_after_player_turns": SNARE_SEAL_TURNS}]}
	rows["snare_seal"] = F.text(Snare.seal_tooltip(seal_objective, {"id": 0}))
	return rows

func _battlefield() -> Dictionary:
	var rows: Dictionary = {}
	for id: String in Rules.data()["instances"]:
		var instance: Dictionary = Rules.instance_for(id, 0)
		var state: Dictionary = {"battlefield_rule": instance, "enemies": [{"id": 0, "hp": 1, "max_hp": 2}]}
		var panel: Dictionary = Rules.panel(state)
		var phased: Dictionary = {}
		if Rules.HalfHealth.check(state): phased = Rules.panel(state)
		rows[id] = {"name": panel.get("name", ""), "sentence": F.text(panel.get("sentence", instance["sentence"])),
			"half_health": F.text(phased.get("sentence", ""))}
	return rows

func _glossary() -> Dictionary:
	var rows: Dictionary = {}
	for term: Dictionary in Glossary.all_entries():
		var id: String = str(term["id"])
		rows[id] = {"name": term["name"], "definition": F.text(Glossary.definition(id)),
			"numbered_example": F.text(Glossary.definition(id, "", GLOSSARY_SAMPLE_AMOUNT))}
	return rows
