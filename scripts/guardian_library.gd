extends RefCounted
class_name GuardianLibrary

const DEFINITIONS := {
	"vyraketh": {"id":"ashen_reaver", "name":"Ashen Reaver", "element":"fire", "arena":"The Cinder Yard", "relic":"ashen_brand", "helpers":["ash_hound", "ash_hound"], "pillars":[[3,3],[5,5]]},
	"iskaldra": {"id":"rimejaw", "name":"Rimejaw", "element":"ice", "arena":"The Broken Rime", "relic":"winters_spur", "helpers":["rime_whelp", "rime_spitter"], "pillars":[[3,3],[4,2],[5,3]]},
	"zekarion": {"id":"storm_cantor", "name":"Storm Cantor", "element":"lightning", "arena":"The Broken Choir", "relic":"resonant_clapper", "helpers":["lightning_wisp", "bell_tender"], "pillars":[[3,4],[5,4]]},
	"vaeloryx": {"id":"gallows_roc", "name":"Gallows Roc", "element":"air", "arena":"The Hanging Roost", "relic":"galehook_talon", "helpers":["roc_fledgling", "roc_fledgling"], "pillars":[[3,3],[5,5]]},
	"tharokh": {"id":"craghide", "name":"Craghide", "element":"earth", "arena":"The Shattered Burrow", "relic":"cragbound_gauntlet", "helpers":["stoneback_mite", "stoneback_mite"], "pillars":[[3,3],[5,3]]},
	"noctyrax": {"id":"last_lamplighter", "name":"Last Lamplighter", "element":"shadow", "arena":"The Last Watch", "relic":"procession_lantern", "helpers":["wick_shade"], "pillars":[[3,3],[5,5]]}
}

static func for_boss(boss_id: String) -> Dictionary:
	return Dictionary(DEFINITIONS.get(boss_id, {})).duplicate(true)

static func for_guardian(guardian_id: String) -> Dictionary:
	for value: Dictionary in DEFINITIONS.values():
		if str(value["id"]) == guardian_id: return value.duplicate(true)
	return {}

static func enemy_types(boss_id: String) -> Array:
	var definition: Dictionary = for_boss(boss_id)
	if definition.is_empty(): return []
	var result: Array = [definition["id"]]
	result.append_array(definition["helpers"])
	return result

static func emblem_path(guardian_id: String) -> String:
	return "res://assets/art/map/guardians/%s_emblem.png" % guardian_id if not for_guardian(guardian_id).is_empty() else ""

static func configure_layout(layout: Dictionary) -> void:
	var definition: Dictionary = for_boss(str(layout.get("boss_id", "")))
	if definition.is_empty(): return
	layout["guardian_id"] = definition["id"]
	layout["name"] = definition["arena"]
	var grid: Array = layout["grid"]
	for y: int in range(1,8):
		for x: int in range(1,8): grid[y][x] = "stone"
	for pair: Array in definition["pillars"]:
		var tile: Vector2i = oriented_tile(layout, Vector2i(int(pair[0]), int(pair[1])))
		grid[tile.y][tile.x] = "pillar"
	# Rotate the complete authored arena around the chosen entry.
	var positions: Array[Vector2i] = []
	positions.assign([Vector2i(4,3),Vector2i(2,3),Vector2i(6,3)])
	for index: int in range((layout["enemies"] as Array).size()):
		var enemy: Dictionary = layout["enemies"][index]
		enemy["pos"] = oriented_tile(layout, positions[index])
		if index > 0:
			enemy["guardian_helper"] = true
			if str(enemy["type"]) in ["lightning_wisp","wick_shade"]:
				enemy["summoned"] = true
				enemy["reward_embers"] = 0
	layout["terrain"] = []
	layout["traps"] = []
	layout["surfaces"] = {}
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	if str(definition["element"]) == "lightning":
		for tile: Vector2i in [Vector2i(3,5),Vector2i(3,6),Vector2i(5,5),Vector2i(5,6)]:
			surfaces.place(layout,oriented_tile(layout,tile),"electrified",{"actor_kind":"arena"})
	if str(definition["element"]) == "shadow":
		layout["guardian_braziers"] = [{"id":1,"pos":oriented_tile(layout,Vector2i(2,5)),"lit":true},{"id":2,"pos":oriented_tile(layout,Vector2i(6,5)),"lit":true}]

static func oriented_tile(layout: Dictionary, tile: Vector2i) -> Vector2i:
	var entry: Vector2i = layout.get("player_start", Vector2i(4,7))
	var turns: int = 1 if entry.x == 1 else 2 if entry.y == 1 else 3 if entry.x == 7 else 0
	var offset: Vector2i = tile - Vector2i(4,4)
	for step: int in range(turns): offset = Vector2i(-offset.y, offset.x)
	return offset + Vector2i(4,4)

