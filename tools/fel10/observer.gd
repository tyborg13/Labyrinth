extends RefCounted
## Inspect submitted board state, retained render nodes and live pixel commands.
## Rules outcomes alone are insufficient evidence. All coordinates are viewport pixels.

const Bounds = preload("res://tools/fel10/draw_bounds.gd")
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Atlas = preload("res://tools/fel10/atlas_observer.gd")
const Game = preload("res://scripts/game_data.gd")
const Card = preload("res://scripts/card_widget.gd")
const HeroTrail = preload("res://scripts/hero_strike_trail.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")
const Chain = preload("res://scripts/chain_bolt_fx.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const INVALID := Vector2i(-1, -1)
const STATUSES := ["expose", "shock", "freeze", "immobilize", "stoneskin", "frost_armor", "charge", "kindled_bonus"]
const ELEMENTS := ["fire", "ice", "earth", "air", "lightning"]
const SURFACES := ["fire", "ice", "electrified", "rubble"]
const TERRAIN := {"wooden_crate": "crate", "wooden_box": "box", "powder_keg": "powder_keg",
	"crag_outcrop": "outcrop", "ice_pillar": "ice_pillar", "bramble": "bramble",
	"dragon_spire": "worldspine", "raised_cover": "raised_cover"}

var capture_rects: bool
var observations: Dictionary
var _atlas := Atlas.new()
var _pixel_hosts: Dictionary
var _pickups: Dictionary
var _bolts: Dictionary
var _items: Dictionary
var _previous: Dictionary
var _at_turn_start: Dictionary


func _init(tree: SceneTree) -> void:
	tree.node_added.connect(_node_added)
	tree.node_removed.connect(_node_removed)


func _node_added(node: Node) -> void:
	if node.get_script() == Pixel:
		_pixel_hosts[node.get_instance_id()] = node
	elif node.get_script() == Card and node.get_parent().name == "CardFxLayer" and Game.card_def(node.card_id).get("item", false):
		_items[node.get_instance_id()] = node
	elif node.get_script() == Chain:
		_bolts[node.get_instance_id()] = node
	elif node.name in [&"ItemAcquisitionIcon", &"EquipmentAcquisitionIcon"]:
		_pickups[node.get_instance_id()] = node


func _node_removed(node: Node) -> void:
	_pixel_hosts.erase(node.get_instance_id())
	_pickups.erase(node.get_instance_id())
	_bolts.erase(node.get_instance_id())
	_items.erase(node.get_instance_id())


func baseline(scene: Node) -> void:
	_previous = _board_state(scene.board_view)
	_at_turn_start = {}
	_at_turn_start = sample(scene, false).duplicate()


func sample(scene: Node, enemy_turn: bool) -> Dictionary:
	observations = {}
	var board: Control = scene.board_view
	if not is_instance_valid(board) or not board.is_visible_in_tree(): return observations
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	if effect.get("preview", false): effect = {}
	_atlas.sample(board, shown, effect, enemy_turn, _emit, capture_rects)
	_sample_presentation(board, shown, effect, enemy_turn)
	_sample_pixel_hosts(board, effect, enemy_turn)
	_sample_board_changes(board)
	for bolt: Sprite2D in _bolts.values():
		if board.is_ancestor_of(bolt) and bolt.is_visible_in_tree() and bolt.texture != null:
			var center: Vector2 = board.get_global_transform_with_canvas() * bolt.from_point.lerp(bolt.to_point, 0.5)
			_emit("chain_bolt", center, "ChainBolt texture", bolt.phase, Bounds.screen(bolt, bolt.get_rect()), "bolt:%d" % bolt.get_instance_id())
	for icon: Control in _pickups.values():
		if scene.is_ancestor_of(icon) and icon.is_visible_in_tree() and icon.modulate.a > 0.0:
			_emit("loot_pickup", icon.get_global_rect().get_center(), str(icon.name), -1, Bounds.control(icon), "icon:%d" % icon.get_instance_id())
	for item: Control in _items.values():
		if scene.is_ancestor_of(item) and item.is_visible_in_tree() and item.z_index == 1490 and item.modulate.a > 0.0:
			_emit("item_use", item.get_global_rect().get_center(), "consuming item card proxy", -1, Bounds.control(item), "proxy:%d" % item.get_instance_id())
	for id: String in _at_turn_start.keys():
		if observations.has(id):
			observations.erase(id)
		else:
			_at_turn_start.erase(id)
	return observations


func _emit(id: String, center: Vector2, source: String, phase: int = -1, _rect: Rect2 = Rect2(), _instance: String = "") -> void:
	if not observations.has(id):
		observations[id] = {"center": center, "source": source, "phase": phase}


func _rect(id: String, rect: Rect2, source: String, instance: String) -> void:
	if rect.has_area(): _emit(id, rect.get_center(), source, -1, rect, instance)


func _at(board: Control, id: String, tile: Vector2i, source: String) -> void:
	if tile != INVALID and board._board_tile_is_visible_to_player(tile):
		_emit(id, board.get_global_transform_with_canvas() * board._tile_center(tile), source)


func _sample_presentation(board: Control, shown: Dictionary, effect: Dictionary, enemy_turn: bool) -> void:
	var tile: Vector2i = effect.get("center", effect.get("to", effect.get("tile", INVALID)))
	var kind: String = str(effect.get("kind", ""))
	var actor: String = str(effect.get("actor_key", ""))
	var hero: bool = actor == "player" if not actor.is_empty() else not enemy_turn
	var prefix: String = "player_" if hero else "enemy_"
	var strike: Dictionary = shown.get("strike_trail_effect", effect)
	var layers: Array = [board._effects_render_layer]
	var front: Control = board._scene_front_effect_render_layers_by_tile.get(strike.get("to", INVALID))
	if is_instance_valid(front): layers.append(front)
	var strike_tile: Vector2i = strike.get("to", strike.get("center", INVALID))
	for layer: Control in layers:
		if not is_instance_valid(layer): continue
		var mesh: Node = layer._strike_trail_layer
		if not is_instance_valid(mesh) or mesh._batches.is_empty(): continue
		var hero_trail: bool = HeroTrail.handles(strike)
		_at(board, "player_melee_trail" if hero_trail else "enemy_melee_trail", strike_tile, "live strike mesh")
		if not hero_trail and layer._enemy_strike_trail.resolved.get("kind") == "claw_marks":
			_at(board, "enemy_claw_marks", strike_tile, "live claw marks mesh")
	var action_type: String = str(effect.get("action_type", kind))
	if kind == "aoe" and not effect.get(Bursts.ACTIVE, false):
		var progress: float = float(shown.get("effect_progress", 1.0))
		if board._aoe_resolution_footprint_visibility(effect, progress) > 0.0:
			for target: Vector2i in effect.get("tiles", []):
				_at(board, prefix + "area", target, "visible area footprint")
	if effect.get("grave_surgeon_melee", false):
		_at(board, "surgeon_jab", tile, "grave surgeon jab painter")
	if effect.get("en04_mechanic") == "lob_land" and float(shown.get("effect_progress", 0.0)) >= Lob.CONTACT_PROGRESS:
		_at(board, "enemy_lob_landing", tile, "Lob contact presentation")
	if kind == "erupt" or not (shown.get("en01_erupt", {}) as Dictionary).is_empty():
		var erupt: Dictionary = shown.get("en01_erupt", {})
		_at(board, "enemy_erupt", _actor_tile(board, erupt.get("actor_key", actor), tile), "Erupt body presentation")
	for key: String in shown.get("burrow_grub_motion", {}):
		var clip: String = shown["burrow_grub_motion"][key].get("clip", "")
		if clip in ["burrow", "erupt"]:
			_at(board, "enemy_" + clip, _actor_tile(board, key, tile), "Burrow Grub cutout pose")
	if effect.get("en04_mechanic") == "grow_bramble":
		for terrain: Dictionary in board.combat_state.get("terrain", []):
			if terrain.get("kind") == "bramble":
				_at(board, "enemy_grow_bramble", terrain["pos"], "bramble growth submission")
				break
	for decal: Dictionary in shown.get("impact_decals", []):
		if decal.get("element", "none") == "none" and not decal.get("baked_strike", false) and float(shown.get("impact_progress", 1.0)) < board.IMPACT_DECAL_FADE_PROGRESS:
			_at(board, "neutral_impact_decal", decal["tile"], "visible non-baked neutral decal")
	for key: String in board._enemy_shadow_dissolve_effects_by_key:
		var dissolve: Control = board._enemy_shadow_dissolve_effects_by_key[key]
		if dissolve.is_visible_in_tree():
			_emit("death_dissolve", dissolve.get_global_rect().get_center(), "live dissolve Control")
	for key: String in shown.get("combat_feel_flash_actor_keys", []):
		_at(board, "hit_flash", _actor_tile(board, key, INVALID), "combat-feel flash profile")
	if board._camera_kick_progress < 1.0 and board._camera_kick_amplitude > 0.0:
		var center: Vector2 = board.get_viewport().get_visible_rect().get_center()
		_emit("camera_kick", center, "live camera tween")
	for burst: Dictionary in shown.get("burst_effects", []):
		_at(board, "death_burst", burst.get("tile", burst.get("center", INVALID)), "death Burst submission")
	var positions: Dictionary = shown.get("unit_world_positions", {})
	if not positions.is_empty() and action_type in ["push", "pull"]:
		_at(board, prefix + action_type, tile, "active forced displacement")
	if action_type == "pull" and not hero:
		for unit: Dictionary in board._visible_units_cache:
			if unit.get("key") != actor or unit.get("type") != "chainbound_gaoler": continue
			var rig: Node = board.unit_cutout_renderer(unit)
			if is_instance_valid(rig) and rig.get("clip") == "reel":
				_at(board, "enemy_pull", unit["pos"], "live Chain Reel cutout pose")
	for key: String in positions:
		var center: Vector2 = board.get_global_transform_with_canvas() * (positions[key] as Vector2)
		if key == "player" and action_type not in ["blink", "push", "pull"] and not enemy_turn:
			_emit("player_move", center, "moving hero body")
		elif key.begins_with("enemy_") and action_type not in ["push", "pull"]:
			_emit("enemy_move", center, "moving enemy body")
			if shown.get("harrier_travel_variant") == "retreat":
				_emit("enemy_retreat", center, "retreat travel variant")
	for trap: Dictionary in shown.get("trap_effects", []):
		var element: String = str(trap.get("element", ""))
		if element in ELEMENTS: _at(board, "trap_" + element, trap.get("pos", trap.get("tile", INVALID)), "live trap feedback")
	for entry: Dictionary in shown.get("floating_texts", []):
		if float(entry.get("alpha", 1.0)) <= 0.0: continue
		var location: Vector2i = entry.get("tile", INVALID)
		match str(entry.get("icon", "")):
			"stagger": _at(board, "status_stagger", location, "Stagger popup")
			"illuminate": _at(board, "light_placement", location, "Light placement popup")
			"surface_fire": _at(board, "tick_fire", location, "Fire damage popup")
		if str(entry.get("text", "")) == "Fatigue":
			_at(board, "fatigue_float", location, "Fatigue popup")
		var resource: String = str(entry.get("resource_kind", ""))
		if entry.get("kind") == "damage": resource = "damage"
		if resource not in ["damage", "block", "heal", "stoneskin", "draw", "card_play"]: continue
		_at(board, "number_" + resource, location, "visible float " + resource)
	for unit: Dictionary in shown.get("death_animation_units", []):
		_at(board, "unit_death", unit.get("pos", INVALID), "death animation submission")
	for terrain: Dictionary in shown.get("terrain_destruction_units", []):
		var terrain_id: String = TERRAIN.get(terrain.get("kind"), "")
		if not terrain_id.is_empty():
			_at(board, "destroy_" + terrain_id, terrain.get("pos", INVALID), "terrain destruction submission")
	for event: Dictionary in shown.get("surface_feedback_events", []):
		_sample_event(board, event)
	for event: Dictionary in shown.get("ground_feedback_events", []):
		_sample_event(board, event)


func _sample_event(board: Control, event: Dictionary) -> void:
	var tile: Vector2i = event.get("tile", INVALID)
	var kind: String = str(event.get("kind", ""))
	var surface: String = str(event.get("surface", ""))
	match kind:
		"status_applied":
			if event.get("status") == "stagger": _at(board, "status_stagger", tile, kind)
		"surface_damage":
			if surface == "fire": _at(board, "tick_fire", tile, kind)
		"surface_conducted":
			_at(board, "lightning_conduction", tile, kind)
		"surface_removed", "surface_consumed":
			if surface in SURFACES: _at(board, "surface_break_" + surface, tile, kind)
		"terrain_created":
			if event.get("terrain_kind") == "crag_outcrop": _at(board, "enemy_outcrop_raise", tile, kind)
		"powder_keg_burst", "worldspine_pulse", "crystal_mantle_broken":
			_at(board, kind, tile, kind)


func _pixel_rect(host: Node2D, run: Dictionary, command: Dictionary) -> Rect2:
	var local: Rect2 = Spell.pixel_bounds(command["draw"], command["args"])
	if not local.has_area(): return Rect2()
	var physical: Rect2 = host._pixel_transform * (command["transform"] as Transform2D) * local
	var cells: Rect2 = Rect2(run["cell_rect"])
	return physical.intersection(Rect2(cells.position * host._grid, cells.size * host._grid))


func _sample_pixel_hosts(board: Control, effect: Dictionary, enemy_turn: bool) -> void:
	for host: Node2D in _pixel_hosts.values():
		if not host.is_visible_in_tree() or not board.is_ancestor_of(host): continue
		for run: Dictionary in host._runs:
			if not run["composite"].visible: continue
			var center: Vector2 = (run["bounds"] as Rect2).get_center()
			for command: Dictionary in run["drawing"].commands:
				var draw: Callable = command["draw"]
				var method: String = str(draw.get_method())
				var rect: Rect2 = _pixel_rect(host, run, command) if capture_rects else Rect2()
				var key: String = "pixel:%d:%s:%s" % [host.get_instance_id(), method, run["element"]]
				if method in ["impact", "travel", "ground", "floor_light", "release"]:
					_emit("pixel_" + method, center, method + " " + str(run["element"]), -1, rect, key)
					if method == "impact" and effect.get("kind") == "aoe":
						_emit("enemy_area" if enemy_turn else "player_area", center, "pixel area impact", -1, rect, key)
				elif method == "draw_line_command" and not effect.is_empty():
					var kind: String = str(effect.get("kind", ""))
					if kind == "ranged":
						_emit(("enemy_" if enemy_turn else "player_") + "ranged_projectile", center, "pixel line", -1, rect, key)


func _sample_board_changes(board: Control) -> void:
	var now: Dictionary = _board_state(board)
	var before: Dictionary = _previous
	_previous = now
	if before.is_empty() or now.is_empty(): return
	for kind: String in SURFACES:
		for tile: Vector2i in now["surfaces"][kind]:
			if not before["surfaces"][kind].has(tile):
				_at(board, "surface_" + kind, tile, "rendered surface " + kind)
	for id: Variant in now["terrain"]:
		var terrain: Array = now["terrain"][id]
		if terrain[0] == "crag_outcrop" and not before["terrain"].has(id):
			_at(board, "enemy_outcrop_raise", terrain[1], "outcrop added to board")
	for key: String in now["units"]:
		var unit: Dictionary = now["units"][key]
		var old: Dictionary = before["units"].get(key, {})
		var tile: Vector2i = unit.get("pos", INVALID)
		if old.is_empty():
			if unit.get("split_birth", false):
				_at(board, "enemy_split", tile, "new body matching active split death")
			continue
		for status: String in STATUSES:
			var prior: int = int(old.get(status, 0))
			var current: int = int(unit.get(status, 0))
			if status == "charge" and current > prior:
				_at(board, "enemy_charge", tile, "charge pip count increased")
			if current != prior:
				_at(board, "status_" + status + ("_gain" if current > prior else "_tick"), tile, "rendered unit status changed")
		if int(old.get("block", 0)) > 0 and int(unit.get("block", 0)) == 0 and int(unit.get("hp", 0)) < int(old.get("hp", 0)):
			_at(board, "block_break", tile, "Block depleted on hit")
	if not before["wind"] and now["wind"]:
		_at(board, "enemy_wind", now["wind_source"], "wind field submitted")
	if now["lights"] != before["lights"]:
		for tile: Vector2i in now["lights"]:
			if not before["lights"].has(tile): _at(board, "light_placement", tile, "rendered Light source")
	if now["stage"] != before["stage"] and now["umbra"].size() < before["umbra"].size():
		for tile: Vector2i in before["umbra"]:
			if not now["umbra"].has(tile):
				_emit("umbra_advance", board.get_global_transform_with_canvas() * board._tile_center(tile), "visible tile lost to Umbra")
				break


func _board_state(board: Control) -> Dictionary:
	var state: Dictionary = board.combat_state
	if state.is_empty(): return {}
	var shown: Dictionary = board.presentation
	var surfaces: Dictionary = {}
	for kind: String in SURFACES:
		surfaces[kind] = Surfaces.tiles(state, kind)
	var terrain: Dictionary = {}
	for object: Dictionary in state.get("terrain", []):
		if int(object.get("hp", object.get("health", 1))) > 0:
			terrain[object["id"]] = [str(object["kind"]), object["pos"]]
	var split_type: String = ""
	for dying: Dictionary in shown.get("death_animation_units", []):
		var spawn: Dictionary = Game.enemy_property(str(dying.get("type", "")), "death_spawn", {})
		if not spawn.is_empty(): split_type = spawn.get("enemy_type", "")
	var units: Dictionary = {}
	for unit: Dictionary in board._visible_units_cache:
		var view: Dictionary = {"pos": unit.get("pos", INVALID), "hp": unit.get("hp", 0), "block": unit.get("block", 0)}
		view["split_birth"] = not split_type.is_empty() and unit.get("type") == split_type
		for field: String in STATUSES: view[field] = unit.get(field, 0)
		units[str(unit.get("key", ""))] = view
	var lights: Dictionary = {}
	for light: Dictionary in shown.get("umbra_light_sources", []):
		if light.get("tethered", false) or str(light.get("id", "")).begins_with("brazier:"): continue
		var tile: Vector2i = light.get("pos", INVALID)
		if tile != INVALID: lights[tile] = true
	var wind: Dictionary = state.get("wind", {})
	return {"terrain": terrain, "surfaces": surfaces, "units": units, "lights": lights,
		"wind": not wind.is_empty(), "wind_source": wind.get("source_tile", state["player"].get("pos", INVALID)),
		"umbra": shown.get("umbra_visible_tiles", []).duplicate(), "stage": shown.get("umbra_stage")}


func _actor_tile(board: Control, key: String, fallback: Vector2i) -> Vector2i:
	for unit: Dictionary in board._visible_units_cache:
		if unit.get("key") == key: return unit.get("pos", fallback)
	return fallback
