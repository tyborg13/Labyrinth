extends RefCounted

const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")
const Chain = preload("res://scripts/chain_attack_feedback.gd")
const ChainBolt = preload("res://scripts/chain_bolt_fx.gd")
const Cutout = preload("res://assets/units/storm_capacitor_cutout/actions.gd")
const DeferredDeath = preload("res://scripts/enemy_mechanics/deferred_death_view.gd")
const Shot = preload("res://scripts/shot_fx.gd")
const Rules = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Contact = preload("res://scripts/enemy_mechanics/lightning_contact_view.gd")
const COLOR := Color("a77bf0")
const EMPTY_COLOR := Color("3a2f4f")
const PIP_SIZE: float = 8.0
const GLOW_ALPHA: float = 0.4
const PIP_GAP: float = 4.0
const PIP_ROW_OFFSET: float = 10.0

static var _preview_engine := Combat.new()

static func charge_tooltip(state: Dictionary, unit: Dictionary) -> String:
	return Icons.tooltip("charge").replace("At 3 Charge", "At %d Charge" % Rules.MAX_CHARGE)

static func badges(unit: Dictionary, state: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if Rules.is_capacitor(unit): result.append({"status_class": "trait", "icon": "charge", "count": int(unit.get("charge", 0)), "show_count": true, "fill": EMPTY_COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": charge_tooltip(state, unit) + "\n%d/%d" % [int(unit.get("charge", 0)), Rules.MAX_CHARGE]})
	return result

static func draw_pips(board: Control, unit: Dictionary, health: Rect2) -> void:
	if not Rules.is_capacitor(unit): return
	var centers: Array[Vector2] = pip_centers(health, Rules.MAX_CHARGE)
	for index: int in range(centers.size()):
		var center: Vector2 = centers[index]
		var points := PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)])
		if index < int(unit.get("charge", 0)):
			board.draw_circle(center, PIP_SIZE * 0.5, Color(COLOR, GLOW_ALPHA))
			board.draw_colored_polygon(points, COLOR)
		else:
			points.append(points[0])
			board.draw_polyline(points, EMPTY_COLOR, 1.0, true)

static func pip_centers(health_frame: Rect2, threshold: int = Rules.MAX_CHARGE) -> Array[Vector2]:
	var result: Array[Vector2]
	for index: int in range(threshold):
		result.append(Vector2(health_frame.get_center().x + (index - float(threshold - 1) * 0.5) * (PIP_SIZE + PIP_GAP), health_frame.position.y - PIP_ROW_OFFSET))
	return result

static func rows(intent: Dictionary, state: Dictionary = {}, unit: Dictionary = {}) -> Array:
	if not Rules.handles_intent(intent): return []
	var action: Dictionary = intent["actions"][0]
	var token: Dictionary
	if str(action["type"]) == "gain_charge":
		var charge: Dictionary = preload("res://scripts/game_data.gd").enemies()["storm_capacitor"]["charge"]
		token = Icons.icon_text_token("charge", "Charge +%d" % int(action["amount"]), "At %d Charge, this enemy's next attack is Arc Lash. Shock removes %d Charge." % [int(charge["max"]), int(charge["lose_on_shock"])])
	else:
		token = Icons.icon_text_token("chain", "Arc %d, Range %d, %d extra hits" % [int(action["damage"]), int(action["first_range"]), int(action["jumps"])], "This enemy hits the nearest target within %d tiles for %d damage, then hits up to %d more, each adjacent to the prior target and taking %d less damage." % [int(action["first_range"]), int(action["damage"]), int(action["jumps"]), int(action["falloff"])])
	token["glossary_key"] = "charge"
	return [[token]]

static func draw_telegraphs(board: Control) -> void:
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		if str(threat.get("projected_attack_action", {}).get("type", "")) != "chain_discharge": continue
		for hit: Dictionary in threat.get("chain_hits", []):
			var start: Vector2 = Contact.chest(board, hit["from"])
			var finish: Vector2 = Contact.chest(board, hit["to"])
			Contact.draw_arc_link(board, start, finish, float(board.presentation.get("en03_time_seconds", float(preload("res://scripts/presentation_clock.gd").ticks_msec()) / 1000.0)), bool(board.presentation.get("reduced_motion", false)), COLOR)
			var font: Font = preload("res://scripts/ui_typography.gd").display_font()
			board.draw_string_outline(font, finish, str(hit["damage"]), HORIZONTAL_ALIGNMENT_CENTER, -1, board.INTENT_POPUP_ROW_FONT_SIZE, 3, EMPTY_COLOR)
			board.draw_string(font, finish, str(hit["damage"]), HORIZONTAL_ALIGNMENT_CENTER, -1, board.INTENT_POPUP_ROW_FONT_SIZE, COLOR)

