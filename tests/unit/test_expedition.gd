extends GutTest
## Лавка, гавань, события, разлом, после-боевые правила (SPEC_SPRINT3 5–6).

var db: DefsDB
var run: RunState


func before_all() -> void:
	db = DefsDB.load_default()


func before_each() -> void:
	run = RunState.create(db, 3)


# --- Лавка и гавань ---------------------------------------------------------------

func test_shop_offer_deterministic_and_buy() -> void:
	var a := ShopOps.open(db, run, 4)
	assert_eq(a.offer, ShopOps.open(db, run, 4).offer, "повторный вход — то же предложение")
	run.resources[RunState.PARCHMENT] = 10
	var unit_slot := a.offer.find(a.offer.filter(func(id: StringName) -> bool: return db.memory(id).is_unit())[0])
	var before := run.codex.cards.size()
	assert_true(ShopOps.buy(db, run, a, unit_slot))
	assert_eq(run.codex.cards.size(), before + 1)
	assert_eq(run.resources[RunState.PARCHMENT], 10 - ShopOps.CARD_PRICE)
	assert_eq(ShopOps.buy_reason(db, run, a, unit_slot), "REASON_SOLD")


func test_shop_rejects_when_poor_or_full() -> void:
	var v := ShopOps.open(db, run, 4)
	run.resources[RunState.PARCHMENT] = 0
	assert_eq(ShopOps.buy_reason(db, run, v, 0), "REASON_NO_PARCHMENT")
	run.resources[RunState.PARCHMENT] = 50
	while not run.codex.is_full():
		run.codex.add(db, &"ghoul_pack")
	assert_eq(ShopOps.buy_reason(db, run, v, 0), "REASON_CODEX_FULL")


func test_repair_and_recharge() -> void:
	assert_eq(ShopOps.repair_reason(db, run, 0), "REASON_FULL_DURABILITY")
	run.codex.cards[0].durability = 2
	run.resources[RunState.INK] = 1
	assert_true(ShopOps.repair(db, run, 0))
	assert_eq(run.codex.cards[0].durability, 3)
	assert_eq(ShopOps.repair_reason(db, run, 0), "REASON_NO_INK")
	assert_eq(ShopOps.recharge_reason(run, 0), "REASON_NO_SPELLS")
	CodexOps.apply(db, run, 2, CodexOps.Form.SPELL)
	run.resources[RunState.AETHER] = 1
	var charges := run.hero.spells[0].charges
	assert_true(ShopOps.recharge(run, 0))
	assert_eq(run.hero.spells[0].charges, charges + 1)


func test_rework_once_per_visit() -> void:
	var v := ShopOps.open(db, run, 4)
	run.resources[RunState.PARCHMENT] = 10
	assert_true(ShopOps.rework(db, run, v, 2, CodexOps.Form.UPGRADE))
	assert_eq(run.resources[RunState.PARCHMENT], 10 - ShopOps.REWORK_COST)
	assert_eq(ShopOps.rework_reason(db, run, v, 0, CodexOps.Form.UPGRADE), "REASON_REWORK_USED")


func test_haven() -> void:
	run.codex.cards[0].durability = 1
	run.codex.cards[2].durability = 3  # максимум
	assert_eq(ShopOps.haven_repairs(db, run), 1)
	ShopOps.haven_repair_all(db, run)
	assert_eq(run.codex.cards[0].durability, 2)
	assert_eq(run.codex.cards[2].durability, 3)
	CodexOps.apply(db, run, 3, CodexOps.Form.SPELL)
	var charges := run.hero.spells[0].charges
	ShopOps.haven_meditate(run)
	assert_eq(run.hero.spells[0].charges, charges + 1)


# --- События ------------------------------------------------------------------

func test_all_events_resolve_every_option() -> void:
	for id in db.event_ids():
		var event := db.event(id)
		assert_gte(event.options.size(), 2, String(id))
		for i in event.options.size():
			var r := RunState.create(db, 11)
			CodexOps.apply(db, r, 3, CodexOps.Form.SPELL)
			r.resources[RunState.INK] = 5
			var option: EventOptionDef = event.options[i]
			assert_eq(EventResolver.option_reason(db, r, option), "", "%s/%d доступен" % [id, i])
			var res := EventResolver.apply(db, r, 1, event, i, 0 if option.needs_card else -1)
			assert_ne(tr(res.text_key), res.text_key, "%s/%d: перевод итога" % [id, i])
			assert_ne(tr(option.label_key), option.label_key)


func test_event_requirements() -> void:
	var altar := db.event(&"abandoned_altar")
	run.resources[RunState.INK] = 0
	assert_eq(EventResolver.option_reason(db, run, altar.options[0]), "REASON_NO_INK")
	run.resources[RunState.INK] = 2
	assert_eq(EventResolver.option_reason(db, run, altar.options[0]), "REASON_NO_SPELLS")


