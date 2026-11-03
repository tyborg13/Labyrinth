extends Control

## One seekable clock drives runtime, skip and the fixed 0.70s proof.
signal confirmation
signal finished
const Palette = preload("res://scripts/ui_palette.gd")
const Burn = preload("res://scripts/heirloom_burn.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const Gilding = preload("res://scripts/ui_gilded_frame.gd")
const DURATION: float = 1.40
const CROSSFADE_SECONDS: float = 0.25
const TRAIL_SPARKS: int = 12
const TRAIL_CORE_HEX: int = 0xffd68cff
var fixed_clock: bool = false
var elapsed: float = 0.0
var reduced_motion: bool = false
var leaving_nothing: bool = false
var completed: bool = false
var _confirmed: bool = false
var _host: Node
var _view: Control
var _chosen: Control
var _flight: TextureRect
var _start: Vector2
var _target: Vector2
var _control: Vector2
var _portrait_rect: Rect2
var burns: Array[Control]

func configure(host: Node, view: Control, chosen: Control, reduced: bool) -> void:
	_host = host
	_view = view
	_chosen = chosen
	reduced_motion = reduced
	leaving_nothing = chosen == null
	name = "HeirloomCeremony"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not leaving_nothing and not reduced_motion:
		_start = view.get_global_transform().affine_inverse() * chosen.art.get_global_rect().get_center()
		_portrait_rect = host.get("_dialogue_portrait_frame").get_global_rect()
		_portrait_rect.position = view.get_global_transform().affine_inverse() * _portrait_rect.position
		_target = _portrait_rect.get_center()
		var midpoint: Vector2 = (_start + _target) * 0.5
		var perpendicular: Vector2 = (_target - _start).orthogonal().normalized()
		if perpendicular.dot(Vector2(960.0, 540.0) - midpoint) < 0.0: perpendicular = -perpendicular
		_control = midpoint + perpendicular * 300.0
		_flight = TextureRect.new()
		_flight.name = "HeirloomFlyingArt"
		_flight.texture = chosen.art.texture
		_flight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_flight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flight.size = Vector2.ONE * 192.0
		_flight.pivot_offset = _flight.size * 0.5
		add_child(_flight)
		for card: Control in view.cards:
			if card == chosen: continue
			var burn := Burn.new()
			card.get_parent().add_child(burn)
			burn.configure(card)
			burns.append(burn)
	seek(0.0)

func _process(delta: float) -> void:
	if not fixed_clock and not completed: seek(elapsed + delta)

func duration() -> float:
	return CROSSFADE_SECONDS if reduced_motion or leaving_nothing else DURATION

func skip() -> void:
	seek(duration())

func seek(seconds: float) -> void:
	if completed: return
	elapsed = clampf(seconds, 0.0, duration())
	_view.header.modulate.a = 1.0 - clampf(elapsed / CROSSFADE_SECONDS, 0.0, 1.0)
	_view.leave_button.modulate.a = _view.header.modulate.a
	if reduced_motion or leaving_nothing:
		_view.row.modulate.a = 1.0 - elapsed / CROSSFADE_SECONDS
	else:
		for burn: Control in burns: burn.seek(elapsed)
		_chosen.brightening = clampf((elapsed - 0.30) / 0.20, 0.0, 1.0) * 0.35
		_chosen.medallion.queue_redraw()
		_chosen.art.visible = elapsed < 0.30
		_flight.visible = elapsed >= 0.30 and elapsed < 1.10
		if elapsed < 0.50:
			_flight.position = _start - Vector2(0.0, 24.0 * clampf((elapsed - 0.30) / 0.20, 0.0, 1.0)) - _flight.size * 0.5
		else:
			var progress: float = _flight_progress(elapsed)
			_flight.position = _arc(progress) - _flight.size * 0.5
			_flight.scale = Vector2.ONE * lerpf(1.0, 0.45, progress)
		_chosen.modulate.a = 1.0 - clampf((elapsed - 1.10) / 0.20, 0.0, 1.0)
	if not leaving_nothing and not _confirmed and elapsed >= (CROSSFADE_SECONDS if reduced_motion else 1.10):
		_confirmed = true
		_host.get("_sfx_router").request(RunSfx.REWARD_ACCEPTED_ID)
		confirmation.emit()
	queue_redraw()
	if elapsed >= duration():
		completed = true
		finished.emit()

func _flight_progress(seconds: float) -> float:
	var t: float = clampf((seconds - 0.50) / 0.60, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _arc(t: float) -> Vector2:
	# Start at the lifted art, then use the director's quadratic control point.
	return (1.0 - t) * (1.0 - t) * (_start - Vector2(0.0, 24.0)) + 2.0 * (1.0 - t) * t * _control + t * t * _target

func _draw() -> void:
	if reduced_motion or leaving_nothing or completed: return
	if elapsed >= 0.50 and elapsed < 1.10:
		for index: int in range(TRAIL_SPARKS):
			var progress: float = _flight_progress(maxf(0.50, elapsed - float(index + 1) * 0.045))
			var point: Vector2 = _arc(progress)
			for radius: int in range(8, 0, -1):
				draw_circle(point, float(radius), Color(Palette.EMBER.lerp(Color.hex(TRAIL_CORE_HEX), 1.0 - radius / 8.0), (0.85 - index * 0.06) * (1.0 - radius / 8.0)))
	if elapsed >= 1.10:
		var alpha: float = 1.0 - clampf((elapsed - 1.10) / 0.30, 0.0, 1.0)
		var rect: Rect2 = _portrait_rect.grow(8.0)
		Gilding.draw_glow(self, rect, Color(Palette.EMBER, 0.75 * alpha), 30.0)
		var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
		draw_polyline(corners, Color(Palette.GOLD_BRIGHT, alpha), 2.0, true)

