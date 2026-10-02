class_name SaveService
extends RefCounted
## Сохранение забега в JSON (SPEC 6.3).
## Путь по умолчанию можно подменить (автопрогон, тесты), чтобы не трогать сохранение игрока.

const DEFAULT_PATH := "user://run_save.json"

## Текущий путь сохранения; пустой аргумент path у функций означает его.
static var current_path := DEFAULT_PATH


static func save_run(run: RunState, path: String = "") -> bool:
	path = _resolve(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save %s: %s" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(run.to_dict(), "\t"))
	return true


static func load_run(path: String = "") -> RunState:
	path = _resolve(path)
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Corrupted save %s" % path)
		return null
	return RunState.from_dict(json.data)


static func has_save(path: String = "") -> bool:
	return FileAccess.file_exists(_resolve(path))


static func delete_save(path: String = "") -> void:
	path = _resolve(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _resolve(path: String) -> String:
	return current_path if path == "" else path
