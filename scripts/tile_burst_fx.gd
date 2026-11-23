extends RefCounted
## Resolved contact plans and retained rear/front quads. No action awaits playback.

const Fit = preload("res://scripts/pixel_sheet_fit.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Burst = preload("res://scripts/burst_rules.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Lightning = preload("res://scripts/lightning_strike_presentation.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Outcome = preload("res://scripts/combat_outcome_feedback.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
const Flying = preload("res://scripts/enemy_mechanics/flying.gd")
const SHADER = preload("res://shaders/tile_burst.gdshader")
const SELF_DATA_PATH: String = "res://data/self_bursts.json"
const STRIKE_DATA_PATH: String = "res://data/strikes.json"
const CLOCK_QUANTUM_SECONDS: float = 1.0 / 1000000.0
const PALETTE_SIZE: int = 64
const REVEAL_SECONDS_PRECISION: float = 0.0001
const DATA_PATH: String = "res://data/tile_bursts.json"
const ACTIVE: String = "tile_burst_active"
const REPLACE_TARGETED: String = "tile_burst_replace_targeted"
const MAX_TILES: int = 24
const INVALID := Vector2i(-1, -1)

static var _catalogs: Dictionary
# Retained for the area bake verifier. Materials bind their own catalogue.
static var _palette: PackedColorArray

var _catalog: Dictionary
var _self_effects: bool
var _strike_effects: bool

class StrikeCue extends RefCounted:
	var tiles: Array[Vector2i]
	var element: String
	var row: int
	var contact_frame: int
	var contact_offset_usec: int
	var reduced: bool
	var clock: Callable
	var predicted_contact_usec: int
	var contact_usec: int = -1
	var contact_process_frame: int = -1
	var stamped_tiles: Dictionary

	func begin(start_usec: int, presentation_clock: Callable) -> void:
		if clock.is_valid(): return
		clock = presentation_clock
		predicted_contact_usec = start_usec + contact_offset_usec

	func land() -> void:
		contact_usec = clock.call()
		contact_process_frame = Engine.get_process_frames()

	func seconds_from_contact() -> float:
		if contact_usec < 0:
			return minf(0.0, (int(clock.call()) - predicted_contact_usec) / 1000000.0)
		if contact_process_frame == Engine.get_process_frames(): return 0.0
		return maxf(0.0, (int(clock.call()) - contact_usec) / 1000000.0)

	# Playback submits its existing contact frame even when a slow frame skips
	# across the predicted boundary. Hold the last falling cell until then.
	func frame_at(seconds: float, fps: float) -> int:
		if reduced: return -1 if contact_usec < 0 else contact_frame
		var frame: int = contact_frame + floori((seconds + CLOCK_QUANTUM_SECONDS) * fps)
		return mini(frame, contact_frame - 1) if contact_usec < 0 else frame

class Stamp extends Node2D:
	var tile: Vector2i
	var front: bool
	var unit: Dictionary
	var birth: float
	var birth_frame: int
	var tile_visible: bool = true
	var reduced: bool
	var still_frame: int
	var sample: Vector3i
	var cull_extent: Vector2
	var strike: StrikeCue

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1, 1), Color.WHITE)

	func present(frame: int) -> void:
		if frame != sample.x:
			sample.x = frame
			set_instance_shader_parameter("frame_row_mirror", sample)

var ink: ShaderMaterial
var cell_px: int
var sheet_index: int = -1
var _requested: Vector2i
var _load_path: String
var _load_index: int = -1
var _source_thread: Thread
var _seconds: float
var _stamps: Array[Stamp]
var _extent: Vector2
var _warmup: Stamp

func _init(self_effects: bool = false, strike_effects: bool = false) -> void:
	_self_effects = self_effects
	_strike_effects = strike_effects
	_catalog = _catalog_for(STRIKE_DATA_PATH if strike_effects else SELF_DATA_PATH if self_effects else DATA_PATH)

static func _catalog_for(path: String) -> Dictionary:
	if not _catalogs.has(path):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var widths := PackedInt32Array()
		var palette := PackedColorArray()
		for entry: Dictionary in data["sizes"]:
			widths.append(int(entry["tile_cells"][0]))
		for color: String in data["palette"]:
			palette.append(Color(color))
		palette.resize(PALETTE_SIZE)
		if path == DATA_PATH: _palette = palette
		_catalogs[path] = {"data": data, "widths": widths, "palette": palette}
	return _catalogs[path]

static func metadata() -> Dictionary:
	return _catalog_for(DATA_PATH)["data"]

static func self_metadata() -> Dictionary:
	return _catalog_for(SELF_DATA_PATH)["data"]

