extends "res://tools/fel10/observer.gd"
## Capture evidence requires a live painter and an effect-owned rectangle.
## The harvest's broader state/descriptor signals are retained for diagnostics.

const Surgeon = preload("res://scripts/grave_surgeon_cutout/renderer.gd")
const ContactBursts = preload("res://scripts/resolved_contact_bursts.gd")
const StateDraws = preload("res://tools/fel10/state_draw_observer.gd")

var draws: Dictionary
var signals: Dictionary
var _state_draws := StateDraws.new()
var _baseline_instances: Dictionary


func _init(tree: SceneTree) -> void:
	super._init(tree)
	capture_rects = true


func baseline(scene: Node) -> void:
	_state_draws.reset(scene.board_view)
	_baseline_instances = {}
	super.baseline(scene)
	_baseline_instances = draws.duplicate(true)


func sample(scene: Node, enemy_turn: bool) -> Dictionary:
	draws = {}
	signals = super.sample(scene, enemy_turn)
	var board: Control = scene.board_view
	if is_instance_valid(board) and board.is_visible_in_tree() and not board.combat_state.is_empty():
		_state_draws.sample(scene, _rect)
		_sample_painters(board, enemy_turn)
	for id: String in _baseline_instances.keys():
		for key: String in _baseline_instances[id].keys():
			if draws.get(id, {}).has(key):
				draws[id].erase(key)
			else:
				_baseline_instances[id].erase(key)
		if draws.get(id, {}).is_empty(): draws.erase(id)
	return draws


func _emit(id: String, center: Vector2, source: String, phase: int = -1, rect: Rect2 = Rect2(), instance: String = "") -> void:
	super._emit(id, center, source, phase, rect, instance)
	if not rect.has_area() or instance.is_empty(): return
	if not draws.has(id): draws[id] = {}
	var instances: Dictionary = draws[id]
	if instances.has(instance):
		rect = (instances[instance]["rect"] as Rect2).merge(rect)
	instances[instance] = {"rect": rect, "source": source, "phase": phase, "instance": instance}


func _sample_painters(board: Control, enemy_turn: bool) -> void:
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	if effect.get("preview", false): effect = {}
	_sample_trails(board, shown, effect)
	_sample_popups(board)
	_sample_bodies(board, shown, effect, enemy_turn)
	_sample_traps(board, shown)
	_sample_area(board, shown, effect, enemy_turn)
	_sample_surgeon(board, shown, effect)
	_sample_outcrop(board)
	for terrain: Dictionary in shown.get("terrain_destruction_units", []):
		var kind: String = TERRAIN.get(terrain.get("kind"), "")
		if kind.is_empty(): continue
		_rect("destroy_" + kind, Bounds.terrain_destruction(board._scene_render_layers_by_tile.get(terrain.get("pos"), board), terrain),
			"terrain destruction frame texture", "destruction:%s" % terrain.get("id", terrain.get("pos")))
	for key: String in board._enemy_shadow_dissolve_effects_by_key:
		var dissolve: Control = board._enemy_shadow_dissolve_effects_by_key[key]
		if dissolve.is_visible_in_tree():
			_rect("death_dissolve", Bounds.control(dissolve), "live dissolve shader texture", "dissolve:%s" % key)
	if board._camera_kick_progress < 1.0 and board._camera_kick_amplitude > 0.0:
		_rect("camera_kick", Bounds.screen(board, board.rendered_visual_bounds()), "board canvas offset tween", "camera")


func _sample_trails(board: Control, shown: Dictionary, effect: Dictionary) -> void:
	var strike: Dictionary = shown.get("strike_trail_effect", effect)
	var hero: bool = HeroTrail.handles(strike)
	var layers: Array = [board._effects_render_layer]
	for layer: Control in board._scene_front_effect_render_layers_by_tile.values(): layers.append(layer)
	for layer: Control in layers:
		if not is_instance_valid(layer) or not layer.is_visible_in_tree(): continue
		var mesh: Node2D = layer._strike_trail_layer
		if not is_instance_valid(mesh) or mesh._batches.is_empty(): continue
		if mesh.drawn_submission_revision != mesh.submission_revision: continue
		var local := Rect2()
		for batch: Dictionary in mesh._batches:
			var box: Rect2 = Bounds.points(batch["vertices"])
			if box.has_area(): local = local.merge(box) if local.has_area() else box
		var rect: Rect2 = Bounds.screen(mesh, local)
		var key: String = "mesh:%d" % mesh.get_instance_id()
		_rect("player_melee_trail" if hero else "enemy_melee_trail", rect, "drawn strike triangles", key)
		if not hero and layer._enemy_strike_trail.resolved.get("kind") == "claw_marks":
			_rect("enemy_claw_marks", rect, "drawn claw mark triangles", key)


