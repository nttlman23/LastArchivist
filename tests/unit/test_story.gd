extends GutTest
## Спринт 10, этап A: метасюжет — главы, страницы памяти, сценки, реплики, сюжетные события,
## сохранения; учебный бой-пролог — сквозной прогон по шагам.

const PROFILE_PATH := "user://test_story_profile.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_all() -> void:
	SafeFile.remove(PROFILE_PATH)


func _ev(p: ProfileState, event: Story.Event, ctx: Dictionary = {}, run: RunState = null) -> Dictionary:
	return Story.on_event(db, p, run, event, ctx)


func _has_key(key: String) -> bool:
	return TranslationServer.translate(key) != key


func test_data_valid() -> void:
	assert_eq(db.pages.size(), 24)
	assert_eq(db.story_events.size(), 6)
	var per_chapter := {}
	for p in db.pages.values():
		assert_true(Story.EVENTS.has(p.condition), "%s: условие известно" % p.id)
		per_chapter[p.chapter] = per_chapter.get(p.chapter, 0) + 1
		if p.condition == Story.STORY_EVENT:
			assert_true(db.story_events.has(p.arg), "%s: событие %s есть" % [p.id, p.arg])
	assert_eq(per_chapter, {1: 6, 2: 6, 3: 6, 4: 6}, "по 6 страниц на главу")
	for e in db.story_events.values():
		assert_between(e.story_chapter, 1, 4)
		assert_true(db.pages.values().any(func(p: PageDef) -> bool: return p.arg == e.id), "%s: даёт страницу" % e.id)
		assert_false(db.events.has(e.id), "сюжетные события — вне обычных пулов")
		assert_eq(db.event(e.id), e, "db.event находит и сюжетные")


func test_texts_exist() -> void:
	for p in db.pages.values():
		var k := "PAGE_%s" % String(p.id).to_upper()
		assert_true(_has_key(k + "_TITLE") and _has_key(k + "_TEXT"), String(p.id))
	for cond in Story.EVENTS:
		assert_true(_has_key("STORY_HINT_%s" % String(cond).to_upper()), "подсказка %s" % cond)
	for id in Story.SCENES:
		assert_true(_has_key("STORY_SCENE_%s_TITLE" % String(id).to_upper()), "заголовок %s" % id)
		assert_between(Story.paragraphs(id).size(), 2, 6, "абзацы %s" % id)
	for ch in range(1, 5):
		assert_true(_has_key("STORY_CHAPTER_%d" % ch) and _has_key("STORY_CHAPTER_LOCKED_%d" % ch))
		assert_true(_has_key("RUN_WON_TEXT_%d" % ch) and _has_key("RUN_LOST_TEXT_%d" % ch))
	for e in db.story_events.values():
		assert_true(_has_key(e.title_key) and _has_key(e.text_key), String(e.id))
		for o: EventOptionDef in e.options:
			assert_true(_has_key(o.label_key) and _has_key(o.result_key), o.label_key)


func test_lines_for_every_speaker_and_chapter() -> void:
	var p := ProfileState.new()
	var speakers: Array[StringName] = db.commander_ids()
	speakers.append_array([&"rift_warden", &"abyss_lord", Story.PHASE_SPEAKER])
	for ch in range(1, 5):
		p.story_chapter = ch
		for s in speakers:
			assert_ne(Story.line_key(p, s, 1), "", "реплика %s, глава %d" % [s, ch])
	p.story_chapter = 1
	var a := Story.line_key(p, &"ash_overseer", 5)
	var b := Story.line_key(p, &"ash_overseer", 5)
	assert_ne(a, b, "та же реплика не подряд")


func test_chapters_advance() -> void:
	var p := ProfileState.new()
	assert_eq(p.story_chapter, 1)
	var r := _ev(p, Story.Event.RIFT_CLOSED)
	assert_eq(p.story_chapter, 2, "Разлом закрыт — глава II")
	assert_eq(int(r["chapter"]), 2)
	assert_true(p.story_pages.has(&"p1_ash"), "страница за Разлом")
	p.wins = 1
	_ev(p, Story.Event.RUN_WON)
	assert_eq(p.story_chapter, 3, "первая победа — глава III")
	assert_true(p.story_pages.has(&"p3_name"))
	p.wins = 3
	_ev(p, Story.Event.RUN_WON)
	assert_eq(p.story_chapter, 3, "без всех страниц I–III глава IV закрыта")
	for page in db.pages.values():
		if page.chapter <= 3:
			p.story_pages[page.id] = "2026-10-11"
	var r4 := _ev(p, Story.Event.RUN_WON)
	assert_eq(p.story_chapter, 4, "3 победы и все страницы — глава IV")
	assert_true((r4["pages"] as Array).has(&"p4_page"), "страница открытия главы IV")


