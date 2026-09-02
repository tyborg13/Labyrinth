extends RefCounted
class_name AttackFxLibrary

const STYLE_DEFAULT: String = "default"
const STYLE_FIREBALL: String = "fireball"
const STYLE_EARTH_SPIKES: String = "earth_spikes"
const STYLE_AIR_GUST: String = "air_gust"
const STYLE_LIGHTNING_BOLT: String = "lightning_bolt"
const STYLE_ICE_SHARDS: String = "ice_shards"

const FIREBALL_ANIMATION_FRAMES: int = 48
const FIREBALL_FRAME_SECONDS: float = 0.015
const FIREBALL_ANTICIPATION_END_PROGRESS: float = 4.0 / 48.0
const FIREBALL_TRAVEL_END_PROGRESS: float = 12.0 / 48.0
const EARTH_ANIMATION_FRAMES: int = 44
const EARTH_FRAME_SECONDS: float = 0.016
const EARTH_ANTICIPATION_END_PROGRESS: float = 4.0 / 44.0
const EARTH_TRAVEL_END_PROGRESS: float = 16.0 / 44.0
const AIR_ANIMATION_FRAMES: int = 38
const AIR_FRAME_SECONDS: float = 0.015
const AIR_ANTICIPATION_END_PROGRESS: float = 4.0 / 38.0
const AIR_TRAVEL_END_PROGRESS: float = 12.0 / 38.0
const LIGHTNING_ANIMATION_FRAMES: int = 30
const LIGHTNING_FRAME_SECONDS: float = 0.0115
const LIGHTNING_ANTICIPATION_END_PROGRESS: float = 4.0 / 30.0
const LIGHTNING_TRAVEL_END_PROGRESS: float = 8.0 / 30.0
const ICE_ANIMATION_FRAMES: int = 42
const ICE_FRAME_SECONDS: float = 0.016
const ICE_ANTICIPATION_END_PROGRESS: float = 4.0 / 42.0
const ICE_TRAVEL_END_PROGRESS: float = 14.0 / 42.0

static func style_for_effect(effect: Dictionary) -> String:
	var action_type: String = str(effect.get("action_type", effect.get("kind", "")))
	var element_id: String = str(effect.get("element", effect.get("_card_element", "none")))
	var kind: String = str(effect.get("kind", ""))
	var is_ranged_attack: bool = kind == "ranged" and action_type == "ranged"
	var is_ranged_aoe: bool = kind == "aoe" and action_type == "aoe" and int(effect.get("range", 0)) > 0
	if is_ranged_attack or is_ranged_aoe:
		match element_id:
			"fire":
				return STYLE_FIREBALL
			"earth":
				return STYLE_EARTH_SPIKES
			"air":
				return STYLE_AIR_GUST
			"lightning":
				return STYLE_LIGHTNING_BOLT
			"ice":
				return STYLE_ICE_SHARDS
	return STYLE_DEFAULT

static func uses_fireball(effect: Dictionary) -> bool:
	return style_for_effect(effect) == STYLE_FIREBALL

static func uses_authored_elemental_ranged(effect: Dictionary) -> bool:
	return (
		str(effect.get("kind", "")) == "ranged"
		and str(effect.get("action_type", effect.get("kind", ""))) == "ranged"
		and style_for_effect(effect) != STYLE_DEFAULT
	)

static func uses_authored_elemental_attack(effect: Dictionary) -> bool:
	return style_for_effect(effect) != STYLE_DEFAULT

static func animation_frame_count(effect: Dictionary, fallback_count: int, reduced_motion: bool) -> int:
	var style: String = style_for_effect(effect)
	if style == STYLE_DEFAULT:
		return maxi(1, fallback_count)
	if reduced_motion:
		return 1
	match style:
		STYLE_EARTH_SPIKES:
			return EARTH_ANIMATION_FRAMES
		STYLE_AIR_GUST:
			return AIR_ANIMATION_FRAMES
		STYLE_LIGHTNING_BOLT:
			return LIGHTNING_ANIMATION_FRAMES
		STYLE_ICE_SHARDS:
			return ICE_ANIMATION_FRAMES
		_:
			return FIREBALL_ANIMATION_FRAMES

static func animation_frame_seconds(effect: Dictionary, fallback_seconds: float, reduced_motion: bool) -> float:
	var style: String = style_for_effect(effect)
	if style == STYLE_DEFAULT:
		return maxf(0.0, fallback_seconds)
	if reduced_motion:
		return 0.0
	match style:
		STYLE_EARTH_SPIKES:
			return EARTH_FRAME_SECONDS
		STYLE_AIR_GUST:
			return AIR_FRAME_SECONDS
		STYLE_LIGHTNING_BOLT:
			return LIGHTNING_FRAME_SECONDS
		STYLE_ICE_SHARDS:
			return ICE_FRAME_SECONDS
		_:
			return FIREBALL_FRAME_SECONDS

