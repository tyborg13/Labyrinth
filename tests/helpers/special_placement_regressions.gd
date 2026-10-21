extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const V7Suite = preload("res://tests/suites/section_map_v7_suite.gd")
const RELEASE_TEST_SEED: int = 0
const SNARE_TEST_SEEDS: int = 64
const SNARE_TEST_ROOM_COUNT: int = 6
const SNARE_CANDIDATE: Vector2i = Vector2i(3, 0)
const SNARE_BYPASS: Vector2i = Vector2i(3, 1)
const SNARE_EXIT: Vector2i = Vector2i(4, 0)
const SNARE_SECOND_EXIT: Vector2i = Vector2i(4, 1)

static func run(expect: Callable) -> void:
	_test_release_fallback(expect)
	_test_snare_exits(expect)

static func _test_release_fallback(expect: Callable) -> void:
	# Compile a headless copy with assertions removed, as in a release build,
	# and force the repair path. This catches work hidden inside assert even
	# when the ordinary seed sweep never needs the fallback.
	var lines: PackedStringArray
	var forced: bool = false
	for line: String in FileAccess.get_file_as_string("res://scripts/section_map_graph.gd").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("class_name "): continue
		if stripped.begins_with("assert("):
			line = line.substr(0, line.find("assert(")) + "pass"
		elif stripped.begins_with("if revision >= 6 and not Specials.place("):
			line = "\t\tif revision >= 6:"
			forced = true
		lines.append(line)
	expect.call(forced, "Release regression forces the production fallback branch")
	var release_graph := GDScript.new()
	release_graph.source_code = "\n".join(lines)
	var compiled: Error = release_graph.reload()
	expect.call(compiled == OK, "Release-style fallback copy compiles through Godot")
	if compiled != OK: return
	# Revision 6 falls back to the straight layout, whose legal slots hold one
	# special; revision 7 falls back to a stored web, which can hold more.
	for revision: int in [6, 7]:
		var state: Dictionary = {"seed": RELEASE_TEST_SEED, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": revision}
		release_graph.initialize(state)
		for index: int in range(6):
			var count: int = 0
			for room: Dictionary in state["rooms"].values():
				if int(room["section_index"]) == index and room["type"] == "special": count += 1
			expect.call(count == 1 if revision == 6 else count >= 1, "Assertion-free revision %d fallback places an enabled special in section %d" % [revision, index + 1])
			if revision == 7:
				# The repaired section must still be a valid revision-7 web.
				V7Suite.test_section_rules(state, index, expect)
				V7Suite.test_doors(state, index, expect)
				V7Suite.test_layout(state, index, expect)
	print("SPX release fallback regression: checked 6 sections of revisions 6 and 7 with assertions removed")

static func _test_snare_exits(expect: Callable) -> void:
	var data: Dictionary = Specials.catalog()
	for type: String in data["types"]: data["types"][type]["enabled"] = type == "umbral_snare"
	for seed_value: int in range(SNARE_TEST_SEEDS):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var one_exit: Dictionary = _snare_layout(false)
		var before: Dictionary = one_exit.duplicate(true)
		expect.call(one_exit["children"][SNARE_CANDIDATE].size() == 1, "Negative Snare fixture has exactly one exit")
		var placed: bool = Specials.place(one_exit, rng, SNARE_TEST_ROOM_COUNT, "earth", data)
		expect.call(not placed and one_exit == before, "A one-exit combat never becomes a Snare")
		# With a second exit, the same combat must convert; the bypass route
		# remains free of specials. This rejects a vacuous 'place nothing' pass.
		var two_exits: Dictionary = _snare_layout(true)
		rng.seed = seed_value
		placed = Specials.place(two_exits, rng, SNARE_TEST_ROOM_COUNT, "earth", data)
		expect.call(placed and two_exits["nodes"][SNARE_CANDIDATE].get("special_type", "") == "umbral_snare", "The paired two-exit fixture places a Snare")
	print("SPX Snare exit regression: checked 64 seeds with one-exit rejection and two-exit placement")

static func _snare_layout(second_exit: bool) -> Dictionary:
	var exits: Array[Vector2i]
	exits.append(SNARE_EXIT)
	if second_exit: exits.append(SNARE_SECOND_EXIT)
	var second_parents: Array[Vector2i]
	second_parents.append(SNARE_BYPASS)
	if second_exit: second_parents.append(SNARE_CANDIDATE)
	return {
		"order": [SNARE_CANDIDATE, SNARE_BYPASS, SNARE_EXIT, SNARE_SECOND_EXIT],
		"nodes": {
			SNARE_CANDIDATE: {"type": "combat"}, SNARE_BYPASS: {"type": "event"},
			SNARE_EXIT: {"type": "event"}, SNARE_SECOND_EXIT: {"type": "event"},
		},
		"children": {SNARE_CANDIDATE: exits, SNARE_BYPASS: [SNARE_SECOND_EXIT], SNARE_EXIT: [], SNARE_SECOND_EXIT: []},
		"parents": {SNARE_CANDIDATE: [], SNARE_BYPASS: [], SNARE_EXIT: [SNARE_CANDIDATE], SNARE_SECOND_EXIT: second_parents},
	}
