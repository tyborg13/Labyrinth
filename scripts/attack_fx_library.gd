extends RefCounted
class_name AttackFxLibrary

const STYLE_DEFAULT: String = "default"
const STYLE_FIREBALL: String = "fireball"
const STYLE_EARTH_SPIKES: String = "earth_spikes"
const STYLE_AIR_GUST: String = "air_gust"
const STYLE_LIGHTNING_BOLT: String = "lightning_bolt"
const STYLE_ICE_SHARDS: String = "ice_shards"

const FIREBALL_ANIMATION_FRAMES: int = 18
const FIREBALL_FRAME_SECONDS: float = 0.033
const FIREBALL_TRAVEL_END_PROGRESS: float = 10.0 / 18.0
const EARTH_ANIMATION_FRAMES: int = 24
const EARTH_FRAME_SECONDS: float = 0.038
const EARTH_TRAVEL_END_PROGRESS: float = 16.0 / 24.0
const AIR_ANIMATION_FRAMES: int = 20
const AIR_FRAME_SECONDS: float = 0.033
const AIR_TRAVEL_END_PROGRESS: float = 12.0 / 20.0
const LIGHTNING_ANIMATION_FRAMES: int = 15
const LIGHTNING_FRAME_SECONDS: float = 0.026
const LIGHTNING_TRAVEL_END_PROGRESS: float = 8.0 / 15.0
const ICE_ANIMATION_FRAMES: int = 22
const ICE_FRAME_SECONDS: float = 0.035
const ICE_TRAVEL_END_PROGRESS: float = 11.0 / 22.0

static func style_for_effect(effect: Dictionary) -> String:
	var action_type: String = str(effect.get("action_type", effect.get("kind", "")))
	var element_id: String = str(effect.get("element", effect.get("_card_element", "none")))
	if str(effect.get("kind", "")) == "ranged" and action_type == "ranged":
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

static func travel_progress_for_style(style: String, effect_progress: float) -> float:
	return clampf(effect_progress / travel_end_progress(style), 0.0, 1.0)

static func impact_progress_for_style(style: String, effect_progress: float) -> float:
	var travel_end: float = travel_end_progress(style)
	return clampf((effect_progress - travel_end) / (1.0 - travel_end), 0.0, 1.0)

static func fireball_travel_progress(effect_progress: float) -> float:
	return travel_progress_for_style(STYLE_FIREBALL, effect_progress)

static func fireball_impact_progress(effect_progress: float) -> float:
	return impact_progress_for_style(STYLE_FIREBALL, effect_progress)

static func looping_frame_index(progress: float, frame_count: int, cycles: float = 1.0) -> int:
	if frame_count <= 0:
		return 0
	var cycle_progress: float = wrapf(clampf(progress, 0.0, 1.0) * maxf(0.0, cycles), 0.0, 1.0)
	return clampi(int(floor(cycle_progress * float(frame_count))), 0, frame_count - 1)

static func one_shot_frame_index(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	return clampi(int(floor(clampf(progress, 0.0, 1.0) * float(frame_count))), 0, frame_count - 1)
