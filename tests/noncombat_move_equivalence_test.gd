extends SceneTree

const Run = preload("res://scripts/run_engine.gd")
const Original = preload("res://tests/fixtures/noncombat_move_reference.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Data = preload("res://scripts/game_data.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")

class ObservedCurrent extends Run:
	var layout_calls: int = 0
	var stock_calls: int = 0
	func _display_layout_for_room(value: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
		layout_calls += 1
		return super._display_layout_for_room(value, room, travel_dir)
	func _merchant_room_with_stock(state: Dictionary, room: Dictionary, kind: String) -> Dictionary:
		stock_calls += 1
		return super._merchant_room_with_stock(state, room, kind)

class ObservedOriginal extends Original:
	var layout_calls: int = 0
	var stock_calls: int = 0
	func _display_layout_for_room(value: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
		layout_calls += 1
		return super._display_layout_for_room(value, room, travel_dir)
	func _merchant_room_with_stock(state: Dictionary, room: Dictionary, kind: String) -> Dictionary:
		stock_calls += 1
		return super._merchant_room_with_stock(state, room, kind)

var errors: Array[String]
var cases: int = 0
var checks: int = 0
var removed_layouts: int = 0
var removed_stock_builds: int = 0
var coverage: Dictionary = {}

func _initialize() -> void:
	Parallel.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var factory := Run.new()
	var catalogs: Array = [Data.cards(), Data.enemies(), Data.npcs(), Data.equipment(), Data.relics()].duplicate(true)
	var profile: Dictionary = Tutorial.complete_tutorial(Progression.default_data())
	# Every generated forward link across all six sections. Preserve the authored
	# destinations and map topology, reveal only enough to select each real link.
	for value: int in [0, 1, 32, 84217, 2147483647]:
		var base: Dictionary = factory.create_new_run(value, profile)
		for source: Dictionary in (base["rooms"] as Dictionary).values():
			for connection: Dictionary in source.get("connections", []):
				var destination: Vector2i = connection["coord"]
				var input: Dictionary = _selectable(base, source["coord"], destination)
				if not factory.available_moves(input).has(destination): continue
				coverage["section_%d" % int(source["section_index"])] = true
				_compare(input, destination, "generated/%d/section%d/%s" % [value, int(source["section_index"]), str(destination)], true)
		await process_frame
	# The same explicit destination types exercise both new graph state and
	# pre-section-map saves, including absent/default and unknown legacy types.
	for graph: bool in [false, true]:
		for value: int in [11, 57, 290735]:
			var base: Dictionary = factory.create_new_run(value, profile, graph)
			var route: Dictionary = _route(base, factory)
			_check(not route.is_empty(), "Fixture must contain a selectable route")
			if route.is_empty(): continue
			var destination: Vector2i = route["destination"]
			for kind: String in ["start", "campfire", "scavenger", "graftwright", "event", "treasure", "combat", "boss", "guardian", "blacksmith", "arcanist", "unknown_legacy", ""]:
				for variation: String in ["normal", "cleared", "npc", "missing_type"]:
					var input: Dictionary = route["state"].duplicate(true)
					var room: Dictionary = input["rooms"][_key(destination)]
					room["type"] = kind
					room["cleared"] = variation == "cleared"
					room["merchant_kind"] = ""
					room["npcs"] = [{"id": "emaciated_man", "pos": Vector2i(4, 3)}] if variation == "npc" else []
					room["element"] = "fire" if kind in ["combat", "boss", "guardian"] else "none"
					if variation == "missing_type": room.erase("type")
					_compare(input, destination, "type/%s/%d/%s/%s" % [str(graph), value, kind, variation], true)
			_merchant_cases(route, factory, graph)
			_recovery_cases(route, graph)
			_invalid_cases(route, graph)
			if not graph:
				_legacy_choices(route, factory)
				_legacy_missing_type_and_deeper_pair(base, factory)
			await process_frame
	_check(catalogs == [Data.cards(), Data.enemies(), Data.npcs(), Data.equipment(), Data.relics()], "Queries must preserve every mutable source catalog")
	for section: int in range(6): _check(coverage.has("section_%d" % section), "Generated proof must enter every section")
	_check(removed_layouts > 100, "The proof must remove actual discarded layout generations")
	_check(removed_stock_builds > 10, "The proof must remove actual discarded merchant stock builds")
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(orphans == 0, "Move proof must release every owned node")
	print("NONCOMBAT MOVE EQUIVALENCE RESULT: " + JSON.stringify({"cases": cases, "checks": checks, "errors": errors, "removed_layout_generations": removed_layouts, "removed_stock_generations": removed_stock_builds, "coverage": coverage, "orphans": orphans}))
	quit(0 if errors.is_empty() else 1)

func _selectable(base: Dictionary, source: Vector2i, destination: Vector2i) -> Dictionary:
	var input: Dictionary = base.duplicate(true)
	input["current_room"] = source
	input["mode"] = "room"
	input["combat_state"] = {}
	var factory := Run.new()
	var source_room: Dictionary = factory.room_metadata(input, source)
	var target: Dictionary = factory.room_metadata(input, destination)
	source_room.merge({"revealed": true, "visited": true, "cleared": true, "sealed": false}, true)
	target.merge({"revealed": true, "sealed": false}, true)
	input["rooms"][_key(source)] = source_room
	input["rooms"][_key(destination)] = target
	# Stale pending keys must be cleared only by an accepted canonical move.
	input["pending_escape"] = {"destination": source, "sentinel": [1, {"owned": true}]}
	input["pre_battle_pending"] = true
	input["pre_battle_start"] = Vector2i(2, 2)
	input["pre_battle_travel_dir"] = Vector2i.UP
	return input

func _route(base: Dictionary, factory: RefCounted) -> Dictionary:
	if int(base.get("section_map_version", 0)) == 1:
		for source: Dictionary in (base["rooms"] as Dictionary).values():
			for link: Dictionary in source.get("connections", []):
				var destination: Vector2i = link["coord"]
				var input: Dictionary = _selectable(base, source["coord"], destination)
				if factory.available_moves(input).has(destination): return {"state": input, "destination": destination}
	else:
		for source: Vector2i in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(1, 0)]:
			var metadata: Dictionary = factory.room_metadata(base, source)
			for link: Dictionary in metadata.get("connections", []):
				var destination: Vector2i = link["coord"]
				var input: Dictionary = _selectable(base, source, destination)
				if factory.available_moves(input).has(destination): return {"state": input, "destination": destination}
	return {}

func _merchant_cases(route: Dictionary, factory: RefCounted, graph: bool) -> void:
	var destination: Vector2i = route["destination"]
	var base: Dictionary = route["state"].duplicate(true)
	var room: Dictionary = base["rooms"][_key(destination)]
	room.merge({"type": "scavenger", "merchant_kind": "scavenger", "cleared": false, "npcs": []}, true)
	for stock_field: String in ["merchant_stock", "merchant_sold_items", "merchant_purchased_items"]: room.erase(stock_field)
	var pool_state: Dictionary = base.duplicate(true)
	pool_state["current_room"] = destination
	var magic: Array = factory._available_merchant_offer_ids(pool_state, "magic", [])
	var gear: Array = factory._available_merchant_offer_ids(pool_state, "gear", [])
	var items: Array = factory._available_merchant_offer_ids(pool_state, "item", [])
	_check(magic.size() >= 4 and gear.size() >= 4 and items.size() >= 4, "Merchant fixture needs real stocked content")
	if magic.size() < 4 or gear.size() < 4 or items.size() < 4: return
	var full: Array = [magic[0], gear[0], items[0], magic[1], gear[1], items[1], magic[2], gear[2], items[2]]
	for spec: Dictionary in [
		{"name": "missing"}, {"name": "empty", "stock": []}, {"name": "wrong_container", "stock": "invalid"},
		{"name": "valid", "stock": full}, {"name": "invalid_and_duplicate", "stock": [magic[0], magic[0], "", null, 99, "missing", gear[0], items[0]]},
		{"name": "sold", "stock": full, "sold": [magic[0], gear[0], items[0]]},
		{"name": "owned", "stock": full, "owned": true},
		{"name": "reserved_next", "stock": full, "reservation": {"kind": "scavenger", "item_id": gear[3], "origin_coord": base["current_room"]}},
		{"name": "reserved_same", "stock": full, "reservation": {"kind": "scavenger", "item_id": magic[3], "origin_coord": destination}},
		{"name": "reserved_invalid", "stock": full, "reservation": {"kind": "scavenger", "item_id": "missing", "origin_coord": base["current_room"]}},
		{"name": "reserved_legacy", "reservation": {"kind": "blacksmith", "item_id": gear[3]}}
	]:
		var input: Dictionary = base.duplicate(true)
		var changed: Dictionary = input["rooms"][_key(destination)]
		if spec.has("stock"): changed["merchant_stock"] = spec["stock"].duplicate(true) if spec["stock"] is Array else spec["stock"]
		changed["merchant_sold_items"] = spec.get("sold", []).duplicate(true)
		changed["merchant_purchased_items"] = [items[1]]
		changed["merchant_refill_count"] = 7
		if bool(spec.get("owned", false)):
			input["equipment_inventory"] = [gear[0]]
			input["magic_inventory"] = [magic[0]]
			input["item_inventory"] = [items[0]]
		if spec.has("reservation"): input["skill_state"]["reserved_merchant"] = spec["reservation"].duplicate(true)
		_compare(input, destination, "merchant/%s/%s" % [str(graph), spec["name"]], true)

func _recovery_cases(route: Dictionary, graph: bool) -> void:
	var destination: Vector2i = route["destination"]
	for kind: String in ["scavenger", "treasure", "campfire", "combat", "boss", "guardian"]:
		for location: String in ["destination", "elsewhere", "unmemoized"]:
			if location == "unmemoized" and not graph: continue
			for status: String in ["active", "stale", "empty_amount"]:
				var input: Dictionary = route["state"].duplicate(true)
				var room: Dictionary = input["rooms"][_key(destination)]
				room.merge({"type": kind, "cleared": false, "npcs": [], "merchant_kind": ""}, true)
				var coord: Vector2i = destination if location in ["destination", "unmemoized"] else input["current_room"]
				input["progression"]["recovery_marker"] = {"amount": 47 if status != "empty_amount" else 0, "coord_x": coord.x, "coord_y": coord.y, "available_run": int(input["run_index"]) if status != "stale" else int(input["run_index"]) - 1}
				if graph:
					if location == "unmemoized": input.erase("map_recovery_coord")
					else: input["map_recovery_coord"] = coord
				_compare(input, destination, "recovery/%s/%s/%s/%s" % [str(graph), kind, location, status], true)

func _invalid_cases(route: Dictionary, graph: bool) -> void:
	var destination: Vector2i = route["destination"]
	for kind: String in ["same", "disconnected", "hidden", "sealed", "lower_depth", "non_dictionary_link", "mode_combat", "mode_reward", "mode_pre_battle"]:
		var input: Dictionary = route["state"].duplicate(true)
		var target: Vector2i = destination
		var room: Dictionary = input["rooms"][_key(destination)]
		match kind:
			"same": target = input["current_room"]
			"disconnected": target = Vector2i(999, 999)
			"hidden": room["revealed"] = false
			"sealed": room["sealed"] = true
			"lower_depth": room["depth"] = -1
			"non_dictionary_link": input["rooms"][_key(input["current_room"])]["connections"] = [null, "broken", {}]
			_: input["mode"] = kind.trim_prefix("mode_")
		_compare(input, target, "invalid/%s/%s" % [str(graph), kind], false)

func _legacy_choices(route: Dictionary, factory: RefCounted) -> void:
	var destination: Vector2i = route["destination"]
	for kind: String in ["paired_combat", "paired_noncombat", "loop_escape"]:
		var input: Dictionary = route["state"].duplicate(true)
		var room: Dictionary = input["rooms"][_key(destination)]
		room.merge({"type": "event", "cleared": false, "npcs": [], "connections": []}, true)
		var links: Array = []
		for neighbor: Vector2i in [Vector2i(1, 1), Vector2i(1, -1)]:
			if neighbor == destination or neighbor == input["current_room"]: continue
			var node: Dictionary = factory.room_metadata(input, neighbor)
			node.merge({"type": "combat" if kind == "paired_combat" else "treasure", "element": "fire", "cleared": false, "visited": false, "revealed": true, "sealed": false}, true)
			input["rooms"][_key(neighbor)] = node
			links.append({"coord": neighbor, "door_dir": neighbor - destination, "kind": "lateral"})
		room["connections"] = links
		if kind == "loop_escape":
			room["connections"] = []
			for neighbor: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var node: Dictionary = factory.room_metadata(input, neighbor)
				node.merge({"visited": true, "revealed": true, "cleared": true, "sealed": false}, true)
				input["rooms"][_key(neighbor)] = node
		_compare(input, destination, "legacy/" + kind, true)

func _legacy_missing_type_and_deeper_pair(base: Dictionary, factory: RefCounted) -> void:
	# Legacy partial room dictionaries regenerate absent fields from coordinate
	# metadata. A raw default-combat classifier would wrongly take pre-battle.
	var destination := Vector2i(0, 2)
	var input: Dictionary = _selectable(base, Vector2i(0, 1), destination)
	input["rooms"][_key(Vector2i(0, 1))]["connections"].append({"coord": destination, "door_dir": Vector2i.DOWN, "kind": "outward"})
	input["rooms"][_key(destination)].erase("type")
	input["rooms"][_key(destination)].erase("npcs")
	_check(factory.room_metadata(input, destination).get("type") == "campfire", "Missing-type legacy case must regenerate a noncombat destination")
	_compare(input, destination, "legacy/missing_noncombat_type", true)
	# Two depth-two treasure choices can successfully become distinct services;
	# depth-one offers intentionally cannot choose the Scavenger service.
	destination = Vector2i(2, 0)
	input = _selectable(base, Vector2i(1, 0), destination)
	input["rooms"][_key(Vector2i(1, 0))]["connections"].append({"coord": destination, "door_dir": Vector2i.RIGHT, "kind": "outward"})
	var target: Dictionary = input["rooms"][_key(destination)]
	target.merge({"type": "event", "npcs": [], "cleared": false}, true)
	var links: Array = []
	for neighbor: Vector2i in [Vector2i(2, 1), Vector2i(2, -1)]:
		var room: Dictionary = factory.room_metadata(input, neighbor)
		room.merge({"type": "treasure", "cleared": false, "visited": false, "revealed": true, "sealed": false}, true)
		input["rooms"][_key(neighbor)] = room
		links.append({"coord": neighbor, "door_dir": neighbor - destination, "kind": "lateral"})
	target["connections"] = links
	_compare(input, destination, "legacy/paired_noncombat_depth_two", true)

func _compare(input: Dictionary, destination: Vector2i, label: String, moves: bool) -> void:
	var before: Dictionary = input.duplicate(true)
	var original := ObservedOriginal.new()
	var current := ObservedCurrent.new()
	var global_seed: int = 99173 + cases
	seed(global_seed)
	var expected: Dictionary = original.move_to_pre_battle(input, destination)
	var original_global: int = randi()
	seed(global_seed)
	_check(original_global == randi(), label + ": deterministic move must leave global RNG untouched")
	_check(input == before, label + ": original caller input changed")
	seed(global_seed)
	var actual: Dictionary = current.move_to_pre_battle(input, destination)
	_check(randi() == original_global, label + ": global RNG sequence changed")
	_check(actual == expected, label + ": complete move state differed; keys " + str(_different_keys(actual, expected)))
	_check(input == before, label + ": optimized caller input changed")
	if moves:
		_check(actual.get("current_room") == destination, label + ": fixture must commit a real move")
		_check(current.layout_calls == 1, label + ": accepted move must build one display layout")
		_check(current.stock_calls <= 1, label + ": accepted move must build stock at most once")
	removed_layouts += original.layout_calls - current.layout_calls
	removed_stock_builds += original.stock_calls - current.stock_calls
	var family: String = label.split("/")[0]
	coverage[family] = int(coverage.get(family, 0)) + 1
	if label.ends_with("/paired_noncombat_depth_two"):
		var first: Dictionary = actual["rooms"][_key(Vector2i(2, 1))]
		var second: Dictionary = actual["rooms"][_key(Vector2i(2, -1))]
		_check(str(first["type"]) != str(second["type"]) and str(first["type"]) != "combat" and str(second["type"]) != "combat", label + ": fixture must successfully retype a noncombat choice pair")
	if label.ends_with("/loop_escape"):
		var loop_offer: bool = false
		for link: Dictionary in actual["rooms"][_key(destination)]["connections"]:
			loop_offer = loop_offer or bool(link.get("loop_escape", false)) or bool(link.get("attrition_offer", false))
		_check(loop_offer, label + ": fixture must actually add a loop escape or attrition offer")
	# Every return must be deeply caller-owned, including rejected moves.
	if not (actual["rooms"] as Dictionary).is_empty():
		var room: Dictionary = (actual["rooms"] as Dictionary).values()[0]
		room["ownership_probe"] = {"nested": [true]}
		if not (room.get("connections", []) as Array).is_empty() and typeof(room["connections"][0]) == TYPE_DICTIONARY:
			(room["connections"][0] as Dictionary)["ownership_probe"] = true
	actual["progression"]["level"] = int(actual["progression"].get("level", 1)) + 1
	actual["skill_state"]["events"].append({"revision": 999, "skill_id": "ownership_probe"})
	if actual.has("map_events"): actual["map_events"].append({"type": "ownership_probe"})
	_check(input == before, label + ": returned nested rooms/profile/skills/map events alias source")
	(actual["rooms"] as Dictionary).clear()
	_check(input == before, label + ": returned state aliases source rooms")
	cases += 1

func _different_keys(actual: Dictionary, expected: Dictionary) -> Array:
	var result: Array = []
	for key: Variant in actual:
		if actual[key] != expected.get(key): result.append(key)
	for key: Variant in expected:
		if not actual.has(key): result.append(key)
	return result

func _key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
