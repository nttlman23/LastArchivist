extends Node
## Профилировщик (SPEC_SPRINT6 11): бой в покое, бой с движением мыши, массовый бой с эффектами,
## карта и главное меню. Для каждого сценария: средний FPS, средний и худший кадр, число кадров
## дольше 33 мс, draw calls, узлы. Полные эффекты, скорость анимаций 1×.
## Запуск: godot --path . res://tools/profile_battle.tscn (нужно окно, не --headless).
## Профиль и сохранение — временные: данные игрока не трогаются.

const PHASE_TIME := 3.0
const WARMUP_FRAMES := 10
const SLOW_FRAME_US := 33000

var frames := 0
var frame_us_total := 0
var frame_us_max := 0
var slow := 0
var last := 0
var phase := ""
var hover_us_total := 0
var process_total := 0.0
var hover_calls := 0


func _ready() -> void:
	# Профилировщик переживает смену сцен: переносим его в корень дерева.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	Game.profile_path = "user://profile_tool.cfg"
	Game.profile = ProfileState.new()
	SaveService.current_path = "user://profile_tool_save.json"
	Settings.hints = false
	Settings.effects_full = true
	Settings.anim_speed = 1.0
	Settings.screen_shake = true

	var screen := await _open_battle(&"")
	await _measure("battle_idle")
	_reset("battle_mouse")
	var view: BattleView = screen.view
	var origin := view.get_global_transform_with_canvas()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < PHASE_TIME * 1000:
		var k := (Time.get_ticks_msec() - t0) / (PHASE_TIME * 1000.0)
		var pos := origin * Vector2(900 * k, 300 + 200 * sin(k * 20))
		# Реальная мышь шлёт несколько событий за кадр.
		for i in 4:
			get_viewport().warp_mouse(pos)
			var u0 := Time.get_ticks_usec()
			screen._update_hover()
			hover_us_total += Time.get_ticks_usec() - u0
			hover_calls += 1
		await get_tree().process_frame
	_report()
	print("hover avg us: %.0f over %d calls" % [float(hover_us_total) / maxi(1, hover_calls), hover_calls])

	# Массовый бой: элитная встреча, пять отрядов, ходы игрока делает AI — все анимации и эффекты.
	screen = await _open_battle(&"elite_fortress")
	_reset("battle_fight")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < PHASE_TIME * 2000 and screen.state.outcome == BattleState.Outcome.NONE:
		if not screen._busy and screen._is_player_turn():
			var s: BattleState = screen.state
			var hero := HeroAi.choose(s) if s.can_hero_act() else null
			screen._player_act(hero if hero else AiController.choose_action(s, s.active_uid))
		await get_tree().process_frame
	_report()

	# Бой второго акта: вода, течения, босс с намерениями (SPEC_SPRINT7 10).
	screen = await _open_battle(&"abyss")
	await _measure("battle_act2_idle")
	_reset("battle_act2_fight")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < PHASE_TIME * 2000 and screen.state.outcome == BattleState.Outcome.NONE:
		if not screen._busy and screen._is_player_turn():
			var s2: BattleState = screen.state
			var hero2 := HeroAi.choose(s2) if s2.can_hero_act() else null
			screen._player_act(hero2 if hero2 else AiController.choose_action(s2, s2.active_uid))
		await get_tree().process_frame
	_report()

	Game.goto(Game.SCENE_MAP)
	await get_tree().create_timer(1.0).timeout
	await _measure("map_idle")
	Game.run = null
	Game.goto(Game.SCENE_MAIN_MENU)
	await get_tree().create_timer(1.0).timeout
	await _measure("menu_idle")
	SafeFile.remove(Game.profile_path)
	SafeFile.remove(SaveService.current_path)
	Game.quit_game()


## Бой на первом острове (или заданной встрече) с полным Кодексом из пяти отрядов.
func _open_battle(encounter: StringName) -> Node:
	Game.run = RunState.create(Game.defs, 1)
	for id in [&"shard_archers", &"ghoul_pack"]:
		Game.run.codex.add(Game.defs, id)
	MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])
	if encounter != &"":
		Game.run.pending_battle = encounter
	Game.selected = [0, 1, 2, 3, 4]
	# Заклинания героя — чтобы в бою были вспышки и частицы магии.
	for id in [&"chain_spell", &"shard_rain", &"hunger"]:
		Game.run.hero.spells.append(HeroState.SpellSlot.new(id, 3))
	Game.goto(Game.SCENE_BATTLE)
	await get_tree().create_timer(1.5).timeout
	return get_tree().current_scene


func _measure(p: String) -> void:
	_reset(p)
	await get_tree().create_timer(PHASE_TIME).timeout
	_report()


func _reset(p: String) -> void:
	phase = p
	frames = 0
	frame_us_total = 0
	frame_us_max = 0
	slow = 0
	process_total = 0.0
	last = Time.get_ticks_usec()


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := now - last
	last = now
	frames += 1
	if frames <= WARMUP_FRAMES:
		return
	frame_us_total += dt
	frame_us_max = maxi(frame_us_max, dt)
	process_total += Performance.get_monitor(Performance.TIME_PROCESS)
	if dt > SLOW_FRAME_US:
		slow += 1


func _report() -> void:
	var n := maxi(1, frames - WARMUP_FRAMES)
	var avg := frame_us_total / 1000.0 / n
	print("[%s] fps=%.0f avg_frame_ms=%.2f max_frame_ms=%.2f slow_frames=%d/%d cpu_process_ms=%.2f draw_calls=%d nodes=%d" % [
		phase, 1000.0 / maxf(avg, 0.001), avg, frame_us_max / 1000.0, slow, n, process_total * 1000.0 / n,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
