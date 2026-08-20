extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const ICONLESS_SKILLS: Array[String] = [
	"curators_patience",
	"deferred_choice",
	"discerning_eye",
	"layaway",
	"open_arsenal",
	"salvager",
]

const DEDICATED_ICON_TERM_PATTERNS: Array[Dictionary] = [
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
	{"label": "Bleed", "pattern": "(?i)\\bbleed(?:s|ing)?\\b"},
	{"label": "Expose", "pattern": "(?i)\\bexpose(?:s|d)?\\b"},
	{"label": "Poison", "pattern": "(?i)\\bpoison(?:s|ed|ing)?\\b"},
	{"label": "Corruption", "pattern": "(?i)\\bcorruption\\b"},
	{"label": "Radiance", "pattern": "(?i)\\bradiance\\b"},
	{"label": "Bramble", "pattern": "(?i)\\bbramble\\b"},
	{"label": "Snowdrift", "pattern": "(?i)\\bsnowdrift\\b"},
	{"label": "Electrified", "pattern": "(?i)\\belectrified\\b"},
	{"label": "Combust", "pattern": "(?i)\\bcombust\\b"},
	{"label": "Fatigue", "pattern": "(?i)\\bfatigue\\b"},
	{"label": "Defiance", "pattern": "(?i)\\bdefiance\\b"},
	{"label": "Trap", "pattern": "(?i)\\btraps?\\b"},
	{"label": "Exhaust", "pattern": "(?i)\\bexhaust(?:s|ed|ing)?\\b"},
	{"label": "Time", "pattern": "\\bTime\\b"},
]


static func run(expect: Callable) -> void:
	var relic_icon_count: int = 0
	for relic_id: String in GameData.relic_ids():
		var description: String = str(GameData.relic_def(relic_id).get("description", ""))
		relic_icon_count += InlineIconText.icon_keys(description).size()
		expect.call(InlineIconText.has_icons(description), "%s relic rules should use at least one established mechanic icon" % relic_id)
		_audit_description(expect, "relic %s" % relic_id, description)
	expect.call(relic_icon_count >= 175, "The full relic audit should retain broad inline-icon coverage")

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
	expect.call(skill_icon_count >= 48, "The full ability audit should retain broad inline-icon coverage")

	var example: String = "Create @icon(illuminate) 2 for @icon(time) 2."
	expect.call(InlineIconText.plain_text(example) == "Create Illuminate 2 for Time 2.", "Inline icon rules should retain an accessible plain-text expansion")
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
	if regex.compile("@icon\\([a-z0-9_]+\\)") != OK:
		return markup
	return regex.sub(markup, "", true)
