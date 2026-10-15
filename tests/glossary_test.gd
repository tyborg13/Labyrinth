extends SceneTree

const Fixture = preload("res://tests/glossary_fixture.gd")
const Glossary = preload("res://scripts/glossary.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const GameData = preload("res://scripts/game_data.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const TooltipSuite = preload("res://tests/suites/tooltip_consistency_suite.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OWNER_POSITION := Vector2(1800, 80)
const OWNER_SIZE := Vector2(60, 60)
const CHOICE_TEST_TOP: float = 200.0
const CHOICE_TEST_SIZE := Vector2(100, 100)
const CHOICE_TEST_LEFTS: Array = [400.0, 800.0, 1200.0]
const CHOICE_FALLBACK_TOP: float = 600.0
const CHOICE_TALL_PANEL_HEIGHT: float = 200.0
var _failures: Array[String]
var _checks: int = 0
var _tokens: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://glossary_progression.json")
	ProgressionStore.set_run_storage_path("user://glossary_run.save")
	SettingsStore.set_storage_path("user://glossary_settings.json")
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	_test_data()
	TooltipSuite.run(_expect)
	_test_inline_hover()
	await _test_stack()
	await _test_choice_placement()
	await _test_live_relic_hooks()
	for failure: String in _failures:
		push_error(failure)
	print("GLOSSARY COVERAGE: %d entries, %d tokens checked" % [Glossary.all_entries().size(), _tokens])
	print("GLOSSARY TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_data() -> void:
	var ids: Dictionary = {}
	var todos: Array[String]
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string(Glossary.DATA_PATH)) as Array
	_expect(raw.size() == Glossary.all_entries().size(), "Loader does not conceal duplicate ids")
	for value: Variant in Glossary.all_entries():
		var entry: Dictionary = value as Dictionary
		var id: String = str(entry.get("id", ""))
		_expect(not id.is_empty() and not ids.has(id), "Unique glossary id: " + id)
		ids[id] = true
		for field: String in ["name", "icon", "definition", "aliases"]:
			_expect(entry.has(field), id + " has " + field)
		for alias: String in entry.get("aliases", []):
			_expect(str(Glossary.lookup(alias).get("id", "")) == id, "Alias resolves to its canonical concept: " + alias)
		var icon: String = str(entry.get("icon", ""))
		_expect(FileAccess.file_exists(icon) if icon.begins_with("res://") else not ActionIcons.icon_path(icon).is_empty(), "Approved icon exists: " + id)
		if str(entry.get("definition", "")).begins_with("TODO_DESIGN_"):
			todos.append(str(entry["definition"]))
		_check_text(entry.get("definition", ""))
	print("GLOSSARY TODO_DESIGN: %d [%s]" % [todos.size(), ", ".join(todos)])
	print("GLOSSARY PROSE TODO_DESIGN: TODO_DESIGN_GLOSSARY_CONSUME_PROSE (unmarked Consume needs an explicit concept token)")
	_expect(Glossary.lookup("skill_point")["name"] == "Skill Point", "Skill Point uses director's approved name")
	_expect(Glossary.definition("skill_point") == "Earned as you level up. Spend them on skills in the Character menu.", "Skill Point uses director's approved definition")
	_expect(Glossary.lookup("Skill Points")["id"] == "skill_point", "Existing plural resource label remains an alias")
	for key: String in ActionIcons.all_icon_keys():
		_expect(not Glossary.lookup(key).is_empty(), "Registry keyword resolves: " + key)
	# The frozen pre-change copy verifies migration independently of runtime data.
	var before: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/glossary_card_copy_before.json")) as Array
	for entry: Dictionary in before:
		_expect(Glossary.definition(str(entry["id"])) == str(entry["definition"]), "Verbatim pre-change definition: " + str(entry["id"]))
		if str(entry["id"]) != "dive":
			_expect(ActionIcons.description(str(entry["id"])) == str(entry["definition"]), "Card/nested token reads glossary: " + str(entry["id"]))
	# Prove the lookup is live, not still backed by the legacy dictionary.
	var saved: Dictionary = Glossary._entries["follow_up"]
	Glossary._entries["follow_up"] = saved.duplicate(true)
	Glossary._entries["follow_up"]["definition"] = "debug glossary source sentinel"
	_expect(ActionIcons.description("follow_up") == "debug glossary source sentinel", "Keyword text comes from glossary")
	Glossary._entries["follow_up"] = saved
	for path: String in ["res://data/cards.json", "res://data/relics.json", "res://data/skills.json", "res://data/enemies.json", "res://data/grimoire.json"]:
		_walk(JSON.parse_string(FileAccess.get_file_as_string(path)))
	for card_id: String in GameData.cards():
		var card: Dictionary = GameData.card_def(card_id)
		for row: Array in ActionIcons.rows_for_card(card):
			for token: Dictionary in row:
				var key: String = str(token.get("icon", ""))
				if key == "aoe_pattern": key = "aoe"
				if not key.is_empty():
					_expect(not Glossary.lookup(key).is_empty(), card_id + " rendered token resolves: " + key)
				_check_text(str(token.get("tooltip", "")))
	# Status/intent copy is generated by scripts as well as JSON; scan literal
	# @icon tokens throughout production scripts, including all badge helpers.
	_scan_scripts("res://scripts")
	_expect(str(Glossary.lookup("Frozen").get("id")) == "freeze", "Existing status alias resolves")
	_expect(Glossary.lookup("not_a_concept").is_empty(), "Unknown lookup is empty")
	_expect(Glossary.ids_in_text("@icon(empower) Health Cost; @icon(empower) Follow-up; @icon(health)") == ["empower", "health_cost", "follow_up", "health"], "Token and keyword first appearance with overlap/dedup")
	_expect(Glossary.ids_in_text("[color=red]Stagger[/color] misfire timekeeper") == ["stagger"], "Word boundaries and BBCode")
	_expect(Glossary.ids_in_text("Fire Ice @icon(surface_fire) @icon(element_ice)") == ["surface_fire", "element_ice"], "Ambiguous names never alias elements to surfaces")
	_expect(Glossary.ids_in_text("Each time you swap targets, consume ground before your next attack.").is_empty(), "Ordinary prose does not invent Time, Swap or item Consume mechanics")
	_expect(Glossary.ids_in_text("Consume @icon(surface_rubble)") == ["surface_rubble"], "Ambiguous surface removal never gets the item Consume definition")
	_expect(Glossary.ids_in_text("Time @icon(consume) Swap") == ["time", "consume", "swap"], "Authored keywords and explicit tokens still resolve")
	var many: String = "@icon(health) @icon(block) @icon(stoneskin) @icon(time) @icon(move) @icon(draw) @icon(empower)"
	_expect(Glossary.ids_in_text(many, Glossary.MAX_RELIC_PANELS) == ["health", "block", "stoneskin", "time", "move", "draw"], "Six panels in appearance order; no more indicator")

func _test_inline_hover() -> void:
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	InlineIconText.apply_to(label, "@icon(stagger)")
	_expect(label.has_method("_make_custom_tooltip"), "Hoverable inline rules use the shared panel")
	var panel: Control = label.call("_make_custom_tooltip", ActionIcons.tooltip("stagger")) as Control
	_expect(panel is PanelContainer and panel.has_meta("tooltip_surface"), "Inline tooltip uses UiTooltipPanel")
	panel.free()
	label.free()
	label = RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InlineIconText.apply_to(label, "@icon(stagger)")
	_expect(label.get_script() == null, "Noninteractive inline text keeps its input path")
	label.free()

func _walk(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in (value as Dictionary).values(): _walk(child)
	elif value is Array:
		for child: Variant in value: _walk(child)
	elif value is String:
		_check_text(value)

func _check_text(text: String) -> void:
	var literal := RegEx.new()
	literal.compile("@icon\\(([a-z_]+)\\)")
	for token: RegExMatch in literal.search_all(text):
		_tokens += 1
		_expect(not Glossary.lookup(token.get_string(1)).is_empty(), "Text token resolves: " + token.get_string(1))

func _scan_scripts(path: String) -> void:
	var dir := DirAccess.open(path)
	for directory: String in dir.get_directories():
		_scan_scripts(path.path_join(directory))
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(path.path_join(file))
		_check_text(source)
		if source.contains("func player_badges") or source.contains("func badges") or source.contains("func status_badges") or source.contains("func _unit_status_badges"):
			var icons := RegEx.new()
			icons.compile('"icon"\\s*:\\s*"([a-z_]+)"')
			for token: RegExMatch in icons.search_all(source):
				_tokens += 1
				_expect(not Glossary.lookup(token.get_string(1)).is_empty(), "Status badge icon resolves: " + file + ":" + token.get_string(1))

func _test_stack() -> void:
	var stack := Stack.new()
	root.add_child(stack)
	var owner := Stack.RelicOwner.new()
	owner.position = OWNER_POSITION
	owner.size = OWNER_SIZE
	owner.focus_mode = Control.FOCUS_ALL
	root.add_child(owner)
	await _settle()
	var relic: Dictionary = GameData.relic_def("iron_lung")
	owner.tooltip_text = "%s\n%s\nUsed this combat." % [relic["name"], relic["description"]]
	stack.bind_relic(owner, relic)
	owner.mouse_entered.emit()
	await _settle()
	_expect(stack.visible and stack.entry_icon_keys() == ["relic", "health_cost", "empower", "stoneskin", "health"], "Hover displays relic plus deduplicated definitions")
	_expect(str(stack._entries[0]["description"]).ends_with("Used this combat."), "Live badge details preserved")
	_expect(owner.get_tooltip(Vector2.ZERO).is_empty() and not owner.tooltip_text.is_empty(), "Native popup suppressed without losing controller discovery")
	_expect(is_equal_approx(stack.get_global_rect().end.x, VIEWPORT_SIZE.x - Stack.SAFE_MARGIN), "Right-edge owned stack clamps to screen")
	_expect(is_equal_approx(stack.position.y, owner.get_global_rect().end.y + Stack.OWNED_RELIC_GAP), "Owned stack starts eight pixels below icon")
	_expect(not stack.get_global_rect().intersects(owner.get_global_rect()), "Owned stack does not overlap its icon")
	_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(stack.get_global_rect()), "Stack fits viewport")
	owner.grab_focus()
	owner.mouse_exited.emit()
	_expect(stack.visible, "Focus persists after pointer leaves")
	owner.release_focus()
	_expect(not stack.visible, "Last interaction exit hides stack")
	owner.grab_focus()
	var second := Stack.RelicOwner.new()
	second.focus_mode = Control.FOCUS_ALL
	root.add_child(second)
	stack.bind_relic(second, GameData.relic_def("ember_lens"))
	second.mouse_entered.emit()
	_expect(stack._follow_target == second, "Hover temporarily replaces the focused owner's stack")
	second.mouse_exited.emit()
	_expect(stack._follow_target == owner, "Pointer exit restores the still-focused relic")
	second.queue_free()
	owner.release_focus()
	owner.tooltip_text = ""
	stack.show_relic(owner, {"name": relic["name"], "description": "@icon(health) @icon(block) @icon(stoneskin) @icon(time) @icon(move) @icon(draw) @icon(empower)"})
	_expect(stack.entry_icon_keys() == ["relic", "health", "block", "stoneskin", "time", "move", "draw"], "Relic shows first six concepts without a more panel")
	var bbcode_entries: Array = [{"icon": "health", "texture": ActionIcons.icon_texture("health"), "title": "Health", "description": "[b]Health @icon(health)[/b]"}]
	stack.show_for(owner, bbcode_entries, true)
	await _settle()
	var rich_nodes: Array[Node] = stack.find_children("*", "RichTextLabel", true, false)
	_expect(rich_nodes.size() == 1, "BBCode definition uses one shared rich body")
	if not rich_nodes.is_empty():
		var rich: RichTextLabel = rich_nodes[0] as RichTextLabel
		_expect(not rich.get_parsed_text().contains("[b]") and not rich.get_parsed_text().contains("@icon"), "Definition renders BBCode and inline image markup")
	for id: String in GameData.relics():
		# Test authored description rather than the live-counter fixture above.
		owner.tooltip_text = ""
		stack.show_relic(owner, GameData.relic_def(id))
		await _settle()
		_expect(stack.entry_count() <= 7, "Relic has at most six glossary panels: " + id)
		_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(stack.get_global_rect()), "Every relic stack fits: " + id + " " + str(stack.get_global_rect()))
	owner.hide()
	await _settle()
	_expect(not stack.visible, "Hidden owner closes stack")
	owner.queue_free()
	stack.queue_free()
	await _settle()

