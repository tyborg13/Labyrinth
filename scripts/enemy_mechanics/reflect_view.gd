extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/reflect.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const ContactBursts = preload("res://scripts/resolved_contact_bursts.gd")
const PreviewSource = preload("res://scripts/pass_forecast_action_source.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const TileBurst = preload("res://scripts/tile_burst_fx.gd")
const COLOR := Color("9cc8e6")
const FLASH_SECONDS: float = 0.08
const RETURN_SPEED: float = 1.5
const BEAM_SECONDS: float = 0.3
const LATE_RELEASE_LEAD_FRAMES: int = 12
const LANCE_EASE: float = 1.4 # Protected lance timing, also used if the shot catalog is unavailable.
const REFRACTION_SAMPLE: String = "refraction_shot"
const PROJECTILE_TRAVEL_FRACTION: float = 0.48 # Existing projectile's .18–.66 travel.
const PROJECTILE: String = "reflected_projectile"
const BAKED_SHOT: String = "en05_baked_shot"
const RETURN_TILE: String = "en05_return_tile"

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if str(unit.get("type", "")) == "glacial_mirror":
		result.append({"status_class": "trait", "icon": "reflect", "count": 0, "fill": COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": Rules.TOOLTIP})
	return result

const LOSS_POOLS: Dictionary = {"hp_loss": "Health", "block_loss": "Block", "stoneskin_loss": "Guard", "defiance_spent": "Defiance"}

# Attribute each resolved source's losses after that hit's lethal recovery.
static func decorate_preview(scene: Control, result: Dictionary, before: Dictionary, after: Dictionary, _action: Dictionary, _target: Vector2i) -> void:
	var engine: RefCounted = scene._combat_engine
	var reflect_damage: int = 0
	var reflected: Dictionary = {}
	var mirror_keys: Array[String]
	var bounces: Array[Dictionary] = Rules.bounces_between(before, after)
	if bounces.is_empty(): return
	var hidden: Dictionary = PreviewSource.hidden_actor_keys(scene, before)
	for event: Dictionary in bounces:
		if str(event.get("attacker_kind", "")) != "player": continue
		var mirror: Dictionary = engine._surface_actor(before, "enemy", int(event.get("enemy_id", -1)))
		# An area may strike an unseen unit; the forecast never discloses it.
		if mirror.is_empty() or hidden.has(engine._enemy_key(mirror)): continue
		reflect_damage += int(event.get("damage", 0))
		_add_losses(reflected, event)
		var key: String = engine._enemy_key(mirror)
		if not mirror_keys.has(key): mirror_keys.append(key)
	if mirror_keys.is_empty(): return

	var bursts: Dictionary = {}
	var sequence: int = int(before.get("surface_event_sequence", 0))
	for event: Dictionary in after.get("surface_events", []):
		if int(event.get("sequence", 0)) > sequence and event.get("kind") == "detonate":
			_add_losses(bursts, event.get("player_losses", {}))
	var total: Dictionary = result.get("damage_preview", {}).get("player", {})
	if total.is_empty(): total = scene._damage_preview_between_states(before, after).get("player", {})
	var other: Dictionary = total.duplicate()
	for field: String in LOSS_POOLS:
		other[field] = maxi(0, int(total.get(field, 0)) - int(reflected.get(field, 0)) - int(bursts.get(field, 0)))
	other["lethal"] = bool(total.get("lethal", false)) and not bool(reflected.get("lethal", false)) and not bool(bursts.get("lethal", false))

	var chips: Array = (result.get("friendly_damage_chips", []) as Array).filter(func(chip: Dictionary) -> bool: return chip.get("actor_key") != "player")
	var reflect_tooltip: String = _loss_tooltip(Icons.label("reflect"), reflected, reflect_damage if int(reflected.get("defiance_spent", 0)) == 0 else 0)
	var returned: Array = scene._friendly_damage_preview_chips(before, {"player": reflected})
	if not returned.is_empty():
		var parts := PackedStringArray()
		for chip: Dictionary in returned:
			parts.append(str(chip["label"]).trim_prefix("You: "))
		var plate: Dictionary = returned[0]
		plate["label"] = "↶ You: " + ", ".join(parts)
		plate["tooltip"] = reflect_tooltip
		plate["fit_label"] = parts.size() > 1
		chips.append(plate)
	_append_source_chips(scene, before, chips, bursts, _loss_tooltip(Icons.label("burst"), bursts))
	chips.append_array(scene._friendly_damage_preview_chips(before, {"player": other}))
	result["friendly_damage_chips"] = chips
	result["en05_reflect_preview"] = {
		"actor_key": "player", "damage": reflect_damage, "mirror_keys": mirror_keys,
		"tooltip": reflect_tooltip,
	}

static func _add_losses(total: Dictionary, hit: Dictionary) -> void:
	for field: String in LOSS_POOLS:
		var amount: int = int(hit.get(field, 0))
		if field == "hp_loss": amount = int(hit.get("net_hp_loss", amount))
		total[field] = int(total.get(field, 0)) + amount
	total["lethal"] = bool(total.get("lethal", false)) or bool(hit.get("lethal", false))

static func _append_source_chips(scene: Control, before: Dictionary, chips: Array, losses: Dictionary, tooltip: String) -> void:
	for chip: Dictionary in scene._friendly_damage_preview_chips(before, {"player": losses}):
		chip["tooltip"] = tooltip
		chips.append(chip)

static func _loss_tooltip(title: String, losses: Dictionary, damage: int = 0) -> String:
	var lines := PackedStringArray([title])
	if damage > 0: lines.append("You take %d damage." % damage)
	for field: String in LOSS_POOLS:
		var amount: int = int(losses.get(field, 0))
		if amount > 0:
			lines.append("You lose %d %s." % [amount, LOSS_POOLS[field]])
	return "\n".join(lines)

static func intent_rows(intent: Dictionary, return_damage: int = 0) -> Array:
	if str(intent.get("id", "")) != "refraction": return []
	var rows: Array = Icons.rows_for_actions(intent["actions"], [{"actor_kind": "enemy"}])
	if return_damage > 0:
		rows.append([Icons.token_for("reflect", return_damage, "neutral", "Reflect\nThis enemy takes %d damage." % return_damage)])
	return rows

static func draw_preview(board: Control) -> void:
	var preview: Dictionary = board.presentation.get("en05_reflect_preview", {})
	if preview.is_empty(): return
	# The target remains under the pointer while aiming.
	var mirror_keys: Array = preview.get("mirror_keys", [])
	for unit: Dictionary in board._visible_units():
		if mirror_keys.has(str(unit.get("key", ""))): board._register_tooltip(board._unit_draw_rect(unit), str(preview["tooltip"]))

static func reflected_effect(before: Dictionary, action: Dictionary, target: Vector2i, outbound: float) -> Dictionary:
	return {"kind": "ranged", "action_type": PROJECTILE, "from": action.get("_origin_tile", before["player"]["pos"]), "to": target, "element": action.get("element", action.get("_card_element", "none")), "en05_outbound_seconds": outbound}

static func projectile_seconds(outbound: float) -> float:
	return outbound + FLASH_SECONDS + outbound / RETURN_SPEED

static func projectile_frame(progress: float, outbound: float) -> Dictionary:
	var total: float = projectile_seconds(outbound)
	var elapsed: float = clampf(progress, 0.0, 1.0) * total
	if elapsed < outbound: return {"travel": elapsed / outbound, "returning": false, "flash": false}
	if elapsed < outbound + FLASH_SECONDS: return {"travel": 1.0, "returning": false, "flash": true}
	return {"travel": 1.0 - clampf((elapsed - outbound - FLASH_SECONDS) / (outbound / RETURN_SPEED), 0.0, 1.0), "returning": true, "flash": false}

static func draw_effect(board: Control, effect: Dictionary, progress: float) -> bool:
	var kind: String = str(effect.get("action_type", ""))
	if kind == "refraction": return true
	if kind != PROJECTILE: return false
	if effect.has(BAKED_SHOT): return true
	var pose: Dictionary = projectile_pose(board, effect, progress)
	board._draw_projectile_sprite(pose["point"], pose["direction"], board._projectile_element_id(str(effect.get("element", "none"))), pose["travel"])
	return true

static func projectile_pose(board: Control, effect: Dictionary, progress: float) -> Dictionary:
	var frame: Dictionary = projectile_frame(progress, float(effect["en05_outbound_seconds"]))
	var start: Vector2 = board._tile_center(effect["from"]) + Vector2(0.0, -24.0)
	var end: Vector2 = board._tile_center(effect["to"]) + Vector2(0.0, -24.0)
	var control: Vector2 = board._arc_control_point(start, end)
	var t: float = float(frame["travel"])
	var point: Vector2 = board._quadratic_bezier(start, control, end, t)
	var direction: Vector2 = board._quadratic_bezier(start, control, end, minf(1.0, t + 0.04)) - board._quadratic_bezier(start, control, end, maxf(0.0, t - 0.04))
	if bool(frame["returning"]): direction = -direction
	return {"point": point, "direction": direction, "travel": t}

# The return projectile replaces a lone shot's own animation. Area, Chain and
# melee strikes keep theirs; the returned damage shows in their hit text.
static func lone_shot(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["ranged", "push", "pull"] and int(action.get("chain", 0)) <= 0 and int(action.get("radius", 0)) <= 0 and not action.has("pattern_line")

static func animate_player(scene: Control, before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i, card_id: String) -> bool:
	if not lone_shot(action): return false
	var engine: RefCounted = scene._combat_engine
	var bounces: Array[Dictionary] = Rules.bounces_between(before, after)
	if bounces.is_empty(): return false
	var mirror_index: int = engine._enemy_index_at_tile(before, target)
	if mirror_index < 0: return false
	var mirror_id: int = before["enemies"][mirror_index]["id"]
	var attacker_kind: String = "illusion" if bool(action.get("_illusion_echo", false)) else "player"
	for bounce: Dictionary in bounces:
		if bounce["enemy_id"] != mirror_id or bounce["attacker_kind"] != attacker_kind: continue
		await _animate_bounce(scene, before, after, action, target, card_id, bounce)
		return true
	return false

static func _animate_bounce(scene: Control, before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i, card_id: String, bounce: Dictionary) -> void:
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_player_action(preload("res://scripts/game_data.gd").card_def(card_id), action))
	var outbound: float = scene.ATTACK_FRAMES * scene.ATTACK_FRAME_SECONDS * PROJECTILE_TRAVEL_FRACTION
	var effect: Dictionary = reflected_effect(before, action, target, outbound)
	var engine: RefCounted = scene._combat_engine
	var shot: Dictionary = scene._reflected_shot_descriptor(before, engine.action_with_automatic_origin(before, action, target), target, card_id)
	if not shot.is_empty():
		var attacker: Dictionary = engine._surface_actor(before, bounce["attacker_kind"], bounce["attacker_id"])
		effect[BAKED_SHOT] = shot
		effect[RETURN_TILE] = attacker.get("pos", shot["from"])
	await play_projectile(scene, before, after, effect, scene.ATTACK_FRAME_SECONDS)

static func play_projectile(scene: Control, before: Dictionary, after: Dictionary, effect: Dictionary, frame_seconds: float) -> void:
	var outbound: float = effect["en05_outbound_seconds"]
	var total: float = projectile_seconds(outbound)
	var frames: int = ceili(total / frame_seconds)
	var engine: RefCounted = scene._combat_engine
	var key: String = engine._enemy_key(before["enemies"][engine._enemy_index_at_tile(before, effect["to"])])
	await scene._play_timed_animation_frames(frames, total / frames, func(frame: int) -> void:
		var progress: float = float(frame - 1) / frames
		var timing: Dictionary = projectile_frame(progress, outbound)
		scene._render_board_state(before, {"effect": effect, "effect_progress": progress, "combat_feel_flash": {key: 1.0 if bool(timing["flash"]) else 0.0}, "combat_feel_flash_actor_keys": [key]}, true)
	)
	var contact: Dictionary = {"effect": effect, "effect_progress": 1.0} if effect.has(BAKED_SHOT) else {}
	scene._render_board_state(after, contact)
	var impact: Callable
	if effect.has(BAKED_SHOT) and effect.get("element") != "shadow":
		var shot_fx: Script = load("res://scripts/shot_fx.gd")
		if not shot_fx.has_hit(shot_fx.resolve(effect[BAKED_SHOT])):
			var name: String = TileBurst.for_element(effect["element"])
			var tile: Vector2i = effect[RETURN_TILE]
			var hit: bool = TileBurst.hit_tiles(before, after, ContactBursts._footprint).has(tile)
			if not name.is_empty():
				impact = scene.board_view.present_tile_bursts.bind([ContactBursts.spec(name, tile, hit)], before, after, scene._reduced_motion_enabled())
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	await scene._animate_floating_text_presentation(after, {"floating_texts": scene._floating_texts_for_target_losses(losses)}, 0.0, false, {}, impact)

static func refraction_release_frame(step: Dictionary, count: int, contact_frame: int) -> int:
	var shot_fx: Script = load("res://scripts/shot_fx.gd")
	var release: int = 1 + ceili(shot_fx.release_for(Attack.style_for_effect(step)) * (count - 1))
	return release if release < contact_frame else maxi(1, contact_frame - LATE_RELEASE_LEAD_FRAMES)

static func move_refraction_reservation(reservation: Dictionary, step: Dictionary) -> void:
	# adapter_contact prepends the area; any separate trap/surface specs still
	# belong to the original contact submission.
	if not reservation.is_empty() and is_same(reservation["step"], step) and not TileBurst.select_enemy(step).is_empty():
		reservation["specs"].pop_front()

class RefractionFlight:
	var _tiles: Array
	var _next_tile: int
	var _from: Vector2i
	var _distance: float
	var _effect: Dictionary
	var _hits: Dictionary

	func _init(board: Control, before: Dictionary, step: Dictionary) -> void:
		if bool(step.get("cancelled", false)): return
		_tiles = step.get("tiles", [])
		if _tiles.is_empty(): return
		_from = step.get("umbra_original_from", step["from"])
		var to: Vector2i = step.get("umbra_original_to", _tiles.back())
		_distance = Vector2(to - _from).length()
		var shot_fx: Script = load("res://scripts/shot_fx.gd")
		_effect = {shot_fx.RESOLVED_KEY: shot_fx.refraction_shot_id(), "from": _from, "to": to, "actor_key": step["actor_key"]}
		for key: String in ["umbra_action_clipped", "umbra_visible_line_segments"]:
			if step.has(key): _effect[key] = step[key]
		var after: Dictionary = before.merged(step["en05_after"], true)
		after.merge(step.get("trace_state_after", {}), true)
		_hits = TileBurst.hit_tiles(before, after, board._resolved_unit_footprint)
		# Refraction's loss records include Illusion losses and Defiance events
		# that are outside the partial en05 snapshot.
		for loss: Dictionary in step.get("target_losses", []):
			_hits[loss["tile"]] = true
		var terrain_hp: Dictionary
		for terrain: Dictionary in after.get("terrain", []):
			terrain_hp[terrain["id"]] = int(terrain.get("hp", 0))
		for terrain: Dictionary in before.get("terrain", []):
			if int(terrain_hp.get(terrain["id"], 0)) < int(terrain.get("hp", 0)):
				_hits[terrain["pos"]] = true

	func travel_at(frame: int, release: int, contact: int) -> float:
		if frame < release: return -1.0
		if frame >= contact: return 1.0
		return pow(float(frame - release) / (contact - release), LANCE_EASE)

	func present(shown: Dictionary, travel: float, reduced: bool) -> void:
		if travel >= 0.0 and not reduced and not _effect.is_empty():
			shown[REFRACTION_SAMPLE] = {"effect": _effect, "travel": travel}

	func land(board: Control, travel: float, reduced: bool) -> void:
		var player: TileBurst = board._tile_bursts
		if travel < 0.0 or player == null or player.ink == null: return
		while _next_tile < _tiles.size():
			var tile: Vector2i = _tiles[_next_tile]
			# Use the same ground-line coordinate as the head's shadow and sight
			# mask. The straight screen-space head starts above that line.
			if Vector2(tile - _from).length() > _distance * travel and travel < 1.0: break
			_next_tile += 1
			var spec: Dictionary = {"name": TileBurst.for_element("ice"), "center": tile, "tiles": [tile]}
			for entry: Dictionary in TileBurst.plan(spec, board.combat_state["grid"], _hits, board._board_tile_is_visible_to_player, reduced):
				player._spawn_pair(board, entry, reduced)

static func animate_beam(scene: Control, state: Dictionary, step: Dictionary) -> void:
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step(step))
	var reduced: bool = scene._reduced_motion_enabled()
	var flight := RefractionFlight.new(scene.board_view, state, step)
	var feedback: Dictionary = {}
	if not bool(step.get("cancelled", false)):
		var frames: int = ceili(BEAM_SECONDS / scene.ATTACK_FRAME_SECONDS)
		var visual_step: Dictionary = step.duplicate(false)
		visual_step[TileBurst.ACTIVE] = true
		await scene._play_timed_animation_frames(frames, BEAM_SECONDS / frames, func(frame: int) -> void:
			var travel: float = flight.travel_at(frame, 1, frames + 1)
			var shown: Dictionary = {"effect": visual_step, "effect_progress": float(frame - 1) / frames}
			flight.present(shown, travel, reduced)
			scene._render_board_state(state, shown, true)
			flight.land(scene.board_view, travel, reduced)
		)
		flight.present(feedback, 1.0, reduced)
		flight.land(scene.board_view, 1.0, reduced)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, feedback)
	feedback["floating_texts"] = scene._floating_texts_for_target_losses(step.get("target_losses", []))
	await scene._animate_floating_text_presentation(state, feedback, 0.0, false, {}, func() -> void:
		feedback.erase(REFRACTION_SAMPLE)
	)
