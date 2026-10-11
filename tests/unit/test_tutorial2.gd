extends GutTest
## Спринт 11: второй урок «Герой и Кодекс» — бой (заклинание, удар, дальний выстрел), превращение
## изношенной карты в заклинание, учебная карта (полёт, разведка, переход, перелёт). Настоящий забег
## и его сохранение не трогаются.

var _real_profile: ProfileState
var _real_speed: float
var _real_run: RunState


func before_each() -> void:
	_real_profile = Game.profile
	_real_speed = Settings.anim_speed
	_real_run = Game.run
	Game.profile = ProfileState.new()
	Settings.anim_speed = 2.0


func after_each() -> void:
	Game.profile = _real_profile
	Settings.anim_speed = _real_speed
	Game.run = _real_run


func _act(scene: Node, action: BattleAction) -> void:
	scene._player_act(action)
	await wait_physics_frames(2)
	var t0 := Time.get_ticks_msec()
	while (scene._busy or not scene._is_player_turn()) and scene.state.outcome == BattleState.Outcome.NONE and Time.get_ticks_msec() - t0 < 15000:
		await wait_physics_frames(1)


func test_battle_and_rework() -> void:
	var scene: Node = load(Game.SCENE_TUTORIAL2).instantiate()
	add_child_autofree(scene)
	await wait_seconds(1.0)
	var s: BattleState = scene.state
	var enemy: UnitState = s.alive(UnitState.Side.ENEMY)[0]
	assert_eq(scene.step, 0)
	# Приказ вместо заклинания на шаге «заклинание» не проходит.
	var order: BattleAction = null
	for id in s.hero_orders:
		var opts := HeroActions.options(s, id, -1)
		if not opts.is_empty():
			order = opts[0]
			break
	if order:
		scene._player_act(order)
		assert_eq(scene.step, 0, "нужно именно заклинание")
	# 1. Заклинание героя: заряд тратится.
	var spell: Array = HeroActions.options(s, scene.SPELL, 0)
	assert_false(spell.is_empty(), "заклинание доступно")
	await _act(scene, spell[0])
	assert_eq(scene.step, 1)
	assert_eq(int(s.hero_spells[0]["charges"]), scene.SPELL_CHARGES - 1, "заряд потрачен")
	# 2. Удар Стража вплотную.
	var melee: BattleAction = null
	for h in [s.active_unit().hex] + s.grid.neighbors(enemy.hex):
		var a := BattleAction.melee(h, enemy.uid)
		if BattleResolver.validate(s, a):
			melee = a
			break
	assert_not_null(melee, "Страж дотягивается до врага")
	await _act(scene, melee)
	assert_eq(scene.step, 2)
	# 3. Дальний выстрел Летописцев: дальше 5 клеток — в разборе «далеко».
	var shooter := s.active_unit()
	assert_gt(HexGrid.distance(shooter.hex, enemy.hex), DamageCalc.LONG_RANGE)
	var kinds: Array = (DamageCalc.breakdown(shooter, enemy, true)["parts"] as Array).map(func(p: Dictionary) -> StringName: return p["kind"])
	assert_true(kinds.has(&"far"))
	await _act(scene, BattleAction.shoot(enemy.uid))
	assert_eq(scene.step, 3, "последний шаг")
	# 4. Добить.
	var guard := 0
	while s.outcome == BattleState.Outcome.NONE and guard < 10:
		await _act(scene, AiController.choose_action(s, s.active_uid))
		guard += 1
	assert_eq(s.outcome, BattleState.Outcome.PLAYER_WON)
	var t0 := Time.get_ticks_msec()
	while scene._end_panel == null and Time.get_ticks_msec() - t0 < 5000:
		await wait_physics_frames(1)
	assert_not_null(scene._rework, "панель превращения")
	# Не заклинание — подсказка, Кодекс не меняется; заклинание — карта стала заклинанием героя.
	var cards: int = scene._codex_run.codex.cards.size()
	scene._on_rework(2, CodexOps.Form.SACRIFICE)
	assert_eq(scene._codex_run.codex.cards.size(), cards)
	scene._on_rework(2, CodexOps.Form.SPELL)
	assert_eq(scene._codex_run.codex.cards.size(), cards - 1)
	assert_eq(scene._codex_run.hero.spells.size(), 1)
	assert_eq(Game.profile.runs, 0, "в забеги не записано")
	assert_true(Game.profile.chronicle.is_empty())


func test_map_lesson() -> void:
	var real := RunState.create(DefsDB.load_default(), 77)
	Game.run = real
	var real_path := SaveService.current_path
	var scene: Node = load(Game.SCENE_TUTORIAL_MAP).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var run: RunState = scene.run
	assert_ne(run, real, "учебный забег")
	assert_eq(run.map.nodes.size(), 7)
	assert_eq(SaveService.current_path, scene.SAVE_PATH, "сохранение — во временный файл")
	# Не тот остров — шаг не проходит.
	scene._travel(1)
	assert_eq(scene.step, 0)
	scene._travel(0)
	assert_eq(scene.step, 1)
	assert_true(run.map.visited.has(0))
	scene._scout(2)
	assert_eq(scene.step, 2)
	assert_true(run.map.node(2).scouted)
	scene._travel(2)
	assert_eq(scene.step, 3)
	scene._walk(0)
	assert_eq(scene.step, 4)
	assert_eq(run.map.current, 0)
	assert_true(MapActions.flight_targets(run).has(4), "перелёт на остров без моста")
	scene._travel(4)
	assert_eq(scene.step, 5, "урок пройден")
	assert_eq(run.resources[RunState.AETHER], 0, "Эфир потрачен на разведку и перелёт")
	scene.queue_free()
	await wait_physics_frames(2)
	assert_eq(Game.run, real, "настоящий забег вернулся")
	assert_eq(SaveService.current_path, real_path)


func test_finish_marks_profile() -> void:
	Game.profile.prologue_done = false
	Game.tutorial_from_menu = true
	var path := Game.profile_path
	Game.profile_path = "user://test_tutorial2_profile.cfg"
	Game.finish_tutorial2()
	assert_true(Game.profile.tutorial2_done)
	assert_true(Game.profile.prologue_done)
	SafeFile.remove(Game.profile_path)
	Game.profile_path = path
	await wait_physics_frames(2)
