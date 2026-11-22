extends RefCounted
class_name ProgressionStore

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const Checkpoint = preload("res://scripts/run_checkpoint.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const LegacyCardGrowthRefunds = preload("res://scripts/legacy_card_growth_refunds.gd")
const RunScoreRules = preload("res://scripts/run_score_rules.gd")
const Chronicle = preload("res://scripts/chronicle_rules.gd")
const CHRONICLE_RECORDS_KEY: String = "chronicle_records"
const CHRONICLE_TOTALS_KEY: String = "chronicle_totals"
const CHRONICLE_RECEIPTS_KEY: String = "chronicle_completed_ids"
const BEST_SCORE_KEY: String = "best_score"
const UMBRA_DEPTH_UNLOCKED_KEY: String = "umbra_depth_unlocked"
const UMBRA_DEPTH_SELECTED_KEY: String = "umbra_depth_selected"
const UMBRA_DEPTH_BESTS_KEY: String = "umbra_depth_best_scores"

const SURFACE_RULES_VERSION: int = 5

const DEFAULT_STORAGE_PATH: String = "user://progression.json"
const DEFAULT_RUN_STORAGE_PATH: String = "user://current_run.save"
const PROGRESSION_SCHEMA: int = 7
const GRIMOIRE_UNLOCKED_KEY: String = "grimoire_unlocked"
const GRIMOIRE_UNREAD_KEY: String = "grimoire_unread"
const RUN_BESTS_KEY: String = "run_bests"
const LAST_RUN_RESULT_KEY: String = "last_run_result"
const RUN_RESULT_LEDGER_KEY: String = "completed_run_results"
const RUN_COMPLETION_IDS_KEY: String = "completed_run_ids"
const RUN_RESULT_OWNERS_KEY: String = "completed_result_owners"
const PENDING_DESCENT_ID_KEY: String = "pending_descent_run_id"
const RUN_RESULT_LEDGER_LIMIT: int = 32
const UMBRA_WARNING_AVAILABLE_RUN_KEY: String = "umbra_warning_available_run"
const UMBRA_WARNING_SEEN_KEY: String = "umbra_warning_seen"
const EMACIATED_AWAKENING_SEEN_KEY: String = "emaciated_awakening_seen"
const HEIRLOOM_KEY: String = "heirloom_equipment"
const MOLTSHARD_AWARD_IDS_KEY: String = "moltshard_award_ids"
const MOLTSHARD_AWARD_LEDGER_LIMIT: int = 64
const PROGRESSION_ANALYTICS_OUTBOX_KEY: String = "progression_analytics_outbox"
const MOLT_EXCHANGE_EMBERS: int = 250
const RUN_WALLET_RECEIPTS_KEY: String = "run_wallet_receipts"
const STARTING_RELIC_GIFTS_KEY: String = "starting_relic_gifts"
const STARTING_RELIC_GIFT_AWARDS_KEY: String = "starting_relic_gift_awards"
const DEFIANCE_LEVEL_INTERVAL: int = 4
const RUN_RESULT_STAT_IDS := [
	"enemies_killed",
	"damage_dealt",
	"damage_received",
	"depth",
	"rooms_cleared",
	"bosses_defeated"
]
const BEST_ELIGIBLE_STAT_IDS := [
	"enemies_killed",
	"damage_dealt",
	"depth",
	"rooms_cleared",
	"bosses_defeated"
]

static var _session_umbra_depth: int = -1
static var _session_depth_save_failed: bool = false
static var _storage_path: String = DEFAULT_STORAGE_PATH
static var _run_storage_path: String = DEFAULT_RUN_STORAGE_PATH
const PersistenceDisk = preload("res://scripts/persistence_disk_worker.gd")
const OrderedWriter = preload("res://scripts/ordered_background_writer.gd")
static var _run_writer := OrderedWriter.new()
enum RunFile { MISSING, UNAVAILABLE, INVALID, EXCLUDED, READY, TERMINAL, STALE }

static func set_storage_path(path: String) -> void:
	_storage_path = path if not path.is_empty() else DEFAULT_STORAGE_PATH

static func set_run_storage_path(path: String) -> void:
	flush_pending_run_saves()
	_run_storage_path = path if not path.is_empty() else DEFAULT_RUN_STORAGE_PATH

static func default_data() -> Dictionary:
	return {
		"embers": 0,
		"level": 1,
		"skill_ids": [],
		"moltshards": 0,
		MOLTSHARD_AWARD_IDS_KEY: [],
		PROGRESSION_ANALYTICS_OUTBOX_KEY: [],
		"progression_revision": 0,
		"progression_schema": PROGRESSION_SCHEMA,
		"surface_rules_version": SURFACE_RULES_VERSION,
		"rested_at_fire": false,
		"card_upgrades_unlocked": false,
		"pending_fire_rest_dialogue": false,
		"fire_rest_dialogue_seen": false,
		UMBRA_WARNING_AVAILABLE_RUN_KEY: 0,
		UMBRA_WARNING_SEEN_KEY: false,
		EMACIATED_AWAKENING_SEEN_KEY: false,
		"run_counter": 0,
		ContextualCombatTutorial.PROGRESSION_KEY: ContextualCombatTutorial.default_state(),
		"recovery_marker": {},
		BEST_SCORE_KEY: 0,
		RUN_BESTS_KEY: {},
		LAST_RUN_RESULT_KEY: {},
		RUN_RESULT_LEDGER_KEY: [],
		CHRONICLE_RECORDS_KEY: [],
		CHRONICLE_TOTALS_KEY: Chronicle.normalized_totals({}),
		CHRONICLE_RECEIPTS_KEY: [],
		GRIMOIRE_UNLOCKED_KEY: [],
		GRIMOIRE_UNREAD_KEY: []
	}

static func load_data() -> Dictionary:
	return _load_data_at(_storage_path)

static func load_data_in_tree(tree: SceneTree) -> Dictionary:
	var result: Dictionary = {}
	await PersistenceDisk.run_in_tree(tree, _read_profile_for_departure.bind(_storage_path, result))
	return result["profile"]

static func _read_profile_for_departure(path: String, result: Dictionary) -> bool:
	result["profile"] = _load_data_at(path)
	return true

static func _load_data_at(path: String) -> Dictionary:
	var loaded: Dictionary = _load_profile_dictionary(path)
	if not loaded.is_empty():
		return loaded
	loaded = _load_profile_dictionary(path + ".backup")
	return loaded if not loaded.is_empty() else default_data()

static func _load_profile_dictionary(path: String) -> Dictionary:
	var parsed: Variant = _read_profile_json(path)
	return _normalized_data(parsed) if parsed is Dictionary else {}

static func _read_profile_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var source: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return null
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

static func normalized_data(data: Dictionary) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func _normalized_data(data: Dictionary) -> Dictionary:
	if not data.has("embers"):
		data["embers"] = 0
	var source_schema: int = int(data.get("progression_schema", 1))
	if source_schema < 2:
		data = _migrated_legacy_card_upgrades(data)
	elif _has_retired_card_growth(data):
		data = _migrated_legacy_card_upgrades(data)
	if source_schema < 3:
		data = _migrated_legacy_stats(data)
	if source_schema < 6:
		data = _migrated_legacy_combat_unit_history(data)
	# Retired history is disposable and never participates in profile recovery.
	data.erase("recent_events")
	data["run_counter"] = maxi(0, int(data.get("run_counter", 0)))
	if data.has(HEIRLOOM_KEY):
		var item: String = str(data[HEIRLOOM_KEY])
		if GameData.equipment_def(item).is_empty(): data.erase(HEIRLOOM_KEY)
	data[ContextualCombatTutorial.PROGRESSION_KEY] = ContextualCombatTutorial.normalized_state(
		data.get(ContextualCombatTutorial.PROGRESSION_KEY, null)
	)
	data.erase(ContextualCombatTutorial.LEGACY_PROGRESSION_KEY)
	data["level"] = clampi(int(data.get("level", 1)), 1, GameData.max_progression_level())
	var earned_skill_count: int = skill_points_for_level(int(data.get("level", 1)))
	var serialized_skill_ids: Array[String] = SkillTreeLibrary.normalized_ids(data.get("skill_ids", []))
	var source_skill_ids: Array[String]
	for skill_id: String in serialized_skill_ids:
		if not SkillTreeLibrary.is_retired(skill_id) and not SkillTreeLibrary.is_demo_locked(skill_id):
			source_skill_ids.append(skill_id)
	var retired_skill_count: int = serialized_skill_ids.size() - source_skill_ids.size()
	# Schema 4 required a complete allocation at every level. Preserve those
	# profiles exactly during migration, then allow schema 5 profiles to bank any
	# number of earned points without normalization silently spending them. A
	# retired skill is an explicit refund: never fill its vacated point during an
	# older complete-allocation migration.
	var repair_target: int = earned_skill_count if source_schema < 5 else mini(source_skill_ids.size(), earned_skill_count)
	if retired_skill_count > 0:
		repair_target = mini(source_skill_ids.size(), earned_skill_count)
	var repaired_skill_ids: Array[String] = SkillTreeLibrary.repaired_selection(source_skill_ids, repair_target, source_skill_ids)
	if (
		retired_skill_count > 0
		or (
			source_schema < 4
			and earned_skill_count == SkillTreeLibrary.COMPLETE_BUILD_SIZE
			and source_skill_ids.size() == earned_skill_count
			and not _skill_selection_has_keystone(source_skill_ids)
			and repaired_skill_ids != source_skill_ids
		)
	):
		data["progression_revision"] = int(data.get("progression_revision", 0)) + 1
	data["skill_ids"] = repaired_skill_ids
	data["progression_schema"] = PROGRESSION_SCHEMA
	data["surface_rules_version"] = SURFACE_RULES_VERSION
	data["moltshards"] = maxi(0, int(data.get("moltshards", 0)))
	var award_ids: Array = _normalized_string_array(data.get(MOLTSHARD_AWARD_IDS_KEY, []))
	if award_ids.size() > MOLTSHARD_AWARD_LEDGER_LIMIT:
		award_ids = award_ids.slice(award_ids.size() - MOLTSHARD_AWARD_LEDGER_LIMIT)
	data[MOLTSHARD_AWARD_IDS_KEY] = award_ids
	data[PROGRESSION_ANALYTICS_OUTBOX_KEY] = _normalized_progression_analytics_outbox(
		data.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	)
	data["progression_revision"] = maxi(0, int(data.get("progression_revision", 0)))
	data.erase("stats")
	data.erase("unspent_stat_points")
	data.erase("purchased_upgrades")
	data.erase("card_upgrades")
	data.erase("card_mods")
	if not data.has("rested_at_fire"):
		data["rested_at_fire"] = false
	if not data.has("card_upgrades_unlocked"):
		data["card_upgrades_unlocked"] = bool(data.get("rested_at_fire", false))
	if not data.has("pending_fire_rest_dialogue"):
		data["pending_fire_rest_dialogue"] = false
	if not data.has("fire_rest_dialogue_seen"):
		data["fire_rest_dialogue_seen"] = false
	data[UMBRA_WARNING_AVAILABLE_RUN_KEY] = maxi(0, int(data.get(UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)))
	data[UMBRA_WARNING_SEEN_KEY] = bool(data.get(UMBRA_WARNING_SEEN_KEY, false))
	data[EMACIATED_AWAKENING_SEEN_KEY] = bool(data.get(EMACIATED_AWAKENING_SEEN_KEY, false))
	if not data.has("recovery_marker"):
		data["recovery_marker"] = {}
	data[CHRONICLE_RECORDS_KEY] = Chronicle.normalized_records(data.get(CHRONICLE_RECORDS_KEY, []))
	data[CHRONICLE_TOTALS_KEY] = Chronicle.normalized_totals(data.get(CHRONICLE_TOTALS_KEY, {}))
	var chronicle_receipts: Array = _normalized_string_array(data.get(CHRONICLE_RECEIPTS_KEY, []))
	for record: Dictionary in data[CHRONICLE_RECORDS_KEY]:
		if not chronicle_receipts.has(record["run_id"]):
			chronicle_receipts.append(record["run_id"])
	data[CHRONICLE_RECEIPTS_KEY] = chronicle_receipts
	data[BEST_SCORE_KEY] = maxi(0, int(data.get(BEST_SCORE_KEY, 0)))
	# Missing Depth fields are zero/empty, preserving legacy state hashes.
	if data.has(UMBRA_DEPTH_UNLOCKED_KEY): data[UMBRA_DEPTH_UNLOCKED_KEY] = unlocked_umbra_depth(data)
	if data.has(UMBRA_DEPTH_SELECTED_KEY): data[UMBRA_DEPTH_SELECTED_KEY] = selected_umbra_depth(data)
	if data.has(UMBRA_DEPTH_BESTS_KEY): data[UMBRA_DEPTH_BESTS_KEY] = depth_best_scores(data)
	data[RUN_BESTS_KEY] = _normalized_run_metric_map(data.get(RUN_BESTS_KEY, {}), BEST_ELIGIBLE_STAT_IDS)
	data[LAST_RUN_RESULT_KEY] = _normalized_last_run_result(data.get(LAST_RUN_RESULT_KEY, {}))
	var completed_results: Array[Dictionary] = _normalized_run_result_ledger(data.get(RUN_RESULT_LEDGER_KEY, []))
	var last_result: Dictionary = data.get(LAST_RUN_RESULT_KEY, {}) as Dictionary
	if not last_result.is_empty() and _result_index_for_id(completed_results, str(last_result.get("result_id", ""))) < 0:
		completed_results.append(last_result.duplicate(true))
	data[RUN_RESULT_LEDGER_KEY] = _bounded_run_result_ledger(completed_results)
	if data.has(RUN_COMPLETION_IDS_KEY):
		data[RUN_COMPLETION_IDS_KEY] = _normalized_string_array(data[RUN_COMPLETION_IDS_KEY])
	data[GRIMOIRE_UNLOCKED_KEY] = _normalized_string_array(data.get(GRIMOIRE_UNLOCKED_KEY, []))
	data[GRIMOIRE_UNREAD_KEY] = _normalized_string_array(data.get(GRIMOIRE_UNREAD_KEY, []))
	if data.has(STARTING_RELIC_GIFTS_KEY):
		data[STARTING_RELIC_GIFTS_KEY] = pending_starting_relic_gifts(data)
	return data

static func _migrated_legacy_combat_unit_history(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = data.duplicate(true)
	if typeof(next_data.get(RUN_BESTS_KEY, null)) == TYPE_DICTIONARY:
		next_data[RUN_BESTS_KEY] = _migrated_legacy_metric_map(
			next_data.get(RUN_BESTS_KEY, {}) as Dictionary
		)
	if typeof(next_data.get(LAST_RUN_RESULT_KEY, null)) == TYPE_DICTIONARY:
		next_data[LAST_RUN_RESULT_KEY] = _migrated_legacy_run_result(
			next_data.get(LAST_RUN_RESULT_KEY, {}) as Dictionary
		)
	if typeof(next_data.get(RUN_RESULT_LEDGER_KEY, null)) == TYPE_ARRAY:
		var results: Array = []
		for result_var: Variant in next_data.get(RUN_RESULT_LEDGER_KEY, []) as Array:
			if typeof(result_var) == TYPE_DICTIONARY:
				results.append(_migrated_legacy_run_result(result_var as Dictionary))
		next_data[RUN_RESULT_LEDGER_KEY] = results
	if typeof(next_data.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, null)) == TYPE_ARRAY:
		var outbox: Array = []
		for entry_var: Variant in next_data.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, []) as Array:
			if typeof(entry_var) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = (entry_var as Dictionary).duplicate(true)
			if typeof(entry.get("context", null)) == TYPE_DICTIONARY:
				var context: Dictionary = _migrated_legacy_analytics_units(
					entry.get("context", {}) as Dictionary
				)
				context["combat_unit_scale"] = 1
				entry["context"] = context
			if typeof(entry.get("payload", null)) == TYPE_DICTIONARY:
				var payload: Dictionary = _migrated_legacy_analytics_units(
					entry.get("payload", {}) as Dictionary
				)
				payload["combat_unit_scale"] = 1
				entry["payload"] = payload
			outbox.append(entry)
		next_data[PROGRESSION_ANALYTICS_OUTBOX_KEY] = outbox
	return next_data

