extends "res://tests/rr11/action_direction.gd"

## Full transforms stay in ignored logs; tracked proof holds only an inventory.
func write_report(output: String, report: Dictionary) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = "res://experiments/cutouts/hollow_mimic/rr20"
	if args.has("--case"): directory = args[args.find("--case") + 1]
	if ProjectSettings.globalize_path(output) != ProjectSettings.globalize_path(directory.path_join("proof/samples.json")):
		super.write_report(output, report)
		return
	var evidence: String = directory.path_join("proof/logs/samples.full.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence.get_base_dir()))
	super.write_report(evidence, report)
	var counts: Dictionary = {}
	for row: Dictionary in report["samples"]:
		var key: String = "%s/%s/%s" % [row["view"], row["clip"], row["kind"]]
		counts[key] = int(counts.get(key, 0)) + 1
	var summary: Dictionary = report.duplicate()
	summary.erase("samples")
	summary.erase("inputs")
	summary["sample_counts"] = counts
	summary["full_evidence"] = {"file": "logs/samples.full.json", "sha256": FileAccess.get_sha256(evidence)}
	super.write_report(output, summary)
	print("RR20 COMPACT SAMPLES: PASS (%d inventories; full transforms in ignored logs)" % counts.size())
