extends RefCounted
## Offline board setups for the four card keyword recordings.
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Checks = preload("res://tools/tooltip_loops/tip06_checks.gd")

const DETONATE: String = "detonate_fire"
const DISCHARGE: String = "discharge_network"
const SWAP: String = "swap_landing"
const WORLDSPINE: String = "worldspine_pulse"
const IDS: Array = [DETONATE, DISCHARGE, SWAP, WORLDSPINE]
const CARDS: Dictionary = {DETONATE: "inferno_ritual", DISCHARGE: "discharge", SWAP: "empty_husk", WORLDSPINE: "worldspine"}
const ACTION_TYPES: Dictionary = {DETONATE: "detonate", DISCHARGE: "discharge", SWAP: "illusion_swap", WORLDSPINE: "outcrop"}
const PLAIN_FLOOR_BIOME: String = "vyraketh"
const BIOMES: Dictionary = {DETONATE: PLAIN_FLOOR_BIOME, DISCHARGE: PLAIN_FLOOR_BIOME, SWAP: PLAIN_FLOOR_BIOME}
# Fixture positions use the established board patch.
const HERO := Vector2i(0, 2)
const DISCHARGE_HERO := Vector2i(1, 2)
const SWAP_HERO := Vector2i(1, 2)
const DETONATE_TARGET := Vector2i(1, 1)
const FIRE_TILES: Array[Vector2i] = Array([Vector2i(1, 1), Vector2i(2, 1)], TYPE_VECTOR2I, "", null)
const OVERLAP_ENEMY := Vector2i(2, 1)
const SINGLE_ENEMY := Vector2i(3, 1)
const NETWORK: Array[Vector2i] = Array([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)], TYPE_VECTOR2I, "", null)
const ON_NETWORK := Vector2i(1, 1)
const SWAP_LANDING := Vector2i(2, 1)
const WORLDSPINE_PATCH := Rect2i(0, 0, 5, 5)
const WORLDSPINE_HERO := Vector2i(0, 3)
const CAGE_CENTER := Vector2i(2, 2)
const TARGETS: Dictionary = {DETONATE: Combat.INVALID_TILE, DISCHARGE: ON_NETWORK, SWAP: SWAP_LANDING, WORLDSPINE: CAGE_CENTER}
const ENEMY: String = "crawler"
const ILLUSION_CARD: String = "mirror_image"

static func configure(layout: Dictionary, id: String) -> Dictionary:
	layout["player_start"] = SWAP_HERO if id == SWAP else HERO
	layout["element"] = {DETONATE: "fire", DISCHARGE: "none", SWAP: "none", WORLDSPINE: "earth"}[id]
	if id in [DISCHARGE, SWAP, WORLDSPINE]:
		layout["umbra_stage"] = Combat.UMBRA_STAGE_CLEAR
		layout.erase("umbra")
	var units: Array = []
	match id:
		DETONATE: units = [[ENEMY, OVERLAP_ENEMY], [ENEMY, SINGLE_ENEMY]]
		DISCHARGE:
			layout["player_start"] = DISCHARGE_HERO
			units = [[ENEMY, ON_NETWORK]]
		SWAP: layout["objective"] = {"type": Objectives.REACH_EXIT, "exits": []}
		WORLDSPINE:
			layout["player_start"] = WORLDSPINE_HERO
			# The full cage needs a floor path around all four Outcrops.
			var grid: Array = []
			for y: int in range(WORLDSPINE_PATCH.size.y):
				var row: Array = []
				row.resize(WORLDSPINE_PATCH.size.x)
				row.fill("stone")
				grid.append(row)
			layout["grid"] = grid
			units = [[ENEMY, CAGE_CENTER]]
	return {"card": CARDS[id], "units": units}

static func prepare(state: Dictionary, id: String) -> Dictionary:
	var engine := Combat.new()
	var room_source: Dictionary = {"actor_kind": "room"}
	match id:
		DETONATE:
			# Isolate the card's Detonate action after its targeting decision.
			state["last_action_target"] = DETONATE_TARGET
			for tile: Vector2i in FIRE_TILES: Surfaces.place(state, tile, "fire", room_source)
		DISCHARGE:
			for tile: Vector2i in NETWORK: Surfaces.place(state, tile, "electrified", room_source)
		SWAP:
			var summon: Dictionary = engine.card_play_actions(ILLUSION_CARD, state)[0]
			state = engine.apply_player_action(state, summon, SWAP_LANDING)
	return state

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var target: Vector2i = TARGETS[id]
	var action: Dictionary
	for candidate: Dictionary in engine.card_play_actions(fixture["card"], before):
		if candidate["type"] == ACTION_TYPES[id]:
			action = candidate
			break
	if action.is_empty() or not engine.player_action_can_resolve(before, action) or (engine.player_action_needs_target(action) and not engine.valid_targets_for_player_action(before, action).has(target)):
		return {"beats": [], "final": before}
	var working: Dictionary = engine.prepare_player_card(before, 0, "play") if id == WORLDSPINE else before
	var resolution: Dictionary = engine.resolve_player_action_for_presentation(working, action, target)
	var after: Dictionary = resolution["state"]
	var beats: Array[Dictionary]
	beats.append({"kind": "player", "before": before, "after": after, "action": action, "target": target, "chain_hits": resolution.get("chain_hits", []), "card": fixture["card"]})
	if id == WORLDSPINE:
		var actions: Array = engine.card_play_actions(fixture["card"], working)
		after = engine.finish_player_card(after, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})
		beats[0]["after"] = after
		var next_turn: Dictionary = engine.prepare_next_player_turn(after)
		beats.append({"kind": "worldspine_turn_start", "before": after, "after": next_turn})
		after = next_turn
	return {"beats": beats, "final": after}
