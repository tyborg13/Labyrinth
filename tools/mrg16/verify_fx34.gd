extends "res://tools/fx34/verify.gd"

const GearDraw = preload("res://tools/mrg16/gear_draw_probe.gd")

func _compare(name: String, before: Dictionary, after: Dictionary) -> void:
	if _case in Fixture.CHAIN_CASES:
		super._compare(name, before, after)
		return
	# The approved fade replaces only the old tint and rise receipt.
	var old: Dictionary = before.duplicate()
	var current: Dictionary = after.duplicate()
	old.erase("items")
	current.erase("items")
	super._compare(name, old.merged({"items": []}), current.merged({"items": []}))
	var expected_items: int = 0 if _case == "fog_gear" else (2 if _case == "two_missed" else 1)
	var items: Array = after["items"]
	_expect(items.size() == GEAR_FRAMES * expected_items, name + " checks every visible missed pickup sample")
	var start_bounds: Dictionary
	for item: Dictionary in items:
		var progress: float = item["progress"]
		var tile: Vector2i = item["tile"]
		if progress == 0.0:
			start_bounds[tile] = item.get("bounds", "")
		_expect(GearDraw.matches(item, progress, start_bounds.get(tile, "")),
			"%s %s fades in place with only opacity at %.1f" % [name, tile, progress])

func _expected_rows(report: Dictionary, chain: bool) -> Dictionary:
	return super._expected_rows(report, chain) if chain else {}

func _audit_draws(board: Control, effect: Dictionary, missed: float) -> void:
	if missed < 0.0:
		super._audit_draws(board, effect, missed)
		return
	for loot: Dictionary in board.combat_state.get("loot", []):
		var tile: Vector2i = loot["pos"]
		if not board._board_tile_is_visible_to_player(tile) or loot.get("claimed", false): continue
		if board._missed_equipment_disintegration_progress(loot) < 0.0: continue
		var receipt: Dictionary = GearDraw.sample(board, loot)
		receipt.merge({"tile": tile, "progress": missed})
		Audit.items[[tile, missed]] = receipt
