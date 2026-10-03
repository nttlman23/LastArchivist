extends Node
## Сквозной прогон экспедиции через настоящие экраны: карта → острова (бой, событие, лавка, гавань) → разлом → итог.
## За игрока: AI отрядов и HeroAi в бою, MapAi на карте; после боя чередуются формы переработки.
## Запуск: godot --path . res://tools/autoplay.tscn [-- seed [school_id [difficulty]]]  (можно с --headless)
## Печатает AUTOPLAY OK/FAIL и путь забега.

const TIMEOUT_SEC := 900.0

var _log: Array[String] = []
var _start := 0
var _battles := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Узел переживает смену сцен: вешаем его на корень, а не на текущую сцену.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	_start = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 7
	_rng.seed = seed_value
	# Свой профиль и сохранение не трогаем: автопрогон пишет в отдельный профиль.
	# Свои файлы у каждого процесса: автопрогоны можно запускать параллельно.
	Game.profile_path = "user://autoplay_profile_%d.cfg" % OS.get_process_id()
	SaveService.current_path = "user://autoplay_save_%d.json" % OS.get_process_id()
	Game.profile = ProfileState.new()
	Settings.hints = false
	var school := StringName(args[1]) if args.size() > 1 else DefsDB.DEFAULT_SCHOOL
	var difficulty := StringName(args[2]) if args.size() > 2 else Difficulty.NORMAL
	_log.append("школа: %s, сложность: %s" % [school, difficulty])
	Game.run = RunState.create(Game.defs, seed_value, school, Game.profile, difficulty)
	SaveService.save_run(Game.run)
	Game.goto(Game.SCENE_MAP)
	while _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null:
			continue
		await _frames(3)
		match scene.scene_file_path:
			Game.SCENE_MAP:
				var id := MapAi.choose_node(Game.defs, Game.run, _rng)
				var n := Game.run.map.node(id)
				_log.append("слой %d: %s" % [n.layer, MapState.NodeType.keys()[n.type]])
				scene._travel(id)
			Game.SCENE_PREP:
				scene._on_start()
			Game.SCENE_BATTLE:
				await _play_battle(scene)
				continue
			Game.SCENE_REWARD:
				_post_battle(scene)
			Game.SCENE_EVENT:
				await _play_event(scene)
				continue
			Game.SCENE_SHOP:
				MapAi.shop(Game.defs, Game.run, scene.visit)
				_log.append("  лавка: %s" % UiKit.resources_text(Game.run.resources))
				Game.complete_node()
			Game.SCENE_HAVEN:
				MapAi.haven(Game.defs, Game.run)
				Game.complete_node()
			Game.SCENE_RUN_END:
				_log.append("итог: %s, слой %d, побед %d" % ["победа" if Game.run_won else "поражение", Game.run.map.current_layer(), Game.run.battles_won])
				_finish(true)
				return
		await _wait_scene_change(scene)
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
		scene._player_act(hero if hero else AiController.choose_action(state, state.active_uid))
	while scene._end_panel == null and _elapsed() < TIMEOUT_SEC:
		await get_tree().process_frame
	_log.append("  бой %s: %s за %d р., стёрто %d" % [state.units[-1].def_id if state.rift else &"", BattleState.Outcome.keys()[state.outcome], state.round_number, state.erased_cards.size()])
	Game.finish_battle(state.outcome, state.spell_charges(), state.erased_cards)
	await _wait_scene_change(scene)


func _play_event(scene: Node) -> void:
	var ev: EventDef = scene.event
	var options: Array[int] = []
	for i in ev.options.size():
		if EventResolver.option_reason(Game.defs, Game.run, ev.options[i]) == "":
			options.append(i)
	var pick := options[_rng.randi_range(0, options.size() - 1)]
	var card := -1
	if (ev.options[pick] as EventOptionDef).needs_card:
		card = Game.run.codex.unit_indices(Game.defs)[0]
	scene._resolve(pick, card)
	_log.append("  событие %s → вариант %d%s" % [ev.id, pick, " → бой" if scene._result.battle_tier > 0 else ""])
	await _frames(2)
	scene._continue()
	await _wait_scene_change(scene)


## Чередуем: новая карта или превращение (если форма недоступна — карта).
func _post_battle(scene: Node) -> void:
	var run := Game.run
	if _battles % 2 == 1:
		for form in [CodexOps.Form.UPGRADE, CodexOps.Form.SPELL, CodexOps.Form.FUSE]:
			for i in run.codex.cards.size():
				if CodexOps.can_apply(Game.defs, run, i, form) and run.codex.unit_indices(Game.defs).size() > 3:
					_log.append("  память: %s «%s»" % [CodexOps.Form.keys()[form], run.codex.cards[i].memory_id])
					scene._on_select_card(i)
					scene._apply_form(form)
					return
	_log.append("  память: новая карта")
	scene._on_pick(scene._offer[0])
	if run.codex.is_full():
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
	SafeFile.remove(Game.profile_path)
	SafeFile.remove(SaveService.current_path)
	get_tree().quit(0 if ok else 1)
