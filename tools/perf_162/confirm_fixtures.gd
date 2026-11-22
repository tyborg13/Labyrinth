extends RefCounted

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Graft = preload("res://tests/suites/graftwright_suite.gd")
const Events = preload("res://scripts/event_rules.gd")
const SEED := 83
const WALLET := 720
const FIXTURE_DAMAGE := 4
const SHOP_SEED := 73491
const EVENT_ID := "lost_cartographer"
const CARD_ID := "icicle_lance"
const RECIPIENT := "undertaker_plate"
const DONOR := "patched_cloak"
const GRAFT_CARD_INDEX := 1
const SELL_ID := "ward_kite"

static func state_for(case: String, iteration: int) -> Dictionary:
	var engine := Run.new()
	var profile: Dictionary = Store.set_embers(Store.default_data(), WALLET)
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var state: Dictionary
	if case.begins_with("graft"):
		state = Graft.fixture()
		state["progression"] = profile
	else:
		state = engine.create_new_run(SHOP_SEED if case.begins_with("scavenger") else SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	state["run_index"] = iteration + 1
	if case == "graft_continue": return engine.graft_equipment(state, RECIPIENT, DONOR, GRAFT_CARD_INDEX, GRAFT_CARD_INDEX)
	if case == "graft_commit": return state
	if case.begins_with("scavenger"):
		for shop_room: Dictionary in state["rooms"].values():
			if shop_room.get("type") != "scavenger": continue
			var coord: Vector2i = shop_room["coord"]
			shop_room.merge({"revealed": true, "visited": true, "cleared": true, "npcs": []}, true)
			shop_room[Run.MERCHANT_STOCK_KEY] = ["grave_mortar", "icicle_lance", "dawnstep", "boiled_leather",
				"dust_tabi", "duelist_rapier", "crimson_draught", "nail_bomb", "jaw_trap"]
			state["current_room"] = coord
			state["mode"] = "room"
			state["current_room_layout"] = engine._display_layout_for_room(SHOP_SEED, shop_room, Vector2i.RIGHT)
			state["equipment_inventory"].append(SELL_ID)
			return state
		push_error("Missing Scavenger fixture room")
		return {}
	var destinations: Array[Vector2i] = engine.available_moves(state)
	var room: Dictionary = Graph.room(state, destinations.front())
	var kind: String = {
		"campfire": "campfire", "event": "event", "reward": "campfire",
		"treasure": "treasure",
	}[case.get_slice("_", 0)]
	room.merge({"type": kind, "cleared": false, "npcs": []}, true)
	if kind == "event": room["event_id"] = EVENT_ID
	state = engine.move_to_room(state, destinations.front())
	state["player_hp"] = int(state["player_max_hp"]) - FIXTURE_DAMAGE
	if case.begins_with("reward"):
		state["mode"] = "reward"
		state["pending_reward"] = {"kind": "event", "event_id": EVENT_ID, "cards": [CARD_ID, "grave_mortar"],
			"heal_amount": 0, "skip_label": "Skip", "ember_amount": 0, "intro_pending": false}
	elif case == "event_continue":
		state = engine.resolve_map_event(state, "embers")
	return state

static func target(scene: Node, case: String) -> Control:
	match case:
		"campfire_linger", "campfire_embrace", "campfire_strength":
			var choice: String = case.trim_prefix("campfire_")
			for control: Control in scene._relic_choice_bar.get_children():
				if control.get_meta("choice_id", "") == choice and control.get_meta("choice_revealed", false): return control
		"event_choice":
			if scene._event_view != null and not scene._event_view._busy:
				for control: Button in scene._event_view.choices:
					if control.choice_id == "embers": return control
		"event_continue":
			if scene._event_view != null and not scene._event_view._busy: return scene._event_view.continue_button
		"reward_card":
			var slot: Control = scene._relic_choice_bar.find_child("RewardCardChoiceSlot", true, false)
			return slot.find_child("CardWidget", true, false) as Control if slot != null else null
		"reward_skip":
			return scene._relic_choice_bar.find_child("RewardSkipButton", true, false)
		"treasure_claim":
			if not scene._treasure_presentation_busy() and scene._relic_choice_bar.get_child_count() > 0:
				return scene._relic_choice_bar.get_child(0)
		"graft_commit":
			return scene._graftwright_view.find_child("GraftCommit", true, false)
		"graft_continue":
			return scene._graftwright_view.find_child("GraftContinue", true, false)
		"scavenger_buy", "scavenger_sell":
			return scene._scavenger_shop_view.find_child("ScavengerTradeActionButton", true, false)
	return null

static func prepare(scene: Node, case: String) -> String:
	if case.begins_with("graft"):
		var view: Control = scene._graftwright_view
		if case == "graft_commit":
			var browse: Button = view.find_child("GraftBrowse", true, false)
			if browse != null: browse.pressed.emit()
			view.select_recipient(RECIPIENT)
			view.select_donor(DONOR)
			view.select_source(GRAFT_CARD_INDEX)
			view.select_target(GRAFT_CARD_INDEX)
		return RECIPIENT
	if case.begins_with("scavenger"):
		var shop: Control = scene._scavenger_shop_view
		var selling: bool = case == "scavenger_sell"
		if selling: shop._set_pack_mode(true)
		var id: String = SELL_ID if selling else str(scene._run_engine.merchant_offer_ids(scene._run_state, Run.MERCHANT_SCAVENGER).front())
		var source: Control = shop._offer_sources.get(("sell:" if selling else "buy:") + id)
		if source != null: source.grab_focus()
		return id
	return ""

static func settled(scene: Node, case: String, before: Dictionary) -> bool:
	var state: Dictionary = scene._run_state
	match case:
		"campfire_linger": return state["player_hp"] > before["player_hp"] and not scene._campfire_choice_action_pending
		"campfire_embrace": return state["mode"] == "embrace" and scene._campfire_embrace_committed and not scene._campfire_choice_action_pending
		"campfire_strength": return scene._upgrade_scrim.visible and state["progression"]["level"] > before["progression"]["level"]
		"event_choice": return scene._event_view.page == "result" and not scene._event_view._busy and scene._event_view.result_beats == null
		"event_continue": return state["mode"] == "room" and not scene._event_view.visible
		"reward_card": return state["mode"] == "room" and not scene._loadout_acquisition_in_progress and state["attuned_magic_cards"].size() > before["attuned_magic_cards"].size()
		"reward_skip": return state["mode"] == "room" and not scene._relic_choice_overlay.visible
		"treasure_claim": return not scene._treasure_presentation_busy() and state["relics"].size() > before["relics"].size()
		"graft_commit": return not scene._graftwright_view.busy and scene._graftwright_view._used()
		"graft_continue": return state["mode"] == "room" and not scene._graftwright_view.visible
		"scavenger_buy": return state["held_embers"] < before["held_embers"] and not scene._merchant_trade_animation_active
		"scavenger_sell": return state["held_embers"] > before["held_embers"] and not scene._merchant_trade_animation_active
	return false
