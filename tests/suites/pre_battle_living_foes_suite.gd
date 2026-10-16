extends RefCounted

const View = preload("res://scripts/pre_battle_view.gd")
const LiveActor = preload("res://scripts/live_actor_presentation.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/combat_objective_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const EXPECTED_COPY: Dictionary = {
	"kill_all": "Defeat every enemy.",
	"kill_leader": "Defeat the marked leader. The rest flee.",
	"survive": "Survive until the marked time.",
	"reach_exit": "Reach a marked door to escape."
}
const EXPECTED_STATIC: Array[String] = ["hoarfrost_seer", "gale_herald", "arc_thrall", "gloam_stalker", "burrow_grub", "ember_tick", "storm_capacitor", "hollow_mimic", "briar_weaver", "slag_mortar", "glacial_mirror"]
const TEST_STAGE_SIZE := Vector2(206, 365)
const TEST_STEP_SECONDS: float = 0.23
const TEST_PHASE_SLOT: int = 2
const TEST_SLOT_COUNT: int = 6

static func run(expect: Callable) -> void:
	_test_objectives(expect)
	await _test_roster(expect)

static func _test_objectives(expect: Callable) -> void:
	for type: String in EXPECTED_COPY:
		var objective: Dictionary = {"type": type, "description": "stale save copy"}
		expect.call(Rules.description(type) == EXPECTED_COPY[type] and Rules.description_for_objective(objective) == EXPECTED_COPY[type], "Current objective descriptions must be verbatim, including resumed saves: " + type)
		var block: Control = View.build_objective({"objective": objective})
		var title := block.find_child("PreBattleObjectiveTitle", true, false) as Label
		var detail := block.find_child("PreBattleObjectiveDescription", true, false) as RichTextLabel
		expect.call(title.text == "OBJECTIVE · " + Rules.title_for_objective(objective) and title.get_theme_font_size("font_size") == 19, "Prominent objective heading retains the title at 19px: " + type)
		expect.call(detail != null and detail.get_parsed_text() == EXPECTED_COPY[type] and detail.autowrap_mode == TextServer.AUTOWRAP_OFF and detail.get_theme_font_size("normal_font_size") == 14, "Secondary objective copy is exact and cannot wrap: " + type)
		if type == "survive":
			expect.call((detail.get_meta("inline_concept_keys") as Array).has("time") and (detail.get_meta("inline_icon_keys") as Array).is_empty(), "Time retains its gold word token without adding an icon")
		block.free()
	for identity: String in Data.enemies():
		var definition: Dictionary = Data.enemy_def(identity)
		if not bool(definition.get("guardian", false)) and not preload("res://scripts/dragon_boss_library.gd").is_dragon_boss_id(identity): continue
		var objective: Dictionary = {"type": "kill_leader", "leader_type": identity}
		var block: Control = View.build_objective({"objective": objective})
		expect.call(Rules.description_for_objective(objective).is_empty() and block.find_child("PreBattleObjectiveDescription", true, false) == null, "Dragon/Guardian objectives have no secondary line: " + identity)
		expect.call((block.find_child("PreBattleObjectiveTitle", true, false) as Label).text == "OBJECTIVE · Defeat " + str(definition["name"]), "Named objective keeps its authored title: " + identity)
		block.free()

static func _test_roster(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saved_settings: Dictionary = Settings.default_settings()
	saved_settings["reduced_motion"] = Settings.applied_reduced_motion_enabled()
	var settings: Dictionary = saved_settings.duplicate(true)
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	var board := Board.new()
	var host := RunScene.new()
	var stage := Control.new()
	tree.root.add_child(stage)
	var count: int = 0
	var rigged: int = 0
	for identity: String in Data.enemies():
		count += 1
		var uses_renderer: bool = bool(board.call("_unit_uses_cutout", {"type": identity}))
		expect.call((LiveActor.renderer_script(identity) != null) == uses_renderer, "Pre-battle selects the board renderer for " + identity)
		expect.call(uses_renderer == not EXPECTED_STATIC.has(identity), "Roster classification stays 32 rigged / 11 unrigged: " + identity)
		var card: Control = View.build_foe(host, {"type": identity, "hp": 1}, TEST_STAGE_SIZE, false, TEST_PHASE_SLOT, TEST_SLOT_COUNT)
		stage.add_child(card)
		await tree.process_frame
		var live: Control = card.get_node("PreBattleEnemyLiveActor")
		var still := card.get_node("PreBattleEnemyArt") as TextureRect
		var snapshot: Dictionary = live.call("snapshot")
		expect.call(live.position.is_equal_approx(still.position) and live.size.is_equal_approx(still.size), "Live presentation inherits the still's scale and floor registration: " + identity)
		expect.call(snapshot["presentation"] == ("cutout" if uses_renderer else "static") and still.visible != uses_renderer, "Renderer wins over legacy sheets; unrigged actors retain their still: " + identity)
		if uses_renderer:
			rigged += 1
			var renderer: Node = live.get("renderer")
			var start: Dictionary = renderer.call("snapshot")
			expect.call(start["facing"] == "front" and not bool(start["mirrored"]) and start.get("shown_clip", start["clip"]) == "idle", "Board idle faces front: " + identity)
			var seconds: float = float(renderer.get("_idle_seconds"))
			renderer.call("_process", TEST_STEP_SECONDS)
			expect.call(not is_equal_approx(seconds, float(renderer.get("_idle_seconds"))), "Board idle clock advances: " + identity)
			card.hide()
			seconds = float(renderer.get("_idle_seconds"))
			renderer.call("_process", TEST_STEP_SECONDS)
			expect.call(is_equal_approx(seconds, float(renderer.get("_idle_seconds"))), "Hidden pre-battle actors pause their idle work: " + identity)
			card.show()
			settings["reduced_motion"] = true
			Settings.apply_settings(settings, null, false)
			live.call("_process", TEST_STEP_SECONDS)
			var rest: Dictionary = renderer.call("snapshot")
			expect.call(rest.get("shown_clip", rest["clip"]) == "rest", "Reduced motion selects authored rest: " + identity)
			seconds = float(renderer.get("_idle_seconds"))
			renderer.call("_process", TEST_STEP_SECONDS)
			expect.call(is_equal_approx(seconds, float(renderer.get("_idle_seconds"))), "Reduced motion freezes idle clock: " + identity)
			settings["reduced_motion"] = false
			Settings.apply_settings(settings, null, false)
		var inspection: Control = host.call("_build_pre_battle_enemy_inspection_panel", {"type": identity, "hp": 1})
		expect.call(inspection.find_child("PreBattleEnemyLiveActor", true, false) == null, "Inspection remains a cropped still: " + identity)
		inspection.free()
		card.free()
	expect.call(count == 43 and rigged == 32, "Every one of 43 identities is covered (32 cutouts / 11 stills)")
	# Repeated identities must start at distinct deterministic normalized phases.
	var phases: Array = []
	for slot: int in range(TEST_SLOT_COUNT):
		var live := LiveActor.new()
		live.configure("crawler", null, slot, TEST_SLOT_COUNT)
		phases.append(live.initial_phase)
		live.free()
	var unique: Dictionary = {}
	for phase: float in phases: unique[phase] = true
	expect.call(unique.size() == TEST_SLOT_COUNT and phases[TEST_PHASE_SLOT] == float(TEST_PHASE_SLOT) / TEST_SLOT_COUNT, "Six slots use six deterministic phases")
	stage.free()
	host.free()
	board.free()
	Settings.apply_settings(saved_settings, null, false)
