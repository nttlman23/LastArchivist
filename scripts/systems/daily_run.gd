class_name DailyRun
extends RefCounted
## Ежедневный забег (SPEC_SPRINT9 7, SPEC_SPRINT8 9): раскладка задана датой — сид, школа, «Нормально»,
## два модификатора (плюс и минус). Засчитывается первая законченная или брошенная попытка дня.

# Плюсы
const GENEROUS_SHOPS := &"generous_shops"    ## карты в лавке −1 Пергамент (не ниже 1)
const OLD_FRIENDS := &"old_friends"          ## старт с реликвией, без её разовой цены
const QUICK_QUILLS := &"quick_quills"        ## +1 инициатива вашим отрядам
const FULL_INKWELLS := &"full_inkwells"      ## первое заклинание забега +2 заряда
# Минусы
const HUNGRY_RIFT := &"hungry_rift"          ## боссы +12% ОЗ
const DAMPNESS := &"dampness"                ## все бои — с водой
const HEAVY_DREAMS := &"heavy_dreams"        ## карты на старте −1 прочности (не ниже 1)
const EARLY_COMMANDER := &"early_commander"  ## командир во всех боях

const PLUS: Array[StringName] = [GENEROUS_SHOPS, OLD_FRIENDS, QUICK_QUILLS, FULL_INKWELLS]
const MINUS: Array[StringName] = [HUNGRY_RIFT, DAMPNESS, HEAVY_DREAMS, EARLY_COMMANDER]
const ALL: Array[StringName] = [GENEROUS_SHOPS, OLD_FRIENDS, QUICK_QUILLS, FULL_INKWELLS,
		HUNGRY_RIFT, DAMPNESS, HEAVY_DREAMS, EARLY_COMMANDER]

const INKWELL_CHARGES := 2
## Подобрано симуляцией (SPEC_SPRINT9 13): при 20 % Машинный Синод терял 11 п.п. побед.
const BOSS_HP_SHARE := 0.12
## «Сырость»: сколько клеток воды в бою без своей воды, в средних колонках поля.
const DAMP_HEXES := 9
const DAMP_COLUMNS := Vector2i(3, 7)

# Счёт: слой × 10 + элита × 15 + боссы × 50 + оставшиеся ресурсы.
const SCORE_LAYER := 10
const SCORE_ELITE := 15
const SCORE_BOSS := 50

## Значки и цвета модификаторов — для экранов.
const ICONS := {
	GENEROUS_SHOPS: &"parchment", OLD_FRIENDS: &"points", QUICK_QUILLS: &"speed", FULL_INKWELLS: &"spell",
	HUNGRY_RIFT: &"hp", DAMPNESS: &"water", HEAVY_DREAMS: &"kill", EARLY_COMMANDER: &"threat",
}
const PLUS_COLOR := Color(0.55, 0.9, 0.6)
const MINUS_COLOR := Color(1.0, 0.5, 0.45)


static func has(run: RunState, id: StringName) -> bool:
	return run != null and run.modifiers.has(id)


static func today() -> String:
	return Achievements.today()


static func date_seed(date: String) -> int:
	return hash("daily:" + date)


