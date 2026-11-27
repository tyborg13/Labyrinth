extends "res://tests/pre_battle_fixture.gd"

const F = preload("res://tools/txt42/fixture.gd")
const Rewards = preload("res://tools/txt42/reward_witnesses.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SplitFixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Hover = preload("res://tools/txt43/native_hover.gd")
const PatternText = preload("res://scripts/pattern_text.gd")
const Eclipse = preload("res://tools/txt42/enemy_witnesses.gd")
const HOVER_SECONDS: float = 1.5
const TREASURE_READY_SECONDS: float = 5.0
const REWARD_READY_SECONDS: float = 5.0
const HIT_SAMPLE_STEP: int = 3
const REWARD_SKIP_PREFIX: String = "SKIP & RECOVER · +3 HEALTH"
const SPLIT_COPY: String = "On death, this enemy splits into 2 Cinder Droplets within 1 tile."
const CURATOR_COPY: String = "This relic will appear in your next Relic room."
const PAGES: Dictionary = {
	"basic:rewards": ["rewards", "After combat, choose a reward."],
	"keyword:surface_electrified": ["electrified", "A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles."],
	"combat:boss_eclipse": ["last_eclipse", "Last Eclipse starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles."],
	"combat:hollow_gale": ["hollow_gale", "Hollow Gale damages you and your Illusions on Marked tiles, then Pushes you 1 tile away from Vaeloryx."],
	"keyword:charge": ["charge", "At 3 Charge, this enemy's next attack is Arc Lash."],
}

var _output: String
var _headless: bool
var _captures: int


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_output = OS.get_environment("TXT42_OUTPUT")
	if not _output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("Set TXT42_OUTPUT to an absolute writable directory.")
		quit(1)
		return
	_setup()
	Hover.prepare(_viewport)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.set_storage_path("user://txt42_capture_settings.json")
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	_expect(Cel.mode == "all" and _viewport.size == PROBE_VIEWPORT, "Use Cel Look all and 1920x1080.")
	_expect(FileAccess.file_exists("res://cel_look_variants/manifest.json"), "The approved Cel Look manifest is available.")

	var fixture := F.new()
	var state: Dictionary = fixture.descent()
	state["progression"] = Tutorial.complete_tutorial(state["progression"])
	var scene: Node = await _instance(state)
	_expect(is_equal_approx(Typography.ui_scale(scene.ui_root), 1.0), "The run scene uses 100% UI scale.")
	await _grimoire(scene)
	await _split_hover(scene)
	await _eclipse_hover(scene)
	await _normal_reward(scene, fixture)
	await _curator(scene, fixture)
	_viewport.queue_free()
	await process_frame
	_expect(_captures == PAGES.size() + 4, "Every requested proof surface must be reached.")
	print("TXT42 NATIVE PROBE: %s (%s, %d surfaces)" %
		["FAIL" if _failed else "PASS", "headless dry-run" if _headless else "native capture", _captures])
	quit(int(_failed))


func _grimoire(scene: Node) -> void:
	scene._close_large_map()
	var unlocked: Dictionary = Grimoire.unlock_entries(scene._run_state, PAGES.keys() + ["enemy:noctyrax"])
	scene._run_state = unlocked["state"]
	scene._on_grimoire_button_pressed()
	var book: Control = scene._grimoire_scrim
	for id: String in PAGES:
		scene._on_grimoire_entry_pressed(id)
		await _settle()
		var body: RichTextLabel = book._grimoire_detail_body
		var expected: Array = PAGES[id]
		_expect(book.is_visible_in_tree() and book._grimoire_selected_entry == id and body.is_visible_in_tree()
			and expected[1] in body.get_parsed_text(), "Live Grimoire renders the expected opening line for " + id)
		if id == "combat:hollow_gale":
			_expect(PatternText.display_rules(expected[1]) == "@pattern(body_area:2) " + expected[1],
				"Hollow Gale retains its authored inline area diagram.")
		await _save(expected[0])
	scene._on_grimoire_entry_pressed("enemy:noctyrax")
	await _settle()
	var moves: Control = book.find_child("GrimoireMoves", true, false) as Control
	_expect(moves != null and Eclipse.ECLIPSE_SUMMARY in Hover.visible_text(moves),
		"Noctyrax's live Grimoire move table shows the filled Eclipse count.")
	book.close()
	await _settle()


func _split_hover(scene: Node) -> void:
	Live.install(scene, SplitFixture.fixture(["cinder_ooze"]))
	await _settle()
	var board: Control = scene.board_view
	var plates: RefCounted = board.plate_visibility
	for unit: Dictionary in plates.actors():
		if unit.get("type") != "cinder_ooze":
			continue
		for entry: Dictionary in plates.status_entries(unit):
			if entry.get("icon") != "splits":
				continue
			var point: Vector2 = (entry["rect"] as Rect2).get_center()
			await _pointer(board.get_global_transform_with_canvas() * point)
			var tooltip: String = board.call("_get_tooltip", point)
			_expect(board.is_visible_in_tree() and _viewport.gui_get_hovered_control() == board
				and tooltip == "Splits 2\n" + SPLIT_COPY, "The live combat board owns the Splits status-chip hover.")
			if not _headless:
				await create_timer(HOVER_SECONDS).timeout
				_expect(_tooltip_visible(_viewport), "The Splits hover opens the real tooltip popup with the exact trait copy.")
			await _save("splits_hover")
			await _pointer(Vector2.ZERO)
			return
	_fail("A live Cinder Ooze Splits chip could not be found.")


func _eclipse_hover(scene: Node) -> void:
	var state: Dictionary = Fight.state("noctyrax", "last_eclipse")
	var run_state: Dictionary = scene._run_state.duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = {"grid": state["grid"], "element": "shadow", "type": "combat"}
	run_state["combat_state"] = state
	scene._load_run_state(run_state)
	scene._close_large_map()
	scene._close_dialogue()
	await _settle()
	var enemy: Dictionary = state["enemies"][0]
	var inspection: Control = scene._build_pre_battle_enemy_inspection_panel(enemy)
	_viewport.add_child(inspection)
	await process_frame
	_expect(Eclipse.ECLIPSE_SUMMARY in _labels_text(inspection),
		"Noctyrax's pre-battle Known Moves shows the same filled Eclipse count.")
	inspection.queue_free()
	await process_frame
	await scene._on_board_tile_clicked(enemy["pos"])
	await _settle()
	var board: Control = scene.board_view
	var rect: Rect2 = board.enemy_intent_visual_global_rect("enemy_%d" % int(enemy["id"]))
	var point: Vector2 = _eclipse_tooltip_point(board, rect)
	if point == Vector2.INF:
		_fail("The live Eclipse intent chip has no hit region with the exact tooltip.")
		return
	var path: String = _output.path_join("last_eclipse_intent_1920x1080.png")
	var error: String = await Hover.capture(board, point, Eclipse.ECLIPSE_SINGULAR, path)
	_expect(error.is_empty(), "Last Eclipse opens its live intent tooltip: " + error)
	_captures += int(error.is_empty())
	await _pointer(Vector2.ZERO)


func _eclipse_tooltip_point(board: Control, rect: Rect2) -> Vector2:
	var to_local: Transform2D = board.get_global_transform_with_canvas().affine_inverse()
	for y: int in range(ceili(rect.position.y), floori(rect.end.y), HIT_SAMPLE_STEP):
		for x: int in range(ceili(rect.position.x), floori(rect.end.x), HIT_SAMPLE_STEP):
			var point := Vector2(x, y)
			if Eclipse.ECLIPSE_SINGULAR in board.get_tooltip(to_local * point):
				var inset := Vector2(HIT_SAMPLE_STEP, HIT_SAMPLE_STEP)
				if Eclipse.ECLIPSE_SINGULAR in board.get_tooltip(to_local * (point + inset)): return point + inset
	return Vector2.INF


func _normal_reward(scene: Node, fixture: F) -> void:
	var reward: Dictionary = Rewards.regular_reward(fixture)
	reward["progression"] = Tutorial.complete_tutorial(reward["progression"])
	scene._load_run_state(reward)
	scene._close_dialogue()
	scene._close_large_map()
	var deadline: int = Time.get_ticks_msec() + int(REWARD_READY_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var recover: Button = scene.find_child("RewardRecoverButton", true, false) as Button
		var row: Control = scene.find_child("RewardCardRow", true, false) as Control
		if recover == null or row == null or not recover.is_visible_in_tree(): continue
		if not recover.get_global_rect().has_area() or not recover.text.begins_with(REWARD_SKIP_PREFIX): continue
		_expect(reward["mode"] == "reward" and row.is_visible_in_tree() and row.get_child_count() == 3,
			"A normal combat victory displays three cards and the skip heal.")
		await _settle()
		await _save("normal_reward")
		return
	_fail("The normal combat reward screen did not show the +3 Health skip control.")


func _tooltip_visible(node: Node) -> bool:
	if node is Control and node.has_meta("tooltip_surface") and node.is_visible_in_tree():
		if _labels_text(node).contains(SPLIT_COPY):
			return true
	for child: Node in node.get_children(true):
		if _tooltip_visible(child):
			return true
	return false


func _curator(scene: Node, fixture: F) -> void:
	var offer_state: Dictionary = Rewards.curator_offer(fixture)
	offer_state["progression"] = Tutorial.complete_tutorial(offer_state["progression"])
	scene._load_run_state(offer_state)
	scene._close_dialogue()
	scene._close_large_map()
	var deadline: int = Time.get_ticks_msec() + int(TREASURE_READY_SECONDS * 1000.0)
	var relic: String = offer_state["pending_relics"][0]
	var offer: Control
	while Time.get_ticks_msec() < deadline:
		await process_frame
		offer = scene.find_child("RelicChoice_" + relic, true, false) as Control
		if offer != null and offer.is_visible_in_tree() and not scene._treasure_presentation_busy():
			break
	if offer == null or not offer.is_visible_in_tree() or scene._treasure_presentation_busy():
		_fail("Relic room never opened its live choices.")
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	offer.gui_input.emit(press)
	await _settle()
	var dialog: Control = scene._skill_choice_scrim
	var options: Control = scene._skill_choice_list
	if not dialog.is_visible_in_tree() or options.get_child_count() < 2:
		_fail("Selecting a relic must open the Curator's Patience dialog.")
		return
	var save: Button = options.get_child(1)
	save.grab_focus()
	await _settle()
	var description: Label = scene._skill_choice_description
	_expect(scene._skill_choice_title.text == "Curator's Patience" and save.tooltip_text == CURATOR_COPY
		and description.text.contains(CURATOR_COPY), "A focused Save choice shows the exact Curator's Patience line.")
	await _save("curators_patience")


func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	if _headless:
		print("WOULD CAPTURE " + path)
	else:
		await _capture(path)
		if not FileAccess.file_exists(path):
			_fail("Capture missing: " + path)
			return
		print(path)
	_captures += 1
