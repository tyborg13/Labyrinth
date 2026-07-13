extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const DEFAULT_SEED: int = 7262026
const INVALID_COORD: Vector2i = Vector2i(-999999, -999999)
const DEFAULT_REWARD_CARDS: Array = ["quick_stab", "bone_dart", "sidestep_slash", "patch_up"]
const DEFAULT_RELIC_CHOICES: Array = ["iron_lung", "ember_lens", "pilgrim_boots"]
const VALID_SCENARIOS: Array = ["start", "pre_battle", "combat", "reward", "campfire", "treasure", "character", "blacksmith", "arcanist", "scavenger", "boss", "victory", "defeat"]
const VALID_UMBRA_STAGES: Array = ["clear", "fringe", "advancing", "pressing", "deep", "heart", "eclipse"]

var _run_engine = RunEngine.new()
var _combat_engine = CombatEngine.new()
var _options: Dictionary = {}
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_options = _parse_args()
	if _failed:
		return
	if bool(_options.get("show_help", false)):
		_print_help()
		quit(0)
		return
	var user_namespace: String = ParallelRuntime.current_namespace()
	if user_namespace.is_empty() and not bool(_options.get("allow_live_user_dir", false)):
		_fail("Refusing to write the live Godot user:// save. Run through tools/inspection_fixture.py or pass --allow-live-user-dir explicitly.")
		return
	var scenario: String = str(_options.get("scenario", "combat"))
	if not VALID_SCENARIOS.has(scenario):
		_fail("Unknown scenario %s. Expected one of: %s" % [scenario, ", ".join(VALID_SCENARIOS)])
		return
	var progression: Dictionary = _build_progression()
	var run_state: Dictionary = _build_run_state(scenario, progression)
	if _failed:
		return
	run_state["inspection_fixture"] = _fixture_metadata(scenario, user_namespace, run_state)
	if not str(_options.get("notice", "")).is_empty():
		run_state["notice"] = str(_options.get("notice", ""))
	if not ProgressionStore.save_data(progression):
		_fail("Could not save progression.json")
		return
	if not ProgressionStore.save_run_state(run_state):
		_fail("Could not save current_run.save")
		return
	_print_result(scenario, user_namespace, run_state)
	quit(0)

func _parse_args() -> Dictionary:
	var parsed: Dictionary = {
		"scenario": "combat",
		"seed": DEFAULT_SEED,
		"show_help": false,
		"allow_live_user_dir": false,
		"embers": 0,
		"held_embers": -1,
		"level": 1,
		"player_hp": -1,
		"player_max_hp": -1,
		"player_position": "",
		"hand": "",
		"draw": "",
		"discard": "",
		"burned": "",
		"elemental_intensity": "",
		"reward_cards": "",
		"relic_choices": "",
		"relics": "",
		"attuned_magic": "",
		"magic_inventory": "",
		"equipment_inventory": "",
		"item_inventory": "",
		"equipped_items": "",
		"equip": "",
		"stats": "",
		"room_coord": "",
		"min_enemies": 0,
		"enemy_types": "",
		"enemy_positions": "",
		"enemy_intents": "",
		"enemy_hp": -1,
		"equipment_drop": "",
		"notice": "",
		"summary": ""
	}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var arg: String = args[index]
		match arg:
			"--help", "-h":
				parsed["show_help"] = true
			"--allow-live-user-dir":
				parsed["allow_live_user_dir"] = true
			"--scenario":
				index += 1
				parsed["scenario"] = _required_arg(args, index, arg)
			"--seed":
				index += 1
				parsed["seed"] = int(_required_arg(args, index, arg))
			"--embers":
				index += 1
				parsed["embers"] = int(_required_arg(args, index, arg))
			"--held-embers":
				index += 1
				parsed["held_embers"] = int(_required_arg(args, index, arg))
			"--level":
				index += 1
				parsed["level"] = int(_required_arg(args, index, arg))
			"--player-hp":
				index += 1
				parsed["player_hp"] = int(_required_arg(args, index, arg))
			"--player-max-hp":
				index += 1
				parsed["player_max_hp"] = int(_required_arg(args, index, arg))
			"--player-position":
				index += 1
				parsed["player_position"] = _required_arg(args, index, arg)
			"--hand":
				index += 1
				parsed["hand"] = _required_arg(args, index, arg)
			"--draw":
				index += 1
				parsed["draw"] = _required_arg(args, index, arg)
			"--discard":
				index += 1
				parsed["discard"] = _required_arg(args, index, arg)
			"--burned":
				index += 1
				parsed["burned"] = _required_arg(args, index, arg)
			"--elemental-intensity":
				index += 1
				parsed["elemental_intensity"] = _required_arg(args, index, arg)
			"--reward-cards":
				index += 1
				parsed["reward_cards"] = _required_arg(args, index, arg)
			"--relic-choices":
				index += 1
				parsed["relic_choices"] = _required_arg(args, index, arg)
			"--relics":
				index += 1
				parsed["relics"] = _required_arg(args, index, arg)
			"--attuned-magic":
				index += 1
				parsed["attuned_magic"] = _required_arg(args, index, arg)
			"--magic-inventory":
				index += 1
				parsed["magic_inventory"] = _required_arg(args, index, arg)
			"--equipment-inventory":
				index += 1
				parsed["equipment_inventory"] = _required_arg(args, index, arg)
			"--item-inventory":
				index += 1
				parsed["item_inventory"] = _required_arg(args, index, arg)
			"--equipped-items":
				index += 1
				parsed["equipped_items"] = _required_arg(args, index, arg)
			"--equip":
				index += 1
				parsed["equip"] = _required_arg(args, index, arg)
			"--stats":
				index += 1
				parsed["stats"] = _required_arg(args, index, arg)
			"--room-coord":
				index += 1
				parsed["room_coord"] = _required_arg(args, index, arg)
			"--min-enemies":
				index += 1
				parsed["min_enemies"] = int(_required_arg(args, index, arg))
			"--enemy-types":
				index += 1
				parsed["enemy_types"] = _required_arg(args, index, arg)
			"--enemy-positions":
				index += 1
				parsed["enemy_positions"] = _required_arg(args, index, arg)
			"--enemy-intents":
				index += 1
				parsed["enemy_intents"] = _required_arg(args, index, arg)
			"--enemy-hp":
				index += 1
				parsed["enemy_hp"] = int(_required_arg(args, index, arg))
			"--equipment-drop":
				index += 1
				parsed["equipment_drop"] = _required_arg(args, index, arg)
			"--equipment-drop-position":
				index += 1
				parsed["equipment_drop_position"] = _required_arg(args, index, arg)
			"--umbra-stage":
				index += 1
				parsed["umbra_stage"] = _required_arg(args, index, arg)
			"--notice":
				index += 1
				parsed["notice"] = _required_arg(args, index, arg)
			"--summary":
				index += 1
				parsed["summary"] = _required_arg(args, index, arg)
			_:
				_fail("Unknown option: %s" % arg)
				return parsed
		if _failed:
			return parsed
		index += 1
	return parsed

