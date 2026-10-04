extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const PreBattleView = preload("res://scripts/pre_battle_view.gd")
const ThreatTags = preload("res://scripts/pre_battle_threat_tags.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const TrueScaleCases = preload("res://tests/pre_battle_true_scale_cases.gd")

const UMBRA_COLOR: Color = preload("res://scripts/ui_palette.gd").UMBRA
const HP_COLOR: Color = preload("res://scripts/ui_palette.gd").DANGER_BRIGHT
const INITIATIVE_COLOR: Color = preload("res://scripts/ui_palette.gd").STEEL

static func run(expect: Callable) -> void:
	var host: Node = RunSceneScript.new()
	_test_room_umbra_summary(host, expect)
	_test_enemy_detail_semantics(host, expect)
	_test_enemy_detail_cursor_feedback(host, expect)
	_test_known_move_icon_precedence(host, expect)
	await _test_staged_sprite_fitting_for_full_roster(host, expect)
	await _test_foe_caption_layout(host, expect)
	await test_true_scale_lineups(host, expect)
	_test_stage_tag_icons(host, expect)
	host.free()

static func _test_room_umbra_summary(host: Node, expect: Callable) -> void:
	var room_chip: Control = PreBattleView.build_room_chip(host, {
		"name": "Cindered Hall",
		"type": "combat",
		"depth": 3,
		"element": "fire"
	}, {
		"room_name": "Cindered Hall",
		"room_type": "combat",
		"room_depth": 3,
		"room_element": "fire",
		"umbra": {"stage": "fringe"}
	}, Color("e39a42")) as Control
	var depth_label: Label = room_chip.find_child("PreBattleDepthLabel", true, false) as Label
	var umbra_label: Label = room_chip.find_child("PreBattleUmbraLabel", true, false) as Label
	expect.call(depth_label != null and depth_label.text == "DEPTH 3", "Pre-battle room summary should retain its uppercase depth text without a vision value")
	expect.call(umbra_label != null and umbra_label.text == "Fringe Umbra", "Pre-battle room summary should retain only the named Umbra stage")
	expect.call(umbra_label != null and umbra_label.get_theme_color("font_color").is_equal_approx(UMBRA_COLOR), "Pre-battle Umbra text should use the dedicated purple instead of the room element accent")
	expect.call(not _labels_text(room_chip).contains("Vision"), "Pre-battle room summary should remove Vision X text")
	room_chip.free()

static func _test_enemy_detail_semantics(host: Node, expect: Callable) -> void:
	var enemy_def: Dictionary = GameData.enemy_def("warden")
	var inspection: Control = host.call("_build_pre_battle_enemy_inspection_panel", {
		"type": "warden",
		"hp": int(enemy_def.get("max_hp", 1)),
		"max_hp": int(enemy_def.get("max_hp", 1))
	}, true) as Control
	var hp_label: Label = inspection.find_child("PreBattleEnemyHpLine", true, false) as Label
	var initiative_label: Label = inspection.find_child("PreBattleEnemyInitiativeLine", true, false) as Label
	var close_button: Button = inspection.find_child("PreBattleInspectionCloseButton", true, false) as Button
	expect.call(hp_label != null and hp_label.text.begins_with("HP ") and hp_label.get_theme_color("font_color").is_equal_approx(HP_COLOR), "Detailed enemy HP should be isolated on a red line")
	expect.call(initiative_label != null and initiative_label.text.begins_with("Base initiative ") and initiative_label.get_theme_color("font_color").is_equal_approx(INITIATIVE_COLOR), "Detailed enemy initiative should be isolated on a blue line")
	expect.call(not _labels_text(inspection).contains("Known repertoire") and not _labels_text(inspection).contains("next move concealed"), "Detailed enemy inspection should remove the redundant repertoire/concealment line")
	var close_glyph: Label = close_button.find_child("*Glyph", true, false) as Label if close_button != null else null
	expect.call(close_button != null and close_button.visible and close_button.focus_mode == Control.FOCUS_ALL and close_glyph != null and close_glyph.text == "✕" and close_glyph.visible, "Interactive enemy inspection should expose a dedicated visible, focusable close socket with a drawn ✕")
	inspection.free()

static func _test_enemy_detail_cursor_feedback(host: Node, expect: Callable) -> void:
	var scrim := ColorRect.new()
	scrim.visible = true
	scrim.size = Vector2(1000.0, 700.0)
	host.add_child(scrim)
	var inspection := Control.new()
	inspection.name = "PinnedPreBattleInspection"
	inspection.set_meta("inspection_kind", "enemy")
	inspection.position = Vector2(300.0, 150.0)
	inspection.size = Vector2(400.0, 400.0)
	scrim.add_child(inspection)
	var close_button := Button.new()
	close_button.position = Vector2(340.0, 20.0)
	close_button.size = Vector2(40.0, 40.0)
	inspection.add_child(close_button)
	host.set("_pinned_tooltip_scrim", scrim)
	host.set("_pinned_tooltip_panel", inspection)
	host.set("_pinned_tooltip_close_button", close_button)
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(660.0, 190.0)) == "action", "Focused enemy inspection should advertise only its X as actionable")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(450.0, 350.0)) == "inert", "Focused enemy inspection body should not advertise a blocked click")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(100.0, 100.0)) == "inert", "Focused enemy inspection backdrop should not advertise a suppressed underlying click")
	inspection.set_meta("inspection_kind", "card")
	expect.call(host.call("_pinned_tooltip_cursor_feedback_context", Vector2(100.0, 100.0)) == "action", "Other pinned tooltips should retain outside-click dismissal feedback")
	host.set("_pinned_tooltip_scrim", null)
	host.set("_pinned_tooltip_panel", null)
	host.set("_pinned_tooltip_close_button", null)
	scrim.free()

