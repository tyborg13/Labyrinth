extends "res://scripts/merchant_acquisition_effect.gd"
## Reuses the merchant's arc; this receipt never owns gameplay.
const Dissolve = preload("res://scripts/enemy_shadow_dissolve_effect.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
signal arrived
const RISE_SECONDS: float = 0.18
const HOLD_SECONDS: float = 0.20
const FLIGHT_SECONDS: float = 0.50 # Merchant flight: 0.23..0.73.
const ARRIVAL_SECONDS: float = 0.26
var kind: String = "card"
var tone: String = ""
var content: Control
var replacement: Control
var destination_query: Callable
var _destination_resolved: bool = false
var _landed: bool = false
var _dissolve: Control
var _snapshot: SubViewport
var _flight_start: float = RISE_SECONDS + HOLD_SECONDS
var _reward_pool: ColorRect

static func centre_seconds(kind_id: String, tone_id: String, reduced: bool) -> float:
	if reduced: return 0.12
	if kind_id == "lose_item": return 0.40
	if kind_id in ["transform_magic", "reforge"]: return 0.45
	if tone_id == "bane": return 0.42
	return RISE_SECONDS + HOLD_SECONDS

func _ready() -> void:
	super._ready()
	_flight_start = centre_seconds(kind, tone, false)
	if tone != "bane" and kind != "lose_item": _reward_pool = Separation.pool(self, origin)
	if content != null:
		proxy.add_child(content)
		content.position = (origin.size - content.size) * 0.5
	if replacement != null:
		proxy.add_child(replacement)
		replacement.position = (origin.size - replacement.size) * 0.5
		replacement.modulate.a = 0
	if kind == "lose_item" and not reduced_motion: _prepare_dissolve()
	_update_pose()

func _prepare_dissolve() -> void:
	_snapshot = SubViewport.new()
	_snapshot.size = Vector2i(origin.size.ceil())
	_snapshot.transparent_bg = true
	_snapshot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_snapshot)
	proxy.remove_child(content)
	_snapshot.add_child(content)
	content.position = Vector2.ZERO
	_dissolve = Dissolve.new()
	proxy.add_child(_dissolve)
	_dissolve.configure(_snapshot.get_texture(), Rect2(Vector2.ZERO, origin.size), 0, 0, false)

func _process(delta: float) -> void:
	_elapsed += delta
	# New omen/relic badges get their native Container layout after the commit
	# frame. Resolve once at flight launch, after the rise/hold has elapsed.
	if not _destination_resolved and _elapsed >= _flight_start:
		_destination_resolved = true
		if destination_query.is_valid(): destination = destination_query.call()
	var arrival_time: float = _flight_start + FLIGHT_SECONDS
	if not _landed and _elapsed >= (0.12 if reduced_motion else arrival_time):
		_landed = true
		arrived.emit()
	var lifetime: float = 0.12 if reduced_motion else 0.40 if kind == "lose_item" else arrival_time + ARRIVAL_SECONDS
	if _elapsed >= lifetime:
		queue_free()
		return
	_update_pose()

func _update_pose() -> void:
	if proxy == null: return
	if _reward_pool != null:
		_reward_pool.modulate.a = Separation.recession(_elapsed, _flight_start, reduced_motion)
		var pool_scale: float = lerpf(0.8, 1.0, clampf(_elapsed / RISE_SECONDS, 0, 1)) if not reduced_motion else 1.0
		_reward_pool.position = origin.position + origin.size * (1.0 - pool_scale) * 0.5 - Vector2.ONE * Separation.POOL_MARGIN
		_reward_pool.size = origin.size * pool_scale + Vector2.ONE * Separation.POOL_MARGIN * 2.0
	if reduced_motion:
		proxy.visible = true
		proxy.position = origin.position
		proxy.scale = Vector2.ONE
		proxy.modulate.a = clampf(_elapsed / 0.12, 0, 1)
		if replacement != null:
			content.hide()
			replacement.modulate.a = 1
		return
	var rise: float = clampf(_elapsed / (Separation.BANE_STAMP_SECONDS if tone == "bane" else RISE_SECONDS), 0, 1)
	var flight: float = smoothstep(_flight_start, _flight_start + FLIGHT_SECONDS, _elapsed)
	# _path is the production merchant arc, with its 22 px lift already in it.
	proxy.position = _path(flight) + Vector2(0, 22 * (1 - flight)) - origin.size * 0.5
	proxy.scale = Vector2.ONE * lerpf(lerpf(1.6 if tone == "bane" else 0.8, 1.0, rise), 0.10, flight)
	proxy.modulate.a = 1.0 - smoothstep(0.9, 1.0, flight)
	if replacement != null:
		var crossfade: float = clampf(_elapsed / 0.45, 0, 1)
		var flash: float = sin(crossfade * PI)
		# The merchant's existing warm lift tint supplies the brief change flash.
		proxy.modulate = Color(1.0 + flash * 0.22, 1.0 + flash * 0.15, 1.0, proxy.modulate.a)
		content.modulate.a = 1 - crossfade
		replacement.modulate.a = crossfade
	if _dissolve != null:
		(_dissolve.material as ShaderMaterial).set_shader_parameter("progress", clampf(_elapsed / 0.4, 0, 1))
