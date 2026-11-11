extends RefCounted

# Independent checks of all incoming paths, including recombinations at merges.
const Graph = preload("res://scripts/section_map_graph.gd")
const Guardians = preload("res://scripts/guardian_library.gd")

static func validate(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = int(info["room_count"])
	var nodes: Array = []
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) == index: nodes.append(node)
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["map_step"]) < int(b["map_step"]))
	var bounds: Dictionary = {info["entry"]: [0, 0, 0, 0, 0, 0, 0, 0]}
	var guardian_count: int = 0
	var scavenger_count: int = 0
	var incoming: Dictionary = {}
	var choices: Dictionary = {info["entry"]: 0}
	var gaps: Dictionary = {info["entry"]: 0}
	var open_gaps: Dictionary = {info["entry"]: 0}
	var gather: Array = [Graph.V7_MID_HEARTH_STEP, ceili(count / 2.0), count - 1]
	var reachable: Dictionary = Graph.descendants(state, info["entry"])
	expect.call(reachable.size() == nodes.size(), "All section rooms are reachable")
	for node: Dictionary in nodes:
		var coord: Vector2i = node["coord"]
		var step: int = int(node["map_step"])
		var type: String = node["type"]
		if index == 5 and type == "campfire":
			expect.call(bool(node.get("map_landmark", false)), "Both Section VI Hearths retain the existing landmark reveal rule")
		expect.call(bounds.has(coord), "Every room has a reachable prefix")
		var prefix: Array = bounds[coord].duplicate()
		if type == "boss":
			expect.call(int(choices[coord]) >= Graph.V7_MIN_CHOICES, "Every route retains three real choices")
			var fights: int = Graph.FIGHT_COUNTS[index] - 1
			expect.call(prefix[0] >= fights - Graph.V7_FIGHT_SLACK and prefix[1] <= fights + 1, "Every route retains its fight target and slack")
			expect.call(prefix[3] <= 1 and prefix[2] == 0 and prefix[4] >= 1, "Guardian bypass, one Guardian maximum and extra service on every route")
			expect.call(prefix[6] == 1 and prefix[7] == 1, "Exactly one band-2 Hearth on every route")
			continue
		if type == "graftwright": expect.call(prefix[0] >= 3, "Graftwright requires three fights on every incoming route")
		if type == "guardian":
			guardian_count += 1
			expect.call(step >= 3 and step <= count - 3, "Guardian placement remains eligible")
			var guardian: Dictionary = Guardians.for_boss(info["boss_id"])
			expect.call(node["guardian_id"] == guardian["id"] and node["guardian_relic"] == guardian["relic"], "Guardian identity and reward remain section-specific")
		if type == "scavenger":
			scavenger_count += 1
			expect.call(step >= 3, "Scavenger gating remains unchanged")
		if step == 1: expect.call(type == "combat", "Opening row remains combat")
		if step == ceili(count / 2.0): expect.call(type == "treasure", "Guaranteed Relic row remains intact")
		if step == count - 1: expect.call(type == "campfire", "Pre-boss Hearth row remains intact")
		var fight: bool = type in ["combat", "guardian", "special"] or (type == "mystery" and str(node["mystery_type"]) == "combat")
		var service: bool = type in ["event", "scavenger", "graftwright"] or (type == "mystery" and str(node["mystery_type"]) != "combat")
		var hearth: bool = type == "campfire" and int(node["depth"]) - index * 4 == 2
		for metric: int in range(4):
			var value: int = int([fight, type == "guardian", service, hearth][metric])
			prefix[metric * 2] += value
			prefix[metric * 2 + 1] += value
		var directions: Dictionary = {}
		var siblings: Dictionary = {}
		var links: Array = node["connections"]
		var fork: bool = links.size() >= 2 and step > 0 and step < count - 1
		var next_choices: int = int(choices[coord]) + int(fork)
		var next_gap: int = 0 if fork or step == 0 else int(gaps[coord]) + 1
		var next_open_gap: int = 0 if fork or step == 0 or step + 1 in gather else int(open_gaps[coord]) + 1
		if step > 0 and step < count - 1:
			expect.call(next_gap <= Graph.V7_MAX_RUN + 1 and next_open_gap <= Graph.V7_MAX_RUN, "Choice cadence remains bounded through gathering rows")
		for link: Dictionary in links:
			var target: Dictionary = Graph.room(state, link["coord"])
			var child_type: String = target["type"]
			# Specials substitute ordinary fights after the type solver. Their
			# distinct catalog identities remain distinct choices at a fork.
			var child_identity: String = "special:" + str(target["special_type"]) if child_type == "special" else child_type
			expect.call(int(target["map_step"]) == step + 1, "Every edge advances one step")
			expect.call(not directions.has(link["door_dir"]), "Physical exit doors are distinct")
			directions[link["door_dir"]] = true
			if not incoming.has(target["coord"]): incoming[target["coord"]] = {}
			incoming[target["coord"]][-link["door_dir"]] = true
			if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"]: expect.call(type != child_type, "No identical service parent and child")
			expect.call(not siblings.has(child_identity) or (child_type == "combat" and links.size() == 3), "Sibling identities remain distinct")
			siblings[child_identity] = true
			choices[target["coord"]] = mini(int(choices.get(target["coord"], next_choices)), next_choices)
			gaps[target["coord"]] = maxi(int(gaps.get(target["coord"], 0)), next_gap)
			open_gaps[target["coord"]] = maxi(int(open_gaps.get(target["coord"], 0)), next_open_gap)
			if not bounds.has(target["coord"]): bounds[target["coord"]] = prefix.duplicate()
			else:
				var prior: Array = bounds[target["coord"]]
				for metric: int in range(4):
					prior[metric * 2] = mini(prior[metric * 2], prefix[metric * 2])
					prior[metric * 2 + 1] = maxi(prior[metric * 2 + 1], prefix[metric * 2 + 1])
	for node: Dictionary in nodes:
		if node["type"] == "boss": continue
		for link: Dictionary in node["connections"]:
			expect.call(not (incoming.get(node["coord"], {}) as Dictionary).has(link["door_dir"]), "No exit reuses an incoming physical threshold")
	expect.call(guardian_count >= 2 and scavenger_count >= 1, "Section retains two Guardians and a Scavenger")