static func animation_duration_seconds_for_style(style: String) -> float:
	match style:
		STYLE_EARTH_SPIKES:
			return float(EARTH_ANIMATION_FRAMES) * EARTH_FRAME_SECONDS
		STYLE_AIR_GUST:
			return float(AIR_ANIMATION_FRAMES) * AIR_FRAME_SECONDS
		STYLE_LIGHTNING_BOLT:
			return float(LIGHTNING_ANIMATION_FRAMES) * LIGHTNING_FRAME_SECONDS
		STYLE_ICE_SHARDS:
			return float(ICE_ANIMATION_FRAMES) * ICE_FRAME_SECONDS
		STYLE_FIREBALL:
			return float(FIREBALL_ANIMATION_FRAMES) * FIREBALL_FRAME_SECONDS
		_:
			return 0.0

static func impact_duration_seconds_for_style(style: String) -> float:
	return animation_duration_seconds_for_style(style) * (1.0 - travel_end_progress(style))

static func travel_end_progress(style: String) -> float:
	match style:
		STYLE_EARTH_SPIKES:
			return EARTH_TRAVEL_END_PROGRESS
		STYLE_AIR_GUST:
			return AIR_TRAVEL_END_PROGRESS
		STYLE_LIGHTNING_BOLT:
			return LIGHTNING_TRAVEL_END_PROGRESS
		STYLE_ICE_SHARDS:
			return ICE_TRAVEL_END_PROGRESS
		_:
			return FIREBALL_TRAVEL_END_PROGRESS

static func anticipation_end_progress(style: String) -> float:
	match style:
		STYLE_EARTH_SPIKES:
			return EARTH_ANTICIPATION_END_PROGRESS
		STYLE_AIR_GUST:
			return AIR_ANTICIPATION_END_PROGRESS
		STYLE_LIGHTNING_BOLT:
			return LIGHTNING_ANTICIPATION_END_PROGRESS
		STYLE_ICE_SHARDS:
			return ICE_ANTICIPATION_END_PROGRESS
		_:
			return FIREBALL_ANTICIPATION_END_PROGRESS

static func release_progress_for_style(style: String, effect_progress: float) -> float:
	return clampf(effect_progress / anticipation_end_progress(style), 0.0, 1.0)

static func travel_progress_for_style(style: String, effect_progress: float) -> float:
	var anticipation_end: float = anticipation_end_progress(style)
	var travel_end: float = travel_end_progress(style)
	var linear_progress: float = clampf(
		(effect_progress - anticipation_end) / maxf(0.001, travel_end - anticipation_end),
		0.0,
		1.0
	)
	var acceleration_power: float = 2.5
	match style:
		STYLE_EARTH_SPIKES:
			acceleration_power = 1.35
		STYLE_AIR_GUST:
			acceleration_power = 2.2
		STYLE_LIGHTNING_BOLT:
			acceleration_power = 4.0
		STYLE_ICE_SHARDS:
			acceleration_power = 2.8
	return 1.0 - pow(1.0 - linear_progress, acceleration_power)

static func impact_progress_for_style(style: String, effect_progress: float) -> float:
	var travel_end: float = travel_end_progress(style)
	return clampf((effect_progress - travel_end) / (1.0 - travel_end), 0.0, 1.0)

static func fireball_travel_progress(effect_progress: float) -> float:
	return travel_progress_for_style(STYLE_FIREBALL, effect_progress)

static func fireball_impact_progress(effect_progress: float) -> float:
	return impact_progress_for_style(STYLE_FIREBALL, effect_progress)

static func contact_flash_strength(style: String, effect_progress: float) -> float:
	var half_width: float = 0.045
	if style == STYLE_LIGHTNING_BOLT:
		half_width = 0.065
	var distance: float = absf(effect_progress - travel_end_progress(style))
	return pow(clampf(1.0 - distance / half_width, 0.0, 1.0), 0.62)

static func looping_frame_index(progress: float, frame_count: int, cycles: float = 1.0) -> int:
	if frame_count <= 0:
		return 0
	var cycle_progress: float = wrapf(clampf(progress, 0.0, 1.0) * maxf(0.0, cycles), 0.0, 1.0)
	return clampi(int(floor(cycle_progress * float(frame_count))), 0, frame_count - 1)

static func looping_frame_blend(progress: float, frame_count: int, cycles: float = 1.0) -> Vector3:
	if frame_count <= 0:
		return Vector3.ZERO
	var cycle_progress: float = wrapf(clampf(progress, 0.0, 1.0) * maxf(0.0, cycles), 0.0, 1.0)
	var scaled_progress: float = cycle_progress * float(frame_count)
	var current_index: int = posmod(int(floor(scaled_progress)), frame_count)
	var next_index: int = posmod(current_index + 1, frame_count)
	return Vector3(float(current_index), float(next_index), smoothstep(0.0, 1.0, scaled_progress - floor(scaled_progress)))

static func one_shot_frame_index(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	return clampi(int(floor(clampf(progress, 0.0, 1.0) * float(frame_count))), 0, frame_count - 1)

static func one_shot_frame_blend(progress: float, frame_count: int) -> Vector3:
	if frame_count <= 0:
		return Vector3.ZERO
	var scaled_progress: float = clampf(progress, 0.0, 1.0) * float(frame_count)
	var current_index: int = clampi(int(floor(scaled_progress)), 0, frame_count - 1)
	var next_index: int = mini(current_index + 1, frame_count - 1)
	var blend: float = 0.0 if current_index == next_index else smoothstep(0.0, 1.0, scaled_progress - floor(scaled_progress))
	return Vector3(float(current_index), float(next_index), blend)
