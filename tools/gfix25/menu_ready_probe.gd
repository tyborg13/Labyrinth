extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
func _initialize() -> void:
	call_deferred("_go")
func _go() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	Store.set_storage_path(dir.path_join("progression.json"))
	Store.set_run_storage_path(dir.path_join("current_run.save"))
	Analytics.set_storage_dir(dir.path_join("analytics"))
	var before := Analytics.load_all_events().size()
	var scene: Node = load("res://scenes/main_menu.tscn").instantiate()
	var t := Time.get_ticks_usec()
	root.add_child(scene)
	print("NOTE main menu _ready ms=", (Time.get_ticks_usec() - t) / 1000.0, " events_before=", before, " events_after=", Analytics.load_all_events().size())
	var t2 := Time.get_ticks_usec()
	var scene2: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(scene2)
	print("NOTE second main menu _ready ms=", (Time.get_ticks_usec() - t2) / 1000.0)
	quit()
