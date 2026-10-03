class_name AiController
extends RefCounted
## Простой AI без поиска по дереву (SPEC 5, SPEC_SPRINT2 4.3). Работает только с данными боя.
## Кандидаты (выстрел, лучший удар, способности) оцениваются в одной шкале — ожидаемых ОЗ —
## и выбирается лучший; если атаковать нечем, стек идёт к врагу.

const RANGED_TARGET_WEIGHT := 1.5
const STACK_KILL_BONUS := 1000.0
const RETALIATION_WEIGHT := 0.5
## Урон по Хранителю Разлома ценнее: его гибель сразу выигрывает бой.
const BOSS_WEIGHT := 3.0


static func choose_action(state: BattleState, uid: int) -> BattleAction:
	var u := state.get_unit(uid)
	var enemies := state.enemies_of(u)
	if enemies.is_empty():
		return BattleAction.defend()

	var candidates: Array = []
	if u.can_shoot() and not state.is_blocked(u):
		var target := _best_shot_target(u, enemies)
		candidates.append([BattleAction.shoot(target.uid), value(DamageCalc.expected(u, target, true), target)])
	var melee := _best_melee(state, u, enemies)
	if not melee.is_empty():
		candidates.append(melee)
	candidates.append_array(Abilities.ai_candidates(state, u))

	var best: BattleAction = null
	var best_score := 0.0
	for c: Array in candidates:
		if float(c[1]) > best_score and BattleResolver.validate(state, c[0]):
			best_score = c[1]
			best = c[0]
	if best:
		return best

	var dest := _approach_hex(state, u, enemies)
	if dest != u.hex:
		return BattleAction.move(dest)
	return BattleAction.defend()


## Может ли стек атаковать прямо сейчас (выстрелом или дойдя до врага).
static func can_attack_now(state: BattleState, u: UnitState) -> bool:
	if u.can_shoot() and not state.is_blocked(u):
		return true
	return not _best_melee(state, u, state.enemies_of(u)).is_empty()


## Ценность нанесения урона dealt по цели: ОЗ, стрелки дороже, уничтожение стека — огромный бонус.
static func value(dealt: float, target: UnitState) -> float:
	var hp := float(target.total_hp())
	var score := minf(dealt, hp)
	if target.is_ranged:
		score *= RANGED_TARGET_WEIGHT
	if target.is_boss:
		score *= BOSS_WEIGHT
	if dealt >= hp:
		score += STACK_KILL_BONUS
	return score


## Ожидаемый ответный урон от уцелевшей части стека.
static func retaliation_estimate(defender: UnitState, attacker: UnitState, dealt: float) -> float:
	var survivor := UnitState.new()
	survivor.count = defender.count - DamageCalc.kills(defender, roundi(dealt))
	survivor.hp = defender.hp
	survivor.top_hp = defender.hp
	survivor.attack = defender.attack
	survivor.dmg_min = defender.dmg_min
	survivor.dmg_max = defender.dmg_max
	survivor.is_ranged = defender.is_ranged
	survivor.hex = defender.hex
	if survivor.count <= 0:
		return 0.0
	return DamageCalc.expected(survivor, attacker, false)


static func _best_shot_target(u: UnitState, enemies: Array[UnitState]) -> UnitState:
	var best: UnitState = null
	var best_score := -INF
	for e in enemies:
		var score := value(DamageCalc.expected(u, e, true), e)
		if score > best_score:
			best_score = score
			best = e
	return best


## Лучший удар ближнего боя: [BattleAction, score] или пусто.
static func _best_melee(state: BattleState, u: UnitState, enemies: Array[UnitState]) -> Array:
	var origins: Array[Vector2i] = [u.hex]
	# Заблокированный стрелок не уходит, а бьёт соседа.
	if not (u.is_ranged and state.is_blocked(u)):
		for h in Pathfinding.reachable(state, u):
			origins.append(h)
	var best: BattleAction = null
	var best_score := -INF
	for e in enemies:
		var dealt := DamageCalc.expected(u, e, false)
		var retaliation := 0.0
		var retaliates := not e.retaliated or e.has_status(UnitState.STATUS_SHIELD_WALL)
		if retaliates and dealt < e.total_hp():
			retaliation = retaliation_estimate(e, u, dealt)
		var score := value(dealt, e) - RETALIATION_WEIGHT * retaliation
		for origin in origins:
			if not HexGrid.are_adjacent(origin, e.hex):
				continue
			# Небольшой штраф за длину пути — при равенстве не бегать зря.
			var s := score - 0.01 * HexGrid.distance(u.hex, origin)
			if s > best_score:
				best_score = s
				best = BattleAction.melee(origin, e.uid)
	if best == null:
		return []
	# Даже невыгодный удар лучше бездействия рядом с врагом.
	return [best, maxf(best_score, 0.01)]


## Самая продвинутая к ближайшему врагу клетка, достижимая в этот ход.
static func _approach_hex(state: BattleState, u: UnitState, enemies: Array[UnitState]) -> Vector2i:
	if u.is_flying:
		var best_hex := u.hex
		var best_d := _nearest_enemy_distance(u.hex, enemies)
		var reach := Pathfinding.reachable(state, u)
		for h in reach:
			var d := _nearest_enemy_distance(h, enemies)
			if d < best_d or (d == best_d and reach[h] < reach.get(best_hex, 0)):
				best_d = d
				best_hex = h
		return best_hex

	var res := Pathfinding.bfs(state, u.hex)
	var goal := u.hex
	var goal_dist := 1 << 30
	for e in enemies:
		for n in state.grid.neighbors(e.hex):
			if res.dist.has(n) and res.dist[n] < goal_dist:
				goal_dist = res.dist[n]
				goal = n
	if goal == u.hex:
		# Пути к врагу нет — просто сокращаем дистанцию.
		var reach := Pathfinding.reachable(state, u)
		var best_hex := u.hex
		var best_d := _nearest_enemy_distance(u.hex, enemies)
		for h in reach:
			var d := _nearest_enemy_distance(h, enemies)
			if d < best_d:
				best_d = d
				best_hex = h
		return best_hex
	var path := res.path_to(goal)
	return path[mini(u.move_speed(), path.size() - 1)]


static func _nearest_enemy_distance(hex: Vector2i, enemies: Array[UnitState]) -> int:
	var best := 1 << 30
	for e in enemies:
		best = mini(best, HexGrid.distance(hex, e.hex))
	return best
