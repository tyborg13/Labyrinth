extends SceneTree

# Director measurement (not committed): choice density of revision 5/6 section topologies.
const Graph = preload("res://scripts/section_map_graph.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = 200
	var out_path: String = ""
	for i: int in range(args.size() - 1):
		if args[i] == "--seeds": seeds = int(args[i + 1])
		if args[i] == "--out": out_path = args[i + 1]
	var sections: Array = []
	var samples: Array = []
	for seed_value: int in range(1, seeds + 1):
		for index: int in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
			var stats: Dictionary = {}
			var layout: Dictionary = Graph._section_layout_v5(rng, seed_value, index, stats)
			var count: int = Graph.ROOM_COUNTS[index]
			var children: Dictionary = layout["children"]
			var interior: int = 0
			var forks: int = 0
			var out_sum: int = 0
			for cell: Vector2i in layout["order"]:
				if cell.x >= count - 1: continue
				interior += 1
				var degree: int = (children.get(cell, []) as Array).size()
				out_sum += degree
				forks += int(degree >= 2)
			var lane_changes: int = 0
			var edges: int = 0
			for cell: Vector2i in children:
				for target: Vector2i in children[cell]:
					edges += 1
					lane_changes += int(target.y != cell.y)
			# Routes: every opening node (step 1) to the last step.
			var routes: Array = []
			for lane: int in layout["rows"][1]: _routes(children, Vector2i(1, lane), count, [Vector2i(1, lane)], routes)
			var choices: Array[int] = []
			var runs: Array[int] = []
			for route: Array in routes:
				var c: int = 0
				var run: int = 0
				var longest: int = 0
				for cell: Vector2i in route.slice(0, route.size() - 1):
					if (children.get(cell, []) as Array).size() >= 2:
						c += 1
						run = 0
					else:
						run += 1
						longest = maxi(longest, run)
				choices.append(c)
				runs.append(longest)
			choices.sort()
			runs.sort()
			sections.append({"seed": seed_value, "section": index, "rooms": count, "nodes": interior, "fork_share": float(forks) / float(interior), "mean_out": float(out_sum) / float(interior), "lane_change_share": float(lane_changes) / float(edges), "routes": routes.size(), "choices_median": choices[choices.size() / 2], "choices_min": choices[0], "longest_run_median": runs[runs.size() / 2], "longest_run_max": runs[-1]})
			if seed_value <= 3 and index in [1, 3]:
				var kids: Dictionary = {}
				for cell: Vector2i in children: kids["%d,%d" % [cell.x, cell.y]] = (children[cell] as Array).map(func(t: Vector2i) -> String: return "%d,%d" % [t.x, t.y])
				var types: Dictionary = {}
				for cell: Vector2i in layout["nodes"]: types["%d,%d" % [cell.x, cell.y]] = str(layout["nodes"][cell].get("type", ""))
				samples.append({"seed": seed_value, "section": index, "rooms": count, "children": kids, "types": types, "rows": layout["rows"].keys().map(func(k: int) -> Array: return layout["rows"][k])})
	var report: Dictionary = {"seeds": seeds, "sections": sections, "samples": samples}
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	print("MAP CHOICE METRICS: %d sections" % sections.size())
	quit()

func _routes(children: Dictionary, cell: Vector2i, count: int, path: Array, out: Array) -> void:
	if cell.x >= count - 1 or not children.has(cell):
		out.append(path.duplicate())
		return
	for target: Vector2i in children[cell]:
		path.append(target)
		_routes(children, target, count, path, out)
		path.pop_back()
