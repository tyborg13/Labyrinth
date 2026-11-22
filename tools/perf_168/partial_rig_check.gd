extends SceneTree

const Paint = preload("res://scripts/maquette_cutout_runtime/stable_paint.gd")

class PartialRig extends Node2D:
	var layout: Dictionary = {"stable_source_raster": true, "parts": [
		{"name": "Foot", "bone": "foot_near"},
		{"name": "Body", "bone": "torso"},
	]}
	var bones: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rig := PartialRig.new()
	root.add_child(rig)
	rig.position = Vector2(13, 27)
	var torso := Bone2D.new()
	torso.set_autocalculate_length_and_angle(false)
	rig.add_child(torso)
	rig.bones["torso"] = torso
	var sprite := Sprite2D.new()
	sprite.name = "Body"
	torso.add_child(sprite)
	var paint := Polygon2D.new()
	paint.name = "ExactSourcePaint"
	sprite.add_child(paint)
	paint.set_as_top_level(true)
	Paint.follow_root(rig)
	var follows: bool = paint.global_transform == rig.global_transform
	rig.free()
	if follows:
		print("TEST RESULT: PASS — mounted paint follows the root during partial rig construction")
		quit()
	else:
		print("TEST RESULT: FAIL — mounted paint missed the partial-rig transform")
		quit(1)
