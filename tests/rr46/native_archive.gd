extends RefCounted

const IDs = preload("id_pass.gd")
const REPORT_RESERVE_BYTES: int = 2000000
var output: String
var report: Dictionary
var started: int
var bytes_written: int = 0
var budget_exceeded: bool = false

func _init(folder: String, data: Dictionary) -> void:
	output=folder; report=data; started=Time.get_ticks_usec()

func save(image: Image, name: String) -> String:
	var buffer: PackedByteArray = image.save_png_to_buffer()
	if bytes_written+buffer.size()>IDs.MAX_BYTES-REPORT_RESERVE_BYTES:
		budget_exceeded=true
		report["errors"].append("250 MB archive budget exceeded")
		return ""
	FileAccess.open(output.path_join(name),FileAccess.WRITE).store_buffer(buffer)
	bytes_written += buffer.size()
	return name

func within_budget() -> bool:
	return not budget_exceeded and (Time.get_ticks_usec()-started)/1000000.0<IDs.MAX_SECONDS and bytes_written<IDs.MAX_BYTES

func write_report() -> void:
	report["cost"] = {"elapsed_seconds":(Time.get_ticks_usec()-started)/1000000.0,"bytes":bytes_written}
	if not within_budget() and not report["errors"].has("Native proof budget exceeded"): report["errors"].append("Native proof budget exceeded")
	var text: String = JSON.stringify(report,"\t")
	report["cost"]["bytes"] = bytes_written+text.to_utf8_buffer().size()
	if report["cost"]["bytes"]>IDs.MAX_BYTES: report["errors"].append("Native proof budget exceeded")
	FileAccess.open(output.path_join("findings.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
