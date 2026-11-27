extends RefCounted
## Normalize retained painter receipts and native Control labels to screen space.

const Trace = preload("res://tools/fel14/paint_trace.gd")
const Masks = preload("res://tools/fel14/masks.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const HEAD_TORSO_TOP := 0.45
const PAIR_OVERLAP := 0.10
const TEXT_LOSS := 0.15

var _mask := Masks.new()
var _silhouettes := Alpha.new()
var _paint: Array[Dictionary]
var _board: Control

func popup_scores() -> Dictionary:
	var scores: Dictionary = {}
	for id: int in Trace.canvases:
		var canvas: CanvasItem = instance_from_id(id) as CanvasItem
		if not is_instance_valid(canvas) or not canvas.is_visible_in_tree(): continue
		for row: Dictionary in Trace.canvases[id]:
			var popup: Dictionary = row["popup"]
			if popup.is_empty() or not str(row["detail"]).replace("−", "-").is_valid_int(): continue
			var extent: float = float(popup["size"])
			scores[str(popup["key"])] = extent * extent * float(popup["alpha"])
	return scores

func sample(scene: Node, board: Control) -> Dictionary:
	_board = board
	_paint.clear()
	_walk(scene, 0, 0, Masks.VIEWPORT, 1.0)
	_paint.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["layer"] != b["layer"]: return a["layer"] < b["layer"]
		if a["z"] != b["z"]: return a["z"] < b["z"]
		return a["tree"] < b["tree"])
	var labels: Array[Dictionary]
	var health: Dictionary = {}
	for canvas: Dictionary in _paint:
		for row: Dictionary in canvas["rows"]:
			if row["kind"] == "_owner": continue
			var item: Dictionary = _mask.compose(row, canvas["node"], canvas["clip"], canvas["alpha"])
			if item.is_empty(): continue
			item["layer"] = canvas["layer"]
			item["z"] = int(canvas["z"]) + int(item["band"])
			item["base_z"] = canvas["z"]
			item["tree"] = canvas["tree"]
			item["sequence"] = row.get("sequence", 0)
			item["canvas"] = str(scene.get_path_to(canvas["node"]))
			var owner: Dictionary = item["owner"]
			if item["kind"] == "unit_health" and health.has(owner["id"]):
				var earlier: Dictionary = health[owner["id"]]
				item["rect"] = Masks.union_rect(earlier["rect"], item["rect"])
				item["glyph_rect"] = Masks.union_rect(earlier["glyph_rect"], item["glyph_rect"])
				item["text_rect"] = Masks.union_rect(earlier["text_rect"], item["text_rect"])
				item["text"] = earlier["text"] + item["text"]
				item["shapes"] = earlier["shapes"] + item["shapes"]
				labels.erase(earlier)
			if item["kind"] == "unit_health": health[owner["id"]] = item
			labels.append(item)
	labels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["layer"] != b["layer"]: return a["layer"] < b["layer"]
		if a["z"] != b["z"]: return a["z"] < b["z"]
		if a["tree"] != b["tree"]: return a["tree"] < b["tree"]
		return a["sequence"] < b["sequence"])
	for i: int in range(labels.size()): labels[i]["order"] = i
	return {"labels": labels, "body_masks": _bodies(board)}

func _walk(node: Node, layer: int, z: int, clip: Rect2, opacity: float) -> void:
	if node is CanvasLayer:
		if not node.visible: return
		layer = node.layer
		z = 0
	if node is CanvasItem:
		if not node.is_visible_in_tree(): return
		z = z + node.z_index if node.z_as_relative else node.z_index
		opacity *= node.modulate.a
		if opacity <= 0.0: return
		for child: Node in node.get_children():
			if child is CanvasItem and child.show_behind_parent: _walk(child, layer, z, clip, opacity)
		var rows: Array = Trace.canvases.get(node.get_instance_id(), [])
		var control: Dictionary = _control_row(node)
		if not control.is_empty(): rows = rows + [control]
		if not rows.is_empty():
			_paint.append({"node": node, "layer": layer, "z": z, "clip": clip,
				"alpha": opacity * node.self_modulate.a, "rows": rows, "tree": _paint.size()})
		if node is Control and node.clip_contents: clip = clip.intersection(node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size))
	for child: Node in node.get_children():
		if child is CanvasItem and child.show_behind_parent: continue
		if child is Viewport: continue
		_walk(child, layer, z, clip, opacity)

