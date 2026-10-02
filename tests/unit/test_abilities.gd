extends GutTest
## Способности отрядов (SPEC_SPRINT2 4).


func _types(events: Array[BattleEvent]) -> Array[StringName]:
	var result: Array[StringName] = []
	for e in events:
		result.append(e.type)
	return result


func _battle_with(ability: StringName, overrides: Dictionary = {}) -> Array:
	var s := TestHelpers.empty_battle()
	var o := overrides.duplicate()
	o["ability_id"] = ability
	var u := TestHelpers.add(s, 0, Vector2i(3, 4), 10, o)
	return [s, u]


func test_cooldown_and_ready() -> void:
	var b := _battle_with(Abilities.SHIELD_WALL)
	var s: BattleState = b[0]
	var u: UnitState = b[1]
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, u)
	assert_true(BattleResolver.validate(s, BattleAction.ability(Abilities.SHIELD_WALL)))
	BattleResolver.apply(s, BattleAction.ability(Abilities.SHIELD_WALL))
	assert_eq(u.ability_cd, 3)
	assert_false(u.ability_ready())
	for i in 3:
		TurnManager.start_round(s)
	assert_true(u.ability_ready(), "КД 3 — снова готова через 3 раунда")


func test_wrong_ability_id_rejected() -> void:
	var b := _battle_with(Abilities.SHIELD_WALL)
	var s: BattleState = b[0]
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, b[1])
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.MARK)))


func test_shield_wall_unlimited_retaliation() -> void:
	var b := _battle_with(Abilities.SHIELD_WALL)
	var s: BattleState = b[0]
	var guard: UnitState = b[1]
	var ally := TestHelpers.add(s, 0, Vector2i(2, 4))
	var e1 := TestHelpers.add(s, 1, Vector2i(5, 4), 5)
	var e2 := TestHelpers.add(s, 1, Vector2i(5, 3), 5)
	TestHelpers.activate(s, guard)
	var wall_events := BattleResolver.apply(s, BattleAction.ability(Abilities.SHIELD_WALL))
	assert_true(guard.defending)
	# Сосед ходит следующим, и его защита по правилам снимается в начале его хода — проверяем событие.
	var defended := wall_events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.DEFENDED).map(func(ev: BattleEvent) -> int: return ev.data["uid"])
	assert_has(defended, ally.uid, "сосед-союзник тоже в защите")
	for e in [e1, e2]:
		TestHelpers.activate(s, e)
		var events := BattleResolver.apply(s, BattleAction.melee(Vector2i(4, 4) if e == e1 else Vector2i(3, 3), guard.uid))
		var retaliations := events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.ATTACKED and ev.data["retaliation"])
		assert_eq(retaliations.size(), 1, "Страж отвечает каждому")


func test_mark_bonus_consumed() -> void:
	var b := _battle_with(Abilities.MARK, {"is_ranged": true, "shots": 5})
	var s: BattleState = b[0]
	var u: UnitState = b[1]
	var e := TestHelpers.add(s, 1, Vector2i(9, 4), 50)
	TestHelpers.activate(s, u)
	var plain := DamageCalc.damage_range(u, e, true)
	BattleResolver.apply(s, BattleAction.ability(Abilities.MARK, e.uid))
	assert_true(e.has_status(UnitState.STATUS_MARKED))
	assert_eq(DamageCalc.damage_range(u, e, true), Vector2i(floori(plain.x * 1.5), floori(plain.y * 1.5)))
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.MARK, e.uid)), "уже помечен")
	TestHelpers.activate(s, u)
	BattleResolver.apply(s, BattleAction.shoot(e.uid))
	assert_false(e.has_status(UnitState.STATUS_MARKED), "метка снята атакой")


func test_devour_heals_and_revives() -> void:
	var b := _battle_with(Abilities.DEVOUR, {"hp": 10})
	var s: BattleState = b[0]
	var ghoul: UnitState = b[1]
	ghoul.take_damage(30)  # 7 из 10
	var e := TestHelpers.add(s, 1, Vector2i(4, 4), 40)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, ghoul)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.DEVOUR, TestHelpers.add(s, 1, Vector2i(8, 8)).uid)), "только соседний враг")
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.DEVOUR, e.uid))
	assert_has(_types(events), BattleEvent.HEALED)
	# 7 гулей × 2 = 14 урона → лечение 7 ОЗ (до ответного удара).
	var healed: BattleEvent = events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.HEALED)[0]
	assert_eq(healed.data["amount"], 7)


func test_heal_capped_by_start_count() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 5)
	u.take_damage(15)
	assert_eq(u.count, 4)
	assert_eq(u.heal(1000), 15)
	assert_eq(u.count, 5)
	assert_eq(u.top_hp, 10)


