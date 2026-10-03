class_name BattleResolver
extends RefCounted
## Единственная точка изменения BattleState: проверка и применение действий.
## Общие боевые операции (удар, урон, лечение, стены) открыты для Abilities и HeroActions.


## Начинает бой: первый раунд и первый ход.
static func begin(state: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	SchoolPassives.on_battle_start(state, events)
	events.append_array(TurnManager.start_round(state))
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
		BattleAction.Type.ABILITY:
			return u.ability_ready() and action.ref_id == u.ability_id and Abilities.validate(state, u, action)
		BattleAction.Type.HERO:
			return HeroActions.validate(state, action)
	return false


## Применяет действие. Действие отряда передаёт ход; действие героя — нет.
## Недопустимое действие игнорируется.
static func apply(state: BattleState, action: BattleAction) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if not validate(state, action):
		push_warning("Invalid action %s" % action)
		return events
	if action.is_hero():
		HeroActions.apply(state, action, events)
		SchoolPassives.after_events(state, events)
		if check_end(state, events):
			state.active_uid = -1
		elif state.active_unit() == null or not state.active_unit().is_alive():
			# Заклинание героя задело и убило свой активный стек (цепная молния) — ход переходит дальше.
			events.append_array(TurnManager.advance(state))
		return events

	var u := state.active_unit()
	match action.type:
		BattleAction.Type.MOVE:
			move_unit(state, u, action.dest, events)
		BattleAction.Type.MELEE:
			var target := state.get_unit(action.target_uid)
			move_unit(state, u, action.dest, events)
			melee_exchange(state, u, target, events)
		BattleAction.Type.SHOOT:
			var target := state.get_unit(action.target_uid)
			u.shots_left -= 1
			strike(state, u, target, true, false, events)
		BattleAction.Type.WAIT:
			u.waited = true
			state.wait_queue.append(u.uid)
			events.append(BattleEvent.new(BattleEvent.WAITED, {"uid": u.uid}))
		BattleAction.Type.DEFEND:
			u.defending = true
			events.append(BattleEvent.new(BattleEvent.DEFENDED, {"uid": u.uid}))
		BattleAction.Type.ABILITY:
			Abilities.apply(state, u, action, events)
	SchoolPassives.after_events(state, events)
	# «Вперёд!» действует до конца хода стека; ожидание ход не заканчивает.
	if action.type != BattleAction.Type.WAIT and u.has_status(UnitState.STATUS_ADVANCE):
		u.statuses.erase(UnitState.STATUS_ADVANCE)
	if check_end(state, events):
		state.active_uid = -1
		return events
	# Бонус защиты снимается TurnManager в начале следующего хода этого стека.
	events.append_array(TurnManager.advance(state))
	return events


# --- Общие операции -------------------------------------------------------------

static func move_unit(state: BattleState, u: UnitState, dest: Vector2i, events: Array[BattleEvent], path: Array[Vector2i] = []) -> void:
	if dest == u.hex:
		return
	if path.is_empty():
		path = Pathfinding.path(state, u, dest)
	u.hex = dest
	events.append(BattleEvent.new(BattleEvent.MOVED, {"uid": u.uid, "path": path}))


## Удар ближнего боя с ответом (один за раунд, без лимита под «Стеной щитов»).
static func melee_exchange(state: BattleState, attacker: UnitState, target: UnitState, events: Array[BattleEvent], bonus: float = 1.0) -> int:
	var dealt := strike(state, attacker, target, false, false, events, bonus)
	try_retaliate(state, target, attacker, events)
	return dealt


static func try_retaliate(state: BattleState, defender: UnitState, attacker: UnitState, events: Array[BattleEvent]) -> void:
	if not defender.is_alive() or not attacker.is_alive() or defender.inert:
		return
	if not HexGrid.are_adjacent(defender.hex, attacker.hex):
		return
	if defender.retaliated and not defender.has_status(UnitState.STATUS_SHIELD_WALL):
		return
	defender.retaliated = true
	strike(state, defender, attacker, false, true, events)


## Атака с броском урона. Снимает метку с цели. Возвращает нанесённый урон.
static func strike(state: BattleState, attacker: UnitState, target: UnitState, ranged: bool, retaliation: bool, events: Array[BattleEvent], bonus: float = 1.0) -> int:
	var damage := DamageCalc.roll(attacker, target, ranged, state.rng, bonus)
	var killed := target.take_damage(damage)
	events.append(BattleEvent.new(BattleEvent.ATTACKED, {
		"attacker": attacker.uid, "target": target.uid, "damage": damage,
		"killed": killed, "ranged": ranged, "retaliation": retaliation,
	}))
	if target.has_status(UnitState.STATUS_MARKED):
		target.statuses.erase(UnitState.STATUS_MARKED)
		events.append(BattleEvent.new(BattleEvent.STATUS_CHANGED, {"uid": target.uid, "status": UnitState.STATUS_MARKED, "on": false}))
	if not target.is_alive():
		events.append(BattleEvent.new(BattleEvent.DIED, {"uid": target.uid}))
	return damage


## Фиксированный урон без атаки (заклинания): защита не учитывается, ответа нет.
static func deal_damage(target: UnitState, amount: int, source: StringName, events: Array[BattleEvent]) -> void:
	if target.illusion:
		amount = roundi(amount * DamageCalc.ILLUSION_DAMAGE)
	var killed := target.take_damage(amount)
	events.append(BattleEvent.new(BattleEvent.DAMAGED, {"uid": target.uid, "damage": amount, "killed": killed, "source": source}))
	if not target.is_alive():
		events.append(BattleEvent.new(BattleEvent.DIED, {"uid": target.uid}))


static func heal(target: UnitState, amount: int, events: Array[BattleEvent]) -> void:
	var before := target.count
	var healed := target.heal(amount)
	events.append(BattleEvent.new(BattleEvent.HEALED, {"uid": target.uid, "amount": healed, "revived": target.count - before}))


static func add_status(u: UnitState, status: StringName, rounds: int, events: Array[BattleEvent]) -> void:
	u.statuses[status] = rounds
	events.append(BattleEvent.new(BattleEvent.STATUS_CHANGED, {"uid": u.uid, "status": status, "on": true}))


static func set_defending(u: UnitState, events: Array[BattleEvent]) -> void:
	u.defending = true
	events.append(BattleEvent.new(BattleEvent.DEFENDED, {"uid": u.uid}))


static func add_temp_obstacle(state: BattleState, hex: Vector2i, rounds: int, events: Array[BattleEvent]) -> void:
	state.temp_obstacles[hex] = rounds
	events.append(BattleEvent.new(BattleEvent.OBSTACLE_ADDED, {"hex": hex, "rounds": rounds}))


static func check_end(state: BattleState, events: Array[BattleEvent]) -> bool:
	if state.outcome != BattleState.Outcome.NONE:
		return true
	BossRule.check(state, events)
	var outcome := ObjectiveRule.evaluate(state)
	if outcome == BattleState.Outcome.NONE:
		return false
	state.outcome = outcome
	events.append(BattleEvent.new(BattleEvent.BATTLE_ENDED, {"outcome": state.outcome}))
	return true
