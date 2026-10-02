extends GutTest

var s: BattleState
var slow: UnitState
var fast: UnitState
var mid_p: UnitState
var mid_e: UnitState


func before_each() -> void:
	s = TestHelpers.empty_battle()
	slow = TestHelpers.add(s, 0, Vector2i(0, 0), 5, {"initiative": 3})
	fast = TestHelpers.add(s, 1, Vector2i(10, 0), 5, {"initiative": 9})
	mid_p = TestHelpers.add(s, 0, Vector2i(0, 2), 5, {"initiative": 6})
	mid_e = TestHelpers.add(s, 1, Vector2i(10, 2), 5, {"initiative": 6})


func test_order_by_initiative_player_wins_ties() -> void:
	BattleResolver.begin(s)
	assert_eq(s.active_uid, fast.uid)
	assert_eq(s.queue, [mid_p.uid, mid_e.uid, slow.uid] as Array[int])


func test_wait_moves_to_end_in_reverse_order() -> void:
	BattleResolver.begin(s)
	BattleResolver.apply(s, BattleAction.wait())  # fast
	assert_eq(s.active_uid, mid_p.uid)
	BattleResolver.apply(s, BattleAction.wait())  # mid_p
	BattleResolver.apply(s, BattleAction.defend())  # mid_e
	BattleResolver.apply(s, BattleAction.defend())  # slow
	# Фаза ожидания: сначала меньшая инициатива.
	assert_eq(s.active_uid, mid_p.uid)
	assert_false(BattleResolver.validate(s, BattleAction.wait()), "нельзя ждать дважды")
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.active_uid, fast.uid)
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.round_number, 2)
	assert_eq(s.active_uid, fast.uid)
	assert_true(BattleResolver.validate(s, BattleAction.wait()), "в новом раунде можно ждать")


func test_dead_units_skipped() -> void:
	BattleResolver.begin(s)
	mid_p.count = 0
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.active_uid, mid_e.uid)


func test_defend_lasts_until_own_turn() -> void:
	BattleResolver.begin(s)
	BattleResolver.apply(s, BattleAction.defend())
	assert_true(fast.defending)
	for i in 2:
		BattleResolver.apply(s, BattleAction.defend())
	assert_true(fast.defending, "бонус держится до своего хода")
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.active_uid, fast.uid)
	assert_false(fast.defending)


func test_round_limit_loses() -> void:
	s.max_rounds = 2
	BattleResolver.begin(s)
	for i in 8:
		BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_LOST)
	assert_eq(s.active_uid, -1)
