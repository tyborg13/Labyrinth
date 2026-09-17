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
		check.call(is_equal_approx(float(normal.material.get_shader_parameter("art_ambient_level")), 0.77), "Warm values must reach the live material")
	var ids: Array[String] = Profiles.ids()
	for required: String in ["gentle", "warm", "balanced", "moody", "dramatic"]:
		check.call(ids.has(required), "Preserve the approved lighting profile: " + required)
	for id: String in ids:
		check.call(normal.set_preset(id), "Stored profiles remain selectable: " + id)
		var look: Dictionary = Profiles.definition(id)
		for field: String in Profiles.SCALAR_FIELDS:
			check.call(look.has(field) and is_finite(float(look.get(field, NAN))), "Profile has a finite " + field)
			for target: ShaderMaterial in [normal.material, normal.floor_material, normal.cache_bake_material]:
				check.call(is_equal_approx(float(target.get_shader_parameter("art_" + field + "_level")), float(look.get(field, NAN))), "World, cache and floor use the same " + id + " values")
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
	check.call(Profiles.definition("warm")["ambient"] == 0.77, "Editing tool metadata must not mutate the registry")
	_verify_density_anchors(check)
	OS.set_environment("LABYRINTH_ART_LOOK", previous_override)

static func _verify_density_anchors(check: Callable) -> void:
	OS.set_environment("LABYRINTH_ART_LOOK", "")
	var treatment := Treatment.new()
	var original_warm: Dictionary = Profiles.definition("warm")
	var original_gentle: Dictionary = Profiles.definition("gentle")
	check.call(Profiles.resolved_definition("warm", 2.0) == original_warm, "Two-source Warm must retain the complete original Warm definition")
	check.call(Profiles.resolved_definition("warm", 4.0) == original_gentle, "Four-source Warm must match the complete original Gentle definition")
	check.call(is_equal_approx(Profiles.density_blend(3.0), 0.5), "Three sources smoothly blend halfway between the authored anchors")
	for count: int in [2, 3, 4, 6, 2]:
		treatment.configure(_sources(count), "", true)
		var expected: Dictionary = Profiles.resolved_definition("warm", float(count))
		check.call(treatment.preset == "warm", "Density must resolve lighting without changing the selected profile")
		check.call(is_equal_approx(treatment.source_equivalents, float(count)), "Each normal column contributes one torch-equivalent")
		for target: ShaderMaterial in [treatment.material, treatment.floor_material, treatment.cache_bake_material]:
			for key: String in Profiles.SCALAR_FIELDS:
				check.call(is_equal_approx(float(target.get_shader_parameter("art_" + key + "_level")), float(expected[key])), "Density-resolved " + key + " reaches every material")
			var actual_tint: Vector3 = target.get_shader_parameter("art_look_tint")
			check.call(actual_tint.is_equal_approx(expected["tint"]), "Density-resolved tint reaches every material")
			check.call(is_equal_approx(float(target.get_shader_parameter("art_local_light_scale")), Profiles.local_light_scale(float(count))), "Diffuse and cached-floor paths share the higher-density energy scale")
	check.call(is_equal_approx(treatment.local_light_scale, 1.0), "Returning to two sources restores full local lighting")
	treatment.configure(_sources(1, 1.1), "", true)
	check.call(is_equal_approx(treatment.source_equivalents, 1.375), "A stronger campfire contributes proportionally to room density")
	check.call(Profiles.resolved_definition("balanced", 4.0) == Profiles.definition("balanced"), "Other stored looks keep their original art direction")
	check.call(Profiles.resolved_definition("missing", 4.0).is_empty(), "Unknown density profile remains invalid")
	var midpoint: Dictionary = Profiles.resolved_definition("warm", 3.0)
	for key: String in Profiles.SCALAR_FIELDS:
		check.call(is_equal_approx(float(midpoint[key]), (float(original_warm[key]) + float(original_gentle[key])) * 0.5), "Intermediate density interpolates " + key)
	midpoint["gain"] = 0.0
	check.call(Profiles.resolved_definition("warm", 3.0)["gain"] > 0.0, "Resolved definitions must not mutate stored profiles")

static func _sources(count: int, strength: float = 0.8) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for index: int in range(count):
		result.append({"point": Vector2(index * 100, 0), "radius": 300.0, "color": Color(1.0, 0.68, 0.36, strength)})
	return result
