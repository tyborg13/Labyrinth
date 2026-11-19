extends RefCounted

## Presentation only: landing anchors come from committed resolver snapshots,
## never from a second adjacent_free search. Rules, events and saves stay intact.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Outcome = preload("res://scripts/combat_outcome_feedback.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Reactions = preload("res://scripts/cutout_context.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/action.gd")
const LAUNCH_SECONDS: float = 0.06
const FLIGHT_SECONDS: float = 0.36
const LAND_SECONDS: float = LAUNCH_SECONDS + FLIGHT_SECONDS
const APEX_TILE_HEIGHT: float = 0.5
const SURFACE_SECONDS: float = 0.36 # Existing production surface feedback clock.
const AIRBORNE_Z: int = 1 # Board bodies/terrain normally use z=0.

static func actors(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"player": state.get("player", {})}
	for field: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(field, []):
			result[("enemy_" if field == "enemies" else "illusion_") + str(unit["id"])] = unit
	return result

static func paths(before: Dictionary, after: Dictionary, origins: Array = [], excluded: String = "", removed_actors: Dictionary = {}) -> Array[Dictionary]:
	var tiles: Array = origins.duplicate()
	if tiles.is_empty():
		var sequence: int = int(before.get("surface_event_sequence", 0))
		for event: Dictionary in after.get("surface_events", []):
			if int(event.get("sequence", 0)) > sequence and str(event.get("kind", "")) == "terrain_created" and str(event.get("terrain_kind", "")) == "crag_outcrop": tiles.append(event["tile"])
	var result: Array[Dictionary]
	var old: Dictionary = actors(before)
	var next: Dictionary = actors(after)
	next.merge(removed_actors)
	for key: String in old:
		var unit: Dictionary = old[key]
		if key == excluded or unit.is_empty() or not next.has(key) or int(unit.get("hp", 0)) <= 0: continue
		var from: Vector2i = unit["pos"]
		var to: Vector2i = next[key].get("pos", from)
		if from == to: continue
		var intersects: bool = false
		for tile: Vector2i in Surfaces.footprint_tiles(unit):
			if tiles.has(tile): intersects = true
		if intersects: result.append({"actor_key": key, "from": from, "to": to, "unit": unit.duplicate(true)})
	return result

static func display_state(before: Dictionary, after: Dictionary, flights: Array[Dictionary], elapsed: float, reduced: bool, launch_seconds: float = LAUNCH_SECONDS) -> Dictionary:
	if reduced or elapsed >= launch_seconds + FLIGHT_SECONDS or flights.is_empty(): return after
	var shown: Dictionary = after.duplicate(true)
	var old: Dictionary = actors(before)
	var next: Dictionary = actors(shown)
	for path: Dictionary in flights:
		var key: String = path["actor_key"]
		if not next.has(key):
			var collection: String = "illusions" if key.begins_with("illusion_") else "enemies"
			shown[collection].append(old[key].duplicate(true))
			continue
		next[key].clear()
		next[key].merge(old[key].duplicate(true), true)
	return shown

