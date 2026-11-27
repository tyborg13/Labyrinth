extends Node
class_name CombatPacing

signal _playback_frame

const KeyBindings = preload("res://scripts/key_bindings.gd")
const HitStop = preload("res://scripts/combat_hit_stop.gd")
const Settings = preload("res://scripts/settings_store.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const OutcomeFeedback = preload("res://scripts/combat_outcome_feedback.gd")
const DeathSequence = preload("res://scripts/maquette_cutout_runtime/death_sequence.gd")
const PresentationClock = preload("res://scripts/presentation_clock.gd")
const BANNER_LEAD_SECONDS: float = 0.35
const ENEMY_TILE_SECONDS: float = 0.20
const ENEMY_ACTION_SPEED_SCALE: float = 0.80
const ENEMY_HURRY_SPEED_SCALE: float = 2.0
const ENEMY_ACTION_SETTLE_SECONDS: float = 0.08
const NUMBER_LIFETIME_USEC: int = int(FloatingText.ANIMATION_DURATION_SECONDS * 1000000.0)
const ENEMY_ACTION_LEAD_SECONDS: float = 0.25
const ENEMY_ACTION_KINDS: Array = ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "block", "heal", "stoneskin", "status", "status_damage", "surface", "summon", "burrow", "erupt"]
const FLASH_SECONDS: float = 0.140
const WHITE_FLASH_PROFILE: int = 8
# Unspecified perceptible curve: preserve the shipped linear fade until supplied.
# Quadratic ease-out: the flash falls off quickly after its peak.
const FLASH_EASE_OUT_EXPONENT: float = 2.0

static var _flash_shader: Shader
var scene: Node
var hit_stop: Node
var vibration := preload("res://scripts/combat_vibration.gd").new()
var _window_focused: bool = true
var _application_paused: bool = false
var debug_timeline: bool = false
# Scheduling probe only: observe the original HEAD script without new feel.
var debug_baseline: bool = false
var timeline: Array[Dictionary]
var enemies_active: bool = false
var _enemy_action_active: bool = false
var _hurry_inputs: Dictionary = {}
var _left_press_in_enemy_turn: bool = false
var _scope: String = ""
var _base_scale: float = 1.0
var _applied_scale: float = 1.0
var _scale_restored: bool = false
var _leaving_tree: bool = false
var _clock_usec: float = 1.0
var _last_clock_usec: int = 0
var _movie_clock := PresentationClock.new()
var _round_started_usec: int = 0
var _banner_clock: int = 0
var _actor: String = ""
var _caption: String = ""
var _caption_prefix: String = ""
var _caption_target_prefix: String = ""
var _phase: String = ""
var _phase_started_usec: int = 0
var _phase_started_clock: int = 0
var _seen_hits: Dictionary = {}
var _flashes: Dictionary = {}
var _flash_draw_keys: Array = []
var _popups: Dictionary = {}
var _enemy_number_ids: Dictionary = {}
var _number_action: int = 0
var _number_contact_delay: int = 0
var _sampled_number_contact: Dictionary = {}
var _deaths: Array[Dictionary]
var _surfaces: Array[Dictionary]
var _order_serial: int = 0
var _order_running: bool = false
var _last_state: Dictionary = {}
var _last_presentation: Dictionary = {}
var _last_render_frame: int = -1

func install(owner_scene: Node) -> void:
	scene = owner_scene
	name = "CombatPacing"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	scene.add_child(self)
	hit_stop = HitStop.new()
	hit_stop.name = "CombatHitStop"
	hit_stop.restore_scale = Callable(self, "current_scale")
	hit_stop.scale_changing.connect(_sync_clock)
	hit_stop.stop_ended.connect(_release_flashes)
	add_child(hit_stop)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

static func impact_flash_shader(source: Shader) -> Shader:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = source.code.replace("COLOR = source * art_vertex_color;", "COLOR = (art_profile > %s ? vec4(vec3(1.0), source.a) : source) * art_vertex_color;" % (float(WHITE_FLASH_PROFILE) - 0.5))
	return _flash_shader

static func shake_pixels(damage: int, killed: bool = false, hero: bool = false) -> float:
	var amplitude: float = 2.0 if damage <= 3 else 3.5 if damage <= 7 else 5.0 if damage <= 11 else 6.5
	if killed:
		amplitude = 6.5
	return amplitude + (1.5 if hero else 0.0)

static func shake_seconds(amplitude: float) -> float:
	return 0.18 + 0.02 * amplitude

static func unit_shake_strength(presentation: Dictionary, actor_key: String) -> float:
	if actor_key.is_empty() or bool(presentation.get("reduced_motion",false)) or not (presentation.get("impact_actor_keys",[]) as Array).has(actor_key): return 0.0
	var progress: float = clampf(float(presentation.get("impact_progress",0.0)),0.0,1.0)
	return (1.0-progress)*maxf(0.0,float(presentation.get("impact_strength",1.0)))

static func flash_opacity(elapsed: float, hero: bool = false) -> float:
	var remaining: float = 1.0 - clampf(elapsed / FLASH_SECONDS, 0.0, 1.0)
	var fade: float = pow(remaining, FLASH_EASE_OUT_EXPONENT)
	return (0.60 if hero else 0.85) * fade

