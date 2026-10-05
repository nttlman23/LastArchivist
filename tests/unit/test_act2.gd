extends GutTest
## Спринт 7, этап A: два акта, привал, Затопленные хранилища, враги и босс второго акта.

const FIXTURE_V6 := "res://tests/fixtures/run_save_v6.json"
const PATH := "user://test_act2_save.json"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	SafeFile.remove(PATH)


func _codex() -> CodexState:
	var c := CodexState.new()
	for id in [&"salt_legion", &"salt_legion", &"ghoul_pack", &"ash_chroniclers"]:
		c.add(db, id)
	return c


func _battle(enc: StringName, seed_value: int = 7) -> BattleState:
	return BattleState.create(db, db.encounter(enc), _codex(), [0, 1, 2, 3], seed_value)


# --- Данные и карта ---------------------------------------------------------------

func test_act2_pools_and_map() -> void:
	for tier in [4, 5]:
		assert_gt(db.encounter_pool(tier, false, 2).size(), 2, "шаблоны уровня %d" % tier)
	assert_eq(db.encounter_pool(0, true, 2).size(), 3, "элита второго акта")
	assert_eq(db.boss_encounter(2), &"abyss")
	assert_eq(db.boss_encounter(1), &"rift", "Разлом — по-прежнему босс первого акта")
	var map := MapGenerator.generate(db, 99, [], 2)
	for n in map.nodes:
		if n.is_battle() and n.content != &"":
			assert_eq(db.encounter(n.content).act, 2, "на карте второго акта — встречи второго акта")


func test_gift_cards_not_in_pools() -> void:
	var run := RunState.create(db, 5)
	assert_false(run.card_pool.has(CampOps.HERO_CARD))
	assert_false(run.card_pool.has(CampOps.UNIT_CARD), "карты второго акта не выпадают в первом")
	assert_true(db.pool_memory_ids(2).has(CampOps.UNIT_CARD), "во втором акте — выпадают")
	assert_false(db.pool_memory_ids(2).has(CampOps.HERO_CARD), "геройская карта — только из дара")


# --- Структура забега ---------------------------------------------------------------

func test_begin_act2_and_total_layer() -> void:
	var run := RunState.create(db, 6)
	run.map.current = run.map.layer_nodes(MapState.RIFT_LAYER)[0].id
	assert_eq(run.total_layer(), 8)
	var cards := run.codex.cards.size()
	MapActions.begin_act(db, run, 2)
	assert_eq(run.act, 2)
	assert_eq(run.map.current, MapState.START)
	assert_eq(run.codex.cards.size(), cards, "Кодекс переходит во второй акт")
	run.map.current = run.map.layer_nodes(3)[0].id
	assert_eq(run.total_layer(), 11, "сквозной слой: 8 + 3")
	var loaded := RunState.from_dict(run.to_dict())
	assert_eq(loaded.act, 2)


func test_camp_options() -> void:
	var run := RunState.create(db, 8)
	var options := CampOps.options(run)
	assert_eq(options.size(), 4)
	assert_eq(CampOps.reason(db, run, options[0]), "CAMP_REASON_NOTHING_TO_REPAIR", "всё цело — ремонт не нужен")
	run.codex.cards[0].durability = 1
	assert_eq(CampOps.reason(db, run, options[0]), "")
	CampOps.apply(db, run, options[0])
	assert_eq(run.codex.cards[0].durability, db.memory(run.codex.cards[0].memory_id).max_durability)
	CampOps.apply(db, run, options[1])
	assert_true(run.codex.cards.any(func(c: CodexState.Card) -> bool: return c.memory_id == CampOps.HERO_CARD))
	assert_true(CampOps.GIFTS.has(options[3]["id"]))


func test_gifts_apply_in_battle() -> void:
	var run := RunState.create(db, 9)
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	var plain := BattleSetup.for_run(db, run, [0, 1, 2, 3] as Array[int])
	run.gifts = [CampOps.GIFT_INITIATIVE, CampOps.GIFT_VIGOR] as Array[StringName]
	var gifted := BattleSetup.for_run(db, run, [0, 1, 2, 3] as Array[int])
	var a := plain.alive(UnitState.Side.PLAYER)[0]
	var b := gifted.alive(UnitState.Side.PLAYER)[0]
	assert_eq(b.initiative, a.initiative + CampOps.INITIATIVE_BONUS)
	assert_gt(b.hp, a.hp)


# --- Поле: постоянная вода, течения, чернила ----------------------------------------------

func test_permanent_water_never_dries() -> void:
	var s := _battle(&"t4_shallows")
	var enc := db.encounter(&"t4_shallows")
	BattleResolver.begin(s)
	for i in 6:
		TurnManager.start_round(s)
	for h in enc.water_hexes:
		assert_eq(s.water.get(h, 0), BattleState.WATER_PERMANENT)
	assert_eq(s.biome, &"flooded")
	assert_false(s.rift, "«Стирание» — только у Разлома")


