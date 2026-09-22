extends Node

## Runs from a production-only PCK using an unmodified export template.
const ACTORS := ["protagonist", "stone_warden", "crawler", "acolyte", "harrier", "cinder_ooze", "cinder_droplet",
	"bile_bloomer", "chainbound_gaoler", "grave_surgeon", "frostglass_lancer",
	"tharokh", "vyraketh", "vaeloryx", "iskaldra", "noctyrax", "zekarion",
	"veilbound_acolyte", "lightning_wisp"]
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
var _errors: Array[String]

func _ready() -> void:
	_check(not OS.has_feature("editor"), "Uses the unmodified export runtime")
	_check(not DirAccess.dir_exists_absolute("res://experiments"), "No experiment tree is available")
	_check(not DirAccess.dir_exists_absolute("res://tools"), "No authoring tools are available")
	_check(not DirAccess.dir_exists_absolute("res://assets/placeholders"), "No legacy sprite tree is available")
	var textures: Dictionary = {}
	for actor: String in ACTORS + Guardian.ACTOR_IDS:
		var renderer_script: Script = Guardian if Guardian.handles(actor) else load("res://scripts/" + actor + "_cutout/renderer.gd") as Script
		_check(renderer_script != null and renderer_script.can_instantiate(), actor + " packed renderer loads")
		if renderer_script == null or not renderer_script.can_instantiate():
			continue
		var renderer: Node = renderer_script.new()
		if Guardian.handles(actor): renderer.set("character_id", actor)
		add_child(renderer)
		await get_tree().process_frame
		var rigs: Dictionary = renderer.get("rigs")
		_check(rigs.size() == 2, actor + " has both registered views")
		for facing: String in ["front", "rear"]:
			var rig: Node = rigs.get(facing)
			_check(rig != null, actor + " loads " + facing)
			if rig != null:
				_check((rig.get("load_errors") as PackedStringArray).is_empty(), actor + " paint loads in " + facing)
				_check(not (rig.get("bones") as Dictionary).is_empty(), actor + " skeleton loads in " + facing)
		var texture: Texture2D = renderer.call("texture")
		_check(texture != null and not textures.has(texture.get_instance_id()), actor + " owns a unique live texture")
		if texture != null:
			textures[texture.get_instance_id()] = true
		for direction: Vector2i in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
			renderer.call("present", {"clip":"walk", "phase":0.42, "direction":direction}, false, true)
			_check(renderer.call("texture") == texture, actor + " preserves its texture across packed views")
		for reaction: String in ["hit", "death"]:
			renderer.call("present", {"clip":reaction, "phase":.6}, false, reaction != "death")
			_check(renderer.call("snapshot")["clip"] == reaction, actor + " packed " + reaction + " plays")
		print("ROSTER PACKED RENDERER: " + actor + " PASS")
	for error: String in _errors:
		push_error(error)
	print("ENEMY CUTOUT ROSTER EXPORT TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if _errors.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