func _sync_clock() -> void:
	if not Engine.get_write_movie_path().is_empty():
		var delta: float = get_process_delta_time() / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
		_clock_usec += _movie_clock.advance(Engine.get_process_frames(), delta, Engine.time_scale, is_inside_tree() and get_tree().paused)
		return
	var now: int = Time.get_ticks_usec()
	if _last_clock_usec > 0 and (not is_inside_tree() or not get_tree().paused):
		_clock_usec += float(now - _last_clock_usec) * Engine.time_scale
	_last_clock_usec = now

func presentation_usec() -> int:
	_sync_clock()
	return int(_clock_usec)

func next_playback_frame() -> Signal:
	var process_frame: Signal = get_tree().process_frame
	if not process_frame.is_connected(_emit_playback_frame):
		process_frame.connect(_emit_playback_frame, CONNECT_ONE_SHOT)
	return _playback_frame

func _emit_playback_frame() -> void:
	_playback_frame.emit()

func begin_card() -> void:
	_begin_scope("card")

func begin_enemies() -> void:
	_begin_scope("enemies")
	enemies_active = true
	_round_started_usec = Time.get_ticks_usec()
	_banner_clock = presentation_usec()
	_actor = ""
	_caption = ""
	_caption_prefix = ""
	_caption_target_prefix = ""
	_phase = "banner"
	_phase_started_usec = _round_started_usec
	_phase_started_clock = _banner_clock
	if debug_timeline:
		timeline.clear()

func _begin_scope(scope: String) -> void:
	_sync_clock()
	if _scope.is_empty():
		_base_scale = hit_stop.previous_scale() if hit_stop != null and hit_stop.active else Engine.time_scale
	_scope = scope
	_enemy_action_active = false
	_hurry_inputs.clear()
	_scale_restored = false
	_apply_speed()

func current_scale() -> float:
	if _scope.is_empty() or _scale_restored or not _presentation_allowed():
		return _base_scale
	var action_scale: float = ENEMY_ACTION_SPEED_SCALE if _scope == "enemies" and _enemy_action_active else 1.0
	var hurry_scale: float = ENEMY_HURRY_SPEED_SCALE if _scope == "enemies" and not _hurry_inputs.is_empty() else 1.0
	return _base_scale * Settings.combat_speed_scale(scene.get("_settings") as Dictionary) * action_scale * hurry_scale

func observe_hurry_input(event: InputEvent) -> void:
	# Observe edges before Pass or GUI dispatch. A button already down when
	# the enemy scope opens contributes no hold.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_press_in_enemy_turn = _scope == "enemies"
		elif _left_press_in_enemy_turn:
			# The board turns this release into a click after _input; forget the press once it has.
			set_deferred("_left_press_in_enemy_turn", false)
	if _scope != "enemies": return
	if KeyBindings.matches(KeyBindings.HURRY, event, true):
		_set_hurry_input(&"keyboard", event.is_pressed())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_hurry_input(&"mouse", event.pressed)
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		_set_hurry_input(event.device, event.pressed)

func _set_hurry_input(source: Variant, pressed: bool) -> void:
	var was_empty: bool = _hurry_inputs.is_empty()
	_sync_clock()
	if pressed: _hurry_inputs[source] = true
	else: _hurry_inputs.erase(source)
	if was_empty != _hurry_inputs.is_empty(): _apply_speed()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and _hurry_inputs.has(device):
		_set_hurry_input(device, false)

# A left press made during the enemy turn hurries it; its release never becomes a board click, even
# when the button comes up after the hero's turn has begun.
func take_enemy_turn_press() -> bool:
	var pressed_during_enemy_turn: bool = _left_press_in_enemy_turn
	_left_press_in_enemy_turn = false
	return pressed_during_enemy_turn

# A held hurry key can't report its release once the window loses focus.
func _release_hurry_inputs() -> void:
	if _hurry_inputs.is_empty(): return
	_sync_clock()
	_hurry_inputs.clear()
	_apply_speed()

func _set_enemy_action_active(active: bool) -> void:
	# Integrate the old clock before changing it. Movement, caption leads and
	# settles retain combat speed; only wind-up through complete feedback slows.
	_sync_clock()
	_enemy_action_active = active
	_apply_speed()

func _apply_speed() -> void:
	if _base_scale <= 0.0: _base_scale = 1.0
	if hit_stop != null and hit_stop.active:
		if Engine.time_scale > 0.0:
			_base_scale = Engine.time_scale
			Engine.time_scale = 0.0
		return
	_sync_clock()
	var desired: float = current_scale()
	if not is_equal_approx(Engine.time_scale, _applied_scale) and not is_equal_approx(Engine.time_scale, desired):
		# The director writes its own slow-motion scale; retain it as the base.
		_base_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
		desired = current_scale()
	Engine.time_scale = desired
	_applied_scale = desired

# The rail keeps up with the foe that acts (atk-10). A newer order never waits
# behind a running rail motion: that motion jumps to its end state and the
# newest plays at once, at its normal duration. Nothing older stays queued, and
# no actor waits for the rail.
func present_turn_order(before: Array, after: Array, defeated: Dictionary = {}) -> void:
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return
	_order_serial += 1
	var serial: int = _order_serial
	scene.call("_finish_turn_order_transition_now")
	_order_running = true
	var before_order: Array[Dictionary]
	before_order.assign(before)
	var after_order: Array[Dictionary]
	after_order.assign(after)
	await scene.call("_animate_turn_order_transition", before_order, after_order, defeated)
	if serial == _order_serial: _order_running = false

