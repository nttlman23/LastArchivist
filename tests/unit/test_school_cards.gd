extends GutTest
## Спринт 11 (этап B): свои карты у школ — награды только своей школы и общие, чужая карта —
## не больше одной в лавке; Колокольные водолазы и «Откачка».

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


## Профиль, где открыты все школы и все карты.
func _open_profile() -> ProfileState:
	var p := ProfileState.new()
	for u in MetaRewards.all_unlocks(db):
		p.unlocked.append(u["id"])
	for a in db.achievements.values():
		Achievements.grant(db, p, a.id)
	return p


func test_every_memory_has_at_most_one_school() -> void:
	for id in db.memories:
		var owners := db.schools.values().filter(func(s: SchoolDef) -> bool: return s.own_memories.has(id))
		assert_true(owners.size() <= 1, String(id))
	for s: SchoolDef in db.schools.values():
		for id in s.own_memories:
			assert_true(db.memories.has(id), "%s: карта %s существует" % [s.id, id])
		for id in s.favored_memories:
			assert_true(s.own_memories.has(id), "%s: любимая карта %s — своя" % [s.id, id])


func test_rewards_only_own_and_neutral() -> void:
	var p := _open_profile()
	for s: SchoolDef in db.schools_sorted():
		if not s.implemented:
			continue
		for act in [1, 2]:
			var run := RunState.create(db, 9, s.id, p)
			if act == 2:
				MapActions.begin_act(db, run, 2, p)
			for i in 40:
				for id in run.roll_rewards(db, i % 3 == 0):
					var owner := db.memory_school(id)
					assert_true(owner == &"" or owner == s.id, "%s, акт %d: %s — карта школы %s" % [s.id, act, id, owner])


func test_shop_has_at_most_one_foreign_card() -> void:
	var p := _open_profile()
	var with_foreign := 0
	for seed_value in 30:
		var run := RunState.create(db, seed_value, &"tide_order", p)
		var v := ShopOps.open(db, run, seed_value)
		var foreign := v.offer.filter(func(id: StringName) -> bool: return not run.school_allows(db, id))
		assert_true(foreign.size() <= 1, "сид %d" % seed_value)
		assert_eq(v.offer.size(), ShopOps.offer_size(run))
		with_foreign += foreign.size()
	assert_between(with_foreign, 5, 25, "чужая карта бывает, но не всегда")


func test_diving_bells_card() -> void:
	var mem := db.memory(&"diving_bells")
	assert_eq(db.memory_school(&"diving_bells"), &"machine_synod")
	assert_eq(mem.act, 2)
	var def := db.unit(mem.unit_id)
	assert_true(def.construct, "конструкт — чинится «Ремонтом» Синода")
	assert_eq(def.ability_id, Abilities.PUMP)


func _pump_battle() -> Array:
	var s := TestHelpers.empty_battle()
	var bell := s.add_unit(db.unit(&"diving_bell"), UnitState.Side.PLAYER, 5, Vector2i(3, 3))
	TestHelpers.add(s, UnitState.Side.ENEMY, Vector2i(10, 0))
	TestHelpers.activate(s, bell)
	return [s, bell]


func test_pump_drains_water_and_currents_then_restores() -> void:
	var b := _pump_battle()
	var s: BattleState = b[0]
	var bell: UnitState = b[1]
	var near := Vector2i(4, 3)
	var far := Vector2i(8, 3)
	s.water[near] = BattleState.WATER_PERMANENT
	s.water[far] = BattleState.WATER_PERMANENT
	s.currents[near] = 2
	assert_true(Abilities.validate(s, bell, BattleAction.ability(Abilities.PUMP)))
	BattleResolver.apply(s, BattleAction.ability(Abilities.PUMP))
	assert_false(s.water.has(near), "вода рядом осушена")
	assert_false(s.currents.has(near), "течение рядом остановлено")
	assert_true(s.water.has(far), "дальняя вода осталась")
	var copy := BattleState.from_dict(s.to_dict())
	assert_eq(copy.drained.size(), s.drained.size(), "осушенное переживает копию боя")
	for i in Abilities.PUMP_ROUNDS:
		TurnManager.start_round(s)
	assert_eq(s.water.get(near, 0), BattleState.WATER_PERMANENT, "вода вернулась")
	assert_eq(s.currents.get(near, -1), 2, "течение вернулось")
	assert_true(s.drained.is_empty())


func test_pump_repairs_constructs_and_needs_a_reason() -> void:
	var b := _pump_battle()
	var s: BattleState = b[0]
	var bell: UnitState = b[1]
	assert_false(Abilities.validate(s, bell, BattleAction.ability(Abilities.PUMP)), "ни воды, ни ремонта — нельзя")
	var turret := s.add_unit(db.unit(&"clock_turret"), UnitState.Side.PLAYER, 3, Vector2i(3, 2))
	turret.top_hp = 5
	assert_true(Abilities.validate(s, bell, BattleAction.ability(Abilities.PUMP)))
	var before := turret.total_hp()
	BattleResolver.apply(s, BattleAction.ability(Abilities.PUMP))
	assert_eq(turret.total_hp(), before + Abilities.PUMP_HEAL)
