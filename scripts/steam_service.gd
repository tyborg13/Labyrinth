extends Node

signal profile_changed(profile_name: String)
signal steam_status_changed(active: bool)

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const FALLBACK_PROFILE_NAME: String = "Reaver"
const PROFILE_PREFIX: String = "Profile"
const STEAM_USER_DIR_PREFIX: String = "Escape the Umbra/steam"
const STEAM_ID_TEMPLATE: String = "{64BitSteamID}"
const PROFILE_REFRESH_INTERVAL: float = 1.5
const DISABLE_STEAM_ENV: String = "LABYRINTH_DISABLE_STEAM"
const DEFAULT_STATS_STORE_INTERVAL_SECONDS: float = 300.0
const STATS_REQUEST_RETRY_SECONDS: float = 5.0
const STATS_REQUEST_TIMEOUT_SECONDS: float = 15.0
const STATS_QUEUE_PATH_TEMPLATE: String = "user://steam_stats_pending_%s.json"
const MAX_STEAM_INT_STAT: int = 2147483647
const STEAM_RESULT_OK: int = 1

var _steam: Object = null
var _initialized: bool = false
var _logged_on: bool = false
var _persona_name: String = ""
var _steam_id: String = ""
var _init_result: Dictionary = {}
var _refresh_elapsed: float = 0.0
var _stats_store_elapsed: float = 0.0
var _stats_dirty: bool = false
var _stats_store_callback_connected: bool = false
var _stats_store_in_flight: bool = false
var _stats_ready: bool = false
var _stats_request_in_flight: bool = false
var _stats_request_retry_elapsed: float = 0.0
var _stats_request_elapsed: float = 0.0
var _queued_stat_deltas: Dictionary = {}
var _stats_queue_path_override: String = ""
var _pending_stat_targets: Dictionary = {}
var _applied_stat_targets: Dictionary = {}
var _submitted_stat_targets: Dictionary = {}
var _last_stats_status: Dictionary = {}
var _active_app_id: int = 0
var _active_user_id: int = 0

func _enter_tree() -> void:
	ParallelRuntime.apply_from_environment()
	_initialize_steam()
	_apply_steam_user_directory()
	if _initialized:
		_restore_queued_stat_deltas()
		_request_current_stats()
	set_process(_initialized)

func _process(delta: float) -> void:
	if _steam == null:
		return
	if _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")
	if not _stats_ready:
		if _stats_request_in_flight:
			_stats_request_elapsed += delta
			if _stats_request_elapsed >= STATS_REQUEST_TIMEOUT_SECONDS:
				_stats_request_in_flight = false
				_stats_request_elapsed = 0.0
				_stats_request_retry_elapsed = 0.0
				_last_stats_status = {
					"accepted": [],
					"failed": {},
					"reason": "stats_request_timeout",
				}
		else:
			_stats_request_retry_elapsed += delta
			if _stats_request_retry_elapsed >= STATS_REQUEST_RETRY_SECONDS:
				_request_current_stats()
	if _stats_dirty:
		_stats_store_elapsed += delta
		var store_interval: float = maxf(
			60.0,
			float(ProjectSettings.get_setting(
				"telemetry/performance/steam_stats_store_interval_seconds",
				DEFAULT_STATS_STORE_INTERVAL_SECONDS
			))
		)
		if _stats_store_elapsed >= store_interval:
			store_pending_stats()
	_refresh_elapsed += delta
	if _refresh_elapsed < PROFILE_REFRESH_INTERVAL:
		return
	_refresh_elapsed = 0.0
	_refresh_user_info()

func _exit_tree() -> void:
	_persist_queued_stat_deltas()
	if _stats_dirty:
		store_pending_stats()

func is_steam_available() -> bool:
	return _steam != null

func is_steam_active() -> bool:
	return _initialized and _logged_on and not _steam_id.is_empty()

func persona_name() -> String:
	return _persona_name

func steam_id() -> String:
	return _steam_id

func steam_user_dir_name() -> String:
	if _steam_id.is_empty():
		return ""
	return "%s/%s" % [STEAM_USER_DIR_PREFIX, _safe_path_fragment(_steam_id)]

func steam_cloud_subdirectory_template() -> String:
	return "%s/%s" % [STEAM_USER_DIR_PREFIX, STEAM_ID_TEMPLATE]

func profile_label_text() -> String:
	var name: String = _persona_name if is_steam_active() else FALLBACK_PROFILE_NAME
	return "%s %s" % [PROFILE_PREFIX, name]

