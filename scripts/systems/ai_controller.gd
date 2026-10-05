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
## Архив цели «Спасти архив» — главная мишень врага.
const ARCHIVE_WEIGHT := 2.0
## «Удержать точку»: стоять на знамени и дойти до него.
const HOLD_STAY_SCORE := 60.0
const HOLD_MOVE_SCORE := 50.0
## Удар с клетки течения, которое унесёт стек от цели (SPEC_SPRINT7 4).
const CURRENT_DRIFT_PENALTY := 5.0


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
	candidates.append_array(_objective_candidates(state, u))

	var best: BattleAction = null
	var best_score := 0.0
	for c: Array in candidates:
		if float(c[1]) > best_score and BattleResolver.validate(state, c[0]):
			best_score = c[1]
			best = c[0]
	if best:
		return best
	# Цель «Уничтожить цель»: отмеченный стек держится в тылу.
	if state.objective == ObjectiveRule.ASSASSINATE and u.is_boss:
		return BattleAction.defend()
	if state.objective == ObjectiveRule.HOLD and u.side == UnitState.Side.PLAYER and not state.hold_hexes.is_empty():
		var step := _step_toward(state, u, state.hold_hexes)
		if step != u.hex:
			return BattleAction.move(step)

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
	if target.inert:
		score *= ARCHIVE_WEIGHT
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
			if not HexGrid.are_adjacent(drift_hex(state, u, origin), e.hex):
				s -= CURRENT_DRIFT_PENALTY
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
			var d := _nearest_enemy_distance(drift_hex(state, u, h), enemies)
			if d < best_d:
				best_d = d
				best_hex = h
		return best_hex
	var path := res.path_to(goal)
	return _settle(state, u, path, mini(u.move_speed(), path.size() - 1), enemies)


## Клетка остановки на пути: не дальше far, с учётом сноса течением в начале раунда —
## если течение унесёт дальше от врагов, лучше встать раньше (SPEC_SPRINT7 4).
static func _settle(state: BattleState, u: UnitState, path: Array[Vector2i], far: int, enemies: Array[UnitState]) -> Vector2i:
	if state.currents.is_empty() or far <= 0:
		return path[far]
	var best := far
	var best_d := _nearest_enemy_distance(drift_hex(state, u, path[far]), enemies)
	for i in range(far - 1, 0, -1):
		var d := _nearest_enemy_distance(drift_hex(state, u, path[i]), enemies)
		if d < best_d:
			best_d = d
			best = i
	return path[best]


## Где окажется стек, вставший на hex, после сноса течением в начале следующего раунда.
static func drift_hex(state: BattleState, u: UnitState, hex: Vector2i) -> Vector2i:
	if u.is_flying or u.inert or not state.currents.has(hex):
		return hex
	if state.player_ignores_currents and u.side == UnitState.Side.PLAYER:
		return hex
	var to := HexGrid.step(hex, state.currents[hex])
	if not state.grid.in_bounds(to) or state.is_obstacle(to):
		return hex
	var other := state.unit_at(to)
	if other and other != u:
		return hex
	return to


## Кандидаты цели боя: стоять на знамени или дойти до свободного знамени.
static func _objective_candidates(state: BattleState, u: UnitState) -> Array:
	var result: Array = []
	if state.objective != ObjectiveRule.HOLD or u.side != UnitState.Side.PLAYER:
		return result
	if state.hold_hexes.has(u.hex):
		result.append([BattleAction.defend(), HOLD_STAY_SCORE])
		return result
	if ObjectiveRule.holding(state):
		return result
	var reach := Pathfinding.reachable(state, u)
	for h in state.hold_hexes:
		if reach.has(h):
			result.append([BattleAction.move(h), HOLD_MOVE_SCORE])
	return result


## Шаг по пути к ближайшей из клеток goals или её соседу (без учёта врагов).
static func _step_toward(state: BattleState, u: UnitState, goals: Array[Vector2i]) -> Vector2i:
	if u.speed <= 0:
		return u.hex
	var res := Pathfinding.bfs(state, u.hex)
	var goal := u.hex
	var best := 1 << 30
	for g in goals:
		var near: Array[Vector2i] = [g]
		near.append_array(state.grid.neighbors(g))
		for h in near:
			if res.dist.has(h) and res.dist[h] < best:
				best = res.dist[h]
				goal = h
	if goal == u.hex:
		return u.hex
	var path := res.path_to(goal)
	return path[mini(u.move_speed(), path.size() - 1)]


static func _nearest_enemy_distance(hex: Vector2i, enemies: Array[UnitState]) -> int:
	var best := 1 << 30
	for e in enemies:
		best = mini(best, HexGrid.distance(hex, e.hex))
	return best
