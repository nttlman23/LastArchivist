extends GutTest
## Этап B: новые способности, вязкая вода, неподвижность, иллюзии, кража, пассивки школ.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _battle_with(ability: StringName, overrides: Dictionary = {}) -> Array:
	var s := TestHelpers.empty_battle()
	var o := overrides.duplicate()
	o["ability_id"] = ability
	var u := TestHelpers.add(s, 0, Vector2i(3, 4), 10, o)
	return [s, u]


func _find(events: Array[BattleEvent], type: StringName) -> Array:
	return events.filter(func(e: BattleEvent) -> bool: return e.type == type)


# --- Орден Приливов -------------------------------------------------------------

func test_undertow_pulls_and_strikes_without_retaliation() -> void:
	var b := _battle_with(Abilities.UNDERTOW)
	var s: BattleState = b[0]
	var warden: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(6, 4), 20, {"is_ranged": true, "shots": 3})
	TestHelpers.activate(s, warden)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.UNDERTOW, target.uid))
	assert_eq(target.hex, Vector2i(4, 4), "притянут вплотную")
	var attacks := _find(events, BattleEvent.ATTACKED)
	assert_eq(attacks.size(), 1, "без ответного удара")


func test_undertow_needs_clear_line() -> void:
	var b := _battle_with(Abilities.UNDERTOW)
	var s: BattleState = b[0]
	var warden: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(6, 4), 5)
	s.obstacles[Vector2i(5, 4)] = true
	TestHelpers.activate(s, warden)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.UNDERTOW, target.uid)))


func test_flood_water_stops_movement_and_expires() -> void:
	var b := _battle_with(Abilities.FLOOD)
	var s: BattleState = b[0]
	var jelly: UnitState = b[1]
	var walker := TestHelpers.add(s, 1, Vector2i(9, 4), 5, {"speed": 6})
	TestHelpers.activate(s, jelly)
	BattleResolver.apply(s, BattleAction.ability(Abilities.FLOOD, -1, Vector2i(6, 4)))
	assert_true(s.water.has(Vector2i(6, 4)))
	assert_true(s.water.has(Vector2i(7, 4)))
	var reach := Pathfinding.reachable(s, walker)
	assert_true(reach.has(Vector2i(7, 4)), "в воду войти можно")
	assert_false(reach.has(Vector2i(5, 4)), "сквозь воду дальше не пройти")
	TurnManager.start_round(s)
	TurnManager.start_round(s)
	assert_true(s.water.is_empty(), "вода держится 2 раунда")


func test_flyers_ignore_water() -> void:
	var s := TestHelpers.empty_battle()
	var flyer := TestHelpers.add(s, 0, Vector2i(0, 4), 1, {"speed": 4, "is_flying": true})
	s.water[Vector2i(1, 4)] = 2
	assert_true(Pathfinding.reachable(s, flyer).has(Vector2i(3, 4)))


func test_tide_current_shortens_cooldowns() -> void:
	var b := _battle_with(Abilities.FLOOD)
	var s: BattleState = b[0]
	var jelly: UnitState = b[1]
	TestHelpers.add(s, 1, Vector2i(10, 0))
	s.passive_id = SchoolPassives.TIDE_CURRENT
	TestHelpers.activate(s, jelly)
	BattleResolver.apply(s, BattleAction.ability(Abilities.FLOOD, -1, Vector2i(5, 4)))
	assert_eq(jelly.ability_cd, 2, "КД 3 − 1")


# --- Машинный Синод -------------------------------------------------------------

func test_immobile_turret_cannot_move() -> void:
	var s := TestHelpers.empty_battle()
	var turret := TestHelpers.add(s, 0, Vector2i(0, 4), 5, {"speed": 0, "is_ranged": true, "shots": 5})
	TestHelpers.add(s, 1, Vector2i(10, 4), 5)
	TestHelpers.activate(s, turret)
	assert_eq(Pathfinding.reachable(s, turret).size(), 0)
	var a := AiController.choose_action(s, turret.uid)
	assert_ne(a.type, BattleAction.Type.MOVE, "AI не двигает неподвижный стек")


