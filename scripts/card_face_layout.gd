extends RefCounted
## Layout of a sentence card face (playability plan 2026-11-20, round 5): a
## target chip, then one centred sentence in the rules-text font with inline
## icon tokens, and pattern diagrams inline or under the sentence. The rules
## are the approved mock compositor's (compose_v5.py, copied with the probe to
## tools/pla03/): line breaks fall between words, never inside a term token;
## the art lends height before anything shrinks; every chip, line and diagram
## keeps a comfort margin from the parchment edge at its height.
##
## All lengths are the widget's local units. Constants are for a 250x352 card
## (layout scale 1) and scale with the card.

const SummaryMeasurements = preload("res://scripts/card_summary_measurements.gd")
const FaceSpec = preload("res://scripts/card_face_spec.gd")
const AoePatternView = preload("res://scripts/aoe_pattern_view.gd")

const TOP_PAD: float = 3.0
const CHIP_HEIGHT: float = 24.0
const CHIP_GAP: float = 6.0
const NO_CHIP_PAD: float = 2.0
const CHIP_PAD: float = 6.0
const CHIP_ICON: float = 17.0
const CHIP_ICON_GAP: float = 3.0
const CHIP_RANGE_GAP: float = 7.0
const CHIP_RANGE_ICON: float = 15.0
const CHIP_NUMBER_GAP: float = 2.0
const WRAP_WIDTHS: Array = [162.0, 154.0, 146.0, 138.0]
const UNDER_SCALES: Array = [0.9, 0.8, 0.7, 0.6]
const INLINE_PATTERN_SCALE: float = 0.6
const DIAGRAM_GAP: float = 5.0
const ORDER_GAP: float = 5.0
const ORDER_MARK: String = "→"
const VERTICAL_PADDING: float = 10.0
const LEND_STEP: float = 0.5
const TALL_LINE_EXTRA: float = 2.0
# Inline icon height is 1.25x the text's cap height; both card fonts share
# sCapHeight / unitsPerEm = 0.72 (LabyrinthCrumble-Text and -UI).
const ICON_CAP_RATIO: float = 1.25
const CAP_HEIGHT_RATIO: float = 0.72
const ICON_GAP_BEFORE: float = 0.06
const ICON_GAP_AFTER: float = 0.07
const PHRASE_PENALTY: float = 12.0
const RELAXED_PHRASE_PENALTY: float = 4.0
const COMFORT_HALF_WIDTH: float = 82.0
# Allowed half-width of a line at each card y (143..329), measured from the
# light parchment of real captures (mocks_v2 parchment_profile.json: median of
# +-6 rows, +3, capped at the 164-wide comfort measure). It narrows toward the
# torn lower edge and the frame's bottom corners.
const PARCHMENT_TOP_Y: int = 143
const PARCHMENT_HALF_WIDTH: Array = [
	81.88, 81.88, 80.94, 81.88, 81.88, 81.88, 81.88, 81.88, 81.88, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82,
	82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82,
	82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82,
	81.88, 81.88, 81.88, 81.88, 81.88, 81.88, 81.88, 81.88, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82,
	82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 81.88, 81.88, 81.88,
	79.06, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 79.06, 79.06,
	78.12, 78.12, 78.12, 78.12, 78.12, 78.12, 76.24, 69.67, 69.67, 69.67, 69.67, 69.67, 69.67, 69.67, 69.67,
	67.79, 65.91, 65.91, 65.91, 64.04, 64.04, 64.04, 64.04, 64.04, 63.1, 53.71, 52.77, 52.77, 52.77, 52.77,
	52.77, 48.07, 18.96, 18.96, 18.96, 18.96, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
]
# A line never ends on a word that opens a phrase; phrase starters and clause
# ends are good places to break.
const FUNCTION_WORDS: Dictionary = {
	"the": true, "a": true, "an": true, "on": true, "to": true, "of": true, "in": true, "every": true,
	"each": true, "is": true, "was": true, "if": true, "and": true, "then": true, "toward": true,
	"from": true, "next": true, "under": true, "this": true, "which": true, "already": true,
	"stands": true, "burst": true, "deal": true, "push": true, "pull": true, "strike": true,
	"create": true, "gain": true, "draw": true, "move": true, "leave": true, "expose": true,
	"stagger": true, "it": true, "also": true,
}
const PHRASE_STARTERS: Dictionary = {
	"and": true, "then": true, "If": true, "which": true, "toward": true, "instead.": true, "each": true,
	"every": true, "on": true, "in": true, "under": true,
}

