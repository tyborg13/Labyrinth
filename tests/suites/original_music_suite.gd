extends RefCounted

const Music = preload("res://scripts/music_library.gd")
const Assets = preload("res://scripts/asset_loader.gd")

static func run(expect: Callable) -> void:
	var approval: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/ORIGINAL_SOUNDTRACKS_APPROVAL.json"))
	expect.call(str(approval.get("status", "")) == "approved_for_game_integration", "Original tracks need explicit owner integration approval")
	for track: Dictionary in approval.get("tracks", []):
		var entry: Dictionary = Music.entry(str(track["id"]))
		var path: String = str(entry.get("path", ""))
		expect.call(path == "res://" + str(track["asset"]), "Route should use the approved asset")
		expect.call(FileAccess.get_sha256(path) == str(track["ogg_sha256"]), "Shipped music should exactly match the approved audition")
		var stream: AudioStream = Assets.load_audio_stream(path, bool(entry.get("loop", false)))
		expect.call(stream is AudioStreamOggVorbis, "Approved track should load as Ogg through production loader")
		if stream is AudioStreamOggVorbis:
			expect.call((stream as AudioStreamOggVorbis).loop, "Approved Ogg should loop natively")
			expect.call(absf(stream.get_length() - float(track["duration_seconds"])) < 0.01, "Promoted Ogg should keep audition duration")
	for element: String in ["fire", "ice", "lightning", "air", "earth", "none"]:
		_check(expect, "combat", {"type": "combat", "element": element}, {}, false, Music.ASHEN_PURSUIT_TRACK_ID)
	for room_type: String in ["boss", "guardian"]:
		_check(expect, "combat", {"type": room_type, "boss_id": "zekarion"}, {}, false, Music.THORNS_TRACK_ID)
		_check(expect, "pre_battle", {"type": room_type}, {}, false, Music.TURNING_KEY_TRACK_ID)
		_check(expect, "room", {"type": room_type, "cleared": true}, {}, false, Music.LANTERNS_TRACK_ID)
	_check(expect, "combat", {"type": "combat"}, {"enemies": [{"type": "tharokh"}]}, false, Music.THORNS_TRACK_ID)
	_check(expect, "combat", {}, {"room_type": "guardian"}, false, Music.THORNS_TRACK_ID)
	_check(expect, "pre_battle", {"type": "combat"}, {}, false, Music.TURNING_KEY_TRACK_ID)
	_check(expect, "room", {"type": "combat", "cleared": false}, {}, false, Music.TURNING_KEY_TRACK_ID)
	for room_type: String in ["start", "campfire", "treasure", "empty", "combat", "boss", "guardian"]:
		_check(expect, "room", {"type": room_type, "cleared": true}, {}, false, Music.LANTERNS_TRACK_ID)
	for mode: String in ["reward", "treasure", "campfire", "escape", "victory"]:
		_check(expect, mode, {"type": "boss"}, {}, false, Music.LANTERNS_TRACK_ID)
	for room_type: String in Music.PLANNING_ROOMS:
		_check(expect, "room", {"type": room_type}, {}, false, Music.TURNING_KEY_TRACK_ID)
	_check(expect, "event", {}, {}, false, Music.TURNING_KEY_TRACK_ID)
	_check(expect, "combat", {"type": "boss"}, {}, true, Music.TURNING_KEY_TRACK_ID)
	_check(expect, "room", {"type": "start"}, {}, true, Music.TURNING_KEY_TRACK_ID)
	_check(expect, "defeat", {"type": "boss"}, {}, true, Music.CHOPIN_DEATH_TRACK_ID)
	_check(expect, "victory", {"type": "boss"}, {}, true, Music.LANTERNS_TRACK_ID)
	var menu: Dictionary = Music.entry(Music.OLD_CASTLE_MENU_TRACK_ID)
	expect.call(FileAccess.get_sha256(str(menu["path"])) == "57fabef2f4298b22ef7477e18b261702152483c9cb7aabe43acd99ece952fdc8", "Old Castle main-menu bytes must be preserved")
	expect.call(is_equal_approx(float(menu["volume_db"]), -6.5), "Old Castle volume must be preserved")
	var defeat: Dictionary = Music.entry(Music.CHOPIN_DEATH_TRACK_ID)
	expect.call(FileAccess.get_sha256(str(defeat["path"])) == "f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569", "Chopin defeat bytes must be preserved")
	expect.call(is_equal_approx(float(defeat["volume_db"]), -7.0), "Chopin volume must be preserved")

static func _check(expect: Callable, mode: String, room: Dictionary, combat: Dictionary, planning: bool, expected: String) -> void:
	var actual: String = str(Music.entry_for_context(mode, room, combat, planning).get("id", ""))
	expect.call(actual == expected, "Music route %s/%s planning=%s should use %s, got %s" % [mode, room.get("type", ""), planning, expected, actual])
