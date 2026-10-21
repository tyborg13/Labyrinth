extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const TetherView = preload("res://scripts/enemy_mechanics/tether_view.gd")
const COLOR := Color("a77bf0")
const EMPTY_COLOR := Color("3a2f4f")
const PIP_SIZE: float = 8.0
const GLOW_ALPHA: float = 0.4
const PIP_GAP: float = 4.0
const PIP_ROW_OFFSET: float = 10.0

static var _preview_engine := Combat.new()

static func charge_tooltip(state: Dictionary, unit: Dictionary) -> String:
	return Icons.tooltip("charge").replace("At 3,", "At %d," % Rules.threshold(state, unit))

static func badges(unit: Dictionary, state: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if Rules.is_capacitor(unit): result.append({"icon": "charge", "count": int(unit.get("charge", 0)), "fill": EMPTY_COLOR, "border": COLOR, "icon_tint": Color.WHITE, "tooltip": charge_tooltip(state, unit) + "\n%d/%d" % [int(unit.get("charge", 0)), Rules.threshold(state, unit)]})
	return result

static func draw_pips(board: Control, unit: Dictionary, health: Rect2) -> void:
	if not Rules.is_capacitor(unit): return
	var centers: Array[Vector2] = pip_centers(health, Rules.threshold(board.combat_state, unit))
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
		token = Icons.icon_text_token("charge", "+%d" % int(action.get("amount", 1)))
	else:
		token = Icons.icon_text_token("chain", str(int(action["damage"])))
	# Arc Burst retains the approved Chain art, but explains Charge.
	token["glossary_key"] = "charge"
	token["tooltip"] = charge_tooltip(state, unit)
	return [[token]]

static func draw_telegraphs(board: Control) -> void:
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		if str(threat.get("projected_attack_action", {}).get("type", "")) != "chain_discharge": continue
		for hit: Dictionary in threat.get("chain_hits", []):
			var start: Vector2 = TetherView.chest(board, hit["from"])
			var finish: Vector2 = TetherView.chest(board, hit["to"])
			for span: Vector2 in TetherView.dash_spans(start.distance_to(finish), 0.0, true):
				board.draw_line(start + start.direction_to(finish) * span.x, start + start.direction_to(finish) * span.y, Color(COLOR, TetherView.DASH_ALPHA), TetherView.DASH_WIDTH, true)
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

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	for hit: Dictionary in step.get("chain_hits", []):
		var effect: Dictionary = {"kind": "chain", "from": hit["from"], "to": hit["to"], "element": "lightning", "actor_key": step["actor_key"]}
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step({"kind": "ranged", "element": "lightning"}))
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, Rules.HOP_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
			scene._render_board_state(state, {"effect": effect, "effect_progress": float(frame - 1) / float(scene.ATTACK_FRAMES)}, true)
		)
		state.merge(hit["state"].duplicate(true), true)
		scene._render_board_state(state, {})
		scene._queue_player_popup_group(scene._floating_texts_for_target_losses(hit.get("target_losses", [])), 0.0)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
