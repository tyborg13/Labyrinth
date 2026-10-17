extends CanvasLayer
## Owns the uninterrupted dragon-reward -> next threshold presentation.
## The cleared-boss save remains the replay source until destination persistence succeeds.

signal finished
signal arrived

const Graph = preload("res://scripts/section_map_graph.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Music = preload("res://scripts/music_library.gd")
const RoomReveal = preload("res://scripts/menu_run_transition.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Reward = preload("res://scripts/section_transition_reward.gd")

const MapPanel = preload("res://scripts/section_map_panel.gd")

const MAP_CROSSFADE_SECONDS: float = 0.40
const SKIP_CROSSFADE_SECONDS: float = 0.12
const REWARD_FADE_SECONDS: float = 0.24
const REDUCED_REWARD_FADE_SECONDS: float = 0.12
const DESCENT_SECONDS: float = 0.70
const CAMERA_DESCENT_PX: float = 140.0
const CARD_SECONDS: float = 1.90
const CARD_FADE_SECONDS: float = 0.50
const PUSH_SCALE: float = 1.05
const TEXT_AT: float = 0.95
const TEXT_SECONDS: float = 0.45
const TEXT_RISE_PX: float = 8.0
const ARRIVAL_AT: float = 2.60
const ARRIVAL_FADE_SECONDS: float = 0.30
const FINISH_AT: float = 3.20
const SKIP_AT: float = 0.40
const REDUCED_CROSSFADE_SECONDS: float = 0.30
const REDUCED_HOLD_SECONDS: float = 1.40
const EYEBROW_SIZE: int = 24
const TITLE_SIZE: int = 64
const EYEBROW_Y: float = 470.0
const TITLE_Y: float = 540.0
const TEXT_BAND_HALF_HEIGHT: float = 130.0
const TEXT_BAND_CENTRE_Y: float = (EYEBROW_Y + TITLE_Y) * 0.5
const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
# Non-perceptible canvas ordering; above all run overlays.
const OVERLAY_LAYER: int = 100
const CLAIMED_REWARD_KEY: String = Reward.KEY
const SAVE_FAILURE_NOTICE: String = "Could not save. Your rewards are still here; try Continue again."
const TEXT_BAND_SHADER: String = """
shader_type canvas_item;
void fragment() {
	COLOR.a *= 0.50 * (1.0 - abs(UV.y * 2.0 - 1.0));
}
"""
const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform float strength = 1.0;
void fragment() {
	float radius = clamp(length((SCREEN_UV - vec2(0.5)) * 2.0), 0.0, 1.0);
	COLOR.rgb *= 1.0 - radius * 0.60 * strength;
}
"""

var elapsed: float = 0.0
var reduced_motion: bool = false
var active: bool = false
var destination: Vector2i = Graph.INVALID
var entry: String
var _host: Control
var _board: Control
var _board_origin: Vector2
var _reward_items: Array[CanvasItem]
var _reward_modulates: Array[Color]
var _surface: Control
var _black: ColorRect
var _card: Control
var _art: Control
var _arrival_shade: ColorRect
var _painting: TextureRect
var _eyebrow: Label
var _title: Label
var _text_band: ColorRect
var _arrival_start: float = -1.0
var _entered: bool = false
var _map_arrival: bool = false
var _skipped: bool = false
var _map_scrim: ColorRect
var _map_parent: Node
var _map_index: int
var _map_color: Color
var _map_modulate: Color
var _map_background: TextureRect
var _map_background_visible: bool
var _map_mouse_behavior: int
var _map_focus_behavior: int
var _return_start: float = -1.0
var _music: AudioStreamPlayer
var _music_volume: float = 0.0
var _lock_was_set: bool = false
var _cursor_feedback: Node
var _cursor_owner: String

static func arrival_at(reduced: bool) -> float:
	return REDUCED_CROSSFADE_SECONDS + REDUCED_HOLD_SECONDS if reduced else ARRIVAL_AT

static func duration(reduced: bool) -> float:
	return arrival_at(true) + ARRIVAL_FADE_SECONDS + entry_reveal_seconds(reduced) if reduced else FINISH_AT

static func map_crossfade_seconds(reduced: bool, skipped: bool = false) -> float:
	if skipped: return SKIP_CROSSFADE_SECONDS
	return REDUCED_CROSSFADE_SECONDS if reduced else MAP_CROSSFADE_SECONDS

static func map_duration(reduced: bool) -> float:
	return arrival_at(reduced) + map_crossfade_seconds(reduced)

static func entry_reveal_seconds(reduced: bool) -> float:
	return Settings.motion_duration(RoomReveal.REVEAL_SECONDS, {"reduced_motion": reduced})

static func reward_fade_seconds(reduced: bool) -> float:
	return REDUCED_REWARD_FADE_SECONDS if reduced else REWARD_FADE_SECONDS

# Persist only presentation metadata alongside the already committed claim.
# A failed arrival can reconstruct its screen without reissuing a claim receipt.
static func remember_claim(state: Dictionary, reward: Dictionary) -> void:
	if not Graph.enabled(state) or bool(reward.get("final_boss", false)): return
	state[CLAIMED_REWARD_KEY] = reward.duplicate(true)
	state[CLAIMED_REWARD_KEY]["intro_pending"] = false

static func claimed_state(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	# An older failed arrival could itself be saved as an empty reward screen.
	# Only Flow's cleared-boss/unentered-section gates authorize its movement.
	var legacy_empty_reward: bool = str(next.get("mode", "")) == "reward" and (next.get("pending_reward", {}) as Dictionary).is_empty() and not str(next.get("last_dragon_milestone", "")).is_empty()
	if not (next.get(CLAIMED_REWARD_KEY, {}) as Dictionary).is_empty() or legacy_empty_reward:
		next["mode"] = "room"
		next["pending_reward"] = {}
	return next

# The live overlay, headless timing checks and real-renderer strip share this
# exact timeline. A skip starts the same arrival from the current black level.
static func presentation_at(seconds: float, reduced: bool) -> Dictionary:
	var descent: float = clampf((seconds - REWARD_FADE_SECONDS) / (DESCENT_SECONDS - REWARD_FADE_SECONDS), 0.0, 1.0)
	var text: float = clampf((seconds - TEXT_AT) / TEXT_SECONDS, 0.0, 1.0)
	return {
		"reward_alpha": 1.0 - clampf(seconds / reward_fade_seconds(reduced), 0.0, 1.0),
		"black": 0.0 if reduced else pow(descent, 3.0),
		"camera_y": 0.0 if reduced else -CAMERA_DESCENT_PX * pow(descent, 3.0),
		"card_alpha": clampf(seconds / REDUCED_CROSSFADE_SECONDS, 0.0, 1.0) if reduced else clampf((seconds - DESCENT_SECONDS) / CARD_FADE_SECONDS, 0.0, 1.0),
		"painting_scale": 1.0 if reduced else lerpf(1.0, PUSH_SCALE, clampf((seconds - DESCENT_SECONDS) / CARD_SECONDS, 0.0, 1.0)),
		"text_alpha": text,
		"text_y": TEXT_RISE_PX * (1.0 - text),
		"music_gain": 1.0 - clampf(seconds / DESCENT_SECONDS, 0.0, 1.0),
	}

func begin(host: Control, target: Vector2i, entry_kind: String) -> void:
	name = "SectionTransition"
	layer = OVERLAY_LAYER
	_host = host
	_cursor_feedback = host.get_node_or_null("/root/CursorFeedback")
	_cursor_owner = "section_transition_%d" % get_instance_id()
	if is_instance_valid(_cursor_feedback): _cursor_feedback.call("set_glyph_visibility_suppressed", _cursor_owner, true)
	destination = target
	entry = entry_kind
	_map_arrival = bool(host.get("_start_room_map").transition_opens_map(host, target))
	reduced_motion = bool(host.call("_reduced_motion_enabled"))
	_board = host.get("board_view")
	_board_origin = _board.position
	var centering: Tween = host.get("_board_centering_tween")
	if centering != null and centering.is_valid(): centering.kill()
	for field: String in ["_relic_choice_host", "_relic_choice_banner", "_relic_choice_title", "_relic_choice_title_effect"]:
		var item: CanvasItem = host.get(field)
		if is_instance_valid(item):
			_reward_items.append(item)
			_reward_modulates.append(item.modulate)
	_music = host.get("_music_player")
	if is_instance_valid(_music): _music_volume = _music.volume_linear
	host.call("_stop_music_tween")
	_lock_was_set = bool(host.get("_animation_lock"))
	host.set("_animation_lock", true)
	host.call("_close_large_map")
	var focus: Control = host.get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	_build(Graph.section(host.get("_run_state"), Graph.active_section(host.get("_run_state")) + 1))
	active = true
	_apply()

func _build(info: Dictionary) -> void:
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_surface)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_fill(_black, _surface)
	_card = Control.new()
	_card.clip_contents = true
	_fill(_card, _surface)
	_art = Control.new()
	_fill(_art, _card)
	_painting = TextureRect.new()
	_painting.name = "SectionPainting"
	_painting.texture = Assets.load_texture("res://assets/art/backgrounds/sections/%s.png" % str(info.get("boss_id", "")))
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill(_painting, _art)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	# Shade the painting in the same draw so its black fade remains linear.
	# Screen coordinates keep the vignette still while the painting pushes in.
	_painting.material = material
	_text_band = ColorRect.new()
	_text_band.name = "SectionTextBand"
	_text_band.color = Color.BLACK
	_fill(_text_band, _card)
	var band_shader := Shader.new()
	band_shader.code = TEXT_BAND_SHADER
	var band_material := ShaderMaterial.new()
	band_material.shader = band_shader
	_text_band.material = band_material
	_eyebrow = Label.new()
	_eyebrow.name = "SectionNumeral"
	_eyebrow.text = "SECTION " + ["I", "II", "III", "IV", "V", "VI"][clampi(int(info.get("index", 0)), 0, 5)]
	Typography.apply_eyebrow(_eyebrow, EYEBROW_SIZE, Palette.GOLD_BRIGHT)
	_fill(_eyebrow, _card)
	_title = Label.new()
	_title.name = "SectionHeading"
	_title.text = str(info.get("title", ""))
	_title.add_theme_font_override("font", Typography.display_font())
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", Palette.TEXT)
	_fill(_title, _card)
	# A fresh claimed-room resume has no visible reward screen to style first.
	# Resolve the same restrained reward-banner role before copying its shadow.
	_host.call("_apply_relic_choice_title_depth", _host.call("_relic_choice_title_accent", "DRAGON VANQUISHED"), true)
	for label: Label in [_eyebrow, _title]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Copy the live reward banner's existing shadow, including theme fallbacks.
		var reward_title: Label = _host.get("_relic_choice_title")
		label.add_theme_color_override("font_shadow_color", reward_title.get_theme_color("font_shadow_color"))
		for key: String in ["shadow_offset_x", "shadow_offset_y"]:
			label.add_theme_constant_override(key, reward_title.get_theme_constant(key))
	_arrival_shade = ColorRect.new()
	_arrival_shade.color = Color.BLACK
	_fill(_arrival_shade, _surface)

func _fill(control: Control, parent: Control) -> void:
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not active: return
	advance(delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0)

func advance(seconds: float) -> void:
	if not active: return
	elapsed += seconds
	if _return_start >= 0.0:
		_apply_return()
		if elapsed >= _return_start + reward_fade_seconds(reduced_motion): _finish()
		return
	if _arrival_start < 0.0 and elapsed >= arrival_at(reduced_motion):
		_arrival_start = arrival_at(reduced_motion)
	var entry_delay: float = 0.0 if _map_arrival else ARRIVAL_FADE_SECONDS
	if _arrival_start >= 0.0 and not _entered and elapsed >= _arrival_start + entry_delay:
		_enter()
		if _return_start >= 0.0:
			_apply_return()
			return
	_apply()
	var end: float = _arrival_start + (map_crossfade_seconds(reduced_motion, _skipped) if _map_arrival else duration(reduced_motion) - arrival_at(reduced_motion))
	if _arrival_start >= 0.0 and elapsed >= end:
		_finish()

func _finish() -> void:
	cancel()
	finished.emit()
	if is_instance_valid(_host):
		_host.call("_refresh_ui")
		_host.call_deferred("_recover_controller_focus")

func contain_input(event: InputEvent) -> void:
	if not active: return
	var router: Node = _host.get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	var skip: bool = false
	if event is InputEventMouseButton: skip = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventJoypadButton: skip = event.pressed and event.button_index == JOY_BUTTON_A
	elif event is InputEventKey: skip = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]
	if skip and elapsed >= SKIP_AT and _arrival_start < 0.0 and _return_start < 0.0:
		_arrival_start = elapsed
		_skipped = true

func _input(event: InputEvent) -> void:
	if not active: return
	contain_input(event)
	get_viewport().set_input_as_handled()

func _apply() -> void:
	var pose: Dictionary = presentation_at(minf(elapsed, _arrival_start) if _arrival_start >= 0.0 else elapsed, reduced_motion)
	if not _entered:
		_board.position = _board_origin + Vector2(0.0, float(pose["camera_y"]))
		_fade_reward(float(pose["reward_alpha"]))
		if is_instance_valid(_music): _music.volume_linear = _music_volume * float(presentation_at(elapsed, reduced_motion)["music_gain"])
	_black.modulate.a = float(pose["black"])
	_art.modulate.a = float(pose["card_alpha"])
	_arrival_shade.modulate.a = 0.0
	_painting.pivot_offset = _surface.size * 0.5
	_painting.scale = Vector2.ONE * float(pose["painting_scale"])
	var ratio: Vector2 = _surface.size / REFERENCE_SIZE
	_text_band.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_text_band.position = Vector2(0.0, (TEXT_BAND_CENTRE_Y + float(pose["text_y"]) - TEXT_BAND_HALF_HEIGHT) * ratio.y)
	_text_band.size = Vector2(_surface.size.x, TEXT_BAND_HALF_HEIGHT * 2.0 * ratio.y)
	_text_band.modulate.a = float(pose["text_alpha"])
	for label: Label in [_eyebrow, _title]:
		var center_y: float = EYEBROW_Y if label == _eyebrow else TITLE_Y
		label.position = Vector2(0.0, (center_y + float(pose["text_y"])) * ratio.y - _surface.size.y * 0.5)
		label.modulate.a = float(pose["text_alpha"])
	if _arrival_start < 0.0: return
	if _map_arrival and _entered:
		_apply_map_arrival(pose)
		return
	if not _entered:
		_arrival_shade.modulate.a = clampf((elapsed - _arrival_start) / ARRIVAL_FADE_SECONDS, 0.0, 1.0)
	else:
		_card.hide()
		_black.hide()
		var reveal: float = entry_reveal_seconds(reduced_motion)
		_arrival_shade.modulate.a = 0.0 if reveal <= 0.0 else 1.0 - float(Tween.interpolate_value(0.0, 1.0, clampf(elapsed - _arrival_start - ARRIVAL_FADE_SECONDS, 0.0, reveal), reveal, Tween.TRANS_SINE, Tween.EASE_IN_OUT))

func _enter() -> void:
	_board.position = _board_origin
	var saved: bool = bool(_host.call("_enter_section_from_transition", destination, entry))
	if not saved:
		_return_to_reward()
		return
	_entered = true
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	_host.set("_active_music_id", "")
	# Loading may still have reserved the old boss music. Release that reservation
	# exactly here, and use the ordinary destination-room music selection/fade.
	_host.set("_initial_music_deferred", false)
	var room: Dictionary = _host.get("_run_engine").room_metadata(_host.get("_run_state"), _host.get("_run_state").get("current_room"))
	# Open the actual map under the still-opaque title card before any draw can
	# reveal the board. Consuming the visit prevents a second deferred handoff.
	if _map_arrival:
		_host.get("_start_room_map").present_transition_map(_host)
		_prepare_map_arrival()
	var planning: bool = _map_arrival
	_host.call("_play_music", Music.entry_for_context("room", room, {}, planning))
	arrived.emit()

func _prepare_map_arrival() -> void:
	_map_scrim = _host.get("_large_map_scrim")
	_map_parent = _map_scrim.get_parent()
	_map_index = _map_scrim.get_index()
	_map_color = _map_scrim.color
	_map_modulate = _map_scrim.modulate
	_map_focus_behavior = _map_scrim.focus_behavior_recursive
	_map_scrim.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_map_mouse_behavior = _map_scrim.mouse_behavior_recursive
	_map_scrim.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_map_background = _host.get("_large_map_view").call("transition_backdrop")
	_map_background_visible = _map_background.visible
	# Reuse all live map controls and their ordinary layout. Only their drawing
	# moves above the painting; no duplicate scene or surrogate map is involved.
	_release_map_focus()
	_map_scrim.reparent(_surface, false)
	_map_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if reduced_motion or _skipped:
		# No framing motion: cross-fade the stationary title into the real map.
		_map_scrim.color.a = 1.0
	else:
		_map_scrim.color = Color.TRANSPARENT
		_map_background.hide()
	_map_scrim.modulate.a = 0.0
	# Keep the authored text fade independent of the map's background alpha.
	for item: CanvasItem in [_text_band, _eyebrow, _title]:
		item.z_index = _map_scrim.z_index + 1

func _apply_map_arrival(pose: Dictionary) -> void:
	var seconds: float = map_crossfade_seconds(reduced_motion, _skipped)
	var progress: float = clampf((elapsed - _arrival_start) / seconds, 0.0, 1.0)
	var blend: float = float(Tween.interpolate_value(0.0, 1.0, progress * seconds, seconds, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT))
	_black.modulate.a = 1.0 # Opaque coverage remains behind both presentations.
	_map_scrim.modulate.a = blend
	_text_band.modulate.a = float(pose["text_alpha"]) * (1.0 - blend)
	_eyebrow.modulate.a = _text_band.modulate.a
	_title.modulate.a = _text_band.modulate.a
	if reduced_motion or _skipped: return
	# The map painting occupies its content field rather than the full screen.
	# Land on that exact cover-fit rectangle and scale, including settled native
	# container geometry, so returning the real backdrop cannot produce a jump.
	var target: Rect2 = _surface.get_global_transform().affine_inverse() * _map_background.get_global_rect()
	var rect := Rect2(Vector2.ZERO.lerp(target.position, blend), _surface.size.lerp(target.size, blend))
	_painting.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_painting.position = rect.position
	_painting.size = rect.size
	_painting.pivot_offset = rect.size * 0.5
	_painting.scale = Vector2.ONE * lerpf(float(pose["painting_scale"]), 1.0, blend)
	_painting.modulate = Color.WHITE.lerp(MapPanel.BACKGROUND_MODULATE, blend)
	(_painting.material as ShaderMaterial).set_shader_parameter("strength", 1.0 - blend)

func _restore_map() -> void:
	if not is_instance_valid(_map_scrim): return
	_map_scrim.color = _map_color
	_map_scrim.modulate = _map_modulate
	_map_scrim.mouse_behavior_recursive = _map_mouse_behavior
	_map_scrim.focus_behavior_recursive = _map_focus_behavior
	if is_instance_valid(_map_background): _map_background.visible = _map_background_visible
	if is_instance_valid(_map_parent):
		_release_map_focus()
		_map_scrim.reparent(_map_parent, false)
		_map_parent.move_child(_map_scrim, _map_index)
		_map_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_scrim = null

func _release_map_focus() -> void:
	if not _map_scrim.is_inside_tree(): return
	var focus: Control = _map_scrim.get_viewport().gui_get_focus_owner()
	if focus != null and _map_scrim.is_ancestor_of(focus): focus.release_focus()

func _fade_reward(alpha: float) -> void:
	for index: int in range(_reward_items.size()):
		if is_instance_valid(_reward_items[index]): _reward_items[index].modulate.a = _reward_modulates[index].a * alpha

func _return_to_reward() -> void:
	_return_start = elapsed
	var state: Dictionary = _host.get("_run_state")
	state["mode"] = "reward"
	state["pending_reward"] = (state.get(CLAIMED_REWARD_KEY, {}) as Dictionary).duplicate(true)
	state["notice"] = SAVE_FAILURE_NOTICE
	_host.call("_refresh_ui")
	_card.hide()
	_black.hide()
	_board.position = _board_origin
	# Reverse with the existing reward-continue fade (0.24s / 0.12s).
	# Keep the old track rather than handing off to music for an unsaved room.
	_host.set("_initial_music_deferred", false)
	if is_instance_valid(_music) and _music.stream != null and not _music.playing:
		var track: Dictionary = Music.entry(str(_host.get("_active_music_id")))
		if track.has("volume_db"): _music_volume = db_to_linear(float(track["volume_db"]))
		_music.play()

func _apply_return() -> void:
	var progress: float = clampf((elapsed - _return_start) / reward_fade_seconds(reduced_motion), 0.0, 1.0)
	_arrival_shade.modulate.a = 1.0 - progress
	# Restore the complete screen under the reverse fade; avoid multiplying a
	# second opacity ramp into just its reward panel/banner.
	_fade_reward(1.0)
	if is_instance_valid(_music): _music.volume_linear = _music_volume * progress

func cancel() -> void:
	if not active: return
	active = false
	_restore_map()
	_restore_cursor()
	if not _entered and is_instance_valid(_music): _music.volume_linear = _music_volume
	if not _entered and is_instance_valid(_board): _board.position = _board_origin
	for index: int in range(_reward_items.size()):
		if is_instance_valid(_reward_items[index]): _reward_items[index].modulate = _reward_modulates[index]
	if is_instance_valid(_host):
		_host.set("_animation_lock", _lock_was_set)
		_host.set("_section_transition", null)
	if is_instance_valid(_surface): _surface.hide()
	queue_free()

func _exit_tree() -> void:
	if active: cancel()
	_restore_cursor()

func _restore_cursor() -> void:
	if is_instance_valid(_cursor_feedback): _cursor_feedback.call("set_glyph_visibility_suppressed", _cursor_owner, false)
