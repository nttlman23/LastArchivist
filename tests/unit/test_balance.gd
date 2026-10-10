extends GutTest
## Спринт 9, этап B: правила баланса «Тяжело» во втором акте (SPEC_SPRINT9 13).

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _enc(act: int, tier: int, elite: bool = false, boss: bool = false) -> EncounterDef:
	var e := EncounterDef.new()
	e.act = act
	e.tier = tier
	e.elite = elite
	e.boss = boss
	return e


func test_hard_act2_count_factor() -> void:
	var base: float = Difficulty.ENEMY_COUNT[Difficulty.HARD]
	assert_eq(Difficulty.count_factor(Difficulty.HARD, _enc(2, 5)), Difficulty.HARD_ACT2_COUNT, "уровень 5")
	assert_eq(Difficulty.count_factor(Difficulty.HARD, _enc(2, 5, true)), Difficulty.HARD_ACT2_COUNT, "элита второго акта")
	assert_eq(Difficulty.count_factor(Difficulty.HARD, _enc(2, 4)), base, "уровень 4 — как обычно")
	assert_eq(Difficulty.count_factor(Difficulty.HARD, _enc(1, 2, true)), base, "элита первого акта — как обычно")
	assert_eq(Difficulty.count_factor(Difficulty.HARD, _enc(2, 5, false, true)), base, "босс — без надбавки")
	assert_eq(Difficulty.count_factor(Difficulty.NORMAL, _enc(2, 5)), 1.0, "только на «Тяжело»")
	assert_eq(Difficulty.enemy_count(Difficulty.HARD, 10, _enc(2, 5)), roundi(10 * Difficulty.HARD_ACT2_COUNT))
	assert_eq(Difficulty.enemy_count(Difficulty.HARD, 10), roundi(10 * base), "без встречи — общий множитель")


func test_real_encounters_use_factor() -> void:
	var enc := db.encounter(db.encounter_pool(5, false, 2)[0])
	var s := BattleState.create(db, enc, RunState.create(db, 1).codex, [0, 1], 1, HeroState.new(), &"", Difficulty.HARD)
	var expect := 0
	for i in enc.counts.size():
		expect += Difficulty.enemy_count(Difficulty.HARD, enc.counts[i], enc)
	var got := 0
	for u in s.alive(UnitState.Side.ENEMY):
		got += u.count
	assert_eq(got, expect, "в бою — численность с надбавкой")


func _boss_state(difficulty: StringName, trial: int = 0) -> BattleState:
	var run := RunState.create(db, 5, DefsDB.DEFAULT_SCHOOL, null, difficulty, trial)
	MapActions.begin_act(db, run, 2)
	for n in run.map.nodes:
		if n.type == MapState.NodeType.RIFT:
			run.map.current = n.id
			run.pending_node = n.id
	return BattleSetup.for_run(db, run, run.codex.unit_indices(db))


func test_hard_boss_phase_threshold() -> void:
	assert_eq(_boss_state(Difficulty.NORMAL).boss_phase_share, BossRule.PHASE_SHARE)
	assert_eq(_boss_state(Difficulty.HARD).boss_phase_share, Difficulty.HARD_PHASE_SHARE, "на «Тяжело» — раньше")
	assert_eq(_boss_state(Difficulty.HARD, 10).boss_phase_share, Trials.PHASE_SHARE, "Испытание 10 строже «Тяжело»")
