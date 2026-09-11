extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Path = preload("res://scripts/path_utils.gd")

# Adversarial move/pass policy: select the legal endpoint with least HP loss
# before the next activation, then greatest separation. Uses the real initiative
# scheduler and two-tile pool. No card plays or extra movement are granted.
func _initialize() -> void:
	var combat := Combat.new()
	var reports: Array[Dictionary]
	for types: Array in [["crawler"], ["acolyte"], ["harrier"], ["lightning_wisp"], ["crawler", "acolyte", "harrier"], ["warden", "grave_surgeon"]]:
		for clutter: bool in [false, true]:
			var layout: Dictionary = Rooms.new().generate_room(9102601, {"coord": Vector2i(1, 0), "depth": 1, "type": "combat", "element": "none"}, Vector2i.RIGHT)
			layout["umbra_stage"] = "clear"
			layout["traps"] = []
			layout["loot"] = []
			layout["objective"] = {"type": "kill_all"}
			if not clutter:
				layout["terrain"] = []
				for y: int in range(1, 8):
					for x: int in range(1, 8): layout["grid"][y][x] = "stone"
			layout["player_start"] = Vector2i(7, 4)
			layout["enemies"] = []
			for index: int in range(types.size()):
				var pos := Vector2i(2, 3 + index)
				layout["grid"][pos.y][pos.x] = "stone"
				layout["terrain"] = (layout["terrain"] as Array).filter(func(t: Dictionary) -> bool: return t["pos"] != pos)
				layout["enemies"].append({"id": index + 1, "type": types[index], "pos": pos, "hp": 12, "max_hp": 12})
			var state: Dictionary = combat.create_combat(9102601, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["pale_spark", "dull_bolt", "quick_stab", "brace", "guarded_step", "shadow_step", "whirlwind_slash"], "hand_size": 7})
			var steps: int = 0
			var damage: int = 0
			var intents: Dictionary = {}
			for activation: int in range(24):
				if combat.combat_outcome(state) != "": break
				var options: Array[Vector2i] = combat.player_movement_targets(state)
				options.append(state["player"]["pos"])
				var best: Dictionary = {}
				var best_score: int = -100000
				for tile: Vector2i in options:
					var moved: Dictionary = combat.apply_player_movement(state, tile) if tile != state["player"]["pos"] else state
					var forecast: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(moved))["state"]
					var nearest: int = 99
					for enemy: Dictionary in forecast["enemies"]:
						if int(enemy["hp"]) > 0: nearest = mini(nearest, Path.manhattan(forecast["player"]["pos"], enemy["pos"]))
					var score: int = int(forecast["player"]["hp"]) * 100 + nearest
					if score > best_score:
						best_score = score
						best = moved
				var before_hp: int = int(state["player"]["hp"])
				for enemy: Dictionary in best["enemies"]:
					var id: String = str(enemy["intent"].get("id", ""))
					intents[id] = int(intents.get(id, 0)) + 1
				state = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(best))["state"]
				damage += maxi(0, before_hp - int(state["player"]["hp"]))
				steps += 1
			reports.append({"types": types, "clutter": clutter, "activations": steps, "damage": damage, "hp": state["player"]["hp"], "clock": state["initiative_clock"], "observed_intents": intents})
			print("PURSUIT ", reports.back())
	var file: FileAccess = FileAccess.open("/private/tmp/labyrinth-reach-proof/pursuit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"balance_revision": Data.BALANCE_REVISION, "policy": "24 activations; exact next-return HP then separation; move/pass only; observed intents sampled at player boundaries", "cases": reports}, "\t"))
	quit()