static func _migrated_legacy_metric_map(metrics: Dictionary) -> Dictionary:
	var next_metrics: Dictionary = metrics.duplicate(true)
	for field: String in ["damage_dealt", "damage_received"]:
		if next_metrics.has(field):
			next_metrics[field] = _legacy_cumulative_units(int(next_metrics.get(field, 0)))
	return next_metrics

static func _migrated_legacy_run_result(result: Dictionary) -> Dictionary:
	var next_result: Dictionary = result.duplicate(true)
	if typeof(next_result.get("stats", null)) == TYPE_DICTIONARY:
		next_result["stats"] = _migrated_legacy_metric_map(next_result.get("stats", {}) as Dictionary)
	return next_result

static func _migrated_legacy_analytics_units(value: Dictionary) -> Dictionary:
	var migrated: Dictionary = value.duplicate(false)
	var survivor_fields: Array[String] = TypedArrays.strings([
		"player_hp",
		"player_max_hp",
		"player_start_hp",
		"hp_loss",
		"block_loss",
		"stoneskin_loss",
		"restored_hp",
		"lethal_hp_loss",
		"defiance_restored"
	])
	var cumulative_fields: Array[String] = TypedArrays.strings(["damage", "damage_dealt", "damage_received"])
	for key_var: Variant in value.keys():
		var key: String = str(key_var)
		var child: Variant = value.get(key_var)
		if typeof(child) == TYPE_DICTIONARY:
			migrated[key_var] = _migrated_legacy_analytics_units(child as Dictionary)
		elif typeof(child) == TYPE_ARRAY:
			var source_array: Array = child as Array
			var migrated_array: Array = source_array.duplicate(false)
			for index: int in range(source_array.size()):
				if typeof(source_array[index]) == TYPE_DICTIONARY:
					migrated_array[index] = _migrated_legacy_analytics_units(source_array[index] as Dictionary)
			migrated[key_var] = migrated_array
		elif key in survivor_fields and typeof(child) in [TYPE_INT, TYPE_FLOAT]:
			migrated[key_var] = _legacy_survivor_units(int(child))
		elif key in cumulative_fields and typeof(child) in [TYPE_INT, TYPE_FLOAT]:
			migrated[key_var] = _legacy_cumulative_units(int(child))
	return migrated

static func _legacy_survivor_units(value: int) -> int:
	if value <= 0:
		return value
	return int((value + GameData.LEGACY_FIXED_POINT_SCALE - 1) / GameData.LEGACY_FIXED_POINT_SCALE)

static func _legacy_cumulative_units(value: int) -> int:
	if value <= 0:
		return value
	return int((value + int(GameData.LEGACY_FIXED_POINT_SCALE / 2)) / GameData.LEGACY_FIXED_POINT_SCALE)

static func _skill_selection_has_keystone(skill_ids: Array[String]) -> bool:
	for skill_id: String in skill_ids:
		if SkillTreeLibrary.is_keystone(skill_id):
			return true
	return false

static func _has_retired_card_growth(data: Dictionary) -> bool:
	if typeof(data.get("purchased_upgrades", [])) == TYPE_ARRAY and not (data.get("purchased_upgrades", []) as Array).is_empty():
		return true
	if typeof(data.get("card_upgrades", {})) == TYPE_DICTIONARY and not (data.get("card_upgrades", {}) as Dictionary).is_empty():
		return true
	return typeof(data.get("card_mods", {})) == TYPE_DICTIONARY and not (data.get("card_mods", {}) as Dictionary).is_empty()

