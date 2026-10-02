class_name DamageCalc
extends RefCounted
## Формула урона (SPEC 3.4).

const ATTACK_BONUS_PER_POINT := 0.05
const ATTACK_BONUS_CAP := 60
const DEFENSE_BONUS_PER_POINT := 0.025
const DEFENSE_BONUS_CAP := 28
const DEFEND_MULTIPLIER := 1.3
const LONG_RANGE := 5
const HALF := 0.5
const MARK_BONUS := 1.5
## При большом стеке бросаем один раз и умножаем, как в HoMM3.
const SUM_ROLL_LIMIT := 10


static func effective_defense(defender: UnitState) -> float:
	return defender.defense * (DEFEND_MULTIPLIER if defender.defending else 1.0)


static func attack_modifier(attack: float, defense: float) -> float:
	var diff := attack - defense
	if diff > 0:
		return 1.0 + ATTACK_BONUS_PER_POINT * minf(diff, ATTACK_BONUS_CAP)
	return 1.0 - DEFENSE_BONUS_PER_POINT * minf(-diff, DEFENSE_BONUS_CAP)


## Итоговый множитель для удара attacker по defender.
static func multiplier(attacker: UnitState, defender: UnitState, ranged: bool) -> float:
	var m := attack_modifier(attacker.attack, effective_defense(defender))
	if ranged:
		if HexGrid.distance(attacker.hex, defender.hex) > LONG_RANGE:
			m *= HALF
	elif attacker.is_ranged:
		m *= HALF
	if defender.has_status(UnitState.STATUS_MARKED):
		m *= MARK_BONUS
	return m


## bonus — множитель способности (таран, залп, рикошет молнии).
static func roll(attacker: UnitState, defender: UnitState, ranged: bool, rng: RandomNumberGenerator, bonus: float = 1.0) -> int:
	var base := 0
	if attacker.count <= SUM_ROLL_LIMIT:
		for i in attacker.count:
			base += rng.randi_range(attacker.dmg_min, attacker.dmg_max)
	else:
		base = attacker.count * rng.randi_range(attacker.dmg_min, attacker.dmg_max)
	return _finalize(base, multiplier(attacker, defender, ranged) * bonus)


## Диапазон урона для превью: Vector2i(min, max).
static func damage_range(attacker: UnitState, defender: UnitState, ranged: bool, bonus: float = 1.0) -> Vector2i:
	var m := multiplier(attacker, defender, ranged) * bonus
	return Vector2i(_finalize(attacker.count * attacker.dmg_min, m), _finalize(attacker.count * attacker.dmg_max, m))


static func expected(attacker: UnitState, defender: UnitState, ranged: bool, bonus: float = 1.0) -> float:
	var r := damage_range(attacker, defender, ranged, bonus)
	return (r.x + r.y) * 0.5


## Сколько существ погибнет от данного урона (без изменения стека).
static func kills(defender: UnitState, damage: int) -> int:
	var remaining := defender.total_hp() - damage
	if remaining <= 0:
		return defender.count
	return defender.count - ceili(float(remaining) / defender.hp)


static func _finalize(base: int, m: float) -> int:
	return maxi(1, floori(base * m))