static var _plans: Dictionary = {}
const PLAN_CACHE_CAPACITY: int = 64

## metrics: text_font, ui_font (Font), text_sizes (descending ints: the context
## size first, the rules size last), chip_size (int), scale (layout scale),
## rows_top (card y of the rows box before any art lend), details_height and
## max_relief (art height the face may borrow).
static func plan(face: Dictionary, metrics: Dictionary) -> Dictionary:
	var key: Array = [face, metrics["text_sizes"], metrics["chip_size"], metrics["scale"], metrics["rows_top"],
		metrics["details_height"], metrics["max_relief"], (metrics["text_font"] as Font).get_instance_id(),
		SummaryMeasurements.font_revision(metrics["text_font"]), (metrics["ui_font"] as Font).get_instance_id()]
	if _plans.has(key):
		return _plans[key]
	var result: Dictionary = _plan_uncached(face, metrics)
	if _plans.size() >= PLAN_CACHE_CAPACITY:
		_plans.erase(_plans.keys()[0])
	_plans[key] = result
	return result

static func _plan_uncached(face: Dictionary, metrics: Dictionary) -> Dictionary:
	var sizes: Array = metrics["text_sizes"]
	for penalty: float in [PHRASE_PENALTY, RELAXED_PHRASE_PENALTY]:
		for size_var: Variant in sizes:
			var candidate: Dictionary = _plan_at(face, metrics, int(size_var), penalty)
			if bool(candidate["fits"]):
				candidate["phrase_breaks"] = penalty < PHRASE_PENALTY
				return candidate
	# Nothing clears the edge: the full-width face at the rules size and the
	# maximum lend, flagged so a check names it.
	var fallback: Dictionary = _build(face, metrics, int(sizes.back()), PHRASE_PENALTY, float(WRAP_WIDTHS[0]), float(UNDER_SCALES.back()))
	fallback["lend"] = float(metrics["max_relief"])
	fallback["fits"] = false
	fallback["phrase_breaks"] = false
	return fallback

static func _plan_at(face: Dictionary, metrics: Dictionary, text_size: int, penalty: float) -> Dictionary:
	var layout_scale: float = float(metrics["scale"])
	var has_under: bool = not _under_patterns(face).is_empty()
	var under_scales: Array = UNDER_SCALES if has_under else [0.0]
	var last: Dictionary = {}
	for width_var: Variant in WRAP_WIDTHS:
		for under_var: Variant in under_scales:
			var candidate: Dictionary = _build(face, metrics, text_size, penalty, float(width_var), float(under_var))
			var need: float = maxf(0.0, float(candidate["height"]) + VERTICAL_PADDING * layout_scale - float(metrics["details_height"]))
			var lend: float = need
			while lend <= float(metrics["max_relief"]) + 0.0001:
				if _clears_parchment(candidate, float(metrics["rows_top"]) - lend, layout_scale):
					candidate["lend"] = snappedf(lend, 0.01)
					candidate["fits"] = true
					return candidate
				lend += LEND_STEP * layout_scale
			last = candidate
	last["fits"] = false
	return last

## Allowed half-width over card rows y0..y1 (local units).
static func allowed_half_width(y0: float, y1: float, layout_scale: float) -> float:
	var allowed: float = COMFORT_HALF_WIDTH
	var first: int = int(y0 / layout_scale)
	var last: int = int(y1 / layout_scale)
	for y: int in range(first, last + 1):
		var index: int = y - PARCHMENT_TOP_Y
		if index < 0:
			continue
		allowed = minf(allowed, float(PARCHMENT_HALF_WIDTH[index]) if index < PARCHMENT_HALF_WIDTH.size() else 0.0)
	return allowed * layout_scale

