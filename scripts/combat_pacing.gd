extends Node
class_name CombatPacing

const HitStop = preload("res://scripts/combat_hit_stop.gd")
const Settings = preload("res://scripts/settings_store.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const OutcomeFeedback = preload("res://scripts/combat_outcome_feedback.gd")
const BANNER_LEAD_SECONDS: float = 0.35
const ENEMY_TILE_SECONDS: float = 0.20
const ENEMY_FEEDBACK_ADVANCE_SECONDS: float = 0.20
const FLASH_SECONDS: float = 0.140
const WHITE_FLASH_PROFILE: int = 8
# Unspecified perceptible curve: preserve the shipped linear fade until supplied.
# Quadratic ease-out: the flash falls off quickly after its peak.
const FLASH_EASE_OUT_EXPONENT: float = 2.0

static var _flash_shader: Shader
var scene: Node
var hit_stop: Node
var debug_timeline: bool = false
# Scheduling probe only: observe the original HEAD script without new feel.
var debug_baseline: bool = false
var timeline: Array[Dictionary]
var enemies_active: bool = false
var _scope: String = ""
var _base_scale: float = 1.0
var _applied_scale: float = 1.0
var _scale_restored: bool = false
var _leaving_tree: bool = false
var _clock_usec: float = 1.0
var _last_clock_usec: int = 0
var _round_started_usec: int = 0
var _banner_clock: int = 0
var _actor: String = ""
var _caption: String = ""
var _caption_prefix: String = ""
var _phase: String = ""
var _phase_started_usec: int = 0
var _seen_hits: Dictionary = {}
var _flashes: Dictionary = {}
var _flash_draw_keys: Array = []
var _popups: Dictionary = {}
var _deaths: Array[Dictionary]
var _surfaces: Array[Dictionary]
var _pending_order: Dictionary = {}
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
	var now: int = Time.get_ticks_usec()
	if _last_clock_usec > 0 and (not is_inside_tree() or not get_tree().paused):
		_clock_usec += float(now - _last_clock_usec) * Engine.time_scale
	_last_clock_usec = now

func presentation_usec() -> int:
	_sync_clock()
	return int(_clock_usec)

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
	_phase = "banner"
	_phase_started_usec = _round_started_usec
	if debug_timeline:
		timeline.clear()

func _begin_scope(scope: String) -> void:
	_sync_clock()
	if _scope.is_empty():
		_base_scale = hit_stop.previous_scale() if hit_stop != null and hit_stop.active else Engine.time_scale
	_scope = scope
	_scale_restored = false
	_apply_speed()

func current_scale() -> float:
	if _scope.is_empty() or _scale_restored or not _presentation_allowed():
		return _base_scale
	return _base_scale * Settings.combat_speed_scale(scene.get("_settings") as Dictionary)

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

func present_turn_order(before: Array, after: Array, defeated: Dictionary = {}) -> void:
	_pending_order = {"before": before, "after": after, "defeated": defeated}
	if not _order_running: _drain_turn_orders()

func _drain_turn_orders() -> void:
	_order_running = true
	while not _pending_order.is_empty() and is_instance_valid(scene) and scene.is_inside_tree():
		var pending: Dictionary = _pending_order
		_pending_order = {}
		var before: Array[Dictionary]
		before.assign(pending["before"])
		var after: Array[Dictionary]
		after.assign(pending["after"])
		await scene.call("_animate_turn_order_transition", before, after, pending["defeated"])
	_order_running = false

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

func _overlay_deadline(clock: int) -> int:
	var deadline: int = clock
	for popup: Dictionary in _popups.values():
		deadline = maxi(deadline, int(popup["start"]) + int(FloatingText.ANIMATION_DURATION_SECONDS * 1000000.0))
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
	_scale_restored = false
	_close_phase()
	_flashes.clear()
	_popups.clear()
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
		scene.call("_render_board_state", _last_state, _last_presentation, true)

func _active_overlays(entries: Array[Dictionary], clock: int) -> Array[Dictionary]:
	var active: Array[Dictionary]
	for entry: Dictionary in entries:
		if clock - int(entry["start"]) < int(entry["duration"]): active.append(entry)
	return active

func _enter_tree() -> void:
	_leaving_tree = false

func _exit_tree() -> void:
	_leaving_tree = true
	end_scope()
	_flash_shader = null

func before_step(step: Dictionary) -> void:
	var kind: String = str(step.get("kind", ""))
	if kind == "commit":
		return
	var actor: String = str(step.get("actor_key", ""))
	if actor != _actor:
		_caption = ""
		_caption_prefix = ""
	if not debug_baseline and kind == "intent" and _actor.is_empty():
		while presentation_usec() - _banner_clock < int(BANNER_LEAD_SECONDS * 1000000.0):
			await get_tree().process_frame
	# Only an actor or target that depends on a dissolving body waits for it.
	while _death_dependency(step) or _surface_dependency(step):
		await get_tree().process_frame
	if kind == "intent":
		_close_phase()
		_actor = actor
		if not bool(step.get("hidden_by_umbra",false)):
			_caption_prefix = str(step.get("actor_name","Enemy"))
			_caption = "%s: %s" % [_caption_prefix,str(step.get("intent_name",""))]
		_mark("pre-action delay")
		_mark("caption")
		_phase = "caption" if debug_baseline else "wind-up"
		_phase_started_usec = Time.get_ticks_usec()
	elif kind == "move":
		_change_phase("walk")
	elif kind in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]:
		_change_phase("wind-up")

