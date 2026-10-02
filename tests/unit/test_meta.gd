extends GutTest
## Мета-прогрессия, профиль, школы, настройки, подсказки (SPEC_SPRINT4 этап A).

const PROFILE_PATH := "user://test_meta_profile.cfg"
const SETTINGS_PATH := "user://test_meta_settings.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	for p in [PROFILE_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _unlock(id: StringName) -> Dictionary:
	for u in MetaRewards.all_unlocks(db):
		if u["id"] == id:
			return u
	return {}


# --- Очки и открытия ----------------------------------------------------------------

func test_points_for_run() -> void:
	var run := RunState.create(db, 1)
	run.map.current = run.map.layer_nodes(6)[0].id
	run.elites_won = 2
	assert_eq(MetaRewards.points_for_run(run, false), 5 + 4)
	run.map.current = run.map.layer_nodes(MapState.RIFT_LAYER)[0].id
	assert_eq(MetaRewards.points_for_run(run, true), 7 + 4 + 5)


func test_finish_run_updates_profile() -> void:
	var p := ProfileState.new()
	var run := RunState.create(db, 1)
	run.map.current = run.map.layer_nodes(4)[0].id
	var gained := MetaRewards.finish_run(p, run, false)
	assert_eq(gained, 3)
	assert_eq(p.points, 3)
	assert_eq(p.runs, 1)
	assert_eq(p.best_layer, 4)


func test_buy_unlock() -> void:
	var p := ProfileState.new()
	var card := _unlock(&"card_storm_wyrm")
	assert_eq(MetaRewards.buy_reason(db, p, card), "REASON_NO_POINTS")
	p.points = 10
	assert_true(MetaRewards.buy(db, p, card))
	assert_eq(p.points, 6)
	assert_eq(MetaRewards.buy_reason(db, p, card), "REASON_UNLOCKED")


func test_unimplemented_school_is_soon() -> void:
	var p := ProfileState.new()
	p.points = 100
	for s in db.schools_sorted():
		if not s.implemented:
			assert_eq(MetaRewards.buy_reason(db, p, _unlock(MetaRewards.school_unlock_id(s.id))), "REASON_SOON")
			assert_false(MetaRewards.is_school_open(p, s))
	assert_true(MetaRewards.is_school_open(p, db.school(DefsDB.DEFAULT_SCHOOL)), "Архив Пепла открыт сразу")


func test_card_pool_respects_unlocks_and_favorites() -> void:
	var p := ProfileState.new()
	var ash := db.school(DefsDB.DEFAULT_SCHOOL)
	var pool := MetaRewards.card_pool(db, p, ash)
	assert_does_not_have(pool, &"storm_wyrm")
	assert_does_not_have(pool, &"faceless_choir")
	assert_eq(pool.count(&"ghoul_pack"), 2, "любимая карта школы — вес ×2")
	assert_eq(pool.count(&"salt_legion"), 1)
	p.unlocked.append(&"card_storm_wyrm")
	assert_has(MetaRewards.card_pool(db, p, ash), &"storm_wyrm")


func test_locked_events_never_on_map() -> void:
	var p := ProfileState.new()
	for s in 15:
		var run := RunState.create(db, s, DefsDB.DEFAULT_SCHOOL, p)
		assert_does_not_have(run.event_pool, &"captive_king")
		for n in run.map.nodes:
			if n.type == MapState.NodeType.EVENT:
				assert_false(n.content == &"captive_king" or n.content == &"rift_whisper", "закрытое событие %s" % n.content)


func test_rewards_use_run_pool() -> void:
	var p := ProfileState.new()
	var run := RunState.create(db, 4, DefsDB.DEFAULT_SCHOOL, p)
	for i in 30:
		for id in run.roll_rewards(db):
			assert_ne(id, &"storm_wyrm", "закрытая карта не выпадает")
	var offer := run.roll_rewards(db)
	assert_eq(offer.size(), RunState.REWARD_CHOICES)
	assert_eq(offer.size(), _unique(offer).size(), "без повторов в одном предложении")


func test_profile_roundtrip() -> void:
	var p := ProfileState.new()
	p.points = 12
	p.unlocked.append(&"card_storm_wyrm")
	p.seen_hints.append(&"map")
	p.runs = 3
	p.save(PROFILE_PATH)
	var q := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(q.points, 12)
	assert_eq(q.unlocked, [&"card_storm_wyrm"] as Array[StringName])
	assert_eq(q.seen_hints, [&"map"] as Array[StringName])
	assert_eq(q.runs, 3)
	assert_eq(ProfileState.load_or_new("user://missing_profile.cfg").points, 0)


func test_run_save_v4_keeps_school_and_pools() -> void:
	var p := ProfileState.new()
	var run := RunState.create(db, 2, DefsDB.DEFAULT_SCHOOL, p)
	run.elites_won = 1
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_eq(back.school_id, DefsDB.DEFAULT_SCHOOL)
	assert_eq(back.card_pool, run.card_pool)
	assert_eq(back.event_pool, run.event_pool)
	assert_eq(back.elites_won, 1)


# --- Школы ------------------------------------------------------------------------

func test_school_start_codex() -> void:
	var run := RunState.create(db, 1, DefsDB.DEFAULT_SCHOOL)
	var ids := run.codex.cards.map(func(c: CodexState.Card) -> StringName: return c.memory_id)
	assert_eq(ids, Array(db.school(DefsDB.DEFAULT_SCHOOL).starting_codex))


