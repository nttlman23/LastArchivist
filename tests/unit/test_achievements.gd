extends GutTest
## Спринт 9: достижения — данные, условия, награда один раз, открытия, старые профили.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _run(difficulty: StringName = Difficulty.NORMAL, trial: int = 0, profile: ProfileState = null) -> RunState:
	return RunState.create(db, 17, DefsDB.DEFAULT_SCHOOL, profile, difficulty, trial)


func _check(p: ProfileState, run: RunState, event: Achievements.Event, ctx: Dictionary = {}) -> Array[StringName]:
	return Achievements.check(db, p, run, event, ctx)


func _battle_ctx(overrides: Dictionary = {}) -> Dictionary:
	var ctx := {"elite": false, "boss": false, "act": 1, "objective": ObjectiveRule.ELIMINATE, "rounds": 6,
			"fielded": 4, "survived": 3, "archive_intact": false}
	ctx.merge(overrides, true)
	return ctx


func test_defs_valid() -> void:
	var orders := {}
	for a in db.achievements_sorted():
		assert_true(Achievements.EVENTS.has(a.condition), "%s: условие известно" % a.id)
		assert_false(orders.has(a.order), "%s: порядок уникален" % a.id)
		orders[a.order] = true
		if a.unlock_kind == &"":
			assert_between(a.points, 2, 10, "%s: награда очками 2–10" % a.id)
		else:
			assert_eq(a.points, 0, "%s: награда — одно открытие" % a.id)
			match a.unlock_kind:
				Achievements.CARD:
					assert_true(db.memories.has(a.unlock_id), a.id)
				Achievements.RELIC:
					assert_true(db.relics.has(a.unlock_id), a.id)
				Achievements.EVENT:
					assert_true(db.events.has(a.unlock_id), a.id)
				_:
					fail_test("%s: неизвестный вид открытия" % a.id)
	var total := 0
	var unlocks := 0
	for a in db.achievements.values():
		total += a.points
		unlocks += 1 if a.unlock_kind != &"" else 0
	assert_eq(total, 62, "сумма очков по спецификации")
	assert_eq(unlocks, 6)


func test_reward_given_once() -> void:
	var p := ProfileState.new()
	var run := _run()
	var got := _check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx({"boss": true}))
	assert_eq(got, [Achievements.FIRST_CHAPTER] as Array[StringName])
	assert_eq(p.points, 3)
	assert_true(p.has_achievement(Achievements.FIRST_CHAPTER))
	assert_eq(p.achievements[Achievements.FIRST_CHAPTER], Achievements.today())
	assert_true(_check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx({"boss": true})).is_empty(), "второй раз — ничего")
	assert_eq(p.points, 3)


func test_event_filter() -> void:
	var p := ProfileState.new()
	# Условие боя не проверяется на конце забега.
	assert_false(_check(p, _run(), Achievements.Event.RUN_END, _battle_ctx({"boss": true})).has(Achievements.FIRST_CHAPTER))


func test_battle_conditions() -> void:
	var cases := [
		[Achievements.FIRST_CHAPTER, _battle_ctx({"boss": true}), _battle_ctx({"boss": true, "act": 2})],
		[Achievements.NO_LOSSES, _battle_ctx({"elite": true, "survived": 4}), _battle_ctx({"elite": true, "survived": 3})],
		[Achievements.LIGHTNING, _battle_ctx({"rounds": 3}), _battle_ctx({"rounds": 3, "objective": ObjectiveRule.SURVIVE})],
		[Achievements.ON_THE_EDGE, _battle_ctx({"fielded": 3, "survived": 1}), _battle_ctx({"fielded": 2, "survived": 1})],
		[Achievements.ARCHIVE_INTACT, _battle_ctx({"objective": ObjectiveRule.PROTECT, "archive_intact": true}),
				_battle_ctx({"objective": ObjectiveRule.PROTECT, "archive_intact": false})],
	]
	for c: Array in cases:
		var yes := ProfileState.new()
		assert_true(_check(yes, _run(), Achievements.Event.BATTLE_WON, c[1]).has(c[0]), "%s: выполнено" % c[0])
		var no := ProfileState.new()
		assert_false(_check(no, _run(), Achievements.Event.BATTLE_WON, c[2]).has(c[0]), "%s: не выполнено" % c[0])


func test_four_wars() -> void:
	var p := ProfileState.new()
	var run := _run()
	run.objectives_won.assign([ObjectiveRule.SURVIVE, ObjectiveRule.HOLD, ObjectiveRule.PROTECT])
	assert_false(_check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx()).has(Achievements.FOUR_WARS))
	run.objectives_won.append(ObjectiveRule.ASSASSINATE)
	assert_true(_check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx()).has(Achievements.FOUR_WARS))


