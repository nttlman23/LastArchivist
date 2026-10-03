class_name ObjectiveRule
extends RefCounted
## Цели боя (SPEC_SPRINT5 11) и ход командира. Проверки — после каждого действия (evaluate)
## и в начале раунда (on_round_start: время, точки, подкрепления, намерение командира).

const ELIMINATE := &"eliminate"
const SURVIVE := &"survive"
const ASSASSINATE := &"assassinate"
const HOLD := &"hold"
const PROTECT := &"protect"
const ALL: Array[StringName] = [ELIMINATE, SURVIVE, ASSASSINATE, HOLD, PROTECT]

const ARCHIVE_UNIT := &"archive_relic"
const NO_HEX := Vector2i(-1, -1)


## Немедленный исход по составу сторон (после действия). NONE — бой продолжается.
static func evaluate(state: BattleState) -> BattleState.Outcome:
	if fighters(state, UnitState.Side.PLAYER).is_empty():
		return BattleState.Outcome.PLAYER_LOST
	if state.objective == PROTECT:
		var archive := state.get_unit(state.archive_uid)
		if archive == null or not archive.is_alive():
			return BattleState.Outcome.PLAYER_LOST
	var boss := state.get_unit(state.boss_uid)
	if state.alive(UnitState.Side.ENEMY).is_empty() or (boss != null and not boss.is_alive()):
		return BattleState.Outcome.PLAYER_WON
	return BattleState.Outcome.NONE


## Конец раунда (до увеличения номера): командир выполняет намерение.
static func on_round_end(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.commander_id == &"" or state.intent.is_empty():
		return
	var intent := state.intent
	state.intent = {}
	if not CommanderActions.valid(state, intent):
		# Цель исчезла — командир выбирает заново из того, что есть сейчас.
		intent = CommanderAi.choose(state)
		if intent.is_empty():
			return
	CommanderActions.apply(state, intent, events)


## Начало раунда (номер уже увеличен): время цели, точки, подкрепления. Возвращает true, если бой окончен.
static func on_round_start(state: BattleState, events: Array[BattleEvent]) -> bool:
	match state.objective:
		SURVIVE, PROTECT:
			if state.round_number > state.objective_rounds:
				return _finish(state, BattleState.Outcome.PLAYER_WON, events)
		HOLD:
			if state.round_number > 1 and holding(state):
				state.hold_count += 1
				events.append(BattleEvent.new(BattleEvent.OBJECTIVE_PROGRESS, {"count": state.hold_count, "need": state.objective_rounds}))
				if state.hold_count >= state.objective_rounds:
					return _finish(state, BattleState.Outcome.PLAYER_WON, events)
	_spawn_reinforcements(state, events)
	return false


## Новое намерение командира — после подготовки раунда.
static func announce_intent(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.commander_id == &"":
		return
	state.intent = CommanderAi.choose(state)
	if not state.intent.is_empty():
		events.append(BattleEvent.new(BattleEvent.COMMANDER_INTENT, state.intent.duplicate()))


## Свой боец стоит хотя бы на одной клетке-знамени.
static func holding(state: BattleState) -> bool:
	for h in state.hold_hexes:
		var u := state.unit_at(h)
		if u and u.side == UnitState.Side.PLAYER and not u.inert:
			return true
	return false


## Живые стеки стороны без объектов цели (архива).
static func fighters(state: BattleState, side: int) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for u in state.alive(side):
		if not u.inert:
			result.append(u)
	return result


static func _finish(state: BattleState, outcome: BattleState.Outcome, events: Array[BattleEvent]) -> bool:
	state.outcome = outcome
	events.append(BattleEvent.new(BattleEvent.BATTLE_ENDED, {"outcome": outcome, "reason": "objective"}))
	return true


## Подкрепления раунда — у края врага, на свободных клетках.
static func _spawn_reinforcements(state: BattleState, events: Array[BattleEvent]) -> void:
	var rest: Array[Dictionary] = []
	for r in state.reinforcements:
		if int(r["round"]) != state.round_number:
			rest.append(r)
			continue
		var hex := edge_hex(state)
		if hex == NO_HEX:
			rest.append(r)
			continue
		var u := UnitState.from_dict(r["unit"])
		u.uid = state.take_uid()
		u.hex = hex
		state.units.append(u)
		events.append(BattleEvent.new(BattleEvent.SUMMONED, {"uid": u.uid, "source": &"reinforcement"}))
	state.reinforcements = rest


## Свободная клетка у края врага (подкрепления, призыв).
static func edge_hex(state: BattleState) -> Vector2i:
	for col in [state.grid.width - 1, state.grid.width - 2, state.grid.width - 3]:
		for row in BattleState.START_ROWS:
			if state.is_free(Vector2i(col, row)):
				return Vector2i(col, row)
		for row in state.grid.height:
			if state.is_free(Vector2i(col, row)):
				return Vector2i(col, row)
	return NO_HEX
