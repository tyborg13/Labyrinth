extends RefCounted

const Caches = preload("res://scripts/engine_cache_directories.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const SteamServiceScript = preload("res://scripts/steam_service.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")

# Fixture values only. The expected account path is independent of the hook.
const ORIGINAL_PROFILE_NAME: String = "Engine Cache Switch Original"
const STEAM_PROFILE_PREFIX: String = "Escape the Umbra/steam"
const STANDARD_STEAM_ID: String = "123"
const CUSTOM_STEAM_ID: String = "456"
const ORIGINAL_EMBERS: int = 17
const ACCOUNT_EMBERS: int = 29
const ORIGINAL_VOLUME: float = 0.25
const ACCOUNT_VOLUME: float = 0.75
const ORIGINAL_CHECKPOINT: int = 3
const ACCOUNT_CHECKPOINT: int = 7
const CACHE_GROUP: String = "SteamSwitchFixtureRD/group"

static func run(expect: Callable) -> void:
	var previous_custom: bool = ProjectSettings.get_setting("application/config/use_custom_user_dir", false)
	var previous_name: String = ProjectSettings.get_setting("application/config/custom_user_dir_name", "")
	var previous_namespace: String = Parallel._namespace
	var previous_profile: String = Progression._storage_path
	var previous_run: String = Progression._run_storage_path
	var previous_settings: String = Settings.storage_path()
	var previous_analytics: String = Analytics.storage_dir()
	Progression.flush_pending_run_saves()
	Analytics.flush_pending_events(true)
	Progression.set_storage_path(Progression.DEFAULT_STORAGE_PATH)
	Progression.set_run_storage_path(Progression.DEFAULT_RUN_STORAGE_PATH)
	Settings.set_storage_path(Settings.DEFAULT_STORAGE_PATH)
	Analytics.set_storage_dir(Analytics.DEFAULT_STORAGE_DIR)
	# Resolve the platform's custom-user-dir base independently of the Steam hook.
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", ORIGINAL_PROFILE_NAME)
	var custom_base: String = ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir()
	Parallel._namespace = ""
	_exercise_switch(false, STANDARD_STEAM_ID, custom_base, expect)
	_exercise_switch(true, CUSTOM_STEAM_ID, custom_base, expect)
	Progression.flush_pending_run_saves()
	Analytics.flush_pending_events(true)
	Parallel._namespace = previous_namespace
	ProjectSettings.set_setting("application/config/use_custom_user_dir", previous_custom)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", previous_name)
	Progression.set_storage_path(previous_profile)
	Progression.set_run_storage_path(previous_run)
	Settings.set_storage_path(previous_settings)
	Analytics.set_storage_dir(previous_analytics)

static func _exercise_switch(custom: bool, steam_id: String, custom_base: String, expect: Callable) -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", custom)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", ORIGINAL_PROFILE_NAME)
	var original: String = ProjectSettings.globalize_path("user://").trim_suffix("/")
	var expected: String = custom_base.path_join(STEAM_PROFILE_PREFIX).path_join(steam_id)
	expect.call(original != expected, "Switch fixture starts outside the Steam account: " + steam_id)
	DirAccess.make_dir_recursive_absolute(original)
	for folder: String in Caches.CACHE_FOLDERS:
		DirAccess.make_dir_recursive_absolute(original.path_join(folder).path_join(CACHE_GROUP))
	var directory: DirAccess = DirAccess.open(original)
	var links_available: bool = directory.create_link(original.path_join("shader_cache"), "cache-link-fixture") == OK
	_write_profile(ORIGINAL_EMBERS, ORIGINAL_VOLUME, ORIGINAL_CHECKPOINT, "cache_switch_original", expect)
	_check_profile(original, ORIGINAL_EMBERS, ORIGINAL_VOLUME, ORIGINAL_CHECKPOINT, "cache_switch_original", expect)
	var original_bytes: Dictionary = _profile_bytes(original)
	var service := SteamServiceScript.new()
	service._initialized = true
	service._logged_on = true
	service._steam_id = steam_id
	service._apply_steam_user_directory()
	var switched: String = ProjectSettings.globalize_path("user://").trim_suffix("/")
	expect.call(switched == expected, "Steam switch resolves user:// to the expected account path: " + steam_id)
	expect.call(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir")), "Steam switch enables the custom user directory")
	expect.call(ProjectSettings.get_setting("application/config/custom_user_dir_name") == STEAM_PROFILE_PREFIX.path_join(steam_id), "Steam switch selects the account directory name")
	_check_caches(original, expected, links_available, expect)
	_write_profile(ACCOUNT_EMBERS, ACCOUNT_VOLUME, ACCOUNT_CHECKPOINT, "cache_switch_account", expect)
	_check_profile(expected, ACCOUNT_EMBERS, ACCOUNT_VOLUME, ACCOUNT_CHECKPOINT, "cache_switch_account", expect)
	expect.call(int(Progression.load_data()["embers"]) == ACCOUNT_EMBERS, "Account progression loads through the real store")
	expect.call(int(Progression.load_saved_run().get("checkpoint_index", -1)) == ACCOUNT_CHECKPOINT, "Account checkpoint loads through the real store")
	expect.call(is_equal_approx(Settings.load_settings()["master_volume"], ACCOUNT_VOLUME), "Account settings load through the real store")
	expect.call(_profile_bytes(original) == original_bytes, "Steam switch leaves every original profile byte untouched: " + steam_id)
	service._apply_steam_user_directory()
	expect.call(ProjectSettings.globalize_path("user://").trim_suffix("/") == expected, "Repeated Steam hook keeps the expected account path")
	_check_caches(original, expected, links_available, expect)
	expect.call(_profile_bytes(original) == original_bytes, "Repeated Steam hook leaves original profile bytes untouched")
	service.free()

static func _write_profile(embers: int, volume: float, checkpoint: int, event_type: String, expect: Callable) -> void:
	var profile: Dictionary = Progression.default_data()
	profile["embers"] = embers
	expect.call(Progression.save_data(profile), "Real progression save succeeds: " + event_type)
	var run_state: Dictionary = {"surface_rules_version": Progression.SURFACE_RULES_VERSION, "checkpoint_index": checkpoint}
	expect.call(Progression.save_run_state(run_state), "Real run checkpoint save succeeds: " + event_type)
	var settings: Dictionary = Settings.default_settings()
	settings["master_volume"] = volume
	expect.call(Settings.save_settings(settings), "Real settings save succeeds: " + event_type)
	var analytics := Analytics.new()
	expect.call(analytics.write_event(event_type), "Real analytics event write succeeds: " + event_type)
	expect.call(Analytics.flush_pending_events(true), "Analytics writes reach disk: " + event_type)

static func _check_profile(root: String, embers: int, volume: float, checkpoint: int, event_type: String, expect: Callable) -> void:
	var profile_path: String = root.path_join("progression.json")
	var run_path: String = root.path_join("current_run.save")
	var settings_path: String = root.path_join("settings.json")
	expect.call(FileAccess.file_exists(profile_path), "Progression bytes land in the expected profile: " + root)
	expect.call(FileAccess.file_exists(run_path), "Run save bytes land in the expected profile: " + root)
	expect.call(FileAccess.file_exists(settings_path), "Settings bytes land in the expected profile: " + root)
	if FileAccess.file_exists(profile_path):
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
		expect.call(int(profile["embers"]) == embers, "Expected profile contains the saved progression")
	if FileAccess.file_exists(run_path):
		var run_file: FileAccess = FileAccess.open(run_path, FileAccess.READ)
		var run_state: Dictionary = run_file.get_var(false)
		expect.call(int(run_state.get("checkpoint_index", -1)) == checkpoint, "Expected profile contains the saved checkpoint")
	if FileAccess.file_exists(settings_path):
		var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		expect.call(is_equal_approx(settings["master_volume"], volume), "Expected profile contains the saved settings")
	var found_event: bool = false
	var analytics_path: String = root.path_join("analytics")
	if DirAccess.dir_exists_absolute(analytics_path):
		for filename: String in DirAccess.get_files_at(analytics_path):
			if not filename.ends_with(".jsonl"): continue
			for line: String in FileAccess.get_file_as_string(analytics_path.path_join(filename)).split("\n", false):
				var event: Dictionary = JSON.parse_string(line)
				if event.get("event_type") == event_type: found_event = true
	expect.call(found_event, "Analytics event bytes land in the expected profile: " + root)

static func _check_caches(original: String, expected: String, links_available: bool, expect: Callable) -> void:
	var directory: DirAccess = DirAccess.open(expected)
	expect.call(directory != null, "Steam account directory exists at its expected absolute path")
	if directory == null: return
	for folder: String in Caches.CACHE_FOLDERS:
		if links_available:
			expect.call(directory.is_link(folder), "Steam account cache root is linked: " + folder)
			expect.call(directory.is_equivalent(original.path_join(folder), expected.path_join(folder)), "Steam account cache resolves to the pre-switch folder: " + folder)
		else:
			expect.call(DirAccess.dir_exists_absolute(expected.path_join(folder).path_join(CACHE_GROUP)), "Steam account mirrors cache groups when links are denied: " + folder)

static func _profile_bytes(root: String) -> Dictionary:
	var snapshot: Dictionary = {}
	var directory: DirAccess = DirAccess.open(root)
	if directory == null: return snapshot
	directory.include_hidden = true
	for filename: String in directory.get_files():
		if not directory.is_link(filename): snapshot[filename] = FileAccess.get_file_as_bytes(root.path_join(filename))
	for folder: String in directory.get_directories():
		if folder in Caches.CACHE_FOLDERS or directory.is_link(folder): continue
		var nested: Dictionary = _profile_bytes(root.path_join(folder))
		for path: String in nested:
			snapshot[folder.path_join(path)] = nested[path]
	return snapshot
