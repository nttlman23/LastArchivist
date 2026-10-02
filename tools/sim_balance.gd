extends SceneTree
## Балансная симуляция: забеги, где за игрока тоже играет AI.
## За Архивариуса — HeroAi, после боя — случайное действие: новая карта или превращение.
## Запуск: godot --headless -s res://tools/sim_balance.gd -- [runs]

const DEFAULT_RUNS := 200


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else DEFAULT_RUNS
	var db := DefsDB.load_default()
	var chain := db.encounter_chain.size()
	var reached: Array[int] = []
	reached.resize(chain + 1)
	var rounds_sum: Array[int] = []
	rounds_sum.resize(chain)
	var wins: Array[int] = []
	wins.resize(chain)
	var fought: Array[int] = []
	fought.resize(chain)
	var abilities_used := 0
	var hero_actions := 0
	var forms: Dictionary[String, int] = {}

	for i in runs:
		var run := RunState.create(db, i * 7919 + 1)
		var choice_rng := RandomNumberGenerator.new()
		choice_rng.seed = i
		var cleared := 0
		while true:
			var selected: Array[int] = []
			for c in run.codex.unit_indices(db).slice(0, BattleState.MAX_STACKS):
				selected.append(c)
			var s := BattleState.create(db, db.encounter(run.current_encounter_id(db)), run.codex, selected, run.battle_seed(), run.hero)
			fought[run.battle_index] += 1
			BattleResolver.begin(s)
			while s.outcome == BattleState.Outcome.NONE:
				var hero := HeroAi.choose(s) if s.can_hero_act() else null
				var action := hero if hero else AiController.choose_action(s, s.active_uid)
				if action.type == BattleAction.Type.ABILITY:
					abilities_used += 1
				if action.is_hero():
					hero_actions += 1
				BattleResolver.apply(s, action)
			rounds_sum[run.battle_index] += s.round_number
			if s.outcome != BattleState.Outcome.PLAYER_WON:
				break
			wins[run.battle_index] += 1
			cleared += 1
			run.apply_spell_charges(s.spell_charges())
			if run.is_last_battle(db):
				break
			run.decay_after_battle(db, selected)
			var form := _post_battle(db, run, choice_rng)
			forms[form] = forms.get(form, 0) + 1
			run.battle_index += 1
			if not run.codex.has_unit_cards(db):
				break
		reached[cleared] += 1

	print("Забегов: %d" % runs)
	for b in chain:
		print("Бой %d (%s): побед %d из %d (%.0f%%), средн. раундов %.1f" % [
			b + 1, db.encounter_chain[b], wins[b], fought[b], 100.0 * wins[b] / maxi(1, fought[b]),
			float(rounds_sum[b]) / maxi(1, fought[b])])
	print("Полностью пройдено: %d (%.0f%%)" % [reached[-1], 100.0 * reached[-1] / runs])
	print("Способностей за забег: %.1f, действий героя: %.1f" % [float(abilities_used) / runs, float(hero_actions) / runs])
	print("Выбор после боя: %s" % forms)
	quit()


## Случайно: взять карту (50%) или превратить случайную доступную карту.
func _post_battle(db: DefsDB, run: RunState, rng: RandomNumberGenerator) -> String:
	var offer := run.roll_rewards(db)
	if rng.randf() < 0.5 and not run.codex.is_full():
		run.codex.add(db, offer[rng.randi_range(0, offer.size() - 1)])
		return "card"
	var options: Array = []
	for i in run.codex.cards.size():
		for form in CodexOps.ALL_FORMS:
			if CodexOps.can_apply(db, run, i, form):
				options.append([i, form])
	# Не превращаем последнюю карту отряда.
	if options.is_empty() or run.codex.unit_indices(db).size() <= 2:
		if not run.codex.is_full():
			run.codex.add(db, offer[0])
			return "card"
		return "skip"
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	CodexOps.apply(db, run, pick[0], pick[1])
	return CodexOps.Form.keys()[pick[1]].to_lower()