func caption_text(text: String) -> String:
	if enemies_active and not _caption.is_empty() and text.begins_with(_caption_prefix+": "):
		return _caption
	return text

func after_step(step: Dictionary) -> void:
	if debug_baseline and str(step.get("kind", "")) == "intent": _change_phase("wind-up")
	if str(step.get("kind", "")) in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]:
		_close_phase()
		_mark("post-action settle")
		_change_phase("hand-off gap")

func walk_frame_seconds(actor_key: String, counts: Array[int], authored: float) -> float:
	if not enemies_active or actor_key == "player" or counts.is_empty():
		return authored
	var longest: int = 1
	for count: int in counts:
		longest = maxi(longest, count)
	return minf(authored, (ENEMY_TILE_SECONDS - FloatingText.TARGET_FRAME_SECONDS) / float(longest))

func walk_tile(index: int) -> void:
	var phase: String = "walk (tile %d)" % (index + 1)
	if _phase != phase:
		_change_phase(phase)

func walk_finished() -> void:
	if enemies_active: _change_phase("post-action settle")

func present_initial_order(before: Dictionary, after: Dictionary) -> void:
	present_turn_order(scene.call("_turn_order_entries_from_state", before), scene.call("_turn_order_entries_from_state", after))

func feedback_duration(_texts: Array, authored: float, initial_elapsed: float) -> float:
	if not enemies_active:
		return authored
	# Popups/reactions remain alive in decorate() across the next actor's action.
	return minf(authored, maxf(initial_elapsed, ENEMY_FEEDBACK_ADVANCE_SECONDS))

func decorate(state: Dictionary, presentation: Dictionary) -> void:
	_last_render_frame = Engine.get_process_frames()
	_last_state = state
	_last_presentation = presentation.duplicate(false)
	var clock: int = presentation_usec()
	var hits: Array[Dictionary]
	for entry: Dictionary in presentation.get("floating_texts", []):
		var key: String = str(entry.get("reaction_actor_key", ""))
		if str(entry.get("reaction", "")) not in ["hit", "block"] and not FloatingText.is_damage_entry(entry):
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
		hits.append({"id": id, "actor_key": key, "damage": damage, "killed": killed})
		var base: Dictionary = entry.duplicate(true)
		base["screen_layout_id"] = id
		# animate_entries emits peak-sized glyphs plus a scale. Retained entries
		# must start from the same library base, never animate that peak again.
		if FloatingText.is_damage_entry(base): base["font_size"] = FloatingText.DAMAGE_BASE_FONT_SIZE
		elif FloatingText.is_effect_entry(base): base["font_size"] = FloatingText.EFFECT_BASE_FONT_SIZE
		if FloatingText.is_popup_entry(base): base.erase("motion_offset")
		_popups[id] = {"entry": base, "start": clock - int(float(entry.get("animation_progress", 0.0)) * FloatingText.ANIMATION_DURATION_SECONDS * 1000000.0), "sequence": int(entry.get("sequence_index",0))}
	presentation["combat_feel_owner"] = self
	presentation["combat_feel_hits"] = hits
	var texts: Array = []
	for entry: Dictionary in presentation.get("floating_texts", []):
		if str(entry.get("reaction", "")) not in ["hit", "block"] and not FloatingText.is_damage_entry(entry):
			texts.append(entry)
	for id: String in _popups.keys():
		var popup: Dictionary = _popups[id]
		var elapsed: float = float(clock - int(popup["start"])) / 1000000.0
		if elapsed >= FloatingText.ANIMATION_DURATION_SECONDS:
			_popups.erase(id)
		else:
			var animated: Array[Dictionary] = FloatingText.animate_entries([popup["entry"]], elapsed, bool(presentation.get("reduced_motion", false)))
			for entry: Dictionary in animated:
				entry["sequence_index"] = popup["sequence"]
				if bool(presentation.get("reduced_motion", false)):
					var offset: Vector2 = entry.get("motion_offset", Vector2.ZERO)
					offset.y -= float(popup["sequence"]) * FloatingText.REDUCED_STACK_STEP_Y
					entry["motion_offset"] = offset
			texts.append_array(animated)
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
		largest = maxf(largest, shake_pixels(int(hit["damage"]), bool(hit["killed"]), key == "player"))
		if enemies_active and _phase != "impact":
			_change_phase("impact")
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
		_deaths.append({"units": units, "start": presentation_usec(), "duration": int(frames * seconds * 1000000.0)})
	var order_before: Array[Dictionary]
	order_before.assign(scene.call("_turn_order_entries_from_state", before))
	var order_after: Array[Dictionary]
	order_after.assign(scene.call("_turn_order_entries_from_state", after))
	present_turn_order(order_before, order_after, scene.call("_turn_order_defeated_actor_keys", before, after))
	return true

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
		timeline.append({"actor": _actor, "phase": phase, "start": at, "end": at})

func _change_phase(phase: String) -> void:
	_close_phase()
	_phase = phase
	_phase_started_usec = Time.get_ticks_usec()

func _close_phase() -> void:
	if debug_timeline and not _phase.is_empty():
		timeline.append({"actor": _actor, "phase": _phase, "start": float(_phase_started_usec - _round_started_usec) / 1000000.0, "end": float(Time.get_ticks_usec() - _round_started_usec) / 1000000.0})
	_phase = ""

func print_timeline() -> void:
	for row: Dictionary in timeline:
		print("COMBAT FEEL TIMELINE: %s" % JSON.stringify(row))
