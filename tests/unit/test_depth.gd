extends GutTest
## Этап B Спринта 5: сложность, вражеский командир, цели боя.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _codex() -> CodexState:
	var c := CodexState.new()
	for id in [&"salt_legion", &"salt_legion", &"ghoul_pack", &"ash_chroniclers"]:
		c.add(db, id)
	return c


func _battle(enc_id: StringName, difficulty: StringName = Difficulty.NORMAL, commander: StringName = &"") -> BattleState:
	return BattleState.create(db, db.encounter(enc_id), _codex(), [0, 1, 2, 3], 7, null, &"", difficulty, commander)


## Доигрывает раунды, пока бой идёт: все стеки защищаются.
func _skip_rounds(s: BattleState, rounds: int) -> void:
	var target := s.round_number + rounds
	while s.outcome == BattleState.Outcome.NONE and s.round_number < target:
		BattleResolver.apply(s, BattleAction.defend())


# --- Сложность -------------------------------------------------------------------

func test_enemy_counts_scale() -> void:
	var enc := db.encounter(&"t1_priests")
	var easy := _battle(&"t1_priests", Difficulty.EASY)
	var hard := _battle(&"t1_priests", Difficulty.HARD)
	var e_easy := easy.alive(UnitState.Side.ENEMY)
	var e_hard := hard.alive(UnitState.Side.ENEMY)
	assert_eq(e_easy[0].count, roundi(enc.counts[0] * Difficulty.ENEMY_COUNT[Difficulty.EASY]))
	assert_eq(e_hard[0].count, roundi(enc.counts[0] * Difficulty.ENEMY_COUNT[Difficulty.HARD]))
	assert_eq(Difficulty.enemy_count(Difficulty.EASY, 1), 1, "не меньше одного")


func test_start_resources_and_points() -> void:
	var easy := RunState.create(db, 3, DefsDB.DEFAULT_SCHOOL, null, Difficulty.EASY)
	assert_eq(easy.resources[RunState.PARCHMENT], 5, "3 × 1,5 с округлением вверх")
	assert_eq(Difficulty.points(Difficulty.EASY, 10, false), 5)
	assert_eq(Difficulty.points(Difficulty.HARD, 10, false), 15)
	assert_eq(Difficulty.points(Difficulty.HARD, 10, true), 18)


func test_difficulty_saved_and_in_chronicle() -> void:
	var run := RunState.create(db, 3, DefsDB.DEFAULT_SCHOOL, null, Difficulty.HARD)
	var loaded := RunState.from_dict(run.to_dict())
	assert_eq(loaded.difficulty, Difficulty.HARD)
	assert_null(RunState.from_dict({"version": 4}), "старые сохранения не читаются")
	var profile := ProfileState.new()
	MetaRewards.finish_run(profile, run, false, db)
	assert_eq(profile.chronicle[0]["difficulty"], "hard")


func test_commander_assignment() -> void:
	var elite := db.encounter(&"elite_storm")
	var plain := db.encounter(&"t2_storm")
	assert_false(Difficulty.has_commander(Difficulty.EASY, elite, 5))
	assert_true(Difficulty.has_commander(Difficulty.NORMAL, elite, 1))
	assert_false(Difficulty.has_commander(Difficulty.NORMAL, plain, 5))
	assert_false(Difficulty.has_commander(Difficulty.HARD, plain, 2))
	assert_true(Difficulty.has_commander(Difficulty.HARD, plain, 3))
	assert_true(Difficulty.has_commander(Difficulty.NORMAL, db.encounter(db.boss_encounter()), 8))


func test_easy_has_no_objectives() -> void:
	var s := _battle(&"t3_protect", Difficulty.EASY)
	assert_eq(s.objective, ObjectiveRule.ELIMINATE)
	assert_eq(s.archive_uid, -1)
	var hard := _battle(&"t3_protect", Difficulty.HARD)
	assert_eq(hard.objective_rounds, db.encounter(&"t3_protect").objective_rounds + 1, "на «Тяжело» на раунд дольше")


# --- Командир --------------------------------------------------------------------

