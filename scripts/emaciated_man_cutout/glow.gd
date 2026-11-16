extends RefCounted
const SHADER = preload("res://shaders/emaciated_ember_overlay.gdshader")
var overlays: Dictionary = {}
var materials: Dictionary = {}
var enabled: bool = true

func setup(rig: Node2D) -> void:
	for definition: Dictionary in rig.layout.get("glow_overlays", []):
		var target: Sprite2D = rig.find_child(str(definition["part"]), true, false) as Sprite2D
		if target == null: continue
		var overlay := Sprite2D.new()
		overlay.name = "EmberOverlay_" + str(definition["part"])
		overlay.texture = target.texture
		overlay.centered = target.centered
		overlay.position = target.position
		overlay.z_as_relative = target.z_as_relative
		overlay.z_index = target.z_index
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		for part: Dictionary in rig.layout["parts"]:
			if str(part["name"]) == str(definition["part"]):
				shader_material.set_shader_parameter("source_paint", preload("res://scripts/asset_loader.gd").load_original_texture(rig.call("_resolve", str(part["file"])), true))
		var saturation: Variant = rig.layout.get("glow_min_saturation", "TODO_DESIGN_glow_min_saturation")
		# Unresolved design data disables selection, preserving the approved paint.
		if saturation is float or saturation is int:
			shader_material.set_shader_parameter("min_saturation", float(saturation))
		overlay.material = shader_material
		target.get_parent().add_child(overlay)
		overlay.owner = rig
		overlays[definition["channel"]] = overlay
		materials[definition["channel"]] = shader_material

func present(alpha: Dictionary) -> void:
	for channel: String in materials:
		(materials[channel] as ShaderMaterial).set_shader_parameter("pulse_alpha", float(alpha.get(channel, 0.0)) if enabled else 0.0)