func _sample_popups(board: Control) -> void:
	var layer: Control = board._effects_render_layer
	if not is_instance_valid(layer) or not layer.is_visible_in_tree(): return
	var source: Control = layer
	var layout: Array = layer._floating_text_last_layout
	if layout.is_empty() and not board._floating_text_last_layout.is_empty():
		source = board
		layout = board._floating_text_last_layout
	if DisplayServer.get_name() == "headless" and not board.presentation.get("floating_texts", []).is_empty():
		# The dummy display does not run all retained canvas draw callbacks.
		# Compute the submitted glyph geometry with the same production layout,
		# leaving the board's actual lane cache in its original state.
		source = layer if not layer.presentation.get("floating_texts", []).is_empty() else board
		var saved: Dictionary = source._floating_text_layout_cache
		source._floating_text_layout_cache = saved.duplicate(true)
		layout = source._floating_text_screen_layout(source.get_theme_default_font())
		source._floating_text_layout_cache = saved
	var submitted: Array = source.presentation.get("floating_texts", [])
	for popup: Dictionary in layout:
		var entry: Dictionary = popup["entry"]
		if float(entry.get("alpha", 1.0)) <= 0.0 or not entry in submitted: continue
		var rect: Rect2 = popup["rendered_rect"]
		rect.position += popup.get("layout_offset", Vector2.ZERO)
		rect = Bounds.screen(source, rect)
		var key: String = "popup:%s" % popup["key"]
		var kind: String = str(entry.get("resource_kind", ""))
		if entry.get("kind") == "damage": kind = "damage"
		if kind in ["damage", "block", "heal", "stoneskin", "draw", "card_play"]:
			_rect("number_" + kind, rect, "drawn floating glyphs", key)
		match str(entry.get("icon", "")):
			"stagger": _rect("status_stagger", rect, "drawn Stagger popup", key)
			"surface_fire": _rect("tick_fire", rect, "drawn Fire damage popup", key)
		if entry.get("text") == "Fatigue": _rect("fatigue_float", rect, "drawn Fatigue popup", key)


func _sample_bodies(board: Control, shown: Dictionary, effect: Dictionary, enemy_turn: bool) -> void:
	var kind: String = str(effect.get("action_type", effect.get("kind", "")))
	var positions: Dictionary = shown.get("unit_world_positions", {})
	var actor: String = str(effect.get("actor_key", ""))
	var hero: bool = actor == "player" if not actor.is_empty() else not enemy_turn
	var flash: Array = shown.get("combat_feel_flash_actor_keys", [])
	for unit: Dictionary in board._visible_units_cache:
		var key: String = str(unit.get("key", ""))
		var tile: Vector2i = unit.get("pos", INVALID)
		if not board._board_tile_is_visible_to_player(tile): continue
		if key in flash:
			_rect("hit_flash", _body(board, unit), "actor texture with hit flash", "flash:" + key)
		if positions.has(key):
			var rect: Rect2 = _body(board, unit)
			if kind in ["push", "pull"]:
				_rect(("player_" if hero else "enemy_") + kind, rect, "displaced body draw rect", "force:" + key)
			elif kind != "blink" and key == "player" and not enemy_turn:
				_rect("player_move", rect, "walking hero body draw rect", "move:" + key)
			elif key.begins_with("enemy_"):
				_rect("enemy_move", rect, "walking enemy body draw rect", "move:" + key)
				if shown.get("harrier_travel_variant") == "retreat":
					_rect("enemy_retreat", rect, "retreating body draw rect", "move:" + key)
		if key == actor and kind == "pull" and unit.get("type") == "chainbound_gaoler":
			var rig: Node = board.unit_cutout_renderer(unit)
			if is_instance_valid(rig) and rig.get("clip") == "reel":
				_rect("enemy_pull", _body(board, unit), "Chain Reel cutout body", "reel:" + key)
		var clip: String = str(shown.get("burrow_grub_motion", {}).get(key, {}).get("clip", ""))
		if clip in ["burrow", "erupt"]:
			_rect("enemy_" + clip, _body(board, unit), "Burrow Grub cutout bounds", "burrow:" + key)
	for unit: Dictionary in shown.get("death_animation_units", []):
		if not unit.get("death_hold", false) and board._board_tile_is_visible_to_player(unit.get("pos", INVALID)):
			_rect("unit_death", _body(board, unit), "death body draw rect", "death:%s" % unit.get("key"))


