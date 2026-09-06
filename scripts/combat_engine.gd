extends RefCounted
class_name CombatEngine

const BattlefieldItemRules = preload("res://scripts/battlefield_item_rules.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ElementalIntensityRules = preload("res://scripts/elemental_intensity_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")

const FATIGUE_BASE_DAMAGE: int = 2
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const BASE_PLAYER_MOVEMENT: int = 2
const MAX_HAND_SIZE: int = BattlefieldItemRules.MAX_HAND_SIZE
const MAX_LOG_LINES: int = 12
const PLAYER_BASE_INITIATIVE: int = 9
const PLAYER_MIN_INITIATIVE: int = 5
const ENEMY_MIN_INITIATIVE: int = 4
const DEFAULT_CARD_TIME_COST: int = 5
const MIN_CARD_TIME_COST: int = 1
const MAX_CARD_TIME_COST: int = 10
const DEFAULT_ENEMY_BASE_INITIATIVE: int = 12
const DEFAULT_ENEMY_INTENT_TIME_COST: int = 4
const DEFIANCE_RESTORE_FRACTION: float = 0.25
const DEFIANCE_EVENT_LIMIT: int = 16
const TURN_ORDER_PREVIEW_LIMIT: int = 8
const ELEMENTAL_INTENSITY_ROOM_BASE: int = 1
const DEPTHS_PER_SEQUENCE: int = 4
const FIRST_SECTION_UMBRA_START_STEP: int = DEPTHS_PER_SEQUENCE - 2
const UMBRA_STAGE_CLEAR: String = "clear"
const UMBRA_STAGE_FRINGE: String = "fringe"
const UMBRA_STAGE_ADVANCING: String = "advancing"
const UMBRA_STAGE_PRESSING: String = "pressing"
const UMBRA_STAGE_DEEP: String = "deep"
const UMBRA_STAGE_HEART: String = "heart"
const UMBRA_STAGE_ECLIPSE: String = "eclipse"
const UMBRA_UNLIMITED_RADIUS: int = 99
const UMBRA_STAGE_ORDER: Array[String] = [
	UMBRA_STAGE_CLEAR,
	UMBRA_STAGE_FRINGE,
	UMBRA_STAGE_ADVANCING,
	UMBRA_STAGE_PRESSING,
	UMBRA_STAGE_DEEP,
	UMBRA_STAGE_HEART,
	UMBRA_STAGE_ECLIPSE
]
const UMBRA_RADIUS_BY_STAGE := {
	UMBRA_STAGE_CLEAR: UMBRA_UNLIMITED_RADIUS,
	UMBRA_STAGE_FRINGE: 6,
	UMBRA_STAGE_ADVANCING: 5,
	UMBRA_STAGE_PRESSING: 4,
	UMBRA_STAGE_DEEP: 3,
	UMBRA_STAGE_HEART: 2,
	UMBRA_STAGE_ECLIPSE: 1
}
const ENEMY_HP_SCALE_PER_SEQUENCE: float = 0.08
const ENEMY_HP_FLAT_BONUS_PER_SEQUENCE: int = 0
const ENEMY_DAMAGE_BONUS_BY_SEQUENCE: Array[int] = [0, 1, 1, 2, 2, 3]
const ENEMY_SUPPORT_BONUS_BY_SEQUENCE: Array[int] = [0, 0, 1, 1, 2, 2]
const ENEMY_HP_SCALE_DEPTH_ONE: float = 0.85
const ENEMY_HP_SCALE_DEPTH_THREE: float = 1.12
const ENEMY_DAMAGE_DELTA_DEPTH_ONE: int = 0
const ENEMY_DAMAGE_DELTA_DEPTH_THREE: int = 0
const ENEMY_SUPPORT_DELTA_DEPTH_ONE: int = -1
const ENEMY_SUPPORT_DELTA_DEPTH_THREE: int = 0
const ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull"]
const BOSS_DAMAGE_ACTION_TYPES: Array[String] = ["terrain_burst", "cinder_marks", "detonate_cinders", "gale_force", "umbra_eclipse"]
const BOSS_PATTERN_ACTION_TYPES: Array[String] = ["terrain_burst", "cinder_marks", "detonate_cinders", "gale_force", "umbra_eclipse"]
const ENEMY_SUPPORT_ACTION_TYPES: Array[String] = ["heal_ally", "guard_ally"]
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const INTENSITY_BONUS_ADDITIVE_FIELDS := ["amount", "damage", "burn", "freeze", "shock", "poison", "bleed", "expose", "sunder", "chain", "push", "pull"]
const PLAYER_BLEED_TRIGGER_ACTION_TYPES := ["move", "melee", "ranged", "aoe", "push", "pull"]
const ENEMY_BLEED_TRIGGER_ACTION_TYPES := ["move_toward", "move_away", "melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "terrain_burst", "detonate_cinders", "gale_force", "umbra_eclipse"]
const ZEKARION_TYPE: String = "zekarion"
const LIGHTNING_WISP_TYPE: String = "lightning_wisp"
const DRAGON_SPIRE_KIND: String = "dragon_spire"
const CINDER_MARK_KIND: String = "cinder_mark"
const INVALID_TILE: Vector2i = Vector2i(-999999, -999999)
const ENEMY_PATH_TEMPORARY_BLOCKER_TURN_COST: int = 1
const ENEMY_PATH_TRAP_BASE_PENALTY: int = 1000
const ENEMY_TACTICAL_SCORE_WINDOW: int = 32
const ENEMY_TACTICAL_THREAT_DISTANCE: int = 5
const ENEMY_TACTICAL_CLOSE_DISTANCE: int = 2
const DEFAULT_AOE_PATTERN: Array = [
	[0, 0],
	[1, 0],
	[-1, 0],
	[0, 1],
	[0, -1]
]
const TRAP_BLAST_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1)
]

const RUN_STAT_ENEMIES_KILLED: String = "enemies_killed"
const RUN_STAT_DAMAGE_DEALT: String = "damage_dealt"
const RUN_STAT_DAMAGE_RECEIVED: String = "damage_received"

# Relic ownership is stable throughout a combat, while virtually every action
# hook asks for the same expanded effect definitions. Keep that immutable
# expansion on the engine instead of deep-copying every effect for every target,
# preview, status hook, and death hook.
var _relic_effect_cache_key: String = ""
var _relic_effect_cache: Array[Dictionary] = []
var _runtime_performance_instrumentation_enabled: bool = false
var _runtime_performance_totals_usec: Dictionary = {}
var _runtime_performance_counts: Dictionary = {}
var _runtime_performance_max_usec: Dictionary = {}
var _runtime_performance_interval_sink: Callable = Callable()

func set_runtime_performance_interval_sink(sink: Callable) -> void:
	_runtime_performance_interval_sink = sink

func set_runtime_performance_instrumentation_enabled(enabled: bool) -> void:
	_runtime_performance_instrumentation_enabled = enabled
	_runtime_performance_totals_usec.clear()
	_runtime_performance_counts.clear()
	_runtime_performance_max_usec.clear()

func runtime_performance_instrumentation_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for phase_var: Variant in _runtime_performance_totals_usec.keys():
		var phase: String = str(phase_var)
		var count: int = int(_runtime_performance_counts.get(phase, 0))
		result[phase] = {
			"count": count,
			"total_usec": int(_runtime_performance_totals_usec.get(phase, 0)),
			"max_usec": int(_runtime_performance_max_usec.get(phase, 0)),
			"usec_per_call": (
				float(_runtime_performance_totals_usec.get(phase, 0)) / float(count)
				if count > 0
				else 0.0
			),
		}
	return result

func clear_runtime_performance_instrumentation_snapshot() -> void:
	_runtime_performance_totals_usec.clear()
	_runtime_performance_counts.clear()
	_runtime_performance_max_usec.clear()

func _record_runtime_performance_phase(phase: String, started_usec: int) -> int:
	if not _runtime_performance_instrumentation_enabled:
		return 0
	var measured_end_usec: int = Time.get_ticks_usec()
	var elapsed_usec: int = measured_end_usec - started_usec
	_runtime_performance_totals_usec[phase] = int(_runtime_performance_totals_usec.get(phase, 0)) + elapsed_usec
	_runtime_performance_counts[phase] = int(_runtime_performance_counts.get(phase, 0)) + 1
	_runtime_performance_max_usec[phase] = maxi(int(_runtime_performance_max_usec.get(phase, 0)), elapsed_usec)
	if _runtime_performance_interval_sink.is_valid():
		_runtime_performance_interval_sink.call("engine_%s" % phase, started_usec, measured_end_usec, false)
		var bookkeeping_end_usec: int = Time.get_ticks_usec()
		_runtime_performance_interval_sink.call("telemetry_engine_record_overhead", measured_end_usec, bookkeeping_end_usec, true)
	return Time.get_ticks_usec()

static func default_run_stats() -> Dictionary:
	return {
		RUN_STAT_ENEMIES_KILLED: 0,
		RUN_STAT_DAMAGE_DEALT: 0,
		RUN_STAT_DAMAGE_RECEIVED: 0
	}

static func normalized_run_stats(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
	return {
		RUN_STAT_ENEMIES_KILLED: maxi(0, int(source.get(RUN_STAT_ENEMIES_KILLED, 0))),
		RUN_STAT_DAMAGE_DEALT: maxi(0, int(source.get(RUN_STAT_DAMAGE_DEALT, 0))),
		RUN_STAT_DAMAGE_RECEIVED: maxi(0, int(source.get(RUN_STAT_DAMAGE_RECEIVED, 0)))
	}

static func umbra_stage_for_section(section_index: int) -> String:
	# Five elemental-dragon sections build toward the separate Shadow Dragon
	# section. Eclipse is reserved for authored boss actions/fixtures.
	return UMBRA_STAGE_ORDER[clampi(section_index, 0, UMBRA_STAGE_ORDER.size() - 2)]

static func umbra_stage_for_section_depth(section_index: int, room_depth: int) -> String:
	var section_stage: String = umbra_stage_for_section(section_index)
	if section_index != 0:
		return section_stage
	var section_step: int = posmod(maxi(1, room_depth) - 1, DEPTHS_PER_SEQUENCE) + 1
	if section_step >= FIRST_SECTION_UMBRA_START_STEP:
		return UMBRA_STAGE_FRINGE
	return section_stage

static func umbra_stage_for_room_depth(room_depth: int) -> String:
	var section_index: int = int((maxi(1, room_depth) - 1) / DEPTHS_PER_SEQUENCE)
	return umbra_stage_for_section_depth(section_index, room_depth)

static func umbra_stage_index(stage_id: String) -> int:
	var index: int = UMBRA_STAGE_ORDER.find(str(stage_id))
	return index if index >= 0 else 0

static func umbra_radius_for_stage(stage_id: String) -> int:
	return int(UMBRA_RADIUS_BY_STAGE.get(str(stage_id), UMBRA_UNLIMITED_RADIUS))

static func umbra_stage_display_name(stage_id: String) -> String:
	match str(stage_id):
		UMBRA_STAGE_FRINGE:
			return "Fringe"
		UMBRA_STAGE_ADVANCING:
			return "Advancing"
		UMBRA_STAGE_PRESSING:
			return "Pressing"
		UMBRA_STAGE_DEEP:
			return "Deep"
		UMBRA_STAGE_HEART:
			return "Heart"
		UMBRA_STAGE_ECLIPSE:
			return "Eclipse"
	return "Clear"

func _initial_umbra_state(room_layout: Dictionary) -> Dictionary:
	var room_depth: int = int(room_layout.get("depth", 1))
	var room_type: String = str(room_layout.get("type", "combat"))
	var stage_id: String = UMBRA_STAGE_CLEAR
	if room_type in ["combat", "boss"]:
		if room_layout.has("umbra_section_index"):
			stage_id = umbra_stage_for_section(int(room_layout.get("umbra_section_index", 0)))
		elif room_layout.has("section_index"):
			stage_id = umbra_stage_for_section_depth(int(room_layout.get("section_index", 0)), room_depth)
		else:
			stage_id = umbra_stage_for_room_depth(room_depth)
	if room_layout.has("umbra_stage"):
		stage_id = str(room_layout.get("umbra_stage", stage_id))
	var source: Dictionary = room_layout.get("umbra", {}) as Dictionary
	if source.has("stage"):
		stage_id = str(source.get("stage", stage_id))
	if not UMBRA_STAGE_ORDER.has(stage_id):
		stage_id = UMBRA_STAGE_CLEAR
	return {
		"stage": stage_id,
		"boss_eclipse_stage": str(source.get("boss_eclipse_stage", "")),
		"boss_eclipse_activations": maxi(0, int(source.get("boss_eclipse_activations", 0))),
		"stage_reduction": maxi(0, int(source.get("stage_reduction", 0))),
		"vision_bonus": maxi(0, int(source.get("vision_bonus", 0))),
		"vision_bonus_activations": int(source.get("vision_bonus_activations", 0)),
		"truesight_activations": int(source.get("truesight_activations", 0)),
		"light_sources": (source.get("light_sources", []) as Array).duplicate(true),
		"next_light_source_id": maxi(1, int(source.get("next_light_source_id", 1))),
		"movement_interrupted_total": maxi(0, int(source.get("movement_interrupted_total", 0))),
		"tiles_illuminated_total": maxi(0, int(source.get("tiles_illuminated_total", 0))),
		"enemies_revealed_total": maxi(0, int(source.get("enemies_revealed_total", 0))),
		"hidden_attack_damage_received_total": maxi(0, int(source.get("hidden_attack_damage_received_total", 0)))
	}

func effective_umbra_stage(state: Dictionary) -> String:
	var umbra: Dictionary = state.get("umbra", {}) as Dictionary
	var base_stage: String = str(umbra.get("stage", UMBRA_STAGE_CLEAR))
	if int(umbra.get("boss_eclipse_activations", 0)) > 0:
		base_stage = str(umbra.get("boss_eclipse_stage", UMBRA_STAGE_ECLIPSE))
	var base_index: int = umbra_stage_index(base_stage)
	var reduction: int = maxi(0, int(umbra.get("stage_reduction", 0))) + _light_source_umbra_suppression(state)
	return UMBRA_STAGE_ORDER[maxi(0, base_index - reduction)]

func effective_umbra_radius(state: Dictionary) -> int:
	var stage_id: String = effective_umbra_stage(state)
	var base_radius: int = umbra_radius_for_stage(stage_id)
	if base_radius >= UMBRA_UNLIMITED_RADIUS:
		return UMBRA_UNLIMITED_RADIUS
	var umbra: Dictionary = state.get("umbra", {}) as Dictionary
	return base_radius + maxi(0, int(umbra.get("vision_bonus", 0)))

func umbra_visible_tiles(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid: Array = state.get("grid", [])
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var personal_radius: int = effective_umbra_radius(state)
	var sources: Array[Dictionary] = _effective_light_sources(state)
	for y: int in range(grid.size()):
		var row: Array = grid[y] as Array
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			var visible: bool = personal_radius >= UMBRA_UNLIMITED_RADIUS or PathUtils.manhattan(player_pos, tile) <= personal_radius
			if not visible:
				for source: Dictionary in sources:
					var source_pos: Vector2i = source.get("pos", Vector2i(-999, -999))
					if PathUtils.manhattan(source_pos, tile) <= maxi(0, int(source.get("radius", 0))):
						visible = true
						break
			if visible:
				result.append(tile)
	return result

func umbra_visible_tile_lookup(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in umbra_visible_tiles(state):
		result[tile] = true
	return result

func is_tile_visible_to_player(state: Dictionary, tile: Vector2i, visible_lookup: Dictionary = {}) -> bool:
	if not visible_lookup.is_empty():
		return visible_lookup.has(tile)
	if effective_umbra_radius(state) >= UMBRA_UNLIMITED_RADIUS:
		return true
	return umbra_visible_tiles(state).has(tile)

func is_enemy_visible_to_player(state: Dictionary, enemy: Dictionary, visible_lookup: Dictionary = {}) -> bool:
	if int(enemy.get("hp", 0)) <= 0:
		return false
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	if bool(definition.get("boss_bar", false)):
		return true
	if _player_has_truesight(state):
		return true
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		if is_tile_visible_to_player(state, tile, visible_lookup):
			return true
	return false

func _player_has_truesight(state: Dictionary) -> bool:
	var umbra: Dictionary = state.get("umbra", {}) as Dictionary
	if int(umbra.get("truesight_activations", 0)) != 0:
		return true
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("light_grants_truesight")
	if skill_id.is_empty() or not has_skill(state, skill_id):
		return false
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", INVALID_TILE)
	return _light_source_covers_tile(state, player_pos)

func player_has_truesight(state: Dictionary) -> bool:
	return _player_has_truesight(state)

func _effective_light_sources(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = _dictionary_values([])
	for source_var: Variant in (state.get("umbra", {}) as Dictionary).get("light_sources", []):
		if typeof(source_var) == TYPE_DICTIONARY:
			result.append((source_var as Dictionary).duplicate(true))
	var contributors: Array[Dictionary] = _illusion_light_contributors(state)
	var aura_radius: int = _illusion_light_radius_from_contributors(contributors)
	if aura_radius <= 0:
		return result
	for illusion: Dictionary in _live_illusions(state):
		result.append({
			"id": "illusion:%d" % int(illusion.get("id", -1)),
			"pos": illusion.get("pos", INVALID_TILE),
			"radius": aura_radius,
			"remaining_activations": -1,
			"tethered": true,
			"radius_contributors": contributors.duplicate(true)
		})
	return result

func effective_light_source_count(state: Dictionary) -> int:
	return _effective_light_sources(state).size()

func effective_light_sources(state: Dictionary) -> Array[Dictionary]:
	return _effective_light_sources(state)

func tethered_light_source_count(state: Dictionary) -> int:
	var count: int = 0
	for source: Dictionary in _effective_light_sources(state):
		if bool(source.get("tethered", false)):
			count += 1
	return count

func light_source_umbra_suppression(state: Dictionary) -> int:
	return _light_source_umbra_suppression(state)

func _illusion_light_radius(state: Dictionary) -> int:
	return _illusion_light_radius_from_contributors(_illusion_light_contributors(state))

func _illusion_light_contributors(state: Dictionary) -> Array[Dictionary]:
	var contributors: Array[Dictionary] = _dictionary_values([])
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("illusion_light")
	if not skill_id.is_empty() and has_skill(state, skill_id):
		contributors.append({
			"id": skill_id,
			"name": SkillTreeLibrary.display_name(skill_id),
			"radius": int(SkillTreeLibrary.effect(skill_id).get("radius", 1))
		})
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) == "illusion_light_aura":
			var relic_id: String = str(effect.get("relic_id", ""))
			var relic: Dictionary = GameData.relic_def(relic_id)
			contributors.append({
				"id": relic_id,
				"name": str(relic.get("name", relic_id.capitalize())),
				"radius": int(effect.get("radius", 1))
			})
	return contributors

func _illusion_light_radius_from_contributors(contributors: Array[Dictionary]) -> int:
	var radius: int = 0
	for contributor: Dictionary in contributors:
		radius += maxi(0, int(contributor.get("radius", 0)))
	return radius

func _light_source_umbra_suppression(state: Dictionary) -> int:
	var source_count: int = _effective_light_sources(state).size()
	var suppression: int = 0
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) != "light_source_umbra_suppression":
			continue
		var thresholds: Array = effect.get("thresholds", []) as Array
		var stages: Array = effect.get("stages", []) as Array
		for index: int in range(mini(thresholds.size(), stages.size())):
			if source_count >= int(thresholds[index]):
				suppression = maxi(suppression, int(stages[index]))
	return suppression

func visible_enemy_ids(state: Dictionary, visible_lookup: Dictionary = {}) -> Array[int]:
	var result: Array[int] = []
	if visible_lookup.is_empty():
		visible_lookup = umbra_visible_tile_lookup(state)
	for enemy: Dictionary in _live_enemies(state):
		if is_enemy_visible_to_player(state, enemy, visible_lookup):
			result.append(int(enemy.get("id", -1)))
	return result

func umbra_shadow_tiles(state: Dictionary) -> Array[Vector2i]:
	var visible_lookup: Dictionary = {}
	for tile: Vector2i in umbra_visible_tiles(state):
		visible_lookup[tile] = true
	var result: Array[Vector2i] = []
	var grid: Array = state.get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			if not visible_lookup.has(tile):
				result.append(tile)
	return result

func run_stats(state: Dictionary) -> Dictionary:
	return normalized_run_stats(state.get("run_stats", {}))

func skill_ids(state: Dictionary) -> Array[String]:
	return SkillTreeLibrary.normalized_ids(state.get("skill_ids", []))

func has_skill(state: Dictionary, skill_id: String) -> bool:
	return skill_ids(state).has(skill_id)

func skill_was_used(state: Dictionary, skill_id: String) -> bool:
	return bool((state.get("skill_flags", {}) as Dictionary).get("used:%s" % skill_id, false))

func _skill_charge_available(state: Dictionary, skill_id: String) -> bool:
	return has_skill(state, skill_id) and not skill_was_used(state, skill_id)

func skill_is_ready(state: Dictionary, skill_id: String) -> bool:
	if not has_skill(state, skill_id) or skill_was_used(state, skill_id) or combat_outcome(state) != "":
		return false
	match SkillTreeLibrary.effect_type(skill_id):
		"discard_draw":
			return is_player_turn(state) and not (((state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty())
		"discard_recall":
			if not is_player_turn(state) or (((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() >= MAX_HAND_SIZE):
				return false
			return _latest_non_item_discard_index(state) >= 0
		"arm_intensity":
			return (
				is_player_turn(state)
				and not bool((state.get("skill_flags", {}) as Dictionary).get("prismatic_armed", false))
				and not prismatic_target_hand_indices(state).is_empty()
			)
		"preserve_burn":
			return (
				is_player_turn(state)
				and not bool((state.get("skill_flags", {}) as Dictionary).get("burn_preserve_armed", false))
				and _hand_has_non_item_burn(state)
			)
		"preserve_item":
			return (
				is_player_turn(state)
				and not bool((state.get("skill_flags", {}) as Dictionary).get("item_preserve_armed", false))
				and _hand_has_item(state)
			)
		"convert_block":
			var player: Dictionary = state.get("player", {}) as Dictionary
			return (
				is_player_turn(state)
				and int(player.get("block", 0)) > 0
				and not bool((state.get("skill_flags", {}) as Dictionary).get("guard_carry_armed", false))
			)
		"arm_movement_blink":
			if not is_player_turn(state) or player_movement_remaining(state) <= 0:
				return false
			if bool((state.get("skill_flags", {}) as Dictionary).get("movement_blink_armed", false)):
				return false
			var effect: Dictionary = SkillTreeLibrary.effect(skill_id)
			var blink_action: Dictionary = {
				"type": "blink",
				"range": mini(player_movement_remaining(state), maxi(1, int(effect.get("range", 0)))),
				"_movement_pool": true
			}
			return player_action_can_resolve(state, blink_action) and not valid_targets_for_player_action(state, blink_action).is_empty()
	return true

func manual_skill_states(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for skill_id: String in skill_ids(state):
		if SkillTreeLibrary.activation_kind(skill_id) != "manual":
			continue
		result.append({
			"skill_id": skill_id,
			"name": SkillTreeLibrary.display_name(skill_id),
			"description": SkillTreeLibrary.description(skill_id),
			"ready": skill_is_ready(state, skill_id),
			"used": skill_was_used(state, skill_id)
		})
	return result

func use_quick_wits(state: Dictionary, hand_index: int) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("discard_draw")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	if hand_index < 0 or hand_index >= hand.size():
		return next_state
	var hand_was_full: bool = hand.size() >= MAX_HAND_SIZE
	var card_id: String = str(hand[hand_index])
	hand.remove_at(hand_index)
	var discard: Array = (deck.get("discard", []) as Array).duplicate()
	discard.append(card_id)
	deck["hand"] = hand
	deck["discard"] = discard
	next_state["deck"] = deck
	# Resolve a primed Pain Remembers while the discarded card still has a stable
	# identity and location. Otherwise a Quick Wits draw that starts a deck cycle
	# can shuffle the promised card out of discard before the recall sees it.
	# At the hand cap, keep prioritizing Quick Wits' replacement draw and leave the
	# recall primed until a later discard has room, matching the normal cap policy.
	if not hand_was_full:
		next_state = _maybe_trigger_pain_recall(next_state, card_id)
	next_state = _draw_cards_in_place(next_state, 1)
	if hand_was_full:
		next_state = _maybe_trigger_pain_recall(next_state, card_id)
	_mark_skill_used(next_state, skill_id, "%s trades one possibility for another." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func use_encore(state: Dictionary, discard_index: int) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("discard_recall")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
	var discard: Array = (deck.get("discard", []) as Array).duplicate()
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	if discard_index < 0 or discard_index >= discard.size() or hand.size() >= MAX_HAND_SIZE:
		return next_state
	var card_id: String = str(discard[discard_index])
	if GameData.card_is_item(card_id):
		return next_state
	discard.remove_at(discard_index)
	hand.append(card_id)
	deck["discard"] = discard
	deck["hand"] = hand
	next_state["deck"] = deck
	_mark_skill_used(next_state, skill_id, "%s returns %s to hand." % [SkillTreeLibrary.display_name(skill_id), str(card_def(card_id, next_state).get("name", card_id))])
	return next_state

func prismatic_target_hand_indices(state: Dictionary) -> Array[int]:
	var result: Array[int]
	var seen_card_ids: Dictionary = {}
	var hand: Array = ((state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for index: int in range(hand.size()):
		var card_id: String = str(hand[index])
		if seen_card_ids.has(card_id) or not _card_has_intensity_condition(card_def(card_id, state)):
			continue
		seen_card_ids[card_id] = true
		result.append(index)
	return result

func _hand_has_non_item_burn(state: Dictionary) -> bool:
	var hand: Array = ((state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for card_id_var: Variant in hand:
		var card_id: String = str(card_id_var)
		if bool(card_def(card_id, state).get("burn", false)) and not GameData.card_is_item(card_id):
			return true
	return false

func _hand_has_item(state: Dictionary) -> bool:
	var hand: Array = ((state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for card_id_var: Variant in hand:
		if GameData.card_is_item(str(card_id_var)):
			return true
	return false

func arm_prismatic_instinct(state: Dictionary, hand_index: int) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("arm_intensity")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var hand: Array = ((state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	if hand_index < 0 or hand_index >= hand.size() or not prismatic_target_hand_indices(state).has(hand_index):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	var card_id: String = str(hand[hand_index])
	_set_skill_flag(next_state, "prismatic_armed", true)
	_set_skill_flag(next_state, "prismatic_target_card_id", card_id)
	_erase_skill_flag(next_state, "prismatic_resolving")
	_mark_skill_used(next_state, skill_id, "%s arms %s." % [SkillTreeLibrary.display_name(skill_id), str(card_def(card_id, next_state).get("name", card_id))])
	return next_state

func arm_rehearsed_escape(state: Dictionary) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("preserve_burn")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	_set_skill_flag(next_state, "burn_preserve_armed", true)
	_log(next_state, "%s is armed for the next non-item Burn card." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func arm_makeshift_tool(state: Dictionary) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("preserve_item")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	_set_skill_flag(next_state, "item_preserve_armed", true)
	_log(next_state, "%s is armed for the next item played." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func arm_ghost_stride(state: Dictionary) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("arm_movement_blink")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	_set_skill_flag(next_state, "movement_blink_armed", true)
	_log(next_state, "%s is armed for the next movement." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func arm_carry_the_guard(state: Dictionary) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("convert_block")
	if not skill_is_ready(state, skill_id):
		return state.duplicate(true)
	var next_state: Dictionary = state.duplicate(true)
	_set_skill_flag(next_state, "guard_carry_armed", true)
	_log(next_state, "%s is armed to carry block remaining at turn end." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func prepare_player_card(state: Dictionary, hand_index: int, play_mode: String = "play") -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	_erase_skill_flag(next_state, "prismatic_resolving")
	if play_mode != "play":
		return next_state
	var hand: Array = ((next_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	if hand_index < 0 or hand_index >= hand.size():
		return next_state
	var flags: Dictionary = next_state.get("skill_flags", {}) as Dictionary
	var card_id: String = str(hand[hand_index])
	if bool(flags.get("prismatic_armed", false)) and str(flags.get("prismatic_target_card_id", "")) == card_id:
		_set_skill_flag(next_state, "prismatic_resolving", true)
	return next_state

func skill_events(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for event_var: Variant in state.get("skill_events", []):
		if typeof(event_var) == TYPE_DICTIONARY:
			result.append((event_var as Dictionary).duplicate(true))
	return result

func defiance_events(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for event_var: Variant in state.get("defiance_events", []):
		if typeof(event_var) == TYPE_DICTIONARY:
			result.append((event_var as Dictionary).duplicate(true))
	return result

func _skill_flags(state: Dictionary) -> Dictionary:
	return (state.get("skill_flags", {}) as Dictionary).duplicate(true)

func _set_skill_flag(state: Dictionary, flag_id: String, value: Variant) -> void:
	var flags: Dictionary = _skill_flags(state)
	flags[flag_id] = value
	state["skill_flags"] = flags

func _erase_skill_flag(state: Dictionary, flag_id: String) -> void:
	var flags: Dictionary = _skill_flags(state)
	flags.erase(flag_id)
	state["skill_flags"] = flags

func _mark_skill_used(state: Dictionary, skill_id: String, message: String) -> void:
	_set_skill_flag(state, "used:%s" % skill_id, true)
	_record_skill_event(state, skill_id, message)

func _record_skill_event(state: Dictionary, skill_id: String, message: String) -> void:
	var events: Array = (state.get("skill_events", []) as Array).duplicate(true)
	var revision: int = int(state.get("skill_event_revision", 0)) + 1
	events.append({
		"revision": revision,
		"skill_id": skill_id,
		"name": SkillTreeLibrary.display_name(skill_id),
		"message": message,
		"turn": int(state.get("turn", 1))
	})
	while events.size() > 16:
		events.pop_front()
	state["skill_events"] = events
	state["skill_event_revision"] = revision
	if not message.is_empty():
		_log(state, message)

func _latest_non_item_discard_index(state: Dictionary) -> int:
	var discard: Array = ((state.get("deck", {}) as Dictionary).get("discard", []) as Array)
	for index: int in range(discard.size() - 1, -1, -1):
		if not GameData.card_is_item(str(discard[index])):
			return index
	return -1

func _recall_latest_non_item_discard(state: Dictionary, draw_top_when_full: bool = false) -> Dictionary:
	var next_state: Dictionary = state
	var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
	var discard: Array = (deck.get("discard", []) as Array).duplicate()
	var index: int = _latest_non_item_discard_index(next_state)
	if index < 0 or index >= discard.size():
		return next_state
	var card_id: String = str(discard[index])
	discard.remove_at(index)
	deck["discard"] = discard
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	if hand.size() < MAX_HAND_SIZE:
		hand.append(card_id)
		deck["hand"] = hand
	elif draw_top_when_full:
		var draw: Array = (deck.get("draw", []) as Array).duplicate()
		draw.append(card_id)
		deck["draw"] = draw
	else:
		discard.append(card_id)
		deck["discard"] = discard
	next_state["deck"] = deck
	return next_state

func _maybe_trigger_pain_recall(state: Dictionary, discarded_card_id: String) -> Dictionary:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("pain_recall")
	var flags: Dictionary = state.get("skill_flags", {}) as Dictionary
	if not has_skill(state, skill_id) or skill_was_used(state, skill_id) or not bool(flags.get("pain_recall_primed", false)):
		return state
	if GameData.card_is_item(discarded_card_id):
		return state
	if (((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() >= MAX_HAND_SIZE):
		return state
	if _latest_non_item_discard_index(state) < 0:
		return state
	var next_state: Dictionary = _recall_latest_non_item_discard(state)
	_set_skill_flag(next_state, "pain_recall_primed", false)
	_mark_skill_used(next_state, skill_id, "%s returns the discarded card." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func create_combat(run_seed: int, room_layout: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combat_seed(run_seed, room_layout.get("coord", Vector2i.ZERO))
	var deck_cards: Array = player_snapshot.get("deck_cards", []).duplicate()
	var draw_pile: Array[String] = GameData.shuffle_cards(deck_cards, rng)
	var player: Dictionary = _normalized_player({
		"pos": room_layout.get("player_start", Vector2i.ZERO),
		"hp": int(player_snapshot.get("hp", 1)),
		"max_hp": int(player_snapshot.get("max_hp", 1)),
		"block": 0,
		"stoneskin": 0
	})
	var relic_ids: Array = player_snapshot.get("relics", []).duplicate()
	player["block"] = int(player.get("block", 0)) + GameData.stat_bonus_from_relics(relic_ids, "start_combat_block")
	player["stoneskin"] = int(player.get("stoneskin", 0)) + GameData.stat_bonus_from_relics(relic_ids, "start_combat_stoneskin")
	var enemies: Array[Dictionary] = []
	for enemy_var: Variant in room_layout.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		enemies.append(_normalized_enemy(enemy_var as Dictionary))
	var state: Dictionary = {
		"room_name": str(room_layout.get("name", "Room")),
		"room_coord": room_layout.get("coord", Vector2i.ZERO),
		"room_depth": int(room_layout.get("depth", 1)),
		"room_type": str(room_layout.get("type", "combat")),
		"boss_id": str(room_layout.get("boss_id", "")),
		"objective": (room_layout.get("objective", {}) as Dictionary).duplicate(true),
		"room_element": str(room_layout.get("element", ElementData.NONE)),
		"elemental_intensity": _initial_elemental_intensity(str(room_layout.get("element", ElementData.NONE))),
		"elemental_intensity_gained_total": _empty_elemental_intensity(),
		"elemental_intensity_spent_total": _empty_elemental_intensity(),
		"grid": room_layout.get("grid", []).duplicate(true),
		"moss": room_layout.get("moss", {}).duplicate(true),
		"player": player,
		"enemies": enemies,
		"illusions": [],
		"next_illusion_id": 1,
		"traps": room_layout.get("traps", []).duplicate(true),
		"loot": BattlefieldItemRules.normalized_loot(room_layout.get("loot", [])),
		"equipped_items": player_snapshot.get("equipped_items", BattlefieldItemRules.active_items_from_deck({"draw": deck_cards})).duplicate(),
		"item_inventory": player_snapshot.get("item_inventory", []).duplicate(),
		"terrain": room_layout.get("terrain", []).duplicate(true),
		"umbra": _initial_umbra_state(room_layout),
		"relics": relic_ids,
		"skill_ids": SkillTreeLibrary.normalized_ids(player_snapshot.get("skill_ids", [])),
		"skill_flags": {},
		"skill_events": [],
		"defiance_capacity": maxi(0, int(player_snapshot.get("defiance_capacity", 0))),
		"defiance_remaining": clampi(
			int(player_snapshot.get("defiance_remaining", 0)),
			0,
			maxi(0, int(player_snapshot.get("defiance_capacity", 0)))
		),
		"defiance_events": [],
		"defiance_event_revision": 0,
		"banked_plays": 0,
		"banked_play_active": 0,
		"banked_play_spent_this_activation": 0,
		"level": int(player_snapshot.get("level", 1)),
		"hand_size": int(player_snapshot.get("hand_size", 5)) + GameData.stat_bonus_from_relics(relic_ids, "hand_size_bonus"),
		"cards_per_turn": int(player_snapshot.get("cards_per_turn", BASE_CARDS_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "cards_per_turn_bonus"),
		"draw_per_turn": int(player_snapshot.get("draw_per_turn", BASE_DRAW_PER_TURN)) + GameData.stat_bonus_from_relics(relic_ids, "draw_per_turn_bonus"),
		"cards_played_this_turn": 0,
		"player_movement_capacity": BASE_PLAYER_MOVEMENT + GameData.stat_bonus_from_relics(relic_ids, "movement_pool_bonus"),
		"player_movement_remaining": BASE_PLAYER_MOVEMENT + GameData.stat_bonus_from_relics(relic_ids, "movement_pool_bonus"),
		"death_bonus_card_plays_this_turn": 0,
		"card_play_bonus_this_turn": 0,
		"pending_relic_card_plays": 0,
		"player_turn_ending": false,
		"heal_bonus": int(player_snapshot.get("heal_bonus", 0)),
		"deck": {
			"draw": draw_pile,
			"hand": [],
			"discard": [],
			"burned": [],
			"consumed": [],
			"draw_revision": 0,
			"cycles": 0,
			"fatigue_base": FATIGUE_BASE_DAMAGE
		},
		"turn": 1,
		"initiative_clock": 0,
		"activation_seq": 0,
		"current_actor": _player_actor_entry(0, 0),
		"turn_queue": [],
		"player_turn_time_spent": 0,
		"player_turn_restrictions": {
			"frozen": false,
			"shocked": false,
			"immobilized": false
		},
		"pending_player_trap_restriction": "",
		"turn_flags": {
			"first_attack_bonus_used": false,
			"first_move_bonus_used": false
		},
		"relic_flags": {},
		"zekarion_summon_waves": 0,
		"run_stats": normalized_run_stats(player_snapshot.get("run_stats", {})),
		"death_rewards": [],
		"room_embers": 0,
		"recovered_embers_total": 0,
		"rng_state": rng.state,
		"log": []
	}
	state = _apply_start_combat_relic_effects(state, player_snapshot)
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		_assign_enemy_intent(state, enemy_index, rng)
	state["rng_state"] = rng.state
	state = _initialize_initiative_queue(state)
	state = _draw_cards_in_place(state, maxi(0, int(state.get("hand_size", 5)) + GameData.stat_bonus_from_relics(state.get("relics", []), "opening_draw_bonus")))
	_log(state, "Entered %s." % state.get("room_name", "a room"))
	return state

func _apply_start_combat_relic_effects(state: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var deck_cards: Array = player_snapshot.get("deck_cards", []).duplicate()
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"start_combat_stoneskin_per_deck_element":
				var element_id: String = str(effect.get("element", ElementData.NONE))
				var count: int = 0
				for card_id_var: Variant in deck_cards:
					if GameData.card_element(str(card_id_var)) == element_id:
						count += 1
				if count < int(effect.get("threshold", 1)):
					continue
				var bonus: int = count * GameData.fixed_point_amount(int(effect.get("value", 0)))
				if effect.has("max_value"):
					bonus = mini(bonus, GameData.fixed_point_amount(int(effect.get("max_value", bonus))))
				player["stoneskin"] = int(player.get("stoneskin", 0)) + bonus
			"start_combat_intensity":
				if not _start_combat_intensity_effect_applies(effect, deck_cards):
					continue
				var start_element: String = str(effect.get("element", ElementData.NONE))
				var start_amount: int = int(effect.get("amount", effect.get("value", 0)))
				next_state["player"] = player
				next_state = _gain_elemental_intensity(next_state, start_element, start_amount, _relic_effect_source_name(effect))
				player = _normalized_player(next_state.get("player", {}))
	next_state["player"] = player
	return next_state

func card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	return GameData.card_def_for_progression(card_id, state)

func card_play_actions(card_id: String, state: Dictionary = {}) -> Array:
	var card: Dictionary = card_def(card_id, state)
	var printed_actions: Array = (card.get("actions", []) as Array).duplicate(true)
	var intensity_cost: Dictionary = ElementalIntensityRules.card_cost(card)
	var leading_actions: Array = []
	if not intensity_cost.is_empty():
		leading_actions.append({
			"type": "intensity_spend",
			"element": str(intensity_cost.get("element", ElementData.NONE)),
			"amount": int(intensity_cost.get("amount", 0)),
			"required": true,
			"_card_cost": true
		})
	if not bool(card.get("flurry", false)):
		leading_actions.append_array(printed_actions)
		return leading_actions
	var repeat_count: int = flurry_plays_for_card(card_id, state)
	var repeated_actions: Array = leading_actions
	for repeat_index: int in range(repeat_count):
		for action_var: Variant in printed_actions:
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = (action_var as Dictionary).duplicate(true)
			action["_flurry_repeat_index"] = repeat_index
			action["_flurry_repeat_count"] = repeat_count
			# Flurry spends several card plays, but it is still one played card and one
			# targeting decision. Later repetitions reuse the first legal target.
			if repeat_index > 0 and player_action_needs_target(action):
				action["reuse_previous_target"] = true
			repeated_actions.append(action)
	return repeated_actions

func flurry_plays_for_card(card_id: String, state: Dictionary = {}) -> int:
	if not bool(card_def(card_id, state).get("flurry", false)):
		return 1
	return maxi(1, cards_remaining_this_turn(state))

func card_plays_spent_for_actions(actions: Array) -> int:
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		return maxi(1, int((action_var as Dictionary).get("_flurry_repeat_count", 1)))
	return 1

func player_action_needs_target(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "aoe":
		return int(action.get("range", 0)) > 0
	return action_type in ["move", "blink", "melee", "ranged", "push", "pull", "illusion", "illuminate"]

func player_action_needs_orientation(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "aoe":
		return int(action.get("range", 0)) > 0 and _aoe_pattern_variants(action).size() > 1
	return _action_has_forced_movement(action)

func player_action_can_resolve(state: Dictionary, action: Dictionary) -> bool:
	if not action_intensity_requirement_met(state, action):
		return false
	var action_type: String = str(action.get("type", ""))
	if action_type == "intensity_spend" and not action_intensity_spend_requirement_met(state, action):
		return false
	var restrictions: Dictionary = state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		return false
	if bool(restrictions.get("shocked", false)):
		if action_type not in ["move", "blink"]:
			return false
	if bool(restrictions.get("immobilized", false)) and action_type in ["move", "blink"]:
		return false
	return true

func valid_targets_for_player_action(state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if not player_action_can_resolve(state, action):
		return []
	var player: Dictionary = state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var occupied: Dictionary = {}
	var targets: Array[Vector2i] = []
	var visible_lookup: Dictionary = {}
	if action_type in ["blink", "illusion", "melee", "ranged", "aoe", "push", "pull"]:
		visible_lookup = umbra_visible_tile_lookup(state)
	match action_type:
		"move":
			occupied = _known_actor_tiles_for_player(state)
			var move_range: int = int(resolved_action.get("range", 0)) + _move_bonus_for_current_turn(state)
			targets = PathUtils.reachable_tiles(state.get("grid", []), player_pos, move_range, occupied)
		"blink":
			occupied = _player_blocking_tiles(state)
			var max_range: int = int(resolved_action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, max_range, state.get("grid", [])):
				if tile == player_pos:
					continue
				if occupied.has(tile):
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				if not is_tile_visible_to_player(state, tile, visible_lookup):
					continue
				targets.append(tile)
		"illusion":
			occupied = _occupied_actor_tiles(state)
			occupied[player_pos] = true
			var illusion_range: int = int(action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, illusion_range, state.get("grid", [])):
				if occupied.has(tile):
					continue
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				if not is_tile_visible_to_player(state, tile, visible_lookup):
					continue
				targets.append(tile)
		"illuminate":
			var illuminate_range: int = int(action.get("range", 0))
			for tile: Vector2i in PathUtils.diamond_tiles(player_pos, illuminate_range, state.get("grid", [])):
				if not PathUtils.is_passable(state.get("grid", []), tile):
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, tile):
					continue
				targets.append(tile)
		"melee":
			var melee_range: int = int(action.get("range", 1))
			for enemy: Dictionary in _live_enemies(state):
				if not is_enemy_visible_to_player(state, enemy, visible_lookup):
					continue
				var enemy_targetable: bool = false
				for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
					if PathUtils.manhattan(player_pos, enemy_tile) <= melee_range:
						enemy_targetable = true
						break
				if enemy_targetable:
					_append_enemy_footprint_targets(targets, enemy)
			for terrain: Dictionary in _live_terrain(state):
				var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, terrain_pos) <= melee_range and not targets.has(terrain_pos):
					targets.append(terrain_pos)
			for trap: Dictionary in _live_traps(state):
				var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, trap_pos) <= melee_range and not targets.has(trap_pos):
					targets.append(trap_pos)
		"ranged":
			var ranged_range: int = int(resolved_action.get("range", 1))
			for enemy: Dictionary in _live_enemies(state):
				if not is_enemy_visible_to_player(state, enemy, visible_lookup):
					continue
				var enemy_targetable: bool = false
				for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
					if PathUtils.manhattan(player_pos, enemy_tile) > ranged_range:
						continue
					if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_tile):
						continue
					enemy_targetable = true
					break
				if enemy_targetable:
					_append_enemy_footprint_targets(targets, enemy)
			for terrain: Dictionary in _live_terrain(state):
				var terrain_pos: Vector2i = terrain.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, terrain_pos) > ranged_range:
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, terrain_pos):
					continue
				if not targets.has(terrain_pos):
					targets.append(terrain_pos)
			for trap: Dictionary in _live_traps(state):
				var trap_pos: Vector2i = trap.get("pos", Vector2i.ZERO)
				if PathUtils.manhattan(player_pos, trap_pos) > ranged_range:
					continue
				if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, trap_pos):
					continue
				if not targets.has(trap_pos):
					targets.append(trap_pos)
		"aoe":
			var aoe_range: int = int(action.get("range", 0))
			if aoe_range <= 0:
				var attackable_tiles: Dictionary = _player_attackable_tiles_lookup(state, true)
				var pattern_specs: Array[Dictionary] = _aoe_pattern_specs_for_legality(action, false)
				if _aoe_pattern_specs_hit_attackable(player_pos, pattern_specs, attackable_tiles):
					targets.append(player_pos)
			else:
				for tile: Vector2i in PathUtils.diamond_tiles(player_pos, aoe_range, state.get("grid", [])):
					if tile == player_pos:
						continue
					if not PathUtils.is_passable(state.get("grid", []), tile):
						continue
					if not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, tile):
						continue
					if not is_tile_visible_to_player(state, tile, visible_lookup):
						continue
					targets.append(tile)
		"push", "pull":
			var forced_range: int = int(resolved_action.get("range", 1))
			var pushing: bool = action_type == "push"
			for enemy_index: int in range((state.get("enemies", []) as Array).size()):
				var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
				if int(enemy.get("hp", 0)) <= 0:
					continue
				if not is_enemy_visible_to_player(state, enemy, visible_lookup):
					continue
				var resolved_force_action: Dictionary = _action_with_target_state_relic_modifiers(state, resolved_action, enemy_index)
				var force_direction: Vector2i = _action_force_direction(resolved_force_action)
				var force_amount: int = _forced_movement_amount(resolved_force_action)
				if force_direction != Vector2i.ZERO:
					if not _forced_direction_can_move_enemy(state, enemy_index, force_direction, player_pos, pushing):
						continue
				elif _force_directions_for_enemy(state, enemy_index, player_pos, pushing, force_amount).is_empty():
					continue
				var enemy_targetable: bool = false
				for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
					if PathUtils.manhattan(player_pos, enemy_tile) > forced_range:
						continue
					if forced_range > 1 and not PathUtils.has_line_of_sight(state.get("grid", []), player_pos, enemy_tile):
						continue
					enemy_targetable = true
					break
				if enemy_targetable:
					_append_enemy_footprint_targets(targets, enemy)
	return targets

func player_action_has_valid_target(state: Dictionary, action: Dictionary) -> bool:
	# A move has at least one reachable destination iff its first step can enter
	# any adjacent passable, unoccupied tile. Callers that only need existence
	# should not build the complete reachable-tile BFS and every destination path.
	if not player_action_can_resolve(state, action):
		return false
	if str(action.get("type", "")) != "move":
		return not valid_targets_for_player_action(state, action).is_empty()
	var move_range: int = int((_action_with_intensity_bonus(state, action)).get("range", 0)) + _move_bonus_for_current_turn(state)
	if move_range <= 0:
		return false
	var grid: Array = state.get("grid", []) as Array
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _known_actor_tiles_for_player(state)
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var tile: Vector2i = player_pos + direction
		if not occupied.has(tile) and PathUtils.is_passable(grid, tile):
			return true
	return false

func _action_has_illuminate_rider(action: Dictionary) -> bool:
	return int(action.get("illuminate_radius", 0)) > 0

func _append_enemy_footprint_targets(targets: Array[Vector2i], enemy: Dictionary) -> void:
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		if not targets.has(enemy_tile):
			targets.append(enemy_tile)

func path_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var action_type: String = str(action.get("type", ""))
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	match action_type:
		"move":
			var move_range: int = _move_range_for_action(state, action)
			return _actual_player_movement_path(state, player_pos, target_tile, move_range)
		"blink":
			if target_tile.x >= 0:
				return _vector2i_values([target_tile])
			return _vector2i_values([])
		_:
			return _vector2i_values([])

func movement_plan_for_player_action(state: Dictionary, action: Dictionary, prevalidated_targets: Variant = null) -> Dictionary:
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var move_range: int = _move_range_for_action(state, action)
	var target_tiles: Array[Vector2i] = []
	if str(action.get("type", "")) != "move" or move_range <= 0 or not player_action_can_resolve(state, action):
		return {
			"start": player_pos,
			"range": move_range,
			"target_tiles": target_tiles,
			"paths": {}
		}
	if typeof(prevalidated_targets) == TYPE_ARRAY:
		target_tiles = _vector2i_values(prevalidated_targets as Array)
	else:
		target_tiles = valid_targets_for_player_action(state, action)
	# The same immutable plan is also consumed by exact preview simulations. Keep
	# the visibility boundary that produced it so those simulations do not repeat
	# the Umbra flood fill and actor scan once per candidate path.
	var visible_enemy_tiles: Dictionary = _occupied_visible_enemy_tiles(state)
	var known_actor_tiles: Dictionary = visible_enemy_tiles.duplicate()
	for terrain_tile_var: Variant in _occupied_terrain_tiles(state).keys():
		known_actor_tiles[terrain_tile_var] = true
	var hidden_enemy_tiles: Dictionary = _occupied_enemy_tiles(state)
	for visible_tile_var: Variant in visible_enemy_tiles.keys():
		hidden_enemy_tiles.erase(visible_tile_var)
	var navigation: Dictionary = _preferred_player_navigation(
		state.get("grid", []),
		player_pos,
		move_range,
		known_actor_tiles,
		_trap_tiles_lookup(state),
		_preferred_pickup_scores(state)
	)
	var navigation_paths: Dictionary = navigation.get("paths", {})
	var paths: Dictionary = {}
	for target_tile: Vector2i in target_tiles:
		var path: Array[Vector2i] = _vector2i_values(navigation_paths.get(target_tile, []))
		if not path.is_empty():
			paths[target_tile] = path
	return {
		"start": player_pos,
		"range": move_range,
		"target_tiles": target_tiles,
		"paths": paths,
		"hidden_enemy_tiles": hidden_enemy_tiles,
		"_source_state": state,
		"_source_action": action,
	}

func path_from_player_movement_plan(plan: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var paths: Dictionary = plan.get("paths", {})
	var path_value: Variant = paths.get(target_tile, [])
	if typeof(path_value) != TYPE_ARRAY:
		return _vector2i_values([])
	return _vector2i_values(path_value as Array)

func apply_prevalidated_player_move(state: Dictionary, action: Dictionary, target_tile: Vector2i, planned_path: Array) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var movement_path: Array[Vector2i] = _vector2i_values(planned_path)
	if not _prevalidated_player_move_path_is_usable(state, action, target_tile, movement_path):
		var fallback_state: Dictionary = apply_player_action(state, action, target_tile)
		_record_runtime_performance_phase("prevalidated_move_total", performance_total_started)
		return fallback_state
	var performance_phase_started: int = _record_runtime_performance_phase("prevalidated_move_validate", performance_total_started)
	var next_state: Dictionary = state.duplicate(true)
	performance_phase_started = _record_runtime_performance_phase("prevalidated_move_duplicate", performance_phase_started)
	if not bool(action.get("_movement_pool", false)):
		_mark_first_confluence_benefit(next_state, action)
		_snapshot_pending_card_payment(next_state)
	performance_phase_started = _record_runtime_performance_phase("prevalidated_move_prelude", performance_phase_started)
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	performance_phase_started = _record_runtime_performance_phase("prevalidated_move_resolve_action", performance_phase_started)
	next_state = _apply_player_move_along_path(next_state, resolved_action, target_tile, movement_path)
	_record_runtime_performance_phase("prevalidated_move_apply_path_total", performance_phase_started)
	_record_runtime_performance_phase("prevalidated_move_total", performance_total_started)
	return next_state

func apply_planned_player_move(state: Dictionary, action: Dictionary, target_tile: Vector2i, movement_plan: Dictionary) -> Dictionary:
	var source_state: Variant = movement_plan.get("_source_state", null)
	var source_action: Variant = movement_plan.get("_source_action", null)
	if typeof(source_state) != TYPE_DICTIONARY or typeof(source_action) != TYPE_DICTIONARY or not is_same(source_state, state) or not is_same(source_action, action):
		return apply_prevalidated_player_move(state, action, target_tile, path_from_player_movement_plan(movement_plan, target_tile))
	var movement_path: Array[Vector2i] = path_from_player_movement_plan(movement_plan, target_tile)
	if movement_path.size() <= 1 or movement_path[0] != movement_plan.get("start", Vector2i.ZERO) or movement_path[movement_path.size() - 1] != target_tile:
		return apply_prevalidated_player_move(state, action, target_tile, movement_path)
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state.duplicate(true)
	var performance_phase_started: int = _record_runtime_performance_phase("planned_move_duplicate", performance_total_started)
	if not bool(action.get("_movement_pool", false)):
		_mark_first_confluence_benefit(next_state, action)
		_snapshot_pending_card_payment(next_state)
	performance_phase_started = _record_runtime_performance_phase("planned_move_prelude", performance_phase_started)
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	performance_phase_started = _record_runtime_performance_phase("planned_move_resolve_action", performance_phase_started)
	next_state = _apply_player_move_along_path(
		next_state,
		resolved_action,
		target_tile,
		movement_path,
		movement_plan.get("hidden_enemy_tiles", {}) as Dictionary,
		true
	)
	_record_runtime_performance_phase("planned_move_apply_path_total", performance_phase_started)
	_record_runtime_performance_phase("planned_move_total", performance_total_started)
	return next_state

func apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return _apply_player_action(state, action, target_tile, true)

# Opt-in visual trace: actual hit order and intermediate snapshots never enter a
# combat save, preview cache or analytics event. The ordinary resolver is shared.
func resolve_player_action_for_presentation(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var trace: Dictionary = {"chain_hits": []}
	var result: Dictionary = _apply_player_action(state, action, target_tile, true, trace)
	return {"state": result, "chain_hits": trace["chain_hits"]}

func apply_prevalidated_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	# Preview callers obtain target_tile from valid_targets_for_player_action and
	# may then resolve the same action repeatedly for damage feedback. Avoid doing
	# a second full target scan while preserving the exact normal action resolver.
	return _apply_player_action(state, action, target_tile, false)

func _apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i, validate_target: bool, presentation_trace: Dictionary = {}) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state.duplicate(true)
	var performance_phase_started: int = _record_runtime_performance_phase("player_action_duplicate", performance_total_started)
	if not player_action_can_resolve(next_state, action):
		_record_runtime_performance_phase("player_action_total", performance_total_started)
		return next_state
	var action_needs_target: bool = player_action_needs_target(action)
	var target_is_valid: bool = (
		not action_needs_target
		or not validate_target
		or valid_targets_for_player_action(next_state, action).has(target_tile)
	)
	# Targeted actions are only committed after their chosen target validates. Keep
	# Confluence's activation event on that same boundary so previews or stale
	# target requests cannot claim a benefit that never resolved.
	if target_is_valid and not bool(action.get("_movement_pool", false)):
		_mark_first_confluence_benefit(next_state, action)
	if not bool(action.get("_movement_pool", false)):
		_snapshot_pending_card_payment(next_state)
	var player: Dictionary = next_state.get("player", {})
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var action_type: String = str(action.get("type", ""))
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	performance_phase_started = _record_runtime_performance_phase("player_action_prelude", performance_phase_started)
	match action_type:
		"move":
			if target_is_valid:
				var movement_path: Array[Vector2i] = path_for_player_action(next_state, action, target_tile)
				if movement_path.size() <= 1:
					_record_runtime_performance_phase("player_action_body_total", performance_phase_started)
					_record_runtime_performance_phase("player_action_total", performance_total_started)
					return next_state
				next_state = _apply_player_move_along_path(next_state, resolved_action, target_tile, movement_path)
		"blink":
			if target_is_valid:
				var blink_origin: Vector2i = player_pos
				var loot_before: int = _unclaimed_loot_count(next_state)
				player["pos"] = target_tile
				next_state["player"] = player
				_collect_loot_at_player(next_state)
				next_state = _trigger_trap_on_player(next_state)
				next_state = _trigger_blink_relics(next_state, PathUtils.manhattan(blink_origin, target_tile))
				next_state = _dispel_illusion_at_player(next_state)
				var afterimage_id: String = SkillTreeLibrary.skill_id_for_effect("blink_illusion")
				if skill_is_ready(next_state, afterimage_id):
					var afterimage_effect: Dictionary = SkillTreeLibrary.effect(afterimage_id)
					var illusion_health: int = GameData.fixed_point_amount(maxi(1, int(afterimage_effect.get("health_visible", 2))))
					next_state = _create_illusion(next_state, blink_origin, illusion_health)
					_mark_skill_used(next_state, afterimage_id, "%s leaves an illusion behind." % SkillTreeLibrary.display_name(afterimage_id))
				var blink_path: Array[Vector2i] = _vector2i_values([blink_origin, target_tile])
				next_state = _trigger_player_movement_radiance(next_state, resolved_action, blink_path, true)
				var contextual_skill_id: String = str(action.get("_skill_id", ""))
				if not contextual_skill_id.is_empty() and has_skill(next_state, contextual_skill_id) and not skill_was_used(next_state, contextual_skill_id):
					_mark_skill_used(next_state, contextual_skill_id, "%s turns movement into a Blink." % SkillTreeLibrary.display_name(contextual_skill_id))
				if not bool(resolved_action.get("_movement_pool", false)):
					next_state = _maybe_refund_loot_play(next_state, loot_before)
				_log(next_state, "Blinked to %s." % str(target_tile))
		"melee":
			if target_is_valid:
				next_state = _attack_target_on_tile(next_state, action, target_tile, "melee", presentation_trace)
		"ranged":
			if target_is_valid:
				next_state = _attack_target_on_tile(next_state, action, target_tile, "ranged", presentation_trace)
		"aoe":
			if target_is_valid:
				next_state = _aoe_enemies(next_state, action, target_tile)
		"push":
			if target_is_valid:
				next_state = _push_or_pull_target(next_state, action, target_tile, true)
		"pull":
			if target_is_valid:
				next_state = _push_or_pull_target(next_state, action, target_tile, false)
		"block":
			player["block"] = int(player.get("block", 0)) + int(resolved_action.get("amount", 0))
			next_state["player"] = player
			_log(next_state, "Gained %d block." % int(resolved_action.get("amount", 0)))
		"stoneskin":
			var stoneskin_before: int = int(player.get("stoneskin", 0))
			player["stoneskin"] = int(player.get("stoneskin", 0)) + int(resolved_action.get("amount", 0))
			next_state["player"] = player
			next_state = _trigger_stoneskin_relics(next_state, int(player.get("stoneskin", 0)) - stoneskin_before)
			_log(next_state, "Gained %d stoneskin." % int(resolved_action.get("amount", 0)))
		"heal":
			var heal_amount: int = int(resolved_action.get("amount", 0))
			next_state = _heal_player(next_state, heal_amount)
			_log(next_state, "Recovered %d health." % heal_amount)
		"draw":
			var draw_amount: int = int(resolved_action.get("amount", 0))
			if _action_condition_uses_confluence(next_state, action):
				var safe_draws: int = ((next_state.get("deck", {}) as Dictionary).get("draw", []) as Array).size()
				if draw_amount > safe_draws:
					draw_amount = safe_draws
					_log(next_state, "%s stops the conditional draw before Fatigue." % SkillTreeLibrary.display_name(SkillTreeLibrary.skill_id_for_effect("highest_intensity")))
			next_state = _draw_cards_in_place(next_state, draw_amount)
		"card_play":
			var bonus_card_plays: int = maxi(0, int(resolved_action.get("amount", 0)))
			next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + bonus_card_plays
			if bonus_card_plays > 0:
				_log(next_state, "Gained %d card play(s)." % bonus_card_plays)
		"intensity":
			var element_id: String = _action_intensity_element(action)
			var amount: int = maxi(0, int(resolved_action.get("amount", 0)))
			next_state = _gain_elemental_intensity(next_state, element_id, amount)
		"intensity_spend":
			var spend_element_id: String = _action_intensity_element(action)
			var spend_amount: int = maxi(0, int(action.get("amount", 0)))
			next_state = _consume_elemental_intensity(next_state, spend_element_id, spend_amount)
		"illuminate":
			if target_is_valid:
				next_state = _create_umbra_light_source(next_state, target_tile, resolved_action)
		"vision":
			next_state = _apply_umbra_vision(next_state, resolved_action)
		"truesight":
			next_state = _apply_umbra_truesight(next_state, resolved_action)
		"dispel_umbra":
			next_state = _dispel_umbra(next_state, resolved_action)
		"illusion":
			if target_is_valid:
				next_state = _create_illusion(next_state, target_tile, int(resolved_action.get("health", resolved_action.get("amount", 0))))
	_record_runtime_performance_phase("player_action_body_total", performance_phase_started)
	_record_runtime_performance_phase("player_action_total", performance_total_started)
	return next_state

func _apply_player_move_along_path(
	next_state: Dictionary,
	resolved_action: Dictionary,
	target_tile: Vector2i,
	movement_path: Array[Vector2i],
	hidden_collision_tiles: Dictionary = {},
	use_hidden_collision_lookup: bool = false
) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var loot_before: int = _unclaimed_loot_count(next_state)
	var performance_phase_started: int = _record_runtime_performance_phase("move_path_loot_before", performance_total_started)
	next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
	if combat_outcome(next_state) == "defeat":
		_record_runtime_performance_phase("move_path_bleed_outcome", performance_phase_started)
		_record_runtime_performance_phase("move_path_total", performance_total_started)
		return next_state
	performance_phase_started = _record_runtime_performance_phase("move_path_bleed_outcome", performance_phase_started)
	var resolved_path: Array[Vector2i] = _player_path_until_hidden_collision(next_state, movement_path, hidden_collision_tiles, use_hidden_collision_lookup)
	performance_phase_started = _record_runtime_performance_phase("move_path_hidden_collision", performance_phase_started)
	next_state = _move_player_along_path(next_state, resolved_path)
	performance_phase_started = _record_runtime_performance_phase("move_path_traverse_total", performance_phase_started)
	var resolved_endpoint: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", resolved_path[0])
	resolved_path = _movement_path_through_endpoint(resolved_path, resolved_endpoint)
	_mark_first_move_used(next_state)
	performance_phase_started = _record_runtime_performance_phase("move_path_endpoint", performance_phase_started)
	next_state = _trigger_long_move_relics(next_state, resolved_path.size() - 1)
	performance_phase_started = _record_runtime_performance_phase("move_path_long_relics", performance_phase_started)
	next_state = _trigger_player_movement_radiance(next_state, resolved_action, resolved_path, false)
	performance_phase_started = _record_runtime_performance_phase("move_path_radiance", performance_phase_started)
	if not bool(resolved_action.get("_movement_pool", false)):
		next_state = _maybe_refund_loot_play(next_state, loot_before)
	performance_phase_started = _record_runtime_performance_phase("move_path_loot_refund", performance_phase_started)
	_log(next_state, "Moved to %s." % str((next_state.get("player", {}) as Dictionary).get("pos", target_tile)))
	_record_runtime_performance_phase("move_path_log", performance_phase_started)
	_record_runtime_performance_phase("move_path_total", performance_total_started)
	return next_state

func _movement_path_through_endpoint(path: Array[Vector2i], endpoint: Vector2i) -> Array[Vector2i]:
	var traversed: Array[Vector2i] = _vector2i_values([])
	for tile: Vector2i in path:
		traversed.append(tile)
		if tile == endpoint:
			return traversed
	if path.is_empty():
		return _vector2i_values([endpoint])
	return _vector2i_values([path[0], endpoint]) if path[0] != endpoint else _vector2i_values([path[0]])

func _trigger_player_movement_radiance(state: Dictionary, action: Dictionary, path: Array[Vector2i], blinked: bool) -> Dictionary:
	var next_state: Dictionary = state
	if path.size() <= 1:
		return next_state
	var distance: int = PathUtils.manhattan(path[0], path[path.size() - 1]) if blinked else path.size() - 1
	var light_positions: Array[Vector2i] = _vector2i_values([])
	if _action_has_illuminate_rider(action):
		var authored_positions: Array[Vector2i] = _vector2i_values([])
		match str(action.get("illuminate_position_mode", "destination")):
			"path":
				authored_positions = _movement_light_positions(path, blinked)
			_:
				authored_positions.append(path[path.size() - 1])
		for position: Vector2i in authored_positions:
			next_state = _create_umbra_light_source(next_state, position, {
				"radius": int(action.get("illuminate_radius", 1)),
				"duration": int(action.get("illuminate_duration", 1)),
				"silent": true
			})
			if not light_positions.has(position):
				light_positions.append(position)
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "resolved_action_light" or str(effect.get("position_mode", "")) != "path":
			continue
		if not _resolved_action_matches_light_effect(next_state, action, effect):
			continue
		var relic_positions: Array[Vector2i] = _movement_light_positions(path, blinked)
		for position: Vector2i in relic_positions:
			next_state = _create_umbra_light_source(next_state, position, {
				"radius": int(effect.get("radius", 1)),
				"duration": int(effect.get("duration", 2)),
				"silent": true
			})
			if not light_positions.has(position):
				light_positions.append(position)
	var sunpath_id: String = SkillTreeLibrary.skill_id_for_effect("long_move_light_path")
	if not sunpath_id.is_empty() and has_skill(next_state, sunpath_id):
		var sunpath_effect: Dictionary = SkillTreeLibrary.effect(sunpath_id)
		var sunpath_key: String = "skill_turn:%s" % sunpath_id
		if distance >= int(sunpath_effect.get("minimum_distance", 3)) and not _turn_flag(next_state, sunpath_key):
			_set_turn_flag(next_state, sunpath_key, true)
			for position: Vector2i in _movement_light_positions(path, blinked):
				next_state = _create_umbra_light_source(next_state, position, {
					"radius": int(sunpath_effect.get("radius", 1)),
					"duration": int(sunpath_effect.get("duration", 2)),
					"silent": true
				})
				if not light_positions.has(position):
					light_positions.append(position)
			_record_skill_event(next_state, sunpath_id, "%s leaves a path of Light." % SkillTreeLibrary.display_name(sunpath_id))
	if blinked:
		next_state = _trigger_blink_origin_illusion(next_state, path[0])
	if not light_positions.is_empty():
		_log(next_state, "Movement leaves a path of Light.")
	return _trigger_movement_end_rewards(next_state, action)

func _movement_light_positions(path: Array[Vector2i], blinked: bool) -> Array[Vector2i]:
	if blinked:
		return _vector2i_values([path[0], path[path.size() - 1]])
	var result: Array[Vector2i] = _vector2i_values([])
	for index: int in range(1, path.size()):
		result.append(path[index])
	return result

func _trigger_blink_origin_illusion(state: Dictionary, origin: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "blink_origin_illusion":
			continue
		if not _relic_once_available(next_state, effect, "blink_origin_illusion", ""):
			continue
		var illusion_count_before: int = _live_illusions(next_state).size()
		next_state = _create_illusion(next_state, origin, GameData.fixed_point_amount(maxi(1, int(effect.get("health", 2)))))
		if _live_illusions(next_state).size() <= illusion_count_before:
			continue
		_mark_relic_once(next_state, effect, "blink_origin_illusion", "")
		_log(next_state, "%s leaves an illusion behind." % _relic_effect_source_name(effect))
	return next_state

func _trigger_movement_end_rewards(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", INVALID_TILE)
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "movement_end_reward":
			continue
		var action_types: Array = effect.get("action_types", []) as Array
		if not action_types.is_empty() and not action_types.has(str(action.get("type", ""))):
			continue
		if bool(effect.get("player_in_light", false)) and not _light_source_covers_tile(next_state, player_pos):
			continue
		if not _relic_once_available(next_state, effect, "movement_end_reward", ""):
			continue
		_mark_relic_once(next_state, effect, "movement_end_reward", "")
		next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
	return next_state

func _prevalidated_player_move_path_is_usable(state: Dictionary, action: Dictionary, target_tile: Vector2i, movement_path: Array[Vector2i]) -> bool:
	if str(action.get("type", "")) != "move" or not player_action_can_resolve(state, action):
		return false
	if movement_path.size() <= 1:
		return false
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	if movement_path[0] != player_pos or movement_path[movement_path.size() - 1] != target_tile:
		return false
	var move_range: int = _move_range_for_action(state, action)
	if movement_path.size() - 1 > move_range:
		return false
	var grid: Array = state.get("grid", [])
	var occupied: Dictionary = _known_actor_tiles_for_player(state)
	for index: int in range(1, movement_path.size()):
		var previous_tile: Vector2i = movement_path[index - 1]
		var tile: Vector2i = movement_path[index]
		if PathUtils.manhattan(previous_tile, tile) != 1:
			return false
		if not PathUtils.is_passable(grid, tile) or occupied.has(tile):
			return false
	return true

func finish_player_card(state: Dictionary, hand_index: int, plays_spent: int = 1, play_context: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var hand: Array = ((next_state.get("deck", {}) as Dictionary).get("hand", []) as Array).duplicate()
	if hand_index < 0 or hand_index >= hand.size():
		return next_state
	var card_id: String = str(hand[hand_index])
	hand.remove_at(hand_index)
	var deck: Dictionary = next_state.get("deck", {}).duplicate(true)
	deck["hand"] = hand
	var card: Dictionary = card_def(card_id, next_state)
	var destination: String = "discard"
	if bool(card.get("consume_on_play", false)):
		var makeshift_id: String = SkillTreeLibrary.skill_id_for_effect("preserve_item")
		var makeshift_armed: bool = bool((next_state.get("skill_flags", {}) as Dictionary).get("item_preserve_armed", false))
		if has_skill(next_state, makeshift_id) and makeshift_armed:
			var makeshift_discard: Array = deck.get("discard", []).duplicate()
			makeshift_discard.append(card_id)
			deck["discard"] = makeshift_discard
			destination = "discard"
			_erase_skill_flag(next_state, "item_preserve_armed")
			_mark_skill_used(next_state, makeshift_id, "%s preserves the played item." % SkillTreeLibrary.display_name(makeshift_id))
		else:
			var consumed: Array = deck.get("consumed", []).duplicate()
			consumed.append(card_id)
			deck["consumed"] = consumed
			destination = "consume"
			BattlefieldItemRules.consume(next_state, card_id)
	elif bool(card.get("burn", false)):
		var escape_id: String = SkillTreeLibrary.skill_id_for_effect("preserve_burn")
		var escape_armed: bool = bool((next_state.get("skill_flags", {}) as Dictionary).get("burn_preserve_armed", false))
		if not GameData.card_is_item(card_id) and has_skill(next_state, escape_id) and escape_armed:
			var saved_discard: Array = deck.get("discard", []).duplicate()
			saved_discard.append(card_id)
			deck["discard"] = saved_discard
			destination = "discard"
			_erase_skill_flag(next_state, "burn_preserve_armed")
			_mark_skill_used(next_state, escape_id, "%s keeps %s in the deck." % [SkillTreeLibrary.display_name(escape_id), str(card.get("name", card_id))])
		else:
			var burned: Array = deck.get("burned", []).duplicate()
			burned.append(card_id)
			deck["burned"] = burned
			destination = "burn"
	else:
		var discard: Array = deck.get("discard", []).duplicate()
		discard.append(card_id)
		deck["discard"] = discard
		destination = "discard"
	next_state["deck"] = deck
	next_state["last_card_destination"] = destination
	if destination == "discard":
		next_state = _maybe_trigger_pain_recall(next_state, card_id)
	var safe_plays_spent: int = maxi(1, plays_spent)
	var cards_played_before: int = int(next_state.get("cards_played_this_turn", 0))
	var payment_snapshot: Dictionary = next_state.get("pending_card_payment", {}) as Dictionary
	var used_banked_play: bool = _card_payment_uses_banked_play(payment_snapshot, next_state, safe_plays_spent)
	next_state.erase("pending_card_payment")
	next_state["last_card_used_banked_play"] = used_banked_play
	if used_banked_play:
		next_state["banked_play_spent_this_activation"] = 1
	var health_cost: int = int(card.get("health_cost", 0)) * safe_plays_spent
	if health_cost > 0:
		next_state = _lose_player_health(next_state, health_cost, true, false, "card_health_cost")
		_log(next_state, "Paid %d health for %s." % [health_cost, str(card.get("name", card_id))])
	next_state["cards_played_this_turn"] = int(next_state.get("cards_played_this_turn", 0)) + safe_plays_spent
	var time_cost: int = card_time_cost_from_def(card)
	var borrowed_time_id: String = SkillTreeLibrary.skill_id_for_effect("banked_play_no_time")
	if used_banked_play and _skill_charge_available(next_state, borrowed_time_id):
		time_cost = 0
		_mark_skill_used(next_state, borrowed_time_id, "%s removes this card's Time." % SkillTreeLibrary.display_name(borrowed_time_id))
	next_state["player_turn_time_spent"] = int(next_state.get("player_turn_time_spent", 0)) + time_cost
	var flags: Dictionary = next_state.get("skill_flags", {}) as Dictionary
	var play_mode: String = str(play_context.get("play_mode", "play"))
	if (
		play_mode == "play"
		and bool(flags.get("prismatic_resolving", false))
		and str(flags.get("prismatic_target_card_id", "")) == card_id
	):
		_erase_skill_flag(next_state, "prismatic_armed")
		_erase_skill_flag(next_state, "prismatic_target_card_id")
		_erase_skill_flag(next_state, "prismatic_resolving")
		var prismatic_id: String = SkillTreeLibrary.skill_id_for_effect("arm_intensity")
		_log(next_state, "%s fulfills %s's intensity conditions." % [SkillTreeLibrary.display_name(prismatic_id), str(card.get("name", card_id))])
	else:
		_erase_skill_flag(next_state, "prismatic_resolving")
	next_state = _trigger_card_play_relics(
		next_state,
		card,
		card_id,
		play_context,
		destination,
		used_banked_play,
		cards_played_before
	)
	next_state = _apply_pending_player_trap_restriction(next_state)
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func _card_play_capacity_without_banked(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", BASE_CARDS_PER_TURN))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
	)

func _snapshot_pending_card_payment(state: Dictionary) -> void:
	if state.has("pending_card_payment"):
		return
	var budget: Dictionary = card_play_budget(state)
	state["pending_card_payment"] = {
		"ordinary_remaining": int(budget.get("ordinary_remaining", 0)),
		"banked_remaining": int(budget.get("banked_remaining", 0))
	}

func _card_payment_uses_banked_play(snapshot: Dictionary, state: Dictionary, plays_spent: int) -> bool:
	if snapshot.is_empty():
		return _card_spend_uses_banked_play(state, plays_spent)
	return (
		int(snapshot.get("banked_remaining", 0)) > 0
		and maxi(1, plays_spent) > int(snapshot.get("ordinary_remaining", 0))
	)

func _card_spend_uses_banked_play(state: Dictionary, plays_spent: int) -> bool:
	var budget: Dictionary = card_play_budget(state)
	return (
		int(budget.get("banked_remaining", 0)) > 0
		and maxi(1, plays_spent) > int(budget.get("ordinary_remaining", 0))
	)

func _card_has_intensity_condition(card: Dictionary) -> bool:
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		if not _action_intensity_requirement(action).is_empty() or not _action_intensity_bonus(action).is_empty():
			return true
	return false

func is_player_turn(state: Dictionary) -> bool:
	var current_actor: Dictionary = state.get("current_actor", {})
	return str(current_actor.get("kind", "player")) == "player"

func player_base_initiative(state: Dictionary) -> int:
	return PLAYER_BASE_INITIATIVE

func card_time_cost(card_id: String, state: Dictionary = {}) -> int:
	return card_time_cost_from_def(card_def(card_id, state))

func card_time_cost_from_def(card: Dictionary) -> int:
	if card.has("time"):
		return clampi(int(card.get("time", DEFAULT_CARD_TIME_COST)), MIN_CARD_TIME_COST, MAX_CARD_TIME_COST)
	return _estimated_card_time_cost(card)

func current_turn_order(state: Dictionary, limit: int = TURN_ORDER_PREVIEW_LIMIT, projection_context: Dictionary = {}) -> Array[Dictionary]:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var performance_phase_started: int = performance_total_started
	var result: Array[Dictionary] = []
	if projection_context.is_empty():
		var visible_lookup: Dictionary = umbra_visible_tile_lookup(state)
		performance_phase_started = _record_runtime_performance_phase("current_turn_order_visibility", performance_phase_started)
		# A projection presents each enemy several times (live queue, projected next
		# activation, and before/after animation states). Normalize immutable actor
		# facts once for this projection instead of rescanning and rebuilding the same
		# enemy for every entry.
		projection_context = _turn_order_projection_context(state, visible_lookup)
		performance_phase_started = _record_runtime_performance_phase("current_turn_order_context", performance_phase_started)
	else:
		performance_phase_started = _record_runtime_performance_phase("current_turn_order_context_reuse", performance_phase_started)
	var current_actor: Dictionary = _resolved_actor_entry(state, state.get("current_actor", {}), projection_context)
	if not current_actor.is_empty():
		current_actor["active"] = true
		result.append(_umbra_presented_turn_order_entry(state, current_actor, projection_context))
	performance_phase_started = _record_runtime_performance_phase("current_turn_order_active", performance_phase_started)
	var queue: Array = _sorted_turn_queue(state.get("turn_queue", []))
	performance_phase_started = _record_runtime_performance_phase("current_turn_order_initial_sort", performance_phase_started)
	var preview_queue: Array = []
	for entry_var: Variant in queue:
		preview_queue.append(entry_var)
		if typeof(entry_var) == TYPE_DICTIONARY:
			var projected_after_entry: Dictionary = _projected_next_entry_after_entry(state, entry_var as Dictionary, projection_context)
			if not projected_after_entry.is_empty():
				preview_queue.append(projected_after_entry)
	performance_phase_started = _record_runtime_performance_phase("current_turn_order_project_queue", performance_phase_started)
	var projected_current_future: Dictionary = _projected_next_entry_for_current_actor(state, current_actor, projection_context)
	if not projected_current_future.is_empty():
		preview_queue.append(projected_current_future)
	performance_phase_started = _record_runtime_performance_phase("current_turn_order_project_active", performance_phase_started)
	queue = _sorted_turn_queue(preview_queue)
	performance_phase_started = _record_runtime_performance_phase("current_turn_order_projected_sort", performance_phase_started)
	var clock: int = int(state.get("initiative_clock", 0))
	for entry_var: Variant in queue:
		if result.size() >= limit:
			break
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = _resolved_actor_entry(state, entry_var as Dictionary, projection_context)
		if entry.is_empty():
			continue
		entry["active"] = false
		entry["eta"] = maxi(0, int(entry.get("time", clock)) - clock)
		result.append(_umbra_presented_turn_order_entry(state, entry, projection_context))
	_record_runtime_performance_phase("current_turn_order_present", performance_phase_started)
	_record_runtime_performance_phase("current_turn_order_total", performance_total_started)
	return result

func _umbra_presented_turn_order_entry(state: Dictionary, entry: Dictionary, projection_context: Dictionary = {}) -> Dictionary:
	var presented: Dictionary = entry.duplicate(true)
	if str(presented.get("kind", "")) != "enemy":
		return presented
	var enemy_id: int = int(presented.get("enemy_id", -1))
	var enemy_facts: Dictionary = projection_context.get("enemy_facts", {})
	if enemy_facts.has(enemy_id):
		var enemy_fact: Dictionary = enemy_facts.get(enemy_id, {}) as Dictionary
		if bool(enemy_fact.get("visible", false)):
			return presented
		presented["hidden_by_umbra"] = true
		presented["name"] = "Unknown Presence"
		presented["type"] = "umbra_presence"
		presented["pos"] = Vector2i(-1, -1)
		presented.erase("hp")
		presented.erase("max_hp")
		presented.erase("intent_time_cost")
		presented.erase("base_initiative")
		return presented
	var enemy_index: int = _enemy_index_for_id(state, enemy_id)
	if enemy_index < 0:
		return presented
	var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	if is_enemy_visible_to_player(state, enemy):
		return presented
	presented["hidden_by_umbra"] = true
	presented["name"] = "Unknown Presence"
	presented["type"] = "umbra_presence"
	presented["pos"] = Vector2i(-1, -1)
	presented.erase("hp")
	presented.erase("max_hp")
	presented.erase("intent_time_cost")
	presented.erase("base_initiative")
	return presented

func finish_player_activation(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "" or not is_player_turn(next_state):
		return next_state
	var measured_id: String = SkillTreeLibrary.skill_id_for_effect("bank_unused_play")
	if has_skill(next_state, measured_id) and cards_remaining_this_turn(next_state) > 0:
		next_state["banked_plays"] = 1
		_record_skill_event(next_state, measured_id, "%s banks one play." % SkillTreeLibrary.display_name(measured_id))
	else:
		next_state["banked_plays"] = 0
	next_state["player_turn_ending"] = true
	var guard_id: String = SkillTreeLibrary.skill_id_for_effect("convert_block")
	var guard_armed: bool = bool((next_state.get("skill_flags", {}) as Dictionary).get("guard_carry_armed", false))
	if guard_armed:
		var guard_player: Dictionary = _normalized_player(next_state.get("player", {}))
		var remaining_block: int = int(guard_player.get("block", 0))
		if remaining_block > 0 and _skill_charge_available(next_state, guard_id):
			guard_player["block"] = 0
			guard_player["stoneskin"] = int(guard_player.get("stoneskin", 0)) + remaining_block
			next_state["player"] = guard_player
			next_state = _trigger_stoneskin_relics(next_state, remaining_block)
			_mark_skill_used(next_state, guard_id, "%s carries remaining block forward as stoneskin." % SkillTreeLibrary.display_name(guard_id))
		_erase_skill_flag(next_state, "guard_carry_armed")
	next_state = _trigger_activation_end_relics(next_state)
	next_state = _clear_player_bleed_after_turn(next_state)
	var scheduled_time: int = (
		int(next_state.get("initiative_clock", 0))
		+ player_base_initiative(next_state)
		+ maxi(0, int(next_state.get("player_turn_time_spent", 0)))
	)
	_schedule_actor(next_state, _player_actor_entry(scheduled_time, 0))
	next_state["current_actor"] = {"kind": "transition"}
	return next_state

func advance_to_next_player_turn_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary] = []
	var player_turn_before_state: Dictionary = {}
	var safety: int = 0
	while combat_outcome(next_state) == "" and safety < 100:
		safety += 1
		var slice_result: Dictionary = advance_one_activation_with_steps(next_state)
		next_state = slice_result.get("state", next_state) as Dictionary
		for step_var: Variant in slice_result.get("steps", []):
			if typeof(step_var) == TYPE_DICTIONARY:
				steps.append(step_var)
		var slice_player_before: Variant = slice_result.get("player_turn_before_state", {})
		if typeof(slice_player_before) == TYPE_DICTIONARY and not (slice_player_before as Dictionary).is_empty():
			player_turn_before_state = (slice_player_before as Dictionary).duplicate(true)
		if bool(slice_result.get("complete", false)):
			break
	if safety >= 100:
		_log(next_state, "The initiative clock stalls.")
	return {
		"state": next_state,
		"steps": steps,
		"player_turn_before_state": player_turn_before_state
	}

func recover_player_turn_after_stalled_initiative(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if next_state.is_empty() or combat_outcome(next_state) != "":
		return next_state
	# This path is reserved for corrupt/adversarial continuation queues that fail
	# the normal 100-activation bound. Remove the already-scheduled player entry
	# before preparing one deterministic player activation, so finishing recovery
	# cannot leave a duplicate player actor in the initiative queue.
	var repaired_queue: Array = []
	for entry_var: Variant in next_state.get("turn_queue", []):
		if typeof(entry_var) == TYPE_DICTIONARY and str((entry_var as Dictionary).get("kind", "")) == "player":
			continue
		repaired_queue.append(entry_var)
	next_state["turn_queue"] = repaired_queue
	_log(next_state, "The stalled initiative clock resets to the Reaver.")
	return prepare_next_player_turn(next_state)

func advance_one_activation_with_steps(state: Dictionary, include_commit_steps: bool = true) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary] = []
	var player_turn_before_state: Dictionary = {}
	var before_pop_state: Dictionary = next_state.duplicate(true)
	var popped: Dictionary = _pop_next_actor(next_state)
	# This slice owns its initial deep copy, and _pop_next_actor mutates and
	# returns that owned snapshot. Re-cloning it here adds no isolation.
	next_state = popped.get("state", next_state) as Dictionary
	for reinforcement_step_var: Variant in popped.get("reinforcement_steps", []):
		if typeof(reinforcement_step_var) == TYPE_DICTIONARY:
			steps.append(reinforcement_step_var)
	if combat_outcome(next_state) != "":
		if include_commit_steps:
			_append_commit_step(steps, before_pop_state, next_state, "objective_complete")
		_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
		return {"state": next_state, "steps": steps, "player_turn_before_state": {}, "complete": true}
	var entry: Dictionary = popped.get("entry", {})
	if entry.is_empty():
		next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
		player_turn_before_state = next_state.duplicate(true)
		next_state = prepare_next_player_turn(next_state)
		if include_commit_steps:
			_append_commit_step(steps, before_pop_state, next_state, "player_turn_start")
		_append_turn_order_step(steps, before_pop_state, next_state, "activate")
		_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
		return {"state": next_state, "steps": steps, "player_turn_before_state": player_turn_before_state, "complete": true}
	match str(entry.get("kind", "")):
		"player":
			player_turn_before_state = next_state.duplicate(true)
			next_state = prepare_next_player_turn(next_state)
			if include_commit_steps:
				_append_commit_step(steps, before_pop_state, next_state, "player_turn_start")
			_append_turn_order_step(steps, before_pop_state, next_state, "activate")
			_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
			return {"state": next_state, "steps": steps, "player_turn_before_state": player_turn_before_state, "complete": true}
		"enemy":
			if include_commit_steps:
				_append_commit_step(steps, before_pop_state, next_state, "initiative_activate")
			_append_turn_order_step(steps, before_pop_state, next_state, "activate")
			var enemy_index: int = _enemy_index_for_id(next_state, int(entry.get("enemy_id", -1)))
			if enemy_index < 0:
				_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
				return {"state": next_state, "steps": steps, "player_turn_before_state": {}, "complete": false}
			var turn_result: Dictionary = resolve_enemy_turn_with_steps(next_state, enemy_index, include_commit_steps)
			# The turn resolver owns its initial state copy. Keep that ownership within
			# this activation rather than cloning the full combat snapshot again.
			next_state = turn_result.get("state", next_state) as Dictionary
			for step_var: Variant in turn_result.get("steps", []):
				if typeof(step_var) == TYPE_DICTIONARY:
					steps.append(step_var)
			if combat_outcome(next_state) != "":
				_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
				return {"state": next_state, "steps": steps, "player_turn_before_state": {}, "complete": true}
			enemy_index = _enemy_index_for_id(next_state, int(entry.get("enemy_id", -1)))
			var before_reschedule_state: Dictionary = next_state.duplicate(true)
			if enemy_index >= 0:
				var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
				if int(enemy.get("hp", 0)) > 0:
					_schedule_enemy_after_turn(next_state, enemy, int(turn_result.get("time_cost", 0)))
			next_state["current_actor"] = {"kind": "transition"}
			if include_commit_steps:
				_append_commit_step(steps, before_reschedule_state, next_state, "initiative_reschedule")
			_append_turn_order_step(steps, before_reschedule_state, next_state, "reschedule")
			_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
			return {"state": next_state, "steps": steps, "player_turn_before_state": {}, "complete": false}
	_record_runtime_performance_phase("enemy_phase_slice_total", performance_total_started)
	return {"state": next_state, "steps": steps, "player_turn_before_state": {}, "complete": false}

func preview_revealed_enemy_actions_before_player_turn_with_steps(state: Dictionary) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var cursor: Dictionary = begin_revealed_enemy_actions_preview(state)
	while not bool(cursor.get("complete", false)):
		advance_revealed_enemy_actions_preview(cursor)
	_record_runtime_performance_phase("enemy_preview_total", performance_total_started)
	return revealed_enemy_actions_preview_result(cursor)

func begin_revealed_enemy_actions_preview(state: Dictionary) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state.duplicate(true)
	_record_runtime_performance_phase("enemy_preview_initial_duplicate", performance_total_started)
	var initially_visible_enemy_ids: Dictionary = {}
	var performance_phase_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	for enemy_var: Variant in next_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var initial_enemy: Dictionary = _normalized_enemy(enemy_var as Dictionary)
		if int(initial_enemy.get("hp", 0)) <= 0:
			continue
		if (initial_enemy.get("intent", {}) as Dictionary).is_empty():
			continue
		initially_visible_enemy_ids[int(initial_enemy.get("id", -1))] = true
	_record_runtime_performance_phase("enemy_preview_visible_intents", performance_phase_started)
	return {
		"state": next_state,
		"steps": [],
		"player_turn_before_state": {},
		"initially_visible_enemy_ids": initially_visible_enemy_ids,
		"revealed_enemy_ids": {},
		"unrevealed_before_player": false,
		"safety": 0,
		"complete": combat_outcome(next_state) != "",
	}

func advance_revealed_enemy_actions_preview(cursor: Dictionary) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	if bool(cursor.get("complete", false)):
		_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
		return cursor
	var next_state: Dictionary = cursor.get("state", {}) as Dictionary
	var safety: int = int(cursor.get("safety", 0))
	if next_state.is_empty() or combat_outcome(next_state) != "" or safety >= 100:
		cursor["complete"] = true
		_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
		return cursor
	cursor["safety"] = safety + 1
	var performance_phase_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var before_pop_state: Dictionary = next_state.duplicate(true)
	_record_runtime_performance_phase("enemy_preview_before_pop_duplicate", performance_phase_started)
	performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var popped: Dictionary = _pop_next_actor(next_state)
	_record_runtime_performance_phase("enemy_preview_pop_actor", performance_phase_started)
	performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	next_state = (popped.get("state", next_state) as Dictionary).duplicate(true)
	_record_runtime_performance_phase("enemy_preview_pop_result_duplicate", performance_phase_started)
	if not (popped.get("reinforcement_steps", []) as Array).is_empty():
		cursor["unrevealed_before_player"] = true
		performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
		next_state = before_pop_state.duplicate(true)
		_record_runtime_performance_phase("enemy_preview_reinforcement_restore_duplicate", performance_phase_started)
		cursor["state"] = next_state
		cursor["complete"] = true
		_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
		return cursor
	if combat_outcome(next_state) != "":
		cursor["state"] = next_state
		cursor["player_turn_before_state"] = next_state.duplicate(true)
		cursor["complete"] = true
		_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
		return cursor
	var entry: Dictionary = popped.get("entry", {}) as Dictionary
	if entry.is_empty():
		next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
		cursor["state"] = next_state
		cursor["player_turn_before_state"] = next_state.duplicate(true)
		cursor["complete"] = true
		_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
		return cursor
	match str(entry.get("kind", "")):
		"player":
			cursor["state"] = next_state
			cursor["player_turn_before_state"] = next_state.duplicate(true)
			cursor["complete"] = true
		"enemy":
			var enemy_id: int = int(entry.get("enemy_id", -1))
			var enemy_index: int = _enemy_index_for_id(next_state, enemy_id)
			if enemy_index >= 0:
				var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
				var intent: Dictionary = enemy.get("intent", {}) as Dictionary
				var initially_visible_enemy_ids: Dictionary = cursor.get("initially_visible_enemy_ids", {}) as Dictionary
				var revealed_enemy_ids: Dictionary = cursor.get("revealed_enemy_ids", {}) as Dictionary
				if not initially_visible_enemy_ids.has(enemy_id) or revealed_enemy_ids.has(enemy_id) or intent.is_empty():
					cursor["unrevealed_before_player"] = true
					next_state = before_pop_state.duplicate(true)
					cursor["complete"] = true
				else:
					revealed_enemy_ids[enemy_id] = true
					cursor["revealed_enemy_ids"] = revealed_enemy_ids
					performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
					var turn_result: Dictionary = resolve_enemy_turn_with_steps(next_state, enemy_index, false)
					_record_runtime_performance_phase("enemy_preview_resolve_enemy_turn_total", performance_phase_started)
					# The turn result already owns its state. Keep that ownership across
					# rendered slices instead of cloning the full snapshot again.
					next_state = turn_result.get("state", next_state) as Dictionary
					var steps: Array = cursor.get("steps", []) as Array
					for step_var: Variant in turn_result.get("steps", []):
						if typeof(step_var) == TYPE_DICTIONARY:
							steps.append(step_var)
					cursor["steps"] = steps
					if combat_outcome(next_state) != "":
						cursor["complete"] = true
					else:
						enemy_index = _enemy_index_for_id(next_state, enemy_id)
						if enemy_index >= 0:
							enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
							if int(enemy.get("hp", 0)) > 0:
								_schedule_enemy_after_turn(next_state, enemy, int(turn_result.get("time_cost", 0)))
						next_state["current_actor"] = {}
		_:
			pass
	cursor["state"] = next_state
	if int(cursor.get("safety", 0)) >= 100:
		_log(next_state, "The initiative clock stalls.")
		cursor["complete"] = true
	_record_runtime_performance_phase("enemy_preview_slice_total", performance_total_started)
	return cursor

func revealed_enemy_actions_preview_result(cursor: Dictionary) -> Dictionary:
	return {
		"state": cursor.get("state", {}) as Dictionary,
		"steps": cursor.get("steps", []) as Array,
		"player_turn_before_state": cursor.get("player_turn_before_state", {}) as Dictionary,
		"unrevealed_before_player": bool(cursor.get("unrevealed_before_player", false)),
	}

func resolve_enemy_phase(state: Dictionary) -> Dictionary:
	return (resolve_enemy_phase_with_steps(state).get("state", state.duplicate(true)) as Dictionary).duplicate(true)

func resolve_enemy_turn_with_steps(state: Dictionary, enemy_index: int, include_commit_steps: bool = true) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state.duplicate(true)
	_record_runtime_performance_phase("enemy_turn_initial_duplicate", performance_total_started)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(next_state.get("rng_state", 0))
	var steps: Array[Dictionary] = []
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		_record_runtime_performance_phase("enemy_turn_total", performance_total_started)
		return {"state": next_state, "steps": steps, "time_cost": 0}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		_record_runtime_performance_phase("enemy_turn_total", performance_total_started)
		return {"state": next_state, "steps": steps, "time_cost": 0}
	next_state["current_actor"] = _enemy_actor_entry(next_state, enemy, int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
	var intent: Dictionary = (enemy.get("intent", {}) as Dictionary).duplicate(true)
	var turn_time_cost: int = _enemy_intent_time_cost(intent)
	var performance_phase_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var before_turn_setup: Dictionary = next_state.duplicate(true)
	enemy["block"] = 0
	(next_state.get("enemies", []) as Array)[enemy_index] = enemy
	var turn_setup: Dictionary = _resolve_enemy_start_of_turn(next_state, enemy_index)
	# _resolve_enemy_start_of_turn mutates the resolver-owned state and returns
	# that same ownership. Re-cloning it here only duplicates the whole combat.
	next_state = turn_setup.get("state", next_state) as Dictionary
	if include_commit_steps:
		_append_commit_step(steps, before_turn_setup, next_state, "enemy_turn_start")
	for step_var: Variant in turn_setup.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY:
			steps.append(_umbra_marked_enemy_status_step(before_turn_setup, next_state, step_var as Dictionary, int(enemy.get("id", -1))))
	_record_runtime_performance_phase("enemy_turn_setup_total", performance_phase_started)
	if combat_outcome(next_state) != "":
		next_state["rng_state"] = rng.state
		_record_runtime_performance_phase("enemy_turn_total", performance_total_started)
		return {"state": next_state, "steps": steps, "time_cost": turn_time_cost}
	if bool(turn_setup.get("skip_all", false)):
		performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
		var before_skip_resolution: Dictionary = next_state.duplicate(true) if include_commit_steps else {}
		var skip_enemies: Array = next_state.get("enemies", [])
		if enemy_index >= 0 and enemy_index < skip_enemies.size():
			var skip_enemy: Dictionary = _normalized_enemy(skip_enemies[enemy_index] as Dictionary)
			next_state = _clear_enemy_bleed_after_turn(next_state, enemy_index)
			if int(skip_enemy.get("hp", 0)) > 0:
				_assign_enemy_intent(next_state, enemy_index, rng)
		next_state["rng_state"] = rng.state
		if include_commit_steps:
			_append_commit_step(steps, before_skip_resolution, next_state, "enemy_turn_complete")
		var skip_refresh_step: Dictionary = _enemy_intent_refresh_step(next_state, int(enemy.get("id", -1)))
		if not skip_refresh_step.is_empty():
			steps.append(skip_refresh_step)
		_record_runtime_performance_phase("enemy_turn_skipped_complete_total", performance_phase_started)
		_record_runtime_performance_phase("enemy_turn_total", performance_total_started)
		return {"state": next_state, "steps": steps, "time_cost": 0}
	var shocked: bool = bool(turn_setup.get("shocked", false))
	var immobilized: bool = bool(turn_setup.get("immobilized", false))
	enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	intent = enemy.get("intent", {})
	if not intent.is_empty():
		performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
		steps.append(_enemy_intent_step_for_player(next_state, enemy, intent))
		var actions: Array = intent.get("actions", [])
		var activation_plan: Dictionary = enemy_intent_plan(next_state, enemy_index, intent, immobilized, shocked)
		_record_runtime_performance_phase("enemy_turn_plan_total", performance_phase_started)
		for action_index: int in range(actions.size()):
			var action_var: Variant = actions[action_index]
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var
			if combat_outcome(next_state) != "":
				break
			if shocked and not _enemy_action_is_movement(action):
				continue
			if immobilized and _enemy_action_is_movement(action):
				continue
			performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
			var before_state: Dictionary = next_state.duplicate(true)
			var followup_action: Dictionary = {}
			if not shocked:
				followup_action = _next_enemy_followup_attack_action(actions, action_index + 1)
			var action_context: Dictionary = activation_plan.duplicate(true)
			action_context["action_index"] = action_index
			var bleed_steps: Array[Dictionary] = []
			var enemy_id: int = int(enemy.get("id", -1))
			_record_runtime_performance_phase("enemy_turn_action_prepare", performance_phase_started)
			performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
			next_state = _resolve_enemy_action(next_state, enemy_index, action, rng, followup_action, bleed_steps, action_context)
			_record_runtime_performance_phase("enemy_turn_action_resolve_%s_total" % str(action.get("type", "other")), performance_phase_started)
			var presentation_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
			performance_phase_started = presentation_started
			var enemy_hidden_before: bool = _enemy_is_hidden_by_id(before_state, enemy_id)
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_visibility", performance_phase_started)
			_anonymize_hidden_enemy_action_logs(before_state, next_state, enemy_id, action, enemy_hidden_before)
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_anonymize", performance_phase_started)
			_record_hidden_umbra_attack_damage(before_state, next_state, enemy_id, enemy_hidden_before)
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_hidden_damage", performance_phase_started)
			next_state["rng_state"] = rng.state
			if include_commit_steps:
				_append_commit_step(steps, before_state, next_state, "enemy_action")
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_commit_total", performance_phase_started)
			for bleed_step: Dictionary in bleed_steps:
				steps.append(_umbra_marked_enemy_status_step(before_state, next_state, bleed_step, int(enemy.get("id", -1))))
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_bleed_steps", performance_phase_started)
			var raw_step: Dictionary = _enemy_action_step(before_state, next_state, enemy_index, action, action_context)
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_step_build", performance_phase_started)
			var step: Dictionary = _umbra_marked_enemy_action_step(before_state, next_state, raw_step, enemy_id, enemy_hidden_before)
			performance_phase_started = _record_runtime_performance_phase("enemy_turn_action_umbra_mark", performance_phase_started)
			if not step.is_empty():
				steps.append(step)
			_record_runtime_performance_phase("enemy_turn_action_append", performance_phase_started)
			_record_runtime_performance_phase("enemy_turn_action_presentation_total", presentation_started)
	performance_phase_started = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var before_turn_complete: Dictionary = next_state.duplicate(true) if include_commit_steps else {}
	if combat_outcome(next_state) == "":
		var post_turn_enemies: Array = next_state.get("enemies", [])
		if enemy_index >= 0 and enemy_index < post_turn_enemies.size():
			var post_turn_enemy: Dictionary = _normalized_enemy(post_turn_enemies[enemy_index] as Dictionary)
			if int(post_turn_enemy.get("hp", 0)) > 0:
				next_state = _clear_enemy_bleed_after_turn(next_state, enemy_index)
				_assign_enemy_intent(next_state, enemy_index, rng)
	next_state["rng_state"] = rng.state
	if include_commit_steps:
		_append_commit_step(steps, before_turn_complete, next_state, "enemy_turn_complete")
	var refresh_step: Dictionary = _enemy_intent_refresh_step(next_state, int(enemy.get("id", -1)))
	if not refresh_step.is_empty():
		steps.append(refresh_step)
	_record_runtime_performance_phase("enemy_turn_complete_total", performance_phase_started)
	_record_runtime_performance_phase("enemy_turn_total", performance_total_started)
	return {
		"state": next_state,
		"steps": steps,
		"time_cost": turn_time_cost
	}

func enemy_threat_tiles(state: Dictionary, enemy_index: int) -> Dictionary:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"move": [], "attack": [], "projected_path": [], "projected_attack": []}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return {"move": [], "attack": [], "projected_path": [], "projected_attack": []}
	if not is_enemy_visible_to_player(state, enemy):
		return {"move": [], "attack": [], "projected_path": [], "projected_attack": []}
	var intent: Dictionary = enemy.get("intent", {})
	if intent.is_empty():
		return {"move": [], "attack": [], "projected_path": [], "projected_attack": []}
	var enemy_definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var frozen: bool = int(enemy.get("freeze", 0)) > 0
	var shocked: bool = int(enemy.get("shock", 0)) > 0
	var immobilized: bool = bool(enemy.get("immobilize", false))
	var plan: Dictionary = enemy_intent_plan(state, enemy_index, intent, frozen or immobilized, frozen or shocked)
	var occupied: Dictionary = _enemy_threat_path_blockers(state, enemy, true, true)
	var blocked_target: Vector2i = Vector2i(-999, -999)
	var frontier: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var move_lookup: Dictionary = {}
	var attack_lookup: Dictionary = {}
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if not enemy_action_can_resolve(state, action):
			continue
		match str(action.get("type", "")):
			"move_toward", "move_away":
				var next_lookup: Dictionary = {}
				for start_tile: Vector2i in frontier:
					next_lookup[start_tile] = true
					for move_tile: Vector2i in _threat_movement_tiles(state, enemy, start_tile, action, occupied, blocked_target):
						move_lookup[move_tile] = true
						next_lookup[move_tile] = true
				if not next_lookup.is_empty():
					frontier = _sorted_tiles_from_lookup(next_lookup)
			"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
				for start_tile: Vector2i in frontier:
					for attack_tile: Vector2i in _threat_attack_tiles(state, enemy, start_tile, action):
						attack_lookup[attack_tile] = true
			"terrain_burst", "cinder_marks", "detonate_cinders", "gale_force", "umbra_eclipse":
				for attack_tile: Vector2i in _boss_action_threat_tiles(state, enemy, action):
					attack_lookup[attack_tile] = true
	return {
		"move": _sorted_tiles_from_lookup(move_lookup),
		"attack": _sorted_tiles_from_lookup(attack_lookup),
		"projected_path": _vector2i_values(plan.get("path", [])),
		"projected_route": _vector2i_values(plan.get("route", [])),
		"projected_destination": plan.get("destination", enemy.get("pos", Vector2i.ZERO)),
		"projected_attack": _vector2i_values(plan.get("projected_attack", [])),
		"projected_target_key": str(plan.get("target_key", "")),
		"projected_attack_action": (plan.get("attack_action", {}) as Dictionary).duplicate(true),
		"projected_attack_element": str((plan.get("attack_action", {}) as Dictionary).get("element", enemy_definition.get("element", ElementData.NONE))),
		"projected_attack_from": plan.get("destination", enemy.get("pos", Vector2i.ZERO)),
		"projected_attack_target": plan.get("projected_attack_target", INVALID_TILE)
	}

func resolve_enemy_phase_with_steps(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(next_state.get("rng_state", 0))
	var steps: Array[Dictionary] = []
	for enemy_index: int in range((next_state.get("enemies", []) as Array).size()):
		if combat_outcome(next_state) != "":
			break
		var enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["block"] = 0
		(next_state.get("enemies", []) as Array)[enemy_index] = enemy
		var before_turn_setup: Dictionary = next_state.duplicate(true)
		var turn_setup: Dictionary = _resolve_enemy_start_of_turn(next_state, enemy_index)
		next_state = (turn_setup.get("state", next_state) as Dictionary).duplicate(true)
		for step_var: Variant in turn_setup.get("steps", []):
			if typeof(step_var) == TYPE_DICTIONARY:
				steps.append(_umbra_marked_enemy_status_step(before_turn_setup, next_state, step_var as Dictionary, int(enemy.get("id", -1))))
		if combat_outcome(next_state) != "":
			break
		if bool(turn_setup.get("skip_all", false)):
			var skip_enemies: Array = next_state.get("enemies", [])
			if enemy_index >= 0 and enemy_index < skip_enemies.size():
				var skip_enemy: Dictionary = _normalized_enemy(skip_enemies[enemy_index] as Dictionary)
				next_state = _clear_enemy_bleed_after_turn(next_state, enemy_index)
				if int(skip_enemy.get("hp", 0)) > 0:
					_assign_enemy_intent(next_state, enemy_index, rng)
			continue
		var shocked: bool = bool(turn_setup.get("shocked", false))
		var immobilized: bool = bool(turn_setup.get("immobilized", false))
		enemy = _normalized_enemy((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		var intent: Dictionary = enemy.get("intent", {})
		if not intent.is_empty():
			steps.append(_enemy_intent_step_for_player(next_state, enemy, intent))
			var actions: Array = intent.get("actions", [])
			var activation_plan: Dictionary = enemy_intent_plan(next_state, enemy_index, intent, immobilized, shocked)
			for action_index: int in range(actions.size()):
				var action_var: Variant = actions[action_index]
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action: Dictionary = action_var
				if combat_outcome(next_state) != "":
					break
				if shocked and not _enemy_action_is_movement(action):
					continue
				if immobilized and _enemy_action_is_movement(action):
					continue
				var before_state: Dictionary = next_state.duplicate(true)
				var followup_action: Dictionary = {}
				if not shocked:
					followup_action = _next_enemy_followup_attack_action(actions, action_index + 1)
				var action_context: Dictionary = activation_plan.duplicate(true)
				action_context["action_index"] = action_index
				var bleed_steps: Array[Dictionary] = []
				var enemy_id: int = int(enemy.get("id", -1))
				var enemy_hidden_before: bool = _enemy_is_hidden_by_id(before_state, enemy_id)
				next_state = _resolve_enemy_action(next_state, enemy_index, action, rng, followup_action, bleed_steps, action_context)
				_anonymize_hidden_enemy_action_logs(before_state, next_state, enemy_id, action, enemy_hidden_before)
				_record_hidden_umbra_attack_damage(before_state, next_state, enemy_id, enemy_hidden_before)
				for bleed_step: Dictionary in bleed_steps:
					steps.append(_umbra_marked_enemy_status_step(before_state, next_state, bleed_step, int(enemy.get("id", -1))))
				var step: Dictionary = _umbra_marked_enemy_action_step(before_state, next_state, _enemy_action_step(before_state, next_state, enemy_index, action, action_context), enemy_id, enemy_hidden_before)
				if not step.is_empty():
					steps.append(step)
		if combat_outcome(next_state) == "":
			var post_turn_enemies: Array = next_state.get("enemies", [])
			if enemy_index >= 0 and enemy_index < post_turn_enemies.size():
				var post_turn_enemy: Dictionary = _normalized_enemy(post_turn_enemies[enemy_index] as Dictionary)
				if int(post_turn_enemy.get("hp", 0)) > 0:
					next_state = _clear_enemy_bleed_after_turn(next_state, enemy_index)
					_assign_enemy_intent(next_state, enemy_index, rng)
	next_state["rng_state"] = rng.state
	return {
		"state": next_state,
		"steps": steps
	}

func prepare_next_player_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "":
		return next_state
	next_state["current_actor"] = _player_actor_entry(int(next_state.get("initiative_clock", 0)), int(next_state.get("activation_seq", 0)))
	next_state["player_turn_ending"] = false
	next_state["banked_play_active"] = clampi(int(next_state.get("banked_plays", 0)), 0, 1)
	next_state["banked_plays"] = 0
	next_state["banked_play_spent_this_activation"] = 0
	next_state = _tick_umbra_player_activation(next_state)
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	player["block"] = 0
	next_state["player"] = player
	next_state["turn"] = int(next_state.get("turn", 1)) + 1
	next_state["player_turn_time_spent"] = 0
	next_state["cards_played_this_turn"] = 0
	next_state["player_movement_capacity"] = player_movement_capacity(next_state)
	next_state["player_movement_remaining"] = int(next_state.get("player_movement_capacity", BASE_PLAYER_MOVEMENT))
	next_state["death_bonus_card_plays_this_turn"] = 0
	next_state["card_play_bonus_this_turn"] = maxi(0, int(next_state.get("pending_relic_card_plays", 0)))
	next_state["pending_relic_card_plays"] = 0
	next_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
	}
	next_state["pending_player_trap_restriction"] = ""
	next_state["turn_flags"] = {
		"first_attack_bonus_used": false,
		"first_move_bonus_used": false
	}
	next_state = _resolve_player_start_of_turn(next_state)
	if combat_outcome(next_state) != "":
		return next_state
	next_state = _draw_cards_in_place(next_state, int(next_state.get("draw_per_turn", BASE_DRAW_PER_TURN)))
	var restrictions: Dictionary = next_state.get("player_turn_restrictions", {})
	if bool(restrictions.get("frozen", false)):
		next_state["cards_played_this_turn"] = _card_play_capacity(next_state)
	return next_state

func player_movement_capacity(state: Dictionary) -> int:
	return maxi(
		0,
		BASE_PLAYER_MOVEMENT + GameData.stat_bonus_from_relics(state.get("relics", []), "movement_pool_bonus")
	)

func player_movement_remaining(state: Dictionary) -> int:
	if not is_player_turn(state):
		return 0
	var capacity: int = player_movement_capacity(state)
	return clampi(int(state.get("player_movement_remaining", capacity)), 0, capacity)

func normalize_player_movement_pool(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var capacity: int = player_movement_capacity(next_state)
	next_state["player_movement_capacity"] = capacity
	next_state["player_movement_remaining"] = clampi(
		int(next_state.get("player_movement_remaining", capacity)),
		0,
		capacity
	)
	return next_state

func player_movement_action(state: Dictionary) -> Dictionary:
	var remaining: int = player_movement_remaining(state)
	if remaining <= 0 or combat_outcome(state) != "":
		return {}
	var ghost_stride_id: String = SkillTreeLibrary.skill_id_for_effect("arm_movement_blink")
	var ghost_stride_armed: bool = bool((state.get("skill_flags", {}) as Dictionary).get("movement_blink_armed", false))
	if not ghost_stride_id.is_empty() and ghost_stride_armed and has_skill(state, ghost_stride_id) and not skill_was_used(state, ghost_stride_id):
		var effect: Dictionary = SkillTreeLibrary.effect(ghost_stride_id)
		return {
			"type": "blink",
			"range": mini(remaining, maxi(1, int(effect.get("range", remaining)))),
			"_movement_pool": true,
			"_skill_id": ghost_stride_id,
			"_card_action_types": ["blink"]
		}
	return {
		"type": "move",
		"range": remaining,
		"_movement_pool": true,
		"_card_action_types": ["move"]
	}

func player_movement_targets(state: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = player_movement_action(state)
	if action.is_empty():
		return []
	return valid_targets_for_player_action(state, action)

func apply_player_movement(state: Dictionary, target_tile: Vector2i) -> Dictionary:
	var movement_state: Dictionary = state.duplicate(true)
	# This field describes only the current request. Leaving an older successful
	# result in place lets a stale UI target masquerade as a newly committed move.
	movement_state.erase("last_player_movement")
	var action: Dictionary = player_movement_action(movement_state)
	if action.is_empty() or not valid_targets_for_player_action(movement_state, action).has(target_tile):
		return movement_state
	var origin: Vector2i = (_normalized_player(movement_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var planned_path: Array[Vector2i] = path_for_player_action(movement_state, action, target_tile)
	var next_state: Dictionary = apply_player_action(movement_state, action, target_tile)
	var destination: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", origin)
	var spent: int = 0
	if destination != origin:
		if str(action.get("type", "")) == "blink":
			spent = PathUtils.manhattan(origin, destination)
		else:
			spent = maxi(0, _movement_path_through_endpoint(planned_path, destination).size() - 1)
	var remaining_before: int = player_movement_remaining(movement_state)
	next_state["player_movement_capacity"] = player_movement_capacity(next_state)
	next_state["player_movement_remaining"] = maxi(0, remaining_before - spent)
	next_state["last_player_movement"] = {
		"action_type": str(action.get("type", "move")),
		"origin": origin,
		"target": target_tile,
		"destination": destination,
		"spent": spent,
		"remaining_before": remaining_before,
		"remaining_after": int(next_state.get("player_movement_remaining", 0)),
		"capacity": int(next_state.get("player_movement_capacity", BASE_PLAYER_MOVEMENT))
	}
	if spent > 0 and bool((next_state.get("skill_flags", {}) as Dictionary).get("movement_blink_armed", false)):
		_erase_skill_flag(next_state, "movement_blink_armed")
	return next_state

func cards_remaining_this_turn(state: Dictionary) -> int:
	if not is_player_turn(state):
		return 0
	return maxi(
		0,
		_card_play_capacity(state) - int(state.get("cards_played_this_turn", 0))
	)

func player_turn_resources_exhausted(state: Dictionary) -> bool:
	return (
		combat_outcome(state) == ""
		and is_player_turn(state)
		and cards_remaining_this_turn(state) <= 0
		and player_movement_remaining(state) <= 0
	)

func card_play_budget(state: Dictionary) -> Dictionary:
	var total_remaining: int = cards_remaining_this_turn(state)
	var banked_capacity: int = clampi(int(state.get("banked_play_active", 0)), 0, 1)
	var banked_spent: int = clampi(int(state.get("banked_play_spent_this_activation", 0)), 0, banked_capacity)
	var ordinary_spent: int = maxi(0, int(state.get("cards_played_this_turn", 0)) - banked_spent)
	var ordinary_remaining: int = maxi(0, _card_play_capacity_without_banked(state) - ordinary_spent)
	var banked_remaining: int = maxi(0, banked_capacity - banked_spent)
	ordinary_remaining = mini(ordinary_remaining, total_remaining)
	banked_remaining = mini(banked_remaining, maxi(0, total_remaining - ordinary_remaining))
	return {
		"ordinary_remaining": ordinary_remaining,
		"banked_remaining": banked_remaining,
		"total_remaining": total_remaining
	}

func _card_play_capacity(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", BASE_CARDS_PER_TURN))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
		+ int(state.get("banked_play_active", 0))
	)

func attack_bonus_for_current_turn(state: Dictionary) -> int:
	return _attack_bonus_for_current_turn(state)

func move_bonus_for_current_turn(state: Dictionary) -> int:
	return _move_bonus_for_current_turn(state)

func aoe_tiles_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var center: Vector2i = target_tile if int(action.get("range", 0)) > 0 and target_tile.x >= 0 else player_pos
	return _best_aoe_tiles_for_target(state, action, center, false)

func forced_movement_tiles_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var force_direction: Vector2i = _action_force_direction(resolved_action)
	if force_direction == Vector2i.ZERO:
		return []
	if not force_directions_for_player_action(state, action, target_tile).has(force_direction):
		return []
	var enemy_index: int = _enemy_index_at_tile(state, target_tile)
	if enemy_index < 0:
		return []
	var amount: int = _forced_movement_amount(resolved_action)
	if amount <= 0:
		return []
	return _enemy_direction_path(state, enemy_index, force_direction, amount)

func force_directions_for_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var enemy_index: int = _enemy_index_at_tile(state, target_tile)
	if enemy_index < 0:
		return []
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	return _force_directions_for_enemy(
		state,
		enemy_index,
		player_pos,
		_forced_movement_pushes(resolved_action),
		_forced_movement_amount(resolved_action)
	)

func final_damage_for_player_action(state: Dictionary, action: Dictionary) -> int:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	return _final_damage_for_resolved_player_action(state, resolved_action, _relic_effects(state))

func _final_damage_for_resolved_player_action(state: Dictionary, resolved_action: Dictionary, relic_effects: Array[Dictionary]) -> int:
	var action_type: String = str(resolved_action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return int(resolved_action.get("damage", 0))
	var base_damage: int = int(resolved_action.get("damage", 0))
	return maxi(
		0,
		base_damage
		+ _attack_bonus_for_current_turn_from_effects(state, relic_effects)
		+ _conditional_attack_bonus_for_action_from_effects(state, resolved_action, relic_effects)
	)

func damage_modifiers_for_player_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var action_type: String = str(action.get("type", ""))
	if action_type not in ATTACK_ACTION_TYPES:
		return modifiers
	var attack_bonus: int = _attack_bonus_for_current_turn(state)
	if attack_bonus != 0:
		modifiers.append({
			"source": "Duelist Whetstone",
			"kind": "relic",
			"amount": attack_bonus,
			"detail": "First attack this turn"
		})
	for modifier: Dictionary in _intensity_bonus_damage_modifiers_for_action(state, action):
		modifiers.append(modifier)
	for modifier: Dictionary in _conditional_attack_modifiers_for_action(state, action):
		modifiers.append(modifier)
	return modifiers

func elemental_intensities(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw: Variant = state.get("elemental_intensity", {})
	var source: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		source = raw as Dictionary
	for element_id: String in ElementData.all_elements():
		result[element_id] = maxi(0, int(source.get(element_id, 0)))
	return result

func elemental_intensity(state: Dictionary, element_id: String) -> int:
	if not ElementData.is_elemental(element_id):
		return 0
	return int(elemental_intensities(state).get(element_id, 0))

func condition_intensity(state: Dictionary, element_id: String) -> int:
	if not ElementData.is_elemental(element_id):
		return 0
	var flags: Dictionary = state.get("skill_flags", {}) as Dictionary
	if bool(flags.get("prismatic_resolving", false)):
		return 999
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("highest_intensity")
	if has_skill(state, skill_id):
		var highest: int = 0
		for intensity_var: Variant in elemental_intensities(state).values():
			highest = maxi(highest, int(intensity_var))
		return highest
	return elemental_intensity(state, element_id)

func _action_condition_uses_confluence(state: Dictionary, action: Dictionary) -> bool:
	var requirement: Dictionary = _action_intensity_requirement(action)
	if requirement.is_empty():
		return false
	var flags: Dictionary = state.get("skill_flags", {}) as Dictionary
	if bool(flags.get("prismatic_resolving", false)):
		return false
	var element_id: String = str(requirement.get("element", ElementData.NONE))
	var threshold: int = int(requirement.get("amount", 0))
	if elemental_intensity(state, element_id) >= threshold:
		return false
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("highest_intensity")
	return has_skill(state, skill_id) and condition_intensity(state, element_id) >= threshold

func _action_gains_confluence_benefit(state: Dictionary, action: Dictionary) -> bool:
	var flags: Dictionary = state.get("skill_flags", {}) as Dictionary
	if bool(flags.get("prismatic_resolving", false)):
		return false
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("highest_intensity")
	if not has_skill(state, skill_id):
		return false
	var requirements: Array[Dictionary]
	var action_requirement: Dictionary = _action_intensity_requirement(action)
	if not action_requirement.is_empty():
		requirements.append(action_requirement)
	var bonus_requirement: Dictionary = _action_intensity_bonus_requirement(action)
	if not bonus_requirement.is_empty():
		requirements.append(bonus_requirement)
	for requirement: Dictionary in requirements:
		var element_id: String = str(requirement.get("element", ElementData.NONE))
		var threshold: int = int(requirement.get("amount", 0))
		if elemental_intensity(state, element_id) < threshold and condition_intensity(state, element_id) >= threshold:
			return true
	return false

func _mark_first_confluence_benefit(state: Dictionary, action: Dictionary) -> void:
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("highest_intensity")
	if skill_was_used(state, skill_id) or not _action_gains_confluence_benefit(state, action):
		return
	_mark_skill_used(
		state,
		skill_id,
		"%s lets the highest elemental intensity satisfy this card." % SkillTreeLibrary.display_name(skill_id)
	)

func elemental_intensity_counter(state: Dictionary, counter_key: String) -> Dictionary:
	var result: Dictionary = _empty_elemental_intensity()
	var raw: Variant = state.get(counter_key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = raw as Dictionary
	for element_id: String in ElementData.all_elements():
		result[element_id] = maxi(0, int(source.get(element_id, 0)))
	return result

func action_intensity_requirement(action: Dictionary) -> Dictionary:
	return _action_intensity_requirement(action)

func action_intensity_requirement_met(state: Dictionary, action: Dictionary) -> bool:
	var requirement: Dictionary = _action_intensity_requirement(action)
	if requirement.is_empty():
		return true
	return condition_intensity(state, str(requirement.get("element", ElementData.NONE))) >= int(requirement.get("amount", 0))

func action_intensity_spend(action: Dictionary) -> Dictionary:
	if str(action.get("type", "")) == "intensity_spend":
		return ElementalIntensityRules.normalized_cost(action, _action_intensity_element(action))
	return ElementalIntensityRules.action_spend(action)

func action_intensity_spend_requirement_met(state: Dictionary, action: Dictionary) -> bool:
	var spend: Dictionary = action_intensity_spend(action)
	if spend.is_empty():
		return true
	return elemental_intensity(state, str(spend.get("element", ElementData.NONE))) >= int(spend.get("amount", 0))

func enemy_action_can_resolve(state: Dictionary, action: Dictionary) -> bool:
	return action_intensity_requirement_met(state, action) and action_intensity_spend_requirement_met(state, action)

func action_intensity_bonus(action: Dictionary) -> Dictionary:
	return _action_intensity_bonus(action)

func action_intensity_bonus_requirement(action: Dictionary) -> Dictionary:
	return _action_intensity_bonus_requirement(action)

func action_intensity_bonus_requirement_met(state: Dictionary, action: Dictionary) -> bool:
	var requirement: Dictionary = _action_intensity_bonus_requirement(action)
	if requirement.is_empty():
		return false
	return condition_intensity(state, str(requirement.get("element", ElementData.NONE))) >= int(requirement.get("amount", 0))

func trap_damage(state: Dictionary, trap: Dictionary) -> int:
	var element_id: String = str(trap.get("element", state.get("room_element", ElementData.NONE)))
	var intensity: int = elemental_intensity(state, element_id)
	return ElementalIntensityRules.scaled_trap_damage(int(trap.get("base_damage", trap.get("damage", 0))), intensity)

func combat_outcome(state: Dictionary) -> String:
	if int((state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
		return "defeat"
	if str(state.get("room_type", "")) == "boss":
		for enemy: Dictionary in _live_enemies(state):
			if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
				return ""
		return "victory"
	var objective: Dictionary = state.get("objective", {}) as Dictionary
	match str(objective.get("type", CombatObjectiveRules.KILL_ALL)):
		CombatObjectiveRules.KILL_LEADER:
			var leader_id: int = int(objective.get("leader_id", -1))
			var leader_index: int = _enemy_index_for_id(state, leader_id)
			if leader_index < 0:
				for index: int in range((state.get("enemies", []) as Array).size()):
					if bool(((state.get("enemies", []) as Array)[index] as Dictionary).get("is_leader", false)):
						leader_index = index
						break
			if leader_index < 0:
				return "victory" if _live_enemies(state).is_empty() else ""
			var leader: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[leader_index] as Dictionary)
			return "victory" if int(leader.get("hp", 0)) <= 0 else ""
		CombatObjectiveRules.SURVIVE:
			if int(state.get("initiative_clock", 0)) >= int(objective.get("target_clock", 0)):
				return "victory"
			return ""
		CombatObjectiveRules.REACH_EXIT:
			var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
			if CombatObjectiveRules.exit_target_tiles(objective).has(player_tile):
				return "victory"
			return ""
	if _live_enemies(state).is_empty():
		return "victory"
	return ""

func post_combat_board_state(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "victory":
		return next_state
	var objective: Dictionary = next_state.get("objective", {}) as Dictionary
	if str(objective.get("type", CombatObjectiveRules.KILL_ALL)) == CombatObjectiveRules.REACH_EXIT:
		return next_state
	var enemies: Array = next_state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		if int(enemy.get("hp", 0)) > 0:
			enemy["hp"] = 0
			enemy["objective_cleared"] = true
		enemies[index] = enemy
	next_state["enemies"] = enemies
	return next_state

func resolve_missed_equipment_after_victory(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if combat_outcome(next_state) != "victory":
		return next_state
	var missed_equipment: Array = next_state.get("missed_equipment", []).duplicate()
	var loot_entries: Array = next_state.get("loot", []).duplicate(true)
	for index: int in range(loot_entries.size()):
		if typeof(loot_entries[index]) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = (loot_entries[index] as Dictionary).duplicate(true)
		if str(loot.get("kind", "")) not in ["equipment", "item"] or bool(loot.get("claimed", false)):
			continue
		# Left-behind items disappear with the room; only equipment is salvageable.
		var equipment_id: String = str(loot.get("equipment_id", ""))
		if not equipment_id.is_empty() and not missed_equipment.has(equipment_id):
			missed_equipment.append(equipment_id)
		loot["claimed"] = true
		loot["resolution"] = "missed"
		loot_entries[index] = loot
	next_state["loot"] = loot_entries
	next_state["missed_equipment"] = missed_equipment
	return next_state

func _resolve_enemy_intent(state: Dictionary, enemy_index: int, intent: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemy: Dictionary = ((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	if is_enemy_visible_to_player(next_state, enemy):
		_log(next_state, "%s prepares %s." % [
			str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
			str(intent.get("name", "an action"))
		])
	else:
		_log(next_state, "Something stirs in the Umbra.")
	var actions: Array = intent.get("actions", [])
	var activation_plan: Dictionary = enemy_intent_plan(next_state, enemy_index, intent)
	for action_index: int in range(actions.size()):
		if typeof(actions[action_index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[action_index]
		if combat_outcome(next_state) != "":
			break
		var before_action: Dictionary = next_state.duplicate(true)
		var enemy_id: int = int(enemy.get("id", -1))
		var enemy_hidden_before: bool = _enemy_is_hidden_by_id(before_action, enemy_id)
		var action_context: Dictionary = activation_plan.duplicate(true)
		action_context["action_index"] = action_index
		next_state = _resolve_enemy_action(next_state, enemy_index, action, null, {}, [], action_context)
		_anonymize_hidden_enemy_action_logs(before_action, next_state, enemy_id, action, enemy_hidden_before)
		_record_hidden_umbra_attack_damage(before_action, next_state, enemy_id, enemy_hidden_before)
	return next_state

func _enemy_intent_step_for_player(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var hidden: bool = not is_enemy_visible_to_player(state, enemy)
	return {
		"kind": "intent",
		"actor_key": _enemy_key(enemy),
		"actor_name": "Unknown Presence" if hidden else str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		"tile": Vector2i(-1, -1) if hidden else enemy.get("pos", Vector2i.ZERO),
		"intent_name": "Hidden Intent" if hidden else str(intent.get("name", "Action")),
		"hidden_by_umbra": hidden
	}

func _enemy_intent_refresh_step(state: Dictionary, enemy_id: int) -> Dictionary:
	var enemy_index: int = _enemy_index_for_id(state, enemy_id)
	if enemy_index < 0:
		return {}
	var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return {}
	var intent: Dictionary = enemy.get("intent", {}) as Dictionary
	if intent.is_empty():
		return {}
	return {
		"kind": "intent_refresh",
		"actor_key": _enemy_key(enemy),
		"intent": intent.duplicate(true),
	}

func _enemy_visibility_for_player_by_id(state: Dictionary, enemy_id: int) -> int:
	var enemy_index: int = _enemy_index_for_id(state, enemy_id)
	if enemy_index < 0:
		return -1
	var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
	return 1 if is_enemy_visible_to_player(state, enemy) else 0

func _enemy_is_hidden_by_id(state: Dictionary, enemy_id: int) -> bool:
	return _enemy_visibility_for_player_by_id(state, enemy_id) == 0

func _umbra_marked_enemy_action_step(before_state: Dictionary, after_state: Dictionary, step: Dictionary, enemy_id: int, enemy_hidden_before_value: Variant = null) -> Dictionary:
	if step.is_empty():
		return step
	var presented: Dictionary = step.duplicate(true)
	var acting_enemy_index: int = _enemy_index_for_id(before_state, enemy_id)
	if acting_enemy_index >= 0:
		var acting_enemy: Dictionary = _normalized_enemy((before_state.get("enemies", []) as Array)[acting_enemy_index] as Dictionary)
		var enemy_type: String = str(acting_enemy.get("type", ""))
		var ai_profile: Dictionary = GameData.enemy_def(enemy_type).get("ai_profile", {}) as Dictionary
		presented["enemy_type"] = enemy_type
		presented["ai_role"] = str(ai_profile.get("role", ""))
		presented["intent_id"] = str((acting_enemy.get("intent", {}) as Dictionary).get("id", ""))
	var intensity_gained: Dictionary = {}
	var intensity_spent: Dictionary = {}
	var before_intensities: Dictionary = elemental_intensities(before_state)
	var after_intensities: Dictionary = elemental_intensities(after_state)
	for element_id: String in ElementData.all_elements():
		var before_value: int = int(before_intensities.get(element_id, 0))
		var after_value: int = int(after_intensities.get(element_id, 0))
		if after_value > before_value:
			intensity_gained[element_id] = after_value - before_value
		elif after_value < before_value:
			intensity_spent[element_id] = before_value - after_value
	if not intensity_gained.is_empty():
		presented["elemental_intensity_gained"] = intensity_gained
	if not intensity_spent.is_empty():
		presented["elemental_intensity_spent"] = intensity_spent
	var enemy_hidden_before: bool = (
		_enemy_is_hidden_by_id(before_state, enemy_id)
		if enemy_hidden_before_value == null
		else bool(enemy_hidden_before_value)
	)
	if not enemy_hidden_before:
		return presented
	presented["hidden_by_umbra"] = true
	presented["revealed_after_action"] = _enemy_visibility_for_player_by_id(after_state, enemy_id) == 1
	return presented

func _umbra_marked_enemy_status_step(before_state: Dictionary, after_state: Dictionary, step: Dictionary, enemy_id: int) -> Dictionary:
	var presented: Dictionary = _umbra_marked_enemy_action_step(before_state, after_state, step, enemy_id)
	if not bool(presented.get("hidden_by_umbra", false)):
		return presented
	presented["actor_name"] = "Unknown Presence"
	presented["tile"] = Vector2i(-1, -1)
	return presented

func _anonymize_hidden_enemy_action_logs(before_state: Dictionary, after_state: Dictionary, enemy_id: int, action: Dictionary, enemy_hidden_before_value: Variant = null) -> void:
	var enemy_hidden_before: bool = (
		_enemy_is_hidden_by_id(before_state, enemy_id)
		if enemy_hidden_before_value == null
		else bool(enemy_hidden_before_value)
	)
	if not enemy_hidden_before:
		return
	var before_logs: Array = before_state.get("log", []) as Array
	var logs: Array = (after_state.get("log", []) as Array).duplicate()
	if logs.size() <= before_logs.size():
		return
	logs.resize(before_logs.size())
	var action_type: String = str(action.get("type", ""))
	logs.append("A hidden presence attacks." if action_type in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"] else "Something shifts in the Umbra.")
	after_state["log"] = logs

func _record_hidden_umbra_attack_damage(before_state: Dictionary, after_state: Dictionary, enemy_id: int, enemy_hidden_before_value: Variant = null) -> void:
	var enemy_hidden_before: bool = (
		_enemy_is_hidden_by_id(before_state, enemy_id)
		if enemy_hidden_before_value == null
		else bool(enemy_hidden_before_value)
	)
	if not enemy_hidden_before:
		return
	var hp_loss: int = 0
	for loss: Dictionary in _actor_target_losses(before_state, after_state):
		if str(loss.get("kind", "")) == "player":
			hp_loss += maxi(0, int(loss.get("hp_loss", 0)))
	if hp_loss <= 0:
		return
	var umbra: Dictionary = (after_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["hidden_attack_damage_received_total"] = int(umbra.get("hidden_attack_damage_received_total", 0)) + hp_loss
	after_state["umbra"] = umbra

func _enemy_action_step(before_state: Dictionary, after_state: Dictionary, enemy_index: int, action: Dictionary, action_context: Dictionary = {}) -> Dictionary:
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = after_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= before_enemies.size() or enemy_index >= after_enemies.size():
		return {}
	var before_enemy: Dictionary = before_enemies[enemy_index]
	var after_enemy: Dictionary = after_enemies[enemy_index]
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var action_type: String = str(action.get("type", ""))
	var enemy_definition: Dictionary = GameData.enemy_def(str(after_enemy.get("type", "")))
	var actor_name: String = str(enemy_definition.get("name", "Enemy"))
	var attack_element: String = str(action.get("element", enemy_definition.get("element", ElementData.NONE)))
	match action_type:
		"move_toward", "move_away":
			var from_tile: Vector2i = before_enemy.get("pos", Vector2i.ZERO)
			var to_tile: Vector2i = after_enemy.get("pos", Vector2i.ZERO)
			if from_tile == to_tile:
				return {}
			var resolved_path: Array[Vector2i] = _vector2i_values(action_context.get("resolved_path", action_context.get("path", [])))
			if resolved_path.is_empty():
				resolved_path = _vector2i_values([from_tile, to_tile])
			var target_losses: Array[Dictionary] = _actor_target_losses(before_state, after_state)
			var enemy_losses: Array[Dictionary] = _enemy_target_losses(before_state, after_state)
			var terrain_losses: Array[Dictionary] = _terrain_target_losses(before_state, after_state)
			var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
			return {
				"kind": "move",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": from_tile,
				"to": to_tile,
				"path": resolved_path,
				"target_key": str(action_context.get("target_key", "")),
				"target_losses": target_losses,
				"enemy_losses": enemy_losses,
				"terrain_losses": terrain_losses,
				"triggered_traps": triggered_traps,
				"impact_actor_keys": _target_loss_keys(target_losses) + _target_loss_keys(enemy_losses),
				"label": "Advance" if action_type == "move_toward" else "Retreat"
			}
		"intensity":
			var element_id: String = _action_intensity_element(action)
			var before_value: int = elemental_intensity(before_state, element_id)
			var after_value: int = elemental_intensity(after_state, element_id)
			var gained: int = maxi(0, after_value - before_value)
			var enemy_losses: Array[Dictionary] = _enemy_target_losses(before_state, after_state)
			if gained <= 0 and before_value == after_value and enemy_losses.is_empty():
				return {}
			return {
				"kind": "intensity",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"element": element_id,
				"amount": gained,
				"value_before": before_value,
				"value_after": after_value,
				"enemy_losses": enemy_losses,
				"impact_actor_keys": _target_loss_keys(enemy_losses),
				"label": "%s Intensity %d" % [ElementData.name(element_id), after_value]
			}
		"block":
			var block_gain: int = int(after_enemy.get("block", 0)) - int(before_enemy.get("block", 0))
			if block_gain <= 0:
				return {}
			return {
				"kind": "block",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": block_gain,
				"sfx_id": str(action.get("sfx_id", action.get("block_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("block_sfx_category", ""))),
				"label": "Guard"
			}
		"stoneskin":
			var skin_gain: int = int(after_enemy.get("stoneskin", 0)) - int(before_enemy.get("stoneskin", 0))
			if skin_gain <= 0:
				return {}
			return {
				"kind": "stoneskin",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": skin_gain,
				"label": "Stoneskin"
			}
		"heal_self":
			var heal_amount: int = int(after_enemy.get("hp", 0)) - int(before_enemy.get("hp", 0))
			if heal_amount <= 0:
				return {}
			return {
				"kind": "heal",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": heal_amount,
				"label": "Heal"
			}
		"heal_ally":
			var heal_target_index: int = _enemy_support_target_index(before_state, enemy_index, action)
			if heal_target_index < 0 or heal_target_index >= before_enemies.size() or heal_target_index >= after_enemies.size():
				return {}
			var before_heal_target: Dictionary = before_enemies[heal_target_index]
			var after_heal_target: Dictionary = after_enemies[heal_target_index]
			var ally_heal_amount: int = int(after_heal_target.get("hp", 0)) - int(before_heal_target.get("hp", 0))
			if ally_heal_amount <= 0:
				return {}
			var heal_target_name: String = _enemy_display_name(after_heal_target)
			return {
				"kind": "heal",
				"actor_key": _enemy_key(after_heal_target),
				"actor_name": heal_target_name,
				"source_actor_key": _enemy_key(after_enemy),
				"source_actor_name": actor_name,
				"target_name": heal_target_name,
				"tile": after_heal_target.get("pos", Vector2i.ZERO),
				"amount": ally_heal_amount,
				"label": "Heal Self" if heal_target_index == enemy_index else "Heal Ally"
			}
		"guard_ally":
			if str(action.get("target_mode", "")) == "all_other_enemies":
				var guard_targets: Array[Dictionary] = []
				var guarded_actor_keys: Array[String] = []
				var guarded_tiles: Array[Vector2i] = []
				for target_index: int in range(mini(before_enemies.size(), after_enemies.size())):
					if target_index == enemy_index:
						continue
					var before_group_target: Dictionary = before_enemies[target_index]
					var after_group_target: Dictionary = after_enemies[target_index]
					if int(before_group_target.get("hp", 0)) <= 0:
						continue
					var group_guard_amount: int = int(after_group_target.get("block", 0)) - int(before_group_target.get("block", 0))
					if group_guard_amount <= 0:
						continue
					var guarded_key: String = _enemy_key(after_group_target)
					var guarded_tile: Vector2i = after_group_target.get("pos", Vector2i.ZERO)
					guard_targets.append({
						"actor_key": guarded_key,
						"actor_name": _enemy_display_name(after_group_target),
						"tile": guarded_tile,
						"amount": group_guard_amount
					})
					guarded_actor_keys.append(guarded_key)
					guarded_tiles.append(guarded_tile)
				if guard_targets.is_empty():
					return {}
				return {
					"kind": "block",
					"action_type": "guard_ally",
					"actor_key": _enemy_key(after_enemy),
					"actor_name": actor_name,
					"tile": after_enemy.get("pos", Vector2i.ZERO),
					"targets": guard_targets,
					"focus_actor_keys": guarded_actor_keys,
					"focus_tiles": guarded_tiles,
					"impact_actor_keys": guarded_actor_keys,
					"amount": int(action.get("amount", 0)),
					"sfx_id": str(action.get("sfx_id", action.get("block_sfx_id", ""))),
					"sfx_category": str(action.get("sfx_category", action.get("block_sfx_category", ""))),
					"label": "Guard Allies"
				}
			var guard_target_index: int = _enemy_support_target_index(before_state, enemy_index, action)
			if guard_target_index < 0 or guard_target_index >= before_enemies.size() or guard_target_index >= after_enemies.size():
				return {}
			var before_guard_target: Dictionary = before_enemies[guard_target_index]
			var after_guard_target: Dictionary = after_enemies[guard_target_index]
			var guard_amount: int = int(after_guard_target.get("block", 0)) - int(before_guard_target.get("block", 0))
			if guard_amount <= 0:
				return {}
			var guard_target_name: String = _enemy_display_name(after_guard_target)
			return {
				"kind": "block",
				"actor_key": _enemy_key(after_guard_target),
				"actor_name": guard_target_name,
				"source_actor_key": _enemy_key(after_enemy),
				"source_actor_name": actor_name,
				"target_name": guard_target_name,
				"tile": after_guard_target.get("pos", Vector2i.ZERO),
				"amount": guard_amount,
				"sfx_id": str(action.get("sfx_id", action.get("block_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("block_sfx_category", ""))),
				"label": "Guard Self" if guard_target_index == enemy_index else "Guard Ally"
			}
		"raise_terrain", "cinder_marks", "frost_armor":
			var label_by_type := {
				"raise_terrain": "Stonewake",
				"cinder_marks": "Kindle Ground",
				"frost_armor": "Crystal Mantle"
			}
			var focus_tiles: Array[Vector2i] = []
			if action_type == "raise_terrain":
				for terrain_var: Variant in after_state.get("terrain", []):
					if typeof(terrain_var) != TYPE_DICTIONARY:
						continue
					var terrain: Dictionary = terrain_var as Dictionary
					if str(terrain.get("kind", "")) == DRAGON_SPIRE_KIND and not _terrain_id_exists(before_state, str(terrain.get("id", ""))):
						focus_tiles.append(terrain.get("pos", Vector2i.ZERO))
			elif action_type == "cinder_marks":
				for trap: Dictionary in _cinder_mark_traps(after_state, int(after_enemy.get("id", -1))):
					if _trap_index_at_tile(before_state, trap.get("pos", INVALID_TILE)) < 0:
						focus_tiles.append(trap.get("pos", Vector2i.ZERO))
			else:
				focus_tiles.append(after_enemy.get("pos", Vector2i.ZERO))
			return {
				"kind": "status",
				"action_type": action_type,
				"boss_mechanic": true,
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"focus_tiles": focus_tiles,
				"terrain_after": (after_state.get("terrain", []) as Array).duplicate(true),
				"traps_after": (after_state.get("traps", []) as Array).duplicate(true),
				"enemy_after": after_enemy.duplicate(true),
				"amount": focus_tiles.size() if action_type != "frost_armor" else int(after_enemy.get("frost_armor", 0)),
				"label": str(label_by_type.get(action_type, "Dragon Power")),
				"text": "%d spires" % focus_tiles.size() if action_type == "raise_terrain" else "%d marks" % focus_tiles.size() if action_type == "cinder_marks" else "%d armor" % int(after_enemy.get("frost_armor", 0))
			}
		"terrain_burst", "detonate_cinders", "gale_force", "umbra_eclipse":
			var label_by_type := {
				"terrain_burst": "Faultline",
				"detonate_cinders": "Crownfire",
				"gale_force": "Hollow Gale",
				"umbra_eclipse": "Last Eclipse"
			}
			var target_losses: Array[Dictionary] = _actor_target_losses(before_state, after_state)
			var terrain_losses: Array[Dictionary] = _terrain_target_losses(before_state, after_state)
			var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
			var tiles: Array[Vector2i] = _boss_action_threat_tiles(before_state, before_enemy, action)
			var target_tile: Vector2i = after_player.get("pos", Vector2i.ZERO)
			if not target_losses.is_empty():
				target_tile = (target_losses[0] as Dictionary).get("tile", target_tile)
			return {
				"kind": "push" if action_type == "gale_force" else "aoe",
				"action_type": action_type,
				"boss_mechanic": true,
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": before_enemy.get("pos", Vector2i.ZERO),
				"to": target_tile,
				"center": before_enemy.get("pos", Vector2i.ZERO),
				"tiles": tiles,
				"player_from": before_player.get("pos", Vector2i.ZERO),
				"player_to": after_player.get("pos", Vector2i.ZERO),
				"target_losses": target_losses,
				"terrain_losses": terrain_losses,
				"triggered_traps": triggered_traps,
				"umbra_after": (after_state.get("umbra", {}) as Dictionary).duplicate(true),
				"enemy_after": after_enemy.duplicate(true),
				"impact_actor_keys": _target_loss_keys(target_losses),
				"amount": _target_loss_amount(target_losses),
				"hp_loss": int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)),
				"block_loss": int(before_player.get("block", 0)) - int(after_player.get("block", 0)),
				"stoneskin_loss": int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0)),
				"label": str(label_by_type.get(action_type, "Dragon Power"))
			}
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
			var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
			var stoneskin_loss: int = int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0))
			var target_losses: Array[Dictionary] = _actor_target_losses(before_state, after_state)
			var terrain_losses: Array[Dictionary] = _terrain_target_losses(before_state, after_state)
			var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
			var moved: bool = before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO)
			var status_text: String = _player_status_step_text(before_player, after_player, action)
			if target_losses.is_empty() and terrain_losses.is_empty() and triggered_traps.is_empty() and not moved and status_text.is_empty() and action_type != "lightning_strikes":
				return {}
			var target_tile: Vector2i = after_player.get("pos", Vector2i.ZERO)
			if not target_losses.is_empty():
				target_tile = (target_losses[0] as Dictionary).get("tile", target_tile)
			elif not terrain_losses.is_empty():
				target_tile = (terrain_losses[0] as Dictionary).get("tile", target_tile)
			elif not triggered_traps.is_empty():
				target_tile = (triggered_traps[0] as Dictionary).get("pos", target_tile)
			var center_tile: Vector2i = target_tile
			if action_type == "aoe" and int(action.get("range", 0)) <= 0:
				center_tile = before_enemy.get("pos", Vector2i.ZERO)
			var aoe_tiles: Array[Vector2i] = []
			if action_type == "aoe":
				var resolved_step_action: Dictionary = _enemy_action_oriented_to_target(action, before_enemy, target_tile)
				aoe_tiles = _enemy_aoe_tiles_for_target(before_state, before_enemy, resolved_step_action, center_tile, true)
			elif action_type == "lightning_strikes":
				aoe_tiles = _lightning_strike_tiles(before_state, before_enemy, action)
			return {
				"kind": action_type,
				"action_type": action_type,
				"element": attack_element,
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"from": after_enemy.get("pos", Vector2i.ZERO),
				"to": target_tile,
				"player_from": before_player.get("pos", Vector2i.ZERO),
				"player_to": after_player.get("pos", Vector2i.ZERO),
				"center": center_tile,
				"tiles": aoe_tiles,
				"amount": _target_loss_amount(target_losses),
				"hp_loss": hp_loss,
				"block_loss": block_loss,
				"stoneskin_loss": stoneskin_loss,
				"target_losses": target_losses,
				"terrain_losses": terrain_losses,
				"triggered_traps": triggered_traps,
				"impact_actor_keys": _target_loss_keys(target_losses),
				"target_key": str(action_context.get("target_key", "")),
				"status_text": status_text,
				"range": int(action.get("range", 0)),
				"sfx_id": str(action.get("sfx_id", action.get("attack_sfx_id", ""))),
				"sfx_category": str(action.get("sfx_category", action.get("attack_sfx_category", ""))),
				"label": "Strike" if action_type == "melee" else "Shot" if action_type == "ranged" else "Storm" if action_type == "lightning_strikes" else "Area" if action_type == "aoe" else "Push" if action_type == "push" else "Pull"
			}
		"summon_minions":
			var before_count: int = before_enemies.size()
			var after_count: int = after_enemies.size()
			if after_count <= before_count:
				return {}
			return {
				"kind": "summon",
				"actor_key": _enemy_key(after_enemy),
				"actor_name": actor_name,
				"tile": after_enemy.get("pos", Vector2i.ZERO),
				"amount": after_count - before_count,
				"label": "Summon"
			}
		_:
			return {}

func _actor_target_losses(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary]
	# Loss presentation reads only scalar health/defense/position fields. These
	# snapshots are already normalized combat states; deep-normalizing every actor
	# here copied unrelated status payloads once per resolved enemy action.
	var before_player: Dictionary = before_state.get("player", {}) as Dictionary
	var after_player: Dictionary = after_state.get("player", {}) as Dictionary
	var defiance_events_between: Array[Dictionary] = _defiance_events_between_states(before_state, after_state)
	var defiance_restored: int = 0
	var defiance_remaining_after: int = int(after_state.get("defiance_remaining", 0))
	var player_hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)))
	if not defiance_events_between.is_empty():
		player_hp_loss = 0
		for event: Dictionary in defiance_events_between:
			player_hp_loss += maxi(0, int(event.get("lethal_hp_loss", 0)))
			defiance_restored += maxi(0, int(event.get("restored_hp", 0)))
			defiance_remaining_after = int(event.get("charges_after", defiance_remaining_after))
	var player_block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_player.get("block", 0)))
	var player_stoneskin_loss: int = maxi(0, int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0)))
	if player_hp_loss > 0 or player_block_loss > 0 or player_stoneskin_loss > 0:
		var player_loss: Dictionary = {
			"key": "player",
			"kind": "player",
			"tile": after_player.get("pos", before_player.get("pos", Vector2i.ZERO)),
			"hp_loss": player_hp_loss,
			"block_loss": player_block_loss,
			"stoneskin_loss": player_stoneskin_loss,
			"amount": player_hp_loss + player_block_loss + player_stoneskin_loss
		}
		if defiance_restored > 0:
			player_loss["defiance_restored"] = defiance_restored
			player_loss["defiance_remaining"] = defiance_remaining_after
			player_loss["defiance_trigger_count"] = defiance_events_between.size()
		losses.append(player_loss)
	var after_illusions_by_id: Dictionary = {}
	for after_illusion_var: Variant in after_state.get("illusions", []):
		if typeof(after_illusion_var) != TYPE_DICTIONARY:
			continue
		var after_illusion: Dictionary = after_illusion_var as Dictionary
		after_illusions_by_id[int(after_illusion.get("id", -1))] = after_illusion
	for before_illusion_var: Variant in before_state.get("illusions", []):
		if typeof(before_illusion_var) != TYPE_DICTIONARY:
			continue
		var before_illusion: Dictionary = before_illusion_var as Dictionary
		if int(before_illusion.get("hp", 0)) <= 0:
			continue
		var illusion_id: int = int(before_illusion.get("id", -1))
		var after_illusion: Dictionary = after_illusions_by_id.get(illusion_id, before_illusion)
		var hp_loss: int = maxi(0, int(before_illusion.get("hp", 0)) - int(after_illusion.get("hp", 0)))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": _illusion_key(before_illusion),
			"kind": "illusion",
			"id": illusion_id,
			"tile": after_illusion.get("pos", before_illusion.get("pos", Vector2i.ZERO)),
			"hp_loss": hp_loss,
			"block_loss": 0,
			"stoneskin_loss": 0,
			"amount": hp_loss
			})
	return losses

func _defiance_events_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_revision: int = int(before_state.get("defiance_event_revision", 0))
	var results: Array[Dictionary]
	for event: Dictionary in defiance_events(after_state):
		if int(event.get("revision", 0)) > before_revision:
			results.append(event)
	return results

func _enemy_target_losses(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary]
	var after_by_id: Dictionary = {}
	for after_enemy_var: Variant in after_state.get("enemies", []):
		if typeof(after_enemy_var) != TYPE_DICTIONARY:
			continue
		var after_enemy: Dictionary = after_enemy_var as Dictionary
		after_by_id[int(after_enemy.get("id", -1))] = after_enemy
	for before_enemy_var: Variant in before_state.get("enemies", []):
		if typeof(before_enemy_var) != TYPE_DICTIONARY:
			continue
		var before_enemy: Dictionary = before_enemy_var as Dictionary
		if int(before_enemy.get("hp", 0)) <= 0:
			continue
		var enemy_id: int = int(before_enemy.get("id", -1))
		var after_enemy: Dictionary = after_by_id.get(enemy_id, before_enemy)
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		var block_loss: int = maxi(0, int(before_enemy.get("block", 0)) - int(after_enemy.get("block", 0)))
		var stoneskin_loss: int = maxi(0, int(before_enemy.get("stoneskin", 0)) - int(after_enemy.get("stoneskin", 0)))
		if hp_loss <= 0 and block_loss <= 0 and stoneskin_loss <= 0:
			continue
		losses.append({
			"key": _enemy_key(before_enemy),
			"kind": "enemy",
			"id": enemy_id,
			"tile": after_enemy.get("pos", before_enemy.get("pos", Vector2i.ZERO)),
			"hp_loss": hp_loss,
			"block_loss": block_loss,
			"stoneskin_loss": stoneskin_loss,
			"amount": hp_loss + block_loss + stoneskin_loss
		})
	return losses

func _terrain_target_losses(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var losses: Array[Dictionary] = []
	var after_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var as Dictionary
		after_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var as Dictionary
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		var after_terrain: Dictionary = after_by_id.get(terrain_id, before_terrain)
		var hp_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0)))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": "terrain_%s" % terrain_id,
			"kind": str(before_terrain.get("kind", "terrain")),
			"id": terrain_id,
			"tile": before_terrain.get("pos", Vector2i.ZERO),
			"hp_loss": hp_loss,
			"amount": hp_loss
		})
	return losses

func _terrain_id_exists(state: Dictionary, terrain_id: String) -> bool:
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and str((terrain_var as Dictionary).get("id", "")) == terrain_id:
			return true
	return false

func _triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_ids: Dictionary = {}
	for after_trap_var: Variant in after_state.get("traps", []):
		if typeof(after_trap_var) != TYPE_DICTIONARY:
			continue
		var after_trap: Dictionary = after_trap_var
		after_ids[str(after_trap.get("id", ""))] = true
	var triggered: Array[Dictionary] = []
	for before_trap_var: Variant in before_state.get("traps", []):
		if typeof(before_trap_var) != TYPE_DICTIONARY:
			continue
		var before_trap: Dictionary = (before_trap_var as Dictionary).duplicate(true)
		var trap_id: String = str(before_trap.get("id", ""))
		if trap_id.is_empty() or after_ids.has(trap_id):
			continue
		before_trap["resolved_damage"] = trap_damage(before_state, before_trap)
		triggered.append(before_trap)
	return triggered

func _target_loss_amount(target_losses: Array[Dictionary]) -> int:
	var total: int = 0
	for loss: Dictionary in target_losses:
		total += int(loss.get("amount", 0))
	return total

func _target_loss_keys(target_losses: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for loss: Dictionary in target_losses:
		var key: String = str(loss.get("key", ""))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	return keys

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

func _enemy_display_name(enemy: Dictionary) -> String:
	return str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy"))

func _actor_targets(state: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var player: Dictionary = _normalized_player(state.get("player", {}))
	if int(player.get("hp", 0)) > 0:
		targets.append({
			"kind": "player",
			"key": "player",
			"pos": player.get("pos", Vector2i.ZERO),
			"hp": int(player.get("hp", 0))
		})
	for illusion: Dictionary in _live_illusions(state):
		targets.append({
			"kind": "illusion",
			"key": _illusion_key(illusion),
			"id": int(illusion.get("id", -1)),
			"pos": illusion.get("pos", Vector2i.ZERO),
			"hp": int(illusion.get("hp", 0))
		})
	return targets

func _closest_enemy_target(state: Dictionary, enemy: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var best_targets: Array = []
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_targets.clear()
			best_targets.append(target)
		elif distance == best_distance:
			best_targets.append(target)
	return _choose_actor_target_candidate(best_targets, rng)

func _closest_enemy_target_for_action(state: Dictionary, enemy: Dictionary, action: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var best_targets: Array = []
	var best_distance: int = 9999
	for target: Dictionary in _actor_targets(state):
		if not _enemy_action_reaches_target(state, enemy, action, target):
			continue
		var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
		var distance: int = _enemy_distance_to_tile(enemy, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_targets.clear()
			best_targets.append(target)
		elif distance == best_distance:
			best_targets.append(target)
	return _choose_actor_target_candidate(best_targets, rng)

func _choose_actor_target_candidate(candidates: Array, _rng: RandomNumberGenerator = null) -> Dictionary:
	if candidates.is_empty():
		return {}
	var best_target: Dictionary = {}
	for candidate_var: Variant in candidates:
		if typeof(candidate_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_var
		if best_target.is_empty() or _actor_target_precedes(candidate, best_target):
			best_target = candidate
	if best_target.is_empty():
		return {}
	return best_target.duplicate(true)

func _actor_target_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_priority: int = _actor_target_priority(candidate)
	var incumbent_priority: int = _actor_target_priority(incumbent)
	if candidate_priority != incumbent_priority:
		return candidate_priority < incumbent_priority
	var candidate_id: int = int(candidate.get("id", -1))
	var incumbent_id: int = int(incumbent.get("id", -1))
	if candidate_id != incumbent_id:
		return candidate_id < incumbent_id
	return str(candidate.get("key", "")) < str(incumbent.get("key", ""))

func _actor_target_priority(target: Dictionary) -> int:
	# Illusions win exact-distance ties so a deliberately placed decoy redirects
	# reliably. The player remains preferred whenever strictly closer.
	return 0 if str(target.get("kind", "")) == "illusion" else 1

func _enemy_support_target_index(state: Dictionary, source_enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if source_enemy_index < 0 or source_enemy_index >= enemies.size():
		return -1
	var source_enemy: Dictionary = _normalized_enemy(enemies[source_enemy_index])
	if int(source_enemy.get("hp", 0)) <= 0:
		return -1
	var action_type: String = str(action.get("type", ""))
	if action_type not in ENEMY_SUPPORT_ACTION_TYPES:
		return -1
	var allow_self: bool = bool(action.get("allow_self", true))
	var max_range: int = int(action.get("range", 99)) if action.has("range") else 99
	var best_index: int = -1
	var best_enemy: Dictionary = {}
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for index: int in range(enemies.size()):
		if index == source_enemy_index and not allow_self:
			continue
		var candidate: Dictionary = _normalized_enemy(enemies[index])
		if int(candidate.get("hp", 0)) <= 0:
			continue
		if not _enemy_support_action_can_affect(candidate, action):
			continue
		if _enemy_distance_between(source_enemy, candidate) > max_range:
			continue
		if best_index < 0 or _enemy_support_candidate_precedes(action_type, source_enemy, candidate, best_enemy, player):
			best_index = index
			best_enemy = candidate
	return best_index

func _enemy_support_action_can_affect(candidate: Dictionary, action: Dictionary) -> bool:
	if int(action.get("amount", 0)) <= 0:
		return false
	match str(action.get("type", "")):
		"heal_ally":
			return int(candidate.get("hp", 0)) < int(candidate.get("max_hp", 1))
		"guard_ally":
			return true
		_:
			return false

func _enemy_support_candidate_precedes(action_type: String, source_enemy: Dictionary, candidate: Dictionary, incumbent: Dictionary, player: Dictionary) -> bool:
	if incumbent.is_empty():
		return true
	match action_type:
		"heal_ally":
			var candidate_missing: int = maxi(0, int(candidate.get("max_hp", 1)) - int(candidate.get("hp", 0)))
			var incumbent_missing: int = maxi(0, int(incumbent.get("max_hp", 1)) - int(incumbent.get("hp", 0)))
			if candidate_missing != incumbent_missing:
				return candidate_missing > incumbent_missing
			var candidate_support_distance: int = _enemy_distance_between(source_enemy, candidate)
			var incumbent_support_distance: int = _enemy_distance_between(source_enemy, incumbent)
			if candidate_support_distance != incumbent_support_distance:
				return candidate_support_distance < incumbent_support_distance
			if int(candidate.get("hp", 0)) != int(incumbent.get("hp", 0)):
				return int(candidate.get("hp", 0)) < int(incumbent.get("hp", 0))
		"guard_ally":
			var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
			var candidate_threat_distance: int = _enemy_distance_to_tile(candidate, player_pos)
			var incumbent_threat_distance: int = _enemy_distance_to_tile(incumbent, player_pos)
			if candidate_threat_distance != incumbent_threat_distance:
				return candidate_threat_distance < incumbent_threat_distance
			var candidate_defense: int = int(candidate.get("block", 0)) + int(candidate.get("stoneskin", 0))
			var incumbent_defense: int = int(incumbent.get("block", 0)) + int(incumbent.get("stoneskin", 0))
			if candidate_defense != incumbent_defense:
				return candidate_defense < incumbent_defense
			var candidate_ratio: int = int(candidate.get("hp", 0)) * int(incumbent.get("max_hp", 1))
			var incumbent_ratio: int = int(incumbent.get("hp", 0)) * int(candidate.get("max_hp", 1))
			if candidate_ratio != incumbent_ratio:
				return candidate_ratio < incumbent_ratio
			var candidate_guard_distance: int = _enemy_distance_between(source_enemy, candidate)
			var incumbent_guard_distance: int = _enemy_distance_between(source_enemy, incumbent)
			if candidate_guard_distance != incumbent_guard_distance:
				return candidate_guard_distance < incumbent_guard_distance
	return int(candidate.get("id", 0)) < int(incumbent.get("id", 0))

func _enemy_action_reaches_target(state: Dictionary, enemy: Dictionary, action: Dictionary, target: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	match action_type:
		"melee":
			return _enemy_distance_to_tile(enemy, target_pos) <= int(action.get("range", 1))
		"ranged":
			return (
				PathUtils.manhattan(source_pos, target_pos) <= int(action.get("range", 1))
				and PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos)
			)
		"push", "pull":
			var max_range: int = int(action.get("range", 1))
			return (
				PathUtils.manhattan(source_pos, target_pos) <= max_range
				and (max_range <= 1 or PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos))
			)
		"aoe":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			if int(action.get("range", 0)) > 0:
				if PathUtils.manhattan(source_pos, target_pos) > int(action.get("range", 0)):
					return false
				if not PathUtils.has_line_of_sight(state.get("grid", []), source_pos, target_pos):
					return false
				center = target_pos
			var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target_pos)
			return _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true).has(target_pos)
	return false

func _enemy_action_reaches_tile(state: Dictionary, enemy: Dictionary, action: Dictionary, tile: Vector2i) -> bool:
	var action_type: String = str(action.get("type", ""))
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, tile)
	match action_type:
		"melee":
			return _enemy_distance_to_tile(enemy, tile) <= int(action.get("range", 1))
		"ranged":
			return (
				PathUtils.manhattan(source_pos, tile) <= int(action.get("range", 1))
				and PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile)
			)
		"push", "pull":
			var max_range: int = int(action.get("range", 1))
			return (
				PathUtils.manhattan(source_pos, tile) <= max_range
				and (max_range <= 1 or PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile))
			)
		"aoe":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			if int(action.get("range", 0)) > 0:
				if PathUtils.manhattan(source_pos, tile) > int(action.get("range", 0)):
					return false
				if not PathUtils.has_line_of_sight(state.get("grid", []), source_pos, tile):
					return false
				center = tile
			var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, tile)
			return _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true).has(tile)
	return false

func _enemy_action_oriented_to_target(action: Dictionary, enemy: Dictionary, target_pos: Vector2i) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	if not bool(resolved_action.get("orient_toward_target", false)):
		return resolved_action
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	var direction: Vector2i = _cardinal_direction(target_pos - source_pos)
	if direction != Vector2i.ZERO:
		resolved_action["orientation"] = direction
	return resolved_action

func _enemy_aoe_tiles_for_target(state: Dictionary, enemy: Dictionary, action: Dictionary, center: Vector2i, score_player: bool) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = _best_aoe_tiles_for_target(state, action, center, score_player)
	if not bool(action.get("stop_at_blockers", false)):
		return tiles
	var direction: Vector2i = _action_orientation_direction(action)
	if direction == Vector2i.ZERO:
		return tiles
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, center)
	return _aoe_tiles_until_blocked(state.get("grid", []), source_pos, direction, tiles)

func _aoe_tiles_until_blocked(grid: Array, source_pos: Vector2i, direction: Vector2i, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		if _tile_is_on_directional_ray(source_pos, direction, tile) and _directional_ray_clear_to_tile(grid, source_pos, direction, tile):
			lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _tile_is_on_directional_ray(source_pos: Vector2i, direction: Vector2i, tile: Vector2i) -> bool:
	var delta: Vector2i = tile - source_pos
	if direction.x != 0:
		return delta.y == 0 and delta.x * direction.x > 0
	if direction.y != 0:
		return delta.x == 0 and delta.y * direction.y > 0
	return false

func _directional_ray_clear_to_tile(grid: Array, source_pos: Vector2i, direction: Vector2i, tile: Vector2i) -> bool:
	var cursor: Vector2i = source_pos + direction
	while cursor != tile + direction:
		if not PathUtils.is_passable(grid, cursor):
			return false
		if cursor == tile:
			return true
		cursor += direction
	return false

func _best_enemy_trap_attack_index(state: Dictionary, enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return -1
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var direct_damage: int = _enemy_direct_player_damage_estimate(state, enemy, action)
	var best_index: int = -1
	var best_damage: int = direct_damage
	var traps: Array = state.get("traps", [])
	for trap_index: int in range(traps.size()):
		if typeof(traps[trap_index]) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = traps[trap_index]
		if not _enemy_action_reaches_tile(state, enemy, action, trap.get("pos", Vector2i(-1, -1))):
			continue
		if _trap_blast_hits_enemy(state, trap, enemy):
			continue
		if not _trap_blast_hits_player(state, trap):
			continue
		var resolved_trap_damage: int = trap_damage(state, trap)
		if direct_damage >= 0 and resolved_trap_damage <= direct_damage:
			continue
		if direct_damage < 0 and resolved_trap_damage <= 0:
			continue
		if resolved_trap_damage > best_damage:
			best_damage = resolved_trap_damage
			best_index = trap_index
	return best_index

func _enemy_direct_player_damage_estimate(state: Dictionary, enemy: Dictionary, action: Dictionary) -> int:
	if not enemy_action_can_resolve(state, action):
		return -1
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var player: Dictionary = _normalized_player(state.get("player", {}))
	var target: Dictionary = {
		"kind": "player",
		"key": "player",
		"pos": player.get("pos", Vector2i.ZERO),
		"hp": int(player.get("hp", 0))
	}
	if not _enemy_action_reaches_target(state, enemy, resolved_action, target):
		return -1
	return int(resolved_action.get("damage", 0))

func _trap_blast_hits_player(state: Dictionary, trap: Dictionary) -> bool:
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i(-1, -1))
	return _trap_blast_tiles(state, trap).has(player_pos)

func _trap_blast_hits_enemy(state: Dictionary, trap: Dictionary, enemy: Dictionary) -> bool:
	var blast_tiles: Array[Vector2i] = _trap_blast_tiles(state, trap)
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		if blast_tiles.has(tile):
			return true
	return false

func _actor_targets_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[Dictionary]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var targets: Array[Dictionary] = []
	for target: Dictionary in _actor_targets(state):
		if tile_lookup.has(target.get("pos", Vector2i.ZERO)):
			targets.append(target)
	return targets

func _has_attackable_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> bool:
	return (
		not _enemy_indices_in_tiles(state, tiles).is_empty()
		or not _terrain_indices_in_tiles(state, tiles).is_empty()
		or not _trap_tiles_in_tiles(state, tiles).is_empty()
	)

func _damage_actor_target(state: Dictionary, target: Dictionary, damage: int, bypass_block: bool, source_action: Dictionary = {}) -> Dictionary:
	if damage <= 0:
		return state
	match str(target.get("kind", "")):
		"player":
			return _damage_player(state, damage, bypass_block, true, "enemy_attack")
		"illusion":
			var resolved_damage: int = damage
			for effect: Dictionary in _relic_effects(state):
				if str(effect.get("type", "")) != "illusion_damage_cap":
					continue
				var action_types: Array = effect.get("enemy_action_types", []) as Array
				if not action_types.is_empty() and not action_types.has(str(source_action.get("type", ""))):
					continue
				resolved_damage = mini(resolved_damage, GameData.fixed_point_amount(int(effect.get("max_damage", 1))))
			return _damage_illusion(state, int(target.get("id", -1)), resolved_damage)
	return state

func _apply_action_keywords_to_target(state: Dictionary, target: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	if str(target.get("kind", "")) != "player":
		return state
	return _apply_action_keywords_to_player(state, action, source_pos)

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	if not enemy_action_can_resolve(next_state, action):
		var blocked_requirement: Dictionary = action_intensity_spend(action)
		if blocked_requirement.is_empty():
			blocked_requirement = _action_intensity_requirement(action)
		if not blocked_requirement.is_empty():
			_log(next_state, "%s's intent is starved of %s intensity." % [
				_enemy_display_name(enemy),
				ElementData.name(str(blocked_requirement.get("element", ElementData.NONE)))
			])
		return next_state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var intensity_spend: Dictionary = action_intensity_spend(action)
	action = resolved_action
	var state_before_action: Dictionary = next_state.duplicate(true)
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var target: Dictionary = _current_actor_target_for_plan(next_state, action_context)
	if target.is_empty() and action_context.is_empty():
		target = _closest_enemy_target(next_state, enemy, rng)
	var target_pos: Vector2i = target.get("pos", player_pos)
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move_toward":
			var toward_path: Array[Vector2i] = _planned_enemy_movement_path(next_state, enemy, enemy_index, action, followup_action, action_context, target_pos, true)
			if toward_path.size() <= 1:
				return next_state
			next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
			if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
				return next_state
			next_state = _move_enemy_along_planned_path(next_state, enemy_index, toward_path, action_context)
			_log(next_state, "%s closes in." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"move_away":
			var away_path: Array[Vector2i] = _planned_enemy_movement_path(next_state, enemy, enemy_index, action, followup_action, action_context, target_pos, false)
			if away_path.size() <= 1:
				return next_state
			next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
			if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
				return next_state
			next_state = _move_enemy_along_planned_path(next_state, enemy_index, away_path, action_context)
			_log(next_state, "%s falls back." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		"block":
			enemy["block"] = int(enemy.get("block", 0)) + int(action.get("amount", 0))
			enemies[enemy_index] = enemy
			_log(next_state, "%s braces for %d block." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"stoneskin":
			enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) + int(action.get("amount", 0))
			enemies[enemy_index] = enemy
			_log(next_state, "%s hardens for %d stoneskin." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"heal_self":
			enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(enemy.get("hp", 0)) + int(action.get("amount", 0)))
			enemies[enemy_index] = enemy
			_log(next_state, "%s recovers %d health." % [
				str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
				int(action.get("amount", 0))
			])
		"heal_ally":
			var heal_target_index: int = _enemy_support_target_index(next_state, enemy_index, action)
			if heal_target_index < 0:
				return next_state
			var heal_target: Dictionary = _normalized_enemy(enemies[heal_target_index] as Dictionary)
			var heal_before: int = int(heal_target.get("hp", 0))
			heal_target["hp"] = mini(int(heal_target.get("max_hp", 1)), heal_before + int(action.get("amount", 0)))
			enemies[heal_target_index] = heal_target
			var healed_amount: int = int(heal_target.get("hp", 0)) - heal_before
			if healed_amount > 0:
				_log(next_state, "%s stitches %s for %d health." % [
					_enemy_display_name(enemy),
					"itself" if heal_target_index == enemy_index else _enemy_display_name(heal_target),
					healed_amount
				])
		"guard_ally":
			if str(action.get("target_mode", "")) == "all_other_enemies":
				var guarded_count: int = 0
				for target_index: int in range(enemies.size()):
					if target_index == enemy_index:
						continue
					var group_guard_target: Dictionary = _normalized_enemy(enemies[target_index] as Dictionary)
					if int(group_guard_target.get("hp", 0)) <= 0:
						continue
					group_guard_target["block"] = int(group_guard_target.get("block", 0)) + int(action.get("amount", 0))
					enemies[target_index] = group_guard_target
					guarded_count += 1
				if guarded_count <= 0:
					return next_state
				_log(next_state, "%s guards all other enemies for %d block." % [
					_enemy_display_name(enemy),
					int(action.get("amount", 0))
				])
			else:
				var guard_target_index: int = _enemy_support_target_index(next_state, enemy_index, action)
				if guard_target_index < 0:
					return next_state
				var guard_target: Dictionary = _normalized_enemy(enemies[guard_target_index] as Dictionary)
				guard_target["block"] = int(guard_target.get("block", 0)) + int(action.get("amount", 0))
				enemies[guard_target_index] = guard_target
				_log(next_state, "%s guards %s for %d block." % [
					_enemy_display_name(enemy),
					"itself" if guard_target_index == enemy_index else _enemy_display_name(guard_target),
					int(action.get("amount", 0))
				])
		"intensity":
			var intensity_element: String = _action_intensity_element(action)
			var intensity_amount: int = maxi(0, int(action.get("amount", 0)))
			next_state = _gain_elemental_intensity(next_state, intensity_element, intensity_amount, _enemy_display_name(enemy))
		"melee":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "hits", rng, bleed_steps, action_context)
		"ranged":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "fires", rng, bleed_steps, action_context)
		"aoe":
			next_state = _enemy_attack_target(next_state, enemy_index, action, "sweeps the area", rng, bleed_steps, action_context)
		"lightning_strikes":
			next_state = _enemy_lightning_strikes(next_state, enemy_index, action, bleed_steps)
		"push":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, true, rng, bleed_steps, action_context)
		"pull":
			next_state = _enemy_push_or_pull_target(next_state, enemy_index, action, false, rng, bleed_steps, action_context)
		"summon_minions":
			next_state = _enemy_summon_minions(next_state, enemy_index, action, rng)
		"raise_terrain":
			next_state = _enemy_raise_dragon_spires(next_state, enemy_index, action)
		"terrain_burst":
			next_state = _enemy_terrain_burst(next_state, enemy_index, action, bleed_steps)
		"cinder_marks":
			next_state = _enemy_create_cinder_marks(next_state, enemy_index, action)
		"detonate_cinders":
			next_state = _enemy_detonate_cinders(next_state, enemy_index, action, bleed_steps)
		"gale_force":
			next_state = _enemy_gale_force(next_state, enemy_index, action, bleed_steps)
		"frost_armor":
			next_state = _enemy_gain_frost_armor(next_state, enemy_index, action)
		"umbra_eclipse":
			next_state = _enemy_umbra_eclipse(next_state, enemy_index, action, bleed_steps)
	if not intensity_spend.is_empty():
		var resolved_step: Dictionary = _enemy_action_step(state_before_action, next_state, enemy_index, action, action_context)
		if not resolved_step.is_empty():
			next_state = _consume_elemental_intensity(
				next_state,
				str(intensity_spend.get("element", ElementData.NONE)),
				int(intensity_spend.get("amount", 0))
			)
	return next_state

func _planned_enemy_movement_path(state: Dictionary, enemy: Dictionary, enemy_index: int, action: Dictionary, followup_action: Dictionary, action_context: Dictionary, target_pos: Vector2i, toward: bool) -> Array[Vector2i]:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if int(action_context.get("action_index", -1)) == int(action_context.get("movement_action_index", -2)):
		var planned_path: Array[Vector2i] = _vector2i_values(action_context.get("path", []))
		if not planned_path.is_empty() and planned_path[0] == start:
			return planned_path
	var destination: Vector2i = start
	if toward:
		destination = _best_move_toward_for_followup(state, enemy_index, target_pos, int(action.get("range", 0)), followup_action)
		if destination == INVALID_TILE:
			destination = _best_move_toward(state, enemy_index, target_pos, int(action.get("range", 0)))
	else:
		destination = _best_move_away(state, enemy_index, target_pos, int(action.get("range", 0)))
	if destination == start:
		return _vector2i_values([start])
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, false)
	var fallback_path: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), start, destination, occupied)
	if fallback_path.is_empty():
		return _vector2i_values([start, destination])
	return fallback_path

func _move_enemy_along_planned_path(state: Dictionary, enemy_index: int, planned_path: Array[Vector2i], action_context: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var resolved_path: Array[Vector2i] = _vector2i_values([])
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	resolved_path.append(enemy.get("pos", Vector2i.ZERO))
	for path_index: int in range(1, planned_path.size()):
		enemies = next_state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			break
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		enemy["pos"] = planned_path[path_index]
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		resolved_path.append(planned_path[path_index])
		next_state = _trigger_trap_on_enemy(next_state, enemy_index)
		if combat_outcome(next_state) != "":
			break
	action_context["resolved_path"] = resolved_path
	return next_state

func _current_actor_target_for_plan(state: Dictionary, action_context: Dictionary) -> Dictionary:
	var target_key: String = str(action_context.get("target_key", ""))
	if target_key.is_empty():
		return {}
	for target: Dictionary in _actor_targets(state):
		if str(target.get("key", "")) == target_key:
			return target
	return {}

func _attack_target_on_tile(state: Dictionary, action: Dictionary, target_tile: Vector2i, attack_kind: String, presentation_trace: Dictionary = {}) -> Dictionary:
	# apply_player_action already owns a deep copy and validates the target once.
	# Keeping this helper in-place avoids cloning the full combat snapshot twice
	# more for every attack preview and committed attack.
	var next_state: Dictionary = state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var trap_index: int = _trap_index_at_tile(next_state, target_tile)
	if trap_index >= 0:
		next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
		if combat_outcome(next_state) == "defeat":
			return next_state
		if int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _trigger_player_trap_at_index(next_state, trap_index)
		next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([]))
		_log(next_state, "%s triggers a trap." % attack_kind.capitalize())
		return next_state
	var terrain_index: int = _terrain_index_at_tile(next_state, target_tile)
	if terrain_index >= 0:
		var terrain_damage: int = final_damage_for_player_action(next_state, action)
		if terrain_damage > 0:
			next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
			if combat_outcome(next_state) == "defeat":
				return next_state
			_mark_first_attack_used(next_state)
			next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
			next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([]))
			_log(next_state, "%s splinters terrain for %d." % [attack_kind.capitalize(), terrain_damage])
		return next_state
	return _attack_enemy_on_tile(next_state, action, target_tile, attack_kind, presentation_trace)

func _attack_enemy_on_tile(state: Dictionary, action: Dictionary, target_tile: Vector2i, attack_kind: String, presentation_trace: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	resolved_action = _action_with_target_state_relic_modifiers(next_state, resolved_action, enemy_index)
	resolved_action = _action_with_light_target_skill_modifier(next_state, resolved_action, enemy_index)
	if int(resolved_action.get("damage", 0)) > 0 or _action_has_keyword_effect(resolved_action) or _action_has_illuminate_rider(resolved_action):
		next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
		if combat_outcome(next_state) == "defeat":
			return next_state
		next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
		var damage: int = _damage_for_enemy_target(next_state, resolved_action, enemy_index)
		if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, enemy_index)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
		var affected_enemy_indices: Array[int] = _int_values([enemy_index])
		if int(resolved_action.get("chain", 0)) > 0:
			_append_chain_presentation_hit(presentation_trace, next_state, enemy_index, target_tile, target_tile)
		next_state = _apply_chain_from_enemy(next_state, enemy_index, resolved_action, damage, affected_enemy_indices, presentation_trace)
		next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, affected_enemy_indices)
		_mark_light_target_skill_trigger(next_state, resolved_action)
		_log(next_state, "%s for %d." % [attack_kind.capitalize(), damage])
	return next_state

func _aoe_enemies(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	# Relic definitions cannot change while an action resolves. Reuse this immutable
	# expansion across every AOE victim instead of rebuilding/deep-copying it twice
	# per target. Conditions still read the current state for sequential kill/heal
	# semantics.
	var relic_effects: Array[Dictionary] = _relic_effects(next_state)
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var center: Vector2i = target_tile if int(action.get("range", 0)) > 0 and target_tile.x >= 0 else player_pos
	var affected_tiles: Array[Vector2i] = _best_aoe_tiles_for_target(next_state, action, center, false)
	var performance_phase_started: int = _record_runtime_performance_phase("player_aoe_pattern", performance_total_started)
	var affected: Array[int] = _enemy_indices_in_tiles(next_state, affected_tiles)
	var hidden_enemy_affected: bool = false
	for affected_enemy_index: int in affected:
		var affected_enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[affected_enemy_index] as Dictionary)
		if not is_enemy_visible_to_player(next_state, affected_enemy):
			hidden_enemy_affected = true
			break
	var affected_terrain: Array[int] = _terrain_indices_in_tiles(next_state, affected_tiles)
	var affected_traps: Array[Vector2i] = _trap_tiles_in_tiles(next_state, affected_tiles)
	performance_phase_started = _record_runtime_performance_phase("player_aoe_targets", performance_phase_started)
	if affected.is_empty() and affected_terrain.is_empty() and affected_traps.is_empty():
		_record_runtime_performance_phase("player_aoe_total", performance_total_started)
		return next_state
	next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
	if combat_outcome(next_state) == "defeat":
		_record_runtime_performance_phase("player_aoe_total", performance_total_started)
		return next_state
	if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	var last_damage: int = 0
	for enemy_index: int in affected:
		next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
		var damage: int = _damage_for_enemy_target_with_context(next_state, resolved_action, enemy_index, relic_effects)
		last_damage = damage
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, enemy_index)
		next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, next_state.get("player", {}).get("pos", Vector2i.ZERO))
	for terrain_index: int in affected_terrain:
		var terrain_damage: int = _final_damage_for_resolved_player_action(next_state, resolved_action, relic_effects)
		if terrain_damage <= 0:
			continue
		last_damage = terrain_damage
		next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
	performance_phase_started = _record_runtime_performance_phase("player_aoe_damage_total", performance_phase_started)
	next_state = _trigger_traps_on_tiles(next_state, affected_traps)
	performance_phase_started = _record_runtime_performance_phase("player_aoe_traps_total", performance_phase_started)
	next_state = _trigger_resolved_action_light(next_state, resolved_action, center, affected)
	performance_phase_started = _record_runtime_performance_phase("player_aoe_light", performance_phase_started)
	if hidden_enemy_affected:
		_log(next_state, "Area attack strikes through the Umbra.")
	else:
		_log(next_state, "Area attack hits %d target(s) for %d." % [affected.size() + affected_terrain.size() + affected_traps.size(), last_damage])
	_record_runtime_performance_phase("player_aoe_log", performance_phase_started)
	_record_runtime_performance_phase("player_aoe_total", performance_total_started)
	return next_state

func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true, bypass_defense: bool = false) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var hp_before: int = int(enemy.get("hp", 0))
	var was_alive: bool = hp_before > 0
	var total_damage: int = damage
	if apply_freeze_multiplier and int(enemy.get("freeze", 0)) > 0:
		total_damage *= 2
	if total_damage > 0 and int(enemy.get("frost_armor", 0)) > 0:
		enemy["frost_armor"] = int(enemy.get("frost_armor", 0)) - 1
		enemies[enemy_index] = enemy
		_log(next_state, "%s's crystal armor shatters a blow." % _enemy_display_name(enemy))
		return next_state
	var remaining: int = total_damage
	if not bypass_defense:
		var block_amount: int = int(enemy.get("block", 0))
		var applied_to_block: int = mini(block_amount, remaining)
		block_amount -= applied_to_block
		remaining -= applied_to_block
		var stoneskin_amount: int = int(enemy.get("stoneskin", 0))
		var applied_to_stoneskin: int = mini(stoneskin_amount, remaining)
		stoneskin_amount -= applied_to_stoneskin
		remaining -= applied_to_stoneskin
		enemy["block"] = block_amount
		enemy["stoneskin"] = stoneskin_amount
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - remaining)
	enemies[enemy_index] = enemy
	_record_run_stat(next_state, RUN_STAT_DAMAGE_DEALT, maxi(0, hp_before - int(enemy.get("hp", 0))))
	if was_alive and int(enemy.get("hp", 0)) <= 0:
		_record_run_stat(next_state, RUN_STAT_ENEMIES_KILLED, 1)
		var reward_embers: int = int(GameData.enemy_def(str(enemy.get("type", ""))).get("reward_embers", 0))
		var bonus_card_plays: int = 0 if bool(enemy.get("summoned", false)) else 1
		next_state["room_embers"] = int(next_state.get("room_embers", 0)) + reward_embers
		next_state["death_bonus_card_plays_this_turn"] = int(next_state.get("death_bonus_card_plays_this_turn", 0)) + bonus_card_plays
		_record_death_reward(next_state, enemy, reward_embers, bonus_card_plays)
		next_state = _trigger_enemy_death_relics(next_state, enemy)
		if bool(enemy.get("is_leader", false)) and str((next_state.get("objective", {}) as Dictionary).get("type", "")) == CombatObjectiveRules.KILL_LEADER:
			next_state = _clear_remaining_enemies_for_leader_objective(next_state, int(enemy.get("id", -1)))
		else:
			next_state = _trigger_enemy_death_spawn(next_state, enemy)
		_log(next_state, "%s falls." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _clear_remaining_enemies_for_leader_objective(state: Dictionary, leader_id: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	var cleared_count: int = 0
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("id", -1)) == leader_id or int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["hp"] = 0
		enemy["objective_cleared"] = true
		enemies[index] = enemy
		cleared_count += 1
	next_state["enemies"] = enemies
	var objective: Dictionary = (next_state.get("objective", {}) as Dictionary).duplicate(true)
	objective["completed_by_leader"] = true
	objective["followers_cleared"] = cleared_count
	next_state["objective"] = objective
	if cleared_count > 0:
		_log(next_state, "The leader falls. %d bound foe(s) collapse without reward." % cleared_count)
	return next_state

func _sunder_enemy_defense(state: Dictionary, enemy_index: int, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var remaining: int = amount
	var block_removed: int = mini(int(enemy.get("block", 0)), remaining)
	enemy["block"] = int(enemy.get("block", 0)) - block_removed
	remaining -= block_removed
	if remaining > 0:
		var stoneskin_removed: int = mini(int(enemy.get("stoneskin", 0)), remaining)
		enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) - stoneskin_removed
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _consume_enemy_expose(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("expose", 0)) <= 0:
		return next_state
	enemy["expose"] = 0
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _record_death_reward(state: Dictionary, enemy: Dictionary, embers: int, card_plays: int) -> void:
	var rewards: Array = state.get("death_rewards", []).duplicate(true)
	rewards.append({
		"enemy_id": int(enemy.get("id", -1)),
		"actor_key": _enemy_key(enemy),
		"type": str(enemy.get("type", "")),
		"tile": enemy.get("pos", Vector2i.ZERO),
		"embers": maxi(0, embers),
		"card_plays": maxi(0, card_plays),
		"summoned": bool(enemy.get("summoned", false))
	})
	state["death_rewards"] = rewards

func _damage_player(
	state: Dictionary,
	damage: int,
	bypass_block: bool,
	apply_freeze_multiplier: bool = true,
	cause: String = "damage",
	defer_defiance: bool = false
) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var hp_before: int = int(player.get("hp", 0))
	var was_alive: bool = hp_before > 0
	var remaining: int = damage * 2 if apply_freeze_multiplier and int(player.get("freeze", 0)) > 0 else damage
	if not bypass_block:
		var block_amount: int = int(player.get("block", 0))
		var applied_to_block: int = mini(block_amount, remaining)
		block_amount -= applied_to_block
		remaining -= applied_to_block
		player["block"] = block_amount
		var stoneskin_amount: int = int(player.get("stoneskin", 0))
		var applied_to_stoneskin: int = mini(stoneskin_amount, remaining)
		stoneskin_amount -= applied_to_stoneskin
		remaining -= applied_to_stoneskin
		player["stoneskin"] = stoneskin_amount
	player["hp"] = maxi(0, int(player.get("hp", 0)) - remaining)
	var health_was_lost: bool = int(player.get("hp", 0)) < hp_before
	next_state["player"] = player
	_record_run_stat(next_state, RUN_STAT_DAMAGE_RECEIVED, maxi(0, hp_before - int(player.get("hp", 0))))
	if was_alive and int(player.get("hp", 0)) <= 0:
		next_state = _trigger_prevent_lethal_relics(next_state)
		if not defer_defiance and int((_normalized_player(next_state.get("player", {}))).get("hp", 0)) <= 0:
			next_state = _trigger_defiance(next_state, cause, hp_before)
	var pain_id: String = SkillTreeLibrary.skill_id_for_effect("pain_recall")
	var pain_flags: Dictionary = next_state.get("skill_flags", {}) as Dictionary
	if health_was_lost and has_skill(next_state, pain_id) and not skill_was_used(next_state, pain_id) and not bool(pain_flags.get("pain_recall_primed", false)):
		_set_skill_flag(next_state, "pain_recall_primed", true)
	return next_state

func _record_run_stat(state: Dictionary, stat_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var stats: Dictionary = normalized_run_stats(state.get("run_stats", {}))
	stats[stat_id] = maxi(0, int(stats.get(stat_id, 0)) + amount)
	state["run_stats"] = stats

func _lose_player_health(
	state: Dictionary,
	amount: int,
	bypass_block: bool,
	apply_freeze_multiplier: bool = true,
	cause: String = "health_loss",
	defer_defiance: bool = false
) -> Dictionary:
	return _damage_player(state, amount, bypass_block, apply_freeze_multiplier, cause, defer_defiance)

func _damage_illusion(state: Dictionary, illusion_id: int, damage: int) -> Dictionary:
	var next_state: Dictionary = state
	if damage <= 0:
		return next_state
	var source_illusions: Array = next_state.get("illusions", []) as Array
	for index: int in range(source_illusions.size()):
		if typeof(source_illusions[index]) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = _normalized_illusion(source_illusions[index] as Dictionary)
		if int(illusion.get("id", -1)) != illusion_id:
			continue
		var was_alive: bool = int(illusion.get("hp", 0)) > 0
		var will_fade: bool = was_alive and int(illusion.get("hp", 0)) - damage <= 0
		var stage_before: String = effective_umbra_stage(next_state) if will_fade else ""
		illusion["hp"] = maxi(0, int(illusion.get("hp", 0)) - damage)
		# Only the struck illusion changes. A shallow array copy plus the normalized
		# owned entry preserves source-state immutability without cloning every other
		# illusion for each trap in a chained blast.
		var illusions: Array = source_illusions.duplicate(false)
		illusions[index] = illusion
		next_state["illusions"] = illusions
		if will_fade:
			_log(next_state, "Illusion fades.")
			next_state = _trigger_illusion_afterglow(next_state, illusion.get("pos", INVALID_TILE))
			next_state = _resolve_umbra_transition_relics(next_state, stage_before)
			var skill_id: String = SkillTreeLibrary.skill_id_for_effect("illusion_recall")
			var turn_key: String = "turn:%s" % skill_id
			var flags: Dictionary = next_state.get("skill_flags", {}) as Dictionary
			if has_skill(next_state, skill_id) and int(flags.get(turn_key, -1)) != int(next_state.get("turn", 1)) and _latest_non_item_discard_index(next_state) >= 0:
				var deck_before: Dictionary = next_state.get("deck", {}) as Dictionary
				var recalled_index: int = _latest_non_item_discard_index(next_state)
				var recalled_card_id: String = str((deck_before.get("discard", []) as Array)[recalled_index])
				var hand_was_full: bool = (deck_before.get("hand", []) as Array).size() >= MAX_HAND_SIZE
				next_state = _recall_latest_non_item_discard(next_state, true)
				_set_skill_flag(next_state, turn_key, int(next_state.get("turn", 1)))
				var recalled_name: String = str(card_def(recalled_card_id, next_state).get("name", recalled_card_id))
				var message: String = (
					"%s places %s atop the draw pile." % [SkillTreeLibrary.display_name(skill_id), recalled_name]
					if hand_was_full
					else "%s returns %s to hand." % [SkillTreeLibrary.display_name(skill_id), recalled_name]
				)
				_record_skill_event(next_state, skill_id, message)
			return next_state
	return next_state

func _damage_terrain(state: Dictionary, terrain_index: int, damage: int) -> Dictionary:
	var next_state: Dictionary = state
	if damage <= 0:
		return next_state
	var terrain_entries: Array = next_state.get("terrain", []).duplicate(true)
	if terrain_index < 0 or terrain_index >= terrain_entries.size():
		return next_state
	var terrain: Dictionary = _normalized_terrain(terrain_entries[terrain_index])
	if int(terrain.get("hp", 0)) <= 0:
		return next_state
	terrain["hp"] = maxi(0, int(terrain.get("hp", 0)) - damage)
	terrain_entries[terrain_index] = terrain
	next_state["terrain"] = terrain_entries
	if int(terrain.get("hp", 0)) <= 0:
		_log(next_state, "Terrain breaks.")
	return next_state

func _damage_terrain_indices(state: Dictionary, terrain_indices: Array[int], damage: int) -> Dictionary:
	var next_state: Dictionary = state
	if damage <= 0:
		return next_state
	for terrain_index: int in terrain_indices:
		next_state = _damage_terrain(next_state, terrain_index, damage)
	return next_state

func _create_illusion(state: Dictionary, pos: Vector2i, health: int) -> Dictionary:
	var next_state: Dictionary = state
	for existing_illusion: Dictionary in _live_illusions(next_state):
		if existing_illusion.get("pos", INVALID_TILE) == pos:
			return next_state
	var stage_before: String = effective_umbra_stage(next_state)
	var illusion_health: int = maxi(1, health)
	var illusions: Array = next_state.get("illusions", []).duplicate(true)
	var illusion_id: int = int(next_state.get("next_illusion_id", 1))
	illusions.append({
		"id": illusion_id,
		"pos": pos,
		"hp": illusion_health,
		"max_hp": illusion_health
	})
	next_state["illusions"] = illusions
	next_state["next_illusion_id"] = illusion_id + 1
	_log(next_state, "Illusion appears.")
	return _resolve_umbra_transition_relics(next_state, stage_before)

func _trigger_illusion_afterglow(state: Dictionary, pos: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	if pos == INVALID_TILE:
		return next_state
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("illusion_afterglow")
	if skill_id.is_empty() or not has_skill(next_state, skill_id):
		return next_state
	var effect: Dictionary = SkillTreeLibrary.effect(skill_id)
	next_state = _create_umbra_light_source(next_state, pos, {
		"radius": int(effect.get("radius", 1)),
		"duration": int(effect.get("duration", 2)),
		"silent": true
	})
	_record_skill_event(next_state, skill_id, "%s leaves Light where an illusion faded." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func _visible_enemy_id_lookup(state: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for enemy_id: int in visible_enemy_ids(state):
		lookup[enemy_id] = true
	return lookup

func _record_umbra_reveal_delta(state: Dictionary, before_visible: Dictionary, before_tiles: Dictionary) -> void:
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	var after_tiles: Dictionary = _umbra_visible_tile_lookup(state)
	var newly_visible_enemies: int = 0
	for enemy_id: int in visible_enemy_ids(state, after_tiles):
		if not before_visible.has(enemy_id):
			newly_visible_enemies += 1
	var newly_visible_tiles: int = 0
	for tile_var: Variant in after_tiles.keys():
		var tile: Vector2i = tile_var as Vector2i
		if not before_tiles.has(tile):
			newly_visible_tiles += 1
	umbra["enemies_revealed_total"] = int(umbra.get("enemies_revealed_total", 0)) + newly_visible_enemies
	umbra["tiles_illuminated_total"] = int(umbra.get("tiles_illuminated_total", 0)) + newly_visible_tiles
	state["umbra"] = umbra

func _record_umbra_reveal_delta_for_light_source(
	state: Dictionary,
	before_visible: Dictionary,
	before_tiles: Dictionary,
	source_pos: Vector2i,
	source_radius: int
) -> void:
	var newly_visible_tiles: int = 0
	var grid: Array = state.get("grid", []) as Array
	for y: int in range(grid.size()):
		var row: Array = grid[y] as Array
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			if not before_tiles.has(tile) and PathUtils.manhattan(source_pos, tile) <= source_radius:
				newly_visible_tiles += 1
	var newly_visible_enemies: int = 0
	for enemy: Dictionary in _live_enemies(state):
		var enemy_id: int = int(enemy.get("id", -1))
		if before_visible.has(enemy_id):
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if PathUtils.manhattan(source_pos, tile) <= source_radius:
				newly_visible_enemies += 1
				break
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["enemies_revealed_total"] = int(umbra.get("enemies_revealed_total", 0)) + newly_visible_enemies
	umbra["tiles_illuminated_total"] = int(umbra.get("tiles_illuminated_total", 0)) + newly_visible_tiles
	state["umbra"] = umbra

func _umbra_visible_tile_lookup(state: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for tile: Vector2i in umbra_visible_tiles(state):
		lookup[tile] = true
	return lookup

func _create_umbra_light_source(state: Dictionary, pos: Vector2i, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var stage_before: String = effective_umbra_stage(next_state)
	# At unlimited effective radius every board tile and live enemy is already
	# visible, so adding Light cannot increment either reveal counter. Dense AOE
	# previews can create Light on every hovered target; avoiding four full-board
	# visibility walks in this no-op case keeps that exact simulation interactive.
	var tracks_reveal_delta: bool = effective_umbra_radius(next_state) < UMBRA_UNLIMITED_RADIUS
	var had_truesight_before: bool = _player_has_truesight(next_state) if tracks_reveal_delta else false
	var before_tiles: Dictionary = _umbra_visible_tile_lookup(next_state) if tracks_reveal_delta else {}
	var before_visible: Dictionary = {}
	if tracks_reveal_delta:
		for enemy_id: int in visible_enemy_ids(next_state, before_tiles):
			before_visible[enemy_id] = true
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	var sources: Array = (umbra.get("light_sources", []) as Array).duplicate(true)
	var radius: int = maxi(1, int(action.get("radius", action.get("amount", 1))))
	var duration: int = _radiance_duration_for_player(next_state, int(action.get("duration", 1)))
	var refreshed: bool = false
	for index: int in range(sources.size()):
		if typeof(sources[index]) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = (sources[index] as Dictionary).duplicate(true)
		if source.get("pos", Vector2i(-1, -1)) != pos:
			continue
		source["radius"] = maxi(int(source.get("radius", 0)), radius)
		if int(source.get("remaining_activations", 0)) < 0 or duration < 0:
			source["remaining_activations"] = -1
		else:
			source["remaining_activations"] = maxi(int(source.get("remaining_activations", 0)), duration)
		sources[index] = source
		refreshed = true
		break
	if not refreshed:
		var source_id: int = maxi(1, int(umbra.get("next_light_source_id", 1)))
		sources.append({
			"id": source_id,
			"pos": pos,
			"radius": radius,
			"remaining_activations": duration
		})
		umbra["next_light_source_id"] = source_id + 1
	umbra["light_sources"] = sources
	next_state["umbra"] = umbra
	if tracks_reveal_delta:
		if effective_umbra_stage(next_state) != stage_before or (not had_truesight_before and _player_has_truesight(next_state)):
			# Crossing a Light-source suppression threshold expands the player's
			# personal radius globally. Open Sky can also turn a Light source under
			# the player into global enemy Truesight without changing the stage.
			# Both cases require the general after-state comparison.
			_record_umbra_reveal_delta(next_state, before_visible, before_tiles)
		else:
			# With the same effective stage, this source is the only new visibility
			# contributor and its Manhattan coverage is an exact incremental delta.
			_record_umbra_reveal_delta_for_light_source(next_state, before_visible, before_tiles, pos, radius)
	if not bool(action.get("silent", false)):
		_log(next_state, "Light blooms through the Umbra.")
	return _resolve_umbra_transition_relics(next_state, stage_before)

func _apply_umbra_vision(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var before_visible: Dictionary = _visible_enemy_id_lookup(next_state)
	var before_tiles: Dictionary = _umbra_visible_tile_lookup(next_state)
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["vision_bonus"] = int(umbra.get("vision_bonus", 0)) + maxi(0, int(action.get("amount", 0)))
	var duration: int = _radiance_duration_for_player(next_state, int(action.get("duration", 1)))
	if int(umbra.get("vision_bonus_activations", 0)) < 0 or duration < 0:
		umbra["vision_bonus_activations"] = -1
	else:
		umbra["vision_bonus_activations"] = maxi(int(umbra.get("vision_bonus_activations", 0)), duration)
	next_state["umbra"] = umbra
	_record_umbra_reveal_delta(next_state, before_visible, before_tiles)
	_log(next_state, "Vision pushes back the Umbra.")
	return next_state

func _apply_umbra_truesight(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var before_visible: Dictionary = _visible_enemy_id_lookup(next_state)
	var before_tiles: Dictionary = _umbra_visible_tile_lookup(next_state)
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	var duration: int = _radiance_duration_for_player(next_state, int(action.get("duration", action.get("amount", 1))))
	if int(umbra.get("truesight_activations", 0)) < 0 or duration < 0:
		umbra["truesight_activations"] = -1
	else:
		umbra["truesight_activations"] = maxi(int(umbra.get("truesight_activations", 0)), duration)
	next_state["umbra"] = umbra
	_record_umbra_reveal_delta(next_state, before_visible, before_tiles)
	_log(next_state, "Truesight pierces the Umbra.")
	return next_state

func _dispel_umbra(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var stage_before: String = effective_umbra_stage(next_state)
	var before_visible: Dictionary = _visible_enemy_id_lookup(next_state)
	var before_tiles: Dictionary = _umbra_visible_tile_lookup(next_state)
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	var amount: int = maxi(0, int(action.get("amount", 1)))
	umbra["stage_reduction"] = mini(
		umbra_stage_index(str(umbra.get("stage", UMBRA_STAGE_CLEAR))),
		int(umbra.get("stage_reduction", 0)) + amount
	)
	next_state["umbra"] = umbra
	_record_umbra_reveal_delta(next_state, before_visible, before_tiles)
	_log(next_state, "Daybreak drives the Umbra back.")
	return _resolve_umbra_transition_relics(next_state, stage_before)

func _tick_umbra_player_activation(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var stage_before: String = effective_umbra_stage(next_state)
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	var vision_duration: int = int(umbra.get("vision_bonus_activations", 0))
	if vision_duration > 0:
		vision_duration -= 1
		umbra["vision_bonus_activations"] = vision_duration
		if vision_duration <= 0:
			umbra["vision_bonus"] = 0
	var truesight_duration: int = int(umbra.get("truesight_activations", 0))
	if truesight_duration > 0:
		umbra["truesight_activations"] = truesight_duration - 1
	var eclipse_duration: int = int(umbra.get("boss_eclipse_activations", 0))
	if eclipse_duration > 0:
		eclipse_duration -= 1
		umbra["boss_eclipse_activations"] = eclipse_duration
		if eclipse_duration <= 0:
			umbra["boss_eclipse_stage"] = ""
	var remaining_sources: Array = []
	for source_var: Variant in umbra.get("light_sources", []):
		if typeof(source_var) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = (source_var as Dictionary).duplicate(true)
		var remaining: int = int(source.get("remaining_activations", 0))
		if remaining < 0:
			remaining_sources.append(source)
			continue
		remaining -= 1
		if remaining > 0:
			source["remaining_activations"] = remaining
			remaining_sources.append(source)
	umbra["light_sources"] = remaining_sources
	next_state["umbra"] = umbra
	return _resolve_umbra_transition_relics(next_state, stage_before)

func _radiance_duration_for_player(state: Dictionary, duration: int) -> int:
	if duration < 0:
		return duration
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("extend_radiance_duration")
	if skill_id.is_empty() or not has_skill(state, skill_id):
		return duration
	return duration + maxi(0, int(SkillTreeLibrary.effect(skill_id).get("amount", 1)))

func _resolve_umbra_transition_relics(state: Dictionary, stage_before: String) -> Dictionary:
	var next_state: Dictionary = state
	var stage_after: String = effective_umbra_stage(next_state)
	if stage_after == stage_before:
		return next_state
	var authored_stage: String = str((next_state.get("umbra", {}) as Dictionary).get("stage", UMBRA_STAGE_CLEAR))
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "umbra_transition_reward":
			continue
		if umbra_stage_index(authored_stage) < umbra_stage_index(str(effect.get("initial_stage_min", UMBRA_STAGE_FRINGE))):
			continue
		var target_stage: String = str(effect.get("target_stage", UMBRA_STAGE_CLEAR))
		if stage_before == target_stage or stage_after != target_stage:
			continue
		if not _relic_once_available(next_state, effect, "umbra_transition_reward", target_stage):
			continue
		_mark_relic_once(next_state, effect, "umbra_transition_reward", target_stage)
		next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
	return next_state

func _normalized_player(player_value: Variant) -> Dictionary:
	return _normalized_unit(player_value)

func _normalized_illusion(illusion_value: Variant) -> Dictionary:
	var illusion: Dictionary = {}
	if typeof(illusion_value) == TYPE_DICTIONARY:
		illusion = (illusion_value as Dictionary).duplicate(true)
	illusion["id"] = int(illusion.get("id", -1))
	illusion["pos"] = illusion.get("pos", Vector2i.ZERO)
	illusion["hp"] = int(illusion.get("hp", 0))
	illusion["max_hp"] = maxi(1, int(illusion.get("max_hp", illusion.get("hp", 1))))
	return illusion

func _normalized_terrain(terrain_value: Variant) -> Dictionary:
	var terrain: Dictionary = {}
	if typeof(terrain_value) == TYPE_DICTIONARY:
		terrain = (terrain_value as Dictionary).duplicate(true)
	terrain["id"] = str(terrain.get("id", ""))
	terrain["kind"] = str(terrain.get("kind", "wooden_box"))
	terrain["pos"] = terrain.get("pos", Vector2i.ZERO)
	terrain["hp"] = int(terrain.get("hp", 0))
	terrain["max_hp"] = maxi(1, int(terrain.get("max_hp", terrain.get("hp", 1))))
	return terrain

func _normalized_enemy(enemy_value: Variant) -> Dictionary:
	var enemy: Dictionary = _normalized_unit(enemy_value)
	enemy["frost_armor"] = maxi(0, int(enemy.get("frost_armor", 0)))
	if not enemy.has("element"):
		enemy["element"] = ElementData.NONE
	if not enemy.has("footprint"):
		var footprint_value: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("footprint", [])
		if typeof(footprint_value) == TYPE_ARRAY and (footprint_value as Array).size() >= 2:
			enemy["footprint"] = Vector2i(int((footprint_value as Array)[0]), int((footprint_value as Array)[1]))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	enemy["footprint"] = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	for status_id: String in _enemy_status_immunities(enemy):
		match status_id:
			"poison":
				enemy[status_id] = {"damage": 0, "delay": 0}
			"immobilize":
				enemy[status_id] = false
			_:
				enemy[status_id] = 0
	return enemy

func _normalized_unit(unit_value: Variant) -> Dictionary:
	var unit: Dictionary = {}
	if typeof(unit_value) == TYPE_DICTIONARY:
		unit = (unit_value as Dictionary).duplicate(true)
	unit["block"] = int(unit.get("block", 0))
	unit["stoneskin"] = int(unit.get("stoneskin", 0))
	unit["burn"] = int(unit.get("burn", 0))
	unit["bleed"] = int(unit.get("bleed", 0))
	unit["expose"] = int(unit.get("expose", 0))
	unit["freeze"] = int(unit.get("freeze", 0))
	unit["shock"] = int(unit.get("shock", 0))
	unit["immobilize"] = bool(unit.get("immobilize", false))
	var poison_value: Variant = unit.get("poison", {})
	var poison: Dictionary = {}
	if typeof(poison_value) == TYPE_DICTIONARY:
		poison = (poison_value as Dictionary).duplicate(true)
	unit["poison"] = {
		"damage": int(poison.get("damage", 0)),
		"delay": int(poison.get("delay", 0))
	}
	return unit

func _initialize_initiative_queue(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	next_state["initiative_clock"] = 0
	next_state["activation_seq"] = 0
	next_state["current_actor"] = _player_actor_entry(0, 0)
	next_state["player_turn_time_spent"] = 0
	var queue: Array = []
	var enemies: Array = next_state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		if typeof(enemies[enemy_index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
		var first_delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(next_state, enemy) + maxi(0, intent_time_cost))
		var entry: Dictionary = _enemy_actor_entry(next_state, enemy, first_delay + enemy_index, _claim_activation_seq(next_state))
		entry["intent_time_cost"] = intent_time_cost
		queue.append(entry)
	next_state["turn_queue"] = _sorted_turn_queue(queue)
	return next_state

func _player_actor_entry(scheduled_time: int, seq: int) -> Dictionary:
	return {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": scheduled_time,
		"seq": seq
	}

func _enemy_actor_entry(state: Dictionary, enemy: Dictionary, scheduled_time: int, seq: int) -> Dictionary:
	var enemy_type: String = str(enemy.get("type", ""))
	return {
		"kind": "enemy",
		"actor_key": _enemy_key(enemy),
		"enemy_id": int(enemy.get("id", -1)),
		"type": enemy_type,
		"name": str(GameData.enemy_def(enemy_type).get("name", "Enemy")),
		"team": "enemy",
		"time": scheduled_time,
		"seq": seq,
		"pos": enemy.get("pos", Vector2i.ZERO)
	}

func _enemy_with_resolved_footprint(enemy_value: Variant, definition: Dictionary = {}) -> Dictionary:
	if typeof(enemy_value) != TYPE_DICTIONARY:
		return {}
	var enemy: Dictionary = enemy_value as Dictionary
	var footprint: Vector2i = Vector2i.ONE
	var footprint_value: Variant = enemy.get("footprint", null)
	if typeof(footprint_value) == TYPE_VECTOR2I:
		footprint = footprint_value as Vector2i
	else:
		if typeof(footprint_value) != TYPE_ARRAY:
			if definition.is_empty():
				definition = GameData.enemy_def(str(enemy.get("type", "")))
			footprint_value = definition.get("footprint", [])
		if typeof(footprint_value) == TYPE_ARRAY and (footprint_value as Array).size() >= 2:
			footprint = Vector2i(int((footprint_value as Array)[0]), int((footprint_value as Array)[1]))
	footprint = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	if enemy.get("footprint", null) == footprint:
		return enemy
	var resolved: Dictionary = enemy.duplicate()
	resolved["footprint"] = footprint
	return resolved

func _turn_order_projection_context(state: Dictionary, visible_lookup: Dictionary) -> Dictionary:
	var player_value: Variant = state.get("player", {})
	var player: Dictionary = player_value as Dictionary if typeof(player_value) == TYPE_DICTIONARY else {}
	var context: Dictionary = {
		"clock": int(state.get("initiative_clock", 0)),
		"player": player,
		"player_base_initiative": player_base_initiative(state),
		"player_turn_time_spent": int(state.get("player_turn_time_spent", 0)),
		"enemy_facts": {}
	}
	var enemy_facts: Dictionary = context.get("enemy_facts", {}) as Dictionary
	var definitions_by_type: Dictionary = {}
	var player_has_truesight: bool = _player_has_truesight(state)
	var depth: int = maxi(1, int(state.get("room_depth", 1)))
	var depth_bonus: int = mini(4, int((depth - 1) / 3))
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		# Turn-order presentation only reads identity, health, position, footprint,
		# and intent. Full enemy normalization deep-copies every status payload and
		# resolves immunities, none of which can affect this projection.
		var raw_enemy: Dictionary = enemy_var as Dictionary
		var enemy_id: int = int(raw_enemy.get("id", -1))
		# Preserve _enemy_index_for_id's first-match behavior for malformed legacy
		# states with duplicate IDs.
		if enemy_facts.has(enemy_id):
			continue
		var enemy_type: String = str(raw_enemy.get("type", ""))
		var definition: Dictionary = definitions_by_type.get(enemy_type, {}) as Dictionary
		if definition.is_empty():
			definition = GameData.enemy_def(enemy_type)
			definitions_by_type[enemy_type] = definition
		var enemy: Dictionary = _enemy_with_resolved_footprint(raw_enemy, definition)
		var base_initiative: int = maxi(
			ENEMY_MIN_INITIATIVE,
			int(definition.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE)) - depth_bonus
		)
		var visible: bool = int(enemy.get("hp", 0)) > 0 and (
			bool(definition.get("boss_bar", false))
			or player_has_truesight
		)
		if not visible and int(enemy.get("hp", 0)) > 0:
			for tile: Vector2i in _enemy_footprint_tiles(enemy):
				if visible_lookup.has(tile):
					visible = true
					break
		enemy_facts[enemy_id] = {
			"enemy": enemy,
			"actor": {
				"kind": "enemy",
				"actor_key": _enemy_key(enemy),
				"enemy_id": enemy_id,
				"type": enemy_type,
				"name": str(definition.get("name", "Enemy")),
				"team": "enemy",
				"pos": enemy.get("pos", Vector2i.ZERO)
			},
			"base_initiative": base_initiative,
			"intent_time_cost": _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary),
			"visible": visible
		}
	return context

func _turn_order_enemy_entry(enemy_fact: Dictionary, scheduled_time: int, seq: int) -> Dictionary:
	var enemy_entry: Dictionary = (enemy_fact.get("actor", {}) as Dictionary).duplicate()
	enemy_entry["time"] = scheduled_time
	enemy_entry["seq"] = seq
	return enemy_entry

func _resolved_actor_entry(state: Dictionary, entry: Dictionary, projection_context: Dictionary = {}) -> Dictionary:
	var kind: String = str(entry.get("kind", ""))
	if kind == "player":
		var player: Dictionary = projection_context.get("player", {}) as Dictionary
		if player.is_empty():
			player = _normalized_player(state.get("player", {}))
		if int(player.get("hp", 0)) <= 0:
			return {}
		var player_entry: Dictionary = _player_actor_entry(int(entry.get("time", state.get("initiative_clock", 0))), int(entry.get("seq", 0)))
		player_entry["eta"] = maxi(0, int(player_entry.get("time", 0)) - int(state.get("initiative_clock", 0)))
		player_entry["base_initiative"] = int(projection_context.get("player_base_initiative", player_base_initiative(state)))
		player_entry["turn_time_spent"] = int(projection_context.get("player_turn_time_spent", state.get("player_turn_time_spent", 0)))
		player_entry["hp"] = int(player.get("hp", 0))
		player_entry["max_hp"] = int(player.get("max_hp", 1))
		if bool(entry.get("projected", false)):
			player_entry["projected"] = true
		if entry.has("projected_time_cost"):
			player_entry["projected_time_cost"] = int(entry.get("projected_time_cost", 0))
		if entry.has("projected_card_name"):
			player_entry["projected_card_name"] = str(entry.get("projected_card_name", ""))
		return player_entry
	if kind == "enemy":
		var enemy_id: int = int(entry.get("enemy_id", -1))
		var enemy_facts: Dictionary = projection_context.get("enemy_facts", {})
		if enemy_facts.has(enemy_id):
			var enemy_fact: Dictionary = enemy_facts.get(enemy_id, {}) as Dictionary
			var cached_enemy: Dictionary = enemy_fact.get("enemy", {}) as Dictionary
			if int(cached_enemy.get("hp", 0)) <= 0:
				return {}
			var cached_entry: Dictionary = _turn_order_enemy_entry(
				enemy_fact,
				int(entry.get("time", state.get("initiative_clock", 0))),
				int(entry.get("seq", 0))
			)
			cached_entry["eta"] = maxi(0, int(cached_entry.get("time", 0)) - int(state.get("initiative_clock", 0)))
			cached_entry["base_initiative"] = int(enemy_fact.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE))
			cached_entry["hp"] = int(cached_enemy.get("hp", 0))
			cached_entry["max_hp"] = int(cached_enemy.get("max_hp", 1))
			if bool(entry.get("projected", false)):
				cached_entry["projected"] = true
			if entry.has("intent_time_cost"):
				cached_entry["intent_time_cost"] = int(entry.get("intent_time_cost", 0))
			return cached_entry
		var enemy_index: int = _enemy_index_for_id(state, enemy_id)
		if enemy_index < 0:
			return {}
		var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			return {}
		var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, int(entry.get("time", state.get("initiative_clock", 0))), int(entry.get("seq", 0)))
		enemy_entry["eta"] = maxi(0, int(enemy_entry.get("time", 0)) - int(state.get("initiative_clock", 0)))
		enemy_entry["base_initiative"] = _enemy_base_initiative(state, enemy)
		enemy_entry["hp"] = int(enemy.get("hp", 0))
		enemy_entry["max_hp"] = int(enemy.get("max_hp", 1))
		if bool(entry.get("projected", false)):
			enemy_entry["projected"] = true
		if entry.has("intent_time_cost"):
			enemy_entry["intent_time_cost"] = int(entry.get("intent_time_cost", 0))
		return enemy_entry
	return {}

func _projected_next_entry_for_current_actor(state: Dictionary, current_actor: Dictionary, projection_context: Dictionary = {}) -> Dictionary:
	if current_actor.is_empty():
		return {}
	var clock: int = int(state.get("initiative_clock", 0))
	match str(current_actor.get("kind", "")):
		"player":
			var preview_delta: int = maxi(0, int(state.get("turn_order_preview_time_delta", 0)))
			var player_entry: Dictionary = _player_actor_entry(
				clock + player_base_initiative(state) + maxi(0, int(state.get("player_turn_time_spent", 0))) + preview_delta,
				-1
			)
			player_entry["projected"] = true
			if preview_delta > 0:
				player_entry["projected_time_cost"] = preview_delta
			if state.has("turn_order_preview_card_name"):
				player_entry["projected_card_name"] = str(state.get("turn_order_preview_card_name", ""))
			return player_entry
		"enemy":
			var enemy_id: int = int(current_actor.get("enemy_id", -1))
			var enemy_facts: Dictionary = projection_context.get("enemy_facts", {})
			if enemy_facts.has(enemy_id):
				var enemy_fact: Dictionary = enemy_facts.get(enemy_id, {}) as Dictionary
				var cached_enemy: Dictionary = enemy_fact.get("enemy", {}) as Dictionary
				if int(cached_enemy.get("hp", 0)) <= 0:
					return {}
				var cached_intent_time_cost: int = int(enemy_fact.get("intent_time_cost", DEFAULT_ENEMY_INTENT_TIME_COST))
				var cached_delay: int = maxi(ENEMY_MIN_INITIATIVE, int(enemy_fact.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE)) + maxi(0, cached_intent_time_cost))
				var cached_entry: Dictionary = _turn_order_enemy_entry(enemy_fact, clock + cached_delay, -1)
				cached_entry["projected"] = true
				cached_entry["intent_time_cost"] = cached_intent_time_cost
				return cached_entry
			var enemy_index: int = _enemy_index_for_id(state, enemy_id)
			if enemy_index < 0:
				return {}
			var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
			if int(enemy.get("hp", 0)) <= 0:
				return {}
			var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
			var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
			var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, clock + delay, -1)
			enemy_entry["projected"] = true
			enemy_entry["intent_time_cost"] = intent_time_cost
			return enemy_entry
	return {}

func _projected_next_entry_after_entry(state: Dictionary, entry: Dictionary, projection_context: Dictionary = {}) -> Dictionary:
	if bool(entry.get("projected", false)):
		return {}
	var resolved: Dictionary = _resolved_actor_entry(state, entry, projection_context)
	if resolved.is_empty():
		return {}
	var scheduled_time: int = int(resolved.get("time", state.get("initiative_clock", 0)))
	var projected_seq: int = int(entry.get("seq", 0)) + 10000
	match str(resolved.get("kind", "")):
		"player":
			var player_entry: Dictionary = _player_actor_entry(scheduled_time + player_base_initiative(state), projected_seq)
			player_entry["projected"] = true
			return player_entry
		"enemy":
			var enemy_id: int = int(resolved.get("enemy_id", -1))
			var enemy_facts: Dictionary = projection_context.get("enemy_facts", {})
			if enemy_facts.has(enemy_id):
				var enemy_fact: Dictionary = enemy_facts.get(enemy_id, {}) as Dictionary
				var cached_enemy: Dictionary = enemy_fact.get("enemy", {}) as Dictionary
				if int(cached_enemy.get("hp", 0)) <= 0:
					return {}
				var cached_intent_time_cost: int = int(enemy_fact.get("intent_time_cost", DEFAULT_ENEMY_INTENT_TIME_COST))
				var cached_delay: int = maxi(ENEMY_MIN_INITIATIVE, int(enemy_fact.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE)) + maxi(0, cached_intent_time_cost))
				var cached_entry: Dictionary = _turn_order_enemy_entry(enemy_fact, scheduled_time + cached_delay, projected_seq)
				cached_entry["projected"] = true
				cached_entry["intent_time_cost"] = cached_intent_time_cost
				return cached_entry
			var enemy_index: int = _enemy_index_for_id(state, enemy_id)
			if enemy_index < 0:
				return {}
			var enemy: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[enemy_index] as Dictionary)
			if int(enemy.get("hp", 0)) <= 0:
				return {}
			var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
			var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
			var enemy_entry: Dictionary = _enemy_actor_entry(state, enemy, scheduled_time + delay, projected_seq)
			enemy_entry["projected"] = true
			enemy_entry["intent_time_cost"] = intent_time_cost
			return enemy_entry
	return {}

func _sorted_turn_queue(queue_value: Variant) -> Array:
	var queue: Array = []
	if typeof(queue_value) == TYPE_ARRAY:
		queue = (queue_value as Array).duplicate(true)
	queue.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_entry: Dictionary = {}
		if typeof(a) == TYPE_DICTIONARY:
			a_entry = a as Dictionary
		var b_entry: Dictionary = {}
		if typeof(b) == TYPE_DICTIONARY:
			b_entry = b as Dictionary
		var a_time: int = int(a_entry.get("time", 0))
		var b_time: int = int(b_entry.get("time", 0))
		if a_time == b_time:
			# The Reaver wins exact clock ties. Turn-order projections already put
			# the player's future slot first; applying the same rule here keeps the
			# displayed forecast and the actor that actually activates consistent.
			var a_is_player: bool = str(a_entry.get("kind", "")) == "player"
			var b_is_player: bool = str(b_entry.get("kind", "")) == "player"
			if a_is_player != b_is_player:
				return a_is_player
			return int(a_entry.get("seq", 0)) < int(b_entry.get("seq", 0))
		return a_time < b_time
	)
	return queue

func _pop_next_actor(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var queue: Array = _sorted_turn_queue(next_state.get("turn_queue", []))
	while not queue.is_empty():
		var entry_var: Variant = queue.pop_front()
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var resolved: Dictionary = _resolved_actor_entry(next_state, entry)
		if resolved.is_empty():
			continue
		next_state["turn_queue"] = queue
		next_state["current_actor"] = resolved
		next_state["initiative_clock"] = int(resolved.get("time", next_state.get("initiative_clock", 0)))
		var reinforcement_steps: Array[Dictionary] = _spawn_due_survival_reinforcements(next_state)
		return {"state": next_state, "entry": resolved, "reinforcement_steps": reinforcement_steps}
	next_state["turn_queue"] = queue
	return {"state": next_state, "entry": {}, "reinforcement_steps": []}

func _spawn_due_survival_reinforcements(state: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var objective: Dictionary = (state.get("objective", {}) as Dictionary).duplicate(true)
	if str(objective.get("type", "")) != CombatObjectiveRules.SURVIVE:
		return steps
	var current_clock: int = int(state.get("initiative_clock", 0))
	var target_clock: int = int(objective.get("target_clock", 0))
	var interval: int = maxi(1, int(objective.get("reinforcement_interval", CombatObjectiveRules.SURVIVAL_REINFORCEMENT_INTERVAL)))
	var next_clock: int = int(objective.get("next_reinforcement_clock", interval))
	if current_clock >= target_clock:
		return steps
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = int(state.get("rng_state", 1))
	while next_clock <= current_clock and next_clock < target_clock:
		var spawn_tile: Vector2i = _survival_reinforcement_spawn_tile(state, rng)
		if spawn_tile.x < 0:
			break
		var pool: Array = objective.get("reinforcement_pool", [])
		if pool.is_empty():
			break
		var enemy_type: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		var spawned_enemy: Dictionary = _spawned_enemy_entry(state, enemy_type, _next_enemy_id(state), spawn_tile, false)
		spawned_enemy["objective_reinforcement"] = true
		var enemies: Array = state.get("enemies", []).duplicate(true)
		enemies.append(spawned_enemy)
		state["enemies"] = enemies
		var spawned_index: int = enemies.size() - 1
		_assign_enemy_intent(state, spawned_index, rng)
		spawned_enemy = _normalized_enemy((state.get("enemies", []) as Array)[spawned_index] as Dictionary)
		_schedule_enemy_after_spawn(state, spawned_enemy, int(objective.get("reinforcement_waves_spawned", 0)))
		objective["reinforcement_waves_spawned"] = int(objective.get("reinforcement_waves_spawned", 0)) + 1
		next_clock += interval
		objective["next_reinforcement_clock"] = next_clock
		state["objective"] = objective.duplicate(true)
		state["rng_state"] = rng.state
		_log(state, "%s emerges from the Umbra." % _enemy_display_name(spawned_enemy))
		steps.append({
			"kind": "reinforcement_spawn",
			"spawned_enemies": [spawned_enemy.duplicate(true)],
			"state": state.duplicate(true)
		})
	return steps

func _survival_reinforcement_spawn_tile(state: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var blocked: Dictionary = _enemy_blocking_tiles(state)
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY:
			blocked[(trap_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for loot_var: Variant in state.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY and not bool((loot_var as Dictionary).get("claimed", false)):
			blocked[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var candidates: Array[Dictionary] = []
	for tile: Vector2i in _all_passable_tiles(state):
		if blocked.has(tile):
			continue
		var edge_distance: int = mini(mini(tile.x, tile.y), mini(8 - tile.x, 8 - tile.y))
		candidates.append({
			"tile": tile,
			"score": PathUtils.manhattan(tile, player_tile) * 8 - edge_distance * 3 + rng.randi_range(0, 5)
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: int = int(a.get("score", 0))
		var b_score: int = int(b.get("score", 0))
		if a_score == b_score:
			return _tile_precedes(a.get("tile", INVALID_TILE), b.get("tile", INVALID_TILE))
		return a_score > b_score
	)
	return candidates[0].get("tile", Vector2i(-1, -1)) if not candidates.is_empty() else Vector2i(-1, -1)

func _schedule_actor(state: Dictionary, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var queue: Array = _sorted_turn_queue(state.get("turn_queue", []))
	var scheduled: Dictionary = entry.duplicate(true)
	scheduled["seq"] = _claim_activation_seq(state)
	queue.append(scheduled)
	state["turn_queue"] = _sorted_turn_queue(queue)

func _schedule_enemy_after_turn(state: Dictionary, enemy: Dictionary, turn_time_cost: int) -> void:
	var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, turn_time_cost))
	_schedule_actor(state, _enemy_actor_entry(state, enemy, int(state.get("initiative_clock", 0)) + delay, 0))

func _append_turn_order_step(steps: Array[Dictionary], before_state: Dictionary, after_state: Dictionary, label: String) -> void:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var before_order: Array[Dictionary] = []
	var after_order: Array[Dictionary] = []
	if _turn_order_projection_context_can_be_shared(before_state, after_state):
		# Activation and reschedule boundaries normally change only the initiative
		# queue, clock, and current actor. Their visibility and actor facts are
		# identical, so building that projection context twice only repeats work.
		var visible_lookup: Dictionary = umbra_visible_tile_lookup(after_state)
		var shared_context: Dictionary = _turn_order_projection_context(after_state, visible_lookup)
		before_order = current_turn_order(before_state, TURN_ORDER_PREVIEW_LIMIT, shared_context)
		after_order = current_turn_order(after_state, TURN_ORDER_PREVIEW_LIMIT, shared_context)
	else:
		before_order = current_turn_order(before_state, TURN_ORDER_PREVIEW_LIMIT)
		after_order = current_turn_order(after_state, TURN_ORDER_PREVIEW_LIMIT)
	var performance_phase_started: int = _record_runtime_performance_phase("turn_order_step_projection_total", performance_total_started)
	if _turn_order_signature(before_order) == _turn_order_signature(after_order):
		_record_runtime_performance_phase("turn_order_step_signature", performance_phase_started)
		_record_runtime_performance_phase("turn_order_step_total", performance_total_started)
		return
	performance_phase_started = _record_runtime_performance_phase("turn_order_step_signature", performance_phase_started)
	steps.append({
		"kind": "turn_order",
		"label": label,
		"before_order": before_order,
		"after_order": after_order
	})
	_record_runtime_performance_phase("turn_order_step_append", performance_phase_started)
	_record_runtime_performance_phase("turn_order_step_total", performance_total_started)

func _turn_order_projection_context_can_be_shared(before_state: Dictionary, after_state: Dictionary) -> bool:
	return (
		before_state.get("player", {}) == after_state.get("player", {})
		and before_state.get("enemies", []) == after_state.get("enemies", [])
		and int(before_state.get("room_depth", 1)) == int(after_state.get("room_depth", 1))
		and before_state.get("grid", []) == after_state.get("grid", [])
		and before_state.get("umbra", {}) == after_state.get("umbra", {})
		and before_state.get("illusions", []) == after_state.get("illusions", [])
		and before_state.get("skill_ids", []) == after_state.get("skill_ids", [])
		and before_state.get("relics", []) == after_state.get("relics", [])
		and int(before_state.get("player_turn_time_spent", 0)) == int(after_state.get("player_turn_time_spent", 0))
	)

func _append_commit_step(steps: Array[Dictionary], before_state: Dictionary, after_state: Dictionary, boundary: String) -> void:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	if before_state == after_state:
		_record_runtime_performance_phase("commit_step_compare", performance_total_started)
		_record_runtime_performance_phase("commit_step_total", performance_total_started)
		return
	var performance_phase_started: int = _record_runtime_performance_phase("commit_step_compare", performance_total_started)
	var committed_state: Dictionary = after_state.duplicate(true)
	performance_phase_started = _record_runtime_performance_phase("commit_step_duplicate", performance_phase_started)
	steps.append({
		"kind": "commit",
		"boundary": boundary,
		"state": committed_state
	})
	_record_runtime_performance_phase("commit_step_append", performance_phase_started)
	_record_runtime_performance_phase("commit_step_total", performance_total_started)

func _turn_order_signature(order: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in order:
		parts.append("%s:%s:%d:%d:%s" % [
			str(entry.get("kind", "")),
			str(entry.get("actor_key", "")),
			int(entry.get("time", 0)),
			int(entry.get("seq", 0)),
			str(bool(entry.get("active", false)))
		])
	return "|".join(parts)

func _claim_activation_seq(state: Dictionary) -> int:
	var next_seq: int = int(state.get("activation_seq", 0)) + 1
	state["activation_seq"] = next_seq
	return next_seq

func _enemy_index_for_id(state: Dictionary, enemy_id: int) -> int:
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		if int((enemies[index] as Dictionary).get("id", -1)) == enemy_id:
			return index
	return -1

func _enemy_base_initiative(state: Dictionary, enemy: Dictionary) -> int:
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var base: int = int(definition.get("base_initiative", DEFAULT_ENEMY_BASE_INITIATIVE))
	var depth: int = maxi(1, int(state.get("room_depth", 1)))
	var depth_bonus: int = mini(4, int((depth - 1) / 3))
	return maxi(ENEMY_MIN_INITIATIVE, base - depth_bonus)

func _enemy_intent_time_cost(intent: Dictionary) -> int:
	if intent.has("time"):
		return clampi(int(intent.get("time", DEFAULT_ENEMY_INTENT_TIME_COST)), 0, 12)
	var total: int = 0
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		total += _enemy_action_time_cost(action_var as Dictionary)
	return maxi(DEFAULT_ENEMY_INTENT_TIME_COST, total)

func _enemy_action_time_cost(action: Dictionary) -> int:
	match str(action.get("type", "")):
		"move_toward", "move_away":
			return 2 if int(action.get("range", 0)) <= 2 else 3
		"melee", "ranged", "push", "pull":
			return 3
		"aoe", "lightning_strikes":
			return 4
		"summon_minions", "terrain_burst", "detonate_cinders", "gale_force", "umbra_eclipse":
			return 5
		"block", "stoneskin", "heal_self", "heal_ally", "guard_ally", "intensity", "raise_terrain", "cinder_marks", "frost_armor":
			return 2
		_:
			return DEFAULT_ENEMY_INTENT_TIME_COST

func _estimated_card_time_cost(card: Dictionary) -> int:
	var total: int = 1
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		match str(action.get("type", "")):
			"move", "blink", "block", "stoneskin", "draw", "card_play", "intensity", "intensity_spend", "illuminate", "vision":
				total += 1
			"heal", "illusion", "truesight", "dispel_umbra":
				total += 2
			"melee", "ranged", "push", "pull":
				total += 2
				if int(action.get("damage", 0)) >= 10:
					total += 1
			"aoe":
				total += 3
			_:
				total += 1
	if bool(card.get("burn", false)):
		total = maxi(1, total - 1)
	return clampi(total, MIN_CARD_TIME_COST, MAX_CARD_TIME_COST)

func _enemy_status_immunities(enemy: Dictionary) -> Array[String]:
	var immunities: Array[String] = []
	var raw_immunities: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("status_immunities", [])
	if typeof(raw_immunities) != TYPE_ARRAY:
		return immunities
	for immunity_var: Variant in raw_immunities:
		var status_id: String = str(immunity_var)
		if not status_id.is_empty() and not immunities.has(status_id):
			immunities.append(status_id)
	return immunities

func _enemy_is_immune_to_status(enemy: Dictionary, status_id: String) -> bool:
	return _enemy_status_immunities(enemy).has(status_id)

func _action_has_keyword_effect(action: Dictionary) -> bool:
	return (
		int(action.get("burn", 0)) > 0
		or int(action.get("bleed", 0)) > 0
		or int(action.get("expose", 0)) > 0
		or int(action.get("sunder", 0)) > 0
		or int(action.get("freeze", 0)) > 0
		or int(action.get("shock", 0)) > 0
		or _action_applies_immobilize(action)
		or int(action.get("poison", 0)) > 0
		or int(action.get("push", 0)) > 0
		or int(action.get("pull", 0)) > 0
		or int(action.get("chain", 0)) > 0
	)

func _action_has_forced_movement(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	return (
		(action_type == "push" and int(action.get("amount", 0)) > 0)
		or (action_type == "pull" and int(action.get("amount", 0)) > 0)
		or int(action.get("push", 0)) > 0
		or int(action.get("pull", 0)) > 0
	)

func _action_applies_immobilize(action: Dictionary) -> bool:
	return bool(action.get("immobilize", false))

func _forced_movement_amount(action: Dictionary) -> int:
	match str(action.get("type", "")):
		"push", "pull":
			return maxi(0, int(action.get("amount", 0)))
		_:
			return maxi(0, maxi(int(action.get("push", 0)), int(action.get("pull", 0))))

func _forced_movement_pushes(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", ""))
	if action_type == "pull":
		return false
	if action_type == "push":
		return true
	var push_amount: int = int(action.get("push", 0))
	var pull_amount: int = int(action.get("pull", 0))
	return push_amount > 0 or pull_amount <= 0

func _action_force_direction(action: Dictionary) -> Vector2i:
	return _cardinal_direction(action.get("force_direction", action.get("orientation", Vector2i.ZERO)))

func _action_orientation_direction(action: Dictionary) -> Vector2i:
	return _cardinal_direction(action.get("orientation", Vector2i.ZERO))

func _cardinal_direction(value: Variant) -> Vector2i:
	var raw: Vector2i = Vector2i.ZERO
	match typeof(value):
		TYPE_VECTOR2I:
			raw = value
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			raw = Vector2i(int(roundf(vector_value.x)), int(roundf(vector_value.y)))
		TYPE_ARRAY:
			var pair: Array = value
			if pair.size() >= 2:
				raw = Vector2i(int(pair[0]), int(pair[1]))
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			raw = Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
	if raw == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(raw.x) >= absi(raw.y):
		return Vector2i(1 if raw.x >= 0 else -1, 0)
	return Vector2i(0, 1 if raw.y >= 0 else -1)

func _action_pierces_defense(action: Dictionary) -> bool:
	return bool(action.get("pierce", false))

func _initial_elemental_intensity(room_element: String) -> Dictionary:
	var intensities: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		intensities[element_id] = ELEMENTAL_INTENSITY_ROOM_BASE if element_id == room_element else 0
	return intensities

func _empty_elemental_intensity() -> Dictionary:
	var intensities: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		intensities[element_id] = 0
	return intensities

func _gain_elemental_intensity(state: Dictionary, element_id: String, amount: int, source_name: String = "") -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or amount <= 0:
		return next_state
	var before_value: int = elemental_intensity(next_state, element_id)
	var intensities: Dictionary = elemental_intensities(next_state)
	intensities[element_id] = before_value + amount
	next_state["elemental_intensity"] = intensities
	var gained_total: Dictionary = elemental_intensity_counter(next_state, "elemental_intensity_gained_total")
	gained_total[element_id] = int(gained_total.get(element_id, 0)) + amount
	next_state["elemental_intensity_gained_total"] = gained_total
	if source_name.is_empty():
		_log(next_state, "%s intensity rises by %d." % [ElementData.name(element_id), amount])
	else:
		_log(next_state, "%s raises %s intensity by %d." % [source_name, ElementData.name(element_id), amount])
	return _trigger_intensity_threshold_relics(next_state, element_id, before_value, before_value + amount)

func _consume_elemental_intensity(state: Dictionary, element_id: String, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or amount <= 0:
		return next_state
	var before_value: int = elemental_intensity(next_state, element_id)
	var after_value: int = maxi(0, before_value - amount)
	var spent: int = before_value - after_value
	if spent <= 0:
		return next_state
	var intensities: Dictionary = elemental_intensities(next_state)
	intensities[element_id] = after_value
	next_state["elemental_intensity"] = intensities
	var spent_total: Dictionary = elemental_intensity_counter(next_state, "elemental_intensity_spent_total")
	spent_total[element_id] = int(spent_total.get(element_id, 0)) + spent
	next_state["elemental_intensity_spent_total"] = spent_total
	_log(next_state, "%s intensity is spent by %d." % [ElementData.name(element_id), spent])
	return next_state

func _action_intensity_element(action: Dictionary) -> String:
	var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
	return element_id if ElementData.is_elemental(element_id) else ElementData.NONE

func _action_intensity_requirement(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("requires_intensity", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var requirement: Dictionary = raw as Dictionary
	var element_id: String = str(requirement.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(requirement.get("amount", requirement.get("threshold", 0)))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	return {
		"element": element_id,
		"amount": threshold
	}

func _action_intensity_bonus(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("intensity_bonus", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var bonus: Dictionary = (raw as Dictionary).duplicate(true)
	var element_id: String = str(bonus.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(bonus.get("threshold", bonus.get("amount", bonus.get("requires", 0))))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	bonus["element"] = element_id
	bonus["threshold"] = threshold
	return bonus

func _action_intensity_bonus_requirement(action: Dictionary) -> Dictionary:
	var bonus: Dictionary = _action_intensity_bonus(action)
	if bonus.is_empty():
		return {}
	return {
		"element": str(bonus.get("element", ElementData.NONE)),
		"amount": int(bonus.get("threshold", 0))
	}

func _action_with_intensity_bonus(state: Dictionary, action: Dictionary) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	resolved_action.erase("intensity_bonus")
	var bonus: Dictionary = _action_intensity_bonus(action)
	if not bonus.is_empty():
		var element_id: String = str(bonus.get("element", ElementData.NONE))
		if condition_intensity(state, element_id) >= int(bonus.get("threshold", 0)):
			for field: String in INTENSITY_BONUS_ADDITIVE_FIELDS:
				if not bonus.has(field):
					continue
				resolved_action[field] = int(resolved_action.get(field, 0)) + int(bonus.get(field, 0))
			if bool(bonus.get("pierce", false)):
				resolved_action["pierce"] = true
			if bool(bonus.get("immobilize", false)):
				resolved_action["immobilize"] = true
	return _action_with_player_state_relic_modifiers(state, resolved_action)

func _action_with_player_state_relic_modifiers(state: Dictionary, action: Dictionary) -> Dictionary:
	if bool(action.get("_player_state_relic_modifiers_applied", false)):
		return action
	var resolved_action: Dictionary = action.duplicate(true)
	resolved_action["_player_state_relic_modifiers_applied"] = true
	if not action.has("_card_action_types"):
		return resolved_action
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) != "player_state_action_mod":
			continue
		if not _relic_player_state_condition_met(state, effect):
			continue
		var action_types: Array = effect.get("action_types", [])
		if not action_types.is_empty() and not action_types.has(str(action.get("type", ""))):
			continue
		var field: String = str(effect.get("field", ""))
		if field.is_empty():
			continue
		if typeof(effect.get("value", null)) == TYPE_BOOL:
			resolved_action[field] = bool(effect.get("value", false))
		else:
			resolved_action[field] = int(resolved_action.get(field, 0)) + GameData.scaled_action_field_delta(
				str(action.get("type", "")),
				field,
				int(effect.get("amount", effect.get("value", 0)))
			)
	return resolved_action

func _relic_player_state_condition_met(state: Dictionary, effect: Dictionary) -> bool:
	var player: Dictionary = _normalized_player(state.get("player", {}))
	if effect.has("player_min_block") and int(player.get("block", 0)) < GameData.fixed_point_amount(int(effect.get("player_min_block", 0))):
		return false
	if effect.has("player_min_stoneskin") and int(player.get("stoneskin", 0)) < GameData.fixed_point_amount(int(effect.get("player_min_stoneskin", 0))):
		return false
	if effect.has("player_max_block") and int(player.get("block", 0)) > GameData.fixed_point_amount(int(effect.get("player_max_block", 0))):
		return false
	if effect.has("player_max_stoneskin") and int(player.get("stoneskin", 0)) > GameData.fixed_point_amount(int(effect.get("player_max_stoneskin", 0))):
		return false
	if effect.has("player_min_illusions") and _live_illusions(state).size() < int(effect.get("player_min_illusions", 0)):
		return false
	if bool(effect.get("player_has_truesight", false)) and not _player_has_truesight(state):
		return false
	if bool(effect.get("player_in_light", false)) and not _light_source_covers_tile(state, player.get("pos", INVALID_TILE)):
		return false
	return true

func _action_with_target_state_relic_modifiers(state: Dictionary, action: Dictionary, enemy_index: int) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return resolved_action
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) != "target_state_action_mod":
			continue
		var action_types: Array = effect.get("action_types", []) as Array
		if not action_types.is_empty() and not action_types.has(str(action.get("type", ""))):
			continue
		if bool(effect.get("target_in_light", false)):
			var target_lit: bool = false
			for tile: Vector2i in _enemy_footprint_tiles(enemy):
				if _light_source_covers_tile(state, tile):
					target_lit = true
					break
			if not target_lit:
				continue
		var target_status: String = str(effect.get("target_status", ""))
		if not target_status.is_empty() and _unit_status_amount(enemy, target_status) <= 0:
			continue
		var field: String = str(effect.get("field", ""))
		if field.is_empty():
			continue
		if typeof(effect.get("value", null)) == TYPE_BOOL:
			resolved_action[field] = bool(effect.get("value", false))
		else:
			resolved_action[field] = int(resolved_action.get(field, 0)) + GameData.scaled_action_field_delta(
				str(action.get("type", "")),
				field,
				int(effect.get("amount", effect.get("value", 0)))
			)
	return resolved_action

func _action_with_light_target_skill_modifier(state: Dictionary, action: Dictionary, enemy_index: int) -> Dictionary:
	var resolved_action: Dictionary = action.duplicate(true)
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("light_target_expose")
	if skill_id.is_empty() or not has_skill(state, skill_id):
		return resolved_action
	var flag_key: String = "skill_turn:%s" % skill_id
	if _turn_flag(state, flag_key):
		return resolved_action
	var effect: Dictionary = SkillTreeLibrary.effect(skill_id)
	var action_types: Array = effect.get("action_types", ["melee", "ranged", "push", "pull"]) as Array
	if not action_types.has(str(action.get("type", ""))):
		return resolved_action
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return resolved_action
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var target_lit: bool = false
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		if _light_source_covers_tile(state, tile):
			target_lit = true
			break
	if not target_lit:
		return resolved_action
	resolved_action["expose"] = int(resolved_action.get("expose", 0)) + maxi(1, int(effect.get("amount", 1)))
	resolved_action["_light_target_skill_id"] = skill_id
	return resolved_action

func _mark_light_target_skill_trigger(state: Dictionary, action: Dictionary) -> void:
	var skill_id: String = str(action.get("_light_target_skill_id", ""))
	if skill_id.is_empty():
		return
	var flag_key: String = "skill_turn:%s" % skill_id
	if _turn_flag(state, flag_key):
		return
	_set_turn_flag(state, flag_key, true)
	_record_skill_event(state, skill_id, "%s exposes a foe in Light." % SkillTreeLibrary.display_name(skill_id))

func _trigger_resolved_action_light(
	state: Dictionary,
	action: Dictionary,
	target_tile: Vector2i,
	affected_enemy_indices: Array
) -> Dictionary:
	var next_state: Dictionary = _apply_authored_attack_light_rider(state, action, target_tile)
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "resolved_action_light":
			continue
		if str(effect.get("position_mode", "target")) == "path":
			continue
		if not _resolved_action_matches_light_effect(next_state, action, effect):
			continue
		if not _relic_once_available(next_state, effect, "resolved_action_light", ""):
			continue
		var positions: Array[Vector2i] = _vector2i_values([])
		match str(effect.get("position_mode", "target")):
			"affected_enemies":
				var enemies: Array = next_state.get("enemies", [])
				for enemy_index_var: Variant in affected_enemy_indices:
					var enemy_index: int = int(enemy_index_var)
					if enemy_index < 0 or enemy_index >= enemies.size():
						continue
					var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
					var enemy_pos: Vector2i = enemy.get("pos", INVALID_TILE)
					if enemy_pos != INVALID_TILE and not positions.has(enemy_pos):
						positions.append(enemy_pos)
			_:
				if target_tile != INVALID_TILE and target_tile.x >= 0:
					positions.append(target_tile)
		if positions.is_empty():
			continue
		_mark_relic_once(next_state, effect, "resolved_action_light", "")
		for position: Vector2i in positions:
			next_state = _create_umbra_light_source(next_state, position, {
				"radius": int(effect.get("radius", 1)),
				"duration": int(effect.get("duration", 2)),
				"silent": true
			})
		_log(next_state, "%s leaves Light behind." % _relic_effect_source_name(effect))
	return next_state

func _apply_authored_attack_light_rider(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	if not _action_has_illuminate_rider(action) or target_tile == INVALID_TILE or target_tile.x < 0:
		return state
	return _create_umbra_light_source(state, target_tile, {
		"radius": int(action.get("illuminate_radius", 1)),
		"duration": int(action.get("illuminate_duration", 1)),
		"silent": true
	})

func _resolved_action_matches_light_effect(state: Dictionary, action: Dictionary, effect: Dictionary) -> bool:
	var action_types: Array = effect.get("action_types", []) as Array
	if not action_types.is_empty() and not action_types.has(str(action.get("type", ""))):
		return false
	var card_action_types: Array[String] = _action_card_types(action)
	for excluded_type_var: Variant in effect.get("excludes_card_action_types", []):
		if card_action_types.has(str(excluded_type_var)):
			return false
	var required_field: String = str(effect.get("requires_field", ""))
	if not required_field.is_empty() and not _action_has_positive_field(action, required_field):
		return false
	var any_fields: Array = effect.get("requires_any_fields", []) as Array
	if not any_fields.is_empty():
		var matches_any_field: bool = false
		for field_var: Variant in any_fields:
			if _action_has_positive_field(action, str(field_var)):
				matches_any_field = true
				break
		if not matches_any_field:
			return false
	if bool(effect.get("player_has_truesight", false)) and not _player_has_truesight(state):
		return false
	return true

func _action_has_positive_field(action: Dictionary, field: String) -> bool:
	var value: Variant = action.get(field, null)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and int(value) > 0

func _action_card_types(action: Dictionary) -> Array[String]:
	var result: Array[String]
	for action_type_var: Variant in action.get("_card_action_types", []):
		var action_type: String = str(action_type_var)
		if not action_type.is_empty() and not result.has(action_type):
			result.append(action_type)
	return result

func _action_matches_relic_card_groups(action: Dictionary, effect: Dictionary) -> bool:
	var card_action_types: Array[String] = _action_card_types(action)
	if card_action_types.is_empty():
		return false
	for group_var: Variant in effect.get("requires_any_action_type_groups", []):
		if typeof(group_var) != TYPE_ARRAY or not _action_types_include_any(card_action_types, group_var as Array):
			return false
	return true

func _intensity_bonus_damage_modifiers_for_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var bonus: Dictionary = _action_intensity_bonus(action)
	if bonus.is_empty() or int(bonus.get("damage", 0)) == 0:
		return modifiers
	var element_id: String = str(bonus.get("element", ElementData.NONE))
	var threshold: int = int(bonus.get("threshold", 0))
	if condition_intensity(state, element_id) < threshold:
		return modifiers
	modifiers.append({
		"source": "%s Intensity" % ElementData.name(element_id),
		"kind": "elemental_intensity",
		"amount": int(bonus.get("damage", 0)),
		"detail": "%s %d+" % [ElementData.name(element_id), threshold]
	})
	return modifiers

func _apply_action_keywords_to_enemy(state: Dictionary, enemy_index: int, action: Dictionary, source_pos: Vector2i, trigger_player_relics: bool = true) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return next_state
	var triggered_statuses: Array[String] = []
	if int(action.get("burn", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "burn"):
		enemy["burn"] = int(enemy.get("burn", 0)) + int(action.get("burn", 0))
		triggered_statuses.append("burn")
	if int(action.get("bleed", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "bleed"):
		enemy["bleed"] = int(enemy.get("bleed", 0)) + int(action.get("bleed", 0))
		triggered_statuses.append("bleed")
	if int(action.get("expose", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "expose"):
		enemy["expose"] = maxi(int(enemy.get("expose", 0)), int(action.get("expose", 0)))
		triggered_statuses.append("expose")
	if int(action.get("freeze", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "freeze"):
		var before_freeze: int = int(enemy.get("freeze", 0))
		enemy["freeze"] = maxi(int(enemy.get("freeze", 0)), int(action.get("freeze", 0)))
		if int(enemy.get("freeze", 0)) > before_freeze:
			triggered_statuses.append("freeze")
	if int(action.get("shock", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "shock"):
		var before_shock: int = int(enemy.get("shock", 0))
		enemy["shock"] = maxi(int(enemy.get("shock", 0)), int(action.get("shock", 0)))
		if int(enemy.get("shock", 0)) > before_shock:
			triggered_statuses.append("shock")
	if _action_applies_immobilize(action) and not _enemy_is_immune_to_status(enemy, "immobilize"):
		var before_immobilize: bool = bool(enemy.get("immobilize", false))
		enemy["immobilize"] = true
		if not before_immobilize:
			triggered_statuses.append("immobilize")
	if int(action.get("poison", 0)) > 0 and not _enemy_is_immune_to_status(enemy, "poison"):
		var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(action.get("poison", 0))
		poison["delay"] = 2
		enemy["poison"] = poison
		triggered_statuses.append("poison")
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	if trigger_player_relics:
		for status_id: String in triggered_statuses:
			next_state = _trigger_status_relics(next_state, status_id, action)
	if int(action.get("push", 0)) > 0:
		var push_direction: Vector2i = _action_force_direction(action)
		if push_direction != Vector2i.ZERO and _forced_direction_can_move_enemy(next_state, enemy_index, push_direction, source_pos, true):
			next_state = _move_enemy_in_direction(next_state, enemy_index, push_direction, int(action.get("push", 0)), trigger_player_relics)
		elif push_direction == Vector2i.ZERO:
			next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("push", 0)), true, trigger_player_relics)
	elif int(action.get("pull", 0)) > 0:
		var pull_direction: Vector2i = _action_force_direction(action)
		if pull_direction != Vector2i.ZERO and _forced_direction_can_move_enemy(next_state, enemy_index, pull_direction, source_pos, false):
			next_state = _move_enemy_in_direction(next_state, enemy_index, pull_direction, int(action.get("pull", 0)), trigger_player_relics)
		elif pull_direction == Vector2i.ZERO:
			next_state = _move_enemy_from_source(next_state, enemy_index, source_pos, int(action.get("pull", 0)), false, trigger_player_relics)
	return next_state

func _apply_action_keywords_to_player(state: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(action.get("burn", 0)) > 0:
		player["burn"] = int(player.get("burn", 0)) + int(action.get("burn", 0))
	if int(action.get("bleed", 0)) > 0:
		player["bleed"] = int(player.get("bleed", 0)) + int(action.get("bleed", 0))
	if int(action.get("expose", 0)) > 0:
		player["expose"] = maxi(int(player.get("expose", 0)), int(action.get("expose", 0)))
	if int(action.get("freeze", 0)) > 0:
		player["freeze"] = maxi(int(player.get("freeze", 0)), int(action.get("freeze", 0)))
	if int(action.get("shock", 0)) > 0:
		player["shock"] = maxi(int(player.get("shock", 0)), int(action.get("shock", 0)))
	if _action_applies_immobilize(action):
		player["immobilize"] = true
	if int(action.get("poison", 0)) > 0:
		var poison: Dictionary = player.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(action.get("poison", 0))
		poison["delay"] = 2
		player["poison"] = poison
	next_state["player"] = player
	if int(action.get("push", 0)) > 0:
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("push", 0)), true)
	elif int(action.get("pull", 0)) > 0:
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("pull", 0)), false)
	return next_state

func _apply_chain_from_enemy(state: Dictionary, initial_enemy_index: int, action: Dictionary, damage: int, affected_enemy_indices: Array[int], presentation_trace: Dictionary = {}) -> Dictionary:
	var max_distance: int = int(action.get("chain", 0))
	if max_distance <= 0:
		return state
	var next_state: Dictionary = state
	var visited: Dictionary = {}
	var current_index: int = initial_enemy_index
	visited[current_index] = true
	while true:
		var current_enemy: Dictionary = _normalized_enemy(((next_state.get("enemies", []) as Array)[current_index] as Dictionary))
		var next_index: int = _nearest_chain_target(next_state, current_enemy.get("pos", Vector2i.ZERO), visited, max_distance)
		if next_index < 0:
			break
		visited[next_index] = true
		if not affected_enemy_indices.has(next_index):
			affected_enemy_indices.append(next_index)
		var target_enemy: Dictionary = (next_state.get("enemies", []) as Array)[next_index] as Dictionary
		var target_tile: Vector2i = target_enemy.get("pos", Vector2i.ZERO)
		next_state = _sunder_enemy_defense(next_state, next_index, int(action.get("sunder", 0)))
		next_state = _damage_enemy(next_state, next_index, damage, true, _action_pierces_defense(action))
		if damage > 0:
			next_state = _consume_enemy_expose(next_state, next_index)
		next_state = _apply_action_keywords_to_enemy(next_state, next_index, action, current_enemy.get("pos", Vector2i.ZERO))
		_append_chain_presentation_hit(presentation_trace, next_state, next_index, current_enemy.get("pos", Vector2i.ZERO), target_tile)
		current_index = next_index
	return next_state

func _append_chain_presentation_hit(trace: Dictionary, state: Dictionary, enemy_index: int, from_tile: Vector2i, to_tile: Vector2i) -> void:
	if not trace.has("chain_hits"):
		return
	var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index] as Dictionary
	(trace["chain_hits"] as Array).append({
		"enemy_id": int(enemy.get("id", -1)),
		"from": from_tile,
		"to": to_tile,
		"state": state.duplicate(true),
	})

func _nearest_chain_target(state: Dictionary, from_tile: Vector2i, visited: Dictionary, max_distance: int) -> int:
	var best_index: int = -1
	var best_distance: int = 9999
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		if visited.has(index):
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if not is_enemy_visible_to_player(state, enemy):
			continue
		var distance: int = PathUtils.manhattan(from_tile, enemy.get("pos", Vector2i.ZERO))
		if distance > max_distance:
			continue
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _enemy_attack_target(state: Dictionary, enemy_index: int, action: Dictionary, verb: String, rng: RandomNumberGenerator = null, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var action_type: String = str(action.get("type", ""))
	var has_plan: bool = int(action_context.get("action_index", -1)) == int(action_context.get("attack_action_index", -2))
	var target: Dictionary = _current_actor_target_for_plan(next_state, action_context) if has_plan else _closest_enemy_target_for_action(next_state, enemy, action, rng)
	if not target.is_empty() and not _enemy_action_reaches_target(next_state, enemy, action, target):
		target = {}
	var planned_trap_index: int = _trap_index_at_tile(next_state, action_context.get("trap_attack_tile", INVALID_TILE)) if has_plan else -1
	if planned_trap_index >= 0:
		next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
		if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
			return next_state
		enemies = next_state.get("enemies", [])
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		next_state = _trigger_trap_at_index(next_state, planned_trap_index)
		_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		return next_state
	if target.is_empty():
		var trap_attack_index: int = -1 if has_plan else _best_enemy_trap_attack_index(next_state, enemy_index, action)
		if trap_attack_index >= 0:
			next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
			if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
				return next_state
			enemies = next_state.get("enemies", [])
			enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
			next_state = _trigger_trap_at_index(next_state, trap_attack_index)
			_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
			return next_state
		var terrain_override: int = int(action_context.get("blocking_terrain_index", -1)) if has_plan else -2
		return _enemy_attack_blocking_terrain(next_state, enemy_index, action, bleed_steps, terrain_override)
	var damage: int = int(action.get("damage", 0))
	if action_type == "aoe":
		var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target.get("pos", Vector2i.ZERO))
		if int(action.get("range", 0)) > 0:
			center = target.get("pos", Vector2i.ZERO)
		var affected_tiles: Array[Vector2i] = _enemy_aoe_tiles_for_target(next_state, enemy, resolved_action, center, true)
		var affected_targets: Array[Dictionary] = _actor_targets_in_tiles(next_state, affected_tiles)
		var affected_terrain: Array[int] = _terrain_indices_in_tiles(next_state, affected_tiles)
		if affected_targets.is_empty() and affected_terrain.is_empty():
			return next_state
		next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
		if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
			return next_state
		enemies = next_state.get("enemies", [])
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		next_state = _damage_enemy_aoe_occupants(next_state, enemy_index, action, affected_tiles)
	else:
		next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
		if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
			return next_state
		enemies = next_state.get("enemies", [])
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if damage > 0:
			next_state = _damage_actor_target(next_state, target, damage, _action_pierces_defense(action), action)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	_log(next_state, "%s %s for %d." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		verb,
		damage
	])
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	return next_state

func _damage_enemy_aoe_occupants(state: Dictionary, enemy_index: int, action: Dictionary, affected_tiles: Array[Vector2i]) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var damage: int = int(action.get("damage", 0))
	for affected_target: Dictionary in _actor_targets_in_tiles(next_state, affected_tiles):
		if damage > 0:
			next_state = _damage_actor_target(next_state, affected_target, damage, _action_pierces_defense(action), action)
		next_state = _apply_action_keywords_to_target(next_state, affected_target, action, _closest_enemy_tile_to(enemy, affected_target.get("pos", Vector2i.ZERO)))
	return _damage_terrain_indices(next_state, _terrain_indices_in_tiles(next_state, affected_tiles), damage)

func _enemy_push_or_pull_target(state: Dictionary, enemy_index: int, action: Dictionary, pushing: bool, rng: RandomNumberGenerator = null, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var has_plan: bool = int(action_context.get("action_index", -1)) == int(action_context.get("attack_action_index", -2))
	var target: Dictionary = _current_actor_target_for_plan(next_state, action_context) if has_plan else _closest_enemy_target_for_action(next_state, enemy, action, rng)
	if not target.is_empty() and not _enemy_action_reaches_target(next_state, enemy, action, target):
		target = {}
	var planned_trap_index: int = _trap_index_at_tile(next_state, action_context.get("trap_attack_tile", INVALID_TILE)) if has_plan else -1
	if planned_trap_index >= 0:
		next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
		if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
			return next_state
		enemies = next_state.get("enemies", [])
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		next_state = _trigger_trap_at_index(next_state, planned_trap_index)
		_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
		return next_state
	if target.is_empty():
		var trap_attack_index: int = -1 if has_plan else _best_enemy_trap_attack_index(next_state, enemy_index, action)
		if trap_attack_index >= 0:
			next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
			if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
				return next_state
			enemies = next_state.get("enemies", [])
			enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
			next_state = _trigger_trap_at_index(next_state, trap_attack_index)
			_log(next_state, "%s triggers a trap." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
			return next_state
		var terrain_override: int = int(action_context.get("blocking_terrain_index", -1)) if has_plan else -2
		return _enemy_attack_blocking_terrain(next_state, enemy_index, action, bleed_steps, terrain_override)
	var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, target_pos)
	var damage: int = int(action.get("damage", 0))
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	enemies = next_state.get("enemies", [])
	enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if damage > 0:
		next_state = _damage_actor_target(next_state, target, damage, _action_pierces_defense(action), action)
	if str(target.get("kind", "")) == "player":
		next_state = _move_player_from_source(next_state, source_pos, int(action.get("amount", 0)), pushing)
	next_state = _apply_action_keywords_to_target(next_state, target, action, source_pos)
	next_state = _apply_enemy_self_damage(next_state, enemy_index, int(action.get("self_damage", 0)))
	_log(next_state, "%s %s." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		"batters the line" if pushing else "drags inward"
	])
	return next_state

func _enemy_attack_blocking_terrain(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary] = [], terrain_index_override: int = -2) -> Dictionary:
	var next_state: Dictionary = state
	if int(action.get("damage", 0)) <= 0:
		return next_state
	var terrain_index: int = terrain_index_override if terrain_index_override >= -1 else _blocking_terrain_index_for_enemy_action(next_state, enemy_index, action)
	if terrain_index < 0:
		return next_state
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	var damage: int = int(action.get("damage", 0))
	var enemies: Array = next_state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if str(action.get("type", "")) == "aoe":
		var terrain_entries: Array = next_state.get("terrain", [])
		var blocking_terrain: Dictionary = _normalized_terrain(terrain_entries[terrain_index])
		var blocking_tile: Vector2i = blocking_terrain.get("pos", Vector2i.ZERO)
		var center: Vector2i = blocking_tile if int(action.get("range", 0)) > 0 else enemy.get("pos", Vector2i.ZERO)
		var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, blocking_tile)
		var affected_tiles: Array[Vector2i] = _enemy_aoe_tiles_for_target(next_state, enemy, resolved_action, center, true)
		next_state = _damage_enemy_aoe_occupants(next_state, enemy_index, action, affected_tiles)
	else:
		next_state = _damage_terrain(next_state, terrain_index, damage)
	_log(next_state, "%s breaks through terrain for %d." % [
		str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
		damage
	])
	return next_state

func _blocking_terrain_index_for_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary) -> int:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return -1
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _enemy_blocking_tiles_without_terrain(state, int(enemy.get("id", -1)))
	var start: Vector2i = _closest_enemy_tile_to(enemy, player_pos)
	var path: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), start, player_pos, occupied, true)
	if path.is_empty():
		return -1
	for step_index: int in range(1, path.size()):
		var tile: Vector2i = path[step_index]
		var terrain_index: int = _terrain_index_at_tile(state, tile)
		if terrain_index < 0:
			continue
		if _enemy_action_reaches_tile(state, enemy, action, tile):
			return terrain_index
		return -1
	return -1

func _enemy_lightning_strikes(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary] = []) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var strike_tiles: Array[Vector2i] = _lightning_strike_tiles(next_state, enemy, action)
	var targets: Array[Dictionary] = _actor_targets_in_tiles(next_state, strike_tiles)
	var affected_terrain: Array[int] = _terrain_indices_in_tiles(next_state, strike_tiles)
	if targets.is_empty() and affected_terrain.is_empty():
		return next_state
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	enemies = next_state.get("enemies", [])
	enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
	for target: Dictionary in targets:
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), _action_pierces_defense(action), action)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	next_state = _damage_terrain_indices(next_state, affected_terrain, int(action.get("damage", 0)))
	_log(next_state, "%s calls down the storm." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _enemy_summon_minions(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var minion_type: String = str(action.get("minion_type", LIGHTNING_WISP_TYPE))
	var count: int = int(action.get("count", 2))
	var spawn_tiles: Array[Vector2i] = _summon_tiles_for_enemy(next_state, enemy, count)
	var first_minion_index: int = enemies.size()
	var next_id: int = _next_enemy_id(next_state)
	for tile: Vector2i in spawn_tiles:
		var minion_max_hp: int = _scaled_enemy_max_hp(minion_type, int(next_state.get("room_depth", 1)))
		var minion: Dictionary = {
			"id": next_id,
			"type": minion_type,
			"summoned": true,
			"element": str(next_state.get("room_element", ElementData.NONE)),
			"pos": tile,
			"hp": minion_max_hp,
			"max_hp": minion_max_hp,
			"block": 0,
			"stoneskin": 0
		}
		enemies.append(minion)
		next_id += 1
	next_state["enemies"] = enemies
	var intent_rng: RandomNumberGenerator = rng
	if intent_rng == null:
		intent_rng = RandomNumberGenerator.new()
		intent_rng.state = int(next_state.get("rng_state", 1))
	for minion_index: int in range(first_minion_index, first_minion_index + spawn_tiles.size()):
		_assign_enemy_intent(next_state, minion_index, intent_rng)
	if str(enemy.get("type", "")) == ZEKARION_TYPE and not spawn_tiles.is_empty():
		next_state["zekarion_summon_waves"] = int(next_state.get("zekarion_summon_waves", 0)) + 1
	if rng == null:
		next_state["rng_state"] = intent_rng.state
	_log(next_state, "%s summons lightning wisps." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _mark_dragon_mechanic_opened(state: Dictionary, enemy_index: int) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	enemy["boss_mechanic_opened"] = true
	enemies[enemy_index] = enemy
	state["enemies"] = enemies

func _all_passable_tiles(state: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var grid: Array = state.get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			if PathUtils.is_passable(grid, tile):
				tiles.append(tile)
	return tiles

func _dragon_spires(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_var)
		if str(terrain.get("kind", "")) == DRAGON_SPIRE_KIND and int(terrain.get("hp", 0)) > 0:
			result.append(terrain)
	return result

func _dragon_spire_tiles(state: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for terrain: Dictionary in _dragon_spires(state):
		tiles.append(terrain.get("pos", Vector2i.ZERO))
	return tiles

func _enemy_raise_dragon_spires(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var candidates: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 5), Vector2i(6, 5),
		Vector2i(3, 6), Vector2i(5, 6), Vector2i(2, 4), Vector2i(6, 4)
	]
	var occupied: Dictionary = _occupied_actor_tiles(next_state)
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var terrain_entries: Array = next_state.get("terrain", []).duplicate(true)
	var count: int = maxi(1, int(action.get("count", 4)))
	var health: int = maxi(1, int(action.get("health", GameData.fixed_point_amount(6))))
	var raised: int = 0
	var start_index: int = posmod(int(next_state.get("turn", 1)) + int(enemy.get("id", 0)), candidates.size())
	for offset: int in range(candidates.size()):
		var tile: Vector2i = candidates[posmod(start_index + offset, candidates.size())]
		if not PathUtils.is_passable(next_state.get("grid", []), tile):
			continue
		if occupied.has(tile) or _terrain_index_at_tile(next_state, tile) >= 0 or _trap_index_at_tile(next_state, tile) >= 0:
			continue
		if PathUtils.manhattan(player_pos, tile) <= 1:
			continue
		terrain_entries.append({
			"id": "dragon_spire_%d_%d_%d" % [int(enemy.get("id", 0)), int(next_state.get("turn", 1)), raised],
			"kind": DRAGON_SPIRE_KIND,
			"pos": tile,
			"hp": health,
			"max_hp": health,
			"boss_created": true
		})
		next_state["terrain"] = terrain_entries
		raised += 1
		if raised >= count:
			break
	if raised > 0:
		_mark_dragon_mechanic_opened(next_state, enemy_index)
		_log(next_state, "%s raises %d Worldspine%s." % [_enemy_display_name(enemy), raised, "s" if raised != 1 else ""])
	return next_state

func _terrain_burst_tiles(state: Dictionary, radius: int) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for spire_tile: Vector2i in _dragon_spire_tiles(state):
		for tile: Vector2i in PathUtils.diamond_tiles(spire_tile, maxi(1, radius), state.get("grid", [])):
			if PathUtils.is_passable(state.get("grid", []), tile):
				lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _enemy_terrain_burst(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var spire_tiles: Array[Vector2i] = _dragon_spire_tiles(next_state)
	if spire_tiles.is_empty():
		return next_state
	var affected_tiles: Array[Vector2i] = _terrain_burst_tiles(next_state, int(action.get("radius", 1)))
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	for target: Dictionary in _actor_targets_in_tiles(next_state, affected_tiles):
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), _action_pierces_defense(action), action)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	for terrain_index: int in _terrain_indices_in_tiles(next_state, spire_tiles):
		var terrain: Dictionary = _normalized_terrain((next_state.get("terrain", []) as Array)[terrain_index])
		next_state = _damage_terrain(next_state, terrain_index, int(terrain.get("hp", 0)))
	_mark_dragon_mechanic_opened(next_state, enemy_index)
	_log(next_state, "%s ruptures the Worldspines." % _enemy_display_name(enemy))
	return next_state

func _cinder_mark_traps(state: Dictionary, owner_enemy_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var as Dictionary
		if str(trap.get("boss_hazard_kind", "")) != CINDER_MARK_KIND:
			continue
		if owner_enemy_id >= 0 and int(trap.get("owner_enemy_id", -1)) != owner_enemy_id:
			continue
		result.append(trap.duplicate(true))
	return result

func _cinder_mark_candidate_tiles(state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _occupied_actor_tiles(state)
	for tile: Vector2i in _all_passable_tiles(state):
		var distance: int = PathUtils.manhattan(player_pos, tile)
		if distance < 1 or distance > 4:
			continue
		if occupied.has(tile) or _terrain_index_at_tile(state, tile) >= 0 or _trap_index_at_tile(state, tile) >= 0:
			continue
		candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score: int = PathUtils.manhattan(player_pos, a) * 100 + posmod(a.x * 31 + a.y * 17 + int(enemy.get("id", 0)) * 13 + int(state.get("turn", 1)) * 7, 97)
		var b_score: int = PathUtils.manhattan(player_pos, b) * 100 + posmod(b.x * 31 + b.y * 17 + int(enemy.get("id", 0)) * 13 + int(state.get("turn", 1)) * 7, 97)
		if a_score == b_score:
			return a.y < b.y if a.y != b.y else a.x < b.x
		return a_score < b_score
	)
	var results: Array[Vector2i] = []
	for tile: Vector2i in candidates:
		results.append(tile)
		if results.size() >= count:
			break
	return results

func _enemy_create_cinder_marks(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var trap_entries: Array = next_state.get("traps", []).duplicate(true)
	var candidates: Array[Vector2i] = _cinder_mark_candidate_tiles(next_state, enemy, maxi(1, int(action.get("count", 5))))
	for index: int in range(candidates.size()):
		trap_entries.append({
			"id": "cinder_mark_%d_%d_%d" % [int(enemy.get("id", 0)), int(next_state.get("turn", 1)), index],
			"pos": candidates[index],
			"element": ElementData.FIRE,
			"damage": int(action.get("damage", 0)),
			"burn": int(action.get("burn", 0)),
			"owner_enemy_id": int(enemy.get("id", -1)),
			"boss_hazard_kind": CINDER_MARK_KIND,
			"armed": true
		})
	next_state["traps"] = trap_entries
	if not candidates.is_empty():
		enemy["cinder_detonation_pending"] = true
		enemy["boss_mechanic_opened"] = true
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		_log(next_state, "%s brands the arena with %d cinder marks." % [_enemy_display_name(enemy), candidates.size()])
	return next_state

func _cinder_detonation_tiles(state: Dictionary, owner_enemy_id: int) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for trap: Dictionary in _cinder_mark_traps(state, owner_enemy_id):
		for tile: Vector2i in _trap_blast_tiles(state, trap):
			lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _enemy_detonate_cinders(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var marks: Array[Dictionary] = _cinder_mark_traps(next_state, int(enemy.get("id", -1)))
	if marks.is_empty():
		enemy["cinder_detonation_pending"] = false
		enemies[enemy_index] = enemy
		return next_state
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	for mark: Dictionary in marks:
		var trap_index: int = _trap_index_at_tile(next_state, mark.get("pos", INVALID_TILE))
		if trap_index >= 0:
			next_state = _trigger_trap_at_index(next_state, trap_index)
	enemies = next_state.get("enemies", [])
	if enemy_index < enemies.size():
		enemy = _normalized_enemy(enemies[enemy_index] as Dictionary)
		enemy["cinder_detonation_pending"] = false
		enemy["boss_mechanic_opened"] = true
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
	_log(next_state, "%s detonates every surviving cinder mark." % _enemy_display_name(enemy))
	return next_state

func _enemy_gale_force(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	for target: Dictionary in _actor_targets(next_state):
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), _action_pierces_defense(action), action)
		next_state = _apply_action_keywords_to_target(next_state, target, action, _closest_enemy_tile_to(enemy, target.get("pos", Vector2i.ZERO)))
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	next_state = _move_player_from_source(next_state, _closest_enemy_tile_to(enemy, player_pos), int(action.get("amount", 3)), true)
	_mark_dragon_mechanic_opened(next_state, enemy_index)
	_log(next_state, "%s unleashes the Hollow Gale." % _enemy_display_name(enemy))
	return next_state

func _enemy_gain_frost_armor(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var maximum: int = maxi(1, int(action.get("maximum", 3)))
	enemy["frost_armor"] = mini(maximum, int(enemy.get("frost_armor", 0)) + maxi(1, int(action.get("amount", 2))))
	enemy["boss_mechanic_opened"] = true
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	_log(next_state, "%s forms %d layers of crystal armor." % [_enemy_display_name(enemy), int(enemy.get("frost_armor", 0))])
	return next_state

func _light_source_covers_tile(state: Dictionary, tile: Vector2i) -> bool:
	for source: Dictionary in _effective_light_sources(state):
		if PathUtils.manhattan(source.get("pos", INVALID_TILE), tile) <= maxi(0, int(source.get("radius", 0))):
			return true
	return false

func _actor_has_radiance_protection(state: Dictionary, target: Dictionary) -> bool:
	var tile: Vector2i = target.get("pos", INVALID_TILE)
	if _light_source_covers_tile(state, tile):
		return true
	if str(target.get("kind", "")) != "player":
		return false
	var umbra: Dictionary = state.get("umbra", {}) as Dictionary
	return int(umbra.get("vision_bonus", 0)) > 0 or _player_has_truesight(state) or int(umbra.get("stage_reduction", 0)) > 0

func _umbra_eclipse_threat_tiles(state: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for tile: Vector2i in _all_passable_tiles(state):
		if not _light_source_covers_tile(state, tile):
			lookup[tile] = true
	var player: Dictionary = _normalized_player(state.get("player", {}))
	if _actor_has_radiance_protection(state, {"kind": "player", "pos": player.get("pos", INVALID_TILE)}):
		lookup.erase(player.get("pos", INVALID_TILE))
	return _sorted_tiles_from_lookup(lookup)

func _enemy_umbra_eclipse(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var exposed_targets: Array[Dictionary] = []
	for target: Dictionary in _actor_targets(next_state):
		if not _actor_has_radiance_protection(next_state, target):
			exposed_targets.append(target)
	next_state = _trigger_enemy_bleed_for_resolved_action(next_state, enemy_index, action, bleed_steps)
	if _enemy_cannot_continue_after_bleed(next_state, enemy_index):
		return next_state
	var umbra: Dictionary = (next_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["boss_eclipse_stage"] = UMBRA_STAGE_ECLIPSE
	umbra["boss_eclipse_activations"] = maxi(1, int(action.get("duration", 2)))
	next_state["umbra"] = umbra
	for target: Dictionary in exposed_targets:
		next_state = _damage_actor_target(next_state, target, int(action.get("damage", 0)), _action_pierces_defense(action), action)
	_mark_dragon_mechanic_opened(next_state, enemy_index)
	_log(next_state, "%s swallows the arena in the Last Eclipse." % _enemy_display_name(enemy))
	return next_state

func _boss_action_threat_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	match str(action.get("type", "")):
		"terrain_burst":
			return _terrain_burst_tiles(state, int(action.get("radius", 1)))
		"cinder_marks":
			return _cinder_mark_candidate_tiles(state, enemy, maxi(1, int(action.get("count", 5))))
		"detonate_cinders":
			return _cinder_detonation_tiles(state, int(enemy.get("id", -1)))
		"gale_force":
			return _all_passable_tiles(state)
		"umbra_eclipse":
			return _umbra_eclipse_threat_tiles(state)
	return []

func _push_or_pull_target(state: Dictionary, action: Dictionary, target_tile: Vector2i, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state
	var resolved_action: Dictionary = _action_with_intensity_bonus(next_state, action)
	var trap_index: int = _trap_index_at_tile(next_state, target_tile)
	if trap_index >= 0:
		next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
		if combat_outcome(next_state) == "defeat":
			return next_state
		if int(resolved_action.get("damage", 0)) > 0:
			_mark_first_attack_used(next_state)
		next_state = _trigger_player_trap_at_index(next_state, trap_index)
		next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([]))
		_log(next_state, "%s triggers a trap." % ("Push" if pushing else "Pull"))
		return next_state
	var terrain_index: int = _terrain_index_at_tile(next_state, target_tile)
	if terrain_index >= 0:
		var terrain_damage: int = final_damage_for_player_action(next_state, resolved_action)
		if terrain_damage > 0:
			next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
			if combat_outcome(next_state) == "defeat":
				return next_state
			if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
				_mark_first_attack_used(next_state)
			next_state = _damage_terrain(next_state, terrain_index, terrain_damage)
			next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([]))
			_log(next_state, "%s splinters terrain for %d." % ["Push" if pushing else "Pull", terrain_damage])
		return next_state
	var enemy_index: int = _enemy_index_at_tile(next_state, target_tile)
	if enemy_index < 0:
		return next_state
	resolved_action = _action_with_target_state_relic_modifiers(next_state, resolved_action, enemy_index)
	resolved_action = _action_with_light_target_skill_modifier(next_state, resolved_action, enemy_index)
	next_state = _trigger_player_bleed_for_action(next_state, resolved_action)
	if combat_outcome(next_state) == "defeat":
		return next_state
	next_state = _sunder_enemy_defense(next_state, enemy_index, int(resolved_action.get("sunder", 0)))
	var damage: int = _damage_for_enemy_target(next_state, resolved_action, enemy_index)
	if _attack_bonus_for_current_turn(next_state) > 0 and int(resolved_action.get("damage", 0)) > 0:
		_mark_first_attack_used(next_state)
	if damage > 0:
		next_state = _damage_enemy(next_state, enemy_index, damage, true, _action_pierces_defense(resolved_action))
		next_state = _consume_enemy_expose(next_state, enemy_index)
	if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
		next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([enemy_index]))
		_mark_light_target_skill_trigger(next_state, resolved_action)
		return next_state
	next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, resolved_action, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO))
	var force_direction: Vector2i = _action_force_direction(resolved_action)
	if force_direction != Vector2i.ZERO:
		var player_source: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		if _forced_direction_can_move_enemy(next_state, enemy_index, force_direction, player_source, pushing):
			next_state = _move_enemy_in_direction(next_state, enemy_index, force_direction, int(resolved_action.get("amount", 0)), true)
	else:
		next_state = _move_enemy_from_source(next_state, enemy_index, (next_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), int(resolved_action.get("amount", 0)), pushing, true)
	next_state = _trigger_resolved_action_light(next_state, resolved_action, target_tile, _int_values([enemy_index]))
	_mark_light_target_skill_trigger(next_state, resolved_action)
	_log(next_state, "%s %d." % ["Push" if pushing else "Pull", int(resolved_action.get("amount", 0))])
	return next_state

func _force_directions_for_enemy(state: Dictionary, enemy_index: int, source_pos: Vector2i, pushing: bool, amount: int) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	if amount <= 0:
		return directions
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		if not _forced_direction_can_move_enemy(state, enemy_index, direction, source_pos, pushing):
			continue
		directions.append(direction)
	return directions

func _forced_direction_can_move_enemy(state: Dictionary, enemy_index: int, direction: Vector2i, source_pos: Vector2i, pushing: bool) -> bool:
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO:
		return false
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return false
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		return false
	var before_distance: int = _enemy_distance_to_tile(enemy, source_pos)
	var moved_enemy: Dictionary = enemy.duplicate(true)
	moved_enemy["pos"] = enemy.get("pos", Vector2i.ZERO) + step_direction
	var after_distance: int = _enemy_distance_to_tile(moved_enemy, source_pos)
	if pushing and after_distance <= before_distance:
		return false
	if not pushing and after_distance >= before_distance:
		return false
	return not _enemy_direction_path(state, enemy_index, step_direction, 1).is_empty()

func _enemy_direction_path(state: Dictionary, enemy_index: int, direction: Vector2i, amount: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO or amount <= 0:
		return path
	var next_state: Dictionary = state.duplicate(true)
	for _step: int in range(amount):
		var enemies: Array = next_state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			break
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var candidate: Vector2i = enemy.get("pos", Vector2i.ZERO) + step_direction
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		path.append(candidate)
	return path

func _move_enemy_in_direction(state: Dictionary, enemy_index: int, direction: Vector2i, amount: int, player_triggered_traps: bool = false) -> Dictionary:
	var next_state: Dictionary = state
	var step_direction: Vector2i = _cardinal_direction(direction)
	if step_direction == Vector2i.ZERO or amount <= 0:
		return next_state
	for _step: int in range(amount):
		var enemies: Array = next_state.get("enemies", [])
		if enemy_index < 0 or enemy_index >= enemies.size():
			break
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var candidate: Vector2i = enemy.get("pos", Vector2i.ZERO) + step_direction
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		next_state = _trigger_trap_on_enemy(next_state, enemy_index, player_triggered_traps)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
			break
	return next_state

func _move_enemy_from_source(state: Dictionary, enemy_index: int, source_pos: Vector2i, amount: int, pushing: bool, player_triggered_traps: bool = false) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size() or amount <= 0:
		return next_state
	for _step: int in range(amount):
		enemies = next_state.get("enemies", [])
		var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			break
		var current: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var occupied: Dictionary = _enemy_blocking_tiles(next_state, int(enemy.get("id", -1)))
		var player_pos: Vector2i = (next_state.get("player", {}) as Dictionary).get("pos", Vector2i(-99, -99))
		var candidate: Vector2i = (
			_next_tile_away_from_source(next_state.get("grid", []), current, source_pos, occupied, player_pos)
			if pushing
			else _next_tile_toward_source(next_state.get("grid", []), current, source_pos, occupied)
		)
		if candidate == current:
			break
		if not _enemy_can_occupy_anchor(next_state, enemy, candidate, occupied, player_pos):
			break
		enemy["pos"] = candidate
		enemies[enemy_index] = enemy
		next_state["enemies"] = enemies
		next_state = _trigger_trap_on_enemy(next_state, enemy_index, player_triggered_traps)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) <= 0:
			break
	return next_state

func _move_player_from_source(state: Dictionary, source_pos: Vector2i, amount: int, pushing: bool) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	for _step: int in range(amount):
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		var current: Vector2i = player.get("pos", Vector2i.ZERO)
		var enemy_occupied: Dictionary = _player_blocking_tiles(next_state)
		var next_tile: Vector2i = (
			_next_tile_away_from_source(next_state.get("grid", []), current, source_pos, enemy_occupied, Vector2i(-99, -99))
			if pushing
			else _next_tile_toward_source(next_state.get("grid", []), current, source_pos, enemy_occupied)
		)
		if next_tile == current:
			break
		player["pos"] = next_tile
		next_state["player"] = player
		_collect_loot_at_player(next_state)
		next_state = _trigger_trap_on_player(next_state)
		if int((next_state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			break
	return _dispel_illusion_at_player(next_state)

func _move_player_along_path(state: Dictionary, path: Array[Vector2i]) -> Dictionary:
	var next_state: Dictionary = state
	if path.size() <= 1:
		return next_state
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var performance_phase_started: int = performance_total_started
	for step_index: int in range(1, path.size()):
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		player["pos"] = path[step_index]
		next_state["player"] = player
		performance_phase_started = _record_runtime_performance_phase("traverse_position", performance_phase_started)
		_collect_loot_at_player(next_state)
		performance_phase_started = _record_runtime_performance_phase("traverse_loot", performance_phase_started)
		next_state = _trigger_trap_on_player(next_state)
		performance_phase_started = _record_runtime_performance_phase("traverse_trap_total", performance_phase_started)
		if int((next_state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			break
	var result_state: Dictionary = _dispel_illusion_at_player(next_state)
	_record_runtime_performance_phase("traverse_dispel", performance_phase_started)
	_record_runtime_performance_phase("traverse_total", performance_total_started)
	return result_state

func _player_path_until_hidden_collision(
	state: Dictionary,
	path: Array[Vector2i],
	hidden_collision_tiles: Dictionary = {},
	use_hidden_collision_lookup: bool = false
) -> Array[Vector2i]:
	var resolved: Array[Vector2i] = []
	if path.is_empty():
		return resolved
	resolved.append(path[0])
	var hidden_enemy_tiles: Dictionary = hidden_collision_tiles
	if not use_hidden_collision_lookup:
		hidden_enemy_tiles = _occupied_enemy_tiles(state)
		var visible_enemy_tiles: Dictionary = _occupied_visible_enemy_tiles(state)
		for visible_tile_var: Variant in visible_enemy_tiles.keys():
			hidden_enemy_tiles.erase(visible_tile_var)
	for index: int in range(1, path.size()):
		var tile: Vector2i = path[index]
		if hidden_enemy_tiles.has(tile):
			var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
			umbra["movement_interrupted_total"] = int(umbra.get("movement_interrupted_total", 0)) + 1
			state["umbra"] = umbra
			_log(state, "Something in the Umbra blocks the way.")
			break
		resolved.append(tile)
	return resolved

func _actual_player_movement_path(state: Dictionary, start: Vector2i, goal: Vector2i, max_distance: int) -> Array[Vector2i]:
	if max_distance <= 0:
		return []
	var navigation: Dictionary = _preferred_player_navigation(
		state.get("grid", []),
		start,
		max_distance,
		_known_actor_tiles_for_player(state),
		_trap_tiles_lookup(state),
		_preferred_pickup_scores(state)
	)
	return _vector2i_values((navigation.get("paths", {}) as Dictionary).get(goal, []))

func _preferred_pickup_scores(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for loot_var: Variant in state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var as Dictionary
		if bool(loot.get("claimed", false)):
			continue
		var tile: Vector2i = loot.get("pos", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var score: int = 2
		match str(loot.get("kind", "")):
			"equipment":
				score = 8
			"dropped_embers":
				score = 5
			"item":
				score = 4
		if score > 0:
			result[tile] = score
	return result

func _preferred_player_navigation(
	grid: Array,
	start: Vector2i,
	max_distance: int,
	occupied: Dictionary,
	trap_tiles: Dictionary,
	pickup_scores: Dictionary
) -> Dictionary:
	var start_path: Array[Vector2i] = _vector2i_values([start])
	var paths: Dictionary = {start: start_path}
	var qualities: Dictionary = {start: {"traps": 0, "pickups": 0, "steps": 0}}
	if max_distance <= 0:
		return {"paths": paths, "qualities": qualities}
	var pickup_indices: Dictionary = {}
	var pickup_index: int = 0
	for pickup_tile_var: Variant in pickup_scores.keys():
		if typeof(pickup_tile_var) != TYPE_VECTOR2I:
			continue
		pickup_indices[pickup_tile_var] = pickup_index
		pickup_index += 1
	var frontier: Array = [{
		"tile": start,
		"path": start_path,
		"traps": 0,
		"pickups": 0,
		"pickup_mask": 0,
	}]
	var best_state_traps: Dictionary = {}
	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front() as Dictionary
		var current_tile: Vector2i = current.get("tile", start)
		var current_path: Array[Vector2i] = _vector2i_values(current.get("path", []))
		var current_steps: int = current_path.size() - 1
		if current_steps >= max_distance:
			continue
		for direction: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current_tile + direction
			if not PathUtils.is_passable(grid, next_tile) or occupied.has(next_tile) or current_path.has(next_tile):
				continue
			var next_path: Array[Vector2i] = current_path.duplicate()
			next_path.append(next_tile)
			var next_traps: int = int(current.get("traps", 0)) + (1 if trap_tiles.has(next_tile) else 0)
			var next_pickups: int = int(current.get("pickups", 0))
			var next_mask: int = int(current.get("pickup_mask", 0))
			if pickup_indices.has(next_tile):
				var pickup_bit: int = 1 << int(pickup_indices.get(next_tile, 0))
				if (next_mask & pickup_bit) == 0:
					next_mask |= pickup_bit
					next_pickups += int(pickup_scores.get(next_tile, 0))
			var next_steps: int = next_path.size() - 1
			var state_key: String = "%d:%d:%d:%d" % [next_tile.x, next_tile.y, next_steps, next_mask]
			if best_state_traps.has(state_key) and int(best_state_traps.get(state_key, 0)) <= next_traps:
				continue
			best_state_traps[state_key] = next_traps
			var next_quality: Dictionary = {"traps": next_traps, "pickups": next_pickups, "steps": next_steps}
			if not qualities.has(next_tile) or _player_route_quality_is_better(next_quality, qualities.get(next_tile, {}) as Dictionary):
				qualities[next_tile] = next_quality
				paths[next_tile] = next_path
			frontier.append({
				"tile": next_tile,
				"path": next_path,
				"traps": next_traps,
				"pickups": next_pickups,
				"pickup_mask": next_mask,
			})
	return {"paths": paths, "qualities": qualities}

func _player_route_quality_is_better(candidate: Dictionary, existing: Dictionary) -> bool:
	var candidate_traps: int = int(candidate.get("traps", 0))
	var existing_traps: int = int(existing.get("traps", 0))
	if candidate_traps != existing_traps:
		return candidate_traps < existing_traps
	var candidate_pickups: int = int(candidate.get("pickups", 0))
	var existing_pickups: int = int(existing.get("pickups", 0))
	if candidate_pickups != existing_pickups:
		return candidate_pickups > existing_pickups
	return int(candidate.get("steps", 0)) < int(existing.get("steps", 0))

func _trigger_trap_on_player(state: Dictionary) -> Dictionary:
	var trap_index: int = _trap_index_at_tile(state, (_normalized_player(state.get("player", {}))).get("pos", Vector2i(-1, -1)))
	if trap_index < 0:
		return state
	return _trigger_player_trap_at_index(state, trap_index)

func _trigger_player_trap_at_index(state: Dictionary, trap_index: int) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("disarm_trap")
	var traps: Array = state.get("traps", []) as Array
	var protected: bool = trap_index >= 0 and trap_index < traps.size() and _skill_charge_available(state, skill_id)
	# The player is standing on the live trap tile, which is always the center of
	# its blast. Avoid building the nine-tile blast twice merely to rediscover that
	# the charged disarm skill protects this trigger.
	var next_state: Dictionary = _trigger_trap_at_index(state, trap_index, protected, true)
	_record_runtime_performance_phase("player_trap_total", performance_total_started)
	return next_state

func _trigger_trap_on_enemy(state: Dictionary, enemy_index: int, player_triggered: bool = false) -> Dictionary:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var trap_index: int = -1
	for tile: Vector2i in _enemy_footprint_tiles(enemy):
		trap_index = _trap_index_at_tile(state, tile)
		if trap_index >= 0:
			break
	if trap_index < 0:
		return state
	return _trigger_player_trap_at_index(state, trap_index) if player_triggered else _trigger_trap_at_index(state, trap_index)

func _trigger_traps_on_tiles(state: Dictionary, trap_tiles: Array[Vector2i]) -> Dictionary:
	var next_state: Dictionary = state
	for trap_tile: Vector2i in trap_tiles:
		var trap_index: int = _trap_index_at_tile(next_state, trap_tile)
		if trap_index < 0:
			continue
		next_state = _trigger_player_trap_at_index(next_state, trap_index)
	return next_state

func _trigger_trap_at_index(state: Dictionary, trap_index: int, protect_player: bool = false, player_protection_prechecked: bool = false) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var next_state: Dictionary = state
	var traps: Array = next_state.get("traps", []).duplicate(true)
	if trap_index < 0 or trap_index >= traps.size():
		return next_state
	var trap: Dictionary = (traps[trap_index] as Dictionary).duplicate(true)
	traps.remove_at(trap_index)
	next_state["traps"] = traps
	var performance_phase_started: int = _record_runtime_performance_phase("trap_duplicate", performance_total_started)
	var blast_tiles: Array[Vector2i] = _trap_blast_tiles(next_state, trap)
	var blast_lookup: Dictionary = {}
	for tile: Vector2i in blast_tiles:
		blast_lookup[tile] = true
	var damage: int = trap_damage(next_state, trap)
	performance_phase_started = _record_runtime_performance_phase("trap_blast", performance_phase_started)
	var player_hit: bool = blast_lookup.has((_normalized_player(next_state.get("player", {}))).get("pos", Vector2i(-1, -1)))
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("disarm_trap")
	var player_protected: bool = player_hit and (
		protect_player
		or (not player_protection_prechecked and _skill_charge_available(next_state, skill_id))
	)
	if player_protected:
		_mark_skill_used(next_state, skill_id, "%s leaves you untouched by the trap blast." % SkillTreeLibrary.display_name(skill_id))
	elif player_hit:
		if damage > 0:
			next_state = _damage_player(next_state, damage, false, true, "trap")
		next_state = _apply_trap_keywords_to_player(next_state, trap)
	performance_phase_started = _record_runtime_performance_phase("trap_player", performance_phase_started)
	var illusions: Array = next_state.get("illusions", [])
	for illusion_var: Variant in illusions:
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var as Dictionary
		if int(illusion.get("hp", 0)) <= 0:
			continue
		if not blast_lookup.has(illusion.get("pos", Vector2i.ZERO)):
			continue
		next_state = _damage_illusion(next_state, int(illusion.get("id", -1)), damage)
	performance_phase_started = _record_runtime_performance_phase("trap_illusions", performance_phase_started)
	var enemies: Array = next_state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[enemy_index] as Dictionary
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if int(trap.get("owner_enemy_id", -1)) == int(enemy.get("id", -2)):
			continue
		var enemy_hit: bool = false
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if blast_lookup.has(tile):
				enemy_hit = true
				break
		if not enemy_hit:
			continue
		if damage > 0:
			next_state = _damage_enemy(next_state, enemy_index, damage)
		if int(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary).get("hp", 0)) > 0:
			next_state = _apply_action_keywords_to_enemy(next_state, enemy_index, trap, trap.get("pos", Vector2i.ZERO), false)
	performance_phase_started = _record_runtime_performance_phase("trap_enemies_total", performance_phase_started)
	next_state = _damage_terrain_indices(next_state, _terrain_indices_in_tiles(next_state, blast_tiles), damage)
	performance_phase_started = _record_runtime_performance_phase("trap_terrain", performance_phase_started)
	_log(next_state, _trap_trigger_log(next_state, trap, damage))
	_record_runtime_performance_phase("trap_log", performance_phase_started)
	_record_runtime_performance_phase("trap_total", performance_total_started)
	return next_state

func _apply_trap_keywords_to_player(state: Dictionary, trap: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(trap.get("burn", 0)) > 0:
		player["burn"] = int(player.get("burn", 0)) + int(trap.get("burn", 0))
	if int(trap.get("poison", 0)) > 0:
		var poison: Dictionary = player.get("poison", {}).duplicate(true)
		poison["damage"] = int(poison.get("damage", 0)) + int(trap.get("poison", 0))
		poison["delay"] = 2
		player["poison"] = poison
	var restriction_kind: String = _trap_action_blocker_kind(trap)
	if restriction_kind.is_empty():
		next_state["player"] = player
		return next_state
	if _player_trap_applies_this_turn(next_state):
		next_state["player"] = player
		next_state["pending_player_trap_restriction"] = _stronger_restriction(
			str(next_state.get("pending_player_trap_restriction", "")),
			restriction_kind
		)
		return next_state
	if restriction_kind == "immobilize":
		player["immobilize"] = true
	else:
		player[restriction_kind] = maxi(int(player.get(restriction_kind, 0)), int(trap.get(restriction_kind, 0)))
	next_state["player"] = player
	return next_state

func _player_trap_applies_this_turn(state: Dictionary) -> bool:
	return cards_remaining_this_turn(state) > 1

func _trap_action_blocker_kind(trap: Dictionary) -> String:
	if int(trap.get("freeze", 0)) > 0:
		return "freeze"
	if int(trap.get("shock", 0)) > 0:
		return "shock"
	if bool(trap.get("immobilize", false)):
		return "immobilize"
	return ""

func _stronger_restriction(current_kind: String, next_kind: String) -> String:
	if current_kind.is_empty():
		return next_kind
	if current_kind == "freeze":
		return current_kind
	if next_kind == "freeze":
		return next_kind
	if current_kind == "shock" and next_kind == "immobilize":
		return current_kind
	return next_kind

func _apply_pending_player_trap_restriction(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var restriction_kind: String = str(next_state.get("pending_player_trap_restriction", ""))
	if restriction_kind.is_empty():
		return next_state
	next_state["pending_player_trap_restriction"] = ""
	var restrictions: Dictionary = (next_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	match restriction_kind:
		"freeze":
			restrictions["frozen"] = true
		"shock":
			restrictions["shocked"] = true
		"immobilize":
			restrictions["immobilized"] = true
	next_state["player_turn_restrictions"] = restrictions
	return next_state

func _trap_trigger_log(state: Dictionary, trap: Dictionary, resolved_damage: int = -1) -> String:
	var element_id: String = str(trap.get("element", ElementData.NONE))
	var damage: int = trap_damage(state, trap) if resolved_damage < 0 else resolved_damage
	var parts: PackedStringArray = ["%s trap hits for %d at intensity %d." % [
		ElementData.name(element_id),
		damage,
		elemental_intensity(state, element_id)
	]]
	if int(trap.get("burn", 0)) > 0:
		parts.append("Burn %d." % int(trap.get("burn", 0)))
	if int(trap.get("freeze", 0)) > 0:
		parts.append("Freeze.")
	if int(trap.get("shock", 0)) > 0:
		parts.append("Shock.")
	if bool(trap.get("immobilize", false)):
		parts.append("Immobilize.")
	if int(trap.get("poison", 0)) > 0:
		parts.append("Poison %d." % int(trap.get("poison", 0)))
	return " ".join(parts)

func _trap_tiles_lookup(state: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		lookup[trap.get("pos", Vector2i(-1, -1))] = true
	return lookup

func _live_traps(state: Dictionary) -> Array[Dictionary]:
	var traps: Array[Dictionary] = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		traps.append((trap_var as Dictionary).duplicate(true))
	return traps

func _trap_tiles_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var trap_tiles: Array[Vector2i] = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var as Dictionary
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if tile_lookup.has(trap_pos):
			trap_tiles.append(trap_pos)
	return trap_tiles

func _trap_blast_tiles(state: Dictionary, trap: Dictionary) -> Array[Vector2i]:
	var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
	var tiles: Array[Vector2i] = []
	for offset: Vector2i in TRAP_BLAST_OFFSETS:
		var tile: Vector2i = trap_pos + offset
		if not PathUtils.is_in_bounds(state.get("grid", []), tile):
			continue
		if not PathUtils.is_passable(state.get("grid", []), tile):
			continue
		tiles.append(tile)
	return tiles

func _trap_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var traps: Array = state.get("traps", [])
	for index: int in range(traps.size()):
		var trap: Dictionary = traps[index]
		if trap.get("pos", Vector2i(-1, -1)) == tile:
			return index
	return -1

func _next_tile_away_from_source(grid: Array, start: Vector2i, source_pos: Vector2i, occupied: Dictionary, blocked_target: Vector2i) -> Vector2i:
	var best_tile: Vector2i = start
	var best_score: int = PathUtils.manhattan(start, source_pos)
	for dir: Vector2i in PathUtils.DIRS_4:
		var candidate: Vector2i = start + dir
		if candidate == blocked_target:
			continue
		if occupied.has(candidate):
			continue
		if not PathUtils.is_passable(grid, candidate):
			continue
		var score: int = PathUtils.manhattan(candidate, source_pos)
		if score > best_score:
			best_score = score
			best_tile = candidate
	return best_tile

func _next_tile_toward_source(grid: Array, start: Vector2i, source_pos: Vector2i, occupied: Dictionary) -> Vector2i:
	var path: Array[Vector2i] = PathUtils.find_path(grid, start, source_pos, occupied, true)
	if path.is_empty():
		return start
	var candidate: Vector2i = path[1] if path.size() > 1 else start
	return start if candidate == source_pos else candidate

func _apply_enemy_self_damage(state: Dictionary, enemy_index: int, amount: int) -> Dictionary:
	if amount <= 0:
		return state
	return _damage_enemy(state, enemy_index, amount, false)

func _enemy_status_damage_step(
	base_step: Dictionary,
	before_state: Dictionary,
	after_state: Dictionary
) -> Dictionary:
	var step: Dictionary = base_step.duplicate(true)
	var enemy_losses: Array[Dictionary] = _enemy_target_losses(before_state, after_state)
	step["enemy_losses"] = enemy_losses
	step["impact_actor_keys"] = _target_loss_keys(enemy_losses)
	step["enemies_after"] = (after_state.get("enemies", []) as Array).duplicate(true)
	step["elemental_intensity_after"] = (after_state.get("elemental_intensity", {}) as Dictionary).duplicate(true)
	step["player_after"] = (after_state.get("player", {}) as Dictionary).duplicate(true)
	for element_id: String in ElementData.all_elements():
		if elemental_intensity(before_state, element_id) == elemental_intensity(after_state, element_id):
			continue
		step["damage_feedback_element"] = element_id
		break
	return step

func _player_action_triggers_bleed(action: Dictionary) -> bool:
	return str(action.get("type", "")) in PLAYER_BLEED_TRIGGER_ACTION_TYPES

func _enemy_action_triggers_bleed(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ENEMY_BLEED_TRIGGER_ACTION_TYPES

func _trigger_player_bleed_for_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	if not _player_action_triggers_bleed(action):
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var bleed_amount: int = int(player.get("bleed", 0))
	if bleed_amount <= 0:
		return next_state
	next_state = _damage_player(next_state, bleed_amount, false, true, "bleed")
	_log(next_state, "Bleed opens for %d." % bleed_amount)
	return next_state

func _trigger_enemy_bleed_for_action(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var empty_step: Dictionary = {}
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"state": next_state, "step": empty_step}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var bleed_amount: int = int(enemy.get("bleed", 0))
	if bleed_amount <= 0 or int(enemy.get("hp", 0)) <= 0:
		return {"state": next_state, "step": empty_step}
	var before_state: Dictionary = next_state.duplicate(true)
	var before_enemy: Dictionary = enemy.duplicate(true)
	next_state = _damage_enemy(next_state, enemy_index, bleed_amount)
	var after_enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= after_enemies.size():
		return {"state": next_state, "step": empty_step}
	var after_enemy: Dictionary = _normalized_enemy(after_enemies[enemy_index] as Dictionary)
	var step: Dictionary = _enemy_status_damage_step({
		"kind": "status_damage",
		"actor_key": _enemy_key(after_enemy),
		"actor_name": str(GameData.enemy_def(str(after_enemy.get("type", ""))).get("name", "Enemy")),
		"tile": before_enemy.get("pos", Vector2i.ZERO),
		"amount": maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0))),
		"label": "Bleed",
		"text": "Bleed %d" % bleed_amount,
		"trigger": "action",
		"action_type": str(action.get("type", ""))
	}, before_state, next_state)
	return {"state": next_state, "step": step}

func _trigger_enemy_bleed_for_resolved_action(state: Dictionary, enemy_index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	if not _enemy_action_triggers_bleed(action):
		return state
	var bleed_result: Dictionary = _trigger_enemy_bleed_for_action(state, enemy_index, action)
	var bleed_step: Dictionary = bleed_result.get("step", {})
	if not bleed_step.is_empty():
		bleed_steps.append(bleed_step)
	return (bleed_result.get("state", state) as Dictionary).duplicate(true)

func _enemy_cannot_continue_after_bleed(state: Dictionary, enemy_index: int) -> bool:
	if combat_outcome(state) != "":
		return true
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return true
	return int((enemies[enemy_index] as Dictionary).get("hp", 0)) <= 0

func _clear_player_bleed_after_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(player.get("bleed", 0)) <= 0:
		return next_state
	player["bleed"] = 0
	next_state["player"] = player
	return next_state

func _clear_enemy_bleed_after_turn(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return next_state
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("bleed", 0)) <= 0:
		return next_state
	enemy["bleed"] = 0
	enemies[enemy_index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _resolve_enemy_start_of_turn(state: Dictionary, enemy_index: int) -> Dictionary:
	var next_state: Dictionary = state
	var steps: Array[Dictionary] = []
	var enemies: Array = next_state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {"steps": steps, "skip_all": false, "shocked": false, "immobilized": false}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var actor_name: String = str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy"))
	if int(enemy.get("burn", 0)) > 0:
		var burn_amount: int = int(enemy.get("burn", 0))
		var burn_before_state: Dictionary = next_state.duplicate(true)
		var before_enemy: Dictionary = enemy.duplicate(true)
		next_state = _damage_enemy(next_state, enemy_index, burn_amount)
		enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
		enemy["burn"] = maxi(0, int(enemy.get("burn", 0)) - GameData.status_tick_reduction("burn"))
		var burn_enemies: Array = next_state.get("enemies", [])
		burn_enemies[enemy_index] = enemy
		next_state["enemies"] = burn_enemies
		steps.append(_enemy_status_damage_step({
			"kind": "status_damage",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"amount": int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0)),
			"label": "Burn",
			"text": "Burn %d" % burn_amount
		}, burn_before_state, next_state))
		if int(enemy.get("hp", 0)) <= 0:
			return {"steps": steps, "skip_all": true, "shocked": false, "immobilized": false, "state": next_state}
	if _poison_damage(enemy) > 0:
		var poison_before: Dictionary = enemy.duplicate(true)
		enemy = _advance_poison(enemy)
		var poison_enemies: Array = next_state.get("enemies", [])
		poison_enemies[enemy_index] = enemy
		next_state["enemies"] = poison_enemies
		if int(enemy.get("poison", {}).get("trigger", 0)) > 0:
			var poison_damage: int = int(enemy.get("poison", {}).get("trigger", 0))
			var poison_damage_before_state: Dictionary = next_state.duplicate(true)
			next_state = _damage_enemy(next_state, enemy_index, poison_damage)
			enemy = _normalized_enemy(((next_state.get("enemies", []) as Array)[enemy_index] as Dictionary))
			var poison_step: Dictionary = {
				"kind": "status_damage",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"amount": int(poison_before.get("hp", 0)) - int(enemy.get("hp", 0)),
				"label": "Poison",
				"text": "Poison %d" % poison_damage
			}
			var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
			poison["trigger"] = 0
			enemy["poison"] = poison
			poison_enemies = next_state.get("enemies", [])
			poison_enemies[enemy_index] = enemy
			next_state["enemies"] = poison_enemies
			steps.append(_enemy_status_damage_step(poison_step, poison_damage_before_state, next_state))
			if int(enemy.get("hp", 0)) <= 0:
				return {"steps": steps, "skip_all": true, "shocked": false, "immobilized": false, "state": next_state}
	else:
		enemy = _advance_poison(enemy)
		var pending_poison_enemies: Array = next_state.get("enemies", [])
		pending_poison_enemies[enemy_index] = enemy
		next_state["enemies"] = pending_poison_enemies
	var skip_all: bool = false
	var shocked: bool = false
	var immobilized: bool = false
	if int(enemy.get("freeze", 0)) > 0:
		enemy["freeze"] = maxi(0, int(enemy.get("freeze", 0)) - 1)
		var frozen_enemies: Array = next_state.get("enemies", [])
		frozen_enemies[enemy_index] = enemy
		next_state["enemies"] = frozen_enemies
		skip_all = true
		steps.append({
			"kind": "status",
			"actor_key": _enemy_key(enemy),
			"actor_name": actor_name,
			"tile": enemy.get("pos", Vector2i.ZERO),
			"label": "Frozen",
			"text": "Frozen"
		})
	else:
		if int(enemy.get("shock", 0)) > 0:
			enemy["shock"] = maxi(0, int(enemy.get("shock", 0)) - 1)
			shocked = true
			steps.append({
				"kind": "status",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"label": "Shocked",
				"text": "Shocked"
			})
		if bool(enemy.get("immobilize", false)):
			enemy["immobilize"] = false
			immobilized = true
			steps.append({
				"kind": "status",
				"actor_key": _enemy_key(enemy),
				"actor_name": actor_name,
				"tile": enemy.get("pos", Vector2i.ZERO),
				"label": "Immobilized",
				"text": "Immobilized"
			})
		var restricted_enemies: Array = next_state.get("enemies", [])
		restricted_enemies[enemy_index] = enemy
		next_state["enemies"] = restricted_enemies
	return {"steps": steps, "skip_all": skip_all, "shocked": shocked, "immobilized": immobilized, "state": next_state}

func _resolve_player_start_of_turn(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(player.get("burn", 0)) > 0:
		var burn_amount: int = int(player.get("burn", 0))
		next_state = _damage_player(next_state, burn_amount, false, true, "burn")
		player = _normalized_player(next_state.get("player", {}))
		player["burn"] = maxi(0, int(player.get("burn", 0)) - GameData.status_tick_reduction("burn"))
		next_state["player"] = player
		_log(next_state, "Burn deals %d." % burn_amount)
		if combat_outcome(next_state) != "":
			return next_state
	if _poison_damage(player) > 0:
		player = _advance_poison(player)
		next_state["player"] = player
		if int(player.get("poison", {}).get("trigger", 0)) > 0:
			var poison_damage: int = int(player.get("poison", {}).get("trigger", 0))
			next_state = _damage_player(next_state, poison_damage, false, true, "poison")
			player = _normalized_player(next_state.get("player", {}))
			var poison: Dictionary = player.get("poison", {}).duplicate(true)
			poison["trigger"] = 0
			player["poison"] = poison
			next_state["player"] = player
			_log(next_state, "Poison deals %d." % poison_damage)
			if combat_outcome(next_state) != "":
				return next_state
	else:
		player = _advance_poison(player)
		next_state["player"] = player
	var restrictions: Dictionary = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
	}
	if int(player.get("freeze", 0)) > 0:
		player["freeze"] = maxi(0, int(player.get("freeze", 0)) - 1)
		restrictions["frozen"] = true
		_log(next_state, "Frozen this turn.")
	else:
		if int(player.get("shock", 0)) > 0:
			player["shock"] = maxi(0, int(player.get("shock", 0)) - 1)
			restrictions["shocked"] = true
			_log(next_state, "Shocked this turn.")
		if bool(player.get("immobilize", false)):
			player["immobilize"] = false
			restrictions["immobilized"] = true
			_log(next_state, "Immobilized this turn.")
	next_state["player"] = player
	next_state["player_turn_restrictions"] = restrictions
	return next_state

func _poison_damage(unit: Dictionary) -> int:
	return int((unit.get("poison", {}) as Dictionary).get("damage", 0))

func _advance_poison(unit: Dictionary) -> Dictionary:
	var next_unit: Dictionary = unit.duplicate(true)
	var poison: Dictionary = (next_unit.get("poison", {}) as Dictionary).duplicate(true)
	var damage: int = int(poison.get("damage", 0))
	var delay: int = int(poison.get("delay", 0))
	poison["trigger"] = 0
	if damage <= 0 or delay <= 0:
		poison["damage"] = damage
		poison["delay"] = maxi(0, delay)
		next_unit["poison"] = poison
		return next_unit
	delay -= 1
	if delay <= 0:
		poison["trigger"] = damage
		poison["damage"] = 0
		poison["delay"] = 0
	else:
		poison["delay"] = delay
	next_unit["poison"] = poison
	return next_unit

func _enemy_action_is_movement(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["move_toward", "move_away"]

func _next_enemy_followup_attack_action(actions: Array, start_index: int) -> Dictionary:
	for action_index: int in range(start_index, actions.size()):
		var action_var: Variant = actions[action_index]
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if str(action.get("type", "")) in ATTACK_ACTION_TYPES:
			return action.duplicate(true)
	return {}

func _threat_movement_tiles(state: Dictionary, enemy: Dictionary, start_tile: Vector2i, action: Dictionary, occupied: Dictionary, blocked_target: Vector2i) -> Array[Vector2i]:
	var move_range: int = int(action.get("range", 0))
	if move_range <= 0:
		return []
	var preview_enemy: Dictionary = enemy.duplicate(true)
	preview_enemy["pos"] = start_tile
	if preview_enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
		return _reachable_enemy_anchor_tiles(state, preview_enemy, move_range, occupied, blocked_target)
	return PathUtils.reachable_tiles(state.get("grid", []), start_tile, move_range, occupied)

func _threat_attack_tiles(state: Dictionary, enemy: Dictionary, start_tile: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	var grid: Array = state.get("grid", [])
	var preview_enemy: Dictionary = enemy.duplicate(true)
	preview_enemy["pos"] = start_tile
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"melee", "ranged", "push", "pull":
			for tile: Vector2i in _threat_candidate_tiles(state, preview_enemy):
				if _enemy_action_reaches_tile(state, preview_enemy, action, tile):
					lookup[tile] = true
			for tile: Vector2i in _threat_trap_blast_tiles(state, preview_enemy, action):
				lookup[tile] = true
		"aoe":
			for tile: Vector2i in _threat_aoe_tiles(state, preview_enemy, action):
				lookup[tile] = true
			for tile: Vector2i in _threat_trap_blast_tiles(state, preview_enemy, action):
				lookup[tile] = true
		"lightning_strikes":
			var preview_state: Dictionary = _state_with_enemy_anchor(state, preview_enemy, start_tile)
			for tile: Vector2i in _lightning_strike_tiles(preview_state, preview_enemy, action):
				lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _threat_candidate_tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var enemy_footprint: Array[Vector2i] = _enemy_footprint_tiles(enemy)
	var tiles: Array[Vector2i] = []
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile: Vector2i = Vector2i(x, y)
			if enemy_footprint.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			tiles.append(tile)
	return tiles

func _threat_aoe_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var lookup: Dictionary = {}
	var centers: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var attack_range: int = int(action.get("range", 0))
	if attack_range > 0:
		centers = _threat_candidate_tiles(state, enemy)
	for center: Vector2i in centers:
		if attack_range > 0 and not _enemy_aoe_can_target_center(state, enemy, action, center):
			continue
		if _action_orientation_direction(action) != Vector2i.ZERO:
			for tile: Vector2i in _enemy_aoe_tiles_for_target(state, enemy, action, center, true):
				if _enemy_footprint_tiles(enemy).has(tile):
					continue
				lookup[tile] = true
		elif bool(action.get("orient_toward_target", false)):
			for target: Dictionary in _actor_targets(state):
				if not _enemy_action_reaches_target(state, enemy, action, target):
					continue
				var target_pos: Vector2i = target.get("pos", Vector2i.ZERO)
				if attack_range > 0 and center != target_pos:
					continue
				var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target_pos)
				for tile: Vector2i in _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true):
					if _enemy_footprint_tiles(enemy).has(tile):
						continue
					lookup[tile] = true
		else:
			for offsets_var: Variant in _aoe_pattern_variants(action):
				var offsets: Array = offsets_var
				for tile: Vector2i in _tiles_for_aoe_offsets(grid, center, offsets):
					if _enemy_footprint_tiles(enemy).has(tile):
						continue
					lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _threat_trap_blast_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for trap: Dictionary in _live_traps(state):
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if not _enemy_action_reaches_tile(state, enemy, action, trap_pos):
			continue
		if _trap_blast_hits_enemy(state, trap, enemy):
			continue
		for tile: Vector2i in _trap_blast_tiles(state, trap):
			lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _enemy_aoe_can_target_center(state: Dictionary, enemy: Dictionary, action: Dictionary, center: Vector2i) -> bool:
	var grid: Array = state.get("grid", [])
	if not PathUtils.is_passable(grid, center):
		return false
	var source_pos: Vector2i = _closest_enemy_tile_to(enemy, center)
	return (
		PathUtils.manhattan(source_pos, center) <= int(action.get("range", 0))
		and PathUtils.has_line_of_sight(grid, source_pos, center)
	)

func _state_with_enemy_anchor(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> Dictionary:
	var preview_state: Dictionary = state.duplicate(true)
	var enemies: Array = preview_state.get("enemies", []).duplicate(true)
	var enemy_id: int = int(enemy.get("id", -1))
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = enemies[index]
		if int(candidate.get("id", -1)) != enemy_id:
			continue
		var preview_enemy: Dictionary = enemy.duplicate(true)
		preview_enemy["pos"] = anchor
		enemies[index] = preview_enemy
		break
	preview_state["enemies"] = enemies
	return preview_state

func _player_status_step_text(before_player: Dictionary, after_player: Dictionary, action: Dictionary) -> String:
	var tags: PackedStringArray = []
	if int(after_player.get("burn", 0)) > int(before_player.get("burn", 0)):
		tags.append("Burn")
	if int(after_player.get("freeze", 0)) > int(before_player.get("freeze", 0)):
		tags.append("Freeze")
	if int(after_player.get("shock", 0)) > int(before_player.get("shock", 0)):
		tags.append("Shock")
	if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)):
		tags.append("Immobilize")
	var before_poison: Dictionary = before_player.get("poison", {})
	var after_poison: Dictionary = after_player.get("poison", {})
	if int(after_poison.get("damage", 0)) > int(before_poison.get("damage", 0)):
		tags.append("Poison")
	if int(action.get("push", 0)) > 0 and before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO):
		tags.append("Push")
	if int(action.get("pull", 0)) > 0 and before_player.get("pos", Vector2i.ZERO) != after_player.get("pos", Vector2i.ZERO):
		tags.append("Pull")
	if tags.is_empty():
		return ""
	return ", ".join(tags)

func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
	var next_state: Dictionary = state
	var deck: Dictionary = next_state.get("deck", {}).duplicate(true)
	for _draw_index: int in range(count):
		if (deck.get("hand", []) as Array).size() >= MAX_HAND_SIZE:
			break
		if combat_outcome(next_state) != "":
			break
		if (deck.get("draw", []) as Array).is_empty():
			var discard: Array = deck.get("discard", []).duplicate()
			if discard.is_empty():
				break
			deck["cycles"] = int(deck.get("cycles", 0)) + 1
			var fatigue_damage: int = int(deck.get("fatigue_base", FATIGUE_BASE_DAMAGE)) + int(deck.get("cycles", 0)) - 1
			var fatigue_hp_before: int = int((_normalized_player(next_state.get("player", {}))).get("hp", 0))
			next_state["deck"] = deck
			next_state = _lose_player_health(next_state, fatigue_damage, true, true, "fatigue", true)
			var reserve_id: String = SkillTreeLibrary.skill_id_for_effect("survive_fatigue")
			var fatigue_player: Dictionary = _normalized_player(next_state.get("player", {}))
			if int(fatigue_player.get("hp", 0)) <= 0 and has_skill(next_state, reserve_id) and not skill_was_used(next_state, reserve_id):
				var reserve_effect: Dictionary = SkillTreeLibrary.effect(reserve_id)
				var reserve_health: int = GameData.fixed_point_amount(maxi(1, int(reserve_effect.get("minimum_health_visible", 1))))
				fatigue_player["hp"] = reserve_health
				next_state["player"] = fatigue_player
				_mark_skill_used(next_state, reserve_id, "%s survives Fatigue at %d health." % [SkillTreeLibrary.display_name(reserve_id), reserve_health])
			fatigue_player = _normalized_player(next_state.get("player", {}))
			if int(fatigue_player.get("hp", 0)) <= 0:
				next_state = _trigger_defiance(next_state, "fatigue", fatigue_hp_before)
			deck = next_state.get("deck", {}).duplicate(true)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.state = int(next_state.get("rng_state", 0))
			deck["draw"] = GameData.shuffle_cards(discard, rng)
			deck["discard"] = []
			next_state["rng_state"] = rng.state
			_log(next_state, "Fatigue costs %d health." % fatigue_damage)
			if combat_outcome(next_state) != "":
				break
		var draw_pile: Array = deck.get("draw", []).duplicate()
		if draw_pile.is_empty():
			break
		var hand: Array = deck.get("hand", []).duplicate()
		hand.append(str(draw_pile.pop_back()))
		deck["draw"] = draw_pile
		deck["hand"] = hand
		deck["draw_revision"] = int(deck.get("draw_revision", 0)) + 1
	next_state["deck"] = deck
	return next_state

func _collect_loot_at_player(state: Dictionary) -> void:
	var loot_entries: Array = state.get("loot", [])
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	for index: int in range(loot_entries.size()):
		var loot: Dictionary = loot_entries[index]
		if bool(loot.get("claimed", false)):
			continue
		if loot.get("pos", Vector2i(-1, -1)) != player_pos:
			continue
		loot["claimed"] = true
		loot_entries[index] = loot
		var amount: int = int(loot.get("amount", 0))
		match str(loot.get("kind", "")):
			"item":
				BattlefieldItemRules.collect(state, loot)
				_log(state, "Found %s." % str(GameData.card_def(str(loot.get("card_id", ""))).get("name", "item")))
			"dropped_embers":
				state["recovered_embers_total"] = int(state.get("recovered_embers_total", 0)) + amount
				state["recovery_marker_claimed"] = true
				_log(state, "Recovered %d embers." % amount)
			"equipment":
				var equipment_id: String = str(loot.get("equipment_id", ""))
				if not equipment_id.is_empty():
					var collected: Array = state.get("collected_equipment", []).duplicate()
					if not collected.has(equipment_id):
						collected.append(equipment_id)
					state["collected_equipment"] = collected
					var item_name: String = str(GameData.equipment_def(equipment_id).get("name", equipment_id))
					_log(state, "Found %s." % item_name)

func _unclaimed_loot_count(state: Dictionary) -> int:
	var count: int = 0
	for loot_var: Variant in state.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY and not bool((loot_var as Dictionary).get("claimed", false)):
			count += 1
	return count

func _maybe_refund_loot_play(state: Dictionary, unclaimed_before: int) -> Dictionary:
	var next_state: Dictionary = state
	if _unclaimed_loot_count(next_state) >= unclaimed_before:
		return next_state
	var skill_id: String = SkillTreeLibrary.skill_id_for_effect("loot_refund")
	if not skill_is_ready(next_state, skill_id):
		return next_state
	next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + 1
	_mark_skill_used(next_state, skill_id, "%s refunds the play spent reaching loot." % SkillTreeLibrary.display_name(skill_id))
	return next_state

func _occupied_enemy_tiles(state: Dictionary, exclude_id: int = -1) -> Dictionary:
	var occupied: Dictionary = {}
	for enemy: Dictionary in _live_enemies(state):
		if int(enemy.get("id", -1)) == exclude_id:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			occupied[tile] = true
	return occupied

func _occupied_visible_enemy_tiles(state: Dictionary, exclude_id: int = -1) -> Dictionary:
	var occupied: Dictionary = {}
	var visible_lookup: Dictionary = umbra_visible_tile_lookup(state)
	for enemy: Dictionary in _live_enemies(state):
		if int(enemy.get("id", -1)) == exclude_id or not is_enemy_visible_to_player(state, enemy, visible_lookup):
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			occupied[tile] = true
	return occupied

func _occupied_illusion_tiles(state: Dictionary, exclude_id: int = -1) -> Dictionary:
	var occupied: Dictionary = {}
	for illusion: Dictionary in _live_illusions(state):
		if int(illusion.get("id", -1)) == exclude_id:
			continue
		occupied[illusion.get("pos", Vector2i.ZERO)] = true
	return occupied

func _occupied_terrain_tiles(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for terrain: Dictionary in _live_terrain(state):
		occupied[terrain.get("pos", Vector2i.ZERO)] = true
	return occupied

func _occupied_actor_tiles(state: Dictionary, exclude_enemy_id: int = -1, exclude_illusion_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state, exclude_enemy_id)
	for tile_var: Variant in _occupied_illusion_tiles(state, exclude_illusion_id).keys():
		occupied[tile_var] = true
	for tile_var: Variant in _occupied_terrain_tiles(state).keys():
		occupied[tile_var] = true
	return occupied

func _player_blocking_tiles(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state)
	for tile_var: Variant in _occupied_terrain_tiles(state).keys():
		occupied[tile_var] = true
	return occupied

func _known_actor_tiles_for_player(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = _occupied_visible_enemy_tiles(state)
	for tile_var: Variant in _occupied_terrain_tiles(state).keys():
		occupied[tile_var] = true
	return occupied

func _dispel_illusion_at_player(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	for illusion: Dictionary in _live_illusions(next_state):
		if illusion.get("pos", Vector2i(-999, -999)) != player_pos:
			continue
		return _damage_illusion(next_state, int(illusion.get("id", -1)), int(illusion.get("hp", 0)))
	return next_state

func _enemy_blocking_tiles(state: Dictionary, exclude_enemy_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_actor_tiles(state, exclude_enemy_id)
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	occupied[player_pos] = true
	return occupied

func _enemy_blocking_tiles_without_terrain(state: Dictionary, exclude_enemy_id: int = -1) -> Dictionary:
	var occupied: Dictionary = _occupied_enemy_tiles(state, exclude_enemy_id)
	for tile_var: Variant in _occupied_illusion_tiles(state).keys():
		occupied[tile_var] = true
	var player_pos: Vector2i = (_normalized_player(state.get("player", {}))).get("pos", Vector2i.ZERO)
	occupied[player_pos] = true
	return occupied

func _live_enemies(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0:
			result.append(enemy)
	return result

func _live_illusions(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = _normalized_illusion(illusion_var as Dictionary)
		if int(illusion.get("hp", 0)) > 0:
			result.append(illusion)
	return result

func _live_terrain(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_var)
		if int(terrain.get("hp", 0)) > 0:
			result.append(terrain)
	return result

func _illusion_key(illusion: Dictionary) -> String:
	return "illusion_%d" % int(illusion.get("id", -1))

func _enemy_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if _enemy_footprint_tiles(enemy).has(tile):
				return index
	return -1

func _terrain_index_at_tile(state: Dictionary, tile: Vector2i) -> int:
	var terrain_entries: Array = state.get("terrain", [])
	for index: int in range(terrain_entries.size()):
		if typeof(terrain_entries[index]) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_entries[index])
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if terrain.get("pos", Vector2i(-1, -1)) == tile:
			return index
	return -1

func _enemy_indices_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[int]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var indices: Array[int] = []
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemies[index] as Dictionary
		if int(enemy.get("hp", 0)) <= 0:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if tile_lookup.has(tile):
				indices.append(index)
				break
	return indices

func _terrain_indices_in_tiles(state: Dictionary, tiles: Array[Vector2i]) -> Array[int]:
	var tile_lookup: Dictionary = {}
	for tile: Vector2i in tiles:
		tile_lookup[tile] = true
	var indices: Array[int] = []
	var terrain_entries: Array = state.get("terrain", [])
	for index: int in range(terrain_entries.size()):
		if typeof(terrain_entries[index]) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_entries[index] as Dictionary
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if tile_lookup.has(terrain.get("pos", Vector2i.ZERO)):
			indices.append(index)
	return indices

func _enemy_footprint_tiles(enemy: Dictionary, origin_override: Vector2i = Vector2i(-999, -999)) -> Array[Vector2i]:
	var origin: Vector2i = origin_override if origin_override.x > -900 else enemy.get("pos", Vector2i(-1, -1))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _enemy_distance_to_tile(enemy: Dictionary, tile: Vector2i) -> int:
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		best_distance = mini(best_distance, PathUtils.manhattan(enemy_tile, tile))
	return best_distance

func _enemy_distance_between(first_enemy: Dictionary, second_enemy: Dictionary) -> int:
	var best_distance: int = 9999
	for first_tile: Vector2i in _enemy_footprint_tiles(first_enemy):
		for second_tile: Vector2i in _enemy_footprint_tiles(second_enemy):
			best_distance = mini(best_distance, PathUtils.manhattan(first_tile, second_tile))
	return best_distance

func _closest_enemy_tile_to(enemy: Dictionary, tile: Vector2i) -> Vector2i:
	var best_tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		var distance: int = PathUtils.manhattan(enemy_tile, tile)
		if distance < best_distance:
			best_distance = distance
			best_tile = enemy_tile
	return best_tile

func _enemy_can_occupy_anchor(state: Dictionary, enemy: Dictionary, anchor: Vector2i, occupied: Dictionary, blocked_target: Vector2i = Vector2i(-999, -999)) -> bool:
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		if tile == blocked_target:
			return false
		if occupied.has(tile):
			return false
		if not PathUtils.is_passable(state.get("grid", []), tile):
			return false
	return true

func _lightning_strike_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var grid: Array = state.get("grid", [])
	var occupied: Dictionary = _occupied_enemy_tiles(state)
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile: Vector2i = Vector2i(x, y)
			if occupied.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score: int = _lightning_tile_score(state, enemy, action, a)
		var b_score: int = _lightning_tile_score(state, enemy, action, b)
		if a_score == b_score:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return a_score < b_score
	)
	var results: Array[Vector2i] = []
	var strike_count: int = mini(int(action.get("count", 4)), candidates.size())
	for index: int in range(strike_count):
		results.append(candidates[index])
	return results

func _lightning_tile_score(state: Dictionary, enemy: Dictionary, action: Dictionary, tile: Vector2i) -> int:
	var seed: int = int(state.get("rng_state", 0))
	seed = int((seed + int(state.get("turn", 1)) * 1103515245 + int(enemy.get("id", 0)) * 92821 + int(action.get("count", 0)) * 193) & 0x7fffffff)
	seed = int((seed + tile.x * 68917 + tile.y * 28307) & 0x7fffffff)
	return seed

func _trigger_enemy_death_spawn(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	if bool(enemy.get("summoned", false)):
		return next_state
	var spawn_def_value: Variant = GameData.enemy_def(str(enemy.get("type", ""))).get("death_spawn", {})
	if typeof(spawn_def_value) != TYPE_DICTIONARY:
		return next_state
	var spawn_def: Dictionary = (spawn_def_value as Dictionary).duplicate(true)
	if spawn_def.is_empty():
		return next_state
	var spawn_kind: String = str(spawn_def.get("type", "split"))
	if spawn_kind != "split":
		return next_state
	var spawn_type: String = str(spawn_def.get("enemy_type", ""))
	if spawn_type.is_empty() or GameData.enemy_def(spawn_type).is_empty():
		return next_state
	var spawn_count: int = maxi(0, int(spawn_def.get("count", 0)))
	if spawn_count <= 0:
		return next_state
	var spawn_tiles: Array[Vector2i] = _death_spawn_tiles_for_enemy(next_state, enemy, spawn_def)
	if spawn_tiles.is_empty():
		return next_state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	var first_spawned_index: int = enemies.size()
	var next_id: int = _next_enemy_id(next_state)
	for tile: Vector2i in spawn_tiles:
		enemies.append(_spawned_enemy_entry(next_state, spawn_type, next_id, tile, bool(spawn_def.get("summoned", true))))
		next_id += 1
	next_state["enemies"] = enemies
	var intent_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	intent_rng.state = int(next_state.get("rng_state", 1))
	for spawned_index: int in range(first_spawned_index, first_spawned_index + spawn_tiles.size()):
		_assign_enemy_intent(next_state, spawned_index, intent_rng)
		var spawned_enemy: Dictionary = _normalized_enemy((next_state.get("enemies", []) as Array)[spawned_index] as Dictionary)
		_schedule_enemy_after_spawn(next_state, spawned_enemy, spawned_index - first_spawned_index)
	next_state["rng_state"] = intent_rng.state
	_log(next_state, "%s splits." % str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")))
	return next_state

func _spawned_enemy_entry(state: Dictionary, enemy_type: String, enemy_id: int, tile: Vector2i, summoned: bool) -> Dictionary:
	var max_hp: int = _scaled_enemy_max_hp(enemy_type, int(state.get("room_depth", 1)))
	var spawned: Dictionary = {
		"id": enemy_id,
		"type": enemy_type,
		"summoned": summoned,
		"element": str(state.get("room_element", ElementData.NONE)),
		"pos": tile,
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"stoneskin": 0
	}
	return _normalized_enemy(spawned)

func _schedule_enemy_after_spawn(state: Dictionary, enemy: Dictionary, spawn_order: int) -> void:
	var intent_time_cost: int = _enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
	var delay: int = maxi(ENEMY_MIN_INITIATIVE, _enemy_base_initiative(state, enemy) + maxi(0, intent_time_cost))
	_schedule_actor(state, _enemy_actor_entry(state, enemy, int(state.get("initiative_clock", 0)) + delay + maxi(0, spawn_order), 0))

func _death_spawn_tiles_for_enemy(state: Dictionary, enemy: Dictionary, spawn_def: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = _vector2i_values([])
	var occupied: Dictionary = _enemy_blocking_tiles(state)
	var radius: int = maxi(1, int(spawn_def.get("radius", 1)))
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	for tile: Vector2i in PathUtils.diamond_tiles(origin, radius, state.get("grid", [])):
		if occupied.has(tile):
			continue
		if not PathUtils.is_passable(state.get("grid", []), tile):
			continue
		if _enemy_distance_to_tile(enemy, tile) <= 0:
			continue
		candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance: int = _enemy_distance_to_tile(enemy, a)
		var b_distance: int = _enemy_distance_to_tile(enemy, b)
		if a_distance == b_distance:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return a_distance < b_distance
	)
	var results: Array[Vector2i] = _vector2i_values([])
	var count: int = maxi(0, int(spawn_def.get("count", 0)))
	for tile: Vector2i in candidates:
		results.append(tile)
		if results.size() >= count:
			break
	return results

func _summon_tiles_for_enemy(state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var occupied: Dictionary = _enemy_blocking_tiles(state)
	for tile: Vector2i in PathUtils.diamond_tiles(enemy.get("pos", Vector2i.ZERO), 4, state.get("grid", [])):
		if occupied.has(tile):
			continue
		if not PathUtils.is_passable(state.get("grid", []), tile):
			continue
		if _enemy_distance_to_tile(enemy, tile) <= 0:
			continue
		candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance: int = _enemy_distance_to_tile(enemy, a)
		var b_distance: int = _enemy_distance_to_tile(enemy, b)
		if a_distance == b_distance:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return a_distance < b_distance
	)
	var results: Array[Vector2i] = []
	for tile: Vector2i in candidates:
		results.append(tile)
		if results.size() >= count:
			break
	return results

func _next_enemy_id(state: Dictionary) -> int:
	var next_id: int = 1
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		next_id = maxi(next_id, int((enemy_var as Dictionary).get("id", 0)) + 1)
	return next_id

func _enemy_should_summon_wisps(state: Dictionary, enemy: Dictionary) -> bool:
	if str(enemy.get("type", "")) != ZEKARION_TYPE:
		return false
	if int(state.get("zekarion_summon_waves", 0)) >= 1:
		return false
	for other: Dictionary in _live_enemies(state):
		if str(other.get("type", "")) == LIGHTNING_WISP_TYPE:
			return false
	return true

func _zekarion_summon_intent() -> Dictionary:
	return {
		"id": "call_wisps",
		"name": "Call Wisps",
		"time": 6,
		"actions": [
			{"type": "summon_minions", "minion_type": LIGHTNING_WISP_TYPE, "count": 2}
		]
	}

func _best_aoe_tiles_for_target(state: Dictionary, action: Dictionary, target_tile: Vector2i, score_player: bool) -> Array[Vector2i]:
	var grid: Array = state.get("grid", [])
	var centered_target: bool = int(action.get("range", 0)) > 0
	var orientation: Vector2i = _action_orientation_direction(action)
	if orientation != Vector2i.ZERO:
		var oriented_offsets: Array[Vector2i] = _aoe_pattern_offsets_for_direction(action, orientation)
		return _tiles_for_centered_aoe_offsets(grid, target_tile, oriented_offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, oriented_offsets)
	var variants: Array = _aoe_pattern_variants(action)
	if variants.size() == 1:
		var sole_offsets: Array = variants[0] as Array
		return _tiles_for_centered_aoe_offsets(grid, target_tile, sole_offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, sole_offsets)
	var best_tiles: Array[Vector2i] = []
	var best_score: int = -1
	var best_size: int = 9999
	for offsets_var: Variant in variants:
		var offsets: Array = offsets_var
		var tiles: Array[Vector2i] = _tiles_for_centered_aoe_offsets(grid, target_tile, offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, offsets)
		var score: int = 0
		if score_player:
			score = _actor_targets_in_tiles(state, tiles).size()
		else:
			score = _enemy_indices_in_tiles(state, tiles).size()
			score += _terrain_indices_in_tiles(state, tiles).size()
			score += _trap_tiles_in_tiles(state, tiles).size()
		if score > best_score or (score == best_score and tiles.size() < best_size):
			best_score = score
			best_size = tiles.size()
			best_tiles = tiles
	return best_tiles

func _player_attackable_tiles_lookup(state: Dictionary, include_hidden_enemies: bool = false) -> Dictionary:
	var lookup: Dictionary = {}
	var grid: Array = state.get("grid", [])
	for enemy: Dictionary in _live_enemies(state):
		if not include_hidden_enemies and not is_enemy_visible_to_player(state, enemy):
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if PathUtils.is_passable(grid, tile):
				lookup[tile] = true
	for terrain: Dictionary in _live_terrain(state):
		var terrain_tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		if PathUtils.is_passable(grid, terrain_tile):
			lookup[terrain_tile] = true
	for trap: Dictionary in _live_traps(state):
		var trap_tile: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if PathUtils.is_passable(grid, trap_tile):
			lookup[trap_tile] = true
	return lookup

func _aoe_pattern_specs_for_legality(action: Dictionary, centered_target: bool) -> Array[Dictionary]:
	var variants: Array = []
	var orientation: Vector2i = _action_orientation_direction(action)
	if orientation != Vector2i.ZERO:
		variants.append(_aoe_pattern_offsets_for_direction(action, orientation))
	else:
		variants = _aoe_pattern_variants(action)
	var specs: Array[Dictionary] = []
	for offsets_var: Variant in variants:
		if typeof(offsets_var) != TYPE_ARRAY:
			continue
		var offsets: Array = offsets_var as Array
		specs.append({
			"offsets": offsets,
			"center": _aoe_center_offset(offsets) if centered_target else Vector2i.ZERO
		})
	return specs

func _aoe_pattern_specs_hit_attackable(target_tile: Vector2i, specs: Array[Dictionary], attackable_tiles: Dictionary) -> bool:
	if attackable_tiles.is_empty():
		return false
	for spec: Dictionary in specs:
		var anchor: Vector2i = target_tile - (spec.get("center", Vector2i.ZERO) as Vector2i)
		for offset_var: Variant in spec.get("offsets", []):
			if typeof(offset_var) != TYPE_VECTOR2I:
				continue
			if attackable_tiles.has(anchor + (offset_var as Vector2i)):
				return true
	return false

func _aoe_tiles_for_anchor(grid: Array, action: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var centered_target: bool = int(action.get("range", 0)) > 0
	var orientation: Vector2i = _action_orientation_direction(action)
	if orientation != Vector2i.ZERO:
		var oriented_offsets: Array[Vector2i] = _aoe_pattern_offsets_for_direction(action, orientation)
		return _tiles_for_centered_aoe_offsets(grid, target_tile, oriented_offsets) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, oriented_offsets)
	var variants: Array = _aoe_pattern_variants(action)
	if variants.is_empty():
		return []
	return _tiles_for_centered_aoe_offsets(grid, target_tile, variants[0]) if centered_target else _tiles_for_aoe_offsets(grid, target_tile, variants[0])

func _tiles_for_centered_aoe_offsets(grid: Array, center: Vector2i, offsets: Array) -> Array[Vector2i]:
	return _tiles_for_aoe_offsets(grid, center - _aoe_center_offset(offsets), offsets)

func _tiles_for_aoe_offsets(grid: Array, anchor: Vector2i, offsets: Array) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for offset: Vector2i in _vector2i_values(offsets):
		var tile: Vector2i = anchor + offset
		if not PathUtils.is_passable(grid, tile):
			continue
		lookup[tile] = true
	return _sorted_tiles_from_lookup(lookup)

func _aoe_center_offset(offsets: Array) -> Vector2i:
	var typed_offsets: Array[Vector2i] = _vector2i_values(offsets)
	if typed_offsets.is_empty():
		return Vector2i.ZERO
	var center_sum: Vector2 = Vector2.ZERO
	for offset: Vector2i in typed_offsets:
		center_sum += Vector2(float(offset.x), float(offset.y))
	var centroid: Vector2 = center_sum / float(typed_offsets.size())
	var rounded_centroid: Vector2i = Vector2i(int(roundf(centroid.x)), int(roundf(centroid.y)))
	if is_equal_approx(centroid.x, float(rounded_centroid.x)) and is_equal_approx(centroid.y, float(rounded_centroid.y)):
		return rounded_centroid
	var best_offset: Vector2i = typed_offsets[0]
	var best_distance: float = INF
	var best_origin_distance: int = 99999
	for offset: Vector2i in typed_offsets:
		var distance: float = Vector2(float(offset.x), float(offset.y)).distance_squared_to(centroid)
		var origin_distance: int = PathUtils.manhattan(Vector2i.ZERO, offset)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and origin_distance < best_origin_distance):
			best_distance = distance
			best_origin_distance = origin_distance
			best_offset = offset
	return best_offset

func _aoe_pattern_variants(action: Dictionary) -> Array:
	var offsets: Array[Vector2i] = _aoe_pattern_offsets(action)
	var variants: Array = []
	var seen: Dictionary = {}
	var rotation_count: int = 4 if bool(action.get("rotate", true)) else 1
	for rotation: int in range(rotation_count):
		var rotated: Array[Vector2i] = []
		for offset: Vector2i in offsets:
			rotated.append(_rotated_offset(offset, rotation))
		var key_parts: PackedStringArray = []
		for rotated_offset: Vector2i in rotated:
			key_parts.append("%d,%d" % [rotated_offset.x, rotated_offset.y])
		key_parts.sort()
		var key: String = "|".join(key_parts)
		if seen.has(key):
			continue
		seen[key] = true
		var unique_lookup: Dictionary = {}
		for rotated_offset: Vector2i in rotated:
			unique_lookup[rotated_offset] = true
		var unique_offsets: Array[Vector2i] = _sorted_tiles_from_lookup(unique_lookup)
		variants.append(unique_offsets)
	return variants

func _aoe_pattern_offsets_for_direction(action: Dictionary, direction: Vector2i) -> Array[Vector2i]:
	var rotation: int = _rotation_for_direction(direction)
	var result: Array[Vector2i] = []
	for offset: Vector2i in _aoe_pattern_offsets(action):
		result.append(_rotated_offset(offset, rotation))
	return result

func _rotation_for_direction(direction: Vector2i) -> int:
	match _cardinal_direction(direction):
		Vector2i(0, 1):
			return 1
		Vector2i(-1, 0):
			return 2
		Vector2i(0, -1):
			return 3
		_:
			return 0

func _aoe_pattern_offsets(action: Dictionary) -> Array[Vector2i]:
	var raw_pattern: Array = action.get("pattern", DEFAULT_AOE_PATTERN)
	var offsets: Array[Vector2i] = []
	for offset_var: Variant in raw_pattern:
		match typeof(offset_var):
			TYPE_VECTOR2I:
				offsets.append(offset_var)
			TYPE_ARRAY:
				var pair: Array = offset_var
				if pair.size() >= 2:
					offsets.append(Vector2i(int(pair[0]), int(pair[1])))
			TYPE_DICTIONARY:
				var offset_dict: Dictionary = offset_var
				offsets.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
	if offsets.is_empty():
		offsets.append(Vector2i.ZERO)
	return offsets

func _vector2i_values(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _int_values(values: Array) -> Array[int]:
	var result: Array[int]
	for value: Variant in values:
		if typeof(value) == TYPE_INT:
			result.append(value)
	return result

func _dictionary_values(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for value: Variant in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(value)
	return result

func _rotated_offset(offset: Vector2i, rotation: int) -> Vector2i:
	match posmod(rotation, 4):
		1:
			return Vector2i(-offset.y, offset.x)
		2:
			return Vector2i(-offset.x, -offset.y)
		3:
			return Vector2i(offset.y, -offset.x)
		_:
			return offset

func _assign_enemy_intent(state: Dictionary, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var enemy_type: String = str(enemy.get("type", ""))
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	if _enemy_should_summon_wisps(state, enemy):
		enemy["intent"] = _zekarion_summon_intent()
		enemies[enemy_index] = enemy
		return
	var intents: Array = _scaled_enemy_intents(
		definition.get("intents", []),
		int(state.get("room_depth", 1))
	)
	if enemy_type == DragonBossLibrary.FIRE_BOSS_ID and bool(enemy.get("cinder_detonation_pending", false)) and _cinder_mark_traps(state, int(enemy.get("id", -1))).is_empty():
		enemy["cinder_detonation_pending"] = false
		enemies[enemy_index] = enemy
		state["enemies"] = enemies
	var forced_intent: Dictionary = _forced_dragon_intent(state, enemy, intents)
	if not forced_intent.is_empty():
		enemy["intent"] = forced_intent
		enemies[enemy_index] = enemy
		return
	var available_intents: Array = []
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if _dragon_intent_available(state, enemy, intent):
			available_intents.append(intent)
	intents = available_intents
	if intents.is_empty():
		return
	var tactical_options: Array[Dictionary] = _enemy_tactical_intent_options(
		state,
		enemy_index,
		enemy,
		definition,
		intents
	)
	if not tactical_options.is_empty():
		var tactical_total_weight: int = 0
		for option: Dictionary in tactical_options:
			tactical_total_weight += int(option.get("effective_weight", 0))
		if tactical_total_weight > 0:
			var tactical_roll: int = rng.randi_range(1, tactical_total_weight)
			var tactical_cursor: int = 0
			for option: Dictionary in tactical_options:
				tactical_cursor += int(option.get("effective_weight", 0))
				if tactical_roll <= tactical_cursor:
					enemy["intent"] = (option.get("intent", {}) as Dictionary).duplicate(true)
					enemies[enemy_index] = enemy
					return
	var total_weight: int = 0
	for intent: Dictionary in intents:
		total_weight += _objective_adjusted_intent_weight(state, intent)
	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for intent: Dictionary in intents:
		cursor += _objective_adjusted_intent_weight(state, intent)
		if roll <= cursor:
			enemy["intent"] = intent.duplicate(true)
			enemies[enemy_index] = enemy
			return
	enemy["intent"] = (intents[0] as Dictionary).duplicate(true)
	enemies[enemy_index] = enemy

func _objective_adjusted_intent_weight(state: Dictionary, intent: Dictionary) -> int:
	var weight: int = maxi(1, int(intent.get("weight", 1)))
	var objective: Dictionary = state.get("objective", {}) as Dictionary
	if str(objective.get("type", "")) == CombatObjectiveRules.REACH_EXIT and CombatObjectiveRules.is_control_intent(intent):
		weight *= 3
	return weight

func enemy_tactical_intent_options(state: Dictionary, enemy_index: int) -> Array[Dictionary]:
	var enemies: Array = state.get("enemies", []) as Array
	if enemy_index < 0 or enemy_index >= enemies.size() or typeof(enemies[enemy_index]) != TYPE_DICTIONARY:
		return []
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var intents: Array = _scaled_enemy_intents(
		definition.get("intents", []),
		int(state.get("room_depth", 1))
	)
	var available: Array = []
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if _dragon_intent_available(state, enemy, intent):
			available.append(intent)
	return _enemy_tactical_intent_options(state, enemy_index, enemy, definition, available)

func _enemy_tactical_intent_options(
	state: Dictionary,
	enemy_index: int,
	enemy: Dictionary,
	definition: Dictionary,
	intents: Array
) -> Array[Dictionary]:
	var profile: Dictionary = definition.get("ai_profile", {}) as Dictionary
	var role: String = str(profile.get("role", ""))
	if role.is_empty():
		return []
	var evaluated: Array[Dictionary] = []
	var best_score: int = -1000000
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = _enemy_tactical_intent_option(
			state,
			enemy_index,
			enemy,
			profile,
			intent_var as Dictionary
		)
		evaluated.append(option)
		if bool(option.get("eligible", false)):
			best_score = maxi(best_score, int(option.get("score", -1000000)))
	if best_score <= -1000000:
		return []
	var competitive: Array[Dictionary] = []
	for option: Dictionary in evaluated:
		var score: int = int(option.get("score", -1000000))
		if not bool(option.get("eligible", false)) or score < best_score - ENEMY_TACTICAL_SCORE_WINDOW:
			continue
		var intent: Dictionary = option.get("intent", {}) as Dictionary
		var score_factor: int = maxi(1, ENEMY_TACTICAL_SCORE_WINDOW + 1 - (best_score - score))
		option["effective_weight"] = _objective_adjusted_intent_weight(state, intent) * score_factor
		competitive.append(option)
	return competitive

func _enemy_tactical_intent_option(
	state: Dictionary,
	enemy_index: int,
	enemy: Dictionary,
	profile: Dictionary,
	intent: Dictionary
) -> Dictionary:
	var role: String = str(profile.get("role", "frontliner"))
	var preferred_range: int = maxi(1, int(profile.get("preferred_range", 1)))
	var retreat_distance: int = maxi(0, int(profile.get("retreat_distance", 0)))
	var plan: Dictionary = enemy_intent_plan(state, enemy_index, intent)
	var actions: Array = intent.get("actions", []) as Array
	var movement_type: String = ""
	var attack_action: Dictionary = {}
	var has_block: bool = false
	var has_stoneskin: bool = false
	var self_heal_amount: int = 0
	var heal_target_index: int = -1
	var guard_target_index: int = -1
	var group_guard_count: int = 0
	var group_guard_threatened: int = 0
	var group_guard_lowest_distance: int = 9999
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		if movement_type.is_empty() and action_type in ["move_toward", "move_away"]:
			movement_type = action_type
		if attack_action.is_empty() and action_type in ATTACK_ACTION_TYPES:
			attack_action = action
		match action_type:
			"block":
				has_block = int(action.get("amount", 0)) > 0
			"stoneskin":
				has_stoneskin = int(action.get("amount", 0)) > 0
			"heal_self":
				self_heal_amount = maxi(self_heal_amount, int(action.get("amount", 0)))
			"heal_ally":
				heal_target_index = _enemy_support_target_index(state, enemy_index, action)
			"guard_ally":
				if str(action.get("target_mode", "")) == "all_other_enemies":
					var group_guard: Dictionary = _enemy_tactical_group_guard_context(state, enemy_index)
					group_guard_count = int(group_guard.get("count", 0))
					group_guard_threatened = int(group_guard.get("threatened", 0))
					group_guard_lowest_distance = int(group_guard.get("lowest_distance", 9999))
				else:
					guard_target_index = _enemy_support_target_index(state, enemy_index, action)
	var target_tile: Vector2i = plan.get("target_tile", INVALID_TILE)
	if target_tile == INVALID_TILE:
		target_tile = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var distance_before: int = _enemy_distance_to_tile(enemy, target_tile)
	var destination: Vector2i = plan.get("destination", enemy.get("pos", Vector2i.ZERO))
	var destination_enemy: Dictionary = enemy.duplicate(true)
	destination_enemy["pos"] = destination
	var distance_after: int = _enemy_distance_to_tile(destination_enemy, target_tile)
	var path: Array[Vector2i] = _vector2i_values(plan.get("path", []))
	var moved: bool = path.size() > 1
	var closes_distance: bool = moved and distance_after < distance_before
	var increases_distance: bool = moved and distance_after > distance_before
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var player_distance_before: int = _enemy_distance_to_tile(enemy, player_pos)
	var player_distance_after: int = _enemy_distance_to_tile(destination_enemy, player_pos)
	var hp: int = int(enemy.get("hp", 0))
	var max_hp: int = maxi(1, int(enemy.get("max_hp", 1)))
	var missing_hp: int = maxi(0, max_hp - hp)
	var low_health: bool = hp * 2 <= max_hp
	var threatened: bool = mini(player_distance_before, player_distance_after) <= ENEMY_TACTICAL_THREAT_DISTANCE
	var useful: bool = false
	var score: int = 0
	var attack_available: bool = not attack_action.is_empty() and bool(plan.get("attack_available", false))
	if not attack_action.is_empty():
		if attack_available:
			score += 90 + mini(12, maxi(0, int(attack_action.get("damage", 0)))) * 2
			useful = true
		elif movement_type == "move_toward" and closes_distance:
			score += 30 + (distance_before - distance_after) * 6
			useful = true
		else:
			score -= 120
	if heal_target_index >= 0:
		var heal_target: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[heal_target_index] as Dictionary)
		var target_missing_hp: int = maxi(0, int(heal_target.get("max_hp", 1)) - int(heal_target.get("hp", 0)))
		score += 60 + target_missing_hp * 12
		useful = true
	if group_guard_count > 0:
		score += group_guard_count * 8 + group_guard_threatened * 34
		if group_guard_lowest_distance <= ENEMY_TACTICAL_THREAT_DISTANCE or role == "support":
			useful = true
	if guard_target_index >= 0:
		var guard_target: Dictionary = _normalized_enemy((state.get("enemies", []) as Array)[guard_target_index] as Dictionary)
		var guard_distance: int = _enemy_distance_to_tile(guard_target, player_pos)
		var guard_defense: int = int(guard_target.get("block", 0)) + int(guard_target.get("stoneskin", 0))
		score += 55 if guard_distance <= ENEMY_TACTICAL_THREAT_DISTANCE else 8
		if int(guard_target.get("hp", 0)) * 2 <= maxi(1, int(guard_target.get("max_hp", 1))):
			score += 40
		score -= mini(24, guard_defense * 3)
		if guard_distance <= ENEMY_TACTICAL_THREAT_DISTANCE or role == "support":
			useful = true
	if has_block or has_stoneskin:
		if threatened or low_health:
			score += 45 + (25 if low_health else 0)
			useful = true
		else:
			score -= 45
	if self_heal_amount > 0:
		if missing_hp > 0:
			score += 40 + mini(self_heal_amount, missing_hp) * 12
			useful = true
		else:
			score -= 24
	match movement_type:
		"move_toward":
			if closes_distance:
				match role:
					"frontliner", "protector", "controller":
						score += 55
					"skirmisher", "artillery":
						score += 45 if distance_before > preferred_range else -10
					"support":
						score += 20 if player_distance_before <= ENEMY_TACTICAL_CLOSE_DISTANCE else -90
		"move_away":
			if increases_distance and player_distance_before <= retreat_distance:
				score += 95
				useful = true
			else:
				score -= 100
	match role:
		"frontliner":
			if not attack_action.is_empty():
				score += 30
			if closes_distance:
				score += 25
		"protector":
			if not attack_action.is_empty():
				score += 15
			if group_guard_threatened > 0:
				score += 110
			if closes_distance and _enemy_tactical_screens_vulnerable_ally(state, enemy_index, destination_enemy):
				score += 35
		"skirmisher":
			if str(attack_action.get("type", "")) == "ranged" and attack_available:
				score += 40
			if movement_type == "move_away" and player_distance_before <= retreat_distance:
				score += 70
			if str(attack_action.get("type", "")) == "melee" and player_distance_before > ENEMY_TACTICAL_CLOSE_DISTANCE:
				score -= 55
		"artillery":
			if str(attack_action.get("type", "")) in ["ranged", "aoe"] and attack_available:
				score += 45
			if player_distance_before < preferred_range and has_block:
				score += 35
		"controller":
			if not attack_action.is_empty():
				score += 25
		"support":
			if heal_target_index >= 0:
				score += 75
			if guard_target_index >= 0 or group_guard_count > 0:
				score += 40
			if not attack_action.is_empty():
				if player_distance_before <= ENEMY_TACTICAL_CLOSE_DISTANCE:
					score += 35
				else:
					score -= 180
					useful = false if heal_target_index < 0 and guard_target_index < 0 and group_guard_count <= 0 else useful
	var previous_intent_id: String = str((enemy.get("intent", {}) as Dictionary).get("id", ""))
	if not previous_intent_id.is_empty() and previous_intent_id == str(intent.get("id", "")):
		score -= 8
	return {
		"intent": intent.duplicate(true),
		"intent_id": str(intent.get("id", "")),
		"role": role,
		"eligible": useful,
		"score": score,
		"attack_available": attack_available,
		"distance_before": distance_before,
		"distance_after": distance_after,
		"destination": destination,
		"path": path,
		"heal_target_index": heal_target_index,
		"guard_target_index": guard_target_index,
		"group_guard_count": group_guard_count,
		"group_guard_threatened": group_guard_threatened,
	}

func _enemy_tactical_group_guard_context(state: Dictionary, source_enemy_index: int) -> Dictionary:
	var enemies: Array = state.get("enemies", []) as Array
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var count: int = 0
	var threatened_count: int = 0
	var lowest_distance: int = 9999
	for index: int in range(enemies.size()):
		if index == source_enemy_index or typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(candidate.get("hp", 0)) <= 0:
			continue
		count += 1
		var distance: int = _enemy_distance_to_tile(candidate, player_pos)
		lowest_distance = mini(lowest_distance, distance)
		if distance <= ENEMY_TACTICAL_THREAT_DISTANCE:
			threatened_count += 1
	return {
		"count": count,
		"threatened": threatened_count,
		"lowest_distance": lowest_distance,
	}

func _enemy_tactical_screens_vulnerable_ally(state: Dictionary, source_enemy_index: int, source_at_destination: Dictionary) -> bool:
	if source_enemy_index < 0:
		return false
	var context: Dictionary = _enemy_protector_screening_context(state, source_at_destination)
	var score_by_tile: Dictionary = context.get("score_by_tile", {}) as Dictionary
	return int(score_by_tile.get(source_at_destination.get("pos", INVALID_TILE), 0)) > 0

func _intent_by_id(intents: Array, intent_id: String) -> Dictionary:
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if str(intent.get("id", "")) == intent_id:
			return intent.duplicate(true)
	return {}

func _forced_dragon_intent(state: Dictionary, enemy: Dictionary, intents: Array) -> Dictionary:
	var enemy_type: String = str(enemy.get("type", ""))
	if not DragonBossLibrary.is_dragon_boss_id(enemy_type) or enemy_type == DragonBossLibrary.LIGHTNING_BOSS_ID:
		return {}
	if enemy_type == DragonBossLibrary.FIRE_BOSS_ID and bool(enemy.get("cinder_detonation_pending", false)):
		var crownfire: Dictionary = _intent_by_id(intents, "crownfire")
		if not crownfire.is_empty():
			return crownfire
	if enemy_type == DragonBossLibrary.EARTH_BOSS_ID and _dragon_spires(state).is_empty():
		var stonewake: Dictionary = _intent_by_id(intents, "stonewake")
		if not stonewake.is_empty():
			return stonewake
	if bool(enemy.get("boss_mechanic_opened", false)):
		return {}
	return _intent_by_id(intents, DragonBossLibrary.opening_intent_id(enemy_type))

func _dragon_intent_available(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	var intent_id: String = str(intent.get("id", ""))
	match intent_id:
		"crownfire":
			return false
		"stonewake":
			return _dragon_spires(state).is_empty()
		"faultline":
			return not _dragon_spires(state).is_empty()
		"kindle_ground":
			return _cinder_mark_traps(state, int(enemy.get("id", -1))).is_empty()
		"crystal_mantle":
			return int(enemy.get("frost_armor", 0)) <= 0
		"last_eclipse":
			return int((state.get("umbra", {}) as Dictionary).get("boss_eclipse_activations", 0)) <= 0
	return true

func _scaled_enemy_intents(base_intents: Array, room_depth: int) -> Array:
	var intents: Array = []
	for intent_var: Variant in base_intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		intents.append(_scale_enemy_intent(intent_var as Dictionary, room_depth))
	return intents

func _scale_enemy_intent(base_intent: Dictionary, room_depth: int) -> Dictionary:
	var intent: Dictionary = base_intent.duplicate(true)
	var actions: Array = []
	for action_var: Variant in base_intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		actions.append(_scale_enemy_action_for_depth(action, room_depth))
	intent["actions"] = actions
	return intent

func _encounter_depth_for_room_depth(room_depth: int) -> int:
	return posmod(maxi(1, room_depth) - 1, DEPTHS_PER_SEQUENCE) + 1

func _depth_sequence_index(room_depth: int) -> int:
	return int((maxi(1, room_depth) - 1) / DEPTHS_PER_SEQUENCE)

func _scaled_enemy_max_hp(enemy_type: String, room_depth: int) -> int:
	var base_hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
	var local_scale: float = _local_enemy_hp_scale(room_depth)
	var scaled_hp: int = ceili(float(base_hp) * local_scale)
	var sequence_index: int = _depth_sequence_index(room_depth)
	if sequence_index <= 0:
		return scaled_hp
	scaled_hp = ceili(float(scaled_hp) * (1.0 + ENEMY_HP_SCALE_PER_SEQUENCE * float(sequence_index)))
	return scaled_hp + ENEMY_HP_FLAT_BONUS_PER_SEQUENCE * sequence_index

func _scale_enemy_action_for_depth(action: Dictionary, room_depth: int) -> Dictionary:
	var scaled: Dictionary = action.duplicate(true)
	var action_type: String = str(scaled.get("type", ""))
	var damage_delta: int = _local_enemy_damage_delta(room_depth)
	if damage_delta != 0 and (action_type in ATTACK_ACTION_TYPES or action_type == "lightning_strikes" or action_type in BOSS_DAMAGE_ACTION_TYPES) and scaled.has("damage"):
		scaled["damage"] = maxi(GameData.fixed_point_amount(1), int(scaled.get("damage", 0)) + damage_delta)
	var support_delta: int = _local_enemy_support_delta(room_depth)
	if support_delta != 0:
		if action_type == "block" or action_type == "stoneskin" or action_type == "guard_ally":
			scaled["amount"] = maxi(0, int(scaled.get("amount", 0)) + support_delta)
		elif action_type == "heal_self" or action_type == "heal_ally":
			scaled["amount"] = maxi(0, int(scaled.get("amount", 0)) + support_delta)
		elif action_type == "raise_terrain" and scaled.has("health"):
			scaled["health"] = maxi(GameData.fixed_point_amount(1), int(scaled.get("health", 0)) + support_delta)
	var sequence_index: int = _depth_sequence_index(room_depth)
	if sequence_index <= 0:
		return scaled
	var damage_bonus: int = ENEMY_DAMAGE_BONUS_BY_SEQUENCE[mini(sequence_index, ENEMY_DAMAGE_BONUS_BY_SEQUENCE.size() - 1)]
	var support_bonus: int = ENEMY_SUPPORT_BONUS_BY_SEQUENCE[mini(sequence_index, ENEMY_SUPPORT_BONUS_BY_SEQUENCE.size() - 1)]
	if action_type in ATTACK_ACTION_TYPES or action_type == "lightning_strikes" or action_type in BOSS_DAMAGE_ACTION_TYPES:
		if scaled.has("damage"):
			scaled["damage"] = int(scaled.get("damage", 0)) + damage_bonus
	if action_type == "block" or action_type == "stoneskin" or action_type == "guard_ally":
		scaled["amount"] = int(scaled.get("amount", 0)) + support_bonus
	elif action_type == "heal_self" or action_type == "heal_ally":
		scaled["amount"] = int(scaled.get("amount", 0)) + support_bonus
	elif action_type == "raise_terrain" and scaled.has("health"):
		scaled["health"] = int(scaled.get("health", 0)) + support_bonus
	return scaled

func _local_enemy_hp_scale(room_depth: int) -> float:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_HP_SCALE_DEPTH_ONE
		3:
			return ENEMY_HP_SCALE_DEPTH_THREE
		_:
			return 1.0

func _local_enemy_damage_delta(room_depth: int) -> int:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_DAMAGE_DELTA_DEPTH_ONE
		3:
			return ENEMY_DAMAGE_DELTA_DEPTH_THREE
		_:
			return 0

func _local_enemy_support_delta(room_depth: int) -> int:
	match _encounter_depth_for_room_depth(room_depth):
		1:
			return ENEMY_SUPPORT_DELTA_DEPTH_ONE
		3:
			return ENEMY_SUPPORT_DELTA_DEPTH_THREE
		_:
			return 0

func _apply_revealed_intent_blocks(state: Dictionary) -> Dictionary:
	# Intent can preview a future guard, but block only becomes real when that
	# actor reaches its activation and resolves the block action.
	return state.duplicate(true)

func _preview_block_for_intent(intent: Dictionary) -> int:
	var total: int = 0
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var as Dictionary
		if str(action.get("type", "")) == "block":
			total += int(action.get("amount", 0))
	return total

func enemy_intent_plan(state: Dictionary, enemy_index: int, intent_override: Dictionary = {}, movement_disabled: bool = false, attack_disabled: bool = false) -> Dictionary:
	var performance_total_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		_record_runtime_performance_phase("enemy_plan_total", performance_total_started)
		return {}
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	if int(enemy.get("hp", 0)) <= 0:
		_record_runtime_performance_phase("enemy_plan_total", performance_total_started)
		return {}
	var intent: Dictionary = intent_override if not intent_override.is_empty() else enemy.get("intent", {})
	var actions: Array = intent.get("actions", [])
	var movement_index: int = -1
	var attack_index: int = -1
	var pattern_attack_index: int = -1
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action_type: String = str((actions[index] as Dictionary).get("type", ""))
		if movement_index < 0 and action_type in ["move_toward", "move_away"]:
			movement_index = index
		if attack_index < 0 and action_type in ATTACK_ACTION_TYPES:
			attack_index = index
		if pattern_attack_index < 0 and (action_type == "lightning_strikes" or action_type in BOSS_PATTERN_ACTION_TYPES):
			pattern_attack_index = index
	var movement_action: Dictionary = {}
	if movement_index >= 0:
		movement_action = (actions[movement_index] as Dictionary).duplicate(true)
	var attack_action: Dictionary = {}
	if attack_index >= 0:
		attack_action = (actions[attack_index] as Dictionary).duplicate(true)
	var support_target_tile: Vector2i = INVALID_TILE
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var support_action: Dictionary = action_var as Dictionary
		if str(support_action.get("type", "")) not in ENEMY_SUPPORT_ACTION_TYPES:
			continue
		var support_target_index: int = _enemy_support_target_index(state, enemy_index, support_action)
		if support_target_index >= 0 and support_target_index < enemies.size():
			support_target_tile = (enemies[support_target_index] as Dictionary).get("pos", INVALID_TILE)
		break
	var attack_resolvable: bool = attack_action.is_empty() or enemy_action_can_resolve(state, attack_action)
	var planning_attack: Dictionary = attack_action
	if planning_attack.is_empty():
		planning_attack = {"type": "melee", "range": 1, "damage": 0}
	var move_range: int = 0 if movement_disabled else int(movement_action.get("range", 0))
	var movement_type: String = str(movement_action.get("type", "move_toward"))
	# Support-only intents already have a legal ally target at the current anchor.
	# Do not feed their authored move_toward step into the fallback melee planner:
	# that made back-line healers creep toward the player while healing an ally
	# they could already reach.
	var support_holds_position: bool = (
		attack_index < 0
		and support_target_tile != INVALID_TILE
		and movement_type == "move_toward"
	)
	if support_holds_position:
		move_range = 0
	var performance_phase_started: int = _record_runtime_performance_phase("enemy_plan_setup", performance_total_started)
	var actual_records: Array[Dictionary] = _enemy_actual_path_records(state, enemy, move_range)
	performance_phase_started = _record_runtime_performance_phase("enemy_plan_actual_paths", performance_phase_started)
	var pure_retreat: bool = movement_type == "move_away" and movement_index >= 0 and attack_index < 0
	var protector_screening_context: Dictionary = (
		_enemy_protector_screening_context(state, enemy)
		if movement_type == "move_toward" and move_range > 0
		else {}
	)
	var direct_candidate: Dictionary = _best_enemy_retreat_candidate(state, enemy, actual_records) if pure_retreat else _best_enemy_direct_attack_candidate(
		state,
		enemy,
		planning_attack,
		actual_records,
		movement_type,
		protector_screening_context
	)
	performance_phase_started = _record_runtime_performance_phase("enemy_plan_direct_candidate", performance_phase_started)
	var protector_screening_candidate: Dictionary = (
		_best_enemy_protector_screening_candidate(state, enemy, actual_records, protector_screening_context)
		if direct_candidate.is_empty() and not pure_retreat
		else {}
	)
	performance_phase_started = _record_runtime_performance_phase("enemy_plan_protector_screen", performance_phase_started)
	var target: Dictionary = {}
	var actual_path: Array[Vector2i] = _vector2i_values([enemy.get("pos", Vector2i.ZERO)])
	var future_route: Array[Vector2i] = actual_path.duplicate()
	var route_cost: int = 0
	var attack_available: bool = false
	if not direct_candidate.is_empty():
		target = (direct_candidate.get("target", {}) as Dictionary).duplicate(true)
		actual_path = _vector2i_values(direct_candidate.get("path", []))
		future_route = actual_path.duplicate()
		route_cost = int(direct_candidate.get("cost", 0))
		attack_available = not pure_retreat
	elif not protector_screening_candidate.is_empty():
		# A protector that cannot attack this activation may spend its movement
		# intercepting the shortest player-to-backliner route. Keep the selected
		# endpoint as the current-activation path instead of letting a later
		# attack route pull the Warden back off the lane it meant to block.
		actual_path = _vector2i_values(protector_screening_candidate.get("path", []))
		future_route = actual_path.duplicate()
		route_cost = int(protector_screening_candidate.get("cost", 0))
	else:
		# The future route also selects among the player and illusions and evaluates
		# every legal footprint anchor. Even when this activation has no movement,
		# resolution uses its first reachable terrain blocker; replacing it with a
		# player-only tile path changes which obstacle redirected and large enemies
		# strike. Preserve that plan and optimize its implementation, not its rules.
		var future_candidate: Dictionary = {} if pure_retreat else _best_enemy_future_route_candidate(state, enemy, planning_attack, move_range)
		performance_phase_started = _record_runtime_performance_phase("enemy_plan_future_candidate_total", performance_phase_started)
		if not future_candidate.is_empty():
			target = (future_candidate.get("target", {}) as Dictionary).duplicate(true)
			future_route = _vector2i_values(future_candidate.get("route", []))
			actual_path = _enemy_actual_prefix_for_route(state, enemy, future_route, move_range)
			route_cost = int(future_candidate.get("cost", 0))
	var finalize_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var finalize_phase_started: int = finalize_started
	if target.is_empty():
		target = _closest_enemy_target(state, enemy)
	finalize_phase_started = _record_runtime_performance_phase("enemy_plan_target_fallback", finalize_phase_started)
	var destination: Vector2i = actual_path[actual_path.size() - 1] if not actual_path.is_empty() else enemy.get("pos", Vector2i.ZERO)
	var preview_enemy: Dictionary = enemy.duplicate(true)
	preview_enemy["pos"] = destination
	var preview_state: Dictionary = _state_with_enemy_anchor(state, preview_enemy, destination)
	finalize_phase_started = _record_runtime_performance_phase("enemy_plan_preview_state", finalize_phase_started)
	var target_reachable: bool = not target.is_empty() and _enemy_action_reaches_target(preview_state, preview_enemy, planning_attack, target)
	finalize_phase_started = _record_runtime_performance_phase("enemy_plan_target_reachable", finalize_phase_started)
	var terrain_index: int = -1
	var trap_index: int = -1
	var trap_tile: Vector2i = INVALID_TILE
	if attack_index >= 0 and not attack_disabled and attack_resolvable:
		trap_index = _best_enemy_trap_attack_index(preview_state, enemy_index, planning_attack)
		if trap_index >= 0:
			trap_tile = ((preview_state.get("traps", []) as Array)[trap_index] as Dictionary).get("pos", INVALID_TILE)
		if trap_index < 0 and not target_reachable:
			terrain_index = _planned_blocking_terrain_index(preview_state, preview_enemy, planning_attack, future_route)
	finalize_phase_started = _record_runtime_performance_phase("enemy_plan_obstacle_targets", finalize_phase_started)
	var projected_attack_tiles: Array[Vector2i] = _vector2i_values([])
	var projected_attack_target: Vector2i = INVALID_TILE
	if attack_index >= 0 and not attack_disabled and attack_resolvable:
		projected_attack_tiles = _enemy_projected_attack_tiles(
			preview_state,
			preview_enemy,
			planning_attack,
			target if target_reachable else {},
			terrain_index,
			trap_index
		)
		if trap_index >= 0:
			projected_attack_target = trap_tile
		elif terrain_index >= 0:
			var blocking_terrain: Dictionary = _normalized_terrain((preview_state.get("terrain", []) as Array)[terrain_index])
			projected_attack_target = blocking_terrain.get("pos", INVALID_TILE)
		elif target_reachable:
			projected_attack_target = target.get("pos", INVALID_TILE)
	elif pattern_attack_index >= 0 and not attack_disabled:
		var pattern_action: Dictionary = actions[pattern_attack_index]
		if str(pattern_action.get("type", "")) == "lightning_strikes":
			projected_attack_tiles = _lightning_strike_tiles(preview_state, preview_enemy, pattern_action)
		else:
			projected_attack_tiles = _boss_action_threat_tiles(preview_state, preview_enemy, pattern_action)
		attack_available = not _actor_targets_in_tiles(preview_state, projected_attack_tiles).is_empty()
		target = {}
	_record_runtime_performance_phase("enemy_plan_projected_attack", finalize_phase_started)
	_record_runtime_performance_phase("enemy_plan_finalize_total", finalize_started)
	_record_runtime_performance_phase("enemy_plan_total", performance_total_started)
	return {
		"enemy_index": enemy_index,
		"enemy_key": _enemy_key(enemy),
		"movement_action_index": movement_index,
		"attack_action_index": attack_index,
		"attack_action": attack_action,
		"target": target,
		"target_key": str(target.get("key", "")),
		"target_tile": target.get("pos", INVALID_TILE),
		"support_target_tile": support_target_tile,
		"path": actual_path,
		"route": future_route,
		"destination": destination,
		"route_cost": route_cost,
		"attack_available": not attack_disabled and (
			(attack_index >= 0 and attack_resolvable and attack_available and target_reachable)
			or (attack_index < 0 and pattern_attack_index >= 0 and attack_available)
		),
		"blocking_terrain_index": terrain_index,
		"trap_attack_index": trap_index,
		"trap_attack_tile": trap_tile,
		"projected_attack_target": projected_attack_target,
		"projected_attack": projected_attack_tiles
	}

func _enemy_actual_path_records(state: Dictionary, enemy: Dictionary, move_range: int) -> Array[Dictionary]:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var start_path: Array[Vector2i] = _vector2i_values([start])
	var records: Array[Dictionary]
	records.append({"tile": start, "path": start_path, "trap_cost": 0, "steps": 0})
	if move_range <= 0:
		return records
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, false)
	var frontier: Array[Dictionary]
	frontier.append(records[0].duplicate(true))
	for step: int in range(1, move_range + 1):
		var next_by_tile: Dictionary = {}
		for record: Dictionary in frontier:
			var current: Vector2i = record.get("tile", start)
			var current_path: Array[Vector2i] = _vector2i_values(record.get("path", []))
			for direction: Vector2i in PathUtils.DIRS_4:
				var candidate_tile: Vector2i = current + direction
				if current_path.has(candidate_tile):
					continue
				if not _enemy_can_occupy_anchor(state, enemy, candidate_tile, occupied):
					continue
				var candidate_path: Array[Vector2i] = current_path.duplicate()
				candidate_path.append(candidate_tile)
				var candidate: Dictionary = {
					"tile": candidate_tile,
					"path": candidate_path,
					"trap_cost": int(record.get("trap_cost", 0)) + _enemy_anchor_trap_penalty(state, enemy, candidate_tile),
					"steps": step
				}
				if not next_by_tile.has(candidate_tile) or _enemy_actual_record_precedes(candidate, next_by_tile[candidate_tile] as Dictionary):
					next_by_tile[candidate_tile] = candidate
		frontier.clear()
		for tile: Vector2i in _sorted_tiles_from_lookup(next_by_tile):
			var next_record: Dictionary = next_by_tile[tile]
			frontier.append(next_record)
			records.append(next_record)
	return records

func _enemy_actual_record_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_cost: int = int(candidate.get("trap_cost", 0))
	var incumbent_cost: int = int(incumbent.get("trap_cost", 0))
	if candidate_cost != incumbent_cost:
		return candidate_cost < incumbent_cost
	return _enemy_path_precedes(_vector2i_values(candidate.get("path", [])), _vector2i_values(incumbent.get("path", [])))

func _best_enemy_retreat_candidate(state: Dictionary, enemy: Dictionary, path_records: Array[Dictionary]) -> Dictionary:
	var target: Dictionary = _closest_enemy_target(state, enemy)
	if target.is_empty():
		return {}
	var best: Dictionary = {}
	for record: Dictionary in path_records:
		var destination: Vector2i = record.get("tile", enemy.get("pos", Vector2i.ZERO))
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = destination
		var candidate: Dictionary = {
			"target": target,
			"path": record.get("path", []),
			"destination": destination,
			"trap_cost": int(record.get("trap_cost", 0)),
			"steps": int(record.get("steps", 0)),
			"separation": _enemy_distance_to_tile(candidate_enemy, target.get("pos", Vector2i.ZERO)),
			"regression_cost": _enemy_path_regression_cost(
				enemy,
				_vector2i_values(record.get("path", [])),
				target.get("pos", Vector2i.ZERO),
				false
			),
			"cost": int(record.get("trap_cost", 0)) + int(record.get("steps", 0))
		}
		if best.is_empty() or _enemy_retreat_candidate_precedes(candidate, best):
			best = candidate
	return best

func _enemy_retreat_candidate_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_trap_cost: int = int(candidate.get("trap_cost", 0))
	var incumbent_trap_cost: int = int(incumbent.get("trap_cost", 0))
	if candidate_trap_cost != incumbent_trap_cost:
		return candidate_trap_cost < incumbent_trap_cost
	var candidate_separation: int = int(candidate.get("separation", 0))
	var incumbent_separation: int = int(incumbent.get("separation", 0))
	if candidate_separation != incumbent_separation:
		return candidate_separation > incumbent_separation
	var candidate_steps: int = int(candidate.get("steps", 0))
	var incumbent_steps: int = int(incumbent.get("steps", 0))
	if candidate_steps != incumbent_steps:
		return candidate_steps < incumbent_steps
	var candidate_regression: int = int(candidate.get("regression_cost", 0))
	var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
	if candidate_regression != incumbent_regression:
		return candidate_regression < incumbent_regression
	var candidate_destination: Vector2i = candidate.get("destination", INVALID_TILE)
	var incumbent_destination: Vector2i = incumbent.get("destination", INVALID_TILE)
	if candidate_destination != incumbent_destination:
		return _tile_precedes(candidate_destination, incumbent_destination)
	return _enemy_path_precedes(_vector2i_values(candidate.get("path", [])), _vector2i_values(incumbent.get("path", [])))

func _enemy_protector_screening_context(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var profile: Dictionary = GameData.enemy_def(str(enemy.get("type", ""))).get("ai_profile", {}) as Dictionary
	if str(profile.get("role", "")) != "protector":
		return {}
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var terrain_occupied: Dictionary = _occupied_terrain_tiles(state)
	var score_by_tile: Dictionary = {}
	var ally_index_by_tile: Dictionary = {}
	var source_id: int = int(enemy.get("id", -1))
	var enemies: Array = state.get("enemies", []) as Array
	for ally_index: int in range(enemies.size()):
		if typeof(enemies[ally_index]) != TYPE_DICTIONARY:
			continue
		var ally: Dictionary = _normalized_enemy(enemies[ally_index] as Dictionary)
		if int(ally.get("id", -1)) == source_id or int(ally.get("hp", 0)) <= 0:
			continue
		var ally_profile: Dictionary = GameData.enemy_def(str(ally.get("type", ""))).get("ai_profile", {}) as Dictionary
		var ally_role: String = str(ally_profile.get("role", ""))
		if ally_role not in ["support", "artillery", "skirmisher"]:
			continue
		var ally_pos: Vector2i = ally.get("pos", INVALID_TILE)
		if ally_pos == INVALID_TILE:
			continue
		# Use the board's deterministic shortest terrain route, but deliberately
		# ignore unit occupancy: the question is where the Warden can interpose
		# before the player reaches this backliner, not where the player can walk
		# while the current formation remains frozen in place.
		var intercept_route: Array[Vector2i] = PathUtils.find_path(
			state.get("grid", []),
			player_pos,
			ally_pos,
			terrain_occupied,
			true
		)
		if intercept_route.size() < 3:
			continue
		var role_priority: int = 60 if ally_role == "support" else (40 if ally_role == "artillery" else 20)
		var missing_hp: int = maxi(0, int(ally.get("max_hp", 1)) - int(ally.get("hp", 0)))
		for route_index: int in range(1, intercept_route.size() - 1):
			var tile: Vector2i = intercept_route[route_index]
			# Earlier route tiles intercept the player sooner. Role and injury break
			# ties between allies without making a rearward tile beat a stronger
			# forward screen on the same lane.
			var screen_score: int = 100000 - route_index * 100 + role_priority + mini(19, missing_hp)
			if screen_score <= int(score_by_tile.get(tile, -1)):
				continue
			score_by_tile[tile] = screen_score
			ally_index_by_tile[tile] = ally_index
	return {
		"score_by_tile": score_by_tile,
		"ally_index_by_tile": ally_index_by_tile,
	}

func _best_enemy_protector_screening_candidate(
	state: Dictionary,
	enemy: Dictionary,
	path_records: Array[Dictionary],
	context: Dictionary
) -> Dictionary:
	var score_by_tile: Dictionary = context.get("score_by_tile", {}) as Dictionary
	if score_by_tile.is_empty():
		return {}
	var ally_index_by_tile: Dictionary = context.get("ally_index_by_tile", {}) as Dictionary
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var best: Dictionary = {}
	for record: Dictionary in path_records:
		var destination: Vector2i = record.get("tile", enemy.get("pos", Vector2i.ZERO))
		var screen_score: int = int(score_by_tile.get(destination, 0))
		if screen_score <= 0:
			continue
		var candidate: Dictionary = record.duplicate(true)
		candidate["destination"] = destination
		candidate["screening_score"] = screen_score
		candidate["screening_ally_index"] = int(ally_index_by_tile.get(destination, -1))
		candidate["player_distance"] = PathUtils.manhattan(destination, player_pos)
		candidate["regression_cost"] = _enemy_path_regression_cost(
			enemy,
			_vector2i_values(record.get("path", [])),
			player_pos,
			true
		)
		candidate["cost"] = int(record.get("trap_cost", 0)) + int(record.get("steps", 0))
		if best.is_empty() or _enemy_protector_screening_candidate_precedes(candidate, best):
			best = candidate
	return best

func _enemy_protector_screening_candidate_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_trap_cost: int = int(candidate.get("trap_cost", 0))
	var incumbent_trap_cost: int = int(incumbent.get("trap_cost", 0))
	if candidate_trap_cost != incumbent_trap_cost:
		return candidate_trap_cost < incumbent_trap_cost
	var candidate_score: int = int(candidate.get("screening_score", 0))
	var incumbent_score: int = int(incumbent.get("screening_score", 0))
	if candidate_score != incumbent_score:
		return candidate_score > incumbent_score
	var candidate_distance: int = int(candidate.get("player_distance", 9999))
	var incumbent_distance: int = int(incumbent.get("player_distance", 9999))
	if candidate_distance != incumbent_distance:
		return candidate_distance < incumbent_distance
	var candidate_steps: int = int(candidate.get("steps", 0))
	var incumbent_steps: int = int(incumbent.get("steps", 0))
	if candidate_steps != incumbent_steps:
		return candidate_steps < incumbent_steps
	var candidate_regression: int = int(candidate.get("regression_cost", 0))
	var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
	if candidate_regression != incumbent_regression:
		return candidate_regression < incumbent_regression
	var candidate_destination: Vector2i = candidate.get("destination", INVALID_TILE)
	var incumbent_destination: Vector2i = incumbent.get("destination", INVALID_TILE)
	if candidate_destination != incumbent_destination:
		return _tile_precedes(candidate_destination, incumbent_destination)
	return _enemy_path_precedes(_vector2i_values(candidate.get("path", [])), _vector2i_values(incumbent.get("path", [])))

func _best_enemy_direct_attack_candidate(
	state: Dictionary,
	enemy: Dictionary,
	attack_action: Dictionary,
	path_records: Array[Dictionary],
	movement_type: String,
	protector_screening_context: Dictionary = {}
) -> Dictionary:
	var best: Dictionary = {}
	for target: Dictionary in _actor_targets(state):
		for record: Dictionary in path_records:
			var destination: Vector2i = record.get("tile", enemy.get("pos", Vector2i.ZERO))
			var candidate_enemy: Dictionary = enemy.duplicate(true)
			candidate_enemy["pos"] = destination
			# Reach checks read the moved enemy plus the unchanged grid/actor targets.
			# They do not need a deep copy of the combat state at every anchor.
			if not _enemy_action_reaches_target(state, candidate_enemy, attack_action, target):
				continue
			var candidate: Dictionary = {
				"target": target,
				"path": record.get("path", []),
				"destination": destination,
				"trap_cost": int(record.get("trap_cost", 0)),
				"steps": int(record.get("steps", 0)),
				"target_distance": _enemy_distance_to_tile(enemy, target.get("pos", Vector2i.ZERO)),
				"separation": _enemy_distance_to_tile(candidate_enemy, target.get("pos", Vector2i.ZERO)),
				"regression_cost": _enemy_path_regression_cost(
					enemy,
					_vector2i_values(record.get("path", [])),
					target.get("pos", Vector2i.ZERO),
					movement_type != "move_away"
				),
				"exit_block_score": _objective_exit_block_score(state, destination),
				"protector_screen_score": int((protector_screening_context.get("score_by_tile", {}) as Dictionary).get(destination, 0)),
				"cost": int(record.get("trap_cost", 0)) + int(record.get("steps", 0))
			}
			if best.is_empty() or _enemy_direct_attack_candidate_precedes(candidate, best, movement_type):
				best = candidate
	return best

func _enemy_direct_attack_candidate_precedes(candidate: Dictionary, incumbent: Dictionary, movement_type: String) -> bool:
	if movement_type == "move_away":
		var candidate_trap_cost: int = int(candidate.get("trap_cost", 0))
		var incumbent_trap_cost: int = int(incumbent.get("trap_cost", 0))
		if candidate_trap_cost != incumbent_trap_cost:
			return candidate_trap_cost < incumbent_trap_cost
		var candidate_target_distance: int = int(candidate.get("target_distance", 9999))
		var incumbent_target_distance: int = int(incumbent.get("target_distance", 9999))
		if candidate_target_distance != incumbent_target_distance:
			return candidate_target_distance < incumbent_target_distance
		var target_order: int = _compare_actor_targets(candidate.get("target", {}), incumbent.get("target", {}))
		if target_order != 0:
			return target_order < 0
		var candidate_regression: int = int(candidate.get("regression_cost", 0))
		var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
		if candidate_regression != incumbent_regression:
			return candidate_regression < incumbent_regression
		var candidate_separation: int = int(candidate.get("separation", 0))
		var incumbent_separation: int = int(incumbent.get("separation", 0))
		if candidate_separation != incumbent_separation:
			return candidate_separation > incumbent_separation
		var candidate_steps: int = int(candidate.get("steps", 0))
		var incumbent_steps: int = int(incumbent.get("steps", 0))
		if candidate_steps != incumbent_steps:
			return candidate_steps < incumbent_steps
	else:
		var candidate_steps: int = int(candidate.get("steps", 0))
		var incumbent_steps: int = int(incumbent.get("steps", 0))
		if candidate_steps != incumbent_steps:
			return candidate_steps < incumbent_steps
		var candidate_trap_cost: int = int(candidate.get("trap_cost", 0))
		var incumbent_trap_cost: int = int(incumbent.get("trap_cost", 0))
		if candidate_trap_cost != incumbent_trap_cost:
			return candidate_trap_cost < incumbent_trap_cost
		var candidate_screen_score: int = int(candidate.get("protector_screen_score", 0))
		var incumbent_screen_score: int = int(incumbent.get("protector_screen_score", 0))
		if candidate_screen_score != incumbent_screen_score:
			return candidate_screen_score > incumbent_screen_score
		var candidate_regression: int = int(candidate.get("regression_cost", 0))
		var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
		if candidate_regression != incumbent_regression:
			return candidate_regression < incumbent_regression
		var candidate_target_distance: int = int(candidate.get("target_distance", 9999))
		var incumbent_target_distance: int = int(incumbent.get("target_distance", 9999))
		if candidate_target_distance != incumbent_target_distance:
			return candidate_target_distance < incumbent_target_distance
		var target_order: int = _compare_actor_targets(candidate.get("target", {}), incumbent.get("target", {}))
		if target_order != 0:
			return target_order < 0
	var candidate_exit_block_score: int = int(candidate.get("exit_block_score", 9999))
	var incumbent_exit_block_score: int = int(incumbent.get("exit_block_score", 9999))
	if candidate_exit_block_score != incumbent_exit_block_score:
		return candidate_exit_block_score < incumbent_exit_block_score
	var candidate_destination: Vector2i = candidate.get("destination", INVALID_TILE)
	var incumbent_destination: Vector2i = incumbent.get("destination", INVALID_TILE)
	if candidate_destination != incumbent_destination:
		return _tile_precedes(candidate_destination, incumbent_destination)
	return _enemy_path_precedes(_vector2i_values(candidate.get("path", [])), _vector2i_values(incumbent.get("path", [])))

func _best_enemy_future_route_candidate(state: Dictionary, enemy: Dictionary, attack_action: Dictionary, move_range: int) -> Dictionary:
	var best: Dictionary = {}
	# Each route to a possible target explores the same board anchors. Cache the
	# target-independent occupancy facts once for this planning call rather than
	# rescanning terrain, enemies, traps, and actor targets for every neighboring
	# edge in the search.
	var context_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	var planning_context: Dictionary = _enemy_future_planning_context(state, enemy)
	_record_runtime_performance_phase("enemy_future_context", context_started)
	for target: Dictionary in planning_context.get("actor_targets", []):
		var search_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
		var route_record: Dictionary = _enemy_future_route_to_attack(state, enemy, attack_action, target, move_range, planning_context)
		_record_runtime_performance_phase("enemy_future_search", search_started)
		if route_record.is_empty():
			continue
		var candidate: Dictionary = route_record.duplicate(true)
		candidate["target"] = target
		candidate["target_distance"] = _enemy_distance_to_tile(enemy, target.get("pos", Vector2i.ZERO))
		var route: Array[Vector2i] = _vector2i_values(candidate.get("route", []))
		var destination_index: int = mini(maxi(0, move_range), maxi(0, route.size() - 1))
		candidate["exit_block_score"] = _objective_exit_block_score(state, route[destination_index] if not route.is_empty() else enemy.get("pos", Vector2i.ZERO))
		if best.is_empty() or _enemy_future_route_candidate_precedes(candidate, best):
			best = candidate
	return best

func _enemy_future_route_candidate_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_cost: int = int(candidate.get("cost", 999999))
	var incumbent_cost: int = int(incumbent.get("cost", 999999))
	var candidate_open_prefix: int = int(candidate.get("open_prefix_steps", 0))
	var incumbent_open_prefix: int = int(incumbent.get("open_prefix_steps", 0))
	if candidate_cost != incumbent_cost:
		return candidate_cost < incumbent_cost
	if candidate_open_prefix != incumbent_open_prefix:
		return candidate_open_prefix > incumbent_open_prefix
	var candidate_prefix_distance: int = int(candidate.get("prefix_distance_cost", 0))
	var incumbent_prefix_distance: int = int(incumbent.get("prefix_distance_cost", 0))
	if candidate_prefix_distance != incumbent_prefix_distance:
		return candidate_prefix_distance < incumbent_prefix_distance
	var candidate_regression: int = int(candidate.get("regression_cost", 0))
	var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
	if candidate_regression != incumbent_regression:
		return candidate_regression < incumbent_regression
	var candidate_distance: int = int(candidate.get("target_distance", 9999))
	var incumbent_distance: int = int(incumbent.get("target_distance", 9999))
	if candidate_distance != incumbent_distance:
		return candidate_distance < incumbent_distance
	var target_order: int = _compare_actor_targets(candidate.get("target", {}), incumbent.get("target", {}))
	if target_order != 0:
		return target_order < 0
	var candidate_exit_block_score: int = int(candidate.get("exit_block_score", 9999))
	var incumbent_exit_block_score: int = int(incumbent.get("exit_block_score", 9999))
	if candidate_exit_block_score != incumbent_exit_block_score:
		return candidate_exit_block_score < incumbent_exit_block_score
	return _enemy_path_precedes(_vector2i_values(candidate.get("route", [])), _vector2i_values(incumbent.get("route", [])))

func _objective_exit_block_score(state: Dictionary, destination: Vector2i) -> int:
	var objective: Dictionary = state.get("objective", {}) as Dictionary
	if str(objective.get("type", "")) != CombatObjectiveRules.REACH_EXIT:
		return 9999
	var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var best_score: int = 9999
	for exit_tile: Vector2i in CombatObjectiveRules.exit_target_tiles(objective):
		var score: int = PathUtils.manhattan(destination, exit_tile)
		var player_route: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), player_tile, exit_tile, {})
		if player_route.has(destination):
			score -= 20
		best_score = mini(best_score, score)
	return best_score

func _enemy_future_route_to_attack(state: Dictionary, enemy: Dictionary, attack_action: Dictionary, target: Dictionary, move_range: int, planning_context: Dictionary) -> Dictionary:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var start_path: Array[Vector2i] = _vector2i_values([start])
	var open: Array[Dictionary]
	open.append({"tile": start, "cost": 0, "steps": 0, "route": start_path, "open_prefix_steps": 0, "prefix_blocked": false, "regression_cost": 0, "prefix_distance_cost": 0})
	var best_by_tile: Dictionary = {start: open[0]}
	var closed: Dictionary = {}
	while not open.is_empty():
		var best_open_index: int = _enemy_best_open_route_index(open)
		var current: Dictionary = open[best_open_index]
		open.remove_at(best_open_index)
		var current_tile: Vector2i = current.get("tile", start)
		if closed.has(current_tile):
			continue
		closed[current_tile] = true
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = current_tile
		var anchor_details: Dictionary = _enemy_future_anchor_details(state, enemy, current_tile, planning_context)
		if bool(anchor_details.get("dynamically_open", false)) and _enemy_action_reaches_target(state, candidate_enemy, attack_action, target):
			return current
		for direction: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current_tile + direction
			if closed.has(next_tile):
				continue
			var next_anchor_details: Dictionary = _enemy_future_anchor_details(state, enemy, next_tile, planning_context)
			if not bool(next_anchor_details.get("in_grid", false)):
				continue
			var step_cost: int = _enemy_future_anchor_step_cost(state, next_anchor_details, attack_action, move_range)
			if step_cost < 0:
				continue
			var route: Array[Vector2i] = _vector2i_values(current.get("route", []))
			if route.has(next_tile):
				continue
			var next_route: Array[Vector2i] = route.duplicate()
			next_route.append(next_tile)
			var current_enemy: Dictionary = enemy.duplicate(true)
			current_enemy["pos"] = current_tile
			var next_enemy: Dictionary = enemy.duplicate(true)
			next_enemy["pos"] = next_tile
			var current_target_distance: int = _enemy_distance_to_tile(current_enemy, target.get("pos", Vector2i.ZERO))
			var next_target_distance: int = _enemy_distance_to_tile(next_enemy, target.get("pos", Vector2i.ZERO))
			var regression_cost: int = int(current.get("regression_cost", 0)) + maxi(0, next_target_distance - current_target_distance)
			var next_steps: int = int(current.get("steps", 0)) + 1
			var prefix_distance_cost: int = int(current.get("prefix_distance_cost", 0))
			if next_steps <= move_range:
				# Weight earlier steps more heavily so equal-cost routes postpone a
				# necessary detour until the obstacle is actually near. Previously a
				# distant blocker could make the first activation move away, sideways,
				# and back even though direct progress remained open for several tiles.
				prefix_distance_cost += next_target_distance * (move_range - next_steps + 1)
			var prefix_blocked: bool = bool(current.get("prefix_blocked", false))
			var open_prefix_steps: int = int(current.get("open_prefix_steps", 0))
			if not prefix_blocked and open_prefix_steps < move_range:
				if bool(next_anchor_details.get("dynamically_open", false)):
					open_prefix_steps += 1
				else:
					prefix_blocked = true
			var next_record: Dictionary = {
				"tile": next_tile,
				"cost": int(current.get("cost", 0)) + step_cost,
				"steps": next_steps,
				"route": next_route,
				"open_prefix_steps": open_prefix_steps,
				"prefix_blocked": prefix_blocked,
				"regression_cost": regression_cost,
				"prefix_distance_cost": prefix_distance_cost
			}
			if best_by_tile.has(next_tile) and not _enemy_route_record_precedes(next_record, best_by_tile[next_tile] as Dictionary):
				continue
			best_by_tile[next_tile] = next_record
			open.append(next_record)
	return {}

func _enemy_best_open_route_index(open: Array[Dictionary]) -> int:
	var best_index: int = 0
	for index: int in range(1, open.size()):
		if _enemy_route_record_precedes(open[index], open[best_index]):
			best_index = index
	return best_index

func _enemy_route_record_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var candidate_cost: int = int(candidate.get("cost", 999999))
	var incumbent_cost: int = int(incumbent.get("cost", 999999))
	var candidate_open_prefix: int = int(candidate.get("open_prefix_steps", 0))
	var incumbent_open_prefix: int = int(incumbent.get("open_prefix_steps", 0))
	if candidate_cost != incumbent_cost:
		return candidate_cost < incumbent_cost
	if candidate_open_prefix != incumbent_open_prefix:
		return candidate_open_prefix > incumbent_open_prefix
	var candidate_prefix_distance: int = int(candidate.get("prefix_distance_cost", 0))
	var incumbent_prefix_distance: int = int(incumbent.get("prefix_distance_cost", 0))
	if candidate_prefix_distance != incumbent_prefix_distance:
		return candidate_prefix_distance < incumbent_prefix_distance
	var candidate_steps: int = int(candidate.get("steps", 9999))
	var incumbent_steps: int = int(incumbent.get("steps", 9999))
	if candidate_steps != incumbent_steps:
		return candidate_steps < incumbent_steps
	var candidate_regression: int = int(candidate.get("regression_cost", 0))
	var incumbent_regression: int = int(incumbent.get("regression_cost", 0))
	if candidate_regression != incumbent_regression:
		return candidate_regression < incumbent_regression
	var candidate_tile: Vector2i = candidate.get("tile", INVALID_TILE)
	var incumbent_tile: Vector2i = incumbent.get("tile", INVALID_TILE)
	if candidate_tile != incumbent_tile:
		return _tile_precedes(candidate_tile, incumbent_tile)
	return _enemy_path_precedes(_vector2i_values(candidate.get("route", [])), _vector2i_values(incumbent.get("route", [])))

func _enemy_future_anchor_step_cost(state: Dictionary, anchor_details: Dictionary, attack_action: Dictionary, move_range: int) -> int:
	if bool(anchor_details.get("actor_target_overlap", false)):
		return -1
	var cost: int = 1 + int(anchor_details.get("trap_penalty", 0))
	var terrain_indices: Array[int] = _int_values(anchor_details.get("terrain_indices", []))
	if not terrain_indices.is_empty():
		var damage: int = int(attack_action.get("damage", 0))
		if damage <= 0:
			return -1
		for terrain_index: int in terrain_indices:
			var terrain: Dictionary = _normalized_terrain((state.get("terrain", []) as Array)[terrain_index])
			var hits: int = ceili(float(int(terrain.get("hp", 0))) / float(damage))
			cost += maxi(1, hits) * maxi(1, move_range)
	var blocking_enemy_count: int = int(anchor_details.get("blocking_enemy_count", 0))
	# A currently occupied anchor costs at least one complete activation plus the
	# step itself. This keeps an equally efficient open detour preferable to
	# waiting behind an ally without globally discounting every open prefix step.
	# The old discount made unnecessarily long first-activation U routes appear
	# cheaper than their true path length.
	cost += blocking_enemy_count * ENEMY_PATH_TEMPORARY_BLOCKER_TURN_COST * (maxi(1, move_range) + 1)
	return cost

func _enemy_future_planning_context(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var blocking_enemy_entries_by_tile: Dictionary = {}
	var terrain_index_by_tile: Dictionary = {}
	var trap_entry_by_tile: Dictionary = {}
	var actor_target_tiles: Dictionary = {}
	var definitions_by_type: Dictionary = {}
	var enemy_id: int = int(enemy.get("id", -1))
	var enemies: Array = state.get("enemies", [])
	for enemy_index: int in range(enemies.size()):
		if typeof(enemies[enemy_index]) != TYPE_DICTIONARY:
			continue
		# Future routing only needs identity, health, and footprint. Avoid deep status
		# normalization for every blocker in every enemy planning call.
		var raw_other: Dictionary = enemies[enemy_index] as Dictionary
		var enemy_type: String = str(raw_other.get("type", ""))
		var definition: Dictionary = definitions_by_type.get(enemy_type, {}) as Dictionary
		if definition.is_empty():
			definition = GameData.enemy_def(enemy_type)
			definitions_by_type[enemy_type] = definition
		var other: Dictionary = _enemy_with_resolved_footprint(raw_other, definition)
		if int(other.get("hp", 0)) <= 0 or int(other.get("id", -1)) == enemy_id:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(other):
			var blocking_entries: Dictionary = blocking_enemy_entries_by_tile.get(tile, {})
			blocking_entries[enemy_index] = true
			blocking_enemy_entries_by_tile[tile] = blocking_entries
	var terrain_entries: Array = state.get("terrain", []) as Array
	for terrain_index: int in range(terrain_entries.size()):
		if typeof(terrain_entries[terrain_index]) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = _normalized_terrain(terrain_entries[terrain_index] as Dictionary)
		if int(terrain.get("hp", 0)) <= 0:
			continue
		var tile: Vector2i = terrain.get("pos", INVALID_TILE)
		# Match _terrain_index_at_tile's first-live-entry behavior for malformed
		# saves that retain destroyed terrain or duplicate entries at one tile.
		if not terrain_index_by_tile.has(tile):
			terrain_index_by_tile[tile] = terrain_index
	var trap_entries: Array = state.get("traps", []) as Array
	for trap_index: int in range(trap_entries.size()):
		if typeof(trap_entries[trap_index]) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_entries[trap_index] as Dictionary
		var tile: Vector2i = trap.get("pos", INVALID_TILE)
		# Match _trap_index_at_tile's first-entry behavior and compute damage once.
		if not trap_entry_by_tile.has(tile):
			trap_entry_by_tile[tile] = {
				"index": trap_index,
				"penalty": ENEMY_PATH_TRAP_BASE_PENALTY + trap_damage(state, trap),
			}
	var actor_targets: Array[Dictionary] = _actor_targets(state)
	for target: Dictionary in actor_targets:
		actor_target_tiles[target.get("pos", INVALID_TILE)] = true
	return {
		"anchor_details": {},
		"blocking_enemy_entries_by_tile": blocking_enemy_entries_by_tile,
		"terrain_index_by_tile": terrain_index_by_tile,
		"trap_entry_by_tile": trap_entry_by_tile,
		"actor_targets": actor_targets,
		"actor_target_tiles": actor_target_tiles,
	}

func _enemy_future_blocking_enemy_count(enemy: Dictionary, anchor: Vector2i, planning_context: Dictionary) -> int:
	var blocking_enemy_entries: Dictionary = {}
	var blocking_enemy_entries_by_tile: Dictionary = planning_context.get("blocking_enemy_entries_by_tile", {})
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		var tile_entries: Dictionary = blocking_enemy_entries_by_tile.get(tile, {})
		for enemy_index_var: Variant in tile_entries.keys():
			blocking_enemy_entries[enemy_index_var] = true
	return blocking_enemy_entries.size()

func _enemy_future_anchor_details(state: Dictionary, enemy: Dictionary, anchor: Vector2i, planning_context: Dictionary) -> Dictionary:
	var cache: Dictionary = planning_context.get("anchor_details", {})
	if cache.has(anchor):
		return cache[anchor] as Dictionary
	var in_grid: bool = _enemy_anchor_is_in_grid(state, enemy, anchor)
	var terrain_indices: Array[int] = _enemy_future_terrain_indices(enemy, anchor, planning_context)
	var blocking_enemy_count: int = _enemy_future_blocking_enemy_count(enemy, anchor, planning_context)
	var actor_target_overlap: bool = _enemy_future_actor_target_overlap(enemy, anchor, planning_context)
	var trap_penalty: int = _enemy_future_trap_penalty(enemy, anchor, planning_context)
	var details: Dictionary = {
		"in_grid": in_grid,
		"terrain_indices": terrain_indices,
		"blocking_enemy_count": blocking_enemy_count,
		"actor_target_overlap": actor_target_overlap,
		"trap_penalty": trap_penalty,
		"dynamically_open": terrain_indices.is_empty() and blocking_enemy_count == 0 and not actor_target_overlap,
	}
	cache[anchor] = details
	planning_context["anchor_details"] = cache
	return details

func _enemy_future_terrain_indices(enemy: Dictionary, anchor: Vector2i, planning_context: Dictionary) -> Array[int]:
	var indices: Array[int]
	var terrain_index_by_tile: Dictionary = planning_context.get("terrain_index_by_tile", {}) as Dictionary
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		var terrain_index: int = int(terrain_index_by_tile.get(tile, -1))
		if terrain_index >= 0 and not indices.has(terrain_index):
			indices.append(terrain_index)
	return indices

func _enemy_future_actor_target_overlap(enemy: Dictionary, anchor: Vector2i, planning_context: Dictionary) -> bool:
	var actor_target_tiles: Dictionary = planning_context.get("actor_target_tiles", {}) as Dictionary
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		if actor_target_tiles.has(tile):
			return true
	return false

func _enemy_future_trap_penalty(enemy: Dictionary, anchor: Vector2i, planning_context: Dictionary) -> int:
	var penalty: int = 0
	var seen_indices: Array[int]
	var trap_entry_by_tile: Dictionary = planning_context.get("trap_entry_by_tile", {}) as Dictionary
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		var trap_entry: Dictionary = trap_entry_by_tile.get(tile, {}) as Dictionary
		var trap_index: int = int(trap_entry.get("index", -1))
		if trap_index < 0 or seen_indices.has(trap_index):
			continue
		seen_indices.append(trap_index)
		penalty += int(trap_entry.get("penalty", 0))
	return penalty

func _enemy_anchor_is_in_grid(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> bool:
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		if not PathUtils.is_passable(state.get("grid", []), tile):
			return false
	return true

func _enemy_anchor_is_dynamically_open(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> bool:
	return _enemy_anchor_terrain_indices(state, enemy, anchor).is_empty() and _enemy_anchor_blocking_enemy_count(state, enemy, anchor) == 0 and not _enemy_anchor_overlaps_any_actor_target(state, enemy, anchor)

func _enemy_anchor_overlaps_any_actor_target(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> bool:
	var footprint: Array[Vector2i] = _enemy_footprint_tiles(enemy, anchor)
	for actor_target: Dictionary in _actor_targets(state):
		if footprint.has(actor_target.get("pos", INVALID_TILE)):
			return true
	return false

func _enemy_anchor_blocking_enemy_count(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> int:
	var footprint_lookup: Dictionary = {}
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		footprint_lookup[tile] = true
	var count: int = 0
	for other_var: Variant in state.get("enemies", []):
		if typeof(other_var) != TYPE_DICTIONARY:
			continue
		var other: Dictionary = _normalized_enemy(other_var as Dictionary)
		if int(other.get("hp", 0)) <= 0 or int(other.get("id", -1)) == int(enemy.get("id", -1)):
			continue
		for tile: Vector2i in _enemy_footprint_tiles(other):
			if footprint_lookup.has(tile):
				count += 1
				break
	return count

func _enemy_anchor_terrain_indices(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> Array[int]:
	var indices: Array[int]
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		var terrain_index: int = _terrain_index_at_tile(state, tile)
		if terrain_index >= 0 and not indices.has(terrain_index):
			indices.append(terrain_index)
	return indices

func _enemy_anchor_trap_penalty(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> int:
	var penalty: int = 0
	var seen_indices: Array[int]
	for tile: Vector2i in _enemy_footprint_tiles(enemy, anchor):
		var trap_index: int = _trap_index_at_tile(state, tile)
		if trap_index < 0 or seen_indices.has(trap_index):
			continue
		seen_indices.append(trap_index)
		var trap: Dictionary = (state.get("traps", []) as Array)[trap_index]
		penalty += ENEMY_PATH_TRAP_BASE_PENALTY + trap_damage(state, trap)
	return penalty

func _enemy_actual_prefix_for_route(state: Dictionary, enemy: Dictionary, route: Array[Vector2i], move_range: int) -> Array[Vector2i]:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var path: Array[Vector2i] = _vector2i_values([start])
	if move_range <= 0 or route.is_empty():
		return path
	for route_index: int in range(1, route.size()):
		if path.size() - 1 >= move_range:
			break
		var anchor: Vector2i = route[route_index]
		if not _enemy_anchor_is_dynamically_open(state, enemy, anchor):
			break
		path.append(anchor)
	return path

func _planned_blocking_terrain_index(state: Dictionary, enemy: Dictionary, attack_action: Dictionary, route: Array[Vector2i]) -> int:
	for anchor: Vector2i in route:
		for terrain_index: int in _enemy_anchor_terrain_indices(state, enemy, anchor):
			var terrain: Dictionary = _normalized_terrain((state.get("terrain", []) as Array)[terrain_index])
			if _enemy_action_reaches_tile(state, enemy, attack_action, terrain.get("pos", INVALID_TILE)):
				return terrain_index
			return -1
	return -1

func _enemy_projected_attack_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary, target: Dictionary, terrain_index: int, trap_index: int) -> Array[Vector2i]:
	if trap_index >= 0:
		return _trap_blast_tiles(state, (state.get("traps", []) as Array)[trap_index])
	if not target.is_empty():
		var target_pos: Vector2i = target.get("pos", INVALID_TILE)
		if str(action.get("type", "")) == "aoe":
			var center: Vector2i = enemy.get("pos", Vector2i.ZERO)
			var resolved_action: Dictionary = _enemy_action_oriented_to_target(action, enemy, target_pos)
			if int(action.get("range", 0)) > 0:
				center = target_pos
			return _enemy_aoe_tiles_for_target(state, enemy, resolved_action, center, true)
		return _vector2i_values([target_pos])
	if terrain_index >= 0:
		var terrain: Dictionary = _normalized_terrain((state.get("terrain", []) as Array)[terrain_index])
		return _vector2i_values([terrain.get("pos", INVALID_TILE)])
	return []

func _compare_actor_targets(first: Dictionary, second: Dictionary) -> int:
	if _actor_target_precedes(first, second):
		return -1
	if _actor_target_precedes(second, first):
		return 1
	return 0

func _tile_precedes(first: Vector2i, second: Vector2i) -> bool:
	if first.y != second.y:
		return first.y < second.y
	return first.x < second.x

func _enemy_path_precedes(first: Array[Vector2i], second: Array[Vector2i]) -> bool:
	var compare_count: int = mini(first.size(), second.size())
	for index: int in range(compare_count):
		if first[index] == second[index]:
			continue
		return _tile_precedes(first[index], second[index])
	return first.size() < second.size()

func _enemy_path_regression_cost(enemy: Dictionary, path: Array[Vector2i], target: Vector2i, toward: bool) -> int:
	if path.size() <= 1:
		return 0
	var previous_enemy: Dictionary = enemy.duplicate(true)
	previous_enemy["pos"] = path[0]
	var previous_distance: int = _enemy_distance_to_tile(previous_enemy, target)
	var regression: int = 0
	for index: int in range(1, path.size()):
		var step_enemy: Dictionary = enemy.duplicate(true)
		step_enemy["pos"] = path[index]
		var distance: int = _enemy_distance_to_tile(step_enemy, target)
		regression += maxi(0, distance - previous_distance) if toward else maxi(0, previous_distance - distance)
		previous_distance = distance
	return regression

func _best_move_toward(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var movement_occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
	var best_tile: Vector2i = _best_move_toward_with_scoring(state, enemy, target, move_range, movement_occupied, movement_occupied)
	if best_tile != start:
		return best_tile
	var terrain_planning_occupied: Dictionary = _enemy_path_blockers(state, enemy, false, true)
	return _best_move_toward_with_scoring(state, enemy, target, move_range, movement_occupied, terrain_planning_occupied)

func _best_move_toward_for_followup(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int, followup_action: Dictionary) -> Vector2i:
	if move_range <= 0:
		return INVALID_TILE
	if str(followup_action.get("type", "")) != "aoe" or not bool(followup_action.get("orient_toward_target", false)):
		return INVALID_TILE
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return INVALID_TILE
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
	var candidates: Array[Vector2i] = _vector2i_values([start])
	for tile: Vector2i in _reachable_enemy_anchor_tiles(state, enemy, move_range, occupied, target):
		if not candidates.has(tile):
			candidates.append(tile)
	var best_tile: Vector2i = INVALID_TILE
	var best_move_cost: int = 9999
	var best_target_distance: int = 9999
	for tile: Vector2i in candidates:
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = tile
		var candidate_state: Dictionary = _state_with_enemy_anchor(state, candidate_enemy, tile)
		if not _enemy_action_reaches_tile(candidate_state, candidate_enemy, followup_action, target):
			continue
		var move_cost: int = PathUtils.manhattan(start, tile)
		var target_distance: int = _enemy_distance_to_tile(candidate_enemy, target)
		if best_tile == INVALID_TILE or _line_setup_candidate_is_better(move_cost, target_distance, tile, best_move_cost, best_target_distance, best_tile):
			best_tile = tile
			best_move_cost = move_cost
			best_target_distance = target_distance
	return best_tile

func _line_setup_candidate_is_better(move_cost: int, target_distance: int, tile: Vector2i, best_move_cost: int, best_target_distance: int, best_tile: Vector2i) -> bool:
	if move_cost != best_move_cost:
		return move_cost < best_move_cost
	if target_distance != best_target_distance:
		return target_distance < best_target_distance
	if tile.y != best_tile.y:
		return tile.y < best_tile.y
	return tile.x < best_tile.x

func _best_move_away(state: Dictionary, enemy_index: int, target: Vector2i, move_range: int) -> Vector2i:
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if move_range <= 0:
		return start
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, true, true)
	if enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
		var reachable: Array[Vector2i] = _reachable_enemy_anchor_tiles(state, enemy, move_range, occupied, target)
		var best_big_tile: Vector2i = start
		var best_big_score: int = _enemy_distance_to_tile(enemy, target)
		for tile: Vector2i in reachable:
			var candidate_enemy: Dictionary = enemy.duplicate(true)
			candidate_enemy["pos"] = tile
			var score: int = _enemy_distance_to_tile(candidate_enemy, target)
			if score > best_big_score:
				best_big_tile = tile
				best_big_score = score
		return best_big_tile
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(state.get("grid", []), start, move_range, occupied)
	var best_tile: Vector2i = start
	var best_score: int = PathUtils.manhattan(start, target)
	for tile: Vector2i in reachable:
		var score: int = PathUtils.manhattan(tile, target)
		if score > best_score:
			best_tile = tile
			best_score = score
	return best_tile

func _best_move_toward_with_scoring(state: Dictionary, enemy: Dictionary, target: Vector2i, move_range: int, movement_occupied: Dictionary, scoring_occupied: Dictionary) -> Vector2i:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var start_score: int = _enemy_anchor_path_distance(state, enemy, target, scoring_occupied)
	var start_distance: int = _enemy_distance_to_tile(enemy, target)
	var best_tile: Vector2i = start
	var best_score: int = start_score
	var best_distance: int = start_distance
	for tile: Vector2i in _reachable_enemy_anchor_tiles(state, enemy, move_range, movement_occupied, target):
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = tile
		var score: int = _enemy_anchor_path_distance(state, candidate_enemy, target, scoring_occupied)
		var distance: int = _enemy_distance_to_tile(candidate_enemy, target)
		var improves_start: bool = score < start_score or (score == start_score and distance < start_distance)
		if not improves_start:
			continue
		if best_tile == start or _toward_move_candidate_is_better(score, distance, tile, best_score, best_distance, best_tile):
			best_tile = tile
			best_score = score
			best_distance = distance
	return best_tile

func _toward_move_candidate_is_better(score: int, distance: int, tile: Vector2i, best_score: int, best_distance: int, best_tile: Vector2i) -> bool:
	if score != best_score:
		return score < best_score
	if distance != best_distance:
		return distance < best_distance
	if tile.y != best_tile.y:
		return tile.y < best_tile.y
	return tile.x < best_tile.x

func _enemy_anchor_path_distance(state: Dictionary, enemy: Dictionary, target: Vector2i, occupied: Dictionary) -> int:
	if _enemy_distance_to_tile(enemy, target) <= 1:
		return 0
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var queue: Array[Vector2i] = _vector2i_values([start])
	var queue_head: int = 0
	var distance_by_tile: Dictionary = {start: 0}
	while queue_head < queue.size():
		var current: Vector2i = queue[queue_head]
		queue_head += 1
		var current_distance: int = int(distance_by_tile.get(current, 0))
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if distance_by_tile.has(next_tile):
				continue
			if not _enemy_can_occupy_anchor(state, enemy, next_tile, occupied, target):
				continue
			var next_enemy: Dictionary = enemy.duplicate(true)
			next_enemy["pos"] = next_tile
			var next_distance: int = current_distance + 1
			if _enemy_distance_to_tile(next_enemy, target) <= 1:
				return next_distance
			distance_by_tile[next_tile] = next_distance
			queue.append(next_tile)
	return 10000 + _enemy_distance_to_tile(enemy, target)

func _enemy_path_blockers(state: Dictionary, enemy: Dictionary, block_terrain: bool, avoid_traps: bool) -> Dictionary:
	var enemy_id: int = int(enemy.get("id", -1))
	var occupied: Dictionary = _enemy_blocking_tiles(state, enemy_id) if block_terrain else _enemy_blocking_tiles_without_terrain(state, enemy_id)
	if avoid_traps:
		for trap_tile_var: Variant in _trap_tiles_lookup(state).keys():
			occupied[trap_tile_var] = true
	return occupied

func _enemy_threat_path_blockers(state: Dictionary, enemy: Dictionary, block_terrain: bool, avoid_traps: bool) -> Dictionary:
	var occupied: Dictionary = _enemy_path_blockers(state, enemy, block_terrain, avoid_traps)
	var player: Dictionary = _normalized_player(state.get("player", {}))
	var player_pos_value: Variant = player.get("pos", null)
	if typeof(player_pos_value) == TYPE_VECTOR2I:
		occupied.erase(player_pos_value)
	return occupied

func _reachable_enemy_anchor_tiles(state: Dictionary, enemy: Dictionary, max_distance: int, occupied: Dictionary, blocked_target: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	if max_distance <= 0:
		return results
	var queue: Array[Vector2i] = _vector2i_values([start])
	var queue_head: int = 0
	var distance_by_tile: Dictionary = {start: 0}
	while queue_head < queue.size():
		var current: Vector2i = queue[queue_head]
		queue_head += 1
		var current_distance: int = int(distance_by_tile.get(current, 0))
		if current_distance > 0:
			results.append(current)
		if current_distance >= max_distance:
			continue
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if distance_by_tile.has(next_tile):
				continue
			if not _enemy_can_occupy_anchor(state, enemy, next_tile, occupied, blocked_target):
				continue
			distance_by_tile[next_tile] = current_distance + 1
			queue.append(next_tile)
	return results

func _attack_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_attack_bonus_used", false)):
		return 0
	return _attack_bonus_for_current_turn_from_effects(state, _relic_effects(state))

func _attack_bonus_for_current_turn_from_effects(state: Dictionary, relic_effects: Array[Dictionary]) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_attack_bonus_used", false)):
		return 0
	var total: int = 0
	for effect: Dictionary in relic_effects:
		if str(effect.get("type", "")) == "first_attack_bonus":
			total += int(effect.get("value", 0))
	return GameData.fixed_point_amount(total)

func _move_bonus_for_current_turn(state: Dictionary) -> int:
	if bool((state.get("turn_flags", {}) as Dictionary).get("first_move_bonus_used", false)):
		return 0
	return GameData.stat_bonus_from_relics(state.get("relics", []), "first_move_bonus")

func _move_range_for_action(state: Dictionary, action: Dictionary) -> int:
	var move_range: int = maxi(0, int(action.get("range", 0)))
	if bool(action.get("_movement_pool", false)):
		return move_range
	return move_range + _move_bonus_for_current_turn(state)

func _damage_for_enemy_target(state: Dictionary, action: Dictionary, enemy_index: int) -> int:
	var resolved_action: Dictionary = _action_with_intensity_bonus(state, action)
	var relic_effects: Array[Dictionary] = _relic_effects(state)
	return _damage_for_enemy_target_with_context(state, resolved_action, enemy_index, relic_effects)

func _damage_for_enemy_target_with_context(
	state: Dictionary,
	resolved_action: Dictionary,
	enemy_index: int,
	relic_effects: Array[Dictionary]
) -> int:
	var damage: int = _final_damage_for_resolved_player_action(state, resolved_action, relic_effects)
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return damage
	var enemy: Dictionary = _normalized_enemy(enemies[enemy_index] as Dictionary)
	damage += int(enemy.get("expose", 0))
	for effect: Dictionary in relic_effects:
		if str(effect.get("type", "")) != "damage_vs_status":
			continue
		var status_id: String = str(effect.get("status", ""))
		if status_id.is_empty() or _unit_status_amount(enemy, status_id) <= 0:
			continue
		damage += GameData.fixed_point_amount(int(effect.get("value", 0)))
	return maxi(0, damage)

func _conditional_attack_bonus_for_action(state: Dictionary, action: Dictionary) -> int:
	return _conditional_attack_bonus_for_action_from_effects(state, action, _relic_effects(state))

func _conditional_attack_bonus_for_action_from_effects(
	state: Dictionary,
	action: Dictionary,
	relic_effects: Array[Dictionary]
) -> int:
	var total: int = 0
	if str(action.get("type", "")) not in ATTACK_ACTION_TYPES:
		return total
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for effect: Dictionary in relic_effects:
		match str(effect.get("type", "")):
			"glass_attack_bonus":
				if int(player.get("block", 0)) <= 0 and int(player.get("stoneskin", 0)) <= 0:
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"bloodied_glass_attack_bonus":
				if (
					int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1))
					and int(player.get("block", 0)) <= 0
					and int(player.get("stoneskin", 0)) <= 0
				):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"bloodied_attack_bonus":
				if int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1)):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"room_element_attack_bonus":
				var card_element: String = str(action.get("_card_element", ElementData.NONE))
				if ElementData.is_elemental(card_element) and card_element == str(state.get("room_element", ElementData.NONE)):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
			"first_card_attack_bonus":
				var first_card_key: String = _turn_relic_flag_key(effect, "first_card_attack_bonus")
				if not _turn_flag(state, first_card_key) and _action_matches_relic_card_groups(action, effect):
					total += GameData.fixed_point_amount(int(effect.get("value", 0)))
	return total

func _conditional_attack_modifiers_for_action(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if str(action.get("type", "")) not in ATTACK_ACTION_TYPES:
		return modifiers
	var player: Dictionary = _normalized_player(state.get("player", {}))
	for effect: Dictionary in _relic_effects(state):
		var amount: int = 0
		var detail: String = ""
		match str(effect.get("type", "")):
			"glass_attack_bonus":
				if int(player.get("block", 0)) <= 0 and int(player.get("stoneskin", 0)) <= 0:
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "No block or stoneskin"
			"bloodied_glass_attack_bonus":
				if (
					int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1))
					and int(player.get("block", 0)) <= 0
					and int(player.get("stoneskin", 0)) <= 0
				):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "At half health or less with no defense"
			"bloodied_attack_bonus":
				if int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1)):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "At half health or less"
			"room_element_attack_bonus":
				var card_element: String = str(action.get("_card_element", ElementData.NONE))
				if ElementData.is_elemental(card_element) and card_element == str(state.get("room_element", ElementData.NONE)):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "Matching room element"
			"first_card_attack_bonus":
				var first_card_key: String = _turn_relic_flag_key(effect, "first_card_attack_bonus")
				if not _turn_flag(state, first_card_key) and _action_matches_relic_card_groups(action, effect):
					amount = GameData.fixed_point_amount(int(effect.get("value", 0)))
					detail = "First move-or-blink attack card this turn"
			"player_state_action_mod":
				if (
					str(effect.get("field", "")) == "damage"
					and _relic_player_state_condition_met(state, effect)
					and (effect.get("action_types", []) as Array).has(str(action.get("type", "")))
					and action.has("_card_action_types")
				):
					amount = GameData.scaled_action_field_delta(
						str(action.get("type", "")),
						"damage",
						int(effect.get("amount", effect.get("value", 0)))
					)
					detail = "While you have block"
		if amount == 0:
			continue
		modifiers.append({
			"source": _relic_effect_source_name(effect),
			"kind": "relic",
			"amount": amount,
			"detail": detail
		})
	return modifiers

func _trigger_card_play_relics(
	state: Dictionary,
	card: Dictionary,
	card_id: String,
	play_context: Dictionary,
	destination: String,
	used_banked_play: bool,
	cards_played_before: int
) -> Dictionary:
	var next_state: Dictionary = state
	var card_element: String = GameData.card_element_from_def(card)
	var card_action_types: Array[String] = _card_action_types_for_relic(card)
	var previous_element: String = str((next_state.get("turn_flags", {}) as Dictionary).get("relic_sequence:last_element", ""))
	var previous_action_types: Array[String] = _tracked_relic_turn_action_types(next_state)
	_track_relic_card_element(next_state, card_element)
	_track_relic_card_action_types(next_state, card_action_types)
	var condition_state: Dictionary = next_state.duplicate(true)
	var triggered_reward_effects: Array[Dictionary]
	for effect: Dictionary in _relic_effects(condition_state):
		var effect_type: String = str(effect.get("type", ""))
		if effect_type == "first_card_attack_bonus":
			var first_card_key: String = _turn_relic_flag_key(effect, "first_card_attack_bonus")
			if (
				not _turn_flag(condition_state, first_card_key)
				and _card_matches_relic_play_condition(
					condition_state,
					card,
					card_id,
					effect,
					play_context,
					destination,
					used_banked_play,
					cards_played_before,
					previous_element,
					previous_action_types
				)
			):
				_set_turn_flag(next_state, first_card_key, true)
			continue
		if effect_type != "card_play_reward":
			continue
		if not _card_matches_relic_play_condition(
			condition_state,
			card,
			card_id,
			effect,
			play_context,
			destination,
			used_banked_play,
			cards_played_before,
			previous_element,
			previous_action_types
		):
			continue
		var trigger_count: int = int(effect.get("trigger_count", 1))
		if trigger_count > 1 and _increment_relic_counter(next_state, effect, "card_play_condition") < trigger_count:
			continue
		if not _relic_once_available(next_state, effect, "card_play_reward", card_element):
			continue
		_mark_relic_once(next_state, effect, "card_play_reward", card_element)
		triggered_reward_effects.append(effect)
	for effect: Dictionary in triggered_reward_effects:
		next_state = _apply_card_play_relic_rewards(next_state, effect, card_id, destination)
	if ElementData.is_elemental(card_element):
		_set_turn_flag(next_state, "relic_sequence:last_element", card_element)
	return next_state

func _apply_card_play_relic_rewards(state: Dictionary, effect: Dictionary, card_id: String, destination: String) -> Dictionary:
	var next_state: Dictionary = state
	var held_played_card: bool = false
	if destination == "discard" and _relic_rewards_include_type(effect, "draw"):
		var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
		var discard: Array = (deck.get("discard", []) as Array).duplicate()
		for index: int in range(discard.size() - 1, -1, -1):
			if str(discard[index]) != card_id:
				continue
			discard.remove_at(index)
			held_played_card = true
			break
		if held_played_card:
			deck["discard"] = discard
			next_state["deck"] = deck
	var reward_card: Dictionary = card_def(card_id, next_state)
	next_state = _apply_relic_rewards(next_state, _relic_rewards_resolved_from_card(effect.get("rewards", []), reward_card), effect)
	if held_played_card:
		var restored_deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
		var restored_discard: Array = (restored_deck.get("discard", []) as Array).duplicate()
		restored_discard.append(card_id)
		restored_deck["discard"] = restored_discard
		next_state["deck"] = restored_deck
	return next_state

func _relic_rewards_resolved_from_card(raw_rewards: Variant, card: Dictionary) -> Array:
	var rewards: Array = (raw_rewards as Array).duplicate(true) if typeof(raw_rewards) == TYPE_ARRAY else []
	for index: int in range(rewards.size()):
		if typeof(rewards[index]) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = (rewards[index] as Dictionary).duplicate(true)
		var duration_types: Array = reward.get("duration_from_action_types", []) as Array
		if duration_types.is_empty():
			continue
		var duration: int = 0
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if duration_types.has(str(action.get("type", ""))):
				duration = maxi(duration, int(action.get("duration", action.get("amount", 1))))
		reward["duration"] = duration
		rewards[index] = reward
	return rewards

func _relic_rewards_include_type(effect: Dictionary, reward_type: String) -> bool:
	var raw_rewards: Variant = effect.get("rewards", [])
	var rewards: Array = raw_rewards as Array if typeof(raw_rewards) == TYPE_ARRAY else [raw_rewards]
	for reward_var: Variant in rewards:
		if typeof(reward_var) == TYPE_DICTIONARY and str((reward_var as Dictionary).get("type", "")) == reward_type:
			return true
	return false

func _card_matches_relic_play_condition(
	state: Dictionary,
	card: Dictionary,
	card_id: String,
	effect: Dictionary,
	play_context: Dictionary,
	destination: String,
	used_banked_play: bool,
	cards_played_before: int,
	previous_element: String,
	previous_action_types: Array[String]
) -> bool:
	var play_mode: String = str(play_context.get("play_mode", "play"))
	if play_mode != str(effect.get("play_mode", "play")):
		return false
	var card_element: String = GameData.card_element_from_def(card)
	var required_element: String = str(effect.get("element", ""))
	if not required_element.is_empty() and card_element != required_element:
		return false
	var action_types: Array[String] = _card_action_types_for_relic(card)
	for required_type_var: Variant in effect.get("requires_action_types", []):
		if not action_types.has(str(required_type_var)):
			return false
	var any_required: Array = effect.get("requires_any_action_types", [])
	if not any_required.is_empty() and not _action_types_include_any(action_types, any_required):
		return false
	for group_var: Variant in effect.get("requires_any_action_type_groups", []):
		if typeof(group_var) != TYPE_ARRAY or not _action_types_include_any(action_types, group_var as Array):
			return false
	var cross_groups: Array = effect.get("cross_card_action_type_groups", [])
	if not cross_groups.is_empty():
		if cross_groups.size() != 2 or typeof(cross_groups[0]) != TYPE_ARRAY or typeof(cross_groups[1]) != TYPE_ARRAY:
			return false
		var first_group: Array = cross_groups[0] as Array
		var second_group: Array = cross_groups[1] as Array
		var completes_forward: bool = (
			_action_types_include_any(previous_action_types, first_group)
			and _action_types_include_any(action_types, second_group)
		)
		var completes_reverse: bool = (
			_action_types_include_any(previous_action_types, second_group)
			and _action_types_include_any(action_types, first_group)
		)
		if not completes_forward and not completes_reverse:
			return false
	for excluded_type_var: Variant in effect.get("excludes_action_types", []):
		if action_types.has(str(excluded_type_var)):
			return false
	var action_count: int = (card.get("actions", []) as Array).size()
	if effect.has("min_action_count") and action_count < int(effect.get("min_action_count", 0)):
		return false
	if effect.has("max_action_count") and action_count > int(effect.get("max_action_count", action_count)):
		return false
	var time_cost: int = card_time_cost_from_def(card)
	if effect.has("min_time") and time_cost < int(effect.get("min_time", 0)):
		return false
	if effect.has("max_time") and time_cost > int(effect.get("max_time", time_cost)):
		return false
	if effect.has("min_health_cost") and int(card.get("health_cost", 0)) < int(effect.get("min_health_cost", 0)):
		return false
	if effect.has("burn_card") and bool(card.get("burn", false)) != bool(effect.get("burn_card", false)):
		return false
	if effect.has("destination") and destination != str(effect.get("destination", "")):
		return false
	if effect.has("used_banked_play") and used_banked_play != bool(effect.get("used_banked_play", false)):
		return false
	if effect.has("min_cards_played_before") and cards_played_before < int(effect.get("min_cards_played_before", 0)):
		return false
	if effect.has("max_cards_played_before") and cards_played_before > int(effect.get("max_cards_played_before", cards_played_before)):
		return false
	var hp_percent_max: int = int(effect.get("player_hp_percent_max", 100))
	if hp_percent_max < 100:
		var player: Dictionary = _normalized_player(state.get("player", {}))
		if int(player.get("hp", 0)) * 100 > int(player.get("max_hp", 1)) * hp_percent_max:
			return false
	if not _relic_player_state_condition_met(state, effect):
		return false
	var previous_mode: String = str(effect.get("previous_element", ""))
	if previous_mode == "different":
		if not ElementData.is_elemental(previous_element) or not ElementData.is_elemental(card_element) or previous_element == card_element:
			return false
	elif previous_mode == "same":
		if not ElementData.is_elemental(previous_element) or previous_element != card_element:
			return false
	var unique_threshold: int = int(effect.get("unique_elements_threshold", 0))
	if unique_threshold > 0:
		var unique_scope: String = str(effect.get("unique_elements_scope", "combat"))
		var unique_key: String = "relic_sequence:turn_elements" if unique_scope == "turn" else "relic_sequence:combat_elements"
		var source_flags: Dictionary = state.get("turn_flags", {}) as Dictionary if unique_scope == "turn" else state.get("relic_flags", {}) as Dictionary
		if (source_flags.get(unique_key, []) as Array).size() < unique_threshold:
			return false
	return true

func _card_action_types_for_relic(card: Dictionary) -> Array[String]:
	var result: Array[String]
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action_type: String = str((action_var as Dictionary).get("type", ""))
		if not action_type.is_empty() and not result.has(action_type):
			result.append(action_type)
	return result

func _action_types_include_any(action_types: Array[String], candidates: Array) -> bool:
	for candidate_var: Variant in candidates:
		if action_types.has(str(candidate_var)):
			return true
	return false

func _track_relic_card_element(state: Dictionary, element_id: String) -> void:
	if not ElementData.is_elemental(element_id):
		return
	var turn_elements: Array = ((state.get("turn_flags", {}) as Dictionary).get("relic_sequence:turn_elements", []) as Array).duplicate()
	if not turn_elements.has(element_id):
		turn_elements.append(element_id)
	_set_turn_flag(state, "relic_sequence:turn_elements", turn_elements)
	var combat_elements: Array = ((state.get("relic_flags", {}) as Dictionary).get("relic_sequence:combat_elements", []) as Array).duplicate()
	if not combat_elements.has(element_id):
		combat_elements.append(element_id)
	_set_combat_relic_flag(state, "relic_sequence:combat_elements", combat_elements)

func _tracked_relic_turn_action_types(state: Dictionary) -> Array[String]:
	var result: Array[String]
	for action_type_var: Variant in (state.get("turn_flags", {}) as Dictionary).get("relic_sequence:turn_action_types", []):
		result.append(str(action_type_var))
	return result

func _track_relic_card_action_types(state: Dictionary, action_types: Array[String]) -> void:
	var tracked: Array[String] = _tracked_relic_turn_action_types(state)
	for action_type: String in action_types:
		if not tracked.has(action_type):
			tracked.append(action_type)
	_set_turn_flag(state, "relic_sequence:turn_action_types", tracked)

func _trigger_activation_end_relics(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "end_turn_block_to_stoneskin":
			continue
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		var remaining_block: int = int(player.get("block", 0))
		if remaining_block <= 0:
			continue
		var stoneskin_gain: int = remaining_block * maxi(1, int(effect.get("multiplier", 1)))
		player["block"] = 0
		player["stoneskin"] = int(player.get("stoneskin", 0)) + stoneskin_gain
		next_state["player"] = player
		next_state = _trigger_stoneskin_relics(next_state, stoneskin_gain)
		_log(next_state, "%s carries %d block forward as stoneskin." % [_relic_effect_source_name(effect), stoneskin_gain])
	return next_state

func _trigger_blink_relics(state: Dictionary, distance: int = 0) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"blink_draw_once_per_turn":
				if distance < int(effect.get("threshold", 0)):
					continue
				var draw_key: String = _turn_relic_flag_key(effect, "blink_draw")
				if _turn_flag(next_state, draw_key):
					continue
				_set_turn_flag(next_state, draw_key, true)
				next_state = _draw_relic_cards_in_place(next_state, int(effect.get("value", 1)))
				var bonus_card_plays: int = maxi(0, int(effect.get("card_play", 0)))
				if bonus_card_plays > 0:
					next_state = _grant_relic_card_plays(next_state, bonus_card_plays)
			"blink_intensity_gain_once_per_turn":
				var intensity_key: String = _turn_relic_flag_key(effect, "blink_intensity")
				if _turn_flag(next_state, intensity_key):
					continue
				_set_turn_flag(next_state, intensity_key, true)
				next_state = _gain_elemental_intensity(next_state, str(effect.get("element", ElementData.NONE)), int(effect.get("amount", effect.get("value", 1))), _relic_effect_source_name(effect))
	return _trigger_long_move_relics(next_state, distance)

func _trigger_long_move_relics(state: Dictionary, distance: int) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "long_move_card_play":
			continue
		if distance < int(effect.get("threshold", 1)):
			continue
		var flag_key: String = _turn_relic_flag_key(effect, "long_move_card_play")
		if _turn_flag(next_state, flag_key):
			continue
		_set_turn_flag(next_state, flag_key, true)
		if effect.has("rewards"):
			next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
		else:
			next_state = _grant_relic_card_plays(next_state, int(effect.get("value", 1)))
	return next_state

func _trigger_stoneskin_relics(state: Dictionary, gained: int) -> Dictionary:
	var next_state: Dictionary = state
	if gained <= 0:
		return next_state
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"stoneskin_thorns":
				var damage: int = GameData.fixed_point_amount(int(effect.get("value", 0)))
				if bool(effect.get("scale_from_gain", false)):
					damage = gained / maxi(1, int(effect.get("divisor", 1)))
					if effect.has("max_value"):
						damage = mini(damage, GameData.fixed_point_amount(int(effect.get("max_value", 0))))
				next_state = _damage_adjacent_enemies_from_player(next_state, damage)
			"stoneskin_intensity_gain_once_per_turn":
				var intensity_key: String = _turn_relic_flag_key(effect, "stoneskin_intensity")
				if _turn_flag(next_state, intensity_key):
					continue
				_set_turn_flag(next_state, intensity_key, true)
				next_state = _gain_elemental_intensity(
					next_state,
					str(effect.get("element", ElementData.NONE)),
					int(effect.get("amount", effect.get("value", 1))),
					_relic_effect_source_name(effect)
				)
	return next_state

func _trigger_status_relics(state: Dictionary, status_id: String, source_action: Dictionary = {}) -> Dictionary:
	var next_state: Dictionary = state
	var matching_effects: Array[Dictionary]
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("status", "")) != status_id:
			continue
		var action_types: Array = effect.get("action_types", []) as Array
		if not action_types.is_empty() and not action_types.has(str(source_action.get("type", ""))):
			continue
		matching_effects.append(effect)

	# Intensity gains form the first phase of a status event. Every remaining
	# condition then observes the same post-gain snapshot, independent of relic
	# acquisition order.
	for effect: Dictionary in matching_effects:
		if str(effect.get("type", "")) != "status_intensity_gain":
			continue
		var intensity_key: String = _turn_relic_flag_key(effect, "status_intensity")
		if _turn_flag(next_state, intensity_key):
			continue
		_set_turn_flag(next_state, intensity_key, true)
		next_state = _gain_elemental_intensity(
			next_state,
			str(effect.get("element", ElementData.NONE)),
			int(effect.get("amount", effect.get("value", 1))),
			_relic_effect_source_name(effect)
		)

	var condition_state: Dictionary = next_state.duplicate(true)
	var queued_resolutions: Array[Dictionary]
	for effect: Dictionary in matching_effects:
		match str(effect.get("type", "")):
			"first_status_card_play":
				var flag_key: String = _combat_relic_flag_key(effect, "first_status_card_play")
				if _combat_relic_flag(condition_state, flag_key):
					continue
				_set_combat_relic_flag(next_state, flag_key, true)
				queued_resolutions.append({"type": "card_play", "amount": int(effect.get("value", 1))})
			"status_draw_once_per_turn":
				var turn_key: String = _turn_relic_flag_key(effect, "status_draw")
				if _turn_flag(condition_state, turn_key):
					continue
				_set_turn_flag(next_state, turn_key, true)
				queued_resolutions.append({"type": "draw", "amount": int(effect.get("value", 1))})
			"status_count_reward":
				if not _relic_player_state_condition_met(condition_state, effect):
					continue
				var intensity_element: String = str(effect.get("intensity_element", ""))
				if (
					ElementData.is_elemental(intensity_element)
					and elemental_intensity(condition_state, intensity_element) < int(effect.get("min_intensity", 0))
				):
					continue
				var status_count: int = _increment_relic_counter(next_state, effect, "status_count")
				if status_count < int(effect.get("threshold", 1)):
					continue
				if not _relic_once_available(next_state, effect, "status_count_reward", status_id):
					continue
				_mark_relic_once(next_state, effect, "status_count_reward", status_id)
				queued_resolutions.append({"type": "rewards", "effect": effect})
	for resolution: Dictionary in queued_resolutions:
		match str(resolution.get("type", "")):
			"card_play":
				next_state = _grant_relic_card_plays(next_state, int(resolution.get("amount", 0)))
			"draw":
				next_state = _draw_relic_cards_in_place(next_state, int(resolution.get("amount", 0)))
			"rewards":
				var reward_effect: Dictionary = resolution.get("effect", {}) as Dictionary
				next_state = _apply_relic_rewards(next_state, reward_effect.get("rewards", []), reward_effect)
	return next_state

func _trigger_intensity_threshold_relics(state: Dictionary, element_id: String, before_value: int, after_value: int) -> Dictionary:
	var next_state: Dictionary = state
	if not ElementData.is_elemental(element_id) or after_value <= before_value:
		return next_state
	var triggered_effects: Array[Dictionary]
	for effect: Dictionary in _relic_effects(state):
		if str(effect.get("type", "")) != "intensity_threshold_reward":
			continue
		if not _relic_effect_matches_intensity_element(effect, element_id):
			continue
		var threshold: int = int(effect.get("threshold", effect.get("amount", 0)))
		if threshold <= 0 or before_value >= threshold or after_value < threshold:
			continue
		var qualifying_elements: Array[String] = _elements_at_or_above_intensity(state, threshold)
		if qualifying_elements.size() < int(effect.get("required_elements", 1)):
			continue
		if not _relic_once_available(state, effect, "intensity_threshold", element_id):
			continue
		triggered_effects.append({
			"effect": effect,
			"qualifying_elements": qualifying_elements
		})

	# Resolve every trigger from the same post-gain snapshot. Mark them before
	# applying rewards so a reward that raises intensity cannot re-enter a
	# trigger that is already waiting to resolve.
	var intensity_to_consume: Dictionary = {}
	for trigger: Dictionary in triggered_effects:
		var effect: Dictionary = trigger.get("effect", {}) as Dictionary
		_mark_relic_once(next_state, effect, "intensity_threshold", element_id)
		var consume_amount: int = int(effect.get("consume", 0))
		if bool(effect.get("consume_all_qualifying", false)):
			var qualifying_elements: Array[String]
			qualifying_elements.assign(trigger.get("qualifying_elements", []))
			for qualifying_element: String in qualifying_elements:
				intensity_to_consume[qualifying_element] = int(intensity_to_consume.get(qualifying_element, 0)) + consume_amount
		else:
			intensity_to_consume[element_id] = int(intensity_to_consume.get(element_id, 0)) + consume_amount

	for consumed_element_var: Variant in intensity_to_consume.keys():
		var consumed_element: String = str(consumed_element_var)
		next_state = _consume_elemental_intensity(next_state, consumed_element, int(intensity_to_consume[consumed_element]))

	for trigger: Dictionary in triggered_effects:
		var effect: Dictionary = trigger.get("effect", {}) as Dictionary
		next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
	return next_state

func _elements_at_or_above_intensity(state: Dictionary, threshold: int) -> Array[String]:
	var result: Array[String]
	for element_id: String in ElementData.all_elements():
		if elemental_intensity(state, element_id) >= threshold:
			result.append(element_id)
	return result

func _trigger_enemy_death_relics(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"kill_status_heal":
				var status_id: String = str(effect.get("status", ""))
				if _unit_status_amount(enemy, status_id) <= 0:
					continue
				if not _relic_once_available(next_state, effect, "kill_status_heal", status_id):
					continue
				_mark_relic_once(next_state, effect, "kill_status_heal", status_id)
				next_state = _heal_player(next_state, GameData.fixed_point_amount(int(effect.get("value", 0))))
			"enemy_death_reward":
				if not _enemy_matches_relic_status_condition(enemy, effect):
					continue
				var death_count: int = _increment_relic_counter(next_state, effect, "enemy_death")
				if death_count < int(effect.get("threshold", 1)):
					continue
				if not _relic_once_available(next_state, effect, "enemy_death_reward", ""):
					continue
				_mark_relic_once(next_state, effect, "enemy_death_reward", "")
				next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
	return next_state

func _enemy_matches_relic_status_condition(enemy: Dictionary, effect: Dictionary) -> bool:
	var statuses: Array = effect.get("statuses", [])
	if statuses.is_empty():
		var single_status: String = str(effect.get("status", ""))
		if not single_status.is_empty():
			statuses = [single_status]
	if statuses.is_empty():
		return not bool(effect.get("requires_status", false)) or _enemy_has_any_relic_status(enemy)
	for status_var: Variant in statuses:
		if _unit_status_amount(enemy, str(status_var)) > 0:
			return true
	return false

func _enemy_has_any_relic_status(enemy: Dictionary) -> bool:
	for status_id: String in ["burn", "bleed", "expose", "freeze", "shock", "poison"]:
		if _unit_status_amount(enemy, status_id) > 0:
			return true
	return bool(enemy.get("immobilize", false))

func _trigger_prevent_lethal_relics(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "prevent_lethal_once":
			continue
		var flag_key: String = _combat_relic_flag_key(effect, "prevent_lethal_once")
		if _combat_relic_flag(next_state, flag_key):
			continue
		_set_combat_relic_flag(next_state, flag_key, true)
		var player: Dictionary = _normalized_player(next_state.get("player", {}))
		player["hp"] = GameData.FIXED_POINT_SCALE
		next_state["player"] = player
		var burn_amount: int = GameData.fixed_point_amount(int(effect.get("burn_all_enemies", 0)))
		if burn_amount > 0:
			next_state = _burn_all_live_enemies(next_state, burn_amount)
		_log(next_state, "%s prevents death." % _relic_effect_source_name(effect))
		return next_state
	return next_state

func _trigger_defiance(state: Dictionary, cause: String, hp_before: int) -> Dictionary:
	var next_state: Dictionary = state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	if int(player.get("hp", 0)) > 0:
		return next_state
	var capacity: int = maxi(0, int(next_state.get("defiance_capacity", 0)))
	var remaining_before: int = clampi(int(next_state.get("defiance_remaining", 0)), 0, capacity)
	if remaining_before <= 0:
		return next_state
	var restored_hp: int = maxi(1, ceili(float(int(player.get("max_hp", 1))) * DEFIANCE_RESTORE_FRACTION))
	player["hp"] = mini(int(player.get("max_hp", 1)), restored_hp)
	next_state["player"] = player
	next_state["defiance_remaining"] = remaining_before - 1
	var revision: int = int(next_state.get("defiance_event_revision", 0)) + 1
	var event: Dictionary = {
		"revision": revision,
		"cause": cause,
		"hp_before": maxi(0, hp_before),
		"lethal_hp_loss": maxi(0, hp_before),
		"restored_hp": int(player.get("hp", restored_hp)),
		"charges_before": remaining_before,
		"charges_after": remaining_before - 1,
		"capacity": capacity,
		"turn": int(next_state.get("turn", 1))
	}
	var events: Array = (next_state.get("defiance_events", []) as Array).duplicate(true)
	events.append(event)
	while events.size() > DEFIANCE_EVENT_LIMIT:
		events.pop_front()
	next_state["defiance_events"] = events
	next_state["defiance_event_revision"] = revision
	for effect: Dictionary in _relic_effects(next_state):
		match str(effect.get("type", "")):
			"defiance_trigger_burn":
				var burn_amount: int = GameData.fixed_point_amount(int(effect.get("value", 0)))
				if burn_amount > 0:
					next_state = _burn_all_live_enemies(next_state, burn_amount)
			"defiance_trigger_reward":
				next_state = _apply_relic_rewards(next_state, effect.get("rewards", []), effect)
	_log(
		next_state,
		"DEFIANCE restores %d health. %d remaining." % [
			int(player.get("hp", restored_hp)),
			remaining_before - 1
		]
	)
	return next_state

func _scaled_relic_reward_amount(reward: Dictionary) -> int:
	var amount: int = int(reward.get("amount", reward.get("value", 0)))
	match str(reward.get("type", "")):
		"block", "stoneskin", "heal", "all_enemies_damage", "block_to_stoneskin":
			return GameData.fixed_point_amount(amount)
		"all_enemies_status":
			var status_id: String = str(reward.get("status", ""))
			return GameData.fixed_point_amount(amount) if status_id in ["burn", "poison"] else amount
		_:
			return amount

func _apply_relic_rewards(state: Dictionary, raw_rewards: Variant, effect: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	var rewards: Array = []
	if typeof(raw_rewards) == TYPE_ARRAY:
		rewards = (raw_rewards as Array).duplicate(true)
	elif typeof(raw_rewards) == TYPE_DICTIONARY:
		rewards = [raw_rewards]
	for reward_var: Variant in rewards:
		if typeof(reward_var) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_var as Dictionary
		var amount: int = _scaled_relic_reward_amount(reward)
		match str(reward.get("type", "")):
			"draw":
				if bool(reward.get("safe", true)):
					next_state = _draw_relic_cards_in_place(next_state, amount)
				else:
					next_state = _draw_cards_in_place(next_state, amount)
			"card_play":
				if amount > 0:
					next_state = _grant_relic_card_plays(next_state, amount)
			"block":
				var block_player: Dictionary = _normalized_player(next_state.get("player", {}))
				block_player["block"] = int(block_player.get("block", 0)) + maxi(0, amount)
				next_state["player"] = block_player
			"stoneskin":
				var stoneskin_player: Dictionary = _normalized_player(next_state.get("player", {}))
				var stoneskin_before: int = int(stoneskin_player.get("stoneskin", 0))
				stoneskin_player["stoneskin"] = int(stoneskin_player.get("stoneskin", 0)) + maxi(0, amount)
				next_state["player"] = stoneskin_player
				next_state = _trigger_stoneskin_relics(next_state, int(stoneskin_player.get("stoneskin", 0)) - stoneskin_before)
			"block_to_stoneskin":
				var converting_player: Dictionary = _normalized_player(next_state.get("player", {}))
				var converted: int = mini(maxi(0, amount), int(converting_player.get("block", 0)))
				if converted > 0:
					converting_player["block"] = int(converting_player.get("block", 0)) - converted
					converting_player["stoneskin"] = int(converting_player.get("stoneskin", 0)) + converted
					next_state["player"] = converting_player
					next_state = _trigger_stoneskin_relics(next_state, converted)
			"heal":
				next_state = _heal_player(next_state, amount)
			"intensity":
				var reward_element: String = str(reward.get("element", effect.get("element", ElementData.NONE)))
				next_state = _gain_elemental_intensity(next_state, reward_element, amount, _relic_effect_source_name(effect))
			"vision":
				next_state = _apply_umbra_vision(next_state, {
					"amount": int(reward.get("amount", 0)),
					"duration": int(reward.get("duration", 2))
				})
			"truesight":
				next_state = _apply_umbra_truesight(next_state, {"duration": int(reward.get("duration", amount if amount != 0 else 2))})
			"dispel_umbra":
				next_state = _dispel_umbra(next_state, {"amount": int(reward.get("amount", 1))})
			"illuminate_player":
				var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", INVALID_TILE)
				if player_pos != INVALID_TILE:
					next_state = _create_umbra_light_source(next_state, player_pos, {
						"radius": int(reward.get("radius", 1)),
						"duration": int(reward.get("duration", 2)),
						"silent": true
					})
			"intensity_per_deck_element":
				var deck_element: String = str(reward.get("deck_element", reward.get("element", ElementData.NONE)))
				var cards_per_point: int = maxi(1, int(reward.get("cards_per_point", 1)))
				var deck_element_count: int = _combat_deck_element_card_count(next_state, deck_element)
				var scaled_amount: int = deck_element_count / cards_per_point
				if reward.has("max_value"):
					scaled_amount = mini(scaled_amount, int(reward.get("max_value", scaled_amount)))
				if scaled_amount > 0:
					var scaled_element: String = str(reward.get("element", deck_element))
					next_state = _gain_elemental_intensity(next_state, scaled_element, scaled_amount, _relic_effect_source_name(effect))
			"stoneskin_per_deck_element":
				var stoneskin_deck_element: String = str(reward.get("deck_element", reward.get("element", ElementData.NONE)))
				var stoneskin_card_count: int = _combat_deck_element_card_count(next_state, stoneskin_deck_element)
				var stoneskin_amount: int = stoneskin_card_count * GameData.fixed_point_amount(int(reward.get("value", 1)))
				if reward.has("max_value"):
					stoneskin_amount = mini(stoneskin_amount, GameData.fixed_point_amount(int(reward.get("max_value", stoneskin_amount))))
				if stoneskin_amount > 0:
					var scaling_player: Dictionary = _normalized_player(next_state.get("player", {}))
					scaling_player["stoneskin"] = int(scaling_player.get("stoneskin", 0)) + stoneskin_amount
					next_state["player"] = scaling_player
					next_state = _trigger_stoneskin_relics(next_state, stoneskin_amount)
			"all_enemies_status":
				next_state = _apply_status_to_all_live_enemies(next_state, str(reward.get("status", "")), amount)
			"all_enemies_damage":
				next_state = _damage_all_live_enemies(next_state, amount)
	if not rewards.is_empty():
		_log(next_state, "%s triggers." % _relic_effect_source_name(effect))
	return next_state

func _grant_relic_card_plays(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	if is_player_turn(next_state) and not bool(next_state.get("player_turn_ending", false)):
		next_state["card_play_bonus_this_turn"] = int(next_state.get("card_play_bonus_this_turn", 0)) + amount
	else:
		next_state["pending_relic_card_plays"] = int(next_state.get("pending_relic_card_plays", 0)) + amount
	return next_state

func _relic_safe_draws_available(state: Dictionary) -> int:
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	return (deck.get("draw", []) as Array).size()

func _draw_relic_cards_in_place(state: Dictionary, count: int) -> Dictionary:
	return _draw_cards_in_place(state, mini(maxi(0, count), _relic_safe_draws_available(state)))

func _apply_status_to_all_live_enemies(state: Dictionary, status_id: String, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0 or status_id.is_empty():
		return next_state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		match status_id:
			"burn":
				if not _enemy_is_immune_to_status(enemy, "burn"):
					enemy["burn"] = int(enemy.get("burn", 0)) + amount
			"freeze":
				if not _enemy_is_immune_to_status(enemy, "freeze"):
					enemy["freeze"] = maxi(int(enemy.get("freeze", 0)), amount)
			"shock":
				if not _enemy_is_immune_to_status(enemy, "shock"):
					enemy["shock"] = maxi(int(enemy.get("shock", 0)), amount)
			"poison":
				if not _enemy_is_immune_to_status(enemy, "poison"):
					var poison: Dictionary = enemy.get("poison", {}).duplicate(true)
					poison["damage"] = int(poison.get("damage", 0)) + amount
					poison["delay"] = 2
					enemy["poison"] = poison
			_:
				continue
		enemies[index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _damage_all_live_enemies(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var enemies: Array = next_state.get("enemies", [])
	for index: int in range(enemies.size()):
		var current_enemies: Array = next_state.get("enemies", [])
		if index < 0 or index >= current_enemies.size() or typeof(current_enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(current_enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		next_state = _damage_enemy(next_state, index, amount)
	return next_state

func _damage_adjacent_enemies_from_player(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var player_pos: Vector2i = (_normalized_player(next_state.get("player", {}))).get("pos", Vector2i.ZERO)
	var enemies: Array = next_state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if _enemy_distance_to_tile(enemy, player_pos) > 1:
			continue
		next_state = _damage_enemy(next_state, index, amount)
	return next_state

func _burn_all_live_enemies(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	var enemies: Array = next_state.get("enemies", []).duplicate(true)
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["burn"] = int(enemy.get("burn", 0)) + amount
		enemies[index] = enemy
	next_state["enemies"] = enemies
	return next_state

func _heal_player(state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = state
	if amount <= 0:
		return next_state
	var player: Dictionary = _normalized_player(next_state.get("player", {}))
	var hp_before: int = int(player.get("hp", 0))
	var max_hp: int = int(player.get("max_hp", 1))
	player["hp"] = mini(max_hp, hp_before + amount)
	next_state["player"] = player
	var overheal: int = maxi(0, hp_before + amount - max_hp)
	if overheal <= 0:
		return next_state
	for effect: Dictionary in _relic_effects(next_state):
		if str(effect.get("type", "")) != "overheal_to_stoneskin":
			continue
		var cap: int = GameData.fixed_point_amount(int(effect.get("cap", effect.get("max_value", 0))))
		var key: String = _turn_relic_flag_key(effect, "overheal_converted")
		var converted_before: int = int((next_state.get("turn_flags", {}) as Dictionary).get(key, 0))
		var available: int = overheal if cap <= 0 else maxi(0, cap - converted_before)
		var converted: int = mini(overheal, available)
		if converted <= 0:
			continue
		var converted_player: Dictionary = _normalized_player(next_state.get("player", {}))
		var stoneskin_before: int = int(converted_player.get("stoneskin", 0))
		converted_player["stoneskin"] = stoneskin_before + converted
		next_state["player"] = converted_player
		_set_turn_flag(next_state, key, converted_before + converted)
		next_state = _trigger_stoneskin_relics(next_state, converted)
		var first_conversion_rewards: Variant = effect.get("first_conversion_rewards", [])
		if typeof(first_conversion_rewards) == TYPE_ARRAY and not (first_conversion_rewards as Array).is_empty():
			var first_key: String = _turn_relic_flag_key(effect, "overheal_first_conversion")
			if not _turn_flag(next_state, first_key):
				_set_turn_flag(next_state, first_key, true)
				next_state = _apply_relic_rewards(next_state, first_conversion_rewards, effect)
		_log(next_state, "%s hardens %d excess healing into stoneskin." % [_relic_effect_source_name(effect), converted])
	return next_state

func _start_combat_intensity_effect_applies(effect: Dictionary, deck_cards: Array) -> bool:
	var deck_element: String = str(effect.get("deck_element", ""))
	if not ElementData.is_elemental(deck_element):
		return true
	return _deck_element_card_count(deck_cards, deck_element) >= int(effect.get("threshold", 1))

func _deck_element_card_count(deck_cards: Array, element_id: String) -> int:
	if not ElementData.is_elemental(element_id):
		return 0
	var count: int = 0
	for card_id_var: Variant in deck_cards:
		if GameData.card_element(str(card_id_var)) == element_id:
			count += 1
	return count

func _combat_deck_element_card_count(state: Dictionary, element_id: String) -> int:
	if not ElementData.is_elemental(element_id):
		return 0
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	var count: int = 0
	for zone: String in ["draw", "hand", "discard", "burned", "consumed"]:
		for card_id_var: Variant in deck.get(zone, []):
			if GameData.card_element(str(card_id_var)) == element_id:
				count += 1
	return count

func _relic_effect_matches_intensity_element(effect: Dictionary, element_id: String) -> bool:
	var effect_element: String = str(effect.get("element", "any"))
	return effect_element.is_empty() or effect_element == "any" or effect_element == element_id

func _increment_relic_counter(state: Dictionary, effect: Dictionary, suffix: String) -> int:
	var key: String = "%s:%s:%s" % [
		str(effect.get("relic_id", "")),
		str(effect.get("status", "")),
		suffix
	]
	var scope: String = str(effect.get("count_scope", effect.get("once", "turn")))
	if scope.begins_with("combat"):
		var combat_count: int = int((state.get("relic_flags", {}) as Dictionary).get(key, 0)) + 1
		_set_combat_relic_flag(state, key, combat_count)
		return combat_count
	var turn_count: int = int((state.get("turn_flags", {}) as Dictionary).get(key, 0)) + 1
	_set_turn_flag(state, key, turn_count)
	return turn_count

func _relic_once_available(state: Dictionary, effect: Dictionary, suffix: String, element_id: String) -> bool:
	var once: String = str(effect.get("once", ""))
	if once.is_empty():
		return true
	var include_element: bool = once.ends_with("_per_element")
	var key: String = _relic_once_key(effect, suffix, element_id, include_element)
	if once.begins_with("turn"):
		return not _turn_flag(state, key)
	if once.begins_with("combat"):
		return not _combat_relic_flag(state, key)
	return true

func _mark_relic_once(state: Dictionary, effect: Dictionary, suffix: String, element_id: String) -> void:
	var once: String = str(effect.get("once", ""))
	if once.is_empty():
		return
	var include_element: bool = once.ends_with("_per_element")
	var key: String = _relic_once_key(effect, suffix, element_id, include_element)
	if once.begins_with("turn"):
		_set_turn_flag(state, key, true)
	elif once.begins_with("combat"):
		_set_combat_relic_flag(state, key, true)

func _relic_once_key(effect: Dictionary, suffix: String, element_id: String, include_element: bool) -> String:
	var key: String = "%s:%s:%s:%d" % [
		str(effect.get("relic_id", "")),
		str(effect.get("status", "")),
		suffix,
		int(effect.get("threshold", effect.get("amount", 0)))
	]
	if include_element:
		key = "%s:%s" % [key, element_id]
	return key

func _relic_effects(state: Dictionary) -> Array[Dictionary]:
	var relic_ids: Array = state.get("relics", []) as Array
	var key_parts := PackedStringArray()
	for relic_id_var: Variant in relic_ids:
		key_parts.append(str(relic_id_var))
	var cache_key: String = "\u001f".join(key_parts)
	if cache_key != _relic_effect_cache_key:
		_relic_effect_cache_key = cache_key
		_relic_effect_cache = GameData.relic_effects_for_ids(relic_ids)
	return _relic_effect_cache

func _relic_effect_source_name(effect: Dictionary) -> String:
	var relic_id: String = str(effect.get("relic_id", ""))
	return str(GameData.relic_def(relic_id).get("name", relic_id))

func _unit_status_amount(unit: Dictionary, status_id: String) -> int:
	if status_id == "poison":
		return int((unit.get("poison", {}) as Dictionary).get("damage", 0))
	return int(unit.get(status_id, 0))

func _combat_relic_flag_key(effect: Dictionary, suffix: String) -> String:
	return "%s:%s:%s" % [str(effect.get("relic_id", "")), str(effect.get("status", "")), suffix]

func _turn_relic_flag_key(effect: Dictionary, suffix: String) -> String:
	return "%s:%s:%s" % [str(effect.get("relic_id", "")), str(effect.get("status", "")), suffix]

func _combat_relic_flag(state: Dictionary, key: String) -> bool:
	return bool((state.get("relic_flags", {}) as Dictionary).get(key, false))

func _set_combat_relic_flag(state: Dictionary, key: String, value: Variant) -> void:
	var flags: Dictionary = state.get("relic_flags", {}).duplicate(true)
	flags[key] = value
	state["relic_flags"] = flags

func _turn_flag(state: Dictionary, key: String) -> bool:
	return bool((state.get("turn_flags", {}) as Dictionary).get(key, false))

func _set_turn_flag(state: Dictionary, key: String, value: Variant) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags[key] = value
	state["turn_flags"] = flags

func _sorted_tiles_from_lookup(lookup: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile_var: Variant in lookup.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return tiles

func _mark_first_attack_used(state: Dictionary) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags["first_attack_bonus_used"] = true
	state["turn_flags"] = flags

func _mark_first_move_used(state: Dictionary) -> void:
	var flags: Dictionary = state.get("turn_flags", {}).duplicate(true)
	flags["first_move_bonus_used"] = true
	state["turn_flags"] = flags

func _combat_seed(run_seed: int, coord: Vector2i) -> int:
	var value: int = run_seed
	value = int((value * 214013 + 2531011 + coord.x * 19349663 + coord.y * 83492791) & 0x7fffffff)
	return value

func _log(state: Dictionary, message: String) -> void:
	var log_lines: Array = state.get("log", [])
	log_lines.append(message)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)
	state["log"] = log_lines
