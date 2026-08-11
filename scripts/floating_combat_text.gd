extends RefCounted
class_name FloatingCombatText

const KIND_DAMAGE: String = "damage"
const KIND_EFFECT: String = "effect"

const GENERIC_PRESENTATION_SECONDS: float = 0.35
const ANIMATION_DURATION_SECONDS: float = 0.96
const STAGGER_SECONDS: float = 0.13
const TARGET_FRAME_SECONDS: float = 1.0 / 60.0

const DAMAGE_PRESENTATION_SCALE: float = 1.25
const DAMAGE_BASE_FONT_SIZE: int = 38
const DAMAGE_PEAK_FONT_SIZE: int = 75
const DAMAGE_EXIT_FONT_SIZE: int = 29
const DAMAGE_REDUCED_MOTION_FONT_SIZE: int = 40
const DAMAGE_OUTLINE_SIZE: int = 5
const DAMAGE_WIDTH: float = 140.0
const DAMAGE_SETTLE_PROGRESS: float = 0.32
const DAMAGE_FADE_START: float = 0.78
const DAMAGE_REDUCED_FADE_START: float = 0.88
const ARC_RISE_HEIGHT: float = 58.0
const ARC_LATERAL_DRIFT: float = 34.0
const ARC_END_DROP: float = 18.0
const ARC_APEX_PROGRESS: float = 0.34
const NORMAL_STACK_STEP_Y: float = 0.0
const REDUCED_STACK_STEP_Y: float = 36.0

const EFFECT_BASE_FONT_SIZE: int = 24
const EFFECT_PEAK_FONT_SIZE: int = 48
const EFFECT_EXIT_FONT_SIZE: int = 20
const EFFECT_REDUCED_MOTION_FONT_SIZE: int = 28
const EFFECT_OUTLINE_SIZE: int = 3


