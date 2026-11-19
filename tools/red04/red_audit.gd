extends RefCounted
## Pair the legacy and current floor on the same settled scene. Decorators
## and visibility are shared so rule and Snare geometry cannot skew the delta.

const Model = preload("res://tools/qa110/model.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const SOURCE_KEY := "enemy_1"
const WALK_TILE := Vector2i(2, 5)
const THAROKH_PRESENT := [Vector2i(2, 5), Vector2i(5, 3), Vector2i(5, 4)]
const THAROKH_SHIFTED := [Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5), Vector2i(3, 4)]

static func paired(scene: Node) -> Dictionary:
	var board: Control = scene.board_view
	var shown: Dictionary = board.presentation
	var live: Dictionary = shown.get("threats_at_rest", {})
	var state: Dictionary = scene._combat_state
	var preview: Dictionary = scene._enemy_intent_preview_state(scene._board_display_state())
	var at_rest: bool = is_same(preview, state)
	var engine: RefCounted = scene._combat_engine
	var known: Callable = scene._surface_preview_information_state.bind(preview)
	var first: Dictionary = Model.Badges.new().presentation_for_state(engine, state, preview, "", known)
	var revision: int = scene._combat_preview_revision
	var marks: Dictionary = scene._rest_pass_disc_marks
	if not at_rest:
		var hovered: Dictionary = scene._hover_red_forecast()
		marks = {} if hovered.is_empty() else Discs.record(hovered, revision)
	var legacy: Dictionary = Discs.apply(first, marks, revision, true)
	var first_actors: Dictionary = _actor_tiles(first["threats"])
	var legacy_actors: Dictionary = _actor_tiles(legacy["threats"])
	var floor: Array = Red.floor_rows(shown)
	var actual_actors: Dictionary = _actor_tiles(floor)
	var legacy_rest: Dictionary = live.duplicate(false)
	var legacy_rows: Array[Dictionary]
	legacy_rows.assign(live.get("threats", []))
	var actual_lookup: Dictionary = {}
	var legacy_lookup: Dictionary = {}
	var kinds: Dictionary = {}
	var later_rows: int = 0
	for row: Dictionary in floor:
		var key: String = str(row["key"])
		if key == "snare_pressure": continue
		_collect(board, row, actual_lookup)
		if row.get("later", false): later_rows += 1
		if row.get("later", false) or row.get("hero_hit", false):
			var kind: String = ("rule_contact" if key == "battlefield_rule" else "foe_surface") if row.get("hero_hit", false) else "unexpected_later_attack"
			var kind_tiles: Dictionary = kinds.get_or_add(kind, {})
			_collect(board, row, kind_tiles)
	for row: Dictionary in legacy_rows:
		if row["key"] != "snare_pressure": _collect(board, row, legacy_lookup)
	for tile: Vector2i in preload("res://scripts/enemy_mechanics/lob_view.gd").marks(board):
		if board._board_tile_is_visible_to_player(tile):
			legacy_lookup[tile] = true
			actual_lookup[tile] = true
	legacy_rest["threats"] = legacy_rows
	var gained: Array = _difference(actual_lookup, legacy_lookup)
	var lost: Array = _difference(legacy_lookup, actual_lookup)
	var reasons: Array[String]
	for kind: String in kinds:
		if gained.any(func(tile: Vector2i) -> bool: return kinds[kind].has(tile)): reasons.append(kind)
	var shifted: bool = false
	var dropped: bool = false
	var restored: bool = false
	var unshifted: bool = false
	for key: String in first_actors:
		var old: Dictionary = legacy_actors.get(key, {})
		var current: Dictionary = first_actors[key]
		if current == old: continue
		var added: bool = gained.any(func(tile: Vector2i) -> bool: return current.has(tile) and not old.has(tile))
		var removed: bool = lost.any(func(tile: Vector2i) -> bool: return old.has(tile) and not current.has(tile))
		if marks.get("died_first_keys", {}).has(key):
			dropped = true
			restored = restored or added
		if marks.get("relative_red_areas", {}).has(key):
			shifted = true
			unshifted = unshifted or added or removed
	if unshifted: reasons.append("present_anchor")
	if restored: reasons.append("living_foe_warning")
	return {"at_rest": at_rest, "legacy_rest": legacy_rest, "first_actors": first_actors,
		"legacy_actors": legacy_actors, "actual_actors": actual_actors, "gained": gained, "lost": lost,
		"board_changed": not gained.is_empty() or not lost.is_empty(), "kinds": reasons, "later_rows": later_rows,
		"legacy_shifted": shifted, "legacy_omitted": dropped, "shifted_or_omitted": first_actors != actual_actors}

