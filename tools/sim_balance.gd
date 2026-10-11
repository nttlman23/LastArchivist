extends SceneTree
## Балансная симуляция экспедиций: за игрока — AI отрядов, HeroAi в бою и MapAi на карте.
## Запуск: godot --headless -s res://tools/sim_balance.gd -- [runs] [school_id] [difficulty] [--upgrades=all|half|none|<id>] [--trial=N] [--unlocks=all] [--daily=<модификатор>]
## Играет «новичок»: профиль без открытий (закрытые карты и события не выпадают).
## --cards — сила карт (SPEC_SPRINT11 10): доля побед в боях с картой и доля полных забегов, где карта побывала в Кодексе.

const DEFAULT_RUNS := 200

var db: DefsDB
var stats := {}
var _profile: ProfileState
## Сила карт: id -> [боёв с картой, из них побед]; id -> [забегов с картой, из них полных побед].
var card_battles := {}
var card_runs := {}
var _run_cards := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else DEFAULT_RUNS
	db = DefsDB.load_default()
	var school_id := StringName(args[1]) if args.size() > 1 else DefsDB.DEFAULT_SCHOOL
	var difficulty := StringName(args[2]) if args.size() > 2 else Difficulty.NORMAL
	var profile := ProfileState.new()
	for s in db.schools_sorted():
		profile.unlocked.append(MetaRewards.school_unlock_id(s.id))
	# Зал Архива и Испытания (SPEC_SPRINT8): --upgrades=all|half|none|<id>, --trial=N.
	var trial := 0
	var upgrades_mode := "none"
	# Этап B Спринта 9: --daily=<модификатор> — ежедневный забег с одним модификатором (SPEC_SPRINT9 13),
	# --unlocks=all — открытия достижений (карты, реликвии, события).
	var daily_mod := &""
	var unlocks := false
	var cards := args.has("--cards")
	for arg in args:
		if arg.begins_with("--upgrades="):
			upgrades_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--trial="):
			trial = int(arg.get_slice("=", 1))
		elif arg.begins_with("--daily="):
			daily_mod = StringName(arg.get_slice("=", 1))
		elif arg == "--unlocks=all":
			unlocks = true
	_profile = profile
	for n: UpgradeNodeDef in db.hall_nodes.values():
		var take := upgrades_mode == "all" or (upgrades_mode == "half" and n.tier <= 2) or upgrades_mode == String(n.id)
		if take:
			profile.upgrades.append(n.id)
	if unlocks:
		for a in db.achievements.values():
			if a.unlock_kind != &"":
				Achievements.grant(db, profile, a.id)
		profile.points = 0
	var won := 0
	var act2 := 0
	var layers_sum := 0
	var res_sum := {RunState.INK: 0, RunState.PARCHMENT: 0, RunState.AETHER: 0}
	var deaths := {}
	for i in runs:
		var run := RunState.create(db, i * 7919 + 1, school_id, profile, difficulty, trial)
		if daily_mod != &"":
			run.modifiers = [daily_mod] as Array[StringName]
			DailyRun.apply_start(db, run)
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		_run_cards = {}
		var result := _play(run, rng)
		for id in _run_cards:
			if not card_runs.has(id):
				card_runs[id] = [0, 0]
			card_runs[id][0] += 1
			if result == "won":
				card_runs[id][1] += 1
		if result == "won":
			won += 1
		if run.act >= 2:
			act2 += 1
		else:
			deaths[result] = deaths.get(result, 0) + 1
		layers_sum += run.total_layer()
		for id in res_sum:
			res_sum[id] += run.resources[id]
	print("Школа: %s, сложность: %s, улучшения: %s, Испытание: %d" % [school_id, difficulty, upgrades_mode, trial])
	print("Экспедиций: %d, дошли до 2-го акта: %d (%.0f%%), пройдено полностью: %d (%.0f%%), средний слой %.1f" % [
		runs, act2, 100.0 * act2 / runs, won, 100.0 * won / runs, float(layers_sum) / runs])
	print("Поражения: %s" % deaths)
	for key in stats.keys():
		var s: Array = stats[key]
		print("  %-10s побед %d из %d (%.0f%%), средн. раундов %.1f" % [key, s[0], s[1], 100.0 * s[0] / maxi(1, s[1]), float(s[2]) / maxi(1, s[1])])
	# Строка для сводных таблиц: школа, сложность, улучшения, открытия, Испытание, модификатор, % 2-го акта, % побед.
	print("RESULT %s %s %s %s %d %s %.1f %.1f" % [school_id, difficulty, upgrades_mode, "unlocks" if unlocks else "-", trial,
			daily_mod if daily_mod != &"" else &"-", 100.0 * act2 / runs, 100.0 * won / runs])
	print("Остаток ресурсов в среднем: Ч %.1f · П %.1f · Э %.1f" % [float(res_sum[RunState.INK]) / runs, float(res_sum[RunState.PARCHMENT]) / runs, float(res_sum[RunState.AETHER]) / runs])
	if cards:
		_print_cards(won, runs)
	quit()


