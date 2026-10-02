extends GutTest
## Приказы и заклинания Архивариуса (SPEC_SPRINT2 3).

var s: BattleState
var a: UnitState
var b: UnitState
var e: UnitState


func before_each() -> void:
	s = TestHelpers.empty_battle()
	a = TestHelpers.add(s, 0, Vector2i(0, 4), 10, {"initiative": 9, "speed": 2})
	b = TestHelpers.add(s, 0, Vector2i(1, 4), 10, {"initiative": 5})
	e = TestHelpers.add(s, 1, Vector2i(10, 4), 20, {"initiative": 7})
	s.hero_orders = [HeroActions.ADVANCE, HeroActions.CLOSE_RANKS]
	BattleResolver.begin(s)
	assert_eq(s.active_uid, a.uid)


func _give_spell(id: StringName, charges: int, power: int) -> int:
	s.hero_spells.append({"spell_id": id, "charges": charges, "power": power})
	return s.hero_spells.size() - 1


func test_one_action_per_round_and_turn_continues() -> void:
	var order := BattleAction.order(HeroActions.ADVANCE, a.uid)
	assert_true(BattleResolver.validate(s, order))
	var events := BattleResolver.apply(s, order)
	assert_eq(s.active_uid, a.uid, "действие героя не заканчивает ход отряда")
	assert_false(events.any(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.TURN_STARTED))
	assert_false(BattleResolver.validate(s, BattleAction.order(HeroActions.CLOSE_RANKS, b.uid)), "одно действие за раунд")
	# Доходим до следующего раунда — действие снова доступно.
	BattleResolver.apply(s, BattleAction.defend())
	BattleResolver.apply(s, BattleAction.defend())
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.round_number, 2)
	assert_true(s.can_hero_act())


func test_not_on_enemy_turn() -> void:
	BattleResolver.apply(s, BattleAction.defend())
	assert_eq(s.active_uid, e.uid)
	assert_false(BattleResolver.validate(s, BattleAction.order(HeroActions.CLOSE_RANKS, a.uid)))


func test_advance_adds_speed_until_turn_end() -> void:
	# (3, 3) — 4 шага в обход стоящего рядом b.
	assert_false(Pathfinding.reachable(s, a).has(Vector2i(3, 3)))
	BattleResolver.apply(s, BattleAction.order(HeroActions.ADVANCE, a.uid))
	assert_eq(a.move_speed(), 4)
	assert_true(Pathfinding.reachable(s, a).has(Vector2i(3, 3)))
	BattleResolver.apply(s, BattleAction.move(Vector2i(3, 3)))
	assert_eq(a.move_speed(), 2, "рывок заканчивается вместе с ходом")


func test_close_ranks_defends_neighbors() -> void:
	BattleResolver.apply(s, BattleAction.order(HeroActions.CLOSE_RANKS, a.uid))
	assert_true(a.defending)
	assert_true(b.defending)
	assert_false(e.defending)


func test_royal_requires_king_and_acted_unit() -> void:
	assert_false(BattleResolver.validate(s, BattleAction.order(HeroActions.ROYAL, a.uid)), "нет Короля — нет приказа")
	s.hero_orders.append(HeroActions.ROYAL)
	assert_false(BattleResolver.validate(s, BattleAction.order(HeroActions.ROYAL, b.uid)), "b ещё не ходил")
	BattleResolver.apply(s, BattleAction.defend())  # a
	BattleResolver.apply(s, BattleAction.defend())  # e
	assert_eq(s.active_uid, b.uid)
	BattleResolver.apply(s, BattleAction.order(HeroActions.ROYAL, a.uid))
	BattleResolver.apply(s, BattleAction.defend())  # b
	assert_eq(s.active_uid, a.uid, "a ходит ещё раз сразу после текущего")
	assert_eq(s.round_number, 1)


func test_spell_damage_ignores_defense_and_spends_charge() -> void:
	var slot := _give_spell(HeroActions.ASH_RECORD, 2, 60)
	e.defending = true
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.ASH_RECORD, e.uid))
	assert_eq(e.total_hp(), 140)
	assert_eq(s.hero_spells[slot]["charges"], 1)
	assert_eq(s.spell_charges(), [1] as Array[int])


