class_name SaveService
extends RefCounted
## Сохранение забега в JSON (SPEC 6.3). Запись атомарная с резервной копией, старые версии
## переводятся миграциями (SPEC_SPRINT6 13). Повреждённый файл не роняет игру: берётся копия.
## Путь по умолчанию можно подменить (автопрогон, тесты), чтобы не трогать сохранение игрока.

const DEFAULT_PATH := "user://run_save.json"

## Текущий путь сохранения; пустой аргумент path у функций означает его.
static var current_path := DEFAULT_PATH


static func save_run(run: RunState, path: String = "") -> bool:
	return SafeFile.write_text(_resolve(path), JSON.stringify(run.to_dict(), "\t"))


static func load_run(path: String = "") -> RunState:
	var text := SafeFile.read_text(_resolve(path), func(t: String) -> bool: return not _parse(t).is_empty())
	if text == "":
		return null
	return RunState.from_dict(_parse(text))


## Сохранение есть на диске, но не читается ни оно, ни резервная копия.
static func is_broken(path: String = "") -> bool:
	return has_save(path) and load_run(path) == null


## Словарь сохранения в текущей версии или пустой (не JSON, не словарь, неподдерживаемая версия).
static func _parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var d := SaveMigrations.migrate(json.data)
	return d if d.has_all(RunState.REQUIRED_KEYS) else {}


static func has_save(path: String = "") -> bool:
	return FileAccess.file_exists(_resolve(path))


static func delete_save(path: String = "") -> void:
	SafeFile.remove(_resolve(path))


static func _resolve(path: String) -> String:
	return current_path if path == "" else path
