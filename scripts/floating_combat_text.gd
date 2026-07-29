extends RefCounted
class_name FloatingCombatText

const KIND_DAMAGE: String = "damage"
const KIND_EFFECT: String = "effect"

const GENERIC_FRAME_COUNT: int = 7
const GENERIC_FRAME_SECONDS: float = 0.05
const DAMAGE_FRAME_COUNT: int = 13
const DAMAGE_FRAME_SECONDS: float = 0.06

const DAMAGE_BASE_FONT_SIZE: int = 30
const DAMAGE_PEAK_FONT_SIZE: int = 52
const DAMAGE_EXIT_FONT_SIZE: int = 23
const DAMAGE_REDUCED_MOTION_FONT_SIZE: int = 32
const DAMAGE_OUTLINE_SIZE: int = 4
const DAMAGE_WIDTH: float = 112.0
const DAMAGE_ANCHOR_Y: float = 8.0
const DAMAGE_DRIFT_Y: float = 30.0
const DAMAGE_LANE_OFFSET_X: float = 104.0
const EFFECT_LANE_OFFSET_X: float = 120.0
const COMPANION_X_OFFSET: float = 136.0
const COMPANION_WIDTH: float = 112.0
const WIDE_COMPANION_WIDTH: float = 184.0
const DAMAGE_SETTLE_PROGRESS: float = 0.28
const DAMAGE_FADE_START: float = 0.78
const DAMAGE_REDUCED_FADE_START: float = 0.88

const EFFECT_BASE_FONT_SIZE: int = 24
const EFFECT_PEAK_FONT_SIZE: int = 42
const EFFECT_EXIT_FONT_SIZE: int = 20
const EFFECT_REDUCED_MOTION_FONT_SIZE: int = 28
const EFFECT_OUTLINE_SIZE: int = 3


static func damage_entry(
	tile: Vector2i,
	text: String,
	color: Color,
	overrides: Dictionary = {}
) -> Dictionary:
	var lane_offset_x: float = _lane_offset_x(tile, DAMAGE_LANE_OFFSET_X)
	var entry: Dictionary = {
		"kind": KIND_DAMAGE,
		"tile": tile,
		"text": text,
		"color": color,
		"x_offset": -DAMAGE_WIDTH * 0.5 + lane_offset_x,
		"automatic_lane": true,
		"anchor_y": DAMAGE_ANCHOR_Y,
		"width": DAMAGE_WIDTH,
		"font_size": DAMAGE_BASE_FONT_SIZE,
		"outline_size": DAMAGE_OUTLINE_SIZE,
		"outline_color": Color("230706"),
		"shadow_offset": Vector2(2.0, 4.0),
		"shadow_color": Color(0.06, 0.01, 0.01, 0.78),
		"alignment": HORIZONTAL_ALIGNMENT_CENTER,
	}
	entry.merge(overrides, true)
	return entry


static func is_damage_entry(entry: Dictionary) -> bool:
	return str(entry.get("kind", "")) == KIND_DAMAGE


static func is_effect_entry(entry: Dictionary) -> bool:
	return str(entry.get("kind", "")) == KIND_EFFECT


static func is_popup_entry(entry: Dictionary) -> bool:
	return is_damage_entry(entry) or is_effect_entry(entry)


static func frame_count(entries: Array) -> int:
	return DAMAGE_FRAME_COUNT if not entries.is_empty() else GENERIC_FRAME_COUNT


static func frame_seconds(entries: Array) -> float:
	return DAMAGE_FRAME_SECONDS if not entries.is_empty() else GENERIC_FRAME_SECONDS


static func animate_entry(base_entry: Dictionary, progress: float, reduced_motion: bool) -> Dictionary:
	var entry: Dictionary = base_entry.duplicate(true)
	var t: float = clampf(progress, 0.0, 1.0)
	if is_damage_entry(entry):
		return _animate_damage_entry(entry, t, reduced_motion)
	return _animate_effect_entry(entry, t, reduced_motion)


static func _animate_damage_entry(entry: Dictionary, t: float, reduced_motion: bool) -> Dictionary:
	var base_font_size: int = int(entry.get("font_size", DAMAGE_BASE_FONT_SIZE))
	if reduced_motion:
		entry["font_size"] = maxi(base_font_size, DAMAGE_REDUCED_MOTION_FONT_SIZE)
		entry["outline_size"] = maxi(int(entry.get("outline_size", DAMAGE_OUTLINE_SIZE)), DAMAGE_OUTLINE_SIZE)
		entry["rise"] = 8.0
		entry["alpha"] = _alpha_for_progress(t, DAMAGE_REDUCED_FADE_START)
		_scale_entry_icon(entry, float(entry["font_size"]) / float(maxi(1, base_font_size)))
		return entry

	var peak_font_size: int = maxi(base_font_size, int(entry.get("impact_font_size", DAMAGE_PEAK_FONT_SIZE)))
	var exit_font_size: int = mini(base_font_size, int(entry.get("exit_font_size", DAMAGE_EXIT_FONT_SIZE)))
	var animated_font_size: float
	if t <= DAMAGE_SETTLE_PROGRESS:
		var settle_t: float = clampf(t / DAMAGE_SETTLE_PROGRESS, 0.0, 1.0)
		var settle_ease: float = 1.0 - pow(1.0 - settle_t, 3.0)
		animated_font_size = lerpf(float(peak_font_size), float(base_font_size), settle_ease)
	else:
		var exit_t: float = clampf((t - DAMAGE_SETTLE_PROGRESS) / (1.0 - DAMAGE_SETTLE_PROGRESS), 0.0, 1.0)
		animated_font_size = lerpf(float(base_font_size), float(exit_font_size), smoothstep(0.0, 1.0, exit_t))
	entry["font_size"] = maxi(1, roundi(animated_font_size))
	entry["outline_size"] = maxi(3, roundi(lerpf(5.0, 3.0, t)))
	entry["rise"] = DAMAGE_DRIFT_Y * (1.0 - pow(1.0 - t, 2.0))
	entry["alpha"] = _alpha_for_progress(t, DAMAGE_FADE_START)
	_scale_entry_icon(entry, animated_font_size / float(maxi(1, base_font_size)))
	return entry


