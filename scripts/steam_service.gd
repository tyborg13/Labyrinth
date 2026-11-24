extends Node

signal profile_changed(profile_name: String)
signal steam_status_changed(active: bool)

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const PlayStats = preload("res://scripts/play_stats.gd")
const MIN_STORE_INTERVAL_USEC := 60000000
const PLAY_SESSION_PATH := "user://steam_play_session_%s.json"
const InputRouterScript = preload("res://scripts/input_router.gd")
const RunPersistence = preload("res://scripts/run_persistence.gd")
# Tests can substitute an absent feature to exercise the exported-build path.
const TEST_OVERRIDE_FEATURE: String = "editor"

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
const FLOATING_TEXT_INPUT_SINGLE_LINE: int = 0

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
var _floating_keyboard_open: bool = false
var _play_kinds := PlayStats.kinds()
var _play: PlayStats
var _queued_play_batches: Array[Dictionary]
var _unavailable_play_stats: Dictionary = {}
var _warned_play_stat_rejection := false
var _last_store_usec := -MIN_STORE_INTERVAL_USEC
var _recovered_play_session := ""
var _play_session_id := ""
var _play_session_path_override := ""
var _clean_quit_captured := false
var _play_queue_needs_persist := false
var _play_queue_persist_minute := -1

func _enter_tree() -> void:
	ParallelRuntime.apply_from_environment()
	preload("res://scripts/application_shutdown.gd").install(get_tree().root)
	var started := Time.get_ticks_usec() if OS.get_environment("LABYRINTH_HITCH_TRACE") == "1" else 0
	_initialize_steam()
	if started > 0:
		set_meta(&"startup_steam_init_usec", Time.get_ticks_usec() - started)
	_apply_steam_user_directory()
	if is_steam_active():
		_play = PlayStats.new()
		_restore_queued_stat_deltas()
	if _initialized: _request_current_stats()
	set_process(_initialized)
	if is_steam_active():
		_start_play_session()
		get_tree().root.focus_entered.connect(_on_play_focus.bind(true))
		get_tree().root.focus_exited.connect(_on_play_focus.bind(false))
		_on_play_focus(get_tree().root.has_focus())

func _ready() -> void:
	add_child(preload("res://scripts/settings_runtime.gd").new())

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
	if _play != null:
		if preload("res://scripts/application_shutdown.gd").quit_requested(get_tree()):
			capture_clean_quit(get_tree().current_scene)
		_flush_play_on_idle.call_deferred()
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
	if _clean_quit_captured:
		_finish_clean_quit()
	else:
		_persist_queued_stat_deltas()
		if _stats_dirty:
			store_pending_stats()

func is_steam_available() -> bool:
	return _steam != null

func is_steam_active() -> bool:
	return _initialized and _logged_on and not _steam_id.is_empty()

func open_store_page() -> void:
	var config: Dictionary = preload("res://scripts/demo_rules.gd").config()
	if is_steam_active() and _steam.has_method("isOverlayEnabled") and bool(_steam.call("isOverlayEnabled")) and _steam.has_method("activateGameOverlayToStore"):
		_steam.call("activateGameOverlayToStore", int(config["store_app_id"]), 0)
	else:
		var shell: Callable = OS.shell_open
		if OS.has_feature(TEST_OVERRIDE_FEATURE):
			var override: Variant = get_meta("store_shell_open_for_test", Callable())
			if override is Callable and (override as Callable).is_valid():
				shell = override
		shell.call(str(config["store_url"]))

func show_floating_gamepad_text_input(field_rect: Rect2i) -> bool:
	if not _initialized or _steam == null or not _steam.has_method("showFloatingGamepadTextInput"):
		return false
	if _steam.has_method("isSteamRunning") and not bool(_steam.call("isSteamRunning")):
		return false
	if _floating_keyboard_open: return true
	if field_rect.size.x <= 0 or field_rect.size.y <= 0: return false
	if _steam.has_signal("floating_gamepad_text_input_dismissed"):
		var dismissed: Callable = _on_floating_keyboard_dismissed
		if not _steam.is_connected("floating_gamepad_text_input_dismissed", dismissed):
			_steam.connect("floating_gamepad_text_input_dismissed", dismissed)
	_floating_keyboard_open = bool(_steam.call("showFloatingGamepadTextInput", FLOATING_TEXT_INPUT_SINGLE_LINE,
		field_rect.position.x, field_rect.position.y, field_rect.size.x, field_rect.size.y))
	return _floating_keyboard_open

