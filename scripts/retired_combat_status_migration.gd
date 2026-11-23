extends RefCounted
## Scrub live snapshots, including held intents and saved combat continuations.
## Historical events and prose remain readable in their original form.
const Data = preload("res://scripts/game_data.gd")
const THORN_CROWN_PACT: String = "thorn_crown_pact"
const ENEMY_ATTACKS: Array = ["melee", "ranged", "aoe", "push", "pull"]
const HISTORICAL_KEYS: Array = [
	"analytics", "analytics_context", "analytics_events", "progression_analytics_outbox",
	"completed_run_results", "last_run_result", "log", "surface_events",
]
const RETIRED_FIELDS: Array = ["bleed", "sunder", "player_bleed_loss_totals", "_player_bleed_paid"]

static func migrate(run: Dictionary) -> void:
	# Existing early saves can use legacy 10x combat units until RunEngine
	# normalizes them. Estimate the units via the same run-state reader.
	var damage_step: int = Data.fixed_point_amount(1)
	var run_rules = preload("res://scripts/run_engine.gd")
	if run_rules.combat_units_migration_required(run) and run_rules._legacy_combat_unit_classification(run) == "legacy_fixed_10x":
		damage_step = Data.LEGACY_FIXED_POINT_SCALE
	_scrub(run, damage_step)

static func _scrub(value: Variant, damage_step: int, enemy_intent: bool = false) -> void:
	if value is Array:
		for child: Variant in value:
			_scrub(child, damage_step, enemy_intent)
	elif value is Dictionary:
		if value.get("active_rites") is Array:
			_refresh_thorn_crown_pact(value["active_rites"])
		var type: String = str(value.get("type", ""))
		if enemy_intent and type in ENEMY_ATTACKS and (int(value.get("bleed", 0)) > 0 or int(value.get("sunder", 0)) > 0):
			value["damage"] = int(value.get("damage", 0)) + damage_step
		for key: String in RETIRED_FIELDS:
			value.erase(key)
		for field: String in ["statuses", "status_immunities"]:
			if value.get(field) is Array:
				value[field].erase("bleed")
				value[field].erase("sunder")
		for key: Variant in value:
			if str(key) in HISTORICAL_KEYS:
				continue
			_scrub(value[key], damage_step, enemy_intent or str(key) in ["intent", "intents"])

static func _refresh_thorn_crown_pact(rites: Array) -> void:
	for entry: Variant in rites:
		if not entry is Dictionary or entry.get("card_id") != THORN_CROWN_PACT:
			continue
		var card: Dictionary = Data.card_def(THORN_CROWN_PACT)
		entry["description"] = card["description"]
		entry["effects"] = (card["rite"]["effects"] as Array).duplicate(true)