static func _animate_effect_entry(entry: Dictionary, t: float, reduced_motion: bool) -> Dictionary:
	entry["kind"] = KIND_EFFECT
	var text_length: int = str(entry.get("text", "")).length()
	var default_base_size: int = EFFECT_BASE_FONT_SIZE if text_length <= 7 else (22 if text_length <= 16 else 18)
	var default_peak_size: int = EFFECT_PEAK_FONT_SIZE if text_length <= 7 else (34 if text_length <= 16 else 27)
	var default_exit_size: int = EFFECT_EXIT_FONT_SIZE if text_length <= 7 else (18 if text_length <= 16 else 16)
	var base_font_size: int = maxi(int(entry.get("font_size", 0)), default_base_size)
	var peak_font_size: int = maxi(base_font_size, int(entry.get("impact_font_size", default_peak_size)))
	var exit_font_size: int = mini(base_font_size, int(entry.get("exit_font_size", default_exit_size)))
	_prepare_effect_composition(entry, text_length, base_font_size)
	if reduced_motion:
		entry["font_size"] = maxi(base_font_size, EFFECT_REDUCED_MOTION_FONT_SIZE if text_length <= 7 else base_font_size)
		entry["outline_size"] = maxi(int(entry.get("outline_size", EFFECT_OUTLINE_SIZE)), EFFECT_OUTLINE_SIZE)
		entry["rise"] = 8.0
		entry["alpha"] = _alpha_for_progress(t, DAMAGE_REDUCED_FADE_START)
		_scale_entry_icon(entry, float(entry["font_size"]) / float(maxi(1, base_font_size)))
		return entry

	var animated_font_size: float
	if t <= DAMAGE_SETTLE_PROGRESS:
		var settle_t: float = clampf(t / DAMAGE_SETTLE_PROGRESS, 0.0, 1.0)
		var settle_ease: float = 1.0 - pow(1.0 - settle_t, 3.0)
		animated_font_size = lerpf(float(peak_font_size), float(base_font_size), settle_ease)
	else:
		var exit_t: float = clampf((t - DAMAGE_SETTLE_PROGRESS) / (1.0 - DAMAGE_SETTLE_PROGRESS), 0.0, 1.0)
		animated_font_size = lerpf(float(base_font_size), float(exit_font_size), smoothstep(0.0, 1.0, exit_t))
	entry["font_size"] = maxi(1, roundi(animated_font_size))
	entry["outline_size"] = maxi(2, roundi(lerpf(4.0, 2.0, t)))
	entry["rise"] = DAMAGE_DRIFT_Y * (1.0 - pow(1.0 - t, 2.0))
	entry["alpha"] = _alpha_for_progress(t, DAMAGE_FADE_START)
	_scale_entry_icon(entry, animated_font_size / float(maxi(1, base_font_size)))
	return entry


static func _prepare_effect_composition(entry: Dictionary, text_length: int, base_font_size: int) -> void:
	var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
	var lane_offset_x: float = _lane_offset_x(tile, EFFECT_LANE_OFFSET_X)
	if not entry.has("width"):
		entry["width"] = clampf(34.0 + float(text_length) * float(base_font_size) * 0.68, 86.0, 220.0)
	if not entry.has("x_offset"):
		entry["x_offset"] = -float(entry.get("width", 86.0)) * 0.5 + lane_offset_x
		entry["automatic_lane"] = true
	if not entry.has("anchor_y"):
		entry["anchor_y"] = DAMAGE_ANCHOR_Y
	if not entry.has("alignment"):
		entry["alignment"] = HORIZONTAL_ALIGNMENT_CENTER
	if not entry.has("outline_color"):
		entry["outline_color"] = Color("1d0c08")
	if not entry.has("shadow_offset"):
		entry["shadow_offset"] = Vector2(2.0, 3.0)
	if not entry.has("shadow_color"):
		entry["shadow_color"] = Color(0.03, 0.01, 0.01, 0.72)


static func _lane_offset_x(tile: Vector2i, magnitude: float) -> float:
	# On the usual nine-column combat board, pushing away from the middle column
	# keeps the impact headline beside the actor instead of covering its HUD stack.
	return -magnitude if tile.x < 4 else magnitude


static func _scale_entry_icon(entry: Dictionary, scale: float) -> void:
	if str(entry.get("icon", "")).is_empty():
		return
	var base_icon_size: float = float(entry.get("base_icon_size", entry.get("icon_size", 22.0)))
	entry["icon_size"] = clampf(base_icon_size * scale, 18.0, 38.0)


static func _alpha_for_progress(progress: float, fade_start: float) -> float:
	if progress <= fade_start:
		return 1.0
	return clampf(1.0 - ((progress - fade_start) / maxf(0.001, 1.0 - fade_start)), 0.0, 1.0)
