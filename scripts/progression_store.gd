extends RefCounted
class_name ProgressionStore

const GameData = preload("res://scripts/game_data.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

const DEFAULT_STORAGE_PATH: String = "user://progression.json"
const DEFAULT_RUN_STORAGE_PATH: String = "user://current_run.save"
const PROGRESSION_SCHEMA: int = 7
const GRIMOIRE_UNLOCKED_KEY: String = "grimoire_unlocked"
const GRIMOIRE_UNREAD_KEY: String = "grimoire_unread"
const RUN_BESTS_KEY: String = "run_bests"
const LAST_RUN_RESULT_KEY: String = "last_run_result"
const RUN_RESULT_LEDGER_KEY: String = "completed_run_results"
const RUN_RESULT_LEDGER_LIMIT: int = 32
const UMBRA_WARNING_AVAILABLE_RUN_KEY: String = "umbra_warning_available_run"
const UMBRA_WARNING_SEEN_KEY: String = "umbra_warning_seen"
const MOLTSHARD_AWARD_IDS_KEY: String = "moltshard_award_ids"
const MOLTSHARD_AWARD_LEDGER_LIMIT: int = 64
const PROGRESSION_ANALYTICS_OUTBOX_KEY: String = "progression_analytics_outbox"
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

static var _storage_path: String = DEFAULT_STORAGE_PATH
static var _run_storage_path: String = DEFAULT_RUN_STORAGE_PATH

static func set_storage_path(path: String) -> void:
	_storage_path = path if not path.is_empty() else DEFAULT_STORAGE_PATH

static func set_run_storage_path(path: String) -> void:
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
		"rested_at_fire": false,
		"card_upgrades_unlocked": false,
		"pending_fire_rest_dialogue": false,
		"fire_rest_dialogue_seen": false,
		UMBRA_WARNING_AVAILABLE_RUN_KEY: 0,
		UMBRA_WARNING_SEEN_KEY: false,
		"run_counter": 0,
		"recovery_marker": {},
		RUN_BESTS_KEY: {},
		LAST_RUN_RESULT_KEY: {},
		RUN_RESULT_LEDGER_KEY: [],
		GRIMOIRE_UNLOCKED_KEY: [],
		GRIMOIRE_UNREAD_KEY: []
	}

static func load_data() -> Dictionary:
	var loaded: Dictionary = _load_profile_dictionary(_storage_path)
	if not loaded.is_empty():
		return loaded
	loaded = _load_profile_dictionary(_profile_backup_path())
	return loaded if not loaded.is_empty() else default_data()

