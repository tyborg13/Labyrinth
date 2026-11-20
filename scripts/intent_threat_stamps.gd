extends RefCounted
## Held displays retain the saved approach. Red coverage uses reachable
## relative stamps for stopped enemies, with fixed marks left in place.

const Areas = preload("res://scripts/boss_area_rules.gd")
const Maneuvers = preload("res://scripts/maneuver_rules.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")

static func append_visible(engine: RefCounted, known: Dictionary, enemy: Dictionary, intent: Dictionary, row: Dictionary, same_board: bool, live: bool, area: bool, release_rows: Array[Dictionary], floor_rows: Array[Dictionary]) -> void:
	var saved: Dictionary = enemy.get("intent", {})
	var shares_plan: bool = row["plan"].has("projected_destination") and is_same(intent, saved)
	var floor: Array[Vector2i]
	var release: Array[Vector2i]
	var stopped: bool = false
	if saved.has("committed_plan") and Areas.has_held(saved):
		stopped = _movement_stopped(enemy)
		var ordinary_engine: bool = engine.get_script().resource_path in ["res://scripts/combat_engine.gd", "res://scripts/hero_facing_combat.gd"]
		if shares_plan:
			var anchored: Dictionary = enemy.duplicate(false)
			anchored["pos"] = row["plan"]["projected_destination"]
			floor = Areas.announced_tiles(anchored, null, known)
		elif stopped:
			floor = Areas.announced_tiles(enemy, null, known)
		if shares_plan and same_board and ordinary_engine and not Warband.active(known) and int(enemy.get("shock", 0)) <= 0 and not stopped:
			release = floor
		else:
			release = Areas.announced_tiles(enemy, engine, known)
		if not shares_plan and not stopped: floor = release
	else:
		release = Areas.announced_tiles(enemy, null, known)
		floor = release
	var marker_held: Variant = floor if stopped and floor != release else null
	var rows: Array[Dictionary] = _rows(row, intent, release, live, area, marker_held)
	release_rows.append_array(rows)
	floor_rows.append_array(rows if release == floor else _rows(row, intent, floor, live, area))

static func append_concealed(engine: RefCounted, state: Dictionary, committed: Dictionary, enemy: Dictionary, release_rows: Array[Dictionary], floor_rows: Array[Dictionary]) -> void:
	var release: Array[Vector2i] = Areas.announced_tiles(enemy, engine, state)
	var floor: Array[Vector2i] = Areas.announced_tiles(enemy, null, state) if _movement_stopped(enemy) else release
	if release.is_empty() and floor.is_empty(): return
	var row: Dictionary = {"key": "enemy_%d" % int(committed["id"]), "tiles": release, "alpha": 1.0,
		"area": true, "area_announced": true, "area_signature": Areas.forecast_signature(committed.get("intent", {})),
		"order": "", "attacker_tile": committed["pos"]}
	if floor != release:
		var release_row: Dictionary = row.duplicate(false)
		release_row["marker_tiles"] = floor
		release_rows.append(release_row)
	elif not release.is_empty(): release_rows.append(row)
	if not floor.is_empty():
		if floor != release:
			row = row.duplicate(false)
			row["tiles"] = floor
		floor_rows.append(row)

static func _rows(row: Dictionary, intent: Dictionary, held: Array[Vector2i], live: bool, area: bool, marker_held: Variant = null) -> Array[Dictionary]:
	var rows: Array[Dictionary]
	if not held.is_empty() or (marker_held != null and not marker_held.is_empty()):
		var announced: Dictionary = row.duplicate(false)
		announced.merge({"tiles": held, "area": true, "area_announced": true, "area_signature": Areas.forecast_signature(intent)})
		if marker_held != null: announced["marker_tiles"] = marker_held
		rows.append(announced)
	if live:
		var impact: Array = row["plan"].get("projected_attack", [])
		var attack: Dictionary = row.duplicate(false)
		attack["tiles"] = _uncovered(impact, held)
		if marker_held != null: attack["marker_tiles"] = _uncovered(impact, marker_held)
		attack["area"] = area
		# A held and a live row may describe the same plan. Each owns its payload.
		if not held.is_empty(): attack["plan"] = row["plan"].duplicate(true)
		rows.append(attack)
	return rows

static func _uncovered(impact: Array, held: Array[Vector2i]) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for tile: Vector2i in impact:
		if not held.has(tile): tiles.append(tile)
	return tiles

static func _movement_stopped(enemy: Dictionary) -> bool:
	return bool(enemy.get("immobilize", false)) or int(enemy.get("freeze", 0)) > 0 or Maneuvers.is_petrified(enemy)
