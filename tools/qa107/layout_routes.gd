extends RefCounted
## Additional views reached with the owning screen's production openers.

const EventRules = preload("res://scripts/event_rules.gd")
const GraftRules = preload("res://scripts/graftwright_rules.gd")
const GRIMOIRE_QUERY: String = "burn"

static func visit(host: SceneTree, screen: String) -> void:
	var scene: Node = host.scene
	match screen:
		"title":
			scene.call("_on_settings_button_pressed")
			await host.inspect("title/settings", scene.get("settings_panel"))
			scene.call("_on_settings_back_button_pressed")
			scene.call("_on_chronicle_button_pressed")
			await host.inspect("title/chronicle", scene.get("_chronicle"))
			scene.get("_chronicle").call("close")
		"start":
			scene.call("_open_menu_overlay")
			await host.inspect("start/menu", scene.get("_menu_scrim"))
			scene.call("_close_menu_overlay")
		"character", "character_inventory":
			for tab: String in ["equipment", "magic", "skills"]:
				scene.call("_open_character_overlay", tab)
				await host.inspect(screen + "/" + tab, scene.get("_upgrade_scrim"))
				scene.call("_close_card_upgrade_overlay")
		"combat":
			for pile: String in ["draw", "discard", "burned"]:
				scene.call("_open_pile_view", pile)
				await host.inspect("combat/pile_" + pile, scene.get("_pile_scrim"))
				scene.call("_close_pile_view")
		"pre_battle":
			var preview: Dictionary = scene.get("_pre_battle_preview_run_state")
			var enemies: Array = preview.get("combat_state", {}).get("enemies", [])
			if not enemies.is_empty():
				var enemy: Dictionary = enemies[0]
				var button: Control = scene.find_child("PreBattleEnemyCard", true, false)
				scene.call("_open_pinned_pre_battle_inspection", "enemy", str(enemy.get("type", "")), button, enemy)
				await host.inspect("pre_battle/pinned_enemy", scene.get("_pinned_tooltip_scrim"))
				scene.call("_close_pinned_tooltip")
		"scavenger":
			var shop: Control = scene.get("_scavenger_shop_view")
			if not shop.is_visible_in_tree(): return
			shop.call("_set_pack_mode", true)
			await host.inspect("scavenger/pack", shop)
			shop.call("_set_pack_mode", false)
		"graftwright", "graftwright_stocked":
			await _graftwright(host, scene.get("_graftwright_view"), screen)
		"event":
			var state: Dictionary = scene.get("_run_state")
			var choice: String = EventRules.first_available_choice_id(state)
			if not choice.is_empty():
				scene.call("_on_section_map_event", choice)
				var event: Control = scene.get("_event_view")
				if is_instance_valid(event) and event.is_visible_in_tree():
					event.call("finish_result_beats")
					await host.inspect("event/result", event)
		"victory", "defeat":
			var recap: Control = scene.get("_run_end_recap")
			if not is_instance_valid(recap) or not recap.is_visible_in_tree(): return
			recap.call("_open_chronicle")
			await host.inspect(screen + "/chronicle", recap.get("_chronicle"))
			recap.get("_chronicle").call("close")

static func grimoire(host: SceneTree) -> void:
	var scene: Node = host.scene
	var scrim: Control = scene.get("_grimoire_scrim")
	var sections: Array[String]
	for button: Button in scene.get("_grimoire_nav_buttons"):
		if str(button.get_meta("grimoire_nav_kind", "")) == "section":
			sections.append(str(button.get_meta("grimoire_nav_id", "")))
	for id: String in sections:
		if host.finished: return
		scene.call("_on_grimoire_section_pressed", id)
		await host.inspect("start/grimoire/" + id, scrim)
	if host.finished: return
	var search: LineEdit = scene.get("_grimoire_search_input")
	search.text = GRIMOIRE_QUERY
	scene.call("_on_grimoire_search_text_changed", GRIMOIRE_QUERY)
	await host.inspect("start/grimoire/search", scrim)

static func _graftwright(host: SceneTree, graft: Control, state_name: String) -> void:
	graft.call("begin_work")
	await host.inspect(state_name + "/bench", graft)
	for role: String in ["recipient", "donor"]:
		if host.finished: return
		graft.call("open_picker", role)
		var picker: Control = graft.get("_picker")
		if picker == null: continue
		await host.inspect(state_name + "/picker_" + role, picker)
		graft.call("close_picker")
	if host.finished: return
	var state: Dictionary = graft.get("state")
	for recipient: String in GraftRules.owned(state):
		var donors: Array[String] = GraftRules.donors(state, recipient)
		if donors.is_empty(): continue
		graft.call("select_recipient", recipient)
		graft.call("select_donor", donors[0])
		await host.inspect(state_name + "/selected_pair", graft)
		if host.finished: return
		var cards: Array = graft.get("_source_cards")
		if not cards.is_empty():
			graft.call("_open_inspection", cards[0])
			await host.inspect(state_name + "/card_inspection", graft.get("_inspection"))
			graft.call("close_inspection")
		return