func test_spell_without_charges_rejected() -> void:
	var slot := _give_spell(HeroActions.ASH_RECORD, 0, 60)
	assert_false(BattleResolver.validate(s, BattleAction.spell(slot, HeroActions.ASH_RECORD, e.uid)))


func test_spell_wrong_side_rejected() -> void:
	var dmg := _give_spell(HeroActions.ASH_RECORD, 1, 60)
	var heal := _give_spell(HeroActions.HUNGER, 1, 50)
	assert_false(BattleResolver.validate(s, BattleAction.spell(dmg, HeroActions.ASH_RECORD, a.uid)))
	assert_false(BattleResolver.validate(s, BattleAction.spell(heal, HeroActions.HUNGER, e.uid)))


func test_spell_can_win_battle() -> void:
	var slot := _give_spell(HeroActions.ASH_RECORD, 1, 1000)
	var events := BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.ASH_RECORD, e.uid))
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	assert_eq(events[-1].type, BattleEvent.BATTLE_ENDED)


func test_hunger_revives() -> void:
	var slot := _give_spell(HeroActions.HUNGER, 1, 50)
	b.take_damage(60)
	assert_eq(b.count, 4)
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.HUNGER, b.uid))
	assert_eq(b.count, 9)


func test_rust_armor() -> void:
	var slot := _give_spell(HeroActions.RUST_ARMOR, 1, 4)
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.RUST_ARMOR, b.uid))
	assert_eq(b.defense, 9)
	assert_true(b.has_status(UnitState.STATUS_RUST_ARMOR))


func test_chain_spell_hits_allies() -> void:
	var slot := _give_spell(HeroActions.CHAIN_SPELL, 1, 50)
	var near := TestHelpers.add(s, 0, Vector2i(9, 4), 10)
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.CHAIN_SPELL, e.uid))
	assert_eq(e.total_hp(), 150)
	assert_eq(near.total_hp(), 75, "рикошет в своего: 25")


func test_salt_wall_two_hexes_expire() -> void:
	var slot := _give_spell(HeroActions.SALT_WALL, 1, 2)
	assert_false(BattleResolver.validate(s, BattleAction.spell(slot, HeroActions.SALT_WALL, -1, Vector2i(5, 4), Vector2i(7, 4))), "вторая клетка не соседняя")
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.SALT_WALL, -1, Vector2i(5, 4), Vector2i(5, 3)))
	assert_false(s.is_free(Vector2i(5, 4)))
	assert_false(s.is_free(Vector2i(5, 3)))
	TurnManager.start_round(s)
	TurnManager.start_round(s)
	assert_true(s.is_free(Vector2i(5, 4)))


func test_shard_rain_area() -> void:
	var slot := _give_spell(HeroActions.SHARD_RAIN, 1, 20)
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.SHARD_RAIN, -1, Vector2i(1, 4)))
	assert_eq(b.total_hp(), 80, "центр")
	assert_eq(a.total_hp(), 80, "сосед, свой")
	assert_eq(e.total_hp(), 200, "далеко")


func test_echo_spell_grants_another_action() -> void:
	var slot := _give_spell(HeroActions.ECHO_SPELL, 1, 1)
	BattleResolver.apply(s, BattleAction.spell(slot, HeroActions.ECHO_SPELL))
	assert_true(s.can_hero_act())
	BattleResolver.apply(s, BattleAction.order(HeroActions.CLOSE_RANKS, a.uid))
	assert_false(s.can_hero_act())


func test_options_match_validate() -> void:
	var slot := _give_spell(HeroActions.ASH_RECORD, 1, 60)
	var opts := HeroActions.options(s, HeroActions.ASH_RECORD, slot)
	assert_eq(opts.size(), 1)
	for o in HeroActions.options(s, HeroActions.CLOSE_RANKS, -1):
		assert_true(BattleResolver.validate(s, o))


func test_hero_ai_casts_lethal_spell() -> void:
	var slot := _give_spell(HeroActions.ASH_RECORD, 1, 1000)
	var action := HeroAi.choose(s)
	assert_not_null(action)
	assert_eq(action.slot, slot)
	assert_eq(action.target_uid, e.uid)
