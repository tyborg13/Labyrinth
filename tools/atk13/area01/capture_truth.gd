extends RefCounted
## Compare the live Pass panel to a committed resolution of the same proof state.

const Observer = preload("res://tools/atk13/area01/observed_engine.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const PROOF_FROZEN_SPAN_LIMIT: int = 100

class ProofEngine extends Observer:
	var fatigue_loss: int = 0

	func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
		var before: int = int(state.get("run_stats", {}).get(RUN_STAT_DAMAGE_RECEIVED, 0))
		var after: Dictionary = super._draw_cards_in_place(state, count)
		fatigue_loss += maxi(0, int(after.get("run_stats", {}).get(RUN_STAT_DAMAGE_RECEIVED, 0)) - before)
		return after

static func check(source: Dictionary, actor: String, summary: Dictionary, chip: Button) -> Dictionary:
	var engine := ProofEngine.new()
	engine.observing = true
	var state: Dictionary = source.duplicate(true)
	for activation: int in range(PROOF_FROZEN_SPAN_LIMIT):
		state = Commit.advance_to_player(engine, Commit.finish_player_activation(engine, state))["state"]
		if not engine.combat_outcome(state).is_empty() or not bool(state.get("player_turn_restrictions", {}).get("frozen", false)): break
	var intents: Array[String]
	var boss_loss: Dictionary = {}
	var strike: Array = []
	var inert: Array = []
	var last_clock: int = -1
	for receipt: Dictionary in engine.receipts:
		if receipt["owner"] != actor: continue
		var intent: String = str(receipt["intent"])
		if int(receipt["clock"]) != last_clock:
			last_clock = int(receipt["clock"])
			intents.append(intent)
		boss_loss[intent] = int(boss_loss.get(intent, 0)) + int(receipt["hp"])
		if intent == "bedrock_breath" and receipt.has("area_struck"):
			strike = receipt["area_struck"]
			inert = receipt["area_inert"]
	var shown: int = int(ForecastPanel.row_losses(summary)["health"])
	var health_row: bool = false
	var expected_text: String = "−%d → 0" % shown if bool(summary.get("defeat", false)) else "−%d" % shown
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	if panel != null and panel.is_visible_in_tree() and bool(chip.get_meta("pass_forecast_active", false)):
		for row: Dictionary in chip.get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []):
				if part.get("icon") == "health" and str(part.get("text")) == expected_text: health_row = true
	var actual: int = maxi(0, int(source["player"]["hp"]) - int(state["player"]["hp"]) - engine.fatigue_loss)
	return {"intents": intents, "shown_loss": shown, "actual_loss": actual, "health_row": health_row,
		"boss_loss": boss_loss, "strike": strike, "inert": inert}
