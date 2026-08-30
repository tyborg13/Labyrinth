extends RefCounted
class_name RunEngine

const BattlefieldItemRules = preload("res://scripts/battlefield_item_rules.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

const PLANNED_DEPTH_SEQUENCES: int = 6
const ACTIVE_DEPTH_SEQUENCES: int = 6
const DEPTHS_PER_SEQUENCE: int = 4
const MAX_DEPTH: int = ACTIVE_DEPTH_SEQUENCES * DEPTHS_PER_SEQUENCE
const BASE_MAX_HP: int = 24
const BASE_HAND_SIZE: int = 5
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const REWARD_HEAL: int = 3
const CAMPFIRE_LINGER_HEAL: int = 4
const BOSS_VICTORY_HEAL_FRACTION: float = 0.25
const BOSS_VICTORY_EMBERS: int = 30
const DEBUG_BOSS_SEED: int = 90429
const DEBUG_BOSS_COORD: Vector2i = Vector2i(4, 0)
const RELIC_ROOM_CANDIDATE_PERCENT: int = 47
const MERCHANT_ROOM_CANDIDATE_PERCENT: int = 22
const MERCHANT_ROOM_MIN_DEPTH: int = 2
const EQUIPMENT_ROOM_DROP_PERCENT: int = 38
const EQUIPMENT_DROP_PITY_MISSES: int = 2
const MAX_VISITED_ROOMS_BEFORE_OUTWARD_OFFER: int = 3
const MISSED_EQUIPMENT_NOTICE: String = "Unclaimed gear crumbles into dust."
const ESCAPE_MISSED_EQUIPMENT_NOTICE: String = "Unclaimed gear will be left behind."
const SKILL_STATE_KEY: String = "skill_state"
const RUN_SKILL_EVENT_LIMIT: int = 48
const MERCHANT_SCAVENGER: String = "scavenger"
const LEGACY_MERCHANT_BLACKSMITH: String = "blacksmith"
const LEGACY_MERCHANT_ARCANIST: String = "arcanist"
# Compatibility aliases are retained only for old serialized runs and old test
# fixtures. New generation and every player-facing merchant path use Scavenger.
const MERCHANT_BLACKSMITH: String = LEGACY_MERCHANT_BLACKSMITH
const MERCHANT_ARCANIST: String = LEGACY_MERCHANT_ARCANIST
const CHOICE_CATEGORY_COMBAT: String = "combat"
const CHOICE_CATEGORY_NON_COMBAT: String = "non_combat"
const CHOICE_NON_COMBAT_ROOM_TYPES = ["treasure", MERCHANT_SCAVENGER]
const MERCHANT_EQUIPMENT_BUY_COST_BY_RARITY := {
	"common": 150,
	"rare": 240,
	"epic": 360,
	"legendary": 540
}
const MERCHANT_MAGIC_BUY_COST_BY_RARITY := {
	"common": 110,
	"rare": 175,
	"epic": 265,
	"legendary": 400
}
const MERCHANT_ITEM_BUY_COST_BY_RARITY := {
	"common": 25,
	"rare": 40,
	"epic": 60,
	"legendary": 90
}
const MERCHANT_SELL_VALUE_RATIO: float = 0.35
const MERCHANT_OFFERS_PER_CATEGORY: int = 3
const MERCHANT_OFFER_COUNT: int = MERCHANT_OFFERS_PER_CATEGORY * 3
const MERCHANT_ITEM_KIND_MAGIC: String = "magic"
const MERCHANT_ITEM_KIND_GEAR: String = "gear"
const MERCHANT_ITEM_KIND_ITEM: String = "item"
const MERCHANT_STOCK_KEY: String = "merchant_stock"
const MERCHANT_SOLD_KEY: String = "merchant_sold_items"
const MERCHANT_PURCHASED_KEY: String = "merchant_purchased_items"
const MERCHANT_REFILL_COUNT_KEY: String = "merchant_refill_count"
const MODE_PRE_BATTLE: String = "pre_battle"
const MODE_ESCAPE: String = "escape"
const UNREAD_LOADOUT_EQUIPMENT_KEY: String = "unread_loadout_equipment"
const UNREAD_LOADOUT_MAGIC_KEY: String = "unread_loadout_magic"
const NEW_LOADOUT_EQUIPMENT_KEY: String = "new_loadout_equipment"
const NEW_LOADOUT_MAGIC_KEY: String = "new_loadout_magic"
const RUN_CONTENT_SCHEMA_KEY: String = "run_content_schema"
const RUN_CONTENT_SCHEMA: int = 3
const COMBAT_UNITS_SCHEMA_KEY: String = "combat_units_schema"
const COMBAT_UNITS_SCHEMA: int = 1
const COMBAT_CONTINUATION_KEY: String = "pending_combat_checkpoints"
const DEFIANCE_CAPACITY_KEY: String = "defiance_capacity"
const DEFIANCE_REMAINING_KEY: String = "defiance_remaining"

var _combat_engine = CombatEngineScript.new()
var _room_generator = RoomGeneratorScript.new()

static func normalized_run_stats(value: Variant) -> Dictionary:
	return CombatEngineScript.normalized_run_stats(value)

static func run_result_id(run_state: Dictionary) -> String:
	return "run:%d:seed:%d" % [int(run_state.get("run_index", 0)), int(run_state.get("seed", 0))]

func create_new_run(seed: int, progression: Dictionary) -> Dictionary:
	var normalized_progression: Dictionary = ProgressionStore.normalized_data(progression)
	var max_hp: int = BASE_MAX_HP
	var hand_size: int = BASE_HAND_SIZE
	var heal_bonus: int = 0
	var starting_embers: int = maxi(0, int(normalized_progression.get("embers", 0)))
	var rooms: Dictionary = {}
	var start_room: Dictionary = _build_room_metadata(seed, Vector2i.ZERO)
	start_room["revealed"] = true
	start_room["visited"] = true
	start_room["cleared"] = true
	rooms[_room_key(Vector2i.ZERO)] = start_room
	var start_layout: Dictionary = _display_layout_for_room(seed, start_room, Vector2i.ZERO)
	var equipped_equipment: Dictionary = GameData.starting_equipped_equipment()
	var reward_cards: Array = []
	var attuned_magic_cards: Array = GameData.starting_magic_cards()
	var magic_inventory: Array = []
	var equipped_items: Array = []
	var defiance_capacity: int = ProgressionStore.defiance_capacity_for_level(
		int(normalized_progression.get("level", 1))
	)
	var run_state: Dictionary = {
		"seed": seed,
		"run_index": int(normalized_progression.get("run_counter", 0)),
		RUN_CONTENT_SCHEMA_KEY: RUN_CONTENT_SCHEMA,
		COMBAT_UNITS_SCHEMA_KEY: COMBAT_UNITS_SCHEMA,
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"current_room_layout": start_layout,
		"rooms": rooms,
		"deck_cards": GameData.compile_deck_cards(equipped_equipment, attuned_magic_cards, equipped_items),
		"reward_cards": reward_cards,
		"attuned_magic_cards": attuned_magic_cards,
		"magic_inventory": magic_inventory,
		"item_inventory": [],
		"equipped_items": equipped_items,
		"equipment_inventory": [],
		"equipped_equipment": equipped_equipment,
		"collected_equipment": GameData.starter_equipment_ids(),
		UNREAD_LOADOUT_EQUIPMENT_KEY: [],
		UNREAD_LOADOUT_MAGIC_KEY: [],
		NEW_LOADOUT_EQUIPMENT_KEY: [],
		NEW_LOADOUT_MAGIC_KEY: [],
		"equipment_drop_misses": 0,
		"relics": [],
		"player_hp": max_hp,
		"player_max_hp": max_hp,
		DEFIANCE_CAPACITY_KEY: defiance_capacity,
		DEFIANCE_REMAINING_KEY: defiance_capacity,
		"hand_size": hand_size,
		"heal_bonus": heal_bonus,
		"held_embers": starting_embers,
		"unbanked_embers": starting_embers,
		"combat_state": {},
		"pending_reward": {},
		"pending_escape": {},
		"pending_relics": [],
		"game_over": false,
		"victory": false,
		"turns_spent": 0,
		"run_stats": CombatEngineScript.default_run_stats(),
		"notice": "",
		SKILL_STATE_KEY: _default_skill_state(),
		"progression": normalized_progression
	}
	run_state = GrimoireLibrary.ensure_run_state(run_state)
	_reveal_neighbors(run_state, Vector2i.ZERO)
	_stage_recovery_marker(run_state)
	return run_state

func create_debug_boss_run(progression: Dictionary) -> Dictionary:
	var max_hp: int = 28
	var current_hp: int = 22
	var deck_cards: Array = []
	for card_id: String in [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"hamstring_shot",
		"sidestep_slash",
		"whirlwind_slash",
		"patch_up",
		"bloody_lunge",
		"brace",
		"lantern_shot",
		"iron_wheel",
		"ricochet_knife",
		"warded_advance",
		"cinderburst",
		"chain_bolt",
		"static_lash",
		"volt_surge",
		"frostbolt"
	]:
		deck_cards.append(card_id)
	var relics: Array[String] = []
	for relic_id: String in ["iron_lung", "ember_lens", "pilgrim_boots"]:
		relics.append(relic_id)
	var debug_equipped: Dictionary = GameData.starting_equipped_equipment()
	var debug_reward_cards: Array = _migrated_reward_cards_from_deck(deck_cards, debug_equipped)
	var debug_magic_state: Dictionary = _magic_loadout_from_collected_rewards(debug_reward_cards)
	var debug_attuned_magic: Array = debug_magic_state.get("attuned_magic_cards", []) as Array
	var debug_magic_inventory: Array = debug_magic_state.get("magic_inventory", []) as Array
	var debug_equipped_items: Array = ["crimson_draught", "nail_bomb"]
	deck_cards = GameData.compile_deck_cards(debug_equipped, debug_attuned_magic, debug_equipped_items)
	var boss_room: Dictionary = _build_room_metadata(DEBUG_BOSS_SEED, DEBUG_BOSS_COORD)
	boss_room["revealed"] = true
	boss_room["visited"] = true
	boss_room["cleared"] = false
	boss_room["sealed"] = false
	var layout: Dictionary = _combat_layout_for_room(boss_room, Vector2i(1, 0), {"seed": DEBUG_BOSS_SEED})
	var player_snapshot: Dictionary = {
		"hp": current_hp,
		"max_hp": max_hp,
		"deck_cards": deck_cards,
		"relics": relics,
		"hand_size": BASE_HAND_SIZE,
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN,
		"heal_bonus": 0,
		DEFIANCE_CAPACITY_KEY: ProgressionStore.defiance_capacity_for_level(int(progression.get("level", 1))),
		DEFIANCE_REMAINING_KEY: ProgressionStore.defiance_capacity_for_level(int(progression.get("level", 1)))
	}
	var combat_state: Dictionary = _combat_engine.create_combat(DEBUG_BOSS_SEED, layout, player_snapshot)
	var rooms: Dictionary = {}
	rooms[_room_key(DEBUG_BOSS_COORD)] = boss_room
	var run_state: Dictionary = {
		"seed": DEBUG_BOSS_SEED,
		"run_index": -1,
		RUN_CONTENT_SCHEMA_KEY: RUN_CONTENT_SCHEMA,
		COMBAT_UNITS_SCHEMA_KEY: COMBAT_UNITS_SCHEMA,
		"mode": "combat",
		"current_room": DEBUG_BOSS_COORD,
		"current_room_layout": layout,
		"rooms": rooms,
		"deck_cards": deck_cards,
		"reward_cards": debug_reward_cards,
		"attuned_magic_cards": debug_attuned_magic,
		"magic_inventory": debug_magic_inventory,
		"item_inventory": [],
		"equipped_items": debug_equipped_items,
		"equipment_inventory": [],
		"equipped_equipment": debug_equipped,
		"collected_equipment": GameData.starter_equipment_ids(),
		"equipment_drop_misses": 0,
		"relics": relics,
		"player_hp": current_hp,
		"player_max_hp": max_hp,
		"hand_size": BASE_HAND_SIZE,
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN,
		"heal_bonus": 0,
		DEFIANCE_CAPACITY_KEY: int(player_snapshot.get(DEFIANCE_CAPACITY_KEY, 0)),
		DEFIANCE_REMAINING_KEY: int(player_snapshot.get(DEFIANCE_REMAINING_KEY, 0)),
		"held_embers": 44,
		"unbanked_embers": 44,
		"combat_state": combat_state,
		"pending_reward": {},
		"pending_escape": {},
		"pending_relics": [],
		"game_over": false,
		"victory": false,
		"turns_spent": 11,
		"run_stats": CombatEngineScript.default_run_stats(),
		"notice": "Debug boss fixture",
		SKILL_STATE_KEY: _default_skill_state(),
		"progression": progression.duplicate(true),
		"debug_boss_run": true
	}
	return GrimoireLibrary.ensure_run_state(run_state)

func repair_loaded_run_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = migrate_renamed_content_ids(run_state) if run_content_migration_required(run_state) else run_state.duplicate(true)
	if next_state.is_empty():
		return next_state
	next_state = migrate_combat_units(next_state)
	next_state = _repair_legacy_merchant_rooms(next_state)
	next_state[RUN_CONTENT_SCHEMA_KEY] = RUN_CONTENT_SCHEMA
	next_state[COMBAT_UNITS_SCHEMA_KEY] = COMBAT_UNITS_SCHEMA
	next_state = GrimoireLibrary.ensure_run_state(next_state)
	next_state["run_stats"] = CombatEngineScript.normalized_run_stats(next_state.get("run_stats", {}))
	next_state[SKILL_STATE_KEY] = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	next_state["progression"] = ProgressionStore.normalized_data(next_state.get("progression", {}) as Dictionary)
	next_state.erase("stats")
	next_state = _sync_defiance_capacity(next_state, false)
	var repaired_combat_state: Dictionary = (next_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if not repaired_combat_state.is_empty():
		repaired_combat_state["skill_ids"] = ProgressionStore.selected_skill_ids(next_state.get("progression", {}) as Dictionary)
		repaired_combat_state.erase("stats")
		repaired_combat_state.erase("card_upgrades")
		repaired_combat_state.erase("card_mods")
		repaired_combat_state = _repair_combat_defiance_state(
			_repair_combat_skill_state(repaired_combat_state),
			defiance_capacity(next_state),
			defiance_remaining(next_state)
		)
		next_state["combat_state"] = repaired_combat_state
		next_state[DEFIANCE_CAPACITY_KEY] = int(repaired_combat_state.get(DEFIANCE_CAPACITY_KEY, defiance_capacity(next_state)))
		next_state[DEFIANCE_REMAINING_KEY] = int(repaired_combat_state.get(DEFIANCE_REMAINING_KEY, defiance_remaining(next_state)))
	next_state = _repair_pending_combat_checkpoints(next_state)
	if not next_state.has("held_embers"):
		next_state["held_embers"] = int(next_state.get("unbanked_embers", 0))
	next_state["unbanked_embers"] = int(next_state.get("held_embers", 0))
	next_state = _repair_equipment_state(next_state)
	next_state = BattlefieldItemRules.repair_loaded_run(next_state)
	next_state = _repair_skill_dependent_state(next_state)
	next_state = _repair_pending_escape(next_state)
	if not next_state.has("equipment_drop_misses"):
		next_state["equipment_drop_misses"] = EQUIPMENT_DROP_PITY_MISSES
	_stage_recovery_marker(next_state)
	var current_coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(next_state, current_coord)
	if str(next_state.get("mode", "room")) not in ["combat", MODE_PRE_BATTLE] or not _room_blocks_exit_reveal(current_room):
		_reveal_neighbors(next_state, current_coord)
		_ensure_loop_escape_connection(next_state, current_coord)
		_sync_current_layout_doors(next_state, current_coord)
	return next_state

func _repair_legacy_merchant_rooms(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var rooms: Dictionary = (next_state.get("rooms", {}) as Dictionary).duplicate(true)
	var current_room: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var current_room_key: String = _room_key(current_room)
	var migrated_current_room: bool = false
	for room_key_var: Variant in rooms.keys():
		if typeof(rooms.get(room_key_var)) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = (rooms.get(room_key_var) as Dictionary).duplicate(true)
		var room_type: String = str(room.get("type", ""))
		var merchant_kind: String = str(room.get("merchant_kind", ""))
		if room_type not in [LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST] and merchant_kind not in [LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
			continue
		room["type"] = MERCHANT_SCAVENGER
		room["merchant_kind"] = MERCHANT_SCAVENGER
		room["npcs"] = [{"id": MERCHANT_SCAVENGER, "pos": Vector2i(3, 4)}]
		rooms[room_key_var] = room
		if str(room_key_var) == current_room_key:
			migrated_current_room = true
	next_state["rooms"] = rooms
	var layout: Dictionary = (next_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	var layout_type: String = str(layout.get("type", ""))
	var layout_merchant_kind: String = str(layout.get("merchant_kind", ""))
	if migrated_current_room or layout_type in [LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST] or layout_merchant_kind in [LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		layout["type"] = MERCHANT_SCAVENGER
		layout["merchant_kind"] = MERCHANT_SCAVENGER
		layout["npcs"] = [{"id": MERCHANT_SCAVENGER, "pos": Vector2i(3, 4)}]
		if layout.has("room_type"):
			layout["room_type"] = MERCHANT_SCAVENGER
		next_state["current_room_layout"] = layout
	var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	var reservation: Dictionary = (skill_state.get("reserved_merchant", {}) as Dictionary).duplicate(true)
	if str(reservation.get("kind", "")) in [LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		reservation["kind"] = MERCHANT_SCAVENGER
		skill_state["reserved_merchant"] = reservation
		next_state[SKILL_STATE_KEY] = skill_state
	return next_state

func _repair_pending_escape(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var mode: String = str(next_state.get("mode", "room"))
	if mode not in ["reward", MODE_ESCAPE]:
		next_state["pending_escape"] = {}
		return next_state
	var escape: Dictionary = pending_escape(next_state)
	var board_state: Dictionary = escape.get("board_state", {}) as Dictionary
	var objective: Dictionary = board_state.get("objective", {}) as Dictionary
	var target_tile_var: Variant = escape.get("target_tile", null)
	if (
		escape.is_empty()
		or board_state.is_empty()
		or str(objective.get("type", "")) != CombatObjectiveRules.REACH_EXIT
		or typeof(target_tile_var) != TYPE_VECTOR2I
	):
		next_state["pending_escape"] = {}
		if mode == MODE_ESCAPE:
			next_state["mode"] = "room"
		return next_state
	var exit_spec: Dictionary = CombatObjectiveRules.exit_spec_for_target(objective, target_tile_var as Vector2i)
	if exit_spec.is_empty() or typeof(exit_spec.get("coord", null)) != TYPE_VECTOR2I:
		next_state["pending_escape"] = {}
		if mode == MODE_ESCAPE:
			next_state["mode"] = "room"
		return next_state
	escape["destination"] = exit_spec.get("coord", Vector2i.ZERO)
	escape["door_tile"] = exit_spec.get("door_tile", Vector2i(-1, -1))
	escape["direction"] = exit_spec.get("direction", Vector2i.ZERO)
	escape["target_tile"] = target_tile_var
	escape["board_state"] = board_state
	next_state["pending_escape"] = escape
	return next_state

static func run_content_migration_required(run_state: Dictionary) -> bool:
	return int(run_state.get(RUN_CONTENT_SCHEMA_KEY, 0)) < RUN_CONTENT_SCHEMA

static func combat_units_migration_required(run_state: Dictionary) -> bool:
	return int(run_state.get(COMBAT_UNITS_SCHEMA_KEY, 0)) < COMBAT_UNITS_SCHEMA

static func migrate_combat_units(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if next_state.is_empty() or not combat_units_migration_required(next_state):
		return next_state
	var classification: String = _legacy_combat_unit_classification(next_state)
	if classification == "legacy_fixed_10x":
		next_state = _migrated_legacy_fixed_point_run(next_state)
	elif classification == "conflict":
		push_warning("Conflicting legacy combat-unit evidence; preserving serialized values rather than risking destructive conversion.")
	next_state[COMBAT_UNITS_SCHEMA_KEY] = COMBAT_UNITS_SCHEMA
	return next_state

static func _legacy_combat_unit_classification(run_state: Dictionary) -> String:
	# Content schema 2 shipped entirely inside the former x10 unit era.
	if int(run_state.get(RUN_CONTENT_SCHEMA_KEY, 0)) >= 2:
		return "legacy_fixed_10x"
	var natural_evidence: bool = false
	var fixed_evidence: bool = false
	var outer_max_hp: int = int(run_state.get("player_max_hp", 0))
	if outer_max_hp > 0:
		fixed_evidence = outer_max_hp >= 100
		natural_evidence = outer_max_hp < 100
	var combat_state: Dictionary = run_state.get("combat_state", {}) as Dictionary
	var combat_player: Dictionary = combat_state.get("player", {}) as Dictionary
	var combat_max_hp: int = int(combat_player.get("max_hp", 0))
	if combat_max_hp > 0:
		fixed_evidence = fixed_evidence or combat_max_hp >= 100
		natural_evidence = natural_evidence or combat_max_hp < 100
	if fixed_evidence and natural_evidence:
		return "conflict"
	if fixed_evidence:
		return "legacy_fixed_10x"
	return "natural"

static func _migrated_legacy_fixed_point_run(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	for field: String in ["player_hp", "player_max_hp", "heal_bonus"]:
		if next_state.has(field):
			next_state[field] = _legacy_survivor_units(int(next_state.get(field, 0)))
	if next_state.has("run_stats"):
		next_state["run_stats"] = _migrated_legacy_run_stats(next_state.get("run_stats", {}))
	if typeof(next_state.get("pending_reward", null)) == TYPE_DICTIONARY:
		var pending_reward: Dictionary = (next_state.get("pending_reward", {}) as Dictionary).duplicate(true)
		if pending_reward.has("heal_amount"):
			pending_reward["heal_amount"] = _legacy_survivor_units(int(pending_reward.get("heal_amount", 0)))
		if typeof(pending_reward.get("board_state", null)) == TYPE_DICTIONARY:
			pending_reward["board_state"] = _migrated_legacy_combat_state_units(
				pending_reward.get("board_state", {}) as Dictionary
			)
		next_state["pending_reward"] = pending_reward
	if typeof(next_state.get("current_room_layout", null)) == TYPE_DICTIONARY:
		next_state["current_room_layout"] = _migrated_legacy_combat_state_units(
			next_state.get("current_room_layout", {}) as Dictionary
		)
	if typeof(next_state.get("combat_state", null)) == TYPE_DICTIONARY:
		next_state["combat_state"] = _migrated_legacy_combat_state_units(
			next_state.get("combat_state", {}) as Dictionary
		)
	if typeof(next_state.get("pending_escape", null)) == TYPE_DICTIONARY:
		var pending_escape: Dictionary = (next_state.get("pending_escape", {}) as Dictionary).duplicate(true)
		if typeof(pending_escape.get("board_state", null)) == TYPE_DICTIONARY:
			pending_escape["board_state"] = _migrated_legacy_combat_state_units(
				pending_escape.get("board_state", {}) as Dictionary
			)
		next_state["pending_escape"] = pending_escape
	if typeof(next_state.get(COMBAT_CONTINUATION_KEY, null)) == TYPE_ARRAY:
		var checkpoints: Array = []
		for checkpoint_var: Variant in next_state.get(COMBAT_CONTINUATION_KEY, []) as Array:
			if typeof(checkpoint_var) != TYPE_DICTIONARY:
				continue
			var checkpoint: Dictionary = (checkpoint_var as Dictionary).duplicate(true)
			if typeof(checkpoint.get("state", null)) == TYPE_DICTIONARY:
				checkpoint["state"] = _migrated_legacy_combat_state_units(checkpoint.get("state", {}) as Dictionary)
			checkpoints.append(checkpoint)
		next_state[COMBAT_CONTINUATION_KEY] = checkpoints
	return next_state

static func _migrated_legacy_combat_state_units(combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = combat_state.duplicate(true)
	if typeof(next_state.get("player", null)) == TYPE_DICTIONARY:
		next_state["player"] = _migrated_legacy_unit(next_state.get("player", {}) as Dictionary)
	for collection_key: String in ["enemies", "illusions", "terrain"]:
		if typeof(next_state.get(collection_key, null)) != TYPE_ARRAY:
			continue
		var migrated_units: Array = []
		for unit_var: Variant in next_state.get(collection_key, []) as Array:
			if typeof(unit_var) == TYPE_DICTIONARY:
				migrated_units.append(_migrated_legacy_unit(unit_var as Dictionary))
		next_state[collection_key] = migrated_units
	if typeof(next_state.get("traps", null)) == TYPE_ARRAY:
		var traps: Array = []
		for trap_var: Variant in next_state.get("traps", []) as Array:
			if typeof(trap_var) != TYPE_DICTIONARY:
				continue
			var trap: Dictionary = (trap_var as Dictionary).duplicate(true)
			for field: String in ["damage", "base_damage", "burn", "bleed", "poison"]:
				if trap.has(field):
					trap[field] = _legacy_survivor_units(int(trap.get(field, 0)))
			traps.append(trap)
		next_state["traps"] = traps
	if typeof(next_state.get("loot", null)) == TYPE_ARRAY:
		var loot_entries: Array = []
		for loot_var: Variant in next_state.get("loot", []) as Array:
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = (loot_var as Dictionary).duplicate(true)
			if str(loot.get("kind", "")) in ["healing_vial", "rusty_shield"] and loot.has("amount"):
				loot["amount"] = _legacy_survivor_units(int(loot.get("amount", 0)))
			loot_entries.append(loot)
		next_state["loot"] = loot_entries
	if typeof(next_state.get("deck", null)) == TYPE_DICTIONARY:
		var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
		if deck.has("fatigue_base"):
			deck["fatigue_base"] = _legacy_survivor_units(int(deck.get("fatigue_base", 0)))
		next_state["deck"] = deck
	if next_state.has("heal_bonus"):
		next_state["heal_bonus"] = _legacy_survivor_units(int(next_state.get("heal_bonus", 0)))
	if next_state.has("run_stats"):
		next_state["run_stats"] = _migrated_legacy_run_stats(next_state.get("run_stats", {}))
	if typeof(next_state.get("umbra", null)) == TYPE_DICTIONARY:
		var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
		if umbra.has("hidden_attack_damage_received_total"):
			umbra["hidden_attack_damage_received_total"] = _legacy_cumulative_units(
				int(umbra.get("hidden_attack_damage_received_total", 0))
			)
		next_state["umbra"] = umbra
	var migrated_actions: Variant = _migrated_legacy_action_tree(next_state)
	return migrated_actions as Dictionary if typeof(migrated_actions) == TYPE_DICTIONARY else next_state

static func _migrated_legacy_unit(unit: Dictionary) -> Dictionary:
	var next_unit: Dictionary = unit.duplicate(true)
	for field: String in ["hp", "max_hp", "block", "stoneskin", "burn", "bleed", "expose", "sunder"]:
		if next_unit.has(field):
			next_unit[field] = _legacy_survivor_units(int(next_unit.get(field, 0)))
	if typeof(next_unit.get("poison", null)) == TYPE_DICTIONARY:
		var poison: Dictionary = (next_unit.get("poison", {}) as Dictionary).duplicate(true)
		for field: String in ["damage", "trigger"]:
			if poison.has(field):
				poison[field] = _legacy_survivor_units(int(poison.get(field, 0)))
		next_unit["poison"] = poison
	return next_unit

static func _migrated_legacy_action_tree(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value as Dictionary
			var migrated: Dictionary = source.duplicate(false)
			for key: Variant in source.keys():
				migrated[key] = _migrated_legacy_action_tree(source.get(key))
			var action_type: String = str(source.get("type", ""))
			if not action_type.is_empty():
				for field: String in ["damage", "self_damage", "burn", "bleed", "expose", "sunder", "poison", "amount", "health"]:
					if migrated.has(field) and GameData.action_field_uses_fixed_point(action_type, field):
						migrated[field] = _legacy_survivor_units(int(migrated.get(field, 0)))
				if typeof(migrated.get("intensity_bonus", null)) == TYPE_DICTIONARY:
					var bonus: Dictionary = (migrated.get("intensity_bonus", {}) as Dictionary).duplicate(true)
					for field: String in ["damage", "self_damage", "burn", "bleed", "expose", "sunder", "poison", "amount", "health"]:
						if bonus.has(field) and GameData.action_field_uses_fixed_point(action_type, field):
							bonus[field] = _legacy_survivor_units(int(bonus.get(field, 0)))
					migrated["intensity_bonus"] = bonus
			if migrated.has("health_cost"):
				migrated["health_cost"] = _legacy_survivor_units(int(migrated.get("health_cost", 0)))
			return migrated
		TYPE_ARRAY:
			var source_array: Array = value as Array
			var migrated_array: Array = source_array.duplicate(false)
			for index: int in range(source_array.size()):
				migrated_array[index] = _migrated_legacy_action_tree(source_array[index])
			return migrated_array
		_:
			return value

static func _migrated_legacy_run_stats(value: Variant) -> Dictionary:
	var stats: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	var migrated: Dictionary = stats.duplicate(true)
	for field: String in ["damage_dealt", "damage_received"]:
		if migrated.has(field):
			migrated[field] = _legacy_cumulative_units(int(migrated.get(field, 0)))
	return migrated

static func _legacy_survivor_units(value: int) -> int:
	if value <= 0:
		return 0
	return int((value + GameData.LEGACY_FIXED_POINT_SCALE - 1) / GameData.LEGACY_FIXED_POINT_SCALE)

static func _legacy_cumulative_units(value: int) -> int:
	if value <= 0:
		return 0
	return int((value + int(GameData.LEGACY_FIXED_POINT_SCALE / 2)) / GameData.LEGACY_FIXED_POINT_SCALE)

static func migrate_renamed_content_ids(run_state: Dictionary) -> Dictionary:
	# Serialized runs can hold content ids in loadouts, rewards, combat piles,
	# merchant stock, analytics context, and nested intent state. Walk the whole
	# Variant graph so a resumed run cannot retain a retired vocabulary-era id.
	var neutralizer := RegEx.new()
	var legacy_prefix: String = _string_from_bytes([97, 115, 104])
	if neutralizer.compile("(?i)(?<![[:alnum:]])%s[[:alnum:]_-]*" % legacy_prefix) != OK:
		return run_state.duplicate(true)
	var replacements: Dictionary = _renamed_content_id_map()
	var composite_ids: Array = []
	for id_var: Variant in replacements.keys():
		var content_id: String = str(id_var)
		if content_id != legacy_prefix:
			composite_ids.append(content_id)
	composite_ids.sort_custom(func(left: String, right: String) -> bool: return left.length() > right.length())
	var migrated: Variant = _replace_renamed_content_ids(
		run_state,
		replacements,
		composite_ids,
		neutralizer
	)
	return migrated as Dictionary if typeof(migrated) == TYPE_DICTIONARY else {}

static func _renamed_content_id_map() -> Dictionary:
	return {
		_string_from_bytes([97, 115, 104, 108, 105, 110, 101, 95, 116, 101, 109, 112, 111]): "cinderline_tempo",
		_string_from_bytes([97, 115, 104, 119, 101, 97, 118, 101, 95, 103, 117, 97, 114, 100]): "cinderweave_guard",
		_string_from_bytes([97, 115, 104, 119, 101, 97, 118, 101, 95, 109, 97, 105, 108]): "cinderweave_mail",
		_string_from_bytes([97, 115, 104, 101, 110, 95, 98, 117, 99, 107, 108, 101, 114]): "iron_buckler",
		_string_from_bytes([97, 115, 104, 95, 98, 111, 108, 116]): "dust_bolt",
		_string_from_bytes([97, 115, 104, 102, 97, 108, 108]): "cinderfall",
		_string_from_bytes([97, 115, 104]): "stone",
	}

static func _string_from_bytes(values: Array) -> String:
	var bytes := PackedByteArray()
	for value: Variant in values:
		bytes.append(int(value))
	return bytes.get_string_from_ascii()

static func _replace_renamed_content_ids(value: Variant, replacements: Dictionary, composite_ids: Array, neutralizer: RegEx) -> Variant:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = str(value)
			if replacements.has(text):
				return str(replacements.get(text, text))
			for content_id_var: Variant in composite_ids:
				var content_id: String = str(content_id_var)
				text = text.replace(content_id, str(replacements.get(content_id, content_id)))
			return neutralizer.sub(text, "cinder", true)
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value as Dictionary
			var migrated_dictionary: Dictionary = source_dictionary.duplicate(false)
			for key: Variant in source_dictionary.keys():
				var migrated_key: Variant = _replace_renamed_content_ids(key, replacements, composite_ids, neutralizer)
				var migrated_value: Variant = _replace_renamed_content_ids(source_dictionary.get(key), replacements, composite_ids, neutralizer)
				if migrated_key != key:
					migrated_dictionary.erase(key)
				migrated_dictionary[migrated_key] = migrated_value
			return migrated_dictionary
		TYPE_ARRAY:
			var migrated_array: Array = (value as Array).duplicate(false)
			for index: int in range(migrated_array.size()):
				migrated_array[index] = _replace_renamed_content_ids(migrated_array[index], replacements, composite_ids, neutralizer)
			return migrated_array
		TYPE_PACKED_STRING_ARRAY:
			var migrated_strings: PackedStringArray = value
			for index: int in range(migrated_strings.size()):
				migrated_strings[index] = str(_replace_renamed_content_ids(migrated_strings[index], replacements, composite_ids, neutralizer))
			return migrated_strings
	return value

static func _default_skill_state() -> Dictionary:
	return {
		"used_by_sequence": {},
		"events": [],
		"event_revision": 0,
		"pending_card": "",
		"pending_relic": "",
		"reserved_merchant": {},
		"previous_room": Vector2i.ZERO,
		"moltshard_awarded": false
	}

static func _normalized_skill_state(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	var result: Dictionary = _default_skill_state()
	result["used_by_sequence"] = (source.get("used_by_sequence", {}) as Dictionary).duplicate(true) if typeof(source.get("used_by_sequence", {})) == TYPE_DICTIONARY else {}
	var events: Array = []
	var highest_revision: int = maxi(0, int(source.get("event_revision", 0)))
	if typeof(source.get("events", [])) == TYPE_ARRAY:
		for event_var: Variant in source.get("events", []):
			if typeof(event_var) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = (event_var as Dictionary).duplicate(true)
			var revision: int = maxi(0, int(event.get("revision", 0)))
			if revision <= 0 or str(event.get("skill_id", "")).is_empty():
				continue
			event["revision"] = revision
			events.append(event)
			highest_revision = maxi(highest_revision, revision)
	if events.size() > RUN_SKILL_EVENT_LIMIT:
		events = events.slice(events.size() - RUN_SKILL_EVENT_LIMIT)
	result["events"] = events
	result["event_revision"] = highest_revision
	result["pending_card"] = str(source.get("pending_card", ""))
	result["pending_relic"] = str(source.get("pending_relic", ""))
	result["reserved_merchant"] = (source.get("reserved_merchant", {}) as Dictionary).duplicate(true) if typeof(source.get("reserved_merchant", {})) == TYPE_DICTIONARY else {}
	var previous_room_value: Variant = source.get("previous_room", Vector2i.ZERO)
	result["previous_room"] = previous_room_value if typeof(previous_room_value) == TYPE_VECTOR2I else Vector2i.ZERO
	result["moltshard_awarded"] = bool(source.get("moltshard_awarded", false))
	return result

func run_skill_ids(run_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for skill_id: String in SkillTreeLibrary.normalized_ids((run_state.get("progression", {}) as Dictionary).get("skill_ids", [])):
		if not SkillTreeLibrary.is_retired(skill_id):
			result.append(skill_id)
	return result

func has_run_skill(run_state: Dictionary, skill_id: String) -> bool:
	return run_skill_ids(run_state).has(skill_id)

func _sequence_index_for_run_state(run_state: Dictionary) -> int:
	var room: Dictionary = room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var depth: int = maxi(1, int(room.get("depth", _room_depth(run_state.get("current_room", Vector2i.ZERO)))))
	return maxi(0, int((depth - 1) / DEPTHS_PER_SEQUENCE))

func _skill_sequence_key(run_state: Dictionary, skill_id: String) -> String:
	return "%d:%s" % [_sequence_index_for_run_state(run_state), skill_id]

func run_skill_used_this_sequence(run_state: Dictionary, skill_id: String) -> bool:
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	return bool((skill_state.get("used_by_sequence", {}) as Dictionary).get(_skill_sequence_key(run_state, skill_id), false))

func _mark_run_skill_used(run_state: Dictionary, skill_id: String, message: String = "") -> void:
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	var used: Dictionary = (skill_state.get("used_by_sequence", {}) as Dictionary).duplicate(true)
	var sequence_key: String = _skill_sequence_key(run_state, skill_id)
	if bool(used.get(sequence_key, false)):
		run_state[SKILL_STATE_KEY] = skill_state
		return
	used[sequence_key] = true
	skill_state["used_by_sequence"] = used
	run_state[SKILL_STATE_KEY] = skill_state
	_record_run_skill_event(run_state, skill_id, message)

func _record_run_skill_event(run_state: Dictionary, skill_id: String, message: String = "") -> void:
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	var revision: int = int(skill_state.get("event_revision", 0)) + 1
	var events: Array = (skill_state.get("events", []) as Array).duplicate(true)
	events.append({
		"revision": revision,
		"skill_id": skill_id,
		"message": message if not message.is_empty() else "%s takes effect." % SkillTreeLibrary.display_name(skill_id)
	})
	if events.size() > RUN_SKILL_EVENT_LIMIT:
		events = events.slice(events.size() - RUN_SKILL_EVENT_LIMIT)
	skill_state["events"] = events
	skill_state["event_revision"] = revision
	run_state[SKILL_STATE_KEY] = skill_state

func run_skill_events(run_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	for event_var: Variant in skill_state.get("events", []):
		if typeof(event_var) == TYPE_DICTIONARY:
			result.append((event_var as Dictionary).duplicate(true))
	return result

func run_skill_event_revision(run_state: Dictionary) -> int:
	return int(_normalized_skill_state(run_state.get(SKILL_STATE_KEY, {})).get("event_revision", 0))

func run_skill_is_ready(run_state: Dictionary, skill_id: String) -> bool:
	if skill_id == "layaway":
		var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
		if not (skill_state.get("reserved_merchant", {}) as Dictionary).is_empty():
			return false
	return has_run_skill(run_state, skill_id) and not run_skill_used_this_sequence(run_state, skill_id)

func available_moves(run_state: Dictionary) -> Array[Vector2i]:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(run_state, current)
	var current_depth: int = int(current_room.get("depth", 0))
	var cleared_intermediate_boss: bool = (
		str(current_room.get("type", "")) == "boss"
		and bool(current_room.get("cleared", false))
		and not _is_final_boss_depth(current_depth)
	)
	var neighbors: Array[Vector2i] = []
	var seen: Dictionary = {}
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if cleared_intermediate_boss and str(connection.get("kind", "")) != "outward":
			continue
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		if seen.has(candidate):
			continue
		var candidate_room: Dictionary = room_metadata(run_state, candidate)
		if not bool(candidate_room.get("revealed", false)):
			continue
		if int(candidate_room.get("depth", 0)) < current_depth:
			continue
		if bool(candidate_room.get("sealed", false)):
			continue
		seen[candidate] = true
		neighbors.append(candidate)
	return neighbors

func room_metadata(run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {})
	var key: String = _room_key(coord)
	if rooms.has(key):
		return _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms[key] as Dictionary)
	return _build_room_metadata(int(run_state.get("seed", 0)), coord)

func move_to_room(run_state: Dictionary, destination: Vector2i) -> Dictionary:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if destination == current:
		return run_state.duplicate(true)
	if not available_moves(run_state).has(destination):
		return run_state.duplicate(true)
	var current_room_before_move: Dictionary = room_metadata(run_state, current)
	var connection: Dictionary = _connection_to_room(current_room_before_move, destination)
	if connection.is_empty():
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["pending_escape"] = {}
	var move_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	move_skill_state["previous_room"] = current
	next_state[SKILL_STATE_KEY] = move_skill_state
	_clear_pre_battle_state(next_state)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var destination_key: String = _room_key(destination)
	var current_key: String = _room_key(current)
	var current_room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), current, rooms.get(current_key, {}) as Dictionary)
	current_room["sealed"] = true
	rooms[current_key] = current_room
	var room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	rooms[destination_key] = room
	next_state["current_room"] = destination
	next_state["turns_spent"] = int(next_state.get("turns_spent", 0)) + 1
	next_state["notice"] = ""
	next_state["rooms"] = rooms
	var reveal_exits_on_entry: bool = not _room_blocks_exit_reveal(room)
	if reveal_exits_on_entry:
		_reveal_neighbors(next_state, destination)
		_ensure_loop_escape_connection(next_state, destination)
	rooms = next_state.get("rooms", {}).duplicate(true)
	room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var merchant_kind: String = merchant_kind_for_room(room)
	if not merchant_kind.is_empty():
		room = _merchant_room_with_stock(next_state, room, merchant_kind)
		rooms[destination_key] = room
		next_state["rooms"] = rooms
		next_state = _inject_reserved_merchant_offer(next_state, destination, merchant_kind)
		rooms = next_state.get("rooms", {}).duplicate(true)
		room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var travel_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
	next_state["current_room_layout"] = _display_layout_for_room(int(next_state.get("seed", 0)), room, travel_dir)
	_stage_recovery_marker(next_state)
	match str(room.get("type", "combat")):
		"start":
			next_state["mode"] = "room"
			next_state["combat_state"] = {}
		"campfire":
			room["cleared"] = true
			rooms[destination_key] = room
			next_state["rooms"] = rooms
			next_state["mode"] = "campfire"
			next_state["combat_state"] = {}
		"treasure":
			if bool(room.get("cleared", false)):
				next_state["pending_relics"] = []
				next_state["mode"] = "room"
			else:
				room["cleared"] = true
				rooms[destination_key] = room
				next_state["rooms"] = rooms
				var relic_choices: Array[String] = _generate_relic_choices(next_state, destination)
				var pending_relic: String = str((_normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))).get("pending_relic", ""))
				if not pending_relic.is_empty():
					if not (next_state.get("relics", []) as Array).has(pending_relic) and not GameData.relic_def(pending_relic).is_empty():
						relic_choices = _offer_with_deferred_id(relic_choices, pending_relic)
					var relic_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
					relic_skill_state["pending_relic"] = ""
					next_state[SKILL_STATE_KEY] = relic_skill_state
				next_state["pending_relics"] = relic_choices
				next_state["mode"] = "treasure" if not relic_choices.is_empty() else "room"
			next_state["combat_state"] = {}
		_:
			if _room_has_npcs(room):
				room["cleared"] = true
				rooms[destination_key] = room
				next_state["rooms"] = rooms
				next_state["mode"] = "room"
				next_state["combat_state"] = {}
				return next_state
			if bool(room.get("cleared", false)):
				next_state["mode"] = "room"
				next_state["combat_state"] = {}
				return next_state
			var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
			if _equipment_drop_can_attempt(next_state, room):
				next_state = _record_equipment_drop_attempt(next_state, layout)
			var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
			next_state["combat_state"] = combat_state
			next_state["mode"] = "combat"
	return next_state

func move_to_pre_battle(run_state: Dictionary, destination: Vector2i) -> Dictionary:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if destination == current:
		return run_state.duplicate(true)
	if not available_moves(run_state).has(destination):
		return run_state.duplicate(true)
	var current_room_before_move: Dictionary = room_metadata(run_state, current)
	var connection: Dictionary = _connection_to_room(current_room_before_move, destination)
	if connection.is_empty():
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["pending_escape"] = {}
	var move_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	move_skill_state["previous_room"] = current
	next_state[SKILL_STATE_KEY] = move_skill_state
	_clear_pre_battle_state(next_state)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var destination_key: String = _room_key(destination)
	var current_key: String = _room_key(current)
	var current_room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), current, rooms.get(current_key, {}) as Dictionary)
	current_room["sealed"] = true
	rooms[current_key] = current_room
	var room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	rooms[destination_key] = room
	next_state["current_room"] = destination
	next_state["turns_spent"] = int(next_state.get("turns_spent", 0)) + 1
	next_state["notice"] = ""
	next_state["rooms"] = rooms
	var reveal_exits_on_entry: bool = not _room_blocks_exit_reveal(room)
	if reveal_exits_on_entry:
		_reveal_neighbors(next_state, destination)
		_ensure_loop_escape_connection(next_state, destination)
	rooms = next_state.get("rooms", {}).duplicate(true)
	room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var merchant_kind: String = merchant_kind_for_room(room)
	if not merchant_kind.is_empty():
		room = _merchant_room_with_stock(next_state, room, merchant_kind)
		rooms[destination_key] = room
		next_state["rooms"] = rooms
	var travel_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
	next_state["current_room_layout"] = _display_layout_for_room(int(next_state.get("seed", 0)), room, travel_dir)
	_stage_recovery_marker(next_state)
	if str(room.get("type", "combat")) not in ["combat", "boss"] or bool(room.get("cleared", false)) or _room_has_npcs(room):
		return move_to_room(run_state, destination)
	next_state["mode"] = MODE_PRE_BATTLE
	next_state["combat_state"] = {}
	next_state["pre_battle_pending"] = true
	next_state["pre_battle_travel_dir"] = travel_dir
	return next_state

func pre_battle_preview_state(run_state: Dictionary) -> Dictionary:
	if str(run_state.get("mode", "room")) != MODE_PRE_BATTLE:
		return {}
	var next_state: Dictionary = run_state.duplicate(true)
	var room: Dictionary = room_metadata(next_state, next_state.get("current_room", Vector2i.ZERO))
	if not _room_blocks_exit_reveal(room):
		return {}
	var travel_dir: Vector2i = next_state.get("pre_battle_travel_dir", Vector2i.ZERO)
	var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
	var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
	next_state["combat_state"] = combat_state
	next_state["mode"] = "combat"
	return next_state

func pre_battle_start_tiles(run_state: Dictionary) -> Array[Vector2i]:
	var choices: Array[Vector2i]
	if str(run_state.get("mode", "room")) != MODE_PRE_BATTLE or not has_run_skill(run_state, "true_bearing"):
		return choices
	var room: Dictionary = room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	if not _room_blocks_exit_reveal(room):
		return choices
	var travel_dir: Vector2i = run_state.get("pre_battle_travel_dir", Vector2i.ZERO)
	var preview_state: Dictionary = run_state.duplicate(true)
	preview_state.erase("pre_battle_start")
	var layout: Dictionary = _combat_layout_for_room(room, travel_dir, preview_state)
	var grid: Array = layout.get("grid", [])
	var authored_start: Vector2i = layout.get("player_start", Vector2i(-1, -1))
	if authored_start.x < 0:
		return choices
	var occupied: Dictionary = _layout_occupied_tiles(layout)
	occupied.erase(authored_start)
	var max_range: int = maxi(0, int(SkillTreeLibrary.effect("true_bearing").get("range", 2)))
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			if absi(tile.x - authored_start.x) + absi(tile.y - authored_start.y) > max_range:
				continue
			if occupied.has(tile) or not PathUtils.is_passable(grid, tile):
				continue
			choices.append(tile)
	choices.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		var left_distance: int = absi(left.x - authored_start.x) + absi(left.y - authored_start.y)
		var right_distance: int = absi(right.x - authored_start.x) + absi(right.y - authored_start.y)
		if left_distance != right_distance:
			return left_distance < right_distance
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x
	)
	return choices

func set_pre_battle_start(run_state: Dictionary, tile: Vector2i) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if not pre_battle_start_tiles(next_state).has(tile):
		return next_state
	if typeof(next_state.get("pre_battle_start", null)) == TYPE_VECTOR2I and next_state.get("pre_battle_start") == tile:
		return next_state
	next_state["pre_battle_start"] = tile
	_record_run_skill_event(next_state, "true_bearing", "Chose a different combat entry tile.")
	return next_state

func begin_pre_battle_combat(run_state: Dictionary) -> Dictionary:
	if str(run_state.get("mode", "room")) != MODE_PRE_BATTLE:
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	var room: Dictionary = room_metadata(next_state, next_state.get("current_room", Vector2i.ZERO))
	if not _room_blocks_exit_reveal(room):
		return next_state
	var travel_dir: Vector2i = next_state.get("pre_battle_travel_dir", Vector2i.ZERO)
	var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
	if _equipment_drop_can_attempt(next_state, room):
		next_state = _record_equipment_drop_attempt(next_state, layout)
	var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
	next_state["combat_state"] = combat_state
	next_state["mode"] = "combat"
	_clear_pre_battle_state(next_state)
	return next_state

func set_combat_state(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["combat_state"] = combat_state.duplicate(true)
	next_state["run_stats"] = CombatEngineScript.normalized_run_stats(combat_state.get("run_stats", next_state.get("run_stats", {})))
	next_state["player_hp"] = int((combat_state.get("player", {}) as Dictionary).get("hp", next_state.get("player_hp", 1)))
	next_state[DEFIANCE_CAPACITY_KEY] = maxi(0, int(combat_state.get(DEFIANCE_CAPACITY_KEY, next_state.get(DEFIANCE_CAPACITY_KEY, 0))))
	next_state[DEFIANCE_REMAINING_KEY] = clampi(
		int(combat_state.get(DEFIANCE_REMAINING_KEY, next_state.get(DEFIANCE_REMAINING_KEY, 0))),
		0,
		int(next_state.get(DEFIANCE_CAPACITY_KEY, 0))
	)
	next_state = _apply_recovered_embers_from_combat(next_state, combat_state)
	next_state = _apply_collected_equipment_from_combat(next_state, combat_state)
	# Combat owns pickup/consumption transactions, including duplicate copies.
	# Copying the snapshot is idempotent across checkpoints, finish and reload.
	if combat_state.has("equipped_items"):
		next_state["equipped_items"] = _item_card_array(combat_state.get("equipped_items", []))
		next_state["item_inventory"] = _item_card_array(combat_state.get("item_inventory", []))
		next_state = _rebuild_deck_cards(next_state)
		for loot: Dictionary in BattlefieldItemRules.pickups_between(run_state.get("combat_state", {}), combat_state):
			var card_id: String = str(loot.get("card_id", ""))
			if next_state["equipped_items"].has(card_id) or next_state["item_inventory"].has(card_id):
				next_state = _mark_loadout_unread(next_state, "equipment", card_id)
	return next_state

func finish_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var outcome: String = _combat_engine.combat_outcome(combat_state)
	var pending_escape: Dictionary = _pending_escape_for_combat_victory(combat_state, outcome)
	var resolved_combat_state: Dictionary = combat_state.duplicate(true)
	if outcome == "victory":
		resolved_combat_state = _combat_engine.post_combat_board_state(resolved_combat_state)
		resolved_combat_state = _combat_engine.resolve_missed_equipment_after_victory(resolved_combat_state)
	var salvaged_equipment_id: String = ""
	if outcome == "victory" and run_skill_is_ready(run_state, "salvager"):
		var missed_before_salvage: Array = resolved_combat_state.get("missed_equipment", []).duplicate()
		if not missed_before_salvage.is_empty():
			salvaged_equipment_id = str(missed_before_salvage[0])
			missed_before_salvage.remove_at(0)
			resolved_combat_state["missed_equipment"] = missed_before_salvage
			var collected_after_salvage: Array = resolved_combat_state.get("collected_equipment", []).duplicate()
			if not salvaged_equipment_id.is_empty() and not collected_after_salvage.has(salvaged_equipment_id):
				collected_after_salvage.append(salvaged_equipment_id)
			resolved_combat_state["collected_equipment"] = collected_after_salvage
			resolved_combat_state = _mark_salvaged_loot_resolution(resolved_combat_state, salvaged_equipment_id)
	if not pending_escape.is_empty():
		# Reward and escape continuation must hold the same final board pixels.
		# Reach Exit keeps living pursuers; only loot-resolution metadata changes.
		pending_escape["board_state"] = resolved_combat_state.duplicate(true)
	var missed_equipment: Array = resolved_combat_state.get("missed_equipment", []) as Array
	var next_state: Dictionary = set_combat_state(run_state, resolved_combat_state)
	next_state["pending_escape"] = pending_escape
	if not salvaged_equipment_id.is_empty():
		var salvaged_name: String = str(GameData.equipment_def(salvaged_equipment_id).get("name", salvaged_equipment_id))
		_mark_run_skill_used(next_state, "salvager", "Salvager recovers %s before it is lost." % salvaged_name)
	next_state["current_room_layout"] = _room_layout_from_combat_state(resolved_combat_state)
	next_state["combat_state"] = {}
	next_state["player_hp"] = int((resolved_combat_state.get("player", {}) as Dictionary).get("hp", next_state.get("player_hp", 1)))
	if outcome == "defeat":
		if _can_last_door_retreat(next_state):
			return _retreat_through_last_door(next_state)
		next_state["mode"] = "defeat"
		next_state["game_over"] = true
		return next_state
	if outcome != "victory":
		next_state["mode"] = "combat"
		next_state["combat_state"] = combat_state.duplicate(true)
		return next_state
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var current_room: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room_key: String = _room_key(current_room)
	var room: Dictionary = (rooms.get(room_key, {}) as Dictionary).duplicate(true)
	room["cleared"] = true
	rooms[room_key] = room
	next_state["rooms"] = rooms
	_reveal_neighbors(next_state, current_room)
	_ensure_loop_escape_connection(next_state, current_room)
	_sync_current_layout_doors(next_state, current_room)
	var ember_bonus: int = GameData.stat_bonus_from_relics(next_state.get("relics", []), "combat_ember_bonus")
	var total_embers: int = int(combat_state.get("room_embers", 0)) + ember_bonus
	next_state = add_held_embers(next_state, total_embers)
	if str(room.get("type", "")) == "boss":
		var boss_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
		var awarded_moltshard: bool = false
		if not bool(boss_skill_state.get("moltshard_awarded", false)):
			var progression_before_award: Dictionary = next_state.get("progression", {}) as Dictionary
			var award_id: String = "%s:first_boss_moltshard" % run_result_id(next_state)
			var progression_after_award: Dictionary = ProgressionStore.add_moltshard_for_award(progression_before_award, award_id)
			awarded_moltshard = ProgressionStore.moltshard_count(progression_after_award) > ProgressionStore.moltshard_count(progression_before_award)
			next_state["progression"] = progression_after_award
			boss_skill_state["moltshard_awarded"] = true
			next_state[SKILL_STATE_KEY] = boss_skill_state
		var boss_max_hp: int = maxi(1, int(next_state.get("player_max_hp", 1)))
		var boss_heal: int = ceili(float(boss_max_hp) * BOSS_VICTORY_HEAL_FRACTION)
		next_state["player_hp"] = mini(
			boss_max_hp,
			int(next_state.get("player_hp", 1)) + boss_heal
		)
		next_state = add_held_embers(next_state, BOSS_VICTORY_EMBERS)
		next_state["pending_reward"] = {}
		if _is_final_boss_depth(int(room.get("depth", _room_depth(current_room)))) or bool(next_state.get("debug_boss_run", false)):
			next_state["victory"] = true
			next_state["mode"] = "victory"
			if awarded_moltshard:
				next_state["notice"] = "Moltshard acquired."
		else:
			next_state["victory"] = false
			next_state["mode"] = "room"
			next_state["notice"] = (
				"Moltshard acquired. The labyrinth opens outward."
				if awarded_moltshard
				else "The labyrinth opens outward."
			)
		if not missed_equipment.is_empty():
			var boss_notice: String = str(next_state.get("notice", ""))
			next_state["notice"] = "%s\n%s" % [boss_notice, MISSED_EQUIPMENT_NOTICE] if not boss_notice.is_empty() else MISSED_EQUIPMENT_NOTICE
		return next_state
	var reward_cards: Array[String] = _generate_card_rewards(next_state, current_room)
	var reward_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	var pending_card: String = str(reward_skill_state.get("pending_card", ""))
	if not pending_card.is_empty():
		if not GameData.card_def(pending_card).is_empty():
			reward_cards = _offer_with_deferred_id(reward_cards, pending_card)
		reward_skill_state["pending_card"] = ""
		next_state[SKILL_STATE_KEY] = reward_skill_state
	next_state["pending_reward"] = {
		"cards": reward_cards,
		"heal_amount": REWARD_HEAL + int(next_state.get("heal_bonus", 0)),
		"ember_amount": total_embers,
		"board_state": resolved_combat_state.duplicate(true),
		"intro_pending": true
	}
	next_state["mode"] = "reward"
	if not missed_equipment.is_empty():
		next_state["notice"] = ESCAPE_MISSED_EQUIPMENT_NOTICE if not pending_escape.is_empty() else MISSED_EQUIPMENT_NOTICE
	return next_state

func _pending_escape_for_combat_victory(combat_state: Dictionary, outcome: String) -> Dictionary:
	if outcome != "victory":
		return {}
	var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
	if str(objective.get("type", "")) != CombatObjectiveRules.REACH_EXIT:
		return {}
	var player_tile: Vector2i = (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
	var exit_spec: Dictionary = CombatObjectiveRules.exit_spec_for_target(objective, player_tile)
	if exit_spec.is_empty() or typeof(exit_spec.get("coord", null)) != TYPE_VECTOR2I:
		return {}
	return {
		"destination": exit_spec.get("coord", Vector2i.ZERO),
		"door_tile": exit_spec.get("door_tile", Vector2i(-1, -1)),
		"target_tile": player_tile,
		"direction": exit_spec.get("direction", Vector2i.ZERO),
		"board_state": combat_state.duplicate(true)
	}

func _mark_salvaged_loot_resolution(combat_state: Dictionary, equipment_id: String) -> Dictionary:
	var next_state: Dictionary = combat_state.duplicate(true)
	if equipment_id.is_empty():
		return next_state
	var loot_entries: Array = next_state.get("loot", []).duplicate(true)
	for index: int in range(loot_entries.size()):
		if typeof(loot_entries[index]) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = (loot_entries[index] as Dictionary).duplicate(true)
		if str(loot.get("equipment_id", "")) != equipment_id:
			continue
		loot["claimed"] = true
		loot["resolution"] = "salvaged"
		loot_entries[index] = loot
		break
	next_state["loot"] = loot_entries
	return next_state

func _can_last_door_retreat(run_state: Dictionary) -> bool:
	if not run_skill_is_ready(run_state, "last_door"):
		return false
	var current_coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(run_state, current_coord)
	if str(current_room.get("type", "combat")) == "boss":
		return false
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	var previous_coord: Variant = skill_state.get("previous_room", null)
	if typeof(previous_coord) != TYPE_VECTOR2I or previous_coord == current_coord:
		return false
	return not _connection_to_room(current_room, previous_coord as Vector2i).is_empty()

func _retreat_through_last_door(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var current_coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(next_state, current_coord)
	var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	var previous_coord: Vector2i = skill_state.get("previous_room", Vector2i.ZERO)
	var return_connection: Dictionary = _connection_to_room(current_room, previous_coord)
	if return_connection.is_empty():
		return next_state
	var last_door_effect: Dictionary = SkillTreeLibrary.effect("last_door")
	var return_health: int = GameData.fixed_point_amount(maxi(1, int(last_door_effect.get("minimum_health_visible", 1))))
	var return_notice: String = "Last Door returns you to the previous chamber at %d health." % return_health
	_mark_run_skill_used(next_state, "last_door", return_notice)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	current_room["cleared"] = false
	current_room["sealed"] = false
	rooms[_room_key(current_coord)] = current_room
	var previous_room: Dictionary = _merge_room_metadata(
		int(next_state.get("seed", 0)),
		previous_coord,
		rooms.get(_room_key(previous_coord), {}) as Dictionary
	)
	previous_room["revealed"] = true
	previous_room["visited"] = true
	previous_room["sealed"] = false
	rooms[_room_key(previous_coord)] = previous_room
	next_state["rooms"] = rooms
	next_state["current_room"] = previous_coord
	next_state["current_room_layout"] = _display_layout_for_room(
		int(next_state.get("seed", 0)),
		previous_room,
		return_connection.get("door_dir", Vector2i.ZERO)
	)
	next_state["player_hp"] = return_health
	next_state["combat_state"] = {}
	next_state["pending_reward"] = {}
	next_state["mode"] = "room"
	next_state["game_over"] = false
	next_state["victory"] = false
	next_state["notice"] = return_notice
	_reveal_neighbors(next_state, previous_coord)
	_sync_current_layout_doors(next_state, previous_coord)
	return next_state

func claim_card_reward(run_state: Dictionary, card_id: String) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not card_id.is_empty():
		var reward_cards: Array = next_state.get("reward_cards", []).duplicate()
		reward_cards.append(card_id)
		next_state["reward_cards"] = reward_cards
		var magic_inventory: Array = next_state.get("magic_inventory", []).duplicate()
		magic_inventory.append(card_id)
		next_state["magic_inventory"] = magic_inventory
		next_state = _mark_loadout_unread(next_state, "magic", card_id)
		next_state = _rebuild_deck_cards(next_state)
		next_state["notice"] = "Added %s to reserve magic." % str(GameData.card_def(card_id).get("name", card_id))
	next_state["pending_reward"] = {}
	next_state["mode"] = MODE_ESCAPE if not pending_escape(next_state).is_empty() else "room"
	return next_state

func pending_escape(run_state: Dictionary) -> Dictionary:
	if typeof(run_state.get("pending_escape", null)) != TYPE_DICTIONARY:
		return {}
	return (run_state.get("pending_escape", {}) as Dictionary).duplicate(true)

func continue_pending_escape(run_state: Dictionary) -> Dictionary:
	var escape: Dictionary = pending_escape(run_state)
	if escape.is_empty():
		return run_state.duplicate(true)
	var destination_var: Variant = escape.get("destination", null)
	if typeof(destination_var) != TYPE_VECTOR2I:
		var invalid_state: Dictionary = run_state.duplicate(true)
		invalid_state["pending_escape"] = {}
		invalid_state["mode"] = "room"
		return invalid_state
	var destination: Vector2i = destination_var as Vector2i
	var previous_coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var continued_state: Dictionary = move_to_pre_battle(run_state, destination)
	continued_state["pending_escape"] = {}
	if continued_state.get("current_room", previous_coord) != destination:
		continued_state["mode"] = "room"
	return continued_state

func can_change_equipment(run_state: Dictionary) -> bool:
	return str(run_state.get("mode", "room")) in ["room", "campfire", MODE_PRE_BATTLE]

func can_change_magic(run_state: Dictionary) -> bool:
	return can_change_equipment(run_state)

func can_change_items(run_state: Dictionary) -> bool:
	return can_change_equipment(run_state)

func equip_equipment(run_state: Dictionary, equipment_id: String, target_slot: String = "") -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not can_change_equipment(next_state):
		return next_state
	var native_slot: String = GameData.equipment_slot(equipment_id)
	var slot: String = native_slot if target_slot.is_empty() else target_slot
	var wild_trinket_equip: bool = slot == "trinket" and native_slot != "trinket"
	if native_slot.is_empty() or not GameData.equipment_slots().has(slot) or not _run_has_equipment(next_state, equipment_id):
		return next_state
	if slot != native_slot and (not wild_trinket_equip or not has_run_skill(next_state, "open_arsenal")):
		return next_state
	var equipped: Dictionary = (next_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	for equipped_slot: String in GameData.equipment_slots():
		if str(equipped.get(equipped_slot, "")) == equipment_id:
			return next_state
	var current_id: String = str(equipped.get(slot, ""))
	if current_id == equipment_id:
		return next_state
	var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
	inventory.erase(equipment_id)
	if not current_id.is_empty() and not inventory.has(current_id):
		inventory.append(current_id)
	equipped[slot] = equipment_id
	next_state["equipment_inventory"] = inventory
	next_state["equipped_equipment"] = equipped
	next_state = _rebuild_deck_cards(next_state)
	if wild_trinket_equip:
		_record_run_skill_event(
			next_state,
			"open_arsenal",
			"Open Arsenal equips %s in the trinket slot." % str(GameData.equipment_def(equipment_id).get("name", equipment_id))
		)
	next_state["notice"] = "Equipped %s." % str(GameData.equipment_def(equipment_id).get("name", equipment_id))
	return next_state

func swap_magic_card(run_state: Dictionary, inventory_index: int, attuned_index: int) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not can_change_magic(next_state):
		return next_state
	var inventory: Array = next_state.get("magic_inventory", []).duplicate()
	var attuned: Array = next_state.get("attuned_magic_cards", []).duplicate()
	if inventory_index < 0 or inventory_index >= inventory.size():
		return next_state
	if attuned_index < 0 or attuned_index >= attuned.size():
		return next_state
	var incoming_card_id: String = str(inventory[inventory_index])
	var outgoing_card_id: String = str(attuned[attuned_index])
	if incoming_card_id.is_empty() or outgoing_card_id.is_empty():
		return next_state
	inventory[inventory_index] = outgoing_card_id
	attuned[attuned_index] = incoming_card_id
	next_state["magic_inventory"] = inventory
	next_state["attuned_magic_cards"] = attuned
	next_state = _rebuild_deck_cards(next_state)
	next_state["notice"] = "Attuned %s." % str(GameData.card_def(incoming_card_id).get("name", incoming_card_id))
	return next_state

func equip_item_card(run_state: Dictionary, inventory_index: int, equipped_index: int = -1) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not can_change_items(next_state):
		return next_state
	var inventory: Array = next_state.get("item_inventory", []).duplicate()
	var equipped: Array = next_state.get("equipped_items", []).duplicate()
	if inventory_index < 0 or inventory_index >= inventory.size():
		return next_state
	var incoming_card_id: String = str(inventory[inventory_index])
	if not GameData.card_is_item(incoming_card_id):
		return next_state
	if equipped_index >= GameData.item_loadout_limit():
		return next_state
	inventory.remove_at(inventory_index)
	if equipped_index >= 0 and equipped_index < equipped.size():
		var outgoing_card_id: String = str(equipped[equipped_index])
		equipped[equipped_index] = incoming_card_id
		if not outgoing_card_id.is_empty():
			inventory.append(outgoing_card_id)
	elif equipped.size() < GameData.item_loadout_limit():
		equipped.append(incoming_card_id)
	else:
		inventory.insert(inventory_index, incoming_card_id)
		next_state["item_inventory"] = inventory
		next_state["equipped_items"] = equipped
		next_state["notice"] = "Item slots are full."
		return next_state
	next_state["item_inventory"] = inventory
	next_state["equipped_items"] = equipped
	next_state = _rebuild_deck_cards(next_state)
	next_state["notice"] = "Equipped %s." % str(GameData.card_def(incoming_card_id).get("name", incoming_card_id))
	return next_state

func unequip_item_card(run_state: Dictionary, equipped_index: int) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not can_change_items(next_state):
		return next_state
	var equipped: Array = next_state.get("equipped_items", []).duplicate()
	if equipped_index < 0 or equipped_index >= equipped.size():
		return next_state
	var card_id: String = str(equipped[equipped_index])
	equipped.remove_at(equipped_index)
	var inventory: Array = next_state.get("item_inventory", []).duplicate()
	if not card_id.is_empty():
		inventory.append(card_id)
	next_state["equipped_items"] = equipped
	next_state["item_inventory"] = inventory
	next_state = _rebuild_deck_cards(next_state)
	next_state["notice"] = "Stowed %s." % str(GameData.card_def(card_id).get("name", card_id))
	return next_state

func consume_equipped_item_card(run_state: Dictionary, card_id: String) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if card_id.is_empty() or not GameData.card_consumes_on_play(card_id):
		return next_state
	var equipped: Array = next_state.get("equipped_items", []).duplicate()
	var consumed_index: int = -1
	for index: int in range(equipped.size()):
		if str(equipped[index]) == card_id:
			consumed_index = index
			break
	if consumed_index < 0:
		return next_state
	equipped.remove_at(consumed_index)
	next_state["equipped_items"] = equipped
	next_state = _rebuild_deck_cards(next_state)
	next_state["notice"] = "Used %s." % str(GameData.card_def(card_id).get("name", card_id))
	return next_state

func merchant_kind_for_current_room(run_state: Dictionary) -> String:
	return merchant_kind_for_room(room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO)))

func merchant_kind_for_room(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", ""))
	if room_type in [MERCHANT_SCAVENGER, LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		return MERCHANT_SCAVENGER
	var merchant_kind: String = str(room.get("merchant_kind", ""))
	if merchant_kind in [MERCHANT_SCAVENGER, LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		return MERCHANT_SCAVENGER
	return ""

func merchant_offer_ids(run_state: Dictionary, merchant_kind: String) -> Array:
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(run_state, coord)
	var stored_stock: Array = _merchant_room_stock(room)
	if room.has(MERCHANT_STOCK_KEY):
		return _merchant_valid_stock_ids(run_state, merchant_kind, room, stored_stock)
	return _initial_merchant_stock(run_state, merchant_kind, room)

func merchant_sellable_ids(run_state: Dictionary, merchant_kind: String) -> Array:
	if merchant_kind != MERCHANT_SCAVENGER:
		return []
	var result: Array = []
	var room: Dictionary = room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var purchased_ids: Array = _merchant_room_purchased_ids(room)
	var purchased_counts: Dictionary = _id_counts(purchased_ids)
	var inventories: Array = [
		run_state.get("equipment_inventory", []),
		run_state.get("magic_inventory", []),
		run_state.get("item_inventory", []),
	]
	for inventory_var: Variant in inventories:
		for item_var: Variant in inventory_var as Array:
			var item_id: String = str(item_var)
			if merchant_item_kind(item_id).is_empty():
				continue
			var protected_count: int = int(purchased_counts.get(item_id, 0))
			if protected_count > 0:
				purchased_counts[item_id] = protected_count - 1
				continue
			result.append(item_id)
	result.sort()
	return result

func merchant_item_kind(item_id: String) -> String:
	if not GameData.equipment_def(item_id).is_empty():
		return MERCHANT_ITEM_KIND_GEAR
	if GameData.card_is_item(item_id):
		return MERCHANT_ITEM_KIND_ITEM
	if not GameData.card_def(item_id).is_empty():
		return MERCHANT_ITEM_KIND_MAGIC
	return ""

func merchant_buy_cost(_merchant_kind: String, item_id: String) -> int:
	match merchant_item_kind(item_id):
		MERCHANT_ITEM_KIND_GEAR:
			var equipment_rarity: String = GameData.equipment_rarity(item_id)
			return int(MERCHANT_EQUIPMENT_BUY_COST_BY_RARITY.get(equipment_rarity, MERCHANT_EQUIPMENT_BUY_COST_BY_RARITY["common"]))
		MERCHANT_ITEM_KIND_MAGIC:
			var magic_rarity: String = GameData.card_rarity(item_id)
			return int(MERCHANT_MAGIC_BUY_COST_BY_RARITY.get(magic_rarity, MERCHANT_MAGIC_BUY_COST_BY_RARITY["common"]))
		MERCHANT_ITEM_KIND_ITEM:
			var item_rarity: String = GameData.card_rarity(item_id)
			return int(MERCHANT_ITEM_BUY_COST_BY_RARITY.get(item_rarity, MERCHANT_ITEM_BUY_COST_BY_RARITY["common"]))
	return 0

func merchant_sell_value(merchant_kind: String, item_id: String) -> int:
	var buy_cost: int = merchant_buy_cost(merchant_kind, item_id)
	if buy_cost <= 0:
		return 0
	return maxi(1, int(round(float(buy_cost) * MERCHANT_SELL_VALUE_RATIO)))

func buy_merchant_item(run_state: Dictionary, merchant_kind: String, item_id: String) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not _can_trade_at_merchant(next_state, merchant_kind):
		return next_state
	next_state = _ensure_merchant_room_stock(next_state, merchant_kind)
	if not merchant_offer_ids(next_state, merchant_kind).has(item_id):
		next_state["notice"] = "Not in stock."
		return next_state
	var room: Dictionary = room_metadata(next_state, next_state.get("current_room", Vector2i.ZERO))
	var stock: Array = _merchant_room_stock(room)
	var bought_slot: int = stock.find(item_id)
	if bought_slot < 0:
		next_state["notice"] = "Not in stock."
		return next_state
	var cost: int = merchant_buy_cost(merchant_kind, item_id)
	if cost <= 0:
		return next_state
	if held_embers(next_state) < cost:
		next_state["notice"] = "Need %d embers." % cost
		return next_state
	next_state = spend_held_embers(next_state, cost)
	match merchant_item_kind(item_id):
		MERCHANT_ITEM_KIND_GEAR:
			var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
			if not inventory.has(item_id):
				inventory.append(item_id)
			next_state["equipment_inventory"] = inventory
			var collected: Array = next_state.get("collected_equipment", []).duplicate()
			if not collected.has(item_id):
				collected.append(item_id)
			next_state["collected_equipment"] = collected
			next_state = _mark_loadout_unread(next_state, "equipment", item_id)
			next_state["notice"] = "Bought %s." % str(GameData.equipment_def(item_id).get("name", item_id))
		MERCHANT_ITEM_KIND_MAGIC:
			var reward_cards: Array = next_state.get("reward_cards", []).duplicate()
			reward_cards.append(item_id)
			next_state["reward_cards"] = reward_cards
			var magic_inventory: Array = next_state.get("magic_inventory", []).duplicate()
			magic_inventory.append(item_id)
			next_state["magic_inventory"] = magic_inventory
			next_state = _mark_loadout_unread(next_state, "magic", item_id)
			next_state = _rebuild_deck_cards(next_state)
			next_state["notice"] = "Bought %s." % str(GameData.card_def(item_id).get("name", item_id))
		MERCHANT_ITEM_KIND_ITEM:
			var item_inventory: Array = next_state.get("item_inventory", []).duplicate()
			item_inventory.append(item_id)
			next_state["item_inventory"] = item_inventory
			next_state = _mark_loadout_unread(next_state, "equipment", item_id)
			next_state["notice"] = "Bought %s." % str(GameData.card_def(item_id).get("name", item_id))
	next_state = _mark_merchant_item_purchased(next_state, item_id)
	next_state = _refill_merchant_stock_slot(next_state, merchant_kind, bought_slot, item_id)
	return next_state

func sell_merchant_item(run_state: Dictionary, merchant_kind: String, item_id: String) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state.duplicate(true))
	if not _can_trade_at_merchant(next_state, merchant_kind):
		return next_state
	next_state = _ensure_merchant_room_stock(next_state, merchant_kind)
	if not merchant_sellable_ids(next_state, merchant_kind).has(item_id):
		next_state["notice"] = "Cannot sell that here."
		return next_state
	var value: int = merchant_sell_value(merchant_kind, item_id)
	if value <= 0:
		return next_state
	match merchant_item_kind(item_id):
		MERCHANT_ITEM_KIND_GEAR:
			var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
			inventory.erase(item_id)
			next_state["equipment_inventory"] = inventory
			var collected: Array = next_state.get("collected_equipment", []).duplicate()
			collected.erase(item_id)
			next_state["collected_equipment"] = collected
			next_state["notice"] = "Sold %s." % str(GameData.equipment_def(item_id).get("name", item_id))
		MERCHANT_ITEM_KIND_MAGIC:
			var magic_inventory: Array = next_state.get("magic_inventory", []).duplicate()
			magic_inventory.erase(item_id)
			next_state["magic_inventory"] = magic_inventory
			var reward_cards: Array = next_state.get("reward_cards", []).duplicate()
			reward_cards.erase(item_id)
			next_state["reward_cards"] = reward_cards
			next_state = _rebuild_deck_cards(next_state)
			next_state["notice"] = "Sold %s." % str(GameData.card_def(item_id).get("name", item_id))
		MERCHANT_ITEM_KIND_ITEM:
			var item_inventory: Array = next_state.get("item_inventory", []).duplicate()
			item_inventory.erase(item_id)
			next_state["item_inventory"] = item_inventory
			next_state["notice"] = "Sold %s." % str(GameData.card_def(item_id).get("name", item_id))
	next_state = _mark_merchant_item_sold(next_state, item_id)
	next_state = add_held_embers(next_state, value)
	return next_state

func reserve_merchant_offer(run_state: Dictionary, item_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var merchant_kind: String = merchant_kind_for_current_room(next_state)
	if merchant_kind.is_empty() or not _can_trade_at_merchant(next_state, merchant_kind):
		return next_state
	if not run_skill_is_ready(next_state, "layaway") or item_id.is_empty():
		return next_state
	next_state = _ensure_merchant_room_stock(next_state, merchant_kind)
	if not merchant_offer_ids(next_state, merchant_kind).has(item_id):
		return next_state
	var coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(next_state, coord)
	var stock: Array = _merchant_room_stock(room)
	if not stock.has(item_id):
		return next_state
	stock.erase(item_id)
	room[MERCHANT_STOCK_KEY] = stock
	next_state = _store_room_metadata(next_state, coord, room)
	var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	skill_state["reserved_merchant"] = {
		"kind": merchant_kind,
		"item_id": item_id,
		"origin_coord": coord
	}
	next_state[SKILL_STATE_KEY] = skill_state
	_mark_run_skill_used(next_state, "layaway", "Layaway holds %s for the next visit." % _merchant_item_name(merchant_kind, item_id))
	next_state["notice"] = "%s is held for the next visit." % _merchant_item_name(merchant_kind, item_id)
	return next_state

func reroll_card_reward(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if str(next_state.get("mode", "room")) != "reward" or not run_skill_is_ready(next_state, "discerning_eye"):
		return next_state
	var pending_reward: Dictionary = (next_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	var previous_cards: Array[String] = _string_array_typed(pending_reward.get("cards", []))
	if previous_cards.is_empty():
		return next_state
	var current_room: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var replacement_cards: Array[String] = _generate_card_rewards(next_state, current_room, 1991, previous_cards)
	if replacement_cards.is_empty():
		return next_state
	pending_reward["cards"] = replacement_cards
	next_state["pending_reward"] = pending_reward
	_mark_run_skill_used(next_state, "discerning_eye", "Discerning Eye replaces the offered card reward.")
	next_state["notice"] = "The reward shifts into a new set of choices."
	return next_state

func skip_reward_for_heal(run_state: Dictionary, deferred_card_id: String = "") -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var pending_reward: Dictionary = next_state.get("pending_reward", {}) as Dictionary
	var offered_cards: Array = pending_reward.get("cards", []) as Array
	if has_run_skill(next_state, "deferred_choice") and not deferred_card_id.is_empty() and offered_cards.has(deferred_card_id):
		var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
		if str(skill_state.get("pending_card", "")) != deferred_card_id:
			skill_state["pending_card"] = deferred_card_id
			next_state[SKILL_STATE_KEY] = skill_state
			_record_run_skill_event(next_state, "deferred_choice", "Saved a card for the next reward.")
	var heal_amount: int = int(pending_reward.get("heal_amount", 0))
	next_state["player_hp"] = mini(int(next_state.get("player_max_hp", 1)), int(next_state.get("player_hp", 0)) + heal_amount)
	next_state["pending_reward"] = {}
	next_state["mode"] = MODE_ESCAPE if not pending_escape(next_state).is_empty() else "room"
	return next_state

func claim_relic(run_state: Dictionary, relic_id: String, deferred_relic_id: String = "") -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var offered_relics: Array = next_state.get("pending_relics", []) as Array
	if relic_id.is_empty():
		next_state["pending_relics"] = []
		next_state["mode"] = "room"
		return next_state
	if not offered_relics.has(relic_id):
		return next_state
	var relics: Array = next_state.get("relics", []).duplicate()
	if not relics.has(relic_id):
		relics.append(relic_id)
	next_state["relics"] = relics
	var bonus: int = GameData.stat_bonus_from_relics([relic_id], "max_hp")
	if bonus != 0:
		next_state["player_max_hp"] = int(next_state.get("player_max_hp", 1)) + bonus
		next_state["player_hp"] = int(next_state.get("player_hp", 1)) + bonus
	next_state = _sync_defiance_capacity(next_state, true)
	if has_run_skill(next_state, "curators_patience") and deferred_relic_id != relic_id and offered_relics.has(deferred_relic_id) and not relics.has(deferred_relic_id):
		var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
		if str(skill_state.get("pending_relic", "")) != deferred_relic_id:
			skill_state["pending_relic"] = deferred_relic_id
			next_state[SKILL_STATE_KEY] = skill_state
			_record_run_skill_event(next_state, "curators_patience", "Saved a relic for the next offer.")
	next_state["pending_relics"] = []
	next_state["mode"] = "room"
	return next_state

func leave_campfire(run_state: Dictionary, heal_amount: int = 0) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if heal_amount > 0:
		var max_hp: int = maxi(1, int(next_state.get("player_max_hp", 1)))
		var current_hp: int = int(next_state.get("player_hp", max_hp))
		next_state["player_hp"] = mini(max_hp, current_hp + heal_amount)
	next_state["mode"] = "room"
	return next_state

func held_embers(run_state: Dictionary) -> int:
	return maxi(0, int(run_state.get("held_embers", run_state.get("unbanked_embers", 0))))

func set_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["held_embers"] = maxi(0, amount)
	next_state["unbanked_embers"] = maxi(0, amount)
	return next_state

func add_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	return set_held_embers(run_state, held_embers(run_state) + amount)

func spend_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	return set_held_embers(run_state, held_embers(run_state) - amount)

func clear_held_embers(run_state: Dictionary) -> Dictionary:
	return set_held_embers(run_state, 0)

func apply_progression_update(run_state: Dictionary, progression: Dictionary, preserve_held_embers: bool = true) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var held_before: int = held_embers(next_state)
	var previous_skills: Array[String] = run_skill_ids(next_state)
	var normalized_progression: Dictionary = ProgressionStore.normalized_data(progression)
	next_state["progression"] = normalized_progression
	next_state = _sync_defiance_capacity(next_state, true)
	var held_after: int = held_before if preserve_held_embers else int(normalized_progression.get("embers", held_before))
	next_state = set_held_embers(next_state, held_after)
	next_state = _clear_removed_skill_pending(next_state, previous_skills, run_skill_ids(next_state))
	next_state = _repair_skill_dependent_state(next_state)
	var combat_state: Dictionary = (next_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if not combat_state.is_empty():
		combat_state["skill_ids"] = run_skill_ids(next_state)
		next_state["combat_state"] = _repair_combat_skill_state(combat_state)
	return next_state

func _repair_combat_skill_state(combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = combat_state.duplicate(true)
	var combat_skills: Array[String] = []
	for skill_id: String in SkillTreeLibrary.normalized_ids(next_state.get("skill_ids", [])):
		if not SkillTreeLibrary.is_retired(skill_id):
			combat_skills.append(skill_id)
	next_state["skill_ids"] = combat_skills
	var flags: Dictionary = (next_state.get("skill_flags", {}) as Dictionary).duplicate(true)
	if not combat_skills.has("prismatic_instinct"):
		flags.erase("prismatic_armed")
		flags.erase("prismatic_target_card_id")
	flags.erase("prismatic_resolving")
	if not combat_skills.has("rehearsed_escape"):
		flags.erase("burn_preserve_armed")
	if not combat_skills.has("makeshift_tool"):
		flags.erase("item_preserve_armed")
	if not combat_skills.has("carry_the_guard"):
		flags.erase("guard_carry_armed")
	if not combat_skills.has("pain_remembers"):
		flags.erase("pain_recall_primed")
	if not combat_skills.has("measured_breath"):
		next_state["banked_plays"] = 0
		next_state["banked_play_active"] = 0
		next_state["banked_play_spent_this_activation"] = 0
	next_state["skill_flags"] = flags
	return next_state

func _repair_combat_defiance_state(combat_state: Dictionary, capacity: int, fallback_remaining: int) -> Dictionary:
	var next_state: Dictionary = combat_state.duplicate(true)
	var safe_capacity: int = maxi(0, capacity)
	next_state[DEFIANCE_CAPACITY_KEY] = safe_capacity
	next_state[DEFIANCE_REMAINING_KEY] = clampi(
		int(next_state.get(DEFIANCE_REMAINING_KEY, fallback_remaining)),
		0,
		safe_capacity
	)
	var events: Array = []
	var latest_revision: int = maxi(0, int(next_state.get("defiance_event_revision", 0)))
	if typeof(next_state.get("defiance_events", null)) == TYPE_ARRAY:
		for event_var: Variant in next_state.get("defiance_events", []) as Array:
			if typeof(event_var) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = (event_var as Dictionary).duplicate(true)
			var revision: int = maxi(0, int(event.get("revision", 0)))
			if revision <= 0:
				continue
			event["revision"] = revision
			latest_revision = maxi(latest_revision, revision)
			events.append(event)
	while events.size() > CombatEngineScript.DEFIANCE_EVENT_LIMIT:
		events.pop_front()
	next_state["defiance_events"] = events
	next_state["defiance_event_revision"] = latest_revision
	return next_state

func _repair_pending_combat_checkpoints(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if typeof(next_state.get(COMBAT_CONTINUATION_KEY, null)) != TYPE_ARRAY:
		return next_state
	var checkpoints: Array = []
	var skill_ids: Array[String] = ProgressionStore.selected_skill_ids(
		next_state.get("progression", {}) as Dictionary
	)
	var capacity: int = defiance_capacity(next_state)
	var fallback_remaining: int = defiance_remaining(next_state)
	for checkpoint_var: Variant in next_state.get(COMBAT_CONTINUATION_KEY, []) as Array:
		if typeof(checkpoint_var) != TYPE_DICTIONARY:
			continue
		var checkpoint: Dictionary = (checkpoint_var as Dictionary).duplicate(true)
		if bool(checkpoint.get("resume_enemy_phase", false)):
			checkpoints.append({
				"boundary": str(checkpoint.get("boundary", "enemy_phase_continue")),
				"resume_enemy_phase": true
			})
			continue
		if typeof(checkpoint.get("state", null)) != TYPE_DICTIONARY:
			continue
		var checkpoint_state: Dictionary = (checkpoint.get("state", {}) as Dictionary).duplicate(true)
		checkpoint_state["skill_ids"] = skill_ids
		checkpoint_state.erase("stats")
		checkpoint_state.erase("card_upgrades")
		checkpoint_state.erase("card_mods")
		checkpoint_state = _repair_combat_defiance_state(
			_repair_combat_skill_state(checkpoint_state),
			capacity,
			fallback_remaining
		)
		checkpoint["state"] = checkpoint_state
		checkpoints.append(checkpoint)
	next_state.erase(COMBAT_CONTINUATION_KEY)
	if not checkpoints.is_empty() and str(next_state.get("mode", "")) == "combat":
		next_state[COMBAT_CONTINUATION_KEY] = checkpoints
	return next_state

func reconcile_progression_revision(run_state: Dictionary, profile_progression: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var embedded: Dictionary = ProgressionStore.normalized_data(next_state.get("progression", {}) as Dictionary)
	var profile: Dictionary = ProgressionStore.normalized_data(profile_progression)
	if int(profile.get("progression_revision", 0)) > int(embedded.get("progression_revision", 0)):
		var level_advanced: bool = int(profile.get("level", 1)) > int(embedded.get("level", 1))
		next_state = apply_progression_update(next_state, profile, not level_advanced)
		# Level-up commits are profile-first. If the run checkpoint was interrupted,
		# consume the stale campfire choice without granting its heal as well.
		if level_advanced and str(next_state.get("mode", "room")) == "campfire":
			next_state = leave_campfire(next_state, 0)
	else:
		next_state["progression"] = embedded
		next_state = _repair_skill_dependent_state(next_state)
	return next_state

func room_neighbors_with_metadata(run_state: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord: Vector2i in available_moves(run_state):
		results.append(room_metadata(run_state, coord))
	return results

func exit_options(run_state: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var current_room: Dictionary = room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var available_lookup: Dictionary = {}
	for coord: Vector2i in available_moves(run_state):
		available_lookup[coord] = true
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var destination: Vector2i = connection.get("coord", Vector2i(999, 999))
		if not available_lookup.has(destination):
			continue
		var door_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
		var room: Dictionary = room_metadata(run_state, destination)
		results.append({
			"dir": door_dir,
			"door_dir": door_dir,
			"coord": destination,
			"door_tile": RoomGeneratorScript.door_tile_for_direction(door_dir),
			"room": room
		})
	return results

func _repair_equipment_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var equipped: Dictionary = (next_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	if equipped.is_empty():
		equipped = GameData.starting_equipped_equipment()
	for slot: String in GameData.equipment_slots():
		if not equipped.has(slot):
			equipped[slot] = str(GameData.starting_equipped_equipment().get(slot, ""))
	next_state["equipped_equipment"] = equipped
	if not next_state.has("equipment_inventory"):
		next_state["equipment_inventory"] = []
	next_state[UNREAD_LOADOUT_EQUIPMENT_KEY] = _string_array(next_state.get(UNREAD_LOADOUT_EQUIPMENT_KEY, []))
	next_state[UNREAD_LOADOUT_MAGIC_KEY] = _string_array(next_state.get(UNREAD_LOADOUT_MAGIC_KEY, []))
	next_state[NEW_LOADOUT_EQUIPMENT_KEY] = _string_array(next_state.get(NEW_LOADOUT_EQUIPMENT_KEY, []))
	next_state[NEW_LOADOUT_MAGIC_KEY] = _string_array(next_state.get(NEW_LOADOUT_MAGIC_KEY, []))
	if not next_state.has("collected_equipment"):
		var collected: Array = []
		for slot: String in GameData.equipment_slots():
			var equipped_id: String = str(equipped.get(slot, ""))
			if not equipped_id.is_empty() and not collected.has(equipped_id):
				collected.append(equipped_id)
		for equipment_var: Variant in next_state.get("equipment_inventory", []):
			var inventory_id: String = str(equipment_var)
			if not inventory_id.is_empty() and not collected.has(inventory_id):
				collected.append(inventory_id)
		next_state["collected_equipment"] = collected
	if not next_state.has("reward_cards"):
		next_state["reward_cards"] = _migrated_reward_cards_from_deck(next_state.get("deck_cards", []), equipped)
	next_state = _repair_magic_state(next_state)
	next_state = _repair_item_state(next_state)
	return _rebuild_deck_cards(next_state)

func _clear_removed_skill_pending(run_state: Dictionary, previous_skills: Array[String], _current_skills: Array[String]) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if previous_skills.has("true_bearing") and not _current_skills.has("true_bearing"):
		next_state.erase("pre_battle_start")
	return next_state

func _repair_skill_dependent_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	if not str(skill_state.get("pending_card", "")).is_empty() and GameData.card_def(str(skill_state.get("pending_card", ""))).is_empty():
		skill_state["pending_card"] = ""
	if not str(skill_state.get("pending_relic", "")).is_empty() and GameData.relic_def(str(skill_state.get("pending_relic", ""))).is_empty():
		skill_state["pending_relic"] = ""
	var reservation: Dictionary = skill_state.get("reserved_merchant", {}) as Dictionary
	if not reservation.is_empty() and not _merchant_item_is_valid(str(reservation.get("kind", "")), str(reservation.get("item_id", ""))):
		skill_state["reserved_merchant"] = {}
	next_state[SKILL_STATE_KEY] = skill_state
	if not has_run_skill(next_state, "true_bearing"):
		next_state.erase("pre_battle_start")
	if not has_run_skill(next_state, "open_arsenal"):
		next_state = _stow_invalid_wild_trinket(next_state)
	return next_state

func _stow_invalid_wild_trinket(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var equipped: Dictionary = (next_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	var current_trinket: String = str(equipped.get("trinket", ""))
	if current_trinket.is_empty() or GameData.equipment_slot(current_trinket) == "trinket":
		return next_state
	var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
	if not inventory.has(current_trinket):
		inventory.append(current_trinket)
	var replacement: String = ""
	for candidate_var: Variant in inventory:
		var candidate: String = str(candidate_var)
		if GameData.equipment_slot(candidate) == "trinket":
			replacement = candidate
			break
	if not replacement.is_empty():
		inventory.erase(replacement)
	equipped["trinket"] = replacement
	next_state["equipment_inventory"] = inventory
	next_state["equipped_equipment"] = equipped
	return _rebuild_deck_cards(next_state)

func _repair_magic_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var reward_cards: Array = _string_array(next_state.get("reward_cards", []))
	next_state["reward_cards"] = reward_cards
	if not next_state.has("attuned_magic_cards") and not next_state.has("magic_inventory"):
		var migrated_magic: Dictionary = _magic_loadout_from_collected_rewards(reward_cards)
		next_state["attuned_magic_cards"] = migrated_magic.get("attuned_magic_cards", [])
		next_state["magic_inventory"] = migrated_magic.get("magic_inventory", [])
		return next_state
	var attuned: Array = _string_array(next_state.get("attuned_magic_cards", []))
	var inventory: Array = _string_array(next_state.get("magic_inventory", []))
	var limit: int = GameData.magic_loadout_limit()
	if attuned.size() > limit:
		for index: int in range(limit, attuned.size()):
			inventory.append(str(attuned[index]))
		while attuned.size() > limit:
			attuned.pop_back()
	attuned = _filled_attuned_magic(attuned)
	next_state["attuned_magic_cards"] = attuned
	next_state["magic_inventory"] = inventory
	return next_state

func _magic_loadout_from_collected_rewards(reward_cards: Array) -> Dictionary:
	var attuned: Array = []
	var inventory: Array = []
	var limit: int = GameData.magic_loadout_limit()
	for card_id_var: Variant in reward_cards:
		var card_id: String = str(card_id_var)
		if card_id.is_empty():
			continue
		if attuned.size() < limit:
			attuned.append(card_id)
		else:
			inventory.append(card_id)
	attuned = _filled_attuned_magic(attuned)
	return {
		"attuned_magic_cards": attuned,
		"magic_inventory": inventory
	}

func _filled_attuned_magic(attuned_cards: Array) -> Array:
	var result: Array = _string_array(attuned_cards)
	var defaults: Array = GameData.starting_magic_cards()
	var default_index: int = 0
	while result.size() < GameData.magic_loadout_limit() and not defaults.is_empty():
		result.append(str(defaults[default_index % defaults.size()]))
		default_index += 1
	return result

func _repair_item_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var inventory: Array = _item_card_array(next_state.get("item_inventory", []))
	var equipped: Array = _item_card_array(next_state.get("equipped_items", []))
	var limit: int = GameData.item_loadout_limit()
	if equipped.size() > limit:
		for index: int in range(limit, equipped.size()):
			inventory.append(str(equipped[index]))
		while equipped.size() > limit:
			equipped.pop_back()
	next_state["item_inventory"] = inventory
	next_state["equipped_items"] = equipped
	return next_state

func _item_card_array(values: Variant) -> Array:
	var result: Array = []
	for card_id_var: Variant in _string_array(values):
		var card_id: String = str(card_id_var)
		if GameData.card_is_item(card_id):
			result.append(card_id)
	return result

func _string_array(values: Variant) -> Array:
	var result: Array = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value_var: Variant in values:
		var value: String = str(value_var)
		if not value.is_empty():
			result.append(value)
	return result

func _string_array_typed(values: Variant) -> Array[String]:
	var result: Array[String]
	for value_var: Variant in _string_array(values):
		result.append(str(value_var))
	return result

func _migrated_reward_cards_from_deck(deck_cards: Array, equipped: Dictionary) -> Array:
	var equipment_counts: Dictionary = {}
	for card_id: String in GameData.compile_deck_cards(equipped, []):
		equipment_counts[card_id] = int(equipment_counts.get(card_id, 0)) + 1
	var migrated: Array = []
	for card_var: Variant in deck_cards:
		var card_id: String = str(card_var)
		var remaining_count: int = int(equipment_counts.get(card_id, 0))
		if remaining_count > 0:
			equipment_counts[card_id] = remaining_count - 1
		else:
			migrated.append(card_id)
	return migrated

func _rebuild_deck_cards(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["deck_cards"] = GameData.compile_deck_cards(
		next_state.get("equipped_equipment", {}) as Dictionary,
		next_state.get("attuned_magic_cards", []) as Array,
		next_state.get("equipped_items", []) as Array
	)
	return next_state

func _run_has_equipment(run_state: Dictionary, equipment_id: String) -> bool:
	if equipment_id.is_empty():
		return false
	for equipment_var: Variant in run_state.get("equipment_inventory", []):
		if str(equipment_var) == equipment_id:
			return true
	for equipped_var: Variant in (run_state.get("equipped_equipment", {}) as Dictionary).values():
		if str(equipped_var) == equipment_id:
			return true
	return false

func _player_snapshot(run_state: Dictionary) -> Dictionary:
	return {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": run_state.get("deck_cards", []).duplicate(),
		"equipped_items": run_state.get("equipped_items", []).duplicate(),
		"item_inventory": run_state.get("item_inventory", []).duplicate(),
		"skill_ids": ((run_state.get("progression", {}) as Dictionary).get("skill_ids", []) as Array).duplicate(),
		"level": int((run_state.get("progression", {}) as Dictionary).get("level", 1)),
		DEFIANCE_CAPACITY_KEY: int(run_state.get(DEFIANCE_CAPACITY_KEY, 0)),
		DEFIANCE_REMAINING_KEY: int(run_state.get(DEFIANCE_REMAINING_KEY, 0)),
		"relics": run_state.get("relics", []).duplicate(),
		"hand_size": int(run_state.get("hand_size", BASE_HAND_SIZE)),
		"heal_bonus": int(run_state.get("heal_bonus", 0)),
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN,
		"run_stats": CombatEngineScript.normalized_run_stats(run_state.get("run_stats", {}))
	}

func defiance_capacity(run_state: Dictionary) -> int:
	return maxi(0, int(run_state.get(DEFIANCE_CAPACITY_KEY, _derived_defiance_capacity(run_state))))

func defiance_remaining(run_state: Dictionary) -> int:
	return clampi(
		int(run_state.get(DEFIANCE_REMAINING_KEY, defiance_capacity(run_state))),
		0,
		defiance_capacity(run_state)
	)

func _derived_defiance_capacity(run_state: Dictionary) -> int:
	var progression: Dictionary = ProgressionStore.normalized_data(run_state.get("progression", {}) as Dictionary)
	return (
		ProgressionStore.defiance_capacity_for_level(int(progression.get("level", 1)))
		+ GameData.stat_bonus_from_relics(run_state.get("relics", []), "defiance_capacity")
	)

func _sync_defiance_capacity(run_state: Dictionary, grant_new_capacity: bool) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var desired_capacity: int = maxi(0, _derived_defiance_capacity(next_state))
	var previous_capacity: int = maxi(0, int(next_state.get(DEFIANCE_CAPACITY_KEY, desired_capacity)))
	var remaining: int = clampi(
		int(next_state.get(DEFIANCE_REMAINING_KEY, previous_capacity)),
		0,
		previous_capacity
	)
	if grant_new_capacity and desired_capacity > previous_capacity:
		remaining += desired_capacity - previous_capacity
	next_state[DEFIANCE_CAPACITY_KEY] = desired_capacity
	next_state[DEFIANCE_REMAINING_KEY] = clampi(remaining, 0, desired_capacity)
	var combat_state: Dictionary = (next_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if not combat_state.is_empty():
		combat_state[DEFIANCE_CAPACITY_KEY] = desired_capacity
		combat_state[DEFIANCE_REMAINING_KEY] = int(next_state.get(DEFIANCE_REMAINING_KEY, 0))
		next_state["combat_state"] = combat_state
	return next_state

func _build_room_metadata(seed: int, coord: Vector2i) -> Dictionary:
	var depth: int = _room_depth(coord)
	var room_type: String = _room_type_for_coord(seed, coord)
	var element_id: String = _room_element_for_coord(seed, coord, room_type)
	var boss_id: String = DragonBossLibrary.boss_id_for_depth(seed, depth) if room_type == "boss" else ""
	var npcs: Array[Dictionary] = _room_npcs_for_coord(seed, coord)
	var merchant_kind: String = _merchant_kind_for_room_type(room_type)
	var metadata: Dictionary = {
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"merchant_kind": merchant_kind,
		"element": element_id,
		"connections": _room_connections(coord),
		"npcs": npcs,
		"revealed": depth == 0,
		"visited": false,
		"cleared": room_type == "start",
		"sealed": false
	}
	if not boss_id.is_empty():
		metadata["boss_id"] = boss_id
	return metadata

func _display_layout_for_room(seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var layout: Dictionary = _room_generator.generate_room(seed, room, travel_dir)
	if layout.is_empty():
		return {}
	layout["enemies"] = []
	return layout

func _combat_layout_for_room(room: Dictionary, travel_dir: Vector2i, run_state: Dictionary) -> Dictionary:
	var layout_room: Dictionary = room.duplicate(true)
	if _room_has_recovery_marker(room):
		layout_room["type"] = "combat"
		if not ElementData.is_elemental(str(layout_room.get("element", ElementData.NONE))):
			layout_room["element"] = _room_element_for_coord(int(run_state.get("seed", 0)), layout_room.get("coord", Vector2i.ZERO), "combat")
	if str(layout_room.get("type", "combat")) == "combat":
		layout_room[CombatObjectiveRules.ONBOARDING_ROOM_KEY] = not _run_has_completed_combat(run_state)
	var equipment_drop: String = _equipment_drop_for_room(run_state, layout_room)
	if not equipment_drop.is_empty():
		layout_room["equipment_drop"] = equipment_drop
	var layout: Dictionary = _room_generator.generate_room(int(run_state.get("seed", 0)), layout_room, travel_dir)
	layout = _layout_with_recovery_loot(layout, room, run_state)
	if has_run_skill(run_state, "true_bearing") and typeof(run_state.get("pre_battle_start", null)) == TYPE_VECTOR2I:
		var chosen_start: Vector2i = run_state.get("pre_battle_start", Vector2i(-1, -1))
		if _layout_accepts_pre_battle_start(layout, chosen_start):
			layout["player_start"] = chosen_start
	return layout

func _run_has_completed_combat(run_state: Dictionary) -> bool:
	for room_var: Variant in (run_state.get("rooms", {}) as Dictionary).values():
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_var
		if str(room.get("type", "combat")) in ["combat", "boss"] and bool(room.get("cleared", false)):
			return true
	return false

func _layout_accepts_pre_battle_start(layout: Dictionary, tile: Vector2i) -> bool:
	var authored_start: Vector2i = layout.get("player_start", Vector2i(-1, -1))
	var max_range: int = maxi(0, int(SkillTreeLibrary.effect("true_bearing").get("range", 2)))
	if authored_start.x < 0 or absi(tile.x - authored_start.x) + absi(tile.y - authored_start.y) > max_range:
		return false
	var occupied: Dictionary = _layout_occupied_tiles(layout)
	occupied.erase(authored_start)
	return not occupied.has(tile) and PathUtils.is_passable(layout.get("grid", []), tile)

func _room_layout_from_combat_state(combat_state: Dictionary) -> Dictionary:
	return {
		"name": combat_state.get("room_name", "Room"),
		"coord": combat_state.get("room_coord", Vector2i.ZERO),
		"type": combat_state.get("room_type", "combat"),
		"element": combat_state.get("room_element", ElementData.NONE),
		"depth": int(combat_state.get("room_depth", 1)),
		"boss_id": str(combat_state.get("boss_id", "")),
		"grid": combat_state.get("grid", []).duplicate(true),
		"moss": combat_state.get("moss", {}).duplicate(true),
		"player_start": (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
		"npcs": [],
		"enemies": [],
		"traps": combat_state.get("traps", []).duplicate(true),
		"loot": combat_state.get("loot", []).duplicate(true),
		"terrain": combat_state.get("terrain", []).duplicate(true),
		"objective": (combat_state.get("objective", {}) as Dictionary).duplicate(true)
	}

func _room_type_for_coord(seed: int, coord: Vector2i) -> String:
	var depth: int = _room_depth(coord)
	if depth == 0:
		return "start"
	if depth > MAX_DEPTH:
		return "boss"
	if _is_sequence_boss_depth(depth):
		return "boss"
	if _is_campfire_coord(coord):
		return "campfire"
	if _is_relic_room_coord(seed, coord):
		return "treasure"
	if _is_merchant_room_coord(seed, coord):
		return _merchant_room_type_for_coord(seed, coord)
	return "combat"

func _room_element_for_coord(seed: int, coord: Vector2i, room_type: String) -> String:
	if room_type == "boss":
		return DragonBossLibrary.element_for_boss(DragonBossLibrary.boss_id_for_depth(seed, _room_depth(coord)))
	if room_type != "combat":
		return ElementData.NONE
	var roll: int = _coord_hash(seed, coord, 151) % ElementData.all_elements().size()
	return ElementData.all_elements()[roll]

func _room_depth(coord: Vector2i) -> int:
	return maxi(absi(coord.x), absi(coord.y))

func _depth_step_in_sequence(depth: int) -> int:
	return posmod(maxi(1, depth) - 1, DEPTHS_PER_SEQUENCE) + 1

func _is_sequence_boss_depth(depth: int) -> bool:
	return depth > 0 and depth <= MAX_DEPTH and _depth_step_in_sequence(depth) == DEPTHS_PER_SEQUENCE

func _is_final_boss_depth(depth: int) -> bool:
	return depth >= MAX_DEPTH and _is_sequence_boss_depth(depth)

func _is_campfire_coord(coord: Vector2i) -> bool:
	var depth: int = _room_depth(coord)
	return _depth_step_in_sequence(depth) == 2 and (coord.x == 0 or coord.y == 0)

func _is_relic_room_coord(seed: int, coord: Vector2i) -> bool:
	return _is_relic_room_coord_with_memo(seed, coord, {})

func _is_relic_room_coord_with_memo(seed: int, coord: Vector2i, memo: Dictionary) -> bool:
	var key: String = _room_key(coord)
	if memo.has(key):
		return bool(memo[key])
	if not _is_relic_room_candidate(seed, coord):
		memo[key] = false
		return false
	var priority: int = _relic_room_priority(seed, coord)
	for dir: Vector2i in PathUtils.DIRS_4:
		var neighbor: Vector2i = coord + dir
		if not _is_relic_room_candidate(seed, neighbor):
			continue
		var neighbor_priority: int = _relic_room_priority(seed, neighbor)
		var neighbor_has_priority: bool = neighbor_priority < priority or (neighbor_priority == priority and _room_key(neighbor) < key)
		if not neighbor_has_priority:
			continue
		if _is_relic_room_coord_with_memo(seed, neighbor, memo):
			memo[key] = false
			return false
	memo[key] = true
	return true

func _is_relic_room_candidate(seed: int, coord: Vector2i) -> bool:
	if not _is_relic_room_eligible(coord):
		return false
	return (_coord_hash(seed, coord, 77) % 1000) < RELIC_ROOM_CANDIDATE_PERCENT * 10

func _is_relic_room_eligible(coord: Vector2i) -> bool:
	var depth: int = _room_depth(coord)
	if depth <= 0 or depth > MAX_DEPTH:
		return false
	if _is_sequence_boss_depth(depth):
		return false
	if _is_campfire_coord(coord):
		return false
	if coord in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		return false
	return true

func _relic_room_priority(seed: int, coord: Vector2i) -> int:
	return _coord_hash(seed, coord, 733)

func _is_merchant_room_coord(seed: int, coord: Vector2i) -> bool:
	return _is_merchant_room_coord_with_memo(seed, coord, {})

func _is_merchant_room_coord_with_memo(seed: int, coord: Vector2i, memo: Dictionary) -> bool:
	var key: String = _room_key(coord)
	if memo.has(key):
		return bool(memo[key])
	if not _is_merchant_room_candidate(seed, coord):
		memo[key] = false
		return false
	var priority: int = _merchant_room_priority(seed, coord)
	for dir: Vector2i in PathUtils.DIRS_4:
		var neighbor: Vector2i = coord + dir
		if not _is_merchant_room_candidate(seed, neighbor):
			continue
		var neighbor_priority: int = _merchant_room_priority(seed, neighbor)
		var neighbor_has_priority: bool = neighbor_priority < priority or (neighbor_priority == priority and _room_key(neighbor) < key)
		if not neighbor_has_priority:
			continue
		if _is_merchant_room_coord_with_memo(seed, neighbor, memo):
			memo[key] = false
			return false
	memo[key] = true
	return true

func _is_merchant_room_candidate(seed: int, coord: Vector2i) -> bool:
	if not _is_merchant_room_eligible(seed, coord):
		return false
	return (_coord_hash(seed, coord, 811) % 1000) < MERCHANT_ROOM_CANDIDATE_PERCENT * 10

func _is_merchant_room_eligible(seed: int, coord: Vector2i) -> bool:
	var depth: int = _room_depth(coord)
	if depth < MERCHANT_ROOM_MIN_DEPTH or depth > MAX_DEPTH:
		return false
	if _is_sequence_boss_depth(depth):
		return false
	if _is_campfire_coord(coord):
		return false
	if _is_relic_room_coord(seed, coord):
		return false
	return true

func _merchant_room_priority(seed: int, coord: Vector2i) -> int:
	return _coord_hash(seed, coord, 821)

func _merchant_room_type_for_coord(seed: int, coord: Vector2i) -> String:
	return MERCHANT_SCAVENGER

func _merchant_kind_for_room_type(room_type: String) -> String:
	if room_type in [MERCHANT_SCAVENGER, LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		return MERCHANT_SCAVENGER
	return ""

func _generate_card_rewards(run_state: Dictionary, coord: Vector2i, salt: int = 991, excluded_cards: Array = []) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _coord_hash(int(run_state.get("seed", 0)), coord, salt)
	var choices: Array[String] = []
	var excluded: Array[String] = _string_array_typed(excluded_cards)
	var room: Dictionary = room_metadata(run_state, coord)
	var room_element: String = str(room.get("element", ElementData.NONE))
	if ElementData.is_elemental(room_element):
		var blocked_elemental: Array[String] = excluded.duplicate()
		blocked_elemental.append_array(choices)
		choices.append_array(_draw_reward_cards_for_element(rng, room_element, 2, blocked_elemental))
	var blocked_general: Array[String] = excluded.duplicate()
	blocked_general.append_array(choices)
	choices.append_array(_draw_reward_cards_for_element(rng, "", 1, blocked_general))
	if choices.size() < 3:
		choices.append_array(_draw_reward_cards_for_element(rng, "", 3 - choices.size(), choices))
	return choices

func _offer_with_deferred_id(choices_value: Array, deferred_id: String) -> Array[String]:
	var choices: Array[String] = _string_array_typed(choices_value)
	if deferred_id.is_empty() or choices.has(deferred_id):
		return choices
	if choices.size() >= 3:
		choices[choices.size() - 1] = deferred_id
	else:
		choices.append(deferred_id)
	return choices

func _draw_reward_cards_for_element(rng: RandomNumberGenerator, element_filter: String, count: int, existing_choices: Array[String]) -> Array[String]:
	var pool_by_rarity: Dictionary = GameData.reward_card_pool_by_rarity(element_filter, true)
	var choices: Array[String] = []
	var attempts: int = 0
	while choices.size() < count and attempts < 72:
		attempts += 1
		var rarity: String = _draw_card_reward_rarity(rng, pool_by_rarity)
		if rarity.is_empty():
			break
		var pool: Array = (pool_by_rarity.get(rarity, []) as Array).duplicate()
		if pool.is_empty():
			continue
		var weighted_pool: Array[String] = []
		for card_id_var: Variant in pool:
			var card_id: String = str(card_id_var)
			if existing_choices.has(card_id) or choices.has(card_id):
				continue
			for _weight_index: int in range(GameData.reward_offer_weight(card_id)):
				weighted_pool.append(card_id)
		if weighted_pool.is_empty():
			continue
		choices.append(str(weighted_pool[rng.randi_range(0, weighted_pool.size() - 1)]))
	return choices

func _draw_card_reward_rarity(rng: RandomNumberGenerator, pool_by_rarity: Dictionary) -> String:
	var total_weight: int = 0
	for rarity: String in GameData.CARD_RARITY_TIERS:
		if (pool_by_rarity.get(rarity, []) as Array).is_empty():
			continue
		total_weight += GameData.rarity_offer_weight(rarity)
	if total_weight <= 0:
		return ""
	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for rarity: String in GameData.CARD_RARITY_TIERS:
		if (pool_by_rarity.get(rarity, []) as Array).is_empty():
			continue
		cursor += GameData.rarity_offer_weight(rarity)
		if roll <= cursor:
			return rarity
	return "common"

func _equipment_drop_for_room(run_state: Dictionary, room: Dictionary) -> String:
	if str(room.get("type", "")) != "combat" or bool(room.get("cleared", false)):
		return ""
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var available: Array = _available_equipment_drop_ids(run_state)
	if available.is_empty():
		return ""
	var forced_drop: bool = int(run_state.get("equipment_drop_misses", 0)) >= EQUIPMENT_DROP_PITY_MISSES
	if not forced_drop and (_coord_hash(int(run_state.get("seed", 0)), coord, 1201) % 100) >= EQUIPMENT_ROOM_DROP_PERCENT:
		return ""
	return _weighted_equipment_drop_for_room(run_state, coord, available)

func _weighted_equipment_drop_for_room(run_state: Dictionary, coord: Vector2i, available: Array) -> String:
	var total_weight: int = 0
	for equipment_id: String in available:
		total_weight += maxi(1, GameData.equipment_offer_weight(equipment_id))
	var roll: int = (_coord_hash(int(run_state.get("seed", 0)), coord, 1207) % maxi(1, total_weight)) + 1
	var cursor: int = 0
	for equipment_id: String in available:
		cursor += maxi(1, GameData.equipment_offer_weight(equipment_id))
		if roll <= cursor:
			return equipment_id
	return available[0]

func _equipment_drop_can_attempt(run_state: Dictionary, room: Dictionary) -> bool:
	return str(room.get("type", "")) == "combat" and not bool(room.get("cleared", false)) and not _available_equipment_drop_ids(run_state).is_empty()

func _record_equipment_drop_attempt(run_state: Dictionary, layout: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if _layout_has_equipment_drop(layout):
		next_state["equipment_drop_misses"] = 0
	else:
		next_state["equipment_drop_misses"] = int(next_state.get("equipment_drop_misses", 0)) + 1
	return next_state

func _layout_has_equipment_drop(layout: Dictionary) -> bool:
	for loot_var: Variant in layout.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if not bool(loot.get("claimed", false)) and str(loot.get("kind", "")) == "equipment":
			return true
	return false

func _available_equipment_drop_ids(run_state: Dictionary) -> Array:
	var owned: Dictionary = {}
	for equipment_var: Variant in run_state.get("collected_equipment", []):
		owned[str(equipment_var)] = true
	for equipment_var: Variant in run_state.get("equipment_inventory", []):
		owned[str(equipment_var)] = true
	for equipment_var: Variant in (run_state.get("equipped_equipment", {}) as Dictionary).values():
		owned[str(equipment_var)] = true
	for starter_id: String in GameData.starter_equipment_ids():
		owned[starter_id] = true
	var result: Array = []
	for equipment_id_var: Variant in GameData.equipment_ids():
		var equipment_id: String = str(equipment_id_var)
		if owned.has(equipment_id):
			continue
		if GameData.equipment_slot(equipment_id).is_empty():
			continue
		result.append(equipment_id)
	result.sort()
	return result

func _can_trade_at_merchant(run_state: Dictionary, merchant_kind: String) -> bool:
	return str(run_state.get("mode", "room")) == "room" and merchant_kind_for_current_room(run_state) == merchant_kind

func _merchant_room_stock(room: Dictionary) -> Array:
	return _string_array(room.get(MERCHANT_STOCK_KEY, []))

func _merchant_room_sold_ids(room: Dictionary) -> Array:
	return _string_array(room.get(MERCHANT_SOLD_KEY, []))

func _merchant_room_purchased_ids(room: Dictionary) -> Array:
	return _string_array(room.get(MERCHANT_PURCHASED_KEY, []))

func _initial_merchant_stock(run_state: Dictionary, merchant_kind: String, room: Dictionary) -> Array:
	if merchant_kind != MERCHANT_SCAVENGER:
		return []
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var stock: Array = []
	for category: String in [MERCHANT_ITEM_KIND_MAGIC, MERCHANT_ITEM_KIND_GEAR, MERCHANT_ITEM_KIND_ITEM]:
		stock.append_array(_weighted_merchant_choices(
			int(run_state.get("seed", 0)),
			coord,
			_available_merchant_offer_ids(run_state, category, _merchant_room_sold_ids(room)),
			MERCHANT_OFFERS_PER_CATEGORY,
			_merchant_offer_salt(category),
			category
		))
	return stock

func _merchant_room_with_stock(run_state: Dictionary, room: Dictionary, merchant_kind: String) -> Dictionary:
	var stocked_room: Dictionary = room.duplicate(true)
	if not stocked_room.has(MERCHANT_STOCK_KEY):
		stocked_room[MERCHANT_STOCK_KEY] = _initial_merchant_stock(run_state, merchant_kind, stocked_room)
	else:
		stocked_room[MERCHANT_STOCK_KEY] = _merchant_valid_stock_ids(run_state, merchant_kind, stocked_room, _merchant_room_stock(stocked_room))
	if not stocked_room.has(MERCHANT_SOLD_KEY):
		stocked_room[MERCHANT_SOLD_KEY] = []
	if not stocked_room.has(MERCHANT_PURCHASED_KEY):
		stocked_room[MERCHANT_PURCHASED_KEY] = []
	if not stocked_room.has(MERCHANT_REFILL_COUNT_KEY):
		stocked_room[MERCHANT_REFILL_COUNT_KEY] = 0
	return stocked_room

func _inject_reserved_merchant_offer(run_state: Dictionary, coord: Vector2i, merchant_kind: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	var reservation: Dictionary = skill_state.get("reserved_merchant", {}) as Dictionary
	var reserved_kind: String = str(reservation.get("kind", ""))
	var item_id: String = str(reservation.get("item_id", ""))
	var origin_coord: Variant = reservation.get("origin_coord", Vector2i(-999, -999))
	if reserved_kind != merchant_kind or item_id.is_empty() or origin_coord == coord or not _merchant_item_is_valid(merchant_kind, item_id):
		return next_state
	var room: Dictionary = room_metadata(next_state, coord)
	var stock: Array = _merchant_valid_stock_ids(next_state, merchant_kind, room, _merchant_room_stock(room))
	stock.erase(item_id)
	var reserved_category: String = merchant_item_kind(item_id)
	var category_indices: Array[int] = []
	for index: int in range(stock.size()):
		if merchant_item_kind(str(stock[index])) == reserved_category:
			category_indices.append(index)
	if category_indices.size() >= MERCHANT_OFFERS_PER_CATEGORY:
		stock.remove_at(category_indices.back())
	var insert_index: int = category_indices.front() if not category_indices.is_empty() else stock.size()
	stock.insert(mini(insert_index, stock.size()), item_id)
	room[MERCHANT_STOCK_KEY] = stock
	next_state = _store_room_metadata(next_state, coord, room)
	skill_state["reserved_merchant"] = {}
	next_state[SKILL_STATE_KEY] = skill_state
	next_state["notice"] = "%s returns from layaway." % _merchant_item_name(merchant_kind, item_id)
	return next_state

func _merchant_item_is_valid(merchant_kind: String, item_id: String) -> bool:
	return merchant_kind == MERCHANT_SCAVENGER and not merchant_item_kind(item_id).is_empty()

func _merchant_item_name(_merchant_kind: String, item_id: String) -> String:
	if merchant_item_kind(item_id) == MERCHANT_ITEM_KIND_GEAR:
		return str(GameData.equipment_def(item_id).get("name", item_id))
	return str(GameData.card_def(item_id).get("name", item_id))

func _ensure_merchant_room_stock(run_state: Dictionary, merchant_kind: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(next_state, coord)
	return _store_room_metadata(next_state, coord, _merchant_room_with_stock(next_state, room, merchant_kind))

func _refill_merchant_stock_slot(run_state: Dictionary, merchant_kind: String, slot_index: int, purchased_item_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(next_state, coord)
	var stock: Array = _merchant_room_stock(room)
	if slot_index < 0 or slot_index >= stock.size():
		return next_state
	stock.remove_at(slot_index)
	var excluded: Array = stock.duplicate()
	excluded.append_array(_merchant_room_sold_ids(room))
	if not purchased_item_id.is_empty():
		excluded.append(purchased_item_id)
	var refill_count: int = maxi(0, int(room.get(MERCHANT_REFILL_COUNT_KEY, 0)))
	var category: String = merchant_item_kind(purchased_item_id)
	var replacement: Array = _weighted_merchant_choices(
		int(next_state.get("seed", 0)),
		coord,
		_available_merchant_offer_ids(next_state, category, excluded),
		1,
		_merchant_offer_salt(category) + 503 + refill_count * 29 + slot_index * 7,
		category
	)
	if not replacement.is_empty():
		stock.insert(slot_index, str(replacement[0]))
	room[MERCHANT_STOCK_KEY] = stock
	room[MERCHANT_REFILL_COUNT_KEY] = refill_count + 1
	return _store_room_metadata(next_state, coord, room)

func _mark_merchant_item_sold(run_state: Dictionary, item_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(next_state, coord)
	var sold_ids: Array = _merchant_room_sold_ids(room)
	if not item_id.is_empty() and not sold_ids.has(item_id):
		sold_ids.append(item_id)
		sold_ids.sort()
	room[MERCHANT_SOLD_KEY] = sold_ids
	return _store_room_metadata(next_state, coord, room)

func _mark_merchant_item_purchased(run_state: Dictionary, item_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = room_metadata(next_state, coord)
	var purchased_ids: Array = _merchant_room_purchased_ids(room)
	if not item_id.is_empty():
		purchased_ids.append(item_id)
		purchased_ids.sort()
	room[MERCHANT_PURCHASED_KEY] = purchased_ids
	return _store_room_metadata(next_state, coord, room)

func _id_counts(ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for id_var: Variant in ids:
		var item_id: String = str(id_var)
		if item_id.is_empty():
			continue
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts

func _merchant_valid_stock_ids(run_state: Dictionary, merchant_kind: String, room: Dictionary, stock: Array) -> Array:
	var sold_ids: Array = _merchant_room_sold_ids(room)
	var result: Array = []
	if merchant_kind != MERCHANT_SCAVENGER:
		return result
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var skill_state: Dictionary = _normalized_skill_state(run_state.get(SKILL_STATE_KEY, {}))
	var reservation: Dictionary = skill_state.get("reserved_merchant", {}) as Dictionary
	var reservation_origin: Variant = reservation.get("origin_coord", Vector2i(-999, -999))
	var reserved_item_id: String = str(reservation.get("item_id", ""))
	for category: String in [MERCHANT_ITEM_KIND_MAGIC, MERCHANT_ITEM_KIND_GEAR, MERCHANT_ITEM_KIND_ITEM]:
		var category_target: int = MERCHANT_OFFERS_PER_CATEGORY
		if reservation_origin == coord and merchant_item_kind(reserved_item_id) == category:
			category_target -= 1
		var available: Array = _available_merchant_offer_ids(run_state, category, sold_ids)
		var category_items: Array = []
		for item_var: Variant in stock:
			var item_id: String = str(item_var)
			if merchant_item_kind(item_id) != category or sold_ids.has(item_id) or not available.has(item_id) or category_items.has(item_id):
				continue
			category_items.append(item_id)
			if category_items.size() >= category_target:
				break
		var excluded: Array = sold_ids.duplicate()
		excluded.append_array(result)
		excluded.append_array(category_items)
		if not reserved_item_id.is_empty():
			excluded.append(reserved_item_id)
		category_items.append_array(_weighted_merchant_choices(
			int(run_state.get("seed", 0)),
			coord,
			_available_merchant_offer_ids(run_state, category, excluded),
			category_target - category_items.size(),
			_merchant_offer_salt(category) + 313,
			category
		))
		result.append_array(category_items)
	return result

func _available_merchant_offer_ids(run_state: Dictionary, category: String, excluded_ids: Array) -> Array:
	var excluded: Dictionary = {}
	for excluded_var: Variant in excluded_ids:
		excluded[str(excluded_var)] = true
	var source: Array = []
	match category:
		MERCHANT_ITEM_KIND_GEAR:
			source = _available_merchant_equipment_ids(run_state)
		MERCHANT_ITEM_KIND_MAGIC:
			source = _available_merchant_magic_ids(run_state)
		MERCHANT_ITEM_KIND_ITEM:
			source = _available_merchant_item_ids()
	var result: Array = []
	for item_var: Variant in source:
		var item_id: String = str(item_var)
		if item_id.is_empty() or excluded.has(item_id):
			continue
		result.append(item_id)
	return result

func _merchant_offer_salt(category: String) -> int:
	match category:
		MERCHANT_ITEM_KIND_GEAR:
			return 1601
		MERCHANT_ITEM_KIND_MAGIC:
			return 1701
		MERCHANT_ITEM_KIND_ITEM:
			return 1801
	return 1901

func _store_room_metadata(run_state: Dictionary, coord: Vector2i, room: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	rooms[_room_key(coord)] = room
	next_state["rooms"] = rooms
	return next_state

func _available_merchant_equipment_ids(run_state: Dictionary) -> Array:
	var owned: Dictionary = {}
	for equipment_var: Variant in run_state.get("equipment_inventory", []):
		owned[str(equipment_var)] = true
	for equipment_var: Variant in (run_state.get("equipped_equipment", {}) as Dictionary).values():
		owned[str(equipment_var)] = true
	var result: Array = []
	for equipment_id_var: Variant in GameData.equipment_ids():
		var equipment_id: String = str(equipment_id_var)
		if owned.has(equipment_id):
			continue
		if GameData.equipment_slot(equipment_id).is_empty():
			continue
		result.append(equipment_id)
	result.sort()
	return result

func _available_merchant_magic_ids(run_state: Dictionary) -> Array:
	var owned: Dictionary = {}
	for card_var: Variant in run_state.get("reward_cards", []):
		owned[str(card_var)] = true
	for card_var: Variant in run_state.get("attuned_magic_cards", []):
		owned[str(card_var)] = true
	for card_var: Variant in run_state.get("magic_inventory", []):
		owned[str(card_var)] = true
	var pool_by_rarity: Dictionary = GameData.reward_card_pool_by_rarity("", true)
	var result: Array = []
	for rarity: String in GameData.CARD_RARITY_TIERS:
		for card_id_var: Variant in pool_by_rarity.get(rarity, []):
			var card_id: String = str(card_id_var)
			if owned.has(card_id) or result.has(card_id):
				continue
			result.append(card_id)
	result.sort()
	return result

func _available_merchant_item_ids() -> Array:
	return GameData.item_card_ids()

func _weighted_merchant_choices(seed: int, coord: Vector2i, available: Array, count: int, salt: int, merchant_kind: String) -> Array:
	var pool: Array = available.duplicate()
	pool.sort()
	var choices: Array = []
	var pick_index: int = 0
	while choices.size() < count and not pool.is_empty():
		var total_weight: int = 0
		for item_var: Variant in pool:
			total_weight += maxi(1, _merchant_offer_weight(merchant_kind, str(item_var)))
		var roll: int = (_coord_hash(seed, coord, salt + pick_index * 17) % maxi(1, total_weight)) + 1
		var cursor: int = 0
		var selected_index: int = 0
		for index: int in range(pool.size()):
			cursor += maxi(1, _merchant_offer_weight(merchant_kind, str(pool[index])))
			if roll <= cursor:
				selected_index = index
				break
		choices.append(str(pool[selected_index]))
		pool.remove_at(selected_index)
		pick_index += 1
	return choices

func _merchant_offer_weight(category: String, item_id: String) -> int:
	match category:
		MERCHANT_ITEM_KIND_GEAR:
			return GameData.equipment_offer_weight(item_id)
		MERCHANT_ITEM_KIND_MAGIC:
			return GameData.rarity_offer_weight(GameData.card_rarity(item_id))
		MERCHANT_ITEM_KIND_ITEM:
			return GameData.item_offer_weight(item_id)
	return 1

func _generate_relic_choices(run_state: Dictionary, coord: Vector2i) -> Array[String]:
	var owned: Array = run_state.get("relics", []).duplicate()
	var available: Array[String] = []
	for relic_id: String in GameData.relic_ids():
		if not owned.has(relic_id):
			available.append(relic_id)
	available.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _coord_hash(int(run_state.get("seed", 0)), coord, 543)
	var choices: Array[String] = []
	while choices.size() < 3 and not available.is_empty():
		var total_weight: int = 0
		for relic_id: String in available:
			total_weight += maxi(1, GameData.relic_offer_weight(relic_id))
		var roll: int = rng.randi_range(1, total_weight)
		var cursor: int = 0
		var picked_index: int = 0
		for index: int in range(available.size()):
			cursor += maxi(1, GameData.relic_offer_weight(available[index]))
			if roll <= cursor:
				picked_index = index
				break
		choices.append(available[picked_index])
		available.remove_at(picked_index)
	return choices

func _reveal_neighbors(run_state: Dictionary, center: Vector2i) -> void:
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var center_room: Dictionary = room_metadata(run_state, center)
	for connection_var: Variant in center_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var coord: Vector2i = connection.get("coord", Vector2i(999, 999))
		var key: String = _room_key(coord)
		var room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms.get(key, {}) as Dictionary)
		room["revealed"] = true
		rooms[key] = room
	run_state["rooms"] = rooms
	if run_state.get("current_room", Vector2i.ZERO) == center:
		_normalize_current_choice_pair(run_state)

func _normalize_current_choice_pair(run_state: Dictionary) -> void:
	var choices: Array[Vector2i] = available_moves(run_state)
	if choices.size() != 2:
		return
	var seed: int = int(run_state.get("seed", 0))
	var first_coord: Vector2i = choices[0]
	var second_coord: Vector2i = choices[1]
	var first_room: Dictionary = room_metadata(run_state, first_coord)
	var second_room: Dictionary = room_metadata(run_state, second_coord)
	if _choice_pair_is_valid(first_room, second_room):
		return
	var target_category: String = _choice_pair_target_category(first_room, second_room)
	var adjusted_pair: Dictionary = _choice_pair_adjusted_for_category(seed, first_coord, first_room, second_coord, second_room, target_category)
	var adjusted_first: Dictionary = adjusted_pair.get("first", first_room)
	var adjusted_second: Dictionary = adjusted_pair.get("second", second_room)
	if not _choice_pair_is_valid(adjusted_first, adjusted_second):
		target_category = CHOICE_CATEGORY_COMBAT if target_category == CHOICE_CATEGORY_NON_COMBAT else CHOICE_CATEGORY_NON_COMBAT
		adjusted_pair = _choice_pair_adjusted_for_category(seed, first_coord, first_room, second_coord, second_room, target_category)
		adjusted_first = adjusted_pair.get("first", first_room)
		adjusted_second = adjusted_pair.get("second", second_room)
	if not _choice_pair_is_valid(adjusted_first, adjusted_second):
		return
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	rooms[_room_key(first_coord)] = adjusted_first
	rooms[_room_key(second_coord)] = adjusted_second
	run_state["rooms"] = rooms

func _choice_pair_adjusted_for_category(seed: int, first_coord: Vector2i, first_room: Dictionary, second_coord: Vector2i, second_room: Dictionary, target_category: String) -> Dictionary:
	var adjusted_first: Dictionary = first_room.duplicate(true)
	var adjusted_second: Dictionary = second_room.duplicate(true)
	if _choice_room_category(adjusted_first) != target_category and _choice_room_can_retype(adjusted_first, target_category):
		var avoid_second: String = _choice_room_type_key(adjusted_second) if _choice_room_category(adjusted_second) == target_category else ""
		adjusted_first = _room_retyped_for_choice(seed, first_coord, adjusted_first, target_category, avoid_second)
	if _choice_room_category(adjusted_second) != target_category and _choice_room_can_retype(adjusted_second, target_category):
		var avoid_first: String = _choice_room_type_key(adjusted_first) if _choice_room_category(adjusted_first) == target_category else ""
		adjusted_second = _room_retyped_for_choice(seed, second_coord, adjusted_second, target_category, avoid_first)
	if _choice_room_category(adjusted_first) == target_category and _choice_room_category(adjusted_second) == target_category and _choice_room_type_key(adjusted_first) == _choice_room_type_key(adjusted_second):
		if _choice_room_can_retype(adjusted_second, target_category):
			adjusted_second = _room_retyped_for_choice(seed, second_coord, adjusted_second, target_category, _choice_room_type_key(adjusted_first))
		elif _choice_room_can_retype(adjusted_first, target_category):
			adjusted_first = _room_retyped_for_choice(seed, first_coord, adjusted_first, target_category, _choice_room_type_key(adjusted_second))
	return {
		"first": adjusted_first,
		"second": adjusted_second
	}

func _choice_pair_is_valid(first_room: Dictionary, second_room: Dictionary) -> bool:
	if _choice_room_category(first_room) != _choice_room_category(second_room):
		return false
	return _choice_room_type_key(first_room) != _choice_room_type_key(second_room)

func _choice_pair_target_category(first_room: Dictionary, second_room: Dictionary) -> String:
	var first_category: String = _choice_room_category(first_room)
	var second_category: String = _choice_room_category(second_room)
	if first_category == second_category:
		return first_category
	if _choice_room_type_key(first_room) == "boss" or _choice_room_type_key(second_room) == "boss":
		return CHOICE_CATEGORY_COMBAT
	if _choice_room_type_key(first_room) == "campfire" or _choice_room_type_key(second_room) == "campfire":
		return CHOICE_CATEGORY_NON_COMBAT
	return CHOICE_CATEGORY_NON_COMBAT

func _choice_room_category(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "combat" or room_type == "boss":
		return CHOICE_CATEGORY_COMBAT
	return CHOICE_CATEGORY_NON_COMBAT

func _choice_room_type_key(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "combat":
		var element_id: String = str(room.get("element", ElementData.NONE))
		return element_id if ElementData.is_elemental(element_id) else ElementData.NONE
	if room_type == "boss":
		return "boss"
	return room_type

func _choice_room_can_retype(room: Dictionary, target_category: String = "") -> bool:
	if bool(room.get("visited", false)) or bool(room.get("cleared", false)):
		return false
	if _room_has_recovery_marker(room):
		return false
	if room.has(MERCHANT_STOCK_KEY) or room.has(MERCHANT_SOLD_KEY) or room.has(MERCHANT_PURCHASED_KEY):
		return false
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	if coord == Vector2i.ZERO:
		return false
	if _is_sequence_boss_depth(_room_depth(coord)):
		return false
	if _is_campfire_coord(coord) and target_category != CHOICE_CATEGORY_COMBAT:
		return false
	return true

func _room_retyped_for_choice(seed: int, coord: Vector2i, room: Dictionary, category: String, avoid_key: String) -> Dictionary:
	var next_room: Dictionary = room.duplicate(true)
	next_room["cleared"] = false
	if category == CHOICE_CATEGORY_COMBAT:
		next_room["type"] = "combat"
		next_room["merchant_kind"] = ""
		next_room["element"] = _choice_combat_element(seed, coord, avoid_key)
		next_room["npcs"] = []
		return next_room
	var room_type: String = _choice_non_combat_room_type(seed, coord, avoid_key)
	if room_type.is_empty():
		return room.duplicate(true)
	next_room["type"] = room_type
	next_room["merchant_kind"] = _merchant_kind_for_room_type(room_type)
	next_room["element"] = ElementData.NONE
	next_room["npcs"] = _npcs_for_room_type(room_type)
	return next_room

func _choice_combat_element(seed: int, coord: Vector2i, avoid_key: String) -> String:
	var choices: Array = []
	for element_id: String in ElementData.all_elements():
		if element_id == avoid_key:
			continue
		choices.append(element_id)
	if choices.is_empty():
		return ElementData.FIRE
	return str(choices[_coord_hash(seed, coord, 1321) % choices.size()])

func _choice_non_combat_room_type(seed: int, coord: Vector2i, avoid_key: String) -> String:
	var choices: Array = []
	if _is_relic_room_eligible(coord) and avoid_key != "treasure":
		choices.append("treasure")
	var depth: int = _room_depth(coord)
	if depth >= MERCHANT_ROOM_MIN_DEPTH and depth <= MAX_DEPTH and not _is_sequence_boss_depth(depth) and not _is_campfire_coord(coord):
		for room_type_var: Variant in CHOICE_NON_COMBAT_ROOM_TYPES:
			var room_type: String = str(room_type_var)
			if room_type == "treasure" or room_type == avoid_key:
				continue
			choices.append(room_type)
	if choices.is_empty():
		return ""
	return str(choices[_coord_hash(seed, coord, 1327) % choices.size()])

func _npcs_for_room_type(room_type: String) -> Array[Dictionary]:
	var npcs: Array[Dictionary] = []
	if room_type in [MERCHANT_SCAVENGER, LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		npcs.append({"id": MERCHANT_SCAVENGER, "pos": Vector2i(3, 4)})
	return npcs

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _room_npcs_for_coord(seed: int, coord: Vector2i) -> Array[Dictionary]:
	var room_type: String = _room_type_for_coord(seed, coord)
	if coord == Vector2i.ZERO:
		return [
			{
				"id": "emaciated_man",
				"pos": Vector2i(4, 3)
			}
		]
	if room_type in [MERCHANT_SCAVENGER, LEGACY_MERCHANT_BLACKSMITH, LEGACY_MERCHANT_ARCANIST]:
		return [
			{
				"id": MERCHANT_SCAVENGER,
				"pos": Vector2i(3, 4)
			}
		]
	return []

func _room_has_npcs(room: Dictionary) -> bool:
	return (room.get("npcs", []) as Array).size() > 0

func _clear_pre_battle_state(run_state: Dictionary) -> void:
	run_state.erase("pre_battle_pending")
	run_state.erase("pre_battle_travel_dir")
	run_state.erase("pre_battle_start")

func _room_blocks_exit_reveal(room: Dictionary) -> bool:
	var room_type: String = str(room.get("type", "combat"))
	if room_type not in ["combat", "boss"]:
		return false
	if bool(room.get("cleared", false)):
		return false
	if _room_has_npcs(room):
		return false
	return true

func _merge_room_metadata(seed: int, coord: Vector2i, stored_room: Dictionary) -> Dictionary:
	var room: Dictionary = _build_room_metadata(seed, coord)
	for key_var: Variant in stored_room.keys():
		var key: String = str(key_var)
		room[key] = stored_room[key_var]
	if not room.has("sealed"):
		room["sealed"] = false
	return room

# Each non-center depth is a square ring with literal cardinal adjacency.
func _room_connections(coord: Vector2i) -> Array[Dictionary]:
	if coord == Vector2i.ZERO:
		return [
			{"door_dir": Vector2i(0, -1), "coord": Vector2i(0, -1), "kind": "outward"},
			{"door_dir": Vector2i(1, 0), "coord": Vector2i(1, 0), "kind": "outward"},
			{"door_dir": Vector2i(0, 1), "coord": Vector2i(0, 1), "kind": "outward"},
			{"door_dir": Vector2i(-1, 0), "coord": Vector2i(-1, 0), "kind": "outward"}
		]
	var depth: int = _room_depth(coord)
	if depth <= 0 or depth > MAX_DEPTH:
		return []
	var ring: Array[Vector2i] = _ring_coords(depth)
	var index: int = _ring_index_for_coord(ring, coord)
	if index < 0:
		return []
	var previous_coord: Vector2i = ring[(index - 1 + ring.size()) % ring.size()]
	var next_coord: Vector2i = ring[(index + 1) % ring.size()]
	var connections: Array[Dictionary] = [
		{"door_dir": previous_coord - coord, "coord": previous_coord, "kind": "lateral"},
		{"door_dir": next_coord - coord, "coord": next_coord, "kind": "lateral"}
	]
	var inward_coord: Vector2i = _inward_source_for_room(coord)
	if inward_coord.x < 900:
		connections.append({"door_dir": inward_coord - coord, "coord": inward_coord, "kind": "inward"})
	if _room_can_link_outward(depth, index):
		var outward_coord: Vector2i = _outward_coord_for_room(coord)
		connections.append({"door_dir": outward_coord - coord, "coord": outward_coord, "kind": "outward"})
	return connections

func _connection_to(from_coord: Vector2i, destination: Vector2i) -> Dictionary:
	return _connection_to_room({"connections": _room_connections(from_coord)}, destination)

func _connection_to_room(room: Dictionary, destination: Vector2i) -> Dictionary:
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == destination:
			return connection.duplicate(true)
	return {}

func _ensure_loop_escape_connection(run_state: Dictionary, coord: Vector2i) -> void:
	var room: Dictionary = room_metadata(run_state, coord)
	if not _room_can_gain_loop_escape(room):
		return
	if _room_has_available_outward_move(run_state, room):
		return
	var attrition_offer: bool = (
		_visited_room_count_at_depth(run_state, int(room.get("depth", 0)))
		>= MAX_VISITED_ROOMS_BEFORE_OUTWARD_OFFER
	)
	if not attrition_offer and _room_has_progressive_available_move(run_state, room):
		return
	var outward_coord: Vector2i = _outward_coord_for_room(coord)
	if _room_depth(outward_coord) != int(room.get("depth", 0)) + 1:
		return
	var outward_connection: Dictionary = {
		"door_dir": outward_coord - coord,
		"coord": outward_coord,
		"kind": "outward",
		"loop_escape": not attrition_offer,
		"attrition_offer": attrition_offer
	}
	var connections: Array = (room.get("connections", []) as Array).duplicate(true)
	for connection_var: Variant in connections:
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == outward_coord:
			return
	connections.append(outward_connection)
	room["connections"] = connections
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	rooms[_room_key(coord)] = room
	var outward_key: String = _room_key(outward_coord)
	var outward_room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), outward_coord, rooms.get(outward_key, {}) as Dictionary)
	outward_room["revealed"] = true
	rooms[outward_key] = outward_room
	run_state["rooms"] = rooms

func _visited_room_count_at_depth(run_state: Dictionary, depth: int) -> int:
	var visited_count: int = 0
	for room_var: Variant in (run_state.get("rooms", {}) as Dictionary).values():
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_var as Dictionary
		if int(room.get("depth", -1)) == depth and bool(room.get("visited", false)):
			visited_count += 1
	return visited_count

func _room_can_gain_loop_escape(room: Dictionary) -> bool:
	var depth: int = int(room.get("depth", 0))
	if depth <= 0 or depth >= MAX_DEPTH:
		return false
	if str(room.get("type", "combat")) == "boss":
		return false
	return true

func _room_has_progressive_available_move(run_state: Dictionary, room: Dictionary) -> bool:
	var current_depth: int = int(room.get("depth", 0))
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		var candidate_room: Dictionary = room_metadata(run_state, candidate)
		if not bool(candidate_room.get("revealed", false)):
			continue
		if int(candidate_room.get("depth", 0)) < current_depth:
			continue
		if bool(candidate_room.get("sealed", false)):
			continue
		return true
	return false

func _room_has_available_outward_move(run_state: Dictionary, room: Dictionary) -> bool:
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var as Dictionary
		if str(connection.get("kind", "")) != "outward":
			continue
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		var candidate_room: Dictionary = room_metadata(run_state, candidate)
		if bool(candidate_room.get("revealed", false)) and not bool(candidate_room.get("sealed", false)):
			return true
	return false

func _sync_current_layout_doors(run_state: Dictionary, coord: Vector2i) -> void:
	if run_state.get("current_room", Vector2i.ZERO) != coord:
		return
	var layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", []).duplicate(true)
	if grid.is_empty():
		return
	var room: Dictionary = room_metadata(run_state, coord)
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var door_tile: Vector2i = RoomGeneratorScript.door_tile_for_direction(connection.get("door_dir", Vector2i.ZERO))
		if door_tile.x < 0 or door_tile.y < 0 or door_tile.y >= grid.size():
			continue
		var row: Array = (grid[door_tile.y] as Array).duplicate()
		if door_tile.x >= row.size():
			continue
		row[door_tile.x] = RoomGeneratorScript.TILE_DOOR
		grid[door_tile.y] = row
	layout["grid"] = grid
	run_state["current_room_layout"] = layout

func _ring_coords(depth: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if depth <= 0:
		return coords
	for y: int in range(-depth, depth + 1):
		coords.append(Vector2i(depth, y))
	for x: int in range(depth - 1, -depth - 1, -1):
		coords.append(Vector2i(x, depth))
	for y: int in range(depth - 1, -depth - 1, -1):
		coords.append(Vector2i(-depth, y))
	for x: int in range(-depth + 1, depth):
		coords.append(Vector2i(x, -depth))
	return coords

func _ring_index_for_coord(ring: Array[Vector2i], coord: Vector2i) -> int:
	for index: int in range(ring.size()):
		if ring[index] == coord:
			return index
	return -1

func _room_has_outward_link(depth: int, ring_index: int) -> bool:
	return depth > 0 and ring_index % 4 == 0

func _room_can_link_outward(depth: int, ring_index: int) -> bool:
	if depth <= 0 or depth >= MAX_DEPTH:
		return false
	if _is_sequence_boss_depth(depth):
		return true
	return _room_has_outward_link(depth, ring_index)

func _outward_coord_for_room(coord: Vector2i) -> Vector2i:
	return coord + _outward_dir_for_room(coord)

func _outward_dir_for_room(coord: Vector2i) -> Vector2i:
	var depth: int = _room_depth(coord)
	if coord == Vector2i(depth, -depth):
		return Vector2i(1, 0)
	if coord == Vector2i(depth, depth):
		return Vector2i(0, 1)
	if coord == Vector2i(-depth, depth):
		return Vector2i(-1, 0)
	if coord == Vector2i(-depth, -depth):
		return Vector2i(0, -1)
	if coord.x == depth:
		return Vector2i(1, 0)
	if coord.y == depth:
		return Vector2i(0, 1)
	if coord.x == -depth:
		return Vector2i(-1, 0)
	return Vector2i(0, -1)

func _inward_source_for_room(coord: Vector2i) -> Vector2i:
	var depth: int = _room_depth(coord)
	if depth <= 0:
		return Vector2i(999, 999)
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var candidate: Vector2i = coord + dir
		if _room_depth(candidate) != depth - 1:
			continue
		if candidate == Vector2i.ZERO:
			if coord in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				return candidate
			continue
		var previous_ring: Array[Vector2i] = _ring_coords(depth - 1)
		var previous_index: int = _ring_index_for_coord(previous_ring, candidate)
		if previous_index < 0 or not _room_can_link_outward(depth - 1, previous_index):
			continue
		if _outward_coord_for_room(candidate) == coord:
			return candidate
	return Vector2i(999, 999)

func _coord_hash(seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = seed
	value = int((value * 1664525 + 1013904223 + salt) & 0x7fffffff)
	value = int((value + coord.x * 73856093 + coord.y * 19349663) & 0x7fffffff)
	return value

func _stage_recovery_marker(run_state: Dictionary) -> void:
	var progression: Dictionary = (run_state.get("progression", {}) as Dictionary).duplicate(true)
	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	if marker.is_empty():
		return
	if int(run_state.get("run_index", 0)) != int(marker.get("available_run", -1)):
		return
	var coord: Vector2i = ProgressionStore.recovery_coord(progression)
	var amount: int = int(marker.get("amount", 0))
	if amount <= 0:
		return
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var key: String = _room_key(coord)
	var room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms.get(key, {}) as Dictionary)
	if coord != Vector2i.ZERO and str(room.get("type", "")) != "boss":
		room["type"] = "combat"
		room["element"] = _room_element_for_coord(int(run_state.get("seed", 0)), coord, "combat")
		room["npcs"] = []
		room["cleared"] = false
	room["recovery_marker"] = true
	room["recovery_amount"] = amount
	room["recovery_available_run"] = int(marker.get("available_run", 0))
	rooms[key] = room
	run_state["rooms"] = rooms

func _room_has_recovery_marker(room: Dictionary) -> bool:
	return bool(room.get("recovery_marker", false)) and int(room.get("recovery_amount", 0)) > 0

func _layout_with_recovery_loot(layout: Dictionary, room: Dictionary, run_state: Dictionary) -> Dictionary:
	if layout.is_empty() or not _room_has_recovery_marker(room):
		return layout
	var progression: Dictionary = (run_state.get("progression", {}) as Dictionary).duplicate(true)
	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	if marker.is_empty() or int(marker.get("available_run", -1)) != int(run_state.get("run_index", 0)):
		return layout
	if ProgressionStore.recovery_coord(progression) != layout.get("coord", Vector2i.ZERO):
		return layout
	var loot: Array = layout.get("loot", []).duplicate(true)
	for loot_var: Variant in loot:
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		if str((loot_var as Dictionary).get("kind", "")) == "dropped_embers":
			layout["loot"] = loot
			return layout
	var tile: Vector2i = _recovery_loot_tile(layout)
	if tile.x < 0:
		return layout
	loot.append({
		"id": "lost_embers_%d_%d" % [tile.x, tile.y],
		"kind": "dropped_embers",
		"amount": int(marker.get("amount", 0)),
		"pos": tile,
		"recovery_marker": true
	})
	layout["loot"] = loot
	return layout

func _recovery_loot_tile(layout: Dictionary) -> Vector2i:
	var grid: Array = layout.get("grid", [])
	var occupied: Dictionary = _layout_occupied_tiles(layout)
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	var center := Vector2(4.0, 4.0)
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			if occupied.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			var score: float = -tile.distance_to(center)
			score += float(_coord_hash(int(layout.get("depth", 0)), tile, 1307) % 1000) / 10000.0
			if score > best_score:
				best_score = score
				best_tile = tile
	return best_tile

func _layout_occupied_tiles(layout: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	occupied[layout.get("player_start", Vector2i.ZERO)] = true
	for enemy_var: Variant in layout.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy_var as Dictionary):
			occupied[tile] = true
	for npc_var: Variant in layout.get("npcs", []):
		if typeof(npc_var) == TYPE_DICTIONARY:
			occupied[(npc_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for trap_var: Variant in layout.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY:
			occupied[(trap_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for loot_var: Variant in layout.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY:
			occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for terrain_var: Variant in layout.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY:
			occupied[(terrain_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	return occupied

func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i(-1, -1))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _apply_recovered_embers_from_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var recovered_total: int = int(combat_state.get("recovered_embers_total", 0))
	var previous_total: int = int(run_state.get("recovered_embers_total", 0))
	if recovered_total <= previous_total:
		return run_state
	var delta: int = recovered_total - previous_total
	var next_state: Dictionary = add_held_embers(run_state, delta)
	next_state["recovered_embers_total"] = recovered_total
	var progression: Dictionary = (next_state.get("progression", {}) as Dictionary).duplicate(true)
	next_state["progression"] = ProgressionStore.clear_recovery_marker(progression)
	next_state["notice"] = "Recovered %d embers." % delta
	_clear_recovery_marker_on_current_room(next_state)
	return next_state

func _apply_collected_equipment_from_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = _repair_equipment_state(run_state)
	var added_names: Array = []
	for equipment_var: Variant in combat_state.get("collected_equipment", []):
		var equipment_id: String = str(equipment_var)
		if equipment_id.is_empty() or _run_has_equipment(next_state, equipment_id):
			continue
		var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
		inventory.append(equipment_id)
		next_state["equipment_inventory"] = inventory
		var collected: Array = next_state.get("collected_equipment", []).duplicate()
		if not collected.has(equipment_id):
			collected.append(equipment_id)
		next_state["collected_equipment"] = collected
		next_state = _mark_loadout_unread(next_state, "equipment", equipment_id)
		added_names.append(str(GameData.equipment_def(equipment_id).get("name", equipment_id)))
	if not added_names.is_empty():
		next_state["notice"] = "Found %s." % ", ".join(added_names)
	return next_state

func loadout_unread_ids(run_state: Dictionary, mode: String) -> Array:
	var key: String = _loadout_unread_key(mode)
	if key.is_empty():
		return []
	return _string_array(run_state.get(key, []))

func loadout_unread_count(run_state: Dictionary) -> int:
	return loadout_unread_ids(run_state, "equipment").size() + loadout_unread_ids(run_state, "magic").size()

func clear_loadout_unread(run_state: Dictionary, mode: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var key: String = _loadout_unread_key(mode)
	if not key.is_empty():
		next_state[key] = []
	return next_state

func loadout_new_asset_ids(run_state: Dictionary, mode: String) -> Array:
	var key: String = _loadout_new_asset_key(mode)
	if key.is_empty():
		return []
	return _string_array(run_state.get(key, []))

func loadout_asset_is_new(run_state: Dictionary, mode: String, asset_id: String) -> bool:
	return not asset_id.is_empty() and loadout_new_asset_ids(run_state, mode).has(asset_id)

func mark_loadout_asset_seen(run_state: Dictionary, mode: String, asset_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var key: String = _loadout_new_asset_key(mode)
	if key.is_empty() or asset_id.is_empty():
		return next_state
	var new_asset_ids: Array = _string_array(next_state.get(key, []))
	new_asset_ids.erase(asset_id)
	next_state[key] = new_asset_ids
	return next_state

func _mark_loadout_unread(run_state: Dictionary, mode: String, asset_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var key: String = _loadout_unread_key(mode)
	if key.is_empty() or asset_id.is_empty():
		return next_state
	var unread: Array = _string_array(next_state.get(key, []))
	if not unread.has(asset_id):
		unread.append(asset_id)
	next_state[key] = unread
	var new_asset_key: String = _loadout_new_asset_key(mode)
	var new_asset_ids: Array = _string_array(next_state.get(new_asset_key, []))
	if not new_asset_ids.has(asset_id):
		new_asset_ids.append(asset_id)
	next_state[new_asset_key] = new_asset_ids
	return next_state

func _loadout_unread_key(mode: String) -> String:
	if mode == "equipment":
		return UNREAD_LOADOUT_EQUIPMENT_KEY
	if mode == "magic":
		return UNREAD_LOADOUT_MAGIC_KEY
	return ""

func _loadout_new_asset_key(mode: String) -> String:
	if mode == "equipment":
		return NEW_LOADOUT_EQUIPMENT_KEY
	if mode == "magic":
		return NEW_LOADOUT_MAGIC_KEY
	return ""

func _clear_recovery_marker_on_current_room(run_state: Dictionary) -> void:
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var key: String = _room_key(coord)
	if not rooms.has(key):
		return
	var room: Dictionary = (rooms.get(key, {}) as Dictionary).duplicate(true)
	room.erase("recovery_marker")
	room.erase("recovery_amount")
	room.erase("recovery_available_run")
	rooms[key] = room
	run_state["rooms"] = rooms