static func strike_metadata() -> Dictionary:
	return _catalog_for(STRIKE_DATA_PATH)["data"]

static func replaces_fall(profile: Dictionary) -> bool:
	return profile.get("geometry") == "meteor" and strike_metadata()["strike_for_element"].has(profile.get("element"))

static func strike_element(effect: Dictionary) -> String:
	if bool(effect.get("preview", false)): return ""
	if effect.get("en02_mechanic") == "icefall_land": return "ice"
	var profile: Dictionary = Lightning.profile() if effect.get("kind") == "lightning_strikes" else Dragon.profile(effect)
	return str(profile["element"]) if replaces_fall(profile) else ""

# The timed player submits frame 1 at elapsed zero. Reuse its rounded frame
# period and the first frame with the existing result to schedule the fall.
static func strike_frame_cue(effect: Dictionary, first_contact_frame: int, frame_seconds: float, reduced: bool) -> StrikeCue:
	return strike_cue(effect, maxi(0, first_contact_frame - 1) * maxi(1, roundi(frame_seconds * 1000000.0)), reduced)

static func strike_cue(effect: Dictionary, contact_offset_usec: int, reduced: bool) -> StrikeCue:
	var element: String = strike_element(effect)
	if element.is_empty(): return null
	var tiles: Array[Vector2i] = Dragon.tiles(effect)
	if tiles.is_empty(): return null
	var data: Dictionary = strike_metadata()
	var name: String = data["strike_for_element"][element]
	var cue := StrikeCue.new()
	cue.tiles = tiles
	cue.element = element
	cue.row = data["rows"][name + "_front"]
	cue.contact_frame = data["contact_frame"][name]
	cue.contact_offset_usec = 0 if reduced else contact_offset_usec
	cue.reduced = reduced
	return cue

static func reveal_seconds(effect: String, reduced: bool) -> float:
	return 0.0 if reduced else float(self_metadata()["reveal_seconds"][effect])

# The manifest resolves time to four decimals. A tenth 60 Hz tick and the
# authored 0.1667 seconds describe the same presentation boundary.
static func reveal_reached(elapsed: float, deadline: float) -> bool:
	return snappedf(elapsed, REVEAL_SECONDS_PRECISION) >= snappedf(deadline, REVEAL_SECONDS_PRECISION)

static func choice_for(tile_px: float, render_height: int) -> Vector2i:
	return Fit.choose(tile_px, render_height, _catalog_for(DATA_PATH)["widths"])

static func select_player(card: Dictionary, card_id: String, action: Dictionary, effect: Dictionary) -> String:
	var kind: String = str(action.get("type", ""))
	if kind not in ["aoe", "detonate", "destroy_illusion", "burst_terrain"]:
		return ""
	var targeted: bool = kind == "aoe" and replaces_elemental_area(effect)
	var element: String = str(effect.get("element", "none"))
	if targeted and not metadata()["replace_targeted"].has(element):
		return ""
	var base_id: String = str(card.get("base_card_id", card_id))
	var cards: Dictionary = metadata()["burst_for_card"]
	if cards.has(base_id):
		return str(cards[base_id])
	match kind:
		"destroy_illusion": return "light"
		"burst_terrain": return "impact"
		"detonate": element = Burst.fx_element(action)
	return for_element(element)

static func select_enemy(step: Dictionary) -> String:
	if str(step.get("kind", "")) not in ["aoe", "lightning_strikes"] or not Dragon.profile(step).is_empty():
		return ""
	var element: String = str(step.get("element", "none"))
	if element == "shadow" and not replaces_elemental_area(step):
		return ""
	if replaces_elemental_area(step) and not metadata()["replace_targeted"].has(element):
		return ""
	var intents: Dictionary = metadata()["burst_for_intent"]
	var intent: String = str(step.get("intent_id", ""))
	if intents.has(intent):
		return str(intents[intent])
	if step.get("kind") == "lightning_strikes":
		element = "lightning"
	return for_element(element)

## Some authored rigs publish their effect only when their own contact pose
## lands. Use that submission as the trigger without changing the adapter clock.
static func adapter_contact(step: Dictionary, state: Dictionary) -> Dictionary:
	if not Dragon.profile(step).is_empty(): return {}
	var name: String = select_enemy(step)
	var specs: Array[Dictionary] = event_specs(step.get("surface_events", []), true)
	specs.append_array(trap_specs(step.get("triggered_traps", []), state))
	if not name.is_empty():
		step[ACTIVE] = true
		step[REPLACE_TARGETED] = replaces_elemental_area(step)
		specs.push_front(area_spec(name, step))
	if specs.is_empty(): return {}
	var before: Dictionary = state.duplicate(true)
	before.merge((step.get("move_after", {}) as Dictionary).duplicate(true), true)
	return {"step": step, "before": before, "specs": specs}

