extends SceneTree
## Run under the pinned historical project so its own save writer emits the fixture.

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const SEED := 83

func _initialize() -> void:
	_write.call_deferred()

func _write() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	Store.set_run_storage_path(path)
	var state: Dictionary = Run.new().create_new_run(SEED, Store.default_data())
	# Exercise the supported legacy representation with the original serializer.
	state["seed"] = float(SEED)
	if not Store.save_run_state(state):
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Dictionary = file.get_var(false)
	file.close()
	if not raw.get("seed") is float:
		quit(1)
		return
	print("PERF146 LEGACY_WRITTEN seed=", raw["seed"], " sha256=", FileAccess.get_sha256(path))
	quit()
