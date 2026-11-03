extends RefCounted

# The staged director file remains protected. The brs-01 brief authorizes only
# these four title fields in production; retain the original byte-level guard
# for everything else, including formatting and all gameplay data.
static func matches(staged: String, live: String) -> bool:
	var expected: String = staged.replace('"objective_title": "Ember Hoarder",', '"objective_title": "Defeat the Ember Hoarder before it escapes!",\n   "objective_hud_title": "Defeat the Hoarder",')
	expected = expected.replace('"last_light": {\n', '"last_light": {\n   "objective_title": "Survive until dawn!",\n   "objective_hud_title": "Survive until dawn",\n')
	return live == expected
