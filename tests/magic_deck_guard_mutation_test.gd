extends SceneTree

const Suite = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
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
	var controls := Control.new()
	root.add_child(controls)
	var clipped_label := Label.new()
	clipped_label.name = "ClippedLabelMutation"
	clipped_label.text = "Clipped text must fail"
	clipped_label.clip_text = true
	controls.add_child(clipped_label)
	clipped_label.size.x = 1.0
	var clipped_button := Button.new()
	clipped_button.name = "ClippedButtonMutation"
	clipped_button.text = clipped_label.text
	clipped_button.clip_text = true
	controls.add_child(clipped_button)
	clipped_button.size.x = 1.0
	await process_frame
	clipped_label.size.x = 1.0
	clipped_button.size.x = 1.0
	var caught: Array[String] = Presentation.text_fit_failures(controls)
	var text_killed: bool = caught.any(func(value: String) -> bool: return value.contains("ClippedLabelMutation")) and caught.any(func(value: String) -> bool: return value.contains("ClippedButtonMutation"))
	print("TEXT FIT GUARD MUTATION: %s (%d clipped controls caught)" % ["KILLED" if text_killed else "SURVIVED", caught.size()])
	controls.free()
	quit(0 if killed and text_killed else 1)
