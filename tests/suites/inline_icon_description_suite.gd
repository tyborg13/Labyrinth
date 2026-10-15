extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const EventText = preload("res://scripts/event_view_text.gd")

const ICONLESS_SKILLS: Array[String] = [
	"curators_patience",
	"deferred_choice",
	"discerning_eye",
	"layaway",
	"open_arsenal",
	"salvager",
]

const DEDICATED_ICON_TERM_PATTERNS: Array = [
	{"label": "Fire", "pattern": "(?i)\\bfire\\b"},
	{"label": "Ice", "pattern": "(?i)\\bice\\b"},
	{"label": "Rubble", "pattern": "(?i)\\brubble\\b"},
	{"label": "Electrified", "pattern": "(?i)\\belectrified\\b"},
	{"label": "Chilled", "pattern": "(?i)\\bchill(?:ed)?\\b"},
	{"label": "Detonate", "pattern": "(?i)\\bdetonat(?:e|es|ed|ing)\\b"},
	{"label": "Relocate Ground", "pattern": "(?i)\\brelocat(?:e|es|ed|ing)\\b"},
	{"label": "Block", "pattern": "(?i)\\bblock\\b"},
	{"label": "Stoneskin", "pattern": "(?i)\\bstoneskin\\b"},
	{"label": "Health", "pattern": "(?i)\\bhealth(?:-cost)?\\b"},
	{"label": "Heal", "pattern": "(?i)\\bheal(?:s|ed|ing)?\\b"},
	{"label": "Draw", "pattern": "(?i)\\bdraws?\\b"},
	{"label": "Card Play", "pattern": "(?i)\\bcard plays?\\b"},
	{"label": "Move", "pattern": "(?i)\\bmove(?:s|d|ing)?\\b"},
	{"label": "Blink", "pattern": "(?i)\\bblinks?(?:ed|ing)?\\b"},
	{"label": "Range", "pattern": "(?i)\\brange\\b"},
	{"label": "Ranged", "pattern": "(?i)\\branged\\b"},
	{"label": "Melee", "pattern": "(?i)\\bmelee\\b"},
	{"label": "Pierce", "pattern": "(?i)\\bpierce(?:s|d)?\\b"},
	{"label": "Push", "pattern": "(?i)\\bpush(?:es|ed|ing)?\\b"},
	{"label": "Pull", "pattern": "(?i)\\bpull(?:s|ed|ing)?\\b"},
	{"label": "Chain", "pattern": "(?i)\\bchain(?:s|ed|ing)?\\b"},
	{"label": "Illusion", "pattern": "(?i)\\billusions?\\b"},
	{"label": "Light", "pattern": "(?i)\\blight(?:s|ed|ing)?\\b"},
	{"label": "Vision", "pattern": "(?i)\\bvision\\b"},
	{"label": "Truesight", "pattern": "(?i)\\btruesight\\b"},
	{"label": "Umbra", "pattern": "(?i)\\bumbra\\b"},
	{"label": "Burn", "pattern": "(?i)\\bburn(?:s|ed|ing)?\\b"},
	{"label": "Bleed", "pattern": "(?i)\\bbleed(?:s|ing)?\\b"},
	{"label": "Expose", "pattern": "(?i)\\bexpose(?:s|d)?\\b"},
	{"label": "Freeze", "pattern": "(?i)\\b(?:freeze|freezes|freezing|frozen)\\b"},
	{"label": "Shock", "pattern": "(?i)\\bshock(?:s|ed|ing)?\\b"},
	{"label": "Poison", "pattern": "(?i)\\bpoison(?:s|ed|ing)?\\b"},
	{"label": "Fatigue", "pattern": "(?i)\\bfatigue\\b"},
	{"label": "Defiance", "pattern": "(?i)\\bdefiance\\b"},
	{"label": "Intensity", "pattern": "(?i)\\bintensity\\b"},
	{"label": "Trap", "pattern": "(?i)\\btraps?\\b"},
	{"label": "Exhaust", "pattern": "(?i)\\bexhaust(?:s|ed|ing)?\\b"},
	{"label": "Time", "pattern": "\\bTime\\b"},
]


static func run(expect: Callable) -> void:
	var approved: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/text/relic_rewrite.json")):
		approved[str(row["id"])] = row
	var relic_icon_count: int = 0
	for relic_id: String in GameData.relic_ids():
		var description: String = str(GameData.relic_def(relic_id).get("description", ""))
		relic_icon_count += InlineIconText.concept_keys(description).size()
		expect.call(InlineIconText.has_icons(description), "%s relic rules should use at least one established mechanic token" % relic_id)
		expect.call(description == approved[relic_id]["description"], "Relic %s preserves every approved word and explicit concept token" % relic_id)
		expect.call(InlineIconText.invalid_icon_keys(description).is_empty(), "Relic %s resolves every explicit concept" % relic_id)
	expect.call(relic_icon_count >= 180, "The full relic audit should retain broad explicit-concept coverage")

	var skill_icon_count: int = 0
	var iconless_skills: Array[String]
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var description: String = SkillTreeLibrary.description(skill_id)
		var icon_keys: Array[String] = InlineIconText.icon_keys(description)
		skill_icon_count += icon_keys.size()
		if icon_keys.is_empty():
			iconless_skills.append(skill_id)
		_audit_description(expect, "ability %s" % skill_id, description)
	iconless_skills.sort()
	expect.call(iconless_skills == ICONLESS_SKILLS, "Only abilities without an exact card-action concept should remain text-only: %s" % str(iconless_skills))
	expect.call(skill_icon_count >= 50, "The full ability audit should retain broad inline-icon coverage")

	_test_concept_tokens(expect)
	_test_token_syntax(expect)

	var example: String = "Create @icon(illuminate) 2 for @icon(time) 2."
	expect.call(InlineIconText.plain_text(example) == "Create Light 2 for Time 2.", "Inline icon rules should retain an accessible plain-text expansion")
	var rendered := RichTextLabel.new()
	rendered.add_theme_font_size_override("normal_font_size", UiTypography.SIZE_BODY_LARGE)
	InlineIconText.apply_to(rendered, example)
	expect.call(int(rendered.get_meta("inline_icon_font_size", 0)) == UiTypography.SIZE_BODY_LARGE, "Inline icon rules should retain the enlarged rules-text size")
	expect.call(float(rendered.get_meta("inline_icon_size", 0.0)) > float(UiTypography.SIZE_BODY_LARGE), "Inline mechanic icons should render larger than their surrounding rules text")
	rendered.free()