static func damage_entry(
	tile: Vector2i,
	text: String,
	color: Color,
	overrides: Dictionary = {}
) -> Dictionary:
	var entry: Dictionary = {
		"kind": KIND_DAMAGE,
		"tile": tile,
		"text": text,
		"color": color,
		"automatic_anchor": true,
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


static func animate_entries(base_entries: Array, elapsed_seconds: float, reduced_motion: bool) -> Array[Dictionary]:
	var animated: Array[Dictionary] = []
	var sequence_count_by_anchor: Dictionary = {}
	for base_var: Variant in base_entries:
		if typeof(base_var) != TYPE_DICTIONARY:
			continue
		var base_entry: Dictionary = base_var
		var anchor_key: String = _anchor_key(base_entry)
		var sequence_index: int = int(sequence_count_by_anchor.get(anchor_key, 0))
		sequence_count_by_anchor[anchor_key] = sequence_index + 1
		var delay_seconds: float = float(sequence_index) * STAGGER_SECONDS
		if elapsed_seconds + 0.0001 < delay_seconds:
			continue
		var local_elapsed: float = maxf(0.0, elapsed_seconds - delay_seconds)
		var local_progress: float = clampf(local_elapsed / ANIMATION_DURATION_SECONDS, 0.0, 1.0)
		var entry: Dictionary = animate_entry(base_entry, local_progress, reduced_motion)
		entry["sequence_index"] = sequence_index
		entry["sequence_delay_seconds"] = delay_seconds
		var motion_offset: Vector2 = entry.get("motion_offset", Vector2.ZERO)
		if reduced_motion:
			motion_offset.y -= float(sequence_index) * REDUCED_STACK_STEP_Y
		else:
			motion_offset.y -= float(sequence_index) * NORMAL_STACK_STEP_Y
		entry["motion_offset"] = motion_offset
		animated.append(entry)
	return animated


static func total_duration(base_entries: Array) -> float:
	if base_entries.is_empty():
		return GENERIC_PRESENTATION_SECONDS
	var sequence_count_by_anchor: Dictionary = {}
	var largest_sequence_index: int = 0
	for base_var: Variant in base_entries:
		if typeof(base_var) != TYPE_DICTIONARY:
			continue
		var base_entry: Dictionary = base_var
		var anchor_key: String = _anchor_key(base_entry)
		var sequence_index: int = int(sequence_count_by_anchor.get(anchor_key, 0))
		sequence_count_by_anchor[anchor_key] = sequence_index + 1
		largest_sequence_index = maxi(largest_sequence_index, sequence_index)
	return ANIMATION_DURATION_SECONDS + float(largest_sequence_index) * STAGGER_SECONDS


static func rendered_font_size(entry: Dictionary) -> float:
	return float(entry.get("font_size", 0)) * float(entry.get("font_scale", 1.0))


static func animate_entry(base_entry: Dictionary, progress: float, reduced_motion: bool) -> Dictionary:
	var entry: Dictionary = base_entry.duplicate(true)
	var t: float = clampf(progress, 0.0, 1.0)
	if is_damage_entry(entry):
		entry = _animate_damage_entry(entry, t, reduced_motion)
	else:
		entry = _animate_effect_entry(entry, t, reduced_motion)
	entry["motion_offset"] = _motion_offset(entry, t, reduced_motion)
	entry["animation_progress"] = t
	return entry


static func _animate_damage_entry(entry: Dictionary, t: float, reduced_motion: bool) -> Dictionary:
	var base_font_size: int = int(entry.get("font_size", DAMAGE_BASE_FONT_SIZE))
	if reduced_motion:
		entry["font_size"] = maxi(base_font_size, DAMAGE_REDUCED_MOTION_FONT_SIZE)
		entry["font_scale"] = 1.0
		entry["outline_size"] = maxi(int(entry.get("outline_size", DAMAGE_OUTLINE_SIZE)), DAMAGE_OUTLINE_SIZE)
		entry["alpha"] = _alpha_for_progress(t, DAMAGE_REDUCED_FADE_START)
		return entry

	var peak_font_size: int = maxi(base_font_size, int(entry.get("impact_font_size", DAMAGE_PEAK_FONT_SIZE)))
	var exit_font_size: int = mini(base_font_size, int(entry.get("exit_font_size", DAMAGE_EXIT_FONT_SIZE)))
	var animated_font_size: float
	if t <= DAMAGE_SETTLE_PROGRESS:
		var settle_t: float = clampf(t / DAMAGE_SETTLE_PROGRESS, 0.0, 1.0)
		var settle_ease: float = smoothstep(0.0, 1.0, settle_t)
		animated_font_size = lerpf(float(peak_font_size), float(base_font_size), settle_ease)
	else:
		var exit_t: float = clampf((t - DAMAGE_SETTLE_PROGRESS) / (1.0 - DAMAGE_SETTLE_PROGRESS), 0.0, 1.0)
		animated_font_size = lerpf(float(base_font_size), float(exit_font_size), smoothstep(0.0, 1.0, exit_t))
	entry["font_size"] = peak_font_size
	entry["font_scale"] = animated_font_size / float(maxi(1, peak_font_size))
	entry["outline_size"] = 6
	entry["alpha"] = _alpha_for_progress(t, DAMAGE_FADE_START)
	_prepare_scaled_icon(entry, float(peak_font_size) / float(maxi(1, base_font_size)))
	return entry


static func _animate_effect_entry(entry: Dictionary, t: float, reduced_motion: bool) -> Dictionary:
	entry["kind"] = KIND_EFFECT
	var text_length: int = str(entry.get("text", "")).length()
	var default_base_size: int = EFFECT_BASE_FONT_SIZE if text_length <= 7 else (22 if text_length <= 16 else 18)
	var default_peak_size: int = EFFECT_PEAK_FONT_SIZE if text_length <= 7 else (39 if text_length <= 16 else 31)
	var default_exit_size: int = EFFECT_EXIT_FONT_SIZE if text_length <= 7 else (18 if text_length <= 16 else 16)
	var base_font_size: int = maxi(int(entry.get("font_size", 0)), default_base_size)
	var peak_font_size: int = maxi(base_font_size, int(entry.get("impact_font_size", default_peak_size)))
	var exit_font_size: int = mini(base_font_size, int(entry.get("exit_font_size", default_exit_size)))
	_prepare_effect_composition(entry, text_length, base_font_size)
	if reduced_motion:
		entry["font_size"] = maxi(base_font_size, EFFECT_REDUCED_MOTION_FONT_SIZE if text_length <= 7 else base_font_size)
		entry["font_scale"] = 1.0
		entry["outline_size"] = maxi(int(entry.get("outline_size", EFFECT_OUTLINE_SIZE)), EFFECT_OUTLINE_SIZE)
		entry["alpha"] = _alpha_for_progress(t, DAMAGE_REDUCED_FADE_START)
		return entry

	var animated_font_size: float
	if t <= DAMAGE_SETTLE_PROGRESS:
		var settle_t: float = clampf(t / DAMAGE_SETTLE_PROGRESS, 0.0, 1.0)
		var settle_ease: float = smoothstep(0.0, 1.0, settle_t)
		animated_font_size = lerpf(float(peak_font_size), float(base_font_size), settle_ease)
	else:
		var exit_t: float = clampf((t - DAMAGE_SETTLE_PROGRESS) / (1.0 - DAMAGE_SETTLE_PROGRESS), 0.0, 1.0)
		animated_font_size = lerpf(float(base_font_size), float(exit_font_size), smoothstep(0.0, 1.0, exit_t))
	entry["font_size"] = peak_font_size
	entry["font_scale"] = animated_font_size / float(maxi(1, peak_font_size))
	entry["outline_size"] = 4
	entry["alpha"] = _alpha_for_progress(t, DAMAGE_FADE_START)
	_prepare_scaled_icon(entry, float(peak_font_size) / float(maxi(1, base_font_size)))
	return entry


static func _prepare_effect_composition(entry: Dictionary, text_length: int, base_font_size: int) -> void:
	if not entry.has("width"):
		entry["width"] = clampf(34.0 + float(text_length) * float(base_font_size) * 0.68, 86.0, 220.0)
	if not entry.has("automatic_anchor"):
		entry["automatic_anchor"] = true
	if not entry.has("alignment"):
		entry["alignment"] = HORIZONTAL_ALIGNMENT_CENTER
	if not entry.has("outline_color"):
		entry["outline_color"] = Color("1d0c08")
	if not entry.has("shadow_offset"):
		entry["shadow_offset"] = Vector2(2.0, 3.0)
	if not entry.has("shadow_color"):
		entry["shadow_color"] = Color(0.03, 0.01, 0.01, 0.72)


static func _anchor_key(entry: Dictionary) -> String:
	if not str(entry.get("anchor_id", "")).is_empty():
		return str(entry.get("anchor_id", ""))
	var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
	return "%d:%d" % [tile.x, tile.y]


static func _motion_offset(entry: Dictionary, progress: float, reduced_motion: bool) -> Vector2:
	if reduced_motion:
		return Vector2.ZERO
	var t: float = clampf(progress, 0.0, 1.0)
	var lateral_t: float = sin(t * PI * 0.5)
	var x: float = ARC_LATERAL_DRIFT * lateral_t
	var y: float
	if t <= ARC_APEX_PROGRESS:
		var rise_t: float = clampf(t / ARC_APEX_PROGRESS, 0.0, 1.0)
		y = -ARC_RISE_HEIGHT * sin(rise_t * PI * 0.5)
	else:
		var fall_t: float = clampf(
			(t - ARC_APEX_PROGRESS) / (1.0 - ARC_APEX_PROGRESS),
			0.0,
			1.0
		)
		y = lerpf(-ARC_RISE_HEIGHT, ARC_END_DROP, smoothstep(0.0, 1.0, fall_t))
	return Vector2(x, y)


static func _prepare_scaled_icon(entry: Dictionary, peak_scale: float) -> void:
	if str(entry.get("icon", "")).is_empty():
		return
	var base_icon_size: float = float(entry.get("base_icon_size", entry.get("icon_size", 22.0)))
	entry["icon_size"] = clampf(base_icon_size * peak_scale, 18.0, 42.0)


static func _alpha_for_progress(progress: float, fade_start: float) -> float:
	if progress <= fade_start:
		return 1.0
	return clampf(1.0 - ((progress - fade_start) / maxf(0.001, 1.0 - fade_start)), 0.0, 1.0)
