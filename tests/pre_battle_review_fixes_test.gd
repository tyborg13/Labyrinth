extends "res://tests/pre_battle_fixture.gd"

const CardStrip = preload("res://scripts/ui_card_strip.gd")
const Controls = preload("res://scripts/pre_battle_controls.gd")
const View = preload("res://scripts/pre_battle_view.gd")
const Typography = preload("res://scripts/ui_typography.gd")

func _initialize() -> void:
	_setup()
	await _test_strips()
	await _test_tag_overflow()
	_viewport.queue_free()
	await process_frame
	print("PRE-BATTLE REVIEW FIXES TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _test_strips() -> void:
	for id: String in ["waning_pulse", "whirlwind_slash"]:
		var strip := CardStrip.new()
		var count: int = 2 if id == "waning_pulse" else 1
		strip.setup(id, str(GameData.card_def(id)["name"]), count)
		strip.position = Vector2(50.0, 50.0)
		strip.size = Vector2(190.0, 30.0)
		_viewport.add_child(strip)
		await process_frame
		await process_frame
		var art := strip.get_node("Art") as TextureRect
		var atlas := art.texture as AtlasTexture
		_expect(atlas != null, "Strip art must use a zoomed center crop")
		if atlas != null:
			var source: Texture2D = atlas.atlas
			var height: float = minf(source.get_height() * 0.6, source.get_width() * 0.5)
			_expect(is_equal_approx(atlas.region.size.x / atlas.region.size.y, 2.0), "Strip art crop must be 2:1")
			_expect(is_equal_approx(atlas.region.size.y, height) and atlas.region.get_center().is_equal_approx(source.get_size() * 0.5), "Strip art crop must lie within the middle 60% and remain centered")
			_expect(str(atlas.get_meta("asset_source_path", "")) == str(GameData.card_def(id)["art_path"]), "Cropped strip art must preserve its source identity")
		_expect(art.modulate == Color(1.15, 1.15, 1.15, 1.0), "Strip art brightness must be 1.15")
		var name_label := strip.get_node("Name") as Label
		var font: Font = name_label.get_theme_font("font")
		var text_width: float = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_label.get_theme_font_size("font_size")).x
		_expect(text_width <= name_label.size.x, "%s must fit without truncation at the kit's 190px strip width: %.1f in %.1f" % [name_label.text, text_width, name_label.size.x])
		var count_label := strip.get_node("Count") as Label
		var name_end: float = count_label.position.x if count > 1 else strip.size.x - 6.0
		_expect(is_equal_approx(name_label.get_rect().end.x, name_end), "Strip name must use all available space before its count or 6px right padding")
		strip.queue_free()
		await process_frame

func _test_tag_overflow() -> void:
	var tags := Controls.MoveTags.new()
	tags.base_overflow = 1
	tags.size = Vector2(206.0, 30.0)
	for word: String in ["Pull", "Ranged", "Melee"]:
		var tag := HBoxContainer.new()
		tag.add_theme_constant_override("separation", 2)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(18.0, 18.0)
		tag.add_child(icon)
		tag.add_child(View.label(word, 14, Palette.TEXT_2))
		tags.add_child(tag)
	_viewport.add_child(tags)
	await process_frame
	await process_frame
	var marker := tags.get_node("Overflow") as Label
	_expect(marker.visible and marker.text == "+2", "A crowded Pull/Ranged/Melee/+1 row must drop Melee into +2")
	_expect((tags.get_child(1) as Control).visible and (tags.get_child(2) as Control).visible and not (tags.get_child(3) as Control).visible, "Tag overflow must preserve the first fitting tags")
	for child: Control in tags.get_children():
		if child.visible:
			var line_center: float = (tags.get_child(1) as Control).get_rect().get_center().y
			_expect(tags.get_global_rect().encloses(child.get_global_rect()) and is_equal_approx(child.get_rect().get_center().y, line_center), "Every visible tag and the overflow marker must fit on one line: %s in %s" % [child.get_global_rect(), tags.get_global_rect()])
	tags.size.x = 400.0
	await process_frame
	await process_frame
	_expect(marker.text == "+1" and (tags.get_child(3) as Control).visible, "Tags must return when their row has enough room")
	tags.queue_free()
	await process_frame