func _required_arg(args: PackedStringArray, index: int, flag: String) -> String:
	if index >= args.size():
		_fail("Missing value for %s" % flag)
		return ""
	return args[index]

func _print_help() -> void:
	print("Inspection fixture save builder")
	print("Usage: godot --headless --path . --script tools/inspection_fixture.gd -- --scenario combat [options]")
	print("Scenarios: %s" % ", ".join(VALID_SCENARIOS))
	print("Common options:")
	print("  --seed N")
	print("  --embers N --held-embers N --level N --stats might=2,vigor=1")
	print("  --player-hp N --player-max-hp N --player-position 2:4 --relics ember_lens,pilgrim_boots")
	print("  --attuned-magic card_a,card_b --magic-inventory card_c,card_d")
	print("  --equip weapon=training_sword,offhand=splintered_shield")
	print("  --equipment-inventory item_a,item_b")
	print("  --item-inventory card_a,card_b --equipped-items card_c,card_d")
	print("Combat options:")
	print("  --hand card_a,card_b --draw card_c --discard card_d --burned card_e")
	print("  --elemental-intensity fire=2,ice=2,lightning=2,air=2,earth=2")
	print("  --enemy-types enemy_a,enemy_b --enemy-positions 6:1,5:4 --enemy-intents intent_a,intent_b")
	print("  --enemy-hp N --equipment-drop equipment_id [--equipment-drop-position 6:5]")
	print("  --umbra-stage clear|fringe|advancing|pressing|deep|heart|eclipse")
	print("Room options:")
	print("  --reward-cards card_a,card_b --relic-choices relic_a,relic_b --room-coord x,y")
	print("Pre-battle options:")
	print("  --min-enemies N")
	print("Safety:")
	print("  The script refuses to write live user:// saves unless LABYRINTH_USER_DIR_NAME is set or --allow-live-user-dir is passed.")