func _test_choice_placement() -> void:
	var row := Control.new()
	root.add_child(row)
	var stack := Stack.new()
	root.add_child(stack)
	var choices: Array[Control]
	for left: float in CHOICE_TEST_LEFTS:
		var choice := Stack.RelicOwner.new()
		choice.position = Vector2(left, CHOICE_TEST_TOP)
		choice.size = CHOICE_TEST_SIZE
		row.add_child(choice)
		stack.bind_relic(choice, {"name": "debug owner title", "description": "@icon(health)"}, row)
		choices.append(choice)
	for index: int in range(choices.size()):
		var choice: Control = choices[index]
		choice.mouse_entered.emit()
		await _settle()
		var bounds: Rect2 = stack.get_global_rect()
		_expect(stack.entry_icon_keys() == ["health"], "Choice omits redundant owner name and description")
		_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(bounds), "Choice stack fits screen")
		for other: Control in choices:
			_expect(not bounds.intersects(other.get_global_rect()), "Choice stack avoids every card")
		if index == 0:
			_expect(is_equal_approx(bounds.end.x, choice.position.x - Stack.RELIC_CHOICE_GAP), "Left choice uses outer side")
			_expect(is_equal_approx(bounds.position.y, choice.position.y), "Left choice top aligns")
		elif index == 2:
			_expect(is_equal_approx(bounds.position.x, choice.get_global_rect().end.x + Stack.RELIC_CHOICE_GAP), "Right choice uses outer side")
			_expect(is_equal_approx(bounds.position.y, choice.position.y), "Right choice top aligns")
		else:
			_expect(is_equal_approx(bounds.position.y, choice.get_global_rect().end.y + Stack.RELIC_CHOICE_GAP), "Middle choice goes below row")
			_expect(is_equal_approx(bounds.get_center().x, choice.get_global_rect().get_center().x), "Middle choice centers under owner")
		choice.mouse_exited.emit()
	var edge: Control = choices.front()
	edge.mouse_entered.emit()
	await _settle()
	edge.position.x = stack.size.x + Stack.RELIC_CHOICE_SIDE_CLEARANCE
	await _settle()
	_expect(is_equal_approx(stack.get_global_rect().end.x, edge.position.x - Stack.RELIC_CHOICE_GAP), "Exactly panel width plus 24 pixels admits outer placement")
	edge.position.x -= 1.0
	await _settle()
	_expect(is_equal_approx(stack.position.y, edge.get_global_rect().end.y + Stack.RELIC_CHOICE_GAP), "Insufficient outer room falls below row")
	_expect(not stack.get_global_rect().intersects(edge.get_global_rect()), "Outer fallback avoids owner")
	# Force differently sized rows to prove the four-column fallback and its
	# return to a single outer column; these dimensions are proof-only.
	for choice: Control in choices:
		choice.position.y = CHOICE_FALLBACK_TOP
	var middle: Control = choices[1]
	stack.show_relic(middle, {"description": "@icon(health) @icon(block) @icon(stoneskin) @icon(time) @icon(move) @icon(draw)"})
	var panels: Array[Node] = stack.find_children("CardFocusTooltip_*", "PanelContainer", true, false)
	for index: int in [0, 3]:
		(panels[index] as Control).custom_minimum_size.y = CHOICE_TALL_PANEL_HEIGHT
	await _settle()
	_expect(int(stack.get_meta("glossary_choice_columns")) == 4, "Tall three-column flow falls back to four columns")
	_expect(stack.get_global_rect().end.y <= VIEWPORT_SIZE.y - Stack.RELIC_CHOICE_SCREEN_MARGIN, "Four-column fallback respects bottom margin")
	_expect(is_equal_approx((panels[0] as Control).position.y, (panels[3] as Control).position.y), "First four panels remain in first row")
	_expect((panels[4] as Control).position.y > (panels[3] as Control).position.y, "Remaining panels move to second row")
	row.move_child(middle, 0)
	middle.position.y = CHOICE_TEST_TOP
	await _settle()
	_expect(int(stack.get_meta("glossary_choice_columns")) == 1, "Flow can return to fitting outer column")
	_expect(is_equal_approx(stack.size.x, (panels[0] as Control).size.x), "Outer column releases previous flow width")
	row.queue_free()
	stack.queue_free()
	await _settle()

