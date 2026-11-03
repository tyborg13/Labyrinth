extends RefCounted
## The next battlefield beat's tiles, marked like any other threat at rest (el-04).
## Snares keep their own pressure view; Warband orders and ordinary sources preview
## here, and only when their beat fires before the hero's next turn.
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const THREAT_KEY: String = "battlefield_rule"
const TURN_ORDER_SCAN: int = 12
# Gust keeps WindView's landing ghosts. Upheaval sets units down like the wind does, so it uses the same pale
# ghost. Shadowstep is enemies moving, so it uses the enemy-move ghost, drawn as the Umbra shade: the movers are
# hidden, and the shade is how the game already shows a hidden enemy (el-05).
const ENEMY_MOVE_ROLE: String = "enemy_move_preview"
const SHADE_TYPE: String = "umbra_shade"
# The shade icon is near-black, so as an enemy-move ghost it vanishes on dark floors. Its ghost is the hooded figure
# alone as pale Umbra light (the violet aura dropped, the eye openings left clear), standing on its tile at about the
# hero's height (45% of the unit frame).
const SHADE_SOURCE_PATH: String = "res://assets/art/icons/umbra_presence.png"
const SHADE_LIGHTEN: float = 0.6
const SHADE_BODY_MAX_VALUE: float = 0.22
const SHADE_FRAME_SHARE: float = 0.45
static var _shade_texture: Texture2D
static var _engine := preload("res://scripts/combat_engine.gd").new()
static var _memo := preload("res://scripts/combat_preview_memo.gd").new()
static var _ghost_memo := preload("res://scripts/combat_preview_memo.gd").new()

static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	if state.is_empty() or str(state.get("objective", {}).get("special_type", "")) == "umbral_snare": return original
	if str(state.get("current_actor", {}).get("kind", "player")) != "player": return original
	var effect: Dictionary = original.get("effect", {})
	if not effect.is_empty() and not bool(effect.get("preview", false)): return original
	if BattlefieldRules.active(state).is_empty(): return original
	# Same pure inputs as the rule forecast itself: the board state and every catalog it reads.
	var tiles: Array = _memo.resolve(BattlefieldRules.forecast_inputs(_engine, state), func() -> Array: return _due_tiles(state))
	if tiles.is_empty(): return original
	var result: Dictionary = original.duplicate(false)
	var rest: Dictionary = original.get("threats_at_rest", {}).duplicate(false)
	var threats: Array = rest.get("threats", []).duplicate(false)
	threats = threats.filter(func(threat: Dictionary) -> bool: return str(threat.get("key", "")) != THREAT_KEY)
	threats.append({"key": THREAT_KEY, "area": true, "tiles": tiles})
	rest["threats"] = threats
	rest["hero_tile"] = state["player"]["pos"]
	result["threats_at_rest"] = rest
	return result

static func _due_tiles(state: Dictionary) -> Array:
	var tiles: Array = []
	if not beat_before_next_player_turn(state): return tiles
	for group: Array in BattlefieldRules.forecast(_engine, state).get("tiles", {}).values():
		for tile: Vector2i in group:
			if not tiles.has(tile): tiles.append(tile)
	return tiles

## True when the rail shows the rule's beat before the hero acts again.
static func beat_before_next_player_turn(state: Dictionary) -> bool:
	for entry: Dictionary in _engine.current_turn_order(state, TURN_ORDER_SCAN):
		if bool(entry.get("active", false)): continue
		if str(entry.get("kind", "")) == "beat": return true
		if str(entry.get("kind", "")) == "player": return false
	return false

