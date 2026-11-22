extends RefCounted
## All canonical keyword panels and every registered source/alias.
const Context = preload("res://scripts/tooltip_loop_context.gd")
const Registry = Context.Registry
const Icons = Context.Icons
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Data = preload("res://scripts/game_data.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const Playback = preload("res://tools/tooltip_loops/playback.gd")

static func audit(errors: Array[String]) -> void:
	var terms: Array = Context.Glossary.all_entries()
	var mentions := PackedStringArray()
	var sources: Array[Dictionary]
	sources.assign([{}, Context.enemy("crawler"), {"kind": "hero_card", "id": "quick_stab"}])
	for row: Dictionary in Registry.entries():
		mentions.append(Icons.label(row["term"]))
		var scope: Dictionary = row["source_match"].duplicate()
		if scope.has("ids"): scope["id"] = scope["ids"][0]
		if scope.get("kind") != "*" and not sources.has(scope): sources.append(scope)
		for id: String in row.get("grimoire_entries", []):
			sources.append({"kind": "grimoire", "id": id})
	var definition: String = " ".join(mentions)
	for source: Dictionary in sources:
		var unrelated: Control = Context.panel_for_text("Example heading\n" + definition, source)
		if unrelated != null:
			errors.append("A definition cannot route media for %s" % source)
			unrelated.free()
		for entry: Dictionary in terms:
			var term: String = entry["id"]
			var title: String = entry["name"]
			var expected: String = _expected(term, source)
			var panel: Control = Panels.make_icon_lines(null, title, PackedStringArray([definition]), term, source)
			_check(errors, panel, expected, term, source)
			if Context.Glossary.lookup(title).get("id") == term:
				_check(errors, Context.panel_for_text(title + "\n" + definition, source), expected, term, source)
	# A supplied key that has no clip must not fall back to a clip for the heading.
	_check(errors, Context.panel_for_text(Icons.tooltip("collision"), Context.enemy("crawler"), "flying"), "", "flying", Context.enemy("crawler"))
	for term: String in ["push", "pull", "flying"]:
		var source: Dictionary = Context.enemy("gust_shrike")
		var expected: String = "" if term == "flying" else term + "_card"
		_check(errors, Context.panel_for_text(Icons.tooltip(term), source), expected, term, source)
	for row: Dictionary in Registry.entries():
		var source: Dictionary = row["source_match"].duplicate()
		if source.has("ids"): source["id"] = source["ids"][0]
		for term: String in row.get("aliases", []):
			var panel: Control = Context.panel_for_text(Icons.label(term) + "\n" + definition, source, term)
			_check(errors, panel, _expected(term, source), term, source)

static func audit_feedback(tree: SceneTree, errors: Array[String]) -> void:
	var before: int = errors.size()
	_known_moves(errors)
	await _shatter_hover(tree, errors)
	print("TIP12 FEEDBACK ROUTES: %s" % ["PASS" if errors.size() == before else "FAIL"])

static func _known_moves(errors: Array[String]) -> void:
	var host: Node = preload("res://scenes/run_scene.tscn").instantiate()
	for case: Array in [["ember_tick", "scuttle", ""], ["cinder_ooze", "smolder_slide", ""], ["ember_tick", "kindle", "burst_ember_tick"]]:
		var source: Dictionary = Context.enemy(case[0])
		var intents: Array = Data.enemy_def(case[0])["intents"]
		var index: int = intents.find_custom(func(intent: Dictionary) -> bool: return intent["id"] == case[1])
		if index < 0:
			errors.append("Known Moves fixture missing authored move " + case[1])
			continue
		var move: Control = Inspection.build_move(host, intents[index], source)
		if move.tooltip_text.is_empty() != (case[2] == ""):
			errors.append("Known Moves hover must belong to its displayed keyword: " + case[1])
		var panel: Control = move._make_custom_tooltip(move.tooltip_text) if not move.tooltip_text.is_empty() else null
		_check(errors, panel, case[2], case[1], source)
		move.free()
	host.free()

static func _shatter_hover(tree: SceneTree, errors: Array[String]) -> void:
	var viewport: SubViewport = Playback.canvas(tree)
	var card: Control = CardScene.instantiate()
	card.configure("shatter")
	viewport.add_child(card)
	for frame: int in range(Playback.SETTLE_FRAMES): await tree.process_frame
	var condition: Control = card.find_child("SurfaceCondition", true, false)
	if condition == null:
		errors.append("Shatter must expose its Frozen-condition row")
	else:
		var checked: Array[String]
		for child: Control in condition.get_children():
			var local: Vector2 = card.get_global_transform().affine_inverse() * child.get_global_rect().get_center()
			var text: String = card.call("_get_tooltip", local)
			var panel: Control = card._make_custom_tooltip(text)
			var icon: TextureRect = panel.find_child("TooltipIcon", true, false) if panel != null else null
			if icon == null or icon.texture != Icons.icon_texture("freeze"):
				errors.append("Shatter hover must display the snowflake at " + str(child.name))
			var expected_term: String = "freeze" if child is TextureRect else "if_frozen"
			if card.get("_native_tooltip_route").get("term") != expected_term:
				errors.append("Shatter hover must carry the correct loop key at " + str(child.name))
			_check(errors, panel, "freeze_status", expected_term, {"kind": "hero_card", "id": "shatter"})
			if child is Label: checked.append(child.text)
		if checked != ["vs", ":"]: errors.append("Shatter proof must exercise both labels beside the snowflake")
	viewport.queue_free()
	await tree.process_frame

static func _expected(term: String, source: Dictionary) -> String:
	var row: Dictionary = Registry.find(term, source)
	return str(row["id"]) if Registry.media_available(row) else ""

static func _check(errors: Array[String], panel: Control, expected: String, term: String, source: Dictionary) -> void:
	var actual: Array[String]
	if panel != null:
		for window: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
			actual.append(str(window.get_meta("tooltip_loop_id", "")))
		panel.free()
	var wanted: Array[String]
	if not expected.is_empty(): wanted.append(expected)
	if actual != wanted:
		errors.append("%s panel for %s selected %s, expected %s" % [term, source, actual, wanted])
