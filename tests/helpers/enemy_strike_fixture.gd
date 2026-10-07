extends RefCounted
const HeroFixture = preload("res://tests/helpers/strike_trail_fixture.gd")
const Points = preload("res://scripts/enemy_strike_points.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")

static func state(enemy_type: String, delta: Vector2i) -> Dictionary:
	var result: Dictionary = HeroFixture.state(-delta)
	result["enemies"][0]["type"] = enemy_type
	result["enemies"][0]["footprint"] = Vector2i(2,2) if enemy_type in Dragon.TYPES else Vector2i.ONE
	if enemy_type in Dragon.TYPES:
		# Aim from the footprint centre, avoiding diagonal facing ties.
		var target_delta: Vector2i = Vector2i(1,2) if delta == Vector2i(0,1) else Vector2i(1,-1) if delta == Vector2i(0,-1) else Vector2i(2,1) if delta == Vector2i(1,0) else Vector2i(-1,1)
		result["player"]["pos"] = result["enemies"][0]["pos"] + target_delta
	return result

static func effect(enemy_type: String, state_value: Dictionary, variant: String = "") -> Dictionary:
	var source: Dictionary = state_value["enemies"][0]
	var from: Vector2i = source["pos"]
	var to: Vector2i = state_value["player"]["pos"]
	var result: Dictionary = {"kind":"push" if variant == "push" else "aoe" if variant in ["area","guardian_area","thrust"] else "melee",
		"enemy_type":enemy_type, "actor_key":"enemy_1", "from":from, "to":to, "element":"none", "seed":11}
	if variant == "area":
		result["intent_id"] = "worldspine_claw"
		var ray: Vector2i = Dragon.direction(result, source, to)
		var forward: Vector2i = Vector2i(signi(ray.x),0) if absi(ray.x) >= absi(ray.y) else Vector2i(0,signi(ray.y))
		# Keep the fan beyond the dragon, including rear/mirrored views;
		# a target cell must not accidentally overlap its own 2x2 footprint.
		result["tiles"] = [to, to + forward, to + Vector2i(-forward.y,forward.x)]
	elif variant == "guardian_area": result["intent_id"] = "hooked_sweep"
	elif variant == "thrust": result["intent_id"] = "glass_lunge"
	elif variant == "advance": result["intent_id"] = "spear_advance"
	return result

static func presentation(enemy_type: String, state_value: Dictionary, effect_value: Dictionary, progress: float, reduced: bool = false) -> Dictionary:
	var result: Dictionary = {"effect":effect_value, "effect_progress":progress, "reduced_motion":reduced, "board_backdrop_visible":true}
	var source: Dictionary = state_value["enemies"][0]
	var delta: Vector2i = Points.direction(effect_value, source, state_value["player"]["pos"])
	var motion: Dictionary = {"clip":"attack", "phase":progress, "contact":Points.contact(effect_value), "direction":delta}
	var field: String = enemy_type + "_motion"
	if Guardian.handles(enemy_type):
		field = "guardian_motion"
		motion = Guardian.action_motion(effect_value, source, progress, Points.contact(effect_value))
	elif enemy_type == "chainbound_gaoler":
		field = "gaoler_motion"; motion["action"] = "strike"
	elif enemy_type == "frostglass_lancer":
		field = "frostglass_motion"
		if str(effect_value.get("intent_id", "")) != "spear_advance":
			motion = preload("res://scripts/frostglass_lancer_cutout/action.gd").motion_for_effect(effect_value,"thrust",progress,Points.contact(effect_value))
		else: motion = {}
	elif enemy_type == "acolyte": motion = {}
	elif enemy_type == "iskaldra":
		motion = preload("res://scripts/iskaldra_cutout/action.gd").motion_for_effect(effect_value,source,progress,state_value["player"]["pos"])
	elif enemy_type == "noctyrax": motion["clip"] = "claw"
	elif enemy_type in ["tharokh", "zekarion"]: motion["action"] = "claw"
	elif enemy_type == "vaeloryx": motion["action"] = "dive"
	elif enemy_type == "lightning_wisp": motion["action"] = "dart"
	if str(effect_value["kind"]) in ["push","pull"] and not Guardian.handles(enemy_type): motion = {}
	result[field] = {"enemy_1":motion}
	return result

static func motion_field(enemy_type: String) -> String:
	if Guardian.handles(enemy_type): return "guardian_motion"
	if enemy_type == "chainbound_gaoler": return "gaoler_motion"
	if enemy_type == "frostglass_lancer": return "frostglass_motion"
	return enemy_type + "_motion"