static func _load_profile_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var source: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _normalized_data((parsed as Dictionary).duplicate(true))

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
	data["level"] = clampi(int(data.get("level", 1)), 1, GameData.max_progression_level())
	var earned_skill_count: int = skill_points_for_level(int(data.get("level", 1)))
	var serialized_skill_ids: Array[String] = SkillTreeLibrary.normalized_ids(data.get("skill_ids", []))
	var source_skill_ids: Array[String] = []
	for skill_id: String in serialized_skill_ids:
		if not SkillTreeLibrary.is_retired(skill_id):
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
	if not data.has("run_counter"):
		data["run_counter"] = 0
	if not data.has("recovery_marker"):
		data["recovery_marker"] = {}
	data[RUN_BESTS_KEY] = _normalized_run_metric_map(data.get(RUN_BESTS_KEY, {}), BEST_ELIGIBLE_STAT_IDS)
	data[LAST_RUN_RESULT_KEY] = _normalized_last_run_result(data.get(LAST_RUN_RESULT_KEY, {}))
	var completed_results: Array[Dictionary] = _normalized_run_result_ledger(data.get(RUN_RESULT_LEDGER_KEY, []))
	var last_result: Dictionary = data.get(LAST_RUN_RESULT_KEY, {}) as Dictionary
	if not last_result.is_empty() and _result_index_for_id(completed_results, str(last_result.get("result_id", ""))) < 0:
		completed_results.append(last_result.duplicate(true))
	data[RUN_RESULT_LEDGER_KEY] = _bounded_run_result_ledger(completed_results)
	data[GRIMOIRE_UNLOCKED_KEY] = _normalized_string_array(data.get(GRIMOIRE_UNLOCKED_KEY, []))
	data[GRIMOIRE_UNREAD_KEY] = _normalized_string_array(data.get(GRIMOIRE_UNREAD_KEY, []))
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
	var survivor_fields: Array[String] = [
		"player_hp",
		"player_max_hp",
		"player_start_hp",
		"hp_loss",
		"block_loss",
		"stoneskin_loss",
		"restored_hp",
		"lethal_hp_loss",
		"defiance_restored"
	]
	var cumulative_fields: Array[String] = ["damage", "damage_dealt", "damage_received"]
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
		refund += maxi(0, GameData.upgrade_cost(upgrade_id))
	for upgrade_id_var: Variant in (next_data.get("card_upgrades", {}) as Dictionary).values():
		var upgrade_id: String = str(upgrade_id_var)
		if upgrade_id.is_empty() or seen_upgrades.has(upgrade_id):
			continue
		seen_upgrades[upgrade_id] = true
		refund += maxi(0, GameData.upgrade_cost(upgrade_id))
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
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var seen_keys: Dictionary = {}
	for entry_var: Variant in value as Array:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var event_type: String = str(entry.get("event_type", "")).strip_edges()
		var idempotency_key: String = str(entry.get("idempotency_key", "")).strip_edges()
		if event_type.is_empty() or idempotency_key.is_empty() or seen_keys.has(idempotency_key):
			continue
		seen_keys[idempotency_key] = true
		var context: Dictionary = {}
		if typeof(entry.get("context", null)) == TYPE_DICTIONARY:
			context = (entry.get("context", {}) as Dictionary).duplicate(true)
		var payload: Dictionary = {}
		if typeof(entry.get("payload", null)) == TYPE_DICTIONARY:
			payload = (entry.get("payload", {}) as Dictionary).duplicate(true)
		result.append({
			"event_type": event_type,
			"idempotency_key": idempotency_key,
			"context": context,
			"payload": payload,
		})
	return result

static func save_data(data: Dictionary) -> bool:
	var temp_path: String = _profile_temp_path()
	var backup_path: String = _profile_backup_path()
	_remove_profile_file_if_present(temp_path)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_normalized_data(data.duplicate(true)), "\t"))
	file.flush()
	file.close()
	if _load_profile_dictionary(temp_path).is_empty():
		_remove_profile_file_if_present(temp_path)
		return false
	var live_path: String = ProjectSettings.globalize_path(_storage_path)
	var live_exists: bool = FileAccess.file_exists(_storage_path)
	var live_valid: bool = live_exists and not _load_profile_dictionary(_storage_path).is_empty()
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
		if backup_valid and not FileAccess.file_exists(_storage_path):
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
	return FileAccess.file_exists(_run_storage_path) or FileAccess.file_exists(_run_backup_path())

static func load_saved_run() -> Dictionary:
	if not has_saved_run():
		return {}
	var loaded: Dictionary = _load_run_dictionary(_run_storage_path)
	if not loaded.is_empty():
		return loaded
	return _load_run_dictionary(_run_backup_path())

static func _load_run_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var(false)
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	# `get_var()` decodes a fresh Variant graph owned by this call. Returning it
	# directly avoids cloning the entire save once more during resume/recovery.
	return data as Dictionary

