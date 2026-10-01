extends "res://tests/aoe_targeting_preview_probe.gd"

# Real-renderer proof for patterned outcrop aim (card pool overhaul wave 2):
# Earthen Rampart's three-tile line highlights its default aim, Rotate turns it
# like an area, and the commit raises the rotated line.
const RAMPART_OUTPUT := "user://probes/earthen_rampart_rotate"
const RAMPART_TARGET := Vector2i(3, 3)

var _metrics: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://earthen_rampart_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://earthen_rampart_probe_run.save")
	SettingsStore.set_storage_path("user://earthen_rampart_probe_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAMPART_OUTPUT))
	await _capture_rampart_states()
	var file := FileAccess.open(ProjectSettings.globalize_path(RAMPART_OUTPUT.path_join("earthen-rampart-proof.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(RAMPART_OUTPUT))
	if _failures.is_empty():
		print("EARTHEN RAMPART ROTATE PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("EARTHEN RAMPART ROTATE PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)

func _capture_rampart_states() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	instance.set("_settings", settings)
	await _install_combat_fixture(instance, "earthen_rampart", 30092)
	await _arm_printed_card(instance)
	var board: Control = instance.get("board_view") as Control
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", RAMPART_TARGET) as Vector2)
	instance.call("_sync_click_targeting_arrow", point)
	instance.call("_on_board_tile_hovered", RAMPART_TARGET)
	await _settle()
	await _capture_case(instance, "01_default_line", [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)])
	instance.call("_on_rotate_action_context_pressed")
	instance.call("_on_board_tile_hovered", RAMPART_TARGET)
	await _settle()
	await _capture_case(instance, "02_rotated_line", [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	await instance.call("_on_board_tile_clicked", RAMPART_TARGET)
	await create_timer(1.5).timeout
	await _settle()
	await _save_screenshot(RAMPART_OUTPUT.path_join("03_committed.png"))
	var raised: Array = []
	for entry: Dictionary in (instance.get("_combat_state") as Dictionary).get("terrain", []):
		if str(entry.get("kind", "")) == "crag_outcrop":
			raised.append(entry.get("pos"))
	_expect(_same_tiles(raised, [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]), "The commit raises the rotated line: %s" % str(raised))
	_metrics["committed"] = {"outcrops": raised}
	instance.queue_free()
	await _settle()
	_capture_viewport.queue_free()

func _capture_case(instance: Node, label: String, expected: Array) -> void:
	var preview: Dictionary = instance.call("_active_card_preview")
	var tiles: Array = instance.call("_focus_tiles_for_preview", preview)
	_expect(_same_tiles(tiles, expected), "%s highlights %s, got %s" % [label, str(expected), str(tiles)])
	_expect(instance.find_child("ActionContextRotate", true, false) != null, label + " must offer Rotate")
	await _save_screenshot(RAMPART_OUTPUT.path_join(label + ".png"))
	_metrics[label] = {"focus_tiles": tiles}
