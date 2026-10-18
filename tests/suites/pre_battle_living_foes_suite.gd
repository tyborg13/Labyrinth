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
const EXPECTED_STATIC := ["gale_herald", "gloam_stalker", "burrow_grub", "ember_tick", "storm_capacitor", "hollow_mimic", "briar_weaver", "slag_mortar", "glacial_mirror"]
const MAQUETTE_FOES := ["bile_bloomer", "lightning_wisp", "hoarfrost_seer", "arc_thrall"]
const TEST_STAGE_SIZE := Vector2(206, 365)
const PROCESS_FRAMES: int = 3
const PHASE_EPSILON: float = 0.000001
const TEST_PHASE_SLOT: int = 2
const TEST_SLOT_COUNT: int = 6
const OBJECTIVE_TEST_SIZE := Vector2(1000, 100)

# Independent oracle: board constants plus explicit maquette Scripts, never the
# selector under test. Shared Guardian instances must also carry their identity.
const EXPECTED_RENDERERS: Dictionary = {
	"hoarfrost_seer": preload("res://assets/units/hoarfrost_seer_cutout/renderer.gd"),
	"arc_thrall": preload("res://assets/units/arc_thrall_cutout/renderer.gd"),
	"crawler": Board.CrawlerCutout, "acolyte": Board.AcolyteCutout,
	"harrier": Board.HarrierCutout, "warden": Board.WardenCutout,
	"cinder_ooze": Board.CinderOozeCutout, "cinder_droplet": Board.CinderDropletCutout,
	"bile_bloomer": preload("res://scripts/maquette_cutout_runtime/shale_bloomer_renderer.gd"), "chainbound_gaoler": Board.GaolerCutout,
	"grave_surgeon": Board.GraveSurgeonCutout, "frostglass_lancer": Board.FrostglassCutout,
	"tharokh": Board.TharokhCutout, "vyraketh": Board.VyrakethCutout,
	"vaeloryx": Board.VaeloryxCutout, "iskaldra": Board.IskaldraCutout,
	"noctyrax": Board.NoctyraxCutout, "zekarion": Board.ZekarionCutout,
	"veilbound_acolyte": Board.VeilboundAcolyteCutout,
	"lightning_wisp": preload("res://scripts/maquette_cutout_runtime/lightning_wisp_renderer.gd"), "gust_shrike": Board.GustShrikeCutout
}

static func run(expect: Callable) -> void:
	_test_objectives(expect)
	await _test_heading_focus(expect)
	await _test_roster(expect)
	await _test_applied_slot_phases(expect)
	await preload("res://tests/suites/maquette_presentation_surfaces_suite.gd").run(expect)
	await preload("res://tests/suites/live_actor_submission_suite.gd").run(expect)

static func _test_objectives(expect: Callable) -> void:
	for type: String in EXPECTED_COPY:
		var objective: Dictionary = {"type": type, "description": "stale save copy"}
		expect.call(Rules.description(type) == EXPECTED_COPY[type] and Rules.description_for_objective(objective) == EXPECTED_COPY[type], "Current objective descriptions must be verbatim, including resumed saves: " + type)
		var block: Control = View.build_objective({"objective": objective})
		var title := block.find_child("PreBattleObjectiveTitle", true, false) as Label
		expect.call(title.text == "OBJECTIVE · " + Rules.title_for_objective(objective) and title.get_theme_font_size("font_size") == 19, "Prominent objective heading retains the title at 19px: " + type)
		expect.call(block.find_child("PreBattleObjectiveDescription", true, false) == null and title.focus_mode == Control.FOCUS_ALL, "Every objective is heading-only and navigation-focusable: " + type)
		expect.call(title.tooltip_text == Rules.title_for_objective(objective) + "\n" + str(EXPECTED_COPY[type]), "Heading hover rules are exact: " + type)
		var tooltip: Control = title.call("_make_custom_tooltip", title.tooltip_text)
		expect.call(bool(tooltip.get_meta("tooltip_surface", false)), "Heading uses the existing tooltip style: " + type)
		var copy: String = ""
		for child: Node in tooltip.find_children("*", "Control", true, false):
			if child is Label and (child as Label).text == EXPECTED_COPY[type]: copy = (child as Label).text
			if child is RichTextLabel:
				copy = (child as RichTextLabel).get_parsed_text()
				if type == "survive": expect.call((child.get_meta("inline_concept_keys") as Array).has("time"), "Time keeps its gold tooltip word token")
		expect.call(copy == EXPECTED_COPY[type], "Rendered tooltip body preserves verbatim rule text: " + type)
		tooltip.free()
		block.free()
	for identity: String in Data.enemies():
		var definition: Dictionary = Data.enemy_def(identity)
		if not bool(definition.get("guardian", false)) and not preload("res://scripts/dragon_boss_library.gd").is_dragon_boss_id(identity): continue
		var objective: Dictionary = {"type": "kill_leader", "leader_type": identity}
		var block: Control = View.build_objective({"objective": objective})
		expect.call(Rules.description_for_objective(objective).is_empty() and block.find_child("PreBattleObjectiveDescription", true, false) == null, "Dragon/Guardian objectives have no secondary line: " + identity)
		expect.call((block.find_child("PreBattleObjectiveTitle", true, false) as Label).text == "OBJECTIVE · Defeat " + str(definition["name"]), "Named objective keeps its authored title: " + identity)
		block.free()

