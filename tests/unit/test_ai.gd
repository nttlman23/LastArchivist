extends GutTest


func test_shooter_shoots_and_prefers_ranged_target() -> void:
	var s := TestHelpers.empty_battle()
	var archer := TestHelpers.add(s, 1, Vector2i(10, 4), 10, {"is_ranged": true, "shots": 5})
	TestHelpers.add(s, 0, Vector2i(2, 2), 10)
	var enemy_archer := TestHelpers.add(s, 0, Vector2i(2, 6), 10, {"is_ranged": true, "shots": 5})
	TestHelpers.activate(s, archer)
	var a := AiController.choose_action(s, archer.uid)
	assert_eq(a.type, BattleAction.Type.SHOOT)
	assert_eq(a.target_uid, enemy_archer.uid)


func test_prefers_killing_blow() -> void:
	var s := TestHelpers.empty_battle()
	var ghoul := TestHelpers.add(s, 1, Vector2i(5, 4), 10)
	var big := TestHelpers.add(s, 0, Vector2i(4, 4), 50)
	var weak := TestHelpers.add(s, 0, Vector2i(6, 4), 1)
	TestHelpers.activate(s, ghoul)
	var a := AiController.choose_action(s, ghoul.uid)
	assert_eq(a.type, BattleAction.Type.MELEE)
	assert_eq(a.target_uid, weak.uid)
	assert_true(BattleResolver.validate(s, a))
	assert_ne(a.target_uid, big.uid)


func test_moves_toward_enemy_when_out_of_reach() -> void:
	var s := TestHelpers.empty_battle()
	var ghoul := TestHelpers.add(s, 1, Vector2i(10, 4), 10, {"speed": 3})
	TestHelpers.add(s, 0, Vector2i(0, 4), 10)
	TestHelpers.activate(s, ghoul)
	var a := AiController.choose_action(s, ghoul.uid)
	assert_eq(a.type, BattleAction.Type.MOVE)
	assert_eq(HexGrid.distance(a.dest, Vector2i(0, 4)), 7)
	assert_true(BattleResolver.validate(s, a))


func test_walks_around_obstacles() -> void:
	var s := TestHelpers.empty_battle()
	var ghoul := TestHelpers.add(s, 1, Vector2i(6, 4), 10, {"speed": 3})
	TestHelpers.add(s, 0, Vector2i(0, 4), 10)
	for row in range(1, 8):
		s.obstacles[Vector2i(5, row)] = true
	TestHelpers.activate(s, ghoul)
	var a := AiController.choose_action(s, ghoul.uid)
	assert_eq(a.type, BattleAction.Type.MOVE)
	assert_true(BattleResolver.validate(s, a))


func test_blocked_shooter_melees() -> void:
	var s := TestHelpers.empty_battle()
	var archer := TestHelpers.add(s, 1, Vector2i(5, 4), 10, {"is_ranged": true, "shots": 5})
	var adjacent := TestHelpers.add(s, 0, Vector2i(4, 4), 10)
	TestHelpers.add(s, 0, Vector2i(0, 0), 10)
	TestHelpers.activate(s, archer)
	var a := AiController.choose_action(s, archer.uid)
	assert_eq(a.type, BattleAction.Type.MELEE)
	assert_eq(a.target_uid, adjacent.uid)
	assert_eq(a.dest, archer.hex)


func test_flyer_approaches() -> void:
	var s := TestHelpers.empty_battle()
	var wyrm := TestHelpers.add(s, 1, Vector2i(10, 4), 2, {"speed": 4, "is_flying": true})
	TestHelpers.add(s, 0, Vector2i(0, 4), 10)
	TestHelpers.activate(s, wyrm)
	var a := AiController.choose_action(s, wyrm.uid)
	assert_eq(a.type, BattleAction.Type.MOVE)
	assert_eq(HexGrid.distance(a.dest, Vector2i(0, 4)), 6)
