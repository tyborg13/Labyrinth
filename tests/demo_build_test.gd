extends "res://tests/run_tests.gd"

const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoSteamService = preload("res://scripts/steam_service.gd")
const DEMO_ENV: String = "LABYRINTH_DEMO"
const QUEUE_FIXTURE_PATH: String = "user://demo_build_stats_pending_test.json"
const STAT_FIXTURE_NAME: String = "perf_v1_linux_steamdeck_sessions"
const STEAM_ID_FIXTURE: String = "76561198027391269"

func _initialize() -> void:
	_initialize_test_storage()
	var had_flag: bool = OS.has_environment(DEMO_ENV)
	var previous_flag: String = OS.get_environment(DEMO_ENV)
	OS.unset_environment(DEMO_ENV)
	_assert(not DemoBuild.is_demo(), "Unflagged editor run is the full game")
	_assert(DemoSteamService.steam_user_dir_prefix() == "Escape the Umbra/steam", "Full-game prefix is unchanged")
	var full_service := DemoSteamService.new()
	full_service._steam_id = STEAM_ID_FIXTURE
	_assert(full_service.steam_user_dir_name() == "Escape the Umbra/steam/76561198027391269", "Full-game account folder is unchanged")
	_assert(full_service.steam_cloud_subdirectory_template() == "Escape the Umbra/steam/{64BitSteamID}", "Full-game cloud template is unchanged")
	full_service.free()
	# The existing suite covers full-game readiness queues and real submission
	# semantics through its fake API; none of its assertions are replaced here.
	SteamServiceSuite.run(Callable(self, "_assert"))
	OS.set_environment(DEMO_ENV, "true")
	_assert(not DemoBuild.is_demo(), "The editor hook requires exactly 1")
	OS.set_environment(DEMO_ENV, "1")
	_assert(DemoBuild.is_demo(), "The editor environment hook enables demo mode")
	_assert(DemoSteamService.steam_user_dir_prefix() == "Escape the Umbra Demo/steam", "Demo prefix is separate")
	var fake := SteamServiceSuite.FakeSteam.new()
	fake.auto_complete_stats_request = false
	var service := DemoSteamService.new()
	service._set_stats_queue_path_for_test(QUEUE_FIXTURE_PATH)
	service._initialize_with_steam_for_test(fake, {"status": 0})
	_assert(service.steam_user_dir_name() == "Escape the Umbra Demo/steam/76561198027391269", "Demo account folder uses the demo prefix")
	_assert(not service.steam_user_dir_name().begins_with("Escape the Umbra/"), "Demo account folder never uses the full-game prefix")
	_assert(service.steam_cloud_subdirectory_template() == "Escape the Umbra Demo/steam/{64BitSteamID}", "Demo Cloud template matches its runtime folder")
	var namespaced_user_dir: String = ProjectSettings.globalize_path("user://")
	service._apply_steam_user_directory()
	_assert(ProjectSettings.globalize_path("user://") == namespaced_user_dir, "Demo Steam switch preserves the runner namespace")
	var expected_status: Dictionary = {"accepted": [], "failed": {}, "reason": "demo_build"}
	_assert(service.accumulate_int_stats({STAT_FIXTURE_NAME: 1}) == expected_status, "Demo deltas are rejected before the readiness queue")
	_assert(service.last_stats_status() == expected_status, "Demo accumulate status is observable")
	_assert(service._queued_stat_deltas.is_empty(), "Demo deltas never enter the queue")
	_assert(not FileAccess.file_exists(QUEUE_FIXTURE_PATH), "Demo deltas never create a queue file")
	fake.user_stats_received.emit(fake.app_id, 1, fake.steam_id.to_int())
	_assert(service.accumulate_int_stats({STAT_FIXTURE_NAME: 1}) == expected_status, "Ready demo stats are also disabled")
	service._stats_dirty = true
	_assert(service.store_pending_stats() == expected_status, "Demo stats never submit even with dirty state")
	_assert(service.last_stats_status() == expected_status, "Demo store status is observable")
	_assert(fake.stats.is_empty() and fake.store_calls == 0, "Demo calls never reach SetStat or StoreStats")
	# Simulate a legacy in-memory queue at shutdown to cover the persistence hook.
	service._queued_stat_deltas = {STAT_FIXTURE_NAME: 1}
	service._exit_tree()
	_assert(not FileAccess.file_exists(QUEUE_FIXTURE_PATH), "Demo shutdown never writes queued deltas")
	_assert(service.last_stats_status() == expected_status, "Demo shutdown reports the disabled stats status")
	service.free()
	fake.free()
	if had_flag:
		OS.set_environment(DEMO_ENV, previous_flag)
	else:
		OS.unset_environment(DEMO_ENV)
	for failure: String in _failures:
		push_error(failure)
	print("DEMO BUILD TEST RESULT: %s (%d assertions)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count])
	quit(0 if _failures.is_empty() else 1)
