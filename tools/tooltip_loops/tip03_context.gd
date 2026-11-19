extends RefCounted
## Ephemeral proof inputs only. No synthetic recording is installed in assets/.
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const CARD_CONTEXT_PROOF_ID: String = "shatter" # Debug-only existing card with a Frozen condition.
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")

static func verify(proof: SceneTree, path: String) -> void:
	var originals: Dictionary = {}
	for row: Dictionary in Registry.entries():
		if not (Fixture.Tip03.IDS.has(row["id"]) or Fixture.Tip07.IDS.has(row["id"])) or row.has("todo_design"): continue
		originals[row["id"]] = row["asset_path"]
		row["asset_path"] = path
		var source: Dictionary = row["source_match"]
		var tooltip: Control = Inline.glossary_panel(Icons.tooltip(row["term"]), source)
		_expect_loop(proof, tooltip, row["id"], "source glossary")
		tooltip.free()
		if source["kind"] == "enemy":
			var host: Node = preload("res://scenes/run_scene.tscn").instantiate()
			var fixture: Dictionary = Fixture.build(row["id"])
			var popup: Control = Inspection.build(host, fixture["state"]["enemies"][0])
			_expect_loop(proof, popup, row["id"], "pre-battle")
			if row["term"] == "splits":
				var split_row: Control = popup.find_child("EnemySplitTrait", true, false)
				proof._expect(split_row != null, "Production Splits trait row exists")
				if split_row != null:
					proof._expect(proof._matches_term(split_row.tooltip_text, row), "Native capture accepts the exact contextual Splits sentence")
					var nested: Control = split_row._make_custom_tooltip(split_row.tooltip_text)
					_expect_loop(proof, nested, row["id"], "Splits trait source")
					nested.free()
				var details: Control = Inspection.build(host, fixture["state"]["enemies"][0], true)
				var details_trait: Control = details.find_child("EnemySplitTrait", true, false)
				var details_tip: Control = details_trait._make_custom_tooltip(details_trait.tooltip_text)
				_expect_loop(proof, details_tip, row["id"], "interactive Details trait")
				details_tip.free()
				details.free()
			popup.free()
			for intent: Dictionary in Data.enemy_def(source["id"])["intents"]:
				var shown: Dictionary = preload("res://scripts/enemy_mechanics/marked_strike.gd").presentation_intent(host.get("_combat_engine"), fixture["state"], fixture["state"]["enemies"][0], intent)
				var move: Control = Inspection.build_move(host, shown, source)
				if row.get("intent_titles", []) is Array and (row.get("intent_titles", []) as Array).has(str(intent.get("name", ""))):
					var nested: Control = move._make_custom_tooltip(move.tooltip_text)
					_expect_loop(proof, nested, row["id"], "Details move " + str(intent.get("id")) + " " + move.tooltip_text)
					nested.free()
				move.free()
			host.free()
	await _status_ownership(proof)
	await _new_contexts(proof)
	var global: Control = TooltipPanel.make_text(Icons.tooltip("collision"))
	_expect_loop(proof, global, "collision_push", "anonymous Collision")
	global.free()
	for term: String in ["push", "pull"]:
		var card_panel: Control = Inline.glossary_panel(Icons.tooltip(term), {"kind": "hero_card"})
		_expect_loop(proof, card_panel, {"push": Fixture.Tip07.PUSH, "pull": Fixture.Tip07.PULL}[term], "card " + term)
		card_panel.free()
		proof._expect(Registry.find(term, Context.enemy("crawler")).is_empty() and Registry.find(term, {}).is_empty(), "Push/Pull outside cards stay text-only")
	var skybreak: Control = Inline.glossary_panel(Icons.tooltip("lightning_strikes"), Context.enemy("zekarion"))
	proof._expect(Registry.find("lightning_strikes", Context.enemy("zekarion")).is_empty() and skybreak.find_child("TooltipLoopWindow", true, false) == null, "Enemy Skybreak does not borrow the room-rule loop")
	skybreak.free()
	for pair: Array in [["retaliate", "crawler"], ["charge", "crawler"], ["marked", "crawler"], ["burst", "cinder_ooze"]]:
		proof._expect(Registry.find(pair[0], Context.enemy(pair[1])).is_empty(), "Unlisted source stays text-only: " + str(pair))
	proof._expect(not Registry.has_source(Context.enemy("crawler")), "Global Collision does not opt every enemy into outer loops")
	for row: Dictionary in Registry.entries():
		if originals.has(row["id"]): row["asset_path"] = originals[row["id"]]
	await proof.process_frame

static func _expect_loop(proof: SceneTree, panel: Control, id: String, context: String) -> void:
	var window: Control = panel.find_child("TooltipLoopWindow", true, false) if panel != null else null
	proof._expect(window != null and window.get_meta("tooltip_loop_id", "") == id, "%s owns %s (actual %s)" % [context, id, str(window.get_meta("tooltip_loop_id", "")) if window != null else "none"])

