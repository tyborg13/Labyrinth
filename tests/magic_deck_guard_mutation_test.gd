extends SceneTree

const Suite = preload("res://tests/suites/magic_deck_suite.gd")
const Sources = preload("res://tests/sfx_sync_sources.gd")
const GUARD: String = "\tif not magic.has(card_id): return run_state.duplicate(true)"
var _caught: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var source: String = FileAccess.get_file_as_string("res://scripts/run_engine.gd")
	if source.count(GUARD) != 1:
		push_error("Ownership mutation must replace exactly one guard")
		quit(1)
		return
	var mutant: Script = Sources.compile_script("scripts/run_engine.gd", source.replace(GUARD, "\t# Ownership guard removed only in this in-memory mutation."))
	if mutant == null:
		quit(1)
		return
	Suite.unowned_purge_checks(mutant.new(), func(ok: bool, message: String) -> void:
		if not ok: _caught.append(message)
	)
	var killed: bool = _caught.has("Unowned valid spell cannot charge Embers") and _caught.has("Unowned valid spell cannot advance priced_magic_purges")
	print("OWNERSHIP GUARD MUTATION: %s (%d regression assertions caught the mutation)" % ["KILLED" if killed else "SURVIVED", _caught.size()])
	for message: String in _caught: print("MUTATION CAUGHT: " + message)
	quit(0 if killed else 1)