func test_run_end_conditions() -> void:
	var p := ProfileState.new()
	var run := _run(Difficulty.HARD, 5)
	while run.codex.cards.size() > 6:
		run.codex.remove_at(0)
	run.cards_lost = 1
	run.resources[RunState.INK] = 15
	var got := _check(p, run, Achievements.Event.RUN_END, {"won": true})
	for id in [Achievements.DROWNED_VICTORY, Achievements.HARD_HAND, Achievements.CLEAN_SLATE, Achievements.NOTHING_FORGOTTEN,
			Achievements.MISER, Achievements.FIRST_STEP, Achievements.TESTED]:
		assert_true(got.has(id), "%s получено" % id)
	assert_false(got.has(Achievements.ARCHIVE_KEEPER), "ступень 10 — не на ступени 5")
	assert_true(p.is_unlocked(Achievements.unlock_key(Achievements.RELIC, &"synod_seal")), "«Испытанный» открывает Печать Синода")
	assert_true(p.is_unlocked(Achievements.unlock_key(Achievements.EVENT, &"forgotten_shelf")))


func test_loss_gives_only_loss_safe() -> void:
	var p := ProfileState.new()
	var run := _run(Difficulty.HARD, 10)
	run.resources[RunState.AETHER] = 20
	var got := _check(p, run, Achievements.Event.RUN_END, {"won": false})
	assert_eq(got, [Achievements.MISER] as Array[StringName], "без победы — только «Скупец»")


func test_every_school() -> void:
	var p := ProfileState.new()
	for s in [&"ash_archive", &"tide_order", &"machine_synod"]:
		p.school_stats[s] = {"runs": 1, "wins": 1, "best": 16}
	assert_false(_check(p, _run(), Achievements.Event.RUN_END, {"won": true}).has(Achievements.EVERY_SCHOOL))
	p.school_stats[&"garden_of_faces"] = {"runs": 2, "wins": 1, "best": 16}
	assert_true(_check(p, _run(), Achievements.Event.RUN_END, {"won": true}).has(Achievements.EVERY_SCHOOL))


func test_run_counters() -> void:
	var p := ProfileState.new()
	var run := _run()
	run.shop_buys = 4
	assert_true(_check(p, run, Achievements.Event.PURCHASE).has(Achievements.REGULAR_CUSTOMER))
	run.relics.assign([&"salt_crown", &"memory_pearl", &"warden_shell"])
	assert_true(_check(p, run, Achievements.Event.RELIC).has(Achievements.COLLECTOR))
	assert_true(p.is_unlocked(Achievements.unlock_key(Achievements.RELIC, &"rift_shard")))
	for t in 7:
		run.node_types.append(t)
	assert_true(_check(p, run, Achievements.Event.NODE).has(Achievements.FULL_CHRONICLE))
	run.reworks.assign([&"spell", &"upgrade", &"fuse", &"sacrifice"])
	assert_true(_check(p, run, Achievements.Event.REWORK).has(Achievements.MEMORY_ALCHEMIST))
	assert_true(p.is_unlocked(Achievements.unlock_key(Achievements.CARD, &"deep_eels")))


func test_rework_tracked_by_codex_ops() -> void:
	var run := _run()
	var i := run.codex.unit_indices(db)[0]
	CodexOps.apply(db, run, i, CodexOps.Form.UPGRADE)
	i = run.codex.unit_indices(db)[0]
	CodexOps.apply(db, run, i, CodexOps.Form.SPELL)
	i = run.codex.unit_indices(db)[0]
	CodexOps.apply(db, run, i, CodexOps.Form.UPGRADE)
	assert_eq(run.reworks, [&"upgrade", &"spell"] as Array[StringName], "способ считается один раз")


func test_node_types_tracked() -> void:
	var run := _run()
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	MapActions.complete(run)
	assert_eq(run.node_types, [MapState.NodeType.BATTLE] as Array[int])


func test_daily_three() -> void:
	var p := ProfileState.new()
	p.daily_count = 3
	assert_true(_check(p, _run(), Achievements.Event.DAILY).has(Achievements.DAILY_THREE))


func test_repeat_daily_gives_nothing() -> void:
	var p := ProfileState.new()
	var run := DailyRun.create(db, p, "2026-10-05")
	run.daily_ranked = false
	assert_true(_check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx({"boss": true})).is_empty())
	run.daily_ranked = true
	assert_false(_check(p, run, Achievements.Event.BATTLE_WON, _battle_ctx({"boss": true})).is_empty())


