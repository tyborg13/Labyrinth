extends RefCounted

const ORANGE: Color = Color("ff8a3a")
const GLOW_ALPHA: float = 0.35
const CAPPED_GLOW_ALPHA: float = 0.55
# Lanes above the normal art profiles and the white hit flash profile.
const GLOW_PROFILE_OFFSET: int = 8
const CAPPED_PROFILE_OFFSET: int = 16
const Kindle = preload("res://scripts/enemy_mechanics/kindle.gd")
const Clock = preload("res://scripts/presentation_clock.gd")

const PULSE_SECONDS: float = 1.2
const PULSE_ALPHA: float = 0.10
const BADGE_POP_SECONDS: float = 0.25
const BADGE_POP_PEAK: float = 1.35
# Director feedback 1: the badge peaks halfway through its pop.
const BADGE_POP_PEAK_PROGRESS: float = 0.5

static func badge_scale(presentation: Dictionary, actor_key: String) -> float:
	var pop: Dictionary = presentation.get("kindle_pop", {})
	if str(pop.get("actor_key", "")) != actor_key or bool(presentation.get("reduced_motion", false)): return 1.0
	var t: float = clampf(float(pop.get("elapsed", BADGE_POP_SECONDS)) / BADGE_POP_SECONDS, 0.0, 1.0)
	var peak: float = BADGE_POP_PEAK_PROGRESS
	return lerpf(1.0, BADGE_POP_PEAK, t / peak) if t < peak else lerpf(BADGE_POP_PEAK, 1.0, (t - peak) / (1.0 - peak))

static func texts(step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(step.get("amount", 0)) <= 0: return result
	result.append({"tile": step.get("tile", Vector2i.ZERO), "text": "Burst +%d" % int(step["amount"]),
		"color": preload("res://scripts/enemy_mechanics/death_burst_view.gd").FIRE, "offset": -6.0,
		"anchor_id": str(step.get("actor_key", "")), "unit_anchor_key": str(step.get("actor_key", "")), "automatic_anchor": true})
	return result

static func decorate(presentation: Dictionary, elapsed: float) -> void:
	var step: Dictionary = presentation.get("effect", {})
	if str(step.get("action_type", "")) != "kindle": return
	presentation["kindle_pop"] = {"actor_key": step.get("actor_key", ""), "elapsed": elapsed}

# Compose with the board's existing art and white flash shader. Recover the
# original lighting profile before grading or selecting the flash output.
static func configure_sprite_shader(material: ShaderMaterial) -> void:
	material.set_shader_parameter("kindle_orange", Vector3(ORANGE.r, ORANGE.g, ORANGE.b))
	material.set_shader_parameter("kindle_strengths", Vector2(GLOW_ALPHA, CAPPED_GLOW_ALPHA))

static func sprite_profile(unit: Dictionary, profile: int) -> int:
	if not _active(unit): return profile
	return profile + (CAPPED_PROFILE_OFFSET if int(unit["kindled_bonus"]) >= Kindle.MAX_BONUS else GLOW_PROFILE_OFFSET)

static func update_pulse(material: ShaderMaterial, enemies: Array, reduced_motion: bool) -> void:
	for enemy: Dictionary in enemies:
		if not _active(enemy): continue
		var pulse: float = 1.0 if reduced_motion else 1.0 + PULSE_ALPHA * sin(float(Clock.ticks_msec()) / 1000.0 * TAU / PULSE_SECONDS)
		material.set_shader_parameter("kindle_pulse", pulse)
		return

static func _active(unit: Dictionary) -> bool:
	return (
		int(unit.get("kindled_bonus", 0)) > 0
		and int(unit.get("hp", 0)) > 0
		and not bool(unit.get("death_animation", false))
		and str(unit.get("type", "")) in ["ember_tick", "ember_hoarder"]
	)

static func rows(intent: Dictionary) -> Array:
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "kindle":
			return [preload("res://scripts/action_icon_library.gd").tokens_for_action(action, {"actor_kind": "enemy"})]
	return []

static func descriptor(unit: Dictionary, fallback: Dictionary) -> Dictionary:
	for action: Dictionary in (unit.get("intent", {}) as Dictionary).get("actions", []):
		if str(action.get("type", "")) == "kindle": return {"family": "support", "action_type": "kindle", "value": int(action.get("amount", 0))}
	return fallback
