extends GutTest
## Превращения карт, улучшения, геройские карты (SPEC_SPRINT2 3.4–3.6, 5.2).

var db: DefsDB
var run: RunState


func before_all() -> void:
	db = DefsDB.load_default()


func before_each() -> void:
	# Стартовый Кодекс: 2× Легион, Летописцы, Гули.
	run = RunState.create(db, 1)


func test_spell_charges_equal_durability() -> void:
	run.codex.cards[2].durability = 2
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	assert_eq(run.codex.cards.size(), 3)
	assert_eq(run.hero.spells.size(), 1)
	assert_eq(run.hero.spells[0].spell_id, &"ash_record")
	assert_eq(run.hero.spells[0].charges, 2)


func test_upgrade_applied_to_stacks_and_stacks() -> void:
	CodexOps.apply(db, run, 3, CodexOps.Form.UPGRADE)  # Гули: +1 атака
	run.hero.upgrades.append(&"up_attack")
	var selected: Array[int] = [0]
	var s := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 1, run.hero)
	var guard := s.alive(UnitState.Side.PLAYER)[0]
	assert_eq(guard.attack, db.unit(&"salt_guard").attack + 2)
	assert_eq(s.alive(UnitState.Side.ENEMY)[0].attack, db.unit(&"ash_ghoul").attack, "врагам бонус не даётся")


func test_ranged_only_upgrade() -> void:
	run.hero.upgrades.append(&"up_shots")
	var selected: Array[int] = [0, 2]
	var s := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 1, run.hero)
	assert_eq(s.alive(0)[0].shots_left, 0)
	assert_eq(s.alive(0)[1].shots_left, db.unit(&"chronicler").shots + 2)


func test_hp_upgrade() -> void:
	run.hero.upgrades.append(&"up_hp")
	var selected: Array[int] = [0]
	var s := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 1, run.hero)
	assert_eq(s.alive(0)[0].hp, 27)
	assert_eq(s.alive(0)[0].top_hp, 27)


func test_sacrifice_repairs_up_to_max() -> void:
	run.codex.cards[1].durability = 1
	run.codex.cards[2].durability = 3  # максимум 3
	assert_eq(CodexOps.sacrifice_repairs(db, run.codex, 0), 1)
	CodexOps.apply(db, run, 0, CodexOps.Form.SACRIFICE)
	assert_eq(run.codex.cards.size(), 3)
	assert_eq(run.codex.cards[0].durability, 2)
	assert_eq(run.codex.cards[1].durability, 3)


func test_fuse_same_memory() -> void:
	run.codex.cards[0].durability = 1
	run.codex.cards[1].durability = 3
	assert_eq(CodexOps.fuse_partner(run.codex, 0), 1)
	CodexOps.apply(db, run, 0, CodexOps.Form.FUSE)
	assert_eq(run.codex.cards.size(), 3)
	var fused := run.codex.cards[0]
	assert_eq(fused.memory_id, &"salt_legion")
	assert_eq(fused.level, 2)
	assert_eq(fused.durability, 3)
	assert_eq(fused.count(db), 18)


func test_fuse_requires_pair_and_level_cap() -> void:
	assert_eq(CodexOps.unavailable_reason(db, run, 2, CodexOps.Form.FUSE), "REASON_NO_PAIR")
	run.codex.cards[0].level = 3
	assert_eq(CodexOps.unavailable_reason(db, run, 0, CodexOps.Form.FUSE), "REASON_MAX_LEVEL")
	assert_eq(CodexOps.unavailable_reason(db, run, 1, CodexOps.Form.FUSE), "REASON_NO_PAIR", "пара на максимуме не годится")


func test_hero_card_rules() -> void:
	run.codex.add(db, &"last_king")
	var king := run.codex.cards.size() - 1
	for form in CodexOps.ALL_FORMS:
		assert_eq(CodexOps.unavailable_reason(db, run, king, form), "REASON_HERO_CARD")
	assert_eq(run.codex.unit_indices(db), [0, 1, 2, 3] as Array[int])
	assert_eq(run.codex.hero_indices(db), [king] as Array[int])
	assert_has(run.hero.available_orders(db, run.codex), &"order_royal")
	assert_has(run.hero.active_upgrades(db, run.codex), &"up_initiative")


func test_hero_card_decays_every_victory() -> void:
	run.codex.add(db, &"last_king")
	var selected: Array[int] = [0]
	run.decay_after_battle(db, selected)
	assert_eq(run.codex.cards[4].durability, 2, "Король угасает, хоть и не был в бою")
	assert_eq(run.codex.cards[1].durability, 4, "невыбранная карта отряда не угасает")


func test_spell_charges_carry_over() -> void:
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	var charges: Array[int] = [0, 2]
	run.apply_spell_charges(charges)
	assert_eq(run.hero.spells.size(), 1, "пустое заклинание исчезает")
	assert_eq(run.hero.spells[0].spell_id, &"hunger")
	assert_eq(run.hero.spells[0].charges, 2)


func test_battle_gets_hero_spells_and_orders() -> void:
	run.codex.add(db, &"last_king")
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	var selected: Array[int] = [0]
	var s := BattleState.create(db, db.encounter(&"crypt_1"), run.codex, selected, 1, run.hero)
	assert_eq(s.hero_spells.size(), 1)
	assert_eq(s.hero_spells[0]["power"], 60)
	assert_has(s.hero_orders, &"order_royal")
	assert_eq(s.alive(0)[0].initiative, db.unit(&"salt_guard").initiative + 1, "пассивка Короля")


func test_sacrifice_useless_when_all_intact() -> void:
	assert_eq(CodexOps.unavailable_reason(db, run, 0, CodexOps.Form.SACRIFICE), "REASON_NOTHING_TO_REPAIR")
