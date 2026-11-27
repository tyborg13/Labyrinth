extends "res://tools/fel06/hover_probe.gd"

const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const DoorWitness = preload("res://tools/fel08/door_witness.gd")
const ObjectiveWitness = preload("res://tools/fel08/objective_witness.gd")
const PILLAR_ENTRY := {"title": "Pillar", "description": "Blocks movement and sight.", "icon": ""}
const PILLAR_TILE := Vector2i(7, 7)
const UNIT_TILE := Vector2i(4, 7)
const DOOR_TILE := Vector2i(4, 8)
const FIRST := "01-s0-seed1-0-4_0-t9"
const DOOR := "02-s0-seed12-0-1_3-t7"
const SECOND := "09-s3-seed12-3-16_0-t15"
const SPECIAL_KINDS := ["ice_pillar", "dragon_spire"]
const METEOR_DAMAGE: int = 1
const BOUNDARY_WALL := Vector2i.ZERO
const OFF_BOARD := Vector2i(-1, -1)
const BOARD_READY_TIMEOUT_MSEC: int = 5000

var _baseline: bool
var _stacks: Dictionary = {}
var _special_pending: bool


func _run() -> void:
	if _dry != (DisplayServer.get_name() == "headless") or not DirAccess.dir_exists_absolute(_destination):
		_fail("use tools/fel08/native.sh [--dry-run]")
		return
	_baseline = _dry and OS.get_environment("FEL08_BASELINE") == "1"
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel08_capture_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated capture settings")
		return
	var ids: PackedStringArray = [FIRST, SECOND]
	var special_fixtures: PackedStringArray
	if _dry:
		ids.insert(1, DOOR)
		if not _find_special_fixtures(special_fixtures): return
		for id: String in special_fixtures:
			if not ids.has(id): ids.append(id)
	for id: String in ids:
		_special_pending = special_fixtures.has(id)
		if (await _fixture(id)).is_empty(): return
	if not _stacks.has(FIRST + " C") or not _stacks.has(SECOND + " C") or (_dry and not (_stacks.has(FIRST + " B") and _stacks.has(DOOR + " C"))):
		_fail("one or more census picks did not match their specified coordinates")
		return
	var output := FileAccess.open(_destination.path_join("stacks.json"), FileAccess.WRITE)
	if output == null or not output.store_string(JSON.stringify(_stacks, "\t") + "\n"):
		_fail("cannot write stack observations")
		return
	output.close()
	if not _baseline and not await DoorWitness.run(self): return
	if not _baseline and not await ObjectiveWitness.run(self): return
	print("FEL08 %s PASS pillars=2 controls=%d" % ["BASE" if _baseline else ("DRY RUN" if _dry else "NATIVE"), _stacks.size() - 2])
	quit()


func _hover(scene: Node, board: Control, id: String, pick: Dictionary) -> Dictionary:
	if _special_pending:
		_special_pending = false
		if not await _special_control(scene, board, id): return {}
	var category: String = pick["category"]
	var tile: Vector2i = pick["tile"]
	if category == "C" and id in [FIRST, SECOND] and tile == PILLAR_TILE:
		if pick["grid"] != "pillar" or not (pick["units"] as Array).is_empty():
			return _fail(id + " expected an unoccupied grid pillar")
		var sample: Dictionary = await _observe(scene, board, id, pick, true)
		if sample.is_empty(): return sample
		if _dry and not _baseline and id == FIRST and not _edge_stacks(board): return {}
		return sample
	if _dry and ((id == FIRST and category == "B" and tile == UNIT_TILE) or (id == DOOR and category == "C" and tile == DOOR_TILE)):
		return await _observe(scene, board, id, pick)
	return {"skipped": true}


func _find_special_fixtures(result: PackedStringArray) -> bool:
	var ids: PackedStringArray = DirAccess.get_directories_at(FIXTURES)
	ids.sort()
	for id: String in ids:
		var file := FileAccess.open(FIXTURES.path_join(id).path_join(Checkpoint.RUN_FILE), FileAccess.READ)
		if file == null:
			_fail(id + " cannot read the fixture for the special terrain audit")
			return false
		var run: Dictionary = file.get_var(false)
		for terrain: Dictionary in run.get("combat_state", {}).get("terrain", []):
			if SPECIAL_KINDS.has(str(terrain.get("kind", ""))):
				result.append(id)
				break
	print("FEL08 SPECIAL AUDIT fixture_saves=%d with_special_terrain=%d" % [ids.size(), result.size()])
	return true


