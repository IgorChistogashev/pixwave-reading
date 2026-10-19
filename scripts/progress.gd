extends RefCounted
const PATH = "user://progress.json"
var data: Dictionary = {"version": 1, "completed": false, "stars": 0, "practice_requests": 0, "confirmations": 0}
func load_progress() -> void:
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and parsed.get("version") == 1:
			data.merge(parsed, true)
func save() -> bool:
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true