static func _migrated_legacy_card_upgrades(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = data.duplicate(true)
	var refund: int = 0
	var seen_upgrades: Dictionary = {}
	for upgrade_id_var: Variant in next_data.get("purchased_upgrades", []):
		var upgrade_id: String = str(upgrade_id_var)
		if upgrade_id.is_empty() or seen_upgrades.has(upgrade_id):
			continue
		seen_upgrades[upgrade_id] = true
		refund += maxi(LegacyCardGrowthRefunds.cost(upgrade_id), GameData.upgrade_cost(upgrade_id))
	for upgrade_id_var: Variant in (next_data.get("card_upgrades", {}) as Dictionary).values():
		var upgrade_id: String = str(upgrade_id_var)
		if upgrade_id.is_empty() or seen_upgrades.has(upgrade_id):
			continue
		seen_upgrades[upgrade_id] = true
		refund += maxi(LegacyCardGrowthRefunds.cost(upgrade_id), GameData.upgrade_cost(upgrade_id))
	var legacy_mods_by_card: Dictionary = {}
	if typeof(next_data.get("card_mods", {})) == TYPE_DICTIONARY:
		legacy_mods_by_card = (next_data.get("card_mods", {}) as Dictionary).duplicate(true)
	for mods_var: Variant in legacy_mods_by_card.values():
		if typeof(mods_var) != TYPE_ARRAY:
			continue
		for mod_var: Variant in (mods_var as Array):
			if typeof(mod_var) != TYPE_DICTIONARY:
				continue
			refund += maxi(0, int((mod_var as Dictionary).get("cost_paid", 0)))
	next_data["embers"] = maxi(0, int(next_data.get("embers", 0)) + refund)
	next_data["purchased_upgrades"] = []
	next_data["card_upgrades"] = {}
	next_data["card_mods"] = {}
	next_data["rested_at_fire"] = false
	next_data["card_upgrades_unlocked"] = false
	next_data["pending_fire_rest_dialogue"] = false
	next_data["fire_rest_dialogue_seen"] = false
	return next_data

static func _migrated_legacy_stats(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = data.duplicate(true)
	var level: int = clampi(int(next_data.get("level", 1)), 1, GameData.max_progression_level())
	var legacy_stats: Dictionary = GameData.normalized_legacy_progression_stats(next_data.get("stats", {}))
	var preference: Array[String] = _legacy_skill_preference(legacy_stats)
	next_data["skill_ids"] = SkillTreeLibrary.repaired_selection([], skill_points_for_level(level), preference)
	next_data["moltshards"] = maxi(0, int(next_data.get("moltshards", 0)))
	next_data.erase("stats")
	next_data.erase("unspent_stat_points")
	return next_data

static func _legacy_skill_preference(legacy_stats: Dictionary) -> Array[String]:
	var branch_scores: Dictionary = {
		"tactics": int(legacy_stats.get("might", 0)) + int(legacy_stats.get("dexterity", 0)) + int(legacy_stats.get("focus", 0)),
		"resolve": int(legacy_stats.get("vigor", 0)) + int(legacy_stats.get("guard", 0)),
		"traverse": int(legacy_stats.get("agility", 0)) + int(legacy_stats.get("air_magick", 0)),
		"foresight": int(legacy_stats.get("fire_magick", 0)) + int(legacy_stats.get("ice_magick", 0)) + int(legacy_stats.get("lightning_magick", 0)) + int(legacy_stats.get("earth_magick", 0))
	}
	var branch_order: Array[String]
	branch_order.append_array(["tactics", "resolve", "traverse", "foresight"])
	branch_order.sort_custom(func(left: String, right: String) -> bool:
		var left_score: int = int(branch_scores.get(left, 0))
		var right_score: int = int(branch_scores.get(right, 0))
		if left_score != right_score:
			return left_score > right_score
		return SkillTreeLibrary.BRANCH_ORDER.find(left) < SkillTreeLibrary.BRANCH_ORDER.find(right)
	)
	var result: Array[String]
	var ordered: Array[String] = SkillTreeLibrary.ordered_ids()
	for branch_id: String in branch_order:
		for skill_id: String in ordered:
			var skill_def: Dictionary = SkillTreeLibrary.definition(skill_id)
			if str(skill_def.get("branch", "")) == branch_id:
				result.append(skill_id)
	for skill_id: String in ordered:
		if not result.has(skill_id):
			result.append(skill_id)
	return result

static func _normalized_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_var: Variant in value:
		var item_id: String = str(item_var)
		if item_id.is_empty() or result.has(item_id):
			continue
		result.append(item_id)
	return result

static func _normalized_progression_analytics_outbox(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if typeof(value) != TYPE_ARRAY:
		return result
	var seen_keys: Dictionary = {}
	for entry_var: Variant in value as Array:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var event_type: String = str(entry.get("event_type", "")).strip_edges()
		var idempotency_key: String = str(entry.get("idempotency_key", "")).strip_edges()
		var context: Dictionary = {}
		if typeof(entry.get("context", null)) == TYPE_DICTIONARY:
			context = (entry.get("context", {}) as Dictionary).duplicate(true)
		idempotency_key = _progression_event_key(event_type, idempotency_key, context)
		if event_type.is_empty() or idempotency_key.is_empty() or seen_keys.has(idempotency_key):
			continue
		seen_keys[idempotency_key] = true
		var payload: Dictionary = {}
		if typeof(entry.get("payload", null)) == TYPE_DICTIONARY:
			payload = (entry.get("payload", {}) as Dictionary).duplicate(true)
		if event_type == "combat_ended":
			for field: String in ["objective_completion_tile", "objective_completion_door", "objective_completion_destination", "room_coord"]:
				var value_at_field: Variant = payload.get(field)
				if value_at_field is String and value_at_field.begins_with("(") and value_at_field.ends_with(")"):
					var parts: PackedStringArray = value_at_field.substr(1, value_at_field.length() - 2).split(",")
					if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
						payload[field] = {"x": int(parts[0]), "y": int(parts[1])}
		result.append({
			"event_type": event_type,
			"idempotency_key": idempotency_key,
			"context": context,
			"payload": payload,
		})
	return result

static func save_data(data: Dictionary) -> bool:
	return PersistenceDisk.run(_prepare_profile_write(data))

static func save_data_in_tree(tree: SceneTree, data: Dictionary) -> bool:
	return await PersistenceDisk.run_in_tree(tree, _prepare_profile_write(data))

static func _prepare_profile_write(data: Dictionary) -> Callable:
	var saved_data: Dictionary = _normalized_data(data.duplicate(true))
	if DemoBuild.is_demo(): saved_data["build_kind"] = "demo"
	var bytes: PackedByteArray = JSON.stringify(saved_data, "\t").to_utf8_buffer()
	return _write_profile_at.bind(_storage_path, bytes)

static func _write_profile_at(path: String, bytes: PackedByteArray) -> bool:
	var temp_path: String = "%s.tmp" % path
	var backup_path: String = "%s.backup" % path
	if not _archive_before_surface_migration(path, true) or not _archive_before_surface_migration(backup_path, true):
		return false
	_remove_profile_file_if_present(temp_path)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	file.close()
	if _load_profile_dictionary(temp_path).is_empty():
		_remove_profile_file_if_present(temp_path)
		return false
	var live_path: String = ProjectSettings.globalize_path(path)
	var live_exists: bool = FileAccess.file_exists(path)
	var live_valid: bool = live_exists and not _load_profile_dictionary(path).is_empty()
	var backup_valid: bool = false
	if live_valid:
		_remove_profile_file_if_present(backup_path)
		if DirAccess.rename_absolute(live_path, ProjectSettings.globalize_path(backup_path)) != OK:
			_remove_profile_file_if_present(temp_path)
			return false
		backup_valid = true
	else:
		backup_valid = not _load_profile_dictionary(backup_path).is_empty()
		if live_exists:
			if DirAccess.remove_absolute(live_path) != OK:
				_remove_profile_file_if_present(temp_path)
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), live_path) != OK:
		if backup_valid and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), live_path)
		_remove_profile_file_if_present(temp_path)
		return false
	_remove_profile_file_if_present(backup_path)
	return true

static func _profile_temp_path() -> String:
	return "%s.tmp" % _storage_path

static func _profile_backup_path() -> String:
	return "%s.backup" % _storage_path

static func _remove_profile_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func has_saved_run() -> bool:
	flush_pending_run_saves()
	return FileAccess.file_exists(_run_storage_path) or FileAccess.file_exists(_run_backup_path())

static func load_saved_run() -> Dictionary:
	# Low-level Variant reader used by migration and persistence diagnostics.
	return _read_saved_run(false).get("state", {})

static func read_resumable_checkpoint(recover_terminal_profile: bool = false, for_replacement: bool = false) -> Dictionary:
	return _read_saved_run(true, recover_terminal_profile, for_replacement)

static func load_checkpoint_for_replacement() -> Dictionary:
	return _read_saved_run(true, false, true, true)

static func load_checkpoint_for_resume() -> Dictionary:
	return _read_saved_run(true, true, false, true).get("state", {})

static func _read_saved_run(require_structure: bool, recover_terminal_profile: bool = false, for_replacement: bool = false, promote_backup: bool = false) -> Dictionary:
	flush_pending_run_saves()
	var profile := _read_completion_profile() if require_structure else {}
	var live := _read_checkpoint_at(_run_storage_path, require_structure, profile, recover_terminal_profile, for_replacement)
	# A terminal record owns its outstanding settlement. A finalized record
	# can coexist with an independently playable backup from a sync conflict.
	var finalized: bool = live["status"] == RunFile.TERMINAL and not live.get("settlement_pending", false)
	if not finalized and live["status"] not in [RunFile.MISSING, RunFile.INVALID, RunFile.STALE]: return live
	var backup := _read_checkpoint_at(_run_backup_path(), require_structure, profile, recover_terminal_profile, for_replacement, promote_backup)
	if finalized and backup["status"] != RunFile.READY: return live
	if live["status"] == RunFile.STALE and backup["status"] in [RunFile.INVALID, RunFile.EXCLUDED]:
		return live
	if promote_backup and backup.has("state"):
		if not PersistenceDisk.run(_promote_resume_backup_at.bind(_run_storage_path, backup["bytes"])):
			push_error("Failed to promote the selected run backup.")
			return {"status": RunFile.UNAVAILABLE}
		backup.erase("bytes")
	return live if backup["status"] == RunFile.MISSING else backup

static func _read_checkpoint_at(path: String, require_structure: bool, profile: Dictionary, recover_terminal_profile: bool, for_replacement: bool, retain_bytes: bool = false) -> Dictionary:
	var inspection := _inspect_run_file(path, retain_bytes)
	var status: int = inspection["status"]
	if status != RunFile.READY: return {"status": status}
	var state: Dictionary = inspection["state"]
	# Keep the demo cutoff authoritative so an older backup cannot bypass it.
	if Checkpoint.past_demo_cutoff(state):
		return {"status": RunFile.EXCLUDED}
	if not Checkpoint.build_stamp_allowed(state):
		return {"status": RunFile.INVALID if require_structure else RunFile.EXCLUDED}
	var summary: Dictionary = {}
	if require_structure:
		summary = Checkpoint.validated_resume_summary(state)
		if summary.is_empty():
			if not Checkpoint.is_terminal_record(state):
				return {"status": RunFile.STALE if has_completed_run(profile, state) else RunFile.INVALID}
			# A run scene already asked to resume may need to repair a bank or
			# recovery marker whose profile write failed after the heirloom choice.
			# Title Continue uses the ordinary resume summary.
			var pending := terminal_profile_write_pending(state, profile) or embrace_settlement_pending(state, profile)
			if state.get("mode") in ["victory", "defeat"] and not completion_run_id(state).is_empty():
				pending = pending or not has_completed_run(profile, state)
			if for_replacement or (recover_terminal_profile and pending):
				inspection["status"] = RunFile.TERMINAL
				inspection["state"] = _migrate_run_dictionary(state)
				inspection["settlement_pending"] = pending
				return inspection
			return {"status": RunFile.TERMINAL, "settlement_pending": pending}
		# The release summary already validates an unanswered terminal prompt.
		# Only active gameplay can be hidden by a matching completion receipt.
		if summary["mode"] not in ["victory", "defeat"] and has_completed_run(profile, state):
			return {"status": RunFile.STALE}
	inspection["state"] = _migrate_run_dictionary(state)
	inspection["summary"] = summary
	return inspection

static func _promote_resume_backup_at(path: String, bytes: PackedByteArray) -> bool:
	if not _archive_before_surface_migration(path, false): return false
	var temporary := path + ".tmp"
	_remove_run_file_if_present(temporary)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	var written := file.store_buffer(bytes)
	file.flush()
	file.close()
	if written and FileAccess.get_file_as_bytes(temporary) == bytes:
		# Windows may remove the old live file during rename. Keep the
		# selected backup in place throughout so every cut still owns it.
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK:
			return true
	_remove_run_file_if_present(temporary)
	return false

static func _read_completion_profile() -> Dictionary:
	# Match the profile reader's live/backup order without normalizing unrelated
	# stats, skills and history on each title Continue refresh.
	var profile: Variant = _read_profile_json(_storage_path)
	if profile is Dictionary: return profile
	profile = _read_profile_json(_profile_backup_path())
	return profile if profile is Dictionary else {}

static func embrace_settlement_pending(state: Dictionary, profile: Dictionary) -> bool:
	return state.get("mode") == "embrace" and bool(state.get("embrace_settlement", false)) and not has_completed_run(profile, state)

static func terminal_profile_write_pending(state: Dictionary, profile: Dictionary) -> bool:
	if state.get("mode") not in ["victory", "defeat"]: return false
	var wallet: Variant = state.get("heirloom_terminal_wallet")
	var embedded: Variant = state.get("progression")
	if not wallet is Dictionary or wallet.is_empty() or not embedded is Dictionary: return false
	var revision: Variant = embedded.get("progression_revision", 0)
	return revision is int and revision > int(profile.get("progression_revision", 0))

static func _load_run_dictionary(path: String) -> Dictionary:
	var inspection := _inspect_run_file(path)
	return _migrate_run_dictionary(inspection["state"]) if inspection["status"] == RunFile.READY else {}

