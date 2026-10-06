extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const OPTION_LIMIT: int = 8

# Menu futures own exact inputs, catalogs and RNG. They never install partial
# combat or commit an equipment action. A click consumes the whole batch; only
# a complete matching factory transfers to the scene's ordinary preview guard.
var _engine := Run.new()
var _source: Dictionary = {}
var _definitions: Array = []
var _options: Array[Dictionary]
var _next_option: int = 0
var _cursor: Dictionary = {}
var _cursor_key: String = ""
var _cursor_committed_input: Dictionary = {}
var _ready: Dictionary = {}
var _complete: bool = true

func reset() -> void:
	_source = {}
	# Completed factories share this private snapshot. Release the reference
	# rather than clearing an array that a consumed factory now owns.
	_definitions = []
	_options.clear()
	_next_option = 0
	_cursor = {}
	_cursor_key = ""
	_cursor_committed_input = {}
	_ready.clear()
	_complete = true

func begin(source: Dictionary, options: Array) -> void:
	reset()
	if str(source.get("mode", "")) != Run.MODE_PRE_BATTLE or not _engine.can_change_equipment(source): return
	_source = source.duplicate(true)
	_definitions = _engine._pre_battle_definitions().duplicate(true)
	var seen: Dictionary = {}
	for value: Variant in options:
		if not value is Dictionary: continue
		var id: String = str(value.get("id", ""))
		var slot: String = str(value.get("slot", Data.equipment_slot(id)))
		var native_slot: String = Data.equipment_slot(id)
		var key: String = _key(id, slot)
		if id.is_empty() or native_slot.is_empty() or not Data.equipment_slots().has(slot) or seen.has(key): continue
		if not (_source.get("equipment_inventory", []) as Array).has(id): continue
		if (_source.get("equipped_equipment", {}) as Dictionary).values().has(id): continue
		if slot != native_slot and not (slot == "trinket" and _engine.has_run_skill(_source, "open_arsenal")): continue
		seen[key] = true
		_options.append({"id": id, "slot": slot})
		if _options.size() == OPTION_LIMIT: break
	_complete = _options.is_empty()

func matches_source(source: Dictionary) -> bool:
	return not _source.is_empty() and _source == source and _definitions == _engine._pre_battle_definitions()

func advance() -> bool:
	if _source.is_empty(): return true
	if _definitions != _engine._pre_battle_definitions():
		reset()
		return true
	if _complete: return true
	if _cursor.is_empty():
		if _next_option == _options.size():
			_complete = true
			return true
		var option: Dictionary = _options[_next_option]
		_next_option += 1
		var committed: Dictionary = _engine.equip_equipment(_source, option["id"], option["slot"])
		if str((committed.get("equipped_equipment", {}) as Dictionary).get(option["slot"], "")) != option["id"]: return false
		_cursor_committed_input = committed
		_cursor_key = _key(option["id"], option["slot"])
		# The original UI header reconciles discoveries before showing preview.
		# Compute that same pure state now; the final preview still compares every
		# field against the actual header result, including all receipt metadata.
		var preview_input: Dictionary = Library.unlock_entries(committed, Library.entry_ids_for_run_state(committed))["state"]
		_cursor = _engine.begin_pre_battle_combat_preparation(preview_input)
		return false
	if not _engine.advance_pre_battle_combat_preparation(_cursor): return false
	if _cursor.is_empty():
		reset()
		return true
	_cursor["definitions"] = _definitions
	_ready[_cursor_key] = {"committed": _cursor_committed_input, "factory": _cursor}
	_cursor = {}
	_cursor_committed_input = {}
	_cursor_key = ""
	return false

func take(before: Dictionary, committed: Dictionary, id: String, slot: String) -> Dictionary:
	var result: Dictionary = {}
	if matches_source(before):
		var ready: Dictionary = _ready.get(_key(id, slot), {})
		if not ready.is_empty() and ready["committed"] == committed:
			# Only completed private cursors enter _ready. matches_source above
			# already compared the whole live catalog snapshot; the scene still
			# validates the factory against its actual post-header input.
			result = ready["factory"]
	# Release every other private result before transferring this factory. Its
	# catalogs/state now have one owner; no future callback can mutate them.
	reset()
	return result

func snapshot() -> Dictionary:
	return {"options": _options.size(), "ready": _ready.size(), "partial": not _cursor.is_empty(), "complete": _complete}

static func _key(id: String, slot: String) -> String:
	return slot + "/" + id

static func _active(scene: Variant, prepared: RefCounted, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._equipment_factory_preparation_generation == generation and scene._equipment_factory_preparation == prepared and scene._progression_overlay_mode == "equipment" and is_instance_valid(scene._upgrade_scrim) and scene._upgrade_scrim.is_visible_in_tree() and scene._combat_state.is_empty() and prepared.matches_source(scene._run_state)

static func prepare_for(scene: Node, prepared: RefCounted, generation: int) -> void:
	if not _active(scene, prepared, generation): return
	var tree: SceneTree = scene.get_tree()
	# Leave the open/rebuild frame and its queued native layout intact. These
	# are existing process frames; input and authored motion never await us.
	for delay: int in range(2):
		await tree.process_frame
		if not _active(scene, prepared, generation):
			prepared.reset()
			return
	while _active(scene, prepared, generation):
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		var complete: bool = prepared.advance()
		scene._record_runtime_performance_phase("equipment_factory_preparation", started)
		if complete: return
		await tree.process_frame
	prepared.reset()
