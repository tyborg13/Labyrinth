extends "res://tools/ux19/probe.gd"

const SceneLoads = preload("res://scripts/menu_run_preload.gd")

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_output = _arg("--output-dir", "")
	_check(_output.is_absolute_path() and DirAccess.make_dir_recursive_absolute(_output) == OK, "Controls output is writable")
	_check(CelLook.mode == "all" and not CelLook._files.is_empty(), "Approved cel look is active")
	Settings.set_storage_path("user://mrg14_settings.json")
	_save_defaults()
	_router = root.get_node("InputRouter")
	_open_viewport(DESKTOP)
	_router.set_forced_state_for_test("pointer", "xbox")
	var panel: Control = await _open_settings()
	_check_settings_size(panel)
	_check(_cap_text(panel, Keys.PASS) == "P" and _cap_text(panel, Keys.MAP) == "M", "Controls shows the shipped keycaps")
	await _capture("settings-controls")
	await _close_viewport()
	while not SceneLoads.drain_for_shutdown(self):
		await process_frame
	_router.clear_forced_state_for_test()
	print("MRG-14 CONTROLS STILL: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
