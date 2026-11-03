extends RefCounted

# Exercise the actual Steam hook without starting Steam. The task namespace is
# disabled only for this call; HOME and all files remain runner-isolated.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const SteamServiceScript = preload("res://scripts/steam_service.gd")
const Caches = preload("res://scripts/engine_cache_directories.gd")
const FIXTURE_STEAM_ID: String = "123"

static func switch_user_directory() -> Dictionary:
	Parallel.apply_from_environment()
	var original: String = ProjectSettings.globalize_path("user://")
	var previous_namespace: String = Parallel._namespace
	var service := SteamServiceScript.new()
	service._initialized = true
	service._logged_on = true
	service._steam_id = FIXTURE_STEAM_ID
	Parallel._namespace = ""
	service._apply_steam_user_directory()
	Parallel._namespace = previous_namespace
	service.free()
	var switched: String = ProjectSettings.globalize_path("user://")
	var directory: DirAccess = DirAccess.open(switched)
	var folders: Dictionary = {}
	for folder: String in Caches.CACHE_FOLDERS:
		folders[folder] = {"linked": directory.is_link(folder), "shared": directory.is_equivalent(original.path_join(folder), switched.path_join(folder))}
	return {"before": original, "after": switched, "folders": folders}
