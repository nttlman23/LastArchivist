extends Node
## Сквозной прогон через настоящие экраны: меню → подготовка → бой → память после боя → … → итог.
## За игрока ходит AI отрядов и HeroAi, после боя чередуются формы переработки.
## Запуск: godot --path . res://tools/autoplay.tscn [-- seed]  (окно нужно для сцен; можно с --headless)
## Печатает AUTOPLAY OK/FAIL и путь забега.

const TIMEOUT_SEC := 600.0

var _log: Array[String] = []
var _start := 0
var _forms := [CodexOps.Form.SPELL, CodexOps.Form.UPGRADE, CodexOps.Form.FUSE, CodexOps.Form.SACRIFICE]
var _battles := 0


func _ready() -> void:
	# Узел переживает смену сцен: вешаем его на корень, а не на текущую сцену.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	_start = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 7
	Game.run = RunState.create(Game.defs, seed_value)
	SaveService.save_run(Game.run)
	Game.goto(Game.SCENE_PREP)
	while _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null:
			continue
		match scene.scene_file_path:
			Game.SCENE_PREP:
				await _frames(3)
				_log.append("prep %d: %d карт" % [Game.run.battle_index + 1, Game.run.codex.cards.size()])
				scene._on_start()
				await _wait_scene_change(scene)
			Game.SCENE_BATTLE:
				await _play_battle(scene)
			Game.SCENE_REWARD:
				await _frames(3)
				_post_battle(scene)
				await _wait_scene_change(scene)
			Game.SCENE_RUN_END:
				_log.append("итог: %s" % ("победа" if Game.run_won else "поражение"))
				_finish(true)
				return
	_log.append("таймаут")
	_finish(false)


func _play_battle(scene: Node) -> void:
	_battles += 1
	var state: BattleState = scene.state
	while state.outcome == BattleState.Outcome.NONE and _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
		if scene._busy:
			continue
		var hero := HeroAi.choose(state)
		var action := hero if hero else AiController.choose_action(state, state.active_uid)
		scene._player_act(action)
	# Ждём, пока доиграют анимации и появится итог боя.
	while scene._end_panel == null and _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
	_log.append("бой %d: %s за %d раундов" % [Game.run.battle_index + 1, BattleState.Outcome.keys()[state.outcome], state.round_number])
	Game.finish_battle(state.outcome, state.spell_charges())
	await _wait_scene_change(scene)


## Чередуем: новая карта, затем превращения по кругу (если форма недоступна — берём карту).
func _post_battle(scene: Node) -> void:
	var run := Game.run
	var form: CodexOps.Form = _forms[_battles % _forms.size()]
	if _battles % 2 == 1:
		for i in run.codex.cards.size():
			if CodexOps.can_apply(Game.defs, run, i, form):
				_log.append("память: %s «%s»" % [CodexOps.Form.keys()[form], run.codex.cards[i].memory_id])
				scene._on_select_card(i)
				scene._apply_form(form)
				return
	_log.append("память: новая карта")
	scene._on_pick(scene._offer[0])
	if not run.codex.is_full():
		return
	scene._on_discard(0)


func _wait_scene_change(old: Node) -> void:
	while is_instance_valid(old) and get_tree().current_scene == old and _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start) / 1000.0


func _finish(ok: bool) -> void:
	for line in _log:
		print(line)
	print("AUTOPLAY %s за %.0f с" % ["OK" if ok else "FAIL", _elapsed()])
	SaveService.delete_save()
	get_tree().quit(0 if ok else 1)
