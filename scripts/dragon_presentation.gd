extends RefCounted

## Presentation follows the authored action, not the resolver's generic `aoe`
## transport kind. An intent may contain movement, a spell and a second attack.
## Keep those actions distinct; this module never selects targets or outcomes.
const TYPES := ["vyraketh", "tharokh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]
const RELEASE: float = 0.30
const CONTACT: float = 0.52

static func profile(effect: Dictionary, actor: Dictionary = {}) -> Dictionary:
	var enemy: String = str(actor.get("type", effect.get("enemy_type", "")))
	var action: String = str(effect.get("action_type", effect.get("kind", "")))
	var kind: String = str(effect.get("kind", ""))
	var intent: String = str(effect.get("intent_id", ""))
	if enemy not in TYPES or kind in ["move", "intent", "intent_refresh", "status_damage"]:
		return {}
	var clip: String = ""
	var geometry: String = "physical"
	var element: String = str(effect.get("element", "none"))
	match enemy:
		"vyraketh":
			if action == "cinder_marks": clip = "kindle"; geometry = "meteor"; element = "fire"
			elif action == "detonate_cinders": clip = "crownfire"; geometry = "ground"; element = "fire"
			elif intent == "cinderfall" or action == "ranged": clip = "cinderfall"; geometry = "breath"; element = "fire"
			elif action in ["melee", "aoe"]: clip = "maw"
		"tharokh":
			if action == "raise_terrain": clip = "brace"; geometry = "utility"; element = "earth"
			elif action == "terrain_burst": clip = "faultline"; geometry = "ground"; element = "earth"
			elif intent == "bedrock_breath" or action == "ranged": clip = "breath"; geometry = "breath"; element = "earth"
			elif action in ["melee", "aoe"]: clip = "claw"
		"vaeloryx":
			if action == "block": clip = "guard"; geometry = "utility"
			elif intent == "skyhook" or action == "pull": clip = "pull"; geometry = "breath"; element = "air"
			elif intent in ["hollow_gale","eye_of_storm"] or action == "gale_force": clip = "gale"; geometry = "ground"; element = "air"
			elif action in ["melee", "aoe"]: clip = "dive"
		"iskaldra":
			if action == "frost_armor": clip = "mantle"; geometry = "utility"; element = "ice"
			elif intent == "crystal_mantle" and action in ["melee","aoe"]: clip = "talon"
			elif intent == "whiteout_lance" or action == "ranged": clip = "lance"; geometry = "breath"; element = "ice"
			elif intent == "shatterstorm" or action == "aoe": clip = "storm"; geometry = "ground"; element = "ice"
			elif action == "melee": clip = "talon"
		"zekarion":
			if action in ["summon_minions", "summon", "block"]: clip = "call"; geometry = "utility"; element = "lightning"
			elif action == "lightning_strikes": clip = "charge"; geometry = "meteor"; element = "lightning"
			elif intent == "tempest_breath": clip = "charge"; geometry = "ground"; element = "lightning"
			elif action == "ranged": clip = "breath"; geometry = "breath"; element = "lightning"
			elif action in ["melee", "aoe"]: clip = "claw"
		"noctyrax":
			if action in ["summon_minions","summon"]: clip = "eclipse"; geometry = "utility"; element = "shadow"
			elif action == "aoe" and str(effect.get("committed_shape","")) == "refuge": clip = "eclipse"; geometry = "ground"; element = "shadow"
			elif action == "umbra_eclipse": clip = "eclipse"; geometry = "ground"; element = "shadow"
			elif intent == "starless_breath" or action == "ranged": clip = "breath"; geometry = "breath"; element = "shadow"
			elif intent == "night_coil": clip = "coil"; geometry = "breath"; element = "shadow"
			elif action in ["melee", "aoe"]: clip = "claw"
	if clip.is_empty(): return {}
	return {"enemy":enemy, "clip":clip, "geometry":geometry, "element":element}

static func clip(effect: Dictionary, actor: Dictionary = {}) -> String:
	return str(profile(effect, actor).get("clip", ""))

static func direction(effect: Dictionary, actor: Dictionary, player_tile: Vector2i) -> Vector2i:
	var held: Vector2i = effect.get("action_direction", Vector2i.ZERO)
	if held != Vector2i.ZERO: return held
	var origin: Vector2i = actor.get("pos", effect.get("from", Vector2i.ZERO))
	var target: Vector2i = effect.get("player_from", effect.get("to", player_tile))
	if str(profile(effect, actor).get("geometry", "")) in ["utility", "ground", "meteor"]: target = player_tile
	var footprint: Vector2i = actor.get("footprint", Vector2i(2,2))
	return target * 2 - (origin * 2 + footprint - Vector2i.ONE)

static func area_fx(effect: Dictionary) -> bool:
	return str(profile(effect).get("geometry", "")) in ["breath", "ground", "meteor"]

static func pose_phase(effect: Dictionary, progress: float) -> float:
	var release: float = RELEASE if str(profile(effect).get("geometry","")) == "breath" else CONTACT
	var contact_pose: float = 0.55
	if progress <= release: return lerpf(0.0,contact_pose,progress/release)
	if progress <= CONTACT: return lerpf(contact_pose,0.65,(progress-release)/maxf(.01,CONTACT-release))
	return lerpf(0.65 if release < CONTACT else contact_pose,1.0,(progress-CONTACT)/(1.0-CONTACT))

static func tiles(effect: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in effect.get("tiles", effect.get("focus_tiles", [])):
		if value is Vector2i and (value as Vector2i).x >= 0 and not result.has(value): result.append(value)
	# Empty resolved areas are meaningful: clearing every Cinder or Worldspine
	# cancels all target impacts. Only a genuine single-target delivery may use
	# `to`; its ordinary resolver step also carries an empty `tiles` array.
	var kind: String = str(effect.get("kind", ""))
	var action: String = str(effect.get("action_type", kind))
	var direct: bool = kind in ["melee", "ranged", "push", "pull"] and action in ["melee", "ranged", "push", "pull"]
	if result.is_empty() and direct and effect.get("to", Vector2i(-1,-1)).x >= 0: result.append(effect["to"])
	return result