static func _migrate_run_dictionary(data: Dictionary) -> Dictionary:
	# Variant decoding gives this call a fresh, owned graph. Returning it
	# directly avoids cloning the entire save once more during resume/recovery.
	preload("res://scripts/arc_thrall_save_migration.gd").migrate(data)
	preload("res://scripts/enemy_mechanics/retired_intents.gd").migrate(data)
	# Raw legacy-unit fights need unit repair before inserting natural intents.
	preload("res://scripts/retired_mirror_save_migration.gd").migrate(data, int(data.get("combat_units_schema", 0)) >= 1)
	_migrate_retired_battlefield_pieces(data)
	if data.get("combat_state", {}) is Dictionary:
		preload("res://scripts/guardian_combat_rules.gd").migrate_saved_combat(data.get("combat_state", {}))
	preload("res://scripts/dragon_combat_rules.gd").migrate_save(data)
	preload("res://scripts/worldspine_save_migration.gd").migrate(data)
	if data.get("combat_state", {}) is Dictionary:
		preload("res://scripts/boss_area_rules.gd").migrate_combat(data.get("combat_state", {}))
	return data

static func _migrate_retired_battlefield_pieces(value: Variant) -> void:
	if value is Array:
		for child: Variant in value: _migrate_retired_battlefield_pieces(child)
	elif value is Dictionary:
		# Keep a saved intent's identity, Time and held geometry, replacing only
		# the retired action payload so it can resume through the shared pieces.
		match str(value.get("type", "")):
			"grow_bramble":
				for key: String in ["shape", "rounds", "pushed_damage", "pushed_bleed"]: value.erase(key)
				value.merge({"type": "upheaval_mark", "pattern": "line_between", "length": 3, "health": 3}, true)
			"icefall_land":
				for key: String in ["terrain", "terrain_rounds", "pillar_shatter_damage"]: value.erase(key)
		for key: Variant in value:
			if str(key) in ["analytics", "analytics_context", "analytics_events", "progression_analytics_outbox", "completed_run_results", "last_run_result", "log", "surface_events", "elemental_source", "rubble_source"]: continue
			if str(key) == "terrain" and value[key] is Array:
				value[key] = value[key].filter(func(entry: Variant) -> bool: return not entry is Dictionary or str(entry.get("kind", "")) not in ["bramble", "ice_pillar"])
			else: _migrate_retired_battlefield_pieces(value[key])

static func _run_dictionary_is_nonempty(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = file.get_var(false)
	file.close()
	return typeof(data) == TYPE_DICTIONARY and not (data as Dictionary).is_empty()

# The synchronous API remains a durability barrier for callers that need one.
static func save_run_state(run_state: Dictionary) -> bool:
	queue_run_state(run_state)
	return flush_pending_run_saves()

static func install_replacement_run(run_state: Dictionary) -> bool:
	# An earlier checkpoint keeps its retry policy. A rejected New Run must
	# never enter that queue, even if the failing file operation later recovers.
	if not flush_pending_run_saves(): return false
	return _save_run_state_at(_run_storage_path, run_state)

static func queue_run_state(run_state: Dictionary, failure_boundary: String = "") -> bool:
	return queue_owned_run_state(run_state.duplicate(true), failure_boundary)

static func queue_owned_run_state(state: Dictionary, failure_boundary: String, receipt: OrderedWriter.Receipt = null,
		settled: Callable = Callable()) -> bool:
	# Defer encoding to dispatch so superseded checkpoints are never encoded.
	# Only the owned snapshot is read during preparation on the game thread.
	var request: Dictionary = {"reported": false}
	_run_writer.submit_prepared(_prepare_run_state_at.bind(_run_storage_path, state), true,
		_report_run_write.bind(failure_boundary, request, settled), receipt)
	return true

static func _prepare_run_state_at(path: String, state: Dictionary, transaction_probe: Callable = Callable(),
		force_backup_rotation: bool = false) -> Callable:
	# FileAccess.store_var(false) writes a little-endian length followed by the
	# same object-free Variant payload as var_to_bytes(). Keep both finished
	# buffers separate to avoid copying the full room graph into a second array.
	var payload: PackedByteArray = var_to_bytes(state)
	var length: PackedByteArray = [0, 0, 0, 0]
	length.encode_u32(0, payload.size())
	var rotate_live: bool = force_backup_rotation or OS.get_name() == "Windows"
	return _write_run_state_at.bind(path, length, payload, not state.is_empty(), transaction_probe, rotate_live)

static func _report_run_write(saved: bool, failure_boundary: String, request: Dictionary, settled: Callable) -> void:
	if not saved and not bool(request["reported"]) and not failure_boundary.is_empty():
		push_error("Failed to persist committed run boundary: %s" % failure_boundary)
		request["reported"] = true
	if settled.is_valid(): settled.call(saved)

static func poll_pending_run_saves(idle: bool = true) -> void:
	_run_writer.poll(idle)
	_run_writer.take_failure() # The owning boundary reports its original error once.

static func flush_pending_run_saves() -> bool:
	var succeeded: bool = _run_writer.flush()
	_run_writer.take_failure()
	return succeeded

static func flush_pending_run_saves_in_tree(tree: SceneTree) -> bool:
	var succeeded: bool = await _run_writer.flush_in_tree(tree)
	_run_writer.take_failure()
	return succeeded

static func _save_run_state_at(run_path: String, run_state: Dictionary, transaction_probe: Callable = Callable(),
		force_backup_rotation: bool = false) -> bool:
	return PersistenceDisk.run(_prepare_run_state_at(run_path, run_state, transaction_probe, force_backup_rotation))

static func _write_run_state_at(run_path: String, length: PackedByteArray, payload: PackedByteArray,
		validate: bool, transaction_probe: Callable, rotate_live: bool) -> bool:
	# Reuse this transaction's inspection for migration and crash recovery. Both
	# used to deserialize the entire previous run independently on every save.
	# Never cache across transactions: externally restored/corrupt files must be
	# inspected again. The newly written temporary file is still read back below.
	var live_inspection: Dictionary = _inspect_run_file(run_path)
	var backup_inspection: Dictionary = _inspect_run_file("%s.backup" % run_path)
	if not _archive_before_surface_migration(run_path, false, live_inspection) or not _archive_before_surface_migration("%s.backup" % run_path, false, backup_inspection):
		return false
	var temp_path: String = "%s.tmp" % run_path
	var backup_path: String = "%s.backup" % run_path
	_remove_run_file_if_present(temp_path)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var written: bool = file.store_buffer(length)
	if written and transaction_probe.is_valid():
		file.flush()
		written = transaction_probe.call("temporary_started")
	if written: written = file.store_buffer(payload)
	file.flush()
	file.close()
	if not written or FileAccess.get_size(temp_path) != length.size() + payload.size() or (validate and not _run_dictionary_is_nonempty(temp_path)):
		_remove_run_file_if_present(temp_path)
		return false
	if transaction_probe.is_valid() and not transaction_probe.call("temporary_validated"): return false
	var live_path: String = ProjectSettings.globalize_path(run_path)
	var recovery_path: String = ProjectSettings.globalize_path(backup_path) if rotate_live else ""
	var backup_valid: bool = rotate_live and _inspection_is_authoritative(backup_inspection)
	# Windows DirAccess removes an existing target before renaming. Rotate a
	# valid live file first so a process crash leaves it readable as .backup.
	# On platforms with atomic replacement the live file can stay in place.
	if rotate_live and _inspection_is_authoritative(live_inspection):
		if DirAccess.rename_absolute(live_path, recovery_path) != OK:
			_remove_run_file_if_present(temp_path)
			return false
		backup_valid = true
	if transaction_probe.is_valid() and not transaction_probe.call("recovery_ready"): return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), live_path) != OK:
		if rotate_live and backup_valid and not FileAccess.file_exists(run_path):
			DirAccess.rename_absolute(recovery_path, live_path)
		_remove_run_file_if_present(temp_path)
		return false
	if transaction_probe.is_valid() and not transaction_probe.call("promoted"): return false
	_remove_run_file_if_present(backup_path)
	return true

static func clear_saved_run() -> bool:
	flush_pending_run_saves()
	_run_writer.cancel_pending()
	return _report_run_clear(PersistenceDisk.run(_clear_run_at.bind(_run_storage_path)))

static func clear_saved_run_in_tree(tree: SceneTree) -> bool:
	await flush_pending_run_saves_in_tree(tree)
	_run_writer.cancel_pending()
	return _report_run_clear(await PersistenceDisk.run_in_tree(tree, _clear_run_at.bind(_run_storage_path)))

static func _report_run_clear(cleared: bool) -> bool:
	if not cleared: push_warning("Could not clear the saved run.")
	return cleared

static func _clear_run_at(path: String) -> bool:
	# A terminal legacy save can reach clearing without another combat write.
	# Preserve its original bytes before the normal live/recovery cleanup.
	if not _archive_before_surface_migration(path, false) or not _archive_before_surface_migration(path + ".backup", false):
		return false
	# Keep the live checkpoint authoritative until both recovery paths are gone.
	return _delete_run_file(path + ".backup") and _delete_run_file(path + ".tmp") and _delete_run_file(path)

static func _delete_run_file(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var parent := DirAccess.open(absolute.get_base_dir())
	if parent == null: return DirAccess.get_open_error() == ERR_FILE_NOT_FOUND
	var name := absolute.get_file()
	if parent.dir_exists(name) and not parent.is_link(name): return false
	parent.remove(name)
	# Enumerate the directory to verify absence, including entries whose file
	# attributes cannot be read or whose symlink target no longer exists.
	parent.include_hidden = true
	if parent.list_dir_begin() != OK: return false
	var entry := parent.get_next()
	while not entry.is_empty():
		if entry.nocasecmp_to(name) == 0:
			parent.list_dir_end()
			return false
		entry = parent.get_next()
	parent.list_dir_end()
	return true

static func _inspect_run_file(path: String, retain_bytes: bool = false) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		if DirAccess.dir_exists_absolute(path): return {"status": RunFile.INVALID}
		var missing: bool = error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path)
		return {"status": RunFile.MISSING if missing else RunFile.UNAVAILABLE}
	# Read the stored Variant frame explicitly. A short read of a known-present
	# byte range is an I/O failure even if the platform reports EOF.
	var size := file.get_length()
	if file.get_error() != OK: return {"status": RunFile.UNAVAILABLE}
	var header := file.get_buffer(4)
	var read_error := file.get_error()
	if read_error not in [OK, ERR_FILE_EOF] or (header.size() < 4 and size >= 4):
		return {"status": RunFile.UNAVAILABLE}
	if header.size() < 4: return {"status": RunFile.INVALID}
	if size < 4: return {"status": RunFile.UNAVAILABLE}
	var length := header.decode_u32(0)
	if length < 4 or length > size - 4: return {"status": RunFile.INVALID}
	var payload := file.get_buffer(length)
	read_error = file.get_error()
	if read_error != OK or payload.size() != length: return {"status": RunFile.UNAVAILABLE}
	var raw: Variant = bytes_to_var(payload)
	if not raw is Dictionary or raw.is_empty(): return {"status": RunFile.INVALID}
	Checkpoint.normalize_seed(raw)
	var result := {"status": RunFile.READY, "state": raw}
	if retain_bytes:
		var trailing_length: int = size - length - 4
		if trailing_length > 0:
			var trailing := file.get_buffer(trailing_length)
			if trailing.size() != trailing_length or file.get_error() != OK: return {"status": RunFile.UNAVAILABLE}
			payload.append_array(trailing)
		header.append_array(payload)
		result["bytes"] = header
	file.close()
	return result

