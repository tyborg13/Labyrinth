extends SceneTree

const Suite = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const Sources = preload("res://tests/sfx_sync_sources.gd")
const ShopAction = preload("res://scripts/scavenger_action.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SERVICE_TEST_SIZE := Vector2(300.0, 52.0)
const SERVICE_LAYOUT_FRAMES: int = 2
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
	# Use the production plate and tag, with its actual rendered nested label.
	# A healthy Button.text must not mask clipping in ScavengerPurge._label.
	var service := ShopAction.new()
	service.name = "ScavengerPurge"
	service.surface = "segment"
	service.text = "Purge a spell"
	service.size = SERVICE_TEST_SIZE
	Typography.set_button_size(service, 22)
	controls.add_child(service)
	var price := PriceTag.new()
	price.name = "ScavengerPurgePrice"
	price.amount = 50
	price.size = Vector2(118.0, 60.0)
	price.position = Vector2(SERVICE_TEST_SIZE.x - price.size.x, -price.size.y)
	service.add_child(price)
	for _frame: int in range(SERVICE_LAYOUT_FRAMES): await process_frame
	service.prepare_label()
	var service_passed: bool = true
	for disabled: bool in [false, true]:
		service.disabled = disabled
		var baseline: Array[String] = Presentation.text_fit_failures(service)
		if not baseline.is_empty():
			service_passed = false
			for failure: String in baseline: push_error(failure)
		var label_path: String = str((service.get("_label") as Label).get_path())
		var service_caught: Array[String] = Presentation.service_label_clipping_failures(service)
		var service_killed: bool = service_caught.any(func(value: String) -> bool: return value.begins_with(label_path + " clips Label "))
		service_passed = service_passed and service_killed and Presentation.text_fit_failures(service).is_empty()
		print("SERVICE TEXT FIT GUARD MUTATION (%s): %s" % ["disabled" if disabled else "enabled", "KILLED" if service_killed else "SURVIVED"])
	controls.free()
	quit(0 if killed and text_killed and service_passed else 1)
