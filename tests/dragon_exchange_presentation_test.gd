extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_path("user://exchange_test_profile.json")
	Store.set_run_storage_path("user://exchange_test_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://exchange_test_events")
	_run.call_deferred()
func _run() -> void:
	var profile_path: String = Store._storage_path
	var run_path: String = Store._run_storage_path
	var settings_path: String = preload("res://scripts/settings_store.gd").storage_path()
	var analytics_path: String = preload("res://scripts/analytics_store.gd").storage_dir()
	await preload("res://tests/suites/dragon_exchange_presentation_suite.gd").run_live(self,_expect)
	_expect(Store._storage_path==profile_path and Store._run_storage_path==run_path,"Live adapter restores profile/run paths")
	_expect(preload("res://scripts/settings_store.gd").storage_path()==settings_path and preload("res://scripts/analytics_store.gd").storage_dir()==analytics_path,"Live adapter restores settings/analytics paths")
	print("TEST RESULT: ","PASS" if failures.is_empty() else "FAIL"," Dragon exchange presentation ",failures)
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