static func _inspection_is_authoritative(inspection: Dictionary) -> bool:
	if inspection["status"] != RunFile.READY: return false
	var state: Dictionary = inspection["state"]
	return Checkpoint.is_terminal_record(state) or not Checkpoint.validated_resume_summary(state).is_empty()

# Unlike the rotating crash-recovery backup, this archive survives successful
# writes and clearing a completed run. The content hash makes retries idempotent
# while preserving different legacy saves a player may explicitly restore.
static func _archive_before_surface_migration(path: String, profile: bool, run_inspection: Dictionary = {}) -> bool:
	var version: int = 0
	if not profile:
		var inspection: Dictionary = _inspect_run_file(path) if run_inspection.is_empty() else run_inspection
		if inspection["status"] == RunFile.UNAVAILABLE: return false
		if inspection["status"] != RunFile.READY: return true
		version = int(inspection["state"].get("surface_rules_version", 0))
	else:
		if not FileAccess.file_exists(path): return true
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null: return false
		var raw: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
			return true # Invalid live files still use the ordinary recovery path.
		version = int((raw as Dictionary).get("surface_rules_version", 0))
	if version >= SURFACE_RULES_VERSION:
		return true
	var digest: String = FileAccess.get_sha256(path)
	if digest.is_empty():
		return false
	var archive_path: String = "%s.pre-surfaces-v%d.%s" % [path, SURFACE_RULES_VERSION, digest.substr(0, 16)]
	if FileAccess.file_exists(archive_path):
		return FileAccess.get_sha256(archive_path) == digest
	var temporary: String = "%s.tmp" % archive_path
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(temporary))
	if error != OK:
		return false
	if FileAccess.get_sha256(temporary) != digest:
		_remove_run_file_if_present(temporary)
		return false
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(archive_path))
	if error != OK:
		_remove_run_file_if_present(temporary)
	return error == OK

static func _run_backup_path() -> String:
	return "%s.backup" % _run_storage_path

static func _remove_run_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func completion_run_id(state: Dictionary) -> String:
	var analytics: Variant = state.get("analytics")
	if not analytics is Dictionary: return ""
	var id: Variant = analytics.get("run_id")
	# The released analytics ID is random. Score and Chronicle identities use
	# a counter and seed and cannot identify a run across cloned profiles.
	return id if id is String and not id.strip_edges().is_empty() and not id.begins_with("run:") else ""

static func has_completed_run(profile: Dictionary, state: Dictionary) -> bool:
	var id := completion_run_id(state)
	var ids: Variant = profile.get(RUN_COMPLETION_IDS_KEY)
	if id.is_empty(): return false
	if ids is Array and ids.has(id): return true
	# Earlier builds wrote a durable score receipt with the random ID in its
	# context, but omitted the standalone completion ID. Only settlement queues
	# run_scored; a run_ended receipt can be staged before the wallet settles.
	var outbox: Variant = profile.get(PROGRESSION_ANALYTICS_OUTBOX_KEY)
	if outbox is Array:
		for receipt: Variant in outbox:
			if not receipt is Dictionary or receipt.get("event_type") != "run_scored": continue
			var context: Variant = receipt.get("context")
			if context is Dictionary and context.get("run_id") == id: return true
	# The released build records the result as run:N:seed:S with the wallet.
	# It is this run's unless a newer build attributed it to another run. An
	# ID minted on load follows the release rules: completion is unknown.
	var legacy := legacy_result_id(state)
	if not legacy.is_empty() and not _run_id_minted_on_load(state) and _result_recorded(profile, legacy):
		return result_owner(profile, legacy) in ["", id]
	return false

static func _run_id_minted_on_load(state: Dictionary) -> bool:
	# LoadedRoomState marks an ID minted for a checkpoint saved without one.
	var analytics: Variant = state.get("analytics")
	return analytics is Dictionary and bool(analytics.get("run_id_minted_on_load", false))

static func legacy_result_id(state: Dictionary) -> String:
	if not state.has("seed"): return ""
	return "run:%d:seed:%d" % [int(state.get("run_index", 0)), int(state.get("seed", 0))]

static func _result_recorded(profile: Dictionary, result_id: String) -> bool:
	# Raw read: title checks pass the unnormalized profile JSON.
	var receipts: Variant = profile.get(CHRONICLE_RECEIPTS_KEY)
	if receipts is Array and receipts.has(result_id): return true
	var last: Variant = profile.get(LAST_RUN_RESULT_KEY)
	if last is Dictionary and str(last.get("result_id", "")) == result_id: return true
	var ledger: Variant = profile.get(RUN_RESULT_LEDGER_KEY)
	if ledger is Array:
		for entry: Variant in ledger:
			if entry is Dictionary and str(entry.get("result_id", "")) == result_id: return true
	return false

static func result_owner(profile: Dictionary, result_id: String) -> String:
	var owners: Variant = profile.get(RUN_RESULT_OWNERS_KEY)
	return str(owners.get(result_id, "")) if owners is Dictionary else ""

static func stamp_result_identity(state: Dictionary, profile: Dictionary) -> void:
	# Two descents started in the same second from cloned profiles share a
	# counter and seed. The second to settle records under its random ID.
	if state.has(Chronicle.RESULT_IDENTITY_KEY) or _run_id_minted_on_load(state): return
	var id := completion_run_id(state)
	var legacy := legacy_result_id(state)
	if id.is_empty() or legacy.is_empty() or not _result_recorded(profile, legacy): return
	var owner := result_owner(profile, legacy)
	if not owner.is_empty() and owner != id: state[Chronicle.RESULT_IDENTITY_KEY] = id

static func record_run_completion(profile: Dictionary, state: Dictionary) -> Dictionary:
	var next := profile.duplicate(true)
	var id := completion_run_id(state)
	if id.is_empty(): return next
	var ids: Array = _normalized_string_array(next.get(RUN_COMPLETION_IDS_KEY, []))
	if not ids.has(id): ids.append(id)
	next[RUN_COMPLETION_IDS_KEY] = ids
	# Attribute a result recorded under the released identity to this run.
	var legacy := legacy_result_id(state)
	if not state.has(Chronicle.RESULT_IDENTITY_KEY) and not legacy.is_empty() and _result_recorded(next, legacy) and result_owner(next, legacy).is_empty():
		var owners: Dictionary = (next.get(RUN_RESULT_OWNERS_KEY, {}) as Dictionary).duplicate() if next.get(RUN_RESULT_OWNERS_KEY) is Dictionary else {}
		owners[legacy] = id
		next[RUN_RESULT_OWNERS_KEY] = owners
	return next

static func merge_run_completion_ids(profile: Dictionary, source: Dictionary) -> void:
	# The caller owns its candidate profile. A newer embedded revision can
	# repair progression, but it cannot revoke a durable completion receipt.
	var source_owners: Variant = source.get(RUN_RESULT_OWNERS_KEY)
	if source_owners is Dictionary and not source_owners.is_empty():
		var owners: Dictionary = (profile.get(RUN_RESULT_OWNERS_KEY, {}) as Dictionary).duplicate() if profile.get(RUN_RESULT_OWNERS_KEY) is Dictionary else {}
		for result_id: Variant in source_owners:
			if not owners.has(result_id): owners[result_id] = source_owners[result_id]
		profile[RUN_RESULT_OWNERS_KEY] = owners
	if not source.has(RUN_COMPLETION_IDS_KEY): return
	var ids: Array = _normalized_string_array(profile.get(RUN_COMPLETION_IDS_KEY, []))
	ids.append_array(_normalized_string_array(source[RUN_COMPLETION_IDS_KEY]))
	profile[RUN_COMPLETION_IDS_KEY] = _normalized_string_array(ids)

static func record_run_result(data: Dictionary, result_id: String, stats_value: Variant, run_state: Dictionary = {}, outcome: String = "") -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	var safe_result_id: String = result_id.strip_edges()
	if safe_result_id.is_empty():
		return {"data": next_data, "result": {}, "recorded": false}
	# Chronicle has its own uncapped receipts: replay remains harmless even after
	# the visible history and legacy result ledger have dropped this run.
	var chronicle_record: Dictionary = Chronicle.terminal_snapshot(safe_result_id)
	var links_eligible: bool = DemoBuild.is_demo() and bool(chronicle_record.get("_demo_links_eligible", false))
	chronicle_record.erase("_demo_links_eligible")
	if not run_state.is_empty():
		chronicle_record = Chronicle.build_record(run_state, outcome, RunScoreRules.score(run_state, outcome))
		links_eligible = DemoRules.end_panel_kind(run_state, outcome, next_data) == "links" and Chronicle.record_id(run_state) == safe_result_id
	if links_eligible and str(next_data.get(DemoRules.LINKS_PROMPT_RUN_KEY, "")).is_empty():
		next_data[DemoRules.LINKS_PROMPT_RUN_KEY] = safe_result_id
		# Like awakening and heirloom receipts, this must supersede an older
		# embedded profile on resume and survive the inverse torn-write repair.
		next_data["progression_revision"] = int(next_data.get("progression_revision", 0)) + 1
	if not chronicle_record.is_empty() and str(chronicle_record.get("run_id", "")) == safe_result_id:
		next_data = record_chronicle(next_data, chronicle_record)
	var completed_results: Array[Dictionary] = completed_run_results(next_data)
	var previous_index: int = _result_index_for_id(completed_results, safe_result_id)
	if previous_index >= 0:
		var previous_result: Dictionary = completed_results[previous_index].duplicate(true)
		completed_results.remove_at(previous_index)
		completed_results.append(previous_result.duplicate(true))
		next_data[RUN_RESULT_LEDGER_KEY] = _bounded_run_result_ledger(completed_results)
		next_data[LAST_RUN_RESULT_KEY] = previous_result
		return {"data": next_data, "result": previous_result, "recorded": false}

	var stats: Dictionary = _normalized_run_metric_map(stats_value, RUN_RESULT_STAT_IDS)
	var bests: Dictionary = run_bests(next_data)
	var new_bests: Array[String]
	for stat_id_var: Variant in BEST_ELIGIBLE_STAT_IDS:
		var stat_id: String = str(stat_id_var)
		var value: int = int(stats.get(stat_id, 0))
		if not bests.has(stat_id):
			# First-ever observations establish a baseline without claiming prior history.
			bests[stat_id] = value
			continue
		if value > int(bests.get(stat_id, 0)):
			bests[stat_id] = value
			new_bests.append(stat_id)
	var result: Dictionary = {
		"result_id": safe_result_id,
		"stats": stats,
		"new_bests": new_bests
	}
	var score_input: Dictionary = {}
	if stats_value is Dictionary:
		score_input = (stats_value as Dictionary).get("_score_result", {}) as Dictionary
	if not run_state.is_empty():
		var location: Dictionary = RunScoreRules.location(run_state)
		score_input = {"scored": RunScoreRules.score(run_state, outcome), "killer": RunScoreRules.normalized_stats(run_state.get("run_stats", {}))["killer"], "section": location["section"], "biome": location["biome"], "outcome": outcome, "context": RunScoreRules.analytics_context(run_state), "escaped_noctyrax": RunScoreRules.string_ids(run_state.get("run_stats", {}).get("dragons_slain", [])).has("noctyrax")}
	if not score_input.is_empty():
		var scored: Dictionary = score_input["scored"]
		result["score"] = int(scored["total"])
		result["lines"] = scored["lines"]
		result["feats"] = scored["feats"]
		result["killer"] = score_input["killer"]
		result["section"] = score_input["section"]
		result["biome"] = score_input["biome"]
		result["outcome"] = score_input["outcome"]
		result["new_best_score"] = int(result["score"]) > int(next_data[BEST_SCORE_KEY])
		next_data[BEST_SCORE_KEY] = maxi(int(next_data[BEST_SCORE_KEY]), int(result["score"]))
		var completed_depth: int = clampi(int(score_input.get("context", {}).get("depth", 0)), 0, DepthRules.MAX_DEPTH)
		if completed_depth > 0: result[DepthRules.STATE_KEY] = completed_depth
		var depth_bests: Dictionary = depth_best_scores(next_data)
		depth_bests[str(completed_depth)] = maxi(int(depth_bests.get(str(completed_depth), 0)), int(result["score"]))
		next_data[UMBRA_DEPTH_BESTS_KEY] = depth_bests
		var demo_clear: bool = DemoRules.is_demo_clear(run_state, str(score_input["outcome"]))
		if not demo_clear and str(score_input["outcome"]) == "victory" and bool(score_input.get("escaped_noctyrax", false)) and completed_depth == unlocked_umbra_depth(next_data):
			next_data[UMBRA_DEPTH_UNLOCKED_KEY] = mini(DepthRules.MAX_DEPTH, completed_depth + 1)
		if not demo_clear and completed_depth == DepthRules.MAX_DEPTH and str(score_input["outcome"]) == "victory" and bool(score_input.get("escaped_noctyrax", false)):
			next_data["umbra_depth_twenty_escaped"] = true
		# Durable, idempotent outbox follows the existing local JSONL delivery path.
		next_data = queue_progression_analytics_event(next_data, "run_scored", "%s:run_scored" % safe_result_id, score_input.get("context", {"run_id": safe_result_id}), scored)
	next_data[RUN_BESTS_KEY] = bests
	next_data[LAST_RUN_RESULT_KEY] = result
	result = _normalized_last_run_result(result)
	next_data[LAST_RUN_RESULT_KEY] = result
	completed_results.append(result.duplicate(true))
	next_data[RUN_RESULT_LEDGER_KEY] = _bounded_run_result_ledger(completed_results)
	return {"data": next_data, "result": result, "recorded": true}