static func _clears_parchment(candidate: Dictionary, top: float, layout_scale: float) -> bool:
	var chip: Dictionary = candidate["chip"]
	if not chip.is_empty():
		var chip_top: float = top + float(chip["y"])
		if float(chip["width"]) * 0.5 > allowed_half_width(chip_top, chip_top + float(chip["height"]), layout_scale):
			return false
	for line: Dictionary in candidate["lines"]:
		var line_top: float = top + float(line["y"])
		if float(line["width"]) * 0.5 > allowed_half_width(line_top, line_top + float(line["height"]), layout_scale):
			return false
	var under: Dictionary = candidate["under"]
	if not under.is_empty():
		var under_top: float = top + float(under["y"])
		if float(under["width"]) * 0.5 > allowed_half_width(under_top, under_top + float(under["height"]), layout_scale):
			return false
	return true

# ---------------------------------------------------------------- building

## One full candidate: chip, wrapped lines and under-diagrams with positions
## relative to the face's top centre.
static func _build(face: Dictionary, metrics: Dictionary, text_size: int, penalty: float, wrap_width: float, under_scale: float) -> Dictionary:
	var layout_scale: float = float(metrics["scale"])
	var font: Font = metrics["text_font"]
	var pitch: float = SummaryMeasurements.text_height(font, text_size)
	var ascent: float = font.get_ascent(text_size)
	var cap: float = CAP_HEIGHT_RATIO * float(text_size)
	var space: float = SummaryMeasurements.text_width(font, text_size, " ")
	var words: Array = _words(face, font, text_size, layout_scale)
	var y: float = TOP_PAD * layout_scale
	var chip: Dictionary = _chip(face.get("chip", null), metrics, layout_scale)
	if not chip.is_empty():
		chip["y"] = y
		y += (CHIP_HEIGHT + CHIP_GAP) * layout_scale
	else:
		y += NO_CHIP_PAD * layout_scale
	var lines: Array = []
	for range_var: Variant in _wrap(words, space, wrap_width * layout_scale, penalty):
		var span: Vector2i = range_var
		var line_words: Array = words.slice(span.x, span.y)
		var width: float = space * float(line_words.size() - 1)
		var tallest: float = 0.0
		for word: Dictionary in line_words:
			width += float(word["width"])
			tallest = maxf(tallest, float(word["height"]))
		var height: float = maxf(tallest + (TALL_LINE_EXTRA * layout_scale if tallest > pitch else 0.0), pitch)
		var baseline: float = y + (height - pitch) * 0.5 + ascent
		var pieces: Array = []
		var x: float = -width * 0.5
		var text: PackedStringArray = PackedStringArray()
		for word: Dictionary in line_words:
			for piece_var: Variant in word["pieces"]:
				var piece: Dictionary = (piece_var as Dictionary).duplicate()
				piece["x"] = x + float(piece["dx"])
				match str(piece["kind"]):
					"icon":
						piece["y"] = baseline - cap * 0.5 - float(piece["h"]) * 0.5
					"pattern":
						piece["y"] = y + (height - float(piece["h"])) * 0.5
					_:
						piece["baseline"] = baseline
				pieces.append(piece)
			text.append(str(word["raw"]))
			x += float(word["width"]) + space
		lines.append({"y": y, "height": height, "width": width, "pieces": pieces, "text": " ".join(text)})
		y += height
	var under: Dictionary = _under(face, metrics, text_size, under_scale, layout_scale)
	if not under.is_empty():
		y += DIAGRAM_GAP * layout_scale
		under["y"] = y
		for item: Dictionary in under["items"]:
			if str(item["kind"]) == "pattern":
				item["y"] = y + (float(under["height"]) - float(item["h"])) * 0.5
			else:
				item["baseline"] = y + float(under["height"]) * 0.5 + cap * 0.5
		y += float(under["height"])
	return {
		"text_size": text_size, "pitch": pitch, "wrap_width": wrap_width, "under_scale": under_scale,
		"chip": chip, "lines": lines, "under": under, "height": y, "lend": 0.0, "fits": false,
	}

