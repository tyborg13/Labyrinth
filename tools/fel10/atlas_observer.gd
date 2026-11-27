extends RefCounted
## Read the actual stamp instances, including reused shot slots.

const Bounds = preload("res://tools/fel10/draw_bounds.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")

var _rows: Array[Dictionary]
var _stamp_aliases: Dictionary
var _board_id: int


func _init() -> void:
	for catalog: Dictionary in [Bursts.metadata(), Bursts.self_metadata(), Bursts.strike_metadata()]:
		var names: Dictionary = {}
		for name: String in catalog["rows"]: names[int(catalog["rows"][name])] = name
		_rows.append(names)


func sample(board: Control, shown: Dictionary, effect: Dictionary, enemy_turn: bool, emit: Callable, capture_rects: bool = false) -> void:
	if _board_id != board.get_instance_id():
		_board_id = board.get_instance_id()
		_stamp_aliases.clear()
	var hero: bool = _is_hero(effect, enemy_turn)
	var players: Array = [board._tile_bursts, board._self_bursts, board._sky_strikes]
	for index: int in players.size():
		var player: RefCounted = players[index]
		if player == null: continue
		for stamp: Node2D in player._stamps:
			if not stamp.front or not stamp.is_visible_in_tree(): continue
			var row: String = _rows[index].get(stamp.sample.y, "")
			if row.is_empty(): continue
			var center: Vector2 = stamp.get_global_transform_with_canvas().origin
			var phase: int = stamp.sample.x
			var rect: Rect2 = Bounds.burst(stamp, player) if capture_rects else Rect2()
			var key: String = "stamp:%d" % stamp.get_instance_id()
			var send: Callable = _bounded(emit, rect, key, true) if capture_rects else emit
			var variant: String = row.trim_suffix("_front")
			match index:
				0:
					send.call("burst_" + variant, center, "fx-12 " + row, phase)
					if effect.get("kind") == "aoe" and (stamp.tile == effect.get("center") or stamp.tile in effect.get("tiles", [])):
						send.call("player_area" if hero else "enemy_area", center, "area stamp " + row, phase)
						if effect.get("ground_burst", false): send.call("player_burst", center, "ground Burst stamp " + row, phase)
					if capture_rects: _contact_aliases(shown, effect, stamp.tile, variant, center, phase, send)
					if variant.begins_with("steel_") and effect.get("kind") == "melee":
						send.call("player_melee_impact" if hero else "enemy_melee_impact", center, row, phase)
				1:
					send.call("self_" + variant, center, "fx-13 " + row, phase)
					var recipient: String = str(stamp.unit.get("key", ""))
					if variant == "illusion":
						send.call("player_summon", center, row, phase)
					if variant == "summon":
						if stamp.unit.has("id") and stamp.unit.has("type"):
							send.call("enemy_summon", center, row, phase)
						elif effect.get("kind") == "blink" and stamp.tile in [effect.get("from"), effect.get("to")]:
							send.call("player_blink" if hero else "enemy_blink", center, row, phase)
						elif shown.get("battlefield_rule_caption", {}).get("rule") == "shadowstep":
							send.call("enemy_blink", center, row, phase)
					if variant in ["block", "heal"]:
						send.call(("player_" if recipient == "player" else "enemy_") + variant, center, row, phase)
				2:
					send.call("sky_" + variant, center, "fx-15 " + row, phase)
					if stamp.strike.contact_usec >= 0 and variant in ["meteor", "ice_spear"]:
						send.call("enemy_meteorfall" if variant == "meteor" else "enemy_icefall_landing", center, row, phase)
			if capture_rects:
				for id: String in _stamp_aliases.get(key, {}):
					emit.call(id, center, _stamp_aliases[key][id], phase, rect, key)
	_sample_shots(board, shown, effect, hero, emit, capture_rects)


