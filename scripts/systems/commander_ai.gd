class_name CommanderAi
extends RefCounted
## Выбор намерения командира (SPEC_SPRINT5 10): лучшее по оценке действие с зарядами.
## Намерение — {"action", "target", "hex"} или пусто, если делать нечего.

const CURSE_SCORE := 20.0
const WALL_SCORE := 15.0
const GUARD_PER_ATTACKER := 10.0
const HASTE_SCORE := 25.0
const FURY_SCORE := 18.0
const HEAL_MIN_MISSING := 0.5
const WAVE_PER_UNIT := 14.0
const SUMMON_SCORE := 35.0
## Призывать, пока у босса меньше стольких стеков.
const SUMMON_BELOW := 6


static func choose(state: BattleState) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for id in state.commander_charges:
		if int(state.commander_charges[id]) <= 0:
			continue
		for c in _candidates(state, id):
			if float(c[1]) > best_score:
				best_score = c[1]
				best = c[0]
	return best


## Варианты действия: [[намерение, оценка]].
static func _candidates(state: BattleState, id: StringName) -> Array:
	var result: Array = []
	var players := _fighters(state, UnitState.Side.PLAYER)
	var enemies := _fighters(state, UnitState.Side.ENEMY)
	match id:
		CommanderActions.BOLT:
			for t in players:
				result.append([_intent(id, t.uid), AiController.value(CommanderActions.BOLT_DAMAGE, t)])
		CommanderActions.CURSE:
			for t in players:
				if not t.has_status(UnitState.STATUS_MARKED):
					result.append([_intent(id, t.uid), CURSE_SCORE * (1.0 + t.total_hp() / 200.0)])
		CommanderActions.HEAL:
			for t in enemies:
				var missing := t.start_count * t.hp - t.total_hp()
				if missing >= CommanderActions.HEAL_AMOUNT * HEAL_MIN_MISSING:
					result.append([_intent(id, t.uid), float(mini(missing, CommanderActions.HEAL_AMOUNT))])
		CommanderActions.GUARD:
			var zones := ThreatMap.zones(state, UnitState.Side.PLAYER)
			for t in enemies:
				if t.has_status(UnitState.STATUS_SHIELD_WALL):
					continue
				var n := ThreatMap.attackers_of(state, zones, t, true).size()
				if n > 0:
					result.append([_intent(id, t.uid), GUARD_PER_ATTACKER * n])
		CommanderActions.HASTE:
			for t in enemies:
				if t.has_status(UnitState.STATUS_ADVANCE) or t.speed <= 0:
					continue
				if not AiController.can_attack_now(state, t):
					t.statuses[UnitState.STATUS_ADVANCE] = UnitState.PERMANENT
					var reaches := AiController.can_attack_now(state, t)
					t.statuses.erase(UnitState.STATUS_ADVANCE)
					if reaches:
						result.append([_intent(id, t.uid), HASTE_SCORE])
		CommanderActions.FURY:
			for t in enemies:
				if AiController.can_attack_now(state, t):
					result.append([_intent(id, t.uid), FURY_SCORE * (1.0 + t.count / 20.0)])
		CommanderActions.WAVE:
			for t in players:
				var pushed := 0
				for o in players:
					if o.hex.y == t.hex.y and state.is_free(HexGrid.step(o.hex, CommanderActions.WAVE_DIR)):
						pushed += 1
				if pushed > 0:
					result.append([_intent(id, t.uid), WAVE_PER_UNIT * pushed])
		CommanderActions.SUMMON:
			if not state.summon_template.is_empty() and enemies.size() < SUMMON_BELOW:
				result.append([{"action": id, "target": -1, "hex": CommanderActions.NO_HEX}, SUMMON_SCORE])
		CommanderActions.DEEP_STRIKE:
			for t in players:
				result.append([_intent(id, t.uid), AiController.value(CommanderActions.DEEP_DAMAGE, t)])
		CommanderActions.WALL:
			var h := wall_hex(state)
			if h != CommanderActions.NO_HEX:
				result.append([{"action": id, "target": -1, "hex": h}, WALL_SCORE])
	return result


## Клетка стены: свободный сосед сильнейшего стека игрока ближнего боя в сторону ближайшего врага.
static func wall_hex(state: BattleState) -> Vector2i:
	var best: UnitState = null
	for u in _fighters(state, UnitState.Side.PLAYER):
		if not u.is_ranged and (best == null or u.total_hp() > best.total_hp()):
			best = u
	if best == null:
		return CommanderActions.NO_HEX
	var enemies := _fighters(state, UnitState.Side.ENEMY)
	if enemies.is_empty():
		return CommanderActions.NO_HEX
	var near := enemies[0]
	for e in enemies:
		if HexGrid.distance(best.hex, e.hex) < HexGrid.distance(best.hex, near.hex):
			near = e
	if HexGrid.distance(best.hex, near.hex) <= 1:
		return CommanderActions.NO_HEX
	var hex := CommanderActions.NO_HEX
	for n in state.grid.neighbors(best.hex):
		if state.is_free(n) and (hex == CommanderActions.NO_HEX or HexGrid.distance(n, near.hex) < HexGrid.distance(hex, near.hex)):
			hex = n
	return hex


static func _intent(id: StringName, target: int) -> Dictionary:
	return {"action": id, "target": target, "hex": CommanderActions.NO_HEX}


static func _fighters(state: BattleState, side: int) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for u in state.alive(side):
		if not u.inert:
			result.append(u)
	return result
