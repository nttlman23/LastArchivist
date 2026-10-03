extends GutTest
## Этап B Спринта 6: миграция и надёжность сохранений, детерминизм боя, короткий стресс.

const PATH := "user://test_stability_save.json"
const CFG := "user://test_stability.cfg"
const FIXTURE_V5 := "res://tests/fixtures/run_save_v5.json"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	SafeFile.remove(PATH)
	SafeFile.remove(CFG)


# --- Миграция ---------------------------------------------------------------------

func test_v5_fixture_migrates_and_continues() -> void:
	var text := FileAccess.get_file_as_string(FIXTURE_V5)
	assert_ne(text, "")
	SafeFile.write_text(PATH, text)
	var run := SaveService.load_run(PATH)
	assert_not_null(run, "сохранение v5 читается")
	assert_eq(run.cards_lost, 0, "новое поле получило значение по умолчанию")
	assert_eq(run.difficulty, Difficulty.HARD)
	assert_eq(run.school_id, &"tide_order")
	assert_eq(run.battles_won, 1)
	# Дальше забег сохраняется уже в текущей версии.
	SaveService.save_run(run, PATH)
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(PATH))
	assert_eq(int(json.data["version"]), RunState.SAVE_VERSION)


func test_unsupported_versions() -> void:
	assert_true(SaveMigrations.migrate({"version": 4}).is_empty(), "до v5 не читается")
	assert_true(SaveMigrations.migrate({"version": RunState.SAVE_VERSION + 1}).is_empty(), "из будущего — тоже")
	assert_false(SaveMigrations.migrate({"version": RunState.SAVE_VERSION}).is_empty())


# --- Надёжная запись -------------------------------------------------------------------

func test_write_keeps_backup() -> void:
	var run := RunState.create(db, 11)
	SaveService.save_run(run, PATH)
	run.battles_won = 3
	SaveService.save_run(run, PATH)
	assert_true(FileAccess.file_exists(PATH + SafeFile.BAK_SUFFIX), "прежняя версия — в резервной копии")
	assert_false(FileAccess.file_exists(PATH + SafeFile.TMP_SUFFIX), "временный файл убран")
	assert_eq(SaveService.load_run(PATH).battles_won, 3)


func test_corrupted_save_uses_backup() -> void:
	var run := RunState.create(db, 12)
	run.battles_won = 2
	SaveService.save_run(run, PATH)
	run.battles_won = 5
	SaveService.save_run(run, PATH)
	# Основной файл испорчен: обрезан посреди JSON.
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{\"battles_won\": 5, \"cod")
	f.close()
	var loaded := SaveService.load_run(PATH)
	assert_not_null(loaded, "берётся резервная копия")
	assert_eq(loaded.battles_won, 2)


func test_garbage_and_empty_files() -> void:
	for content in ["", "not json at all", "[1, 2, 3]", "{\"version\": 6}"]:
		SafeFile.remove(PATH)
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		assert_null(SaveService.load_run(PATH), "«%s» — без падения, забега нет" % content)
		assert_true(SaveService.is_broken(PATH))


func test_delete_removes_backup() -> void:
	var run := RunState.create(db, 13)
	SaveService.save_run(run, PATH)
	SaveService.save_run(run, PATH)
	SaveService.delete_save(PATH)
	assert_null(SaveService.load_run(PATH), "после конца забега копия не воскрешает его")


func test_profile_config_backup() -> void:
	var p := ProfileState.new()
	p.points = 3
	p.save(CFG)
	p.points = 9
	p.save(CFG)
	# Основной файл обнулился (сбой посреди записи).
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	f.close()
	assert_eq(ProfileState.load_or_new(CFG).points, 3, "профиль — из резервной копии")


# --- Детерминизм ------------------------------------------------------------------------

func _battle(enc: StringName, seed_value: int, difficulty: StringName = Difficulty.NORMAL, commander: StringName = &"") -> BattleState:
	var codex := CodexState.new()
	for id in [&"salt_legion", &"ghoul_pack", &"ash_chroniclers", &"clock_turrets"]:
		codex.add(db, id)
	var s := BattleState.create(db, db.encounter(enc), codex, [0, 1, 2, 3], seed_value, null, &"", difficulty, commander)
	BattleResolver.begin(s)
	return s


func _play_out(s: BattleState, limit: int = 3000) -> int:
	var n := 0
	while s.outcome == BattleState.Outcome.NONE and n < limit:
		BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
		n += 1
	return n


func test_same_seed_same_battle() -> void:
	var a := _battle(&"t3_siege", 77, Difficulty.HARD, &"ash_overseer")
	var b := _battle(&"t3_siege", 77, Difficulty.HARD, &"ash_overseer")
	_play_out(a)
	_play_out(b)
	assert_eq(a.to_dict(), b.to_dict(), "один сид — один и тот же бой до последнего байта")


func test_save_mid_battle_keeps_outcome() -> void:
	var a := _battle(&"elite_siege", 5, Difficulty.NORMAL, &"salt_keeper")
	for i in 12:
		if a.outcome == BattleState.Outcome.NONE:
			BattleResolver.apply(a, AiController.choose_action(a, a.active_uid))
	var b := BattleState.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	_play_out(a)
	_play_out(b)
	assert_eq(b.outcome, a.outcome)
	assert_eq(b.round_number, a.round_number)
	assert_eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()))


# --- Короткий стресс -----------------------------------------------------------------------

func test_short_stress_all_encounters_finish() -> void:
	var ids := db.encounters.keys()
	ids.sort()
	var difficulties := Difficulty.ALL
	var commanders := db.commander_ids()
	var n := 0
	for i in ids.size():
		for d in difficulties.size():
			var s := _battle(ids[i], 1000 + i * 7 + d, difficulties[d], commanders[(i + d) % commanders.size()])
			var actions := _play_out(s)
			assert_ne(s.outcome, BattleState.Outcome.NONE, "%s/%s закончился за %d действий" % [ids[i], difficulties[d], actions])
			n += 1
	assert_eq(n, ids.size() * difficulties.size())