func _sample_shots(board: Control, shown: Dictionary, effect: Dictionary, hero: bool, emit: Callable, capture_rects: bool) -> void:
	var shots: RefCounted = board._single_shot_fx
	if shots == null: return
	var prefix: String = "player_" if _is_hero(shots._effect, not hero) else "enemy_"
	for head: Node2D in shots._heads:
		if not head.is_visible_in_tree(): continue
		var center: Vector2 = head.get_global_transform_with_canvas().origin
		var shot: String = shots._shot_id
		var send: Callable = _shot_sender(emit, head, "flight", capture_rects)
		if effect.get("en04_mechanic") == "lob_land" and float(shown.get("effect_progress", 1.0)) < Lob.CONTACT_PROGRESS:
			shot = "ember"
			send.call("enemy_lob_projectile", center, "Lob ember head", -1)
		if shot.is_empty(): continue
		if effect.get("action_type") == "refraction": send.call("enemy_refraction", center, "Refraction head", -1)
		send.call("shot_" + shot, center, "fx-14 head " + shot, -1)
		send.call(prefix + "ranged_projectile", center, "fx-14 head " + shot, -1)
		var action: String = str(shots._effect.get("action_type", shots._effect.get("kind", "")))
		if action in ["push", "pull"]: send.call(prefix + action, center, "force projectile " + shot, -1)
	if is_instance_valid(shots._shadow) and shots._shadow.is_visible_in_tree():
		_shot_sender(emit, shots._shadow, "shadow", capture_rects).call("shot_shadow", shots._shadow.get_global_transform_with_canvas().origin, "fx-14 shadow", -1)
	for hit: Node2D in shots._hits:
		if hit.lifetime_start < 0 or not hit.is_visible_in_tree(): continue
		var center: Vector2 = hit.get_global_transform_with_canvas().origin
		var send: Callable = _shot_sender(emit, hit, str(hit.lifetime_start), capture_rects)
		send.call("shot_" + hit.hit_id, center, "fx-14 " + hit.hit_id, -1)
		send.call(prefix + "ranged_impact", center, "fx-14 " + hit.hit_id, -1)
	if is_instance_valid(shots._links) and shots._links.is_visible_in_tree():
		_shot_sender(emit, shots._links, "links", capture_rects).call("hook_links", shots._links.get_global_transform_with_canvas().origin, "fx-14 links", -1)
	if is_instance_valid(shots._reflected_head) and shots._reflected_head.is_visible_in_tree():
		_shot_sender(emit, shots._reflected_head, "reflection", capture_rects).call("reflected_projectile", shots._reflected_head.get_global_transform_with_canvas().origin, "fx-14 reflected slot", -1)


static func _is_hero(effect: Dictionary, enemy_turn: bool) -> bool:
	var actor: String = str(effect.get("actor_key", ""))
	return actor == "player" if not actor.is_empty() else not enemy_turn


func _bounded(emit: Callable, rect: Rect2, instance: String, remember: bool = false) -> Callable:
	return func(id: String, center: Vector2, source: String, phase: int) -> void:
		if remember:
			if not _stamp_aliases.has(instance): _stamp_aliases[instance] = {}
			_stamp_aliases[instance][id] = source
		emit.call(id, center, source, phase, rect, instance)


func _shot_sender(emit: Callable, stamp: Node2D, role: String, capture_rects: bool) -> Callable:
	if not capture_rects: return emit
	return _bounded(emit, Bounds.screen(stamp, stamp.bounds), "shot:%d:%s" % [stamp.get_instance_id(), role])


static func _contact_aliases(shown: Dictionary, effect: Dictionary, tile: Vector2i, variant: String,
		center: Vector2, phase: int, emit: Callable) -> void:
	if effect.get("en04_mechanic") == "lob_land" and variant.begins_with("fire_") and tile == effect.get("to"):
		emit.call("enemy_lob_landing", center, "Lob contact stamp", phase)
	for event: Dictionary in shown.get("surface_feedback_events", []):
		if tile != event.get("tile") and not tile in event.get("tiles", []): continue
		if event.get("kind") == "surface_conducted" and variant.begins_with("lightning_"):
			emit.call("lightning_conduction", center, "conduction contact stamp", phase)
		elif event.get("kind") == "crystal_mantle_broken" and variant.begins_with("ice_"):
			emit.call("crystal_mantle_broken", center, "Mantle ice contact stamp", phase)
	for event: Dictionary in shown.get("burst_effects", []):
		if (event.get("center") == tile or tile in event.get("tiles", [])) and variant.begins_with(str(event.get("element", "fire")) + "_"):
			emit.call("death_burst", center, "death Burst contact stamp", phase)
