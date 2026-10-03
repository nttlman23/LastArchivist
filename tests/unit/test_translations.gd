extends GutTest
## Целостность строк: CSV без сломанных строк, все ключи из кода и данных существуют.

const CSV_PATH := "res://translations/strings.csv"
const CODE_DIRS := ["res://scripts/presentation", "res://scripts/autoload", "res://scripts/systems"]


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
	for c: CommanderDef in db.commanders.values():
		assert_true(keys.has(c.name_key), c.name_key)
		assert_true(keys.has(c.desc_key), c.desc_key)
		for act in c.actions:
			assert_true(keys.has("CMDACT_" + String(act).to_upper()), "CMDACT_" + String(act).to_upper())
	for o in ObjectiveRule.ALL:
		assert_true(keys.has("OBJ_" + String(o).to_upper()), "OBJ_" + String(o).to_upper())
		assert_true(keys.has("OBJ_" + String(o).to_upper() + "_DESC"), "OBJ_%s_DESC" % String(o).to_upper())
	for d in Difficulty.ALL:
		assert_true(keys.has("DIFFICULTY_" + String(d).to_upper()), String(d))
		assert_true(keys.has("DIFFICULTY_" + String(d).to_upper() + "_DESC"), String(d))
	for a: AbilityDef in db.abilities.values():
		assert_true(keys.has(a.name_key), a.name_key)
		assert_true(keys.has(a.desc_key), a.desc_key)
	for sp: SpellDef in db.spells.values():
		assert_true(keys.has(sp.name_key), sp.name_key)
		assert_true(keys.has(sp.desc_key), sp.desc_key)
	for o: OrderDef in db.orders.values():
		assert_true(keys.has(o.name_key), o.name_key)
		assert_true(keys.has(o.desc_key), o.desc_key)
	for up: UpgradeDef in db.upgrades.values():
		assert_true(keys.has(up.name_key), up.name_key)
	for m: MemoryCardDef in db.memories.values():
		if m.desc_key != "":
			assert_true(keys.has(m.desc_key), m.desc_key)
