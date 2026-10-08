extends RefCounted

# Each published row belongs to its final scene/list. The continuation only
# creates currently discovered entries and yields within the existing loading
# or deferred preparation; typing, visible input and result ranking stay sync.
const Library = preload("res://scripts/grimoire_library.gd")
const Search = preload("res://scripts/grimoire_search.gd")
const SLICE_USEC: int = 4000

static func prepare_current_for(scene: Node, revision: int, present: Callable, still_active: Callable) -> void:
	if not _active(scene, revision, still_active) or scene._grimoire_row_preparation_running_revision == revision: return
	scene._grimoire_row_preparation_running_revision = revision
	await _prepare_owned_for(scene, revision, present, still_active)
	if is_instance_valid(scene) and scene._grimoire_row_preparation_running_revision == revision:
		scene._grimoire_row_preparation_running_revision = -1

static func _prepare_owned_for(scene: Node, revision: int, present: Callable, still_active: Callable) -> void:
	# Let the current committed UI change complete its queued native draw first.
	await present.call()
	if not _active(scene, revision, still_active): return
	var source: Dictionary = scene._grimoire_row_preparation_key().duplicate(true)
	var known: Dictionary = {}
	for id: String in source["ids"]: known[id] = true
	scene._prune_grimoire_search_rows(source["ids"])
	var entries: Array[Dictionary]
	for entry: Dictionary in Library.entries():
		if known.has(str(entry.get("id", ""))): entries.append(entry)
	var documents: Array[Dictionary] = Search.build_index(entries, Library.sections())
	var slice_started: int = Time.get_ticks_usec()
	for document: Dictionary in documents:
		if not _active(scene, revision, still_active): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		scene._prepare_grimoire_search_row(document)
		scene._record_runtime_performance_phase("grimoire_row_preparation", started)
		if Time.get_ticks_usec() - slice_started >= SLICE_USEC:
			await present.call()
			if not _active(scene, revision, still_active) or scene._grimoire_row_preparation_key() != source: return
			slice_started = Time.get_ticks_usec()

static func _active(scene: Variant, revision: int, still_active: Callable) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._grimoire_row_preparation_revision == revision and bool(still_active.call()) and is_instance_valid(scene._grimoire_section_list)