## Возвращает "won" или причину поражения.
func _play(run: RunState, rng: RandomNumberGenerator) -> String:
	while true:
		var id := MapAi.choose_node(db, run, rng)
		MapActions.travel(run, id)
		var node := run.pending()
		match node.type:
			MapState.NodeType.BATTLE, MapState.NodeType.ELITE, MapState.NodeType.RIFT:
				var key := "rift" if node.type == MapState.NodeType.RIFT else ("elite" if node.type == MapState.NodeType.ELITE else "tier%d" % db.encounter(node.content).tier)
				if run.act >= 2 and key in ["rift", "elite"]:
					key += "2"
				if not _battle(run, rng, key, node.type == MapState.NodeType.ELITE):
					return "бой:" + key
				if node.type == MapState.NodeType.RIFT:
					if run.act >= 2:
						return "won"
					# Привал: ремонт, если есть что чинить, иначе пассивка-дар.
					var options := CampOps.options(run)
					var choice: Dictionary = options[0] if CampOps.reason(db, run, options[0]) == "" else options[3]
					CampOps.apply(db, run, choice)
					# С профилем, как в игре: закрытые карты не попадают в награды второго акта.
					MapActions.begin_act(db, run, 2, _profile)
					continue
			MapState.NodeType.EVENT:
				var r := MapAi.event(db, run, id, rng)
				if r.battle_tier > 0:
					run.pending_battle = EventResolver.battle_encounter(db, run, id, r.battle_tier)
					run.pending_reward_card = r.battle_reward
					if not _battle(run, rng, "event", false):
						return "бой:event"
			MapState.NodeType.SHOP:
				MapAi.shop(db, run, ShopOps.open(db, run, id))
			MapState.NodeType.HAVEN:
				MapAi.haven(db, run)
			MapState.NodeType.RELIQUARY:
				MapAi.reliquary(db, run, id)
		MapActions.complete(run)
		if not run.codex.has_unit_cards(db):
			return "нет карт"
	return "?"


func _battle(run: RunState, rng: RandomNumberGenerator, key: String, elite: bool) -> bool:
	var selected: Array[int] = []
	for c in run.codex.unit_indices(db).slice(0, BattleState.MAX_STACKS):
		selected.append(c)
	var enc0 := db.encounter(run.current_encounter_id(db))
	MapAi.reinforce(db, run, selected, enc0.elite or enc0.boss)
	var enc := db.encounter(run.current_encounter_id(db))
	var s := BattleSetup.for_run(db, run, selected)
	var okey := key + ":" + String(s.objective) if s.objective != ObjectiveRule.ELIMINATE else key
	if s.commander_id != &"":
		okey += "+cmd"
	for i in selected:
		_run_cards[run.codex.cards[i].memory_id] = true
	BattleResolver.begin(s)
	while s.outcome == BattleState.Outcome.NONE:
		var hero := HeroAi.choose(s) if s.can_hero_act() else null
		BattleResolver.apply(s, hero if hero else AiController.choose_action(s, s.active_uid))
	if not stats.has(okey):
		stats[okey] = [0, 0, 0]
	stats[okey][1] += 1
	stats[okey][2] += s.round_number
	for i in selected:
		var mid := run.codex.cards[i].memory_id
		if not card_battles.has(mid):
			card_battles[mid] = [0, 0]
		card_battles[mid][0] += 1
		if s.outcome == BattleState.Outcome.PLAYER_WON:
			card_battles[mid][1] += 1
	if s.outcome != BattleState.Outcome.PLAYER_WON:
		return false
	stats[okey][0] += 1
	run.battles_won += 1
	run.apply_spell_charges(s.spell_charges())
	run.after_battle(db, selected, s.erased_cards)
	if enc.boss:
		return true
	var rewards := MapActions.battle_rewards(enc)
	var relic_bonus := RelicOps.battle_bonus(run)
	for id in relic_bonus:
		rewards[id] += relic_bonus[id]
	for id in rewards:
		run.gain(id, rewards[id])
	var bonus := BattleSetup.objective_bonus(run, enc)
	if bonus != &"":
		run.gain(bonus, 1)
	if run.pending_reward_card != &"" and not run.codex.is_full():
		run.codex.add(db, run.pending_reward_card)
	MapAi.post_battle(db, run, rng, elite)
	return true


## Таблица силы карт: польза = доля полных побед в забегах с картой / общая доля побед.
func _print_cards(won: int, runs: int) -> void:
	var base := float(won) / maxi(1, runs)
	var ids := card_runs.keys()
	ids.sort_custom(func(a, b) -> bool: return _use(a, base) > _use(b, base))
	print("Карта                  забегов  побед%%  польза   боёв  побед в бою%%")
	for id in ids:
		var r: Array = card_runs[id]
		var b: Array = card_battles.get(id, [0, 0])
		print("  %-20s %6d  %6.0f  %6.2f  %6d  %6.0f" % [id, r[0], 100.0 * r[1] / maxi(1, r[0]), _use(id, base), b[0], 100.0 * b[1] / maxi(1, b[0])])
		print("CARD %s %d %.3f %d %.3f" % [id, r[0], _use(id, base), b[0], float(b[1]) / maxi(1, b[0])])


func _use(id, base: float) -> float:
	var r: Array = card_runs[id]
	return (float(r[1]) / maxi(1, r[0])) / maxf(0.001, base)
