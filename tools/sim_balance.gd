extends SceneTree
## Балансная симуляция: забеги, где за игрока тоже играет AI.
## Запуск: godot --headless -s res://tools/sim_balance.gd -- [runs]

const DEFAULT_RUNS := 200


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else DEFAULT_RUNS
	var db := DefsDB.load_default()
	var reached: Array[int] = []
	reached.resize(db.encounter_chain.size() + 1)
	var rounds_sum: Array[int] = []
	rounds_sum.resize(db.encounter_chain.size())
	var wins_per_battle: Array[int] = []
	wins_per_battle.resize(db.encounter_chain.size())

	for i in runs:
		var run := RunState.create(db, i * 7919 + 1)
		var cleared := 0
		while true:
			var selected: Array[int] = []
			for c in mini(BattleState.MAX_STACKS, run.codex.cards.size()):
				selected.append(c)
			var s := BattleState.create(db, db.encounter(run.current_encounter_id(db)), run.codex, selected, run.battle_seed())
			BattleResolver.begin(s)
			while s.outcome == BattleState.Outcome.NONE:
				BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
			rounds_sum[run.battle_index] += s.round_number
			if s.outcome != BattleState.Outcome.PLAYER_WON:
				break
			wins_per_battle[run.battle_index] += 1
			cleared += 1
			run.codex.decay(selected)
			if run.is_last_battle(db):
				break
			# Награда: берём первую предложенную карту, если есть место.
			var offer := run.roll_rewards(db)
			if not run.codex.is_full():
				run.codex.add(db, offer[0])
			run.battle_index += 1
			if not run.codex.has_unit_cards():
				break
		reached[cleared] += 1

	print("Забегов: %d" % runs)
	for b in db.encounter_chain.size():
		var fought := runs - _sum(reached.slice(0, b))
		print("Бой %d (%s): побед %d из %d, средн. раундов %.1f" % [
			b + 1, db.encounter_chain[b], wins_per_battle[b], fought,
			float(rounds_sum[b]) / maxi(1, fought)])
	print("Полностью пройдено: %d (%.0f%%)" % [reached[-1], 100.0 * reached[-1] / runs])
	quit()


func _sum(arr: Array) -> int:
	var total := 0
	for v: int in arr:
		total += v
	return total
