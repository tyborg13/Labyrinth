extends "res://tests/pre_battle_living_foes_fixture.gd"

const OUTPUT: String = "user://probes/pb_01_living_foes"
const STRIP_FRAMES: int = 4
const STRIP_STEP_SECONDS: float = 0.2
const HOVER_DEADLINE_MSEC: int = 3000
const HOVER_POLL_SECONDS: float = 0.05
# Debug-only int-02 pack; authored creature data and presentation stay intact.
const MAQUETTE_ROSTER: Array = ["crawler", "bile_bloomer", "lightning_wisp", "noctyrax", "gust_shrike", "hoarfrost_seer"]
const MAQUETTE_SCRIPTS: Dictionary = {
	"bile_bloomer": preload("res://scripts/maquette_cutout_runtime/shale_bloomer_renderer.gd"),
	"lightning_wisp": preload("res://scripts/maquette_cutout_runtime/lightning_wisp_renderer.gd")
}
var _logic_only: bool = false
var _maquette_pack: bool = false
var _witnesses: Array[Dictionary]
var _previous: Image
var _reduced_before: Image

func _initialize() -> void:
	_logic_only = "--logic-only" in OS.get_cmdline_user_args()
	_maquette_pack = "--maquette-pack" in OS.get_cmdline_user_args()
	_setup()
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	_run.call_deferred()

func _run() -> void:
	var instance: Node = await _living_fixture()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var proof_roster: Array[String]
	proof_roster.assign(MAQUETTE_ROSTER if _maquette_pack else MIXED_ROSTER)
	var panel: Control = await _set_roster(instance, proof_roster, {"type": "kill_all"})
	for index: int in range(STRIP_FRAMES):
		await _snap("mixed_idle_%02d" % index, panel)
		await create_timer(STRIP_STEP_SECONDS).timeout
	for type: String in ["kill_leader", "survive", "reach_exit"]:
		panel = await _set_roster(instance, proof_roster, {"type": type, "leader_id": 1})
		var heading := panel.find_child("PreBattleObjectiveTitle", true, false) as Label
		if type == "kill_leader":
			await _hover_objective(heading)
		else:
			router.call("set_forced_state_for_test", "controller" if type == "reach_exit" else "pointer", "xbox")
			var first_foe := panel.find_child("PreBattleEnemyCard", true, false) as Control
			first_foe.grab_focus()
			if type == "reach_exit": await _joy(JOY_BUTTON_DPAD_UP)
			else: await _key(KEY_UP)
			await _settle()
			_expect(heading.has_focus() and heading.get_node_or_null("PreBattleObjectiveFocusTooltip") != null, "Keyboard/controller Up reaches objective heading and shows rules")
		await _snap("objective_" + type, panel)
	var named_roster: Array[String]
	named_roster.append("vyraketh")
	panel = await _set_roster(instance, named_roster, {"type": "kill_leader", "leader_type": "vyraketh", "leader_id": 1})
	await _snap("objective_dragon", panel)
	named_roster.clear()
	named_roster.append("last_lamplighter")
	panel = await _set_roster(instance, named_roster, {"type": "kill_leader", "leader_type": "last_lamplighter", "leader_id": 1})
	await _snap("objective_guardian", panel)
	panel = await _set_roster(instance, proof_roster, {"type": "kill_all"})
	router.call("set_forced_state_for_test", "controller", "xbox")
	var foe := panel.find_child("PreBattleEnemyCard", true, false) as Control
	foe.grab_focus()
	await _settle()
	await _snap("controller_focus", panel)
	await _joy(JOY_BUTTON_A)
	await _settle()
	var inspection := instance.get("_pinned_tooltip_panel") as Control
	_expect(inspection != null and inspection.find_child("PreBattleEnemyLiveActor", true, false) == null, "Controller inspect retains its cropped still")
	await _snap("inspection_still", panel)
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "Controller back closes inspection")
	router.call("clear_forced_state_for_test")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	instance.call("_on_settings_changed", settings)
	await _settle()
	for live: Dictionary in _living_snapshots(panel):
		_expect(live.get("shown_clip", live["clip"]) in ["rest", "static"], "Reduced-motion actors must rest")
	await _snap("reduced_motion_00", panel)
	await create_timer(STRIP_STEP_SECONDS).timeout
	await _snap("reduced_motion_01", panel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT + "/witnesses.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"viewport": [1920, 1080], "ui_scale": 1.0, "captures": _witnesses}, "\t"))
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PB-01 LIVING FOES PROBE%s: %s" % [" LOGIC ONLY" if _logic_only else "", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _snap(name: String, panel: Control) -> void:
	if _maquette_pack and not name.begins_with("objective_"):
		var found: Dictionary = {}
		for live: Node in panel.find_children("PreBattleEnemyLiveActor", "Control", true, false):
			var identity: String = str(live.get("actor_type"))
			if not MAQUETTE_SCRIPTS.has(identity): continue
			var renderer: Node = live.get("renderer")
			_expect(renderer != null and renderer.get_script() == MAQUETTE_SCRIPTS[identity], "int-02 capture uses the approved maquette Script: " + identity)
			found[identity] = true
		_expect(found.size() == MAQUETTE_SCRIPTS.size(), "int-02 proof pack contains both maquette identities")
	_witnesses.append({"capture": name + ".png", "actors": _living_snapshots(panel)})
	if _logic_only: return
	await _capture(OUTPUT + "/" + name + ".png")
	var image: Image = _viewport.get_texture().get_image()
	var region := Rect2i((panel.find_child("PreBattleEnemyFlow", true, false) as Control).get_global_rect())
	var actors: Image = image.get_region(region)
	if name.begins_with("mixed_idle_"):
		if _previous != null:
			_expect(actors.get_data() != _previous.get_data(), "Rendered idle strip must change inside the foe stage")
		_previous = actors
	elif name == "reduced_motion_00":
		_reduced_before = actors
	elif name == "reduced_motion_01":
		_expect(_reduced_before.get_data() == actors.get_data(), "Rendered reduced-motion foe stage must stay still")

func _hover_objective(heading: Label) -> void:
	await _pointer(heading.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == heading, "Actual heading owns native pointer hover")
	var deadline: int = Time.get_ticks_msec() + HOVER_DEADLINE_MSEC
	while Time.get_ticks_msec() < deadline:
		for node: Node in heading.find_children("*", "Window", true, false):
			var popup := node as Window
			if popup.visible and popup.theme_type_variation == &"TooltipPanel":
				_expect(not popup.find_children("*", "PanelContainer", true, false).is_empty(), "Native hover contains the shared tooltip panel")
				return
		await create_timer(HOVER_POLL_SECONDS).timeout
	_expect(false, "Heading hover must open its real native tooltip")
