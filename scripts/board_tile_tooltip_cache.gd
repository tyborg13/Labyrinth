extends RefCounted

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Tooltip = preload("res://scripts/board_tile_tooltip.gd")
var revision: int = 0
var entry_build_count: int = 0
var mark_build_count: int = 0
var light_build_count: int = 0
var _entries: Dictionary = {}
var _encoded: Dictionary = {}
var _marks: Dictionary = {}
var _lights: Dictionary = {}
var _marks_ready: bool = false
var _lights_ready: bool = false
var _observed_lights: Dictionary = {}

func invalidate() -> void:
	revision += 1
	_entries.clear()
	_encoded.clear()
	_marks_ready = false
	_lights_ready = false
	_observed_lights.clear()

func entries_for_tile(view: Control, tile: Vector2i) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	if tile.x < 0 or not view._board_tile_is_visible_to_player(tile): return empty
	if _entries.has(tile): return TypedArrays.dictionaries(_entries[tile])
	if not _marks_ready:
		_marks = Tooltip.mark_entries(view)
		_marks_ready = true
		mark_build_count += 1
	if not _lights_ready: refresh_lights(view)
	var result: Array[Dictionary] = Tooltip.build_entries(view, tile, _marks, _lights)
	_entries[tile] = result
	entry_build_count += 1
	return result

func encoded_for_tile(view: Control, tile: Vector2i) -> String:
	if not _encoded.has(tile): _encoded[tile] = Tooltip.encode(entries_for_tile(view, tile))
	return str(_encoded[tile])

func refresh_lights(view: Control) -> void:
	var next: Dictionary = Tooltip.light_entries(view)
	if _lights_ready and next != _lights:
		revision += 1
		_entries.clear()
		_encoded.clear()
	_lights = next
	_lights_ready = true
	light_build_count += 1

func refresh_used_lights(view: Control) -> void:
	if _lights_ready: refresh_lights(view)

func light_region_changed(source_id: int, tile: Vector2i, key: String, text: String) -> bool:
	var identity: String = "%d:%s:%s" % [source_id, tile, key]
	if _observed_lights.get(identity) == text: return false
	_observed_lights[identity] = text
	if not _lights_ready: return false
	revision += 1
	_lights_ready = false
	_entries.clear()
	_encoded.clear()
	return true
