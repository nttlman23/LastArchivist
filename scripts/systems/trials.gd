class_name Trials
extends RefCounted
## Испытания (SPEC_SPRINT8 3): ступени 1–10 поверх «Тяжело», ступень N включает правила 1…N.
## Открываются по одной победой на предыдущей ступени, отдельно для каждой школы.

const MAX := 10

const ELITE_COUNT := 1         ## элита: +20% численности врагов
const START_RESOURCES := 2     ## стартовые ресурсы −1 каждого
const REPAIR := 3              ## ремонт в лавке +1 Чернила
const INITIATIVE := 4          ## враги +1 к инициативе
const COMMANDERS := 5          ## командир во всех боях
const BOSS_HP := 6             ## боссы +15% ОЗ
const REWARDS := 7             ## после обычного боя — 2 карты на выбор
const PRICES := 8              ## карты в лавке +1 Пергамент
const DURABILITY := 9          ## новые карты −1 прочности (не ниже 1)
const PHASE := 10              ## Хозяин Глубин переходит во вторую фазу при 65% ОЗ

const ELITE_COUNT_SHARE := 1.2
const BOSS_HP_SHARE := 0.15
const PHASE_SHARE := 0.65
## Очки памяти: +10% за ступень.
const POINTS_PER_TRIAL := 0.1


static func has(run: RunState, rule: int) -> bool:
	return run != null and run.trial >= rule


## Испытания выбираются только на «Тяжело».
static func allowed(difficulty: StringName) -> bool:
	return difficulty == Difficulty.HARD


static func points(run: RunState, base: int) -> int:
	return roundi(base * (1.0 + POINTS_PER_TRIAL * run.trial))


## Правила боя: численность элиты, инициатива врагов, ОЗ боссов, порог второй фазы.
static func apply_battle(run: RunState, enc: EncounterDef, state: BattleState) -> void:
	if run.trial <= 0:
		return
	for e in state.alive(UnitState.Side.ENEMY):
		if enc.elite and has(run, ELITE_COUNT):
			e.count = ceili(e.count * ELITE_COUNT_SHARE)
			e.start_count = e.count
		if has(run, INITIATIVE):
			e.initiative += 1
		if enc.boss and has(run, BOSS_HP):
			var bonus := ceili(e.hp * BOSS_HP_SHARE)
			e.hp += bonus
			e.top_hp += bonus
	if has(run, PHASE):
		state.boss_phase_share = PHASE_SHARE


## Номера правил, действующих на ступени trial (для подсказок).
static func rules(trial: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(1, mini(trial, MAX) + 1):
		result.append(i)
	return result


static func rule_key(rule: int) -> String:
	return "TRIAL_RULE_%d" % rule


## Подсказка ступени: все правила, новое — последним.
static func describe(trial: int) -> String:
	if trial <= 0:
		return TranslationServer.translate("TRIAL_NONE_DESC")
	var lines: Array[String] = []
	for r in rules(trial):
		lines.append(("▸ " if r == trial else "· ") + TranslationServer.translate(rule_key(r)))
	return "\n".join(lines)
