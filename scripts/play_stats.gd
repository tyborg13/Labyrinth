extends RefCounted
## Converts accepted local analytics records and lifecycle signals into Steam-only integers.
## The packed game includes this allowlist. The task proof checks it against the owner manifest.

const PREFIX := "play_v1_"
const FLAGS := [
	"p_launched", "p_run_started", "p_fight_won", "p_fight3", "p_fight5", "p_guardian",
	"p_boss", "p_boss_won", "p_run2", "p_run_after_win", "p_day2", "p_day7", "p_wishlist",
	"p_discord", "p_gamepad", "p_os_windows", "p_os_macos", "p_os_linux", "p_os_steamdeck",
]
const COUNTERS := [
	"sessions", "play_minutes", "run_minutes", "runs_started", "runs_resumed", "runs_won",
	"runs_died", "runs_withdrew", "runs_abandoned", "runs_reached_boss", "fights_won",
	"died_combat", "died_special", "died_guardian", "died_boss", "died_other",
	"tutorial_started", "tutorial_left_early", "unclean_exits", "load_errors", "save_errors",
	"wishlist_end", "wishlist_menu", "discord_end", "discord_menu", "rise_again",
]
const RUN_SCREENS := ["map", "fight", "reward", "event", "shop"]
const QUIT_SCREENS := ["menu", "map", "fight", "reward", "event", "shop", "run_end", "other"]
const QUIT_DEPTHS := ["f0_1", "f2_3", "f4_5", "f6p"]
const SESSION_BUCKETS := ["lt5", "5_15", "15_30", "30_60", "60p"]
const MINUTE_USEC := 60000000
const DAY_SECONDS := 86400
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

var batches: Array[Dictionary]
var store_requested := false
var menu_reached := false
var started_usec: int
var started_unix: int
var focused_since_usec := -1
var focused_usec := 0
var focus_minutes := 0
var marker_minute := -1
var gamepad_seen := false
var run_clock_id := ""
var run_clock_minute := 0
var boss_run_id := ""
var tutorial_run_id := ""
var closing := false

static func kinds() -> Dictionary:
	var result := {PREFIX + "first_day": "player_value"}
	for suffix: String in FLAGS:
		result[PREFIX + suffix] = "player_flag"
	for suffix: String in COUNTERS:
		result[PREFIX + suffix] = "counter"
	for fight: int in range(1, 8):
		result[PREFIX + "fights_started_%d" % fight] = "counter"
		result[PREFIX + "died_fight_%d" % fight] = "counter"
	for screen: String in QUIT_SCREENS:
		result[PREFIX + "quit_" + screen] = "counter"
	for depth: String in QUIT_DEPTHS:
		result[PREFIX + "quit_midrun_" + depth] = "counter"
	for bucket: String in SESSION_BUCKETS:
		result[PREFIX + "sess_" + bucket] = "counter"
	return result

static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("SteamService") if tree != null else null

static func notify(event: String, detail: Variant = null) -> void:
	var steam := service()
	if steam != null and steam.has_method("record_play_signal"): steam.record_play_signal(event, detail)

static func observe_records(records: Array) -> void:
	var steam := service()
	if steam != null and steam.has_method("observe_play_records"): steam.observe_play_records(records)

func emit_stats(deltas: Dictionary) -> void:
	if deltas.is_empty(): return
	var names: Dictionary = {}
	for suffix: String in deltas:
		names[PREFIX + suffix] = deltas[suffix]
	# Adjacent unconditional changes share one readiness batch. Launch and new
	# run checks stay in order with the counter values they depend on.
	if not batches.is_empty() and batches.back().has("deltas"):
		var pending: Dictionary = batches.back()["deltas"]
		for key: String in names:
			pending[key] = int(pending.get(key, 0)) + int(names[key])
	else:
		batches.append({"deltas": names})

func launch(day: int, platform: String, deck: bool) -> void:
	batches.append({"launch_day": day})
	var os_stat := platform.to_lower()
	if deck:
		os_stat = "steamdeck"
	if os_stat in ["windows", "macos", "linux", "steamdeck"]:
		emit_stats({"p_os_" + os_stat: 1})

func main_menu_loaded() -> void:
	if menu_reached: return
	menu_reached = true
	emit_stats({"p_launched": 1, "sessions": 1})

func set_focused(focused: bool, now_usec: int) -> void:
	if focused and focused_since_usec < 0:
		focused_since_usec = now_usec
	elif not focused and focused_since_usec >= 0:
		focused_usec += maxi(0, now_usec - focused_since_usec)
		focused_since_usec = -1

func sample_focus(now_usec: int) -> void:
	var elapsed := focused_usec
	if focused_since_usec >= 0:
		elapsed += maxi(0, now_usec - focused_since_usec)
	var minute := int(elapsed / MINUTE_USEC)
	if minute > focus_minutes:
		emit_stats({"play_minutes": minute - focus_minutes})
		focus_minutes = minute

