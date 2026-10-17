extends RefCounted

## Scene adapter: the model owns seeded outcomes and durable receipts; the
## overlay owns transient inspection and secondary selection. A cancelled
## selection never charges, rerolls, consumes an heirloom, or declines a boon.
const Rules = preload("res://scripts/opening_boon_rules.gd")
const Overlay = preload("res://scripts/opening_boon_overlay.gd")
const Store = preload("res://scripts/progression_store.gd")
const Router = preload("res://scripts/input_router.gd")
var overlay: Control
var _ending_outcome: String = ""
var _presenting_ending: bool = false
var _loading: bool = false
const OFFER_DIALOGUE_RECT := Rect2(323.0, 842.0, 1236.0, 217.0)
var _dialogue_parent: Node
var _dialogue_index: int = 0
var _dialogue_fit_content: bool = true

func begin_load(host: Node) -> void:
	_loading = true
	close(host)
	_ending_outcome = ""
	_presenting_ending = false
	if str(host.get("_dialogue_script").get("id", "")).begins_with("opening_boon_"):
		host.set("_dialogue_script", {})

func end_load() -> void:
	_loading = false

func active() -> bool:
	return is_instance_valid(overlay)

func speak(host: Node) -> bool:
	var state: Dictionary = host.get("_run_state")
	if not Rules.pending(state): return false
	close(host)
	var candidate: Dictionary = Rules.offer(state)
	if not _commit(host, candidate, "opening_boon_offered"): return true
	host.call("_start_dialogue", host.get("_dialogue_engine").boon_dialogue("offer"))
	show_offers(host)
	return true

func dialogue_closed(host: Node, dialogue: Dictionary) -> void:
	match str(dialogue.get("id", "")):
		"opening_boon_taken", "opening_boon_declined":
			_restore_dialogue(host)
		"opening_boon_heirloom_confirmation":
			var state: Dictionary = (host.get("_run_state") as Dictionary).duplicate(true)
			state[Rules.HEIRLOOM_END_KEY]["done"] = true
			if _commit(host, state, "heirloom_confirmed"): host.call("_show_run_end_recap", _ending_outcome)

func may_close_dialogue(dialogue: Dictionary) -> bool:
	# The explicit Leave nothing option is the only empty choice. Back cannot
	# silently make a persistent decision on behalf of the player.
	return str(dialogue.get("id", "")) not in ["opening_boon_heirloom_prompt", "opening_boon_offer"]

func show_offers(host: Node) -> void:
	close(host, false)
	_seat_dialogue(host)
	overlay = Overlay.new()
	host.get("ui_root").add_child(overlay)
	overlay.configure(host, host.get("_run_state"))
	overlay.chosen.connect(_choose.bind(host))
	host.call("_schedule_controller_modal_refresh")

func _choose(id: String, choices: Array, host: Node) -> void:
	var before: Dictionary = host.get("_run_state")
	var next: Dictionary = Rules.choose(host.get("_run_engine"), before, id, choices)
	if next == before or not _commit(host, next, "opening_boon_chosen"): return
	close(host, false)
	host.call("_refresh_ui")
	host.call("_start_dialogue", host.get("_dialogue_engine").boon_dialogue("declined" if id.is_empty() else "taken"))

func close(host: Node, restore_dialogue: bool = true) -> void:
	var was_active: bool = active()
	if was_active:
		var old: Control = overlay
		overlay = null
		old.get_parent().remove_child(old)
		old.queue_free()
	if restore_dialogue: _restore_dialogue(host)
	if was_active and is_instance_valid(host) and host.is_inside_tree(): host.call("_schedule_controller_modal_refresh")

func seats_dialogue() -> bool:
	return is_instance_valid(_dialogue_parent)

func _seat_dialogue(host: Node) -> void:
	var dialog: Control = host.get("_dialogue_dialog")
	if not seats_dialogue():
		_dialogue_parent = dialog.get_parent()
		_dialogue_index = dialog.get_index()
		_dialogue_fit_content = bool(host.get("_dialogue_text_label").fit_content)
		host.get("_dialogue_text_label").fit_content = false
		dialog.reparent(host.get("_dialogue_overlay"), false)
	layout_dialogue(host)

