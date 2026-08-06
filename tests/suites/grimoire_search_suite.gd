extends RefCounted

const GrimoireSearch = preload("res://scripts/grimoire_search.gd")

static func run(expect: Callable) -> void:
	var sections: Array = [
		{"id": "combat", "title": "Combat"},
		{"id": "keywords", "title": "Keywords"}
	]
	var entries: Array = [
		{
			"id": "combat:turn_clock",
			"section": "combat",
			"title": "Turn Clock",
			"aliases": ["initiative", "turn order"],
			"body": ["The clock previews upcoming actors."]
		},
		{
			"id": "combat:fatigue",
			"section": "combat",
			"title": "Fatigue",
			"body": ["When the draw pile empties, the discard pile reshuffles."]
		},
		{
			"id": "keyword:truesight",
			"section": "keywords",
			"title": "Truesight",
			"body": ["Direct attacks may target concealed enemies."]
		},
		{
			"id": "keyword:turning",
			"section": "keywords",
			"title": "Turning",
			"body": ["A turn clock curiosity."]
		},
		{
			"id": "keyword:crystal_guard",
			"section": "keywords",
			"title": "Crystal Armor",
			"body": ["A title-word ranking check without duplicated terminology."]
		},
		{
			"id": "combat:health_defense",
			"section": "combat",
			"title": "Health and Defenses",
			"aliases": ["armor"],
			"body": ["Armor is also mentioned in these rules, so field priority must not depend on additive score luck."]
		},
		{
			"id": "keyword:vital_toll",
			"section": "keywords",
			"title": "Health Cost",
			"body": ["Health paid to commit a card."]
		},
		{
			"id": "combat:arena",
			"section": "combat",
			"title": "Combat Board",
			"body": ["The tactical play space."]
		}
	]

	var title_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "turn clock")
	expect.call(title_results.size() >= 1, "Grimoire search should find a multi-word title")
	expect.call(str((title_results[0].get("entry", {}) as Dictionary).get("id", "")) == "combat:turn_clock", "Exact title matches should outrank body mentions")

	var reordered_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "clock turn")
	expect.call(not reordered_results.is_empty() and str((reordered_results[0].get("entry", {}) as Dictionary).get("id", "")) == "combat:turn_clock", "Grimoire search terms should work in any order")

	var alias_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "initiative")
	expect.call(not alias_results.is_empty() and str((alias_results[0].get("entry", {}) as Dictionary).get("id", "")) == "combat:turn_clock", "Grimoire search should honor familiar aliases")
	expect.call(str(alias_results[0].get("match_kind", "")) == "alias", "Alias matches should explain their result source")

	var title_word_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "armor")
	expect.call(not title_word_results.is_empty() and str((title_word_results[0].get("entry", {}) as Dictionary).get("id", "")) == "keyword:crystal_guard", "An exact title word should outrank the same word used as an alias even when the alias also appears in rules text")

	var partial_second_word_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "combat b")
	expect.call(not partial_second_word_results.is_empty() and str((partial_second_word_results[0].get("entry", {}) as Dictionary).get("id", "")) == "combat:arena", "A one-character trailing token should keep a multi-word title visible while the player types")
	var typo_partial_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "heath c")
	expect.call(not typo_partial_results.is_empty() and str((typo_partial_results[0].get("entry", {}) as Dictionary).get("id", "")) == "keyword:vital_toll", "A one-character trailing token should compose with conservative typo recovery")
	var lone_character_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "c")
	expect.call(lone_character_results.is_empty(), "A lone one-character query should not enable broad prefix matching")

	var rules_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "reshuffle")
	expect.call(not rules_results.is_empty() and str((rules_results[0].get("entry", {}) as Dictionary).get("id", "")) == "combat:fatigue", "Grimoire search should find mechanics inside rules text")
	expect.call(str(rules_results[0].get("match_kind", "")) == "rules", "Rules-text matches should explain their result source")

	var typo_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "truesigth")
	expect.call(not typo_results.is_empty() and str((typo_results[0].get("entry", {}) as Dictionary).get("id", "")) == "keyword:truesight", "Grimoire search should recover a small transposition typo")
	expect.call(str(typo_results[0].get("match_kind", "")) == "close", "Typo recovery should be labeled as a close match")

	var all_terms_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "fatigue concealed")
	expect.call(all_terms_results.is_empty(), "Grimoire search should require evidence for every query term instead of returning noisy partial matches")

	var short_noise_results: Array[Dictionary] = GrimoireSearch.search(entries, sections, "zz")
	expect.call(short_noise_results.is_empty(), "Grimoire search should not fuzzy-match very short noise")
