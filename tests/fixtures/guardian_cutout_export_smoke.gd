extends Node
const Renderer = preload("res://scripts/guardian_cutout/renderer.gd")
var errors: Array[String]
func _ready() -> void:
	check(not OS.has_feature("editor"),"unmodified export runtime")
	check(not DirAccess.dir_exists_absolute("res://experiments"),"no loose experiment sources")
	check(not DirAccess.dir_exists_absolute("res://tools"),"no authoring tools")
	var textures: Dictionary = {}
	for id: String in Renderer.ACTOR_IDS:
		var renderer := Renderer.new()
		renderer.character_id=id
		add_child(renderer)
		await get_tree().process_frame
		check(renderer.rigs.size()==2,id+" both views load")
		for rig: Node in renderer.rigs.values():
			check((rig.load_errors as PackedStringArray).is_empty(),id+" all paint loads")
			check(not (rig.bones as Dictionary).is_empty(),id+" skeleton loads")
		var texture: Texture2D = renderer.texture()
		check(texture!=null and not textures.has(texture.get_instance_id()),id+" distinct live texture")
		textures[texture.get_instance_id()]=true
		for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			for clip: String in ["idle","walk","strike","cast","brace"]:
				var motion: Dictionary = {"clip":clip if clip in ["idle","walk"] else "attack","action":clip,"phase":.46,"direction":direction}
				renderer.present(motion,false,true)
				check(renderer.texture()==texture,id+" stable texture across motions and facings")
				renderer.present(motion,true,true)
		print("GUARDIAN PACKED RENDERER: ",id," PASS")
	for error: String in errors:push_error(error)
	print("GUARDIAN PACK RUNTIME: ","PASS" if errors.is_empty() else "FAIL"," editor=",OS.has_feature("editor"))
	get_tree().quit(0 if errors.is_empty() else 1)
func check(ok: bool,message: String) -> void:
	if not ok:errors.append(message)
