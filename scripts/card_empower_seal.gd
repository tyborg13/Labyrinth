extends "res://scripts/ui_socket.gd"

# Empower's authored state treatment on the shared painted socket.
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Motion = preload("res://scripts/settings_store.gd")
const SOCKET_SIZE: float = 66.0
const SEAL_Z_INDEX: int = 128
const HOVER_RING_RGB := Vector3(1.25, 1.18, 1.06)
const OFFER_FILL = "#181412"
const CHARGED_FILL = "#46200E"
const BLOCKED_FILL = "#2E1212"
const EMBER_COLOR = "#FF963C"
const SLASH_COLOR = "#C8463C"
# Charge response: 0.22 s total, rising to 1.18x and back.
const CHARGE_RISE_SECONDS: float = 0.11 # Director: apex at half the 0.22 s response.
const CHARGE_EASING_CURVE: Tween.TransitionType = Tween.TRANS_QUAD # Director: quad ease-out, then ease-in.
const ICON_SHADER: String = """
shader_type canvas_item;
uniform float strength = 0.62;
uniform bool blocked = false;
void fragment() {
	vec4 pixel = COLOR;
	if (blocked) {
		pixel.rgb = vec3(dot(pixel.rgb, vec3(0.299, 0.587, 0.114)));
	} else {
		pixel.rgb = pixel.rgb * strength + vec3(30.0, 18.0, 8.0) / 255.0 * (1.0 - strength);
	}
	COLOR = pixel;
}
"""

var charged: bool = false
var blocked: bool = false
var locked: bool = false
var hint: String = "E"
var show_hint: bool = false
var _flare: float = 1.0
var _charge_tween: Tween
var _state_signature: Array = []
var _slash: Control
var _ember_material: ShaderMaterial

func _init() -> void:
	super._init()
	socket_size = SOCKET_SIZE
	z_index = SEAL_Z_INDEX
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("cursor_feedback_context", "action")
	var shader := Shader.new()
	shader.code = ICON_SHADER
	_ember_material = ShaderMaterial.new()
	_ember_material.shader = shader
	_icon.material = _ember_material
	_slash = Control.new()
	_slash.name = "BlockedSlash"
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash.draw.connect(_draw_slash)
	add_child(_slash)

func configure(on: bool, is_blocked: bool, is_locked: bool, raised: bool, glyph: String, detail: String) -> void:
	var signature: Array = [on, is_blocked, is_locked, raised, glyph, detail, Motion.applied_reduced_motion_enabled()]
	if signature == _state_signature: return
	_state_signature = signature
	var charging: bool = on and not charged
	charged = on
	blocked = is_blocked
	locked = is_locked
	show_hint = raised and not blocked
	hint = glyph
	# Keep pointer ownership and tooltip even when activation is blocked.
	focus_mode = Control.FOCUS_NONE if locked or blocked else Control.FOCUS_ALL
	setup(AssetLoader.load_texture("res://assets/art/icons/empower.png"), detail, hint if show_hint else "")
	if charging and not Motion.applied_reduced_motion_enabled():
		if _charge_tween != null: _charge_tween.kill()
		pivot_offset = size * 0.5
		_flare = 2.0
		_charge_tween = create_tween().set_parallel(true)
		_charge_tween.tween_property(self, "scale", Vector2.ONE * 1.18, CHARGE_RISE_SECONDS).set_trans(CHARGE_EASING_CURVE).set_ease(Tween.EASE_OUT)
		_charge_tween.tween_property(self, "scale", Vector2.ONE, 0.22 - CHARGE_RISE_SECONDS).set_delay(CHARGE_RISE_SECONDS).set_trans(CHARGE_EASING_CURVE).set_ease(Tween.EASE_IN)
		_charge_tween.tween_method(_set_flare, 2.0, 1.0, 0.3)
	elif not charged or Motion.applied_reduced_motion_enabled():
		if _charge_tween != null: _charge_tween.kill()
		scale = Vector2.ONE
		_flare = 1.0
	queue_redraw()

func _set_flare(value: float) -> void:
	_flare = value
	queue_redraw()

func _socket_active() -> bool:
	return not locked and not blocked and (is_hovered() or has_focus(true))

func _update_icon_material() -> void:
	if _ember_material == null: return
	_icon.material = _ember_material
	_ember_material.set_shader_parameter("strength", 1.0 if charged else (0.85 if _socket_active() else 0.62))
	_ember_material.set_shader_parameter("blocked", blocked)

func _layout() -> void:
	super._layout()
	var icon_size: float = minf(size.x, size.y) * 0.52
	_icon.size = Vector2.ONE * icon_size
	_icon.position = _ring_center(Rect2(Vector2.ZERO, size)) - _icon.size * 0.5

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var center: Vector2 = _ring_center(rect)
	var radius: float = _ring_radius(rect, "inner_radius")
	if charged:
		var halo: Color = Color.from_string(EMBER_COLOR, Color.WHITE)
		halo.a = 110.0 / 255.0
		draw_texture_rect(Surface.radial_texture(halo, 0.95), rect, false, Color(1, 1, 1, _flare))
	draw_circle(center, radius, Color.from_string(BLOCKED_FILL if blocked else (CHARGED_FILL if charged else OFFER_FILL), Color.BLACK))
	var hover_tint := Color(HOVER_RING_RGB.x, HOVER_RING_RGB.y, HOVER_RING_RGB.z)
	_ring.modulate = DISABLED_RING_TINT if blocked else (ACTIVE_RING_TINT if charged else (hover_tint if _socket_active() else ring_tint))
	_update_icon_material()
	_slash.queue_redraw()

func _draw_slash() -> void:
	if not blocked: return
	var rect := Rect2(Vector2.ZERO, size)
	var center: Vector2 = _ring_center(rect)
	var extent: float = _ring_radius(rect, "inner_radius") * 0.75
	_slash.draw_line(center + Vector2(-extent, extent), center + Vector2(extent, -extent), Color.from_string(SLASH_COLOR, Color.WHITE), size.x / SOCKET_SIZE * 3.0, true)

func _make_custom_tooltip(for_text: String) -> Object:
	return Tooltip.make_text(for_text)
