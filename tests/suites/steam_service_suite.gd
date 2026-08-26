extends RefCounted

const SteamServiceScript = preload("res://scripts/steam_service.gd")

class FakeSteam:
	extends Object
	signal user_stats_received(game_id: int, result: int, user_id: int)
	signal user_stats_stored(game_id: int, result: int)

	var logged_on: bool = true
	var app_id: int = 4530510
	var steam_id: String = "76561198027391269"
	var persona: String = "Wayfarer"
	var stats: Dictionary = {}
	var rejected_stats: Array[String] = []
	var store_succeeds: bool = true
	var store_calls: int = 0
	var request_current_stats_succeeds: bool = true
	var auto_complete_stats_request: bool = true
	var request_current_stats_calls: int = 0

	func loggedOn() -> bool:
		return logged_on

	func getSteamID() -> String:
		return steam_id

	func getAppID() -> int:
		return app_id

	func getPersonaName() -> String:
		return persona

	func run_callbacks() -> void:
		pass

	func requestCurrentStats() -> bool:
		request_current_stats_calls += 1
		if request_current_stats_succeeds and auto_complete_stats_request:
			user_stats_received.emit(app_id, 1, steam_id.to_int())
		return request_current_stats_succeeds

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
	expect.call(fake_steam.request_current_stats_calls == 1, "SteamService should request the current user's stats before applying telemetry deltas")
	expect.call(bool((service.call("stats_readiness_status") as Dictionary).get("ready", false)), "SteamService should wait for the successful current-stats callback")
	expect.call(str(service.call("profile_label_text")) == "Profile Wayfarer", "Steam profile label should use the Steam persona name")
	expect.call(str(service.call("steam_user_dir_name")) == "Escape the Umbra/steam/76561198027391269", "Steam user data should be scoped to the 64-bit Steam ID")
	var queued: Dictionary = service.call("accumulate_int_stats", {
		"perf_v1_linux_steamdeck_frame_samples": 120,
		"perf_v1_linux_steamdeck_frames_over_33_33_ms": 7,
		"perf_v1_linux_steamdeck_sessions": 1,
	})
	expect.call((queued.get("accepted", []) as Array).size() == 3, "SteamService should accept valid additive integer telemetry stats")
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
	# InvalidParam can refresh Steam's volatile cache with server values before the
	# callback. The service must restore every desired target, including sessions.
	fake_steam.stats["perf_v1_linux_steamdeck_frame_samples"] = 0
	fake_steam.stats["perf_v1_linux_steamdeck_frames_over_33_33_ms"] = 0
	fake_steam.stats["perf_v1_linux_steamdeck_sessions"] = 0
	fake_steam.rejected_stats.append("perf_v1_linux_steamdeck_sessions")
	fake_steam.user_stats_stored.emit(fake_steam.app_id + 1, 2)
	expect.call(
		bool((service.call("stats_readiness_status") as Dictionary).get("store_in_flight", false)),
		"A StoreStats callback for another app must not confirm or reject this app's pending generation"
	)
	fake_steam.user_stats_stored.emit(fake_steam.app_id, 2)
	expect.call(str((service.call("last_stats_status") as Dictionary).get("reason", "")) == "store_callback_rejected", "SteamService should retain rejected asynchronous storage for retry")
	expect.call(int(fake_steam.stats.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 150, "A rejected callback should reapply the desired frame-sample target after Steam overwrites its cache")
	expect.call(int(fake_steam.stats.get("perf_v1_linux_steamdeck_sessions", 0)) == 0, "The fake should exercise a per-key SetStat reapply rejection")
	expect.call(int((service.call("pending_stat_targets_for_test") as Dictionary).get("perf_v1_linux_steamdeck_sessions", 0)) == 1, "A failed session-key reapply should remain in the desired-target queue")
	service.call("store_pending_stats")
	service.call("accumulate_int_stats", {"perf_v1_linux_steamdeck_frame_samples": 25})
	var overlapping_store: Dictionary = service.call("store_pending_stats")
	expect.call(str(overlapping_store.get("reason", "")) == "store_in_flight", "SteamService should not overlap asynchronous StoreStats batches")
	fake_steam.user_stats_stored.emit(fake_steam.app_id, 1)
	expect.call(str((service.call("last_stats_status") as Dictionary).get("reason", "")) == "stored_with_newer_pending_stats", "A successful callback should retain values queued while its StoreStats batch was in flight")
	expect.call(int(fake_steam.stats.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 175, "A newer in-flight frame-sample target should remain applied after the older batch succeeds")
	expect.call(int((service.call("pending_stat_targets_for_test") as Dictionary).get("perf_v1_linux_steamdeck_sessions", 0)) == 1, "A successful StoreStats callback must not clear a key whose SetStat reapply failed")
	fake_steam.rejected_stats.erase("perf_v1_linux_steamdeck_sessions")
	service.call("store_pending_stats")
	fake_steam.user_stats_stored.emit(fake_steam.app_id, 1)
	expect.call(str((service.call("last_stats_status") as Dictionary).get("reason", "")) == "stored" and fake_steam.store_calls == 4, "SteamService should clear queued stats only after Steam confirms the latest targets")
	expect.call((service.call("pending_stat_targets_for_test") as Dictionary).is_empty(), "No desired Steam stat targets should remain after the latest batch is confirmed")
	var delayed_steam := FakeSteam.new()
	delayed_steam.auto_complete_stats_request = false
	var delayed_service: Node = SteamServiceScript.new()
	delayed_service.call("_initialize_with_steam_for_test", delayed_steam, {"status": 0})
	var delayed_result: Dictionary = delayed_service.call("accumulate_int_stats", {
		"perf_v1_linux_steamdeck_sessions": 1,
		"perf_v1_linux_steamdeck_frame_samples": 60,
	})
	expect.call(str(delayed_result.get("reason", "")) == "stats_not_ready", "Telemetry should report the current-stats gate instead of writing before Steam is ready")
	expect.call((delayed_result.get("queued", []) as Array).size() == 2, "Telemetry deltas should remain queued while RequestCurrentStats is in flight")
	expect.call(delayed_steam.stats.is_empty(), "No SetStat call should run before UserStatsReceived succeeds")
	delayed_service.call("_process", 15.1)
	expect.call(str((delayed_service.call("last_stats_status") as Dictionary).get("reason", "")) == "stats_request_timeout", "A missing UserStatsReceived callback should become a visible timeout instead of wedging telemetry forever")
	delayed_service.call("_process", 5.1)
	expect.call(delayed_steam.request_current_stats_calls == 2, "SteamService should retry RequestCurrentStats after a callback timeout")
	delayed_steam.user_stats_received.emit(delayed_steam.app_id + 1, 1, delayed_steam.steam_id.to_int())
	expect.call(not bool((delayed_service.call("stats_readiness_status") as Dictionary).get("ready", false)), "A UserStatsReceived callback for another app must not release queued telemetry")
	delayed_steam.user_stats_received.emit(delayed_steam.app_id, 1, delayed_steam.steam_id.to_int() + 1)
	expect.call(not bool((delayed_service.call("stats_readiness_status") as Dictionary).get("ready", false)), "A UserStatsReceived callback for another Steam user must not release queued telemetry")
	delayed_steam.user_stats_received.emit(delayed_steam.app_id, 1, delayed_steam.steam_id.to_int())
	expect.call(int(delayed_steam.stats.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 60, "The readiness callback should release queued frame samples into Steam's local cache")
	expect.call(int(delayed_steam.stats.get("perf_v1_linux_steamdeck_sessions", 0)) == 1, "The readiness callback should release the once-per-session counter exactly once")
	expect.call(bool((delayed_service.call("stats_readiness_status") as Dictionary).get("ready", false)), "The successful UserStatsReceived callback should make stats writable")
	delayed_service.queue_free()
	var durable_path := "user://steam_stats_pending_suite_%d.json" % Time.get_ticks_usec()
	var durable_steam := FakeSteam.new()
	durable_steam.auto_complete_stats_request = false
	var durable_service: Node = SteamServiceScript.new()
	durable_service.call("_set_stats_queue_path_for_test", durable_path)
	durable_service.call("_initialize_with_steam_for_test", durable_steam, {"status": 0})
	durable_service.call("accumulate_int_stats", {
		"perf_v1_linux_steamdeck_sessions": 1,
		"perf_v1_linux_steamdeck_frame_samples": 42,
	})
	expect.call(FileAccess.file_exists(durable_path), "Stats queued before readiness should be persisted immediately for a later client session")
	var restored_steam := FakeSteam.new()
	var restored_service: Node = SteamServiceScript.new()
	restored_service.call("_set_stats_queue_path_for_test", durable_path)
	restored_service.call("_initialize_with_steam_for_test", restored_steam, {"status": 0})
	expect.call(int(restored_steam.stats.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 42, "A later Steam session should restore and release durable queued frame samples")
	expect.call(int(restored_steam.stats.get("perf_v1_linux_steamdeck_sessions", 0)) == 1, "A later Steam session should restore the queued session counter exactly once")
	expect.call(not FileAccess.file_exists(durable_path), "The durable readiness queue should clear after Steam accepts every restored delta")
	durable_service.queue_free()
	restored_service.queue_free()
	var failed_service: Node = SteamServiceScript.new()
	failed_service.call("_initialize_with_steam_for_test", fake_steam, {"status": 1})
	expect.call(not bool(failed_service.call("is_steam_active")), "Failed Steam initialization should not make SteamService active")
	failed_service.queue_free()
	service.queue_free()
