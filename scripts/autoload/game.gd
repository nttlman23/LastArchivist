extends Node
## Глобальная точка входа: реестр данных, текущий забег, переходы между экранами.

const SCENE_MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SCENE_PREP := "res://scenes/prep/prep.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_REWARD := "res://scenes/reward/reward.tscn"
const SCENE_RUN_END := "res://scenes/run_end/run_end.tscn"

const FONT_SIZE := 22

var defs: DefsDB
var run: RunState
## Индексы карт Кодекса, выбранных на текущий бой.
var selected: Array[int] = []
## Карты, угасшие после последнего боя (для экрана награды).
var last_faded: Array[StringName] = []
var run_won := false


func _ready() -> void:
	defs = DefsDB.load_default()
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	get_tree().root.theme = theme
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_test()


## Проверка собранной игры: `LastArchivist.exe --headless -- --smoke`.
## Печатает SMOKE OK/FAIL и завершает процесс с кодом 0/1.
func _smoke_test() -> void:
	var ok := defs.units.size() > 0 and defs.memories.size() > 0
	for id in defs.encounter_chain:
		ok = ok and defs.encounters.has(id)
	var outcome := BattleState.Outcome.NONE
	if ok:
		var test_run := RunState.create(defs, 1)
		var cards: Array[int] = [0, 1, 2, 3]
		var s := BattleState.create(defs, defs.encounter(defs.encounter_chain[0]), test_run.codex, cards, 1)
		BattleResolver.begin(s)
		while s.outcome == BattleState.Outcome.NONE:
			BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
		outcome = s.outcome
		ok = outcome != BattleState.Outcome.NONE
	print("SMOKE %s: units=%d memories=%d encounters=%d battle=%s" % [
		"OK" if ok else "FAIL", defs.units.size(), defs.memories.size(), defs.encounters.size(),
		BattleState.Outcome.keys()[outcome]])
	get_tree().quit(0 if ok else 1)


func new_run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run = RunState.create(defs, rng.seed)
	SaveService.save_run(run)
	goto(SCENE_PREP)


func continue_run() -> bool:
	run = SaveService.load_run()
	if run == null:
		return false
	goto(SCENE_PREP)
	return true


func start_battle(cards: Array[int]) -> void:
	selected = cards.duplicate()
	goto(SCENE_BATTLE)


## Выход из боя без результата: возврат к подготовке с тем же seed.
func abandon_battle() -> void:
	goto(SCENE_PREP)


func finish_battle(outcome: BattleState.Outcome) -> void:
	if outcome != BattleState.Outcome.PLAYER_WON:
		_end_run(false)
		return
	last_faded = run.codex.decay(selected)
	if run.is_last_battle(defs):
		_end_run(true)
		return
	goto(SCENE_REWARD)


## Вызывается экраном награды после выбора (или пропуска).
func complete_reward() -> void:
	run.battle_index += 1
	if not run.codex.has_unit_cards():
		_end_run(false)
		return
	SaveService.save_run(run)
	goto(SCENE_PREP)


func to_main_menu() -> void:
	goto(SCENE_MAIN_MENU)


func goto(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene)


func _end_run(won: bool) -> void:
	run_won = won
	SaveService.delete_save()
	goto(SCENE_RUN_END)