func test_currents_push_and_skip_flyers() -> void:
	var s := TestHelpers.empty_battle()
	var walker := TestHelpers.add(s, 0, Vector2i(5, 4), 5)
	var flyer := TestHelpers.add(s, 0, Vector2i(5, 2), 5, {"is_flying": true})
	TestHelpers.add(s, 1, Vector2i(10, 8), 5)
	s.currents[Vector2i(5, 4)] = 3
	s.currents[Vector2i(5, 2)] = 3
	TurnManager.start_round(s)
	assert_eq(walker.hex, HexGrid.step(Vector2i(5, 4), 3), "течение сносит на клетку")
	assert_eq(flyer.hex, Vector2i(5, 2), "летун не сносится")
	# Занятая клетка — стек остаётся.
	s.currents[walker.hex] = 0
	TestHelpers.add(s, 0, HexGrid.step(walker.hex, 0), 5)
	var before := walker.hex
	TurnManager.start_round(s)
	assert_eq(walker.hex, before)


func test_wet_ink_and_soaked_initiative() -> void:
	var s := TestHelpers.empty_battle()
	var scribe := TestHelpers.add(s, 1, Vector2i(8, 4), 5, {"ability_id": Abilities.WET_INK, "is_ranged": true, "shots": 5})
	var target := TestHelpers.add(s, 0, Vector2i(2, 4), 5, {"initiative": 7})
	TestHelpers.activate(s, scribe)
	BattleResolver.apply(s, BattleAction.ability(Abilities.WET_INK, target.uid))
	assert_true(target.has_status(UnitState.STATUS_MARKED))
	assert_eq(target.effective_initiative(), 7 - UnitState.SOAKED_INITIATIVE)


func test_ink_cloud_blocks_shooters() -> void:
	var s := TestHelpers.empty_battle()
	var kraken := TestHelpers.add(s, 1, Vector2i(6, 4), 5, {"ability_id": Abilities.INK_CLOUD})
	var archer := TestHelpers.add(s, 0, Vector2i(3, 4), 5, {"is_ranged": true, "shots": 5})
	TestHelpers.activate(s, kraken)
	assert_false(s.is_blocked(archer))
	BattleResolver.apply(s, BattleAction.ability(Abilities.INK_CLOUD, -1, archer.hex))
	assert_true(s.ink.has(archer.hex))
	assert_true(s.is_blocked(archer), "в чернилах стрелок не стреляет")
	TurnManager.start_round(s)
	TurnManager.start_round(s)
	assert_false(s.ink.has(archer.hex), "облако рассеивается")


func test_siren_call_pulls() -> void:
	var s := TestHelpers.empty_battle()
	var siren := TestHelpers.add(s, 1, Vector2i(8, 4), 5, {"ability_id": Abilities.SIREN_CALL, "is_flying": true})
	var target := TestHelpers.add(s, 0, Vector2i(3, 4), 5)
	TestHelpers.activate(s, siren)
	var d0 := HexGrid.distance(siren.hex, target.hex)
	BattleResolver.apply(s, BattleAction.ability(Abilities.SIREN_CALL, target.uid))
	assert_eq(HexGrid.distance(siren.hex, target.hex), d0 - Abilities.CALL_STEPS)


# --- Босс --------------------------------------------------------------------------------

func test_boss_has_intents_and_phase_two() -> void:
	var s := _battle(&"abyss")
	assert_eq(s.commander_id, &"abyss_lord_cmd", "у босса свои намерения независимо от сложности")
	BattleResolver.begin(s)
	assert_false(s.intent.is_empty())
	var boss := s.get_unit(s.boss_uid)
	var def0 := boss.defense
	var water0 := s.water.size()
	var dirs := s.currents.duplicate()
	var events: Array[BattleEvent] = []
	BattleResolver.deal_damage(boss, boss.total_hp() / 2 + 1, &"test", events)
	BattleResolver.check_end(s, events)
	assert_eq(s.boss_phase, 2)
	assert_eq(boss.defense, def0 + BossRule.PHASE_DEFENSE)
	assert_gt(s.water.size(), water0, "поле затоплено")
	for h in dirs:
		assert_eq(s.currents[h], (dirs[h] + 3) % 6, "течения развернулись")
	assert_true(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.PHASE_CHANGED))
	# Вторая фаза — один раз.
	var w := s.water.size()
	BattleResolver.check_end(s, events)
	assert_eq(s.water.size(), w)


func test_boss_summon_and_wave() -> void:
	var s := _battle(&"abyss")
	BattleResolver.begin(s)
	var before := s.alive(UnitState.Side.ENEMY).size()
	var events: Array[BattleEvent] = []
	CommanderActions.apply(s, {"action": CommanderActions.SUMMON, "target": -1}, events)
	assert_eq(s.alive(UnitState.Side.ENEMY).size(), before + CommanderActions.SUMMON_STACKS)
	var mine := s.alive(UnitState.Side.PLAYER)[0]
	mine.hex = Vector2i(3, mine.hex.y)
	var x0 := mine.hex.x
	CommanderActions.apply(s, {"action": CommanderActions.WAVE, "target": mine.uid}, events)
	assert_lt(mine.hex.x, x0, "волна сдвигает к краю игрока")


