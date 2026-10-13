extends GutTest
## Спринт 12: износ карт от потерь в бою — пороги, итоги боя, «надломлена», ремонт, учебные забеги после пролога.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func test_amount_thresholds() -> void:
	assert_eq(Wear.amount(20, 20), 0)
	assert_eq(Wear.amount(20, 19), 0, "потеряно 5 %")
	assert_eq(Wear.amount(20, 18), 1, "ровно 10 %")
	assert_eq(Wear.amount(20, 10), 1, "ровно половина")
	assert_eq(Wear.amount(20, 9), 2, "больше половины")
	assert_eq(Wear.amount(20, 0), Wear.WIPED_WEAR, "погиб целиком")
	assert_eq(Wear.amount(20, 22), 0, "поднят лечением выше старта — без износа")


func test_free_losses() -> void:
	assert_eq(Wear.free_losses(20, 20), 1, "до 10 % — ещё одно существо")
	assert_eq(Wear.free_losses(20, 18), 8, "до половины — ещё 8")
	assert_eq(Wear.free_losses(20, 5), -1, "дальше износ уже предельный")


func test_from_battle_counts_only_card_stacks() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 0), 12)
	a.card_index = 0
	a.count = 5
	var b := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 2), 10)
	b.card_index = 1
	b.count = 0
	var illusion := TestHelpers.add(s, UnitState.Side.PLAYER, Vector2i(0, 4), 10)
	illusion.illusion = true
	illusion.count = 0
	TestHelpers.add(s, UnitState.Side.ENEMY, Vector2i(8, 0), 10)
	var r := Wear.from_battle(s)
	assert_eq(r.size(), 2, "иллюзия и враг не считаются")
	assert_eq(r[0]["wear"], 2, "потеряно 7 из 12 (0,58) — больше половины: −2")
	assert_true(r[1]["wiped"])


func test_after_battle_wears_by_losses_and_cracks() -> void:
	var run := RunState.create(db, 1)
	# Стартовый Кодекс Архива: 2× Легион (4), Летописцы (3), Гули (3).
	var selected: Array[int] = [0, 1, 2, 3]
	var results := {
		0: {"start": 12, "left": 12, "wear": 0, "wiped": false},
		1: {"start": 12, "left": 6, "wear": 1, "wiped": false},
		2: {"start": 10, "left": 0, "wear": 2, "wiped": true},
		3: {"start": 10, "left": 2, "wear": 2, "wiped": false},
	}
	var cards := run.codex.cards.duplicate()
	var gone := run.after_battle(db, selected, [], results)
	assert_eq(cards[0].durability, 4, "без потерь — цела")
	assert_eq(cards[1].durability, 3)
	assert_eq(cards[2].durability, 1, "3 − 2 = 1")
	assert_true(cards[2].cracked, "погибли все — надломлена")
	assert_eq(cards[3].durability, 1)
	assert_false(cards[3].cracked)
	assert_true(gone.is_empty())


func test_wiped_card_with_low_durability_fades() -> void:
	var run := RunState.create(db, 1)
	run.codex.cards[2].durability = 2
	var gone := run.after_battle(db, [2] as Array[int], [], {2: {"start": 10, "left": 0, "wear": 2, "wiped": true}})
	assert_eq(gone, [&"ash_chroniclers"] as Array[StringName])


func test_cracked_caps_durability_until_repair() -> void:
	var run := RunState.create(db, 1)
	run.after_battle(db, [0] as Array[int], [], {0: {"start": 12, "left": 0, "wear": 2, "wiped": true}})
	var card := run.codex.cards[0]
	assert_true(card.cracked)
	assert_eq(card.durability, 1, "4 − 2 = 2, но надломлена — не выше 1")
	var saved := CodexState.from_array(run.codex.to_array())
	assert_true(saved.cards[0].cracked, "сохраняется")
	run.resources[RunState.INK] = 5
	assert_true(ShopOps.repair(db, run, 0))
	assert_false(card.cracked, "ремонт снимает «надломлена»")
	assert_eq(card.durability, 2)


func test_without_battle_results_old_rule() -> void:
	var run := RunState.create(db, 1)
	run.after_battle(db, [0] as Array[int])
	assert_eq(run.codex.cards[0].durability, 3, "без итогов боя — как раньше, −1")


func test_skipping_prologue_drops_gentle_runs() -> void:
	var real := Game.profile
	var path := Game.profile_path
	Game.profile = ProfileState.new()
	Game.profile_path = "user://test_wear_profile.cfg"
	Game.finish_tutorial(true)
	assert_eq(Game.profile.gentle_runs_left, 0, "пролог пропущен — учебных забегов нет")
	Game.profile = ProfileState.new()
	Game.finish_tutorial()
	assert_eq(Game.profile.gentle_runs_left, ProfileState.GENTLE_RUNS, "пройден — учебные забеги остаются")
	SafeFile.remove(Game.profile_path)
	Game.profile_path = path
	Game.profile = real
	await wait_physics_frames(2)