func init_result() -> Dictionary:
	return _init_result.duplicate(true)

func accumulate_int_stats(deltas: Dictionary) -> Dictionary:
	if not is_steam_active():
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "steam_not_active",
		}
		return _last_stats_status.duplicate(true)
	if not _steam.has_method("getStatInt") or not _steam.has_method("setStatInt"):
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "integer_stats_api_unavailable",
		}
		return _last_stats_status.duplicate(true)
	if not _stats_ready:
		var queued_result: Dictionary = _queue_int_stat_deltas(deltas)
		_last_stats_status = {
			"accepted": [],
			"queued": queued_result.get("queued", []),
			"failed": queued_result.get("failed", {}),
			"reason": "stats_not_ready",
			"request_in_flight": _stats_request_in_flight,
		}
		return _last_stats_status.duplicate(true)
	var stat_names: Array[String] = []
	for name_var: Variant in deltas.keys():
		stat_names.append(str(name_var))
	stat_names.sort()
	var accepted: Array[String] = []
	var failed: Dictionary = {}
	for stat_name: String in stat_names:
		var delta: int = int(deltas.get(stat_name, 0))
		if delta <= 0:
			continue
		if not _is_valid_stat_name(stat_name):
			failed[stat_name] = "invalid_name"
			continue
		var current_raw: Variant = _steam.call("getStatInt", stat_name)
		if typeof(current_raw) != TYPE_INT and typeof(current_raw) != TYPE_FLOAT:
			failed[stat_name] = "current_value_unavailable"
			continue
		var current: int = clampi(int(current_raw), 0, MAX_STEAM_INT_STAT)
		# A pending target is already reflected in Steam's volatile local cache. Use
		# it as the floor so another telemetry window cannot lose an increment if a
		# StoreStats callback is still pending or has refreshed the cache from the
		# server in the meantime.
		var pending_target: int = clampi(int(_pending_stat_targets.get(stat_name, 0)), 0, MAX_STEAM_INT_STAT)
		var base_value: int = maxi(current, pending_target)
		var next_value: int = mini(MAX_STEAM_INT_STAT, base_value + mini(delta, MAX_STEAM_INT_STAT - base_value))
		if bool(_steam.call("setStatInt", stat_name, next_value)):
			accepted.append(stat_name)
			_pending_stat_targets[stat_name] = next_value
			_applied_stat_targets[stat_name] = next_value
		else:
			failed[stat_name] = "set_rejected"
	if not accepted.is_empty():
		_stats_dirty = true
	_last_stats_status = {
		"accepted": accepted,
		"failed": failed,
		"reason": "queued" if not accepted.is_empty() else "no_stats_accepted",
	}
	return _last_stats_status.duplicate(true)

func store_pending_stats() -> Dictionary:
	if _stats_store_in_flight:
		_last_stats_status = {"attempted": false, "reason": "store_in_flight"}
		return _last_stats_status.duplicate(true)
	if not _stats_ready and not _queued_stat_deltas.is_empty():
		_last_stats_status = {
			"attempted": false,
			"reason": "stats_not_ready",
			"queued_stat_count": _queued_stat_deltas.size(),
			"request_in_flight": _stats_request_in_flight,
		}
		return _last_stats_status.duplicate(true)
	if not _stats_dirty:
		_last_stats_status = {"attempted": false, "reason": "no_pending_stats"}
		return _last_stats_status.duplicate(true)
	if not is_steam_active() or not _steam.has_method("storeStats"):
		_last_stats_status = {"attempted": false, "reason": "steam_store_unavailable"}
		return _last_stats_status.duplicate(true)
	var reapply_failures: Dictionary = _reapply_pending_stat_targets()
	if _applied_stat_targets.is_empty():
		_stats_store_elapsed = 0.0
		_last_stats_status = {
			"attempted": false,
			"reason": "no_applied_stats",
			"reapply_failures": reapply_failures,
		}
		return _last_stats_status.duplicate(true)
	var succeeded: bool = bool(_steam.call("storeStats"))
	_stats_store_elapsed = 0.0
	if succeeded:
		# Only keys successfully present in Steam's volatile cache can be confirmed
		# by this StoreStats callback. Desired targets whose SetStat reapply failed
		# stay pending but must not enter the submitted generation.
		_submitted_stat_targets = _applied_stat_targets.duplicate(true)
		if _stats_store_callback_connected:
			_stats_store_in_flight = true
		else:
			_confirm_submitted_stat_targets()
			_stats_dirty = not _pending_stat_targets.is_empty()
	_last_stats_status = {
		"attempted": true,
		"ok": succeeded,
		"reapply_failures": reapply_failures,
		"reason": (
			"submitted" if succeeded and _stats_store_callback_connected
			else ("stored" if succeeded else "store_rejected")
		),
	}
	return _last_stats_status.duplicate(true)