func sample_run_clock(run_id: String, seconds: float, saved_seconds: float) -> void:
	if run_id.is_empty(): return
	if run_id != run_clock_id:
		run_clock_id = run_id
		run_clock_minute = floori(saved_seconds / 60.0)
	var minute := floori(seconds / 60.0)
	if minute > run_clock_minute:
		emit_stats({"run_minutes": minute - run_clock_minute})
		run_clock_minute = minute

func observe(record: Dictionary) -> void:
	var run_id: String = record.get("run_id", "")
	if bool(record.get("debug_boss_run", false)):
		return
	var payload: Dictionary = record.get("payload", {})
	var outcome: String = payload.get("outcome", "")
	match str(record.get("event_type", "")):
		"run_started":
			batches.append({"new_run": true})
		"run_resumed":
			emit_stats({"runs_resumed": 1})
		"combat_started":
			_combat_started(run_id, int(payload.get("fight_number", 0)), str(payload.get("room_type", record.get("room_type", ""))))
		"combat_ended":
			if outcome == "victory":
				emit_stats({"fights_won": 1, "p_fight_won": 1})
		"run_ended":
			_run_ended(run_id, outcome, payload)
		"guided_tutorial_started":
			tutorial_run_id = run_id
			emit_stats({"tutorial_started": 1})
		"guided_tutorial_dismissed":
			if str(payload.get("phase_id", "")) != Tutorial.PHASE_COMPLETE and int(payload.get("completed_step_count", 0)) < Tutorial.MILESTONE_ORDER.size():
				emit_stats({"tutorial_left_early": 1})
			tutorial_run_id = ""
		"guided_tutorial_step_completed":
			if int(payload.get("completed_step_count", 0)) >= Tutorial.MILESTONE_ORDER.size():
				tutorial_run_id = ""
			else:
				tutorial_run_id = run_id
		"guided_tutorial_completed":
			tutorial_run_id = ""

func _combat_started(run_id: String, fight: int, room_type: String) -> void:
	var deltas: Dictionary = {}
	_fight_bucket(deltas, "fights_started_", fight)
	if fight >= 3: deltas["p_fight3"] = 1
	if fight >= 5: deltas["p_fight5"] = 1
	if room_type == "guardian": deltas["p_guardian"] = 1
	if room_type == "boss":
		deltas["p_boss"] = 1
		if boss_run_id != run_id:
			deltas["runs_reached_boss"] = 1
			boss_run_id = run_id
	emit_stats(deltas)

func _run_ended(run_id: String, outcome: String, payload: Dictionary) -> void:
	match outcome:
		"victory":
			emit_stats({"runs_won": 1, "p_boss_won": 1})
		"defeat":
			var deltas := {"runs_died": 1}
			_fight_bucket(deltas, "died_fight_", int(payload.get("defeat_fight_number", 0)))
			var room_type: String = payload.get("defeat_room_type", "")
			if room_type in ["combat", "special", "guardian", "boss"]:
				deltas["died_" + room_type] = 1
			elif room_type.is_empty():
				deltas["died_other"] = 1
			emit_stats(deltas)
		"embrace":
			emit_stats({"runs_withdrew": 1})
		"abandoned":
			emit_stats({"runs_abandoned": 1})
	if tutorial_run_id == run_id and not run_id.is_empty():
		emit_stats({"tutorial_left_early": 1})
		tutorial_run_id = ""
	store_requested = true

static func _fight_bucket(deltas: Dictionary, prefix: String, fight: int) -> void:
	if fight > 0: deltas[prefix + str(mini(fight, 7))] = 1

func button(action: String, source: String) -> void:
	if action in ["discord", "feedback"]: action = "discord"
	if action in ["wishlist", "discord"] and source in ["end", "menu"]:
		emit_stats({"p_" + action: 1, action + "_" + source: 1})

static func session_bucket(minute: int) -> String:
	if minute < 5: return "lt5"
	if minute < 15: return "5_15"
	if minute < 30: return "15_30"
	if minute < 60: return "30_60"
	return "60p"

func recover_session(minute: int) -> void:
	emit_stats({"unclean_exits": 1, "sess_" + session_bucket(minute): 1})

func finish_session(screen: String, fights: int, minute: int) -> void:
	var deltas := {"quit_" + screen: 1, "sess_" + session_bucket(minute): 1}
	if fights >= 0 and screen in RUN_SCREENS:
		deltas["quit_midrun_" + QUIT_DEPTHS[mini(fights / 2, 3)]] = 1
	emit_stats(deltas)

static func run_screen(mode: String, map_open: bool, dialogue: bool, merchant: bool, recap: bool, guardian_reward: bool) -> String:
	if recap: return "run_end"
	if map_open: return "map"
	if dialogue: return "event"
	match mode:
		"pre_battle", "combat":
			return "fight"
		"reward":
			return "reward"
		"treasure":
			return "reward" if guardian_reward else "event"
		"event", "campfire":
			return "event"
		"room":
			return "shop" if merchant else "map"
		"escape":
			return "map"
	return "other"
