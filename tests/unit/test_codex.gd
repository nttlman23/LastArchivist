extends GutTest

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func test_defs_loaded() -> void:
	assert_eq(db.units.size(), 17)
	assert_eq(db.memories.size(), 14)
	assert_eq(db.encounters.size(), 21)
	assert_eq(db.commanders.size(), 3)
	assert_eq(db.abilities.size(), 16)
	assert_eq(db.events.size(), 8)
	assert_eq(db.spells.size(), 10)
	assert_eq(db.orders.size(), 3)
	assert_eq(db.upgrades.size(), 7)
	for u: UnitDef in db.units.values():
		assert_true(u.inert or db.abilities.has(u.ability_id), "у %s есть способность" % u.id)
	for m: MemoryCardDef in db.memories.values():
		if m.is_unit():
			assert_true(db.units.has(m.unit_id), "карта %s ссылается на существо" % m.id)
			assert_true(db.spells.has(m.spell_id), "у карты %s есть заклинание" % m.id)
			assert_true(db.upgrades.has(m.upgrade_id), "у карты %s есть улучшение" % m.id)
		else:
			assert_true(db.orders.has(m.order_id), "геройская карта %s открывает приказ" % m.id)
	for id in db.base_orders:
		assert_true(db.orders.has(id))
	for e: EncounterDef in db.encounters.values():
		assert_eq(e.unit_ids.size(), e.counts.size())
		assert_true(ObjectiveRule.ALL.has(e.objective), "цель %s" % e.id)
		assert_eq(e.reinforce_ids.size(), e.reinforce_counts.size())
		assert_eq(e.reinforce_ids.size(), e.reinforce_rounds.size())
		if e.objective == ObjectiveRule.HOLD:
			assert_false(e.hold_hexes.is_empty(), "знамёна %s" % e.id)
		if e.objective != ObjectiveRule.ELIMINATE:
			assert_false(e.boss, "у Разлома своя цель")
			assert_true(e.elite or e.tier >= 2, "на слое 1 — только «уничтожить всех»")
	for c: CommanderDef in db.commanders.values():
		for a in c.actions:
			assert_true(CommanderActions.ICONS.has(a), "действие %s командира %s" % [a, c.id])
	for tier in [1, 2, 3]:
		assert_gt(db.encounter_pool(tier, false).size(), 2, "шаблоны уровня %d" % tier)
	assert_eq(db.encounter_pool(0, true).size(), 5, "элитные")
	assert_true(db.encounter(db.boss_encounter()).boss)


func test_starting_codex() -> void:
	var run := RunState.create(db, 1)
	assert_eq(run.codex.cards.size(), 4)
	assert_eq(run.codex.cards[0].durability, 4)


func test_decay_removes_faded() -> void:
	var codex := CodexState.new()
	codex.add(db, &"storm_wyrm")  # прочность 2
	codex.add(db, &"salt_legion")  # прочность 4
	var both: Array[int] = [0, 1]
	assert_eq(codex.decay(both).size(), 0)
	var faded := codex.decay(both)
	assert_eq(faded, [&"storm_wyrm"] as Array[StringName])
	assert_eq(codex.cards.size(), 1)
	assert_eq(codex.cards[0].memory_id, &"salt_legion")
	assert_eq(codex.cards[0].durability, 2)


func test_decay_only_selected() -> void:
	var codex := CodexState.new()
	codex.add(db, &"salt_legion")
	codex.add(db, &"salt_legion")
	var first: Array[int] = [0]
	codex.decay(first)
	assert_eq(codex.cards[0].durability, 3)
	assert_eq(codex.cards[1].durability, 4)


func test_limit() -> void:
	var codex := CodexState.new()
	for i in CodexState.MAX_CARDS:
		codex.add(db, &"ghoul_pack")
	assert_true(codex.is_full())


func test_rewards_distinct_and_deterministic() -> void:
	var r1 := RunState.create(db, 5)
	var r2 := RunState.create(db, 5)
	var a := r1.roll_rewards(db)
	assert_eq(a.size(), 3)
	assert_eq(a, r2.roll_rewards(db))
	assert_ne(a[0], a[1])
	assert_ne(a[1], a[2])
	assert_ne(a[0], a[2])
