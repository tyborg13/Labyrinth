extends RefCounted
## Record the overlay's actual draw arguments on headless Godot, where canvas
## commands cannot be read back. The visual take uses the original draw calls.

static func compile_source(path: String, kind: String, capture_commands: bool = false) -> GDScript:
	var source: String = FileAccess.get_file_as_string(path)
	if source.is_empty(): return null
	var script := GDScript.new()
	script.resource_path = "res://tools/fx19/proof_" + kind + ".gd"
	if kind == "board":
		source = source.replace("class_name CombatBoardView", "")
		if capture_commands: source = _instrument_board(source)
	script.source_code = source
	return script if script.reload() == OK else null

static func _instrument_board(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var in_blink: bool = false
	for index: int in lines.size():
		var line: String = lines[index]
		if line.begins_with("func "):
			in_blink = line.begins_with("func _draw_blink_")
		if line == "\t_draw_protagonist_charge()":
			lines[index] = "\tif not _fx19_sampling: _draw_protagonist_charge()"
			continue
		if not in_blink: continue
		var call: String = line.strip_edges()
		if not call.begins_with("draw_") and not call.begins_with("_draw_tile_ring(") and not call.begins_with("_draw_blink_afterimage_ghost("):
			continue
		var open: int = call.find("(")
		var indent: String = line.substr(0, line.find(call))
		lines[index] = indent + "if _fx19_sampling: _fx19_record(%s, [%s])\n" % [JSON.stringify(call.substr(0, open)), call.substr(open + 1, call.rfind(")") - open - 1)] + indent + "else: " + call
	return "\n".join(lines) + """
var _fx19_sampling: bool
var _fx19_commands: Array

func _fx19_record(command: String, args: Array) -> void:
	for index: int in args.size():
		if args[index] is Texture2D: args[index] = args[index].resource_path
	_fx19_commands.append([command, args])
"""

static func _commands(board: Control, effect: Dictionary, progress: float) -> Array:
	var shown: Dictionary = board.presentation
	board.presentation = {"effect": effect, "effect_progress": progress}
	board._fx19_sampling = true
	board._fx19_commands.clear()
	board._draw_effect_overlay()
	board._fx19_sampling = false
	board.presentation = shown
	return board._fx19_commands.duplicate()

static func preview(board: Control, effect: Dictionary) -> Dictionary:
	var texture: Texture2D = board._effect_textures.get("blink_rift_preview")
	var authored: Array = _commands(board, effect, 0.5)
	board._effect_textures["blink_rift_preview"] = null
	var fallback: Array = _commands(board, effect, 0.5)
	board._effect_textures["blink_rift_preview"] = texture
	return {"authored": authored, "fallback": fallback}

static func resolved(board: Control, effect: Dictionary, progress: float) -> Array:
	return _commands(board, effect, progress).map(func(command: Array) -> String: return command[0])