## Раскладка дня: {"seed", "school", "modifiers"}. Школа — из открытых у игрока (без профиля — из стартовых).
static func layout(db: DefsDB, profile: ProfileState, date: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = date_seed(date)
	var schools: Array[StringName] = []
	for s in db.schools_sorted():
		if s.implemented and (s.unlock_cost == 0 or (profile != null and MetaRewards.is_school_open(profile, s))):
			schools.append(s.id)
	var school: StringName = schools[rng.randi_range(0, schools.size() - 1)]
	var mods: Array[StringName] = [PLUS[rng.randi_range(0, PLUS.size() - 1)], MINUS[rng.randi_range(0, MINUS.size() - 1)]]
	return {"seed": date_seed(date), "school": school, "modifiers": mods}


## Новая попытка дня date. Засчитывается, если в этот день ещё ничего не засчитано.
static func create(db: DefsDB, profile: ProfileState, date: String) -> RunState:
	var l := layout(db, profile, date)
	var run := RunState.create(db, int(l["seed"]), l["school"], profile, Difficulty.NORMAL, 0)
	run.daily_date = date
	run.modifiers.assign(l["modifiers"])
	run.daily_ranked = profile == null or profile.daily_last != date
	apply_start(db, run)
	return run


## Модификаторы старта: реликвия «Старых знакомых», прочность «Тяжёлых снов».
static func apply_start(db: DefsDB, run: RunState) -> void:
	if has(run, OLD_FRIENDS):
		var pool := RelicOps.available(db, run)
		if not pool.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("daily_relic:%d" % run.run_seed)
			RelicOps.take(db, run, pool[rng.randi_range(0, pool.size() - 1)], rng.randi(), false)
	if has(run, HEAVY_DREAMS):
		for c in run.codex.cards:
			c.durability = maxi(1, c.durability - 1)


## Модификаторы боя: инициатива, ОЗ боссов, вода.
static func apply_battle(run: RunState, enc: EncounterDef, state: BattleState) -> void:
	if run.modifiers.is_empty():
		return
	if has(run, QUICK_QUILLS):
		for u in state.alive(UnitState.Side.PLAYER):
			if not u.inert:
				u.initiative += 1
	if has(run, HUNGRY_RIFT) and enc.boss:
		for e in state.alive(UnitState.Side.ENEMY):
			var bonus := ceili(e.hp * BOSS_HP_SHARE)
			e.hp += bonus
			e.top_hp += bonus
	if has(run, DAMPNESS) and state.water.is_empty():
		_add_water(run, state)


## Вода в средних колонках на свободных клетках; свой генератор, чтобы не сдвигать случайность боя.
static func _add_water(run: RunState, state: BattleState) -> void:
	var free: Array[Vector2i] = []
	for x in range(DAMP_COLUMNS.x, DAMP_COLUMNS.y + 1):
		for y in state.grid.height:
			var h := Vector2i(x, y)
			if state.is_free(h):
				free.append(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("daily_water:%d" % run.battle_seed())
	for i in mini(DAMP_HEXES, free.size()):
		state.water[free.pop_at(rng.randi_range(0, free.size() - 1))] = BattleState.WATER_PERMANENT


static func bosses(run: RunState, won: bool) -> int:
	return (1 if won or run.act >= 2 else 0) + (1 if won else 0)


static func score(run: RunState, won: bool) -> int:
	var res := 0
	for id in run.resources:
		res += run.resources[id]
	return run.total_layer() * SCORE_LAYER + run.elites_won * SCORE_ELITE + bosses(run, won) * SCORE_BOSS + res


## Попытка засчитывается: первая в свой день.
static func counts(profile: ProfileState, run: RunState) -> bool:
	return run.daily_date != "" and run.daily_ranked and profile.daily_last != run.daily_date


## Запись засчитанной попытки в историю профиля; false — попытка не засчитывается.
static func record(profile: ProfileState, run: RunState, outcome: String) -> bool:
	if not counts(profile, run):
		return false
	profile.record_daily({
		"date": run.daily_date,
		"school": String(run.school_id),
		"modifiers": Array(run.modifiers).map(func(x: StringName) -> String: return String(x)),
		"layer": run.total_layer(),
		"score": score(run, outcome == ProfileState.OUTCOME_WON),
		"outcome": outcome,
	})
	return true


## Засчитанная попытка дня из истории (пусто — не сыграна).
static func entry_for(profile: ProfileState, date: String) -> Dictionary:
	for e in profile.daily:
		if e.get("date", "") == date:
			return e
	return {}


## Дата на days дней раньше date (формат ГГГГ-ММ-ДД).
static func shift_date(date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00") + days * 86400
	return Time.get_datetime_string_from_unix_time(unix).substr(0, 10)
