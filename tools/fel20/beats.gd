extends RefCounted
## Sample authored presentation phases. Independent beats may overlap.

const INPUT_HANDLER := {
	"title.continue": "scripts/main_menu.gd:1185",
	"map.prebattle": "scripts/section_map_panel.gd:548",
	"prebattle.combat": "scripts/run_scene.gd:27759",
	"kill.reward": "scripts/run_scene.gd:21100",
	"reward.map": "scripts/run_scene.gd:28007",
	"map.event": "scripts/section_map_panel.gd:548",
	"event.result": "scripts/run_scene.gd:35202",
	"event.map": "scripts/run_scene.gd:35202",
	"map.shop": "scripts/section_map_panel.gd:548",
	"shop.buy": "scripts/run_scene.gd:28399",
	"shop.leave": "scripts/run_scene.gd:15852",
	"character.open": "scripts/run_scene.gd:29961",
	"character.close": "scripts/run_scene.gd:21521",
	"grimoire.open": "scripts/run_scene.gd:29079",
	"grimoire.close": "scripts/run_scene.gd:29100",
	"large_map.open": "scripts/run_scene.gd:21677",
	"large_map.close": "scripts/run_scene.gd:21709",
	"pause.open": "scripts/run_scene.gd:28991",
	"pause.close": "scripts/run_scene.gd:29013",
	"section.change": "scripts/run_scene.gd:15223",
	"defeat.recap": "scripts/run_scene.gd:14923",
	"recap.title": "scripts/cursor_feedback.gd:148",
}

const SectionTransition = preload("res://scripts/section_transition.gd")

var spans: Array[Dictionary]
var _open: Dictionary


func sample(screens, at: float) -> Array:
	var signature: Array = [screens.screen()]
	var live: Dictionary = {}
	var scene: Node = screens.run_scene()
	if scene == null:
		var transition: Node
		for node: Node in screens.tree.root.get_children():
			if node.has_method("performance_snapshot") and node.get("phase") != null:
				transition = node
				break
		if transition != null:
			var phase: String = str(transition.phase)
			signature.append([phase, transition.message_label.visible_characters, transition._surface.modulate.a])
			match phase:
				"loading": live["Threaded load"] = "scripts/menu_run_transition.gd:147"
				"preparing": live["Build and warm destination"] = "scripts/menu_run_transition.gd:203"
				"revealing": live["Loading cover fade out"] = "scripts/menu_run_transition.gd:291"
	else:
		_run(scene, screens, signature, live)
	for beat: String in _open.keys():
		if not live.has(beat): _close(beat, at)
	for beat: String in live:
		if not _open.has(beat):
			_open[beat] = {"name": beat, "source": live[beat], "start_ms": at}
	return signature