func dismiss_floating_gamepad_text_input() -> void:
	if _floating_keyboard_open and _steam != null and _steam.has_method("dismissFloatingGamepadTextInput"):
		_steam.call("dismissFloatingGamepadTextInput")
	_floating_keyboard_open = false

func _on_floating_keyboard_dismissed() -> void:
	_floating_keyboard_open = false

func persona_name() -> String:
	return _persona_name

func steam_id() -> String:
	return _steam_id

static func steam_user_dir_prefix() -> String:
	return DemoBuild.DEMO_APP_NAME + "/steam" if DemoBuild.is_demo() else STEAM_USER_DIR_PREFIX

func steam_user_dir_name() -> String:
	if _steam_id.is_empty():
		return ""
	return "%s/%s" % [steam_user_dir_prefix(), _safe_path_fragment(_steam_id)]

func steam_cloud_subdirectory_template() -> String:
	return "%s/%s" % [steam_user_dir_prefix(), STEAM_ID_TEMPLATE]

func profile_label_text() -> String:
	var name: String = _persona_name if is_steam_active() else FALLBACK_PROFILE_NAME
	return "%s %s" % [PROFILE_PREFIX, name]

func init_result() -> Dictionary:
	return _init_result.duplicate(true)

func accumulate_int_stats(deltas: Dictionary) -> Dictionary:
	if DemoBuild.is_demo():
		deltas = _play_only(deltas)
		if deltas.is_empty():
			_last_stats_status = {"accepted": [], "failed": {}, "reason": "demo_build"}
			return _last_stats_status.duplicate(true)
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
	var stat_names: Array[String]
	for name_var: Variant in deltas.keys():
		stat_names.append(str(name_var))
	stat_names.sort()
	var accepted: Array[String]
	var failed: Dictionary = {}
	for stat_name: String in stat_names:
		var delta: int = int(deltas.get(stat_name, 0))
		if delta <= 0:
			continue
		if not _is_valid_stat_name(stat_name):
			failed[stat_name] = "invalid_name"
			continue
		var is_play: bool = _play_kinds.has(stat_name)
		var base_value: int = _current_stat_value(stat_name)
		if base_value < 0:
			failed[stat_name] = "current_value_unavailable"
			if is_play: _reject_play_stat(stat_name)
			continue
		var next_value: int
		match str(_play_kinds.get(stat_name, "")):
			"player_flag":
				next_value = 1
			"player_value":
				next_value = mini(MAX_STEAM_INT_STAT, delta)
			_:
				next_value = base_value + mini(delta, MAX_STEAM_INT_STAT - base_value)
		if is_play and base_value >= next_value: continue
		if _play_kinds.get(stat_name) == "player_value" and base_value != 0: continue
		if bool(_steam.call("setStatInt", stat_name, next_value)):
			accepted.append(stat_name)
			_pending_stat_targets[stat_name] = next_value
			_applied_stat_targets[stat_name] = next_value
		else:
			failed[stat_name] = "set_rejected"
			if is_play: _reject_play_stat(stat_name)
	if not accepted.is_empty():
		_stats_dirty = true
	_last_stats_status = {
		"accepted": accepted,
		"failed": failed,
		"reason": "queued" if not accepted.is_empty() else "no_stats_accepted",
	}
	return _last_stats_status.duplicate(true)