static func _icon_height(text_size: int) -> float:
	return CAP_HEIGHT_RATIO * float(text_size) * ICON_CAP_RATIO

## Sentence segments -> words (wrap units). A term or damage token is one
## indivisible run; text segments break only at their spaces; punctuation that
## touches a token stays with it.
static func _words(face: Dictionary, font: Font, text_size: int, layout_scale: float) -> Array:
	var segments: Array = _inline_segments(face)
	var words: Array = []
	var current: Array = []
	for index: int in range(segments.size()):
		var segment: Dictionary = segments[index]
		if segment.has("text"):
			var buffer: String = ""
			for character: String in str(segment["text"]):
				if character == " ":
					if not buffer.is_empty():
						current.append({"kind": "text", "text": buffer})
						buffer = ""
					if not current.is_empty():
						words.append(current)
						current = []
				else:
					buffer += character
			if not buffer.is_empty():
				current.append({"kind": "text", "text": buffer})
		elif segment.has("term"):
			current.append({"kind": "icon", "icon": str(segment["term"]), "segment": int(segment["_index"])})
			current.append({"kind": "text", "text": str(segment.get("word", "")), "segment": int(segment["_index"])})
			if segment.get("number", null) != null:
				current.append({"kind": "space"})
				current.append({"kind": "number", "text": str(segment.get("display", segment["number"])), "segment": int(segment["_index"])})
		elif segment.has("damage"):
			if bool(segment.get("bonus", false)):
				current.append({"kind": "text", "text": "+"})
			current.append({"kind": "icon", "icon": str(segment["damage"]), "segment": int(segment["_index"])})
			current.append({"kind": "number", "text": str(segment.get("display", segment["number"])), "segment": int(segment["_index"])})
		elif segment.has("duration"):
			current.append({"kind": "number", "text": str(segment.get("display", int(segment["duration"]))), "segment": int(segment["_index"])})
		elif segment.has("number"):
			current.append({"kind": "number", "text": str(segment.get("display", int(segment["number"]))), "segment": int(segment["_index"])})
		elif segment.has("pattern"):
			current.append({"kind": "pattern", "pattern": str(segment["pattern"]), "segment": int(segment["_index"])})
	if not current.is_empty():
		words.append(current)
	words = _glue_conditions(words)
	# Keep prose endings together. A final icon term is already indivisible
	# and must be able to start a line of its own.
	if words.size() >= 2 and not _is_pattern_word(words.back()) and not _is_pattern_word(words[words.size() - 2]) and str(words.back()[0].get("kind", "")) != "icon":
		var joined: Array = (words[words.size() - 2] as Array) + [{"kind": "space"}] + (words[words.size() - 1] as Array)
		words.resize(words.size() - 2)
		words.append(joined)
	var measured: Array = []
	for pieces: Array in words:
		measured.append(_measure_word(pieces, font, text_size, layout_scale))
	return measured

## "On [ground]" is the one condition form: its "On" never ends a line.
static func _glue_conditions(words: Array) -> Array:
	var result: Array = []
	var index: int = 0
	while index < words.size():
		var pieces: Array = words[index]
		if index + 1 < words.size() and pieces.size() == 1 and str((pieces[0] as Dictionary).get("text", "")).to_lower() == "on":
			var following: Array = words[index + 1]
			var lead: Dictionary = following[0]
			if str(lead["kind"]) == "icon" and str(lead["icon"]).begins_with("surface_"):
				result.append(pieces + [{"kind": "space"}] + following)
				index += 2
				continue
		result.append(pieces)
		index += 1
	return result

static func _is_pattern_word(pieces: Array) -> bool:
	return not pieces.is_empty() and str((pieces[0] as Dictionary)["kind"]) == "pattern"