func test_shard_volley_splash_hits_allies() -> void:
	var b := _battle_with(Abilities.SHARD_VOLLEY, {"is_ranged": true, "shots": 3})
	var s: BattleState = b[0]
	var archer: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(7, 4), 20)
	var enemy_near := TestHelpers.add(s, 1, Vector2i(8, 4), 20)
	var ally_near := TestHelpers.add(s, 0, Vector2i(6, 4), 20)
	TestHelpers.activate(s, archer)
	BattleResolver.apply(s, BattleAction.ability(Abilities.SHARD_VOLLEY, target.uid))
	assert_eq(archer.shots_left, 2)
	assert_lt(target.total_hp(), 200)
	assert_lt(enemy_near.total_hp(), 200)
	assert_lt(ally_near.total_hp(), 200, "осколки задевают своих")


func test_shard_volley_blocked_when_adjacent() -> void:
	var b := _battle_with(Abilities.SHARD_VOLLEY, {"is_ranged": true, "shots": 3})
	var s: BattleState = b[0]
	var archer: UnitState = b[1]
	TestHelpers.add(s, 1, Vector2i(4, 4))
	var far := TestHelpers.add(s, 1, Vector2i(9, 4))
	TestHelpers.activate(s, archer)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.SHARD_VOLLEY, far.uid)))


func test_chain_lightning_jumps_including_allies() -> void:
	var b := _battle_with(Abilities.CHAIN_LIGHTNING)
	var s: BattleState = b[0]
	var wyrm: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(6, 4), 20)
	var ally := TestHelpers.add(s, 0, Vector2i(7, 3), 20)
	var far_enemy := TestHelpers.add(s, 1, Vector2i(10, 8), 20)
	TestHelpers.activate(s, wyrm)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.CHAIN_LIGHTNING, far_enemy.uid)), "дальше 4 клеток")
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.CHAIN_LIGHTNING, target.uid))
	var hit := events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.ATTACKED).map(func(ev: BattleEvent) -> int: return ev.data["target"])
	assert_eq(hit, [target.uid, ally.uid], "первый прыжок — на ближайший стек, даже свой")
	assert_eq(far_enemy.total_hp(), 200)


func test_cover_wall_expires() -> void:
	var b := _battle_with(Abilities.COVER)
	var s: BattleState = b[0]
	var u: UnitState = b[1]
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, u)
	var hex := Vector2i(4, 4)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.COVER, -1, Vector2i(6, 4))), "только соседняя клетка")
	BattleResolver.apply(s, BattleAction.ability(Abilities.COVER, -1, hex))
	assert_false(s.is_free(hex))
	for i in 3:
		TurnManager.start_round(s)
	assert_true(s.is_free(hex), "стена держится 3 раунда")


func test_restore_requires_wounded_ally() -> void:
	var b := _battle_with(Abilities.RESTORE)
	var s: BattleState = b[0]
	var priest: UnitState = b[1]
	var ally := TestHelpers.add(s, 0, Vector2i(0, 0), 10)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	TestHelpers.activate(s, priest)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.RESTORE, ally.uid)), "здоровых не лечит")
	ally.take_damage(45)
	BattleResolver.apply(s, BattleAction.ability(Abilities.RESTORE, ally.uid))
	assert_eq(ally.total_hp(), 85)


func test_ram_pushes_target() -> void:
	var b := _battle_with(Abilities.RAM)
	var s: BattleState = b[0]
	var ram: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(6, 4), 30)
	TestHelpers.activate(s, ram)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.RAM, target.uid))
	assert_eq(ram.hex, Vector2i(5, 4))
	assert_eq(target.hex, Vector2i(7, 4))
	assert_has(_types(events), BattleEvent.PUSHED)
	var retaliations := events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.ATTACKED and ev.data["retaliation"])
	assert_eq(retaliations.size(), 0, "отброшенная цель не отвечает")


func test_ram_blocked_push_bonus_and_retaliation() -> void:
	var b := _battle_with(Abilities.RAM)
	var s: BattleState = b[0]
	var ram: UnitState = b[1]
	var target := TestHelpers.add(s, 1, Vector2i(6, 4), 30)
	s.obstacles[Vector2i(7, 4)] = true
	TestHelpers.activate(s, ram)
	var events := BattleResolver.apply(s, BattleAction.ability(Abilities.RAM, target.uid))
	assert_eq(target.hex, Vector2i(6, 4))
	var attacks := events.filter(func(ev: BattleEvent) -> bool: return ev.type == BattleEvent.ATTACKED)
	# 10 × 2 урона × 1.5 = 30
	assert_eq(attacks[0].data["damage"], 30)
	assert_true(attacks[1].data["retaliation"])