func finish_enemies() -> void:
	_change_phase("hero hand-off")
	while _order_running: await get_tree().process_frame
	# Snapshot the last bounded feedback deadline. No new actor work starts here.
	var deadline: int = _overlay_deadline(presentation_usec())
	while not _scope.is_empty() and is_inside_tree() and not _leaving_tree and presentation_usec() < deadline:
		await get_tree().process_frame
	# Submit the terminal feedback state before retiring the scope. A skipped
	# render frame must not leave the last partial dissolve on the board.
	_refresh_overlays()
	end_scope()

func _overlay_deadline(clock: int, numbers_fading: bool = false) -> int:
	var deadline: int = clock
	for popup: Dictionary in _popups.values():
		var lifetime: int = NUMBER_LIFETIME_USEC
		if numbers_fading and popup.has("reduced"):
			lifetime = ceili(FloatingText.number_fade_start_seconds(bool(popup["reduced"])) * 1000000.0)
		deadline = maxi(deadline, int(popup["start"]) + lifetime)
	for entries: Array[Dictionary] in [_deaths, _surfaces]:
		for entry: Dictionary in entries:
			deadline = maxi(deadline, int(entry["start"]) + int(entry["duration"]))
	for start: int in _flashes.values():
		deadline = maxi(deadline, (clock if start < 0 else start) + int(FLASH_SECONDS * 1000000.0))
	return deadline

func restore_time_scale() -> void:
	var owns_scale: bool = not _scope.is_empty() or (hit_stop != null and hit_stop.active)
	_sync_clock()
	if _base_scale <= 0.0: _base_scale = 1.0
	_scale_restored = true
	if hit_stop != null: hit_stop.cancel()
	if owns_scale:
		Engine.time_scale = _base_scale
		_applied_scale = _base_scale

func end_scope() -> void:
	var owns_scale: bool = not _scope.is_empty() or (hit_stop != null and hit_stop.active)
	restore_time_scale()
	_scope = ""
	enemies_active = false
	_enemy_action_active = false
	_hurry_inputs.clear()
	_scale_restored = false
	_close_phase()
	_flashes.clear()
	_popups.clear()
	_enemy_number_ids.clear()
	_number_action = 0
	_number_contact_delay = 0
	_sampled_number_contact.clear()
	_deaths.clear()
	_surfaces.clear()
	_last_state = {}
	_last_presentation = {}
	if owns_scale and _stage_refresh_allowed():
		_refresh_stage_after_scope.call_deferred()

func _stage_refresh_allowed() -> bool:
	return not _leaving_tree and is_inside_tree() and is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and not bool(scene.get("_animation_lock")) and scene.has_method("_refresh_stage_view")

func _refresh_stage_after_scope() -> void:
	# A scene may be detached, deleted or locked after the callback is queued.
	if _stage_refresh_allowed(): scene.call("_refresh_stage_view")

func _presentation_allowed() -> bool:
	if scene == null or not scene.is_inside_tree() or scene.get_tree().paused:
		return false
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat":
		return false
	return bool(scene.get("_animation_lock")) and int(scene.get("_drag_card_index")) < 0 and not bool(scene.call("_controller_modal_visible"))

func _process(_delta: float) -> void:
	_sync_clock()
	if vibration.has_active_pulse() and vibration.device_id != _vibration_device():
		vibration.stop()
	if not _scope.is_empty():
		if not bool(scene.get("_animation_lock")) or str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat":
			end_scope()
		else:
			if not _presentation_allowed():
				hit_stop.cancel()
			_apply_speed()
	if not _scope.is_empty() and _last_render_frame != Engine.get_process_frames() and not hit_stop.active and (not _flashes.is_empty() or not _popups.is_empty() or not _deaths.is_empty() or not _surfaces.is_empty()):
		_refresh_overlays.call_deferred()

func _refresh_overlays() -> void:
	if not _scope.is_empty() and _last_render_frame != Engine.get_process_frames() and scene != null and scene.is_inside_tree() and not _last_state.is_empty():
		var started: int = Time.get_ticks_usec() if bool(scene.get("_runtime_performance_instrumentation_enabled")) else 0
		scene.call("_render_board_state", _last_state, _last_presentation, true)
		if started > 0: scene.call("_record_runtime_performance_phase", "animation_overlay_board_submission", started)

func _active_overlays(entries: Array[Dictionary], clock: int) -> Array[Dictionary]:
	var active: Array[Dictionary]
	for entry: Dictionary in entries:
		if clock - int(entry["start"]) < int(entry["duration"]): active.append(entry)
	return active

func _enter_tree() -> void:
	_leaving_tree = false

func _exit_tree() -> void:
	_leaving_tree = true
	# The tree can keep processing while a retired RunScene is detached. Drop
	# both the frame relay and its suspended consumers before that can happen.
	var process_frame: Signal = get_tree().process_frame
	if process_frame.is_connected(_emit_playback_frame):
		process_frame.disconnect(_emit_playback_frame)
	for connection: Dictionary in _playback_frame.get_connections():
		_playback_frame.disconnect(connection["callable"])
	vibration.stop()
	end_scope()
	_flash_shader = null

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_window_focused = false
			vibration.stop()
			_release_hurry_inputs()
		NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN:
			_window_focused = true
		NOTIFICATION_APPLICATION_PAUSED:
			_application_paused = true
			vibration.stop()
			_release_hurry_inputs()
		NOTIFICATION_APPLICATION_RESUMED:
			_application_paused = false
		NOTIFICATION_PAUSED:
			vibration.stop()