func test_overclock_two_shots() -> void:
	var b := _battle_with(Abilities.OVERCLOCK, {"is_ranged": true, "shots": 5, "speed": 0})
	var s: BattleState = b[0]
	var turret: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(7, 4), 30)
	TestHelpers.activate(s, turret)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.OVERCLOCK, target.uid))
	assert_eq(_find(events, BattleEvent.ATTACKED).size(), 2)
	assert_eq(turret.shots_left, 3)


func test_overclock_retargets_after_kill() -> void:
	var b := _battle_with(Abilities.OVERCLOCK, {"is_ranged": true, "shots": 5})
	var s: BattleState = b[0]
	var turret: UnitState = b[1]
	var weak := TestHelpers.add(s, 1, Vector2i(7, 4), 1)
	var other := TestHelpers.add(s, 1, Vector2i(9, 8), 30)
	TestHelpers.activate(s, turret)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.OVERCLOCK, weak.uid))
	var targets := _find(events, BattleEvent.ATTACKED).map(func(e: BattleEvent) -> int: return e.data["target"])
	assert_eq(targets, [weak.uid, other.uid])


func test_tinker_heals_construct_or_builds_barrier() -> void:
	var b := _battle_with(Abilities.TINKER, {"construct": true})
	var s: BattleState = b[0]
	var tinker: UnitState = b[1]
	var turret := TestHelpers.add(s, 0, Vector2i(0, 0), 10, {"construct": true})
	var flesh := TestHelpers.add(s, 0, Vector2i(0, 8), 10)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	turret.take_damage(50)
	flesh.take_damage(50)
	TestHelpers.activate(s, tinker)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.TINKER, flesh.uid)), "только конструкты")
	BattleResolver.apply(s, BattleAction.ability(Abilities.TINKER, turret.uid))
	assert_eq(turret.total_hp(), 90)
	TestHelpers.activate(s, tinker)
	tinker.ability_cd = 0
	BattleResolver.apply(s, BattleAction.ability(Abilities.TINKER, -1, Vector2i(4, 4)))
	assert_eq(s.temp_obstacles.size(), 2, "барьер из двух клеток")


func test_synod_repair_heals_constructs_without_revive() -> void:
	var s := TestHelpers.empty_battle()
	s.passive_id = SchoolPassives.SYNOD_REPAIR
	var turret := TestHelpers.add(s, 0, Vector2i(0, 0), 10, {"construct": true})
	var flesh := TestHelpers.add(s, 0, Vector2i(0, 8), 10)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	turret.take_damage(25)  # 7.5 существ: 8 шт., верхнее 5/10
	flesh.take_damage(5)
	TurnManager.start_round(s)
	assert_eq(turret.count, 8, "без воскрешения")
	assert_eq(turret.top_hp, 10, "верхнее починено")
	assert_eq(flesh.top_hp, 5, "живых не чинит")


# --- Сад Лиц -----------------------------------------------------------------------

func test_reflect_summons_illusion_that_takes_double_damage() -> void:
	var b := _battle_with(Abilities.REFLECT)
	var s: BattleState = b[0]
	var double: UnitState = b[1]
	var guard := TestHelpers.add(s, 0, Vector2i(0, 4), 12, {"hp": 25})
	var e := TestHelpers.add(s, 1, Vector2i(10, 4), 10)
	TestHelpers.activate(s, double)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.REFLECT, guard.uid))
	assert_eq(_find(events, BattleEvent.SUMMONED).size(), 1)
	var illusion: UnitState = s.units[-1]
	assert_true(illusion.illusion)
	assert_eq(illusion.count, 6)
	assert_eq(illusion.card_index, -1)
	assert_eq(DamageCalc.damage_range(e, illusion, false).x, DamageCalc.damage_range(e, guard, false).x * 2, "двойной урон")
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.REFLECT, illusion.uid)), "иллюзию не копировать")


func test_illusion_takes_double_fixed_damage() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 10)
	u.illusion = true
	var events: Array[BattleEvent] = []
	BattleResolver.deal_damage(u, 20, &"test", events)
	assert_eq(u.total_hp(), 60)


func test_garden_masks_at_battle_start() -> void:
	var s := TestHelpers.empty_battle()
	s.passive_id = SchoolPassives.GARDEN_MASKS
	TestHelpers.add(s, 0, Vector2i(0, 4), 10)
	TestHelpers.add(s, 1, Vector2i(10, 4), 10)
	var events := BattleResolver.begin(s)
	assert_eq(_find(events, BattleEvent.SUMMONED).size(), 1)
	assert_eq(s.alive(UnitState.Side.PLAYER).size(), 2)
	assert_has(s.queue + [s.active_uid], s.units[-1].uid, "иллюзия ходит уже в первом раунде")


