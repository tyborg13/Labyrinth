extends RefCounted
## Presentation-only strike registry. Points are absolute bind/source coordinates,
## transformed by the named bone in the creature's own sampled action pose.
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const FrostglassAction = preload("res://scripts/frostglass_lancer_cutout/action.gd")
const IskaldraAction = preload("res://scripts/iskaldra_cutout/action.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const MODELS: Dictionary = {
	"harrier": preload("res://scripts/harrier_cutout/renderer.gd"),
	"frostglass_lancer": preload("res://scripts/frostglass_lancer_cutout/renderer.gd"),
	"warden": preload("res://scripts/stone_warden_cutout/renderer.gd"),
	"chainbound_gaoler": preload("res://scripts/chainbound_gaoler_cutout/renderer.gd"),
	"crawler": preload("res://scripts/crawler_cutout/renderer.gd"),
	"noctyrax": preload("res://scripts/noctyrax_cutout/renderer.gd"),
	"zekarion": preload("res://scripts/zekarion_cutout/renderer.gd"),
	"tharokh": preload("res://scripts/tharokh_cutout/renderer.gd"),
	"vaeloryx": preload("res://scripts/vaeloryx_cutout/renderer.gd"),
	"iskaldra": preload("res://scripts/iskaldra_cutout/renderer.gd")}
const BESPOKE: Array = ["grave_surgeon", "veilbound_acolyte", "cinder_droplet", "cinder_ooze", "vyraketh"]
const REGISTRY: Dictionary = {
	"harrier": {"kind":"streak", "bone":"weapon_r", "landmark":"weapon_tip", "inner_bone":"weapon_r", "window":Vector2(0.34,0.60), "length":74.0},
	"frostglass_lancer": {"kind":"streak", "bone":"lance", "landmark":"weapon_tip", "inner_bone":"lance", "window":Vector2(0.315,0.60), "length":74.0},
	"warden": {"kind":"sweep", "bone":"weapon_r", "landmark":"mace_head", "inner_bone":"weapon_r", "window":Vector2(0.3696,0.66), "reach":0.50},
	# Cudgel Press is a punch; the hanging chain barely moves during this clip.
	"chainbound_gaoler": {"kind":"streak", "bone":"hand_fist", "inner_bone":"fore_fist", "window":Vector2(0.30,0.56), "length":48.0},
	"crawler": {"kind":"rake", "bone":"claw_near", "landmark":"contacts.claw_near", "inner_bone":"fore_near", "window":Vector2(0.378,0.66)},
	"noctyrax": {"kind":"rake", "bone":"claw_fore_near", "point":[Vector2(107,205),Vector2(228,208)], "inner_bone":"lower_fore_near", "window":Vector2(0.336,0.66)},
	"zekarion": {"kind":"rake", "bone":"claw_near", "landmark":"strike", "inner_bone":"lower_near", "window":Vector2(0.3696,0.66)},
	"tharokh": {"kind":"rake", "bone":"claw_fore_near", "landmark":"sole_fore_near", "inner_bone":"lower_fore_near", "window":Vector2(0.3696,0.66)},
	"vaeloryx": {"kind":"rake", "bone":"claw_near", "point":[Vector2(120,191),Vector2(188,170)], "inner_bone":"arm_near", "window":Vector2(0.34,0.66)},
	"iskaldra": {"kind":"rake", "bone":"talon_near", "point":[Vector2(116,207),Vector2(66,205)], "inner_bone":"arm_near", "window":Vector2(0.30,0.60)},
	"lightning_wisp": {"kind":"arc", "window":Vector2(0.33,0.56)},
	"acolyte": {"kind":"arc", "window":Vector2(0.33,0.56)},
	# Guardian contact is authored .46, mapped to effect .42. The drive starts
	# at authored .31, i.e. .31/.46*.42; end .57 maps to .538148 effect time.
	"ashen_reaver": {"kind":"sweep", "bone":"blade", "point":[Vector2(8,220),Vector2(236,226)], "inner_bone":"blade", "window":Vector2(0.283043,0.538148), "reason":"The broad cleaver rotates through an overhead cut."},
	"bell_tender": {"kind":"streak", "bone":"spear", "point":[Vector2(52,15),Vector2(207,15)], "inner_bone":"spear", "window":Vector2(0.283043,0.538148), "length":74.0, "reason":"Both hands drive one rigid forked spear."},
	"storm_cantor": {"kind":"streak", "bone":"spear", "point":[Vector2(52,13),Vector2(191,13)], "inner_bone":"spear", "window":Vector2(0.283043,0.538148), "length":74.0, "reason":"The near hand drives the spear point."},
	"craghide": {"kind":"rake", "bone":"foot_fore_near", "landmark":"foot_contacts.foot_fore_near", "inner_bone":"knee_fore_near", "window":Vector2(0.283043,0.538148), "reason":"Its raised forepaw has several broad painted claws."},
	"rimejaw": {"kind":"rake", "bone":"foot_fore_near", "landmark":"foot_contacts.foot_fore_near", "inner_bone":"knee_fore_near", "window":Vector2(0.283043,0.538148), "reason":"The authored strike lifts and rakes the near foreclaw."},
	"rime_whelp": {"kind":"rake", "bone":"foot_fore_near", "landmark":"foot_contacts.foot_fore_near", "inner_bone":"knee_fore_near", "window":Vector2(0.283043,0.538148), "reason":"The small dragon shares the raised foreclaw strike."},
	"stoneback_mite": {"kind":"rake", "bone":"foot_front_near", "landmark":"foot_contacts.foot_front_near", "inner_bone":"knee_front_near", "window":Vector2(0.283043,0.538148), "reason":"The front claw lifts while the other five legs support it."},
	"gallows_roc": {"kind":"rake", "bone":"feathers_near", "offset":Vector2(0,35), "inner_bone":"wing_elbow_near", "window":Vector2(0.283043,0.538148), "reason":"The articulated near wing sweeps its feather tips; the feet stay planted."},
	"roc_fledgling": {"kind":"rake", "bone":"feathers_near", "offset":Vector2(0,30), "inner_bone":"wing_elbow_near", "window":Vector2(0.283043,0.538148), "reason":"Its smaller articulated wing repeats the feather-tip stroke."},
	"wick_shade": {"kind":"rake", "bone":"hand_near", "point":[Vector2(46,177),Vector2(57,187)], "inner_bone":"elbow_near", "window":Vector2(0.283043,0.538148), "reason":"The empty near hand has long claw-like fingers and reaches to strike."},
	"last_lamplighter": {"kind":"sweep", "bone":"lantern", "point":[Vector2(176,207),Vector2(68,197)], "inner_bone":"lantern", "window":Vector2(0.283043,0.538148), "reason":"The hanging lantern rotates through the near-hand strike."},
	"ash_hound": {"kind":"sweep", "bone":"head", "point":[Vector2(40,178),Vector2(214,150)], "inner_bone":"head", "window":Vector2(0.283043,0.538148), "reach":0.40, "reason":"The authored attack drives the jaw; its paws remain planted."},
	"rime_spitter": {"kind":"sweep", "bone":"head", "point":[Vector2(43,155),Vector2(216,144)], "inner_bone":"head", "window":Vector2(0.283043,0.538148), "reach":0.40, "reason":"The rigid snout lunges to contact; the throat sac belongs to casting."}}

