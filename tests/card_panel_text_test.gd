extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const ItemRules = preload("res://scripts/item_relic_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const CardHover = preload("res://scripts/card_keyword_hover.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const PanelText = preload("res://scripts/card_panel_text.gd")
const TXT20_COPY: String = "res://tests/fixtures/txt20_rules_copy.json"
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-02/card_panels.json"
## pla-04 (Burst merge): director rows whose copy named Detonate, Terrain Burst
## or Shatter Illusion. Their templates stay protected but no live card uses them.
const PLA07_COPY: String = "res://tests/fixtures/pla07_status_copy.json"
const PLA06_COPY: String = "res://tests/fixtures/pla06_ice_copy.json"
const PLA04_RETIRED_ROWS: Array = ["keg_detonate", "terrain_burst_any", "terrain_burst_own", "shatter_illusion"]
const OUTPUT_DIR: String = "res://proof/tt-02"
const WORD_COUNT_SCOPE: String = "title_and_body"
const ASSEMBLY_FIXTURE: Dictionary = {"same_term_values": [2, 4], "different_target_value": 3, "petrify_range": 3, "modifier_amount": 1}
const COUNT_FIXTURE: Dictionary = {"counts": [0, 1, 2], "other_placeholder_value": 2}
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	var dump: Array = []
	var definitions: Dictionary = {}
	var unbound_amount := RegEx.create_from_string("\\bX\\b")
	for id: String in Data.cards():
		definitions[id] = Data.card_def(id)
	for id: String in Data.cards():
		var item: Dictionary = Data.card_def(id)
		if bool(item.get("item", false)):
			definitions["variant:item_once_per_combat:" + id] = ItemRules.modify_card(item, [{"type": "item_once_per_combat"}], Callable())
	for id: String in Data.card_upgrade_ids():
		definitions["upgrade:" + id] = Data.upgraded_card_def(id)
	for id: String in Data.upgradeable_card_ids():
		for element: Dictionary in Data.upgradeable_elements_for_card(id, {}):
			var options: Array = Data.upgrade_options_for_element(id, element, {})
			for index: int in range(options.size()):
				definitions["upgrade:%s:%s:%d" % [id, element["key"], index]] = Data.preview_card_with_mod(id, options[index], {})
	for id: String in definitions:
		var card: Dictionary = definitions[id]
		var entries: Array[Dictionary] = _entries(card, str(card.get("base_card_id", card.get("id", id))))
		for problem: String in stack_errors(entries, card):
			_expect(false, id + ": " + problem)
		_checks += entries.size()
		for entry: Dictionary in entries:
			_expect(unbound_amount.search(str(entry["description"])) == null, id + ": panel leaves an unbound amount in " + str(entry["title"]))
			dump.append({"card": id, "name": card.get("name", id), "icon": entry["icon"], "glossary_key": entry.get("glossary_key", entry["icon"]), "title": entry["title"], "text": entry["description"]})
	_test_examples()
	_test_tile_target_range()
	_test_grimoire()
	_test_assembly()
	_test_feedback_copy_and_counted_tiles()
	_write_proof(dump, definitions.size())
	if OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--measure-layout"):
		var proof := preload("res://tests/helpers/card_panel_proof.gd").new()
		await proof.run(self, _expect, OS.get_cmdline_user_args().has("--capture"))
	for failure: String in _failures:
		push_error(failure)
	print("CARD PANEL TEXT TEST RESULT: %s (%d definitions, %d panels, %d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", definitions.size(), dump.size(), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

static func _entries(card: Dictionary, card_id: String = "") -> Array[Dictionary]:
	var leading: Array = []
	if Icons.card_is_rite(card): leading.append("rite")
	return CardHover.entries_for_card(card_id, Icons.rows_for_card(card), leading)

static func stack_errors(entries: Array[Dictionary], card: Dictionary) -> Array[String]:
	var errors: Array[String]
	var sentences: Dictionary = {}
	var semantics: Dictionary = {}
	var term_titles: Array = []
	for glossary: Dictionary in Glossary.all_entries(): term_titles.append(glossary["name"])
	for row: Dictionary in _json(COPY_PATH)["rows"]: term_titles.append(row["title"])
	# crd-08's supplied conditional titles extend the original director fixture.
	term_titles.append_array(["If Exposed", "If Immobilized", "If Staggered", "If Shocked"])
	term_titles.append("Rubble")
	var hidden: Array = []
	_collect_cleanse_statuses(card, hidden)
	for entry: Dictionary in entries:
		var title: String = str(entry.get("title", ""))
		var body: String = str(entry.get("description", "")).split("\nModified by:", true, 1)[0]
		var term: String = str(entry.get("glossary_key", entry.get("icon", "")))
		var marks: int = body.count(".") + body.count("!") + body.count("?")
		if body.is_empty(): errors.append("Empty body: " + title)
		# Light includes its combat duration and the enemy turn-start effect.
		var light_template: String = Glossary.definition("illuminate")
		var light_number := RegEx.create_from_string("within (\\d+) tiles?")
		var radius: RegExMatch = light_number.search(body)
		var is_light_rule: bool = term == "illuminate" and body == Glossary.fill_amount(light_template, radius.get_string(1) if radius != null else null)
		var word_budget: int = 20 if is_light_rule else 16
		if term == "next_attack" and body.contains("for each tile you moved this turn"):
			word_budget = 22 # The approved Headlong sentence is also used by its fallback row.
		if body.contains("\n") or marks != 1 or body.split(" ", false).size() > word_budget:
			errors.append("R1: " + title + ": " + body)
		if sentences.has(body): errors.append("R4 repeated sentence: " + body)
		if hidden.has(term): errors.append("R5 Cleanse status: " + term)
		var uses_title: bool = term not in ["surface_consume", "quicken", "next_attack"]
		if uses_title and (not term_titles.has(title) or title.split(" ", false).size() > 4 or title.ends_with(".")):
			errors.append("R6 title: " + title)
		elif not uses_title and not title.is_empty():
			errors.append("R6 title: " + title)
		var semantic: String = term + "\u001f" + body
		if semantics.has(semantic): errors.append("R7 repeated term and text: " + term)
		sentences[body] = true
		semantics[semantic] = true
	return errors

static func _collect_cleanse_statuses(value: Variant, statuses: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		if str(value.get("type", "")) == "cleanse": statuses.append_array(value.get("statuses", []))
		for child: Variant in value.values(): _collect_cleanse_statuses(child, statuses)
	elif typeof(value) == TYPE_ARRAY:
		for child: Variant in value: _collect_cleanse_statuses(child, statuses)

func _test_examples() -> void:
	var examples: Dictionary = _json("res://tests/fixtures/card_panel_examples.json")
	var director: Dictionary = _json(COPY_PATH)
	_expect(examples.size() == (director["rows"] as Array).size(), "Each director row has a named representative")
	for row: Dictionary in director["rows"]:
		var id: String = row["id"]
		_expect(examples.has(id), "Representative for " + id)
		if not examples.has(id): continue
		# pla-04 retires these director rows: their cards Burst now (one verb).
		if id in PLA04_RETIRED_ROWS or id in _json(PLA06_COPY)["retired_panel_rows"]: continue
		var example: Dictionary = (_json(PLA06_COPY)["panel_examples"] as Dictionary).get(id, examples[id])
		var card: Dictionary = example.get("definition", Data.card_def(example["card"]))
		_expect(not card.is_empty(), "Representative exists: " + id + " -> " + str(example["card"]))
		# Keep the approved examples for the older, explicitly restricted actions.
		if id in ["ice_to_electrified", "range_ice"]:
			(card["actions"][0] as Dictionary).erase("source_optional")
		elif id == "only_fire":
			card["actions"][0]["selector"] = "on_fire"
			(card["actions"][0] as Dictionary).erase("surface_bonus")
		var entries: Array[Dictionary] = _entries(card)
		for panel: Dictionary in example["panels"]:
			var body: String = Glossary.definition(panel["glossary"], "", panel.get("amount")) if panel.has("glossary") else str(panel["text"])
			_expect(entries.any(func(e: Dictionary) -> bool: return e["title"] == panel["title"] and e["description"] == body), "Exact " + id + " on " + str(example["card"]) + ": " + body)
		print("TT02 ROW %s: %s" % [id, example["card"]])

func _test_tile_target_range() -> void:
	var range_text: String = PanelText.copy("unchanged_choose_a_tile_within_this_range")["card_tooltip"]
	for id: String in ["shattered_reflection", "frost_circuit"]:
		var entries: Array[Dictionary] = _entries(Data.card_def(id))
		_expect(entries.any(func(entry: Dictionary) -> bool: return entry["icon"] == "range" and entry["description"] == range_text), id + " shares the tile-target Range tooltip")

func _test_grimoire() -> void:
	var director: Dictionary = _json(COPY_PATH)
	var facts: Dictionary = _json("res://tests/fixtures/card_panel_grimoire_facts.json")
	var pla02_pages: Dictionary = _json("res://tests/fixtures/pla02_grimoire_pages.json")["pages"]
	var entries: Dictionary = Grimoire.entry_map()
	var ice: Dictionary = _json(PLA06_COPY)
	var updated: Dictionary = _json(TXT20_COPY)["grimoire_bodies"]
	preload("res://tests/fixtures/approved_glossary_structure.gd").apply_pla09_copy(ice["glossary_definitions"], ice["grimoire_bodies"])
	var appended: int = 0
	for row: Dictionary in director["rows"]:
		if row["grimoire"] == null: continue
		_expect(facts.has(row["id"]), "Grimoire fact has an owning topic: " + str(row["id"]))
		# pla-04 retired rows: their topics merged into the two-paragraph Burst page.
		if row["id"] in PLA04_RETIRED_ROWS:
			_expect(not entries.has(facts[row["id"]]["owner"]), "Retired Burst-family topic stays absent: " + str(row["id"]))
			if facts[row["id"]]["appended"]: appended += 1
			continue
		var fact: Dictionary = facts[row["id"]]
		var owner: String = fact["owner"]
		if owner in ["keyword:surface_consume", "keyword:quicken", "keyword:next_attack"]:
			_expect(not entries.has(owner), "Retired term has no topic: " + owner)
			if fact["appended"]: appended += 1
			continue
		var status: Dictionary = _json(PLA07_COPY)
		if owner in ice["retired_grimoire_entries"] or owner in status["retired_grimoire_entries"]:
			_expect(not entries.has(owner), "Retired control topic stays absent: " + owner)
			continue
		if pla02_pages.has(owner):
			_expect(entries[owner]["body"] == pla02_pages[owner], "Merged page owns the fact in " + owner)
			if fact["appended"]: appended += 1
			continue
		if updated.has(owner):
			_expect(entries[owner]["body"] == updated[owner], "Template rules retain the fact in " + owner)
			continue
		if status["grimoire_bodies"].has(owner):
			_expect(entries[owner]["body"] == status["grimoire_bodies"][owner], "Merged status rules own the topic: " + owner)
			continue
		if ice["grimoire_bodies"].has(owner):
			_expect(entries[owner]["body"] == ice["grimoire_bodies"][owner], "Ice rule owns the revised topic: " + owner)
			continue
		for paragraph: String in fact["paragraphs"]:
			var body: Array = entries.get(fact["owner"], {}).get("body", [])
			_expect(body.count(paragraph) == 1, "Grimoire retains the fact exactly once: " + str(row["id"]))
		if fact["appended"]: appended += 1
	print("TT02 GRIMOIRE: %d facts checked; %d paragraphs appended" % [facts.size(), appended])

func _test_assembly() -> void:
	var tokens: Array = []
	for value: int in ASSEMBLY_FIXTURE["same_term_values"]: tokens.append(Icons.token_for("range", value))
	_expect(Icons.tooltip_entries_for_rows([tokens]).size() == 1, "R7 merges the same term and same text")
	tokens.append(Icons.token_for("range", ASSEMBLY_FIXTURE["different_target_value"], "neutral", "Choose an enemy within this range."))
	_expect(Icons.tooltip_entries_for_rows([tokens]).size() == 2, "R7 keeps different target text for one term")
	var token: Dictionary = Icons.tokens_for_action(Data.card_def("petrify")["actions"][0])[0]
	_expect(Icons.token_tooltip(token) == Icons.tooltip("stagger", 6), "Petrify fills the shared Stagger tooltip")
	var before: Dictionary = token.duplicate(true)
	Icons.tooltip_entries_for_rows([[token]])
	_expect(token == before, "Card assembly does not mutate shared tokens")
	var ground: Dictionary = Icons.surface_token("fire", "Leaves this ground in the affected area.")
	ground["modifiers"] = [{"source": "Relic", "amount": ASSEMBLY_FIXTURE["modifier_amount"]}]
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows([[ground, ground]])
	_expect(entries.size() == 1 and entries[0]["description"] == Glossary.definition("surface_fire") + "\nModified by:\nRelic +1", "R3 preserves merged modifier lines unchanged")

func _test_feedback_copy_and_counted_tiles() -> void:
	_expect(PanelText.copy("item_once_per_combat")["card_tooltip"] == "This item can be used once per combat and returns next combat.", "Template rules use the item as the subject")
	_expect(PanelText.copy("empower_health", {"n": 1})["card_tooltip"] == "Lose 1 Health after the card resolves.", "The Empower Health tooltip explains payment timing")
	_expect(str(PanelText.copy("next_attack_element", {"element": "Air"})["card_tooltip"]).ends_with("Only an Air attack uses this bonus."), "Templated Air uses an")
	_expect(str(PanelText.copy("next_attack_element", {"element": "Lightning"})["tooltip"]).ends_with("Only a Lightning attack uses this bonus."), "Templated Lightning uses a in native tooltips")
	var blood_price: Dictionary = Data.card_def("blood_price")
	_expect(str(Icons.empower_copy(blood_price)["card_tooltip"]).ends_with("Empower for 2 Health: +8 damage and Pierce."), "Damage bonus uses the shared Empower template")
	_expect(PanelText.copy("unchanged_leaves_an_illusion_with_this_much_health_where_you_stood")["card_tooltip"] == "Leave an Illusion with X Health on the tile you left.", "Unbound Illusion Health uses X")
	var counted_tiles := RegEx.new()
	counted_tiles.compile("\\{(\\w+)\\} tiles\\b")
	var placeholder := RegEx.new()
	placeholder.compile("\\{(\\w+)\\}")
	var templates: Dictionary = _json(PanelText.DATA_PATH)
	var template_count: int = 0
	var case_count: int = 0
	for id: String in templates:
		var text: String = str(templates[id].get("text", ""))
		var matches: Array[RegExMatch] = counted_tiles.search_all(text)
		if matches.is_empty(): continue
		template_count += 1
		for counted: RegExMatch in matches:
			for count: int in COUNT_FIXTURE["counts"]:
				var values: Dictionary = {}
				for field: RegExMatch in placeholder.search_all(text):
					values[field.get_string(1)] = COUNT_FIXTURE["other_placeholder_value"]
				values[counted.get_string(1)] = count
				var rendered: String = PanelText.copy(id, values)["card_tooltip"]
				var noun: String = "tile" if count == 1 else "tiles"
				_expect(rendered.contains("%d %s" % [count, noun]) and not rendered.contains("1 tiles"), "Counted tiles: %s / %s=%d uses %s" % [id, counted.get_string(1), count, noun])
				case_count += 1
	_expect(template_count > 0, "The counted-tiles test visits the data templates")
	var gale: Array[Dictionary] = _entries(Data.card_def("gale_ward"))
	_expect(gale.any(func(e: Dictionary) -> bool: return e["title"] == "Push" and e["description"] == "Push each enemy within 1 tile of you 1 tile away."), "Gale Ward uses the singular tile sentence in its card stack")
	print("TT02 COUNTED TILE TEMPLATES: %d templates, %d count cases" % [template_count, case_count])

func _write_proof(dump: Array, definitions: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_write(OUTPUT_DIR.path_join("after_panels.json"), dump)
	var baseline: Array = _json("res://spec/peer_benchmark/staged/tt-02/base_panels.json")
	var before: Dictionary = _counts(baseline)
	var after: Dictionary = _counts(dump)
	var comparisons: Array = []
	for id: String in before:
		comparisons.append({"card": id, "before": before[id], "after": after.get(id, {})})
	_write(OUTPUT_DIR.path_join("summary.json"), {"word_count_scope": WORD_COUNT_SCOPE, "base_cards": before.size(), "definitions_with_upgrades": definitions, "before_panels": baseline.size(), "after_base_panels": dump.filter(func(e: Dictionary) -> bool: return not str(e["card"]).contains(":")).size(), "after_all_panels": dump.size(), "cards": comparisons})

static func _counts(dump: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in dump:
		var id: String = entry["card"]
		if not counts.has(id): counts[id] = {"panels": 0, "words": 0, "body_words": 0}
		counts[id]["panels"] += 1
		var body_words: int = str(entry["text"]).replace("\n", " ").replace("\t", " ").split(" ", false).size()
		counts[id]["body_words"] += body_words
		counts[id]["words"] += body_words + str(entry["title"]).split(" ", false).size()
	return counts

static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
