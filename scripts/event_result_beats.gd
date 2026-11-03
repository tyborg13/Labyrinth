extends Control
## A disposable projection of already committed outcomes. No resolver or save writes.
const Preview = preload("res://scripts/event_reward_preview.gd")
const Gain = preload("res://scripts/event_gain_effect.gd")
const Data = preload("res://scripts/game_data.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const EmberFeedback = preload("res://scripts/ember_reward_feedback.gd")
const Sounds = preload("res://scripts/run_sfx_library.gd")
const Omens = preload("res://scripts/omen_badges.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
const STAGGER_SECONDS: float = 0.25
const EMBER_CUE: String = "pickup.item"
const BANE_CUE: String = "omen.bane"
const BLESSING_CUE: String = "omen.blessing"
# Existing combat-board impact waveform (0.09 radians per millisecond).
const COMBAT_SHAKE_RADIANS_PER_SECOND: float = 90.0
# The combat atmosphere's existing hurt-edge shape, without its ambient pool.
const HURT_EDGE_SHADER: String = """
shader_type canvas_item;
varying vec2 edge_uv;
void vertex() { edge_uv = VERTEX / vec2(1920.0,1080.0); }
void fragment() {
 vec2 q = (edge_uv - vec2(0.5)) * 2.0;
 float edge = length(q * vec2(1.0,0.92)) / 1.36;
 COLOR.a *= smoothstep(0.42,1.05,edge);
}
"""
signal finished
var view: Control
var before: Dictionary
var after: Dictionary
var destinations: Dictionary
var cue: Callable
var reduced: bool = false
var outcomes: Array
var start_times: Array[float]
var _next: int = 0
var _elapsed: float = 0
var _last_damage: float = -1
var _last_bane: float = -1
var _stopped: bool = false
var _pulses: Dictionary = {}
var _ember_label: Label
var _ember_from: int = 0
var _ember_to: int = 0
var _ember_values: Array
var _ember_started: float = -1
var _ember_original_scale: Vector2
var _ember_original_modulate: Color
var _ember_roll: Callable
var _ember_pulse: Tween
var _health_current: float
var _health_max: float
var _painting_release_at: float = -1

func _ready() -> void:
	name = "EventResultBeats"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = HURT_EDGE_SHADER
	var edge_material := ShaderMaterial.new()
	edge_material.shader = shader
	material = edge_material
	outcomes = after.get("event_state", {}).get("outcomes", []).duplicate(true)
	start_times = schedule(outcomes, reduced)
	# Own one uninterrupted recession across the entire receipt, including
	# Health/resource beats before or between its centre objects.
	for index: int in range(outcomes.size()):
		var kind: String = str(outcomes[index].get("type", ""))
		if not is_centre_beat(kind): continue
		var tone: String = str(Data.omen_def(str(outcomes[index].get("id", ""))).get("kind", "")) if kind == "omen" else ""
		var centre_seconds: float = Separation.BANE_STAMP_SECONDS if tone == "bane" else Gain.centre_seconds(kind, tone, reduced)
		_painting_release_at = maxf(_painting_release_at, start_times[index] + centre_seconds)
	view.hover_preview.preserve_painting = _painting_release_at >= 0 and not reduced
	_health_current = float(before.get("player_hp", 0))
	_health_max = float(before.get("player_max_hp", 1))
	view.health.set_health(_health_current, _health_max)
	_ember_from = int(before.get("held_embers", before.get("unbanked_embers", 0)))
	_ember_to = _ember_from
	_process(0)

func _process(delta: float) -> void:
	if _stopped: return
	_elapsed += delta
	while _next < outcomes.size() and _elapsed >= start_times[_next]:
		_start_beat(outcomes[_next], start_times[_next])
		_next += 1
	_update_ember()
	_update_panel()
	if _next == outcomes.size() and get_child_count() == 0 and _pulses.is_empty() and _elapsed >= (start_times.back() if not start_times.is_empty() else 0.0) + 0.85: finish()
	queue_redraw()

static func is_centre_beat(kind: String) -> bool:
	return kind in ["card", "item", "relic", "equipment", "omen", "defiance", "lose_item", "transform_magic", "reforge"]

static func schedule(entries: Array, reduced_motion: bool) -> Array[float]:
	var result: Array[float]
	var next_start: float = 0
	var centre_available: float = 0
	for entry: Dictionary in entries:
		var kind: String = str(entry.get("type", ""))
		var start: float = maxf(next_start, centre_available) if is_centre_beat(kind) else next_start
		result.append(start)
		if is_centre_beat(kind):
			var tone: String = str(Data.omen_def(str(entry.get("id", ""))).get("kind", "")) if kind == "omen" else ""
			centre_available = start + Gain.centre_seconds(kind, tone, reduced_motion)
		next_start = start + STAGGER_SECONDS
	return result

func _start_beat(outcome: Dictionary, started_at: float) -> void:
	var kind: String = str(outcome.get("type", ""))
	var amount: int = int(outcome.get("amount", 0))
	if kind in ["hp", "heal", "heal_percent", "max_hp"]:
		if kind == "max_hp":
			_health_max = maxf(1, _health_max + amount)
			_health_current = minf(_health_max, _health_current + maxi(0, amount))
		else: _health_current = clampf(_health_current + amount, 1, _health_max)
		view.health.beat(kind, amount, reduced, _health_current, _health_max)
		if kind == "hp" and amount < 0: _last_damage = started_at; _play("hurt.hero")
		elif kind in ["heal", "heal_percent"] and amount > 0: _play("heal")
		return
	if kind == "embers":
		_start_embers(amount)
		_play(EMBER_CUE)
		return
	if kind in ["scout", "reveal"]:
		_pulse(destinations.get("map", {}))
		return
	if kind == "card_choice" or kind == "nothing_changed": return # An offer grants no card until claimed.
	if kind not in ["card", "item", "relic", "equipment", "omen", "defiance", "lose_item", "transform_magic", "reforge"]: return
	var effect := Gain.new()
	effect.kind = kind
	effect.reduced_motion = reduced
	effect._elapsed = maxf(0, _elapsed - started_at)
	var line: Dictionary = Preview.outcome_line(outcome)
	var destination_kind: String = "deck" if kind in ["card", "transform_magic"] else "loadout" if kind in ["equipment", "item", "reforge"] else kind
	if kind == "omen":
		effect.tone = str(Data.omen_def(str(outcome["id"])).get("kind", ""))
		destination_kind = "omen:" + str(outcome["id"])
		if effect.tone == "bane": _last_bane = started_at
		_play(BANE_CUE if effect.tone == "bane" else BLESSING_CUE)
	elif kind != "lose_item": _play("pickup.item" if kind == "item" else "pickup.gear" if kind in ["equipment", "reforge"] else Sounds.REWARD_ACCEPTED_ID)
	if kind == "defiance": line["ids"] = ["defiance"]
	if kind in ["transform_magic", "reforge"]:
		effect.content = Preview.build({"kind": "equipment" if kind == "reforge" else "card", "ids": [outcome["from"]]}, before, true)
		effect.replacement = Preview.build({"kind": "equipment" if kind == "reforge" else "card", "ids": [outcome["to"]]}, after, true)
	else: effect.content = Preview.build(line, after, true)
	var extent: Vector2 = effect.content.size
	if effect.replacement != null: extent = extent.max(effect.replacement.size)
	effect.origin = Rect2(view.painting_center() - extent * 0.5, extent)
	var target: Dictionary = destinations.get(destination_kind, {})
	effect.destination = _target_position(target)
	effect.destination_query = _target_position.bind(target)
	effect.arrived.connect(func() -> void:
		if not _stopped: _pulse(target, kind == "omen"))
	add_child(effect)

func _target_position(target: Dictionary) -> Vector2:
	var control: Control = target.get("control")
	var point: Vector2 = control.get_global_rect().get_center() if is_instance_valid(control) else target.get("position", view.get_global_transform() * view.painting_center())
	return get_global_transform().affine_inverse() * point

func _pulse(target: Dictionary, omen: bool = false) -> void:
	var control: Control = target.get("control")
	if not is_instance_valid(control): return
	if _pulses.has(control):
		(_pulses[control]["tween"] as Tween).kill()
		control.scale = _pulses[control]["scale"]
	else: _pulses[control] = {"scale": control.scale, "pivot": control.pivot_offset}
	control.pivot_offset = control.size * 0.5
	var original: Vector2 = _pulses[control]["scale"]
	if omen and control.has_method("gain"): control.gain(reduced)
	var motion := create_tween()
	_pulses[control]["tween"] = motion
	if reduced:
		motion.tween_interval(0.12)
	elif omen and control.has_method("gain"):
		motion.tween_interval(0.25)
	else:
		motion.tween_property(control, "scale", original * 1.18, 0.125)
		motion.tween_property(control, "scale", original, 0.125)
	motion.tween_callback(func() -> void:
		if is_instance_valid(control):
			control.scale = original
			control.pivot_offset = _pulses.get(control, {}).get("pivot", control.pivot_offset)
		_pulses.erase(control))

func _start_embers(amount: int) -> void:
	var target: Dictionary = destinations.get("embers", {})
	_ember_label = target.get("control") as Label
	_ember_roll = target.get("update", Callable())
	_ember_from = _ember_to
	_ember_to += amount
	_ember_values = EmberFeedback.roll_values(_ember_from, _ember_to)
	_ember_started = _elapsed
	if _ember_label != null:
		if _ember_pulse != null:
			_ember_pulse.kill()
			_ember_label.scale = _ember_original_scale
			_ember_label.modulate = _ember_original_modulate
		_ember_original_scale = _ember_label.scale
		_ember_original_modulate = _ember_label.modulate
		_ember_pulse = EmberFeedback._start_counter_pulse(self, _ember_label, reduced)
		EmberFeedback._spawn_gain_label(self, self, _ember_label, amount, reduced)
	if not reduced and amount != 0:
		var sparks := EmberSparks.new()
		sparks.origin = view.painting_center()
		sparks.destination = _target_position(target)
		add_child(sparks)

func _update_ember() -> void:
	if _ember_started < 0: return
	var progress: float = clampf((_elapsed - _ember_started) / EmberFeedback.ROLL_SECONDS, 0, 1)
	if _ember_roll.is_valid() and not _ember_values.is_empty():
		var index: int = mini(_ember_values.size() - 1, floori(progress * _ember_values.size()))
		_ember_roll.call(int(_ember_values[index]))
	if progress >= 1: _ember_started = -1

func _update_panel() -> void:
	var offset := Vector2.ZERO
	var damage_age: float = _elapsed - _last_damage
	var bane_age: float = _elapsed - _last_bane
	if not reduced and _last_damage >= 0 and damage_age < 0.18: offset.x += sin(damage_age * COMBAT_SHAKE_RADIANS_PER_SECOND) * 6 * pow(1 - damage_age / 0.18, 2)
	if not reduced and _last_bane >= 0 and bane_age < 0.12: offset.y += sin(bane_age / 0.12 * PI) * 3
	view.panel.position = view.PANEL_RECT.position + offset
	if _painting_release_at >= 0:
		var strength: float = 0.0 if reduced else 1.0 - clampf((_elapsed - _painting_release_at) / Separation.PAINTING_RETURN_SECONDS, 0, 1)
		view.set_preview_brightness(lerpf(1.0, Separation.PAINTING_BRIGHTNESS, strength))

func _draw() -> void:
	if reduced or _last_damage < 0: return
	var alpha: float = 0.28 * (1 - clampf((_elapsed - _last_damage) / 0.35, 0, 1))
	draw_rect(Rect2(Vector2.ZERO, view.REFERENCE_SIZE), Color(Palette.DANGER, alpha))

func _play(id: String) -> void:
	if not id.is_empty() and cue.is_valid(): cue.call(id)

func finish() -> void:
	if _stopped: return
	_stopped = true
	set_process(false)
	for child: Node in get_children(): remove_child(child); child.free()
	for control: Control in _pulses:
		(_pulses[control]["tween"] as Tween).kill()
		if is_instance_valid(control):
			if control.has_method("finish_gain"): control.finish_gain()
			control.scale = _pulses[control]["scale"]
			control.pivot_offset = _pulses[control]["pivot"]
	_pulses.clear()
	if _ember_pulse != null: _ember_pulse.kill()
	if is_instance_valid(_ember_label):
		_ember_label.scale = _ember_original_scale
		_ember_label.modulate = _ember_original_modulate
	if _ember_roll.is_valid(): _ember_roll.call(int(after.get("held_embers", after.get("unbanked_embers", 0))))
	view.health.finish(int(after.get("player_hp", 0)), int(after.get("player_max_hp", 1)))
	view.panel.position = view.PANEL_RECT.position
	view.hover_preview.preserve_painting = false
	view.set_preview_brightness(1)
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	# Scene replacement also cancels external HUD pulses synchronously.
	if not _stopped: finish()

class EmberSparks extends Control:
	var origin: Vector2
	var destination: Vector2
	var age: float = 0
	func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		age += delta
		if age > Gain.FLIGHT_SECONDS: queue_free()
		queue_redraw()
	func _draw() -> void:
		for index: int in range(8):
			var t: float = clampf((age - index * 0.018) / (Gain.FLIGHT_SECONDS - 7 * 0.018), 0, 1)
			var point: Vector2 = origin.lerp(destination, t) + Vector2(0, -sin(t * PI) * 105)
			draw_circle(point, (2 + index % 3) * sin(t * PI), Palette.EMBER)