func test_ram_requires_straight_free_line() -> void:
	var b := _battle_with(Abilities.RAM)
	var s: BattleState = b[0]
	var ram: UnitState = b[1]
	var adjacent := TestHelpers.add(s, 1, Vector2i(4, 4))
	var off_line := TestHelpers.add(s, 1, Vector2i(6, 2))
	# (4, 6) — на прямой ЮВ через (3, 5).
	var blocked := TestHelpers.add(s, 1, Vector2i(4, 6))
	s.obstacles[Vector2i(3, 5)] = true
	TestHelpers.activate(s, ram)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.RAM, adjacent.uid)), "вплотную нельзя")
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.RAM, off_line.uid)), "не на прямой")
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.RAM, blocked.uid)), "путь перекрыт")


func test_echo_copies_last_ally_ability() -> void:
	var s := TestHelpers.empty_battle()
	var choir := TestHelpers.add(s, 0, Vector2i(3, 4), 5, {"ability_id": Abilities.ECHO})
	var priest := TestHelpers.add(s, 0, Vector2i(0, 0), 5, {"ability_id": Abilities.RESTORE})
	var wounded := TestHelpers.add(s, 0, Vector2i(0, 8), 10)
	TestHelpers.add(s, 1, Vector2i(10, 0))
	wounded.take_damage(80)
	TestHelpers.activate(s, choir)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.ECHO, wounded.uid)), "нечего повторять")
	TestHelpers.activate(s, priest)
	BattleResolver.apply(s, BattleAction.ability(Abilities.RESTORE, wounded.uid))
	TestHelpers.activate(s, choir)
	assert_eq(Abilities.effective(s, choir), Abilities.RESTORE)
	BattleResolver.apply(s, BattleAction.ability(Abilities.ECHO, wounded.uid))
	assert_eq(wounded.total_hp(), 80)
	assert_eq(choir.ability_cd, 2)


func test_options_match_validate() -> void:
	var b := _battle_with(Abilities.CHAIN_LIGHTNING)
	var s: BattleState = b[0]
	var u: UnitState = b[1]
	TestHelpers.add(s, 1, Vector2i(5, 4))
	TestHelpers.add(s, 1, Vector2i(10, 8))
	TestHelpers.activate(s, u)
	var opts := Abilities.options(s, u)
	assert_eq(opts.size(), 1, "только враг в радиусе")
	for a in opts:
		assert_true(BattleResolver.validate(s, a))


func test_ai_uses_restore_on_wounded() -> void:
	var s := TestHelpers.empty_battle()
	var priest := TestHelpers.add(s, 1, Vector2i(10, 4), 6, {"ability_id": Abilities.RESTORE})
	var wounded := TestHelpers.add(s, 1, Vector2i(10, 0), 10)
	wounded.take_damage(60)
	TestHelpers.add(s, 0, Vector2i(0, 4), 10)
	TestHelpers.activate(s, priest)
	var a := AiController.choose_action(s, priest.uid)
	assert_eq(a.type, BattleAction.Type.ABILITY)
	assert_eq(a.target_uid, wounded.uid)


func test_ai_rams_when_line_is_clear() -> void:
	var s := TestHelpers.empty_battle()
	var ram := TestHelpers.add(s, 1, Vector2i(8, 4), 3, {"ability_id": Abilities.RAM, "speed": 1, "dmg_min": 6, "dmg_max": 6})
	var target := TestHelpers.add(s, 0, Vector2i(5, 4), 5, {"is_ranged": true, "shots": 5})
	TestHelpers.activate(s, ram)
	var a := AiController.choose_action(s, ram.uid)
	assert_eq(a.type, BattleAction.Type.ABILITY)
	assert_eq(a.target_uid, target.uid)


func test_ai_avoids_volley_hurting_allies() -> void:
	var s := TestHelpers.empty_battle()
	var archer := TestHelpers.add(s, 1, Vector2i(10, 4), 10, {"ability_id": Abilities.SHARD_VOLLEY, "is_ranged": true, "shots": 5})
	var target := TestHelpers.add(s, 0, Vector2i(5, 4), 30)
	# Вокруг цели — только союзники стрелка, и слабые: залп их добьёт.
	TestHelpers.add(s, 1, Vector2i(4, 4), 1)
	TestHelpers.add(s, 1, Vector2i(6, 4), 1)
	TestHelpers.activate(s, archer)
	var a := AiController.choose_action(s, archer.uid)
	assert_eq(a.type, BattleAction.Type.SHOOT, "обычный выстрел вместо залпа по своим")
	assert_eq(a.target_uid, target.uid)