static func replaces_elemental_area(effect: Dictionary) -> bool:
	if effect.get("kind") != "aoe": return false
	if effect.get("element", effect.get("_card_element", "none")) == "shadow":
		# Shadow areas have no authored elemental style, including self-centred casts.
		return effect.get("action_type", "aoe") in ["aoe", "terrain_burst"] \
			and not bool(effect.get("preview", false)) and not effect.has("chain_index") and Dragon.profile(effect).is_empty()
	return int(effect.get("range", 0)) > 0 and Attack.uses_authored_elemental_attack(effect)

## Keep separate surface breaks and collision feedback on replaced spell tiles.
static func without_replaced_impacts(events: Array, tile: Vector2i, element: String) -> Array:
	var result: Array = events
	for index: int in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if event.get("tile", INVALID) != tile or Outcome.element(event) != element: continue
		var kind: String = str(event.get("kind", ""))
		if event.get("feedback_element", "") != element and kind not in ["surface_created", "surface_replaced"]: continue
		if is_same(result, events): result = events.duplicate(false)
		if str(event.get("break_surface", "")).is_empty():
			result.remove_at(index)
		else:
			var broken: Dictionary = event.duplicate(false)
			broken["feedback_element"] = ""
			result[index] = broken
	return result

static func for_element(element: String) -> String:
	return str(metadata()["burst_for_element"].get(element, "steel"))

static func for_trap(element: String) -> String:
	return "impact" if element in ["", "none"] else for_element(element)

static func player_spec(name: String, effect: Dictionary, action: Dictionary, facing: Vector2i) -> Dictionary:
	var spec: Dictionary = area_spec(name, effect)
	if name == "steel" and action.get("type") == "aoe" and int(action.get("range", 0)) == 0:
		spec["sweep"] = facing
	return spec

static func area_spec(name: String, effect: Dictionary) -> Dictionary:
	return {
		"name": name,
		"center": effect.get("center", effect.get("to", effect.get("from", INVALID))),
		"tiles": effect.get("burst_tiles", effect.get("tiles", [])),
	}

static func trap_specs(traps: Array, state: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary]
	for trap: Dictionary in traps:
		var center: Vector2i = trap.get("pos", INVALID)
		var name: String = for_trap(str(trap.get("element", "none")))
		if not name.is_empty():
			specs.append({"name": name, "center": center, "tiles": Burst.cross(state, center), "arrival": true})
	return specs

static func mark_traps(traps: Array) -> Array[Dictionary]:
	var marked: Array[Dictionary]
	for trap: Dictionary in traps:
		var entry: Dictionary = trap.duplicate(false)
		entry[ACTIVE] = not for_trap(str(trap.get("element", "none"))).is_empty()
		marked.append(entry)
	return marked

static func event_specs(events: Array, include_detonate: bool, trap_state: Dictionary = {}) -> Array[Dictionary]:
	var specs: Array[Dictionary]
	for event: Dictionary in events:
		var kind: String = str(event.get("kind", ""))
		if kind == "trap_triggered" and not trap_state.is_empty():
			specs.append_array(trap_specs([{"pos": event.get("tile", INVALID), "element": event.get("element", "none")}], trap_state))
		elif kind == "powder_keg_burst":
			specs.append({"name": "impact", "center": event.get("tile", INVALID), "tiles": event.get("burst_tiles", event.get("tiles", []))})
		elif include_detonate and kind == "detonate":
			var sources: Array = event.get("burst_sources", [])
			if sources.is_empty(): continue
			var element: String = Burst.fx_element({"detonate_surface": event.get("surface", "")})
			specs.append({"name": for_element(element), "center": sources[0], "tiles": event.get("burst_tiles", event.get("tiles", []))})
	return specs

