extends RefCounted

const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const CaptureScene = preload("res://tools/uph01/capture_scene.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const EN01 = preload("res://tests/suites/en01_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Actions = preload("res://scripts/maquette_cutout_runtime/action.gd")

const SIZE := CaptureViewport.SIZE
const CROP_SIZE := Vector2i(640, 640)
const GRUB_TILE := Vector2i(3, 4)
const ACTOR_KEY: String = "enemy_1"
const TYPE: String = "burrow_grub"
const BURROW_PERIOD_MSEC: int = 1500
const BREATH_PEAK_MSEC: int = 375
const BREATH_TROUGH_MSEC: int = 1125
const ERUPT_TAIL_SECONDS: float = 0.233
const FPS: int = 60
const REEL_SECONDS: int = 6
const REEL_BURROW_FRAME: int = 24
const REEL_ERUPT_FRAME: int = 216
const STILLS: PackedStringArray = [
	"01_burrowed_peak", "02_burrowed_trough", "03_burrow_last", "04_after_burrow",
	"05_erupt_start", "06_erupt_contact", "07_erupt_contact_plus_233ms", "08_burrowed_full",
]

var viewport: SubViewport
var scene: Control
var board: Control
var states: Dictionary
var contact: float = float(Actions.data_for(TYPE)["clips"]["erupt"]["contact"])

func setup(tree: SceneTree) -> void:
	Live.prepare_storage()
	tree.root.content_scale_size = SIZE
	viewport = CaptureViewport.create(tree.root)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(CaptureScene)
	viewport.add_child(scene)
	await Live.settle(tree)
	var engine := Combat.new()
	var initial: Dictionary = EN01.fixture()
	initial["enemies"][0]["pos"] = GRUB_TILE
	var burrow: Dictionary = engine.resolve_enemy_turn_with_steps(initial, 0)
	var buried: Dictionary = burrow["state"]
	var erupt: Dictionary = engine.resolve_enemy_turn_with_steps(buried, 0)
	states = {"initial": initial, "buried": buried,
		"burrow": _step(burrow, "burrow"), "erupt": _step(erupt, "erupt")}
	Live.install(scene, initial)
	Live.set_reduced_motion(scene, false)
	scene.set("_animation_lock", true)
	scene._render_board_state(initial, {})
	await Live.settle(tree)
	board = scene.get("board_view")

func drive(kind: String) -> void:
	var before: Dictionary = states["initial"] if kind == "burrow" else states["buried"]
	await scene._animate_enemy_phase_steps(before.duplicate(true), [states[kind]])

func grub_unit() -> Dictionary:
	for unit: Dictionary in board._visible_units():
		if unit.get("key") == ACTOR_KEY: return unit
	return {}

func crop() -> Rect2i:
	var tile: Vector2i = board.combat_state["enemies"][0]["pos"]
	var center: Vector2 = board.get_global_transform_with_canvas() * board._tile_center(tile)
	return Rect2i(Vector2i(center.round()) - CROP_SIZE / 2, CROP_SIZE)

func motion() -> Dictionary:
	return board.presentation.get("burrow_grub_motion", {}).get(ACTOR_KEY, {})

func sample(seconds: float) -> Dictionary:
	var motion_frame: Dictionary = motion()
	var enemy: Dictionary = board.combat_state["enemies"][0]
	var renderer: Node = board.unit_cutout_renderer({"type": TYPE, "id": 1})
	var facing: String = renderer.get("facing")
	var rig: Node = renderer.rigs[facing]
	var pose: Array = []
	for bone: String in rig.bones:
		var node: Bone2D = rig.bones[bone]
		pose.append([bone, str(node.transform), node.modulate.a])
	return {
		"seconds": seconds, "clip": motion_frame.get("clip", ""), "phase": motion_frame.get("phase", -1.0),
		"root_alpha": rig.bones["root"].modulate.a, "pose_sha256": JSON.stringify(pose).sha256_text(),
		"burrowed": enemy.get("burrowed", false), "tile": str(enemy["pos"]),
		"player_hp": board.combat_state["player"]["hp"],
		"surface_feedback": not (board.presentation.get("surface_feedback_events", []) as Array).is_empty(),
	}

func _step(phase: Dictionary, kind: String) -> Dictionary:
	for step: Dictionary in phase["steps"]:
		if step.get("kind") == kind: return step
	return {}
