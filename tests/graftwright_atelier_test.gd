extends SceneTree

# VP4 unit 4, standard UI risk: exact header/dialogue, narrow panels, selection
# preview and static reduced motion. Renderer inspection uses graftwright_probe.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const View = preload("res://scripts/graftwright_view.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const ProofProbe = preload("res://tests/graftwright_probe.gd")
const EngineScript = preload("res://scripts/run_engine.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
var failed: bool = false
var viewport: SubViewport
var view: Control
var requests: int = 0
var leaves: int = 0

func _initialize() -> void:
	Parallel.apply_from_environment()
	var proof_script: Script = ProofProbe
	check(proof_script.can_instantiate(), "Updated renderer proof script parses")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	view = View.new()
	viewport.add_child(view)
	view.size = Vector2(viewport.size)
	var state: Dictionary = Suite.fixture()
	view.call("configure", state, true)
	view.graft_requested.connect(func(_recipient: String, _donor: String, _source: int, _target: int) -> void: requests += 1)
	view.leave_requested.connect(func() -> void: leaves += 1)
	await settle()
	check_header()
	check_dialogue(true)
	view.call("focus_first")
	check(view.find_child("GraftBrowse", true, false).has_focus(), "Entry begins on Browse equipment")
	await action(&"ui_focus_next")
	check(view.find_child("GraftSkip", true, false).has_focus(), "Entry focus order retains Browse then Skip")
	await action(&"ui_accept")
	check(leaves == 1, "Keyboard activates quiet entry Skip")
	view.call("begin_work")
	await settle()
	check(view.find_child("GraftPreviewThread", true, false) == null, "Empty workbench has no transfer thread")
	check(not bool(view.call("semantic_snapshot")["can_commit"]), "Empty workbench cannot graft")
	view.call("select_donor", "patched_cloak")
	view.call("select_recipient", "undertaker_plate")
	await settle()
	check_card_bounds()
	check_equipment_names()
	check(view.find_child("ChangeSacrifice", true, false) != null and view.find_child("ChangeRecipient", true, false) != null, "Both selected pieces expose Change piece")
	view.call("select_source", 1)
	check(view.find_child("GraftPreviewThread", true, false) == null, "Source-only selection has no preview thread")
	view.call("select_target", 1)
	await settle()
	check(bool(view.call("semantic_snapshot")["can_commit"]), "Source and replacement enable the Graft action")
	check(bool(view.find_child("GraftCommit", true, false).get("primary")), "Graft owns primary action halo")
	check_preview()
	var thread: Control = view.find_child("GraftPreviewThread", true, false) as Control
	var before: Vector2 = thread.call("point", 0.25)
	thread.call("_process", 1.0)
	check(thread.call("point", 0.25) == before and not thread.is_processing(), "Reduced motion keeps the dashed thread still")
	view.call("configure", state, false)
	thread = view.find_child("GraftPreviewThread", true, false) as Control
	before = thread.call("point", 0.25)
	thread.call("_process", 1.0)
	check(thread.call("point", 0.25) != before and thread.is_processing(), "Normal preview has gentle idle sway")
	view.call("configure", state, true)
	(view.find_child("SourceCard_1", true, false) as Button).grab_focus()
	check(view.call("inspect_focused"), "Selected cards retain optional exact inspection")
	await settle()
	view.call("request_leave")
	check(viewport.gui_get_focus_owner() == view.find_child("SourceCard_1", true, false), "Inspection Back restores source focus")
	# The original well remains the navigation destination for Change piece.
	(view.find_child("ChooseSacrifice", true, false) as Button).grab_focus()
	await action(&"ui_accept")
	check(view.call("semantic_snapshot")["picker_role"] == "donor", "Keyboard still opens the sacrifice picker")
	check_header()
	view.call("request_leave")
	check(viewport.gui_get_focus_owner() == view.find_child("ChooseSacrifice", true, false), "Picker Back restores the equipment well")
	var commit: Button = view.find_child("GraftCommit", true, false) as Button
	commit.grab_focus()
	await joy_accept()
	check(requests == 1 and bool(view.call("semantic_snapshot")["busy"]), "Controller activation emits exactly one graft request")
	view.call("_request_graft")
	check(requests == 1, "Busy ritual rejects repeated requests")
	view.call("reject", "Retry the graft.")
	check(not bool(view.call("semantic_snapshot")["busy"]) and bool(view.call("semantic_snapshot")["can_commit"]), "Rejection retains the preview and allows retry")
	var engine := EngineScript.new()
	var result: Dictionary = engine.graft_equipment(state, "undertaker_plate", "patched_cloak", 1, 1)
	await view.call("present_result", result)
	await settle()
	check_header()
	check(bool(view.call("semantic_snapshot")["used"]) and view.find_child("GraftContinue", true, false) != null, "Reduced-motion ritual reaches the existing result")
	check(view.find_child("GraftPreviewThread", true, false) == null, "Result clears preview thread")
	state["seed"] = int(state["seed"]) + 1
	view.call("configure", state, true)
	view.call("begin_work")
	view.call("select_donor", "training_sword")
	view.call("select_recipient", "iron_cleaver")
	view.call("select_source", 0)
	view.call("select_target", 2)
	await settle()
	check_card_bounds()
	check_equipment_names()
	check(view.find_child("TargetCard_2", true, false) != null, "Three-card equipment retains every selection")
	check_thread_route()
	view.call("configure", state, false)
	result = engine.graft_equipment(state, "iron_cleaver", "training_sword", 0, 2)
	await view.call("present_result", result)
	await settle()
	check(bool(view.call("semantic_snapshot")["used"]) and view.find_child("ResultCard_2", true, false) != null, "Normal ritual retains three-card equipment and reaches result")
	var no_pair: Dictionary = Suite.fixture(int(state["seed"]) + 1)
	no_pair["equipment_inventory"] = []
	view.call("configure", no_pair, true)
	await settle()
	check_dialogue(false)
	check_header()
	view.call("focus_first")
	check(view.find_child("GraftSkip", true, false).has_focus(), "No-pair dialogue focuses its quiet Skip")
	view.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	for node: Node in root.get_node("CursorFeedback").find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	await process_frame
	print("GRAFTWRIGHT ATELIER TEST: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func check_header() -> void:
	var header: Control = view.find_child("AtelierHeader", true, false) as Control
	check(header != null and header.is_visible_in_tree(), "Common atelier header stays visible")
	if header == null: return
	check(header.position.x == 610 and header.size.x == 1260, "Common header spans the work area")
	var title := header.get_node("AtelierTitle") as Label
	check(title.text == "Graftwright" and title.get_theme_font("font") == Typography.display_font(), "Exact title uses Display")
	check(title.get_theme_font_size("font_size") == 52 and title.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Title uses brief size and gold")
	check((header.get_node("AtelierEyebrow") as Label).text == "THE GRAFTWRIGHT'S ATELIER", "Exact atelier eyebrow")
	if view.find_child("EquipmentPicker", true, false) != null:
		check(header.z_index > (view.find_child("EquipmentPicker", true, false) as Control).z_index, "Header stays above picker scrim")

func check_dialogue(pair: bool) -> void:
	var panel: Control = view.find_child("GraftwrightDialogue", true, false) as Control
	check(panel != null and panel.size == Vector2(1160, 300), "Entry uses the compact atelier panel")
	if panel == null: return
	check(panel.get_child(0) is NinePatchRect, "Entry reuses the painted atelier workmat")
	var body := panel.get_node("GraftwrightDialogueBody") as Label
	check(body.get_line_count() * body.get_line_height() <= body.size.y, "Exact dialogue fits without clipping")
	check(body.get_theme_font("font") == Typography.text_font() and body.get_theme_font_size("font_size") == 25, "Dialogue uses 25px text font")
	check(body.text.begins_with("Lay down two pieces" if pair else "My needle needs two pieces"), "Both dialogue variants retain exact rules")
	check((panel.get_node("GraftwrightDialogueSpeaker") as Control).position.y == 46, "Speaker has the extra 14px top padding")
	check((panel.get_node("GraftSkip") as Button).get("kind") == "quiet_plate", "Skip has a quiet plate at rest")
	check((panel.find_child("GraftBrowse", true, false) != null) == pair, "Browse remains available only with a pair")
	for node: Node in panel.find_children("*", "Button", true, false):
		check(Rect2(Vector2.ZERO, panel.size).encloses((node as Control).get_rect()), "Dialogue actions fit their panel")

func check_card_bounds() -> void:
	for prefix: String in ["SourceCard_", "TargetCard_"]:
		var panel := Rect2(610 if prefix == "SourceCard_" else 1370, 190, 500, 650)
		for node: Node in view.find_children(prefix + "*", "Button", true, false):
			check(panel.grow(-24).encloses((node as Control).get_rect()), "All cards fit the 500px panels")

func check_equipment_names() -> void:
	for role: String in ["Sacrifice", "Improve"]:
		var label: Label = view.find_child(role + "Name", true, false) as Label
		var fate: Label = view.find_child(role + "Fate", true, false) as Label
		var change: Control = view.find_child("ChangeSacrifice" if role == "Sacrifice" else "ChangeRecipient", true, false) as Control
		check(label != null and label.get_line_count() * label.get_line_height() <= label.size.y, "Equipment name fits above its fate: " + role)
		if label == null or fate == null or change == null: return
		check(label.position.x == fate.position.x and label.position.x == change.position.x and fate.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Equipment stack shares one left edge")
		check(is_equal_approx(fate.position.y - label.get_rect().end.y, 8) and is_equal_approx(change.position.y - fate.get_rect().end.y, 8), "Equipment name, fate and Change piece have 8px gaps")

func check_preview() -> void:
	var thread: Control = view.find_child("GraftPreviewThread", true, false) as Control
	check(thread != null, "Complete choices show a thread")
	if thread == null: return
	check(thread.call("point", 0.0) == thread.get("origin") and thread.call("point", 1.0).is_equal_approx(thread.get("destination")), "Thread meets the chosen card tops")
	var needle: Vector2 = thread.call("point", 0.5)
	check(needle.x == 1240 and needle.y < 200, "Needle sits above the panel header bands")
	check_thread_route()
	var summary := view.find_child("GraftSummary", true, false) as Control
	check(summary != null and summary.position.x > 1110 and summary.get_rect().end.x < 1370, "Summary sits in the gap")
	if summary != null:
		check(summary.position.y == 600 and is_equal_approx(summary.get_rect().get_center().x, 1240), "Summary is raised and centered in the gap")
		check((summary.get_node("CarriedName") as Label).text == "Shadow Step" and (summary.get_node("ReplacedName") as Label).text == "Coffin Brace", "Summary has carried and replaced names")
	var strip := view.find_child("ReplacementStrip", true, false) as Label
	check(strip.text == "Coffin Brace → Shadow Step" and not strip.visible, "Legacy comparison remains readable to tests")
	var labels := PackedStringArray()
	for node: Node in view.find_children("*", "Label", true, false): labels.append((node as Label).text)
	check(labels.has("LOST") and labels.has("CARRIED") and labels.has("KEPT") and labels.has("REPLACED"), "Every selected or unchosen card has its fate")

func check_thread_route() -> void:
	var thread: Control = view.find_child("GraftPreviewThread", true, false) as Control
	check(thread != null, "Selected cards have a preview thread")
	if thread == null: return
	var snapshot: Dictionary = view.call("semantic_snapshot")
	var source: Control = view.find_child("SourceCard_%d" % int(snapshot["source_index"]), true, false) as Control
	var target: Control = view.find_child("TargetCard_%d" % int(snapshot["target_index"]), true, false) as Control
	var origin: Vector2 = thread.get("origin")
	var destination: Vector2 = thread.get("destination")
	check(origin == source.position + Vector2(source.size.x * 0.5, 0) and destination == target.position + Vector2(target.size.x * 0.5, 0), "Thread endpoints follow each chosen card's top edge")
	check(not bool(thread.call("segment_occluded", origin, origin - Vector2(0, 2))) and not bool(thread.call("segment_occluded", destination - Vector2(0, 2), destination)), "Thread remains visible at both card edges")
	check(is_equal_approx((thread.call("point", 0.125) as Vector2).x, origin.x) and is_equal_approx((thread.call("point", 0.875) as Vector2).x, destination.x), "Thread rises and descends vertically")
	check((thread.call("point", 0.25) as Vector2).y <= 204 and (thread.call("point", 0.75) as Vector2).y <= 204, "Thread reaches above both panel titles before crossing")
	for node: Node in view.find_children("*", "Label", true, false):
		var label := node as Label
		if label.get_parent() != view.get("_content") and label.get_parent() != view.get("_sacrifice_content"): continue
		if label.position.y < 235 or label.position.y >= 480: continue
		check(label.z_index > thread.z_index, "Panel text draws above the thread")
		check(thread.call("segment_occluded", label.get_rect().get_center(), label.get_rect().get_center()), "Thread is masked out of the full text area")
	for name: String in ["ChooseSacrifice", "ChooseRecipient"]:
		check((view.find_child(name, true, false) as Control).z_index > thread.z_index, "Equipment wells draw above the preview thread")

func settle() -> void:
	await process_frame
	await process_frame

func action(action_name: StringName) -> void:
	for down: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action_name
		event.pressed = down
		viewport.push_input(event, true)
		await process_frame

func joy_accept() -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		viewport.push_input(event, true)
		await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
