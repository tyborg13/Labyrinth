extends RefCounted
## Read production playback once per rendered frame (once per submitted frame in dry-run).

const Attack = preload("res://scripts/attack_fx_library.gd")
const EnemyTrail = preload("res://scripts/enemy_strike_trail.gd")
const HeroTrail = preload("res://scripts/hero_strike_trail.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const CROP := Vector2i(480, 360)
const RADIUS := 12
const FPS := 60
const INVALID := Vector2i(-1, -1)

var strips: Array[Dictionary]
var captions: Array[Dictionary]
var notes: Array[String]
var comparisons: Dictionary
var frame: int = -1
var enemy_turn: bool
var comparisons_only: bool
var hero_action: String
var problem: String

var _history: Array[Image]
var _pending: Array[Dictionary]
var _melee_key: Array
var _melee_progress: float
var _melee_contact: bool
var _trail_kind: String
var _step_number: int
var _intent_number: int
var _caption: Dictionary
var _actor: String
var _action_number: int
var _action_has_caption: bool = true
var _tile_rows: Dictionary


func _init() -> void:
	_history.resize(RADIUS + 1)
	for name: String in Bursts.metadata()["rows"]:
		_tile_rows[int(Bursts.metadata()["rows"][name])] = name


func step_seen(step: Dictionary) -> void:
	_step_number += 1
	var key: String = Pacing.action_actor_key(step)
	if step.get("kind") == "intent" or (step.get("kind") == "intent_callout" and key != _actor):
		_intent_number += 1
		_actor = key
	elif Pacing.is_action_step(step):
		_close_action()
		_action_number = _step_number
		_action_has_caption = false
		_actor = key


func _close_action() -> void:
	if not comparisons_only and not _action_has_caption:
		notes.append("No caption rendered for enemy action %d (%s)." % [_action_number, _actor])
	_action_has_caption = true


func sample(scene: Node, viewport: SubViewport, dry: bool) -> void:
	frame += 1
	var image: Image
	if not dry:
		image = viewport.get_texture().get_image()
		if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE:
			problem = "readback is missing or differs from 1920x1080"
			return
		_history[frame % _history.size()] = image
	var board: Control = scene.board_view
	var shown: Dictionary = board.presentation
	if not comparisons_only:
		_watch_melee(board, shown, scene.action_banner, dry)
		if enemy_turn: _watch_caption(scene.action_banner, image)
	_watch_bursts(board, scene.action_banner.text, dry)
	for strip: Dictionary in _pending.duplicate():
		if strip["contact"] < frame:
			_append_crop(strip, frame, dry)
		if strip["contact"] + RADIUS == frame:
			_pending.erase(strip)


func finish() -> bool:
	_close_action()
	_close_caption(frame + 1)
	if not _pending.is_empty():
		problem = "ended before the last strip's +12 frame"
	return problem.is_empty()


func _watch_melee(board: Control, shown: Dictionary, banner: Label, dry: bool) -> void:
	var effect: Dictionary = shown.get("effect", {})
	var strike: Dictionary = shown.get("strike_trail_effect", effect)
	var hero: bool = HeroTrail.handles(strike)
	var from: Vector2i = strike.get("from", INVALID)
	var to: Vector2i = strike.get("to", INVALID)
	if from == INVALID or to == INVALID: return
	var kind: String = strike.get("kind", "")
	if not hero and kind != "melee" and not EnemyTrail.handles(board, strike) and not EnemyTrail.physical_area(strike):
		return
	var actor: String = str(strike.get("actor_key", "player" if hero else _actor))
	var key: Array = [0 if hero else _action_number, actor, kind, from, to, strike.get("intent_id", "")]
	var progress: float = float(shown.get("strike_trail_progress", shown.get("effect_progress", 0.0)))
	if key != _melee_key or progress < _melee_progress - 0.0001:
		_melee_key = key
		_melee_contact = false
		_trail_kind = ""
	_melee_progress = progress
	var trail_kind: String = _displayed_trail(board, strike, hero)
	if not trail_kind.is_empty():
		_trail_kind = trail_kind
		for row: Dictionary in _pending:
			if row.get("key") == key: row["trail"] = trail_kind
	if _melee_contact or progress + 0.0001 < Attack.feedback_start_progress(strike): return
	_melee_contact = true
	var targets: Array[Vector2i]
	if from != to:
		targets.append(to)
	else:
		# Self-centred melee swings have one visual beat, but distinct contacts
		# at the occupied tiles that receive the hit.
		var hits: Array = shown.get("impact_actor_keys", [])
		for unit: Dictionary in board._visible_units_cache:
			if unit.get("key") in hits and unit.get("key") != actor:
				targets.append(unit["pos"])
		if targets.is_empty():
			notes.append("No presented target for the %s melee at frame %d." % [banner.text, frame])
	var element: String = strike.get("element", "none")
	for target: Vector2i in targets:
		_begin_strip({
			"category": "melee", "key": key, "attacker": _unit_name(board, actor),
			"action": hero_action if hero else banner.text, "trail": _trail_kind,
			"element": element, "from": from, "to": target,
		}, _contact_midpoint(board, actor, from, target), dry)


func _displayed_trail(board: Control, effect: Dictionary, hero: bool) -> String:
	var layer: Control = board._effects_render_layer
	if is_instance_valid(layer):
		var mesh: Node = layer._strike_trail_layer
		if is_instance_valid(mesh) and not mesh._batches.is_empty():
			if hero:
				if effect.get("illusion_echo", false): return "arc"
				return Trail.motion_settings(effect.get("protagonist_weapon_motion", "sword"))["kind"]
			return layer._enemy_strike_trail.resolved.get("kind", "")
	if not hero and EnemyTrail.physical_area(effect):
		return "rake"
	return ""


func _watch_bursts(board: Control, action: String, dry: bool) -> void:
	for category: String in ["fx12", "fx13"]:
		if comparisons.has(category): continue
		var player: RefCounted = board._tile_bursts if category == "fx12" else board._self_bursts
		if player == null: continue
		for stamp: Node2D in player._stamps:
			if not stamp.front or not stamp.is_visible_in_tree(): continue
			if category == "fx13" and stamp.sample.y != int(Bursts.self_metadata()["rows"]["block_front"]): continue
			var design: String = _tile_rows.get(stamp.sample.y, "") if category == "fx12" else "block_front"
			if design.is_empty(): continue
			var actor: String = stamp.unit.get("key", _actor if enemy_turn else "player")
			var element: String = "none"
			for candidate: String in Bursts.metadata()["burst_for_element"]:
				if design.begins_with(str(Bursts.metadata()["burst_for_element"][candidate]) + "_"):
					element = candidate
					break
			_begin_strip({
				"category": category, "attacker": _unit_name(board, actor), "action": action,
				"trail": "baked " + design, "element": element, "from": stamp.tile, "to": stamp.tile,
			}, stamp.get_global_transform_with_canvas().origin, dry)
			comparisons[category] = true
			break


func _unit_name(board: Control, key: String) -> String:
	if key == "player": return "Reaver"
	for unit: Dictionary in board._visible_units_cache:
		if unit.get("key") == key:
			var type: String = unit.get("type", "")
			return "%s [%s]" % [GameData.enemy_def(type).get("name", type), key]
	return key


func _contact_midpoint(board: Control, actor: String, from: Vector2i, to: Vector2i) -> Vector2:
	var source: Vector2 = board.world_position_for_tile(from)
	var target: Vector2 = board.world_position_for_tile(to)
	for unit: Dictionary in board._visible_units_cache:
		if unit.get("key") == actor:
			source = board._unit_draw_rect(unit).get_center()
		else:
			var footprint := Rect2i(unit["pos"], board._resolved_unit_footprint(unit))
			if footprint.has_point(to):
				target = board._unit_draw_rect(unit).get_center()
	return board.get_global_transform_with_canvas() * source.lerp(target, 0.5)


func _begin_strip(row: Dictionary, center: Vector2, dry: bool) -> void:
	if frame < RADIUS:
		problem = "contact arrived without 12 prior samples"
		return
	var corner: Vector2i = Vector2i((center - Vector2(CROP) * 0.5).round())
	corner = corner.clamp(Vector2i.ZERO, Checkpoint.VIEWPORT_SIZE - CROP)
	row["crop"] = Rect2i(corner, CROP)
	row["contact"] = frame
	row["frames"] = []
	strips.append(row)
	_pending.append(row)
	for sample_frame: int in range(frame - RADIUS, frame + 1):
		_append_crop(row, sample_frame, dry)


func _append_crop(row: Dictionary, sample_frame: int, dry: bool) -> void:
	var images: Array = row["frames"]
	if dry:
		images.append(sample_frame)
	else:
		var crop: Image = _history[sample_frame % _history.size()].get_region(row["crop"])
		crop.convert(Image.FORMAT_RGB8)
		images.append(crop)


func _watch_caption(label: Label, image: Image) -> void:
	if _actor.is_empty() or not label.is_visible_in_tree() or label.text.is_empty():
		_close_caption(frame)
		return
	# A new intent can bring the same text (e.g. two Rocs using Circle).
	var key: Array = [label.text, _intent_number, _actor]
	if _caption.get("key", []) != key:
		_close_caption(frame)
		_caption = {"key": key, "text": label.text, "actor": _actor, "shown": frame, "actions": []}
	if not _caption.has("full") and _fully_visible(label):
		_caption["full"] = frame
		_caption["image"] = image
		_caption["rect"] = label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
		_caption["font_px"] = label.get_theme_font_size("font_size")
	if _caption.has("full") and _action_number == _step_number and not _caption["actions"].has(_action_number):
		_caption["actions"].append(_action_number)
		_action_has_caption = true


func _fully_visible(label: Label) -> bool:
	if not is_equal_approx(label.self_modulate.a, 1.0): return false
	var parent: CanvasItem = label
	while parent != null:
		if not is_equal_approx(parent.modulate.a, 1.0): return false
		parent = parent.get_parent() as CanvasItem
	return label.visible_ratio >= 1.0


func _close_caption(end: int) -> void:
	if _caption.is_empty(): return
	if _caption.has("full"):
		_caption["duration"] = end - int(_caption["shown"])
		captions.append(_caption)
	_caption = {}
