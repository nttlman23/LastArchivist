extends SceneTree
## Балансная симуляция экспедиций: за игрока — AI отрядов, HeroAi в бою и MapAi на карте.
## Запуск: godot --headless -s res://tools/sim_balance.gd -- [runs] [school_id] [difficulty]
## Играет «новичок»: профиль без открытий (закрытые карты и события не выпадают).

const DEFAULT_RUNS := 200

var db: DefsDB
var stats := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else DEFAULT_RUNS
	db = DefsDB.load_default()
	var school_id := StringName(args[1]) if args.size() > 1 else DefsDB.DEFAULT_SCHOOL
	var difficulty := StringName(args[2]) if args.size() > 2 else Difficulty.NORMAL
	var profile := ProfileState.new()
	for s in db.schools_sorted():
		profile.unlocked.append(MetaRewards.school_unlock_id(s.id))
	var won := 0
	var layers_sum := 0
	var res_sum := {RunState.INK: 0, RunState.PARCHMENT: 0, RunState.AETHER: 0}
	var deaths := {}
	for i in runs:
		var run := RunState.create(db, i * 7919 + 1, school_id, profile, difficulty)
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var result := _play(run, rng)
		if result == "won":
			won += 1
		else:
			deaths[result] = deaths.get(result, 0) + 1
		layers_sum += run.map.current_layer()
		for id in res_sum:
			res_sum[id] += run.resources[id]
	print("Школа: %s, сложность: %s" % [school_id, difficulty])
	print("Экспедиций: %d, пройдено полностью: %d (%.0f%%), средний слой %.1f" % [runs, won, 100.0 * won / runs, float(layers_sum) / runs])
	print("Поражения: %s" % deaths)
	for key in stats.keys():
		var s: Array = stats[key]
		print("  %-10s побед %d из %d (%.0f%%), средн. раундов %.1f" % [key, s[0], s[1], 100.0 * s[0] / maxi(1, s[1]), float(s[2]) / maxi(1, s[1])])
	print("Остаток ресурсов в среднем: Ч %.1f · П %.1f · Э %.1f" % [float(res_sum[RunState.INK]) / runs, float(res_sum[RunState.PARCHMENT]) / runs, float(res_sum[RunState.AETHER]) / runs])
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
				if not _battle(run, rng, key, node.type == MapState.NodeType.ELITE):
					return "бой:" + key
				if node.type == MapState.NodeType.RIFT:
					return "won"
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
		MapActions.complete(run)
		if not run.codex.has_unit_cards(db):
			return "нет карт"
	return "?"


func _battle(run: RunState, rng: RandomNumberGenerator, key: String, elite: bool) -> bool:
	var selected: Array[int] = []
	for c in run.codex.unit_indices(db).slice(0, BattleState.MAX_STACKS):
		selected.append(c)
	var enc := db.encounter(run.current_encounter_id(db))
	var s := BattleSetup.for_run(db, run, selected)
	var okey := key + ":" + String(s.objective) if s.objective != ObjectiveRule.ELIMINATE else key
	if s.commander_id != &"":
		okey += "+cmd"
	BattleResolver.begin(s)
	while s.outcome == BattleState.Outcome.NONE:
		var hero := HeroAi.choose(s) if s.can_hero_act() else null
		BattleResolver.apply(s, hero if hero else AiController.choose_action(s, s.active_uid))
	if not stats.has(okey):
		stats[okey] = [0, 0, 0]
	stats[okey][1] += 1
	stats[okey][2] += s.round_number
	if s.outcome != BattleState.Outcome.PLAYER_WON:
		return false
	stats[okey][0] += 1
	run.battles_won += 1
	run.apply_spell_charges(s.spell_charges())
	run.after_battle(db, selected, s.erased_cards)
	if enc.boss:
		return true
	var rewards := MapActions.battle_rewards(enc)
	for id in rewards:
		run.gain(id, rewards[id])
	var bonus := BattleSetup.objective_bonus(run, enc)
	if bonus != &"":
		run.gain(bonus, 1)
	if run.pending_reward_card != &"" and not run.codex.is_full():
		run.codex.add(db, run.pending_reward_card)
	MapAi.post_battle(db, run, rng, elite)
	return true