static func _measure_word(pieces: Array, font: Font, text_size: int, layout_scale: float) -> Dictionary:
	var x: float = 0.0
	var height: float = SummaryMeasurements.text_height(font, text_size)
	var raw: String = ""
	var placed: Array = []
	var icon_height: float = _icon_height(text_size)
	var previous: String = ""
	for piece_var: Variant in pieces:
		var piece: Dictionary = (piece_var as Dictionary).duplicate()
		match str(piece["kind"]):
			"icon":
				if previous in ["text", "number"]:
					x += ICON_GAP_BEFORE * float(text_size)
				piece["dx"] = x
				piece["h"] = icon_height
				piece["w"] = icon_height * float(FaceSpec.icon_entry(str(piece["icon"]))["aspect"])
				x += float(piece["w"]) + ICON_GAP_AFTER * float(text_size)
				raw += "{%s}" % str(piece["icon"])
			"space":
				piece["dx"] = x
				x += SummaryMeasurements.text_width(font, text_size, " ")
				raw += "~"
			"pattern":
				var size: Vector2 = AoePatternView.measured_size(FaceSpec.pattern_offsets(str(piece["pattern"])), FaceSpec.pattern_shows_origin(str(piece["pattern"])), INLINE_PATTERN_SCALE * layout_scale)
				piece["dx"] = x
				piece["w"] = size.x
				piece["h"] = size.y
				piece["scale"] = INLINE_PATTERN_SCALE * layout_scale
				x += size.x
				height = maxf(height, size.y)
				raw += "{pat:%s}" % str(piece["pattern"])
			_:
				piece["dx"] = x
				piece["w"] = SummaryMeasurements.text_width(font, text_size, str(piece["text"]))
				x += float(piece["w"])
				raw += ("#" if str(piece["kind"]) == "number" else "") + str(piece["text"])
		previous = str(piece["kind"])
		if previous != "space":
			placed.append(piece)
	return {"pieces": placed, "width": x, "height": height, "raw": raw, "pattern": _is_pattern_word(pieces)}

## Fewest lines, then breaks at sentence and clause ends and before phrase
## starters, never after a word that opens a phrase.
static func _wrap(words: Array, space: float, width: float, penalty: float) -> Array:
	var count: int = words.size()
	var best_cost: Array = []
	var best_from: Array = []
	best_cost.resize(count + 1)
	best_from.resize(count + 1)
	best_cost.fill(INF)
	best_from.fill(-1)
	best_cost[0] = 0.0
	for end: int in range(1, count + 1):
		for start: int in range(end):
			if is_inf(float(best_cost[start])):
				continue
			var line_width: float = space * float(end - start - 1)
			for index: int in range(start, end):
				line_width += float((words[index] as Dictionary)["width"])
			if line_width > width and end - start > 1:
				continue
			var cost: float = 10.0 + (1000.0 if line_width > width else 0.0)
			if end < count:
				cost += pow((width - line_width) / width, 2.0) + _break_cost(words[end - 1], words[end], penalty)
			if float(best_cost[start]) + cost < float(best_cost[end]):
				best_cost[end] = float(best_cost[start]) + cost
				best_from[end] = start
	var spans: Array = []
	var cursor: int = count
	while cursor > 0:
		var start: int = int(best_from[cursor])
		spans.push_front(Vector2i(start, cursor))
		cursor = start
	return spans

static func _break_cost(previous: Dictionary, following: Dictionary, penalty: float) -> float:
	var text: String = str(previous["raw"])
	if text.ends_with("."):
		return -1.0
	if text.ends_with(",") or text.ends_with(":"):
		return -0.6
	if FUNCTION_WORDS.has(text.to_lower()):
		return penalty
	if PHRASE_STARTERS.has(str(following["raw"])):
		return -0.3
	if bool(following["pattern"]):
		return 3.0  # A diagram stays beside the words it shapes.
	return 0.0

# ---------------------------------------------------------------- chip

