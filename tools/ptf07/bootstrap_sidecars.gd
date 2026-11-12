extends SceneTree

# Source metadata only: avoid repeating the repository-wide asset bootstrap
# merely to give these new task-owned scripts stable resource identifiers.
func _initialize() -> void:
	var paths := PackedStringArray([
		"res://scripts/pass_forecast_focus_tooltip.gd",
		"res://scripts/pass_forecast_tooltip_button.gd",
		"res://scripts/pass_forecast_turn_start.gd",
	])
	for name: String in DirAccess.get_files_at("res://tools/ptf07"):
		if name.ends_with(".gd"):
			paths.append("res://tools/ptf07/" + name)
	for path: String in paths:
		var sidecar: String = path + ".uid"
		if FileAccess.file_exists(sidecar): continue
		var file := FileAccess.open(sidecar, FileAccess.WRITE)
		if file == null:
			print("PTF07 SIDECARS: FAIL " + sidecar)
			quit(1)
			return
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	print("PTF07 SIDECARS: PASS")
	quit()
