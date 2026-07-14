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

var _steam: Object = null
var _initialized: bool = false
var _logged_on: bool = false
var _persona_name: String = ""
var _steam_id: String = ""
var _init_result: Dictionary = {}
var _refresh_elapsed: float = 0.0

func _enter_tree() -> void:
	ParallelRuntime.apply_from_environment()
	_initialize_steam()
	_apply_steam_user_directory()
	set_process(_initialized)

func _process(delta: float) -> void:
	if _steam == null:
		return
	if _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")
	_refresh_elapsed += delta
	if _refresh_elapsed < PROFILE_REFRESH_INTERVAL:
		return
	_refresh_elapsed = 0.0
	_refresh_user_info()

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
		_refresh_user_info()

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
		_refresh_user_info()

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
