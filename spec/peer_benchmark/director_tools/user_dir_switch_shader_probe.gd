extends SceneTree

# Director diagnostic (shader-01): does switching user:// at runtime (as SteamService does) break
# Godot's shader-cache writes? Draws a fresh shader before and after the switch; watch stderr for
# "_save_to_cache" errors and report where cache files landed.
var _frame: int = 0
var _phase: int = 0

func _initialize() -> void:
	print("PROBE user dir before: ", OS.get_user_data_dir())

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		_draw_fresh_shader("before")
	elif _frame == 30:
		ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
		ProjectSettings.set_setting("application/config/custom_user_dir_name", "Escape the Umbra Shader Probe/steam/123")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
		print("PROBE user dir after switch: ", OS.get_user_data_dir(), " globalize user:// -> ", ProjectSettings.globalize_path("user://"))
	elif _frame == 40:
		_draw_fresh_shader("after")
	elif _frame == 70:
		print("PROBE done")
		quit(0)
	return false

func _draw_fresh_shader(tag: String) -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float k_%s = %d.0;\nvoid fragment() { COLOR = vec4(UV, sin(TIME * k_%s) * 0.5 + 0.5, 1.0); }\n" % [tag, randi() % 1000 + 1, tag]
	var material := ShaderMaterial.new()
	material.shader = shader
	var rect := ColorRect.new()
	rect.material = material
	rect.size = Vector2(64, 64)
	rect.position = Vector2(20 + (0 if tag == "before" else 100), 20)
	root.add_child(rect)
	print("PROBE drew fresh shader ", tag, " at frame ", _frame)