func _build_progression() -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = maxi(0, int(_options.get("embers", 0)))
	progression["level"] = clampi(int(_options.get("level", 1)), 1, GameData.max_progression_level())
	var stats: Dictionary = GameData.normalized_progression_stats({})
	for entry: String in _string_list(str(_options.get("stats", ""))):
		var pair: PackedStringArray = entry.split("=", false, 2)
		if pair.size() != 2:
			_fail("Invalid --stats entry %s. Use stat_id=value." % entry)
			return progression
		var stat_id: String = pair[0].strip_edges()
		if not GameData.progression_stat_ids().has(stat_id):
			_fail("Unknown progression stat %s" % stat_id)
			return progression
		stats[stat_id] = maxi(0, int(pair[1]))
	progression["stats"] = GameData.normalized_progression_stats(stats)
	progression["unspent_stat_points"] = maxi(
		0,
		GameData.progression_stat_points_for_level(int(progression.get("level", 1))) - GameData.spent_progression_stat_points(progression.get("stats", {}))
	)
	return progression

func _build_run_state(scenario: String, progression: Dictionary) -> Dictionary:
	match scenario:
		"start":
			return _build_start_run(progression)
		"character":
			var character_state: Dictionary = _apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression))
			if str(_options.get("notice", "")).is_empty():
				character_state["notice"] = "Inspection fixture: open Character."
			return _apply_room_overrides(character_state)
		"pre_battle":
			return _build_pre_battle_run(progression)
		"combat":
			return _build_combat_run(progression)
		"boss":
			var boss_state: Dictionary = _run_engine.create_debug_boss_run(progression)
			boss_state = _apply_loadout(boss_state)
			return _apply_combat_overrides(boss_state)
		"reward":
			return _build_reward_run(progression)
		"campfire":
			return _build_room_mode_run(progression, "campfire")
		"treasure":
			return _build_room_mode_run(progression, "treasure")
		"blacksmith", "arcanist", "scavenger":
			return _build_merchant_run(progression, scenario)
		"victory":
			return _build_terminal_run(progression, "victory")
		"defeat":
			return _build_terminal_run(progression, "defeat")
	return {}

func _build_start_run(progression: Dictionary) -> Dictionary:
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression))
	var requested_coord: Vector2i = _parse_coord(str(_options.get("room_coord", "")))
	if requested_coord != INVALID_COORD:
		state = _run_state_for_room(state, requested_coord, "room", Vector2i(1, 0))
		if str(_options.get("notice", "")).is_empty():
			state["notice"] = "Inspection fixture: room."
	return _apply_room_overrides(state)

func _build_combat_run(progression: Dictionary) -> Dictionary:
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression))
	var requested_coord: Vector2i = _parse_coord(str(_options.get("room_coord", "")))
	if requested_coord != INVALID_COORD:
		state = _force_combat_room(state, requested_coord)
	else:
		var combat_coord: Vector2i = _first_available_room_coord_of_type(state, "combat")
		if combat_coord != INVALID_COORD:
			state = _run_engine.move_to_room(state, combat_coord)
		if str(state.get("mode", "")) != "combat":
			var fallback_coord: Vector2i = combat_coord if combat_coord != INVALID_COORD else _first_room_coord_of_type(state, "combat")
			state = _force_combat_room(state, fallback_coord)
	return _apply_combat_overrides(state)

func _build_pre_battle_run(progression: Dictionary) -> Dictionary:
	var seed: int = int(_options.get("seed", DEFAULT_SEED))
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(seed, progression))
	var requested_coord: Vector2i = _parse_coord(str(_options.get("room_coord", "")))
	var min_enemies: int = maxi(1, int(_options.get("min_enemies", 5)))
	var coord: Vector2i = requested_coord
	if coord == INVALID_COORD:
		coord = _first_room_coord_with_min_enemies(state, min_enemies)
	if coord == INVALID_COORD:
		_fail("Could not find a pre-battle room with at least %d enemies." % min_enemies)
		return state
	var travel_dir: Vector2i = _fixture_travel_dir_for_coord(coord)
	state = _run_state_for_room(state, coord, RunEngine.MODE_PRE_BATTLE, travel_dir)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	var room: Dictionary = _run_engine.room_metadata(state, coord).duplicate(true)
	if str(room.get("type", "")) not in ["combat", "boss"]:
		room["type"] = "combat"
		room["element"] = str(room.get("element", ElementData.NONE))
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = _run_engine.call("_display_layout_for_room", seed, room, travel_dir)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel_dir
	if str(_options.get("notice", "")).is_empty():
		state["notice"] = "Inspection fixture: pre-battle."
	return _apply_room_overrides(state)

