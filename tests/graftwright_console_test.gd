extends SceneTree

const Harness = preload("res://tools/headless_playtest.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
var failed: bool = false

func _initialize() -> void:
	Analytics.set_storage_dir("user://graftwright_console_analytics")
	Analytics.clear_storage()
	var harness = Harness.new()
	harness.set("_run_state", Suite.fixture())
	harness.set("_session_path", "user://graftwright_console.save")
	harness.set("_analytics_store", Analytics.new())
	harness.call("_handle_command", "graft undertaker_plate patched_cloak 1 1")
	var state: Dictionary = harness.get("_run_state") as Dictionary
	check(Data.equipment_cards("undertaker_plate", state) == ["undertaker_stand", "shadow_step"], "Console uses the production graft transaction")
	var file := FileAccess.open("user://graftwright_console.save", FileAccess.READ)
	var saved: Dictionary = file.get_var(false) as Dictionary
	file.close()
	check(saved["run_state"]["equipment_grafts"] == state["equipment_grafts"], "Console persists the inherited equipment")
	harness.call("_handle_command", "graft undertaker_plate boiled_leather 0 1")
	check((harness.get("_run_state") as Dictionary)["equipment_inventory"] == state["equipment_inventory"], "Repeated console request consumes nothing")
	harness.call("_handle_command", "leave")
	check((harness.get("_run_state") as Dictionary)["mode"] == "room", "Console can leave the completed encounter")
	harness.call("_save_session")
	var graft_events: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) == "equipment_grafted": graft_events += 1
	check(graft_events == 1, "Replay writes one local graft event")
	harness.free()
	print("GRAFTWRIGHT CONSOLE TEST: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
