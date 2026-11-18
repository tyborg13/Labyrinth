extends SceneTree
const PROOF_FIRST_SEED: int = 1
const PROOF_SEED_COUNT: int = 9
func _initialize() -> void:
	var source: String = OS.get_cmdline_user_args()[0]
	var paths: Array[String]
	if DirAccess.dir_exists_absolute(source):
		for seed_value: int in range(PROOF_FIRST_SEED,PROOF_FIRST_SEED+PROOF_SEED_COUNT): paths.append(source.path_join("ladder-%d.bin" % seed_value))
	else: paths.append(source)
	var counts: Dictionary = {}
	for path: String in paths:
		var file := FileAccess.open(path,FileAccess.READ)
		assert(file != null)
		var payload: Dictionary = file.get_var()
		file.close()
		for entry: Dictionary in payload["entries"]:
			var id: String = str(entry["layout"].get("guardian_id",entry["layout"].get("boss_id","")))
			counts[id] = int(counts.get(id,0))+1
	print("AREA01 NATURAL LADDER INPUT COUNTS ",JSON.stringify(counts))
	quit(0)
