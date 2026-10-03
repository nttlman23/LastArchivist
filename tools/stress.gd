extends SceneTree
## Стресс-тест боёв (SPEC_SPRINT6 12): все встречи × сложности × школы × сиды.
## Запуск: godot --headless --path . -s res://tools/stress.gd -- [боёв на сочетание]
## Проверяет: бой заканчивается (лимит действий), детерминизм по сиду, сохранение посреди боя
## не меняет исход; меряет время хода AI и предсказания намерений. Код выхода 1 — есть сбои.

const ACTION_LIMIT := 3000
const CHECK_EVERY := 7
const SAVE_AT := 15

var db: DefsDB
var failures: Array[String] = []
var battles := 0
var actions_total := 0
var ai_us_total := 0
var ai_calls := 0
var ai_us_max := 0
var intent_us_max := 0
var outcomes := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var per_combo := int(args[0]) if args.size() > 0 else 3
	db = DefsDB.load_default()
	var t0 := Time.get_ticks_msec()
	var ids: Array = db.encounters.keys()
	ids.sort()
	var commanders := db.commander_ids()
	for school in db.schools_sorted():
		for difficulty in Difficulty.ALL:
			for enc_id: StringName in ids:
				for k in per_combo:
					var seed_value := hash("%s|%s|%s|%d" % [school.id, difficulty, enc_id, k])
					var rng := RandomNumberGenerator.new()
					rng.seed = seed_value
					var commander: StringName = commanders[rng.randi_range(0, commanders.size() - 1)] if rng.randf() < 0.5 else &""
					_one(school, difficulty, enc_id, seed_value, commander, rng, battles % CHECK_EVERY == 0)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("STRESS: боёв %d за %.1f с, действий %d, сбоев %d" % [battles, secs, actions_total, failures.size()])
	print("  исходы: %s" % outcomes)
	print("  ход AI: в среднем %.2f мс, максимум %.2f мс; предсказание намерений: максимум %.2f мс" % [
		ai_us_total / 1000.0 / maxi(1, ai_calls), ai_us_max / 1000.0, intent_us_max / 1000.0])
	for f in failures.slice(0, 20):
		print("  СБОЙ: " + f)
	quit(1 if not failures.is_empty() else 0)


func _codex(school: SchoolDef, rng: RandomNumberGenerator) -> CodexState:
	var c := CodexState.new()
	for id in school.starting_codex:
		c.add(db, id)
	var pool := db.memory_ids()
	for i in rng.randi_range(0, 3):
		if not c.is_full():
			c.add(db, pool[rng.randi_range(0, pool.size() - 1)])
	return c


func _create(school: SchoolDef, difficulty: StringName, enc_id: StringName, seed_value: int, commander: StringName, rng: RandomNumberGenerator) -> BattleState:
	var codex := _codex(school, rng)
	var selected: Array[int] = []
	for i in codex.unit_indices(db).slice(0, BattleState.MAX_STACKS):
		selected.append(i)
	var hero := HeroState.new()
	var s := BattleState.create(db, db.encounter(enc_id), codex, selected, seed_value, hero, school.passive_id, difficulty, commander)
	BattleResolver.begin(s)
	return s


func _step(s: BattleState) -> void:
	var t := Time.get_ticks_usec()
	var hero := HeroAi.choose(s) if s.can_hero_act() else null
	var a := hero if hero else AiController.choose_action(s, s.active_uid)
	var dt := Time.get_ticks_usec() - t
	ai_us_total += dt
	ai_calls += 1
	ai_us_max = maxi(ai_us_max, dt)
	BattleResolver.apply(s, a)


func _play(s: BattleState, limit: int = ACTION_LIMIT) -> int:
	var n := 0
	while s.outcome == BattleState.Outcome.NONE and n < limit:
		if s.active_unit() and s.active_unit().side == UnitState.Side.PLAYER and n % 5 == 0:
			var t := Time.get_ticks_usec()
			EnemyIntents.predict(s)
			intent_us_max = maxi(intent_us_max, Time.get_ticks_usec() - t)
		_step(s)
		n += 1
	return n


func _one(school: SchoolDef, difficulty: StringName, enc_id: StringName, seed_value: int, commander: StringName, rng: RandomNumberGenerator, check: bool) -> void:
	battles += 1
	var label := "%s/%s/%s/%d" % [school.id, difficulty, enc_id, seed_value]
	var rng_state := rng.state
	var s := _create(school, difficulty, enc_id, seed_value, commander, rng)
	var n := _play(s)
	actions_total += n
	var key: String = BattleState.Outcome.keys()[s.outcome]
	outcomes[key] = outcomes.get(key, 0) + 1
	if s.outcome == BattleState.Outcome.NONE:
		failures.append("%s: не закончился за %d действий" % [label, ACTION_LIMIT])
		return
	if not check:
		return
	# Детерминизм: тот же сид — тот же бой.
	rng.state = rng_state
	var again := _create(school, difficulty, enc_id, seed_value, commander, rng)
	_play(again)
	if JSON.stringify(again.to_dict()) != JSON.stringify(s.to_dict()):
		failures.append("%s: повтор по сиду разошёлся" % label)
	# Сохранение посреди боя не меняет исход.
	rng.state = rng_state
	var a := _create(school, difficulty, enc_id, seed_value, commander, rng)
	_play(a, SAVE_AT)
	var b := BattleState.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	_play(a)
	_play(b)
	if JSON.stringify(a.to_dict()) != JSON.stringify(b.to_dict()):
		failures.append("%s: сохранение посреди боя изменило исход" % label)