func _special_control(scene: Node, board: Control, id: String) -> bool:
	for terrain: Dictionary in (board.get("combat_state") as Dictionary).get("terrain", []):
		var kind: String = str(terrain.get("kind", ""))
		if not SPECIAL_KINDS.has(kind): continue
		var tile: Vector2i = terrain["pos"]
		if not board.call("_board_tile_is_visible_to_player", tile): continue
		return not (await _observe(scene, board, id, {"tile": tile, "category": kind})).is_empty()
	print("FEL08 SPECIAL no visible Icefall pillar or Worldspine spire after resuming " + id)
	return true


func _edge_stacks(board: Control) -> bool:
	var original: Dictionary = board.get("combat_state")
	var state: Dictionary = original.duplicate(true)
	# Exercise the real mark index and the living Tharokh footprint with an
	# isolated snapshot. Restore before either the scene or the board draws.
	state["meteor_marks"] = [{"tiles": [PILLAR_TILE], "damage": METEOR_DAMAGE}]
	(state["grid"][UNIT_TILE.y] as Array)[UNIT_TILE.x] = "pillar"
	board.set("combat_state", state)
	var marks: Dictionary = TileTooltip.mark_entries(board)
	var marked: Array[Dictionary] = TileTooltip.build_entries(board, PILLAR_TILE, marks, {}, {})
	var occupied: Array[Dictionary] = TileTooltip.build_entries(board, UNIT_TILE, {}, {}, {})
	var wall: Array[Dictionary] = TileTooltip.build_entries(board, BOUNDARY_WALL, {}, {}, {})
	var off_board: Array[Dictionary] = TileTooltip.build_entries(board, OFF_BOARD, {}, {}, {})
	board.set("combat_state", original)
	if _titles(marked) != ["Pillar", "Meteorfall"] or _titles(occupied) != ["Rubble"] or not wall.is_empty() or not off_board.is_empty():
		_fail("unexpected edge stacks marked=%s occupied=%s wall=%s off_board=%s" % [marked, occupied, wall, off_board])
		return false
	print("FEL08 EDGE PASS marked=[Pillar, Meteorfall] occupied=[Rubble] wall=[] off_board=[]")
	return true


func _observe(scene: Node, board: Control, id: String, pick: Dictionary, pillar: bool = false) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + BOARD_READY_TIMEOUT_MSEC
	while not scene.call("_combat_objective_board_is_framed"):
		if Time.get_ticks_msec() >= deadline: return _fail(id + " combat board did not finish framing")
		await process_frame
	var sample: Dictionary = await super._hover(scene, board, id, pick)
	if sample.is_empty(): return sample
	var tile: Vector2i = pick["tile"]
	var mouse: Array[Dictionary] = _popup_entries(board)
	var focus: Dictionary = scene.call("_controller_candidate_for_tile", tile)
	var focus_entries: Array[Dictionary] = TileTooltip.decode(str(focus.get("detail_key", "")))
	var label: String = id + " " + str(pick["category"])
	if pillar:
		var expected: Array[Dictionary]
		if not _baseline: expected.append(PILLAR_ENTRY)
		if mouse != expected or focus_entries != expected or (board.call("controller_navigable_tiles") as Array).has(tile):
			return _fail("%s %s mouse=%s focus=%s expected=%s or ordinary navigation reached the pillar" % [label, tile, mouse, focus_entries, expected])
		if not _baseline:
			var popups: Array = sample["hover"]["tooltips"]
			if popups.size() != 1 or (popups[0]["panels"] as Array).size() != 1 or popups[0]["panels"][0]["text"] != ["PILLAR", PILLAR_ENTRY["description"]]:
				return _fail(label + " did not display the exact Pillar panel: " + str(popups))
	_stacks[label] = {"tile": tile, "mouse": mouse, "focus": focus_entries}
	print("FEL08 STACK %s %s mouse=%s focus=%s" % [label, tile, _titles(mouse), _titles(focus_entries)])
	return sample


func _popup_entries(board: Control) -> Array[Dictionary]:
	var entries: Array[Dictionary]
	for popup: Window in _viewport.get_embedded_subwindows():
		if not popup.visible or popup.get_parent() != board: continue
		var stack: Node = popup.get_node_or_null("BoardTileTooltipStack")
		if stack == null: continue
		for panel: Control in stack.get_children():
			if panel.is_visible_in_tree(): entries.append(panel.get_meta("tile_tooltip_entry"))
	return entries


func _titles(entries: Array[Dictionary]) -> Array[String]:
	var titles: Array[String]
	for entry: Dictionary in entries: titles.append(str(entry["title"]))
	return titles
