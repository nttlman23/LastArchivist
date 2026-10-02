extends GutTest


func test_reachable_respects_speed() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 4), 1, {"speed": 2})
	var r := Pathfinding.reachable(s, u)
	assert_false(r.has(u.hex))
	for h in r:
		assert_true(r[h] <= 2)
	assert_true(r.has(Vector2i(2, 4)))
	assert_false(r.has(Vector2i(3, 4)))


func test_obstacles_and_units_block() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 4), 1, {"speed": 3})
	s.obstacles[Vector2i(1, 4)] = true
	TestHelpers.add(s, 1, Vector2i(0, 3), 1)
	var r := Pathfinding.reachable(s, u)
	assert_false(r.has(Vector2i(1, 4)))
	assert_false(r.has(Vector2i(0, 3)))
	# Обход снизу: (0,5) -> (1,5) -> (2,4)
	assert_eq(r.get(Vector2i(2, 4), -1), 3)


func test_walled_in_unit_cannot_move() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 1)
	s.obstacles[Vector2i(1, 0)] = true
	s.obstacles[Vector2i(0, 1)] = true
	assert_eq(Pathfinding.reachable(s, u).size(), 0)


func test_flyer_ignores_obstacles() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 1, {"speed": 3, "is_flying": true})
	s.obstacles[Vector2i(1, 0)] = true
	s.obstacles[Vector2i(0, 1)] = true
	var r := Pathfinding.reachable(s, u)
	assert_true(r.has(Vector2i(2, 0)))
	assert_false(r.has(Vector2i(1, 0)))


func test_path_ends_at_dest() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 4), 1, {"speed": 5})
	var p := Pathfinding.path(s, u, Vector2i(4, 4))
	assert_eq(p[0], Vector2i(0, 4))
	assert_eq(p[-1], Vector2i(4, 4))
	assert_eq(p.size(), 5)
