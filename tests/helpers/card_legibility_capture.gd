extends RefCounted

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const ProofViewport = preload("res://tests/helpers/card_legibility_viewport.gd")
const OUTPUT: String = "res://tests/pt13_03/feedback2/captures/after"
# Proof-only placement, never used by the game.
const CARD_ORIGIN := Vector2(420, 240)
const COLUMN_GAP: float = 420.0
const HAND_ORIGIN := Vector2(140, 600)
const HAND_EXTENT := Vector2(1640, 420)
const CAPTURE_SETTLE_SECONDS: float = 0.3
const EQUIPMENT_LOCKED_FIXTURE: bool = true
const HAND_FIXTURE: Array = ["quick_stab", "iron_wheel", "headlong", "guarded_step", "rallying_breath"]
const COVERAGE_OUTPUT: String = "res://tests/pt13_03/pt13_08/captures"

static func run_coverage_gaps(tree: SceneTree, audit: RefCounted, expect: Callable, capture: bool) -> void:
	var live := preload("res://tests/helpers/card_legibility_contexts.gd").new()
	await live.setup(tree, 1, true)
	var viewport: SubViewport = live.workers[0]["viewport"]
	ProofViewport.verify(tree, viewport, expect)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COVERAGE_OUTPUT))
	var records: Array = []
	for context: Dictionary in audit.contexts():
		if not ["chronicle_card", "chronicle_equipment", "graftwright_inspection"].has(context["id"]): continue
		var faces: Array = await live.open(context)
		expect.call(faces.size() == 1, "Coverage proof opens the native face: " + context["id"])
		if faces.is_empty(): continue
		var settled: Dictionary = await preload("res://tests/helpers/card_legibility_settle.gd").wait_for(tree, faces)
		expect.call(settled["settled"], "Coverage proof settles: " + context["id"])
		var measured: Dictionary = Audit.measure(faces[0], live.workers[0].get("initial_definition", {}))
		expect.call(Audit.floor_errors(measured).is_empty(), "Native coverage proof meets the rules/icon floors: " + context["id"])
		if str(context["id"]).begins_with("chronicle"):
			var menu: Control = live.workers[0]["menu"]
			var panel: Control = menu.get("_chronicle")
			expect.call(panel.get_parent() == menu and panel.is_ancestor_of(faces[0]) and not menu.get("menu_column").visible, "Coverage proof retains MainMenu's Chronicle open hierarchy")
		else:
			expect.call(measured.get("rules_body_visible", false) and measured.get("rules_body_nonempty", false), "Coverage proof contains the real Graftwright rules body")
		var record: Dictionary = {"image": context["id"] + ".png", "node_path": str(faces[0].get_path()), "measurement": measured, "production_ancestors": settled["ancestors"], "settled_frames": settled["stable_frames"], "image_size": null}
		records.append(record)
		if not capture: continue
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var valid: bool = ProofViewport.image_matches(image)
		expect.call(valid, "1920x1080 coverage capture: " + context["id"])
		if image != null: record["image_size"] = [image.get_width(), image.get_height()]
		if valid: expect.call(image.save_png(COVERAGE_OUTPUT.path_join(record["image"])) == OK, "Save " + context["id"])
	var file := FileAccess.open(COVERAGE_OUTPUT.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"viewport": [viewport.size.x, viewport.size.y], "ui_scale": 1.0, "captures": records}, "\t") + "\n")
	live.cleanup()
	print(ProjectSettings.globalize_path(COVERAGE_OUTPUT))