static func hit_tiles(before: Dictionary, after: Dictionary, footprint_for: Callable = Callable(), arrival: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var old_player: Dictionary = before.get("player", {})
	if _lost_pool(old_player, after.get("player", {})) or int(after.get("defiance_remaining", 0)) < int(before.get("defiance_remaining", 0)):
		var new_player: Dictionary = after.get("player", {})
		result[new_player.get("pos", old_player.get("pos", INVALID)) if arrival else old_player.get("pos", INVALID)] = true
	for group: String in ["enemies", "illusions", "terrain"]:
		var remaining: Dictionary = {}
		for unit: Dictionary in after.get(group, []):
			remaining[unit.get("id")] = unit
		for unit: Dictionary in before.get(group, []):
			var current: Dictionary = remaining.get(unit.get("id"), {})
			var previous_hp: int = int(unit.get("hp", 0))
			if previous_hp <= 0:
				continue
			if group == "terrain":
				if int(current.get("hp", 0)) < previous_hp:
					result[unit.get("pos", INVALID)] = true
			elif _lost_pool(unit, current):
				var origin: Vector2i = unit.get("pos", INVALID)
				if arrival: origin = current.get("pos", origin)
				var footprint: Vector2i = footprint_for.call(unit) if group == "enemies" and footprint_for.is_valid() else Vector2i.ONE
				for y: int in footprint.y:
					for x: int in footprint.x:
						result[origin + Vector2i(x, y)] = true
	return result

static func _lost_pool(before: Dictionary, after: Dictionary) -> bool:
	return Burst.took_damage(Burst.damage_pools(before), after) or int(after.get(Maneuver.MANTLE_FIELD, 0)) < int(before.get(Maneuver.MANTLE_FIELD, 0))

static func step_hit_tiles(before: Dictionary, after: Dictionary, footprint_for: Callable) -> Dictionary:
	# A moved actor's loss counts at its original attack tile and where it
	# stopped. The latter can be owned by a collision or trap surface beat.
	var hits: Dictionary = hit_tiles(before, after, footprint_for)
	hits.merge(hit_tiles(before, after, footprint_for, true))
	var terrain_after: Dictionary
	for unit: Dictionary in after.get("terrain", []):
		terrain_after[unit.get("id")] = int(unit.get("hp", 0))
	for unit: Dictionary in before.get("terrain", []):
		if int(terrain_after.get(unit.get("id"), 0)) < int(unit.get("hp", 0)):
			hits[unit.get("pos", INVALID)] = true
	if int(after.get("defiance_event_revision", 0)) > int(before.get("defiance_event_revision", 0)):
		for state: Dictionary in [before, after]:
			hits[state.get("player", {}).get("pos", INVALID)] = true
	include_event_hits(hits, after.get("surface_events", []), before)
	return hits

static func include_event_hits(hits: Dictionary, events: Array, before: Dictionary) -> void:
	var after_sequence: int = int(before.get("surface_event_sequence", 0))
	for event: Dictionary in events:
		if int(event.get("sequence", 0)) <= after_sequence: continue
		var tile: Vector2i = event.get("tile", INVALID)
		match event.get("kind", ""):
			"force_collision":
				var mover_damage: Variant = event.get("target_damage", event.get("damage"))
				if mover_damage == null and event.has("total_damage"):
					mover_damage = int(event["total_damage"]) - int(event.get("blocker_damage", 0))
				# Explicit zero damage is meaningful. Old collision payloads
				# with no amount retain their original hit cue.
				if (mover_damage == null or int(mover_damage) > 0) and not _flying_collision_actor(before, event.get("actor_kind", ""), event.get("id", -1)):
					hits[event.get("anchor", tile)] = true
				for blocker: Dictionary in event.get("blockers", []):
					if int(blocker.get("damage", 0)) > 0 and not _flying_collision_actor(before, blocker.get("kind", ""), blocker.get("id", -1)):
						hits[blocker.get("tile", INVALID)] = true
			"surface_damage":
				if int(event.get("amount", event.get("health_lost", 0))) > 0: hits[tile] = true
			"crystal_mantle_broken":
				hits[tile] = true
			"actor_death":
				hits[event.get("unit", {}).get("pos", tile)] = true

static func _flying_collision_actor(before: Dictionary, kind: String, id: int) -> bool:
	# Collision journals report attempted damage even for airborne enemies.
	if kind == "enemy":
		for enemy: Dictionary in before.get("enemies", []):
			if int(enemy.get("id", -1)) == id: return Flying.flying(enemy)
	return false

static func plan(spec: Dictionary, grid: Array, hits: Dictionary, visible: Callable, reduced: bool) -> Array[Dictionary]:
	var data: Dictionary = metadata()
	var rows: Dictionary = data["rows"]
	var simultaneous: bool = bool(spec.get("simultaneous", false))
	var center: Vector2i = spec["center"]
	var name: String = spec["name"]
	var still_frame: int = int(data.get("reduced_motion_frame_by_burst", {}).get(name, data["reduced_motion_frame"]))
	var tiles: Array[Vector2i]
	var ordered: Dictionary = {}
	var result: Array[Dictionary]
	if name.is_empty() or center == INVALID: return result
	for tile: Vector2i in spec["tiles"]:
		if not ordered.has(tile) and Paths.is_passable(grid, tile) and Paths.tile_id(grid, tile) != "void" and visible.call(tile):
			ordered[tile] = tiles.size()
			tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a: int = Paths.manhattan(center, a)
		var distance_b: int = Paths.manhattan(center, b)
		if distance_a != distance_b: return distance_a < distance_b
		return int(ordered[a]) < int(ordered[b])
	)
	if not simultaneous and tiles.size() > MAX_TILES: tiles.resize(MAX_TILES)
	var facing: Vector2i = spec.get("sweep", Vector2i.ZERO)
	if facing != Vector2i.ZERO and not reduced:
		var forward: float = Vector2(facing).angle()
		# Isometric projection preserves clockwise orientation in tile coordinates.
		tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var angle_a: float = _sweep_angle(a - center, forward)
			var angle_b: float = _sweep_angle(b - center, forward)
			if is_equal_approx(angle_a, angle_b):
				return Paths.manhattan(center, a) < Paths.manhattan(center, b)
			return angle_a < angle_b
		)
	# Keep the original cap and delay when another player owns a planned tile.
	var excluded: Dictionary = spec.get("excluded_tiles", {})
	for index: int in tiles.size():
		var tile: Vector2i = tiles[index]
		if excluded.has(tile): continue
		var delay: float = minf(float(data["max_delay_seconds"]), Paths.manhattan(center, tile) * float(data["delay_per_tile_seconds"]))
		if facing != Vector2i.ZERO:
			delay = float(data["max_delay_seconds"]) * index / maxi(1, tiles.size() - 1)
		var hit: bool = hits.has(tile)
		var row_key: String = name + ("_hit" if hit else "_floor")
		result.append({
			"tile": tile, "hit": hit, "delay": 0.0 if reduced or simultaneous else delay,
			"still_frame": still_frame,
			"rear": int(rows[row_key + "_rear"]), "front": int(rows[row_key + "_front"]),
		})
	return result

