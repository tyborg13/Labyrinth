extends RefCounted
## Source and input-route checks use temporary numerical media, never ship it.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Tiles = preload("res://scripts/board_tile_tooltip.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func verify(proof: SceneTree, media_path: String) -> void:
	var board := Board.new()
	for id: String in Fixture.Traps.IDS:
		var fixture: Dictionary = Fixture.build(id)
		board.combat_state = fixture["state"]
		board._tile_tooltip_cache.invalidate()
		var source: Dictionary = {"kind": "trap", "element": id.trim_prefix("trap_")}
		var row: Dictionary = Registry.find("traps", source)
		proof._expect(row.get("id") == id, "Trap resolves only its element: " + id)
		proof._expect(Registry.find("traps", {"kind": "trap"}).is_empty() and Registry.find("traps", {"kind": "enemy", "element": source["element"]}).is_empty() and Registry.find("traps", {}).is_empty(), "No anonymous or enemy trap-loop borrowing")
		var entries: Array[Dictionary] = Tiles.entries(board, Fixture.Traps.CENTER)
		proof._expect(entries.size() == 1 and entries[0].get("icon") == "traps" and entries[0].get("loop_source") == source, "Tile detail keeps trap icon and exact element")
		var expected: Dictionary = {
			"fire": "The trap leaves @term(surface_fire) on the trap’s tile and each adjacent tile.",
			"ice": "The trap leaves @term(surface_ice) on the trap’s tile and each adjacent tile.",
			"lightning": "The trap leaves @term(surface_electrified) on the trap’s tile and each adjacent tile.",
			"earth": "The trap leaves @term(surface_rubble) on the trap’s tile and each adjacent tile.",
			"air": "@kw(push) each unit adjacent to the trap 1 tile away."
		}
		proof._expect(entries[0]["description"] == "Triggers when entered or attacked.\n%d damage to the unit on this tile.\n%s" % [fixture["state"]["traps"][0]["base_damage"], expected[source["element"]]], "Trap copy matches all three brief lines exactly")
		var original: String = row["asset_path"]
		row["asset_path"] = media_path
		for controller: bool in [false, true]:
			var text: String = board.controller_tooltip_for_tile(Fixture.Traps.CENTER) if controller else Tiles.encode(entries)
			var panel: Control = board._make_custom_tooltip(text)
			var window: Control = panel.find_child("TooltipLoopWindow", true, false)
			proof._expect(window != null and window.get_meta("tooltip_loop_id") == id, "Mouse/controller tile builder attaches this trap loop")
			var icon: TextureRect = panel.find_child("TooltipIcon", true, false)
			proof._expect(icon != null and icon.texture == Icons.icon_texture("traps"), "Trap panel retains the traps icon")
			panel.free()
		row["asset_path"] = original
	board.free()
	print("TRP01 TOOLTIP ROUTES: ", "PASS" if proof.failures.is_empty() else "FAIL", " (five elements; mouse and controller; source isolation)")
