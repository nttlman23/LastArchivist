class_name ThreatMap
extends RefCounted
## Угрозы стеков (SPEC_SPRINT5 2): куда стек может дойти и кого атаковать в этот ход.
## Только читает состояние боя; положение остальных стеков считается неизменным.


class Zone:
	## Клетки, куда стек может переместиться (без стартовой).
	var move: Dictionary[Vector2i, int] = {}
	## Клетки, стоящего на которых стек может ударить в ближнем бою (соседние с move и стартом).
	var melee: Dictionary[Vector2i, bool] = {}
	## Стрелок с выстрелами и без врага вплотную: бьёт любую цель на поле.
	var shoots := false

	func reaches(hex: Vector2i) -> bool:
		return shoots or melee.has(hex)


## Зона одного стека.
static func zone(state: BattleState, u: UnitState) -> Zone:
	var z := Zone.new()
	z.move = Pathfinding.reachable(state, u)
	z.shoots = u.can_shoot() and not state.is_blocked(u)
	var stands: Array[Vector2i] = [u.hex]
	stands.append_array(z.move.keys())
	for h in stands:
		for n in state.grid.neighbors(h):
			if n != u.hex and not state.obstacles.has(n) and not state.temp_obstacles.has(n):
				z.melee[n] = true
	return z


## Зоны всех живых стеков стороны side: uid -> Zone.
static func zones(state: BattleState, side: int) -> Dictionary[int, Zone]:
	var result: Dictionary[int, Zone] = {}
	for u in state.alive(side):
		result[u.uid] = zone(state, u)
	return result


## Кто из стеков с зонами all может атаковать target в этот ход.
## melee_only — без стрелков: они достают всех, и значок «под ударом» от них ничего не говорит.
static func attackers_of(state: BattleState, all: Dictionary[int, Zone], target: UnitState, melee_only: bool = false) -> Array[int]:
	var result: Array[int] = []
	for uid in all:
		var a := state.get_unit(uid)
		var z := all[uid]
		var reaches := z.melee.has(target.hex) if melee_only else z.reaches(target.hex)
		if a and a.is_alive() and a.side != target.side and reaches:
			result.append(uid)
	return result


## Суммарная угроза ближнего боя: клетка -> число стеков, которые до неё дотянутся.
## Стрелки не учитываются — они покрывают всё поле; их цели видны при наведении на стрелка.
static func heat(all: Dictionary[int, Zone]) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	for uid in all:
		for h in all[uid].melee:
			result[h] = result.get(h, 0) + 1
	return result


## Суммарный урон всех, кто достаёт target: x..y — разброс, z — погибших при максимуме.
static func damage_to(state: BattleState, all: Dictionary[int, Zone], target: UnitState) -> Vector3i:
	var lo := 0
	var hi := 0
	for uid in attackers_of(state, all, target):
		var r := DamageCalc.damage_range(state.get_unit(uid), target, all[uid].shoots)
		lo += r.x
		hi += r.y
	return Vector3i(lo, hi, DamageCalc.kills(target, hi))


## Цели выстрела стрелка: uid -> дальний выстрел (урон снижен).
static func shot_targets(state: BattleState, u: UnitState) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	if not u.can_shoot() or state.is_blocked(u):
		return result
	for e in state.enemies_of(u):
		result[e.uid] = HexGrid.distance(u.hex, e.hex) > DamageCalc.LONG_RANGE
	return result


## Напряжение боя 0..1 для слоя музыки (SPEC_SPRINT9 12): доля ОЗ ваших стеков под ударом врага
## (ближний бой и стрелки) и номер раунда — затянувшийся бой тревожнее. all — зоны врагов (пусто — посчитать).
const TENSION_THREAT := 0.8
const TENSION_ROUND := 0.3
const TENSION_ROUNDS := 8


static func tension(state: BattleState, all: Dictionary[int, Zone] = {}) -> float:
	if all.is_empty():
		all = zones(state, UnitState.Side.ENEMY)
	var total := 0
	var threatened := 0
	for u in state.alive(UnitState.Side.PLAYER):
		if u.inert:
			continue
		total += u.total_hp()
		if not attackers_of(state, all, u).is_empty():
			threatened += u.total_hp()
	var share := float(threatened) / maxi(1, total)
	var late := clampf((state.round_number - 1) / float(TENSION_ROUNDS), 0.0, 1.0)
	return clampf(share * TENSION_THREAT + late * TENSION_ROUND, 0.0, 1.0)
