extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Data = preload("res://scripts/game_data.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const Boon = preload("res://scripts/opening_boon_overlay.gd")
const Confirmation = preload("res://scripts/magic_purge_confirmation.gd")
const Fixture = preload("res://tests/helpers/card_display_fixture.gd")
const TEST_CARDS: Array = ["nail_bomb", "quick_stab"]
const TEST_VIEW_SIZE := Vector2(250, 352)
const TEST_GRAFT_POSITION := Vector2.ZERO
const BOOT_SETTLE_SECONDS: float = 0.4
const UPGRADE_RELICS: Array = ["bloodglass_knife"]
const UPGRADE_HEALTH: int = 12
const UPGRADE_MAX_HEALTH: int = 24
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var audit := Audit.new()
	audit.host = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(audit.host)
	await create_timer(BOOT_SETTLE_SECONDS).timeout
	var host: Node = audit.host
	host.call("_close_dialogue")
	var state: Dictionary = Fixture.shop(preload("res://scripts/run_engine.gd").new())
	host.set("_run_state", state)
	host.set("_combat_state", {})
	root.add_child(audit.graft)
	audit.graft.call("_ensure_built")
	audit.graft.set("_intro_open", false)
	var all_unmodified: bool = _all_unmodified()
	if all_unmodified:
		state["relics"] = []
		host.set("_run_state", state)
		host.get("_pile_dialog_pool_warm_cards").clear()
		host.call("_build_card_upgrade_overlay")
		var catalog: Array = ["quick_stab", "guarded_step", "cinder_trail", "fan_the_flames"] if OS.get_cmdline_user_args().has("--catalog-smoke") else Data.cards().keys()
		for id: String in catalog:
			await _card_views(audit, id, state)
			await _unmodified_upgrades(audit, id)
			for entry: Dictionary in host.get("_pile_dialog_card_pool"): entry["button"].free()
			host.get("_pile_dialog_card_pool").clear()
		print("CARD02 UNMODIFIED COVERAGE: %d catalog cards in every ID-built factory; current/available upgrade previews" % catalog.size())
	else:
		for id: String in TEST_CARDS:
			await _card_views(audit, id, state)
		await _upgraded_preview(audit, state)
		await _retained_shop(audit, state)
		await preload("res://tests/helpers/card_display_regressions.gd").run(self, host, _expect)
	# Pure extraction must not spend first-attack/Tempo flags or mutate the run.
	var original: PackedByteArray = var_to_bytes(state)
	Display.for_card("nail_bomb", state)
	_expect(var_to_bytes(state) == original, "Display calculation does not mutate run state")
	host.get("_pile_dialog_pool_warm_cards").clear()
	for frame: int in range(Audit.SETTLE_FRAMES): await process_frame
	audit.cleanup()
	for failure: String in _failures: push_error(failure)
	print("CARD DISPLAY OVERRIDES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _all_unmodified() -> bool:
	return OS.get_cmdline_user_args().has("--all-unmodified")

func _card_views(audit: RefCounted, id: String, state: Dictionary) -> void:
	var host: Node = audit.host
	var surface := Control.new()
	host.add_child(surface)
	var hand: Control = CardScene.instantiate()
	hand.configure(id, false, false, true, false, false, true, host.call("_card_def", id, state))
	var expected: Dictionary = host.call("_card_widget_display", id, state)
	hand.set_display_overrides(expected["summary_bbcode"], expected["modifier_lines"], expected["summary_rows"], expected.get("time_surcharge", 0))
	surface.add_child(hand)
	var faces: Dictionary = {}
	# Both the purge picker and campfire removal use this production cell.
	for context: String in ["deck", "campfire_remove", "purge_picker"]:
		var cell: Control = Audit.Pile.card_cell(host, id, 1, func(_id: String) -> void: pass)
		surface.add_child(cell)
		faces[context] = cell.widget
	var confirm := Confirmation.new()
	surface.add_child(confirm)
	confirm.configure(host)
	confirm.present(id, 0, false, true)
	faces["purge_confirmation"] = confirm.card
	audit.shop.set("_run_state", state)
	faces["scavenger"] = audit.shop.call("_build_native_scaled_card", surface, id, TEST_VIEW_SIZE, "Card02Shop", false)
	audit.graft.set("state", state)
	var choice: Control = audit.graft.call("_card", surface, id, TEST_GRAFT_POSITION, false, Color.WHITE, func() -> void: pass)
	faces["graftwright"] = choice.get("card_face")
	var boon := Boon.new()
	boon.set("_host", host)
	boon.set("_state", state)
	surface.add_child(boon)
	boon.call("_spell_choice", surface, id, 0, TEST_VIEW_SIZE, 0.0)
	faces["boons"] = surface.find_child("BoonSpellChoice_0_" + id, true, false)
	var rewards := HBoxContainer.new()
	surface.add_child(rewards)
	var focusable: Array[Control]
	host.call("_add_reward_choice_card", rewards, id, TEST_VIEW_SIZE, focusable)
	faces["rewards"] = focusable[0]
	var stack := preload("res://scripts/opening_boon_tooltip_stack.gd").new()
	surface.add_child(stack)
	var inspection: RefCounted = boon.get("_inspection")
	inspection.configure(stack)
	inspection.call("_show", faces["boons"])
	_expect(stack.get("_entries") == Icons.tooltip_entries_for_rows(hand.display_summary_rows()), id + ": boon inspection uses the displayed rows")
	var proxy: Control = host.call("_spawn_card_proxy", id, Rect2(Vector2.ZERO, TEST_VIEW_SIZE))
	surface.add_child(proxy)
	faces["purge_reward_proxy"] = Audit.find_card(proxy)
	var tooltip: Control = host.call("_build_card_preview_widget", id, TEST_VIEW_SIZE)
	surface.add_child(tooltip)
	faces["card_tooltip_grimoire_equipment"] = Audit.find_card(tooltip)
	# Exercise the retained combat pile construction in addition to the deck cell.
	var entry: Dictionary = host.call("_append_pile_dialog_card_pool_entry", id)
	faces["combat_pile"] = entry["widget"]
	entry["button"].show()
	host.get("_pile_scrim").show()
	for frame: int in range(Audit.SETTLE_FRAMES): await process_frame
	for context: String in faces:
		var face: Control = faces[context]
		_expect(face != null, id + ": production face exists in " + context)
		if face == null: continue
		_expect(face.display_summary_rows() == expected["summary_rows"], id + ": hand summary rows in " + context)
		_expect(_rendered_text(face) == _rendered_text(hand), id + ": rendered rich text and labels in " + context)
		_expect(Display.rules_text(id, face.call("_display_card_def"), face.display_summary_rows()) == Display.rules_text(id, hand.call("_display_card_def"), hand.display_summary_rows()), id + ": text-only inspection matches the hand in " + context)
		_expect(Icons.tooltip_entries_for_rows(face.display_summary_rows()) == Icons.tooltip_entries_for_rows(hand.display_summary_rows()), id + ": hand tooltips in " + context)
	if id == "nail_bomb" and (state.get("relics", []) as Array).has("quartermasters_ledger"):
		_expect(not bool(hand.call("_display_card_def").get("consume_on_play", false)) and bool(hand.call("_display_card_def").get("burn", false)), "Nail Bomb shows the Ledger's Exhaust transformation")
		_expect(expected != Display.for_card(id, {}), "Retort and Ledger change the fixture's text/rows")
	await _inspect_rules(audit.graft, choice, Display.rules_text(id, hand.call("_display_card_def"), hand.display_summary_rows()))
	# A live update refreshes the same nodes, without reopening or changing inputs.
	var clean: Dictionary = state.duplicate(true)
	clean["relics"] = []
	host.set("_run_state", clean)
	host.call("_refresh_ui_finish")
	host.get("_pile_scrim").show()
	_expect(stack.get("_entries") == Icons.tooltip_entries_for_rows(Display.for_card(id, clean)["summary_rows"]), id + ": open boon tooltip refreshes with the card")
	for context: String in faces:
		var face: Control = faces[context]
		if face == null or context == "purge_reward_proxy": continue
		var before: Control = CardScene.instantiate()
		before.configure(id, false, false, true, false, false)
		surface.add_child(before)
		await process_frame
		_expect(_rendered_text(face) == _rendered_text(before), id + ": no-modifier rendered bytes unchanged in " + context)
		_expect(Display.rules_text(id, face.call("_display_card_def"), face.display_summary_rows()) == Icons.card_rules_text(Data.card_def(id)), id + ": no-modifier inspection prose unchanged in " + context)
		_expect(var_to_bytes(face.display_summary_rows()) == var_to_bytes(Icons.rows_for_card(Data.card_def(id))), id + ": no-modifier row bytes unchanged in " + context)
		before.free()
	await _inspect_rules(audit.graft, choice, Icons.card_rules_text(Data.card_def(id)))
	host.set("_run_state", state)
	Display.refresh(host, state)
	host.get("_pile_scrim").hide()
	surface.free()

func _unmodified_upgrades(audit: RefCounted, id: String) -> void:
	var host: Node = audit.host
	host.set("_upgrade_selected_card_id", id)
	var elements: Array = Data.upgradeable_elements_for_card(id, {})
	host.set("_upgrade_selected_element_key", str(elements[0]["key"]) if not elements.is_empty() else "")
	host.call("_upgrade_refresh_options")
	host.get("_upgrade_scrim").show()
	await process_frame
	var current: Control = Audit.find_card(host.get("_upgrade_preview_box"))
	var baseline: Control = CardScene.instantiate()
	baseline.configure(id)
	host.add_child(baseline)
	_expect(var_to_bytes(current.display_summary_rows()) == var_to_bytes(Icons.rows_for_card(Data.card_def(id))), id + ": no-modifier upgrade current rows are byte-identical")
	_expect(_rendered_text(current) == _rendered_text(baseline), id + ": no-modifier upgrade current text is byte-identical")
	var element: Dictionary = host.call("_selected_upgrade_element")
	if not element.is_empty():
		var options: Array = Data.upgrade_options_for_element(id, element, host.get("_progression"))
		var children: Array[Node] = host.get("_upgrade_option_list").get_children()
		for index: int in range(options.size()):
			var definition: Dictionary = Data.preview_card_with_mod(id, options[index], {})
			var face: Control = Audit.find_card(children[index])
			baseline.configure(id, false, false, true, false, false, true, definition)
			_expect(var_to_bytes(face.display_summary_rows()) == var_to_bytes(Icons.rows_for_card(definition)), id + ": no-modifier upgraded rows are byte-identical")
			_expect(_rendered_text(face) == _rendered_text(baseline), id + ": no-modifier upgraded text is byte-identical")
	baseline.free()
	host.get("_upgrade_scrim").hide()
	await process_frame

func _inspect_rules(graft: Control, source: Control, expected: String) -> void:
	await graft.call("_open_inspection", source)
	var inspection: Control = graft.get("_inspection")
	_expect(inspection != null, "Graftwright opens its production inspection")
	if inspection == null: return
	var panel: Control = inspection.get_node("ExactRules")
	var body: Node = panel.get_child(0).get_child(1)
	var text: String = body.get_parsed_text() if body is RichTextLabel else str(body.get("text"))
	_expect(Audit.normalized_rules_text(text) == Audit.normalized_rules_text(expected), "Graftwright actual inspection text follows the face")
	graft.call("close_inspection")

func _upgraded_preview(audit: RefCounted, state: Dictionary) -> void:
	var host: Node = audit.host
	var preview_state: Dictionary = state.duplicate(true)
	preview_state["relics"] = UPGRADE_RELICS.duplicate()
	preview_state["player_hp"] = UPGRADE_HEALTH
	preview_state["player_max_hp"] = UPGRADE_MAX_HEALTH
	host.set("_run_state", preview_state)
	host.call("_build_card_upgrade_overlay")
	host.set("_upgrade_selected_card_id", "quick_stab")
	host.call("_refresh_card_upgrade_overlay")
	host.get("_upgrade_scrim").show()
	var current: Control = Audit.find_card(host.get("_upgrade_preview_box"))
	_expect(current.display_summary_rows() == Display.for_card("quick_stab", preview_state)["summary_rows"], "Campfire upgrade current card uses the hand projection")
	var rows: Array[Node] = host.get("_upgrade_option_list").get_children()
	_expect(not rows.is_empty(), "Upgrade fixture has authored options")
	if rows.is_empty(): return
	var face: Control = Audit.find_card(rows[0])
	var definition: Dictionary = face.call("_display_card_def")
	_expect(bool(definition.get("upgraded", false)), "Upgrade preview retains the upgraded definition")
	_expect(face.display_summary_rows() == Display.for_card("quick_stab", preview_state, definition)["summary_rows"], "Upgrade preview computes rows from upgraded numbers")
	var element: Dictionary = host.call("_selected_upgrade_element")
	var option: Dictionary = Data.upgrade_options_for_element("quick_stab", element, host.get("_progression"))[0]
	var changed: Dictionary = preview_state.duplicate(true)
	changed["relics"] = ["fencers_gloves"]
	changed["player_hp"] = UPGRADE_MAX_HEALTH
	changed["turn_flags"] = {"cards_finished": 1}
	Display.refresh(host, changed)
	var independent: Dictionary = Data.preview_card_with_mod("quick_stab", option, changed)
	_expect(independent != definition, "Upgrade refresh fixture changes the authored definition, not only runtime damage")
	_expect(int(face.get("_time_badge").get("value")) == int(independent["time"]), "Refreshed upgrade Time badge matches independently resolved pricing")
	_expect(face.call("_display_card_def") == independent, "Refreshed upgrade definition matches an independently resolved option")
	_expect(face.display_summary_rows() == Display.for_card("quick_stab", changed, independent)["summary_rows"], "Refreshed upgrade numbers and rows match the independent definition")

	host.set("_run_state", state)

func _retained_shop(audit: RefCounted, state: Dictionary) -> void:
	var shop: Control = audit.shop
	root.add_child(shop)
	var engine := preload("res://scripts/run_engine.gd").new()
	var run: Dictionary = Fixture.shop(engine)
	shop.configure(run, engine, true)
	var source: Control = shop.find_child("ItemOffer_nail_bomb", true, false)
	_expect(source != null, "Real shop fixture offers Nail Bomb")
	if source == null: return
	shop.call("_select_item", "nail_bomb", false, source)
	var face: Control = Audit.find_card(shop.get("_detail_card_host"))
	var instance_id: int = face.get_instance_id()
	run["relics"] = []
	shop.configure(run, engine, true)
	_expect(face.get_instance_id() == instance_id and face.display_summary_rows() == Display.for_card("nail_bomb", run)["summary_rows"], "Retained shop detail refreshes without changing card id")

static func _rendered_text(node: Node) -> PackedByteArray:
	var text: Array = []
	for child: Node in node.get_children(): _collect_text(child, text)
	return var_to_bytes(text)

static func _collect_text(node: Node, result: Array) -> void:
	if node is Window or node.is_queued_for_deletion() or node.name == "RewardOwnershipBadge" or (node is CanvasItem and not node.visible): return
	if node is Label or node is RichTextLabel:
		# Card size changes markup sizes, never the authored text or icon payload.
		result.append([node.get_class(), node.text])
	for child: Node in node.get_children(): _collect_text(child, result)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