func _run(scene: Node, screens, signature: Array, live: Dictionary) -> void:
	var run: Dictionary = scene._run_state
	var mode: String = str(run.get("mode", ""))
	var board: Dictionary = scene.board_view.get("presentation")
	signature.append_array([mode, run.get("current_room"), run.get("player_hp"), run.get("embers"),
		scene.action_banner.text, scene._animation_lock, board.get("door_opening"), board.get("effect", {}).get("progress"),
		board.get("death_animation_units", []).hash()])
	if scene._large_map_scrim.visible:
		_tween(live, "Map fade in", "scripts/large_map_backdrop.gd:12", scene._large_map_scrim._fade)
		var map: Control = scene._large_map_view
		_tween(live, "Map acknowledgement and lantern walk", "scripts/section_map_panel.gd:548", map._activation_tween)
		signature.append([scene._large_map_scrim.modulate.a, map._canvas.get("travel_progress"), map.activation_coord])
	if scene._pre_battle_scrim.visible:
		_tween(live, "Pre-battle fade and scale", "scripts/run_scene.gd:5617", scene._pre_battle_entry_tween)
		signature.append([scene._pre_battle_scrim.modulate.a, scene._pre_battle_panel.scale])
	if scene._opening_hand_draw_in_progress:
		var objective: Control = scene._combat_objective_hud
		if scene._hand_layout_pending_revision >= 0:
			live["Opening layout wait"] = "scripts/run_scene.gd:27842"
		elif objective != null and objective.intro_active:
			live["Objective intro"] = "scripts/run_scene.gd:11700"
		elif not scene._draw_hand_transition_proxies.is_empty():
			live["Opening hand deal"] = "scripts/run_scene.gd:27834"
		else:
			live["Combat intro handoff"] = "scripts/run_scene.gd:27815"
	if not scene._draw_hand_transition_proxies.is_empty():
		var poses: Array = []
		for proxy: Control in scene._draw_hand_transition_proxies:
			if is_instance_valid(proxy): poses.append([proxy.position, proxy.modulate])
		signature.append(poses)
	if not board.get("door_opening", {}).is_empty(): live["Board door open"] = "scripts/run_scene.gd:27928"
	if not board.get("death_animation_units", []).is_empty(): live["Death playback"] = "scripts/run_scene.gd:23115"
	if screens.visible(scene._post_combat_victory_overlay):
		live["Victory banner and hold"] = "scripts/post_combat_reward_sequence.gd:12"
		signature.append(scene._post_combat_victory_overlay.modulate)
	if scene._reward_reveal_pending:
		live["Reward reveal"] = "scripts/post_combat_reward_sequence.gd:19"
	if scene._loadout_acquisition_in_progress:
		live["Reward collection flair and delivery"] = "scripts/run_scene.gd:28007"
	_tween(live, "Character arrival", "scripts/run_scene.gd:29992", scene._character_menu_arrival_tween)
	if screens.visible(scene._upgrade_scrim): signature.append(scene._upgrade_dialog.modulate)
	var event: Control = scene._event_view
	if screens.visible(event):
		if event._busy: live["Event entry"] = "scripts/event_view.gd:545"
		if event._closing: live["Event dismissal"] = "scripts/event_view.gd:653"
		if event.result_beats != null and event.result_beats.is_processing():
			live["Event outcome feedback"] = "scripts/event_view.gd:620"
		signature.append([event.modulate, event._busy, event._closing])
	var shop: Control = scene._scavenger_shop_view
	if screens.visible(shop):
		_tween(live, "Scavenger entry", "scripts/scavenger_shop_view.gd:1524", shop._entry_tween)
		if shop._purchase_effects.get_child_count() > 0:
			live["Scavenger trade feedback"] = "scripts/scavenger_shop_view.gd:356"
		signature.append([shop._canvas.modulate, shop._detail_action.text, shop._purchase_effects.get_child_count()])
	var section: Node = scene._section_transition
	if is_instance_valid(section) and section.active:
		if section.elapsed < SectionTransition.reward_fade_seconds(section.reduced_motion):
			live["Section reward fade out"] = "scripts/section_transition.gd:122"
		elif section._arrival_start < 0.0:
			live["Section descent and title card"] = "scripts/section_transition.gd:144"
		else:
			live["Section arrival and crossfade"] = "scripts/section_transition.gd:293"
			if section._entry_art_pending:
				live["Section destination art wait"] = "scripts/section_transition.gd:304"
		signature.append(section.elapsed)
	var recap: Control = scene._run_end_recap
	if screens.visible(recap):
		if recap.is_processing(): live["Recap shroud, rows and score"] = "scripts/run_end_recap_overlay.gd:847"
		signature.append(recap._elapsed)
	var progress: Array = []
	for name: String in live: progress.append(name)
	signature.append(progress)


func _tween(active: Dictionary, name: String, source: String, tween: Tween) -> void:
	if tween != null and tween.is_running(): active[name] = source


func finish(at: float) -> void:
	for beat: String in _open.keys(): _close(beat, at)


func _close(beat: String, at: float) -> void:
	var row: Dictionary = _open[beat]
	row["end_ms"] = at
	spans.append(row)
	_open.erase(beat)



func record_dispatch(id: String, end: float) -> void:
	var source: String = INPUT_HANDLER.get(id, "scripts/run_scene.gd:29961")
	spans.append({"name": "Dispatch and synchronous UI work", "source": source, "start_ms": 0.0, "end_ms": end})