# The wide approved chain/base silhouette must fit the fixed 255 canvas. This
# derived draw factor restores the brief's exact 120% hero body height.
const BODY_SCALE: float = 216.0 * 1.2 / 243.0
static func art_scale(unit_type: String, authored: float) -> float:
	return BODY_SCALE if unit_type == "storm_capacitor" else authored

# Same retained-layer and health-preview contract as EN03's beam integration.
static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	var effect: Dictionary = original.get("effect", {})
	if not effect.is_empty() and not bool(effect.get("preview", false)): return original
	var indices: Array[int]
	for index: int in range(state.get("enemies", []).size()):
		if Rules.is_capacitor(state["enemies"][index]): indices.append(index)
	if indices.is_empty(): return original
	var result: Dictionary = original.duplicate(false)
	var engine := _preview_engine
	var previews: Array = result.get("enemy_threat_previews", []).duplicate(false)
	var attack_tiles: Array = result.get("projected_attack_tiles", []).duplicate()
	var damage: Dictionary = result.get("damage_preview", {}).duplicate(false)
	for index: int in indices:
		var enemy: Dictionary = state["enemies"][index]
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		var threat: Dictionary = engine.enemy_threat_tiles(state, index)
		threat["enemy_key"] = engine._enemy_key(enemy)
		previews = previews.filter(func(entry: Dictionary) -> bool: return str(entry.get("enemy_key", "")) != str(threat["enemy_key"]))
		previews.append(threat)
		if not bool(effect.get("preview", false)):
			for tile: Vector2i in threat.get("projected_attack", []):
				if not attack_tiles.has(tile): attack_tiles.append(tile)
		for hit: Dictionary in threat.get("chain_hits", []):
			for loss: Dictionary in hit.get("target_losses", []):
				var key: String = str(loss["key"])
				if damage.has(key): continue
				var target: Dictionary = hit["state"]["player"] if key == "player" else engine._surface_actor(hit["state"], "enemy", int(loss["id"]))
				damage[key] = {"hp": int(target["hp"]), "damage": int(loss["hp_loss"]), "lethal": int(target["hp"]) <= 0}
	result["enemy_threat_previews"] = previews
	result["projected_attack_tiles"] = attack_tiles
	result["damage_preview"] = damage
	return result

static func grounded_texts(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for target: Dictionary in Rules.grounded_targets(before, after):
		result.append({"tile": target["tile"], "text": "Grounded", "color": COLOR})
	return result

static func queue_grounded(scene: Control, step: Dictionary) -> void:
	var texts: Array[Dictionary]
	for target: Dictionary in step.get("grounded_targets", []):
		texts.append({"tile": target["tile"], "text": "Grounded", "color": COLOR})
	if not texts.is_empty(): scene._queue_player_popup_group(texts, 0.0)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary = {}) -> void:
	if Cutout.handles(step, actor):
		await _animate_cutout_discharge(scene, state, step, actor)
		return
	var before: Dictionary = state.duplicate(true)
	var hits: Array = step.get("chain_hits", [])
	for index: int in hits.size():
		var hit: Dictionary = hits[index]
		var effect: Dictionary = _hop_effect(step, hit)
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step({"kind": "ranged", "element": "lightning"}))
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, Rules.HOP_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
			var shown: Dictionary = {"effect": effect, "effect_progress": float(frame - 1) / float(scene.ATTACK_FRAMES)}
			_add_spark_flight(shown, index)
			scene._render_board_state(state, shown, true)
		)
		state.merge(hit["state"].duplicate(true), true)
		scene._render_board_state(state, {})
		preload("res://scripts/enemy_mechanics/chain_hit_feedback.gd").submit(scene, state, hit.get("target_losses", []))
		_present_contacts(scene, before, hits, index, index + 1)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})

