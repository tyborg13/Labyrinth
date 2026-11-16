extends RefCounted
## Focused authoring proof, using task-local media only for attachment semantics.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Hud = preload("res://scripts/battlefield_rule_hud.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")

static func verify(proof: SceneTree, media_path: String) -> void:
	for row: Dictionary in Registry.entries():
		if not Fixture.Tip04.IDS.has(row["id"]) and not Fixture.Tip05.IDS.has(row["id"]): continue
		var original: String = row["asset_path"]
		row["asset_path"] = media_path
		# Exhaustive catalog source check, including bosses sharing these rules.
		for type: String in Data.enemies():
			var source: Dictionary = Context.enemy(type)
			proof._expect(Registry.find(row["term"], source).is_empty(), "Enemy cannot borrow room rule: %s / %s" % [type, row["term"]])
			var enemy_panel: Control = TooltipPanel.make_icon_lines(Icons.icon_texture(row["term"]), Icons.label(row["term"]), PackedStringArray([Icons.description(row["term"])]), row["term"], source)
			proof._expect(enemy_panel.find_child("TooltipLoopWindow", true, false) == null, "Enemy tooltip stays text-only: %s / %s" % [type, row["id"]])
			enemy_panel.free()
		proof._expect(Registry.find(row["term"], {}).is_empty() and Registry.find(row["term"], {"kind": "hero_card"}).is_empty(), "Anonymous/card terms stay text-only: " + str(row["id"]))
		var fixture: Dictionary = Fixture.build(row["id"])
		var engine := Combat.new()
		if row.has("todo_design"):
			proof._expect(Registry.find(row["term"], row["source_match"]).is_empty(), "Design-pending rule remains text-only: " + str(row["id"]))
			proof._expect(not str(Fixture.plan(fixture, engine).get("todo_design", "")).is_empty(), "Recorder explicitly stops pending rule: " + str(row["id"]))
			row["asset_path"] = original
			continue
		var hud := Hud.new()
		hud.set_combat_state(fixture["state"], engine)
		proof._expect(hud.visible and hud.rule_id == row["source_match"]["id"], "Production HUD owns rule identity: " + str(row["id"]))
		var text: String = hud.tooltip_text
		var panel: Control = hud._make_custom_tooltip(text)
		var window: Control = panel.find_child("TooltipLoopWindow", true, false)
		proof._expect(window != null and window.get_meta("tooltip_loop_id", "") == row["id"], "Rule panel attaches its own loop: " + str(row["id"]))
		var text_only: Control = TooltipPanel.make_text(text)
		proof._expect(proof._popup_text(panel) == proof._popup_text(text_only), "Rule tooltip copy matches its original text-only factory: " + str(row["id"]))
		text_only.free()
		proof._expect(hud._detail.text == Rules.panel(fixture["state"])["sentence"], "Room sentence is unchanged: " + str(row["id"]))
		panel.free()
		hud.free()
		row["asset_path"] = original
	proof._expect(Registry.find("erupt", Context.enemy("burrow_grub")).get("id") == "marked_burrow_grub" and Registry.find("upheaval", Context.enemy("burrow_grub")).is_empty(), "Burrow Grub Erupt retains its enemy loop; it cannot get rule_upheaval")
	print("TIP04 RULE OWNERSHIP: ", "PASS" if proof.failures.is_empty() else "FAIL", " (all enemy sources rejected; rule HUD; unchanged copy; five rule HUD routes)")