func test_commander_announces_and_acts_at_round_end() -> void:
	var s := _battle(&"t2_storm", Difficulty.NORMAL, &"ash_overseer")
	var events := BattleResolver.begin(s)
	assert_false(s.intent.is_empty(), "намерение объявлено в начале раунда")
	assert_true(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.COMMANDER_INTENT))
	var action := StringName(s.intent["action"])
	var charges := s.commander_charges[action]
	# Доигрываем раунд: в конце командир выполняет намерение.
	var acted := false
	while s.round_number == 1 and s.outcome == BattleState.Outcome.NONE:
		var ev := BattleResolver.apply(s, BattleAction.defend())
		acted = acted or ev.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.COMMANDER_ACTED)
	assert_true(acted)
	assert_eq(s.commander_charges[action], charges - 1)


func test_commander_rechooses_when_target_dies() -> void:
	var s := _battle(&"t2_storm", Difficulty.NORMAL, &"ash_overseer")
	BattleResolver.begin(s)
	s.intent = {"action": CommanderActions.BOLT, "target": 9999, "hex": Vector2i(-1, -1)}
	assert_false(CommanderActions.valid(s, s.intent))
	var events: Array[BattleEvent] = []
	ObjectiveRule.on_round_end(s, events)
	assert_true(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.COMMANDER_ACTED), "выбрано новое действие")


func test_commander_actions_effects() -> void:
	var s := _battle(&"t2_storm", Difficulty.NORMAL, &"salt_keeper")
	var mine := s.alive(UnitState.Side.PLAYER)[0]
	var foe := s.alive(UnitState.Side.ENEMY)[1]
	for id in [CommanderActions.BOLT, CommanderActions.CURSE, CommanderActions.FURY, CommanderActions.GUARD]:
		s.commander_charges[id] = 1
	var events: Array[BattleEvent] = []
	var hp := mine.total_hp()
	CommanderActions.apply(s, {"action": CommanderActions.BOLT, "target": mine.uid}, events)
	assert_eq(mine.total_hp(), hp - CommanderActions.BOLT_DAMAGE)
	CommanderActions.apply(s, {"action": CommanderActions.CURSE, "target": mine.uid}, events)
	assert_true(mine.has_status(UnitState.STATUS_MARKED))
	var atk := foe.attack
	CommanderActions.apply(s, {"action": CommanderActions.FURY, "target": foe.uid}, events)
	assert_eq(foe.attack, atk + CommanderActions.FURY_ATTACK)
	CommanderActions.apply(s, {"action": CommanderActions.GUARD, "target": foe.uid}, events)
	assert_true(foe.defending and foe.has_status(UnitState.STATUS_SHIELD_WALL))
	assert_eq(s.commander_charges[CommanderActions.BOLT], 0, "заряд потрачен")


func test_commander_state_roundtrip() -> void:
	var s := _battle(&"t2_storm", Difficulty.NORMAL, &"rift_herald")
	BattleResolver.begin(s)
	var copy := BattleState.from_dict(s.to_dict())
	assert_eq(copy.commander_id, &"rift_herald")
	assert_eq(copy.commander_charges, s.commander_charges)
	assert_eq(copy.intent.get("action"), s.intent.get("action"))


# --- Цели боя --------------------------------------------------------------------

func test_survive_wins_after_rounds_with_reinforcements() -> void:
	var s := _battle(&"t2_survive")
	var enc := db.encounter(&"t2_survive")
	assert_eq(s.objective, ObjectiveRule.SURVIVE)
	assert_eq(s.reinforcements.size(), enc.reinforce_ids.size())
	BattleResolver.begin(s)
	var enemies_before := s.alive(UnitState.Side.ENEMY).size()
	_skip_rounds(s, 1)
	if s.outcome == BattleState.Outcome.NONE:
		assert_eq(s.alive(UnitState.Side.ENEMY).size(), enemies_before + 1, "подкрепление во 2-м раунде")
	# Армия бессмертна для проверки времени: защищаемся до конца.
	for u in s.alive(UnitState.Side.PLAYER):
		u.count = 9999
	_skip_rounds(s, 20)
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	assert_eq(s.round_number, enc.objective_rounds + 1)


func test_assassinate_wins_on_target_death() -> void:
	var s := _battle(&"t3_assassinate")
	BattleResolver.begin(s)
	var target := s.get_unit(s.boss_uid)
	assert_eq(target.def_id, db.encounter(&"t3_assassinate").unit_ids[0])
	var events: Array[BattleEvent] = []
	BattleResolver.deal_damage(target, target.total_hp(), &"test", events)
	assert_true(BattleResolver.check_end(s, events))
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON, "остальных добивать не нужно")


