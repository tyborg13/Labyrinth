extends RefCounted

const Boons = preload("res://scripts/opening_boon_rules.gd")
const Card = preload("res://scripts/opening_boon_card.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Data = preload("res://scripts/game_data.gd")

static func run(viewport: Node, scene: Node, expect: Callable) -> Dictionary:
	var result: Dictionary = {"cards": 0, "maximum_lines": 0, "maximum_height": 0, "smaller_body_cards": 0}
	var holder := Control.new()
	viewport.add_child(holder)
	var pool: Array[String] = Boons.relic_pool("common", {})
	pool.append_array(Boons.relic_pool("rare", {}))
	for id: String in pool:
		for boon: String in ["trinket", "pawned_light"]:
			var offer: Dictionary = {"boon": boon, "relic": id, "column": "Shaping" if boon == "trinket" else "Bargain"}
			var card := Card.new()
			holder.add_child(card)
			card.configure(scene, offer)
			# Exercise the production control after its deferred layout and a draw
			# opportunity, rather than measuring a differently configured label.
			await viewport.get_tree().process_frame
			await viewport.get_tree().process_frame
			var rich: RichTextLabel = card.get_node("BoonRules")
			var font_size: int = rich.get_theme_font_size("normal_font_size")
			var lines: int = rich.get_line_count()
			var suffix: String = "" if boon == "trinket" else " Start at half @kw(health|HP)."
			expect.call(Boons.text(offer) == str(Data.relic_def(id)["description"]) + suffix, "Authored effect/keywords survive both relic presentations: " + id + "/" + boon)
			expect.call(absf(rich.position.x - 24.0) <= 1.0 and absf(rich.size.x - 252.0) <= 1.0 and absf(card.size.x - rich.get_rect().end.x - 24.0) <= 1.0, "Rendered relic rules retain both 24px pads and 252px width: " + id + "/" + boon)
			expect.call((font_size == Typography.SIZE_BODY and lines <= 4) or (font_size == Typography.SIZE_SMALL and lines <= 5), "Rendered relic rules obey 4 body / 5 smaller-body line limits: %s/%s size=%d lines=%d" % [id, boon, font_size, lines])
			expect.call(rich.get_content_height() <= rich.size.y, "All relic effect lines fit vertically: " + id + "/" + boon)
			result["cards"] += 1
			result["maximum_lines"] = maxi(int(result["maximum_lines"]), lines)
			result["maximum_height"] = maxi(int(result["maximum_height"]), rich.get_content_height())
			if font_size == Typography.SIZE_SMALL: result["smaller_body_cards"] += 1
			card.free()
	holder.free()
	print("BOON RELIC RULES PROOF: " + JSON.stringify(result))
	return result