func last_stats_status() -> Dictionary:
	return _last_stats_status.duplicate(true)

func stats_readiness_status() -> Dictionary:
	return {
		"ready": _stats_ready,
		"request_in_flight": _stats_request_in_flight,
		"request_elapsed_seconds": _stats_request_elapsed,
		"queued_stat_count": _queued_stat_deltas.size(),
		"queued_stats_durable": _queued_stat_deltas.is_empty() or FileAccess.file_exists(_stats_queue_path()),
		"pending_target_count": _pending_stat_targets.size(),
		"store_in_flight": _stats_store_in_flight,
	}

func pending_stat_targets_for_test() -> Dictionary:
	return _pending_stat_targets.duplicate(true)

func _initialize_steam() -> void:
	if OS.get_environment(DISABLE_STEAM_ENV).strip_edges().to_lower() in ["1", "true", "yes"]:
		_init_result = {"ok": false, "reason": "Steam initialization disabled by %s" % DISABLE_STEAM_ENV}
		return
	if not Engine.has_singleton("Steam"):
		_init_result = {"ok": false, "reason": "GodotSteam singleton is not available"}
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		_init_result = {"ok": false, "reason": "GodotSteam singleton could not be loaded"}
		return
	var raw_result: Variant = null
	if _steam.has_method("steamInitEx"):
		raw_result = _steam.call("steamInitEx")
	elif _steam.has_method("steamInit"):
		raw_result = _steam.call("steamInit")
	else:
		_init_result = {"ok": false, "reason": "GodotSteam has no initialization method"}
		return
	_init_result = _normalized_init_result(raw_result)
	_initialized = bool(_init_result.get("ok", false))
	if _initialized:
		_connect_stats_callbacks()
		_refresh_user_info()

func _connect_stats_callbacks() -> void:
	if _steam == null:
		return
	if _steam.has_signal("user_stats_received"):
		var received_callback := Callable(self, "_on_user_stats_received")
		if not _steam.is_connected("user_stats_received", received_callback):
			_steam.connect("user_stats_received", received_callback)
	if _steam.has_signal("user_stats_stored"):
		var stored_callback := Callable(self, "_on_user_stats_stored")
		if not _steam.is_connected("user_stats_stored", stored_callback):
			_steam.connect("user_stats_stored", stored_callback)
		_stats_store_callback_connected = true

func _request_current_stats() -> void:
	_stats_request_retry_elapsed = 0.0
	_stats_request_elapsed = 0.0
	if _steam == null or not _initialized:
		return
	if not _steam.has_method("requestCurrentStats"):
		# Current Steam clients preload local-user stats before launch. Older
		# GodotSteam builds expose no explicit request method, so retain that
		# compatibility path while gating every build that can provide a callback.
		_stats_ready = true
		_stats_request_in_flight = false
		_apply_queued_stat_deltas()
		return
	var requested: bool = bool(_steam.call("requestCurrentStats"))
	# A test double may complete synchronously; the real SDK callback is normally
	# asynchronous. Never overwrite a callback-confirmed ready state.
	_stats_request_in_flight = requested and not _stats_ready
	if not requested:
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "stats_request_rejected",
		}

func _on_user_stats_received(game_id: int, result: int, user_id: int) -> void:
	if not _stats_callback_matches_active_identity(game_id, user_id):
		return
	_stats_request_in_flight = false
	_stats_request_elapsed = 0.0
	_stats_ready = result == STEAM_RESULT_OK
	if not _stats_ready:
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "stats_request_callback_rejected",
			"result": result,
		}
		return
	_apply_queued_stat_deltas()

