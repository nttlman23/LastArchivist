extends GutTest
## Спринт 9: ежедневный забег — раскладка по дате, зачёт попытки, счёт, история, модификаторы,
## отдельное сохранение; миграции профиля v2 → v3 и забега v9 → v10.

const DATE := "2026-10-05"
const PATH := "user://test_daily_run.json"
const PROFILE_PATH := "user://test_daily_profile.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_all() -> void:
	SafeFile.remove(PATH)
	SafeFile.remove(PROFILE_PATH)


## Ежедневный забег с заданными модификаторами (раскладку дня подменяем).
func _daily(mods: Array[StringName], profile: ProfileState = null) -> RunState:
	var run := DailyRun.create(db, profile, DATE)
	run.modifiers = mods
	return run


func _in_battle(run: RunState) -> BattleState:
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	return BattleSetup.for_run(db, run, run.codex.unit_indices(db))


func test_layout_by_date() -> void:
	var p := ProfileState.new()
	var a := DailyRun.layout(db, p, DATE)
	assert_eq(a, DailyRun.layout(db, p, DATE), "одна дата — одна раскладка")
	var mods: Array = a["modifiers"]
	assert_eq(mods.size(), 2)
	assert_true(DailyRun.PLUS.has(mods[0]) and DailyRun.MINUS.has(mods[1]), "один плюс и один минус")
	var seen := {}
	for d in 20:
		seen[DailyRun.layout(db, p, DailyRun.shift_date(DATE, d)).hash()] = true
	assert_gt(seen.size(), 5, "разные дни — разные раскладки")


func test_layout_school_from_open() -> void:
	var p := ProfileState.new()
	for d in 30:
		assert_eq(DailyRun.layout(db, p, DailyRun.shift_date(DATE, d))["school"], DefsDB.DEFAULT_SCHOOL, "открыта только стартовая школа")
	for s in db.schools_sorted():
		p.unlocked.append(MetaRewards.school_unlock_id(s.id))
	var schools := {}
	for d in 30:
		schools[DailyRun.layout(db, p, DailyRun.shift_date(DATE, d))["school"]] = true
	assert_gt(schools.size(), 1, "из всех открытых школ")


func test_create() -> void:
	var p := ProfileState.new()
	var run := DailyRun.create(db, p, DATE)
	assert_eq(run.daily_date, DATE)
	assert_eq(run.difficulty, Difficulty.NORMAL)
	assert_eq(run.trial, 0)
	assert_true(run.daily_ranked)
	assert_eq(run.run_seed, DailyRun.date_seed(DATE))
	p.daily_last = DATE
	assert_false(DailyRun.create(db, p, DATE).daily_ranked, "день уже засчитан — повтор")


func test_one_counted_attempt() -> void:
	var p := ProfileState.new()
	var first := DailyRun.create(db, p, DATE)
	var second := DailyRun.create(db, p, DATE)
	assert_true(DailyRun.record(p, first, ProfileState.OUTCOME_ABANDONED), "первая попытка засчитана (брошена)")
	assert_false(DailyRun.record(p, second, ProfileState.OUTCOME_WON), "вторая — нет")
	assert_eq(p.daily.size(), 1)
	assert_eq(p.daily_count, 1)
	assert_eq(p.daily_last, DATE)
	assert_eq(DailyRun.entry_for(p, DATE)["outcome"], ProfileState.OUTCOME_ABANDONED)


func test_date_change_keeps_layout() -> void:
	var p := ProfileState.new()
	var run := DailyRun.create(db, p, DATE)
	SaveService.save_run(run, PATH)
	# Полночь посреди забега: попытка остаётся попыткой своего дня.
	var loaded := SaveService.load_run(PATH)
	assert_eq(loaded.daily_date, DATE)
	assert_eq(loaded.modifiers, run.modifiers)
	assert_eq(loaded.run_seed, run.run_seed)
	assert_true(DailyRun.record(p, loaded, ProfileState.OUTCOME_LOST))
	assert_eq(p.daily_last, DATE)