static func _test_known_move_icon_precedence(host: Node, expect: Callable) -> void:
	var intent_expectations: Array = [
		[{"actions": [{"type": "move_toward", "range": 3}, {"type": "melee", "damage": 3}]}, "melee"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 3}]}, "ranged"],
		[{"actions": [{"type": "move_away", "range": 2}, {"type": "block", "amount": 4}]}, "block"],
		[{"actions": [{"type": "move_toward", "range": 2}, {"type": "heal_ally", "amount": 4}]}, "heal_ally"],
		[{"actions": [{"type": "move_toward", "range": 2}]}, "move"],
		[{"actions": [{"type": "lightning_strikes", "damage": 4, "count": 3}]}, "lightning_strikes"],
		[{"actions": [{"type": "summon_minions", "count": 2}]}, "summon_minions"],
		[{"actions": [{"type": "raise_terrain", "count": 4}]}, "raise_terrain"],
		[{"actions": [{"type": "terrain_burst", "damage": 8}]}, "terrain_burst"],
		[{"actions": [{"type": "cinder_marks", "count": 5}]}, "cinder_marks"],
		[{"actions": [{"type": "detonate_cinders"}]}, "detonate_cinders"],
		[{"actions": [{"type": "gale_force", "damage": 6}]}, "gale_force"],
		[{"actions": [{"type": "frost_armor", "amount": 2}]}, "frost_armor"],
		[{"actions": [{"type": "umbra_eclipse", "duration": 2}]}, "umbra_eclipse"]
	]
	for expectation_var: Variant in intent_expectations:
		var expectation: Array = expectation_var as Array
		var actual: String = str(host.call("_pre_battle_known_move_icon_key", expectation[0] as Dictionary))
		expect.call(actual == str(expectation[1]), "Known enemy move icon should prioritize %s semantics over incidental movement (got %s)" % [str(expectation[1]), actual])