static func chronicle_records(data: Dictionary) -> Array[Dictionary]:
	return Chronicle.normalized_records(data.get(CHRONICLE_RECORDS_KEY, []))

static func chronicle_totals(data: Dictionary) -> Dictionary:
	return Chronicle.normalized_totals(data.get(CHRONICLE_TOTALS_KEY, {}))

static func record_chronicle(data: Dictionary, value: Dictionary) -> Dictionary:
	var next_data: Dictionary = data.duplicate(true)
	var record: Dictionary = Chronicle.normalized_record(value)
	if record.is_empty():
		return next_data
	var receipts: Array = _normalized_string_array(next_data.get(CHRONICLE_RECEIPTS_KEY, []))
	if receipts.has(record["run_id"]):
		return next_data
	receipts.append(record["run_id"])
	var records: Array[Dictionary] = chronicle_records(next_data)
	records.push_front(record)
	while records.size() > Chronicle.RECORD_LIMIT:
		records.pop_back()
	next_data[CHRONICLE_RECORDS_KEY] = records
	next_data[CHRONICLE_RECEIPTS_KEY] = receipts
	next_data[CHRONICLE_TOTALS_KEY] = Chronicle.add_to_totals(chronicle_totals(next_data), record)
	return next_data

static func run_bests(data: Dictionary) -> Dictionary:
	return _normalized_run_metric_map(data.get(RUN_BESTS_KEY, {}), BEST_ELIGIBLE_STAT_IDS)

static func unlocked_umbra_depth(data: Dictionary) -> int:
	return clampi(int(data.get(UMBRA_DEPTH_UNLOCKED_KEY, 0)), 0, DepthRules.MAX_DEPTH)

static func merge_depth_progress(candidate: Dictionary, source: Dictionary) -> void:
	if source.has(UMBRA_DEPTH_UNLOCKED_KEY):
		candidate[UMBRA_DEPTH_UNLOCKED_KEY] = maxi(unlocked_umbra_depth(candidate), unlocked_umbra_depth(source))
	if _escaped_depth_twenty(source): candidate["umbra_depth_twenty_escaped"] = true
	var bests := depth_best_scores(candidate)
	var saved_bests := depth_best_scores(source)
	for depth: String in saved_bests:
		bests[depth] = maxi(int(bests.get(depth, 0)), int(saved_bests[depth]))
	if not bests.is_empty(): candidate[UMBRA_DEPTH_BESTS_KEY] = bests
	candidate[BEST_SCORE_KEY] = maxi(int(candidate.get(BEST_SCORE_KEY, 0)), int(source.get(BEST_SCORE_KEY, 0)))

static func merge_synced_profile(candidate: Dictionary, source: Dictionary, run_state: Dictionary) -> void:
	# A newer profile from another machine can win reconciliation. It never
	# rolls the descent counter back or drops the other side's left heirloom,
	# unless this run took that heirloom as its opening boon.
	candidate["run_counter"] = maxi(int(candidate.get("run_counter", 0)), int(source.get("run_counter", 0)))
	var left := heirloom(source)
	if left.is_empty() or not heirloom(candidate).is_empty(): return
	var boon: Variant = run_state.get("opening_boon")
	if boon is Dictionary and boon.get("chosen") == "heirloom":
		for offer: Variant in boon.get("offers", []):
			if offer is Dictionary and offer.get("boon") == "heirloom" and offer.get("item") == left: return
	candidate[HEIRLOOM_KEY] = left

static func selected_umbra_depth(data: Dictionary) -> int:
	return clampi(int(data.get(UMBRA_DEPTH_SELECTED_KEY, 0)), 0, unlocked_umbra_depth(data))

static func session_umbra_depth(data: Dictionary) -> int:
	return clampi(_session_umbra_depth, 0, unlocked_umbra_depth(data)) if _session_umbra_depth >= 0 else selected_umbra_depth(data)

static func remember_umbra_depth(data: Dictionary, selected: int) -> Dictionary:
	var next: Dictionary = select_umbra_depth(data, selected)
	_session_umbra_depth = selected_umbra_depth(next)
	var saved: bool = save_data(next)
	if not saved and not _session_depth_save_failed:
		push_error("Failed to save Umbra Depth selection; keeping it for this session.")
	_session_depth_save_failed = not saved
	return next

static func save_new_descent_profile(data: Dictionary) -> bool:
	var saved: bool = save_data(data)
	if saved: _session_depth_save_failed = false
	# Selection persistence is optional; the new run still must be saved by
	# RunScene before replacing the previous descent.
	return saved or _session_depth_save_failed

static func select_umbra_depth(data: Dictionary, selected: int) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	next[UMBRA_DEPTH_SELECTED_KEY] = clampi(selected, 0, unlocked_umbra_depth(next))
	return next

