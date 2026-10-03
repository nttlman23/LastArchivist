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
# Спринт 4, этап B: школы.
const UNDERTOW := &"undertow"
const FLOOD := &"flood"
const OVERCLOCK := &"overclock"
const TINKER := &"tinker"
const REFLECT := &"reflect"
const STEAL := &"steal"

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
const UNDERTOW_MIN := 2
const UNDERTOW_MAX := 4
const FLOOD_RANGE := 4
const FLOOD_ROUNDS := 2
const TINKER_HEAL := 40
const BARRIER_ROUNDS := 3
const REFLECT_SHARE := 0.5
## Способности, которые нельзя украсть.
const UNSTEALABLE: Array[StringName] = [&"", ECHO, STEAL, RIFT_TEAR]

# Веса оценки для AI (в единицах ожидаемых ОЗ, как в AiController).
const ALLY_HIT_WEIGHT := 1.5
const RESTORE_WEIGHT := 1.2
const DEFENSIVE_SCORE := 10.0
const MARK_SCORE_IDLE := 20.0
const MARK_SCORE := 5.0
const PUSH_SHOOTER_BONUS := 10.0
const RANGED_TARGET_BONUS := 1.5


## Какую способность фактически применяет стек: Хор копирует последнюю союзную,
## Похититель на время применения — заимствованную у врага.
static func effective(state: BattleState, u: UnitState) -> StringName:
	if u.ability_id == ECHO:
		return state.last_ability.get(u.side, &"")
	if u.ability_id == STEAL and u.borrowed_ability != &"":
		return u.borrowed_ability
	return u.ability_id


## Копирующие способности не требуют выстрелов и т.п. — повторяют эффект.
static func _is_copy(u: UnitState) -> bool:
	return u.ability_id == ECHO or (u.ability_id == STEAL and u.borrowed_ability != &"")


static func target_kind(id: StringName) -> Targeting.Kind:
	match id:
		MARK, DEVOUR, SHARD_VOLLEY, CHAIN_LIGHTNING, RAM, UNDERTOW, OVERCLOCK, STEAL:
			return Targeting.Kind.ENEMY
		RESTORE, REFLECT, TINKER:
			return Targeting.Kind.ALLY
		COVER, RIFT_TEAR, FLOOD:
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
				# Объект цели (архив) можно только лечить.
				if not a.inert or id == RESTORE:
					candidates.append(BattleAction.ability(u.ability_id, a.uid))
			# «Механик» ещё ставит барьер на соседнюю клетку.
			if id == TINKER:
				for h in state.grid.neighbors(u.hex):
					candidates.append(BattleAction.ability(u.ability_id, -1, h))
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
	var echo := _is_copy(u)
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
		UNDERTOW:
			return _is_enemy(u, target) and not undertow_path(state, u, target).is_empty()
		FLOOD:
			return state.grid.in_bounds(action.dest) and HexGrid.distance(u.hex, action.dest) <= FLOOD_RANGE
		OVERCLOCK:
			return _is_enemy(u, target) and (echo or (u.can_shoot() and not state.is_blocked(u)))
		TINKER:
			if target:
				return target.is_alive() and target.side == u.side and target.construct and _missing_hp(target) > 0
			return HexGrid.are_adjacent(u.hex, action.dest) and state.is_free(action.dest)
		REFLECT:
			return target != null and target.is_alive() and target.side == u.side and not target.illusion \
					and not target.is_boss and not target.inert and illusion_hex(state, target, u) != NO_HEX
		STEAL:
			return _is_enemy(u, target) and not steal_options(state, u, target).is_empty()
	return false