static func stage_loot(layout: Dictionary) -> void:
	var occupied: Dictionary = {layout["player_start"]:true}
	for list: String in ["enemies", "traps", "guardian_braziers"]:
		for object: Dictionary in layout.get(list, []): occupied[object["pos"]] = true
	var candidates: Array[Vector2i] = []
	for y: int in range(6,1,-1):
		for x: int in [2,6,3,5,4,1,7]:
			var tile: Vector2i = oriented_tile(layout,Vector2i(x,y))
			if str(layout["grid"][tile.y][tile.x]) == "stone" and not occupied.has(tile): candidates.append(tile)
	var staged: Array[Dictionary] = []
	for loot: Dictionary in layout.get("loot", []):
		if candidates.is_empty(): break
		loot["pos"] = candidates.pop_front()
		staged.append(loot)
	layout["loot"] = staged

# Supplemental rules for the existing encounter inspection. Ordinary enemies
# never inherit Guardian helper rules merely by sharing an enemy type.
static func inspection_summary(enemy: Dictionary) -> String:
	var enemy_type: String = str(enemy.get("type", ""))
	var definition: Dictionary = for_guardian(enemy_type)
	if not definition.is_empty():
		var helpers: String = ""
		match enemy_type:
			"ashen_reaver": helpers = "Both Ash Hounds stay defeated."
			"rimejaw": helpers = "The Rime Whelp and Rime Spitter do not return."
			"storm_cantor": helpers = "The Bell Tender stays defeated. Call the Spark can replace the Wisp."
			"gallows_roc": helpers = "Both Fledglings stay defeated."
			"craghide": helpers = "Both Stoneback Mites stay defeated."
			"last_lamplighter": helpers = "Snuff adds temporary Wick Shades; the starting Shade stays until defeated."
		return "Defeat %s to end the encounter; remaining helpers leave. %s" % [definition["name"], helpers]
	if not bool(enemy.get("guardian_helper", false)): return ""
	match enemy_type:
		"lightning_wisp":
			return "Call the Spark can replace this Wisp, with at most one alive. No extra card play or Embers when defeated."
		"wick_shade":
			return "Snuff can summon Wick Shades, up to two alive. Last Procession dismisses Shades summoned by Snuff; the starting Shade stays. No extra card play or Embers when defeated."
	return "Does not return when defeated. Grants no Embers."

static func intent_notes(intent: Dictionary) -> String:
	var notes: Array[String] = []
	for action: Dictionary in intent.get("actions", []):
		match str(action.get("guardian_shape", "")):
			"broken_line": notes.append("A straight line with a safe gap on its second tile.")
			"line": notes.append("Hits the declared straight line; it will not track your new position.")
			"sweep": notes.append("Sweeps the three tiles directly ahead.")
			"connector": notes.append("Places %s. Break the connection or leave the network before Peal." % ("one Electrified tile" if int(action.get("guardian_count", 1)) == 1 else "%d Electrified tiles" % int(action["guardian_count"])))
			"conductor": notes.append("Strikes a declared conductor and its connected network. Remove that conductor or leave the network to avoid the discharge.")
		if action.has("trail_surface"):
			notes.append("Leaves %s on each tile it moves off." % str(action["trail_surface"]).capitalize())
		if action.has("terminal_surface"):
			notes.append("Leaves %s at the end of the strike." % str(action["terminal_surface"]).capitalize())
		if int(action.get("self_expose", 0)) > 0:
			notes.append("Gains %d Expose afterward, even if the strike misses." % int(action["self_expose"]))
		if bool(action.get("snuff_brazier", false)):
			notes.append("Extinguishes one arena brazier until Last Procession finishes. Summons a Wick Shade beside it if fewer than %d are alive." % int(action.get("guardian_cap", 2)))
		elif str(action.get("type", "")) == "summon_minions" and action.has("guardian_cap"):
			notes.append("Replaces the defeated Wisp. Does nothing while a Wisp is alive.")
		if str(action.get("guardian_kind", "")) == "crag_outcrop":
			if str(action.get("type", "")) == "raise_terrain":
				notes.append("Raises up to %d destructible outcrops with %d HP each, at most two alive. Destroy them to remove their Groundsplit danger." % [int(action.get("count", 2)), int(action.get("health", 3))])
			elif str(action.get("type", "")) == "terrain_burst":
				notes.append("Strikes the four neighbors of each surviving outcrop. Overlapping bursts hit each victim once; destroyed outcrops cannot burst.")
	if bool(intent.get("restore_braziers", false)):
		notes.append("Afterward, restores both arena braziers and dismisses Shades summoned by Snuff, even if Freeze or Shock stops this move.")
	return " ".join(notes)
