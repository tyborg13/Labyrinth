extends RefCounted

const SteamServiceScript = preload("res://scripts/steam_service.gd")

class FakeSteam:
	extends Object
	signal user_stats_stored(game_id: int, result: int)

	var logged_on: bool = true
	var steam_id: String = "76561198027391269"
	var persona: String = "Wayfarer"
	var stats: Dictionary = {}
	var rejected_stats: Array[String] = []
	var store_succeeds: bool = true
	var store_calls: int = 0

	func loggedOn() -> bool:
		return logged_on

	func getSteamID() -> String:
		return steam_id

	func getPersonaName() -> String:
		return persona

	func run_callbacks() -> void:
		pass

	func getStatInt(stat_name: String) -> int:
		return int(stats.get(stat_name, 0))

	func setStatInt(stat_name: String, value: int) -> bool:
		if stat_name in rejected_stats:
			return false
		stats[stat_name] = value
		return true

	func storeStats() -> bool:
		store_calls += 1
		return store_succeeds

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
	var queued: Dictionary = service.call("accumulate_int_stats", {
		"perf_v1_linux_steamdeck_frame_samples": 120,
		"perf_v1_linux_steamdeck_frames_over_33_33_ms": 7,
	})
	expect.call((queued.get("accepted", []) as Array).size() == 2, "SteamService should accept valid additive integer telemetry stats")
	service.call("accumulate_int_stats", {"perf_v1_linux_steamdeck_frame_samples": 30})
	expect.call(int(fake_steam.stats.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 150, "SteamService should add telemetry deltas to the user's current absolute Steam stat")
	fake_steam.rejected_stats.append("perf_v1_linux_steamdeck_rejected")
	var partial: Dictionary = service.call("accumulate_int_stats", {
		"perf_v1_linux_steamdeck_rejected": 1,
		"Invalid Stat Name": 1,
	})
	expect.call(str((partial.get("failed", {}) as Dictionary).get("perf_v1_linux_steamdeck_rejected", "")) == "set_rejected", "Rejected App Admin stat keys should fail without blocking other telemetry")
	expect.call(str((partial.get("failed", {}) as Dictionary).get("Invalid Stat Name", "")) == "invalid_name", "SteamService should reject unsafe dynamic stat names")
	fake_steam.store_succeeds = false
	var failed_store: Dictionary = service.call("store_pending_stats")
	expect.call(not bool(failed_store.get("ok", true)), "A failed StoreStats call should retain pending Steam telemetry for retry")
	fake_steam.store_succeeds = true
	var stored: Dictionary = service.call("store_pending_stats")
	expect.call(bool(stored.get("ok", false)) and str(stored.get("reason", "")) == "submitted", "SteamService should wait for Steam's asynchronous storage callback")
	fake_steam.user_stats_stored.emit(4531660, 2)
	expect.call(str((service.call("last_stats_status") as Dictionary).get("reason", "")) == "store_callback_rejected", "SteamService should retain rejected asynchronous storage for retry")
	service.call("store_pending_stats")
	fake_steam.user_stats_stored.emit(4531660, 1)
	expect.call(str((service.call("last_stats_status") as Dictionary).get("reason", "")) == "stored" and fake_steam.store_calls == 3, "SteamService should clear queued stats only after Steam confirms storage")
	var failed_service: Node = SteamServiceScript.new()
	failed_service.call("_initialize_with_steam_for_test", fake_steam, {"status": 1})
	expect.call(not bool(failed_service.call("is_steam_active")), "Failed Steam initialization should not make SteamService active")
	failed_service.queue_free()
	service.queue_free()