func test_unlocks_gate_content() -> void:
	var p := ProfileState.new()
	var school := db.school(DefsDB.DEFAULT_SCHOOL)
	assert_false(MetaRewards.card_pool(db, p, school, 1).has(&"ash_keepers"))
	assert_false(MetaRewards.card_pool(db, p, school, 2).has(&"deep_eels"))
	assert_false(MetaRewards.event_pool(db, p).has(&"voice_from_ink"))
	var run := _run(Difficulty.NORMAL, 0, p)
	assert_false(RelicOps.available(db, run).has(&"rift_shard"))
	for a in db.achievements.values():
		if a.unlock_kind != &"":
			Achievements.grant(db, p, a.id)
	assert_true(MetaRewards.card_pool(db, p, school, 1).has(&"ash_keepers"))
	assert_true(MetaRewards.card_pool(db, p, school, 2).has(&"deep_eels"))
	assert_true(MetaRewards.event_pool(db, p).has(&"voice_from_ink"))
	assert_true(MetaRewards.event_pool(db, p).has(&"forgotten_shelf"))
	run = _run(Difficulty.NORMAL, 0, p)
	assert_true(RelicOps.available(db, run).has(&"rift_shard"))
	assert_true(RelicOps.available(db, run).has(&"synod_seal"))


func test_new_relics() -> void:
	var run := RunState.create(db, 31)
	run.resources[RunState.PARCHMENT] = 5
	RelicOps.take(db, run, &"synod_seal")
	assert_eq(run.resources[RunState.PARCHMENT], 2, "Печать: −3 Пергамента")
	run.codex.cards[0].durability = 1
	run.codex.cards[1].durability = 2
	RelicOps.after_victory(db, run)
	assert_eq(run.codex.cards[0].durability, 2, "самая потрёпанная карта +1")
	RelicOps.take(db, run, &"rift_shard")
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	var plain := RunState.create(db, 31)
	MapActions.travel(plain, plain.map.next_of(MapState.START)[0])
	var s := BattleSetup.for_run(db, run, run.codex.unit_indices(db))
	var s0 := BattleSetup.for_run(db, plain, plain.codex.unit_indices(db))
	var u := s.alive(UnitState.Side.PLAYER)[0]
	var u0 := s0.alive(UnitState.Side.PLAYER)[0]
	assert_eq(u.initiative, u0.initiative + 1, "Осколок: +1 инициатива")
	assert_eq(u.defense, maxi(0, u0.defense - 1), "Осколок: −1 защита")


func test_battle_context() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 0))
	var b := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 2))
	var c := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 4))
	var ill := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 6))
	TestHelpers.add(s, UnitState.Side.ENEMY, Vector2i(10, 0))
	a.card_index = 0
	b.card_index = 1
	c.card_index = 2
	ill.illusion = true
	b.count = 0
	c.count = 0
	s.round_number = 2
	var enc := EncounterDef.new()
	enc.elite = true
	var ctx := Achievements.battle_context(s, enc, 1)
	assert_eq(ctx["fielded"], 3, "иллюзия не считается")
	assert_eq(ctx["survived"], 1)
	assert_eq(ctx["rounds"], 2)
	assert_true(ctx["elite"])
	assert_false(ctx["archive_intact"], "без Архива — не цел")


func test_retro_grant() -> void:
	var p := ProfileState.new()
	p.wins = 2
	p.best_layer = 16
	p.trials[&"ash_archive"] = 6
	p.school_stats[&"ash_archive"] = {"runs": 5, "wins": 2, "best": 16,
			"best_codex": {"codex": ["a", "b", "c", "d", "e"], "difficulty": "hard", "trial": 5, "lost": 3, "date": "2026-10-01"}}
	p.chronicle.append({"outcome": "lost", "relics": ["salt_crown", "memory_pearl", "tide_compass"], "codex": [], "lost": 0})
	p.needs_retro = true
	var got := Achievements.grant_retro(db, p)
	for id in [Achievements.FIRST_CHAPTER, Achievements.DROWNED_VICTORY, Achievements.HARD_HAND, Achievements.CLEAN_SLATE,
			Achievements.COLLECTOR, Achievements.FIRST_STEP, Achievements.TESTED]:
		assert_true(got.has(id), "%s — по статистике" % id)
	for id in [Achievements.EVERY_SCHOOL, Achievements.NOTHING_FORGOTTEN, Achievements.ARCHIVE_KEEPER, Achievements.LIGHTNING]:
		assert_false(got.has(id), "%s — не выдаётся" % id)
	assert_false(p.needs_retro)
	assert_eq(p.points, 3 + 5 + 5 + 3, "очки наград: Первая глава, Затонувшая победа, Тяжёлая рука, Первая ступень")
