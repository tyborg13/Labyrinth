extends RefCounted
## Contact-only decisions. The existing tile player owns depth, visibility and time.

const Throw = preload("res://scripts/displacement_throw.gd")
const Burst = preload("res://scripts/tile_burst_fx.gd")
const Outcome = preload("res://scripts/combat_outcome_feedback.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Game = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const INVALID := Vector2i(-1, -1)
const REPLACED: String = "contact_burst_replaced"
const CONTACT_TILES: String = "contact_burst_tiles"
const SHOT_PATH: String = "res://scripts/shot_fx.gd"
const Shot = preload("res://scripts/shot_fx.gd")
const SURFACE_ELEMENTS: Dictionary = {"ice": "ice", "rubble": "earth", "fire": "fire", "electrified": "lightning"}
var _before: Dictionary
var _step: Dictionary
var _step_hits: Dictionary
var _enabled: bool
var _replace_fallbacks: bool
var _seen: Dictionary
var _surface_marks: Dictionary
var _erupt_or_dive_started: bool
var _erupt_pending_hits: Dictionary
var _bramble_started: bool
var _covered: Dictionary
var _higher: Dictionary
var _shot: Script

func begin(before: Dictionary, step: Dictionary = {}, enabled: bool = true) -> void:
	_before = {"surface_event_sequence": before.get("surface_event_sequence", 0), "defiance_remaining": before.get("defiance_remaining", 0),
		"defiance_event_revision": before.get("defiance_event_revision", 0)}
	for key: String in ["player", "enemies", "illusions", "terrain"]:
		if before.has(key): _before[key] = before[key].duplicate(true)
	_step = step
	_step_hits.clear()
	var dragon: Dictionary = Dragon.profile(step)
	_enabled = enabled and dragon.get("element") != "shadow" and dragon.get("enemy") != "noctyrax"
	_replace_fallbacks = _enabled and dragon.is_empty()
	_seen.clear()
	_covered.clear()
	_higher.clear()
	_erupt_or_dive_started = false
	_erupt_pending_hits.clear()
	_bramble_started = false

func clear() -> void:
	begin({}, {}, false)
	_surface_marks.clear()

func reserve(specs: Array, grid: Array, visible: Callable) -> void:
	for spec: Dictionary in specs:
		for entry: Dictionary in Burst.plan(spec, grid, {}, visible, false):
			_covered[entry["tile"]] = true

func reserve_strike(strike: Burst.StrikeCue) -> void:
	if strike != null: reserve_strike_tiles(strike.tiles)

func reserve_strike_tiles(tiles: Array[Vector2i]) -> void:
	for tile: Vector2i in tiles:
		_higher[tile] = true
		_covered[tile] = true

func reserve_dragon(schedule: Array[Dictionary], grid: Array, visible: Callable) -> void:
	reserve(schedule.map(func(entry: Dictionary) -> Dictionary: return entry["spec"]), grid, visible)
	for tile: Vector2i in _covered:
		_higher[tile] = true

func ordered_specs(specs: Array, grid: Array, visible: Callable) -> Array[Dictionary]:
	var selected: Array[Dictionary]
	var claimed: Dictionary = _higher.duplicate()
	for candidate: Dictionary in specs:
		var excluded: Dictionary
		var accepted: bool = false
		for entry: Dictionary in Burst.plan(candidate, grid, {}, visible, false):
			var tile: Vector2i = entry["tile"]
			if claimed.has(tile):
				excluded[tile] = true
			else:
				claimed[tile] = true
				accepted = true
		if not accepted: continue
		var spec_entry: Dictionary = candidate
		if not excluded.is_empty():
			spec_entry = candidate.duplicate(false)
			excluded.merge(candidate.get("excluded_tiles", {}))
			spec_entry["excluded_tiles"] = excluded
		selected.append(spec_entry)
	return selected

func reserve_shot(effect: Dictionary) -> bool:
	var id: String = (_shot if _shot != null else Shot).resolve(effect)
	if not Shot.has_hit(id): return false
	_covered[effect.get("umbra_original_to", effect.get("to", INVALID))] = true
	return true

static func spec(name: String, tile: Vector2i, hit: bool) -> Dictionary:
	return {"name": name, "center": tile, "tiles": [tile], "contact_hits": {tile: true} if hit else {}}

func include_outcome(before: Dictionary, after: Dictionary, events: Array = []) -> void:
	_step_hits.merge(Burst.step_hit_tiles(before, after, _footprint))
	Burst.include_event_hits(_step_hits, events, before)

func append_attack(specs: Array, effect: Dictionary, before: Dictionary, after: Dictionary, visible: Callable, shot_effect: Dictionary = {}) -> void:
	if not _enabled or bool(effect.get("preview", false)) or effect.has("chain_index"): return
	var dragon: Dictionary = Dragon.profile(effect)
	if not dragon.is_empty():
		if dragon.get("geometry") == "physical":
			_append_physical(specs, effect, before, after, visible)
		elif not _covered.is_empty():
			effect[CONTACT_TILES] = _covered.duplicate()
		return
	var kind: String = str(effect.get("kind", ""))
	var action: String = str(effect.get("action_type", kind))
	var tile: Vector2i = effect.get("umbra_original_to", effect.get("to", INVALID))
	var name: String = Burst.for_element(str(effect.get("element", effect.get("_card_element", "none"))))
	var has_shot_hit: bool = false
	if kind in ["ranged", "push", "pull"]:
		var descriptor: Dictionary = shot_effect if not shot_effect.is_empty() else effect
		var id: String = (_shot if _shot != null else Shot).resolve(descriptor)
		if not id.is_empty():
			effect[Shot.RESOLVED_KEY] = id
			has_shot_hit = Shot.has_hit(id)
			if has_shot_hit and _tile_drawn(after.get("grid", []), tile, visible):
				if _covered.has(tile): effect[Shot.SKIP_HIT] = true
				else: reserve_shot(descriptor)
	if name.is_empty(): return
	var single: bool = kind in ["melee", "ranged"] and action not in ["push", "pull"]
	if single and not has_shot_hit:
		include_outcome(before, after, effect.get("surface_events", []))
		_add(specs, name, tile, _step_hits.has(tile), after.get("grid", []), visible)
	if single and _covered.has(tile):
		effect[CONTACT_TILES] = {tile: true}
		if not has_shot_hit and kind == "ranged":
			effect[Burst.REPLACE_TARGETED] = true
	elif kind in ["aoe", "lightning_strikes", "push", "pull"] or action in ["push", "pull"]:
		effect[CONTACT_TILES] = _covered.duplicate()
		if name == "shadow" and not _covered.is_empty() and Burst.replaces_elemental_area(effect):
			effect[Burst.REPLACE_TARGETED] = true
		for event: Dictionary in after.get("surface_events", []):
			if int(event.get("sequence", 0)) <= int(before.get("surface_event_sequence", 0)): continue
			if event.get("kind") == "force_collision":
				for contact_tile: Vector2i in _collision_tiles(event):
					effect[CONTACT_TILES][contact_tile] = true
		# Keep the decal/tail decision above on its original coverage. These
		# additional stamps replace painting without shortening the action.
		if kind == "aoe" and not effect.get(Burst.ACTIVE, false):
			include_outcome(before, after, effect.get("surface_events", []))
			for contact: Vector2i in effect.get("burst_tiles", effect.get("tiles", [])):
				_add(specs, name, contact, _step_hits.has(contact), after.get("grid", []), visible)
			effect[Burst.ACTIVE] = true
			if Burst.replaces_elemental_area(effect):
				effect[Burst.REPLACE_TARGETED] = true

func _append_physical(specs: Array, effect: Dictionary, before: Dictionary, after: Dictionary, visible: Callable) -> void:
	var name: String = Burst.for_element(str(effect.get("element", "none")))
	var hits: Dictionary = Burst.hit_tiles(before, after, _footprint)
	var occupied: Dictionary
	for unit: Dictionary in Throw.actors(before).values():
		if int(unit.get("hp", 0)) <= 0: continue
		var footprint: Dictionary = {"pos": unit["pos"], "footprint": _footprint(unit)}
		for tile: Vector2i in Surface.footprint_tiles(footprint):
			occupied[tile] = true
	var tiles: Array[Vector2i] = Dragon.tiles(effect)
	if effect.has("umbra_original_to") and effect.get("kind") == "melee":
		tiles.assign([effect["umbra_original_to"]])
	var covered: Dictionary = _covered.duplicate()
	for tile: Vector2i in tiles:
		if not _tile_drawn(after.get("grid", []), tile, visible): continue
		covered[tile] = true
		if occupied.has(tile): _add(specs, name, tile, hits.has(tile), after.get("grid", []), visible)
	effect[CONTACT_TILES] = covered

static func mask_strike_decals(shown: Dictionary, tiles: Array[Vector2i]) -> void:
	if not shown.has("impact_decals"): return
	var decals: Array[Dictionary]
	for original: Dictionary in shown["impact_decals"]:
		var decal: Dictionary = original
		if tiles.has(decal.get("tile", INVALID)) and not decal.get("baked_strike", false):
			decal = original.duplicate(false)
			decal["baked_strike"] = true
		decals.append(decal)
	shown["impact_decals"] = decals

static func suppresses_decal(effect: Dictionary, tile: Vector2i) -> bool:
	var covered: Dictionary = effect.get(CONTACT_TILES, {})
	if covered.has(tile): return true
	# The loss popup names the anchor of a large target. The contact names
	# the tile struck, so the old decal at the anchor would be a second hit.
	var kind: String = str(effect.get("kind", ""))
	return kind in ["melee", "ranged"] and str(effect.get("action_type", kind)) not in ["push", "pull"] and not covered.is_empty()

static func _footprint(unit: Dictionary) -> Vector2i:
	var raw: Variant = unit.get("footprint", Vector2i.ONE)
	var size: Vector2i = raw if raw is Vector2i else Vector2i(int(raw[0]), int(raw[1]))
	var authored: Array = Game.enemies().get(str(unit.get("type", "")), {}).get("footprint", [1, 1])
	return size.max(Vector2i(int(authored[0]), int(authored[1])))

static func _collision_tiles(event: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = [event.get("anchor", event.get("tile", INVALID))]
	for blocker: Dictionary in event.get("blockers", []):
		if str(blocker.get("kind", "")) in ["enemy", "illusion", "player"] and int(blocker.get("damage", 0)) > 0:
			tiles.append(blocker.get("tile", INVALID))
	return tiles

static func _tile_drawn(grid: Array, tile: Vector2i, visible: Callable) -> bool:
	return tile != INVALID and Paths.is_passable(grid, tile) and Paths.tile_id(grid, tile) != "void" and visible.call(tile)

func _add(specs: Array, name: String, tile: Vector2i, hit: bool, grid: Array, visible: Callable) -> bool:
	if name.is_empty() or not _tile_drawn(grid, tile, visible):
		return false
	if not _covered.has(tile):
		_covered[tile] = true
		specs.append(spec(name, tile, hit))
	return true

func observe(shown: Dictionary, state: Dictionary, visible: Callable) -> Array[Dictionary]:
	var specs: Array[Dictionary]
	if _enabled:
		_observe_shadow_ambush(specs, shown, state, visible)
		_mechanic(specs, shown, state, visible)
	var events: Array = shown.get("surface_feedback_events", [])
	var has_decals: bool = _replace_fallbacks and shown.has("impact_decals")
	if not events.is_empty() or has_decals:
		include_outcome(_before, state, events)
	# Surface events also arrive through retained overlap and displacement frames.
	# Process the published beat once and retain the drawing mark across submissions.
	if not events.is_empty():
		# Planned attacks and strikes have already reserved their tiles.
		# Resolve collisions, traps and leaving ground before ambient feedback.
		for event: Dictionary in events:
			_observe_event(specs, event, state, visible)
		if _replace_fallbacks:
			for event: Dictionary in events:
				_observe_surface_contact(specs, event, state, visible)
		shown["surface_feedback_events"] = _marked_events(events)
	if has_decals:
		_observe_decals(specs, shown, state, visible)
	if _surface_marks.is_empty(): return specs
	for key: String in ["throw_surface_frames", "combat_feel_surface_frames"]:
		if not shown.has(key): continue
		var frames: Dictionary = shown[key]
		for tile: Vector2i in shown[key]:
			var frame: Dictionary = frames[tile]
			var frame_events: Array = _marked_events(frame["events"])
			if is_same(frame_events, frame["events"]): continue
			if is_same(frames, shown[key]): frames = frames.duplicate(false)
			var marked: Dictionary = frame.duplicate(false)
			marked["events"] = frame_events
			frames[tile] = marked
		shown[key] = frames
	var replaced_traps: Dictionary
	for event: Dictionary in shown.get("surface_feedback_events", []):
		if event.get(REPLACED) == "trap": replaced_traps[event["tile"]] = true
	if not replaced_traps.is_empty() and shown.has("trap_effects"):
		var traps: Array = shown["trap_effects"].duplicate(false)
		for index: int in traps.size():
			if not replaced_traps.has(traps[index].get("pos")): continue
			var trap: Dictionary = traps[index].duplicate(false)
			trap[Burst.ACTIVE] = true
			traps[index] = trap
		shown["trap_effects"] = traps
	return specs

func _observe_shadow_ambush(specs: Array, shown: Dictionary, state: Dictionary, visible: Callable) -> void:
	if not _step.get("en03_veil", false) or not _step.has("strike_step"): return
	var effect: Dictionary = shown.get("effect", {})
	if effect.get("kind") != "melee" or effect.get("element") != "shadow" or effect.get("actor_key") != _step.get("actor_key"): return
	if _covered.has(effect.get("umbra_original_to", effect.get("to", INVALID))): return
	# The cutout submits this nested strike only when its contact pose lands.
	append_attack(specs, effect, _step.get("blink_after", _before), state, visible)

func _observe_event(specs: Array, event: Dictionary, state: Dictionary, visible: Callable) -> void:
	if not _before.has("player"): return
	var sequence: int = int(event.get("sequence", 0))
	if sequence <= int(_before.get("surface_event_sequence", 0)) or _seen.has(sequence): return
	_seen[sequence] = true
	var grid: Array = state.get("grid", [])
	var tile: Vector2i = event.get("tile", INVALID)
	match str(event.get("kind", "")):
		"force_collision":
			var contacts: Array[Vector2i] = _collision_tiles(event)
			if _add(specs, "impact", contacts[0], _step_hits.has(contacts[0]), grid, visible):
				_surface_marks[sequence] = "collision"
			for index: int in range(1, contacts.size()):
				_add(specs, "impact", contacts[index], _step_hits.has(contacts[index]), grid, visible)
			return
		"trap_triggered":
			var name: String = Burst.for_trap(str(event.get("element", "none")))
			if _add(specs, name, tile, _step_hits.has(tile), grid, visible):
				_surface_marks[sequence] = "trap"
			for contact: Vector2i in event.get("wake_tiles", []):
				_add(specs, name, contact, _step_hits.has(contact), grid, visible)
			return
	var broken: String = str(event.get("break_surface", Outcome.broken_surface(event)))
	if SURFACE_ELEMENTS.has(broken) and _add(specs, Burst.for_element(SURFACE_ELEMENTS[broken]), tile, _step_hits.has(tile), grid, visible):
		_surface_marks[sequence] = "break"

func _observe_surface_contact(specs: Array, event: Dictionary, state: Dictionary, visible: Callable) -> void:
	var sequence: int = int(event.get("sequence", 0))
	if sequence <= int(_before.get("surface_event_sequence", 0)) or _surface_marks.has(sequence): return
	var element: String = str(event.get("feedback_element", ""))
	# A placement with no elemental core still used the floor glow, including
	# placements whose core was already owned by the primary attack.
	if element.is_empty() and event.get("kind") in ["surface_created", "surface_replaced"]:
		element = Outcome.element(event)
	if element.is_empty(): return
	var grid: Array = state.get("grid", [])
	var tiles: Array = (event.get("tiles", []) as Array).duplicate()
	tiles.append(event.get("tile", INVALID))
	for tile: Vector2i in tiles:
		if _add(specs, Burst.for_element(element), tile, _step_hits.has(tile), grid, visible):
			_surface_marks[sequence] = "surface"

func _observe_decals(specs: Array, shown: Dictionary, state: Dictionary, visible: Callable) -> void:
	var grid: Array = state.get("grid", [])
	for decal: Dictionary in shown["impact_decals"]:
		if decal.get("baked_strike", false): continue
		var tile: Vector2i = decal.get("tile", INVALID)
		if _covered.has(tile): continue
		var name: String = Burst.for_element(str(decal.get("element", "none")))
		_add(specs, name, tile, _step_hits.has(tile), grid, visible)
	# RunScene keeps the original list for its feedback clock. Only the board
	# submission drops the remaining ground decals.
	shown.erase("impact_decals")

func _marked_events(events: Array) -> Array:
	var result: Array = events
	for index: int in events.size():
		var event: Dictionary = events[index]
		var mark: String = _surface_marks.get(int(event.get("sequence", 0)), "")
		if mark.is_empty(): continue
		if is_same(result, events): result = events.duplicate(false)
		var marked: Dictionary = event.duplicate(false)
		marked[REPLACED] = mark
		result[index] = marked
	return result

func _mechanic(specs: Array, shown: Dictionary, state: Dictionary, visible: Callable) -> void:
	var effect: Dictionary = shown.get("contact_bramble_step", shown.get("effect", {}))
	var bramble: String = str(effect.get("en04_mechanic", ""))
	var grid: Array = state.get("grid", [])
	if not _bramble_started and bramble in ["grow_bramble", "bramble_expiry"]:
		_bramble_started = true
		var tiles: Array = (effect.get("tiles", []) as Array).duplicate()
		for terrain: Dictionary in effect.get("expired_bramble", []):
			tiles.append(terrain.get("pos", INVALID))
		for tile: Vector2i in tiles:
			_add(specs, "earth", tile, false, grid, visible)
	var flying: Dictionary = shown.get("unit_world_positions", {})
	for tile: Vector2i in _erupt_pending_hits.keys():
		if flying.has(_erupt_pending_hits[tile]): continue
		if Paths.is_passable(grid, tile) and Paths.tile_id(grid, tile) != "void" and visible.call(tile):
			specs.append(spec("earth", tile, true))
		_erupt_pending_hits.erase(tile)
	var kind: String = str(_step.get("kind", ""))
	if _erupt_or_dive_started or kind not in ["burrow", "erupt"] or not _step.has("state_after"): return
	var key: String = str(_step.get("actor_key", ""))
	var motion: Dictionary = shown.get("burrow_grub_motion", {}).get(key, {})
	var after: Dictionary = _step.get("state_after", state)
	if motion.is_empty():
		if kind == "erupt" and shown.has("en01_erupt"): return
		if _burrowed(state, key) != (kind == "burrow"): return
	else:
		var action = preload("res://scripts/maquette_cutout_runtime/action.gd")
		var clip: Dictionary = action.data_for("burrow_grub")["clips"][kind]
		if float(motion.get("phase", 0.0)) < float(clip.get("contact", 1.0)): return
	_erupt_or_dive_started = true
	var center: Vector2i = _step.get("from" if kind == "burrow" else "to", INVALID)
	var tiles: Dictionary = {center: true}
	var health: Dictionary = {}
	if kind == "erupt":
		var marked: Vector2i = _step.get("to", INVALID)
		for enemy: Dictionary in _before.get("enemies", []):
			if key == "enemy_%d" % int(enemy.get("id", -1)):
				marked = enemy.get("erupt_tile", marked)
				break
		tiles[marked] = true
		var old_units: Dictionary = Throw.actors(_before)
		var new_units: Dictionary = Throw.actors(after)
		for unit_key: String in old_units:
			if unit_key == key: continue
			var previous: Dictionary = old_units[unit_key]
			if int(previous.get("hp", 0)) <= 0 or not Surface.footprint_tiles(previous).has(marked): continue
			if int(new_units.get(unit_key, {}).get("hp", 0)) < int(previous["hp"]):
				health[marked] = unit_key
	for tile: Vector2i in tiles:
		if not health.has(tile) or not flying.has(health[tile]):
			_add(specs, "earth", tile, health.has(tile), grid, visible)
		elif not _covered.has(tile):
			# The throw publishes the victim's damage number when it lands.
			_covered[tile] = true
			_erupt_pending_hits[tile] = health[tile]

static func _burrowed(state: Dictionary, key: String) -> bool:
	for unit: Dictionary in state.get("enemies", []):
		if key == "enemy_%d" % int(unit.get("id", -1)): return bool(unit.get("burrowed", false))
	return false
