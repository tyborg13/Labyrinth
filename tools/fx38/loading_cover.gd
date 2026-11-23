extends RefCounted
## Observe the production Continue handoff and the board shader it inherits.

const Warm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const SAMPLE_NAME: String = "board cel textured polygons"
const TIMEOUT_MSEC: int = 30000
const HEADLESS_YIELD_MSEC: int = 2

var scene: Control
var failed: bool
var sample_frame: int = -1
var board_frame: int = -1
var sampled_shader: Shader
var warmed_before_board: bool

func enter(tree: SceneTree) -> bool:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	tree.node_added.connect(_added)
	menu._on_continue_button_pressed()
	var transition: Node = tree.root.get_node_or_null("MenuRunTransition")
	if transition != null:
		transition.finished.connect(_finished)
		transition.failed.connect(_failed)
		var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
		while scene == null and not failed and Time.get_ticks_msec() < deadline:
			# Fixed-FPS headless frames run far ahead of the real loader thread.
			if DisplayServer.get_name() == "headless": OS.delay_msec(HEADLESS_YIELD_MSEC)
			await tree.process_frame
	tree.node_added.disconnect(_added)
	if scene == null:
		var phase: String = str(transition.phase) if is_instance_valid(transition) else "no transition"
		var status: String = str(preload("res://scripts/progression_store.gd").read_resumable_checkpoint().get("status"))
		push_error("FX-38 Continue status=%s phase=%s failed=%s shader_sample_frame=%d board_frame=%d" % [status, phase, failed, sample_frame, board_frame])
		if is_instance_valid(transition): print(transition.performance_snapshot())
	return scene != null

func verify(board: Control, label: String, expect_kindle: bool) -> bool:
	var material: ShaderMaterial = board.material
	var contains_kindle: bool = material != null and material.shader.code.contains("kindle_crack")
	var same_shader: bool = material != null and material.shader == sampled_shader
	var ordered: bool = sample_frame >= 0 and board_frame >= sample_frame and warmed_before_board
	print("FX-38 %s LOADING_COVER prewarm before board=%s sample_frame=%d board_frame=%d shared_shader=%s board shader contains kindle_crack=%s" % [
		label, "yes" if ordered else "no", sample_frame, board_frame, "yes" if same_shader else "no", "yes" if contains_kindle else "no"])
	return ordered and same_shader and contains_kindle == expect_kindle

func _finished(destination: Node) -> void:
	scene = destination as Control

func _failed() -> void:
	failed = true

func _added(node: Node) -> void:
	if node.name == &"CombatBoard" and node.get_parent().name == &"BoardUnderlay" and board_frame < 0:
		board_frame = Engine.get_process_frames()
		var warmed: Dictionary = node.get_viewport().get_meta(Warm.WARMED_META, {})
		for material: Variant in warmed.values():
			if material is ShaderMaterial and material.resource_name == SAMPLE_NAME and material.shader == sampled_shader:
				warmed_before_board = true
				break
		return
	if sampled_shader != null or not node is CanvasItem: return
	var material: ShaderMaterial = node.material as ShaderMaterial
	if material == null or material.resource_name != SAMPLE_NAME: return
	var worker: Node = node.get_parent().get_parent()
	if worker.name != Warm.NODE_NAME or worker.get_parent().name != &"MenuRunTransition": return
	sample_frame = Engine.get_process_frames()
	sampled_shader = material.shader
