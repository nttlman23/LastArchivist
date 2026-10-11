class_name GentleRuns
extends RefCounted
## Учебные забеги (SPEC_SPRINT11 6): первые забеги нового профиля — на слоях 1–3 первого акта
## враги слабее (численность ×0,75) и без командиров. Поверх выбранной сложности; не для
## ежедневных забегов и испытаний; выключается в настройках.

const COUNT_FACTOR := 0.75
const LAST_LAYER := 3


## Начало обычного забега: учебный ли он (и списать один из оставшихся учебных забегов профиля).
static func start(run: RunState, profile: ProfileState, enabled: bool) -> void:
	run.gentle = enabled and profile != null and profile.gentle_runs_left > 0 and run.trial <= 0 and run.daily_date == ""
	if run.gentle:
		profile.gentle_runs_left -= 1


## Ослаблены ли враги в бою на слое layer.
static func active(run: RunState, layer: int) -> bool:
	return run != null and run.gentle and run.act == 1 and layer >= 1 and layer <= LAST_LAYER


## Численность врага с учётом учебного забега (для подписей на карте и подготовке).
static func count(run: RunState, layer: int, encounter: EncounterDef, base: int) -> int:
	if active(run, layer) and not encounter.boss:
		return maxi(1, roundi(base * COUNT_FACTOR))
	return base


## Бой текущего острова: враги слабее (кроме босса).
static func apply_battle(run: RunState, enc: EncounterDef, state: BattleState) -> void:
	var node := run.pending()
	if enc.boss or node == null or not active(run, node.layer):
		return
	for e in state.alive(UnitState.Side.ENEMY):
		e.count = maxi(1, roundi(e.count * COUNT_FACTOR))
		e.start_count = e.count