func _on_user_stats_stored(game_id: int, result: int) -> void:
	if not _stats_callback_matches_active_identity(game_id):
		return
	if not _stats_store_in_flight:
		_last_stats_status = {
			"attempted": false,
			"ok": result == STEAM_RESULT_OK,
			"reason": "unexpected_store_callback",
			"result": result,
		}
		return
	_stats_store_in_flight = false
	if result == STEAM_RESULT_OK:
		# Remove only the exact targets covered by this callback. A newer window may
		# already have raised a key while StoreStats was in flight; keep and reapply
		# that newer target to Steam's local cache for the next batch.
		_confirm_submitted_stat_targets()
		_applied_stat_targets.clear()
		var reapply_failures: Dictionary = _reapply_pending_stat_targets()
		_stats_dirty = not _pending_stat_targets.is_empty()
		_last_stats_status = {
			"attempted": true,
			"ok": true,
			"reason": "stored" if not _stats_dirty else "stored_with_newer_pending_stats",
			"reapply_failures": reapply_failures,
		}
		return
	_submitted_stat_targets.clear()
	_applied_stat_targets.clear()
	# Valve may replace rejected local values with the server's corrected values.
	# Reapply every still-pending desired absolute value before the next retry so
	# telemetry deltas (including the once-per-session key) survive that refresh.
	var reapply_failures: Dictionary = _reapply_pending_stat_targets()
	_stats_dirty = true
	_last_stats_status = {
		"attempted": true,
		"ok": false,
		"reason": "store_callback_rejected",
		"result": result,
		"reapply_failures": reapply_failures,
	}

func _reapply_pending_stat_targets() -> Dictionary:
	var failed: Dictionary = {}
	if _steam == null or not _steam.has_method("getStatInt") or not _steam.has_method("setStatInt"):
		return {"*": "integer_stats_api_unavailable"} if not _pending_stat_targets.is_empty() else {}
	var stat_names: Array[String] = []
	for stat_name_var: Variant in _pending_stat_targets.keys():
		stat_names.append(str(stat_name_var))
	stat_names.sort()
	for stat_name: String in stat_names:
		var desired_target: int = clampi(int(_pending_stat_targets.get(stat_name, 0)), 0, MAX_STEAM_INT_STAT)
		var current_raw: Variant = _steam.call("getStatInt", stat_name)
		if typeof(current_raw) != TYPE_INT and typeof(current_raw) != TYPE_FLOAT:
			failed[stat_name] = "current_value_unavailable"
			_applied_stat_targets.erase(stat_name)
			continue
		var corrected_target: int = maxi(clampi(int(current_raw), 0, MAX_STEAM_INT_STAT), desired_target)
		_pending_stat_targets[stat_name] = corrected_target
		if bool(_steam.call("setStatInt", stat_name, corrected_target)):
			_applied_stat_targets[stat_name] = corrected_target
		else:
			failed[stat_name] = "set_rejected"
			_applied_stat_targets.erase(stat_name)
	return failed

func _queue_int_stat_deltas(deltas: Dictionary) -> Dictionary:
	var queued: Array[String] = []
	var failed: Dictionary = {}
	for name_var: Variant in deltas.keys():
		var stat_name: String = str(name_var)
		var delta: int = int(deltas.get(name_var, 0))
		if delta <= 0:
			continue
		if not _is_valid_stat_name(stat_name):
			failed[stat_name] = "invalid_name"
			continue
		_queued_stat_deltas[stat_name] = mini(
			MAX_STEAM_INT_STAT,
			int(_queued_stat_deltas.get(stat_name, 0)) + delta
		)
		queued.append(stat_name)
	queued.sort()
	_persist_queued_stat_deltas()
	return {"queued": queued, "failed": failed}

func _apply_queued_stat_deltas() -> void:
	if not _stats_ready or _queued_stat_deltas.is_empty():
		return
	var queued: Dictionary = _queued_stat_deltas.duplicate(true)
	_queued_stat_deltas.clear()
	var result: Dictionary = accumulate_int_stats(queued)
	var failed: Dictionary = result.get("failed", {}) as Dictionary
	for stat_name_var: Variant in failed.keys():
		var stat_name: String = str(stat_name_var)
		if queued.has(stat_name):
			_queued_stat_deltas[stat_name] = int(queued[stat_name])
	_persist_queued_stat_deltas()
	if not failed.is_empty():
		# Runtime SetStat rejection is not transient readiness. Preserve the
		# additive delta in the durable queue for a later client session while the
		# ordinary pending-target behavior continues for accepted keys.
		_last_stats_status["released_from_readiness_queue"] = true

func _stats_callback_matches_active_identity(game_id: int, user_id: int = -1) -> bool:
	if _active_app_id > 0 and game_id != _active_app_id:
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "stats_callback_app_mismatch",
			"callback_app_id": game_id,
		}
		return false
	if user_id >= 0 and _active_user_id > 0 and user_id != _active_user_id:
		_last_stats_status = {
			"accepted": [],
			"failed": {},
			"reason": "stats_callback_user_mismatch",
		}
		return false
	return true