func test_score() -> void:
	var run := DailyRun.create(db, null, DATE)
	run.elites_won = 2
	run.resources = {RunState.INK: 3, RunState.PARCHMENT: 4, RunState.AETHER: 1}
	var layer := run.total_layer()
	assert_eq(DailyRun.score(run, false), layer * 10 + 2 * 15 + 8)
	run.act = 2
	assert_eq(DailyRun.score(run, false), run.total_layer() * 10 + 30 + 50 + 8, "Разлом закрыт — один босс")
	assert_eq(DailyRun.score(run, true), run.total_layer() * 10 + 30 + 100 + 8, "победа — два босса")


func test_history_trimmed() -> void:
	var p := ProfileState.new()
	for d in 40:
		p.record_daily({"date": DailyRun.shift_date(DATE, d), "score": d * 10, "outcome": "lost"})
	assert_eq(p.daily.size(), ProfileState.DAILY_SIZE)
	assert_eq(p.daily_count, 40)
	assert_eq(p.daily_best, 390)
	assert_eq(p.daily[0]["date"], DailyRun.shift_date(DATE, 39), "новые первыми")


func test_shift_date() -> void:
	assert_eq(DailyRun.shift_date("2026-10-05", -5), "2026-09-30")
	assert_eq(DailyRun.shift_date("2026-12-31", 1), "2027-01-01")


func test_separate_save() -> void:
	var run := DailyRun.create(db, null, DATE)
	assert_eq(SaveService.path_for(run), SaveService.daily_path)
	assert_eq(SaveService.path_for(RunState.create(db, 1)), SaveService.current_path)


# --- Модификаторы -------------------------------------------------------------------------

func test_generous_shops() -> void:
	var run := _daily([DailyRun.GENEROUS_SHOPS])
	assert_eq(ShopOps.price(db, &"salt_legion", run), ShopOps.price(db, &"salt_legion", null) - 1)


func test_old_friends() -> void:
	var run := _daily([])
	run.modifiers = [DailyRun.OLD_FRIENDS]
	var before := run.resources.duplicate()
	var codex := run.codex.to_array()
	DailyRun.apply_start(db, run)
	assert_eq(run.relics.size(), 1, "старт с реликвией")
	assert_eq(run.resources, before, "разовая цена не взята")
	assert_eq(run.codex.to_array(), codex)


func test_heavy_dreams() -> void:
	var run := _daily([])
	var before: Array[int] = []
	for c in run.codex.cards:
		before.append(c.durability)
	run.modifiers = [DailyRun.HEAVY_DREAMS]
	DailyRun.apply_start(db, run)
	for i in run.codex.cards.size():
		assert_eq(run.codex.cards[i].durability, maxi(1, before[i] - 1))


func test_quick_quills() -> void:
	var s := _in_battle(_daily([DailyRun.QUICK_QUILLS]))
	var s0 := _in_battle(_daily([]))
	assert_eq(s.alive(UnitState.Side.PLAYER)[0].initiative, s0.alive(UnitState.Side.PLAYER)[0].initiative + 1)


func test_full_inkwells() -> void:
	var run := _daily([DailyRun.FULL_INKWELLS])
	var i := run.codex.unit_indices(db)[0]
	var base := CodexOps.spell_charges(run.codex.cards[i])
	CodexOps.apply(db, run, i, CodexOps.Form.SPELL)
	assert_eq(run.hero.spells[0].charges, base + DailyRun.INKWELL_CHARGES, "первое заклинание +2")
	i = run.codex.unit_indices(db)[0]
	base = CodexOps.spell_charges(run.codex.cards[i])
	CodexOps.apply(db, run, i, CodexOps.Form.SPELL)
	assert_eq(run.hero.spells[1].charges, base, "второе — без бонуса")


func _boss_hp(mods: Array[StringName]) -> int:
	var run := _daily(mods)
	for n in run.map.nodes:
		if n.type == MapState.NodeType.RIFT:
			run.map.current = n.id
			run.pending_node = n.id
	var s := BattleSetup.for_run(db, run, run.codex.unit_indices(db))
	return s.get_unit(s.boss_uid).hp


