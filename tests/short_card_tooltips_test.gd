extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Proof = preload("res://tests/helpers/short_card_tooltips_proof.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const DiscoverySync = preload("res://scripts/grimoire_discovery_sync.gd")
const RETIRED_TERMS: PackedStringArray = ["dive", "veil", "lob", "icefall", "burrow", "erupt", "flurry"] # sta-01/mrk-01/flu-01; protected copy stays intact.
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-01/tooltips.json"
const EXPECTATIONS_PATH: String = "res://tests/fixtures/short_card_tooltips_expectations.json"
var _failures: Array[String]
var _checks: int = 0
var _expectations: Dictionary

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
	var entry_map: Dictionary = Grimoire.entry_map()
	_expect(Glossary.all_entries().size() == 140, "Final glossary contains all 140 live entries")
	_expect(Glossary.definition("marked") == "These tiles take the hit on this enemy's next turn.", "Marked retains its approved definition")
	_expect(entry_map["keyword:marked"]["body"] == [Glossary.definition("marked")], "Marked owns the full definition replacing the four retired topics")
	var changes: Dictionary = {}
	var tt02: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/tt-02/card_panels.json"))
	var superseding: Dictionary = {}
	for edit: Dictionary in tt02["glossary_edits"]:
		superseding[edit["id"]] = edit["text"]
	superseding["retaliate"] = "Until its next turn, whoever hits this unit up close takes that much damage."
	_expect((_expectations["owners"] as Dictionary).size() == (copy["entries"] as Array).size(), "Every changed term has an independently specified owning topic")
	for change: Dictionary in copy["entries"]:
		var id: String = str(change["id"])
		changes[id] = change
		if id in RETIRED_TERMS:
			_expect(not Glossary.all_entries().any(func(entry: Dictionary) -> bool: return entry["id"] == id) and not entry_map.has("keyword:" + id), "Retired glossary and Grimoire identity stays absent: " + id)
			if id in ["lob", "icefall", "burrow", "erupt"]:
				_expect(Glossary.lookup(id).get("id", "") == "marked", "Retired marked move resolves to the shared Marked topic: " + id)
			else:
				_expect(Glossary.lookup(id).is_empty(), "Retired keyword has no glossary alias: " + id)
			continue
		_expect(Glossary.definition(id) == superseding.get(id, change["tooltip"]), "Protected short copy: " + id)
		var owner: String = str((_expectations["owners"] as Dictionary).get(id, ""))
		var entry: Dictionary = entry_map.get(owner, {})
		_expect(not entry.is_empty(), "Expected owning topic exists: " + id + " -> " + owner)
		# bos-02 replaces these two retired dragon rules with approved full bodies.
		if id in ["gale_force", "worldspines"]:
			var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_feedback1_grimoire.json"))
			_expect(entry.get("body", []) == approved["entries"][owner]["body"], "bos-02 approved full rules replace retired prose: " + id)
		else:
			_expect((entry.get("body", []) as Array).has(change["old"]), "Full rules remain in their expected owning topic: " + id + " -> " + owner)
	_test_new_entry_schema(changes, entry_map)
	_test_discovery()
	var proof := Proof.new()
	await proof.run(self, _expect, OS.get_cmdline_user_args().has("--capture"))
	for failure: String in _failures:
		push_error(failure)
	print("SHORT CARD TOOLTIPS TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_new_entry_schema(changes: Dictionary, entry_map: Dictionary) -> void:
	for term: String in _expectations["new_terms"]:
		if term in RETIRED_TERMS: continue
		var entry: Dictionary = entry_map.get("keyword:" + term, {})
		var glossary: Dictionary = Glossary.lookup(term)
		var icon: Variant = glossary["icon"]
		if term in ["skill_point", "moltshard"]: icon = term
		_expect(entry.get("id") == "keyword:" + term, "New entry retains its id: " + term)
		_expect(entry.get("section") == "keywords", "New entry remains in Keywords: " + term)
		_expect(entry.get("title") == glossary["name"], "New entry uses its glossary title: " + term)
		_expect(entry.has("icon") and entry.get("icon") == icon, "New entry uses its approved icon, including explicit null: " + term)
		var expected_body: Array = [changes[term]["old"]]
		var tt02_facts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/card_panel_grimoire_facts.json"))
		for fact: Dictionary in tt02_facts.values():
			if fact["owner"] == "keyword:" + term and fact["appended"]:
				expected_body.append_array(fact["paragraphs"])
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
		var id: String = "keyword:" + term
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
		if term not in RETIRED_TERMS: expected.append("keyword:" + term)
	expected.sort()
	var actual: Array[String] = _new_discovered_ids(scene._run_state[Grimoire.UNLOCKED_KEY])
	_expect(actual == expected, "Exact new keyword unlocks for %s: expected=%s actual=%s" % [name, expected, actual])
	_expect(_new_discovered_ids(scene._run_state[Grimoire.UNREAD_KEY]) == expected, "Only expected new terms become unread for " + name)
	var calls: int = scene.unlock_calls
	sync.sync(scene)
	_expect(scene.unlock_calls == calls, "Unchanged encounter does not repeat discovery: " + name)
	scene.free()

func _is_default(term: String) -> bool:
	return (_expectations["general_defaults"] as Array).has(term) or (_expectations["fallback_defaults"] as Array).has(term)

func _new_discovered_ids(ids: Array) -> Array[String]:
	var result: Array[String]
	for term: String in _expectations["new_terms"]:
		if term in RETIRED_TERMS: continue
		if not _is_default(term) and ids.has("keyword:" + term): result.append("keyword:" + term)
	result.sort()
	return result

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