static func settings(enemy_type: String, effect: Dictionary) -> Dictionary:
	var kind: String = str(effect.get("kind", ""))
	if kind in ["push", "pull"] or (enemy_type == "frostglass_lancer" and str(effect.get("intent_id", "")) == "spear_advance"):
		return {"kind":"arc", "window":Vector2(0.33,0.56), "actions":[kind]}
	if enemy_type in BESPOKE:
		return {"kind":"bespoke", "actions":["melee"]}
	var result: Dictionary = REGISTRY.get(enemy_type, {"kind":"arc", "window":Vector2(0.33,0.56)}).duplicate()
	# Hooked Sweep's blade is nearly held after its .38 contact. A moving
	# windup must not disguise that stationary displayed contact/follow-through.
	if enemy_type == "ashen_reaver" and kind == "aoe": result["contact_hold_arc"] = true
	result["actions"] = ["melee", "aoe"] if enemy_type in ["frostglass_lancer", "warden"] or Guardian.handles(enemy_type) else ["melee"]
	return result

static func contact(effect: Dictionary) -> float:
	# Same feedback boundary as RunScene; this helper never moves its clock.
	if str(Dragon.profile(effect).get("geometry", "")) == "physical": return 0.42
	var style: String = Fx.style_for_effect(effect)
	if style != Fx.STYLE_DEFAULT: return Fx.travel_end_progress(style)
	match str(effect.get("kind", "")):
		"melee": return 0.42
		"aoe": return 0.38
		_: return 0.50

static func window_for(settings_value: Dictionary, boundary: float) -> Vector2:
	var window: Vector2 = settings_value["window"]
	return Vector2(window.x / 0.42 * boundary, boundary + (window.y - 0.42) / 0.58 * (1.0 - boundary))