func _control_row(node: CanvasItem) -> Dictionary:
	if not node is Label: return {}
	var label: Label = node
	if label.text.is_empty(): return {}
	var kind: String
	var owner: String
	var plate: StyleBoxFlat
	var plate_rect := Rect2()
	var source_texture: Texture2D
	var texture_rect := Rect2()
	var texture_is_glyph: bool = false
	match str(label.name):
		"TurnBannerLabel":
			kind = "turn_banner"
			owner = "combat turn"
		"ActionBanner":
			kind = "action_caption"
			owner = str(Trace.displayed.get("actor", ""))
			var scrim: Control = label.get_node_or_null("ActionCaptionScrim")
			if scrim != null:
				plate_rect = scrim.call("caption_scrim_rect")
				plate = StyleBoxFlat.new()
				plate.bg_color = Color(0.0, 0.0, 0.0, float(scrim.get_script().get_script_constant_map()["CAPTION_ALPHA"]))
			var icon: TextureRect = label.get_node_or_null("BattlefieldRuleCaptionIcon")
			if icon != null and icon.is_visible_in_tree():
				source_texture = icon.texture
				texture_rect = Rect2(icon.position, icon.size)
				texture_is_glyph = true
		"BossEncounterName":
			kind = "boss_name"
			owner = Trace.boss_key(_board)
		"BossHealthValue":
			kind = "boss_health"
			owner = Trace.boss_key(_board)
			var frame: TextureRect = label.get_parent().get_parent().get_node_or_null("BossHealthDragonFrame")
			if frame != null:
				source_texture = frame.texture
				texture_rect = label.get_global_transform_with_canvas().affine_inverse() * (frame.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, frame.size))
			plate_rect = Rect2(Vector2.ZERO, label.size)
			plate = StyleBoxFlat.new()
			plate.bg_color = Color.BLACK
		"Title":
			if str(label.get_parent().get_parent().name) != "SnareSealChips": return {}
			kind = "seals_pill"
			owner = str(label.get_parent().name)
			plate = label.get_parent().get_theme_stylebox("panel") as StyleBoxFlat
			var chip: Control = label.get_parent()
			var to_local: Transform2D = label.get_global_transform_with_canvas().affine_inverse()
			plate_rect = to_local * (chip.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, chip.size))
		_:
			var cell: Control = label.get_parent() as Control
			if cell == null or str(cell.get_parent().name) != "BossStatusRow": return {}
			kind = "boss_status"
			owner = Trace.boss_key(_board)
			for sibling: Node in cell.get_children():
				if sibling is TextureRect and sibling.is_visible_in_tree():
					source_texture = sibling.texture
					texture_rect = label.get_global_transform_with_canvas().affine_inverse() * (sibling.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, sibling.size))
					texture_is_glyph = true
					break
	var font: Font = label.get_theme_font("font")
	var font_px: int = label.get_theme_font_size("font_size")
	var offset: float = 0.0
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: offset = (label.size.y - font.get_height(font_px)) * 0.5
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: offset = label.size.y - font.get_height(font_px)
	var baseline := Vector2(0.0, offset + font.get_ascent(font_px))
	var ink: Array = []
	if plate != null and plate_rect.has_area(): ink.append([["style", plate_rect, plate], Transform2D.IDENTITY, 1.0, false])
	if source_texture != null: ink.append([["texture", texture_rect, source_texture, Rect2()], Transform2D.IDENTITY, 1.0, texture_is_glyph])
	var shadow: Vector2 = Vector2(label.get_theme_constant("shadow_offset_x"), label.get_theme_constant("shadow_offset_y"))
	var shadow_alpha: float = label.get_theme_color("font_shadow_color").a
	if shadow_alpha > 0.0:
		ink.append([["text", font, baseline + shadow, label.text, label.horizontal_alignment, label.size.x, font_px,
			label.get_theme_constant("shadow_outline_size")], Transform2D.IDENTITY, shadow_alpha, false])
	var outline: int = label.get_theme_constant("outline_size")
	if outline > 0:
		ink.append([["text", font, baseline, label.text, label.horizontal_alignment, label.size.x, font_px, outline],
			Transform2D.IDENTITY, label.get_theme_color("font_outline_color").a, false])
	ink.append([["text", font, baseline, label.text, label.horizontal_alignment, label.size.x, font_px, 0],
		Transform2D.IDENTITY, label.get_theme_color("font_color").a, true])
	return {"kind": kind, "owner": {"id": owner, "tile": []}, "detail": "", "text": [label.text], "ink": ink, "popup": {}}

