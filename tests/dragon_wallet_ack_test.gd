extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const PROFILE_PATH: String = "user://dragon_wallet_ack_profile.json"
const RUN_PATH: String = "user://dragon_wallet_ack_run.save"

class WalletScene:
	extends "res://scripts/run_scene.gd"
	var fail_next_ack: bool = false
	var blocked_ack_observed: bool = false
	func _reconcile_progression_analytics_outbox() -> bool:
		if not fail_next_ack:
			return super._reconcile_progression_analytics_outbox()
		fail_next_ack = false
		# The purchase's profile-first commit has already succeeded. Block only
		# the acknowledgment write after the real JSONL append.
		var blocked_path: String = ProjectSettings.globalize_path("user://dragon_wallet_ack_profile.json.tmp")
		assert(DirAccess.make_dir_absolute(blocked_path) == OK)
		var result: bool = super._reconcile_progression_analytics_outbox()
		blocked_ack_observed = not result
		assert(DirAccess.remove_absolute(blocked_path) == OK)
		return result

var failed: int = 0
var checks: int = 0
var scene: WalletScene

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(RUN_PATH)
	Analytics.set_storage_dir("user://dragon_wallet_ack_events")
	Analytics.clear_storage()
	Settings.set_storage_path("user://dragon_wallet_ack_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	instance.set_script(WalletScene)
	scene = instance as WalletScene
	root.add_child(scene)
	await process_frame
	var serial: int = 0
	for source: String in ["emaciated_man", "campfire"]:
		for kind: String in ["moltshard_exchange", "level_up"]:
			if source == "campfire" and kind == "moltshard_exchange":
				continue
			for fail_ack: bool in [false, true]:
				serial += 1
				await _check_wallet(kind, source, fail_ack, serial)
	scene.queue_free()
	await process_frame
	print("DRAGON WALLET ACK TEST: %s (%d checks)" % ["PASS" if failed == 0 else "FAIL", checks])
	quit(1 if failed else 0)

func _check_wallet(kind: String, source: String, fail_ack: bool, serial: int) -> void:
	var profile: Dictionary = Store.default_data()
	profile["embers"] = 1000
	profile["moltshards"] = 2
	profile["run_counter"] = 100 + serial
	profile[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION, "status":"dismissed", "completed_steps":[]}
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(94100 + serial, profile)
	if source == "campfire":
		run["mode"] = "campfire"
	expect(Store.save_data(profile) and Store.save_run_state(run), "Wallet fixture saves before invoking the real handler")
	scene.set("_progression", profile)
	scene.call("_load_run_state", run)
	scene.call("_close_card_upgrade_overlay")
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await process_frame
	scene.fail_next_ack = fail_ack
	scene.blocked_ack_observed = false
	if kind == "moltshard_exchange":
		scene.call("_exchange_moltshard_at_entrance")
	else:
		scene.call("_open_level_up_overlay", source)
	await process_frame
	var key: String = "%s:wallet:1" % Run.run_result_id(run)
	var expected_embers: int = 1250 if kind == "moltshard_exchange" else 820
	var expected_level: int = 1 if kind == "moltshard_exchange" else 2
	var expected_shards: int = 1 if kind == "moltshard_exchange" else 2
	var label: String = "%s/%s/fail_ack=%s" % [source, kind, str(fail_ack)]
	expect(scene.blocked_ack_observed == fail_ack, "%s exercises the requested acknowledgment outcome" % label)
	expect(_event_count(key) == 1, "%s appends exactly one keyed wallet event" % label)
	_check_values(expected_embers, expected_level, expected_shards, label)
	# Keep the real refresh that originally copied the stale run outbox back
	# over acknowledged active progression, then exercise a normal later save.
	scene.call("_refresh_ui")
	expect(bool(scene.call("_persist_committed_boundary", "wallet_test_after_refresh")), "%s saves after refresh" % label)
	_check_outboxes(1 if fail_ack else 0, label)
	var saved: Dictionary = Store.load_saved_run()
	scene.call("_load_run_state", saved)
	scene.call("_close_dialogue")
	expect(bool(scene.call("_persist_committed_boundary", "wallet_test_after_reload")), "%s saves after reload/retry" % label)
	_check_outboxes(0, "%s after reload" % label)
	_check_values(expected_embers, expected_level, expected_shards, label)
	expect(_event_count(key) == 1, "%s replay neither repeats spending nor duplicates analytics" % label)
	await process_frame

func _check_outboxes(expected: int, label: String) -> void:
	var active: Dictionary = scene.get("_progression")
	var run: Dictionary = scene.get("_run_state")
	var saved: Dictionary = Store.load_saved_run()
	expect(Store.progression_analytics_outbox(active).size() == expected, "%s active outbox" % label)
	expect(Store.progression_analytics_outbox(run.get("progression", {})).size() == expected, "%s run outbox" % label)
	expect(Store.progression_analytics_outbox(Store.load_data()).size() == expected, "%s profile outbox" % label)
	expect(Store.progression_analytics_outbox(saved.get("progression", {})).size() == expected, "%s saved-run outbox" % label)

func _check_values(embers: int, level: int, shards: int, label: String) -> void:
	var run: Dictionary = scene.get("_run_state")
	var progression: Dictionary = scene.get("_progression")
	expect(Run.new().held_embers(run) == embers and int(progression.get("level", 0)) == level and Store.moltshard_count(progression) == shards, "%s preserves the exact purchase result" % label)
	expect(int(run.get("wallet_transaction_sequence", 0)) == 1, "%s keeps one wallet transaction" % label)

func _event_count(key: String) -> int:
	var count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("idempotency_key", "")) == key:
			count += 1
	return count

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
