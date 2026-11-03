extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Marked = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Fixture = preload("res://tests/helpers/marked_fixture.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Search = preload("res://scripts/grimoire_search.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Store = preload("res://scripts/progression_store.gd")
const SAVE_PATH: String = "user://mrk01-marked-old-save.bin"
const MARKED_DEFINITION: String = "These tiles take the hit on this enemy's next turn."
const MOVE_COPY: Dictionary = {
	"icefall": "Marks 3 tiles across yours. Next turn they take the hit and turn to Ice.",
	"lob": "Marks your tile and the 4 around it. Next turn they take the hit and become Fire.",
	"burrow": "Burrows and marks your tile. While buried, it can't be targeted or moved, but Area Attacks hit it.",
	"erupt": "Emerges at the mark, hitting and moving whoever stands there. Neighbours get Push 1. Leaves Rubble; gains Expose 2."
}
const MARK_IDS: Dictionary = {"hoarfrost_seer": "icefall", "slag_mortar": "lob_slag", "burrow_grub": "burrow"}
const OLD_ALIASES = ["icefall", "Icefall", "icefall_mark", "icefall_land", "lob", "Lob Slag", "lob_slag", "lob_mark", "lob_land", "slag_lands", "burrow", "Burrow", "erupt", "Erupt"]

# Executes the real resolver, then deliberately commits the following strike on
# the marking activation. The ordinary timing assertion must reject this mutant.
class EarlyHitEngine:
	extends "res://scripts/combat_engine.gd"
	func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
		var result: Dictionary = super._resolve_enemy_action(state, enemy_index, action, rng, followup_action, bleed_steps, action_context)
		if str(action.get("type", "")) not in ["icefall_mark", "lob_mark", "burrow"]: return result
		var type: String = str(state["enemies"][enemy_index]["type"])
		for entry: Dictionary in preload("res://scripts/game_data.gd").enemy_def(type)["intents"]:
			if str(entry["id"]) == str(state["enemies"][enemy_index]["intent"]["next_intent"]):
				return super._resolve_enemy_action(result, enemy_index, entry["actions"][0], rng, {}, bleed_steps)
		return result

static func run(expect: Callable, mutation: String = "") -> void:
	_catalog(expect)
	var engine: RefCounted = EarlyHitEngine.new() if mutation == "early" else Combat.new()
	for type: String in MARK_IDS:
		var state: Dictionary = Fixture.fixture(engine, type, Fixture.FIXTURE_SEED)
		state["enemies"][0]["intent"] = Fixture.intent(type, MARK_IDS[type])
		if mutation == "shape" and type != "burrow_grub":
			state["enemies"][0]["intent"]["actions"][0]["shape"] = "plus" if type == "hoarfrost_seer" else "line3_perpendicular"
		var forecast: Array[Vector2i] = engine._vector2i_values(engine.enemy_threat_tiles(state, 0)["projected_attack"])
		var expected: Array[Vector2i]
		match type:
			"hoarfrost_seer": expected.assign([Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)])
			"slag_mortar": expected.assign([Vector2i(5, 5), Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6), Vector2i(4, 5)])
			"burrow_grub": expected.assign([Vector2i(5, 5)])
		expect.call(_same_tiles(forecast, expected), type + " exact authored forecast shape")
		var before_hp: int = int(state["player"]["hp"])
		var marked: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		expect.call(int(marked["player"]["hp"]) == before_hp, type + " marking does not hit a turn early")
		var held: Array[Vector2i]
		match type:
			"hoarfrost_seer": held = engine._vector2i_values(marked["enemies"][0].get("icefall_tiles", []))
			"slag_mortar": held = engine._vector2i_values(marked["enemies"][0].get("lob_tiles", []))
			"burrow_grub": held.assign([marked["enemies"][0].get("erupt_tile", Vector2i(-1, -1))])
		expect.call(_same_tiles(held, expected), type + " commits the forecast tiles")
		var landed: Dictionary = engine.resolve_enemy_turn_with_steps(marked.duplicate(true), 0)["state"]
		var damage: int = 6 if type == "burrow_grub" else 5
		expect.call(before_hp - int(landed["player"]["hp"]) == damage, type + " strikes on its next turn with unchanged damage")
		_old_save(engine, marked, landed, expect)
	_dials(expect)
	_captain_tooltip(expect)