static func _sweep_angle(delta: Vector2i, forward: float) -> float:
	return 0.0 if delta == Vector2i.ZERO else fposmod(Vector2(delta).angle() - forward, TAU)

func sync_size(board: Control) -> void:
	var viewport: Viewport = board.get_viewport()
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var height: int = roundi(viewport.get_visible_rect().size.y * stretch.y)
	var settled_scale: float = board.get_global_transform().get_scale().x * stretch.x
	_requested = Fit.choose(board._tile_width() * settled_scale, height, _catalog["widths"])
	if sheet_index < 0:
		var path: String = _catalog["data"]["sizes"][_requested.y]["atlas"]
		var texture: Texture2D = ResourceLoader.load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(Image.load_from_file(path))
		_use_sheet(texture, _requested)
		_warm(board)
	elif _requested.y == sheet_index:
		if _requested.x != cell_px:
			cell_px = _requested.x
			ink.set_shader_parameter("cell_px", float(cell_px))
	else:
		_request_sheet()

func _request_sheet() -> void:
	if _load_index >= 0: return
	_load_path = _catalog["data"]["sizes"][_requested.y]["atlas"]
	if ResourceLoader.exists(_load_path):
		if ResourceLoader.load_threaded_request(_load_path) == OK:
			_load_index = _requested.y
	else:
		_source_thread = Thread.new()
		if _source_thread.start(_decode_image.bind(_load_path)) == OK:
			_load_index = _requested.y

static func _decode_image(path: String) -> Image:
	return Image.load_from_file(path)

func _poll_sheet() -> bool:
	if _load_index < 0: return false
	var texture: Texture2D
	if _source_thread != null:
		if _source_thread.is_alive(): return false
		var source: Image = _source_thread.wait_to_finish()
		_source_thread = null
		if source != null: texture = ImageTexture.create_from_image(source)
	else:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_load_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return false
		if status == ResourceLoader.THREAD_LOAD_LOADED: texture = ResourceLoader.load_threaded_get(_load_path)
	var completed: int = _load_index
	_load_index = -1
	if _requested.y == completed and texture != null:
		_use_sheet(texture, _requested)
		return true
	if _requested.y != completed and _requested.y != sheet_index:
		_request_sheet()
	return false

func _use_sheet(texture: Texture2D, fit: Vector2i) -> void:
	if texture == null: return
	if ink == null:
		ink = ShaderMaterial.new()
		ink.shader = SHADER
		ink.set_shader_parameter("palette", _catalog["palette"])
	sheet_index = fit.y
	cell_px = fit.x
	var sheet: Dictionary = _catalog["data"]["sizes"][sheet_index]
	var frame_cells := Vector2i(sheet["frame_cells"][0], sheet["frame_cells"][1])
	var centre_cell := Vector2i(sheet["tile_centre_cell"][0], sheet["tile_centre_cell"][1])
	_extent = Vector2(maxi(centre_cell.x, frame_cells.x - centre_cell.x), maxi(centre_cell.y, frame_cells.y - centre_cell.y))
	ink.set_shader_parameter("atlas", texture)
	ink.set_shader_parameter("cell_px", float(cell_px))
	ink.set_shader_parameter("frame_cells", frame_cells)
	ink.set_shader_parameter("centre_cell", centre_cell)