func _vibration_device() -> int:
	if _leaving_tree or not _window_focused or _application_paused or not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion() or scene.get("_leaving_tree") == true:
		return -1
	if get_tree().paused or (scene.get("_run_state") as Dictionary).get("mode") != "combat" or bool(scene.call("_controller_modal_visible")):
		return -1
	if not Settings.controller_vibration_enabled(scene.get("_settings")):
		return -1
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and router.using_controller():
		return router.last_joypad_input_device()
	return -1

static func is_action_step(step: Dictionary) -> bool:
	return str(step.get("kind", "")) in ENEMY_ACTION_KINDS

static func action_actor_key(step: Dictionary) -> String:
	# Ally-support steps apply to actor_key but belong to the source's turn.
	return str(step.get("source_actor_key", step.get("actor_key", "")))

static func activation_has_action(actor: String, steps: Array) -> bool:
	for step: Dictionary in steps:
		if action_actor_key(step) == actor and is_action_step(step): return true
	return false

func _wait_until(deadline: int) -> void:
	while not _scope.is_empty() and is_inside_tree() and not _leaving_tree and presentation_usec() < deadline:
		await get_tree().process_frame

func before_step(step: Dictionary, activation_steps: Array = []) -> void:
	var kind: String = str(step.get("kind", ""))
	if kind == "commit":
		return
	if enemies_active: _set_enemy_action_active(false)
	if enemies_active and (is_action_step(step) or kind in ["move", "worldspine_pulse", "reinforcement_spawn"]):
		begin_number_action()
	var actor: String = action_actor_key(step)
	_caption_target_prefix = str(step.get("actor_name", "")) if step.has("source_actor_key") else ""
	if actor != _actor:
		_caption = ""
		_caption_prefix = ""
	# Only an actor or target that depends on a dissolving body waits for it.
	while _death_dependency(step) or _surface_dependency(step):
		await get_tree().process_frame
	if kind == "intent":
		var first_enemy: bool = _actor.is_empty()
		_close_phase()
		_actor = actor
		if not bool(step.get("hidden_by_umbra",false)):
			_caption_prefix = str(step.get("actor_name","Enemy"))
			_caption = str(step.get("turn_caption", "%s: %s" % [_caption_prefix,str(step.get("intent_name",""))]))
		_mark("caption")
		if not debug_baseline and activation_has_action(actor, activation_steps):
			# Show the printed intent throughout the lead, including the first
			# banner's remaining time. Move-only activations never enter this wait.
			if not _caption.is_empty(): scene.call("_set_action_banner", _caption)
			_change_phase("pre-action delay")
			var deadline: int = _banner_clock + int(BANNER_LEAD_SECONDS * 1000000.0) if first_enemy else presentation_usec() + int(ENEMY_ACTION_LEAD_SECONDS * 1000000.0)
			await _wait_until(deadline)
		_change_phase("intent")
	elif kind == "intent_callout" and step.has("turn_caption") and not bool(step.get("hidden_by_umbra", false)):
		# Frozen/Petrified skip the intent step entirely. Establish their caption
		# before the callout, preserving the existing activation/lead clock.
		_caption_prefix = str(step.get("actor_name", "Enemy"))
		_caption = str(step["turn_caption"])
		scene.call("_set_action_banner", _caption)
	elif kind == "move":
		_change_phase("walk")
	elif is_action_step(step):
		if enemies_active: _set_enemy_action_active(true)
		_change_phase("wind-up")

func caption_text(text: String) -> String:
	if enemies_active and not _caption.is_empty() and (text.begins_with(_caption_prefix+": ") or (not _caption_target_prefix.is_empty() and text.begins_with(_caption_target_prefix+": "))):
		return _caption
	return text

func after_step(step: Dictionary) -> void:
	if debug_baseline and str(step.get("kind", "")) == "intent": _change_phase("wind-up")
	if enemies_active and is_action_step(step):
		# A view may retain feedback beyond its own coroutine (including a
		# staggered popup or hit-stop release). Settle starts after that deadline.
		await _wait_until(_overlay_deadline(presentation_usec(), true))
		_mark("feedback complete")
		_set_enemy_action_active(false)
		_change_phase("post-action settle")
		await _wait_until(presentation_usec() + int(ENEMY_ACTION_SETTLE_SECONDS * 1000000.0))
		_change_phase("hand-off gap")

func walk_frame_seconds(actor_key: String, counts: Array[int], authored: float) -> float:
	if not enemies_active or actor_key == "player" or counts.is_empty():
		return authored
	var longest: int = 1
	for count: int in counts:
		longest = maxi(longest, count)
	return minf(authored, (ENEMY_TILE_SECONDS - FloatingText.TARGET_FRAME_SECONDS) / float(longest))

func begin_movement(actor_key: String) -> bool:
	# Some mechanic views embed an approach walk inside their action coroutine.
	# Save/restore the action clock around travel, including nested move helpers.
	var resume_action: bool = enemies_active and _enemy_action_active and actor_key != "player"
	if enemies_active and actor_key != "player": _set_enemy_action_active(false)
	return resume_action

