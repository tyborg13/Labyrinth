extends SceneTree
## Native isolated-group surfaces: identical production loader, glow disabled
## only for the pixel-equality test. Normal reel/game proof retains the glow.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const Motion = preload("res://scripts/emaciated_man_cutout/motion.gd")
const CASE: String = "res://experiments/cutouts/emaciated_man/emac02/cutout.json"
const OUTPUT: String = "user://probes/emac02_rigid"
var rig: Node2D
var viewport: SubViewport
var verify_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	verify_only = OS.get_cmdline_user_args().has("--verify-only")
	call_deferred("_run")
func _matrix(t: Transform2D) -> Array:
	return [t.x.x,t.x.y,t.y.x,t.y.y,t.origin.x,t.origin.y]
func _group(group: String) -> void:
	var upper: bool = group == "upper"
	for part: Dictionary in rig.layout["parts"]:
		for node: Node in rig.find_children(str(part["name"]),"Sprite2D",true,false):
			(node as CanvasItem).visible = (str(part["bone"]) in Motion.UPPER) == upper
	for mesh: Dictionary in rig.layout.get("joint_meshes",[]):
		for node: Node in rig.find_children(str(mesh["name"]),"Polygon2D",true,false):
			(node as CanvasItem).visible = (str(mesh["replaces_part"]) in Motion.UPPER) == upper
func _capture(name: String) -> void:
	if verify_only: return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(512,512))
	assert(image.save_png(OUTPUT.path_join(name)) == OK)
func _run() -> void:
	root.size = Vector2i(1920,1080)
	viewport = SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	rig = Rig.new()
	rig.position = Vector2(128,128)
	viewport.add_child(rig)
	assert(rig.configure(CASE),str(rig.load_errors))
	rig.set_glow_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var rows: Array[Dictionary]
	for group: String in ["upper","lower"]:
		_group(group)
		rig.apply_pose("rest",0.0)
		await _capture(group+"_rest.png")
		for frame: int in range(35):
			var seconds: float = minf(frame / 10.0,Motion.IDLE_SECONDS)
			var phase: float = seconds / Motion.IDLE_SECONDS
			rig.apply_pose("idle",phase)
			var bones: Dictionary = {}
			for name: String in rig.bones:
				bones[name] = {"global":_matrix(rig.global_transform.affine_inverse() * rig.bones[name].global_transform)}
			var path: String = "%s_%02d.png" % [group,frame]
			await _capture(path)
			rows.append({"group":group,"frame":frame,"seconds":seconds,"phase":phase,"file":path,"bones":bones})
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"case":CASE,"case_sha256":FileAccess.get_sha256(CASE),"verify_only":verify_only,"glow":"disabled for rigid identity only","rows":rows},"\t"))
	print("EMAC RIGID PROBE: PASS; group_samples=70; native_pixels="+str(not verify_only))
	print(ProjectSettings.globalize_path(OUTPUT.path_join("manifest.json")))
	viewport.queue_free()
	await process_frame
	quit()