func test_event_effects() -> void:
	var spring := db.event(&"ink_spring")
	run.codex.cards[1].durability = 1
	EventResolver.apply(db, run, 1, spring, 1, 1)
	assert_eq(run.codex.cards[1].durability, 3)
	var merchant := db.event(&"memory_merchant")
	var r := EventResolver.apply(db, run, 1, merchant, 0, 0)
	assert_eq(run.codex.cards.size(), 3)
	assert_eq(r.resources[RunState.PARCHMENT], 4)
	assert_eq(r.gone, [&"salt_legion"] as Array[StringName])


func test_event_zero_durability_fades() -> void:
	var whisper := db.event(&"rift_whisper")
	for c in run.codex.cards:
		c.durability = 1
	var r := EventResolver.apply(db, run, 1, whisper, 0)
	assert_eq(r.gone.size(), 1, "самая прочная карта угасла")
	assert_eq(run.hero.upgrades.size(), 1)


func test_risky_option_deterministic() -> void:
	var bridge := db.event(&"storm_bridge")
	var a := RunState.create(db, 3)
	var b := RunState.create(db, 3)
	var ra := EventResolver.apply(db, a, 6, bridge, 1)
	var rb := EventResolver.apply(db, b, 6, bridge, 1)
	assert_eq(ra.success, rb.success)
	assert_eq(a.codex.to_array(), b.codex.to_array())


func test_event_battle_and_reward_card() -> void:
	var king := db.event(&"captive_king")
	var r := EventResolver.apply(db, run, 1, king, 0)
	assert_eq(r.battle_tier, 2)
	assert_eq(r.battle_reward, &"last_king")
	var enc := EventResolver.battle_encounter(db, run, 1, 2)
	assert_eq(db.encounter(enc).tier, 2)


# --- Разлом -------------------------------------------------------------------

func _rift_battle() -> BattleState:
	var selected: Array[int] = [0, 1, 2, 3]
	return BattleState.create(db, db.encounter(db.boss_encounter()), run.codex, selected, 5, run.hero)


func test_rift_marks_and_erases() -> void:
	var s := _rift_battle()
	assert_true(s.rift)
	TurnManager.start_round(s)  # 1
	TurnManager.start_round(s)  # 2
	var events := TurnManager.start_round(s)  # 3 — пометка
	var strongest := RiftRule.strongest(s)
	assert_true(strongest.has_status(UnitState.STATUS_RIFT_MARKED))
	assert_true(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.RIFT_MARKED))
	events = TurnManager.start_round(s)  # 4 — стирание
	assert_false(strongest.is_alive())
	assert_eq(s.erased_cards, [strongest.card_index] as Array[int])
	assert_true(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.ERASED))


func test_rift_skips_if_marked_died() -> void:
	var s := _rift_battle()
	for i in 3:
		TurnManager.start_round(s)
	var marked := RiftRule.strongest(s)
	marked.take_damage(100000)
	var events := TurnManager.start_round(s)
	assert_false(events.any(func(e: BattleEvent) -> bool: return e.type == BattleEvent.ERASED))
	assert_eq(s.erased_cards.size(), 0)


func test_erased_card_removed_even_on_victory() -> void:
	var selected: Array[int] = [0, 1, 2]
	var erased: Array[int] = [1]
	var gone := run.after_battle(db, selected, erased)
	assert_has(gone, &"salt_legion")
	assert_eq(run.codex.cards.size(), 3)
	assert_eq(run.codex.cards[0].durability, 3, "участник угас на 1")
	assert_eq(run.codex.cards[2].durability, 3, "не участвовал — без изменений")


func test_rift_tear_hits_only_enemies() -> void:
	var s := TestHelpers.empty_battle()
	var warden := TestHelpers.add(s, 1, Vector2i(8, 4), 1, {"ability_id": Abilities.RIFT_TEAR})
	var victim := TestHelpers.add(s, 0, Vector2i(5, 4), 10)
	var ally := TestHelpers.add(s, 1, Vector2i(5, 3), 10)
	TestHelpers.activate(s, warden)
	assert_false(BattleResolver.validate(s, BattleAction.ability(Abilities.RIFT_TEAR, -1, Vector2i(0, 4))), "дальше 4 клеток")
	BattleResolver.apply(s, BattleAction.ability(Abilities.RIFT_TEAR, -1, Vector2i(5, 4)))
	assert_eq(victim.total_hp(), 100 - Abilities.TEAR_DAMAGE)
	assert_eq(ally.total_hp(), 100)


func test_killing_warden_wins() -> void:
	var s := _rift_battle()
	BattleResolver.begin(s)
	var warden := s.get_unit(s.boss_uid)
	assert_eq(warden.def_id, &"rift_warden")
	warden.take_damage(warden.total_hp() - 1)
	var events: Array[BattleEvent] = []
	warden.take_damage(1)
	assert_true(BattleResolver.check_end(s, events))
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON, "свита ещё жива, но разлом закрыт")


func test_boss_win_ends_run_without_resources() -> void:
	assert_true(db.encounter(db.boss_encounter()).boss)
	var r := MapActions.battle_rewards(db.encounter(db.boss_encounter()))
	assert_eq(r[RunState.INK] + r[RunState.PARCHMENT] + r[RunState.AETHER], 0)
