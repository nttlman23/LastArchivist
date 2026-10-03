extends GutTest
## Спринт 8, этап A: Зал Архива — покупка узлов, сброс, фиксация на забег, эффекты, профиль v2, сохранение v9.

const PROFILE_PATH := "user://test_hall_profile.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		SafeFile.remove(PROFILE_PATH)


func _profile(ids: Array = []) -> ProfileState:
	var p := ProfileState.new()
	for id in ids:
		p.upgrades.append(id)
	return p


func _run(ids: Array = [], seed_value: int = 5) -> RunState:
	return RunState.create(db, seed_value, DefsDB.DEFAULT_SCHOOL, _profile(ids))


# --- Покупка ---------------------------------------------------------------------------

func test_tree_shape() -> void:
	for branch in MetaUpgrades.BRANCHES:
		var nodes := db.hall_branch(branch)
		assert_eq(nodes.size(), 5, "ветвь %s" % branch)
		for i in nodes.size():
			assert_eq(nodes[i].tier, i + 1)
	var total := 0
	for n: UpgradeNodeDef in db.hall_nodes.values():
		total += n.cost
	assert_eq(total, 113, "всё дерево — 113 очков")


func test_buy_needs_previous_and_points() -> void:
	var p := _profile()
	p.points = 100
	assert_eq(MetaUpgrades.buy_reason(db, p, MetaUpgrades.STOCK_PARCHMENT), "REASON_NEEDS_PREVIOUS")
	assert_true(MetaUpgrades.buy(db, p, MetaUpgrades.STOCK_INK))
	assert_eq(p.points, 100 - db.hall_node(MetaUpgrades.STOCK_INK).cost)
	assert_eq(MetaUpgrades.buy_reason(db, p, MetaUpgrades.STOCK_INK), "REASON_UNLOCKED")
	assert_eq(MetaUpgrades.buy_reason(db, p, MetaUpgrades.STOCK_PARCHMENT), "")
	p.points = 0
	assert_eq(MetaUpgrades.buy_reason(db, p, MetaUpgrades.STOCK_PARCHMENT), "REASON_NO_POINTS")
	assert_false(MetaUpgrades.buy(db, p, MetaUpgrades.STOCK_PARCHMENT))


func test_reset_returns_spent_and_keeps_unlocks() -> void:
	var p := _profile()
	p.points = 50
	p.unlocked.append(&"card_storm_wyrm")
	MetaUpgrades.buy(db, p, MetaUpgrades.MARKED_MAP)
	MetaUpgrades.buy(db, p, MetaUpgrades.RUMORS)
	assert_eq(p.points, 50 - 3 - 5)
	assert_eq(MetaUpgrades.reset(db, p), 8)
	assert_eq(p.points, 50)
	assert_true(p.upgrades.is_empty())
	assert_true(p.is_unlocked(&"card_storm_wyrm"), "открытия не сбрасываются")


func test_run_upgrades_frozen() -> void:
	var p := _profile([MetaUpgrades.STOCK_INK])
	var run := RunState.create(db, 3, DefsDB.DEFAULT_SCHOOL, p)
	p.upgrades.append(MetaUpgrades.STOCK_PARCHMENT)
	assert_eq(run.upgrades, [MetaUpgrades.STOCK_INK] as Array[StringName], "покупка посреди забега не меняет его")
	var loaded := RunState.from_dict(run.to_dict())
	assert_eq(loaded.upgrades, run.upgrades)


# --- Эффекты ------------------------------------------------------------------------------

func test_start_resources() -> void:
	var base := _run()
	var rich := _run([MetaUpgrades.STOCK_INK, MetaUpgrades.STOCK_PARCHMENT, MetaUpgrades.STOCK_AETHER])
	for id in RunState.RESOURCE_IDS:
		assert_eq(rich.resources[id], base.resources[id] + 1, String(id))


func test_discount() -> void:
	var unit: StringName = db.pool_memory_ids(1).filter(func(id: StringName) -> bool: return db.memory(id).is_unit())[0]
	assert_eq(ShopOps.price(db, unit, _run()), ShopOps.CARD_PRICE)
	assert_eq(ShopOps.price(db, unit, _run([MetaUpgrades.DISCOUNT])), ShopOps.CARD_PRICE - 1)


func test_camp_supplies() -> void:
	var run := _run([MetaUpgrades.CAMP_SUPPLIES])
	var before := run.resources.duplicate()
	MapActions.begin_act(db, run, 2)
	for id in RunState.RESOURCE_IDS:
		assert_eq(run.resources[id], before[id] + MetaUpgrades.CAMP_SUPPLY_AMOUNT)
	var plain := _run()
	var p_before := plain.resources.duplicate()
	MapActions.begin_act(db, plain, 2)
	assert_eq(plain.resources, p_before)


func test_second_look_once_per_act() -> void:
	assert_false(MetaUpgrades.can_reroll(_run()))
	var run := _run([MetaUpgrades.SECOND_LOOK])
	assert_true(MetaUpgrades.can_reroll(run))
	assert_eq(MetaUpgrades.reroll(db, run, false).size(), RunState.REWARD_CHOICES)
	assert_false(MetaUpgrades.can_reroll(run), "второй раз в акте — нельзя")
	MapActions.begin_act(db, run, 2)
	assert_true(MetaUpgrades.can_reroll(run), "в новом акте — снова можно")


func test_binding_repairs_two() -> void:
	for ids in [[], [MetaUpgrades.BINDING]]:
		var run := _run(ids)
		var card := run.codex.cards[0]
		card.durability = 1
		ShopOps.haven_repair_all(db, run)
		var expected := mini(db.memory(card.memory_id).max_durability, 1 + (2 if ids.size() > 0 else 1))
		assert_eq(card.durability, expected)