func store_pending_stats() -> Dictionary:
	if DemoBuild.is_demo() and _queued_play_batches.is_empty() and _play_only(_queued_stat_deltas).is_empty() and _play_only(_pending_stat_targets).is_empty():
		_last_stats_status = {"accepted": [], "failed": {}, "reason": "demo_build"}
		return _last_stats_status.duplicate(true)
	var clean_quit: bool = _clean_quit_captured
	if _stats_store_in_flight:
		_last_stats_status = {"attempted": false, "reason": "store_in_flight"}
		return _last_stats_status.duplicate(true)
	if not _stats_ready and (not _queued_stat_deltas.is_empty() or not _queued_play_batches.is_empty()):
		_last_stats_status = {
			"attempted": false,
			"reason": "stats_not_ready",
			"queued_stat_count": _queued_stat_deltas.size() + _queued_play_batches.size(),
			"request_in_flight": _stats_request_in_flight,
		}
		return _last_stats_status.duplicate(true)
	if not _stats_dirty:
		_last_stats_status = {"attempted": false, "reason": "demo_build" if DemoBuild.is_demo() else "no_pending_stats"}
		return _last_stats_status.duplicate(true)
	if not is_steam_active() or not _steam.has_method("storeStats"):
		_last_stats_status = {"attempted": false, "reason": "steam_store_unavailable"}
		return _last_stats_status.duplicate(true)
	if is_inside_tree() and not clean_quit and Time.get_ticks_usec() - _last_store_usec < MIN_STORE_INTERVAL_USEC:
		_last_stats_status = {"attempted": false, "reason": "store_throttled"}
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
	_last_store_usec = Time.get_ticks_usec()
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
		"queued_stat_count": _queued_stat_deltas.size() + _queued_play_batches.size(),
		"queued_stats_durable": (_queued_stat_deltas.is_empty() and _queued_play_batches.is_empty()) or FileAccess.file_exists(_stats_queue_path()),
		"pending_target_count": _pending_stat_targets.size(),
		"store_in_flight": _stats_store_in_flight,
	}

func pending_stat_targets_for_test() -> Dictionary:
	return _pending_stat_targets.duplicate(true)

func _initialize_steam() -> void:
	if OS.get_environment(DISABLE_STEAM_ENV).strip_edges().to_lower() in ["1", "true", "yes"]:
		_init_result = {"ok": false, "reason": "Steam initialization disabled by %s" % DISABLE_STEAM_ENV}
		return
	if DisplayServer.get_name() == "headless":
		_init_result = {"ok": false, "reason": "Steam initialization disabled in headless mode"}
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
	if _steam.has_signal("steam_shutdown") and not _steam.is_connected("steam_shutdown", _on_steam_shutdown):
		_steam.connect("steam_shutdown", _on_steam_shutdown)
	if _steam.has_signal("user_stats_received"):
		var received_callback := Callable(self, "_on_user_stats_received")
		if not _steam.is_connected("user_stats_received", received_callback):
			_steam.connect("user_stats_received", received_callback)
	if _steam.has_signal("user_stats_stored"):
		var stored_callback := Callable(self, "_on_user_stats_stored")
		if not _steam.is_connected("user_stats_stored", stored_callback):
			_steam.connect("user_stats_stored", stored_callback)
		_stats_store_callback_connected = true

func _on_steam_shutdown() -> void:
	if is_inside_tree(): capture_clean_quit(get_tree().current_scene)
	preload("res://scripts/application_shutdown.gd").request(get_tree(), "steam_shutdown")

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
	var stat_names: Array[String]
	for stat_name_var: Variant in _pending_stat_targets.keys():
		stat_names.append(str(stat_name_var))
	stat_names.sort()
	for stat_name: String in stat_names:
		if DemoBuild.is_demo() and not _play_kinds.has(stat_name): continue
		var desired_target: int = clampi(int(_pending_stat_targets.get(stat_name, 0)), 0, MAX_STEAM_INT_STAT)
		var current_raw: Variant = _steam.call("getStatInt", stat_name)
		if typeof(current_raw) != TYPE_INT and typeof(current_raw) != TYPE_FLOAT:
			failed[stat_name] = "current_value_unavailable"
			_applied_stat_targets.erase(stat_name)
			if _play_kinds.has(stat_name):
				_reject_play_stat(stat_name)
				_pending_stat_targets.erase(stat_name)
			continue
		var current := clampi(int(current_raw), 0, MAX_STEAM_INT_STAT)
		if _play_kinds.get(stat_name) in ["player_flag", "player_value"] and current > 0:
			if current != desired_target:
				# Steam already has a set-once value. Never overwrite it on retry.
				_pending_stat_targets.erase(stat_name)
				_applied_stat_targets.erase(stat_name)
				continue
		var corrected_target: int = maxi(current, desired_target)
		_pending_stat_targets[stat_name] = corrected_target
		if bool(_steam.call("setStatInt", stat_name, corrected_target)):
			_applied_stat_targets[stat_name] = corrected_target
		else:
			failed[stat_name] = "set_rejected"
			_applied_stat_targets.erase(stat_name)
			if _play_kinds.has(stat_name):
				_reject_play_stat(stat_name)
				_pending_stat_targets.erase(stat_name)
	return failed

