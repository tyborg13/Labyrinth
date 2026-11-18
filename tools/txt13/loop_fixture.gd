extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const WarbandRoom = preload("res://scripts/warband_room_rules.gd")
const Beats = preload("res://tools/tooltip_loops/tip03_fixture.gd")

const FADE: String = "fade_gloam_stalker"
const BARRAGE: String = "lob_slagmaster_barrage"
const IDS: Array = [FADE, BARRAGE]
const BIOMES: Dictionary = {FADE: "noctyrax", BARRAGE: "tharokh"}
const FADE_HERO := Vector2i(2, 1)
const FADE_STALKER := Vector2i(3, 2)
const FADE_FACING: Dictionary = {"facing": "front", "mirrored": true}
const BARRAGE_HERO := Vector2i(1, 1)
const BARRAGE_CAPTAIN := Vector2i(1, 4)
const BARRAGE_SECOND_CENTER := Vector2i(3, 1)
const BARRAGE_PATCH := Rect2i(0, 0, 5, 5)
const BARRAGE_SIDE: int = 1
const BARRAGE_ROOM_TIER: int = 1

static func configure(layout: Dictionary, id: String) -> Array:
	if id == FADE:
		layout["element"] = "shadow"
		layout["player_start"] = FADE_HERO
		return [["gloam_stalker", FADE_STALKER]]
	var floor_grid: Array
	for y: int in range(BARRAGE_PATCH.size.y):
		var row: Array
		row.resize(BARRAGE_PATCH.size.x)
		row.fill("stone")
		floor_grid.append(row)
	layout["grid"] = floor_grid
	layout["element"] = "fire"
	layout["player_start"] = BARRAGE_HERO
	layout["objective"] = WarbandRoom.objective({"special_variant": "fire"}, BARRAGE_ROOM_TIER)
	layout["objective"]["type"] = preload("res://scripts/combat_objective_rules.gd").KILL_LEADER
	return [["slag_mortar", BARRAGE_CAPTAIN]]

static func prepare(state: Dictionary, id: String) -> void:
	if id == FADE:
		state["hero_facing"] = FADE_FACING.duplicate()
		state["enemies"][0]["intent"] = Data.enemy_def("gloam_stalker")["intents"][0].duplicate(true)
	else:
		# Isolate the recording to Lob. Its authored Warband order still sets
		# the number of centres; the separate Wildfire beat has its own loop.
		state["battlefield_rule"] = {}
		state["enemies"][0]["intent"] = Data.enemy_def("slag_mortar")["intents"][0].duplicate(true)
		state["enemies"][0]["intent"]["barrage_side"] = BARRAGE_SIDE

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var first: Dictionary = Beats.enemy_beat(engine, fixture["state"])
	var second: Dictionary = Beats.enemy_beat(engine, first["after"])
	return {"beats": [first, second], "final": second["after"]}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String]
	var initial: Dictionary = fixture["state"]
	var first: Dictionary = result["beats"][0]["after"]
	var final: Dictionary = result["final"]
	var enemy: Dictionary = first["enemies"][0]
	var hit: int = int(initial["player"]["hp"]) - int(final["player"]["hp"])
	if fixture["id"] == FADE:
		var behind: Vector2i = FADE_HERO - preload("res://scripts/hero_facing_state.gd").tile_direction(FADE_FACING)
		if enemy["pos"] != behind or enemy["intent"]["id"] != "ambush" or first["player"]["hp"] != initial["player"]["hp"]:
			failures.append("Fade must Blink behind the hero by facing and announce Ambush without dealing damage")
		if hit != int(enemy["intent"]["actions"][0]["damage"]):
			failures.append("Ambush must hit on the following enemy turn")
	else:
		var centers: Array = enemy.get("lob_centers", [])
		var tiles: Array = enemy.get("lob_tiles", [])
		if centers != [BARRAGE_HERO, BARRAGE_SECOND_CENTER] or tiles.size() != 9:
			failures.append("Slagmaster must place both full overlapping patterns and keep their two centers")
		if enemy.get("intent", {}).get("id") != "slag_lands" or hit != int(enemy["intent"]["actions"][0]["center_damage"]):
			failures.append("The following enemy turn must land the barrage and hit at center damage")
		if final["surfaces"].size() != tiles.size(): failures.append("The loop must isolate the two Lob patterns from Wildfire")
		var surfaces = preload("res://scripts/board_surface_rules.gd")
		for tile: Vector2i in tiles:
			if not BARRAGE_PATCH.has_point(tile) or surfaces.element_at(final, tile) != "fire":
				failures.append("Each held barrage tile must stay inside the crop and become Fire")
				break
	return failures
