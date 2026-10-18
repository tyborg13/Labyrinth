extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Special = preload("res://assets/units/burrow_grub_cutout/actions.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for type: String in ["burrow_grub", "ember_tick"]:
		var board := Board.new()
		board.size = Vector2(1920, 1080)
		root.add_child(board)
		await process_frame
		var state: Dictionary = Fixture.fixture(type)
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
		var renderer: Node = board.unit_cutout_renderer(state["enemies"][0])
		_expect(renderer != null, type + ": board uses registered live cutout")
		if renderer == null: continue
		var data: Dictionary = Action.data_for(type)
		for clip: String in data["clips"]:
			for selector: String in data["clips"][clip].get("intents", []):
				var fields: PackedStringArray = selector.split(":")
				_expect(Action.clip_for({"action_type": fields[1]}, {"type": type, "intent": {"id": fields[0]}}) == clip, type + ": " + selector)
			if data["clips"][clip].has("contact"):
				var contact: float = data["clips"][clip]["contact"]
				var count: int = Action.frames_for(type, clip)
				var frame: int = ceili(contact * (count - 1)) + 1
				_expect(absf(Special.phase_at(frame, count, contact) - contact) < 0.000001, type + ": exact contact " + clip)
			for view: String in ["front", "rear"]:
				var rig: Node2D = renderer.rigs[view]
				var poses: Dictionary = {}
				for frame: int in range(Action.frames_for(type, clip)):
					rig.apply_pose(clip, float(frame) / Action.frames_for(type, clip))
					var pose: Array = []
					for bone: String in rig.bones:
						_expect(rig.bones[bone].transform.is_finite(), type + ": finite " + view + "/" + clip + "/" + bone)
						pose.append(str(rig.bones[bone].transform))
					poses[JSON.stringify(pose)] = true
				_expect(poses.size() >= 6, type + ": at least six changing poses " + view + "/" + clip)
		for view: String in ["front", "rear"]:
			var rig: Node2D = renderer.rigs[view]
			if type == "burrow_grub":
				for pair: Array in [["head", "seg_1"], ["seg_1", "seg_2"], ["seg_2", "seg_3"], ["seg_3", "root"], ["seg_4", "seg_3"], ["seg_5", "seg_4"], ["seg_6", "seg_5"], ["tail", "seg_6"]]:
					_expect(rig.bones[pair[0]].get_parent() == rig.bones[pair[1]], "Grub outward ring chain " + str(pair))
				for side: String in ["near", "far"]:
					for index: int in range(1, 4):
						_expect(rig.bones["leg_%s_%d" % [side, index]].get_parent() == rig.bones["seg_%d" % index], "Grub native leg-ring attachment")
			else:
				_expect(rig.bones["head"].get_parent() == rig.bones["shell"], "Tick head on shell")
				for side: String in ["near", "far"]:
					for index: int in range(1, 5):
						var upper: String = "leg_%s_%d_upper" % [side, index]
						var lower: String = "leg_%s_%d_lower" % [side, index]
						_expect(rig.bones[upper].get_parent() == rig.bones["shell"], "Tick upper on shell")
						_expect(rig.bones[lower].get_parent() == rig.bones[upper], "Tick lower on upper")
		var portrait := TextureRect.new()
		preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, type, false, true)
		root.add_child(portrait)
		await process_frame
		_expect(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas is ViewportTexture, type + ": portrait shares renderer")
		_expect(preload("res://scripts/actor_presentation.gd").travel_renderer(type) == Presentation.renderer_script(type), type + ": pre-battle shares renderer")
		portrait.queue_free()
		board.queue_free()
		await process_frame
		await preload("res://tests/maquette_cutout/pixel_runtime_suite.gd").run(self, _expect, type)
	print("RR12 RUNTIME: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
