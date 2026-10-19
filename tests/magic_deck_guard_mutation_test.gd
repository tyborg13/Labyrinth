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
const DISC_ALPHA_GUARD: String = "const COPY_BADGE_DISC_ALPHA: float = 0.92"
const DISC_DRAW_GUARD: String = "\t\tpaint_disc(Callable(self, \"draw_circle\"))"
const MUTATED_DISC_ALPHA: float = 0.5
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
	var disc_killed: bool = _disc_alpha_mutation()
	var draw_killed: bool = _disc_draw_mutation()
	var focus_killed: bool = await preload("res://tests/helpers/magic_purge_focus_mutations.gd").run(self)
	var passed: bool = killed and text_killed and service_passed and disc_killed and draw_killed and focus_killed
	print("MAGIC DECK GUARD MUTATIONS: %s" % ("PASS" if passed else "FAIL"))
	print("TEST RESULT: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)

func _disc_draw_mutation() -> bool:
	var source: String = FileAccess.get_file_as_string("res://scripts/pile_dialog_view.gd")
	if source.count(DISC_DRAW_GUARD) != 1:
		push_error("Disc draw mutation must remove exactly one painter call")
		return false
	var checks = preload("res://tests/helpers/pile_copy_badge_checks.gd")
	var baseline: Array[String]
	checks.assert_disc_draw(source, func(ok: bool, message: String) -> void:
		if not ok: baseline.append(message)
	)
	var caught: Array[String]
	checks.assert_disc_draw(source.replace(DISC_DRAW_GUARD, "\t\tpass"), func(ok: bool, message: String) -> void:
		if not ok: caught.append(message)
	)
	for failure: String in baseline: push_error(failure)
	var killed: bool = baseline.is_empty() and caught.has("Medallion _draw delegates once to the checked disc painter")
	print("BADGE DISC DRAW MUTATION: %s" % ("KILLED" if killed else "SURVIVED"))
	return killed

func _disc_alpha_mutation() -> bool:
	var source: String = FileAccess.get_file_as_string("res://scripts/pile_dialog_view.gd")
	if source.count(DISC_ALPHA_GUARD) != 1:
		push_error("Disc alpha mutation must replace exactly one paint alpha")
		return false
	var mutant: GDScript = Sources.compile_script("scripts/pile_dialog_view.gd", source.replace(DISC_ALPHA_GUARD, "const COPY_BADGE_DISC_ALPHA: float = %s" % MUTATED_DISC_ALPHA))
	if mutant == null: return false
	var checks = preload("res://tests/helpers/pile_copy_badge_checks.gd")
	var healthy: Control = preload("res://scripts/pile_dialog_view.gd").CopyCountFace.new()
	healthy.size = Vector2(52, 52)
	healthy.call("_layout")
	var baseline: Array[String]
	checks.assert_disc_paint(healthy, func(ok: bool, message: String) -> void:
		if not ok: baseline.append(message)
	)
	healthy.free()
	var face_script: GDScript = mutant.get_script_constant_map()["CopyCountFace"]
	var changed: Control = face_script.new()
	changed.size = Vector2(52, 52)
	changed.call("_layout")
	var caught: Array[String]
	checks.assert_disc_paint(changed, func(ok: bool, message: String) -> void:
		if not ok: caught.append(message)
	)
	changed.free()
	var killed: bool = baseline.is_empty() and caught.has("Medallion centre disc paints INK_0 at alpha 0.92")
	print("BADGE DISC ALPHA MUTATION: %s" % ("KILLED" if killed else "SURVIVED"))
	return killed