func layout_dialogue(host: Node) -> void:
	var dialog: Control = host.get("_dialogue_dialog")
	dialog.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dialog.custom_minimum_size = OFFER_DIALOGUE_RECT.size
	dialog.position = OFFER_DIALOGUE_RECT.position
	dialog.size = OFFER_DIALOGUE_RECT.size
	var offer: bool = str(host.get("_dialogue_script").get("id", "")) == "opening_boon_offer"
	host.get("_dialogue_footer").visible = not offer

func _restore_dialogue(host: Node) -> void:
	if not seats_dialogue() or not is_instance_valid(host): return
	var dialog: Control = host.get("_dialogue_dialog")
	dialog.reparent(_dialogue_parent, false)
	_dialogue_parent.move_child(dialog, _dialogue_index)
	_dialogue_parent = null
	host.get("_dialogue_text_label").fit_content = _dialogue_fit_content
	host.get("_dialogue_footer").show()
	host.call("_sync_dialogue_layout")

func handle_input(host: Node, event: InputEvent) -> bool:
	if not active(): return false
	if Router.is_controller_event(event):
		var router: Node = host.get_node_or_null("/root/InputRouter")
		if router != null: router.call("mark_controller_device", event.device)
	if overlay.contain_input(event): host.get_viewport().set_input_as_handled()
	return true

func intercept_recap(host: Node, outcome: String) -> bool:
	var state: Dictionary = host.get("_run_state")
	if not Rules.heirloom_prompt_pending(state): return false
	if _loading: return true
	_ending_outcome = outcome
	if not bool(host.get("_dialogue_active")) and not _presenting_ending:
		_presenting_ending = true
		host.call("_start_dialogue", host.get("_dialogue_engine").heirloom_dialogue(state))
		_presenting_ending = false
	return true

func leave_heirloom(host: Node, item: String) -> void:
	var before: Dictionary = host.get("_run_state")
	var next: Dictionary = Rules.leave_heirloom(before, item)
	if next == before or not _commit(host, next, "heirloom_left"): return
	# Replace this dialogue directly: closing the prompt cannot be interpreted
	# as the confirmation acknowledgment, and never requests the start-room map.
	host.set("_dialogue_script", {})
	host.call("_close_dialogue")
	host.call("_show_run_end_recap", _ending_outcome)

func _commit(host: Node, candidate: Dictionary, boundary: String) -> bool:
	var before: Dictionary = host.get("_run_state")
	var profile: Dictionary = host.get("_progression")
	var terminal_before: Dictionary = {}
	for field: String in ["_victory_carry_processed", "_defeat_loss_processed", "_victory_carry_amount", "_defeat_lost_amount"]:
		terminal_before[field] = host.get(field)
	host.set("_run_state", candidate)
	host.set("_progression", candidate.get("progression", profile))
	var persisted: Dictionary = host.call("_persist_run_state_snapshot", candidate, false, boundary)
	if not bool(persisted.get("saved", false)):
		host.set("_run_state", before)
		host.set("_progression", profile)
		for field: String in terminal_before: host.set(field, terminal_before[field])
		return false
	host.set("_run_state", persisted.get("state", candidate))
	host.call("_release_committed_run_state")
	# A saved run is authoritative if this second write fails. The existing
	# embedded-revision recovery repairs the profile before the next descent.
	if candidate.get("progression", profile) != profile:
		if not Store.save_data(host.get("_progression")): push_warning("Opening boon profile write deferred to saved-run recovery.")
	return true

func flush_events(host: Node, state: Dictionary) -> bool:
	var context: Dictionary = host.call("_analytics_context_from_states", state)
	var events: Array = state.get(Rules.EVENTS_KEY, [])
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		var key: String = Rules.event_key(context, index, event)
		if not host.get("_analytics_store").write_event(str(event["type"]), context, event["payload"], key): return false
	return true
