extends SceneTree
## Own-resource UID creation only; this is not a parser/editor scan.
func _initialize() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://tools/atk13/area01")
	for name: String in files:
		if name.ends_with(".gd"): write_uid("res://tools/atk13/area01/"+name)
	write_uid("res://scripts/boss_area_rules.gd")
	write_uid("res://scripts/boss_area_marks.gd")
	write_uid("res://tests/suites/boss_area_rules_suite.gd")
	print("AREA01 SIDECARS PASS")
	quit(0)
func write_uid(path: String) -> void:
	if FileAccess.file_exists(path+".uid"): return
	var file := FileAccess.open(path+".uid",FileAccess.WRITE)
	assert(file != null)
	file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