func end_movement(resume_action: bool) -> void:
	if enemies_active:
		_set_enemy_action_active(resume_action)
		if resume_action: _change_phase("wind-up")

func walk_tile(index: int) -> void:
	var phase: String = "walk (tile %d)" % (index + 1)
	if _phase != phase:
		_change_phase(phase)

func walk_finished() -> void:
	if enemies_active: _change_phase("walk hand-off")

func present_initial_order(before: Dictionary, after: Dictionary) -> void:
	present_turn_order(scene.call("_turn_order_entries_from_state", before), scene.call("_turn_order_entries_from_state", after))

func feedback_duration(texts: Array, authored: float, _initial_elapsed: float) -> float:
	if not enemies_active or texts.is_empty(): return authored
	var reduced: bool = Settings.reduced_motion_enabled(scene.get("_settings")) if scene != null else false
	return authored + FloatingText.total_duration(texts, true, reduced) - FloatingText.total_duration(texts)

func begin_number_action() -> void:
	_number_action += 1
	_number_contact_delay = 0

func number_contact_deadline(texts: Array, state: Dictionary) -> int:
	if not enemies_active or _popups.is_empty(): return 0
	var targets: Dictionary = {}
	for entry: Dictionary in texts:
		if FloatingText.is_number_entry(entry) and not _enemy_number_ids.has(str(entry.get("screen_layout_id", ""))):
			for target: Variant in _number_targets(entry, state): targets[target] = true
	if targets.is_empty(): return 0
	var deadline: int = 0
	for popup: Dictionary in _popups.values():
		if int(popup.get("action", _number_action)) == _number_action: continue
		for target: Variant in popup.get("targets", []):
			if targets.has(target): deadline = maxi(deadline, int(popup["start"]) + NUMBER_LIFETIME_USEC)
	return deadline

func wait_for_number_contact(deadline: int) -> void:
	if deadline <= presentation_usec(): return
	var previous_phase: String = _phase
	_change_phase("number contact wait")
	await _wait_until(deadline)
	if enemies_active: _change_phase(previous_phase)

func plan_sampled_number_contact(frame: int, texts: Array, state: Dictionary) -> void:
	var deadline: int = number_contact_deadline(texts, state)
	if deadline > presentation_usec(): _sampled_number_contact = {"frame": frame, "deadline": deadline}

func take_sampled_number_contact() -> Dictionary:
	var contact: Dictionary = _sampled_number_contact
	_sampled_number_contact = {}
	return contact

func _number_targets(entry: Dictionary, state: Dictionary) -> Array:
	var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
	var targets: Array = [tile]
	var actor_key: String = str(entry.get("reaction_actor_key", ""))
	if actor_key.is_empty() and str(entry.get("resource_kind", "")) in ["heal", "block", "stoneskin", "draw", "card_play"]:
		if state.get("player", {}).get("pos") == tile: actor_key = "player"
		else:
			for unit: Dictionary in state.get("enemies", []):
				if int(unit.get("hp", 0)) > 0 and (scene.call("_enemy_footprint_tiles", unit) as Array).has(tile):
					actor_key = scene.call("_enemy_key", unit)
					break
	if not actor_key.is_empty(): targets.append(actor_key)
	return targets

