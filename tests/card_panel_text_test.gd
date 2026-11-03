extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const ItemRules = preload("res://scripts/item_relic_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const PanelText = preload("res://scripts/card_panel_text.gd")
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-02/card_panels.json"
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
		var entries: Array[Dictionary] = _entries(card)
		for problem: String in stack_errors(entries, card):
			_expect(false, id + ": " + problem)
		_checks += entries.size()
		for entry: Dictionary in entries:
			dump.append({"card": id, "name": card.get("name", id), "icon": entry["icon"], "glossary_key": entry.get("glossary_key", entry["icon"]), "title": entry["title"], "text": entry["description"]})
	_test_examples()
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

static func _entries(card: Dictionary) -> Array[Dictionary]:
	var leading: Array = []
	if Icons.card_is_rite(card): leading.append("rite")
	return Icons.tooltip_entries_for_rows(Icons.rows_for_card(card), leading)

static func stack_errors(entries: Array[Dictionary], card: Dictionary) -> Array[String]:
	var errors: Array[String]
	var sentences: Dictionary = {}
	var semantics: Dictionary = {}
	var term_titles: Array = []
	for glossary: Dictionary in Glossary.all_entries(): term_titles.append(glossary["name"])
	for row: Dictionary in _json(COPY_PATH)["rows"]: term_titles.append(row["title"])
	term_titles.append("Rubble")
	var hidden: Array = []
	_collect_cleanse_statuses(card, hidden)
	for entry: Dictionary in entries:
		var title: String = str(entry.get("title", ""))
		var body: String = str(entry.get("description", "")).split("\nModified by:", true, 1)[0]
		var term: String = str(entry.get("glossary_key", entry.get("icon", "")))
		var marks: int = body.count(".") + body.count("!") + body.count("?")
		if body.is_empty(): errors.append("Empty body: " + title)
		if body.contains("\n") or marks != 1 or body.split(" ", false).size() > 16:
			errors.append("R1: " + title + ": " + body)
		if sentences.has(body): errors.append("R4 repeated sentence: " + body)
		if hidden.has(term): errors.append("R5 Cleanse status: " + term)
		if not term_titles.has(title) or title.is_empty() or title.split(" ", false).size() > 4 or title.ends_with("."):
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
		var example: Dictionary = examples[id]
		var card: Dictionary = example.get("definition", Data.card_def(example["card"]))
		_expect(not card.is_empty(), "Representative exists: " + id + " -> " + str(example["card"]))
		var entries: Array[Dictionary] = _entries(card)
		for panel: Dictionary in example["panels"]:
			var body: String = Glossary.definition(panel["glossary"]) if panel.has("glossary") else str(panel["text"])
			_expect(entries.any(func(e: Dictionary) -> bool: return e["title"] == panel["title"] and e["description"] == body), "Exact " + id + " on " + str(example["card"]) + ": " + body)
		print("TT02 ROW %s: %s" % [id, example["card"]])

func _test_grimoire() -> void:
	var director: Dictionary = _json(COPY_PATH)
	var facts: Dictionary = _json("res://tests/fixtures/card_panel_grimoire_facts.json")
	var entries: Dictionary = Grimoire.entry_map()
	var appended: int = 0
	for row: Dictionary in director["rows"]:
		if row["grimoire"] == null: continue
		_expect(facts.has(row["id"]), "Grimoire fact has an owning topic: " + str(row["id"]))
		var fact: Dictionary = facts[row["id"]]
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
	var token: Dictionary = Icons.tokens_for_action({"type": "petrify", "range": ASSEMBLY_FIXTURE["petrify_range"]})[0]
	_expect(Icons.token_tooltip(token).contains("Dragons are immune."), "Enemy/native token tooltip retains its original rules")
	var before: Dictionary = token.duplicate(true)
	Icons.tooltip_entries_for_rows([[token]])
	_expect(token == before, "Card assembly does not mutate shared tokens")
	var ground: Dictionary = Icons.surface_token("fire", "Leaves this ground in the affected area.")
	ground["modifiers"] = [{"source": "Relic", "amount": ASSEMBLY_FIXTURE["modifier_amount"]}]
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows([[ground, ground]])
	_expect(entries.size() == 1 and entries[0]["description"] == Glossary.definition("surface_fire") + "\nModified by:\nRelic +1", "R3 preserves merged modifier lines unchanged")

func _test_feedback_copy_and_counted_tiles() -> void:
	_expect(PanelText.copy("item_once_per_combat")["card_tooltip"] == "Usable once per combat; it returns next combat.", "Feedback 1: approved once-per-combat copy replaces the design placeholder")
	_expect(PanelText.copy("empower_health", {"n": 1})["card_tooltip"] == "Empower cost: lose 1 Health after the card resolves.", "Feedback 1: Empower uses lose and capitalised Health")
	_expect(PanelText.copy("unchanged_leaves_an_illusion_with_this_much_health_where_you_stood")["card_tooltip"] == "Leaves an illusion with this much Health where you stood.", "Feedback 1: illusion Health is capitalised")
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
	_expect(gale.any(func(e: Dictionary) -> bool: return e["title"] == "Push" and e["description"] == "Pushes each enemy within 1 of you 1 tile away."), "Gale Ward uses the singular tile sentence in its card stack")
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