func test_steal_uses_enemy_ability() -> void:
	var b := _battle_with(Abilities.STEAL)
	var s: BattleState = b[0]
	var thief: UnitState = b[1]
	var ram := TestHelpers.add(s, 1, Vector2i(6, 4), 3, {"ability_id": Abilities.RAM})
	var plain := TestHelpers.add(s, 1, Vector2i(10, 0), 3)
	TestHelpers.activate(s, thief)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.STEAL, plain.uid)), "без способности красть нечего")
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.STEAL, ram.uid))
	var used := _find(events, BattleEvent.ABILITY_USED).map(func(e: BattleEvent) -> StringName: return e.data["ability"])
	assert_has(used, Abilities.RAM, "применён украденный «Таран»")
	assert_eq(thief.borrowed_ability, &"", "заимствование снято")
	assert_eq(thief.ability_cd, 3)


func test_cannot_steal_boss_ability() -> void:
	var b := _battle_with(Abilities.STEAL)
	var s: BattleState = b[0]
	var thief: UnitState = b[1]
	var warden := TestHelpers.add(s, 1, Vector2i(6, 4), 1, {"ability_id": Abilities.RIFT_TEAR})
	TestHelpers.activate(s, thief)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.STEAL, warden.uid)))


# --- Школы целиком -----------------------------------------------------------------

func test_new_schools_open_and_start() -> void:
	var p := ProfileState.new()
	for s in db.schools_sorted():
		assert_true(s.implemented, String(s.id))
		assert_eq(s.starting_codex.size(), 4)
		for id in s.starting_codex:
			assert_true(db.memories.has(id), "%s: %s" % [s.id, id])
		if s.unlock_cost > 0:
			assert_false(MetaRewards.is_school_open(p, s))
			p.points = 100
			assert_true(MetaRewards.buy(db, p, {"id": MetaRewards.school_unlock_id(s.id), "kind": MetaRewards.Kind.SCHOOL, "target": s.id, "cost": s.unlock_cost}))
			assert_true(MetaRewards.is_school_open(p, s))


func test_school_creatures_in_pool_only_when_open() -> void:
	var p := ProfileState.new()
	var ash := db.school(DefsDB.DEFAULT_SCHOOL)
	assert_does_not_have(MetaRewards.card_pool(db, p, ash), &"tide_wardens")
	p.unlocked.append(MetaRewards.school_unlock_id(&"tide_order"))
	assert_has(MetaRewards.card_pool(db, p, ash), &"tide_wardens")


func test_every_school_runs_a_battle() -> void:
	for school in db.schools_sorted():
		var run := RunState.create(db, 5, school.id)
		var selected: Array[int] = run.codex.unit_indices(db)
		var st := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 5, run.hero, school.passive_id)
		BattleResolver.begin(st)
		var guard := 0
		while st.outcome == BattleState.Outcome.NONE and guard < 600:
			BattleResolver.apply(st, AiController.choose_action(st, st.active_uid))
			guard += 1
		assert_ne(st.outcome, BattleState.Outcome.NONE, "бой школы %s завершился" % school.id)


func test_new_ability_options_validate() -> void:
	var s := TestHelpers.empty_battle()
	for id in [Abilities.UNDERTOW, Abilities.FLOOD, Abilities.OVERCLOCK, Abilities.TINKER, Abilities.REFLECT, Abilities.STEAL]:
		var u := TestHelpers.add(s, 0, Vector2i(3, 4), 5, {"ability_id": id, "is_ranged": id == Abilities.OVERCLOCK, "shots": 4, "construct": true})
		TestHelpers.add(s, 0, Vector2i(1, 1), 5, {"construct": true})
		TestHelpers.add(s, 1, Vector2i(6, 4), 5, {"ability_id": Abilities.MARK})
		TestHelpers.activate(s, u)
		for a in Abilities.options(s, u):
			assert_true(BattleResolver.validate(s, a), "%s: %s" % [id, a])
		s = TestHelpers.empty_battle()
