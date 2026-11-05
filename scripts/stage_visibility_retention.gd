extends RefCounted
## Animation ticks change motion/feedback while sight usually stays unchanged.
## Retain one owned result, validated against complete inputs on every call.
## Neither a state reference, a preview revision nor a hash proves equality:
## animation steps and test/catalog edits can mutate those inputs in place.

const GameData = preload("res://scripts/game_data.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const Depth = preload("res://scripts/depth_rules.gd")
const Encounters = preload("res://scripts/special_encounter_library.gd")
var _inputs: Array = []
var _result: Dictionary = {}

func clear() -> void:
	_inputs.clear()
	_result.clear()

func resolve(engine: RefCounted, state: Dictionary) -> Dictionary:
	var definitions: Array = []
	for enemy: Dictionary in state.get("enemies", []):
		definitions.append(GameData.enemies().get(str(enemy.get("type", "")), {}))
	var relics: Array = []
	for relic_id: Variant in state.get("relics", []):
		relics.append(GameData.relic_def(str(relic_id)))
	var special_type: String = str(state.get("objective", {}).get("special_type", ""))
	var inputs: Array = [engine, engine.get_script(), state, definitions, relics,
		engine._relic_effects(state), Skills.definitions(), Depth.modifier(state, "umbra_sight_delta"),
		Encounters.definition(special_type) if special_type in ["warband", "umbral_snare"] else {}]
	if _inputs != inputs:
		_result = _build(engine, state)
		_inputs = inputs.duplicate(true)
	# The animation path appends temporarily revealed actors to visible_enemy_ids.
	# Never lend that path (or a stage consumer) the retained arrays/dictionaries.
	return _result.duplicate(true)

func _build(engine: RefCounted, state: Dictionary) -> Dictionary:
	var visible_tiles: Array[Vector2i] = engine.umbra_visible_tiles(state)
	var lookup: Dictionary = {}
	for tile: Vector2i in visible_tiles:
		lookup[tile] = true
	var umbra: Dictionary = state.get("umbra", {}) as Dictionary
	var truesight: bool = engine.player_has_truesight(state)
	var activations: int = int(umbra.get("truesight_activations", 0))
	return {
		"umbra_stage": engine.effective_umbra_stage(state),
		"umbra_radius": engine.effective_umbra_radius(state),
		"umbra_visible_tiles": visible_tiles,
		"visible_enemy_ids": engine.visible_enemy_ids(state, lookup),
		"umbra_light_sources": engine.effective_light_sources(state),
		"umbra_truesight_activations": activations,
		"umbra_truesight": truesight,
		"umbra_vision_bonus_activations": int(umbra.get("vision_bonus_activations", 0)),
		"umbra_truesight_conditional": truesight and activations == 0,
	}
