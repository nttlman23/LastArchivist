extends GutTest


func _types(events: Array[BattleEvent]) -> Array[StringName]:
	var result: Array[StringName] = []
	for e in events:
		result.append(e.type)
	return result


func _find(events: Array[BattleEvent], type: StringName) -> Array[BattleEvent]:
	return events.filter(func(e: BattleEvent) -> bool: return e.type == type)


func test_move() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 4))
	TestHelpers.add(s, 1, Vector2i(10, 4))
	TestHelpers.activate(s, u)
	var events := BattleResolver.apply(s, BattleAction.move(Vector2i(3, 4)))
	assert_eq(u.hex, Vector2i(3, 4))
	assert_eq(events[0].type, BattleEvent.MOVED)


func test_move_out_of_range_rejected() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"speed": 2})
	TestHelpers.add(s, 1, Vector2i(10, 4))
	TestHelpers.activate(s, u)
	assert_false(BattleResolver.validate(s, BattleAction.move(Vector2i(5, 4))))
	assert_eq(BattleResolver.apply(s, BattleAction.move(Vector2i(5, 4))).size(), 0)
	assert_eq(u.hex, Vector2i(0, 4))


func test_melee_with_retaliation_once_per_round() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(2, 4), 10)
	var b := TestHelpers.add(s, 0, Vector2i(4, 2), 10)
	var e := TestHelpers.add(s, 1, Vector2i(4, 4), 20)
	TestHelpers.activate(s, a)
	var events := BattleResolver.apply(s, BattleAction.melee(Vector2i(3, 4), e.uid))
	var attacks := _find(events, BattleEvent.ATTACKED)
	assert_eq(attacks.size(), 2)
	assert_true(attacks[1].data["retaliation"])
	# 10 * 2 урона = 20 -> 2 гибнут; ответ 18 * 2 = 36 -> 3 гибнут
	assert_eq(e.count, 18)
	assert_eq(a.count, 7)
	assert_true(e.retaliated)

	TestHelpers.activate(s, b)
	events = BattleResolver.apply(s, BattleAction.melee(Vector2i(4, 3), e.uid))
	assert_eq(_find(events, BattleEvent.ATTACKED).size(), 1, "второй удар без ответа")


func test_melee_from_unreachable_hex_rejected() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"speed": 2})
	var e := TestHelpers.add(s, 1, Vector2i(6, 4))
	TestHelpers.activate(s, a)
	assert_false(BattleResolver.validate(s, BattleAction.melee(Vector2i(5, 4), e.uid)))


func test_melee_from_non_adjacent_rejected() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4))
	var e := TestHelpers.add(s, 1, Vector2i(4, 4))
	TestHelpers.activate(s, a)
	assert_false(BattleResolver.validate(s, BattleAction.melee(Vector2i(2, 4), e.uid)))


func test_cannot_attack_ally() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4))
	var ally := TestHelpers.add(s, 0, Vector2i(1, 4))
	TestHelpers.add(s, 1, Vector2i(10, 4))
	TestHelpers.activate(s, a)
	assert_false(BattleResolver.validate(s, BattleAction.melee(a.hex, ally.uid)))


func test_shoot_no_retaliation_uses_ammo() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"is_ranged": true, "shots": 2})
	var e := TestHelpers.add(s, 1, Vector2i(4, 4), 20)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, a)
	var events := BattleResolver.apply(s, BattleAction.shoot(e.uid))
	assert_eq(_find(events, BattleEvent.ATTACKED).size(), 1)
	assert_eq(a.shots_left, 1)
	assert_eq(a.count, 10)
	assert_false(e.retaliated)


func test_shoot_blocked_when_enemy_adjacent() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"is_ranged": true, "shots": 2})
	var near := TestHelpers.add(s, 1, Vector2i(1, 4))
	var far := TestHelpers.add(s, 1, Vector2i(8, 4))
	TestHelpers.activate(s, a)
	assert_false(BattleResolver.validate(s, BattleAction.shoot(far.uid)))
	assert_true(BattleResolver.validate(s, BattleAction.melee(a.hex, near.uid)))


func test_shoot_without_ammo_rejected() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"is_ranged": true, "shots": 0})
	var e := TestHelpers.add(s, 1, Vector2i(8, 4))
	TestHelpers.activate(s, a)
	assert_false(BattleResolver.validate(s, BattleAction.shoot(e.uid)))


func test_kill_last_enemy_wins() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 50)
	var e := TestHelpers.add(s, 1, Vector2i(1, 4), 1)
	TestHelpers.activate(s, a)
	var events := BattleResolver.apply(s, BattleAction.melee(a.hex, e.uid))
	assert_has(_types(events), BattleEvent.DIED)
	assert_eq(events[-1].type, BattleEvent.BATTLE_ENDED)
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	assert_false(BattleResolver.validate(s, BattleAction.defend()), "после конца боя действий нет")


func test_dead_attacker_from_retaliation_loses() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 1)
	var e := TestHelpers.add(s, 1, Vector2i(1, 4), 50)
	TestHelpers.activate(s, a)
	BattleResolver.apply(s, BattleAction.melee(a.hex, e.uid))
	assert_false(a.is_alive())
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_LOST)


func test_create_from_encounter() -> void:
	var db := DefsDB.load_default()
	var run := RunState.create(db, 7)
	var selected: Array[int] = [0, 2]
	var s := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 99)
	assert_eq(s.alive(0).size(), 2)
	assert_eq(s.alive(1).size(), 2)
	assert_eq(s.alive(0)[0].hex, Vector2i(0, 0))
	assert_eq(s.alive(0)[1].card_index, 2)
	assert_eq(s.alive(1)[0].hex, Vector2i(10, 0))
	assert_eq(s.obstacles.size(), 2)


func test_determinism() -> void:
	var first := _simulate(1234)
	var second := _simulate(1234)
	assert_eq(JSON.stringify(first.to_dict()), JSON.stringify(second.to_dict()))
	assert_ne(first.outcome, BattleState.Outcome.NONE)


## Полный бой AI против AI на реальных данных.
func _simulate(seed_value: int) -> BattleState:
	var db := DefsDB.load_default()
	var run := RunState.create(db, seed_value)
	var selected: Array[int] = [0, 1, 2, 3]
	var s := BattleState.create(db, db.encounter(&"crypt_2"), run.codex, selected, seed_value)
	BattleResolver.begin(s)
	var guard := 0
	while s.outcome == BattleState.Outcome.NONE and guard < 1000:
		BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
		guard += 1
	return s