static func apply(state: BattleState, u: UnitState, action: BattleAction, events: Array[BattleEvent]) -> void:
	var id := effective(state, u)
	var echo := _is_copy(u)
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
		UNDERTOW:
			# Притянуть к себе по прямой и ударить без ответа.
			var path := undertow_path(state, u, target)
			var from := target.hex
			target.hex = path[-1]
			events.append(BattleEvent.new(BattleEvent.PUSHED, {"uid": target.uid, "from": from, "to": target.hex}))
			BattleResolver.strike(state, u, target, false, false, events)
		FLOOD:
			for h in flood_area(state, action.dest):
				state.water[h] = FLOOD_ROUNDS
			events.append(BattleEvent.new(BattleEvent.OBSTACLE_ADDED, {"hex": action.dest, "rounds": FLOOD_ROUNDS, "water": true}))
		OVERCLOCK:
			# Два выстрела: по цели, второй — по ней же или по ближайшему врагу, если цель пала.
			for shot in 2:
				if not echo:
					if u.shots_left <= 0:
						break
					u.shots_left -= 1
				var aim := target if target.is_alive() else _nearest_enemy(state, u)
				if aim == null:
					break
				BattleResolver.strike(state, u, aim, true, false, events)
		TINKER:
			if target:
				BattleResolver.heal(target, TINKER_HEAL, events)
			else:
				var toward := HexGrid.to_pixel(action.dest, 1.0) - HexGrid.to_pixel(u.hex, 1.0)
				var second := HeroActions.salt_wall_second(state, action.dest, toward)
				BattleResolver.add_temp_obstacle(state, action.dest, BARRIER_ROUNDS, events)
				if second != NO_HEX and second != action.dest:
					BattleResolver.add_temp_obstacle(state, second, BARRIER_ROUNDS, events)
		REFLECT:
			summon_illusion(state, target, illusion_hex(state, target, u), REFLECT_SHARE, events)
		STEAL:
			# Применить способность врага от своего лица по лучшей для себя цели.
			var options := steal_options(state, u, target)
			var best: BattleAction = options[0]
			var best_score := -INF
			u.borrowed_ability = target.ability_id
			for o in options:
				var sc := ai_score(state, u, o)
				if sc > best_score:
					best_score = sc
					best = o
			apply(state, u, best, events)
			u.borrowed_ability = &""
	var cd: int = state.ability_cooldowns.get(u.ability_id, DEFAULT_COOLDOWN)
	if state.passive_id == SchoolPassives.TIDE_CURRENT and u.side == UnitState.Side.PLAYER:
		cd = maxi(1, cd - 1)
	u.ability_cd = cd
	# «Отголосок» повторяет только «настоящие» способности, а не копирующие.
	if id != STEAL and id != ECHO:
		state.last_ability[u.side] = id


const NO_HEX := Vector2i(-1, -1)


## Путь притягивания: [клетка цели, …, клетка рядом с притягивающим] или пусто.
static func undertow_path(state: BattleState, u: UnitState, target: UnitState) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var dist := HexGrid.distance(u.hex, target.hex)
	var dir := HexGrid.line_direction(u.hex, target.hex)
	if dir < 0 or dist < UNDERTOW_MIN or dist > UNDERTOW_MAX:
		return path
	path.append(target.hex)
	var back := (dir + 3) % 6
	var h := target.hex
	for i in dist - 1:
		h = HexGrid.step(h, back)
		if not state.is_free(h):
			path.clear()
			return path
		path.append(h)
	return path


## Клетки «Разлива»: центр и соседи, кроме препятствий.
static func flood_area(state: BattleState, hex: Vector2i) -> Array[Vector2i]:
	var area: Array[Vector2i] = []
	for h in [hex] + Array(state.grid.neighbors(hex)):
		if not state.is_obstacle(h):
			area.append(h)
	return area


## Свободная клетка для иллюзии: рядом с образцом, иначе рядом с создателем.
static func illusion_hex(state: BattleState, source: UnitState, maker: UnitState) -> Vector2i:
	for anchor in [source.hex, maker.hex]:
		for h in state.grid.neighbors(anchor):
			if state.is_free(h):
				return h
	return NO_HEX


