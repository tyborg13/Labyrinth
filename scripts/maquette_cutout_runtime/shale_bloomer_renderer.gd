extends "renderer.gd"

const Rig = preload("shale_bloomer_rig.gd")
const REST_PATH: String = "res://assets/units/shale_bloomer_cutout/front/rest.png"

func _init() -> void:
	character_id = "shale_bloomer"
