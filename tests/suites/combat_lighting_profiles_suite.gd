extends RefCounted

const Profiles = preload("res://scripts/combat_lighting_profiles.gd")
const Treatment = preload("res://scripts/combat_art_treatment.gd")

static func run(check: Callable) -> void:
	var previous_override: String = OS.get_environment("LABYRINTH_ART_LOOK")
	OS.set_environment("LABYRINTH_ART_LOOK", "")
	var normal := Treatment.new()
	check.call(Profiles.DEFAULT_ID == "warm" and normal.preset == "warm", "Every new combat must default to Warm without an override")
	for element: String in ["", "ice", "fire", "lightning", "earth"]:
		normal.configure([], element, true)
		check.call(normal.preset == "warm", "Replacing room lighting must retain Warm for every element")
		check.call(is_equal_approx(float(normal.material.get_shader_parameter("art_ambient_level")), 0.88), "Warm values must reach the live material")
	var ids: Array[String] = Profiles.ids()
	for required: String in ["gentle", "warm", "balanced", "moody", "dramatic"]:
		check.call(ids.has(required), "Preserve the approved lighting profile: " + required)
	for id: String in ids:
		check.call(normal.set_preset(id), "Stored profiles remain selectable: " + id)
		var look: Dictionary = Profiles.definition(id)
		for field: String in ["ambient", "gain", "local_budget", "reach", "contrast", "saturation", "rim"]:
			check.call(look.has(field) and is_finite(float(look.get(field, NAN))), "Profile has a finite " + field)
			for target: ShaderMaterial in [normal.material, normal.floor_material, normal.cache_bake_material]:
				check.call(is_equal_approx(float(target.get_shader_parameter("art_" + field + "_level")), float(look.get(field, NAN))), "World, cache and floor use the same " + id + " values")
		check.call(float(look.get("local_budget", 0.0)) > 0.0, "Local energy budget must be positive")
		check.call(look.get("tint") is Vector3, "Profile tint is a Vector3")
		OS.set_environment("LABYRINTH_ART_LOOK", id)
		var preview := Treatment.new()
		check.call(preview.preset == id, "Explicit development override remains available: " + id)
	var selected: String = normal.preset
	check.call(not normal.set_preset("missing") and normal.preset == selected, "Invalid profile must not disturb the active material")
	OS.set_environment("LABYRINTH_ART_LOOK", "missing")
	var fallback := Treatment.new()
	check.call(fallback.preset == "warm", "An invalid launch override falls back to Warm")
	var copy: Dictionary = Profiles.definition("warm")
	copy["ambient"] = 0.0
	check.call(Profiles.definition("warm")["ambient"] == 0.88, "Editing tool metadata must not mutate the registry")
	OS.set_environment("LABYRINTH_ART_LOOK", previous_override)