## Иллюзия — копия стека с долей численности: двойной урон, без карты, исчезает после боя.
static func summon_illusion(state: BattleState, source: UnitState, hex: Vector2i, share: float, events: Array[BattleEvent]) -> UnitState:
	var copy := UnitState.from_dict(source.to_dict())
	copy.uid = state.take_uid()
	copy.hex = hex
	copy.count = maxi(1, ceili(source.count * share))
	copy.start_count = copy.count
	copy.top_hp = copy.hp
	copy.card_index = -1
	copy.illusion = true
	copy.statuses.clear()
	copy.retaliated = false
	copy.waited = false
	copy.defending = false
	copy.fury = 0
	copy.is_boss = false
	# Иллюзия — только тело: без способностей, иначе иллюзии плодят иллюзии.
	copy.ability_id = &""
	copy.ability_cd = 0
	state.units.append(copy)
	events.append(BattleEvent.new(BattleEvent.SUMMONED, {"uid": copy.uid, "source": source.uid}))
	return copy


## Применения украденной способности врага от лица Похитителя.
static func steal_options(state: BattleState, u: UnitState, target: UnitState) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	if target == null or UNSTEALABLE.has(target.ability_id):
		return result
	u.borrowed_ability = target.ability_id
	var saved := u.ability_id
	# Варианты строятся для заимствованной способности, но от лица Похитителя.
	for a in options(state, u):
		result.append(a)
	u.ability_id = saved
	u.borrowed_ability = &""
	return result


static func _nearest_enemy(state: BattleState, u: UnitState) -> UnitState:
	var best: UnitState = null
	for e in state.enemies_of(u):
		if best == null or HexGrid.distance(u.hex, e.hex) < HexGrid.distance(u.hex, best.hex):
			best = e
	return best


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
	# Одна проверка «могу ли атаковать» на всю оценку вариантов (их бывает ~100 клеток).
	_attack_cache = {u.uid: AiController.can_attack_now(state, u)}
	for a in options(state, u):
		var score := ai_score(state, u, a)
		if score > 0.0:
			result.append([a, score])
	_attack_cache = {}
	return result


static var _attack_cache := {}


static func _can_attack(state: BattleState, u: UnitState) -> bool:
	if _attack_cache.has(u.uid):
		return _attack_cache[u.uid]
	return AiController.can_attack_now(state, u)


static func ai_score(state: BattleState, u: UnitState, action: BattleAction) -> float:
	var id := effective(state, u)
	var target := state.get_unit(action.target_uid)
	match id:
		SHIELD_WALL:
			if _can_attack(state, u) or not _enemies_near(state, u, 4):
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
			if _can_attack(state, u) or not _enemies_near(state, u, 3):
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
		UNDERTOW:
			var score := AiController.value(DamageCalc.expected(u, target, false), target)
			if target.is_ranged:
				score += PUSH_SHOOTER_BONUS
			return score
		FLOOD:
			if _can_attack(state, u):
				return 0.0
			var caught := 0
			for h in flood_area(state, action.dest):
				var o := state.unit_at(h)
				if o and o.side != u.side and not o.is_flying and not o.is_ranged:
					caught += 1
			return DEFENSIVE_SCORE * caught
		OVERCLOCK:
			return 1.8 * AiController.value(DamageCalc.expected(u, target, true), target)
		TINKER:
			if target:
				return RESTORE_WEIGHT * minf(TINKER_HEAL, _missing_hp(target))
			if _can_attack(state, u) or not _enemies_near(state, u, 4):
				return 0.0
			return DEFENSIVE_SCORE
		REFLECT:
			return 15.0 + 0.15 * target.total_hp() * (RANGED_TARGET_BONUS if target.is_ranged else 1.0)
		STEAL:
			var best := 0.0
			u.borrowed_ability = target.ability_id
			for o in steal_options(state, u, target):
				u.borrowed_ability = target.ability_id
				best = maxf(best, ai_score(state, u, o))
			u.borrowed_ability = &""
			return best
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
