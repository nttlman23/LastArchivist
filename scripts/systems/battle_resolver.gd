class_name BattleResolver
extends RefCounted
## Единственная точка изменения BattleState: проверка и применение действий.


## Начинает бой: первый раунд и первый ход.
static func begin(state: BattleState) -> Array[BattleEvent]:
	var events := TurnManager.start_round(state)
	events.append_array(TurnManager.advance(state))
	return events


static func validate(state: BattleState, action: BattleAction) -> bool:
	if state.outcome != BattleState.Outcome.NONE:
		return false
	var u := state.active_unit()
	if u == null or not u.is_alive():
		return false
	match action.type:
		BattleAction.Type.MOVE:
			return Pathfinding.reachable(state, u).has(action.dest)
		BattleAction.Type.MELEE:
			var target := state.get_unit(action.target_uid)
			if target == null or not target.is_alive() or target.side == u.side:
				return false
			if not HexGrid.are_adjacent(action.dest, target.hex):
				return false
			return action.dest == u.hex or Pathfinding.reachable(state, u).has(action.dest)
		BattleAction.Type.SHOOT:
			var target := state.get_unit(action.target_uid)
			if target == null or not target.is_alive() or target.side == u.side:
				return false
			return u.can_shoot() and not state.is_blocked(u)
		BattleAction.Type.WAIT:
			return not u.waited
		BattleAction.Type.DEFEND:
			return true
	return false


## Применяет действие активного стека и передаёт ход. Недопустимое действие игнорируется.
static func apply(state: BattleState, action: BattleAction) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if not validate(state, action):
		push_warning("Invalid action %s" % action)
		return events
	var u := state.active_unit()
	match action.type:
		BattleAction.Type.MOVE:
			_move(state, u, action.dest, events)
		BattleAction.Type.MELEE:
			var target := state.get_unit(action.target_uid)
			_move(state, u, action.dest, events)
			_strike(state, u, target, false, false, events)
			if target.is_alive() and not target.retaliated:
				target.retaliated = true
				_strike(state, target, u, false, true, events)
		BattleAction.Type.SHOOT:
			var target := state.get_unit(action.target_uid)
			u.shots_left -= 1
			_strike(state, u, target, true, false, events)
		BattleAction.Type.WAIT:
			u.waited = true
			state.wait_queue.append(u.uid)
			events.append(BattleEvent.new(BattleEvent.WAITED, {"uid": u.uid}))
		BattleAction.Type.DEFEND:
			u.defending = true
			events.append(BattleEvent.new(BattleEvent.DEFENDED, {"uid": u.uid}))
	if _check_end(state, events):
		state.active_uid = -1
		return events
	# Бонус защиты снимается TurnManager в начале следующего хода этого стека.
	events.append_array(TurnManager.advance(state))
	return events


static func _move(state: BattleState, u: UnitState, dest: Vector2i, events: Array[BattleEvent]) -> void:
	if dest == u.hex:
		return
	var path := Pathfinding.path(state, u, dest)
	u.hex = dest
	events.append(BattleEvent.new(BattleEvent.MOVED, {"uid": u.uid, "path": path}))


static func _strike(state: BattleState, attacker: UnitState, target: UnitState, ranged: bool, retaliation: bool, events: Array[BattleEvent]) -> void:
	var damage := DamageCalc.roll(attacker, target, ranged, state.rng)
	var killed := target.take_damage(damage)
	events.append(BattleEvent.new(BattleEvent.ATTACKED, {
		"attacker": attacker.uid, "target": target.uid, "damage": damage,
		"killed": killed, "ranged": ranged, "retaliation": retaliation,
	}))
	if not target.is_alive():
		events.append(BattleEvent.new(BattleEvent.DIED, {"uid": target.uid}))


static func _check_end(state: BattleState, events: Array[BattleEvent]) -> bool:
	if state.alive(UnitState.Side.ENEMY).is_empty():
		state.outcome = BattleState.Outcome.PLAYER_WON
	elif state.alive(UnitState.Side.PLAYER).is_empty():
		state.outcome = BattleState.Outcome.PLAYER_LOST
	else:
		return false
	events.append(BattleEvent.new(BattleEvent.BATTLE_ENDED, {"outcome": state.outcome}))
	return true