func _build_reward_run(progression: Dictionary) -> Dictionary:
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression))
	state["mode"] = "reward"
	state["combat_state"] = {}
	var reward_cards: Array[String] = _string_list(str(_options.get("reward_cards", "")))
	if reward_cards.is_empty():
		reward_cards = _string_array(DEFAULT_REWARD_CARDS)
	if not _validate_card_ids(reward_cards, "--reward-cards"):
		return state
	state["pending_reward"] = {
		"cards": reward_cards,
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	if str(_options.get("notice", "")).is_empty():
		state["notice"] = "Inspection fixture: reward choice."
	return _apply_room_overrides(state)

func _build_room_mode_run(progression: Dictionary, mode: String) -> Dictionary:
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression))
	var requested_coord: Vector2i = _parse_coord(str(_options.get("room_coord", "")))
	var coord: Vector2i = requested_coord if requested_coord != INVALID_COORD else _first_room_coord_of_type(state, mode)
	state = _run_state_for_room(state, coord, mode, Vector2i(1, 0))
	if mode == "campfire":
		state["player_hp"] = _option_or_default("player_hp", mini(120, int(state.get("player_max_hp", 360))))
		if str(_options.get("notice", "")).is_empty():
			state["notice"] = "Inspection fixture: campfire."
	elif mode == "treasure":
		var relic_choices: Array[String] = _string_list(str(_options.get("relic_choices", "")))
		if relic_choices.is_empty():
			relic_choices = _string_array(DEFAULT_RELIC_CHOICES)
		if not _validate_relic_ids(relic_choices, "--relic-choices"):
			return state
		state["pending_relics"] = relic_choices
		if str(_options.get("notice", "")).is_empty():
			state["notice"] = "Inspection fixture: relic cache."
	return _apply_room_overrides(state)

func _build_merchant_run(progression: Dictionary, merchant_kind: String) -> Dictionary:
	var seed: int = int(_options.get("seed", DEFAULT_SEED))
	var state: Dictionary = _apply_loadout(_run_engine.create_new_run(seed, progression))
	var requested_coord: Vector2i = _parse_coord(str(_options.get("room_coord", "")))
	var coord: Vector2i = requested_coord if requested_coord != INVALID_COORD else _first_room_coord_of_type_or_invalid(state, merchant_kind)
	if requested_coord == INVALID_COORD and coord == INVALID_COORD:
		for offset: int in range(1, 120):
			var candidate_seed: int = seed + offset
			var candidate_state: Dictionary = _apply_loadout(_run_engine.create_new_run(candidate_seed, progression))
			var candidate_coord: Vector2i = _first_room_coord_of_type_or_invalid(candidate_state, merchant_kind)
			if candidate_coord == INVALID_COORD:
				continue
			state = candidate_state
			coord = candidate_coord
			break
	if coord == INVALID_COORD:
		_fail("Could not find a %s room for inspection." % merchant_kind)
		return state
	state = _run_state_for_room(state, coord, "room", Vector2i(1, 0))
	var room: Dictionary = _run_engine.room_metadata(state, coord).duplicate(true)
	room["type"] = merchant_kind
	room["merchant_kind"] = merchant_kind
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	room["npcs"] = [{"id": merchant_kind, "pos": Vector2i(3, 4)}]
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room_layout"] = _run_engine.call("_display_layout_for_room", int(state.get("seed", seed)), room, Vector2i(1, 0))
	if str(_options.get("notice", "")).is_empty():
		state["notice"] = "Inspection fixture: %s merchant." % merchant_kind.capitalize()
	return _apply_room_overrides(state)

func _build_terminal_run(progression: Dictionary, mode: String) -> Dictionary:
	var coord: Vector2i = Vector2i(8, 0) if mode == "victory" else Vector2i(1, 0)
	var state: Dictionary = _run_state_for_room(_apply_loadout(_run_engine.create_new_run(int(_options.get("seed", DEFAULT_SEED)), progression)), coord, mode, Vector2i(1, 0))
	state["mode"] = mode
	state["combat_state"] = {}
	state["victory"] = mode == "victory"
	state["game_over"] = mode == "defeat"
	if mode == "defeat":
		state["player_hp"] = 0
	state["held_embers"] = maxi(0, _option_or_default("held_embers", 42 if mode == "victory" else 23))
	state["unbanked_embers"] = int(state.get("held_embers", 0))
	return _apply_room_overrides(state)

