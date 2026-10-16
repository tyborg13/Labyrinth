extends "renderer.gd"

const Rig = preload("lightning_wisp_rig.gd")
const REST_PATH: String = "res://assets/units/lightning_wisp_cutout/front/rest.png"

func _init() -> void:
	character_id = "lightning_wisp"