func _stats_queue_path() -> String:
	if not _stats_queue_path_override.is_empty():
		return _stats_queue_path_override
	return STATS_QUEUE_PATH_TEMPLATE % _safe_path_fragment(_steam_id)

func _persist_queued_stat_deltas() -> bool:
	var path: String = _stats_queue_path()
	if _queued_stat_deltas.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return true
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"deltas": _queued_stat_deltas,
	}))
	return true

func _restore_queued_stat_deltas() -> void:
	var path: String = _stats_queue_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var deltas: Dictionary = (parsed as Dictionary).get("deltas", {}) as Dictionary
	_queue_int_stat_deltas(deltas)

func _set_stats_queue_path_for_test(path: String) -> void:
	_stats_queue_path_override = path

func _confirm_submitted_stat_targets() -> void:
	for stat_name_var: Variant in _submitted_stat_targets.keys():
		var stat_name: String = str(stat_name_var)
		var submitted_target: int = int(_submitted_stat_targets[stat_name_var])
		if int(_pending_stat_targets.get(stat_name, 0)) <= submitted_target:
			_pending_stat_targets.erase(stat_name)
		if int(_applied_stat_targets.get(stat_name, 0)) <= submitted_target:
			_applied_stat_targets.erase(stat_name)
	_submitted_stat_targets.clear()

func _refresh_user_info() -> void:
	if _steam == null or not _initialized:
		return
	var was_active: bool = is_steam_active()
	var previous_name: String = _persona_name
	if _steam.has_method("loggedOn"):
		_logged_on = bool(_steam.call("loggedOn"))
	else:
		_logged_on = true
	if _steam.has_method("getSteamID"):
		_steam_id = str(_steam.call("getSteamID")).strip_edges()
		_active_user_id = _steam_id.to_int() if _steam_id.is_valid_int() else 0
	if _steam.has_method("getAppID"):
		_active_app_id = int(_steam.call("getAppID"))
	if _steam.has_method("getPersonaName"):
		var next_name: String = str(_steam.call("getPersonaName")).strip_edges()
		if not next_name.is_empty() and next_name != "[unknown]":
			_persona_name = next_name
	if previous_name != _persona_name:
		profile_changed.emit(_persona_name)
	var is_active: bool = is_steam_active()
	if was_active != is_active:
		steam_status_changed.emit(is_active)

func _apply_steam_user_directory() -> void:
	if not is_steam_active():
		return
	if not ParallelRuntime.current_namespace().is_empty():
		return
	var user_dir_name: String = steam_user_dir_name()
	if user_dir_name.is_empty():
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", user_dir_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))

func _normalized_init_result(raw_result: Variant) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"raw_type": typeof(raw_result)
	}
	match typeof(raw_result):
		TYPE_BOOL:
			result["ok"] = bool(raw_result)
		TYPE_INT:
			result["ok"] = int(raw_result) == 0
			result["status"] = int(raw_result)
		TYPE_DICTIONARY:
			var raw_dict: Dictionary = (raw_result as Dictionary).duplicate(true)
			for key_var: Variant in raw_dict.keys():
				result[str(key_var)] = raw_dict[key_var]
			if raw_dict.has("status"):
				result["ok"] = int(raw_dict.get("status", -1)) == 0
			elif raw_dict.has("success"):
				result["ok"] = bool(raw_dict.get("success", false))
			elif raw_dict.has("ok"):
				result["ok"] = bool(raw_dict.get("ok", false))
		_:
			result["raw"] = str(raw_result)
	return result

func _initialize_with_steam_for_test(steam: Object, raw_result: Variant) -> void:
	_steam = steam
	_init_result = _normalized_init_result(raw_result)
	_initialized = bool(_init_result.get("ok", false))
	if _initialized:
		_connect_stats_callbacks()
		_refresh_user_info()
		_restore_queued_stat_deltas()
		_request_current_stats()

func _safe_path_fragment(value: String) -> String:
	var result: String = ""
	for index: int in value.length():
		var ch: String = value.substr(index, 1)
		if ch.is_valid_int() or ch in ["-", "_"]:
			result += ch
		else:
			result += "-"
	while result.find("--") >= 0:
		result = result.replace("--", "-")
	result = result.strip_edges()
	return "steam-user" if result.is_empty() else result.substr(0, 80)

func _is_valid_stat_name(value: String) -> bool:
	if value.is_empty() or value.length() > 127:
		return false
	for index: int in value.length():
		var character: String = value.substr(index, 1)
		if not (character.is_valid_int() or character == "_" or (character >= "a" and character <= "z")):
			return false
	return true