static func _actor_tiles(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("later", false) or row.get("hero_hit", false) or not row["key"].begins_with("enemy_") or not row.has("plan"): continue
		var owned: Dictionary = result.get_or_add(row["key"], {})
		for tile: Vector2i in row["tiles"]: owned[tile] = true
		if owned.is_empty(): result.erase(row["key"])
	return result

static func _collect(board: Control, row: Dictionary, lookup: Dictionary) -> void:
	for tile: Vector2i in row["tiles"]:
		if board._board_tile_is_visible_to_player(tile) or bool(row.get("area_announced", row.get("area_fixed", false))):
			lookup[tile] = true

static func _difference(left: Dictionary, right: Dictionary) -> Array:
	var result: Array = left.keys().filter(func(tile: Vector2i) -> bool: return not right.has(tile))
	result.sort()
	return result

static func compact(picture: Dictionary) -> Dictionary:
	var report: Dictionary = picture.duplicate(false)
	for key: String in ["legacy_rest", "first_actors", "legacy_actors", "actual_actors"]: report.erase(key)
	return report

static func repro(scene: Node, tharokh: bool, before: bool) -> Dictionary:
	var picture: Dictionary = paired(scene)
	var old: Dictionary = picture["legacy_actors"].get(SOURCE_KEY, {})
	var live: Dictionary = picture["actual_actors"].get(SOURCE_KEY, {})
	var first: Dictionary = picture["first_actors"].get(SOURCE_KEY, {})
	var wanted: Array = THAROKH_PRESENT if tharokh else [WALK_TILE]
	var shifted: Array = THAROKH_SHIFTED if tharokh else []
	var valid: bool = picture["at_rest"] and live == first
	for tile: Vector2i in wanted: valid = valid and first.has(tile) and not old.has(tile)
	for tile: Vector2i in shifted: valid = valid and old.has(tile) and not first.has(tile)
	var state: Dictionary = scene._combat_state
	var pass_summary: Dictionary = scene._pass_preview_summary()
	var witness: Dictionary = {"ok": valid, "before": before, "first": first.keys(), "legacy": old.keys(),
		"present": live.keys(), "hero_tile": state["player"]["pos"], "hero_hp": state["player"]["hp"],
		"hero_max_hp": state["player"]["max_hp"], "pass_hp_loss": pass_summary.get("hp_loss", 0)}
	if not tharokh:
		var board: Control = scene.board_view
		var slices: GDScript = preload("res://scripts/board_layer_slices.gd")
		var marker: Dictionary = slices.threat_paint(board, WALK_TILE, {}, PackedVector2Array(), true)
		witness["floor_only"] = board._rest_threat_tile_alphas.has(WALK_TILE) and marker.is_empty()
		witness["ok"] = valid and witness["hero_tile"] == WALK_TILE and witness["floor_only"] and scene._rest_pass_disc_marks.get("died_first_keys", {}).has(SOURCE_KEY)
	if before and witness["ok"]:
		var board: Control = scene.board_view
		var shown: Dictionary = board.presentation.duplicate(false)
		shown.erase(Red.FLOOR_KEY)
		shown["threats_at_rest"] = picture["legacy_rest"]
		board.set_combat_state(board.combat_state, board.move_tiles, board.attack_tiles, board.selected_tile,
			board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, shown)
	var painted: Dictionary = _actor_tiles(Red.floor_rows(scene.board_view.presentation)).get(SOURCE_KEY, {})
	witness["painted"] = painted.keys()
	witness["ok"] = witness["ok"] and painted == (old if before else first)
	return witness
