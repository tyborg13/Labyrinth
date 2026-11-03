extends RefCounted

const Slots = preload("res://scripts/turn_order_slots.gd")
const Original = preload("res://tests/perf/turn_order_reference.gd")
const Discovery = preload("res://scripts/grimoire_discovery_sync.gd")
const Library = preload("res://scripts/grimoire_library.gd")

class FrozenClock extends "res://scripts/run_score_rules.gd":
	func sample_scene_play_time(_host: Control, _committed_state: Dictionary = {}) -> void:
		pass # Compare the same logical instant; no wall-time accrual between oracles.

static func run(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var engine := preload("res://scripts/run_engine.gd").new()
	var state: Dictionary = engine.create_new_run(83, preload("res://scripts/progression_store.gd").default_data())
	state = engine.move_to_room(state, engine.available_moves(state)[0])
	scene._load_run_state(state)
	if scene._dialogue_active: scene._close_dialogue()
	await tree.process_frame
	var holder := Control.new()
	# Off-screen: the headless pointer rests at (0, 0), and a hovered slot opens a tooltip popup only on one side.
	holder.position = Vector2(-4000.0, -4000.0)
	tree.root.add_child(holder)
	var retained: Control = null
	var entry: Dictionary = {"kind": "enemy", "actor_key": "enemy_1", "enemy_id": 1, "type": "crawler", "team": "enemy", "pos": Vector2i(4, 4), "time": 4, "eta": 4, "hp": 12, "max_hp": 40}
	var mutations: Array[Dictionary]
	mutations.assign([{}, {"hp": 1}, {"time": 7, "eta": 7}, {"active": true}, {"active": false, "hp": 0}, {"max_hp": 60}, {"projected": true}, {"projected": false}])
	var comparisons: int = 0
	for change: Dictionary in mutations:
		entry.merge(change, true)
		var previous_id: int = retained.get_instance_id() if retained != null else 0
		retained = Slots.update(scene, entry, comparisons % 6, retained)
		if retained.get_parent() == null: holder.add_child(retained)
		var expected: Control = Original.build(scene, entry, comparisons % 6)
		holder.add_child(expected)
		for frame: int in range(3): await tree.process_frame
		expect.call(snapshot(retained) == snapshot(expected), "Turn-order retained layout/style/texture/text/input equivalence " + str(comparisons))
		if previous_id != 0: expect.call(retained.get_instance_id() == previous_id, "Turn-order actor root retained in place")
		expected.free()
		comparisons += 1
	retained.free()
	var topologies: Array[Dictionary]
	topologies.assign([
		{"hidden_by_umbra": true}, {"petrified": true}, {"late_relic_id": "toll_late_bell"},
		{"kind": "player", "actor_key": "player", "team": "player", "type": "player", "projected": true, "projected_time_delta": 3, "projected_card_name": "Hobnail Drive"},
		{"stagger_preview": 2}])
	for topology: Dictionary in topologies:
		var shaped: Dictionary = entry.duplicate(true)
		shaped.merge(topology, true)
		var expected: Control = Original.build(scene, shaped, 1)
		holder.add_child(expected)
		var candidate: Control = Slots.update(scene, shaped, 1)
		holder.add_child(candidate)
		shaped["hp"] = 5
		candidate = Slots.update(scene, shaped, 2, candidate)
		expected.free()
		expected = Original.build(scene, shaped, 2)
		holder.add_child(expected)
		for frame: int in range(3): await tree.process_frame
		expect.call(snapshot(candidate) == snapshot(expected), "Retained optional portrait/badge/input topology " + str(topology))
		candidate.free()
		expected.free()
		comparisons += 1
	# Exercise reconciliation and the equality guard independently of the source
	# signature. A forced equal hash must not retain a stale visible numeral.
	var entries: Array[Dictionary]
	entries.assign([entry])
	Slots.reconcile(scene, entries)
	var slot: Control = scene._turn_order_bar.get_child(0)
	var old_id: int = slot.get_instance_id()
	var old_source: Array = slot.get_meta("perf03_source").duplicate(true)
	entries[0]["eta"] = 33
	slot.set_meta("perf03_content_key", hash(Slots._inputs(scene, entries[0], 0)))
	Slots.reconcile(scene, entries)
	expect.call(scene._turn_order_bar.get_child(0).get_instance_id() == old_id, "Changed clock updates existing controls")
	expect.call(slot.get_node("TurnOrderTimeNumeral").text == "33", "Equal-key mutation invalidates stale numeral")
	expect.call(slot.get_meta("perf03_source") != old_source, "Retained source is deeply owned")
	slot.scale = Vector2(0.9, 0.9)
	slot.modulate.a = 0.0
	slot.pivot_offset = slot.size * 0.5
	slot.set_meta("turn_order_removal_style", "slide")
	Slots.reconcile(scene, entries)
	expect.call(scene._turn_order_bar.get_child(0).get_instance_id() == old_id, "Unchanged refresh retains controls")
	expect.call(slot.scale == Vector2.ONE and slot.modulate == Color.WHITE and slot.pivot_offset == Vector2.ZERO and not slot.has_meta("turn_order_removal_style"), "Reused animated slot resets the original factory's motion baseline")
	print("PERF03 UI RETENTION EQUIVALENCE: %d complete layout/style/texture/text/input comparisons; stale-clock mutation caught" % comparisons)
	entries[0].erase("eta")
	entries[0]["time"] = 33
	scene._combat_state["initiative_clock"] = 0
	Slots.reconcile(scene, entries)
	scene._combat_state["initiative_clock"] = 30
	Slots.reconcile(scene, entries)
	slot = scene._turn_order_bar.get_child(0)
	expect.call(slot.get_node("TurnOrderTimeNumeral").text == "3", "Clock fallback invalidates unchanged entry content")
	var before_animation_id: int = slot.get_instance_id()
	scene._turn_order_animating = true
	Slots.reconcile(scene, entries)
	expect.call(scene._turn_order_bar.get_child(0).get_instance_id() != before_animation_id, "Animated transitions keep the original fresh-node/tween teardown lifecycle")
	scene._turn_order_animating = false
	var pixel_probe: Script = load("res://tests/perf/turn_order_retention_probe.gd")
	expect.call(pixel_probe != null and pixel_probe.can_instantiate(), "Native pixel proof parses headless")
	await _proxy_preparation(tree, scene, expect)
	_discoveries(scene, expect)
	holder.free()
	scene.queue_free()
	for frame: int in range(3): await tree.process_frame

static func _proxy_preparation(tree: SceneTree, scene: Node, expect: Callable) -> void:
	# Compare an original cold mount with the same card mounted from the prepared
	# pool, including a changed card identity that must replace the old content.
	for pooled: Control in scene._card_proxy_pool: pooled.free()
	scene._card_proxy_pool.clear()
	scene._animation_lock = false
	scene._selected_card_index = -1
	var previous_hand: Array = scene._combat_state["deck"]["hand"].duplicate()
	scene._combat_state["deck"]["hand"] = ["quick_stab"]
	var rect := Rect2(Vector2(24, 38), Vector2(180, 254))
	var cold: Control = scene._spawn_card_proxy("hobnail_drive", rect)
	scene._mount_card_proxy(cold, scene._card_fx_layer, rect)
	for frame: int in range(3): await tree.process_frame
	var expected: Dictionary = snapshot(cold)
	var run_before: Dictionary = scene._run_state.duplicate(true)
	var combat_before: Dictionary = scene._combat_state.duplicate(true)
	var preparation := preload("res://scripts/card_proxy_preparation.gd").new()
	preparation.request(scene)
	preparation.request(scene)
	for frame: int in range(3): await tree.process_frame
	expect.call(preparation.prepared and scene._card_proxy_pool.size() == 1, "One hidden proxy is prepared despite duplicate requests")
	expect.call(scene._run_state == run_before and scene._combat_state == combat_before, "Proxy preparation cannot mutate gameplay state")
	var prepared: Control = scene._card_proxy_pool[0]
	expect.call(not prepared.visible and prepared.process_mode == Node.PROCESS_MODE_DISABLED and prepared.get_parent() == scene._card_fx_layer, "Prepared proxy stays invisible and disabled in the final FX host")
	var retained_id: int = prepared.get_instance_id()
	var prepared_card: String = str(prepared.get_child(0).get("card_id"))
	var reused: Control = scene._spawn_card_proxy("hobnail_drive", rect)
	scene._mount_card_proxy(reused, scene._card_fx_layer, rect)
	for frame: int in range(3): await tree.process_frame
	expect.call(reused.get_instance_id() == retained_id, "First play reuses the prepared tree")
	match_proxy_instance_phase(cold, reused)
	if snapshot(reused) != expected: print("PERF03 PROXY PROPERTY DIFF: ", _differences(expected, snapshot(reused)))
	expect.call(snapshot(reused) == expected, "Prepared and cold card proxy layout/style/texture/text/input are identical")
	expect.call(prepared_card != "hobnail_drive", "Mutation fixture changes the prepared card identity")
	cold.free()
	scene._release_card_proxy(reused)
	scene._combat_state["deck"]["hand"] = previous_hand
	print("PERF03 CARD PROXY PREPARATION: cold/prepared full property equivalence; changed-card stale-content mutation; hidden/state/identity guards")

static func match_proxy_instance_phase(reference: Node, candidate: Node) -> void:
	# Gem-light phases are seeded from each Control's instance id, including in
	# two independent cold factories. Compare the same existing rendering input;
	# production phase generation/animation is untouched.
	if reference.has_method("refresh_motion") and reference.get("_phase") != null:
		candidate.set("_phase", reference.get("_phase"))
		candidate.call("refresh_motion")
	for index: int in range(mini(reference.get_child_count(), candidate.get_child_count())):
		match_proxy_instance_phase(reference.get_child(index), candidate.get_child(index))

static func _discoveries(scene: Node, expect: Callable) -> void:
	var sync := Discovery.new()
	scene._run_play_clock = FrozenClock.new()
	# Compare production unlock output against the original unconditional sync
	# for each relevant mutation, including a nested in-place mutation.
	var run: Dictionary = scene._run_state
	var combat: Dictionary = scene._combat_state
	var mutations: Array[Dictionary]
	mutations.assign([{"surface": "fire"}, {"surface": "electrified"}, {"card": "hobnail_drive"}, {"enemy": "crawler"}, {"trap": true}, {"equipment": "iron_sword"}, {"npc": "emaciated_man"}, {"progression": {}}, {"progression": {"embers": 0}}])
	for mutation: Dictionary in mutations:
		if mutation.has("progression"): run["progression"] = mutation["progression"].duplicate(true)
		if mutation.has("surface"): combat["surfaces"] = {"3,3": {"elemental": mutation["surface"]}}
		if mutation.has("card"): combat.get_or_add("deck", {}).get_or_add("hand", []).append(mutation["card"])
		if mutation.has("enemy"): combat.get_or_add("enemies", []).append({"type": mutation["enemy"]})
		if mutation.has("trap"): combat["traps"] = [{"pos": Vector2i(3, 3)}]
		if mutation.has("equipment"): run.get_or_add("equipment_inventory", []).append(mutation["equipment"])
		if mutation.has("npc"):
			var room: Dictionary = Library._current_room_metadata(run)
			room["npcs"] = [{"id": mutation["npc"]}]
		var candidates: Array[String] = Library.entry_ids_for_run_state(run)
		scene._append_unique_grimoire_ids(candidates, Library.entry_ids_for_combat_state(combat))
		var run_before: Dictionary = run.duplicate(true)
		var progression_before: Dictionary = scene._progression.duplicate(true)
		scene._run_state = run.duplicate(true)
		scene._unlock_grimoire_entries(candidates) # Original unconditional path.
		var expected: Dictionary = scene._run_state.duplicate(true)
		scene._progression = progression_before
		scene._run_state = run_before
		scene._combat_state = combat
		# Force the key equal to the new input while retaining the old source.
		sync._key = hash(Discovery.inputs(run, combat))
		sync.sync(scene)
		expect.call(scene._run_state == expected, "Dirty discoveries match unconditional sync " + str(mutation))
		run = scene._run_state
		var count: int = sync.synchronizations
		sync.sync(scene)
		expect.call(sync.synchronizations == count, "Unchanged discoveries skip UI refresh work")
		combat.get_or_add("player", {})["hp"] = 123
		sync.sync(scene)
		expect.call(sync.synchronizations == count, "Irrelevant HP changes keep discovery clean")
	print("PERF03 GRIMOIRE DIRTY EQUIVALENCE: 9 relevant mutations including empty/nonempty progression, unchanged/HP skips, forced-key stale-source guards")

static func snapshot(node: Node) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in node.get_property_list():
		var key: String = property["name"]
		if not (int(property["usage"]) & PROPERTY_USAGE_STORAGE): continue
		if key in ["name", "owner", "unique_name_in_owner"] or key.begins_with("metadata/perf03_"): continue
		values[key] = _value(node.get(key))
	var children: Array = []
	for child: Node in node.get_children(): children.append(snapshot(child))
	return {"class": node.get_class(), "properties": values, "children": children}

static func _value(value: Variant) -> Variant:
	if value is Resource:
		if not value.resource_path.is_empty(): return [value.get_class(), value.resource_path]
		var fields: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			var key: String = property["name"]
			if not (int(property["usage"]) & PROPERTY_USAGE_STORAGE) or key in ["resource_local_to_scene", "resource_path", "resource_name"]: continue
			fields[key] = _value(value.get(key))
		return fields
	if value is Object: return value.get_class()
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value: copy[key] = _value(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item: Variant in value: copy.append(_value(item))
		return copy
	return value

static func _differences(expected: Variant, actual: Variant, path: String = "") -> Array[String]:
	var differences: Array[String]
	if expected == actual: return differences
	if expected is Dictionary and actual is Dictionary:
		for key: Variant in expected:
			if not actual.has(key): differences.append(path + "/" + str(key) + " missing")
			else: differences.append_array(_differences(expected[key], actual[key], path + "/" + str(key)))
		for key: Variant in actual:
			if not expected.has(key): differences.append(path + "/" + str(key) + " extra")
	elif expected is Array and actual is Array:
		if expected.size() != actual.size(): differences.append(path + " size %d != %d" % [expected.size(), actual.size()])
		for index: int in range(mini(expected.size(), actual.size())): differences.append_array(_differences(expected[index], actual[index], path + "/" + str(index)))
	else: differences.append(path + ": " + str(expected) + " != " + str(actual))
	return differences