func _apply_loadout(run_state: Dictionary) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var relics: Array[String] = _string_list(str(_options.get("relics", "")))
	if not relics.is_empty():
		if not _validate_relic_ids(relics, "--relics"):
			return state
		state["relics"] = relics
	var attuned_magic: Array[String] = _string_list(str(_options.get("attuned_magic", "")))
	if not attuned_magic.is_empty():
		if not _validate_card_ids(attuned_magic, "--attuned-magic"):
			return state
		state["attuned_magic_cards"] = attuned_magic
	var magic_inventory: Array[String] = _string_list(str(_options.get("magic_inventory", "")))
	if not magic_inventory.is_empty():
		if not _validate_card_ids(magic_inventory, "--magic-inventory"):
			return state
		state["magic_inventory"] = magic_inventory
	var equipment_inventory: Array[String] = _string_list(str(_options.get("equipment_inventory", "")))
	if not equipment_inventory.is_empty():
		if not _validate_equipment_ids(equipment_inventory, "--equipment-inventory"):
			return state
		state["equipment_inventory"] = equipment_inventory
	var item_inventory: Array[String] = _string_list(str(_options.get("item_inventory", "")))
	if not item_inventory.is_empty():
		if not _validate_item_card_ids(item_inventory, "--item-inventory"):
			return state
		state["item_inventory"] = item_inventory
	var equipped_items: Array[String] = _string_list(str(_options.get("equipped_items", "")))
	if not equipped_items.is_empty():
		if equipped_items.size() > GameData.item_loadout_limit():
			_fail("--equipped-items allows at most %d cards" % GameData.item_loadout_limit())
			return state
		if not _validate_item_card_ids(equipped_items, "--equipped-items"):
			return state
		state["equipped_items"] = equipped_items
	var equipped: Dictionary = (state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	for entry: String in _string_list(str(_options.get("equip", ""))):
		var pair: PackedStringArray = entry.split("=", false, 2)
		var slot: String = ""
		var equipment_id: String = ""
		if pair.size() == 2:
			slot = pair[0].strip_edges()
			equipment_id = pair[1].strip_edges()
		else:
			equipment_id = entry.strip_edges()
			slot = GameData.equipment_slot(equipment_id)
		if not GameData.equipment_slots().has(slot):
			_fail("Unknown equipment slot %s in --equip" % slot)
			return state
		if not _validate_equipment_ids(_string_array([equipment_id]), "--equip"):
			return state
		equipped[slot] = equipment_id
	state["equipped_equipment"] = equipped
	state["collected_equipment"] = _unique_strings(GameData.starter_equipment_ids() + _dictionary_values(equipped) + equipment_inventory)
	state["deck_cards"] = GameData.compile_deck_cards(equipped, state.get("attuned_magic_cards", []), state.get("equipped_items", []))
	var max_hp: int = _option_or_default("player_max_hp", int(state.get("player_max_hp", 1)))
	state["player_max_hp"] = maxi(1, max_hp)
	state["player_hp"] = clampi(_option_or_default("player_hp", int(state.get("player_hp", max_hp))), 0, int(state.get("player_max_hp", max_hp)))
	if int(_options.get("held_embers", -1)) >= 0:
		state["held_embers"] = maxi(0, int(_options.get("held_embers", 0)))
		state["unbanked_embers"] = int(state.get("held_embers", 0))
	return state

func _apply_room_overrides(run_state: Dictionary) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	if int(_options.get("held_embers", -1)) >= 0:
		state["held_embers"] = maxi(0, int(_options.get("held_embers", 0)))
		state["unbanked_embers"] = int(state.get("held_embers", 0))
	return state

func _apply_combat_overrides(run_state: Dictionary) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var combat_state: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	if combat_state.is_empty():
		_fail("Could not build a combat state for inspection.")
		return state
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	var hand: Array[String] = _string_list(str(_options.get("hand", "")))
	if not hand.is_empty():
		if not _validate_card_ids(hand, "--hand"):
			return state
		deck["hand"] = hand
	for zone: String in ["draw", "discard", "burned"]:
		var cards: Array[String] = _string_list(str(_options.get(zone, "")))
		if cards.is_empty():
			continue
		if not _validate_card_ids(cards, "--%s" % zone):
			return state
		deck[zone] = cards
	combat_state["deck"] = deck
	var intensity: Dictionary = _elemental_intensity_override(combat_state)
	if not intensity.is_empty():
		combat_state["elemental_intensity"] = intensity
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	if int(_options.get("player_max_hp", -1)) >= 0:
		player["max_hp"] = maxi(1, int(_options.get("player_max_hp", 1)))
	if int(_options.get("player_hp", -1)) >= 0:
		player["hp"] = clampi(int(_options.get("player_hp", 1)), 0, int(player.get("max_hp", 1)))
	var player_position_raw: String = str(_options.get("player_position", "")).strip_edges()
	if not player_position_raw.is_empty():
		var player_position: Vector2i = _parse_colon_coord(player_position_raw, "--player-position")
		if _failed:
			return state
		player["pos"] = player_position
		combat_state = _clear_fixture_occupant_tiles(combat_state, _vector2i_array([player_position]))
	combat_state["player"] = player
	if not str(_options.get("enemy_types", "")).strip_edges().is_empty():
		combat_state = _apply_enemy_overrides(combat_state)
		if _failed:
			return state
	if not str(_options.get("enemy_positions", "")).strip_edges().is_empty():
		combat_state = _apply_enemy_position_overrides(combat_state)
		if _failed:
			return state
	var umbra_stage: String = str(_options.get("umbra_stage", "")).strip_edges().to_lower()
	if not umbra_stage.is_empty():
		if not VALID_UMBRA_STAGES.has(umbra_stage):
			_fail("Unknown Umbra stage %s. Expected one of: %s" % [umbra_stage, ", ".join(VALID_UMBRA_STAGES)])
			return state
		var umbra: Dictionary = (combat_state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = umbra_stage
		umbra["stage_reduction"] = 0
		combat_state["umbra"] = umbra
	if int(_options.get("enemy_hp", -1)) >= 0:
		var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
		if enemies.is_empty():
			_fail("--enemy-hp requires at least one enemy")
			return state
		var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
		enemy["hp"] = clampi(int(_options.get("enemy_hp", 1)), 1, int(enemy.get("max_hp", 1)))
		enemies[0] = enemy
		combat_state["enemies"] = enemies
	var equipment_drop: String = str(_options.get("equipment_drop", "")).strip_edges()
	if not equipment_drop.is_empty():
		if not _validate_equipment_ids(_string_array([equipment_drop]), "--equipment-drop"):
			return state
		var equipment_drop_tile: Vector2i = _inspection_equipment_drop_tile(combat_state)
		var equipment_drop_position: String = str(_options.get("equipment_drop_position", "")).strip_edges()
		if not equipment_drop_position.is_empty():
			equipment_drop_tile = _parse_colon_coord(equipment_drop_position, "--equipment-drop-position")
			if _failed:
				return state
		var loot: Array = []
		for loot_var: Variant in combat_state.get("loot", []):
			if typeof(loot_var) == TYPE_DICTIONARY and str((loot_var as Dictionary).get("kind", "")) == "equipment":
				continue
			loot.append((loot_var as Dictionary).duplicate(true) if typeof(loot_var) == TYPE_DICTIONARY else loot_var)
		loot.append({
			"id": "inspection_equipment_%s" % equipment_drop,
			"kind": "equipment",
			"equipment_id": equipment_drop,
			"pos": equipment_drop_tile
		})
		combat_state["loot"] = loot
	combat_state["relics"] = state.get("relics", []).duplicate(true)
	state["combat_state"] = combat_state
	var current_layout: Dictionary = (state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	current_layout["loot"] = (combat_state.get("loot", []) as Array).duplicate(true)
	state["current_room_layout"] = current_layout
	state["player_hp"] = int(player.get("hp", state.get("player_hp", 1)))
	state["mode"] = "combat"
	return state

func _inspection_equipment_drop_tile(combat_state: Dictionary) -> Vector2i:
	var occupied: Dictionary = {}
	occupied[(combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)] = true
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and int((terrain_var as Dictionary).get("hp", 0)) > 0:
			occupied[(terrain_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for tile: Vector2i in _vector2i_array([Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 3), Vector2i(5, 3)]):
		if not occupied.has(tile):
			return tile
	return Vector2i(4, 3)

func _elemental_intensity_override(combat_state: Dictionary) -> Dictionary:
	var raw: String = str(_options.get("elemental_intensity", ""))
	if raw.strip_edges().is_empty():
		return {}
	var intensity: Dictionary = _combat_engine.elemental_intensities(combat_state)
	for entry: String in _string_list(raw):
		var pair: PackedStringArray = entry.split("=", false, 2)
		if pair.size() != 2:
			_fail("Invalid --elemental-intensity entry %s. Use element=value." % entry)
			return {}
		var element_id: String = pair[0].strip_edges()
		if not ElementData.is_elemental(element_id):
			_fail("Unknown elemental intensity %s" % element_id)
			return {}
		intensity[element_id] = maxi(0, int(pair[1]))
	return intensity

func _apply_enemy_overrides(combat_state: Dictionary) -> Dictionary:
	var enemy_types: Array[String] = _string_list(str(_options.get("enemy_types", "")))
	var enemy_intents: Array[String] = _string_list(str(_options.get("enemy_intents", "")))
	var existing_enemies: Array = combat_state.get("enemies", [])
	var fallback_positions: Array[Vector2i] = _vector2i_array([
		Vector2i(5, 4),
		Vector2i(5, 3),
		Vector2i(4, 5),
		Vector2i(5, 5),
		Vector2i(4, 3)
	])
	var enemies: Array = []
	for index: int in range(enemy_types.size()):
		var enemy_type: String = enemy_types[index]
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		if enemy_def.is_empty():
			_fail("Unknown enemy id %s in --enemy-types" % enemy_type)
			return combat_state
		var position: Vector2i = fallback_positions[mini(index, fallback_positions.size() - 1)]
		if index < existing_enemies.size():
			var existing_enemy: Dictionary = existing_enemies[index]
			position = existing_enemy.get("pos", position)
		var max_hp: int = int(enemy_def.get("max_hp", 1))
		var enemy: Dictionary = {
			"id": index + 1,
			"type": enemy_type,
			"pos": position,
			"hp": max_hp,
			"max_hp": max_hp,
			"block": 0,
			"stoneskin": 0,
			"statuses": {}
		}
		var intent_id: String = enemy_intents[index] if index < enemy_intents.size() else ""
		var intent: Dictionary = _enemy_intent(enemy_type, intent_id)
		if intent.is_empty():
			return combat_state
		enemy["intent"] = intent
		enemies.append(_combat_engine.call("_normalized_enemy", enemy) as Dictionary)
	combat_state["enemies"] = enemies
	combat_state = _combat_engine.call("_initialize_initiative_queue", combat_state) as Dictionary
	return combat_state

func _apply_enemy_position_overrides(combat_state: Dictionary) -> Dictionary:
	var requested_positions: Array[Vector2i] = []
	for entry: String in _string_list(str(_options.get("enemy_positions", ""))):
		var pair: PackedStringArray = entry.split(":", false, 2)
		if pair.size() != 2:
			_fail("Invalid --enemy-positions entry %s. Use x:y." % entry)
			return combat_state
		requested_positions.append(Vector2i(int(pair[0]), int(pair[1])))
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	if requested_positions.size() > enemies.size():
		_fail("--enemy-positions supplied %d positions for %d enemies" % [requested_positions.size(), enemies.size()])
		return combat_state
	for index: int in range(requested_positions.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["pos"] = requested_positions[index]
		enemies[index] = _combat_engine.call("_normalized_enemy", enemy) as Dictionary
	combat_state = _clear_fixture_occupant_tiles(combat_state, requested_positions)
	combat_state["enemies"] = enemies
	return _combat_engine.call("_initialize_initiative_queue", combat_state) as Dictionary

func _clear_fixture_occupant_tiles(combat_state: Dictionary, positions: Array[Vector2i]) -> Dictionary:
	var state: Dictionary = combat_state.duplicate(true)
	var occupied: Dictionary = {}
	for position: Vector2i in positions:
		occupied[position] = true
	var terrain: Array = []
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY or not occupied.has((terrain_var as Dictionary).get("pos", INVALID_COORD)):
			terrain.append((terrain_var as Dictionary).duplicate(true) if typeof(terrain_var) == TYPE_DICTIONARY else terrain_var)
	state["terrain"] = terrain
	var traps: Array = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY or not occupied.has((trap_var as Dictionary).get("pos", INVALID_COORD)):
			traps.append((trap_var as Dictionary).duplicate(true) if typeof(trap_var) == TYPE_DICTIONARY else trap_var)
	state["traps"] = traps
	return state

func _parse_colon_coord(value: String, source: String) -> Vector2i:
	var pair: PackedStringArray = value.split(":", false, 2)
	if pair.size() != 2:
		_fail("Invalid %s value %s. Use x:y." % [source, value])
		return INVALID_COORD
	return Vector2i(int(pair[0]), int(pair[1]))

func _force_combat_room(source_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = _run_state_for_room(source_state, coord, "combat", Vector2i(1, 0))
	var room: Dictionary = _run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	if str(room.get("type", "")) in ["start", "campfire", "treasure"]:
		room["type"] = "combat"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	var layout: Dictionary = (_run_engine.call("_combat_layout_for_room", room, Vector2i(1, 0), state) as Dictionary).duplicate(true)
	state["current_room_layout"] = layout
	state["combat_state"] = _combat_engine.create_combat(int(state.get("seed", 0)), layout, _run_engine.call("_player_snapshot", state) as Dictionary)
	state["mode"] = "combat"
	return state

func _run_state_for_room(source_state: Dictionary, coord: Vector2i, mode: String, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = _run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode in ["room", "campfire"]
	if mode in ["campfire", "treasure"]:
		room["type"] = mode
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = _run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_available_room_coord_of_type(state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in _run_engine.available_moves(state):
		if str(_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
			return coord
	return INVALID_COORD

func _first_room_coord_with_min_enemies(state: Dictionary, min_enemies: int) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				var room: Dictionary = _run_engine.room_metadata(state, coord)
				if str(room.get("type", "")) not in ["combat", "boss"]:
					continue
				var layout: Dictionary = _run_engine.call("_combat_layout_for_room", room, _fixture_travel_dir_for_coord(coord), state)
				var enemies: Array = layout.get("enemies", [])
				if enemies.size() >= min_enemies:
					return coord
	return INVALID_COORD

func _first_room_coord_of_type(state: Dictionary, room_type: String) -> Vector2i:
	var coord: Vector2i = _first_room_coord_of_type_or_invalid(state, room_type)
	return coord if coord != INVALID_COORD else Vector2i(1, 0)

func _first_room_coord_of_type_or_invalid(state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return INVALID_COORD

func _fixture_travel_dir_for_coord(coord: Vector2i) -> Vector2i:
	if coord == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(coord.x) >= absi(coord.y) and coord.x != 0:
		return Vector2i(1, 0) if coord.x > 0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if coord.y > 0 else Vector2i(0, -1)

func _parse_coord(value: String) -> Vector2i:
	if value.strip_edges().is_empty():
		return INVALID_COORD
	var parts: PackedStringArray = value.split(",", false, 2)
	if parts.size() != 2:
		_fail("Invalid --room-coord %s. Use x,y." % value)
		return INVALID_COORD
	return Vector2i(int(parts[0]), int(parts[1]))

func _string_list(value: String) -> Array[String]:
	var result: Array[String] = []
	for raw: String in value.split(",", false):
		var item: String = raw.strip_edges()
		if item.is_empty():
			continue
		result.append(item)
	return result

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		var item: String = str(value).strip_edges()
		if item.is_empty():
			continue
		result.append(item)
	return result

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		result.append(value as Vector2i)
	return result

func _enemy_intent(enemy_type: String, intent_id: String) -> Dictionary:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var intents: Array = enemy_def.get("intents", [])
	if intents.is_empty():
		_fail("Enemy %s has no intents." % enemy_type)
		return {}
	if intent_id.strip_edges().is_empty():
		return (intents[0] as Dictionary).duplicate(true)
	for intent_entry: Variant in intents:
		var intent: Dictionary = intent_entry
		if str(intent.get("id", "")) == intent_id:
			return intent.duplicate(true)
	_fail("Unknown intent id %s for enemy %s in --enemy-intents" % [intent_id, enemy_type])
	return {}

func _dictionary_values(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in source.values():
		var item: String = str(value).strip_edges()
		if item.is_empty():
			continue
		result.append(item)
	return result

func _unique_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		var item: String = str(value).strip_edges()
		if item.is_empty() or result.has(item):
			continue
		result.append(item)
	return result

func _validate_card_ids(card_ids: Array[String], source: String) -> bool:
	for card_id: String in card_ids:
		if GameData.card_def(card_id).is_empty():
			_fail("Unknown card id %s in %s" % [card_id, source])
			return false
	return true

func _validate_relic_ids(relic_ids: Array[String], source: String) -> bool:
	for relic_id: String in relic_ids:
		if GameData.relic_def(relic_id).is_empty():
			_fail("Unknown relic id %s in %s" % [relic_id, source])
			return false
	return true

func _validate_equipment_ids(equipment_ids: Array[String], source: String) -> bool:
	for equipment_id: String in equipment_ids:
		if GameData.equipment_def(equipment_id).is_empty():
			_fail("Unknown equipment id %s in %s" % [equipment_id, source])
			return false
	return true

func _validate_item_card_ids(card_ids: Array[String], source: String) -> bool:
	for card_id: String in card_ids:
		if not GameData.card_is_item(card_id):
			_fail("Unknown item card id %s in %s" % [card_id, source])
			return false
	return true

func _option_or_default(key: String, default_value: int) -> int:
	var value: int = int(_options.get(key, -1))
	return value if value >= 0 else default_value

func _fixture_metadata(scenario: String, user_namespace: String, run_state: Dictionary) -> Dictionary:
	var requested_seed: int = int(_options.get("seed", DEFAULT_SEED))
	return {
		"scenario": scenario,
		"summary": str(_options.get("summary", "")),
		"namespace": user_namespace,
		"seed": int(run_state.get("seed", requested_seed)),
		"requested_seed": requested_seed,
		"created_at_unix": Time.get_unix_time_from_system()
	}

func _print_result(scenario: String, user_namespace: String, run_state: Dictionary) -> void:
	var mode: String = str(run_state.get("mode", ""))
	var current_room: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var payload: Dictionary = {
		"ok": true,
		"scenario": scenario,
		"mode": mode,
		"namespace": user_namespace,
		"current_room": "%d,%d" % [current_room.x, current_room.y],
		"save_path": ProjectSettings.globalize_path("user://current_run.save"),
		"progression_path": ProjectSettings.globalize_path("user://progression.json"),
		"summary": str(_options.get("summary", ""))
	}
	print("Inspection fixture saved.")
	print("  scenario: %s" % scenario)
	print("  mode: %s" % mode)
	print("  namespace: %s" % (user_namespace if not user_namespace.is_empty() else "<live user dir>"))
	print("  save: %s" % payload["save_path"])
	print("INSPECTION_FIXTURE_RESULT %s" % JSON.stringify(payload))

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("INSPECTION FIXTURE ERROR: %s" % message)
	quit(1)
