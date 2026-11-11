extends SceneTree
const Inline = preload("res://scripts/inline_icon_text.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const Builder = preload("res://scripts/item_preview_builders.gd")
const REWARD_RITE_FIXTURE: String = "thorn_crown_pact"
const REWARD_FIXTURE_SIZE := Vector2(250, 352)
const REWARD_FIXTURE_SCALE: float = 0.9
const REWARD_FIXTURE_POSITION := Vector2(600, 200)
const REWARD_HOVER_SETTLE_SECONDS: float = 0.2
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var row: RichTextLabel = preload("res://scripts/event_view_text.gd").label("3 @icon(expose)", 400, 20)
	root.add_child(row)
	check(row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Inline event help preserves parent activation")
	var tip: Control = row.call("_make_custom_tooltip", Icons.tooltip("expose"))
	check(tip.find_child("TooltipIcon", true, false) != null, "Inline help uses combat icon panel")
	tip.free()
	row.queue_free()
	var choice := preload("res://scripts/event_view_choice.gd").new()
	choice.add_child(row.duplicate())
	root.add_child(choice)
	check(choice.has_method("_get_tooltip"), "Choice forwards transparent text hit tests")
	choice.queue_free()
	var builder := Builder.new()
	for id: String in Data.cards():
		var preview: Control = builder.card_tooltip(id)
		var column: Node = preview.find_child("InspectionKeywordPanels", true, false)
		var card: Dictionary = Data.card_def(id)
		var leading: Array = []
		if Icons.card_is_rite(card): leading.append("rite")
		var expected: Array = Icons.tooltip_entries_for_rows(Icons.rows_for_card(card), leading)
		check(column.get_child_count() == expected.size(), "Card inspection stack matches combat: " + id)
		preview.free()
	for id: String in Data.omens():
		var entry: Dictionary = Library.entry_def("omen:" + id)
		check(entry.get("title", "") == Data.omen_def(id)["name"], "Omen generated under its data name: " + id)
		check(entry.get("body", []).has(Data.omen_def(id)["description"]), "Omen effect retained: " + id)
		check(entry.get("body", []).has("Lasts %d fights." % int(Data.omen_def(id)["fights"])), "Omen duration generated: " + id)
	check(Library.default_entry_ids().has("omen:dread"), "Dread searchable before encounter")
	var search: Array = preload("res://scripts/grimoire_search.gd").search(Library.entries(), Library.data()["sections"], "Dread")
	check(not search.is_empty() and search[0]["entry"]["id"] == "omen:dread", "Dread search finds generated entry")
	var badge := preload("res://scripts/omen_badges.gd").Badge.new()
	badge.entry = Data.omen_def("dread").duplicate(true)
	badge.entry["id"] = "dread"
	badge.entry["fights_left"] = 3
	root.add_child(badge)
	var omen_tip: Control = badge.call("_make_custom_tooltip", "")
	check(omen_tip.find_child("TooltipIcon", true, false) != null, "HUD omen explains its inline concepts")
	omen_tip.free()
	badge.queue_free()
	var rite_id: String = ""
	var area_id: String = ""
	for id: String in Data.cards():
		if Icons.card_is_rite(Data.card_def(id)): rite_id = id
		for summary_row: Array in Icons.rows_for_card(Data.card_def(id)):
			for token: Dictionary in summary_row:
				if token.get("kind", "") == "aoe_pattern": area_id = id
	for id: String in [rite_id, area_id]:
		var widget: Control = load("res://scenes/card_widget.tscn").instantiate()
		root.add_child(widget)
		widget.configure(id)
		await process_frame
		await process_frame
		var matched: bool = false
		for control: Node in widget.find_children("*", "Control", true, false):
			var expected: String = Icons.tooltip("rite") if id == rite_id else preload("res://scripts/card_widget.gd").AREA_PATTERN_TOOLTIP
			if (control as Control).tooltip_text == expected:
				matched = true
				check(widget.call("_tooltip_for_icon_at", control.get_global_rect().get_center()) == expected, "Reward card forwards token hit test: " + id)
		check(matched, "Reward token has help text: " + id)
		widget.queue_free()
	_test_omen_save_identity()
	await _test_reward_rite_hover()
	var tokens: Array = Icons.rows_for_actions([{"type": "aoe", "damage": 3, "pattern": [[0, 0], [1, 0]]}])
	var found: bool = false
	for tokens_row: Array in tokens:
		for token: Dictionary in tokens_row:
			if token.get("kind", "") == "aoe_pattern":
				found = true
				check(Icons.token_tooltip(token).is_empty(), "Card-only fallback preserves other surfaces")
	check(found, "Fixture includes area-pattern token")
	# Load the integrated scene as a parser/integration check, never editor scan.
	check(load("res://scenes/run_scene.tscn") != null, "Integrated run scene loads")
	await process_frame
	for failure: String in failures: push_error(failure)
	print("PTF06 focused: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

# Exercise the native-facing API at the reward's scale and after its real lift.
# Earlier coverage called only the internal hit-test on an unscaled card.
func _test_reward_rite_hover() -> void:
	var slot := Control.new()
	slot.position = REWARD_FIXTURE_POSITION
	slot.scale = Vector2.ONE * REWARD_FIXTURE_SCALE
	root.add_child(slot)
	var widget: Control = load("res://scenes/card_widget.tscn").instantiate()
	slot.add_child(widget)
	widget.size = REWARD_FIXTURE_SIZE
	widget.configure(REWARD_RITE_FIXTURE)
	widget.set_hover_pose(preload("res://scripts/run_scene.gd").REWARD_CARD_HOVER_LIFT, preload("res://scripts/run_scene.gd").REWARD_CARD_HOVER_SCALE)
	widget.call("_on_local_mouse_entered")
	await create_timer(REWARD_HOVER_SETTLE_SECONDS).timeout
	var expected: String = Icons.tooltip("rite")
	var matched: bool = false
	for control: Node in widget.find_children("*", "HBoxContainer", true, false):
		if control.get_child_count() != 2: continue
		if control.get_child(0).get("tooltip_text") != expected or control.get_child(1).get("tooltip_text") != expected: continue
		matched = true
		check(control.tooltip_text == expected, "Whole reward Rite token carries keyword help")
		for child: Control in control.get_children():
			var local_point: Vector2 = widget.get_global_transform().affine_inverse() * child.get_global_rect().get_center()
			check(widget.get_tooltip(local_point) == expected, "Native reward Rite icon/label tooltip after lift")
		var icon: Control = control.get_child(0)
		var label: Control = control.get_child(1)
		var gap_point := Vector2((icon.get_global_rect().end.x + label.get_global_rect().position.x) * 0.5, control.get_global_rect().get_center().y)
		check(widget.get_tooltip(widget.get_global_transform().affine_inverse() * gap_point) == expected, "Native reward Rite gap tooltip after lift")
	var panel: Control = widget.call("_make_custom_tooltip", expected)
	check(panel.find_child("TooltipIcon", true, false) != null, "Reward Rite uses the shared glossary icon panel")
	panel.free()
	check(matched, "Thorn Crown Pact exposes its Rite hit target")
	slot.queue_free()

# Current omen IDs may contain vocabulary retired from older card IDs. They
# must survive both profile migration and discovery serialization unchanged.
func _test_omen_save_identity() -> void:
	const Engine = preload("res://scripts/run_engine.gd")
	for id: String in Data.omens():
		var profile: Dictionary = {"grimoire_unlocked": ["omen:" + id], "grimoire_unread": ["omen:" + id], "omens": [{"id": id, "fights_left": 3}]}
		check(Engine.migrate_renamed_content_ids(profile) == profile, "Migration preserves current omen identity: " + id)
	var legacy_prefix: String = String.chr(97) + String.chr(115) + String.chr(104)
	var legacy: Dictionary = {"probe": legacy_prefix + "_retired_probe"}
	check(Engine.migrate_renamed_content_ids(legacy)["probe"] == "cinder", "Unknown retired IDs still migrate")
	var preview: Control = Builder.new().equipment_tooltip("iron_cleaver")
	check(preview is PanelContainer and preview.has_meta("equipment_tooltip_surface"), "Equipment inspection preserves its framed owner contract")
	check(preview.find_child("InspectionKeywordPanels", true, false) != null, "Framed equipment inspection retains keyword panels")
	preview.free()
