extends SceneTree

# Structural legal-action sample, not empirical hit probability. Enumerate
# unoccupied floor anchors in seeded rooms; do not play cards or grant free
# movement to every card. Fog cohorts remain separate from printed range.
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Data = preload("res://scripts/game_data.gd")
const Path = preload("res://scripts/path_utils.gd")

func _initialize() -> void:
	var combat := Combat.new()
	var rooms := Rooms.new()
	var cohorts: Dictionary = {}
	var room_count: int = 0
	for element: String in ["none", "fire", "earth", "air", "ice", "lightning"]:
		for depth: int in [1, 3, 9, 19]:
			for seed: int in [9102601, 9102602]:
				var layout: Dictionary = rooms.generate_room(seed, {"coord": Vector2i(depth, 1), "depth": depth, "type": "combat", "element": element}, Vector2i.RIGHT)
				var state: Dictionary = combat.create_combat(seed, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["pale_spark"], "hand_size": 1})
				room_count += 1
				var occupied: Dictionary = combat._player_blocking_tiles(state)
				for fog: String in ["clear", "deep", "heart"]:
					var key: String = "%s/%d/%s" % [element, depth, fog]
					var row: Dictionary = {"anchors": 0, "legal": {}}
					if cohorts.has(key): row = cohorts[key]
					state["umbra"]["stage"] = fog
					for y: int in range(1, 8):
						for x: int in range(1, 8):
							var pos := Vector2i(x, y)
							if occupied.has(pos) or str(state["grid"][y][x]) in ["wall", "pillar"]: continue
							state["player"]["pos"] = pos
							row["anchors"] += 1
							for reach: int in range(1, 8):
								var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "ranged", "range": reach, "damage": 1, "element": "none"})
								var hits_enemy: bool = false
								for enemy: Dictionary in state["enemies"]:
									if targets.has(enemy["pos"]): hits_enemy = true
								row["legal"][str(reach)] = int(row["legal"].get(str(reach), 0)) + int(hits_enemy)
					cohorts[key] = row
	var report: Dictionary = {"balance_revision": Data.BALANCE_REVISION, "rooms": room_count, "method": "all unoccupied inner floor anchors; immediate enemy-target legality; no shared movement added; unweighted structural sample", "cohorts": cohorts}
	var output: String = "/private/tmp/labyrinth-reach-proof/legal-action-snapshots.json"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("REACH LEGALITY SNAPSHOTS: %d rooms, %d cohorts -> %s" % [room_count, cohorts.size(), output])
	quit(0)
