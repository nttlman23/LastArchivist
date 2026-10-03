extends GutTest
## Спринт 8, этап A: Испытания 1–10 — открытие, правила ступеней, очки, лучший Кодекс.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _run(trial: int, seed_value: int = 11, difficulty: StringName = Difficulty.HARD) -> RunState:
	return RunState.create(db, seed_value, DefsDB.DEFAULT_SCHOOL, null, difficulty, trial)


## Встать на остров нужного типа (без пути по мостам — только для сборки боя).
func _at(run: RunState, type: MapState.NodeType) -> MapState.MapNode:
	for n in run.map.nodes:
		if n.type == type:
			run.map.current = n.id
			run.pending_node = n.id
			return n
	return null


func _battle(run: RunState) -> BattleState:
	return BattleSetup.for_run(db, run, run.codex.unit_indices(db))


func test_only_on_hard() -> void:
	assert_eq(_run(5, 11, Difficulty.NORMAL).trial, 0, "на «Нормально» Испытаний нет")
	assert_eq(_run(5).trial, 5)
	assert_eq(_run(99).trial, Trials.MAX)


func test_unlock_by_wins_per_school() -> void:
	var p := ProfileState.new()
	var run := _run(0)
	MetaRewards.finish_run(p, run, false)
	assert_eq(p.trial_open(run.school_id), 0, "поражение не открывает")
	MetaRewards.finish_run(p, _run(0, 11, Difficulty.NORMAL), true)
	assert_eq(p.trial_open(run.school_id), 0, "победа не на «Тяжело» не открывает")
	MetaRewards.finish_run(p, run, true)
	assert_eq(p.trial_open(run.school_id), 1)
	MetaRewards.finish_run(p, _run(1), true)
	assert_eq(p.trial_open(run.school_id), 2)
	MetaRewards.finish_run(p, _run(0), true)
	assert_eq(p.trial_open(run.school_id), 2, "победа ниже открытой ступени ничего не меняет")
	assert_eq(p.trial_open(&"tide_order"), 0, "у другой школы — свои ступени")
	MetaRewards.finish_run(p, _run(10), true)
	assert_eq(p.trial_open(run.school_id), Trials.MAX)


func test_points_multiplier() -> void:
	var a := _run(0)
	var b := _run(5)
	for r in [a, b]:
		r.map.current = r.map.layer_nodes(6)[0].id
		r.elites_won = 2
	assert_eq(MetaRewards.points_for_run(b, false), roundi(MetaRewards.points_for_run(a, false) * 1.5))


func test_start_resources_and_prices() -> void:
	var a := _run(0)
	var b := _run(Trials.PRICES)
	for id in RunState.RESOURCE_IDS:
		assert_eq(b.resources[id], maxi(0, a.resources[id] - 1))
	assert_eq(ShopOps.repair_cost(b), ShopOps.repair_cost(a) + 1)
	assert_eq(ShopOps.adjust_price(b, ShopOps.CARD_PRICE), ShopOps.CARD_PRICE + 1)
	assert_eq(ShopOps.adjust_price(_run(Trials.PRICES - 1), ShopOps.CARD_PRICE), ShopOps.CARD_PRICE)


func test_rewards_and_durability() -> void:
	var run := _run(Trials.DURABILITY)
	assert_eq(run.roll_rewards(db, false).size(), RunState.REWARD_CHOICES_TRIAL)
	assert_eq(run.roll_rewards(db, true).size(), RunState.REWARD_CHOICES, "элита — как обычно")
	var id: StringName = run.card_pool[0]
	assert_eq(run.gain_card(db, id).durability, maxi(1, db.memory(id).max_durability - 1))
	assert_eq(_run(Trials.DURABILITY - 1).gain_card(db, id).durability, db.memory(id).max_durability)


func test_elite_and_initiative() -> void:
	var plain := _run(0)
	var hard := _run(Trials.INITIATIVE)
	_at(plain, MapState.NodeType.ELITE)
	_at(hard, MapState.NodeType.ELITE)
	var a := _battle(plain).alive(UnitState.Side.ENEMY)
	var b := _battle(hard).alive(UnitState.Side.ENEMY)
	for i in a.size():
		assert_eq(b[i].count, ceili(a[i].count * Trials.ELITE_COUNT_SHARE))
		assert_eq(b[i].initiative, a[i].initiative + 1)


