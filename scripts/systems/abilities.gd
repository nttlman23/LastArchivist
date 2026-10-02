class_name Abilities
extends RefCounted
## Активные способности отрядов (SPEC_SPRINT2 4). Способность — весь ход стека.
## Для каждой способности здесь: тип цели, проверка, применение и оценка для AI.

const SHIELD_WALL := &"shield_wall"
const MARK := &"mark"
const DEVOUR := &"devour"
const SHARD_VOLLEY := &"shard_volley"
const CHAIN_LIGHTNING := &"chain_lightning"
const COVER := &"cover"
const ECHO := &"echo"
const RESTORE := &"restore"
const RAM := &"ram"
const RIFT_TEAR := &"rift_tear"

const DEFAULT_COOLDOWN := 2
const DEVOUR_HEAL := 0.5
const VOLLEY_SPLASH := 0.5
const CHAIN_RANGE := 4
const CHAIN_HOP_RANGE := 2
const CHAIN_FACTORS: Array[float] = [0.5, 0.25]
const COVER_ROUNDS := 3
const RESTORE_AMOUNT := 30
const RAM_MIN := 2
const RAM_MAX := 4
const RAM_BONUS := 1.25
const RAM_BLOCKED_BONUS := 1.5
const TEAR_RANGE := 4
const TEAR_DAMAGE := 35

# Веса оценки для AI (в единицах ожидаемых ОЗ, как в AiController).
const ALLY_HIT_WEIGHT := 1.5
const RESTORE_WEIGHT := 1.2
const DEFENSIVE_SCORE := 10.0
const MARK_SCORE_IDLE := 20.0
const MARK_SCORE := 5.0
const PUSH_SHOOTER_BONUS := 10.0


## Какую способность фактически применяет стек: Хор копирует последнюю союзную.
static func effective(state: BattleState, u: UnitState) -> StringName:
	if u.ability_id == ECHO:
		return state.last_ability.get(u.side, &"")
	return u.ability_id


static func target_kind(id: StringName) -> Targeting.Kind:
	match id:
		MARK, DEVOUR, SHARD_VOLLEY, CHAIN_LIGHTNING, RAM:
			return Targeting.Kind.ENEMY
		RESTORE:
			return Targeting.Kind.ALLY
		COVER, RIFT_TEAR:
			return Targeting.Kind.HEX
	return Targeting.Kind.NONE


## Все допустимые применения способности активного стека — для подсветки целей и AI.
static func options(state: BattleState, u: UnitState) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	var id := effective(state, u)
	if id == &"" or not u.ability_ready():
		return result
	var candidates: Array[BattleAction] = []
	match target_kind(id):
		Targeting.Kind.NONE:
			candidates.append(BattleAction.ability(u.ability_id))
		Targeting.Kind.ENEMY:
			for e in state.enemies_of(u):
				candidates.append(BattleAction.ability(u.ability_id, e.uid))
		Targeting.Kind.ALLY:
			for a in state.alive(u.side):
				candidates.append(BattleAction.ability(u.ability_id, a.uid))
		Targeting.Kind.HEX:
			var hexes := state.grid.neighbors(u.hex) if id == COVER else state.grid.all_hexes()
			for h in hexes:
				candidates.append(BattleAction.ability(u.ability_id, -1, h))
	for a in candidates:
		if validate(state, u, a):
			result.append(a)
	return result


static func validate(state: BattleState, u: UnitState, action: BattleAction) -> bool:
	var id := effective(state, u)
	if id == &"" or id == ECHO:
		return false
	var echo := u.ability_id == ECHO
	var target := state.get_unit(action.target_uid)
	match id:
		SHIELD_WALL:
			return true
		MARK:
			return _is_enemy(u, target) and not target.has_status(UnitState.STATUS_MARKED)
		DEVOUR:
			return _is_enemy(u, target) and HexGrid.are_adjacent(u.hex, target.hex)
		SHARD_VOLLEY:
			return _is_enemy(u, target) and (echo or (u.can_shoot() and not state.is_blocked(u)))
		CHAIN_LIGHTNING:
			return _is_enemy(u, target) and HexGrid.distance(u.hex, target.hex) <= CHAIN_RANGE
		COVER:
			return HexGrid.are_adjacent(u.hex, action.dest) and state.is_free(action.dest)
		RESTORE:
			return target != null and target.is_alive() and target.side == u.side and _missing_hp(target) > 0
		RAM:
			return _is_enemy(u, target) and not ram_path(state, u, target).is_empty()
		RIFT_TEAR:
			return state.grid.in_bounds(action.dest) and HexGrid.distance(u.hex, action.dest) <= TEAR_RANGE
	return false


