extends GutTest
## Спринт 11 (этап B): экономика «меньше и дороже» — награды, лимит ремонта в лавке, подкрепление за Эфир.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func test_battle_rewards() -> void:
	var t1 := MapActions.battle_rewards(db.encounter(&"crypt_1"))
	assert_eq([t1[RunState.INK], t1[RunState.PARCHMENT], t1[RunState.AETHER]], [1, 2, 0])
	var elite := MapActions.battle_rewards(db.encounter(&"crypt_5"))
	assert_eq([elite[RunState.INK], elite[RunState.PARCHMENT], elite[RunState.AETHER]], [2, 4, 1])
	for e: EncounterDef in db.encounters.values():
		if e.boss or e.elite:
			continue
		var r := MapActions.battle_rewards(e)
		var expected := [1, 2, 0] if e.tier <= 1 else ([1, 2, 1] if e.tier == 2 else [1, 3, 1])
		assert_eq([r[RunState.INK], r[RunState.PARCHMENT], r[RunState.AETHER]], expected, String(e.id))


func test_repair_limit_per_shop_visit() -> void:
	var run := RunState.create(db, 1)
	run.resources[RunState.INK] = 10
	for c in run.codex.cards:
		c.durability = 1
	var visit := ShopOps.open(db, run, 0)
	for i in ShopOps.REPAIR_LIMIT:
		assert_true(ShopOps.repair(db, run, i, visit))
	assert_eq(ShopOps.repair_reason(db, run, 3, visit), "REASON_REPAIR_LIMIT")
	assert_false(ShopOps.repair(db, run, 3, visit))
	assert_true(ShopOps.repair(db, run, 3), "без визита (события) — без лимита")


func test_reinforcement() -> void:
	var run := RunState.create(db, 1)
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	var selected := run.codex.unit_indices(db)
	var plain := BattleSetup.for_run(db, run, selected)
	run.resources[RunState.AETHER] = 1
	assert_eq(ShopOps.reinforce_reason(run), "REASON_NO_AETHER")
	run.resources[RunState.AETHER] = 3
	assert_true(ShopOps.reinforce(run, selected[0]))
	assert_eq(run.resources[RunState.AETHER], 3 - ShopOps.REINFORCE_COST)
	var s := BattleSetup.for_run(db, run, selected)
	var base: int = plain.alive(UnitState.Side.PLAYER)[0].count
	var boosted: UnitState = s.alive(UnitState.Side.PLAYER)[0]
	assert_eq(boosted.count, base + maxi(1, roundi(base * ShopOps.REINFORCE_SHARE)))
	assert_eq(boosted.start_count, boosted.count)
	assert_eq(s.alive(UnitState.Side.PLAYER)[1].count, plain.alive(UnitState.Side.PLAYER)[1].count, "другие отряды без изменений")
	assert_eq(run.reinforce_card, -1, "подкрепление на один бой")
