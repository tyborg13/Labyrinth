extends SceneTree

func _initialize() -> void:
	var paths: Array[String]
	for name: String in DirAccess.get_files_at("res://tools/rd02"):
		if name.ends_with(".gd"): paths.append("res://tools/rd02/" + name)
	for name: String in ["board_unit_team_outlines.gd", "board_occlusion_alpha.gd", "board_occlusion_silhouettes.gd", "board_occlusion_sources.gd", "board_occlusion_silhouettes.gdshader"]:
		paths.append("res://scripts/" + name)
	for path: String in paths:
		if FileAccess.file_exists(path + ".uid"): continue
		var file := FileAccess.open(path + ".uid", FileAccess.WRITE)
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
		file.close()
	print("RD02 SIDECARS: ", paths.size(), " owned sources checked")
	quit()
