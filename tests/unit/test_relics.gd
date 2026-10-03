extends GutTest
## Спринт 7, этап B: Реликварий, реликвии, события и карты второго акта.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _run_in_battle() -> RunState:
	var run := RunState.create(db, 31)
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	return run


func _battle(run: RunState) -> BattleState:
	return BattleSetup.for_run(db, run, run.codex.unit_indices(db))


func test_reliquaries_only_in_act2() -> void:
	for seed_value in [1, 2, 3, 4, 5]:
		var a1 := MapGenerator.generate(db, seed_value, [], 1)
		var a2 := MapGenerator.generate(db, seed_value, [], 2)
		var n1 := a1.nodes.filter(func(n: MapState.MapNode) -> bool: return n.type == MapState.NodeType.RELIQUARY).size()
		var n2 := a2.nodes.filter(func(n: MapState.MapNode) -> bool: return n.type == MapState.NodeType.RELIQUARY).size()
		assert_eq(n1, 0)
		assert_between(n2, MapGenerator.RELIQUARIES_MIN, MapGenerator.RELIQUARIES_MAX)


func test_events_by_act() -> void:
	var a1 := MapGenerator.generate(db, 7, [], 1)
	var a2 := MapGenerator.generate(db, 7, [], 2)
	for n in a1.nodes:
		if n.type == MapState.NodeType.EVENT:
			assert_eq(db.event(n.content).act, 1)
	for n in a2.nodes:
		if n.type == MapState.NodeType.EVENT:
			assert_eq(db.event(n.content).act, 2)


func test_offer_excludes_owned() -> void:
	var run := RunState.create(db, 3)
	var offer := RelicOps.offer(db, run, 5)
	assert_eq(offer.size(), RelicOps.OFFER)
	assert_eq(RelicOps.offer(db, run, 5), offer, "одно и то же предложение для острова")
	run.relics.append(offer[0])
	assert_false(RelicOps.offer(db, run, 5).has(offer[0]))


func test_relic_costs() -> void:
	var run := RunState.create(db, 4)
	var aether := run.resources[RunState.AETHER]
	RelicOps.take(db, run, RelicOps.HOURGLASS)
	assert_eq(run.resources[RunState.AETHER], maxi(0, aether - 2))
	assert_true(run.relics.has(RelicOps.HOURGLASS))
	var total := 0
	for c in run.codex.cards:
		total += c.durability
	RelicOps.take(db, run, RelicOps.SALT_CROWN, 9)
	var after := 0
	for c in run.codex.cards:
		after += c.durability
	assert_eq(after, total - 1, "Солёный венец: −1 прочности одной карте")


func test_relic_battle_effects() -> void:
	var run := _run_in_battle()
	var plain := _battle(run)
	run.relics = [RelicOps.SALT_CROWN, RelicOps.SHELL, RelicOps.HOURGLASS, RelicOps.COMPASS, RelicOps.LANTERN] as Array[StringName]
	var s := _battle(run)
	var a := plain.alive(UnitState.Side.PLAYER)[0]
	var b := s.alive(UnitState.Side.PLAYER)[0]
	assert_eq(b.defense, a.defense + 1)
	assert_eq(b.attack, a.attack - 1)
	assert_gt(b.hp, a.hp)
	assert_eq(b.initiative, a.initiative - 1)
	assert_true(s.player_ignores_currents)
	BattleResolver.begin(s)
	assert_eq(s.hero_actions_left, BattleState.HERO_ACTIONS_PER_ROUND + 1, "лишнее действие героя в первом раунде")
	for e in s.alive(UnitState.Side.ENEMY):
		assert_true(e.has_status(UnitState.STATUS_SOAKED), "Фонарь: враги промокли в первом раунде")


func test_compass_ignores_currents() -> void:
	var s := TestHelpers.empty_battle()
	var mine := TestHelpers.add(s, 0, Vector2i(5, 4), 5)
	TestHelpers.add(s, 1, Vector2i(10, 8), 5)
	s.currents[Vector2i(5, 4)] = 3
	s.player_ignores_currents = true
	TurnManager.start_round(s)
	assert_eq(mine.hex, Vector2i(5, 4))


func test_pearl_bonus_and_repair_cost() -> void:
	var run := RunState.create(db, 6)
	assert_eq(ShopOps.repair_cost(run), ShopOps.REPAIR_COST)
	run.relics.append(RelicOps.PEARL)
	assert_eq(ShopOps.repair_cost(run), ShopOps.REPAIR_COST * 2)
	assert_eq(RelicOps.battle_bonus(run).get(RunState.PARCHMENT, 0), 1)


func test_inkwell_boosts_spells() -> void:
	var run := _run_in_battle()
	CodexOps.apply(db, run, 3, CodexOps.Form.SPELL)
	var plain := _battle(run)
	run.relics.append(RelicOps.INKWELL)
	var s := _battle(run)
	assert_gt(int(s.hero_spells[0]["power"]), int(plain.hero_spells[0]["power"]))


func test_relic_event_effect() -> void:
	var run := RunState.create(db, 12)
	var altar := db.event(&"sunken_altar")
	EventResolver.apply(db, run, 1, altar, 0, 0)
	assert_eq(run.relics.size(), 1, "алтарь даёт реликвию")


func test_act2_cards_pool() -> void:
	var run := RunState.create(db, 13)
	for id in [&"drowned_scribes", &"ink_krakens", &"sirens", &"abyss_wardens"]:
		assert_false(run.card_pool.has(id), "%s — не в первом акте" % id)
	MapActions.begin_act(db, run, 2)
	for id in [&"drowned_scribes", &"ink_krakens", &"sirens", &"abyss_wardens"]:
		assert_true(run.card_pool.has(id), "%s — во втором акте" % id)


func test_relics_saved_and_migrated() -> void:
	var run := RunState.create(db, 14)
	run.relics.append(RelicOps.SCALE)
	assert_eq(RunState.from_dict(run.to_dict()).relics, [RelicOps.SCALE] as Array[StringName])
	var d := run.to_dict()
	d["version"] = 7
	d.erase("relics")
	var migrated := SaveMigrations.migrate(d)
	assert_eq(int(migrated["version"]), RunState.SAVE_VERSION)
	assert_true(RunState.from_dict(migrated).relics.is_empty())