static func depth_best_scores(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var value: Variant = data.get(UMBRA_DEPTH_BESTS_KEY, {})
	if value is Dictionary:
		for key: Variant in value:
			var id: String = str(key)
			if id.is_valid_int() and int(id) >= 0 and int(id) <= DepthRules.MAX_DEPTH:
				result[str(int(id))] = maxi(0, int(value[key]))
	return result

static func deepest_umbra_escape(data: Dictionary) -> int:
	# Every unlock is an escape at the immediately preceding maximum.
	return unlocked_umbra_depth(data) - 1 if unlocked_umbra_depth(data) < DepthRules.MAX_DEPTH else (DepthRules.MAX_DEPTH if _escaped_depth_twenty(data) else DepthRules.MAX_DEPTH - 1)

static func _escaped_depth_twenty(data: Dictionary) -> bool:
	return bool(data.get("umbra_depth_twenty_escaped", false))

static func last_run_result(data: Dictionary) -> Dictionary:
	return _normalized_last_run_result(data.get(LAST_RUN_RESULT_KEY, {}))

static func completed_run_results(data: Dictionary) -> Array[Dictionary]:
	return _normalized_run_result_ledger(data.get(RUN_RESULT_LEDGER_KEY, []))

static func run_result_for_id(data: Dictionary, result_id: String) -> Dictionary:
	var ledger: Array[Dictionary] = completed_run_results(data)
	var index: int = _result_index_for_id(ledger, result_id.strip_edges())
	return ledger[index].duplicate(true) if index >= 0 else {}

static func _normalized_run_metric_map(value: Variant, allowed_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = value as Dictionary
	for stat_id_var: Variant in allowed_ids:
		var stat_id: String = str(stat_id_var)
		if source.has(stat_id):
			result[stat_id] = maxi(0, int(source.get(stat_id, 0)))
	return result

static func _normalized_last_run_result(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value as Dictionary
	var result_id: String = str(source.get("result_id", "")).strip_edges()
	if result_id.is_empty():
		return {}
	var new_bests: Array[String]
	for stat_id_var: Variant in source.get("new_bests", []):
		var stat_id: String = str(stat_id_var)
		if BEST_ELIGIBLE_STAT_IDS.has(stat_id) and not new_bests.has(stat_id):
			new_bests.append(stat_id)
	var result: Dictionary = {
		"result_id": result_id,
		"stats": _normalized_run_metric_map(source.get("stats", {}), RUN_RESULT_STAT_IDS),
		"new_bests": new_bests,
		"score": maxi(0, int(source["score"])) if source.get("score") != null else null,
		"lines": _score_rows(source.get("lines", [])),
		"feats": _score_rows(source.get("feats", [])),
		"killer": RunScoreRules.normalized_killer(source.get("killer", {})),
		"section": maxi(0, int(source.get("section", 0))),
		"biome": str(source.get("biome", "")),
		"outcome": str(source.get("outcome", "")),
		"new_best_score": bool(source.get("new_best_score", false))
	}
	if source.has(DepthRules.STATE_KEY): result[DepthRules.STATE_KEY] = DepthRules.depth(source)
	return result

static func _score_rows(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if value is Array:
		for row: Variant in value:
			if row is Dictionary:
				var normalized: Dictionary = (row as Dictionary).duplicate(true)
				normalized["points"] = maxi(0, int(normalized.get("points", 0)))
				result.append(normalized)
	return result

static func _normalized_run_result_ledger(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in (value as Array):
		var entry: Dictionary = _normalized_last_run_result(entry_var)
		if entry.is_empty():
			continue
		var existing_index: int = _result_index_for_id(result, str(entry.get("result_id", "")))
		if existing_index >= 0:
			result.remove_at(existing_index)
		result.append(entry)
	return _bounded_run_result_ledger(result)

static func _bounded_run_result_ledger(value: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in value:
		result.append(entry.duplicate(true))
	while result.size() > RUN_RESULT_LEDGER_LIMIT:
		result.pop_front()
	return result

static func _result_index_for_id(results: Array[Dictionary], result_id: String) -> int:
	if result_id.is_empty():
		return -1
	for index: int in range(results.size()):
		if str(results[index].get("result_id", "")) == result_id:
			return index
	return -1

static func add_embers(data: Dictionary, amount: int) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["embers"] = maxi(0, int(next_data.get("embers", 0)) + amount)
	return next_data

static func set_embers(data: Dictionary, amount: int) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["embers"] = maxi(0, amount)
	return next_data

# A profile-first wallet commit includes the run balance and sequence. Recovery
# applies that receipt once, even when the newer profile did not change level.
# Level purchases use the same sequence as exchanges so an older credit can
# never overwrite a later debit after interruption.
static func latest_run_wallet_receipt(data: Dictionary, run_id: String) -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in data.get(RUN_WALLET_RECEIPTS_KEY, []):
		if typeof(raw) != TYPE_DICTIONARY: continue
		var receipt: Dictionary = raw
		if str(receipt.get("run_id", "")) == run_id and int(receipt.get("sequence", 0)) > int(result.get("sequence", 0)):
			result = receipt.duplicate(true)
	return result

static func transact_run_wallet(data: Dictionary, run_id: String, sequence: int, kind: String, source: String) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	if run_id.is_empty() or sequence <= 0: return next
	var previous: Dictionary = latest_run_wallet_receipt(next, run_id)
	if sequence <= int(previous.get("sequence", 0)): return next
	var before_revision: int = int(next.get("progression_revision", 0))
	match kind:
		"moltshard_exchange":
			if moltshard_count(next) < 1: return next
			next["moltshards"] = moltshard_count(next) - 1
			next["embers"] = int(next.get("embers", 0)) + MOLT_EXCHANGE_EMBERS
			next["progression_revision"] = before_revision + 1
		"level_up":
			if not can_level_up(next): return next
			next = purchase_level(next)
		_:
			return next
	var receipts: Array = []
	for raw: Variant in next.get(RUN_WALLET_RECEIPTS_KEY, []):
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("run_id", "")) != run_id:
			receipts.append(raw.duplicate(true))
	receipts.append({"id":"%s:wallet:%d" % [run_id, sequence], "run_id":run_id, "sequence":sequence, "kind":kind, "source":source, "balance":int(next["embers"]), "revision":int(next["progression_revision"])})
	if receipts.size() > RUN_RESULT_LEDGER_LIMIT: receipts = receipts.slice(receipts.size() - RUN_RESULT_LEDGER_LIMIT)
	next[RUN_WALLET_RECEIPTS_KEY] = receipts
	return next

static func pending_starting_relic_gifts(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	# Prefer an existing live gift over its retired alias, even if it comes later.
	var live_gift_ids: Array[String]
	for raw: Variant in data.get(STARTING_RELIC_GIFTS_KEY, []):
		if typeof(raw) != TYPE_DICTIONARY or str(raw.get("id", "")).is_empty(): continue
		var raw_id: String = str(raw.get("relic_id", ""))
		if raw_id == GameData.resolve_relic_id(raw_id): live_gift_ids.append(raw_id)
	for raw: Variant in data.get(STARTING_RELIC_GIFTS_KEY, []):
		if typeof(raw) != TYPE_DICTIONARY: continue
		var id: String = str(raw.get("id", ""))
		var raw_id: String = str(raw.get("relic_id", ""))
		var relic_id: String = GameData.resolve_relic_id(raw_id)
		if raw_id != relic_id and live_gift_ids.has(relic_id): continue
		if not id.is_empty() and not relic_id.is_empty():
			result.append({"id":id, "relic_id":relic_id})
	return result

static func award_starting_relic_gift(data: Dictionary, award_id: String, relic_id: String) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	relic_id = GameData.resolve_relic_id(relic_id)
	var awards: Array = _normalized_string_array(next.get(STARTING_RELIC_GIFT_AWARDS_KEY, []))
	if award_id.is_empty() or awards.has(award_id) or GameData.relic_def(relic_id).is_empty(): return next
	awards.append(award_id)
	if awards.size() > MOLTSHARD_AWARD_LEDGER_LIMIT: awards = awards.slice(awards.size() - MOLTSHARD_AWARD_LEDGER_LIMIT)
	next[STARTING_RELIC_GIFT_AWARDS_KEY] = awards
	var gifts: Array[Dictionary] = pending_starting_relic_gifts(next)
	gifts.append({"id":award_id, "relic_id":relic_id})
	next[STARTING_RELIC_GIFTS_KEY] = gifts
	next["progression_revision"] = int(next.get("progression_revision", 0)) + 1
	return next

static func acknowledge_starting_relic_gifts(data: Dictionary, gift_ids: Array) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	var remaining: Array[Dictionary]
	var removed: bool = false
	for gift: Dictionary in pending_starting_relic_gifts(next):
		if gift_ids.has(str(gift["id"])):
			removed = true
		else:
			remaining.append(gift)
	if removed:
		next[STARTING_RELIC_GIFTS_KEY] = remaining
		next["progression_revision"] = int(next.get("progression_revision", 0)) + 1
	return next

static func next_level_cost(data: Dictionary) -> int:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return GameData.progression_level_cost(int(normalized.get("level", 1)) + 1)

static func is_max_level(data: Dictionary) -> bool:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return int(normalized.get("level", 1)) >= GameData.max_progression_level()

static func can_level_up(data: Dictionary) -> bool:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	var cost: int = next_level_cost(normalized)
	return cost > 0 and int(normalized.get("embers", 0)) >= cost

static func skill_points_for_level(level: int) -> int:
	return maxi(0, clampi(level, 1, GameData.max_progression_level()) - 1)

static func defiance_capacity_for_level(level: int) -> int:
	return int(clampi(level, 1, GameData.max_progression_level()) / DEFIANCE_LEVEL_INTERVAL)

static func selected_skill_ids(data: Dictionary) -> Array[String]:
	# Selection repair depends only on schema, level, skills and legacy stats.
	# Do not migrate/copy run history, tutorials, grimoire and outbox to read it.
	var selection: Dictionary = {
		"progression_schema": data.get("progression_schema", 1),
		"level": data.get("level", 1),
		"skill_ids": data.get("skill_ids", []),
		"stats": data.get("stats", {}),
	}
	var normalized: Dictionary = _normalized_data(selection)
	return SkillTreeLibrary.normalized_ids(normalized.get("skill_ids", []))

static func has_skill(data: Dictionary, skill_id: String) -> bool:
	return selected_skill_ids(data).has(skill_id)

static func available_skill_ids(data: Dictionary) -> Array[String]:
	return SkillTreeLibrary.available_ids(selected_skill_ids(data))

static func unspent_skill_points(data: Dictionary) -> int:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return maxi(
		0,
		skill_points_for_level(int(normalized.get("level", 1)))
			- SkillTreeLibrary.normalized_ids(normalized.get("skill_ids", [])).size()
	)

static func can_learn_skill(data: Dictionary, skill_id: String) -> bool:
	if SkillTreeLibrary.is_demo_locked(skill_id):
		return false
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return (
		unspent_skill_points(normalized) > 0
		and SkillTreeLibrary.is_available(skill_id, normalized.get("skill_ids", []))
	)

static func learn_skill(data: Dictionary, skill_id: String) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	if not can_learn_skill(normalized, skill_id):
		return normalized
	var skills: Array[String] = SkillTreeLibrary.normalized_ids(normalized.get("skill_ids", []))
	skills.append(skill_id)
	normalized["skill_ids"] = skills
	normalized["progression_revision"] = int(normalized.get("progression_revision", 0)) + 1
	return _normalized_data(normalized)

static func can_purchase_level_with_skill(_data: Dictionary, _skill_id: String) -> bool:
	# Kept as a safe compatibility adapter. Level purchase and skill learning are
	# deliberately separate operations in schema 5.
	return false

static func purchase_level(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	if not can_level_up(normalized):
		return normalized
	var cost: int = next_level_cost(normalized)
	normalized["embers"] = maxi(0, int(normalized.get("embers", 0)) - cost)
	normalized["level"] = mini(GameData.max_progression_level(), int(normalized.get("level", 1)) + 1)
	normalized["progression_revision"] = int(normalized.get("progression_revision", 0)) + 1
	return _normalized_data(normalized)

static func purchase_level_with_skill(data: Dictionary, _skill_id: String) -> Dictionary:
	return _normalized_data(data.duplicate(true))

# These adapters intentionally refuse the retired allocation flow. They keep
# older callers safe while saved profiles migrate to one skill per level.
static func can_purchase_level_with_stats(_data: Dictionary, _stat_ids: Array) -> bool:
	return false

static func purchase_level_with_stat(data: Dictionary, _stat_id: String) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func purchase_level_with_stats(data: Dictionary, _stat_ids: Array) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func moltshard_count(data: Dictionary) -> int:
	return maxi(0, int(data.get("moltshards", 0)))

static func add_moltshards(data: Dictionary, amount: int = 1) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	var before: int = int(next_data.get("moltshards", 0))
	next_data["moltshards"] = maxi(0, before + amount)
	if int(next_data.get("moltshards", 0)) != before:
		next_data["progression_revision"] = int(next_data.get("progression_revision", 0)) + 1
	return _normalized_data(next_data)

static func has_moltshard_award(data: Dictionary, award_id: String) -> bool:
	if award_id.is_empty():
		return false
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return (normalized.get(MOLTSHARD_AWARD_IDS_KEY, []) as Array).has(award_id)

static func add_moltshard_for_award(data: Dictionary, award_id: String) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	if award_id.is_empty() or has_moltshard_award(normalized, award_id):
		return normalized
	var award_ids: Array = (normalized.get(MOLTSHARD_AWARD_IDS_KEY, []) as Array).duplicate()
	award_ids.append(award_id)
	if award_ids.size() > MOLTSHARD_AWARD_LEDGER_LIMIT:
		award_ids = award_ids.slice(award_ids.size() - MOLTSHARD_AWARD_LEDGER_LIMIT)
	normalized[MOLTSHARD_AWARD_IDS_KEY] = award_ids
	normalized["moltshards"] = maxi(0, int(normalized.get("moltshards", 0)) + 1)
	normalized["progression_revision"] = int(normalized.get("progression_revision", 0)) + 1
	return _normalized_data(normalized)

static func progression_analytics_outbox(data: Dictionary) -> Array[Dictionary]:
	# Older events require the combat-unit migration; current events need only
	# field validation and owned context/payload copies, not whole-profile repair.
	if int(data.get("progression_schema", 1)) < 6:
		return _normalized_progression_analytics_outbox(
			_normalized_data(data.duplicate(true)).get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
		)
	return _normalized_progression_analytics_outbox(data.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, []))

static func _progression_event_key(event_type: String, key: String, context: Dictionary) -> String:
	var run_id: String = str(context.get("run_id", ""))
	if event_type == "run_ended" and not run_id.is_empty():
		return preload("res://scripts/analytics_store.gd").run_ended_key(run_id)
	if event_type == "reward_claimed" and key.begins_with("reward_claimed|"):
		return preload("res://scripts/analytics_store.gd").dragon_claim_key(key.trim_prefix("reward_claimed|"), run_id)
	return key.strip_edges()

static func queue_progression_analytics_event(
	data: Dictionary,
	event_type: String,
	idempotency_key: String,
	context: Dictionary,
	payload: Dictionary
) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	var safe_event_type: String = event_type.strip_edges()
	var safe_idempotency_key: String = _progression_event_key(safe_event_type, idempotency_key, context)
	if safe_event_type.is_empty() or safe_idempotency_key.is_empty():
		return normalized
	var outbox: Array[Dictionary] = _normalized_progression_analytics_outbox(
		normalized.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	)
	for entry: Dictionary in outbox:
		if str(entry.get("idempotency_key", "")) == safe_idempotency_key:
			return normalized
	outbox.append({
		"event_type": safe_event_type,
		"idempotency_key": safe_idempotency_key,
		"context": context.duplicate(true),
		"payload": payload.duplicate(true),
	})
	normalized[PROGRESSION_ANALYTICS_OUTBOX_KEY] = outbox
	return normalized

static func deliverable_progression_receipts(outbox: Array[Dictionary], settled_profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in outbox:
		var id: String = str(entry["context"].get("run_id", ""))
		if entry["event_type"] == "run_ended" and entry["payload"].get("outcome") == "abandoned" and not id.is_empty():
			if not has_completed_run(settled_profile, {"analytics": {"run_id": id}}): continue
		result.append(entry)
	return result

static func acknowledge_progression_analytics_event(data: Dictionary, idempotency_key: String) -> Dictionary:
	return acknowledge_progression_analytics_events(data, [idempotency_key])

static func acknowledge_progression_analytics_events(data: Dictionary, idempotency_keys: Array) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	var acknowledged: Dictionary = {}
	for idempotency_key_var: Variant in idempotency_keys:
		var safe_idempotency_key: String = str(idempotency_key_var).strip_edges()
		if not safe_idempotency_key.is_empty():
			acknowledged[safe_idempotency_key] = true
	if acknowledged.is_empty():
		return normalized
	var remaining: Array[Dictionary]
	for entry: Dictionary in _normalized_progression_analytics_outbox(
		normalized.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	):
		if not acknowledged.has(str(entry.get("idempotency_key", ""))):
			remaining.append(entry.duplicate(true))
		elif entry["event_type"] == "run_scored":
			# Only settlement queues a score. A delivered run_ended can be one a
			# continued terminal checkpoint staged before its wallet settled.
			normalized = record_run_completion(normalized, {"analytics": entry["context"]})
	normalized[PROGRESSION_ANALYTICS_OUTBOX_KEY] = remaining
	return normalized

static func merge_progression_analytics_outbox(data: Dictionary, source: Dictionary) -> Dictionary:
	var merged: Dictionary = _normalized_data(data.duplicate(true))
	var outbox: Array[Dictionary] = _normalized_progression_analytics_outbox(
		merged.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	)
	var known_keys: Dictionary = {}
	for entry: Dictionary in outbox:
		known_keys[str(entry.get("idempotency_key", ""))] = true
	for entry: Dictionary in _normalized_progression_analytics_outbox(
		source.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	):
		var idempotency_key: String = str(entry.get("idempotency_key", ""))
		if known_keys.has(idempotency_key):
			continue
		known_keys[idempotency_key] = true
		outbox.append(entry)
	merged[PROGRESSION_ANALYTICS_OUTBOX_KEY] = outbox
	return merged

static func can_reset_skills(data: Dictionary) -> bool:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	return (
		int(normalized.get("moltshards", 0)) > 0
		and not SkillTreeLibrary.normalized_ids(normalized.get("skill_ids", [])).is_empty()
	)

static func reset_skills(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	if not can_reset_skills(normalized):
		return normalized
	normalized["skill_ids"] = []
	normalized["moltshards"] = maxi(0, int(normalized.get("moltshards", 0)) - 1)
	normalized["progression_revision"] = int(normalized.get("progression_revision", 0)) + 1
	return _normalized_data(normalized)

# Compatibility adapters intentionally refuse the retired replacement-build
# transaction so older callers cannot recreate a hidden draft.
static func can_respec_skills(_data: Dictionary, _proposed_skill_ids: Array) -> bool:
	return false

static func respec_skills(data: Dictionary, _proposed_skill_ids: Array) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func mark_rested_at_fire(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["rested_at_fire"] = true
	return next_data

static func mark_fire_rest_dialogue_seen(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["pending_fire_rest_dialogue"] = false
	next_data["fire_rest_dialogue_seen"] = true
	return next_data

# The first-dragon receipt persists even after the Shard is spent. Legacy
# profiles with Shards or a recorded boss best receive the introduction too.
static func emaciated_awakening_is_due(data: Dictionary) -> bool:
	if emaciated_services_unlocked(data): return false
	return not (data.get(MOLTSHARD_AWARD_IDS_KEY, []) as Array).is_empty() or moltshard_count(data) > 0 or int((data.get(RUN_BESTS_KEY, {}) as Dictionary).get("bosses_defeated", 0)) > 0

static func emaciated_services_unlocked(data: Dictionary) -> bool:
	return bool(data.get(EMACIATED_AWAKENING_SEEN_KEY, false))

static func heirloom(data: Dictionary) -> String:
	var item: String = str(data.get(HEIRLOOM_KEY, ""))
	return item if not GameData.equipment_def(item).is_empty() else ""

static func leave_heirloom(data: Dictionary, item: String) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	# An empty choice retains the previous piece, including its base identity.
	if item.is_empty() or GameData.equipment_def(item).is_empty(): return next
	next[HEIRLOOM_KEY] = item
	next["progression_revision"] = int(next.get("progression_revision", 0)) + 1
	return next

static func take_heirloom(data: Dictionary, item: String) -> Dictionary:
	var next: Dictionary = normalized_data(data)
	if item.is_empty() or heirloom(next) != item: return next
	next.erase(HEIRLOOM_KEY)
	next["progression_revision"] = int(next.get("progression_revision", 0)) + 1
	return next

static func mark_emaciated_awakening_seen(data: Dictionary) -> Dictionary:
	var next: Dictionary = _normalized_data(data.duplicate(true))
	if not emaciated_awakening_is_due(next): return next
	next[EMACIATED_AWAKENING_SEEN_KEY] = true
	next["progression_revision"] = int(next.get("progression_revision", 0)) + 1
	return next

static func record_first_umbra_reach(data: Dictionary, current_run_index: int) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	if bool(next_data.get(UMBRA_WARNING_SEEN_KEY, false)) or int(next_data.get(UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) > 0:
		return next_data
	next_data[UMBRA_WARNING_AVAILABLE_RUN_KEY] = maxi(1, current_run_index + 1)
	return next_data

static func umbra_warning_is_due(data: Dictionary, current_run_index: int) -> bool:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	var available_run: int = int(normalized.get(UMBRA_WARNING_AVAILABLE_RUN_KEY, 0))
	return not bool(normalized.get(UMBRA_WARNING_SEEN_KEY, false)) and available_run > 0 and current_run_index >= available_run

static func mark_umbra_warning_seen(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data[UMBRA_WARNING_AVAILABLE_RUN_KEY] = 0
	next_data[UMBRA_WARNING_SEEN_KEY] = true
	return next_data

static func prepare_for_new_run(data: Dictionary, previous_checkpoint: Dictionary = {}) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	if _session_umbra_depth >= 0: next_data[UMBRA_DEPTH_SELECTED_KEY] = session_umbra_depth(next_data)
	# Tutorial milestones describe one authored encounter. If that run was
	# abandoned before completion or dismissal, restart the active guide so the
	# replacement run receives the complete deterministic scenario instead of an
	# unreachable mid-curriculum state.
	if (
		ContextualCombatTutorial.is_active(next_data)
		and not ContextualCombatTutorial.completed_steps(next_data).is_empty()
	):
		next_data = ContextualCombatTutorial.restart_tutorial(next_data)
	var reserved: String = str(next_data.get(PENDING_DESCENT_ID_KEY, ""))
	var retry: bool = not reserved.is_empty() and reserved != completion_run_id(previous_checkpoint)
	var next_run_counter: int = int(next_data.get("run_counter", 0))
	var marker: Dictionary = recovery_marker(next_data)
	# Before reservations, a torn install can still be recognized if the
	# selected terminal checkpoint is the source of the marker for this counter.
	if reserved.is_empty() and previous_checkpoint.get("mode") in ["defeat", "abandoned"]:
		retry = (int(marker.get("available_run", -1)) == next_run_counter
			and int(previous_checkpoint.get("run_index", -2)) + 1 == next_run_counter
			and previous_checkpoint.get("current_room") == recovery_coord(next_data))
	if not retry: next_run_counter += 1
	next_data.erase(PENDING_DESCENT_ID_KEY)
	next_data["run_counter"] = next_run_counter
	if not marker.is_empty() and int(marker.get("available_run", 0)) < next_run_counter:
		next_data["recovery_marker"] = {}
	return next_data

static func reconcile_descent_reservation(candidate: Dictionary, disk: Dictionary, checkpoint: Dictionary, settled_loss: bool = false) -> void:
	var reserved: String = str(disk.get(PENDING_DESCENT_ID_KEY, ""))
	if reserved.is_empty(): return
	# The profile can advance before a replacement checkpoint exists. A
	# loaded older checkpoint can still own a prompt but cannot consume the
	# reserved counter or expire its marker.
	candidate["run_counter"] = int(disk.get("run_counter", 0))
	var installed: bool = reserved == completion_run_id(checkpoint)
	var checkpoint_counter: int = int(checkpoint.get("run_index", -1))
	var disk_marker := recovery_marker(disk)
	var reserved_marker: Dictionary = disk_marker
	if installed:
		candidate.erase(PENDING_DESCENT_ID_KEY)
		# The installed descent owns expiry, unless the disk already holds
		# a loss available after that descent.
		if int(disk_marker.get("available_run", -1)) <= checkpoint_counter:
			reserved_marker = recovery_marker(checkpoint.get("progression", {}))
	else:
		candidate[PENDING_DESCENT_ID_KEY] = reserved
	var marker := recovery_marker(candidate)
	var available_run: int = int(marker.get("available_run", -1))
	var reserved_available: int = int(reserved_marker.get("available_run", -1))
	if installed:
		reserved_available = maxi(reserved_available, checkpoint_counter)
	# A loss recovered in this transaction supersedes the older marker on
	# a tie. A zero-Ember loss can clear the marker at the same boundary.
	if settled_loss and maxi(available_run, checkpoint_counter + 1) >= reserved_available: return
	if available_run <= reserved_available:
		candidate["recovery_marker"] = reserved_marker

static func recovery_marker(data: Dictionary) -> Dictionary:
	var marker: Dictionary = (data.get("recovery_marker", {}) as Dictionary).duplicate(true)
	if marker.is_empty():
		return {}
	if int(marker.get("amount", 0)) <= 0:
		return {}
	if not marker.has("coord_x") or not marker.has("coord_y"):
		return {}
	if not marker.has("available_run"):
		return {}
	return marker

static func recovery_coord(data: Dictionary) -> Vector2i:
	var marker: Dictionary = recovery_marker(data)
	if marker.is_empty():
		return Vector2i(-999, -999)
	return Vector2i(int(marker.get("coord_x", 0)), int(marker.get("coord_y", 0)))

static func record_lost_embers(data: Dictionary, amount: int, coord: Vector2i, current_run: int) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["embers"] = 0
	if int(recovery_marker(next_data).get("available_run", -1)) > current_run + 1: return next_data
	if amount <= 0:
		next_data["recovery_marker"] = {}
		return next_data
	next_data["recovery_marker"] = {
		"amount": amount,
		"coord_x": coord.x,
		"coord_y": coord.y,
		"available_run": current_run + 1
	}
	return next_data

static func clear_recovery_marker(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["recovery_marker"] = {}
	return next_data

static func can_purchase(_data: Dictionary, _upgrade_id: String) -> bool:
	return false

static func purchase_upgrade(data: Dictionary, _upgrade_id: String) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func can_purchase_card_mod(_data: Dictionary, _card_id: String, _mod: Dictionary) -> bool:
	return false

static func purchase_card_mod(data: Dictionary, _card_id: String, _mod: Dictionary) -> Dictionary:
	return _normalized_data(data.duplicate(true))

static func has_upgrade(_data: Dictionary, _upgrade_id: String) -> bool:
	return false

static func has_card_upgrade(_data: Dictionary, _card_id: String) -> bool:
	return false