static func _audit_description(expect: Callable, source: String, description: String) -> void:
	expect.call(InlineIconText.invalid_icon_keys(description).is_empty(), "%s should resolve every inline icon key" % source)
	var plain_source: String = _without_icon_tokens(description)
	plain_source = plain_source.replace("draw pile", "pile").replace("Draw pile", "Pile")
	for pattern_def: Dictionary in DEDICATED_ICON_TERM_PATTERNS:
		var regex := RegEx.new()
		var compile_error: Error = regex.compile(str(pattern_def.get("pattern", "")))
		expect.call(compile_error == OK, "Inline-icon audit pattern should compile for %s" % str(pattern_def.get("label", "term")))
		if compile_error != OK:
			continue
		expect.call(regex.search(plain_source) == null, "%s still spells out the dedicated %s icon concept: %s" % [source, str(pattern_def.get("label", "term")), plain_source])


static func _without_icon_tokens(markup: String) -> String:
	var regex := RegEx.new()
	if regex.compile(InlineIconText.TokenSyntax.TOKEN_PATTERN) != OK:
		return markup
	return regex.sub(markup, "", true)


static func _test_concept_tokens(expect: Callable) -> void:
	var markup: String = "Gain @term(health). @kw(illusion|Illusions) use @kw(movement)."
	expect.call(InlineIconText.plain_text(markup) == "Gain Health. Illusions use Movement.", "Concepts expand to canonical names and exact approved inflections")
	expect.call(InlineIconText.icon_keys(markup) == ["health"], "Only term/icon tokens emit artwork; keyword-only tokens do not")
	expect.call(InlineIconText.concept_keys(markup) == ["health", "illusion", "movement"], "Every explicit token retains its semantic key")
	expect.call(InlineIconText.has_icons("@kw(movement)"), "Word-only markup takes the rich-text path")
	expect.call(InlineIconText.invalid_icon_keys("@term(no_such_term) @kw(no_such_keyword)") == ["no_such_term", "no_such_keyword"], "Unknown term and keyword keys fail validation")
	expect.call(InlineIconText.invalid_icon_keys("@kw(turns) @kw(item) @kw(outcrop)").is_empty(), "Text-only glossary entries need no invented icons")
	var glossary = preload("res://scripts/glossary.gd")
	var saved: Dictionary = glossary._entries["health"].duplicate(true)
	glossary._entries["health"]["name"] = "debug live name"
	expect.call(InlineIconText.plain_text("@term(health) @kw(health) @kw(health|Health)") == "debug live name debug live name Health", "Both token kinds read names at render time; explicit forms remain verbatim")
	glossary._entries["health"] = saved
	var label := RichTextLabel.new()
	label.add_theme_font_override("normal_font", UiTypography.ui_font())
	label.add_theme_font_size_override("normal_font_size", UiTypography.SIZE_BODY_LARGE)
	var host_font: Font = label.get_theme_font("normal_font")
	InlineIconText.apply_to(label, markup)
	expect.call(InlineIconText.KEYWORD_COLOR == UiPalette.GOLD_BRIGHT, "Concept words use the director's shared gold token")
	expect.call(not label.hint_underlined, "Glossary hint words have no underline")
	expect.call(label.get_theme_font("normal_font") == host_font and label.get_theme_font_size("normal_font_size") == UiTypography.SIZE_BODY_LARGE, "Concept styling preserves host font and size")
	expect.call(not label.get_parsed_text().contains("@") and label.get_parsed_text().contains("Illusions use Movement."), "Rendered words contain no raw token markup")
	expect.call(label.get_meta("inline_icon_keys") == ["health"], "Rendered metadata retains exact artwork inventory")
	label.free()
	for toned: bool in [false, true]:
		var event_label: RichTextLabel = EventText.label("Gain @kw(block). @term(health|Health).", 300, UiTypography.SIZE_BODY_LARGE, UiPalette.TEXT, true, toned)
		expect.call(not event_label.get_parsed_text().contains("@") and event_label.get_parsed_text().contains("Block."), "Event prose and toned outcomes expand explicit keyword tokens")
		expect.call(not event_label.hint_underlined and event_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Event concept style preserves existing input routing without underline")
		event_label.free()

static func _test_token_syntax(expect: Callable) -> void:
	var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/inline_token_cases.json"))
	for category: String in cases:
		for markup: String in cases[category]:
			var malformed: Array[String] = InlineIconText.TokenSyntax.malformed_tokens(markup)
			var unknown: Array[String] = InlineIconText.invalid_icon_keys(markup)
			expect.call((malformed.is_empty() and unknown.is_empty()) == (category == "valid"), "Shared renderer syntax rejects invalid markup: " + markup)
			if category == "unknown":
				var label := RichTextLabel.new()
				InlineIconText.apply_to(label, markup)
				expect.call(label.get_parsed_text() == markup and InlineIconText.concept_keys(markup).size() == 1, "Unknown punctuation/whitespace keys stay visible and fail validation: " + markup)
				label.free()