func decorate(state: Dictionary, presentation: Dictionary) -> void:
	_last_render_frame = Engine.get_process_frames()
	_last_state = state
	_last_presentation = presentation.duplicate(false)
	var clock: int = presentation_usec()
	var source_texts: Array = presentation.get("floating_texts", [])
	var contacts: Array = source_texts
	if enemies_active:
		_register_enemy_numbers(source_texts, state, clock, bool(presentation.get("reduced_motion", false)))
		contacts = source_texts.filter(func(entry: Dictionary) -> bool: return not FloatingText.is_number_entry(entry))
		for popup: Dictionary in _popups.values():
			if popup.has("action") and clock >= int(popup["start"]) and clock < int(popup["start"]) + NUMBER_LIFETIME_USEC:
				contacts.append(popup["entry"])
	var hits: Array[Dictionary]
	for entry: Dictionary in contacts:
		var key: String = str(entry.get("reaction_actor_key", ""))
		if bool(entry.get(FloatingText.POPUP_ONLY_KEY, false)) or (str(entry.get("reaction", "")) not in ["hit", "block"] and not FloatingText.is_damage_entry(entry)):
			continue
		var id: String = str(entry.get("screen_layout_key", ""))
		if id.is_empty(): id = FloatingText.ensure_screen_layout_id(entry)
		if _seen_hits.has(id):
			continue
		var unit: Dictionary = scene.call("_animation_actor_unit", state, key)
		var killed: bool = not unit.is_empty() and int(unit.get("hp", 1)) <= 0
		for death: Dictionary in presentation.get("death_animation_units", []):
			if str(death.get("key", "")) == key and bool(death.get("death_animation", false)):
				killed = true
		var damage: int = absi(str(entry.get("text", "0")).to_int()) if str(entry.get("reaction", "")) == "hit" or (FloatingText.is_damage_entry(entry) and str(entry.get("reaction","")) != "block") else 0
		hits.append({"id": id, "actor_key": key, "damage": int(entry.get(FloatingText.IMPACT_DAMAGE_KEY, damage)), "killed": killed})
		if not enemies_active or not FloatingText.is_number_entry(entry): _retain_popup(entry, id, clock)
	presentation["combat_feel_owner"] = self
	presentation["combat_feel_hits"] = hits
	var texts: Array = []
	for entry: Dictionary in source_texts:
		if enemies_active and FloatingText.is_number_entry(entry): continue
		if bool(entry.get(FloatingText.POPUP_ONLY_KEY, false)) or (str(entry.get("reaction", "")) not in ["hit", "block"] and not FloatingText.is_damage_entry(entry)):
			texts.append(entry)
	for id: String in _popups.keys():
		var popup: Dictionary = _popups[id]
		var elapsed: float = float(clock - int(popup["start"])) / 1000000.0
		if elapsed >= FloatingText.ANIMATION_DURATION_SECONDS:
			_popups.erase(id)
		elif elapsed >= 0.0:
			# Resample the retained entry as a single glyph, preserving its original
			# gain batch and stagger metadata for the board's contact effects.
			var reduced: bool = bool(presentation.get("reduced_motion", false))
			var entry: Dictionary = FloatingText.animate_entry(popup["entry"], elapsed / FloatingText.ANIMATION_DURATION_SECONDS, reduced)
			entry["screen_layout_key"] = id
			if reduced:
				var offset: Vector2 = entry.get("motion_offset", Vector2.ZERO)
				offset.y -= float(popup["sequence"]) * FloatingText.REDUCED_STACK_STEP_Y
				entry["motion_offset"] = offset
			texts.append(entry)
	presentation["floating_texts"] = texts
	var strengths: Dictionary = {}
	for key: String in _flashes.keys():
		var start: int = int(_flashes[key])
		if start == -2:
			start = clock
			_flashes[key] = start
		if start >= 0 and clock - start >= int(FLASH_SECONDS * 1000000.0):
			_flashes.erase(key)
		elif start >= 0:
			strengths[key] = flash_opacity(float(clock - start) / 1000000.0, key == "player")
	presentation["combat_feel_flash"] = strengths
	var draw_keys: Array = _flash_draw_keys.duplicate()
	for key: String in strengths:
		if not draw_keys.has(key): draw_keys.append(key)
	presentation["combat_feel_flash_actor_keys"] = draw_keys
	_flash_draw_keys = strengths.keys()
	_surfaces = _active_overlays(_surfaces, clock)
	var deaths: Array[Dictionary]
	for entry: Dictionary in _deaths:
		var progress: float = clampf(float(clock - int(entry["start"])) / float(entry["duration"]), 0.0, 1.0)
		for source: Dictionary in entry["units"]:
			var unit: Dictionary = source.duplicate(true)
			unit["death_progress"] = progress
			unit["death_frame"] = int(round(progress * float(int(scene.call("_enemy_death_frame_count_for_unit", unit)) - 1)))
			DeathSequence.sample(unit, float(clock - int(entry["start"])) / 1000000.0, entry.get("sequence", {}))
			deaths.append(unit)
	_deaths = _active_overlays(_deaths, clock)
	if not deaths.is_empty():
		deaths.append_array(presentation.get("death_animation_units", []))
		presentation["death_animation_units"] = deaths
	var events: Array = (presentation.get("surface_feedback_events",[]) as Array).duplicate()
	var frames: Dictionary = {}
	var progress: float = float(presentation.get("surface_feedback_progress",0.0))
	for event: Dictionary in events:
		frames[event.get("tile",Vector2i(-1,-1))] = {"events":events,"progress":progress}
	for surface: Dictionary in _surfaces:
		var elapsed: float = float(clock-int(surface["start"]))/1000000.0
		var local_progress: float = 1.0 if bool(surface["reduced"]) else clampf(elapsed/(float(surface["duration"])/1000000.0),0.0,1.0)
		for event: Dictionary in surface["events"]:
			frames[event.get("tile",Vector2i(-1,-1))] = {"events":surface["events"],"progress":local_progress}
		events.append_array(surface["events"])
		progress = maxf(progress,local_progress)
	presentation["surface_feedback_events"] = events
	presentation["surface_feedback_progress"] = progress
	presentation["combat_feel_surface_frames"] = frames

func _register_enemy_numbers(entries: Array, state: Dictionary, clock: int, reduced: bool) -> void:
	# Custom sampled clips submit at their authored contact. A conflicting old
	# number delays the new number batch while the clip keeps its own clock.
	var deadline: int = number_contact_deadline(entries, state)
	_number_contact_delay = maxi(_number_contact_delay, deadline - clock)
	for entry: Dictionary in entries:
		if not FloatingText.is_number_entry(entry) or float(entry.get("alpha", 1.0)) <= 0.0: continue
		var id: String = FloatingText.ensure_screen_layout_id(entry)
		if _enemy_number_ids.has(id): continue
		_enemy_number_ids[id] = true
		_retain_popup(entry, id, clock)
		var popup: Dictionary = _popups[id]
		popup["start"] = maxi(int(popup["start"]) + _number_contact_delay, deadline)
		popup["action"] = _number_action
		popup["targets"] = _number_targets(entry, state)
		popup["reduced"] = reduced

