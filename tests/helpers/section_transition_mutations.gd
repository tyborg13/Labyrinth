extends RefCounted
## In-memory mutation proof: checkout sources and assertions remain untouched.
const Observer = preload("res://tests/helpers/section_transition_observer.gd")
static var _scripts: Array[GDScript]

static func apply(name: String) -> bool:
	var path: String
	var before: String
	var after: String
	match name:
		"arrival_guard":
			path = "scripts/section_transition.gd"
			before = "and not _entered and elapsed"
			after = "and elapsed"
		"board_flash":
			path = "scripts/section_transition.gd"
			before = "_black.modulate.a = 1.0 # Opaque coverage remains behind both presentations."
			after = "_black.modulate.a = 0.0 # Deliberately expose the board outside the painting."
		"entered_guard":
			path = "scripts/start_room_map_flow.gd"
			before = 'if info.is_empty() or bool(info.get("entered", false)):'
			after = "if info.is_empty():"
		"destination_guard":
			path = "scripts/start_room_map_flow.gd"
			before = "\tif destination == Graph.INVALID or destination != next_section_destination(state, engine): return state.duplicate(true)\n"
		"retry_bypass":
			path = "scripts/run_scene.gd"
			before = '\tif _run_state.has(preload("res://scripts/section_transition.gd").CLAIMED_REWARD_KEY):\n\t\t_run_state = preload("res://scripts/section_transition.gd").claimed_state(_run_state)\n\t\t_begin_section_transition("auto_transition")\n\t\treturn\n'
		"notice_literal":
			path = "scripts/section_transition.gd"
			before = "Could not save. Your rewards are still here; try Continue again."
			after = "Could not save. Your rewards are still here; try Continue again!"
		_:
			push_error("Unknown section-transition mutation: " + name)
			return false
	var source: String = FileAccess.get_file_as_string("res://" + path)
	if source.count(before) != 1:
		push_error("Mutation must replace exactly one source site: " + name)
		return false
	source = source.replace(before, after)
	if path == "scripts/run_scene.gd":
		Observer.source_overrides[path] = source
	else:
		var script := GDScript.new()
		script.take_over_path("res://" + path)
		script.source_code = source
		if script.reload() != OK: return false
		_scripts.append(script)
	print("SECTION TRANSITION MUTANT: " + name)
	return true