func test_ash_sacrifice_passive() -> void:
	var s := TestHelpers.empty_battle()
	s.passive_id = SchoolPassives.ASH_SACRIFICE
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 1, {"attack": 5})
	var b := TestHelpers.add(s, 0, Vector2i(0, 0), 10, {"attack": 5})
	var e := TestHelpers.add(s, 1, Vector2i(1, 4), 50)
	TestHelpers.add(s, 1, Vector2i(10, 8), 5)
	TestHelpers.activate(s, e)
	BattleResolver.apply(s, BattleAction.melee(e.hex, a.uid))
	assert_false(a.is_alive())
	assert_eq(b.attack, 6, "павший союзник злит остальных")
	assert_eq(b.fury, 1)
	assert_true(b.has_status(UnitState.STATUS_ASH_FURY))


func test_no_passive_without_school() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 4), 1)
	var b := TestHelpers.add(s, 0, Vector2i(0, 0), 10, {"attack": 5})
	var e := TestHelpers.add(s, 1, Vector2i(1, 4), 50)
	TestHelpers.activate(s, e)
	BattleResolver.apply(s, BattleAction.melee(e.hex, a.uid))
	assert_eq(b.attack, 5)


# --- Настройки и подсказки --------------------------------------------------------

func test_settings_roundtrip() -> void:
	var saved_path := Settings.settings_path
	var saved := [Settings.detailed, Settings.hints]
	Settings.settings_path = SETTINGS_PATH
	Settings.set_detailed(true)
	Settings.set_hints(false)
	Settings.detailed = false
	Settings.hints = true
	Settings.load_settings()
	assert_true(Settings.detailed)
	assert_false(Settings.hints)
	Settings.settings_path = saved_path
	Settings.detailed = saved[0]
	Settings.hints = saved[1]


func test_hints_once_and_toggle() -> void:
	var real_profile := Game.profile
	var real_path := Game.profile_path
	var real_hints := Settings.hints
	Game.profile = ProfileState.new()
	Game.profile_path = PROFILE_PATH
	Settings.hints = true
	assert_true(Hints.should_show(&"map"))
	Hints.show_hint(&"map")
	assert_has(Game.profile.seen_hints, &"map")
	assert_false(Hints.should_show(&"map"), "второй раз не показывается")
	Hints.hide_all()
	Settings.hints = false
	assert_false(Hints.should_show(&"battle"), "подсказки выключены")
	Settings.hints = true
	Hints.reset()
	assert_true(Hints.should_show(&"map"), "сброс")
	Game.profile = real_profile
	Game.profile_path = real_path
	Settings.hints = real_hints


func test_hint_texts_exist() -> void:
	for id in Hints.IDS:
		var key := "HINT_" + String(id).to_upper()
		assert_ne(tr(key), key, key)


# --- Короткий интерфейс --------------------------------------------------------------

func test_school_and_passive_texts_exist() -> void:
	for s in db.schools_sorted():
		for key in [s.name_key, s.desc_key, s.desc_key + "_SHORT", "PASSIVE_" + String(s.passive_id).to_upper()]:
			assert_ne(tr(key), key, key)


func test_chips_have_tooltips() -> void:
	var c := UiKit.chip(UnitGlyphs.ICON_INK, "3", Color.WHITE, "Чернила", "описание")
	add_child_autofree(c)
	assert_true(c.has_meta("tip"))
	assert_ne(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "подсказке нужна мышь")


func test_short_card_is_compact() -> void:
	var saved := Settings.detailed
	Settings.detailed = false
	var short := UiKit.card_button(db, &"salt_legion")
	Settings.detailed = true
	var full := UiKit.card_button(db, &"salt_legion")
	Settings.detailed = saved
	assert_lt(short.custom_minimum_size.y, full.custom_minimum_size.y)
	short.free()
	full.free()


func test_unit_chips_translated() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 5, {"ability_id": Abilities.MARK, "is_ranged": true, "shots": 3, "is_flying": true})
	u.ability_cd = 1
	u.retaliated = true
	u.defending = true
	u.waited = true
	u.fury = 2
	for st in [UnitState.STATUS_MARKED, UnitState.STATUS_RUST_ARMOR, UnitState.STATUS_ADVANCE, UnitState.STATUS_RIFT_MARKED]:
		u.statuses[st] = UnitState.PERMANENT
	var chips := UnitInfoPanel.chips_of(db, u)
	assert_gte(chips.size(), 10)
	for c: Array in chips:
		assert_false(String(c[3]).begins_with("CHIP_") or String(c[3]).begins_with("STATUS_"), "заголовок переведён: %s" % c[3])
		assert_false(String(c[4]).begins_with("STATUS_") or String(c[4]).begins_with("ABIL"), "описание переведено: %s" % c[4])


func test_every_icon_draws() -> void:
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(60, 60)
	var drawn := []
	canvas.draw.connect(func() -> void:
		for id in UnitGlyphs.ALL_ICONS:
			UnitGlyphs.draw_icon(canvas, id, Vector2(30, 30), 20, Color.BLACK, Color.WHITE)
			drawn.append(id))
	add_child_autofree(canvas)
	await wait_physics_frames(2)
	assert_eq(drawn.size(), UnitGlyphs.ALL_ICONS.size())


func _unique(arr: Array) -> Array:
	var r := []
	for x in arr:
		if not r.has(x):
			r.append(x)
	return r