func test_hungry_rift() -> void:
	var base := _boss_hp([])
	assert_eq(_boss_hp([DailyRun.HUNGRY_RIFT]), base + ceili(base * DailyRun.BOSS_HP_SHARE), "босс +20% ОЗ")


func test_dampness() -> void:
	var s := _in_battle(_daily([DailyRun.DAMPNESS]))
	assert_eq(s.water.size(), DailyRun.DAMP_HEXES)
	for h in s.water:
		assert_null(s.unit_at(h), "вода не под отрядами")
		assert_false(s.is_obstacle(h))
	assert_true(_in_battle(_daily([])).water.is_empty())
	var again := _in_battle(_daily([DailyRun.DAMPNESS]))
	assert_eq(again.water.keys(), s.water.keys(), "детерминированно")


func test_early_commander() -> void:
	var run := _daily([DailyRun.EARLY_COMMANDER])
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	var enc := db.encounter(run.current_encounter_id(db))
	assert_ne(Difficulty.commander_for(db, run, enc), &"", "командир уже в первом бою")
	run.modifiers = []
	assert_eq(Difficulty.commander_for(db, run, enc), &"")


# --- Сохранения ---------------------------------------------------------------------------

func test_daily_save_roundtrip() -> void:
	var run := DailyRun.create(db, null, DATE)
	run.objectives_won.append(ObjectiveRule.HOLD)
	run.reworks.append(&"fuse")
	run.shop_buys = 2
	run.node_types.append(MapState.NodeType.SHOP)
	run.relic_unlocks.append(&"rift_shard")
	run.inkwell_used = true
	SaveService.save_run(run, PATH)
	var loaded := SaveService.load_run(PATH)
	assert_not_null(loaded)
	assert_eq(loaded.daily_date, DATE)
	assert_eq(loaded.modifiers, run.modifiers)
	assert_eq(loaded.daily_ranked, run.daily_ranked)
	assert_eq(loaded.objectives_won, run.objectives_won)
	assert_eq(loaded.reworks, run.reworks)
	assert_eq(loaded.shop_buys, 2)
	assert_eq(loaded.node_types, run.node_types)
	assert_eq(loaded.relic_unlocks, run.relic_unlocks)
	assert_true(loaded.inkwell_used)


func test_run_v9_migrates() -> void:
	var d := RunState.create(db, 5).to_dict()
	d["version"] = 9
	for k in ["objectives_won", "reworks", "shop_buys", "node_types", "relic_unlocks", "daily_date", "modifiers", "daily_ranked", "inkwell_used"]:
		d.erase(k)
	var loaded := RunState.from_dict(SaveMigrations.migrate(d))
	assert_not_null(loaded)
	assert_eq(loaded.daily_date, "", "старый забег — обычный")
	assert_true(loaded.modifiers.is_empty())
	assert_eq(loaded.shop_buys, 0)


func test_profile_v3_roundtrip() -> void:
	var p := ProfileState.new()
	p.achievements[&"miser"] = "2026-10-04"
	p.record_daily({"date": DATE, "school": "ash_archive", "modifiers": ["dampness"], "layer": 9, "score": 140, "outcome": "lost"})
	p.save(PROFILE_PATH)
	var q := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(q.achievements, p.achievements)
	assert_eq(q.daily, p.daily)
	assert_eq(q.daily_last, DATE)
	assert_eq(q.daily_best, 140)
	assert_eq(q.daily_count, 1)
	assert_false(q.needs_retro, "профиль v3 — без повторной выдачи")


func test_profile_v2_migrates() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", 2)
	cfg.set_value("profile", "points", 9)
	cfg.set_value("stats", "wins", 1)
	SafeFile.save_config(cfg, PROFILE_PATH)
	var p := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(p.points, 9)
	assert_true(p.achievements.is_empty())
	assert_true(p.daily.is_empty())
	assert_true(p.needs_retro, "старый профиль — выдать достижения по статистике")
	Achievements.grant_retro(db, p)
	assert_true(p.has_achievement(Achievements.DROWNED_VICTORY))
	assert_eq(p.points, 9 + 3 + 5)
