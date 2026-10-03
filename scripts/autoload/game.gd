extends Node
## Глобальная точка входа: реестр данных, текущий забег, переходы между экранами.

const SCENE_MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_PREP := "res://scenes/prep/prep.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_REWARD := "res://scenes/reward/reward.tscn"
const SCENE_EVENT := "res://scenes/event/event.tscn"
const SCENE_SHOP := "res://scenes/shop/shop.tscn"
const SCENE_HAVEN := "res://scenes/haven/haven.tscn"
const SCENE_RUN_END := "res://scenes/run_end/run_end.tscn"
const SCENE_SCHOOL := "res://scenes/school/school.tscn"
const SCENE_META := "res://scenes/meta/meta.tscn"
const SCENE_SETTINGS := "res://scenes/settings/settings.tscn"
const SCENE_CHRONICLE := "res://scenes/chronicle/chronicle.tscn"

const FONT_SIZE := 22

var defs: DefsDB
var run: RunState
## Индексы карт Кодекса, выбранных на текущий бой.
var selected: Array[int] = []
## Карты, угасшие или стёртые после последнего боя (для экрана награды).
var last_faded: Array[StringName] = []
## Ресурсы, полученные за последний бой.
var last_rewards: Dictionary[StringName, int] = {}
var run_won := false
## Очки памяти, начисленные за последний завершённый забег.
var last_points := 0
var profile: ProfileState
var profile_path := ProfileState.DEFAULT_PATH


func _ready() -> void:
	defs = DefsDB.load_default()
	profile = ProfileState.load_or_new(profile_path)
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	get_tree().root.theme = theme
	Audio.play_music(&"menu")
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_test()


## Проверка собранной игры: `LastArchivist.exe --headless -- --smoke`.
## Печатает SMOKE OK/FAIL и завершает процесс с кодом 0/1.
func _smoke_test() -> void:
	var ok := not (defs.units.is_empty() or defs.memories.is_empty() or defs.abilities.is_empty()
			or defs.spells.is_empty() or defs.orders.is_empty() or defs.upgrades.is_empty() or defs.events.is_empty())
	var outcome := BattleState.Outcome.NONE
	var nodes := 0
	if ok:
		var test_run := RunState.create(defs, 1)
		nodes = test_run.map.nodes.size()
		ok = nodes > MapState.LAYERS
		var cards: Array[int] = [0, 1, 2, 3]
		var s := BattleState.create(defs, defs.encounter(test_run.map.node(test_run.map.next_of(MapState.START)[0]).content),
				test_run.codex, cards, 1, test_run.hero)
		BattleResolver.begin(s)
		while s.outcome == BattleState.Outcome.NONE:
			BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
		outcome = s.outcome
		ok = ok and outcome != BattleState.Outcome.NONE
	print("SMOKE %s: units=%d memories=%d encounters=%d events=%d map_nodes=%d battle=%s" % [
		"OK" if ok else "FAIL", defs.units.size(), defs.memories.size(), defs.encounters.size(),
		defs.events.size(), nodes, BattleState.Outcome.keys()[outcome]])
	get_tree().quit(0 if ok else 1)


func new_run(school_id: StringName = DefsDB.DEFAULT_SCHOOL, difficulty: StringName = Difficulty.NORMAL) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Новый забег поверх сохранённого — старый попадает в летопись как брошенный.
	var old := SaveService.load_run()
	if old:
		MetaRewards.abandon_run(profile, old)
		save_profile()
	run = RunState.create(defs, rng.seed, school_id, profile, difficulty)
	SaveService.save_run(run)
	goto(SCENE_MAP)


func save_profile() -> void:
	profile.save(profile_path)


## Пассивка школы текущего забега — для создания боя.
func school_passive() -> StringName:
	return defs.school(run.school_id).passive_id if run else &""


func continue_run() -> bool:
	run = SaveService.load_run()
	if run == null:
		return false
	goto(SCENE_MAP)
	return true


## Вход на остров карты (по мосту или перелётом). Выбор сразу сохраняется:
## выход с острова возвращает к нему же, а не к выбору пути.
func enter_node(node_id: int) -> bool:
	if not MapActions.travel(run, node_id):
		return false
	SaveService.save_run(run)
	resume_node()
	return true


## Открывает экран текущего (начатого) острова.
func resume_node() -> void:
	match run.pending().type:
		MapState.NodeType.BATTLE, MapState.NodeType.ELITE, MapState.NodeType.RIFT:
			goto(SCENE_PREP)
		MapState.NodeType.EVENT:
			goto(SCENE_EVENT)
		MapState.NodeType.SHOP:
			goto(SCENE_SHOP)
		MapState.NodeType.HAVEN:
			goto(SCENE_HAVEN)


## Событие начало бой: встреча уровня tier, после победы — карта reward (если задана).
func start_event_battle(tier: int, reward: StringName) -> void:
	run.pending_battle = EventResolver.battle_encounter(defs, run, run.pending_node, tier)
	run.pending_reward_card = reward
	goto(SCENE_PREP)


func start_battle(cards: Array[int]) -> void:
	selected = cards.duplicate()
	goto(SCENE_BATTLE)


## Выход с острова без результата: забег возвращается к чекпоинту входа на остров.
func abandon_node() -> void:
	var saved := SaveService.load_run()
	if saved:
		run = saved
	goto(SCENE_MAP)


func finish_battle(outcome: BattleState.Outcome, spell_charges: Array[int] = [], erased: Array[int] = []) -> void:
	if outcome != BattleState.Outcome.PLAYER_WON:
		_end_run(false)
		return
	run.battles_won += 1
	if run.pending() and run.pending().type == MapState.NodeType.ELITE and run.pending_battle == &"":
		run.elites_won += 1
	run.apply_spell_charges(spell_charges)
	var encounter := defs.encounter(run.current_encounter_id(defs))
	last_faded = run.after_battle(defs, selected, erased)
	if encounter.boss:
		_end_run(true)
		return
	last_rewards = MapActions.battle_rewards(encounter)
	var bonus := BattleSetup.objective_bonus(run, encounter)
	if bonus != &"":
		last_rewards[bonus] += 1
	for id in last_rewards:
		run.gain(id, last_rewards[id])
	if run.pending_reward_card != &"" and not run.codex.is_full():
		run.codex.add(defs, run.pending_reward_card)
		last_faded.erase(run.pending_reward_card)
	goto(SCENE_REWARD)


## Награда за элитный бой гарантирует геройскую карту среди предложенных.
func reward_guarantees_hero() -> bool:
	return run.pending() != null and run.pending().type == MapState.NodeType.ELITE and run.pending_battle == &""


## Остров пройден (после награды, события, лавки или гавани): возврат на карту.
func complete_node() -> void:
	MapActions.complete(run)
	if not run.codex.has_unit_cards(defs):
		_end_run(false)
		return
	SaveService.save_run(run)
	goto(SCENE_MAP)


## Совместимость с экраном награды.
func complete_reward() -> void:
	complete_node()


func to_main_menu() -> void:
	goto(SCENE_MAIN_MENU)


func goto(scene: String) -> void:
	Audio.play_music(&"battle" if scene == SCENE_BATTLE else &"menu")
	get_tree().change_scene_to_file.call_deferred(scene)


func _end_run(won: bool) -> void:
	run_won = won
	last_points = MetaRewards.finish_run(profile, run, won, defs)
	save_profile()
	SaveService.delete_save()
	goto(SCENE_RUN_END)