static func _status_ownership(proof: SceneTree) -> void:
	var playback = preload("res://tools/tooltip_loops/playback.gd")
	var viewport: SubViewport = playback.canvas(proof)
	for id: String in ["retaliate_hollow_mimic", "charge_storm_capacitor", "splits_cinder_ooze"]:
		var row: Dictionary = Registry.entries().filter(func(entry: Dictionary) -> bool: return entry["id"] == id)[0]
		var scene: Node = await playback.instance(proof, viewport, Fixture.build(id), false)
		var board: Control = scene.get("board_view")
		var checked: bool = false
		for unit: Dictionary in board.plate_visibility.actors():
			if Context.actor_source(board, unit.get("key", "")) != row["source_match"]: continue
			for entry: Dictionary in board.plate_visibility.status_entries(unit):
				var text: String = str(entry.get("tooltip", ""))
				if Context.term_in(text, row["source_match"]) != row["term"]: continue
				board._last_pointer_position = (entry["rect"] as Rect2).get_center()
				proof._expect(board._get_tooltip(board._last_pointer_position) == text, "Real status plate hit-test: " + id)
				proof._expect(Context.board_source(board, text) == row["source_match"], "Status plate retains enemy identity: " + id)
				var panel: Control = board._make_custom_tooltip(text)
				_expect_loop(proof, panel, id, "status plate")
				panel.free()
				checked = true
		proof._expect(checked, "Source has its real status plate: " + id)
		scene.queue_free()
		await proof.process_frame
	viewport.queue_free()
	await proof.process_frame

static func _new_contexts(proof: SceneTree) -> void:
	var playback = preload("res://tools/tooltip_loops/playback.gd")
	var viewport: SubViewport = playback.canvas(proof)
	for id: String in ["lightning_strikes", "freeze_status"]:
		var fixture: Dictionary = Fixture.build(id)
		var result: Dictionary = Fixture.plan(fixture, preload("res://scripts/hero_facing_combat.gd").new())
		var scene: Node = await playback.instance(proof, viewport, fixture, false)
		var term: String = "freeze" if id == "freeze_status" else "lightning_strikes"
		var global: Control = TooltipPanel.make_text(Icons.tooltip(term))
		if id == "freeze_status": _expect_loop(proof, global, id, "global keyword")
		else: proof._expect(global.find_child("TooltipLoopWindow", true, false) == null, "Anonymous Lightning Strikes stays text-only")
		global.free()
		if id == "lightning_strikes":
			var hud: Control = scene.get("_battlefield_rule_hud")
			proof._expect(hud.rule_id == "lightning_storm" and hud.visible, "Real battlefield rule HUD is present")
			var panel: Control = hud._make_custom_tooltip(hud.tooltip_text)
			_expect_loop(proof, panel, id, "battlefield rule HUD")
			panel.free()
			var shown: Dictionary = playback.rule_presentation(scene, result["beats"][1])
			proof._expect(shown["effect"]["kind"] == "lightning_strikes" and shown["effect"]["tiles"].size() == 2, "Stock lightning painter strikes occupied and empty Electrified tiles")
			proof._expect(shown["floating_texts"].size() == 1 and shown["floating_texts"][0]["text"] == "-3", "Real room-rule loss number is shown only on the Crawler")
		else:
			var rows: Array = Icons.rows_for_actions(Data.card_def(CARD_CONTEXT_PROOF_ID)["actions"])
			var stack: Control = scene.get("_card_focus_tooltip_stack")
			stack.show_for(scene.call("_hand_card_control", 0), Icons.tooltip_entries_for_rows(rows))
			_expect_loop(proof, stack, id, "Existing Frozen-condition card keyword stack")
			stack.hide_stack()
			var frozen: Dictionary = result["beats"][0]["after"]
			scene.call("_render_board_state", frozen, {})
			var board: Control = scene.get("board_view")
			var found: bool = false
			for unit: Dictionary in board.plate_visibility.actors():
				for entry: Dictionary in board.plate_visibility.status_entries(unit):
					var text: String = str(entry.get("tooltip", ""))
					if Context.term_in(text, {}) != "freeze": continue
					board._last_pointer_position = (entry["rect"] as Rect2).get_center()
					var panel: Control = board._make_custom_tooltip(text)
					_expect_loop(proof, panel, id, "Frozen status plate")
					panel.free()
					found = true
			proof._expect(found, "Frozen Bite's real Freeze status plate exists")
			var texts: Array = scene.call("_player_damage_floating_texts", frozen, result["final"])
			proof._expect(texts.size() == 1 and texts[0]["text"] == "-18", "30 HP fixture shows the full production tripled hit")
			print("TIP03 FREEZE: production popup -18; target survives")
		scene.queue_free()
		await proof.process_frame
	viewport.queue_free()
	await proof.process_frame