# The approved cutout still supplies its pose, phase mapping, sound, and hit
# updates. Use the same rig and tail clocks and attach visuals to completed hops.
static func _animate_cutout_discharge(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(Cutout.TYPE)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var key: String = str(step["actor_key"])
	var direction: Vector2i = state["player"]["pos"] - actor["pos"]
	var reduced: bool = scene._reduced_motion_enabled()
	var hits: Array = step.get("chain_hits", [])
	var before: Dictionary = state.duplicate(true)
	var clock: Dictionary = {"cued_hops": 0, "completed_hops": 0}
	var count: int = 1 if reduced else Action.frames_for(Cutout.TYPE, clip)
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else Cutout.phase_at(frame, count, contact)
		var shown: Dictionary = Cutout.motion_for(key, clip, phase, direction)
		if phase < contact:
			scene._render_board_state(state, shown, true)
		else:
			_discharge_frame(scene, state, step, before, hits, clock, (phase - contact) * seconds, shown)
	)
	var remaining: float = maxf(0.0, hits.size() * Rules.HOP_SECONDS - seconds * (1.0 - contact))
	if remaining > 0.0:
		var tail_count: int = maxi(1, ceili(remaining * Action.FPS))
		await scene._play_timed_animation_frames(tail_count, remaining / tail_count, func(frame: int) -> void:
			var shown: Dictionary = Cutout.motion_for(key, clip, 1.0, direction)
			_discharge_frame(scene, state, step, before, hits, clock, seconds * (1.0 - contact) + remaining * float(frame) / tail_count, shown)
		)
	var completed: int = clock["completed_hops"]
	Cutout.finish_hops(scene, state, hits, clock, hits.size())
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
	_present_contacts(scene, before, hits, completed, hits.size())

static func _discharge_frame(scene: Control, state: Dictionary, step: Dictionary, before: Dictionary, hits: Array, clock: Dictionary, elapsed: float, shown: Dictionary) -> void:
	var completed: int = clock["completed_hops"]
	Cutout.chain_frame(scene, state, step, hits, clock, elapsed, shown)
	_add_spark_flight(shown, int(clock["completed_hops"]))
	scene._render_board_state(state, shown, true)
	_present_contacts(scene, before, hits, completed, int(clock["completed_hops"]))

static func _hop_effect(step: Dictionary, hit: Dictionary) -> Dictionary:
	return {"kind": "chain", "from": hit["from"], "to": hit["to"], "element": "lightning", "actor_key": step["actor_key"]}

static func _add_spark_flight(shown: Dictionary, hop: int) -> void:
	if not shown.has("effect"): return
	var effect: Dictionary = shown["effect"].duplicate(false)
	effect["chain_index"] = hop + 1
	# Capacitor applies its hit at the end of its hop. Map that full window
	# onto Spark's release-to-contact interval without changing either clock.
	shown[Shot.ADAPTER_FLIGHT] = {"effect": effect, "progress": float(shown["effect_progress"]) * Chain.HOP_CONTACT}

static func _present_contacts(scene: Control, before: Dictionary, hits: Array, first: int, end: int) -> void:
	if first == end: return
	var board: Control = scene.board_view
	var reduced: bool = scene._reduced_motion_enabled()
	var specs: Array[Dictionary]
	var death_tiles: Dictionary
	for index: int in range(first, end):
		var prior: Dictionary = before if index == 0 else hits[index - 1]["state"]
		var after: Dictionary = hits[index]["state"]
		var events: Array = after.get("death_burst_events", [])
		for event_index: int in range(prior.get("death_burst_events", []).size(), events.size()):
			var event: Dictionary = events[event_index]
			var spec: Dictionary = DeferredDeath.burst_spec(board, event, prior, after)
			spec["excluded_tiles"] = death_tiles.duplicate()
			specs.append(spec)
			for tile: Vector2i in event["tiles"]: death_tiles[tile] = true
	# Burst and lethal damage numbers share the kill sample in the base
	# adapter. The Fire cross owns overlapping tiles on that sample.
	var claimed: Dictionary = death_tiles
	for index: int in range(first, end):
		var hit: Dictionary = hits[index]
		var tile: Vector2i = hit["to"]
		if claimed.has(tile): continue
		var prior: Dictionary = before if index == 0 else hits[index - 1]["state"]
		var impact: Dictionary = Bursts.step_hit_tiles(prior, hit["state"], board._resolved_unit_footprint)
		specs.append({"name": "lightning", "center": tile, "tiles": [tile], "contact_hits": impact})
		claimed[tile] = true
	board.present_tile_bursts(specs, {}, board.combat_state, reduced)
	for index: int in range(maxi(1, first), end):
		var hit: Dictionary = hits[index]
		ChainBolt.present(board, hit["from"], hit["to"], reduced)