func _warm(board: Control) -> void:
	if DisplayServer.get_name() == "headless": return
	_warmup = Stamp.new()
	_warmup.name = "TileBurstPrewarm"
	_warmup.material = ink
	_warmup.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	board.add_child(_warmup)
	# The warm draw samples the last frame, which is fully transparent.
	var row: String = "lightning_front" if _strike_effects else "block_rear" if _self_effects else "steel_floor_rear"
	var data: Dictionary = _catalog["data"]
	_warmup.set_instance_shader_parameter("frame_row_mirror", Vector3i(int(data["frames"]) - 1, data["rows"][row], 0))
	RenderingServer.frame_post_draw.connect(_finish_warm, CONNECT_ONE_SHOT)

func _finish_warm() -> void:
	if is_instance_valid(_warmup): _warmup.queue_free()
	_warmup = null

func spawn(board: Control, specs: Array, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	if ink == null or specs.is_empty(): return
	var hits: Dictionary = hit_tiles(before, after, board._resolved_unit_footprint)
	var step_hits: Dictionary
	var have_step_hits: bool = false
	for spec: Dictionary in specs:
		var arrival: bool = bool(spec.get("arrival", false))
		if arrival and not have_step_hits:
			step_hits = step_hit_tiles(before, after, board._resolved_unit_footprint)
			have_step_hits = true
		var impact_tiles: Dictionary = spec.get("contact_hits", step_hits if arrival else hits)
		for entry: Dictionary in plan(spec, after.get("grid", []), impact_tiles, board._board_tile_is_visible_to_player, reduced):
			_spawn_pair(board, entry, reduced)

func spawn_self(board: Control, effect: String, unit: Dictionary, delay: float, reduced: bool) -> void:
	if ink == null: return
	var tile: Vector2i = unit.get("pos", INVALID)
	if tile == INVALID or not board._board_tile_is_visible_to_player(tile): return
	var rows: Dictionary = _catalog["data"]["rows"]
	_spawn_pair(board, {
		"tile": tile, "unit": unit, "delay": 0.0 if reduced else delay,
		"rear": rows[effect + "_rear"], "front": rows[effect + "_front"],
	}, reduced)

func _spawn_pair(board: Control, entry: Dictionary, reduced: bool) -> void:
	for front: bool in [false, true]:
		_spawn_stamp(board, entry, reduced, front)

func spawn_strikes(board: Control, cue: StrikeCue) -> void:
	if ink == null or (cue.reduced and cue.contact_usec < 0): return
	for tile: Vector2i in cue.tiles:
		if cue.stamped_tiles.has(tile) or not board._board_tile_is_visible_to_player(tile): continue
		if _spawn_stamp(board, {"tile": tile, "delay": 0.0, "front": cue.row}, cue.reduced, true, cue):
			cue.stamped_tiles[tile] = true

func _spawn_stamp(board: Control, entry: Dictionary, reduced: bool, front: bool, strike: StrikeCue = null) -> bool:
	var stamp := Stamp.new()
	stamp.name = "SkyStrikeFront" if strike != null else "TileBurstFront" if front else "TileBurstRear"
	stamp.tile = entry["tile"]
	stamp.unit = entry.get("unit", {})
	stamp.front = front
	stamp.birth = _seconds + float(entry["delay"])
	stamp.birth_frame = Engine.get_process_frames()
	stamp.reduced = reduced
	if reduced and strike == null:
		stamp.still_frame = int(entry.get("still_frame", _catalog["data"]["reduced_motion_frame"]))
	stamp.strike = strike
	var mirror: int = 0 if _self_effects or strike != null else (stamp.tile.x + stamp.tile.y) & 1
	stamp.sample = Vector3i(-1, entry["front" if front else "rear"], mirror)
	stamp.material = ink
	var parent: CanvasItem = _layer(board, stamp)
	if not is_instance_valid(parent):
		stamp.free()
		return false
	parent.add_child(stamp, true)
	stamp.set_instance_shader_parameter("frame_row_mirror", stamp.sample)
	_place(board, stamp, parent)
	_stamps.append(stamp)
	_sample(stamp)
	return true

func _layer(board: Control, stamp: Stamp) -> CanvasItem:
	var layers: Dictionary = board._scene_front_effect_render_layers_by_tile if stamp.front else board._scene_back_effect_render_layers_by_tile
	if _self_effects:
		return layers.get(board.draw_tile_for_unit_origin(stamp.unit, stamp.tile))
	var slot: CanvasItem = layers.get(stamp.tile)
	if not is_instance_valid(slot): return null
	if _strike_effects: return slot
	for unit: Dictionary in board._visible_units_cache:
		var origin: Vector2i = unit.get("pos", INVALID)
		var footprint: Vector2i = board._resolved_unit_footprint(unit)
		if not Rect2i(origin, footprint).has_point(stamp.tile): continue
		var host: Vector2i = board._effective_unit_tile(unit)
		var other_slot: CanvasItem = layers.get(host)
		if not is_instance_valid(other_slot): continue
		if (stamp.front and other_slot.get_index() > slot.get_index()) or (not stamp.front and other_slot.get_index() < slot.get_index()):
			slot = other_slot
	return slot

func _place(board: Control, stamp: Stamp, parent: CanvasItem) -> void:
	if stamp.get_parent() != parent: stamp.reparent(parent, false)
	var center: Vector2 = board.world_position_for_unit_origin(stamp.unit, stamp.tile) if _self_effects else board._tile_center(stamp.tile)
	if stamp.position != center: stamp.position = center
	# Shader expansion and snapping extend beyond the retained unit quad.
	var scale: Vector2 = (board.get_viewport().get_stretch_transform() * board.get_global_transform_with_canvas()).get_scale().abs()
	var extent: Vector2 = (_extent * cell_px + Vector2.ONE) / scale
	if stamp.cull_extent != extent:
		stamp.cull_extent = extent
		RenderingServer.canvas_item_set_custom_rect(stamp.get_canvas_item(), true, Rect2(-extent, extent * 2.0))

func sync_placement(board: Control) -> void:
	for stamp: Stamp in _stamps:
		if not is_instance_valid(stamp): continue
		var parent: CanvasItem = _layer(board, stamp)
		if is_instance_valid(parent):
			_place(board, stamp, parent)
			stamp.tile_visible = board._board_tile_is_visible_to_player(stamp.tile)
			if _self_effects and stamp.unit.has("key"):
				var key: String = stamp.unit["key"]
				stamp.tile_visible = stamp.tile_visible and board._visible_units_cache.any(
					func(unit: Dictionary) -> bool: return unit.get("key") == key)
			_sample(stamp)
		else:
			stamp.tile_visible = false
			stamp.hide()

func has_active() -> bool:
	return not _stamps.is_empty()

func advance(delta: float, process_frame: int) -> bool:
	_seconds += delta
	for index: int in range(_stamps.size() - 1, -1, -1):
		var stamp: Stamp = _stamps[index]
		if is_instance_valid(stamp):
			# RunScene's process-frame continuation may submit before this tick.
			if stamp.birth_frame == process_frame: stamp.birth += delta
			if _sample(stamp): continue
			stamp.queue_free()
		_stamps[index] = _stamps.back()
		_stamps.pop_back()
	return _poll_sheet()

func _sample(stamp: Stamp) -> bool:
	var data: Dictionary = _catalog["data"]
	if stamp.strike != null:
		var seconds: float = stamp.strike.seconds_from_contact()
		var strike_frame: int = stamp.strike.frame_at(seconds, float(data["fps"]))
		var strike_expired: bool = seconds >= float(data["reduced_motion_seconds"]) if stamp.reduced else strike_frame >= int(data["frames"])
		stamp.visible = stamp.tile_visible and strike_frame >= 0 and not strike_expired
		if stamp.visible: stamp.present(strike_frame)
		return not strike_expired
	var age: float = _seconds - stamp.birth
	var frame: int = floori(age * float(data["fps"]))
	var expired: bool = age >= float(data["reduced_motion_seconds"]) if stamp.reduced else frame >= int(data["frames"])
	stamp.visible = stamp.tile_visible and age >= 0.0 and not expired
	if stamp.visible: stamp.present(stamp.still_frame if stamp.reduced else frame)
	return not expired

func clear() -> void:
	for stamp: Stamp in _stamps:
		if is_instance_valid(stamp):
			stamp.hide()
			stamp.queue_free()
	_stamps.clear()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _load_index < 0: return
	if _source_thread != null and _source_thread.is_started():
		_source_thread.wait_to_finish()
	elif ResourceLoader.load_threaded_get_status(_load_path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
		ResourceLoader.load_threaded_get(_load_path)

## Observe the final board submission so overlapping, cutout and inline attack
## frames use the same first-visible-number boundary as the regular popup loop.
var _feedback_scope: Array
var _feedback_pools: Dictionary
var _feedback_turn_ending: bool
var _seen_popup_batches: Dictionary

func present_feedback(board: Control, state_changed: bool) -> void:
	var state: Dictionary = board.combat_state
	var shown: Dictionary = board.presentation
	var scope: Array = [state.get("seed", 0), state.get("room_coord", INVALID)]
	var new_scope: bool = scope != _feedback_scope
	if new_scope:
		_feedback_scope = scope
		_feedback_pools.clear()
		_seen_popup_batches.clear()
	var reduced: bool = bool(shown.get("reduced_motion", false))
	var gains_by_tile: Dictionary
	var declared_gains: Dictionary
	for value: Variant in shown.get("floating_texts", []):
		if not value is Dictionary: continue
		var entry: Dictionary = value
		if not entry.has("gain") or float(entry.get("alpha", 1.0)) <= 0.0: continue
		var tile: Vector2i = entry["tile"]
		var batch: Dictionary = entry.get("gain_batch", {})
		var gains: Array = batch.get("gains", [entry["gain"]])
		_append_gains(declared_gains, tile, gains)
		var id: String = batch.get("id", entry.get("screen_layout_key", entry.get("screen_layout_id", "")))
		if not id.is_empty():
			if _seen_popup_batches.has(id): continue
			_seen_popup_batches[id] = true
		_append_gains(gains_by_tile, tile, gains)

	if state_changed or new_scope or _feedback_pools.is_empty():
		var turn_ending: bool = bool(state.get("player_turn_ending", false))
		var turn_boundary: bool = turn_ending != _feedback_turn_ending
		_feedback_turn_ending = turn_ending
		var effect: Dictionary = shown.get("effect", {})
		var attack: bool = str(effect.get("kind", "")) in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]
		var pools: Dictionary
		_observe_pools(board, state.get("player", {}), "player", pools, gains_by_tile, declared_gains, turn_boundary, attack)
		for group: String in ["enemies", "illusions"]:
			for unit: Dictionary in state.get(group, []):
				_observe_pools(board, unit, "%s_%d" % ["enemy" if group == "enemies" else "illusion", int(unit.get("id", -1))], pools, gains_by_tile, declared_gains, turn_boundary, attack)
		_feedback_pools = pools

	for tile: Vector2i in gains_by_tile:
		var unit: Dictionary = _recipient_at(board, tile)
		if unit.is_empty(): continue
		var data: Dictionary = _catalog["data"]
		var names: Array[String]
		for gain: String in gains_by_tile[tile]:
			var effect: String = str(data["effect_for_gain"].get(gain, ""))
			if not effect.is_empty(): names.append(effect)
		var order: Array = data["order_on_tile"]
		names.sort_custom(func(a: String, b: String) -> bool: return order.find(a) < order.find(b))
		for index: int in mini(2, names.size()):
			spawn_self(board, names[index], unit, index * float(data["second_on_tile_delay_seconds"]), reduced)

static func _append_gains(target: Dictionary, tile: Vector2i, gains: Array) -> void:
	if not target.has(tile): target[tile] = []
	target[tile].append_array(gains)

func _observe_pools(board: Control, unit: Dictionary, key: String, pools: Dictionary, gains: Dictionary, declared: Dictionary, turn_boundary: bool, attack: bool) -> void:
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0: return
	var current := Vector4i(int(unit.get("expose", 0)), int(unit.get("block", 0)), int(unit.get("stoneskin", 0)), int(unit.get("hp", 0)))
	pools[key] = current
	if not _feedback_pools.has(key): return
	var previous: Vector4i = _feedback_pools[key]
	if current.x <= previous.x and not turn_boundary and not (attack and current.w > previous.w): return
	var tile: Vector2i = unit.get("pos", INVALID)
	var visible_unit: Dictionary = _recipient_at(board, tile)
	if visible_unit.get("key") != key: return
	var floated: Array = declared.get(tile, [])
	# Expose follows the resolved status badge when there is no status float.
	# Turn-boundary rewards and attack healing can also land without a popup.
	if current.x > previous.x and not floated.has("expose"): _append_gains(gains, tile, ["expose"])
	if turn_boundary and current.y > previous.y and not floated.has("block"): _append_gains(gains, tile, ["block"])
	if turn_boundary and current.z > previous.z and not floated.has("stoneskin"): _append_gains(gains, tile, ["stoneskin"])
	if (turn_boundary or attack) and current.w > previous.w and not floated.has("heal"): _append_gains(gains, tile, ["heal"])

static func _recipient_at(board: Control, tile: Vector2i) -> Dictionary:
	if not board._board_tile_is_visible_to_player(tile): return {}
	for unit: Dictionary in board._visible_units_cache:
		if str(unit.get("role", "")) not in ["player", "enemy", "illusion"]: continue
		var origin: Vector2i = unit["pos"]
		if Rect2i(origin, board._resolved_unit_footprint(unit)).has_point(tile):
			return unit
	return {}
