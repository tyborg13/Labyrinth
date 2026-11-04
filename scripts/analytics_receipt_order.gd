extends RefCounted
## Owned JSONL records in emission order. A receipt is released only by its
## durable outbox writer after the owning checkpoint has succeeded.
var entries: Array[Dictionary]

func busy() -> bool:
	return not entries.is_empty()

func find_key(key: String) -> Dictionary:
	if key.is_empty(): return {}
	for entry: Dictionary in entries:
		if str(entry["record"].get("idempotency_key", "")) == key: return entry
	return {}

func contains_id(id: String) -> bool:
	for entry: Dictionary in entries:
		if str(entry["record"]["event_id"]) == id: return true
	return false

func append(record: Dictionary, path: String, ready: bool) -> void:
	entries.append({"record": record.duplicate(true), "path": path, "ready": ready, "submitted": false})

func next_batch() -> Dictionary:
	if entries.is_empty() or not bool(entries[0]["ready"]): return {}
	var first: Dictionary = entries[0]
	var records: Array[Dictionary]
	for entry: Dictionary in entries:
		if not bool(entry["ready"]) or entry["path"] != first["path"] or entry["submitted"] != first["submitted"]: break
		records.append(entry["record"])
	return {"path": first["path"], "records": records, "submitted": first["submitted"]}

func mark_submitted(count: int) -> void:
	for index: int in range(count): entries[index]["submitted"] = true

func acknowledge(count: int) -> void:
	for _index: int in range(count): entries.pop_front()