func test_commanders_everywhere() -> void:
	for trial in [Trials.COMMANDERS - 1, Trials.COMMANDERS]:
		var run := _run(trial)
		run.map.current = run.map.layer_nodes(1)[0].id
		run.pending_node = run.map.current
		var n := run.pending()
		if not n.is_battle() or n.type != MapState.NodeType.BATTLE:
			for m in run.map.layer_nodes(1):
				if m.type == MapState.NodeType.BATTLE:
					run.map.current = m.id
					run.pending_node = m.id
		var enc := db.encounter(run.pending().content)
		var cmd := Difficulty.commander_for(db, run, enc)
		if trial >= Trials.COMMANDERS:
			assert_ne(cmd, &"", "Испытание 5: командир с первого слоя")
		else:
			assert_eq(cmd, &"", "без Испытания 5 на первом слое командира нет")


func test_boss_hp_and_phase() -> void:
	var plain := _run(0)
	var hard := _run(Trials.PHASE)
	for r in [plain, hard]:
		var rift: MapState.MapNode = (r as RunState).map.layer_nodes(MapState.RIFT_LAYER)[0]
		r.map.current = rift.id
		r.pending_node = rift.id
	var a := _battle(plain)
	var b := _battle(hard)
	var ea := a.alive(UnitState.Side.ENEMY)
	var eb := b.alive(UnitState.Side.ENEMY)
	assert_eq(eb[0].hp, ea[0].hp + ceili(ea[0].hp * Trials.BOSS_HP_SHARE))
	assert_eq(b.boss_phase_share, Trials.PHASE_SHARE)
	assert_eq(a.boss_phase_share, BossRule.PHASE_SHARE)
	assert_eq(BattleState.from_dict(b.to_dict()).boss_phase_share, Trials.PHASE_SHARE, "порог фазы сохраняется")


func test_phase_threshold() -> void:
	var codex := CodexState.new()
	for id in [&"salt_legion", &"ghoul_pack"]:
		codex.add(db, id)
	var s := BattleState.create(db, db.encounter(&"abyss"), codex, [0, 1], 3)
	s.boss_phase_share = Trials.PHASE_SHARE
	BattleResolver.begin(s)
	var boss := s.get_unit(s.boss_uid)
	var events: Array[BattleEvent] = []
	# 60% ОЗ: без Испытания ещё первая фаза, с Испытанием 10 — уже вторая.
	BattleResolver.deal_damage(boss, roundi(boss.total_hp() * 0.4), &"test", events)
	BattleResolver.check_end(s, events)
	assert_eq(s.boss_phase, 2)


func test_best_codex_prefers_trial() -> void:
	var low := {"difficulty": "hard", "trial": 2, "lost": 0}
	var high := {"difficulty": "hard", "trial": 5, "lost": 4}
	assert_true(ProfileState.is_better_codex(high, low))
	assert_false(ProfileState.is_better_codex(low, high))


func test_describe_lists_rules() -> void:
	assert_eq(Trials.rules(4), [1, 2, 3, 4] as Array[int])
	for i in range(1, Trials.MAX + 1):
		assert_ne(TranslationServer.translate(Trials.rule_key(i)), Trials.rule_key(i), "текст правила %d" % i)


## Регрессия: цепная молния героя убила свой активный стек — ход переходит дальше, бой не зависает.
func test_hero_spell_killing_active_passes_turn() -> void:
	var s := TestHelpers.empty_battle()
	var enemy := TestHelpers.add(s, 1, Vector2i(6, 4), 30)
	var mine := TestHelpers.add(s, 0, Vector2i(5, 4), 1, {"hp": 5})
	TestHelpers.add(s, 0, Vector2i(0, 8), 10)
	s.hero_spells = [{"spell_id": HeroActions.CHAIN_SPELL, "charges": 1, "power": 100}]
	TestHelpers.activate(s, mine)
	BattleResolver.apply(s, BattleAction.spell(0, HeroActions.CHAIN_SPELL, enemy.uid))
	assert_false(mine.is_alive(), "молния перескочила на свой стек")
	assert_ne(s.active_uid, mine.uid, "ход ушёл от погибшего стека")
	assert_true(s.active_unit() != null and s.active_unit().is_alive())
