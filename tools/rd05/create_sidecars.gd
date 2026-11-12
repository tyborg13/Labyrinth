extends SceneTree

func _initialize() -> void:
	var paths: PackedStringArray = ["res://scripts/board_plate_visibility.gd", "res://scripts/board_plate_aim.gd", "res://scripts/turn_order_health_numeral.gd"]
	for name: String in DirAccess.get_files_at("res://tools/rd05"):
		if name.ends_with(".gd"): paths.append("res://tools/rd05/" + name)
	for path: String in paths:
		if FileAccess.file_exists(path + ".uid"): continue
		var file := FileAccess.open(path + ".uid", FileAccess.WRITE)
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
		file.close()
	print("RD05 SIDECARS: PASS")
	quit()
