extends GutTest
## Зоны угрозы (SPEC_SPRINT5 2).


func test_melee_zone_is_move_plus_neighbors() -> void:
	var s := TestHelpers.empty_battle()
	var e := TestHelpers.add(s, 1, Vector2i(5, 4), 5, {"speed": 2})
	var z := ThreatMap.zone(s, e)
	assert_false(z.shoots)
	assert_true(z.move.has(Vector2i(3, 4)), "дойдёт на 2 клетки")
	assert_false(z.move.has(Vector2i(2, 4)))
	assert_true(z.melee.has(Vector2i(2, 4)), "ударит соседа клетки, куда дойдёт")
	assert_false(z.melee.has(Vector2i(1, 4)))


func test_attackers_and_threatened() -> void:
	var s := TestHelpers.empty_battle()
	var mine := TestHelpers.add(s, 0, Vector2i(1, 4), 10)
	var far := TestHelpers.add(s, 0, Vector2i(1, 0), 10)
	var e := TestHelpers.add(s, 1, Vector2i(5, 4), 5, {"speed": 3})
	var zones := ThreatMap.zones(s, UnitState.Side.ENEMY)
	assert_eq(ThreatMap.attackers_of(s, zones, mine), [e.uid] as Array[int])
	assert_true(ThreatMap.attackers_of(s, zones, far).is_empty(), "дальний отряд вне досягаемости")


func test_shooter_reaches_everything_unless_blocked() -> void:
	var s := TestHelpers.empty_battle()
	var mine := TestHelpers.add(s, 0, Vector2i(0, 0), 10)
	var archer := TestHelpers.add(s, 1, Vector2i(10, 8), 5, {"is_ranged": true, "shots": 3, "speed": 1})
	var zones := ThreatMap.zones(s, UnitState.Side.ENEMY)
	assert_eq(ThreatMap.attackers_of(s, zones, mine).size(), 1)
	assert_true(ThreatMap.attackers_of(s, zones, mine, true).is_empty(), "без стрелков — не под ударом")
	assert_eq(ThreatMap.heat(zones).get(mine.hex, 0), 0, "стрелки не входят в общую зону")
	var shots := ThreatMap.shot_targets(s, archer)
	assert_true(shots[mine.uid], "дальний выстрел — урон снижен")
	TestHelpers.add(s, 0, Vector2i(9, 8), 1)
	zones = ThreatMap.zones(s, UnitState.Side.ENEMY)
	assert_true(ThreatMap.attackers_of(s, zones, mine).is_empty(), "стрелок связан боем")
	assert_true(ThreatMap.shot_targets(s, archer).is_empty())


func test_walls_and_water_limit_zone() -> void:
	var s := TestHelpers.empty_battle()
	var e := TestHelpers.add(s, 1, Vector2i(5, 4), 5, {"speed": 4})
	s.temp_obstacles[Vector2i(4, 4)] = 2
	s.water[Vector2i(6, 4)] = 2
	var z := ThreatMap.zone(s, e)
	assert_false(z.melee.has(Vector2i(4, 4)), "стену не атакуют")
	assert_true(z.move.has(Vector2i(6, 4)))


func test_immobile_turret_threatens_only_neighbors_without_shots() -> void:
	var s := TestHelpers.empty_battle()
	var t := TestHelpers.add(s, 1, Vector2i(5, 4), 5, {"speed": 0})
	var z := ThreatMap.zone(s, t)
	assert_true(z.move.is_empty())
	assert_eq(z.melee.size(), 6)


func test_heat_and_damage_sum() -> void:
	var s := TestHelpers.empty_battle()
	var mine := TestHelpers.add(s, 0, Vector2i(4, 4), 10)
	TestHelpers.add(s, 1, Vector2i(6, 4), 5, {"speed": 2})
	TestHelpers.add(s, 1, Vector2i(6, 5), 5, {"speed": 2})
	var zones := ThreatMap.zones(s, UnitState.Side.ENEMY)
	var heat := ThreatMap.heat(zones)
	assert_eq(heat.get(mine.hex, 0), 2, "клетку достают оба врага")
	var d := ThreatMap.damage_to(s, zones, mine)
	assert_gt(d.y, 0)
	assert_true(d.x <= d.y)
	assert_eq(d.z, DamageCalc.kills(mine, d.y))
