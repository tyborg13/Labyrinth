extends "res://tools/fx15/native_capture.gd"

func _save(image: Image, name: String) -> bool:
	return name != "native-evidence.png" or super._save(image, "sky-strike.png")