func _test_live_relic_hooks() -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	var state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	state["relics"] = ["iron_lung"]
	state["mode"] = "room"
	scene.set("_run_state", state)
	scene.call("_refresh_relic_bar")
	var badge: Control = scene.call("_relic_frame_for_id", "iron_lung") as Control
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	_expect(badge != null, "Production owned badge exists")
	if badge != null:
		badge.mouse_entered.emit()
		_expect(stack.visible and stack.entry_count() == 5, "Production owned hover wired")
		badge.mouse_exited.emit()
		var candidates: Array = scene.call("_controller_header_focus_controls")
		_expect(candidates.has(badge), "Owned relic remains discoverable by controller")
		# Controller calls grab_focus through its existing candidate routing.
		scene.call("_controller_set_focus_candidate", {"kind": "relic", "key": "glossary-test", "control": badge}, false)
		_expect(badge.has_focus() and stack.visible, "Production controller focus opens same stack")
		badge.release_focus()
	state = Fixture.treasure_state()
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	for _step: int in range(Fixture.REVEAL_STEPS):
		if not bool(scene.get("_treasure_reveal_active")): break
		await create_timer(Fixture.REVEAL_POLL_SECONDS).timeout
	await _settle()
	var bar: Control = scene.get("_relic_choice_bar") as Control
	var choice: Control = bar.get_node_or_null("RelicChoice_iron_lung") as Control
	_expect(choice != null, "Production relic choice exists after reveal")
	if choice == null:
		scene.queue_free()
		await _settle()
		return
	choice.mouse_entered.emit()
	_expect(stack.visible and stack.entry_count() == 4, "Production choice hover shows only glossary panels")
	choice.mouse_exited.emit()
	choice.grab_focus()
	_expect(choice.has_focus() and stack.visible, "Production choice keyboard focus wired")
	scene.queue_free()
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