func _bodies(board: Control) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	var global: Transform2D = board.get_global_transform_with_canvas()
	for source: Dictionary in silhouettes.current_sources():
		if source["kind"] != "unit" or not source.get("eligible", false): continue
		var mask: Dictionary = _silhouettes.mask_for(source)
		if mask.is_empty() or (mask["points"] as PackedVector2Array).is_empty(): continue
		var rect: Rect2 = global * (source["rect"] as Rect2)
		var min_y: float = 1.0
		var max_y: float = 0.0
		for point: Vector2 in mask["points"]:
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)
		var cutoff: float = rect.position.y + lerpf(min_y, max_y, HEAD_TORSO_TOP) * rect.size.y
		result.append({"id": source["key"], "rect": rect, "cutoff": cutoff, "mask": mask, "mask_flip": source.get("mask_flip", false)})
	return result

static func evaluate(frame: Dictionary) -> Dictionary:
	var labels: Array = frame["labels"]
	var pairs: Array
	var hits: Array
	var public: Array
	for i: int in range(labels.size()):
		var lower: Dictionary = labels[i]
		var text: Rect2 = lower["text_rect"]
		if not text.has_area(): text = lower["glyph_rect"]
		var lower_rect: Rect2 = lower["rect"]
		var text_area: int = Masks.pixel_count(text)
		var receipt: Dictionary = lower.duplicate()
		receipt.erase("shapes")
		receipt.erase("tree")
		receipt.erase("sequence")
		receipt["rect"] = rect_values(lower_rect)
		receipt["glyph_rect"] = rect_values(lower["glyph_rect"])
		receipt["text_rect"] = rect_values(lower["text_rect"])
		public.append(receipt)
		for j: int in range(i + 1, labels.size()):
			var upper: Dictionary = labels[j]
			var upper_rect: Rect2 = upper["rect"]
			var area: float = upper_rect.intersection(lower_rect).get_area()
			var share: float = area / minf(lower_rect.get_area(), upper_rect.get_area())
			var lost: int = 0
			if text_area > 0 and upper_rect.intersects(text):
				var shapes: Array = upper["shapes"]
				if int(upper["band"]) > 0 and upper["layer"] == lower["layer"]:
					shapes = shapes.filter(func(shape: Dictionary) -> bool:
						var z: int = int(upper["base_z"]) + int(shape["band"])
						if z != lower["z"]: return z > lower["z"]
						if upper["tree"] != lower["tree"]: return upper["tree"] > lower["tree"]
						return upper["sequence"] > lower["sequence"])
				lost = Masks.opaque_pixels(shapes, upper_rect.intersection(text))
			var loss: float = float(lost) / text_area if text_area > 0 else 0.0
			pairs.append([i, j, area, share, loss, share >= PAIR_OVERLAP or loss >= TEXT_LOSS])
		if text_area <= 0: continue
		for body: Dictionary in frame["body_masks"]:
			var rect: Rect2 = body["rect"]
			rect.size.y = float(body["cutoff"]) - rect.position.y
			var overlap: Rect2 = rect.intersection(text)
			if not overlap.has_area(): continue
			var filled: int = 0
			for y: int in range(ceili(overlap.position.y - 0.5), ceili(overlap.end.y - 0.5)):
				for x: int in range(ceili(overlap.position.x - 0.5), ceili(overlap.end.x - 0.5)):
					filled += int(Alpha.opaque_at(body, Vector2(x + 0.5, y + 0.5)))
			if filled > 0:
				var share: float = float(filled) / text_area
				hits.append([i, body["id"], filled, share, share >= TEXT_LOSS])
	return {"labels": public, "pairs": pairs, "unit_hits": hits}

static func rect_values(rect: Rect2) -> Array[float]:
	var values: Array[float] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return values
