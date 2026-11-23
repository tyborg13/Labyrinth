extends "res://tools/fx36/native_capture.gd"

const Bolt = preload("res://scripts/chain_bolt_fx.gd")
const Shot = preload("res://scripts/shot_fx.gd")
const EXPECTED_BOLTS: Dictionary = {
	"chain_bolt": 2, "storm_relay": 2, "capacitor": 3,
	"storm_salvo": 2, "spark_conduction": 0, "chain_conduction": 2,
}
const SHAPE_WITNESS := Vector2(120.0, 0.0)
const SHAPE_SEED: int = 36

var _checks: int
var _failures: int
var _palette: Array[String]

func _take() -> void:
	_plan = true
	_install_plan_clock()
	var output: String = _arg("--out")
	if not output.is_absolute_path():
		_fail("Use an absolute --out directory.")
		return
	var selected: String = _arg("--case")
	var record: bool = OS.get_cmdline_user_args().has("--record")
	_check_shape()
	for id: String in Fixture.NATIVE + Fixture.EXTRA:
		if not selected.is_empty() and id != selected: continue
		for reduced: bool in [false, true]:
			_record = record and not reduced and id in Fixture.NATIVE
			var name: String = id + ("_reduced" if reduced else "")
			var report: Dictionary = await take_case(id, output.path_join(name), reduced)
			if report.is_empty(): return
			_check_take(name, report, reduced)
	print("FX-36 OUTPUT " + output)
	print("FX-36 VERIFY %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check_take(name: String, report: Dictionary, reduced: bool) -> void:
	var routes: Array = report["routes"]
	var bolts: Array = report["bolts"]
	_expect(bolts.size() == EXPECTED_BOLTS[_case], name + " has the exact fixture bolt count")
	if _case == "spark_conduction":
		_expect(routes.any(func(route: Dictionary) -> bool: return route["kind"] == "conduction"), name + " resolves conduction")
	if _case in ["storm_relay", "chain_conduction"]:
		_expect(routes.any(func(route: Dictionary) -> bool: return route["kind"] == "relay"), name + " resolves floor relay contacts")
	if _case == "capacitor": _expect(routes.size() == 4, name + " resolves opening plus three jumps")
	if not reduced: _expect(report["opening_spark"], name + " retains the opening Spark")
	var rows: Dictionary = Fx.metadata()["rows"]
	var hit_row: int = int(rows["lightning_hit_front"])
	for route: Dictionary in routes:
		var from: String = Fixture.Witness.coord(route["from"])
		var to: String = Fixture.Witness.coord(route["to"])
		var matching: Array = bolts.filter(func(bolt: Dictionary) -> bool: return bolt["from"] == from and bolt["to"] == to)
		_expect(matching.size() == int(route["bolt"]), "%s %s→%s matches the resolver's actor-only hop" % [name, from, to])
		if matching.size() != 1: continue
		var bolt: Dictionary = matching[0]
		var numbers: Dictionary = report["damage"].get(to, {})
		var frames: Dictionary = report["bursts"].get(to, {})
		var contacts: Dictionary = frames.get(hit_row, {})
		var source: Dictionary = report["bursts"].get(from, {})
		var origin: Dictionary = source.get(hit_row, source.get(int(rows["lightning_floor_front"]), {}))
		var number_frame: int = int(numbers.get("frame", -1))
		var burst_frame: int = int(contacts.get("frame", -1))
		_expect(bolt["birth_offset"] == 0 and bolt["start"] == number_frame and bolt["start"] == burst_frame,
			name + " lands with the damage number and burst")
		_expect(bolt["to_point"] == contacts.get("point") and bolt["from_point"] == origin.get("point"),
			name + " uses both burst anchors")
		_expect(bolt["tips"] == ["ffffffff", "ffffffff"], name + " paints both snapped endpoints")
		_expect(bolt["nearest"] and bolt["cell"] == bolt["spark_cell"] and int(bolt["cell"]) > 0, name + " uses Spark's nearest cell grid")
		var depth: Array = bolt["depth"]
		var front_slot: int = maxi(bolt["front_from"], bolt["front_to"])
		_expect(depth[2] < depth[1] and depth[1] == front_slot, name + " uses the front effect layer above both endpoints")
		if not source.has(hit_row):
			_expect(depth[1] >= bolt["front_from"], name + " sorts over the relay floor row")
		_expect(bolt["floor_depth"] < depth[1] and depth[1] < mini(bolt["effects_depth"], bolt["hud_depth"]),
			name + " sorts above floor paint and below floating numbers and the HUD")
		_check_samples(name, bolt, reduced)
		print("FX-36 CONTACT %s %s→%s bolt=%d damage=%d (%s) burst=%d endpoints=%s→%s burst_points=%s→%s cell=%d" % [
			name, from, to, bolt["start"], number_frame, numbers.get("text", ""), burst_frame,
			bolt["from_point"], bolt["to_point"], origin.get("point"), contacts.get("point"), bolt["cell"]])
	if _record:
		_expect(report["reel_frames"] == REEL_SAMPLES and int(report["done"]) < REEL_SAMPLES,
			name + " fits the game-speed reel segment")

func _check_samples(name: String, bolt: Dictionary, reduced: bool) -> void:
	var samples: Array = bolt["samples"]
	var data: Dictionary = Bolt.metadata()
	var phases: Array = [0] if reduced else range(int(data["full_frames"]) + int(data["fade_frames"]))
	_expect(samples.map(func(sample: Dictionary) -> int: return sample["phase"]) == phases, name + " presents each authored phase")
	var duration: float = float(data["reduced_motion_seconds"]) if reduced else float(phases.size()) / float(data["fps"])
	_expect(float(bolt["last_age"]) < duration and float(bolt.get("end_age", 0.0)) + Bolt.CLOCK_EPSILON >= duration,
		"%s expires on the first game-time sample at %.3f s" % [name, duration])
	for sample: Dictionary in samples:
		var age: float = sample["age"]
		var fps: float = float(data["fps"])
		_expect(age + Bolt.CLOCK_EPSILON >= float(sample["phase"]) / fps, name + " does not advance an authored phase early")
		_expect(int(sample["inks"]) > 0, name + " has visible ink during every phase")
		for color: String in sample["palette"]:
			_expect(color in _palette, "%s uses a fully opaque Spark ink %s" % [name, color])
	if not reduced and samples.size() == phases.size():
		_expect(samples[2]["hash"] != samples[1]["hash"], name + " re-jags on frame 3")
		_expect(samples[2]["inks"] > samples[3]["inks"] and samples[3]["inks"] > samples[4]["inks"], name + " removes ink over all three fade phases")

func _check_shape() -> void:
	var data: Dictionary = Bolt.metadata()
	for color: String in data["palette"].values(): _palette.append(Color(color).to_html())
	var spark_palette: Array = Shot.metadata()["palette"]
	_expect(_palette == ["5a3a9aff", "d0c0ffff", "ffffffff"] and _palette.all(func(color: String) -> bool: return color in spark_palette),
		"the exact Spark halo, body and core are in the baked shot palette")
	print("FX-36 PALETTE %s, Spark cell=%d px at 1920×1080" % [_palette, Shot.grid_px(CanvasSize.y)])
	var short: Array[PackedVector2Array] = Bolt.paths(Vector2.ZERO, SHAPE_WITNESS, 2, SHAPE_SEED)
	var long: Array[PackedVector2Array] = Bolt.paths(Vector2.ZERO, SHAPE_WITNESS, 3, SHAPE_SEED)
	_expect(short.size() == 1 and long.size() == 2 and short[0] == long[0], "one fork only beyond two tiles")
	var main: PackedVector2Array = long[0]
	_expect(main[0] == Vector2.ZERO and main[1] == Vector2(8, 0) and main[-2] == SHAPE_WITNESS - Vector2(8, 0) and main[-1] == SHAPE_WITNESS,
		"each end holds eight straight authored pixels")
	for index: int in range(2, main.size() - 2):
		_expect(is_equal_approx(main[index].x, (index - 1) * 12.0) and absf(main[index].y) <= 6.0, "kink uses the 12 px interval and ±6 px offset")
	var fork: PackedVector2Array = long[1]
	_expect(is_equal_approx(fork[0].distance_to(fork[1]), SHAPE_WITNESS.x * 0.25), "fork is 25% of the hop")
	_expect(fork[0].x >= SHAPE_WITNESS.x * 0.35 and fork[0].x <= SHAPE_WITNESS.x * 0.65, "fork starts in the 35%–65% interval")
	for index: int in range(1, main.size()):
		if main[index].x < fork[0].x: continue
		var angle: float = absf(rad_to_deg((main[index] - main[index - 1]).angle_to(fork[1] - fork[0])))
		_expect(angle >= 25.0 and angle <= 40.0, "fork departs the local segment at 25–40°")
		break
	_expect(main != Bolt.paths(Vector2.ZERO, SHAPE_WITNESS, 3, SHAPE_SEED + 1)[0], "the second seed changes the jag")

func _expect(ok: bool, label: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	printerr("FX-36 CHECK FAILED " + label)