func _retain_popup(entry: Dictionary, id: String, clock: int) -> void:
	var base: Dictionary = entry.duplicate(true)
	base["screen_layout_id"] = id
	# Retained text starts from the library base glyph size.
	if enemies_active and base.has(FloatingText.NUMBER_BASE_FONT_SIZE_KEY):
		base["font_size"] = base[FloatingText.NUMBER_BASE_FONT_SIZE_KEY]
	elif FloatingText.is_damage_entry(base): base["font_size"] = FloatingText.DAMAGE_BASE_FONT_SIZE
	elif FloatingText.is_effect_entry(base): base["font_size"] = FloatingText.EFFECT_BASE_FONT_SIZE
	if FloatingText.is_popup_entry(base): base.erase("motion_offset")
	var elapsed: float = float(entry.get("animation_progress", 0.0)) * FloatingText.ANIMATION_DURATION_SECONDS
	_popups[id] = {"entry": base, "start": clock - int(elapsed * 1000000.0), "sequence": int(entry.get("sequence_index", 0))}

func observe_baseline(state: Dictionary, presentation: Dictionary) -> void:
	var observed: Dictionary = presentation.duplicate(false)
	decorate(state, observed)
	for hit: Dictionary in observed.get("combat_feel_hits", []):
		if _seen_hits.has(hit["id"]): continue
		_seen_hits[hit["id"]] = true
		if enemies_active:
			_close_phase()
			_mark("impact")
			_change_phase("hit reaction / damage number")
	# Baseline instrumentation must not retain/redraw any new presentation.
	_popups.clear()

func present_hits(presentation: Dictionary) -> float:
	if debug_baseline: return 0.0
	var largest: float = 0.0
	var vibration_amplitude: float = 0.0
	var hero_vibration_amplitude: float = 0.0
	for hit: Dictionary in presentation.get("combat_feel_hits", []):
		var id: String = hit["id"]
		if _seen_hits.has(id):
			continue
		_seen_hits[id] = true
		if not _presentation_allowed():
			continue
		var key: String = hit["actor_key"]
		if _scope.is_empty() and not hit_stop.active: _base_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
		elif not _scope.is_empty(): _apply_speed()
		var stopped: bool = hit_stop.request(int(hit["damage"]), bool(hit["killed"]), key == "player", bool(presentation.get("reduced_motion", false)))
		if not key.is_empty(): _flashes[key] = -1 if stopped else presentation_usec()
		if stopped:
			var flash: Dictionary = (presentation.get("combat_feel_flash",{}) as Dictionary).duplicate(false)
			flash.erase(key)
			presentation["combat_feel_flash"] = flash
		var amplitude: float = shake_pixels(int(hit["damage"]), bool(hit["killed"]), key == "player")
		largest = maxf(largest, amplitude)
		if int(hit["damage"]) > 0 or bool(hit["killed"]):
			vibration_amplitude = maxf(vibration_amplitude, amplitude)
			if key == "player":
				hero_vibration_amplitude = maxf(hero_vibration_amplitude, amplitude)
		if enemies_active and _phase != "impact":
			_change_phase("impact")
	if vibration_amplitude > 0.0:
		var device: int = _vibration_device()
		if device >= 0:
			vibration.request(device, clampf(vibration_amplitude / 8.0, 0.2, 1.0),
				clampf((hero_vibration_amplitude - 2.0) / 6.0, 0.0, 1.0), shake_seconds(vibration_amplitude))
	return largest

func _release_flashes() -> void:
	presentation_usec()
	var pending_peak: bool = false
	for key: String in _flashes:
		if int(_flashes[key]) < 0:
			_flashes[key] = -2
			pending_peak = true
	_applied_scale = Engine.time_scale
	# Stop polling runs after animation submissions in a native process frame.
	# A submission made while frozen cannot carry the released white peak. Replace
	# that pending board state before the draw, even if this frame was submitted;
	# routine overlay maintenance still obeys its one-submission guard.
	if pending_peak and not _leaving_tree and _presentation_allowed() and not scene.is_queued_for_deletion() and not _last_state.is_empty():
		scene.call("_render_board_state", _last_state, _last_presentation, true)
	else:
		_refresh_overlays()
	if enemies_active and _phase == "impact":
		_change_phase("hit reaction / damage number")

func overlap_defeats(before: Dictionary, after: Dictionary, skip_terrain: bool) -> bool:
	# Burst journals own a sequential impact timeline, including enemy-phase
	# Reaction deaths. Retained dissolves cannot present those events.
	if (after.get("death_burst_events", []) as Array).size() > (before.get("death_burst_events", []) as Array).size():
		return false
	if not enemies_active or not (scene.call("_defeated_player_units_between_states", before, after) as Array).is_empty():
		return false
	# Terrain destruction retains its existing blocking dependency until its
	# affected tile is available; independent actor dissolves can overlap.
	if not skip_terrain and not (scene.call("_destroyed_terrain_units_between_states", before, after) as Array).is_empty():
		return false
	var units: Array[Dictionary]
	units.assign(scene.call("_defeated_enemy_units_between_states", before, after))
	if not units.is_empty():
		var frames: int = int(scene.get("ENEMY_DEATH_MIN_FRAMES"))
		var seconds: float = float(scene.get("ENEMY_DEATH_FALLBACK_FRAME_SECONDS"))
		for unit: Dictionary in units:
			frames = maxi(frames, int(scene.call("_enemy_death_frame_count_for_unit", unit)))
			seconds = minf(seconds, float(scene.call("_enemy_death_frame_seconds_for_unit", unit)))
		var entry: Dictionary = {"units": units, "start": presentation_usec(), "duration": int(frames * seconds * 1000000.0)}
		var sequence: Dictionary = {}
		DeathSequence.configure(sequence, scene, units, true)
		if sequence.has("unit_clocks"):
			# Reuse the blocking path's opt-in clocks with overlap sampling. Legacy
			# groups keep their original shared progress and lifetime byte for byte.
			entry["sequence"] = sequence
			entry["duration"] = int(sequence["hold_end_usec"])
		_deaths.append(entry)
		_release_held_bodies(units)
	var order_before: Array[Dictionary]
	order_before.assign(scene.call("_turn_order_entries_from_state", before))
	var order_after: Array[Dictionary]
	order_after.assign(scene.call("_turn_order_entries_from_state", after))
	present_turn_order(order_before, order_after, scene.call("_turn_order_defeated_actor_keys", before, after))
	return true

