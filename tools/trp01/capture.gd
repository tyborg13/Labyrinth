extends "res://tools/tooltip_loops/capture.gd"
## Native owner proof only. Uses live tile hover and production action playback.
const Traps = preload("res://tools/tooltip_loops/trap_fixture.gd")
const PROOF_OUT: String = "/private/tmp/labyrinth_codex/trp-01/capture"

func output_dir() -> String:
	return PROOF_OUT

func _run() -> void:
	if OS.get_cmdline_user_args().has("--semantics-only"):
		await _semantics()
		_finish("SEMANTICS")
		return
	if DisplayServer.get_name() == "headless":
		push_error("TRP01 native proof requires the design owner's window server")
		quit(1)
		return
	root.size = Playback.SIZE
	root.content_scale_size = Playback.SIZE
	viewport = Playback.canvas(self)
	viewport.gui_embed_subwindows = true
	viewport.notify_mouse_entered()
	DirAccess.make_dir_recursive_absolute(output_dir())
	for element: String in ["fire", "air"]:
		var fixture: Dictionary = Fixture.build("trap_" + element)
		var scene: Node = await Playback.instance(self, viewport, fixture, false)
		var row: Dictionary = Registry.find("traps", {"kind": "trap", "element": element})
		_expect(Registry.media_available(row), "Record the real trap loop before native tooltip proof")
		var panel: Control = await _open(scene, row)
		var window: Control = panel.find_child("TooltipLoopWindow", true, false) if panel != null else null
		_expect(window != null, "Live tile tooltip contains " + str(row["id"]))
		if window != null:
			window.proof_seconds = -1.0
			for frame: int in range(READY_FRAME_LIMIT):
				await process_frame
				if window.displayed_frame > 0: break
			_expect(not window.reduced_motion and window.displayed_frame > 0, "Tooltip loop is playing at 100% UI scale")
			await _capture("trap_" + element + "_tooltip_playing")
		await OpenProof.close(self, scene, panel)
		if element == "fire":
			var result: Dictionary = Fixture.plan(fixture, preload("res://scripts/hero_facing_combat.gd").new())
			_expect(Fixture.validate(fixture, result).is_empty(), "Fire production aftermath has all five tiles")
			var completion: Dictionary = {"done": false}
			Playback.play(scene, result, completion)
			while not completion["done"]: await process_frame
			await _frame_max(OUTER_POPUP_SETTLE_FRAMES)
			await _capture("trap_fire_five_tile_aftermath")
		scene.queue_free()
		await process_frame
	_finish("TRP01 NATIVE")
