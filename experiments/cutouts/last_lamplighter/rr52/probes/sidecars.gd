extends SceneTree

const OWNED_ROOTS := ["res://assets/units/last_lamplighter_cutout", "res://experiments/cutouts/last_lamplighter/rr52/probes"]

func _initialize() -> void:
	var count: int = 0
	for directory: String in OWNED_ROOTS:
		for file: String in DirAccess.get_files_at(directory):
			if not file.ends_with(".gd"): continue
			var target: String = directory.path_join(file + ".uid")
			if FileAccess.file_exists(target): continue
			FileAccess.open(target, FileAccess.WRITE).store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
			count += 1
	print("RR52 SIDECARS: PASS (%d new UIDs; owned scripts only)" % count)
	quit()