# The retained frame still lists each victim at its held hit pose. Refreshed with
# the dissolve, that later entry draws over it: the body stands until it vanishes.
func _release_held_bodies(units: Array[Dictionary]) -> void:
	if not _last_presentation.has("death_animation_units"): return
	var dying: Dictionary = {}
	for unit: Dictionary in units: dying[str(unit.get("key", ""))] = true
	_last_presentation["death_animation_units"] = (_last_presentation["death_animation_units"] as Array).filter(func(held: Dictionary) -> bool: return not dying.has(str(held.get("key", ""))))

func overlap_surface(before: Dictionary, after: Dictionary, base: Dictionary) -> bool:
	if not enemies_active:
		return false
	var events: Array[Dictionary]
	events.assign(scene.call("_surface_events_between", before, after))
	if events.is_empty():
		events.assign(base.get("surface_feedback_events", []))
	events = OutcomeFeedback.prepare(events)
	scene.call("_play_outcome_sounds", events)
	var reduced: bool = bool(scene.call("_reduced_motion_enabled"))
	_surfaces.append({"events": events, "start": presentation_usec(), "duration": 100000 if reduced else 360000, "reduced":reduced})
	var shown: Dictionary = base.duplicate(false)
	shown.erase("surface_feedback_events")
	shown.erase("surface_feedback_progress")
	# The retained ground effect bypasses the usual status-number path.
	var fire_ticks: Array[Dictionary] = preload("res://scripts/status_tick_feedback.gd").enemy_fire_start_losses(scene, events)
	if not fire_ticks.is_empty():
		fire_ticks.assign(scene.call("_visible_umbra_floating_texts", before, fire_ticks, true))
		var clock: int = presentation_usec()
		var numbers: Array[Dictionary] = FloatingText.animate_entries(fire_ticks, 0.0, reduced)
		for entry: Dictionary in numbers:
			# The ground beat already owns contact feedback.
			entry[FloatingText.POPUP_ONLY_KEY] = true
		_register_enemy_numbers(numbers, after, clock, reduced)
	scene.call("_render_board_state", after, shown)
	return true

func _surface_dependency(step: Dictionary) -> bool:
	var tiles: Array = [step.get("tile",Vector2i(-1,-1)),step.get("to",Vector2i(-1,-1))]
	tiles.append_array(step.get("tiles",[]))
	tiles.append_array(step.get("path",[]))
	for surface: Dictionary in _surfaces:
		if presentation_usec()-int(surface["start"])>=int(surface["duration"]): continue
		for event: Dictionary in surface["events"]:
			if tiles.has(event.get("tile",Vector2i(-2,-2))): return true
	return false

func _death_dependency(step: Dictionary) -> bool:
	var clock: int = presentation_usec()
	for entry: Dictionary in _deaths:
		if clock - int(entry["start"]) >= int(entry["duration"]):
			continue
		for unit: Dictionary in entry["units"]:
			if str(step.get("actor_key", "")) == str(unit.get("key", "")) or (scene.call("_enemy_footprint_tiles",unit) as Array).has(step.get("to", Vector2i(-1, -1))):
				return true
	return false

func _mark(phase: String) -> void:
	if debug_timeline:
		var at: float = float(Time.get_ticks_usec() - _round_started_usec) / 1000000.0
		var clock: float = float(presentation_usec() - _banner_clock) / 1000000.0
		timeline.append({"actor": _actor, "phase": phase, "start": at, "end": at, "clock_start": clock, "clock_end": clock})

func _change_phase(phase: String) -> void:
	_close_phase()
	_phase = phase
	_phase_started_usec = Time.get_ticks_usec()
	_phase_started_clock = presentation_usec()

func _close_phase() -> void:
	if debug_timeline and not _phase.is_empty():
		timeline.append({"actor": _actor, "phase": _phase, "start": float(_phase_started_usec - _round_started_usec) / 1000000.0, "end": float(Time.get_ticks_usec() - _round_started_usec) / 1000000.0, "clock_start": float(_phase_started_clock - _banner_clock) / 1000000.0, "clock_end": float(presentation_usec() - _banner_clock) / 1000000.0})
	_phase = ""

func print_timeline() -> void:
	for row: Dictionary in timeline:
		print("COMBAT FEEL TIMELINE: %s" % JSON.stringify(row))