func _body(board: Control, unit: Dictionary) -> Rect2:
	return Bounds.screen(board, board._unit_draw_rect(unit))


func _sample_traps(board: Control, shown: Dictionary) -> void:
	for trap: Dictionary in shown.get("trap_effects", []):
		var tile: Vector2i = trap.get("pos", INVALID)
		var element: String = str(trap.get("element", ""))
		if not element in ELEMENTS or not board._board_tile_is_visible_to_player(tile): continue
		var progress: float = board._trap_elemental_effect_progress(trap, float(shown.get("effect_progress", 1.0)))
		if board._trap_activation_texture(trap, progress) == null: continue
		_rect("trap_" + element, Bounds.screen(board, board._trap_visual_draw_rect(trap)),
			"trap activation texture", "trap:%s:%s" % [element, tile])


func _sample_area(board: Control, shown: Dictionary, effect: Dictionary, enemy_turn: bool) -> void:
	if effect.get("kind") != "aoe" or effect.get(Bursts.ACTIVE, false): return
	if board._aoe_resolution_footprint_visibility(effect, float(shown.get("effect_progress", 1.0))) <= 0.0: return
	var actor: String = str(effect.get("actor_key", ""))
	var hero: bool = actor == "player" if not actor.is_empty() else not enemy_turn
	for tile: Vector2i in effect.get("tiles", []):
		if not board._board_tile_is_visible_to_player(tile): continue
		_rect("player_area" if hero else "enemy_area", Bounds.screen(board, Bounds.points(board._tile_polygon(tile))),
			"drawn area footprint polygon", "area:%s:%s" % [actor, tile])


func _sample_surgeon(board: Control, shown: Dictionary, effect: Dictionary) -> void:
	if not effect.get("grave_surgeon_melee", false): return
	var tile: Vector2i = effect.get("to", INVALID)
	if tile == INVALID or ContactBursts.suppresses_decal(effect, tile): return
	var from: Vector2 = board._tile_center(effect.get("from", INVALID))
	var to: Vector2 = board._tile_center(tile)
	var direction: Vector2 = (to - from).normalized()
	var progress: float = float(shown.get("effect_progress", 1.0))
	var t: float = 0.45 if shown.get("reduced_motion", false) else Surgeon.attack_trail_phase(progress)
	if direction.is_zero_approx() or t <= 0.0 or t >= 1.0: return
	# The jab painter submits these two antialiased lines.
	var width: float = board._tile_width()
	var center: Vector2 = from.lerp(to, 0.72) + Vector2(0.0, -width * 0.43)
	var half: Vector2 = direction * width * (0.13 + 0.13 * t) * 0.5
	var rect := Rect2(center - half, Vector2.ZERO)
	rect = rect.expand(center + half).expand(center + half + Vector2(0, 3)).expand(center - half + Vector2(0, 3))
	_rect("surgeon_jab", Bounds.screen(board, rect.grow(2.0)), "two drawn jab strokes", "surgeon:" + str(effect.get("actor_key", "")))


func _sample_outcrop(board: Control) -> void:
	for terrain: Dictionary in board.combat_state.get("terrain", []):
		if terrain.get("kind") != "crag_outcrop": continue
		var tile: Vector2i = terrain.get("pos", INVALID)
		if not board._board_tile_is_visible_to_player(tile): continue
		var layer: Control = board._scene_render_layers_by_tile.get(tile)
		if not is_instance_valid(layer) or not layer.is_visible_in_tree(): continue
		var id: String = str(terrain.get("id", tile))
		var cache: Dictionary = layer._prop_command_cache._slots.get("terrain:" + id, {})
		if cache.is_empty() or float(cache["inputs"][3]) >= 1.0: continue
		_rect("enemy_outcrop_raise", Bounds.recorded(layer, cache["commands"]),
			"drawn rising outcrop polygons", "outcrop:" + id)