static func apply(state: BattleState, u: UnitState, action: BattleAction, events: Array[BattleEvent]) -> void:
	var id := effective(state, u)
	var echo := u.ability_id == ECHO
	var target := state.get_unit(action.target_uid)
	events.append(BattleEvent.new(BattleEvent.ABILITY_USED, {
		"uid": u.uid, "ability": id, "echo": echo, "target": action.target_uid, "hex": action.dest,
	}))
	match id:
		SHIELD_WALL:
			BattleResolver.set_defending(u, events)
			for n in state.neighbors_of(u.hex):
				if n.side == u.side:
					BattleResolver.set_defending(n, events)
			BattleResolver.add_status(u, UnitState.STATUS_SHIELD_WALL, 1, events)
		MARK:
			BattleResolver.add_status(target, UnitState.STATUS_MARKED, UnitState.PERMANENT, events)
		DEVOUR:
			var dealt := BattleResolver.strike(state, u, target, false, false, events)
			BattleResolver.heal(u, floori(dealt * DEVOUR_HEAL), events)
			BattleResolver.try_retaliate(state, target, u, events)
		SHARD_VOLLEY:
			if not echo:
				u.shots_left -= 1
			var splash := state.neighbors_of(target.hex).filter(func(o: UnitState) -> bool: return o != u)
			BattleResolver.strike(state, u, target, true, false, events)
			for o: UnitState in splash:
				if o.is_alive():
					BattleResolver.strike(state, u, o, true, false, events, VOLLEY_SPLASH)
		CHAIN_LIGHTNING:
			BattleResolver.strike(state, u, target, true, false, events)
			var hit: Array[int] = [u.uid, target.uid]
			var prev := target.hex
			for f in CHAIN_FACTORS:
				var next := chain_next(state, prev, hit)
				if next == null:
					break
				hit.append(next.uid)
				BattleResolver.strike(state, u, next, true, false, events, f)
				prev = next.hex
		COVER:
			BattleResolver.add_temp_obstacle(state, action.dest, COVER_ROUNDS, events)
		RESTORE:
			BattleResolver.heal(target, RESTORE_AMOUNT, events)
		RAM:
			var path := ram_path(state, u, target)
			var dir := HexGrid.line_direction(u.hex, target.hex)
			var push := HexGrid.step(target.hex, dir)
			var can_push := state.is_free(push)
			BattleResolver.move_unit(state, u, path[-1], events, path)
			BattleResolver.strike(state, u, target, false, false, events, RAM_BONUS if can_push else RAM_BLOCKED_BONUS)
			if target.is_alive():
				if can_push:
					var from := target.hex
					target.hex = push
					events.append(BattleEvent.new(BattleEvent.PUSHED, {"uid": target.uid, "from": from, "to": push}))
				else:
					BattleResolver.try_retaliate(state, target, u, events)
		RIFT_TEAR:
			for v in tear_victims(state, u, action.dest):
				BattleResolver.deal_damage(v, TEAR_DAMAGE, RIFT_TEAR, events)
	u.ability_cd = state.ability_cooldowns.get(u.ability_id, DEFAULT_COOLDOWN)
	state.last_ability[u.side] = id


## Враги стека на клетке и вокруг неё — по ним бьёт «Разрыв» (свои не задеваются).
static func tear_victims(state: BattleState, u: UnitState, hex: Vector2i) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for o in state.neighbors_of(hex):
		if o.side != u.side:
			result.append(o)
	var center := state.unit_at(hex)
	if center and center.side != u.side:
		result.append(center)
	return result


## Ближайший живой стек (любой стороны) в CHAIN_HOP_RANGE от клетки, не из списка; при равенстве — меньший uid.
static func chain_next(state: BattleState, from_hex: Vector2i, exclude: Array[int]) -> UnitState:
	var best: UnitState = null
	var best_d := CHAIN_HOP_RANGE + 1
	for o in state.alive_all():
		if exclude.has(o.uid):
			continue
		var d := HexGrid.distance(from_hex, o.hex)
		if d < best_d or (d == best_d and best != null and o.uid < best.uid):
			best = o
			best_d = d
	return best