func test_wide_shelf() -> void:
	assert_eq(_run().roll_rewards(db, true).size(), RunState.REWARD_CHOICES)
	var run := _run([MetaUpgrades.WIDE_SHELF])
	assert_eq(run.roll_rewards(db, true).size(), RunState.REWARD_CHOICES_WIDE)
	assert_eq(run.roll_rewards(db, false).size(), RunState.REWARD_CHOICES, "обычный бой — как раньше")


func test_copyist_free_rework_once_per_act() -> void:
	assert_eq(ShopOps.rework_cost(_run()), ShopOps.REWORK_COST)
	var run := _run([MetaUpgrades.COPYIST])
	assert_eq(ShopOps.rework_cost(run), 0)
	run.free_rework_act = run.act
	assert_eq(ShopOps.rework_cost(run), ShopOps.REWORK_COST)
	MapActions.begin_act(db, run, 2)
	assert_eq(ShopOps.rework_cost(run), 0)


func test_family_extra_card() -> void:
	var base := _run()
	var run := _run([MetaUpgrades.FAMILY])
	assert_eq(run.codex.cards.size(), base.codex.cards.size() + 1)
	assert_eq(run.codex.cards[-1].durability, MetaUpgrades.FAMILY_DURABILITY)


func test_marked_map_and_secret_paths() -> void:
	assert_eq(MapActions.scout_cost(_run()), MapActions.SCOUT_COST)
	assert_eq(MapActions.scout_cost(_run([MetaUpgrades.MARKED_MAP])), maxi(0, MapActions.SCOUT_COST - 1))
	assert_eq(MapActions.flight_lanes(_run()), MapActions.FLIGHT_LANES)
	assert_eq(MapActions.flight_lanes(_run([MetaUpgrades.SECRET_PATHS])), MapActions.FLIGHT_LANES + 1)


func test_rumors_unlock_events() -> void:
	for id in MetaUpgrades.RUMOR_EVENTS:
		assert_false(_run().event_pool.has(id), "%s закрыто" % id)
		assert_true(_run([MetaUpgrades.RUMORS]).event_pool.has(id), "%s открыто" % id)


func test_known_reliquary_and_lost_relics() -> void:
	var run := _run()
	assert_eq(RelicOps.offer(db, run, 3).size(), RelicOps.OFFER)
	for id in MetaUpgrades.LOST_RELIC_IDS:
		assert_false(RelicOps.available(db, run).has(id))
	var rich := _run([MetaUpgrades.KNOWN_RELIQUARY, MetaUpgrades.LOST_RELICS])
	assert_eq(RelicOps.offer(db, rich, 3).size(), RelicOps.OFFER + 1)
	for id in MetaUpgrades.LOST_RELIC_IDS:
		assert_true(RelicOps.available(db, rich).has(id))


func test_new_relics_effects() -> void:
	var run := _run()
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	var plain := BattleSetup.for_run(db, run, run.codex.unit_indices(db))
	var parchment := run.resources[RunState.PARCHMENT]
	RelicOps.take(db, run, RelicOps.QUILL)
	assert_eq(run.resources[RunState.PARCHMENT], maxi(0, parchment - 2))
	var s := BattleSetup.for_run(db, run, run.codex.unit_indices(db))
	assert_eq(s.alive(UnitState.Side.PLAYER)[0].attack, plain.alive(UnitState.Side.PLAYER)[0].attack + 1)
	assert_eq(ShopOps.offer_size(run), ShopOps.OFFER_SIZE)
	RelicOps.take(db, run, RelicOps.CHEST)
	assert_eq(ShopOps.open(db, run, 4).offer.size(), ShopOps.OFFER_SIZE + 1)


func test_cartographer_scouts_two_layers() -> void:
	var run := _run([MetaUpgrades.RUMORS])
	run.resources[RunState.AETHER] = 3
	EventResolver.apply(db, run, 1, db.event(&"old_cartographer"), 0)
	assert_eq(run.resources[RunState.AETHER], 2)
	for layer in [1, 2]:
		for n in run.map.layer_nodes(layer):
			assert_true(n.scouted, "слой %d разведан" % layer)
	for n in run.map.layer_nodes(3):
		assert_false(n.scouted)


# --- Профиль и сохранение ------------------------------------------------------------------

func test_profile_v2_roundtrip() -> void:
	var p := _profile([MetaUpgrades.STOCK_INK, MetaUpgrades.MARKED_MAP])
	p.trials[&"tide_order"] = 4
	p.save(PROFILE_PATH)
	var q := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(q.upgrades, p.upgrades)
	assert_eq(q.trial_open(&"tide_order"), 4)
	assert_eq(q.trial_open(&"ash_archive"), 0)


func test_profile_v1_migrates() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", 1)
	cfg.set_value("profile", "points", 17)
	cfg.set_value("profile", "unlocked", ["card_storm_wyrm"])
	cfg.set_value("stats", "runs", 6)
	SafeFile.save_config(cfg, PROFILE_PATH)
	var p := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(p.points, 17, "очки старого профиля сохраняются")
	assert_eq(p.runs, 6)
	assert_true(p.is_unlocked(&"card_storm_wyrm"))
	assert_true(p.upgrades.is_empty())
	assert_true(p.trials.is_empty())


func test_run_v8_migrates() -> void:
	var run := _run()
	var d := run.to_dict()
	d["version"] = 8
	for k in ["upgrades", "trial", "reroll_act", "free_rework_act"]:
		d.erase(k)
	var migrated := SaveMigrations.migrate(d)
	assert_eq(int(migrated["version"]), RunState.SAVE_VERSION)
	var loaded := RunState.from_dict(migrated)
	assert_not_null(loaded)
	assert_eq(loaded.trial, 0)
	assert_true(loaded.upgrades.is_empty())
