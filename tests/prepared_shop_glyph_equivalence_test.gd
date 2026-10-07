extends "res://tests/retained_shop_rows_equivalence_test.gd"

const GlyphPreparation = preload("res://scripts/ui_glyph_preparation.gd")
const FontCache = preload("res://tests/fixtures/native_font_cache_probe.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ScavengerAction = preload("res://scripts/scavenger_action.gd")
var _checks: int = 0
var _pixel_differences: Array[Dictionary]
var _native: bool = false
var _presented: int = 0
var _owner_active: bool = true
var _boundary_action: String = ""
var _boundary_shop: Variant
var _boundary_font: Font
var _boundary_executed: bool = false
var _boundary_saw_outline: bool = false

func _run() -> void:
	_native = DisplayServer.get_name() != "headless"
	if _native: await _settle_native_window()
	var engine := Run.new()
	var state: Dictionary = FlowScript.new()._scavenger_state(engine)
	for reduced: bool in [false, true]:
		for held: int in [0, 10000]:
			state["held_embers"] = held
			await _pixel_case(state, engine, reduced)
	for action: String in ["cancel", "show", "detach", "free"]:
		await _ownership_case(state, engine, action)
	await _frame()
	await _frame()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Glyph preparation must retain no orphan owner or canvas nodes")
	print("PREPARED SHOP GLYPH RESULT: " + JSON.stringify({"cases": cases, "checks": _checks, "errors": errors, "differences": differences, "pixel_differences": _pixel_differences, "native": _native, "presented": _presented, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _pixel_case(state: Dictionary, engine: RefCounted, reduced: bool) -> void:
	var before: Dictionary = state.duplicate(true)
	var views: Array[SubViewport]
	var pair: Array[Control]
	for original: bool in [false, true]:
		var view := SubViewport.new()
		view.size = Vector2i(1920, 1080)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var shop: Control = ShopReference.new() if original else ShopScript.new()
		shop.visible = false
		view.add_child(shop)
		pair.append(shop)
	await _frame()
	pair[1].configure(state, engine, reduced)
	_owner_active = true
	await ShopScript.prepare_hidden_for(pair[0], state, engine, reduced, _present_glyph, _alive_glyph)
	pair[0].configure(state, engine, reduced)
	# Shaping collection must already be warm after the real preparation. It
	# cannot make this cache proof pass by adding the glyphs it is about to check.
	var before_collection: Dictionary = FontCache.capture(pair[0])["fonts"]
	var jobs: Array[Dictionary] = GlyphPreparation.collect_controls(pair[0])
	_check(FontCache.capture(pair[0])["fonts"] == before_collection, "Completed preparation must contain every final Label/Button fill cache before inspection")
	var server: TextServer = TextServerManager.get_primary_interface()
	_check(server.has_method("font_get_glyph_list"), "The native renderer must expose glyph-cache occupancy")
	for job: Dictionary in jobs:
		_check(is_equal_approx(float(job["oversampling"]), 1.0), "Native fixture must use the authored 1.0 oversampling")
		var cached: PackedInt32Array = server.call("font_get_glyph_list", job["rid"], job["size"])
		_check(cached.has(int(job["index"])), "The actual native cache must hold each prepared font RID, size, outline and glyph before first visible draw")
	var identities: Dictionary = pair[0]._offer_sources.duplicate()
	var presented_before: int = _presented
	await ShopScript.prepare_hidden_for(pair[0], state, engine, reduced, _present_glyph, _alive_glyph)
	_check(pair[0]._offer_sources == identities, "Warm native glyph preparation must retain actual offer owners")
	_check(_presented == presented_before, "Warm native preparation must not insert travel frames")
	for shop: Control in pair:
		shop._entry_played_for_room = true
		shop.show()
		for action: Node in shop.find_children("*", "Button", true, false):
			if action is ScavengerAction: action._process(0.0)
		_freeze_processes(shop)
		if shop._portrait != null: shop._portrait.call("apply_pose", "rest", 0.0)
	for frame: int in range(8): await _frame()
	var actual: Dictionary = _snapshot(pair[0], pair[0])
	var original: Dictionary = _snapshot(pair[1], pair[1])
	var label: String = "held %d reduced %s" % [state["held_embers"], str(reduced)]
	if actual != original: _print_differences(actual, original, label)
	_check(actual == original, "Prepared shop must preserve complete geometry, fonts, textures, prices and callbacks: " + label)
	_check(pair[0].semantic_snapshot() == pair[1].semantic_snapshot(), "Prepared shop must preserve merchant semantics: " + label)
	_check(state == before, "Native preparation must not mutate the committed destination")
	if _native:
		var a: Image = views[0].get_texture().get_image()
		var b: Image = views[1].get_texture().get_image()
		if a.get_data() != b.get_data():
			_pixel_differences.append({"case": cases, "label": label})
			_check(false, "Prepared and original native Scavenger pixels must match exactly: " + label)
		if cases == 0:
			a.save_png("user://prepared_shop_glyph_actual.png")
			b.save_png("user://prepared_shop_glyph_reference.png")
			print("PREPARED SHOP GLYPH IMAGE: " + ProjectSettings.globalize_path("user://prepared_shop_glyph_actual.png"))
	cases += 1
	for view: SubViewport in views: view.queue_free()
	await _frame()
	await _frame()

func _ownership_case(state: Dictionary, engine: RefCounted, action: String) -> void:
	var shop := ShopScript.new()
	shop.hide()
	root.add_child(shop)
	shop.configure(state, engine, false)
	shop._entry_played_for_room = true
	# A private font on a real hidden child makes a cold glyph slice observable
	# after stock is already warm. Production font resources remain untouched.
	var label := Label.new()
	label.name = "OwnedColdGlyphBoundary"
	_boundary_font = Typography.ui_font().duplicate(true)
	label.add_theme_font_override("font", _boundary_font)
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.text = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	shop.add_child(label)
	_boundary_shop = shop
	_boundary_action = action
	_boundary_executed = false
	_boundary_saw_outline = false
	_owner_active = true
	await ShopScript.prepare_hidden_for(shop, state, engine, false, _present_glyph, _alive_glyph)
	_check(_boundary_executed, "Each ownership case must cross an actual native glyph suspension: " + action)
	_check(_boundary_saw_outline, "Ownership change must occur after native outline rendering, not only stock building: " + action)
	if action == "free":
		_check(not is_instance_valid(shop), "A freed owner must terminate the actual hidden glyph path safely")
	else:
		if action == "detach":
			_check(not shop.is_inside_tree(), "Detached owner must terminate preparation safely")
			root.add_child(shop)
		if action == "show": _check(shop.visible, "Arrival showing the shop must abort hidden preparation")
		if is_instance_valid(label): label.free()
		shop.configure(state, engine, false)
		var reference := ShopReference.new()
		reference.hide()
		root.add_child(reference)
		reference.configure(state, engine, false)
		reference.visible = shop.visible
		_check(shop.semantic_snapshot() == reference.semantic_snapshot(), "Canceled glyph work must preserve the synchronous arrival fallback: " + action)
		shop.free()
		reference.free()
	_boundary_shop = null
	_boundary_font = null
	_boundary_action = ""
	_owner_active = true
	cases += 1
	await _frame()
	await _frame()

func _alive_glyph() -> bool:
	return _owner_active

func _present_glyph() -> void:
	_presented += 1
	if not _boundary_action.is_empty() and not _boundary_executed:
		_boundary_executed = true
		var server: TextServer = TextServerManager.get_primary_interface()
		for rid: RID in _boundary_font.get_rids():
			var cached: PackedInt32Array = server.call("font_get_glyph_list", rid, Vector2i(96, 12))
			if not cached.is_empty(): _boundary_saw_outline = true
		match _boundary_action:
			"cancel": _owner_active = false
			"show": _boundary_shop.show()
			"detach": _boundary_shop.get_parent().remove_child(_boundary_shop)
			"free": _boundary_shop.free()
	await _frame()

func _freeze_processes(node: Node) -> void:
	node.set_process(false)
	if node is ShopCard.RarityGemGlow:
		node._material.set_shader_parameter("phase", 0.0)
		node._material.set_shader_parameter("animate", 0.0)
	for child: Node in node.get_children(): _freeze_processes(child)

func _frame() -> void:
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame

func _settle_native_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920, 1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable == 20, "Native Scavenger proof must settle at 1920x1080 and 100% scale for a full second")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	super._check(ok, message)
