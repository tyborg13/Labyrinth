extends "res://tests/rr46/depth_probe.gd"

## The same production/ID/isolated-actor probe on one fixed regression route.
## Staging only the historical board painter permits a matched base comparison.
const REGRESSION_ROUTE: String = "move_2_1_-1_1"

func _job(item: Dictionary, type: String) -> void:
	report={"schema":4,"native":true,"scope":"rr47_back_route","board":item["label"],"actor":type,"inventory_sha256":FileAccess.get_sha256(Cases.INVENTORY_PATH),"requirements":inventory["boards"][item["label"]]["requirements"][type],"selected_routes":[],"captures":[],"errors":[],"coverage":{},"primitives":[]}
	archive=Archive.new(output,report)
	if jobs_started==0: archive.started=run_started
	jobs_started+=1
	for route: Dictionary in Cases.routes(item["battle"]):
		if route["id"]!=REGRESSION_ROUTE: continue
		var battle: Dictionary = _battle(item,type,route["from"])
		await _cache_primitives(battle,_base(item))
		await _sample(item,type,route,0,true)
		if report["calibration"]["passed"]: await _capture_case(item,type,route)
		else: report["errors"].append("Actor-alone calibration failed")
		archive.write_report()
		print("RR47 NATIVE BACK ROUTE: %s/%s %s (%d samples)"%[item["label"],type,"PASS" if report["errors"].is_empty() else "FAIL",report["captures"].size()])
		return
	report["errors"].append("Missing legal regression route")
	archive.write_report()
