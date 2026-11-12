extends SceneTree

func _initialize() -> void:
	_walk("res://tools/rd08")
	_write("res://scripts/board_rail_highlight.gd")
	_write("res://scripts/board_snare_countdown.gd")
	print("RD08 SIDECARS: PASS")
	quit()

func _walk(folder: String) -> void:
	for filename: String in DirAccess.get_files_at(folder):
		if filename.ends_with(".gd"): _write(folder.path_join(filename))
	for child: String in DirAccess.get_directories_at(folder): _walk(folder.path_join(child))

func _write(source: String) -> void:
	if FileAccess.file_exists(source + ".uid"): return
	var file := FileAccess.open(source + ".uid", FileAccess.WRITE)
	assert(file != null)
	file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
