extends RefCounted

const SteamServiceScript = preload("res://scripts/steam_service.gd")

class FakeSteam:
	extends Object

	var logged_on: bool = true
	var steam_id: String = "76561198027391269"
	var persona: String = "Wayfarer"

	func loggedOn() -> bool:
		return logged_on

	func getSteamID() -> String:
		return steam_id

	func getPersonaName() -> String:
		return persona

	func run_callbacks() -> void:
		pass

static func run(expect: Callable) -> void:
	var service: Node = SteamServiceScript.new()
	expect.call(str(service.call("profile_label_text")) == "Profile Reaver", "Steam profile label should fall back cleanly without an active Steam user")
	expect.call(str(service.call("steam_cloud_subdirectory_template")) == "Escape the Umbra/steam/{64BitSteamID}", "Steam Cloud setup should use the same account-scoped subdirectory as the runtime")
	var success: Dictionary = service.call("_normalized_init_result", {"status": 0})
	expect.call(bool(success.get("ok", false)), "GodotSteam steamInitEx status 0 should be treated as initialized")
	for failed_status: int in [1, 2, 3]:
		var failed: Dictionary = service.call("_normalized_init_result", {"status": failed_status})
		expect.call(not bool(failed.get("ok", true)), "GodotSteam steamInitEx failure status %d should not initialize Steam" % failed_status)
	var fake_steam := FakeSteam.new()
	service.call("_initialize_with_steam_for_test", fake_steam, {"status": 0})
	expect.call(bool(service.call("is_steam_active")), "A successful logged-in Steam user should make SteamService active")
	expect.call(str(service.call("profile_label_text")) == "Profile Wayfarer", "Steam profile label should use the Steam persona name")
	expect.call(str(service.call("steam_user_dir_name")) == "Escape the Umbra/steam/76561198027391269", "Steam user data should be scoped to the 64-bit Steam ID")
	var failed_service: Node = SteamServiceScript.new()
	failed_service.call("_initialize_with_steam_for_test", fake_steam, {"status": 1})
	expect.call(not bool(failed_service.call("is_steam_active")), "Failed Steam initialization should not make SteamService active")
	failed_service.queue_free()
	service.queue_free()