static func _catalog(expect: Callable) -> void:
	expect.call(Glossary.name_for("marked") == "Marked" and Glossary.definition("marked") == MARKED_DEFINITION, "Exact Marked glossary copy")
	var entry: Dictionary = Grimoire.entry_def("keyword:marked")
	expect.call(entry["title"] == "Marked" and entry["body"] == [MARKED_DEFINITION], "Exact Marked grimoire copy")
	expect.call(Icons.icon_path("marked") == "res://assets/art/icons/marked.png" and Icons.icon_texture("marked") != null, "Marked uses the approved director painting")
	for alias: String in OLD_ALIASES: expect.call(str(Glossary.lookup(alias).get("id", "")) == "marked", "Marked alias: " + alias)
	for key: String in MOVE_COPY:
		expect.call(Grimoire.entry_def("keyword:" + key).is_empty(), "Retired keyword page: " + key)
		expect.call(Icons.description(key) == MOVE_COPY[key], "Approved move copy: " + key)
		expect.call(Icons.label(key) != "Marked" and not Icons.icon_path(key).is_empty(), "Move keeps its name and icon: " + key)
		expect.call(Grimoire.normalize_entry_ids(["keyword:" + key]) == _strings(["keyword:marked"]), "Old grimoire discovery migrates: " + key)
		var results: Array[Dictionary] = Search.search([entry], Grimoire.data()["sections"], Icons.label(key))
		expect.call(results.size() == 1 and results[0]["entry"]["id"] == "keyword:marked", "Old move name finds Marked: " + key)
	for action_type: String in ["icefall_mark", "icefall_land", "lob_mark", "lob_land", "burrow", "erupt"]:
		expect.call(Grimoire.entry_ids_for_actions([{"type": action_type}]).has("keyword:marked"), "Action discovers shared keyword: " + action_type)

static func _old_save(engine: RefCounted, marked: Dictionary, landed: Dictionary, expect: Callable) -> void:
	var old: Dictionary = marked.duplicate(true)
	for action: Dictionary in old["enemies"][0]["intent"]["actions"]:
		action.erase("tile_filter")
		if str(action["type"]) == "icefall_land": action.erase("surface")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": old})
	file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	var resumed: Dictionary = engine.resolve_enemy_turn_with_steps(loaded, 0)["state"]
	expect.call(Fixture.save_comparable(resumed) == Fixture.save_comparable(landed), "Old action names and held marks resume identically: " + str(marked["enemies"][0]["type"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _dials(expect: Callable) -> void:
	var engine := Combat.new()
	for type: String in ["hoarfrost_seer", "slag_mortar"]:
		var state: Dictionary = Fixture.fixture(engine, type, Fixture.FIXTURE_SEED)
		var action: Dictionary = Fixture.intent(type, MARK_IDS[type])["actions"][0]
		expect.call(action.has("shape") and action.has("tile_filter") and action.has("ignore_line_of_sight"), type + " pattern and visibility are data dials")
		var before: Dictionary = state.duplicate(true)
		var first: Array[Vector2i] = Marked.tiles(engine, state, state["enemies"][0], action)
		expect.call(first == Marked.tiles(engine, state, state["enemies"][0], action) and state == before, type + " forecast is pure and deterministic")
		state["grid"][4][5] = "wall"
		var with_sight: Dictionary = action.duplicate(true)
		with_sight["ignore_line_of_sight"] = false
		expect.call(Marked.tiles(engine, state, state["enemies"][0], with_sight).is_empty(), type + " LOS dial is honored")
		state["grid"][4][5] = "stone"
		state["terrain"] = [{"id": "mrk01_sight_fixture", "kind": "crag_outcrop", "hp": 3, "max_hp": 3, "pos": Vector2i(5, 4), "blocks_sight": true}]
		expect.call(Marked.tiles(engine, state, state["enemies"][0], with_sight).is_empty(), type + " LOS uses production standing-terrain rules")

static func _same_tiles(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size(): return false
	for tile: Vector2i in a:
		if not b.has(tile): return false
	return true

static func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values: result.append(str(value))
	return result

static func _captain_tooltip(expect: Callable) -> void:
	var orders = preload("res://tests/suites/warband_orders_suite.gd")
	var state: Dictionary = orders.battle("ice")
	state["enemies"][0]["intent"] = orders.authored(state, "icefall")
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.combat_state = state
	var order: String = preload("res://scripts/warband_combat_rules.gd").order_line(state["objective"])
	expect.call(not order.is_empty(), "Oracle tooltip fixture has a real captain Order")
	expect.call(board.enemy_intent_tooltip("enemy_1") == MOVE_COPY["icefall"] + "\n" + order, "Rime Oracle marking tooltip retains its Order")
	state["enemies"][0]["intent"] = orders.authored(state, "icefall_land")
	expect.call(board.enemy_intent_tooltip("enemy_1") == "Marked tiles take the hit and turn to Ice.\n" + order, "Rime Oracle landing tooltip retains its Order")
	board.free()