static func decorate(board: Control, flights: Array[Dictionary], elapsed: float, reduced: bool, base: Dictionary = {}, launch_seconds: float = LAUNCH_SECONDS) -> Dictionary:
	var shown: Dictionary = base.duplicate(true)
	if reduced or elapsed >= launch_seconds + FLIGHT_SECONDS: return shown
	var positions: Dictionary = (shown.get("unit_world_positions", {}) as Dictionary).duplicate()
	var ground_positions: Dictionary = {}
	var held_frames: Dictionary = {}
	var t: float = clampf((elapsed - launch_seconds) / FLIGHT_SECONDS, 0.0, 1.0)
	for path: Dictionary in flights:
		var unit: Dictionary = path["unit"].duplicate(true)
		var key: String = path["actor_key"]
		unit["key"] = key
		if key == "player" or key.begins_with("illusion_"): unit["type"] = "player"
		if key.begins_with("illusion_"): unit["role"] = "illusion"
		if not path.has("held_idle_frame"): path["held_idle_frame"] = board._idle_frame_index(unit)
		held_frames[key] = path["held_idle_frame"]
		var from: Vector2 = board.world_position_for_unit_origin(unit, path["from"])
		var to: Vector2 = board.world_position_for_unit_origin(unit, path["to"])
		var ground: Vector2 = from.lerp(to, t)
		positions[key] = ground - Vector2(0.0, 4.0 * board._tile_height() * APEX_TILE_HEIGHT * t * (1.0 - t))
		if elapsed >= launch_seconds:
			ground_positions[key] = ground
			var renderer: Node = board.unit_cutout_renderer(unit)
			if is_instance_valid(renderer):
				var type: String = str(unit.get("type", ""))
				var motion_key: String = "illusion_motion" if key.begins_with("illusion_") else Reactions.family_key(type)
				var motions: Dictionary = (shown.get(motion_key, {}) as Dictionary).duplicate(true)
				# All dedicated production cutouts have hit; maquettes declare it.
				var has_hit: bool = not Maquette.handles(type) or Maquette.data_for(type).get("clips", {}).has("hit")
				var hit_seconds: float = Maquette.seconds_for(type, "hit") if Maquette.handles(type) and has_hit else Reactions.HIT_SECONDS
				motions[key] = {"clip": "hit", "phase": clampf((elapsed - launch_seconds) / hit_seconds, 0.0, 1.0)} if has_hit else {"clip": renderer.get("clip"), "phase": renderer.get("phase")}
				shown[motion_key] = motions[key] if key == "player" else motions
				shown["maquette_explicit_clip"] = true
	shown["unit_world_positions"] = positions
	shown["unit_throw_ground_positions"] = ground_positions
	shown["unit_throw_idle_frames"] = held_frames
	return shown

## Upheaval's caption is its windup. Launch on the first rise frame and leave
## landing losses and defeats to battlefield-rule playback.
static func animate_rise(scene: Control, before: Dictionary, after: Dictionary, flights: Array[Dictionary], rises: Array[Dictionary], base: Dictionary) -> void:
	var reduced: bool = scene._reduced_motion_enabled()
	var started: int = scene._combat_pacing.presentation_usec()
	var events: Array[Dictionary] = Outcome.prepare(rises)
	var duration: float = maxf(FLIGHT_SECONDS, SURFACE_SECONDS)
	while true:
		var elapsed: float = float(scene._combat_pacing.presentation_usec() - started) / 1000000.0
		var shown: Dictionary = decorate(scene.board_view, flights, elapsed, reduced, base, 0.0)
		shown["surface_feedback_events"] = events
		shown["surface_feedback_progress"] = 1.0 if reduced else clampf(elapsed / SURFACE_SECONDS, 0.0, 1.0)
		var display: Dictionary = display_state(before, after, flights, elapsed, reduced, 0.0)
		if elapsed >= FLIGHT_SECONDS or reduced:
			shown = scene._death_hold_presentation(before, after, shown)
		scene._render_board_state(display, shown)
		if elapsed >= duration or reduced: break
		await scene.get_tree().process_frame

