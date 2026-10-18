extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Special = preload("res://assets/units/hoarfrost_seer_cutout/actions.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for type: String in ["hoarfrost_seer", "arc_thrall"]:
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
				var frame: int = ceili(contact * count)
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
				var minimum: int = 3 if type == "hoarfrost_seer" and clip == "idle" else 6
				_expect(poses.size() >= minimum, type + ": complete progression " + view + "/" + clip)
				if type == "hoarfrost_seer":
					_expect(rig.bones["staff"].get_parent() == rig.bones["hand_far"], "Whole staff follows far grip")
		for view: String in ["front", "rear"]:
			var rig: Node2D = renderer.rigs[view]
			if type == "hoarfrost_seer":
				_expect(not rig.bones.has("collar") and not rig.bones.has("skirt_near"), "Fused collar and robe")
				_expect(rig.bones["pelvis"].get_parent() == rig.bones["root"], "Pelvis follows root")
				_expect(rig.bones["foot_near"].get_parent() == rig.bones["hem_near"], "Foot follows hem anchor")
			else:
				_expect(rig.bones["collar"].get_parent() == rig.bones["torso"], type + ": director collar hierarchy")
				_expect(not rig.bones.has("pelvis"), type + ": no pelvis bone")
				_expect(rig.bones["loincloth"].get_parent() == rig.bones["torso"], "Loincloth follows torso")
		var portrait := TextureRect.new()
		preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, type, false, true)
		root.add_child(portrait)
		await process_frame
		_expect(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas is ViewportTexture, type + ": portrait shares renderer")
		_expect(preload("res://scripts/actor_presentation.gd").travel_renderer(type) == Presentation.renderer_script(type), type + ": pre-battle shares renderer")
		if type == "hoarfrost_seer": preload("res://tests/rr10/humanoid_runtime_suite.gd").run(renderer, _expect)
		portrait.queue_free()
		board.queue_free()
		await process_frame
		if type != "hoarfrost_seer": await preload("res://tests/maquette_cutout/pixel_runtime_suite.gd").run(self, _expect, type)
	print("RR07 RUNTIME: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
