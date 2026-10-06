extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/protagonist_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor")
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 22
		for clip: String in ["idle", "walk", "attack", "cast", "shoot"]:
			rig.call("apply_pose", clip, 0.42)
	var gear: Script = load("res://scripts/protagonist_cutout/gear_visuals.gd")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/protagonist_cutout/gear_visuals.json"))
	passed = passed and gear != null and not registry.is_empty()
	if gear != null:
		for item_id: String in registry.get("items", {}):
			var slot: String = str(registry["items"][item_id]["slot"])
			var equipped: Dictionary = gear.DEFAULTS.duplicate()
			equipped[slot] = item_id
			passed = passed and gear.resolve(equipped)[slot] == item_id
			renderer.call("set_gear", equipped)
			for facing: String in ["front", "rear"]:
				var rig: Node = renderer.get("rigs")[facing]
				passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty()
				for kind: String in ["replace", "attach"]:
					for op: Dictionary in gear.ops_for_facing(equipped, facing)[kind]:
						passed = passed and FileAccess.file_exists("res://assets/units/protagonist_cutout/" + str(op["file"]))
		passed = passed and gear._items.size() == registry["items"].size()
		print("PROTAGONIST GEAR EXPORT ASSETS: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
		renderer.call("set_gear", gear.DEFAULTS)
		var rest: Texture2D = renderer.call("rest_texture")
		var default_rest_passed: bool = rest != null and rest.get_size() == Vector2(255, 255) and str(rest.get_meta("asset_source_path", "")) == renderer_script.DEFAULT_GEAR_REST_PATH
		print("PROTAGONIST DEFAULT GEAR REST ASSET: " + ("PASS" if default_rest_passed else "FAIL"))
		passed = passed and default_rest_passed
	passed = passed and not FileAccess.file_exists("res://experiments/protagonist_2d/README.md")
	renderer.queue_free()
	await get_tree().process_frame
	print("PROTAGONIST CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)