static func direction(effect: Dictionary, actor: Dictionary, player_tile: Vector2i) -> Vector2i:
	if str(actor.get("type", "")) in Dragon.TYPES:
		return Dragon.direction(effect, actor, player_tile)
	return effect.get("action_direction", (effect.get("to", player_tile) as Vector2i) - (effect.get("from", actor.get("pos", Vector2i.ZERO)) as Vector2i))

static func action_pose(enemy_type: String, effect: Dictionary, actor: Dictionary, progress: float, contact: float) -> Dictionary:
	if Guardian.handles(enemy_type):
		var motion: Dictionary = Guardian.action_motion(effect, actor, progress, contact)
		return {"clip":"strike", "phase":motion["phase"]}
	if enemy_type == "frostglass_lancer":
		var motion: Dictionary = FrostglassAction.motion_for_effect(effect, "thrust", progress, contact)
		return {"clip":"thrust", "phase":motion["phase"]}
	if enemy_type == "iskaldra":
		var motion: Dictionary = IskaldraAction.motion_for_effect(effect, actor, progress, effect.get("to", Vector2i.ZERO))
		return {"clip":"talon", "phase":motion["phase"]}
	if enemy_type == "chainbound_gaoler": return {"clip":"strike", "phase":progress}
	var model: Script = MODELS[enemy_type]
	var clip: String = "attack"
	match enemy_type:
		"crawler": clip = model.attack_clip(effect)
		"noctyrax", "zekarion", "tharokh": clip = "claw"
		"vaeloryx": clip = "dive"
	return {"clip":clip, "phase":model.attack_pose_phase(progress, contact)}

static func samples(renderer: Node, actor: Dictionary, effect: Dictionary, delta: Vector2i, settings_value: Dictionary, contact: float) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var enemy_type: String = str(actor["type"])
	var orientation: Dictionary = Facing.direction_for_delta(delta)
	var view: String = orientation["facing"]
	var layout: Dictionary = renderer.rigs[view].layout
	var model: Script = Guardian if Guardian.handles(enemy_type) else MODELS[enemy_type]
	var motion: Script = model.Motion
	var window: Vector2 = settings_value["window"]
	var step: float = preload("res://scripts/strike_trail_fx.gd").SAMPLE_STEP
	var times: Array[float]
	for index: int in range(ceili((window.y - window.x) / step) + 1):
		times.append(minf(window.x + float(index) * step, window.y))
	# Piecewise mappings change slope at impact. Include the exact authored
	# contact so interpolation cannot round off a fast spear/claw's apex.
	if not times.has(contact) and contact >= window.x and contact <= window.y:
		times.append(contact)
		times.sort()
	for progress: float in times:
		var action: Dictionary = action_pose(enemy_type, effect, actor, progress, contact)
		var pose: Dictionary = motion.sample_pose(action["clip"], action["phase"], layout, view)
		var tip: Vector2 = strike_point(layout, pose, settings_value, view)
		var grip: Vector2 = world(pose, layout, settings_value["inner_bone"]).origin
		var inner: Vector2 = tip.lerp(grip, float(settings_value.get("reach", 0.55)))
		if bool(orientation["mirrored"]):
			tip.x = 255.0 - tip.x
			inner.x = 255.0 - inner.x
		result.append({"progress":progress, "tip":tip, "inner":inner})
	return result

static func strike_point(layout: Dictionary, pose: Dictionary, settings_value: Dictionary, view: String) -> Vector2:
	var bone: String = settings_value["bone"]
	var bind: Vector2 = _point(layout["joints"][bone]["position"])
	return world(pose, layout, bone) * (bind_point(layout, settings_value, view) - bind)

static func bind_point(layout: Dictionary, settings_value: Dictionary, view: String) -> Vector2:
	var bind: Vector2 = _point(layout["joints"][settings_value["bone"]]["position"])
	var point: Vector2 = bind + (settings_value.get("offset", Vector2.ZERO) as Vector2)
	if settings_value.has("landmark"):
		var value: Variant = layout["landmarks"]
		for key: String in str(settings_value["landmark"]).split("."): value = value[key]
		point = _point(value)
	elif settings_value.has("point"):
		point = settings_value["point"][0 if view == "front" else 1]
	return point

static func world(pose: Dictionary, layout: Dictionary, bone: String) -> Transform2D:
	if bone.is_empty(): return Transform2D.IDENTITY
	var parent: String = str(layout["joints"][bone].get("parent", "")) if layout["joints"][bone].get("parent") != null else ""
	var value: Dictionary = pose[bone]
	return world(pose, layout, parent) * Transform2D(float(value["rotation"]), value["scale"], float(value.get("skew", 0.0)), value["position"])

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
