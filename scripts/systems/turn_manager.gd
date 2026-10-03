class_name TurnManager
extends RefCounted
## Очередь ходов: раунды по инициативе, фаза ожидания в обратном порядке.


static func start_round(state: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if state.round_number > 0:
		ObjectiveRule.on_round_end(state, events)
		if BattleResolver.check_end(state, events):
			return events
	state.round_number += 1
	if state.round_number > state.max_rounds:
		state.outcome = BattleState.Outcome.PLAYER_LOST
		events.append(BattleEvent.new(BattleEvent.BATTLE_ENDED, {"outcome": state.outcome, "reason": "rounds"}))
		return events
	if state.rift:
		RiftRule.on_round_start(state, events)
		if ObjectiveRule.fighters(state, UnitState.Side.PLAYER).is_empty():
			state.outcome = BattleState.Outcome.PLAYER_LOST
			events.append(BattleEvent.new(BattleEvent.BATTLE_ENDED, {"outcome": state.outcome, "reason": "erased"}))
			return events
	if ObjectiveRule.on_round_start(state, events):
		return events
	_apply_currents(state, events)
	var order := state.alive_all()
	for u in order:
		u.retaliated = false
		u.waited = false
		if u.ability_cd > 0:
			u.ability_cd -= 1
		_tick_statuses(u, events)
	_tick_obstacles(state, events)
	SchoolPassives.on_round_start(state, events)
	state.hero_actions_left = BattleState.HERO_ACTIONS_PER_ROUND
	order.sort_custom(_main_phase_before)
	state.queue.clear()
	state.wait_queue.clear()
	for u in order:
		# Объекты цели (архив) не ходят.
		if not u.inert:
			state.queue.append(u.uid)
	events.append(BattleEvent.new(BattleEvent.ROUND_STARTED, {"round": state.round_number}))
	ObjectiveRule.announce_intent(state, events)
	return events


## Течения: стек на клетке течения сносит на одну клетку по стрелке, если она свободна.
## Летуны не сносятся. Порядок — по uid, чтобы не зависеть от порядка словаря.
static func _apply_currents(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.currents.is_empty():
		return
	var movers := state.alive_all()
	movers.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.uid < b.uid)
	for u in movers:
		if u.is_flying or u.inert or not state.currents.has(u.hex):
			continue
		var to := HexGrid.step(u.hex, state.currents[u.hex])
		if state.is_free(to):
			var from := u.hex
			u.hex = to
			events.append(BattleEvent.new(BattleEvent.PUSHED, {"uid": u.uid, "from": from, "to": to, "current": true}))


static func _tick_statuses(u: UnitState, events: Array[BattleEvent]) -> void:
	for id in u.statuses.keys():
		var left: int = u.statuses[id]
		if left == UnitState.PERMANENT:
			continue
		left -= 1
		if left <= 0:
			u.statuses.erase(id)
			events.append(BattleEvent.new(BattleEvent.STATUS_CHANGED, {"uid": u.uid, "status": id, "on": false}))
		else:
			u.statuses[id] = left


static func _tick_obstacles(state: BattleState, events: Array[BattleEvent]) -> void:
	for hex in state.ink.keys():
		var k: int = state.ink[hex] - 1
		if k <= 0:
			state.ink.erase(hex)
			events.append(BattleEvent.new(BattleEvent.OBSTACLE_EXPIRED, {"hex": hex, "ink": true}))
		else:
			state.ink[hex] = k
	for hex in state.water.keys():
		if state.water[hex] == BattleState.WATER_PERMANENT:
			continue
		var w: int = state.water[hex] - 1
		if w <= 0:
			state.water.erase(hex)
			events.append(BattleEvent.new(BattleEvent.OBSTACLE_EXPIRED, {"hex": hex, "water": true}))
		else:
			state.water[hex] = w
	for hex in state.temp_obstacles.keys():
		var left: int = state.temp_obstacles[hex] - 1
		if left <= 0:
			state.temp_obstacles.erase(hex)
			events.append(BattleEvent.new(BattleEvent.OBSTACLE_EXPIRED, {"hex": hex}))
		else:
			state.temp_obstacles[hex] = left


## Передаёт ход следующему живому стеку, при необходимости начиная новый раунд.
static func advance(state: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	while state.outcome == BattleState.Outcome.NONE:
		var next := _pop_next(state)
		if next:
			state.active_uid = next.uid
			next.defending = false
			events.append(BattleEvent.new(BattleEvent.TURN_STARTED, {"uid": next.uid}))
			return events
		events.append_array(start_round(state))
	state.active_uid = -1
	return events


## Порядок на остаток раунда — для отображения очереди.
static func upcoming(state: BattleState) -> Array[int]:
	var result: Array[int] = []
	for uid in state.queue:
		var u := state.get_unit(uid)
		if u and u.is_alive():
			result.append(uid)
	for u in _sorted_wait(state):
		result.append(u.uid)
	return result


## Порядок следующего раунда (по текущим живым стекам).
static func next_round_order(state: BattleState) -> Array[int]:
	var order := state.alive_all()
	order.sort_custom(_main_phase_before)
	var result: Array[int] = []
	for u in order:
		if not u.inert:
			result.append(u.uid)
	return result


static func _pop_next(state: BattleState) -> UnitState:
	while not state.queue.is_empty():
		var u := state.get_unit(state.queue.pop_front())
		if u and u.is_alive():
			return u
	var waiting := _sorted_wait(state)
	if waiting.is_empty():
		state.wait_queue.clear()
		return null
	var first := waiting[0]
	state.wait_queue.erase(first.uid)
	return first


static func _sorted_wait(state: BattleState) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for uid in state.wait_queue:
		var u := state.get_unit(uid)
		if u and u.is_alive():
			result.append(u)
	result.sort_custom(_wait_phase_before)
	return result


static func _main_phase_before(a: UnitState, b: UnitState) -> bool:
	if a.effective_initiative() != b.effective_initiative():
		return a.effective_initiative() > b.effective_initiative()
	if a.side != b.side:
		return a.side < b.side
	return a.uid < b.uid


static func _wait_phase_before(a: UnitState, b: UnitState) -> bool:
	if a.effective_initiative() != b.effective_initiative():
		return a.effective_initiative() < b.effective_initiative()
	if a.side != b.side:
		return a.side < b.side
	return a.uid < b.uid
