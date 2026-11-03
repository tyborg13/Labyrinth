extends RefCounted
## Director feedback 1: approved prose and its production-rule witnesses.
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")
const Elements = preload("res://tests/suites/dragon_element_rules_suite.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
const COPY_STONE_ANCHOR := Vector2i(3, 3)

static func run(expect: Callable) -> void:
	_approved_tuning(expect)
	_copy_and_panels(expect)
	_outcrop_occupancy(expect)
	_gale_numbers(expect)
	_light_blocks_eclipse(expect)

static func _approved_tuning(expect: Callable) -> void:
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_feedback1_tuning.json"))
	for id: String in approved["bosses"]:
		var reference: Dictionary = approved["bosses"][id]
		var definition: Dictionary = Data.enemy_def(id)
		expect.call(int(definition["max_hp"]) == int(reference["max_hp"]), "F1 approved base Health: " + id)
		if reference.has("helpers"):
			expect.call(definition["dragon_helpers"] == reference["helpers"], "F1 boss-only helper roster: " + id)
		for intent: Dictionary in definition["intents"]:
			if not reference["actions"].has(str(intent["id"])): continue
			for field: String in reference["actions"][str(intent["id"])]:
				var values: Array = intent["actions"].filter(func(action: Dictionary) -> bool: return action.has(field))
				expect.call(not values.is_empty() and int(values[0][field]) == int(reference["actions"][str(intent["id"])][field]), "F1 approved " + field + ": " + id + "/" + str(intent["id"]))
	expect.call(int(Rules.instance_for("tharokh", 1)["dials"]["health"]) == 4, "F1 Tharokh stops before the Outcrop-Health rung")

static func _copy_and_panels(expect: Callable) -> void:
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_feedback1_grimoire.json"))
	var grimoire: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/grimoire.json"))
	var entries: Dictionary = {}
	for entry: Dictionary in grimoire["entries"]: entries[str(entry["id"])] = entry
	for id: String in approved["entries"]:
		var reference: Dictionary = approved["entries"][id]
		expect.call(entries[id]["body"] == reference["body"], "F1 Grimoire body is verbatim: " + id)
		for field: String in reference["identity"]:
			expect.call(entries[id][field] == reference["identity"][field], "F1 preserves Grimoire " + field + ": " + id)
	for id: String in Elements.IDS:
		var state: Dictionary = Boss._boss_combat_state(id)
		var body: String = "\n".join(entries["enemy:" + id]["body"])
		expect.call(body.contains(str(Rules.panel(state)["sentence"])), "F1 Grimoire repeats the in-fight panel word for word: " + id)

static func _outcrop_occupancy(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Elements.beat_fixture("tharokh")
	var boss: Dictionary = state["enemies"][0]
	var grub: Dictionary = state["enemies"][1]
	for actor: Dictionary in [boss, grub]:
		expect.call(engine._enemy_can_occupy_anchor(state, actor, COPY_STONE_ANCHOR, engine._enemy_blocking_tiles(state, int(actor["id"]))), "F1 empty proof anchor fits " + str(actor["type"]))
	state["terrain"].append({"id":"f1_copy_stone", "kind":"crag_outcrop", "pos":COPY_STONE_ANCHOR, "hp":int(Rules.active(state)["dials"]["health"]), "owner_kind":"enemy", "owner_id":int(boss["id"])})
	for actor: Dictionary in [boss, grub]:
		expect.call(not engine._enemy_can_occupy_anchor(state, actor, COPY_STONE_ANCHOR, engine._enemy_blocking_tiles(state, int(actor["id"]))), "F1 Outcrop blocks " + str(actor["type"]))
	grub["erupt_tile"] = COPY_STONE_ANCHOR
	expect.call(Burrow.landing_tile(engine, state, grub) != COPY_STONE_ANCHOR, "F1 a Burrow Grub cannot erupt on an Outcrop")
	state = Rules.fire(engine, state)
	expect.call(engine._terrain_index_at_tile(state, COPY_STONE_ANCHOR) >= 0, "F1 the next Upheaval does not expire an unbroken Outcrop")

static func _gale_numbers(expect: Callable) -> void:
	expect.call(preload("res://scripts/glossary.gd").definition("gale_force") == "Strikes everywhere within 2 tiles of Vaeloryx and Pushes struck actors 1 tile.", "F2 Hollow Gale tooltip is verbatim and matches its own Push 1")
	var gale: Dictionary = {}
	var eye: Dictionary = {}
	for intent: Dictionary in Data.enemy_def("vaeloryx")["intents"]:
		if intent["id"] == "hollow_gale": gale = intent
		if intent["id"] == "eye_of_storm": eye = intent
	var tokens: Array = []
	for row: Array in Icons.rows_for_actions(gale["actions"]): tokens.append_array(row)
	expect.call(tokens.any(func(token: Dictionary) -> bool: return str(token.get("icon", "")) == "push" and int(token.get("value", 0)) == 1), "F1 Hollow Gale's Push badge updates to the director's 1")
	expect.call(int(gale["actions"][0]["range"]) == 2, "F1 Hollow Gale retains its radius-two body attack")
	expect.call(int(eye["actions"][1]["damage"]) > int(eye["actions"][2]["damage"]), "F1 Eye's inner bite remains weaker than its outer ring")
	var wind: Dictionary = Rules.instance_for("vaeloryx", 1)
	expect.call(int(wind["dials"]["tiles"]) == 1 and int(wind["at_half_health"]["dials"]["tiles"]) == 2, "F1 the rule wind stays Push 1 then Push 2")

static func _light_blocks_eclipse(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state("noctyrax", 24)
	var brazier: Dictionary = state["guardian_braziers"][0]
	state["player"]["pos"] = brazier["pos"]
	var hp: int = int(state["player"]["hp"])
	var action: Dictionary = {}
	for intent: Dictionary in Data.enemy_def("noctyrax")["intents"]:
		if intent["id"] == "last_eclipse": action = intent["actions"][0]
	var steps: Array[Dictionary]
	state = engine._enemy_umbra_eclipse(state, 0, action, steps)
	expect.call(int(state["player"]["hp"]) == hp, "F1 a lit brazier protects against Eclipse damage")
	expect.call(not engine._umbra_eclipse_threat_tiles(state).has(brazier["pos"]), "F1 Eclipse's warning also respects Light")
