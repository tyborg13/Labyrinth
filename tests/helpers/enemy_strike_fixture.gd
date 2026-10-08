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
	var result: Dictionary = {"effect":effect_value, "effect_progress":progress, "reduced_motion":reduced, "board_backdrop_visible":true, "focus_actor_keys":["enemy_1"]}
	var source: Dictionary = state_value["enemies"][0]
	var delta: Vector2i = Points.direction(effect_value, source, state_value["player"]["pos"])
	var motion: Dictionary = {"clip":"attack", "phase":progress, "contact":Points.contact(effect_value), "direction":delta}
	var field: String = enemy_type + "_motion"
	if Guardian.handles(enemy_type):
		field = "guardian_motion"
		motion = Guardian.action_motion(effect_value, source, progress, Points.contact(effect_value))
	elif enemy_type == "chainbound_gaoler":
		field = "gaoler_motion"; motion["action"] = Points.MODELS[enemy_type].action_clip(effect_value)
	elif enemy_type == "crawler":
		motion["variant"] = Points.MODELS[enemy_type].attack_clip(effect_value)
	elif enemy_type == "harrier":
		motion = preload("res://scripts/harrier_cutout/action.gd").motion_for_effect(effect_value,progress)
		motion["contact"] = Points.contact(effect_value)
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
	# Match RunScene's cutout routing flags as well as its motion dictionaries.
	var shown_effect: Dictionary = effect_value.duplicate(false)
	if str(effect_value["kind"]) == "melee":
		match enemy_type:
			"harrier": shown_effect["harrier_thrust"] = true
			"crawler": shown_effect["crawler_melee"] = true
			"warden": shown_effect["warden_melee"] = true
			"noctyrax": shown_effect["noctyrax_claw"] = true
			"tharokh": shown_effect["tharokh_melee"] = true
			"zekarion":
				shown_effect["zekarion_cutout"] = true
				shown_effect["zekarion_claw"] = true
	result["effect"] = shown_effect
	return result

static func check_pose(renderer: Node, enemy_type: String, effect_value: Dictionary, state_value: Dictionary, progress: float) -> bool:
	var motion: Dictionary = presentation(enemy_type,state_value,effect_value,progress)[motion_field(enemy_type)]["enemy_1"]
	if motion.is_empty(): return renderer.clip == "idle"
	if str(Points.REGISTRY.get(enemy_type,{}).get("kind","arc")) == "arc":
		return renderer.clip == "attack" and is_equal_approx(renderer.phase,progress)
	var action: Dictionary = Points.action_pose(enemy_type,effect_value,state_value["enemies"][0],progress,Points.contact(effect_value))
	var clip: String = renderer.attack_variant if enemy_type == "crawler" else "claw" if enemy_type in ["zekarion","tharokh"] else "dive" if enemy_type == "vaeloryx" else renderer.clip
	return clip == action["clip"] and is_equal_approx(renderer.phase,action["phase"])

static func motion_field(enemy_type: String) -> String:
	if Guardian.handles(enemy_type): return "guardian_motion"
	if enemy_type == "chainbound_gaoler": return "gaoler_motion"
	if enemy_type == "frostglass_lancer": return "frostglass_motion"
	return enemy_type + "_motion"
