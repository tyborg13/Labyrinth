extends RefCounted
class_name ProgressionStore

const GameData = preload("res://scripts/game_data.gd")

const DEFAULT_STORAGE_PATH: String = "user://progression.json"
const DEFAULT_RUN_STORAGE_PATH: String = "user://current_run.save"

static var _storage_path: String = DEFAULT_STORAGE_PATH
static var _run_storage_path: String = DEFAULT_RUN_STORAGE_PATH

static func set_storage_path(path: String) -> void:
	_storage_path = path if not path.is_empty() else DEFAULT_STORAGE_PATH

static func set_run_storage_path(path: String) -> void:
	_run_storage_path = path if not path.is_empty() else DEFAULT_RUN_STORAGE_PATH

static func default_data() -> Dictionary:
	return {
		"embers": 0,
		"purchased_upgrades": [],
		"card_upgrades": {},
		"rested_at_fire": false,
		"run_counter": 0,
		"recovery_marker": {}
	}

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(_storage_path):
		return default_data()
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.READ)
	if file == null:
		return default_data()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_data()
	var data: Dictionary = (parsed as Dictionary).duplicate(true)
	return _normalized_data(data)

static func _normalized_data(data: Dictionary) -> Dictionary:
	if not data.has("embers"):
		data["embers"] = 0
	if not data.has("purchased_upgrades"):
		data["purchased_upgrades"] = []
	if not data.has("card_upgrades") or typeof(data.get("card_upgrades", {})) != TYPE_DICTIONARY:
		data["card_upgrades"] = {}
	if not data.has("rested_at_fire"):
		data["rested_at_fire"] = false
	if not data.has("run_counter"):
		data["run_counter"] = 0
	if not data.has("recovery_marker"):
		data["recovery_marker"] = {}
	var card_upgrades: Dictionary = (data.get("card_upgrades", {}) as Dictionary).duplicate(true)
	for upgrade_id_var: Variant in data.get("purchased_upgrades", []):
		var upgrade_id: String = str(upgrade_id_var)
		var card_id: String = GameData.upgrade_card_id(upgrade_id)
		if not card_id.is_empty() and not card_upgrades.has(card_id):
			card_upgrades[card_id] = upgrade_id
	data["card_upgrades"] = card_upgrades
	return data

static func save_data(data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

static func has_saved_run() -> bool:
	return FileAccess.file_exists(_run_storage_path)

static func load_saved_run() -> Dictionary:
	if not has_saved_run():
		return {}
	var file: FileAccess = FileAccess.open(_run_storage_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var(false)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return (data as Dictionary).duplicate(true)

static func save_run_state(run_state: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(_run_storage_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(run_state, false)
	return true

static func clear_saved_run() -> void:
	if not has_saved_run():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_run_storage_path))

static func add_embers(data: Dictionary, amount: int) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["embers"] = maxi(0, int(next_data.get("embers", 0)) + amount)
	return next_data

static func mark_rested_at_fire(data: Dictionary) -> Dictionary:
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	next_data["rested_at_fire"] = true
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
	var next_data: Dictionary = data.duplicate(true)
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
	var next_data: Dictionary = data.duplicate(true)
	next_data["recovery_marker"] = {}
	return next_data

static func can_purchase(data: Dictionary, upgrade_id: String) -> bool:
	var normalized: Dictionary = _normalized_data(data.duplicate(true))
	if has_upgrade(data, upgrade_id):
		return false
	var upgrade: Dictionary = GameData.upgrade_def(upgrade_id)
	if upgrade.is_empty():
		return false
	var card_id: String = GameData.upgrade_card_id(upgrade_id)
	if not card_id.is_empty() and has_card_upgrade(normalized, card_id):
		return false
	return int(normalized.get("embers", 0)) >= GameData.upgrade_cost(upgrade_id)

static func purchase_upgrade(data: Dictionary, upgrade_id: String) -> Dictionary:
	if not can_purchase(data, upgrade_id):
		return data.duplicate(true)
	var next_data: Dictionary = _normalized_data(data.duplicate(true))
	var upgrades: Array = next_data.get("purchased_upgrades", []).duplicate()
	upgrades.append(upgrade_id)
	next_data["purchased_upgrades"] = upgrades
	var card_id: String = GameData.upgrade_card_id(upgrade_id)
	if not card_id.is_empty():
		var card_upgrades: Dictionary = (next_data.get("card_upgrades", {}) as Dictionary).duplicate(true)
		card_upgrades[card_id] = upgrade_id
		next_data["card_upgrades"] = card_upgrades
	next_data["embers"] = maxi(0, int(next_data.get("embers", 0)) - GameData.upgrade_cost(upgrade_id))
	return next_data

static func has_upgrade(data: Dictionary, upgrade_id: String) -> bool:
	for purchased_var: Variant in data.get("purchased_upgrades", []):
		if str(purchased_var) == upgrade_id:
			return true
	return false

static func has_card_upgrade(data: Dictionary, card_id: String) -> bool:
	var card_upgrades: Dictionary = (data.get("card_upgrades", {}) as Dictionary)
	return not str(card_upgrades.get(card_id, "")).is_empty()