func test_act2_battles_finish() -> void:
	for id in db.encounters:
		if db.encounters[id].act != 2:
			continue
		var s := _battle(id, 3)
		BattleResolver.begin(s)
		var n := 0
		while s.outcome == BattleState.Outcome.NONE and n < 3000:
			BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
			n += 1
		assert_ne(s.outcome, BattleState.Outcome.NONE, "бой %s закончился" % id)


# --- Сохранения ---------------------------------------------------------------------------

func test_v6_save_migrates() -> void:
	SafeFile.write_text(PATH, FileAccess.get_file_as_string(FIXTURE_V6))
	var run := SaveService.load_run(PATH)
	assert_not_null(run)
	assert_eq(run.act, 1)
	assert_false(run.at_camp)
	assert_true(run.gifts.is_empty())


func test_camp_state_saved() -> void:
	var run := RunState.create(db, 10)
	run.at_camp = true
	run.gifts = [CampOps.GIFT_VIGOR] as Array[StringName]
	var loaded := RunState.from_dict(run.to_dict())
	assert_true(loaded.at_camp)
	assert_eq(loaded.gifts, [CampOps.GIFT_VIGOR] as Array[StringName])


# --- Сверка со спекой (SPEC_SPRINT7 20) -----------------------------------------------------

func test_boss_commander_not_in_random_pool() -> void:
	assert_false(db.commander_ids().has(&"abyss_lord_cmd"), "командир босса не выпадает обычным встречам")
	assert_true(db.commander_ids(true).has(&"abyss_lord_cmd"))
	var run := RunState.create(db, 11, DefsDB.DEFAULT_SCHOOL, null, Difficulty.HARD)
	for n in run.map.nodes:
		if n.is_battle() and n.content != &"":
			run.pending_node = n.id
			assert_ne(Difficulty.commander_for(db, run, db.encounter(n.content)), &"abyss_lord_cmd")


func test_ai_avoids_current_that_breaks_contact() -> void:
	var s := TestHelpers.empty_battle()
	var target := TestHelpers.add(s, 0, Vector2i(5, 4), 5)
	var brute := TestHelpers.add(s, 1, Vector2i(8, 4), 5, {"speed": 4})
	var near := Vector2i(6, 4)
	# Течение уносит с ближайшей клетки прочь от цели.
	s.currents[near] = HexGrid.line_direction(target.hex, near)
	TestHelpers.activate(s, brute)
	assert_ne(AiController.drift_hex(s, brute, near), near)
	var a := AiController.choose_action(s, brute.uid)
	assert_eq(a.type, BattleAction.Type.MELEE)
	assert_ne(a.dest, near, "не встаёт на течение, которое унесёт от цели")
	assert_true(HexGrid.are_adjacent(AiController.drift_hex(s, brute, a.dest), target.hex))


func test_drift_ignored_for_flyers_and_compass() -> void:
	var s := TestHelpers.empty_battle()
	var flyer := TestHelpers.add(s, 0, Vector2i(3, 3), 5, {"is_flying": true})
	var walker := TestHelpers.add(s, 0, Vector2i(3, 5), 5)
	s.currents[Vector2i(4, 4)] = 0
	assert_eq(AiController.drift_hex(s, flyer, Vector2i(4, 4)), Vector2i(4, 4))
	assert_ne(AiController.drift_hex(s, walker, Vector2i(4, 4)), Vector2i(4, 4))
	s.player_ignores_currents = true
	assert_eq(AiController.drift_hex(s, walker, Vector2i(4, 4)), Vector2i(4, 4), "Компас прилива")


func test_siren_call_stops_in_water() -> void:
	var s := TestHelpers.empty_battle()
	var siren := TestHelpers.add(s, 1, Vector2i(8, 4), 5, {"ability_id": Abilities.SIREN_CALL, "is_flying": true})
	var target := TestHelpers.add(s, 0, Vector2i(3, 4), 5)
	var path := Abilities.call_path(s, siren, target)
	assert_eq(path.size(), Abilities.CALL_STEPS)
	s.water[path[0]] = BattleState.WATER_PERMANENT
	assert_eq(Abilities.call_path(s, siren, target), [path[0]] as Array[Vector2i], "вода останавливает притягивание")
	target.is_flying = true
	assert_eq(Abilities.call_path(s, siren, target).size(), Abilities.CALL_STEPS, "летуна вода не держит")


func test_chronicle_keeps_relics_and_gifts() -> void:
	var run := RunState.create(db, 5)
	run.relics.append(RelicOps.SALT_CROWN)
	run.gifts.append(CampOps.GIFT_VIGOR)
	var e := MetaRewards.chronicle_entry(run, ProfileState.OUTCOME_LOST, 0, db)
	assert_eq(e["relics"], ["salt_crown"])
	assert_eq(e["gifts"], ["gift_vigor"])