## Ghosts where the due beat sets units down: Upheaval's displaced occupants and Shadowstep's Blinks.
## Hidden movers become the Umbra shade; landings the player cannot see get no ghost.
static func move_ghosts(view: Control) -> Array[Dictionary]:
	var ghosts: Array[Dictionary]
	var state: Dictionary = view.combat_state
	if state.is_empty() or str(state.get("current_actor", {}).get("kind", "player")) != "player": return ghosts
	var rule: String = str(BattlefieldRules.active(state).get("rule", ""))
	if rule not in ["upheaval", "shadowstep"]: return ghosts
	var due: Dictionary = _ghost_memo.resolve(BattlefieldRules.forecast_inputs(_engine, state), func() -> Dictionary: return _due_moves(state))
	var role: String = ENEMY_MOVE_ROLE if rule == "shadowstep" else WindView.GHOST_ROLE
	for move: Dictionary in due.get("moves", []):
		var landing: Vector2i = move["to"]
		if not view._board_tile_is_visible_to_player(landing): continue
		var unit: Dictionary = _unit_for(state, str(move["actor_key"]))
		if unit.is_empty(): continue
		ghosts.append(_ghost(unit, role, landing, str(move["actor_key"])))
	# Hidden movers: the forecast keeps only where they will appear, so they stand as the shade.
	for landing: Vector2i in due.get("emergences", []):
		if not view._board_tile_is_visible_to_player(landing): continue
		var shade: Dictionary = {"id": -1, "type": SHADE_TYPE, "name": "", "footprint": Vector2i.ONE, "ghost_texture": shade_texture()}
		ghosts.append(_ghost(shade, role, landing, "shade"))
	return ghosts

static func _ghost(unit: Dictionary, role: String, landing: Vector2i, source_key: String) -> Dictionary:
	unit.merge({"role": role, "pos": landing, "key": "rule_ghost_%s_%d_%d" % [source_key, landing.x, landing.y], "wind_forecast": false,
		"hp": 1, "max_hp": 1, "block": 0, "stoneskin": 0, "bleed": 0, "freeze": 0, "shock": 0, "immobilize": false, "intent": {}, "preview": true}, true)
	return unit

static func _due_moves(state: Dictionary) -> Dictionary:
	if not beat_before_next_player_turn(state): return {}
	# A Snare's beat resolves after the hero's activation-end preparation: forecast from that boundary, as the
	# Snare pressure preview does.
	var snare: bool = str(state.get("objective", {}).get("special_type", "")) in ["umbral_snare", "last_light"]
	var basis: Dictionary = _engine.prepare_player_activation_end(state) if snare and _engine.is_player_turn(state) else state
	var forecast: Dictionary = BattlefieldRules.forecast(_engine, basis)
	return {"moves": (forecast.get("moves", []) as Array).duplicate(true), "emergences": (forecast.get("emergences", []) as Array).duplicate(true)}

static func _unit_for(state: Dictionary, key: String) -> Dictionary:
	if key == "player":
		return {"key": "player", "id": -1, "type": "player", "name": "Player", "footprint": Vector2i.ONE}
	for illusion: Dictionary in state.get("illusions", []):
		if "illusion_%d" % int(illusion.get("id", -1)) == key and int(illusion.get("hp", 0)) > 0:
			return {"key": key, "id": int(illusion["id"]), "type": "player", "name": "Illusion", "footprint": Vector2i.ONE}
	for enemy: Dictionary in state.get("enemies", []):
		if "enemy_%d" % int(enemy.get("id", -1)) == key and int(enemy.get("hp", 0)) > 0:
			return {"key": key, "id": int(enemy["id"]), "type": str(enemy["type"]), "name": str(enemy.get("name", "")), "footprint": enemy.get("footprint", Vector2i.ONE)}
	return {}

static func shade_texture() -> Texture2D:
	if _shade_texture != null: return _shade_texture
	# Loaded lazily, source first: a fresh checkout has no imported texture cache yet.
	var source: Image = AssetLoader.load_texture_source_first(SHADE_SOURCE_PATH).get_image()
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var body := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var pixel: Color = source.get_pixel(x, y)
			if pixel.a > 0.08 and pixel.v < SHADE_BODY_MAX_VALUE: body.set_pixel(x, y, Color(UiPalette.UMBRA.lightened(SHADE_LIGHTEN), pixel.a))
	var figure: Image = body.get_region(body.get_used_rect())
	var canvas_height: int = int(ceil(float(figure.get_height()) / SHADE_FRAME_SHARE))
	var canvas := Image.create(figure.get_width(), canvas_height, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), Vector2i(0, canvas_height - figure.get_height()))
	_shade_texture = ImageTexture.create_from_image(canvas)
	return _shade_texture