static func _test_staged_sprite_fitting_for_full_roster(host: Node, expect: Callable) -> void:
	var stage_host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(stage_host)
	for enemy_type: String in GameData.enemies().keys():
		var definition: Dictionary = GameData.enemy_def(enemy_type)
		for compact: bool in [false, true]:
			var column_size := Vector2(206.0, 220.0 if compact else 365.0)
			var card: Control = PreBattleView.build_foe(host, {"type": enemy_type, "hp": int(definition.get("max_hp", 1))}, column_size)
			stage_host.add_child(card)
			card.size = column_size
			await (Engine.get_main_loop() as SceneTree).process_frame
			await (Engine.get_main_loop() as SceneTree).process_frame
			var art := card.find_child("PreBattleEnemyArt", true, false) as TextureRect
			var stage := card.find_child("PreBattleEnemyBrush", true, false) as Control
			expect.call(stage != null, "%s should stand on an ink-pool stage" % enemy_type)
			expect.call(art != null and art.texture != null, "%s should resolve its staged full-body sprite" % enemy_type)
			if art != null and art.texture != null:
				expect.call(_texture_path(art.texture) == str(definition.get("art_path", "")), "%s stage should use its registered full-body art" % enemy_type)
				expect.call(not art.texture is AtlasTexture and art.texture.get_size() == Vector2(255.0, 255.0), "%s stage should draw the complete source canvas" % enemy_type)
				expect.call(art.stretch_mode == TextureRect.STRETCH_SCALE and art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s staged sprite should use the combat board's uniform scale and linear filtering" % enemy_type)
				var drawn_rect: Rect2 = sprite_visible_bounds(card)
				expect.call(card.get_global_rect().grow(0.01).encloses(drawn_rect), "%s complete visible sprite should fit inside its column: %s in %s" % [enemy_type, drawn_rect, card.get_global_rect()])
			card.free()
	stage_host.free()

static func _test_foe_caption_layout(host: Node, expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	var roster: Array = []
	for enemy_type: String in ["zekarion", "warden", "crawler", "zekarion", "vyraketh", "tharokh"]:
		var hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
		roster.append({"type": enemy_type, "hp": hp, "max_hp": hp})
	for count: int in range(1, 7):
		var section: Control = PreBattleView.build_foes(host, {"enemies": roster.slice(0, count)})
		viewport.add_child(section)
		section.size = Vector2(660.0, 560.0)
		for frame: int in range(4):
			await tree.process_frame
		var flow := section.find_child("PreBattleEnemyFlow", true, false) as Control
		for index: int in range(flow.get_child_count()):
			var card := flow.get_child(index) as Control
			var enemy_name := card.find_child("PreBattleEnemyName", true, false) as Label
			var tags := card.find_child("PreBattleMoveTags", true, false) as Control
			var name_rect: Rect2 = enemy_name.get_global_rect()
			var tag_rect: Rect2 = tags.get_global_rect()
			expect.call(not name_rect.intersects(tag_rect), "%d foes: %s tag row must not intersect its rendered name" % [count, enemy_name.text])
			expect.call(absf(tag_rect.position.y - name_rect.end.y - 8.0) <= 0.5, "%d foes: %s tags should flow exactly 8px below the rendered name" % [count, enemy_name.text])
			expect.call(card.get_global_rect().grow(0.5).encloses(name_rect) and card.get_global_rect().grow(0.5).encloses(tag_rect), "%d foes: %s name and tags must fit the column height budget" % [count, enemy_name.text])
			var caption := card.get_node("PreBattleFoeCaption") as Control
			for other: Control in flow.get_children():
				if int(other.get_meta("lineup_row")) == int(card.get_meta("lineup_row")):
					var other_caption := other.get_node("PreBattleFoeCaption") as Control
					expect.call(is_equal_approx(caption.global_position.y, other_caption.global_position.y), "%d foes: each row must share its maximum caption reserve" % count)
			if str((card.get("enemy") as Dictionary).get("type", "")) == "zekarion":
				expect.call(enemy_name.get_visible_line_count() <= 2 and enemy_name.get_theme_font_size("font_size") >= 17, "%d foes: Zekarion's name should fit at most two lines at UI17 or larger" % count)
		section.free()
	viewport.free()

static func test_true_scale_lineups(host: Node, expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	for case: Array in TrueScaleCases.ROSTERS:
		var enemies: Array = []
		for enemy_type: String in case[1]:
			var hp: int = int(GameData.enemy_def(enemy_type).get("max_hp", 1))
			enemies.append({"type": enemy_type, "hp": hp, "max_hp": hp, "id": enemies.size() + 1, "is_leader": enemy_type in ["zekarion", "noctyrax"]})
		var section: Control = PreBattleView.build_foes(host, {"enemies": enemies})
		viewport.add_child(section)
		section.size = Vector2(660.0, 560.0)
		for frame: int in range(6):
			await tree.process_frame
		assert_true_scale(section.get_node("PreBattleEnemyScroll/PreBattleEnemyFlow"), expect, str(case[0]))
		section.free()
	viewport.free()

static func sprite_visible_bounds(card: Control) -> Rect2:
	var art := card.get_node("PreBattleEnemyArt") as TextureRect
	var drawn_scale: float = art.size.x / art.texture.get_width()
	var used := Rect2(AssetLoader.texture_used_rect(art.texture))
	return Rect2(art.global_position + used.position * drawn_scale, used.size * drawn_scale)

static func assert_true_scale(flow: Control, expect: Callable, context: String) -> void:
	_assert_lineup_cells(flow, expect, context)
	_assert_lineup_spacing(flow, expect, context)
	var shared_scale: float = -1.0
	var crawler_height: float = -1.0
	var warden_height: float = -1.0
	var maximum_scale: float = 0.8
	for card: Control in flow.get_children():
		var enemy_type: String = str((card.get("enemy") as Dictionary).get("type", ""))
		var definition: Dictionary = GameData.enemy_def(enemy_type)
		var art := card.get_node("PreBattleEnemyArt") as TextureRect
		expect.call(art.texture != null and not art.texture is AtlasTexture and art.texture.get_size() == Vector2(255.0, 255.0), "%s %s must draw its full source canvas" % [context, enemy_type])
		if art.texture == null:
			continue
		var drawn_scale: float = art.size.x / art.texture.get_width()
		var art_scale: float = float(definition.get("art_scale", 1.0))
		var k: float = drawn_scale / art_scale
		expect.call(is_equal_approx(art.size.y / art.texture.get_height(), drawn_scale), "%s %s must scale uniformly" % [context, enemy_type])
		expect.call(k > 0.0 and k <= 0.80001, "%s %s lineup k must be positive and at most 0.8 (got %.4f)" % [context, enemy_type, k])
		if shared_scale >= 0.0:
			expect.call(is_equal_approx(shared_scale, k), "%s every pair of foes must share drawn_scale / art_scale" % context)
		shared_scale = k
		var used := Rect2(AssetLoader.texture_used_rect(art.texture))
		var anchor: Vector2 = ActorPresentation.floor_anchor(enemy_type)
		var floor_point: Vector2 = art.global_position + anchor * drawn_scale
		var caption := card.get_node("PreBattleFoeCaption") as Control
		var below: float = maxf(0.0, used.end.y - anchor.y)
		var reserve: float = 0.0
		var row_below: float = below * drawn_scale
		for other: Control in flow.get_children():
			if int(other.get_meta("lineup_row")) == int(card.get_meta("lineup_row")):
				var other_caption := other.get_node("PreBattleFoeCaption") as Control
				reserve = maxf(reserve, other_caption.get_combined_minimum_size().y)
				if flow.get_child_count() <= 3:
					var other_art := other.get_node("PreBattleEnemyArt") as TextureRect
					var other_type: String = str((other.get("enemy") as Dictionary).get("type", ""))
					var other_used := Rect2(AssetLoader.texture_used_rect(other_art.texture))
					var other_scale: float = other_art.size.x / other_art.texture.get_width()
					row_below = maxf(row_below, maxf(0.0, other_used.end.y - ActorPresentation.floor_anchor(other_type).y) * other_scale)
		var ground_y: float = caption.global_position.y - row_below
		expect.call(absf(floor_point.y - ground_y) <= 0.01 and absf(floor_point.x - card.get_global_rect().get_center().x) <= 0.01, "%s %s floor anchor must sit on its computed ground line at column centre" % [context, enemy_type])
		var visible_bounds: Rect2 = sprite_visible_bounds(card)
		expect.call(card.get_global_rect().grow(0.01).encloses(visible_bounds), "%s %s visible art must fit its cell: %s in %s" % [context, enemy_type, visible_bounds, card.get_global_rect()])
		expect.call(not visible_bounds.grow(-0.01).intersects(caption.get_global_rect()), "%s %s sprite must not intersect its own caption: %s and %s" % [context, enemy_type, visible_bounds, caption.get_global_rect()])
		for other: Control in flow.get_children():
			if other != card:
				expect.call(not visible_bounds.intersects(other.get_global_rect()), "%s %s sprite must not intersect another foe's cell" % [context, enemy_type])
		var stage := card.get_node("PreBattleEnemyBrush") as Control
		var pool_centre: Vector2 = stage.global_position + stage.size * (stage.get("feet_anchor") as Vector2)
		expect.call(pool_centre.distance_to(floor_point) <= 2.0, "%s %s ink pool must be within 2px of its floor anchor" % [context, enemy_type])
		var pool_size: Vector2 = stage.get("pool_size")
		expect.call(absf(pool_size.x - maxf(40.0, visible_bounds.size.x * 0.9)) <= 0.01 and absf(pool_size.y - pool_size.x * 0.22) <= 0.01, "%s %s ink pool must follow the visible width" % [context, enemy_type])
		var registered_width: float = 2.0 * maxf(anchor.x - used.position.x, used.end.x - anchor.x)
		maximum_scale = minf(maximum_scale, minf((card.size.y - reserve - 6.0) / ((anchor.y - used.position.y + below) * art_scale), (card.size.x - 16.0) / (registered_width * art_scale)))
		var name_label := card.find_child("PreBattleEnemyName", true, false) as Label
		var tags := card.find_child("PreBattleMoveTags", true, false) as Control
		expect.call(not name_label.get_global_rect().intersects(tags.get_global_rect()) and absf(tags.global_position.y - name_label.get_global_rect().end.y - 8.0) <= 0.5, "%s %s tags must stay 8px below its actual name" % [context, enemy_type])
		expect.call(name_label.get_visible_line_count() <= 2 and name_label.get_theme_font_size("font_size") >= 17, "%s %s name must fit at most two lines at UI17 or larger" % [context, enemy_type])
		if name_label.get_line_count() > 2:
			expect.call(name_label.get_theme_font_size("font_size") == 17, "%s %s names that overflow two lines must step down to UI17" % [context, enemy_type])
		var health := card.get_node("PreBattleEnemyHealth") as Control
		expect.call(card.get_global_rect().encloses(health.get_global_rect()), "%s %s HP badge must be clamped inside its column" % [context, enemy_type])
		var leader := card.get_node_or_null("PreBattleLeaderLabel") as Label
		if leader != null:
			expect.call(leader.get_global_rect().end.y <= health.global_position.y + 0.01, "%s %s LEADER must sit above its HP badge" % [context, enemy_type])
		if enemy_type == "crawler":
			crawler_height = visible_bounds.size.y
		elif enemy_type == "warden":
			warden_height = visible_bounds.size.y
	expect.call(is_equal_approx(shared_scale, maximum_scale), "%s must choose the largest shared k satisfying every height and width budget" % context)
	if context == "crawler_warden_droplet":
		expect.call(crawler_height > 0.0 and crawler_height < warden_height * 0.6, "Crawler must draw shorter than 0.6 times the warden in roster 2")

static func _assert_lineup_spacing(flow: Control, expect: Callable, context: String) -> void:
	var hint := flow.get_parent().get_parent().find_child("PreBattleFoeHint", true, false) as Control
	expect.call(hint != null and hint.size.y > 0.0, "%s should reserve the pointer hint's rendered height" % context)
	var top: float = INF
	var bottom: float = -INF
	var ground_y: float = NAN
	for card: Control in flow.get_children():
		top = minf(top, sprite_visible_bounds(card).position.y)
		var caption := card.get_node("PreBattleFoeCaption") as Control
		bottom = maxf(bottom, caption.get_global_rect().end.y)
		var tags := card.find_child("PreBattleMoveTags", true, false) as Control
		if hint != null:
			var gap: float = hint.global_position.y - tags.get_global_rect().end.y
			expect.call(gap >= 14.0 - 0.01, "%s %s tags must sit at least 14px above the hint (got %.2fpx)" % [context, (card.get("enemy") as Dictionary).get("type", ""), gap])
		if flow.get_child_count() <= 3:
			var art := card.get_node("PreBattleEnemyArt") as TextureRect
			var enemy_type: String = str((card.get("enemy") as Dictionary).get("type", ""))
			var floor_y: float = art.global_position.y + ActorPresentation.floor_anchor(enemy_type).y * art.size.y / art.texture.get_height()
			if not is_nan(ground_y):
				expect.call(absf(floor_y - ground_y) <= 0.01, "%s one-row foes must share a ground line" % context)
			ground_y = floor_y
	if flow.get_child_count() > 0 and flow.get_child_count() <= 3:
		var free_above: float = top - flow.global_position.y
		var free_below: float = flow.get_global_rect().end.y - bottom
		expect.call(absf(free_above - free_below) <= 2.0, "%s one-row visual group must have equal free space above and below within 2px (got %.2fpx / %.2fpx)" % [context, free_above, free_below])

static func _assert_lineup_cells(flow: Control, expect: Callable, context: String) -> void:
	var large: Array[Control]
	var small: Array[Control]
	for card: Control in flow.get_children():
		var definition: Dictionary = GameData.enemy_def(str((card.get("enemy") as Dictionary).get("type", "")))
		var footprint: Array = definition.get("footprint", [1, 1])
		if int(footprint[0]) > 1 or int(footprint[1]) > 1:
			large.append(card)
		else:
			small.append(card)
	var rows: int = 1 if flow.get_child_count() <= 3 else 2
	var small_columns: int = small.size() if rows == 1 else ceili(small.size() / 2.0)
	var unit_width: float = flow.size.x / maxi(1, small_columns + large.size() * 2)
	var left_columns: int = ceili(small_columns / 2.0)
	var left: float = 0.0
	for card: Control in flow.get_children():
		var spanning: bool = rows == 2 and large.has(card)
		var row: int = 0
		if rows == 2:
			if spanning:
				left = (left_columns + large.find(card) * 2) * unit_width
			else:
				var column: int = small.find(card) / 2
				row = small.find(card) % 2
				left = (column + (large.size() * 2 if column >= left_columns else 0)) * unit_width
		var width: float = unit_width * (2.0 if large.has(card) else 1.0)
		var expected_rect := Rect2(left, row * flow.size.y / rows, width, flow.size.y if spanning else flow.size.y / rows)
		expect.call(card.get_rect().is_equal_approx(expected_rect), "%s should preserve roster order in weighted columns, with large foes central and spanning both rows: %s expected %s" % [context, card.get_rect(), expected_rect])
		if rows == 1:
			left += width
	if rows == 1 and flow.get_child_count() == 3:
		for card: Control in flow.get_children():
			if bool(card.get_meta("is_leader", false)):
				expect.call(flow.get_child(1) == card, "%s three-foe lineups must place the leader in the centre slot" % context)

static func _texture_path(texture: Texture2D) -> String:
	while texture is AtlasTexture:
		texture = (texture as AtlasTexture).atlas
	return str(texture.get_meta("asset_source_path", texture.resource_path)) if texture != null else ""

static func _labels_text(node: Node) -> String:
	var text_parts: PackedStringArray = []
	for child: Node in node.find_children("*", "Label", true, false):
		text_parts.append((child as Label).text)
	return "\n".join(text_parts)

static func _test_stage_tag_icons(host: Node, expect: Callable) -> void:
	var roster_expectations: Array = [
		["acolyte", "Heal", "heal"],
		["warden", "Guard", "guard_ally"],
		["zekarion", "Area", "lightning_strikes"]
	]
	for expectation_var: Variant in roster_expectations:
		var expectation: Array = expectation_var as Array
		var enemy_type: String = str(expectation[0])
		var card: Control = PreBattleView.build_foe(host, {"type": enemy_type, "hp": 1}, Vector2(206, 365))
		_assert_tag_identity(card.find_child("PreBattleMoveTags", true, false) as Control, str(expectation[1]), str(expectation[2]), expect, enemy_type)
		card.free()
	var action_expectations: Array = [
		[{"type": "heal_self"}, "Heal", "heal"],
		[{"type": "heal_ally"}, "Heal", "heal_ally"],
		[{"type": "guard_ally"}, "Guard", "guard_ally"],
		[{"type": "block"}, "Guard", "block"],
		[{"type": "lightning_strikes"}, "Area", "lightning_strikes"],
		[{"type": "terrain_burst"}, "Worldspines", "terrain_burst"],
		[{"type": "terrain_burst", "guardian_kind": "crag_outcrop"}, "Outcrops", "terrain_burst"],
		[{"type": "raise_terrain"}, "Worldspines", "raise_terrain"],
		[{"type": "detonate_cinders"}, "Cinder Marks", "detonate_cinders"],
		[{"type": "cinder_marks"}, "Cinder Marks", "cinder_marks"],
		[{"type": "melee", "pierce": true, "bleed": 2}, "Pierce", "pierce"],
		[{"type": "melee", "pierce": true, "bleed": 2}, "Bleed", "bleed"],
		[{"type": "split"}, "Split", ""],
		[{"type": "move_toward"}, "Inspect known moves", ""]
	]
	for expectation_var: Variant in action_expectations:
		var expectation: Array = expectation_var as Array
		var tags: Array = ThreatTags.from_intents([{"actions": [expectation[0]]}])
		var row: Control = PreBattleView.build_move_tags(host, tags)
		_assert_tag_identity(row, str(expectation[1]), str(expectation[2]), expect, str((expectation[0] as Dictionary).get("type", "")))
		row.free()
	expect.call(ThreatTags.summary(ThreatTags.build("acolyte")) == "Ranged / Guard / Heal  +1", "Threat summaries should preserve established words, order, deduplication and overflow")

static func _assert_tag_identity(row: Control, word: String, icon_key: String, expect: Callable, context: String) -> void:
	var tag: Control = null
	for child: Control in row.get_children():
		if str(child.get_meta("tag_word", "")) == word:
			tag = child
			break
	expect.call(tag != null, "%s should retain its %s threat word" % [context, word])
	if tag == null:
		return
	expect.call(str(tag.get_meta("icon_key", "")) == icon_key, "%s %s should use registry key %s" % [context, word, icon_key])
	var icons: Array[Node] = tag.find_children("*", "TextureRect", true, false)
	if icon_key.is_empty():
		expect.call(icons.is_empty(), "%s %s must retain its word without borrowing an unrelated icon" % [context, word])
	else:
		expect.call(icons.size() == 1, "%s %s should show exactly one identity icon" % [context, word])
		if icons.size() == 1:
			var texture: Texture2D = (icons[0] as TextureRect).texture
			expect.call(texture != null and _texture_path(texture) == ActionIcons.icon_path(icon_key), "%s %s must show the registered %s icon path" % [context, word, icon_key])
