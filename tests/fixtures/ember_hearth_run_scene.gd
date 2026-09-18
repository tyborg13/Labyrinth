extends "res://scripts/run_scene.gd"
## Exercise production outcomes without leaving the probe/test SceneTree.
var requested_scene: String = ""
var heard_cues: Array[String]

func _change_scene_to_file(path: String) -> void:
	requested_scene = path

func _play_sfx(entry: Dictionary) -> float:
	heard_cues.append(str(entry.get("id", "")))
	return super._play_sfx(entry)