func test_pages_once_and_by_chapter() -> void:
	var p := ProfileState.new()
	var ctx := {"elite": true, "act": 2, "commander": true}
	var got: Array = _ev(p, Story.Event.BATTLE_WON, ctx)["pages"]
	assert_true(got.has(&"p1_elite") and got.has(&"p1_commander"))
	assert_false(got.has(&"p2_elite"), "страница главы II — только в главе II")
	assert_true((_ev(p, Story.Event.BATTLE_WON, ctx)["pages"] as Array).is_empty(), "второй раз — ничего")
	p.story_chapter = 2
	got = _ev(p, Story.Event.BATTLE_WON, ctx)["pages"]
	assert_true(got.has(&"p2_elite") and got.has(&"p2_depths"))
	got = _ev(p, Story.Event.STORY_EVENT, {"event": &"story_diary"})["pages"]
	assert_eq(got, [&"p2_diary"])


func test_repeat_daily_no_progress() -> void:
	var p := ProfileState.new()
	var run := DailyRun.create(db, p, "2026-10-11")
	run.daily_ranked = false
	_ev(p, Story.Event.RIFT_CLOSED, {}, run)
	assert_eq(p.story_chapter, 1)
	assert_true(p.story_pages.is_empty())
	assert_eq(Story.pending_scene(p, &"rift", run), &"")


func test_pending_scenes() -> void:
	var p := ProfileState.new()
	assert_eq(Story.pending_scene(p, &"start"), &"", "в главе I — пролог отдельно, карточки главы нет")
	assert_eq(Story.pending_scene(p, &"rift"), &"rift_1")
	Story.mark_seen(p, &"rift_1")
	assert_eq(Story.pending_scene(p, &"rift"), &"", "просмотренная — не повторяется")
	p.story_chapter = 2
	assert_eq(Story.pending_scene(p, &"start"), &"chapter_2")
	assert_eq(Story.pending_scene(p, &"win"), &"finale_2")
	p.story_chapter = 3
	assert_eq(Story.pending_scene(p, &"win"), &"finale_3")
	p.story_chapter = 4
	assert_eq(Story.pending_scene(p, &"win"), Story.TRUE_FINALE)
	assert_eq(Story.run_end_key(2, true), "RUN_WON_TEXT_2")


func test_place_story_event() -> void:
	var p := ProfileState.new()
	var placed := 0
	for seed_value in 10:
		var run := RunState.create(db, seed_value + 1, DefsDB.DEFAULT_SCHOOL, p)
		Story.place_event(db, run, p)
		if run.story_event == &"":
			continue
		placed += 1
		assert_eq(run.story_event, &"story_scribe", "глава I, первый акт — переписчик")
		var nodes := run.map.nodes.filter(func(n: MapState.MapNode) -> bool: return n.content == run.story_event)
		assert_eq(nodes.size(), 1, "на одном острове")
		assert_eq((nodes[0] as MapState.MapNode).type, MapState.NodeType.EVENT)
		Story.place_event(db, run, p)
		assert_eq(run.map.nodes.filter(func(n: MapState.MapNode) -> bool: return Story.is_story_event(db, n.content)).size(), 1, "не больше одного за забег")
	assert_gt(placed, 5, "почти на каждой карте есть остров-событие")
	p.story_events.append(&"story_scribe")
	var run2 := RunState.create(db, 3, DefsDB.DEFAULT_SCHOOL, p)
	Story.place_event(db, run2, p)
	assert_eq(run2.story_event, &"", "пройденное событие не повторяется; других в главе I нет")


func test_profile_v4_roundtrip_and_migration() -> void:
	var p := ProfileState.new()
	p.story_chapter = 3
	p.story_pages[&"p1_ash"] = "2026-10-11"
	p.story_seen.append(&"rift_1")
	p.story_events.append(&"story_scribe")
	p.prologue_done = true
	p.save(PROFILE_PATH)
	var q := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(q.story_chapter, 3)
	assert_eq(q.story_pages, p.story_pages)
	assert_eq(q.story_seen, p.story_seen)
	assert_eq(q.story_events, p.story_events)
	assert_true(q.prologue_done)
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", 3)
	cfg.set_value("stats", "runs", 4)
	cfg.set_value("stats", "best_layer", 12)
	SafeFile.save_config(cfg, PROFILE_PATH)
	var old := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(old.story_chapter, 2, "дошёл до второго акта — глава II")
	assert_true(old.prologue_done, "старый игрок пролог не проходит заново")
	assert_false(ProfileState.new().prologue_done, "новый — проходит")


