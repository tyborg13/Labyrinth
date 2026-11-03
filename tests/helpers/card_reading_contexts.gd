extends RefCounted

# Live production screens shared by headless layout checks and renderer proof.
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Magic = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const GraftSuite = preload("res://tests/suites/graftwright_suite.gd")
const Purge = preload("res://scripts/magic_purge_overlay.gd")
const SAFE_MARGIN: float = 24.0
const SETTLE_SECONDS: float = 0.4
const PROFILE_PATH: String = "user://pt13_03_reading_profile.json"
const RUN_PATH: String = "user://pt13_03_reading_run.save"
const SETTINGS_PATH: String = "user://pt13_03_reading_settings.json"
const SHOP_MAGIC_FIXTURE: Array = ["grave_mortar", "icicle_lance", "stonefist"]
const SHOP_GEAR_FIXTURE: Array = ["boiled_leather", "dust_tabi", "ward_kite"]
const SHOP_ITEM_FIXTURE: Array = ["crimson_draught", "nail_bomb", "smoke_bomb"]
const GRAFT_EQUIPMENT_FIXTURE: Array = ["training_sword", "iron_cleaver"]
const GRIMOIRE_EQUIPMENT_FIXTURE: String = "training_sword"
const UPGRADE_CARD_FIXTURE: String = "quick_stab"
const FIXTURE_PILE: Array = ["iron_wheel", "headlong", "quick_stab", "brace", "stonefist", "couched_lance", "iron_wheel", "headlong"]
var layouts: Array = []

