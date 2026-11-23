extends Node2D

const INK = preload("res://shaders/ground_contact_shadow.gdshader")

var meshes: Array[ArrayMesh]

func _ready() -> void:
	var shader := ShaderMaterial.new()
	shader.shader = INK
	material = shader
	show_behind_parent = true

func _draw() -> void:
	meshes.clear()
	get_parent().call("_draw_pixel_ground_shadow", self)
