extends "res://tests/pre_battle_living_foes_fixture.gd"

## On-demand rr55 proof uses existing game UI and shared renderer paths.
const Portrait = preload("res://scripts/maquette_cutout_runtime/portrait.gd")
const OUTPUT: String = "user://probes/rr55_surfaces"
const PROOF_SETTLE_FRAMES: int = 8
var _logic: bool

func _initialize() -> void:
	_logic = OS.get_cmdline_user_args().has("--validate-only")
	_setup()
	root.size = PROBE_VIEWPORT
	root.content_scale_size = PROBE_VIEWPORT
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not _logic:
		_fail("Use visual_probe_runner for captures")
		quit(1)
		return
	var instance: Node = await _living_fixture()
	var roster: Array[String]
	roster.assign(["burrow_grub"])
	var panel: Control = await _set_roster(instance, roster, {"type": "kill_all"})
	var lives: Array[Node] = panel.find_children("PreBattleEnemyLiveActor", "Control", true, false)
	_expect(lives.size() == 1, "Grub pre-battle uses the production LiveActor")
	_expect(Portrait.rest_path("burrow_grub") == "res://assets/units/burrow_grub_cutout/front/rest.png", "Portrait shares mq27 production rest")
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	if not _logic:
		await _capture(OUTPUT.path_join("pre_battle.png"))
		print("Saved " + ProjectSettings.globalize_path(OUTPUT.path_join("pre_battle.png")))
	# The actual turn clock is captured by the real-action production probe.
	# A direct bind here additionally observes the shared portrait renderer,
	# using the existing pre-battle still rather than a debug UI composition.
	var still := panel.find_child("PreBattleEnemyArt", true, false) as TextureRect
	_expect(still != null, "Existing pre-battle still is available")
	if still != null:
		Portrait.bind(still, "burrow_grub", false)
		for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
		_expect(still.get_node_or_null("MaquettePortraitRenderer") != null, "Portrait creates the production renderer")
	if not _logic:
		await _capture(OUTPUT.path_join("portrait_bind.png"))
		print("Saved " + ProjectSettings.globalize_path(OUTPUT.path_join("portrait_bind.png")))
	instance.queue_free()
	await process_frame
	print("MQ27 SURFACES: " + ("FAIL" if _failed else "PASS") + (" (headless logic only)" if _logic else " (1920x1080, UI100)"))
	quit(1 if _failed else 0)
