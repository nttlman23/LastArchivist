extends GutTest

const PATH := "user://test_run_save.json"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	SaveService.delete_save(PATH)


func test_run_roundtrip() -> void:
	var run := RunState.create(db, -8070450532247928832)
	run.battles_won = 1
	run.resources[RunState.INK] = 7
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	MapActions.complete(run)
	run.codex.cards[0].durability = 1
	run.codex.cards[1].level = 2
	run.codex.add(db, &"last_king")
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	CodexOps.apply(db, run, 2, CodexOps.Form.UPGRADE)
	run.roll_rewards(db)
	assert_true(SaveService.save_run(run, PATH))
	var loaded := SaveService.load_run(PATH)
	assert_not_null(loaded)
	assert_eq(loaded.run_seed, run.run_seed)
	assert_eq(loaded.battles_won, 1)
	assert_eq(loaded.resources[RunState.INK], 7)
	assert_eq(loaded.map.to_dict(), run.map.to_dict())
	assert_eq(loaded.codex.to_array(), run.codex.to_array())
	assert_eq(loaded.hero.to_dict(), run.hero.to_dict())
	assert_eq(loaded.codex.cards[1].level, 2)
	# Генератор лута продолжает ту же последовательность.
	assert_eq(loaded.roll_rewards(db), run.roll_rewards(db))


func test_missing_and_corrupted() -> void:
	assert_false(SaveService.has_save(PATH))
	assert_null(SaveService.load_run(PATH))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(SaveService.load_run(PATH))


func test_wrong_version_rejected() -> void:
	var d := RunState.create(db, 1).to_dict()
	d["version"] = 999
	assert_null(RunState.from_dict(d))


func test_old_save_rejected() -> void:
	var d := RunState.create(db, 1).to_dict()
	d["version"] = 2
	assert_null(RunState.from_dict(d))


func test_battle_state_roundtrip() -> void:
	var run := RunState.create(db, 3)
	CodexOps.apply(db, run, 3, CodexOps.Form.SPELL)
	var selected: Array[int] = [0, 1]
	var s := BattleState.create(db, db.encounter(&"crypt_4"), run.codex, selected, 77, run.hero)
	s.temp_obstacles[Vector2i(5, 5)] = 2
	s.units[0].statuses[UnitState.STATUS_MARKED] = UnitState.PERMANENT
	BattleResolver.begin(s)
	BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
	var json := JSON.stringify(s.to_dict())
	var restored := BattleState.from_dict(JSON.parse_string(json))
	assert_eq(JSON.stringify(restored.to_dict()), json)
	# Восстановленный бой продолжается идентично.
	BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
	BattleResolver.apply(restored, AiController.choose_action(restored, restored.active_uid))
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(s.to_dict()))
