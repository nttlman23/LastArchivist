class_name SaveService
extends RefCounted
## Сохранение забега в JSON (SPEC 6.3).

const DEFAULT_PATH := "user://run_save.json"


static func save_run(run: RunState, path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save %s: %s" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(run.to_dict(), "\t"))
	return true


static func load_run(path: String = DEFAULT_PATH) -> RunState:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Corrupted save %s" % path)
		return null
	return RunState.from_dict(json.data)


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete_save(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
