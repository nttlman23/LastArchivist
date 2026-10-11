extends GutTest
## Спринт 11: учебные забеги — первые два забега профиля с ослабленными врагами на слоях 1–3
## первого акта, без командиров; миграции забега v11 → v12 и профиля v4 → v5.

const PROFILE_PATH := "user://test_gentle_profile.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_all() -> void:
	SafeFile.remove(PROFILE_PATH)


## Забег на первом боевом острове слоя layer (если такого нет — null).
func _at_battle_layer(run: RunState, layer: int) -> RunState:
	for n in run.map.layer_nodes(layer):
		if n.type == MapState.NodeType.BATTLE:
			run.map.current = n.id
			run.pending_node = n.id
			return run
	return null


func test_start_spends_gentle_runs() -> void:
	var profile := ProfileState.new()
	assert_eq(profile.gentle_runs_left, ProfileState.GENTLE_RUNS)
	var first := RunState.create(db, 1, DefsDB.DEFAULT_SCHOOL, profile)
	GentleRuns.start(first, profile, true)
	var second := RunState.create(db, 2, DefsDB.DEFAULT_SCHOOL, profile)
	GentleRuns.start(second, profile, true)
	var third := RunState.create(db, 3, DefsDB.DEFAULT_SCHOOL, profile)
	GentleRuns.start(third, profile, true)
	assert_true(first.gentle and second.gentle)
	assert_false(third.gentle, "только два первых забега")
	assert_eq(profile.gentle_runs_left, 0)


func test_not_gentle_when_disabled_trial_or_daily() -> void:
	var profile := ProfileState.new()
	var run := RunState.create(db, 1, DefsDB.DEFAULT_SCHOOL, profile)
	GentleRuns.start(run, profile, false)
	assert_false(run.gentle, "выключено в настройках")
	var trial := RunState.create(db, 1, DefsDB.DEFAULT_SCHOOL, profile)
	trial.trial = 1
	GentleRuns.start(trial, profile, true)
	assert_false(trial.gentle, "испытание")
	var daily := DailyRun.create(db, profile, "2026-10-11")
	GentleRuns.start(daily, profile, true)
	assert_false(daily.gentle, "ежедневный")
	assert_eq(profile.gentle_runs_left, ProfileState.GENTLE_RUNS, "счётчик не тратится")


func test_enemies_weaker_on_first_layers_only() -> void:
	for layer in [1, 3, 4]:
		var plain := _at_battle_layer(RunState.create(db, 7), layer)
		var gentle := _at_battle_layer(RunState.create(db, 7), layer)
		if plain == null:
			continue
		gentle.gentle = true
		var a := BattleSetup.for_run(db, plain, plain.codex.unit_indices(db))
		var b := BattleSetup.for_run(db, gentle, gentle.codex.unit_indices(db))
		var ea := a.alive(UnitState.Side.ENEMY)
		var eb := b.alive(UnitState.Side.ENEMY)
		assert_eq(ea.size(), eb.size())
		for i in ea.size():
			var expected: int = maxi(1, roundi(ea[i].count * GentleRuns.COUNT_FACTOR)) if layer <= GentleRuns.LAST_LAYER else ea[i].count
			assert_eq(eb[i].count, expected, "слой %d" % layer)
			assert_eq(eb[i].start_count, eb[i].count)
			var enc := db.encounter(gentle.current_encounter_id(db))
			assert_eq(GentleRuns.count(gentle, layer, enc, ea[i].count), expected, "подпись совпадает с боем")


func test_no_commander_on_gentle_layers() -> void:
	var run := _at_battle_layer(RunState.create(db, 7, DefsDB.DEFAULT_SCHOOL, null, Difficulty.HARD), 3)
	var enc := db.encounter(run.current_encounter_id(db))
	assert_ne(Difficulty.commander_for(db, run, enc), &"", "на «Тяжело» со слоя 3 командир есть")
	run.gentle = true
	assert_eq(Difficulty.commander_for(db, run, enc), &"", "в учебном забеге — нет")


func test_second_act_not_gentle() -> void:
	var run := RunState.create(db, 7)
	run.gentle = true
	MapActions.begin_act(db, run, 2)
	assert_false(GentleRuns.active(run, 1))


func test_run_v11_migrates() -> void:
	var d := RunState.create(db, 5).to_dict()
	d["version"] = 11
	d.erase("gentle")
	var loaded := RunState.from_dict(SaveMigrations.migrate(d))
	assert_not_null(loaded)
	assert_false(loaded.gentle, "старый забег — обычный")


func test_run_gentle_roundtrip() -> void:
	var run := RunState.create(db, 5)
	run.gentle = true
	assert_true(RunState.from_dict(run.to_dict()).gentle)


func test_profile_v4_migrates_gentle_runs() -> void:
	for runs in [0, 1, 5]:
		var cfg := ConfigFile.new()
		cfg.set_value("profile", "version", 4)
		cfg.set_value("stats", "runs", runs)
		SafeFile.save_config(cfg, PROFILE_PATH)
		var p := ProfileState.load_or_new(PROFILE_PATH)
		assert_eq(p.gentle_runs_left, maxi(0, ProfileState.GENTLE_RUNS - runs), "сыграно %d" % runs)
		assert_false(p.tutorial2_done)


func test_profile_gentle_roundtrip() -> void:
	var p := ProfileState.new()
	p.gentle_runs_left = 1
	p.tutorial2_done = true
	p.save(PROFILE_PATH)
	var loaded := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(loaded.gentle_runs_left, 1)
	assert_true(loaded.tutorial2_done)