func _queue_int_stat_deltas(deltas: Dictionary) -> Dictionary:
	var queued: Array[String]
	var failed: Dictionary = {}
	for name_var: Variant in deltas.keys():
		var stat_name: String = str(name_var)
		var delta: int = int(deltas.get(name_var, 0))
		if delta <= 0:
			continue
		if not _is_valid_stat_name(stat_name):
			failed[stat_name] = "invalid_name"
			continue
		if _play_kinds.get(stat_name) == "player_value" and _queued_stat_deltas.has(stat_name):
			queued.append(stat_name)
			continue
		_queued_stat_deltas[stat_name] = mini(
			MAX_STEAM_INT_STAT,
			int(_queued_stat_deltas.get(stat_name, 0)) + mini(delta, MAX_STEAM_INT_STAT)
		)
		queued.append(stat_name)
	queued.sort()
	_persist_queued_stat_deltas()
	return {"queued": queued, "failed": failed}

func _apply_queued_stat_deltas() -> void:
	if not _stats_ready or not is_steam_active(): return
	if not _pending_stat_targets.is_empty() and _stats_dirty: _reapply_pending_stat_targets()
	if not _queued_stat_deltas.is_empty(): _apply_legacy_stat_deltas()
	_apply_queued_play_batches()
	_play_queue_needs_persist = not _persist_queued_stat_deltas()

func _apply_legacy_stat_deltas() -> void:
	var queued: Dictionary = _queued_stat_deltas.duplicate(true)
	_queued_stat_deltas.clear()
	var result: Dictionary = accumulate_int_stats(queued)
	var failed: Dictionary = result.get("failed", {}) as Dictionary
	for stat_name_var: Variant in failed.keys():
		var stat_name: String = str(stat_name_var)
		if queued.has(stat_name) and not _play_kinds.has(stat_name):
			_queued_stat_deltas[stat_name] = int(queued[stat_name])
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
	if _steam_id.is_empty(): return true
	var path: String = _stats_queue_path()
	var deltas: Dictionary = _play_only(_queued_stat_deltas) if DemoBuild.is_demo() else _queued_stat_deltas
	var play_targets: Dictionary = _play_only(_pending_stat_targets)
	var run_clock_id: String = _play.run_clock_id if _play != null else ""
	var boss_run_id: String = _play.boss_run_id if _play != null else ""
	if deltas.is_empty() and _queued_play_batches.is_empty() and play_targets.is_empty() and _recovered_play_session.is_empty() and run_clock_id.is_empty() and boss_run_id.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return true
	return _write_play_json(path, {
		"schema_version": 2,
		"deltas": deltas,
		"play_batches": _queued_play_batches,
		"play_targets": play_targets,
		"recovered_play_session": _recovered_play_session,
		"boss_run_id": boss_run_id,
		"tutorial_run_id": _play.tutorial_run_id if _play != null else "",
		"run_clock_id": run_clock_id,
		"run_clock_minute": _play.run_clock_minute if _play != null else 0,
	})

func _restore_queued_stat_deltas() -> void:
	var parsed: Dictionary = _read_play_json(_stats_queue_path())
	var deltas: Dictionary = parsed.get("deltas", {})
	_queued_stat_deltas = _play_only(deltas) if DemoBuild.is_demo() else deltas
	for batch: Variant in parsed.get("play_batches", []):
		if batch is Dictionary: _queued_play_batches.append(batch)
	_pending_stat_targets.merge(_play_only(parsed.get("play_targets", {})))
	_stats_dirty = not _pending_stat_targets.is_empty()
	_recovered_play_session = str(parsed.get("recovered_play_session", ""))
	if _play != null:
		_play.run_clock_id = str(parsed.get("run_clock_id", ""))
		_play.run_clock_minute = int(parsed.get("run_clock_minute", 0))
		_play.boss_run_id = str(parsed.get("boss_run_id", ""))
		_play.tutorial_run_id = str(parsed.get("tutorial_run_id", ""))

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
	var original_user_dir: String = ProjectSettings.globalize_path("user://")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", user_dir_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	var cache_report: Dictionary = preload("res://scripts/engine_cache_directories.gd").preserve(original_user_dir, ProjectSettings.globalize_path("user://"))
	print("ENGINE CACHE SWITCH: " + JSON.stringify(cache_report))

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
		if not _steam_id.is_empty(): _restore_queued_stat_deltas()
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

