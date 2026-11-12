extends SceneTree
func _initialize() -> void:
	for name: String in DirAccess.get_files_at("res://tools/rd07"):
		if not name.ends_with(".gd"): continue
		var path: String = "res://tools/rd07/" + name + ".uid"
		if FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	print("RD07 SIDECARS: PASS")
	quit()