func run(tree: SceneTree, surface: Control, expect: Callable, save: Callable) -> void:
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(RUN_PATH)
	Settings.set_storage_path(SETTINGS_PATH)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Store.default_data())
	Store.save_data(profile)
	Store.clear_saved_run()
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	surface.add_child(scene)
	await _settle(tree)
	# Production settings respect the desktop's usable rect. Proof owns an
	# exact 1920x1080 viewport, independently of that desktop clamp.
	tree.root.content_scale_size = Audit.VIEWPORT_SIZE
	tree.root.size = Audit.VIEWPORT_SIZE
	await _settle(tree)
	var engine := RunEngine.new()
	var state: Dictionary = Magic.shop_fixture(engine)
	state["attuned_magic_cards"] = Presentation.unique_cards(Presentation.OVERFLOW_IDENTITIES)
	state["rooms"]["2,1"][RunEngine.MERCHANT_STOCK_KEY] = SHOP_MAGIC_FIXTURE + SHOP_GEAR_FIXTURE + SHOP_ITEM_FIXTURE
	scene.call("_load_run_state", engine.repair_loaded_run_state(state))
	scene.call("_close_dialogue")
	await _settle(tree)
	var shop: Control = scene.get("_scavenger_shop_view")
	# Hidden preparation and returning from Sell must retain banner headroom.
	shop.hide()
	await _settle(tree)
	shop.show()
	await _settle(tree)
	var offers: Array = []
	for id: String in SHOP_MAGIC_FIXTURE:
		var button: Control = shop.find_child("MagicOffer_" + id, true, false)
		expect.call(button != null, "Scavenger proof has the fixed three-card offer row: " + id)
		if button != null:
			offers.append(button)
			var rest_scale: Vector2 = button.scale
			var rest_pivot: Vector2 = button.pivot_offset
			button.pivot_offset = button.size * 0.5
			button.scale = Vector2(1.045, 1.045)
			var banner: Control = shop.find_child("ScavengerShopBanner", true, false)
			var signage = preload("res://scripts/scavenger_signage.gd")
			var parchment: Rect2 = banner.get_global_transform() * signage.parchment_rect(banner.size)
			expect.call(signage.ware_rect(button).position.y + Audit.EPSILON >= parchment.end.y + 10.0, "Readable offer preserves existing 10px banner clearance after hidden preparation: " + id)
			button.scale = rest_scale
			button.pivot_offset = rest_pivot
	_record_row("scavenger_offer", offers, expect)
	_record_shelf_collisions(shop, offers)
	expect.call(layouts.filter(func(row: Dictionary) -> bool: return row["todo"] != "").is_empty(), "Original Scavenger shelf has no tag/art overlap")
	await save.call("scavenger_offer")
	# Native focus, without a pressed signal/click, exposes the full-size card.
	if not offers.is_empty():
		(offers[0] as Control).grab_focus()
		await _settle(tree)
		var detail_faces: Array = []
		_collect_faces(shop.get("_detail_card_host"), detail_faces)
		expect.call(detail_faces.size() == 1 and detail_faces[0].card_id == SHOP_MAGIC_FIXTURE[0] and detail_faces[0].size == Audit.Card.BASE_CARD_SIZE, "Scavenger focus exposes the same full-size card without activation")
		await save.call("scavenger_offer_focus")
	for source: String in ["scavenger", "campfire"]:
		var next: Dictionary = state.duplicate(true)
		if source == "campfire": next["mode"] = "campfire"
		scene.call("_load_run_state", engine.repair_loaded_run_state(next))
		scene.set("_animation_lock", false)
		scene.call("_close_dialogue")
		scene.call("_open_magic_purge", source)
		await _settle(tree)
		var modal: Control = scene.get("_magic_purge_overlay")
		expect.call(modal != null, "Live " + source + " purge opens")
		if modal != null:
			Presentation.assert_grid(modal, next["attuned_magic_cards"], expect)
			await save.call("purge_picker" if source == "scavenger" else "campfire")
			# This same production factory supplies the deck-view card faces.
			if source == "scavenger":
				var scroll: ScrollContainer = modal.find_child("MagicPurgeScroll", true, false)
				scroll.scroll_vertical = ceili(Audit.Pile.CARD_SIZE.y + Purge.CARD_GAP.y)
				await _settle(tree)
				expect.call(scroll.scroll_vertical > 0, "Reflowed deck grid retains row scrolling")
				await save.call("deck_view")
			scene.call("_close_magic_purge")
	# Graftwright has the widest equipment cardinality in each centred row.
	var graft_state: Dictionary = GraftSuite.fixture()
	graft_state["equipment_inventory"] = GRAFT_EQUIPMENT_FIXTURE.duplicate()
	scene.call("_load_run_state", engine.repair_loaded_run_state(graft_state))
	await _settle(tree)
	var graft: Control = scene.find_child("GraftwrightView", true, false)
	graft.call("begin_work")
	graft.call("select_donor", GRAFT_EQUIPMENT_FIXTURE[0])
	graft.call("select_recipient", GRAFT_EQUIPMENT_FIXTURE[1])
	graft.call("select_source", 0)
	graft.call("select_target", 0)
	await _settle(tree)
	for prefix: String in ["SourceCard_", "TargetCard_"]:
		var cards: Array = []
		for index: int in range(3):
			var card: Control = graft.find_child(prefix + str(index), true, false)
			expect.call(card != null, "Graftwright maximum three-card row: " + prefix + str(index))
			if card != null: cards.append(card)
		_record_row("graftwright", cards, expect, prefix.trim_suffix("_"))
	await save.call("graftwright")
	# A real combat pile uses pooled faces and its existing scrolling flow.
	var combat: Dictionary = {"deck": {"draw": FIXTURE_PILE.duplicate(), "discard": FIXTURE_PILE.duplicate(), "burn": []}}
	scene.set("_combat_state", combat)
	scene.call("_open_pile_view", "draw")
	await _settle(tree)
	expect.call(scene.get("_pile_scrim").visible, "Live pile viewer opens")
	var flow: Control = scene.get("_pile_dialog_cards")
	var first_y: float = -1.0
	var first_row: int = 0
	for child: Control in flow.get_children():
		if not child.visible: continue
		if first_y < 0: first_y = child.position.y
		if is_equal_approx(child.position.y, first_y): first_row += 1
	expect.call(first_row == 4, "Pile flow reflows five-card rows into four at its unchanged width")
	await save.call("pile_dialog")
	scene.call("_close_pile_view")
	# Unlock only a test profile entry; no production save or catalog values change.
	var run_state: Dictionary = scene.get("_run_state")
	run_state = preload("res://scripts/grimoire_library.gd").unlock_entries(run_state, ["equipment:" + GRIMOIRE_EQUIPMENT_FIXTURE])["state"]
	scene.set("_run_state", run_state)
	scene.call("_open_grimoire_overlay")
	scene.call("_on_grimoire_entry_pressed", "equipment:" + GRIMOIRE_EQUIPMENT_FIXTURE)
	await _settle(tree)
	var content: Control = scene.get("_grimoire_detail_content")
	var faces: Array = []
	_collect_faces(content, faces)
	expect.call(faces.size() == 3, "Grimoire proof displays all three Training Sword cards")
	if faces.size() == 3:
		expect.call(faces[0].get_global_rect().position.y < faces[2].get_global_rect().position.y, "Grimoire granted-card grid wraps inside the existing detail page")
	await save.call("grimoire_equipment")
	scene.call("_close_grimoire_overlay")
	# The retained card-upgrade screen is separate from the Character replacement.
	# Build its production implementation directly to cover every card-face caller.
	scene.call("_build_card_upgrade_overlay")
	scene.set("_upgrade_selected_card_id", UPGRADE_CARD_FIXTURE)
	scene.call("_refresh_card_upgrade_overlay")
	scene.get("_upgrade_scrim").show()
	await _settle(tree)
	var upgrade_bounds: Array = [scene.get("_upgrade_dialog"), scene.get("_upgrade_preview_box")]
	for row: Control in scene.get("_upgrade_option_list").get_children(): upgrade_bounds.append(row)
	_record_row("upgrade_preview", upgrade_bounds, expect)
	await save.call("upgrade_preview")
	scene.free()
	for frame: int in range(Audit.SETTLE_FRAMES): await tree.process_frame