static func animate(scene: Control, before: Dictionary, after: Dictionary, flights: Array[Dictionary], base: Dictionary = {}, first_frame: Callable = Callable(), companion: Callable = Callable()) -> void:
	var reduced: bool = scene._reduced_motion_enabled()
	var events: Array[Dictionary] = Outcome.prepare(scene._surface_events_between(before, after))
	var departure: Array[Dictionary]
	var arrival: Array[Dictionary]
	var landing_tiles: Array
	for path: Dictionary in flights: landing_tiles.append(path["to"])
	for event: Dictionary in events:
		if landing_tiles.has(event.get("tile")) and str(event.get("kind", "")) != "terrain_created": arrival.append(event)
		else: departure.append(event)
	var texts: Array[Dictionary] = scene._player_action_floating_texts(before, after)
	var flight_keys: Array
	for path: Dictionary in flights: flight_keys.append(path["actor_key"])
	var departure_texts: Array[Dictionary]
	var arrival_texts: Array[Dictionary]
	for entry: Dictionary in texts:
		if flight_keys.has(str(entry.get("reaction_actor_key", ""))): arrival_texts.append(entry)
		else: departure_texts.append(entry)
	var started: int = scene._combat_pacing.presentation_usec()
	var landed: bool = false
	var first: bool = true
	scene._play_outcome_sounds(departure)
	var departure_elements: Array
	for event: Dictionary in departure: departure_elements.append(Outcome.element(event))
	var arrival_sounds: Array[Dictionary]
	for event: Dictionary in arrival:
		if not departure_elements.has(Outcome.element(event)): arrival_sounds.append(event)
	while true:
		var elapsed: float = float(scene._combat_pacing.presentation_usec() - started) / 1000000.0
		var contact: float = 0.0 if reduced else LAND_SECONDS
		if elapsed >= contact and not landed:
			landed = true
			scene._play_outcome_sounds(arrival_sounds)
		var shown: Dictionary = decorate(scene.board_view, flights, elapsed, reduced, base)
		shown["surface_feedback_events"] = departure + arrival if landed else departure
		shown["surface_feedback_progress"] = 1.0 if reduced else clampf(elapsed / SURFACE_SECONDS, 0.0, 1.0)
		# Independent clocks let the rock rise at zero and arrival effects start
		# at contact, even while the departure's final frames remain submitted.
		var surface_frames: Dictionary = {}
		for event: Dictionary in departure: surface_frames[event.get("tile", Vector2i(-1, -1))] = {"events": departure, "progress": shown["surface_feedback_progress"]}
		if landed:
			for event: Dictionary in arrival: surface_frames[event.get("tile", Vector2i(-1, -1))] = {"events": arrival, "progress": 1.0 if reduced else clampf((elapsed - contact) / SURFACE_SECONDS, 0.0, 1.0)}
		shown["throw_surface_frames"] = surface_frames
		shown["floating_texts"] = Floating.animate_entries(departure_texts, elapsed, reduced)
		if landed: shown["floating_texts"].append_array(Floating.animate_entries(arrival_texts, elapsed - contact, reduced))
		if companion.is_valid(): companion.call(shown, elapsed)
		if first and first_frame.is_valid(): first_frame.call()
		first = false
		scene._render_board_state(display_state(before, after, flights, elapsed, reduced), shown)
		if elapsed >= contact + (0.1 if reduced else SURFACE_SECONDS): break
		await scene.get_tree().process_frame
	scene._queue_player_popup_group(departure_texts, (0.0 if reduced else LAND_SECONDS) + SURFACE_SECONDS)
	scene._queue_player_popup_group(arrival_texts, SURFACE_SECONDS)
	scene._render_board_state(after, {})

## The body keeps its production painter canvas and team rim. Its shadow is a
## separate z=0 child so raising the body never raises or enlarges the shadow.
static func sync_depth(board: Control, canvas: Control, unit: Dictionary, bindings: Dictionary) -> void:
	var key: String = str(unit.get("key", ""))
	var airborne: bool = (board.presentation.get("unit_throw_ground_positions", {}) as Dictionary).has(key)
	canvas.z_index = AIRBORNE_Z if airborne else 0
	var shadow: Control = canvas.get_node_or_null("ThrowGroundShadow")
	if not airborne:
		if is_instance_valid(shadow): shadow.visible = false
		return
	if not is_instance_valid(shadow):
		shadow = board.get_script().new()
		shadow.name = "ThrowGroundShadow"
		shadow.set("_is_dynamic_render_layer", true)
		shadow.set("_render_layer_kind", "unit_throw_shadow")
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(shadow)
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for field: String in bindings: shadow.set(field, bindings[field])
	shadow.set("_unit_outline_actor", unit)
	shadow.material = canvas.material
	shadow.z_index = -AIRBORNE_Z
	board._copy_resolved_board_layout_to(shadow)
	shadow.visible = true
	shadow.queue_redraw()

static func draw_ground_shadow(view: Control, unit: Dictionary) -> void:
	var key: String = str(unit.get("key", ""))
	var ground: Vector2 = view.presentation["unit_throw_ground_positions"][key]
	var offset: Vector2 = ground - view._unit_center(unit)
	view.draw_set_transform(offset)
	view._draw_unit_shadow(unit)
	view.draw_set_transform(Vector2.ZERO)
