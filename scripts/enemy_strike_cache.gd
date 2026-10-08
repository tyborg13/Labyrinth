extends RefCounted
## Authored poses are independent of the effect's palette, seed and camera.
## Resolve once in rig/source coordinates; reproject only when framing changes.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Geometry = preload("res://scripts/enemy_strike_geometry.gd")
var _owners: Dictionary = {}
var sample_build_count: int = 0
var resolution_build_count: int = 0

func entry(renderer: Node, source: Dictionary, effect: Dictionary, delta: Vector2i,
		settings: Dictionary, contact: float) -> Dictionary:
	var id: int = renderer.get_instance_id()
	if not _owners.has(id):
		for old_id: int in _owners.keys():
			if not is_instance_valid((_owners[old_id]["owner"] as WeakRef).get_ref()): _owners.erase(old_id)
		_owners[id] = {"owner":weakref(renderer),"entries":{}}
	var direction: Dictionary = renderer.direction_for_delta(delta)
	var type: String = source["type"]
	var variant: String = Points.MODELS[type].attack_clip(effect) if type == "crawler" else ""
	# Iskaldra's talon phase/pose uses action and facing, not target distance.
	# Its direction only selects facing/mirror; no target offset belongs here.
	var key: String = "%s|%s|%s|%s|%s|%s|%.9f" % [type,effect.get("kind",""),effect.get("intent_id",""),variant,direction["facing"],direction["mirrored"],contact]
	var entries: Dictionary = _owners[id]["entries"]
	if entries.has(key): return entries[key]
	var samples: Array[Dictionary] = Points.samples(renderer,source,effect,delta,settings,contact)
	sample_build_count += 1
	if samples.is_empty(): return {} # A not-yet-ready rig must remain retryable.
	var hold_span: float = 0.0
	if bool(settings.get("contact_hold_arc",false)):
		hold_span = Geometry.path_span(Geometry.window_samples(samples,Vector2(contact,minf(contact+Trail.TAIL,settings["window"].y))))
	var result: Dictionary = {"raw":samples,"span":Geometry.path_span(samples),"hold_span":hold_span}
	entries[key] = result
	return result

func resolve_entry(entry_value: Dictionary, settings: Dictionary, contact: float,
		fx_scale: float, target: Vector2, tile_width: float) -> Dictionary:
	# Relative target geometry belongs to resolution, not authored sampling.
	# This retains the .6-tile/axis decisions when a new target shares a facing.
	var context: Array = [fx_scale,target,tile_width]
	if entry_value.get("context",[]) == context: return entry_value["resolved"]
	var samples: Array[Dictionary]
	for sample: Dictionary in entry_value["raw"]:
		var tip: Vector2 = sample["tip"]
		samples.append({"progress":sample["progress"],"tip":tip,"inner":tip+((sample["inner"] as Vector2)-tip)*fx_scale})
	var result: Dictionary
	if bool(settings.get("contact_hold_arc",false)) and entry_value["hold_span"] < Geometry.SHORT_PATH*fx_scale:
		result = {"kind":"arc","fallback":true,"reason":"held_contact","held_span":entry_value["hold_span"],"strike_point":Trail.sample_at(samples,contact)["tip"],"target_arc":true}
	else:
		result = Geometry.resolve(samples,settings["kind"],Vector2(127.5,127.5),target,fx_scale,contact,settings["window"],entry_value["span"],tile_width)
		# Typed once; the cached array remains immutable during geometry drawing.
		var resolved_samples: Array[Dictionary] = Geometry.samples_for(result)
		result["samples"] = resolved_samples
	entry_value["context"] = context
	entry_value["resolved"] = result
	entry_value.erase("projection")
	resolution_build_count += 1
	return result

func project(entry_value: Dictionary, source_result: Dictionary, body: Rect2,
		from: Vector2, to: Vector2, scale: float) -> Dictionary:
	var context: Array = [body,from,to,scale]
	if entry_value.get("projection",[]) == context: return entry_value["board_result"]
	var result: Dictionary = source_result.duplicate(false)
	var samples: Array[Dictionary]
	if bool(result.get("target_arc",false)):
		samples = Geometry.target_arc_samples(from,to,scale)
	else:
		for sample: Dictionary in source_result["samples"]:
			samples.append({"progress":sample["progress"],"tip":body.position+(sample["tip"] as Vector2)*body.size/255.0,"inner":body.position+(sample["inner"] as Vector2)*body.size/255.0})
	for field: String in ["anchor","strike_point"]:
		if result.has(field): result[field] = body.position+(result[field] as Vector2)*body.size/255.0
	for field: String in ["span","held_span"]:
		if result.has(field): result[field] *= body.size.x/255.0
	result["samples"] = samples
	entry_value["projection"] = context
	entry_value["board_result"] = result
	return result