func _record_shelf_collisions(shop: Control, offers: Array) -> void:
	# Reading faces retain the authored shelf positions. Surface any newly
	# exposed tag/art collision for the director; never move another shelf.
	for offer: Control in offers:
		var tag: Control = offer.find_child("ScavengerPriceTag", true, false)
		if tag == null: continue
		for gear_id: String in SHOP_GEAR_FIXTURE:
			var gear: Control = shop.find_child("GearOffer_" + gear_id, true, false)
			if gear == null: continue
			var art: Control = gear.find_child("WareArt", true, false)
			var icon: Control = art.get_child(0)
			var overlap: Rect2 = tag.get_global_rect().intersection(icon.get_global_rect())
			if overlap.has_area():
				layouts.append({"context": "scavenger_offer_shelf_overlap", "width": overlap.size.x, "height": overlap.size.y, "position": [overlap.position.x, overlap.position.y], "safe_area": true, "todo": "TODO_DESIGN_scavenger_offer_shelf_overlap", "objects": [str(offer.name) + "/ScavengerPriceTag", str(gear.name) + "/WareArt"]})

func _record_row(context: String, cards: Array, expect: Callable, row_name: String = "") -> void:
	var bounds := Rect2()
	for card: Control in cards:
		var rect: Rect2 = card.get_global_rect()
		var ancestor: Node = card.get_parent()
		while ancestor is Control:
			if ancestor.clip_contents: rect = rect.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if rect.size == Vector2.ZERO: continue
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	var safe := Rect2(Vector2.ONE * SAFE_MARGIN, Vector2(Audit.VIEWPORT_SIZE) - Vector2.ONE * SAFE_MARGIN * 2.0)
	var fits: bool = not cards.is_empty() and safe.encloses(bounds)
	layouts.append({"context": context, "row": row_name, "width": bounds.size.x, "height": bounds.size.y, "position": [bounds.position.x, bounds.position.y], "safe_area": fits, "todo": "" if fits else "TODO_DESIGN_" + context + "_overflow"})
	expect.call(fits, "Fixed row fits 24 px safe area: %s %s" % [context, bounds])

static func _collect_faces(node: Node, faces: Array) -> void:
	if node is Audit.Card and node.is_visible_in_tree(): faces.append(node)
	for child: Node in node.get_children(): _collect_faces(child, faces)

static func _settle(tree: SceneTree) -> void:
	await tree.create_timer(SETTLE_SECONDS).timeout
	for frame: int in range(Audit.SETTLE_FRAMES): await tree.process_frame