static func _test_heading_focus(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for type: String in EXPECTED_COPY:
		var block: Control = View.build_objective({"objective": {"type": type}})
		block.size = OBJECTIVE_TEST_SIZE
		tree.root.add_child(block)
		var heading := block.find_child("PreBattleObjectiveTitle", true, false) as Label
		# The full suite starts in SceneTree._initialize, before its root has
		# entered the tree. Settle attachment/layout before requesting focus.
		await _frames(tree)
		heading.grab_focus()
		await _frames(tree)
		var tooltip := heading.get_node_or_null("PreBattleObjectiveFocusTooltip") as PanelContainer
		expect.call(heading.has_focus() and tooltip != null and tooltip.is_visible_in_tree() and bool(tooltip.get_meta("tooltip_surface", false)), "Navigation focus displays the heading's existing-style tooltip: " + type)
		expect.call(heading.mouse_filter == Control.MOUSE_FILTER_STOP, "Heading receives pointer hover: " + type)
		heading.release_focus()
		await _frames(tree)
		expect.call(heading.get_node_or_null("PreBattleObjectiveFocusTooltip") == null, "Leaving the heading clears its focus tooltip: " + type)
		block.free()

static func _test_roster(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saved_settings: Dictionary = Settings.default_settings()
	saved_settings["reduced_motion"] = Settings.applied_reduced_motion_enabled()
	var settings: Dictionary = saved_settings.duplicate(true)
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	var host := RunScene.new()
	var stage := Control.new()
	tree.root.add_child(stage)
	var actors: Dictionary = {}
	var count: int = 0
	for identity: String in Data.enemies():
		count += 1
		var expected: Script = Board.GuardianCutout if Board.GuardianCutout.handles(identity) else EXPECTED_RENDERERS.get(identity)
		expect.call((expected == null) == EXPECTED_STATIC.has(identity), "Independent 43-identity oracle covers " + identity)
		var card: Control = View.build_foe(host, {"type": identity, "hp": 1}, TEST_STAGE_SIZE, false, TEST_PHASE_SLOT, TEST_SLOT_COUNT)
		stage.add_child(card)
		var live: Control = card.get_node("PreBattleEnemyLiveActor")
		var still := card.get_node("PreBattleEnemyArt") as TextureRect
		var renderer: Node = live.get("renderer")
		expect.call((renderer.get_script() if is_instance_valid(renderer) else null) == expected, "Instantiated renderer Script matches the board identity: " + identity)
		if is_instance_valid(renderer):
			actors[identity] = renderer
			if expected == Board.GuardianCutout: expect.call(renderer.get("character_id") == identity, "Shared Guardian renderer carries character_id: " + identity)
			var snapshot: Dictionary = renderer.call("snapshot")
			expect.call(snapshot["facing"] == "front" and not bool(snapshot["mirrored"]) and snapshot.get("shown_clip", snapshot["clip"]) == "idle", "Board idle faces front: " + identity)
			if identity in MAQUETTE_FOES:
				expect.call(still.texture is AtlasTexture and (still.texture as AtlasTexture).atlas == renderer.call("texture"), "Source canvas shares the single live maquette renderer: " + identity)
		expect.call(still.visible == (expected == null), "Only unrigged identities show the source still: " + identity)
		var inspection: Control = host.call("_build_pre_battle_enemy_inspection_panel", {"type": identity, "hp": 1})
		expect.call(inspection.find_child("PreBattleEnemyLiveActor", true, false) == null, "Inspection remains a cropped still: " + identity)
		if identity in MAQUETTE_FOES:
			var portrait_renderer: Node = inspection.find_child("MaquettePortraitRenderer", true, false)
			expect.call(portrait_renderer != null and portrait_renderer.get_script() == expected, "Inspection resolves the maquette Script: " + identity)
		inspection.free()
	await _frames(tree)
	for card: Control in stage.get_children():
		var live: Control = card.get_node("PreBattleEnemyLiveActor")
		var still := card.get_node("PreBattleEnemyArt") as TextureRect
		expect.call(live.position.is_equal_approx(still.position) and live.size.is_equal_approx(still.size), "Live canvas inherits source scale and floor: " + str(live.get("actor_type")))
	var before: Dictionary = _clocks(actors)
	await _frames(tree)
	for identity: String in actors:
		expect.call(not is_equal_approx(float(before[identity]), float(actors[identity].get("_idle_seconds"))), "SceneTree automatically advances idle: " + identity)
	stage.hide()
	before = _clocks(actors)
	await _frames(tree)
	_assert_frozen(actors, before, expect, "Hidden SceneTree idle stays frozen: ")
	stage.show()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	await _frames(tree)
	for identity: String in actors:
		var rest: Dictionary = actors[identity].call("snapshot")
		expect.call(rest.get("shown_clip", rest["clip"]) == "rest", "Automatic reduced-motion update selects rest: " + identity)
	before = _clocks(actors)
	await _frames(tree)
	_assert_frozen(actors, before, expect, "Reduced-motion SceneTree idle stays frozen: ")
	expect.call(count == 43 and actors.size() == 34, "Every identity is covered (34 cutouts / 9 stills)")
	stage.free()
	host.free()
	Settings.apply_settings(saved_settings, null, false)

static func _frames(tree: SceneTree) -> void:
	for frame: int in range(PROCESS_FRAMES): await tree.process_frame

static func _clocks(actors: Dictionary) -> Dictionary:
	var clocks: Dictionary = {}
	for identity: String in actors: clocks[identity] = float(actors[identity].get("_idle_seconds"))
	return clocks

static func _assert_frozen(actors: Dictionary, clocks: Dictionary, expect: Callable, context: String) -> void:
	for identity: String in actors:
		expect.call(is_equal_approx(float(clocks[identity]), float(actors[identity].get("_idle_seconds"))), context + identity)

static func _test_applied_slot_phases(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings: Dictionary = Settings.default_settings()
	var restore_reduced: bool = Settings.applied_reduced_motion_enabled()
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	var host := RunScene.new()
	for identity: String in ["crawler", "bile_bloomer", "lightning_wisp", "hoarfrost_seer", "arc_thrall"]:
		_test_slot_phases_for(host, tree, identity, expect)
	host.free()
	settings["reduced_motion"] = restore_reduced
	Settings.apply_settings(settings, null, false)
	await _frames(tree)

static func _test_slot_phases_for(host: Node, tree: SceneTree, identity: String, expect: Callable) -> void:
	var first: Array[float]
	for rebuild: int in range(2):
		var stage := Control.new()
		tree.root.add_child(stage)
		var phases: Array[float]
		# Sample real ready-initialized renderers in the same SceneTree boundary,
		# before automatic elapsed time, rather than disabling their processing.
		for slot: int in range(TEST_SLOT_COUNT):
			var card: Control = View.build_foe(host, {"type": identity, "hp": 1}, TEST_STAGE_SIZE, false, slot, TEST_SLOT_COUNT)
			stage.add_child(card)
			var renderer: Node = card.get_node("PreBattleEnemyLiveActor").get("renderer")
			var phase: float = float((renderer.call("snapshot") as Dictionary)["phase"])
			phases.append(phase)
			expect.call(absf(phase - float(slot) / TEST_SLOT_COUNT) < PHASE_EPSILON, "Actual renderer is seeded at slot %d / rebuild %d: %s" % [slot, rebuild, identity])
			expect.call(absf(float((renderer.get("_pose_signature") as Array)[3]) - phase) < PHASE_EPSILON, "Seed is applied to the rig pose at slot %d" % slot)
		var unique: Dictionary = {}
		for phase: float in phases: unique[phase] = true
		expect.call(unique.size() == TEST_SLOT_COUNT, "Six initialized identical foes have six actual idle phases")
		if rebuild == 0: first.assign(phases)
		else: expect.call(phases == first, "Actual renderer phases are deterministic across rebuilds")
		stage.free()
