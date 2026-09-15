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

# Supplemental copy carries encounter-specific exceptions only. The objective,
# action rows and core keyword tooltips already explain victory, numbers,
# surfaces, statuses and ordinary summon rewards.
static func inspection_summary(enemy: Dictionary) -> String:
	var enemy_type: String = str(enemy.get("type",""))
	if not for_guardian(enemy_type).is_empty():
		if enemy_type=="last_lamplighter": return "Replaces its fallen companion. Snuff adds a temporary Shade, up to two Shades total."
		return "Replaces one missing helper on its next declared turn. Up to two helpers alive."
	if not bool(enemy.get("guardian_helper",false)): return ""
	match enemy_type:
		"lightning_wisp": return "The Cantor replaces it after defeat. One Wisp at a time."
		"wick_shade": return "Disappears after Last Procession." if enemy.has("outage_owner") else "Replaced after defeat. Stays through Last Procession."
	return "The Guardian replaces it after defeat."

static func intent_notes(intent: Dictionary) -> String:
	var notes: Array[String] = []
	for action: Dictionary in intent.get("actions",[]):
		match str(action.get("guardian_shape","")):
			"broken_line": notes.append("The second row stays clear.")
			"connector": notes.append("Extends the existing electrical network toward its target.")
		if action.has("surface") and str(action.get("guardian_shape","")) in ["line","broken_line","sweep"] and str(action.get("type","")) in ["melee","ranged","aoe"]:
			notes.append("%s remains even if the strike misses." % str(action["surface"]).capitalize())
		if bool(action.get("snuff_brazier",false)):
			notes.append("Darkness lasts until Last Procession.")
		if str(action.get("guardian_kind",""))=="crag_outcrop":
			if str(action.get("type",""))=="raise_terrain": notes.append("Up to two outcrops; each fuels Groundsplit.")
			elif str(action.get("type",""))=="terrain_burst": notes.append("Overlapping bursts hit once.")
	if bool(intent.get("restore_braziers",false)):
		notes.append("Relights braziers and dismisses Snuff’s Shades, even when skipped.")
	return " ".join(notes)
