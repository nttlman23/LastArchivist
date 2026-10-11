extends SceneTree
## Сила карт отрядов (SPEC_SPRINT11 10): каждая карта по очереди воюет в одном и том же составе —
## Легион Соляных Стражей + Осколочные Лучники + проверяемая карта — против всех встреч своего акта
## (уровни, элита) на нескольких сидах. Счёт = (доля побед + доля уцелевших ОЗ армии) / 2; польза —
## счёт карты / средний счёт карт её акта. Отряды поддержки оцениваются так же: если их способность
## не помогает выиграть, это видно.
## Запуск: godot --headless -s res://tools/card_power.gd -- [сидов на встречу] [карта]

const BASE := [&"salt_legion", &"shard_archers"]

var db: DefsDB


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 6
	var only := StringName(args[1]) if args.size() > 1 else &""
	db = DefsDB.load_default()
	var scores := {}
	for act in [1, 2]:
		var encounters: Array[EncounterDef] = []
		for e: EncounterDef in db.encounters.values():
			if not e.boss and e.act == act:
				encounters.append(e)
		for id in db.memory_ids():
			var mem := db.memory(id)
			if not mem.is_unit() or mem.gift_only or mem.act != act or (only != &"" and id != only):
				continue
			scores[id] = _score(id, encounters, seeds)
	var by_act := {1: [], 2: []}
	for id in scores:
		by_act[db.memory(id).act].append(scores[id]["score"])
	print("Карта                  акт  побед%%  ОЗ%%   счёт  польза  школа")
	var ids := scores.keys()
	ids.sort_custom(func(a, b) -> bool: return scores[a]["score"] > scores[b]["score"])
	for id in ids:
		var s: Dictionary = scores[id]
		var act := db.memory(id).act
		var mean: float = (by_act[act] as Array).reduce(func(acc: float, x: float) -> float: return acc + x, 0.0) / maxi(1, (by_act[act] as Array).size())
		var school := db.memory_school(id)
		print("  %-20s %3d  %6.0f  %5.0f  %5.3f  %6.2f  %s" % [id, act, 100.0 * s["win"], 100.0 * s["hp"], s["score"], s["score"] / maxf(0.001, mean), school if school != &"" else "общая"])
		print("POWER %s %d %.3f %.3f %.3f" % [id, act, s["win"], s["hp"], s["score"] / maxf(0.001, mean)])
	quit()


func _score(id: StringName, encounters: Array[EncounterDef], seeds: int) -> Dictionary:
	var codex := CodexState.new()
	for b in BASE:
		codex.add(db, b)
	codex.add(db, id)
	var selected: Array[int] = [0, 1, 2]
	var wins := 0
	var hp_sum := 0.0
	var n := 0
	for e in encounters:
		for seed_value in seeds:
			var s := BattleState.create(db, e, codex, selected, seed_value * 131 + e.id.hash() % 1000)
			var start := 0
			for u in s.alive(UnitState.Side.PLAYER):
				start += u.total_hp()
			BattleResolver.begin(s)
			var guard := 0
			while s.outcome == BattleState.Outcome.NONE and guard < 2000:
				BattleResolver.apply(s, AiController.choose_action(s, s.active_uid))
				guard += 1
			n += 1
			if s.outcome == BattleState.Outcome.PLAYER_WON:
				wins += 1
				var left := 0
				for u in s.alive(UnitState.Side.PLAYER):
					left += u.total_hp()
				hp_sum += float(left) / maxi(1, start)
	var win := float(wins) / maxi(1, n)
	var hp := hp_sum / maxi(1, n)
	return {"win": win, "hp": hp, "score": (win + hp) * 0.5}
