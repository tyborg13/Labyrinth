extends RefCounted

# Each worker uses the owning production screen in a 1920x1080 viewport.
# Only the definition of its live, production-created face changes per sample.
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const ProofViewport = preload("res://tests/helpers/card_legibility_viewport.gd")
const Run = preload("res://scripts/run_engine.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Magic = preload("res://tests/suites/magic_deck_suite.gd")
const GraftFixture = preload("res://tests/suites/graftwright_suite.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const POOL_SIZE: int = 16
const FIXTURE_CARD: String = "iron_wheel"
const FIXTURE_MAGIC: String = "stonefist"
const FIXTURE_EQUIPMENT: String = "ironshod_sabatons"
const CHRONICLE_FIXTURE_DATE: Dictionary = {"day": 1, "month": 1}
const CHRONICLE_FIXTURE_OUTCOME: String = "defeat"
const CHRONICLE_FIXTURE_SCORE: Dictionary = {}
const PROFILE_PATH: String = "user://pt13_03_live_audit_profile.json"
const RUN_PATH: String = "user://pt13_03_live_audit_run.save"
const SETTINGS_PATH: String = "user://pt13_03_live_audit_settings.json"
var workers: Array = []
var engine := Run.new()
var combat_fixture: Dictionary
var chronicle_profile: Dictionary

func setup(tree: SceneTree, count: int, proof: bool = false) -> void:
	Profile.set_storage_path(PROFILE_PATH)
	Profile.set_run_storage_path(RUN_PATH)
	Settings.set_storage_path(SETTINGS_PATH)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Profile.default_data())
	Profile.save_data(profile)
	Profile.clear_saved_run()
	for seed_value: int in range(1, 120):
		var initial: Dictionary = engine.create_new_run(seed_value, profile)
		for coord: Vector2i in engine.available_moves(initial):
			var candidate: Dictionary = engine.move_to_room(initial, coord)
			if candidate.get("mode") in ["combat", "pre_battle"]:
				combat_fixture = engine.begin_pre_battle_combat(candidate) if candidate.get("mode") == "pre_battle" else candidate
				break
		if not combat_fixture.is_empty(): break
	print("LIVE AUDIT: combat fixture mode=" + str(combat_fixture.get("mode", "missing")))
	var recorded: Dictionary = combat_fixture.duplicate(true)
	recorded["deck_cards"] = [FIXTURE_CARD]
	recorded["equipped_equipment"] = {"feet": FIXTURE_EQUIPMENT}
	profile[Profile.CHRONICLE_RECORDS_KEY] = [preload("res://scripts/chronicle_rules.gd").build_record(recorded, CHRONICLE_FIXTURE_OUTCOME, CHRONICLE_FIXTURE_SCORE, CHRONICLE_FIXTURE_DATE)]
	chronicle_profile = profile.duplicate(true)
	Profile.save_data(profile)
	for index: int in range(count):
		var viewport: SubViewport = ProofViewport.create(tree, DisplayServer.get_name() != "headless") if proof else SubViewport.new()
		viewport.name = "AuditViewport_%d" % index
		viewport.size = Audit.VIEWPORT_SIZE
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		if not viewport.is_inside_tree(): tree.root.add_child(viewport)
		var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
		viewport.add_child(scene)
		workers.append({"viewport": viewport, "scene": scene, "face": null, "extras": []})
	# Finish bootstrap presentation before replacing the opening state; cancelling
	# a boot tween would strand the production coroutine awaiting its completion.
	var roots: Array = workers.map(func(worker: Dictionary) -> Node: return worker["scene"])
	await Settle.wait_for(tree, roots)

func cleanup() -> void:
	for worker: Dictionary in workers: ProofViewport.dispose(worker["viewport"])
	workers.clear()

func open(context: Dictionary) -> Array:
	print("LIVE AUDIT OPEN: " + context["id"])
	var router: Node = workers[0]["scene"].get_node("/root/InputRouter")
	router.call("set_forced_state_for_test", "controller" if context["id"] == "hand_controller_focused" else "pointer", "xbox")
	var faces: Array = []
	for worker: Dictionary in workers:
		var scene: Node = worker["scene"]
		scene.show()
		if worker.has("menu"): worker["menu"].hide()
		for node: Node in worker["extras"]:
			if is_instance_valid(node): node.free()
		worker["extras"].clear()
		for method: String in ["_close_magic_purge", "_close_pile_view", "_close_grimoire_overlay", "_close_card_upgrade_overlay"]: scene.call(method)
		var id: String = context["id"]
		if id.begins_with("chronicle"):
			scene.hide()
			if not worker.has("menu"):
				var menu: Control = preload("res://scenes/main_menu.tscn").instantiate()
				worker["viewport"].add_child(menu)
				worker["menu"] = menu
			worker["menu"].show()
			# Earlier RunScene contexts may persist their own default progression.
			# Restore this context's fixture before the real open path reads disk.
			Profile.save_data(chronicle_profile)
			# The real button opens the MainMenu-owned panel, loads the stored
			# record, and creates its native tile/icon preview builders.
			worker["menu"].get("chronicle_button").pressed.emit()
			var panel: Control = worker["menu"].get("_chronicle")
			var anchor: Control = panel.find_child("Gear_" + FIXTURE_EQUIPMENT if id == "chronicle_equipment" else "Spell_" + FIXTURE_CARD, true, false)
			if anchor != null: panel.call("_show_focus_tooltip", anchor)
			worker["face"] = Audit.find_card(panel.get("_focus_tooltip"))
			if worker["face"] != null: faces.append(worker["face"])
			continue
		var state: Dictionary = combat_fixture.duplicate(true)
		state["combat_state"]["deck"]["hand"] = []
		for index: int in range(int(context.get("count", 1))): state["combat_state"]["deck"]["hand"].append(FIXTURE_CARD)
		state["combat_state"]["deck"]["draw"] = [FIXTURE_CARD]
		state["combat_state"]["deck"]["discard"] = [FIXTURE_CARD]
		if id.begins_with("scavenger") or id in ["deck_view", "campfire", "purge_picker", "purge_confirmation"]:
			state = Magic.shop_fixture(engine)
			if not id.begins_with("scavenger"): state["attuned_magic_cards"] = [FIXTURE_MAGIC]
			if id == "scavenger_sell": state["magic_inventory"] = [FIXTURE_MAGIC]
			state["rooms"]["2,1"][Run.MERCHANT_STOCK_KEY] = [FIXTURE_MAGIC]
			if id == "campfire": state["mode"] = "campfire"
		if id == "graftwright" or id == "graftwright_inspection":
			state = GraftFixture.fixture()
			state["equipment_inventory"] = ["training_sword", "iron_cleaver"]
		scene.call("_load_run_state", state)
		scene.call("_close_dialogue")
		scene.set("_animation_lock", false)
		var face: Control
		if id.begins_with("hand_"):
			face = Audit.find_card(scene.call("_hand_card_control", 0))
			var fan: Control = scene.get("hand_box")
			if context.get("pose") != "rest": fan.call("set_emphasized_index", 0, false, Audit.Fan.TARGETING_EMPHASIS_SCALE if context.get("pose") == "targeting" else Audit.Fan.DEFAULT_EMPHASIS_SCALE)
		elif id.begins_with("scavenger"):
			var shop: Control = scene.get("_scavenger_shop_view")
			match id:
				"scavenger_offer": face = Audit.find_card(shop.find_child("MagicOffer_" + FIXTURE_MAGIC, true, false))
				"scavenger_sell":
					shop.configure(state, engine, true)
					shop.call("_set_pack_mode", true)
					face = Audit.find_card(shop.get("_sell_row"))
				"scavenger_receipt":
					shop.call("_show_receipt", FIXTURE_MAGIC, 1, false)
					face = Audit.find_card(shop.get("_receipt_visual"))
				"scavenger_detail":
					shop.call("_select_item", FIXTURE_MAGIC, false, shop.find_child("MagicOffer_" + FIXTURE_MAGIC, true, false))
					face = Audit.find_card(shop.get("_detail_card_host"))
		elif id in ["campfire", "purge_picker", "purge_confirmation", "deck_view"]:
			scene.call("_open_magic_purge", "campfire" if id == "campfire" else "scavenger")
			var modal: Control = scene.get("_magic_purge_overlay")
			if id == "purge_confirmation":
				modal.call("select_card", FIXTURE_MAGIC)
				face = modal.get("_confirmation").get("card")
			else: face = Audit.find_card(modal.get("_grid"))
		elif id == "pile_dialog":
			scene.call("_open_pile_view", "draw")
			for pooled: Dictionary in scene.get("_pile_dialog_card_pool"):
				if pooled["button"].is_visible_in_tree():
					face = pooled["widget"]
					break
		elif id in ["grimoire", "grimoire_equipment"]:
			scene.call("_open_grimoire_overlay")
			var content: Control = scene.get("_grimoire_detail_content")
			scene.call("_clear_children_now", content)
			scene.call("_populate_grimoire_equipment_detail" if id == "grimoire_equipment" else "_populate_grimoire_card_detail", "ironshod_sabatons" if id == "grimoire_equipment" else FIXTURE_CARD)
			face = Audit.find_card(content)
		elif id in ["graftwright", "graftwright_inspection"]:
			var view: Control = scene.find_child("GraftwrightView", true, false)
			view.call("begin_work")
			view.call("select_donor", "training_sword")
			view.call("select_recipient", "iron_cleaver")
			face = Audit.find_card(view.find_child("SourceCard_0", true, false))
			if id == "graftwright_inspection":
				view.call("_open_inspection", view.find_child("SourceCard_0", true, false))
				face = view.get("_inspection").get_node("ExactRules")
				worker["initial_definition"] = Audit.Data.card_def(str(view.find_child("SourceCard_0", true, false).get_meta("graft_card_id")))
		elif id == "upgrade_preview":
			scene.call("_build_card_upgrade_overlay")
			scene.set("_upgrade_selected_card_id", "quick_stab")
			scene.call("_refresh_card_upgrade_overlay")
			scene.get("_upgrade_scrim").show()
			face = Audit.find_card(scene.get("_upgrade_preview_box"))
		elif id == "reward_offers":
			state["mode"] = "reward"
			state["pending_reward"] = {"cards": [FIXTURE_CARD, "headlong", "stonefist"], "heal_amount": 1}
			scene.call("_load_run_state", state)
			face = Audit.find_card(scene.get("_relic_choice_bar"))
		elif id == "boon_spells":
			var overlay := preload("res://scripts/opening_boon_overlay.gd").new()
			scene.get("ui_root").add_child(overlay)
			worker["extras"].append(overlay)
			var boon: Dictionary = BoonFixture.force_boon("elemental_gift")
			overlay.configure(scene, boon)
			overlay.select_offer(boon[preload("res://scripts/opening_boon_rules.gd").STATE_KEY]["offers"][0])
			face = Audit.find_card(overlay.get("_content"))
		elif id.begins_with("card_fx_staged"):
			var settings: Dictionary = scene.get("_settings")
			settings["reduced_motion"] = id.ends_with("reduced_motion")
			scene.set("_settings", settings)
			var rect: Rect2 = scene.call("_hand_card_global_rect", 0)
			var proxy: Control = await scene.call("_animate_card_play_fx", FIXTURE_CARD, rect, rect.size)
			face = Audit.find_card(proxy)
			worker["extras"].append(proxy)
		elif id == "card_drag_proxy":
			var rect: Rect2 = scene.call("_hand_card_global_rect", 0)
			var proxy: Control = scene.call("_spawn_card_proxy", FIXTURE_CARD, rect)
			scene.call("_mount_card_proxy", proxy, scene.get("_card_fx_layer"), rect)
			proxy.scale *= scene.CARD_DRAG_FOLLOW_SCALE
			worker["extras"].append(proxy)
			face = Audit.find_card(proxy)
		else:
			# Controller loadout previews use this production overlay and mounting path.
			scene.call("_open_character_overlay", "equipment")
			var panel: Control = scene.call("_build_equipment_tooltip_panel", "ironshod_sabatons") if id == "equipment_tooltip" else scene.call("_build_card_tooltip_panel", FIXTURE_CARD)
			panel.name = "ControllerLoadoutTooltip"
			scene.get("_upgrade_scrim").add_child(panel)
			worker["extras"].append(panel)
			face = Audit.find_card(panel)
		worker["face"] = face
		if face != null: faces.append(face)
	return faces

func configure_face(worker: Dictionary, entry: Dictionary, context: Dictionary) -> void:
	var face: Control = worker["face"]
	if not face is Audit.Card:
		# Rebuild the production text-only popover for each changed definition.
		var view: Control = worker["scene"].find_child("GraftwrightView", true, false)
		var source: Control = Audit.find_card(view.find_child("SourceCard_0", true, false))
		source.configure(entry["id"], false, false, true, false, false, true, entry["definition"])
		source.set_display_overrides("", [], entry.get("rows", Audit.Icons.rows_for_card(entry["definition"])))
		view.find_child("SourceCard_0", true, false).set_meta("graft_card_id", entry["id"])
		view.call("close_inspection")
		view.call("_open_inspection", view.find_child("SourceCard_0", true, false))
		worker["face"] = view.get("_inspection").get_node("ExactRules")
		return
	face.set_display_overrides()
	face.configure(entry["id"], context.get("pose") == "targeting", false, true, false, false, true, entry["definition"])
	face.set_display_overrides("", [], entry.get("rows", []), int(entry.get("time_surcharge", 0)))
