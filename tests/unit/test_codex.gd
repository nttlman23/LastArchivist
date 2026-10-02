extends GutTest

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func test_defs_loaded() -> void:
	assert_eq(db.units.size(), 6)
	assert_eq(db.memories.size(), 6)
	assert_eq(db.encounters.size(), 3)
	for m: MemoryCardDef in db.memories.values():
		assert_true(db.units.has(m.unit_id), "карта %s ссылается на существо" % m.id)
	for e: EncounterDef in db.encounters.values():
		assert_eq(e.unit_ids.size(), e.counts.size())
	for id in db.encounter_chain:
		assert_true(db.encounters.has(id))


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
