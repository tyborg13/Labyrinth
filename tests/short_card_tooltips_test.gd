extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Proof = preload("res://tests/helpers/short_card_tooltips_proof.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const DiscoverySync = preload("res://scripts/grimoire_discovery_sync.gd")
const RETIRED_TERMS: PackedStringArray = ["dive", "veil", "lob", "icefall", "burrow", "erupt", "flurry", "aoe", "detonate", "discharge", "shatter_illusion", "freeze", "chilled", "petrify", "bleed", "sunder", "truesight", "dispel_umbra", "radiance"] # sta-01/mrk-01/flu-01/pla-04; protected copy stays intact.
## pla-04 (Burst merge): the approved copy superseding the protected records.
const PLA08_COPY_PATH: String = "res://tests/fixtures/pla08_light_vision_copy.json"
const PLA04_COPY_PATH: String = "res://tests/fixtures/pla04_burst_copy.json"
const PLA07_COPY_PATH: String = "res://tests/fixtures/pla07_status_copy.json"
const PLA06_COPY_PATH: String = "res://tests/fixtures/pla06_ice_copy.json"
const UMBRA_AREA_BODY: String = "Darkness that limits your sight. Hidden enemies show no intent and can't be targeted. Attacks that hit an area hit hidden enemies on those tiles too."
const TXT20_COPY_PATH: String = "res://tests/fixtures/txt20_rules_copy.json"
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-01/tooltips.json"
const EXPECTATIONS_PATH: String = "res://tests/fixtures/short_card_tooltips_expectations.json"
var _failures: Array[String]
var _checks: int = 0
var _expectations: Dictionary
var _pla02_pages: Dictionary = {}

class DiscoveryScene extends Node:
	var _run_state: Dictionary = {}
	var _combat_state: Dictionary = {}
	var unlock_calls: int = 0

	func _append_unique_grimoire_ids(target: Array[String], ids: Array[String]) -> void:
		for id: String in ids:
			if not target.has(id): target.append(id)

	func _unlock_grimoire_entries(ids: Array[String]) -> void:
		_run_state = Grimoire.unlock_entries(_run_state, ids)["state"]
		unlock_calls += 1

func _initialize() -> void:
	call_deferred("_run")

const TRP01_TRAP_BODY: Array = [
	"A trap triggers when a unit enters its tile or an attack hits that tile. The trap damages the unit on its tile, then leaves its element on that tile and each tile next to it. An Air trap leaves no ground: it pushes each unit next to it 1 tile away.",
	"Trigger when entered or attacked. Damage the unit on them, then leave their element on their tile and each tile next to it."
]

const HOUSE_STYLE_GRIMOIRE := {
	"skate": "This turn Ice costs you no Movement and doesn't Expose you.",
	"surface_electrified": "A Lightning hit that touches it spreads to every enemy on connected Electrified tiles. Chain relays through it.",
	"targeting": "Targets must be visible and within Range. Ranged attacks also need line of sight; walls and Outcrops block it.",
	"reflect": "Attacks from a non-adjacent tile bounce back to the attacker.", # pla-01: the rule now matches the tooltip; no exception list.
}

func _run() -> void:
	Runtime.apply_from_environment()
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
	_expectations = JSON.parse_string(FileAccess.get_file_as_string(EXPECTATIONS_PATH))
	# mim-01 retires Mirror without modifying the historical director fixtures.
	copy["entries"] = (copy["entries"] as Array).filter(func(entry: Dictionary) -> bool: return entry["id"] != "mirror")
	(_expectations["owners"] as Dictionary).erase("mirror")
	(_expectations["new_terms"] as Array).erase("mirror")
	(_expectations["triggers"] as Dictionary).erase("mirror")
	(_expectations["encounters"]["hollow_mimic"]["unlocks"] as Array).erase("mirror")
	# pla-04 (Burst merge): Discharge, Shattered Reflection and Rockburst unlock
	# Burst; Groundsplit (the terrain_burst entry) is taught by Craghide.
	var pla04_encounters: Dictionary = _expectations["encounters"]
	pla04_encounters["discharge"]["unlocks"] = ["burst", "element_lightning"]
	pla04_encounters["shattered_reflection"]["unlocks"] = ["burst"]
	pla04_encounters["rockburst"]["unlocks"] = ["burst", "element_earth"]
	pla04_encounters["craghide"] = {"combat": {"enemies": [{"type": "craghide"}]}, "unlocks": ["terrain_burst", "outcrop"]}
	(_expectations["triggers"] as Dictionary)["terrain_burst"] = "craghide"
	var entry_map: Dictionary = Grimoire.entry_map()
	var copy20: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TXT20_COPY_PATH))
	var pla04: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLA04_COPY_PATH))
	_expect(Glossary.all_entries().size() == 128, "Final glossary contains all 128 live entries")
	_expect(Glossary.definition("marked") == "Marked tiles show where this enemy will act.", "Marked retains its approved definition")
	var deferred_copy: String = "Skip a card reward to save 1 offered card. Replace 1 card in your next non-boss reward with that card."
	_expect(Glossary.definition("skill_deferred_choice") == deferred_copy and Skills.description("deferred_choice") == deferred_copy, "Deferred Choice uses its exact shared non-boss reward rule")
	var pla01: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pla01_exception_strip.json"))
	# pla-02: director-approved Grimoire pages (tooltip sentence + one detail
	# paragraph) supersede every Grimoire body pinned below.
	var pla02_pages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pla02_grimoire_pages.json"))["pages"]
	pla02_pages["keyword:marked"][0] = "Marked tiles show where this enemy will act."
	pla02_pages["combat:traps"][0] = "Traps hit when entered or attacked."
	_pla02_pages = pla02_pages
	_expect(entry_map["keyword:marked"]["body"] == pla02_pages["keyword:marked"] and str(pla02_pages["keyword:marked"][0]) == Glossary.definition("marked"), "Marked owns the definition replacing the four retired topics, plus its Burrow detail")
	var changes: Dictionary = {}
	var tt02: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/tt-02/card_panels.json"))
	var superseding: Dictionary = {}
	for edit: Dictionary in tt02["glossary_edits"]:
		superseding[edit["id"]] = edit["text"]
	superseding["retaliate"] = "Until its next turn, whoever hits this unit up close takes that much damage."
	# trp-01 (owner 2026-11-16): traps also leave their ground on their own tile; director copy supersedes the tt-era text.
	superseding["traps"] = "Trigger when entered or attacked: damage the unit on them, then leave their element on their tile and each tile next to it. Air traps push instead."
	superseding["surface_rubble"] = "Costs 2 Movement to leave."
	superseding["skate"] = "This turn Ice costs you no Movement and doesn't Expose you."
	superseding.merge(pla04["glossary_definitions"], true)
	var pla06: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLA06_COPY_PATH))
	superseding.merge(pla06["glossary_definitions"], true)
	(pla04["grimoire_bodies"] as Dictionary).merge(pla06["grimoire_bodies"], true)
	var status: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLA07_COPY_PATH))
	(pla04["grimoire_bodies"] as Dictionary).merge(status["grimoire_bodies"], true)
	preload("res://tests/fixtures/approved_glossary_structure.gd").apply_pla09_copy(superseding, pla04["grimoire_bodies"])
	var pla08: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLA08_COPY_PATH))
	superseding.merge(pla08["definitions"], true)
	superseding.merge(copy20["glossary_definitions"], true)
	superseding.merge(pla01["glossary"], true)
	superseding["traps"] = "Traps hit when entered or attacked."
	_expect((_expectations["owners"] as Dictionary).size() == (copy["entries"] as Array).size(), "Every changed term has an independently specified owning topic")
	for change: Dictionary in copy["entries"]:
		var id: String = str(change["id"])
		changes[id] = change
		if id in RETIRED_TERMS:
			_expect(not Glossary.all_entries().any(func(entry: Dictionary) -> bool: return entry["id"] == id) and not entry_map.has("keyword:" + id), "Retired glossary and Grimoire identity stays absent: " + id)
			if id in ["lob", "icefall", "burrow", "erupt"]:
				_expect(Glossary.lookup(id).get("id", "") == "marked", "Retired marked move resolves to the shared Marked topic: " + id)
			elif id in (pla04["retired_glossary_terms"] as Array):
				_expect(Glossary.lookup(id).get("id", "") == "burst", "Retired Burst-family term resolves to Burst: " + id)
			else:
				_expect(Glossary.lookup(id).is_empty(), "Retired keyword has no glossary alias: " + id)
			continue
		if id == "worldspines":
			_expect(Glossary.lookup(id).is_empty(), "The retired glossary term is absent")
		else:
			_expect(Glossary.definition(id) == superseding.get(id, change["tooltip"]), "Protected short copy: " + id)
		var owner: String = str((_expectations["owners"] as Dictionary).get(id, ""))
		var entry: Dictionary = entry_map.get(owner, {})
		_expect(not entry.is_empty(), "Expected owning topic exists: " + id + " -> " + owner)
		if pla02_pages.has(owner):
			_expect(entry.get("body", []) == pla02_pages[owner], "pla-02 page owns the rules: " + id + " -> " + owner)
		elif copy20["grimoire_bodies"].has(owner):
			_expect(entry.get("body", []) == copy20["grimoire_bodies"][owner], "Template rules own the topic: " + id + " -> " + owner)
		elif id in ["gale_force", "worldspines"]:
			var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_feedback1_grimoire.json"))
			var expected_body: Array = approved["entries"][owner]["body"]
			if id == "worldspines":
				expected_body[0] = str(expected_body[0]).replace(
					"After every second turn of yours, the marked tiles rise as Outcrops: stone that blocks movement until it is broken.",
					"After every second turn of yours, Tharokh's marked tiles rise as Outcrops. A marked tile stays flat if the unit on it can't be pushed off or has nowhere to land."
				)
			_expect(entry.get("body", []) == expected_body, "Grimoire retains the approved full rules: " + id)
		elif id == "outcrop":
			_expect(owner == "combat:outcrops" and str(entry["body"][0]).contains("An Outcrop blocks movement and line of sight"), "One Outcrops article owns the full rule")
		elif id == "traps":
			_expect(entry.get("body", []) == TRP01_TRAP_BODY, "trp-01 director rules own the trap topic: " + id + " -> " + owner)
		elif (pla04["grimoire_bodies"] as Dictionary).has(owner):
			_expect(entry.get("body", []) == pla04["grimoire_bodies"][owner], "Playability rules own the topic: " + id + " -> " + owner)
		elif pla08["grimoire_bodies"].has(owner):
			_expect(entry.get("body") == pla08["grimoire_bodies"][owner], "pla-08 Grimoire copy: " + id)
		else:
			var expected: String = pla08["grimoire_line_updates"].get(id, UMBRA_AREA_BODY if id == "umbra" else HOUSE_STYLE_GRIMOIRE.get(id, status["grimoire_paragraphs"].get(id, change["old"])))
			_expect((entry.get("body", []) as Array).has(expected), "Full rules remain in their expected owning topic: " + id + " -> " + owner)
	var bodies: Dictionary = (pla04["grimoire_bodies"] as Dictionary).merged(copy20["grimoire_bodies"], true)
	_test_new_entry_schema(changes, entry_map, bodies, pla08, pla01["grimoire_appended"])
	_test_discovery()
	var proof := Proof.new()
	await proof.run(self, _expect, OS.get_cmdline_user_args().has("--capture"))
	for failure: String in _failures:
		push_error(failure)
	print("SHORT CARD TOOLTIPS TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_new_entry_schema(changes: Dictionary, entry_map: Dictionary, playability_bodies: Dictionary, pla08: Dictionary, pla01_appended: Dictionary) -> void:
	_expect(not entry_map.has("keyword:outcrop") and not Glossary.lookup("outcrop").is_empty(), "The Outcrop glossary term remains and only the combat article is listed")
	for term: String in _expectations["new_terms"]:
		if term == "outcrop": continue
		if term in RETIRED_TERMS: continue
		var entry: Dictionary = entry_map.get("keyword:" + term, {})
		var glossary: Dictionary = Glossary.lookup(term)
		var icon: Variant = glossary["icon"]
		if term in ["skill_point", "moltshard"]: icon = term
		_expect(entry.get("id") == "keyword:" + term, "New entry retains its id: " + term)
		_expect(entry.get("section") == "keywords", "New entry remains in Keywords: " + term)
		_expect(entry.get("title") == glossary["name"], "New entry uses its glossary title: " + term)
		_expect(entry.has("icon") and entry.get("icon") == icon, "New entry uses its approved icon, including explicit null: " + term)
		if _pla02_pages.has("keyword:" + term):
			_expect(entry.get("body") == _pla02_pages["keyword:" + term], "Merged keyword page: " + term)
			continue
		if playability_bodies.has("keyword:" + term):
			_expect(entry.get("body") == playability_bodies["keyword:" + term], "Playability entry body: " + term)
			continue
		var expected_body: Array = [pla08["grimoire_line_updates"].get(term, HOUSE_STYLE_GRIMOIRE.get(term, changes[term]["old"]))]
		var tt02_facts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/card_panel_grimoire_facts.json"))
		for fact: Dictionary in tt02_facts.values():
			if fact["owner"] == "keyword:" + term and fact["appended"]:
				expected_body.append_array(fact["paragraphs"])
		expected_body.append_array(pla01_appended.get("keyword:" + term, []))
		_expect(entry.get("body") == expected_body, "New entry has its own full definition paragraph: " + term)
		_expect(not entry.has("default") or typeof(entry["default"]) == TYPE_BOOL, "New entry default flag is boolean when present: " + term)

func _test_discovery() -> void:
	var before_failures: int = _failures.size()
	var entry_map: Dictionary = Grimoire.entry_map()
	var defaults: Array[String] = Grimoire.default_entry_ids()
	var default_count: int = 0
	var discovered_count: int = 0
	var triggers: Dictionary = _expectations["triggers"]
	var encounters: Dictionary = _expectations["encounters"]
	_expect((_expectations["new_terms"] as Array).size() == 38, "Discovery regression covers all 38 retained entries")
	_expect(triggers.size() == 28, "Each discovered term has a hand-written trigger fixture")
	for term: String in _expectations["new_terms"]:
		if term in RETIRED_TERMS: continue
		var id: String = _entry_id(term)
		var entry: Dictionary = entry_map[id]
		_expect(not entry.has("TODO_DESIGN_GRIMOIRE_DISCOVERY"), "Discovery policy is resolved: " + term)
		var is_default: bool = _is_default(term)
		_expect(defaults.has(id) == is_default, "Only general rules and approved no-trigger fallbacks are default: " + term)
		if is_default:
			default_count += 1
			_expect(not triggers.has(term), "Default term does not require an encounter: " + term)
			continue
		discovered_count += 1
		_expect(triggers.has(term), "Discovered term has an independent trigger: " + term)
		var encounter: Dictionary = encounters.get(str(triggers.get(term, "")), {})
		_expect((encounter.get("unlocks", []) as Array).has(term), "Trigger fixture explicitly expects its term: " + term)
	for name: String in encounters:
		_test_encounter(name, encounters[name])
	print("TT01 GRIMOIRE DISCOVERY: %s (active entries; %d default, %d discovered; %d independent encounters)" % ["PASS" if _failures.size() == before_failures else "FAIL", default_count, discovered_count, encounters.size()])

func _test_encounter(name: String, encounter: Dictionary) -> void:
	var scene := DiscoveryScene.new()
	var sync := DiscoverySync.new()
	scene._run_state = Grimoire.ensure_run_state({})
	sync.sync(scene)
	_expect(_new_discovered_ids(scene._run_state[Grimoire.UNLOCKED_KEY]).is_empty(), "All discovered terms start locked before " + name)
	scene._run_state.merge((encounter.get("run", {}) as Dictionary).duplicate(true), true)
	scene._combat_state = (encounter.get("combat", {}) as Dictionary).duplicate(true)
	sync.sync(scene)
	var expected: Array[String]
	for term: String in encounter["unlocks"]:
		if term not in RETIRED_TERMS: expected.append(_entry_id(term))
	expected.sort()
	var actual: Array[String] = _new_discovered_ids(scene._run_state[Grimoire.UNLOCKED_KEY])
	_expect(actual == expected, "Exact new keyword unlocks for %s: expected=%s actual=%s" % [name, expected, actual])
	_expect(_new_discovered_ids(scene._run_state[Grimoire.UNREAD_KEY]) == expected, "Only expected new terms become unread for " + name)
	var calls: int = scene.unlock_calls
	sync.sync(scene)
	_expect(scene.unlock_calls == calls, "Unchanged encounter does not repeat discovery: " + name)
	scene.free()

func _entry_id(term: String) -> String:
	return "combat:outcrops" if term == "outcrop" else "keyword:" + term

func _is_default(term: String) -> bool:
	return (_expectations["general_defaults"] as Array).has(term) or (_expectations["fallback_defaults"] as Array).has(term)

func _new_discovered_ids(ids: Array) -> Array[String]:
	var result: Array[String]
	for term: String in _expectations["new_terms"]:
		if term in RETIRED_TERMS: continue
		if not _is_default(term) and ids.has(_entry_id(term)): result.append(_entry_id(term))
	result.sort()
	return result

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