static func _run_dictionary_is_nonempty(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = file.get_var(false)
	file.close()
	return typeof(data) == TYPE_DICTIONARY and not (data as Dictionary).is_empty()

static func save_run_state(run_state: Dictionary) -> bool:
	var temp_path: String = _run_temp_path()
	var backup_path: String = _run_backup_path()
	_remove_run_file_if_present(temp_path)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(run_state, false)
	file.flush()
	file.close()
	if not run_state.is_empty() and not _run_dictionary_is_nonempty(temp_path):
		_remove_run_file_if_present(temp_path)
		return false
	var live_path: String = ProjectSettings.globalize_path(_run_storage_path)
	var live_exists: bool = FileAccess.file_exists(_run_storage_path)
	var live_valid: bool = live_exists and _run_dictionary_is_nonempty(_run_storage_path)
	var backup_valid: bool = false
	if live_valid:
		_remove_run_file_if_present(backup_path)
		if DirAccess.rename_absolute(live_path, ProjectSettings.globalize_path(backup_path)) != OK:
			_remove_run_file_if_present(temp_path)
			return false
		backup_valid = true
	else:
		backup_valid = _run_dictionary_is_nonempty(backup_path)
		if live_exists:
			if DirAccess.remove_absolute(live_path) != OK:
				_remove_run_file_if_present(temp_path)
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), live_path) != OK:
		if backup_valid and not FileAccess.file_exists(_run_storage_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), live_path)
		_remove_run_file_if_present(temp_path)
		return false
	_remove_run_file_if_present(backup_path)
	return true

static func clear_saved_run() -> void:
	_remove_run_file_if_present(_run_storage_path)
	_remove_run_file_if_present(_run_temp_path())
	_remove_run_file_if_present(_run_backup_path())

static func _run_temp_path() -> String:
	return "%s.tmp" % _run_storage_path

static func _run_backup_path() -> String:
	return "%s.backup" % _run_storage_path

static func _remove_run_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func record_run_result(data: Dictionary, result_id: String, stats_value: Variant) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	var safe_result_id: String = result_id.strip_edges()
	if safe_result_id.is_empty():
		return {"data": next_data, "result": {}, "recorded": false}
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
	var new_bests: Array[String] = []
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
	next_data[RUN_BESTS_KEY] = bests
	next_data[LAST_RUN_RESULT_KEY] = result
	completed_results.append(result.duplicate(true))
	next_data[RUN_RESULT_LEDGER_KEY] = _bounded_run_result_ledger(completed_results)
	return {"data": next_data, "result": result, "recorded": true}

static func run_bests(data: Dictionary) -> Dictionary:
	return _normalized_run_metric_map(data.get(RUN_BESTS_KEY, {}), BEST_ELIGIBLE_STAT_IDS)

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
	var new_bests: Array[String] = []
	for stat_id_var: Variant in source.get("new_bests", []):
		var stat_id: String = str(stat_id_var)
		if BEST_ELIGIBLE_STAT_IDS.has(stat_id) and not new_bests.has(stat_id):
			new_bests.append(stat_id)
	return {
		"result_id": result_id,
		"stats": _normalized_run_metric_map(source.get("stats", {}), RUN_RESULT_STAT_IDS),
		"new_bests": new_bests
	}

static func _normalized_run_result_ledger(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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
	var result: Array[Dictionary] = []
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
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
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
	return maxi(0, int(_normalized_data(data.duplicate(true)).get("moltshards", 0)))

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
	return _normalized_progression_analytics_outbox(
		_normalized_data(data.duplicate(true)).get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	)

static func queue_progression_analytics_event(
	data: Dictionary,
	event_type: String,
	idempotency_key: String,
	context: Dictionary,
	payload: Dictionary
) -> Dictionary:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	var safe_event_type: String = event_type.strip_edges()
	var safe_idempotency_key: String = idempotency_key.strip_edges()
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
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in _normalized_progression_analytics_outbox(
		normalized.get(PROGRESSION_ANALYTICS_OUTBOX_KEY, [])
	):
		if not acknowledged.has(str(entry.get("idempotency_key", ""))):
			remaining.append(entry.duplicate(true))
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

static func prepare_for_new_run(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	var next_run_counter: int = int(next_data.get("run_counter", 0)) + 1
	next_data["run_counter"] = next_run_counter
	var marker: Dictionary = recovery_marker(next_data)
	if not marker.is_empty() and int(marker.get("available_run", 0)) < next_run_counter:
		next_data["recovery_marker"] = {}
	return next_data

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