static func run(tree: SceneTree, audit: RefCounted, expect: Callable, capture: bool) -> void:
	var output: String = OUTPUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport: SubViewport = ProofViewport.create(tree, capture)
	ProofViewport.verify(tree, viewport, expect)
	var surface := Control.new()
	surface.size = Vector2(Audit.VIEWPORT_SIZE)
	viewport.add_child(surface)
	var metadata: Array = []
	var contexts: Array = audit.contexts()
	var equipment_builder := Audit.Previews.new()
	equipment_builder.equipment_locked = EQUIPMENT_LOCKED_FIXTURE
	var panel: Control = equipment_builder.equipment_tooltip("ironshod_sabatons")
	panel.position = CARD_ORIGIN
	surface.add_child(panel)
	await _save(tree, surface, output, "sabatons_equipment", expect, capture, metadata)
	_clear(surface)
	for focused: int in [-1, 1, 2]:
		var hand: Dictionary = contexts.filter(func(c: Dictionary) -> bool: return c["id"] == "hand_1_rest")[0]
		var fan := Audit.Fan.new()
		fan.position = HAND_ORIGIN
		fan.size = HAND_EXTENT
		surface.add_child(fan)
		for id: String in HAND_FIXTURE:
			var instance: Dictionary = audit.make_card({"factory": "scaled", "size": hand["size"]}, {"id": id, "definition": Audit.Data.card_def(id)})
			(instance["widget"] as Control).set_hover_pose(0.0, 1.0)
			fan.add_child(instance["surface"])
		fan.configure_layout(audit.host.call("_hand_layout_gap", HAND_FIXTURE.size(), hand["size"]), true)
		fan.set_emphasized_index(focused, false)
		await _save(tree, surface, output, "hand_rest" if focused < 0 else "hand_focus_" + str(HAND_FIXTURE[focused]), expect, capture, metadata)
		_clear(surface)
	for index: int in range(2):
		var tooltip: Control = Audit.Previews.new().card_tooltip(["iron_wheel", "headlong"][index])
		tooltip.position = CARD_ORIGIN + Vector2(COLUMN_GAP * index, 0)
		surface.add_child(tooltip)
	await _save(tree, surface, output, "card_tooltips", expect, capture, metadata)
	_clear(surface)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/pt13_03/audit.json"))
	var definitions: Array = Audit.definitions()
	for exempt: bool in [true, false]:
		var candidates: Array = (report["samples"] as Array).filter(func(s: Dictionary) -> bool: return exempt or s["exemption"] == "")
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left: float = _minimum_text(a)
			var right: float = _minimum_text(b)
			return str(a["card"]) + str(a["context"]) + str(a["variant"]) < str(b["card"]) + str(b["context"]) + str(b["variant"]) if left == right else left < right
		)
		var used: Array = []
		for sample: Dictionary in candidates:
			if used.has(sample["card"]): continue
			var context: Dictionary = contexts.filter(func(c: Dictionary) -> bool: return c["id"] == sample["context"])[0]
			var entry: Dictionary = definitions.filter(func(e: Dictionary) -> bool: return e["id"] == sample["card"] and e["variant"] == sample["variant"])[0]
			var instance: Dictionary = audit.make_card(context, entry)
			(instance["widget"] as Control).set_meta("audit_variant", entry["variant"])
			(instance["surface"] as Control).position = CARD_ORIGIN + Vector2(COLUMN_GAP * used.size(), 0)
			surface.add_child(instance["surface"])
			used.append(sample["card"])
			if used.size() == 3: break
		await _save(tree, surface, output, "smallest_all" if exempt else "smallest_non_exempt", expect, capture, metadata)
		_clear(surface)
	var reading := preload("res://tests/helpers/card_reading_contexts.gd").new()
	await reading.run(tree, surface, expect, func(name: String) -> void: await _save(tree, surface, output, name, expect, capture, metadata))
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": "after", "capture_viewport": viewport.get_class(), "viewport": [viewport.size.x, viewport.size.y], "ui_scale": 1.0, "widget_sha256": FileAccess.get_sha256("res://scripts/card_widget.gd"), "previews_sha256": FileAccess.get_sha256("res://scripts/item_preview_builders.gd"), "captures": metadata, "fixed_rows": reading.layouts, "sources": _source_hashes()}, "\t") + "\n")
	ProofViewport.dispose(viewport)
	print("CARD LEGIBILITY CAPTURE DIR: " + ProjectSettings.globalize_path(output))
	# The visual runner discovers res:// proof output from bare absolute paths.
	print(ProjectSettings.globalize_path(output))

static func _source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["card_widget", "item_preview_builders", "scavenger_shop_view", "graftwright_view", "pile_dialog_view", "magic_purge_overlay", "run_scene"]:
		hashes[path] = FileAccess.get_sha256("res://scripts/" + path + ".gd")
	return hashes

static func _minimum_text(sample: Dictionary) -> float:
	var result: float = INF
	for px: Variant in (sample["text_px"] as Dictionary).values():
		if px != null: result = minf(result, float(px))
	return result

static func _clear(surface: Control) -> void:
	for child: Node in surface.get_children(): child.free()

static func _save(tree: SceneTree, surface: Control, output: String, name: String, expect: Callable, capture: bool, metadata: Array) -> void:
	for frame: int in range(Audit.SETTLE_FRAMES): await tree.process_frame
	var cards: Array = []
	_collect(surface, cards)
	var viewport: SubViewport = surface.get_viewport() as SubViewport
	expect.call(viewport != null and viewport.size == Audit.VIEWPORT_SIZE, "Capture source is the native 1920x1080 SubViewport: " + name)
	var record: Dictionary = {"image": name + ".png", "cards": cards, "capture_viewport": "SubViewport", "image_size": null}
	metadata.append(record)
	expect.call(not cards.is_empty(), "Capture has live production card faces: " + name)
	if not capture or viewport == null: return
	await tree.create_timer(CAPTURE_SETTLE_SECONDS).timeout
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var valid: bool = ProofViewport.image_matches(image)
	expect.call(valid, "1920x1080 capture: " + name)
	if image != null: record["image_size"] = [image.get_width(), image.get_height()]
	if valid: expect.call(image.save_png(output.path_join(name + ".png")) == OK, "Save " + name)

static func _collect(node: Node, cards: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Audit.Card:
		cards.append({"id": node.card_id, "variant": node.get_meta("audit_variant", "base"), "measurement": Audit.measure(node)})
	for child: Node in node.get_children(): _collect(child, cards)