func test_run_v10_migrates() -> void:
	var d := RunState.create(db, 5).to_dict()
	d["version"] = 10
	d.erase("story_event")
	var run := RunState.from_dict(SaveMigrations.migrate(d))
	assert_not_null(run)
	assert_eq(run.story_event, &"")


# --- Учебный бой ------------------------------------------------------------------------------

var _real_profile: ProfileState
var _real_speed: float


func _act(scene: Node, action: BattleAction) -> void:
	scene._player_act(action)
	await wait_physics_frames(2)
	var t0 := Time.get_ticks_msec()
	while (scene._busy or not scene._is_player_turn()) and scene.state.outcome == BattleState.Outcome.NONE and Time.get_ticks_msec() - t0 < 15000:
		await wait_physics_frames(1)


func _enemy(scene: Node) -> UnitState:
	return scene.state.alive(UnitState.Side.ENEMY)[0]


func test_tutorial_walkthrough() -> void:
	_real_profile = Game.profile
	_real_speed = Settings.anim_speed
	Game.profile = ProfileState.new()
	Settings.anim_speed = 2.0
	var scene: Node = load(Game.SCENE_TUTORIAL).instantiate()
	add_child_autofree(scene)
	await wait_seconds(1.0)
	var s: BattleState = scene.state
	assert_eq(s.grid.width, 7, "малое поле")
	assert_eq(scene.step, 0)
	assert_eq(s.active_unit().def_id, &"salt_guard")
	# Неверное действие не ломает шаг.
	scene._player_act(BattleAction.defend())
	assert_eq(scene.step, 0, "защита на шаге «ход» не проходит")
	assert_eq(s.active_unit().def_id, &"salt_guard")
	# 1. Ход: клетка, ближайшая к врагу.
	var best := Vector2i(-1, -1)
	for h in Pathfinding.reachable(s, s.active_unit()):
		if best.x < 0 or HexGrid.distance(h, _enemy(scene).hex) < HexGrid.distance(best, _enemy(scene).hex):
			best = h
	await _act(scene, BattleAction.move(best))
	assert_eq(scene.step, 1)
	# 2. Выстрел.
	await _act(scene, BattleAction.shoot(_enemy(scene).uid))
	assert_eq(scene.step, 2)
	# 3–4. Ждать и защита.
	await _act(scene, BattleAction.wait())
	assert_eq(scene.step, 3)
	await _act(scene, BattleAction.defend())
	assert_eq(scene.step, 4)
	# 5. Архивариус: любой доступный приказ.
	var order: BattleAction = null
	for id in s.hero_orders:
		var opts := HeroActions.options(s, id, -1)
		if not opts.is_empty():
			order = opts[0]
			break
	assert_not_null(order, "есть приказ")
	await _act(scene, order)
	assert_eq(scene.step, 5)
	# 6. Удар Стража.
	var melee: BattleAction = null
	var e := _enemy(scene)
	for h in [s.active_unit().hex] + s.grid.neighbors(e.hex):
		var a := BattleAction.melee(h, e.uid)
		if BattleResolver.validate(s, a):
			melee = a
			break
	assert_not_null(melee, "Страж дотягивается до врага")
	await _act(scene, melee)
	assert_eq(scene.step, 6)
	# 7. Способность Летописцев.
	var abilities := Abilities.options(s, s.active_unit())
	assert_false(abilities.is_empty(), "способность готова")
	await _act(scene, abilities[0])
	assert_eq(scene.step, 7, "последний шаг")
	assert_eq(_enemy(scene).count, 1, "враг ослаблен")
	# 8. Добить.
	var guard := 0
	while s.outcome == BattleState.Outcome.NONE and guard < 10:
		await _act(scene, AiController.choose_action(s, s.active_uid))
		guard += 1
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	var t0 := Time.get_ticks_msec()
	while scene._end_panel == null and Time.get_ticks_msec() - t0 < 5000:
		await wait_physics_frames(1)
	assert_not_null(scene._end_panel, "панель «Учебный бой пройден»")
	Game.profile = _real_profile
	Settings.anim_speed = _real_speed