static func _chip(chip_var: Variant, metrics: Dictionary, layout_scale: float) -> Dictionary:
	if typeof(chip_var) != TYPE_DICTIONARY:
		return {}
	var chip: Dictionary = chip_var
	var font: Font = metrics["ui_font"]
	var size: int = int(metrics["chip_size"])
	var items: Array = []
	var x: float = CHIP_PAD * layout_scale
	if chip.get("icon", null) != null:
		var icon_h: float = CHIP_ICON * layout_scale
		var icon_w: float = icon_h * float(FaceSpec.icon_entry(str(chip["icon"]))["aspect"])
		items.append({"kind": "icon", "icon": str(chip["icon"]), "dx": x, "w": icon_w, "h": icon_h})
		x += icon_w + CHIP_ICON_GAP * layout_scale
	var word: String = str(chip.get("word", ""))
	items.append({"kind": "text", "text": word, "dx": x, "w": SummaryMeasurements.text_width(font, size, word)})
	x += float(items.back()["w"]) + CHIP_RANGE_GAP * layout_scale
	var range_h: float = CHIP_RANGE_ICON * layout_scale
	var range_w: float = range_h * float(FaceSpec.icon_entry("range")["aspect"])
	items.append({"kind": "icon", "icon": "range", "dx": x, "w": range_w, "h": range_h})
	x += range_w + CHIP_NUMBER_GAP * layout_scale
	var number: String = str(chip.get("display", chip.get("range", "")))
	items.append({"kind": "number", "text": number, "dx": x, "w": SummaryMeasurements.text_width(font, size, number)})
	x += float(items.back()["w"]) + CHIP_PAD * layout_scale
	var height: float = CHIP_HEIGHT * layout_scale
	var middle: float = height * 0.5
	for item: Dictionary in items:
		item["x"] = float(item["dx"]) - x * 0.5
		if str(item["kind"]) == "icon":
			item["y"] = middle - float(item["h"]) * 0.5
		else:
			item["baseline"] = middle + CAP_HEIGHT_RATIO * float(size) * 0.5
	return {"width": x, "height": height, "items": items, "text_size": size, "y": 0.0}

# ---------------------------------------------------------------- diagrams

## Patterns after the sentence's last words are drawn under it, side by side
## in their order; any other pattern sits inline beside the words it shapes.
static func _under_patterns(face: Dictionary) -> Array:
	var sentence: Array = face.get("sentence", []) as Array
	var result: Array = []
	for index: int in range(sentence.size() - 1, -1, -1):
		var segment: Dictionary = sentence[index]
		if segment.has("pattern"):
			result.push_front({"pattern": str(segment["pattern"]), "segment": index})
		elif segment.has("text") and str(segment["text"]).strip_edges().is_empty():
			continue
		else:
			break
	return result

static func _inline_segments(face: Dictionary) -> Array:
	var sentence: Array = face.get("sentence", []) as Array
	var keep: int = sentence.size()
	for index: int in range(sentence.size() - 1, -1, -1):
		var segment: Dictionary = sentence[index]
		if segment.has("pattern") or (segment.has("text") and str(segment["text"]).strip_edges().is_empty()):
			keep = index
		else:
			break
	var result: Array = []
	for index: int in range(keep):
		var segment: Dictionary = (sentence[index] as Dictionary).duplicate()
		segment["_index"] = index
		result.append(segment)
	return result

static func _under(face: Dictionary, metrics: Dictionary, text_size: int, under_scale: float, layout_scale: float) -> Dictionary:
	var entries: Array = _under_patterns(face)
	if entries.is_empty():
		return {}
	var font: Font = metrics["text_font"]
	var arrow: float = SummaryMeasurements.text_width(font, text_size, ORDER_MARK)
	var items: Array = []
	var x: float = 0.0
	var height: float = 0.0
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if index > 0:
			x += ORDER_GAP * layout_scale
			items.append({"kind": "arrow", "text": ORDER_MARK, "dx": x, "w": arrow})
			x += arrow + ORDER_GAP * layout_scale
		var pattern_scale: float = under_scale * layout_scale
		var pattern_id: String = str(entry["pattern"])
		var size: Vector2 = AoePatternView.measured_size(FaceSpec.pattern_offsets(pattern_id), FaceSpec.pattern_shows_origin(pattern_id), pattern_scale)
		items.append({"kind": "pattern", "pattern": pattern_id, "dx": x, "w": size.x, "h": size.y, "scale": pattern_scale, "segment": int(entry["segment"])})
		x += size.x
		height = maxf(height, size.y)
	for item: Dictionary in items:
		item["x"] = float(item["dx"]) - x * 0.5
	return {"width": x, "height": height, "items": items, "y": 0.0}
