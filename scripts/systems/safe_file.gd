class_name SafeFile
extends RefCounted
## Надёжная запись файлов (SPEC_SPRINT6 13): во временный файл, затем замена; прежняя версия
## уходит в резервную копию *.bak. Сбой посреди записи не портит последнее хорошее сохранение.

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"


## Записывает текст атомарно. false — не удалось (прежний файл не тронут).
static func write_text(path: String, text: String) -> bool:
	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s: %s" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return _commit(path)


## Сохраняет ConfigFile атомарно.
static func save_config(cfg: ConfigFile, path: String) -> bool:
	var tmp := path + TMP_SUFFIX
	if cfg.save(tmp) != OK:
		push_error("Cannot write %s" % tmp)
		return false
	return _commit(path)


## Текст файла или резервной копии (если основной пуст/не читается — проверяет reader).
## reader(text) -> bool: годится ли содержимое. Возвращает "" если ничего не годится.
static func read_text(path: String, reader: Callable) -> String:
	for p in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if not FileAccess.file_exists(p):
			continue
		var text := FileAccess.get_file_as_string(p)
		if text != "" and reader.call(text):
			if p != path:
				push_warning("Using fallback %s" % p)
			return text
	return ""


## ConfigFile из файла или резервной копии; null — ничего не читается.
## valid(cfg) -> bool — годится ли содержимое (например, есть версия).
static func load_config(path: String, valid: Callable = Callable()) -> ConfigFile:
	for p in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if not FileAccess.file_exists(p):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(p) == OK and (not valid.is_valid() or valid.call(cfg)):
			if p != path:
				push_warning("Using fallback %s" % p)
			return cfg
	return null


static func remove(path: String) -> void:
	for p in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _commit(path: String) -> bool:
	var tmp := path + TMP_SUFFIX
	if FileAccess.file_exists(path):
		var bak := path + BAK_SUFFIX
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			push_error("Cannot back up %s" % path)
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_error("Cannot replace %s" % path)
		return false
	return true