func _play_only(stats: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in stats:
		if _play_kinds.has(key): result[key] = stats[key]
	return result

func _current_stat_value(stat_name: String) -> int:
	if _unavailable_play_stats.has(stat_name): return -1
	var current: Variant = _steam.call("getStatInt", stat_name)
	if typeof(current) != TYPE_INT and typeof(current) != TYPE_FLOAT: return -1
	# Desired targets can outlive a Steam cache refresh or a process restart.
	return maxi(clampi(int(current), 0, MAX_STEAM_INT_STAT), int(_pending_stat_targets.get(stat_name, 0)))

func _reject_play_stat(stat_name: String) -> void:
	_unavailable_play_stats[stat_name] = true
	if _warned_play_stat_rejection: return
	_warned_play_stat_rejection = true
	push_warning("Steam rejected a play stat. Verify the published Steamworks stat definitions for this app.")

func _apply_queued_play_batches() -> void:
	if _queued_play_batches.is_empty() or not _steam.has_method("getStatInt") or not _steam.has_method("setStatInt"):
		return
	for batch: Dictionary in _queued_play_batches:
		if batch.has("deltas"):
			accumulate_int_stats(batch["deltas"])
		elif batch.has("new_run"):
			_apply_play_new_run()
		elif batch.has("launch_day"):
			_apply_play_launch_day(int(batch["launch_day"]))
	_queued_play_batches.clear()

func _apply_play_new_run() -> void:
	accumulate_int_stats({"play_v1_runs_started": 1, "play_v1_p_run_started": 1})
	var flags: Dictionary = {}
	if _current_stat_value("play_v1_runs_started") >= 2: flags["play_v1_p_run2"] = 1
	if _current_stat_value("play_v1_runs_won") >= 1: flags["play_v1_p_run_after_win"] = 1
	if not flags.is_empty(): accumulate_int_stats(flags)

func _apply_play_launch_day(day: int) -> void:
	var first_day := _current_stat_value("play_v1_first_day")
	if first_day == 0:
		accumulate_int_stats({"play_v1_first_day": day})
	elif first_day > 0 and day > first_day:
		var flags := {"play_v1_p_day2": 1}
		if day - first_day >= 7: flags["play_v1_p_day7"] = 1
		accumulate_int_stats(flags)

func _read_play_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _write_play_json(path: String, data: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	var result := file.get_error()
	file.close()
	if result != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK

func _play_marker_path() -> String:
	if not _play_session_path_override.is_empty(): return _play_session_path_override
	return PLAY_SESSION_PATH % _safe_path_fragment(_steam_id)

func _start_play_session(platform: String = OS.get_name()) -> void:
	if _play == null: _play = PlayStats.new()
	_play.started_unix = int(Time.get_unix_time_from_system())
	_play.started_usec = Time.get_ticks_usec()
	_play_session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var previous := _read_play_json(_play_marker_path())
	var previous_id := str(previous.get("id", ""))
	if not previous_id.is_empty() and previous_id != _recovered_play_session:
		_play.recover_session(int(previous.get("last_minute", 0)))
		_recovered_play_session = previous_id
	var deck := _steam.has_method("isSteamRunningOnSteamDeck") and bool(_steam.call("isSteamRunningOnSteamDeck"))
	_play.launch(_play.started_unix / PlayStats.DAY_SECONDS, platform, deck)
	# Record recovery and its token before replacing the old session marker.
	if _flush_play_batches(): _write_play_marker(0)

func _write_play_marker(minute: int) -> void:
	_play.marker_minute = minute
	_write_play_json(_play_marker_path(), {
		"id": _play_session_id, "started_unix": _play.started_unix, "last_minute": minute,
	})

func _on_play_focus(focused: bool) -> void:
	if _play != null and not _play.closing: _play.set_focused(focused, Time.get_ticks_usec())

func _input(event: InputEvent) -> void:
	if _play == null or _play.gamepad_seen or _play.closing: return
	if (
		(event is InputEventJoypadButton and event.pressed)
		or (event is InputEventJoypadMotion and absf(event.axis_value) >= InputRouterScript.JOYSTICK_ACTIVITY_THRESHOLD)
	):
		_mark_play_gamepad()

func _mark_play_gamepad() -> void:
	if _play.gamepad_seen: return
	_play.gamepad_seen = true
	_play.emit_stats({"p_gamepad": 1})

func observe_play_records(records: Array) -> void:
	if _play == null or not is_steam_active(): return
	for record: Dictionary in records: _play.observe(record)

func record_play_signal(event: String, detail: Variant = null) -> void:
	if _play == null or not is_steam_active(): return
	match event:
		"menu_loaded": _play.main_menu_loaded()
		"button": _play.button(detail[0], detail[1])
		"rise_again", "load_errors", "save_errors": _play.emit_stats({event: 1})

func _flush_play_on_idle() -> void:
	if _play.closing or not is_steam_active(): return
	var scene := get_tree().current_scene
	# The persistence scheduler marks both rule work and reserved post-draw work.
	if RunPersistence._resolution_frame == Engine.get_process_frames() or (scene != null and scene.has_meta(RunPersistence.AFTER_DRAW_RESOLUTION_META)):
		return
	var now := Time.get_ticks_usec()
	_play.sample_focus(now)
	_sample_run_play_clock(scene)
	# Modal handlers also record controller input through InputRouter before
	# consuming it, so count activity even if this autoload did not see _input.
	if not _play.gamepad_seen:
		var router := get_tree().root.get_node_or_null("InputRouter")
		if router != null and int(router.get("_last_controller_activity_msec")) >= 0:
			_mark_play_gamepad()
	var minute: int = (now - _play.started_usec) / PlayStats.MINUTE_USEC
	var durable := not _play_queue_needs_persist
	if not _play.batches.is_empty() or (_play_queue_needs_persist and _play_queue_persist_minute != minute):
		_play_queue_persist_minute = minute
		durable = _flush_play_batches()
	if durable and minute > _play.marker_minute: _write_play_marker(minute)
	if _play.store_requested and _stats_ready:
		var result := store_pending_stats()
		if result.get("reason") in ["submitted", "stored", "no_pending_stats", "demo_build", "no_applied_stats"]:
			_play.store_requested = false

func _flush_play_batches() -> bool:
	if not _play.batches.is_empty():
		_queued_play_batches.append_array(_play.batches)
		_play.batches.clear()
		if _stats_ready: _apply_queued_play_batches()
		_play_queue_needs_persist = true
	if _play_queue_needs_persist:
		_play_queue_needs_persist = not _persist_queued_stat_deltas()
	return not _play_queue_needs_persist

func _sample_run_play_clock(scene: Node) -> void:
	if scene == null or not scene.has_method("play_stats_run_clock"): return
	var clock: Array = scene.play_stats_run_clock()
	if not clock.is_empty(): _play.sample_run_clock(clock[0], clock[1], clock[2])

func capture_clean_quit(scene: Node) -> void:
	if _play == null or _clean_quit_captured: return
	_clean_quit_captured = true
	_play.closing = true
	var now := Time.get_ticks_usec()
	_play.sample_focus(now)
	_sample_run_play_clock(scene)
	var screen := "other"
	var fights := -1
	if scene != null and scene.has_method("play_stats_quit_context"):
		var context: Dictionary = scene.play_stats_quit_context()
		screen = context["screen"]
		fights = int(context.get("fights", -1))
		if not bool(context.get("collect", true)): return
	_play.finish_session(screen, fights, (now - _play.started_usec) / PlayStats.MINUTE_USEC)

func _finish_clean_quit() -> void:
	# Persist the marker ID with the clean-quit batch. A hard stop between that
	# write and marker removal must not count the same session a second time.
	_recovered_play_session = _play_session_id
	_flush_play_batches()
	# Submit the final cache without awaiting Steam. The durable play targets
	# cover the case where the previous StoreStats callback is still in flight.
	if _stats_store_in_flight and _steam.has_method("run_callbacks"): _steam.call("run_callbacks")
	if _stats_store_in_flight:
		_stats_store_in_flight = false
		_submitted_stat_targets.clear()
	store_pending_stats()
	_persist_queued_stat_deltas()
	var path := _play_marker_path()
	if str(_read_play_json(path).get("id", "")) == _play_session_id:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