func test_assassinate_target_stays_back() -> void:
	var s := _battle(&"t3_assassinate")
	BattleResolver.begin(s)
	var target := s.get_unit(s.boss_uid)
	s.queue.erase(target.uid)
	s.active_uid = target.uid
	var a := AiController.choose_action(s, target.uid)
	assert_ne(a.type, BattleAction.Type.MOVE, "цель не идёт вперёд")


func test_hold_counts_rounds_on_banner() -> void:
	var s := _battle(&"t2_hold")
	BattleResolver.begin(s)
	var mine := s.alive(UnitState.Side.PLAYER)[0]
	mine.hex = s.hold_hexes[0]
	mine.count = 9999
	_skip_rounds(s, 1)
	assert_eq(s.hold_count, 1)
	mine.hex = Vector2i(0, 0) if s.is_free(Vector2i(0, 0)) else mine.hex
	if mine.hex == Vector2i(0, 0):
		_skip_rounds(s, 1)
		assert_eq(s.hold_count, 1, "без отряда на знамени раунд не засчитан")
		mine.hex = s.hold_hexes[0]
	for u in s.alive(UnitState.Side.PLAYER):
		u.count = 9999
	_skip_rounds(s, 10)
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	assert_eq(s.hold_count, s.objective_rounds)


func test_protect_archive_loss_and_inert() -> void:
	var s := _battle(&"t3_protect")
	BattleResolver.begin(s)
	var archive := s.get_unit(s.archive_uid)
	assert_true(archive.inert)
	assert_eq(archive.side, UnitState.Side.PLAYER)
	assert_false(s.queue.has(archive.uid), "архив не ходит")
	var events: Array[BattleEvent] = []
	BattleResolver.deal_damage(archive, archive.total_hp(), &"test", events)
	assert_true(BattleResolver.check_end(s, events))
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_LOST)


func test_archive_does_not_keep_army_alive() -> void:
	var s := _battle(&"t3_protect")
	BattleResolver.begin(s)
	var events: Array[BattleEvent] = []
	for u in ObjectiveRule.fighters(s, UnitState.Side.PLAYER):
		BattleResolver.deal_damage(u, u.total_hp(), &"test", events)
	assert_true(BattleResolver.check_end(s, events))
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_LOST)


func test_enemy_ai_prefers_archive() -> void:
	var s := _battle(&"t3_protect")
	var archive := s.get_unit(s.archive_uid)
	var mine := ObjectiveRule.fighters(s, UnitState.Side.PLAYER)[0]
	assert_gt(AiController.value(20, archive), AiController.value(20, mine) if mine.total_hp() > 20 else 0.0)


func test_objective_state_roundtrip() -> void:
	var s := _battle(&"t2_hold")
	s.hold_count = 2
	var copy := BattleState.from_dict(s.to_dict())
	assert_eq(copy.objective, ObjectiveRule.HOLD)
	assert_eq(copy.hold_hexes, s.hold_hexes)
	assert_eq(copy.hold_count, 2)
	var sv := _battle(&"t2_survive")
	assert_eq(BattleState.from_dict(sv.to_dict()).reinforcements.size(), sv.reinforcements.size())


func test_objective_bonus_resource() -> void:
	var run := RunState.create(db, 4)
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	assert_eq(BattleSetup.objective_bonus(run, db.encounter(&"t1_wall")), &"")
	assert_true(RunState.RESOURCE_IDS.has(BattleSetup.objective_bonus(run, db.encounter(&"t2_hold"))))
	run.difficulty = Difficulty.EASY
	assert_eq(BattleSetup.objective_bonus(run, db.encounter(&"t2_hold")), &"", "на «Легко» целей нет")


func test_ai_battles_with_objectives_finish() -> void:
	for id in [&"t2_hold", &"t2_survive", &"t3_protect", &"t3_assassinate", &"elite_hunt", &"elite_siege"]:
		var s := _battle(id, Difficulty.HARD, &"salt_keeper")
		BattleResolver.begin(s)
		var guard := 0
		while s.outcome == BattleState.Outcome.NONE and guard < 2000:
			BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
			guard += 1
		assert_ne(s.outcome, BattleState.Outcome.NONE, "бой %s закончился" % id)
