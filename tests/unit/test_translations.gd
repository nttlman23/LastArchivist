extends GutTest
## Целостность строк: CSV без сломанных строк, все ключи из кода и данных существуют.

const CSV_PATH := "res://translations/strings.csv"
const CODE_DIRS := ["res://scripts/presentation", "res://scripts/autoload"]


func _csv_keys() -> Dictionary:
	var keys := {}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := f.get_csv_line()
	assert_eq(Array(header), ["keys", "ru"])
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		assert_eq(row.size(), 2, "строка CSV: %s" % ",".join(row))
		assert_false(keys.has(row[0]), "дубликат ключа %s" % row[0])
		keys[row[0]] = row[1]
	return keys


func test_csv_well_formed() -> void:
	assert_gt(_csv_keys().size(), 0)


func test_code_keys_exist() -> void:
	var keys := _csv_keys()
	var re := RegEx.create_from_string("tr(?:anslate)?\\(\"([A-Z0-9_]+)\"\\)")
	for dir: String in CODE_DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(file))
			for m in re.search_all(text):
				assert_true(keys.has(m.get_string(1)), "%s: нет ключа %s" % [file, m.get_string(1)])


func test_data_keys_exist() -> void:
	var keys := _csv_keys()
	var db := DefsDB.load_default()
	for u: UnitDef in db.units.values():
		assert_true(keys.has(u.name_key), u.name_key)
	for m: MemoryCardDef in db.memories.values():
		assert_true(keys.has(m.name_key), m.name_key)
	for e: EncounterDef in db.encounters.values():
		assert_true(keys.has(e.name_key), e.name_key)
