extends RefCounted

const UiTypography = preload("res://scripts/ui_typography.gd")

const ROLL_SECONDS: float = 0.16
const ROLL_MAX_STEPS: int = 6
const PULSE_IN_SECONDS: float = 0.06
const SETTLE_SECONDS: float = 0.12
const GAIN_LABEL_RISE: float = 8.0

static func play(host: Node, fx_layer: Control, stats_label: Label, amount: int, from_count: int, to_count: int, reduced_motion: bool, update_count: Callable) -> void:
	if stats_label == null:
		return
	var values: Array = roll_values(from_count, to_count)
	if values.is_empty():
		update_count.call(to_count)
		return
	var gain_label: Label = _spawn_gain_label(host, fx_layer, stats_label, amount, reduced_motion)
	var pulse: Tween = _start_counter_pulse(host, stats_label, reduced_motion)
	var roll_seconds: float = ROLL_SECONDS * (0.55 if reduced_motion else 1.0)
	var step_seconds: float = roll_seconds / float(values.size())
	for value_var: Variant in values:
		update_count.call(int(value_var))
		await host.get_tree().create_timer(step_seconds).timeout
	update_count.call(to_count)
	if pulse != null and pulse.is_valid():
		await pulse.finished
	if _node_is_alive(gain_label):
		gain_label.visible = false
		gain_label.queue_free()

static func roll_values(from_count: int, to_count: int) -> Array:
	var values: Array = []
	var difference: int = absi(to_count - from_count)
	if difference == 0:
		return values
	var step_count: int = mini(difference, ROLL_MAX_STEPS)
	for step: int in range(1, step_count + 1):
		var progress: float = float(step) / float(step_count)
		var value: int = roundi(lerpf(float(from_count), float(to_count), progress))
		if values.is_empty() or int(values.back()) != value:
			values.append(value)
	if int(values.back()) != to_count:
		values.append(to_count)
	return values

static func total_amount(rewards: Array) -> int:
	var total: int = 0
	for reward_var: Variant in rewards:
		if reward_var is Dictionary:
			total += maxi(0, int((reward_var as Dictionary).get("embers", 0)))
	return total

static func _spawn_gain_label(host: Node, fx_layer: Control, stats_label: Label, amount: int, reduced_motion: bool) -> Label:
	if fx_layer == null or amount <= 0:
		return null
	var label := Label.new()
	label.name = "EmberGainLabel"
	label.text = "+%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1700
	label.set_meta("ember_counter_feedback", true)
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("ffd67a"))
	label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	label.add_theme_constant_override("outline_size", 2)
	fx_layer.add_child(label)
	label.size = label.get_combined_minimum_size()
	var stats_rect: Rect2 = stats_label.get_global_rect()
	var local_stats_position: Vector2 = stats_rect.position - fx_layer.global_position
	label.position = local_stats_position + Vector2(stats_rect.size.x - label.size.x, stats_rect.size.y - 2.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var rise: float = GAIN_LABEL_RISE * (0.35 if reduced_motion else 1.0)
	var tween: Tween = host.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.04)
	tween.parallel().tween_property(label, "position:y", label.position.y - rise * 0.25, 0.04)
	tween.tween_interval(0.04 if not reduced_motion else 0.0)
	tween.tween_property(label, "position:y", label.position.y - rise, 0.12 if not reduced_motion else 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.12 if not reduced_motion else 0.06)
	tween.finished.connect(label.queue_free)
	return label

static func _start_counter_pulse(host: Node, stats_label: Label, reduced_motion: bool) -> Tween:
	stats_label.pivot_offset = stats_label.size * 0.5
	stats_label.scale = Vector2.ONE
	stats_label.modulate = Color.WHITE
	var tween: Tween = host.create_tween()
	if reduced_motion:
		tween.tween_property(stats_label, "modulate", Color(1.0, 0.92, 0.72, 1.0), 0.04)
		tween.tween_property(stats_label, "modulate", Color.WHITE, 0.08)
		return tween
	tween.tween_property(stats_label, "scale", Vector2(1.035, 1.035), PULSE_IN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(stats_label, "modulate", Color(1.0, 0.90, 0.66, 1.0), PULSE_IN_SECONDS)
	tween.tween_property(stats_label, "scale", Vector2.ONE, SETTLE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(stats_label, "modulate", Color.WHITE, SETTLE_SECONDS)
	return tween

static func _node_is_alive(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion()