## Путь разбега тарана [старт, ..., клетка перед целью] или пусто, если таран невозможен.
static func ram_path(state: BattleState, u: UnitState, target: UnitState) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var dist := HexGrid.distance(u.hex, target.hex)
	var dir := HexGrid.line_direction(u.hex, target.hex)
	if dir < 0 or dist < RAM_MIN or dist > RAM_MAX:
		return path
	path.append(u.hex)
	var h := u.hex
	for i in dist - 1:
		h = HexGrid.step(h, dir)
		if not state.is_free(h):
			path.clear()
			return path
		path.append(h)
	return path


# --- AI ------------------------------------------------------------------------

## Применения способности с положительной оценкой: [[BattleAction, score], ...].
static func ai_candidates(state: BattleState, u: UnitState) -> Array:
	var result: Array = []
	for a in options(state, u):
		var score := ai_score(state, u, a)
		if score > 0.0:
			result.append([a, score])
	return result


static func ai_score(state: BattleState, u: UnitState, action: BattleAction) -> float:
	var id := effective(state, u)
	var target := state.get_unit(action.target_uid)
	match id:
		SHIELD_WALL:
			if AiController.can_attack_now(state, u) or not _enemies_near(state, u, 4):
				return 0.0
			var allies := state.neighbors_of(u.hex).filter(func(o: UnitState) -> bool: return o.side == u.side).size()
			return DEFENSIVE_SCORE * (1 + allies)
		MARK:
			var idle := not u.can_shoot() or state.is_blocked(u)
			return MARK_SCORE_IDLE if idle else MARK_SCORE
		DEVOUR:
			var dealt := DamageCalc.expected(u, target, false)
			var heal := minf(dealt * DEVOUR_HEAL, _missing_hp(u))
			var retaliation := 0.0
			if not target.retaliated and dealt < target.total_hp():
				retaliation = AiController.retaliation_estimate(target, u, dealt)
			return AiController.value(dealt, target) + 0.5 * heal - AiController.RETALIATION_WEIGHT * retaliation
		SHARD_VOLLEY:
			var score := AiController.value(DamageCalc.expected(u, target, true), target)
			for o in state.neighbors_of(target.hex):
				if o == u:
					continue
				var v := AiController.value(DamageCalc.expected(u, o, true, VOLLEY_SPLASH), o)
				score += v if o.side != u.side else -ALLY_HIT_WEIGHT * v
			return score
		CHAIN_LIGHTNING:
			var score := AiController.value(DamageCalc.expected(u, target, true), target)
			var hit: Array[int] = [u.uid, target.uid]
			var prev := target.hex
			for f in CHAIN_FACTORS:
				var next := chain_next(state, prev, hit)
				if next == null:
					break
				hit.append(next.uid)
				var v := AiController.value(DamageCalc.expected(u, next, true, f), next)
				score += v if next.side != u.side else -ALLY_HIT_WEIGHT * v
				prev = next.hex
			return score
		COVER:
			if AiController.can_attack_now(state, u) or not _enemies_near(state, u, 3):
				return 0.0
			return DEFENSIVE_SCORE * 0.8
		RESTORE:
			return RESTORE_WEIGHT * minf(RESTORE_AMOUNT, _missing_hp(target))
		RAM:
			var dir := HexGrid.line_direction(u.hex, target.hex)
			var can_push := state.is_free(HexGrid.step(target.hex, dir))
			var dealt := DamageCalc.expected(u, target, false, RAM_BONUS if can_push else RAM_BLOCKED_BONUS)
			var score := AiController.value(dealt, target)
			if can_push:
				if target.is_ranged:
					score += PUSH_SHOOTER_BONUS
			elif not target.retaliated and dealt < target.total_hp():
				score -= AiController.RETALIATION_WEIGHT * AiController.retaliation_estimate(target, u, dealt)
			return score
		RIFT_TEAR:
			var score := 0.0
			for v in tear_victims(state, u, action.dest):
				score += AiController.value(TEAR_DAMAGE, v)
			return score
	return 0.0


static func _is_enemy(u: UnitState, target: UnitState) -> bool:
	return target != null and target.is_alive() and target.side != u.side


static func _missing_hp(u: UnitState) -> int:
	return u.start_count * u.hp - u.total_hp()


static func _enemies_near(state: BattleState, u: UnitState, radius: int) -> bool:
	for e in state.enemies_of(u):
		if HexGrid.distance(u.hex, e.hex) <= radius:
			return true
	return false
