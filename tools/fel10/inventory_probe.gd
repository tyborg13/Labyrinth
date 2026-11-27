extends SceneTree
## Verify required inventory fields and source anchors.

const FIELDS := ["id", "family", "sites", "path", "grid", "blend", "alpha", "colors", "shape", "cost", "evidence"]


func _initialize() -> void:
	var path: String = OS.get_environment("FEL10_INVENTORY")
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not rows is Array or rows.is_empty():
		_fail("cannot read " + path)
		return
	var ids: Dictionary
	var sources: Dictionary
	var counts: Dictionary
	for row: Dictionary in rows:
		for field: String in FIELDS:
			if not row.has(field) or str(row[field]).is_empty():
				_fail("missing inventory field " + field)
				return
		var id: String = row["id"]
		if ids.has(id):
			_fail("duplicate inventory ID " + id)
			return
		ids[id] = true
		for site: String in row["sites"]:
			var parts: PackedStringArray = site.rsplit(":", false, 1)
			var resource: String = "res://" + parts[0]
			if not sources.has(resource):
				sources[resource] = FileAccess.get_file_as_string(resource).split("\n")
			var number: int = int(parts[1])
			var source: PackedStringArray = sources[resource]
			if number < 1 or number > source.size() or not source[number - 1].contains("func "):
				_fail("invalid source anchor " + site)
				return
		var evidence: String = row["evidence"]
		counts[evidence] = int(counts.get(evidence, 0)) + 1
		print("FEL10 INVENTORY %s family=%s site=%s path=%s" % [id, row["family"], row["sites"][0], row["path"]])
	print("FEL10 INVENTORY PASS rows=%d runtime=%d audit_only=%d dormant=%d" % [
		rows.size(), counts.get("runtime", 0), counts.get("audit-only", 0), counts.get("dormant", 0)])
	quit()


func _fail(message: String) -> void:
	printerr("FEL10 INVENTORY FAIL " + message)
	quit(1)
