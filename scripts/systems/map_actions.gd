class_name MapActions
extends RefCounted
## Перемещение по карте экспедиции (SPEC_SPRINT3 3.2): по рёбрам, перелётом, разведка.

const SCOUT_COST := 1
const FLIGHT_COST := 2
const FLIGHT_LANES := 2


## Острова, куда можно попасть по мостам (SPEC_SPRINT3 3.4): мосты двусторонние, по пройденным островам
## ходить свободно — доступен любой непройденный остров рядом с ними. Разлом насквозь не проходится.
static func reachable(run: RunState) -> Array[int]:
	var result: Array[int] = []
	if run.pending_node >= 0:
		return result
	var map := run.map
	var seen: Dictionary[int, bool] = {map.current: true}
	var frontier: Array[int] = [map.current]
	var head := 0
	while head < frontier.size():
		var cur := frontier[head]
		head += 1
		for nxt in map.linked(cur):
			if seen.has(nxt):
				continue
			seen[nxt] = true
			if map.passable(nxt):
				frontier.append(nxt)
			else:
				result.append(nxt)
	return result


## Острова на следующем слое, связанные с текущим мостом, — путь «только вперёд» (для MapAi).
static func forward(run: RunState) -> Array[int]:
	var open := reachable(run)
	return run.map.next_of(run.map.current).filter(func(id: int) -> bool: return open.has(id))


## Начало акта act: новая карта, пул карт акта (SPEC_SPRINT7 2). Кодекс и ресурсы — как были.
static func begin_act(db: DefsDB, run: RunState, act: int, profile: ProfileState = null) -> void:
	run.act = act
	run.at_camp = false
	run.pending_node = -1
	run.pending_battle = &""
	run.pending_reward_card = &""
	run.map = MapGenerator.generate(db, run.run_seed, run.event_pool, act)
	if act >= 2:
		MetaUpgrades.apply_camp(run)
	var school := db.school(run.school_id)
	if profile:
		run.card_pool = MetaRewards.card_pool(db, profile, school, act)
	else:
		run.card_pool = db.pool_memory_ids(act)
		for id in school.favored_memories:
			run.card_pool.append(id)


## Путь по мостам от текущего острова до непройденного target (без текущего, с target; может идти через
## START и пройденные острова); пусто — не дойти. Выбирается путь с наименьшим числом непройденных островов,
## при равенстве — самый короткий.
static func path_to(run: RunState, target: int) -> Array[int]:
	var map := run.map
	var path: Array[int] = []
	var start := map.current
	if target == start or target == MapState.START or map.passable(target):
		return path
	# Дейкстра на маленьком графе: шаг на непройденный остров стоит UNVISITED_STEP, на пройденный — 1.
	const UNVISITED_STEP := 100
	var dist: Dictionary[int, int] = {start: 0}
	var prev: Dictionary[int, int] = {}
	var done: Dictionary[int, bool] = {}
	while true:
		var cur := -2
		for id in dist:
			if not done.has(id) and (cur == -2 or dist[id] < dist[cur]):
				cur = id
		if cur == -2 or cur == target:
			break
		done[cur] = true
		# Сквозь непройденный остров путь идёт (его придётся пройти), сквозь Разлом — нет.
		if cur != start and cur != MapState.START and map.node(cur).type == MapState.NodeType.RIFT:
			continue
		for nxt in map.linked(cur):
			var d := dist[cur] + (1 if map.passable(nxt) else UNVISITED_STEP)
			if not dist.has(nxt) or d < dist[nxt]:
				dist[nxt] = d
				prev[nxt] = cur
	if not prev.has(target):
		return path
	var cur := target
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


## Ресурсы за бои на пути (награды за победу; пройденные острова пусты).
static func path_rewards(db: DefsDB, run: RunState, path: Array[int]) -> Dictionary[StringName, int]:
	var total := _res(0, 0, 0)
	for id in path:
		if run.map.passable(id):
			continue
		var n := run.map.node(id)
		if n.is_battle() and n.content != &"":
			var r := battle_rewards(db.encounter(n.content))
			for k in r:
				total[k] += r[k]
	return total


## Дальность перелёта в полосах: +1 с «Тайными тропами».
static func flight_lanes(run: RunState) -> int:
	return FLIGHT_LANES + (1 if MetaUpgrades.has(run, MetaUpgrades.SECRET_PATHS) else 0)


## Цена разведки: −1 с «Картой с пометками».
static func scout_cost(run: RunState) -> int:
	return maxi(0, SCOUT_COST - (1 if MetaUpgrades.has(run, MetaUpgrades.MARKED_MAP) else 0))


## Острова следующего слоя, доступные только перелётом.
static func flight_targets(run: RunState) -> Array[int]:
	var result: Array[int] = []
	if run.pending_node >= 0 or run.map.current == MapState.START:
		return result
	var cur := run.map.node(run.map.current)
	var linked := reachable(run)
	for n in run.map.layer_nodes(cur.layer + 1):
		if not linked.has(n.id) and not run.map.visited.has(n.id) and absi(n.lane - cur.lane) <= flight_lanes(run):
			result.append(n.id)
	return result


static func can_travel(run: RunState, node_id: int) -> bool:
	if reachable(run).has(node_id):
		return true
	return flight_targets(run).has(node_id) and run.can_afford(RunState.AETHER, FLIGHT_COST)


## Начинает прохождение острова: по мосту бесплатно, перелётом — за Эфир.
static func travel(run: RunState, node_id: int) -> bool:
	if not can_travel(run, node_id):
		return false
	if not reachable(run).has(node_id):
		run.spend(RunState.AETHER, FLIGHT_COST)
	run.map.current = node_id
	run.pending_node = node_id
	run.pending_battle = &""
	run.pending_reward_card = &""
	return true


static func can_scout(run: RunState, node_id: int) -> bool:
	var n := run.map.node(node_id)
	var visible := reachable(run).has(node_id) or flight_targets(run).has(node_id)
	return visible and not n.scouted and n.content != &"" and run.can_afford(RunState.AETHER, scout_cost(run))


static func scout(run: RunState, node_id: int) -> bool:
	if not can_scout(run, node_id):
		return false
	run.spend(RunState.AETHER, scout_cost(run))
	run.map.node(node_id).scouted = true
	return true


## Остров пройден: возврат на карту.
static func complete(run: RunState) -> void:
	# Типы пройденных островов — для достижения «Полная летопись» (SPEC_SPRINT9 6).
	if run.pending_node >= 0 and not run.node_types.has(run.map.node(run.pending_node).type):
		run.node_types.append(run.map.node(run.pending_node).type)
	if run.pending_node >= 0 and not run.map.visited.has(run.pending_node):
		run.map.visited.append(run.pending_node)
	run.pending_node = -1
	run.pending_battle = &""
	run.pending_reward_card = &""


## Награда ресурсами за победу во встрече (SPEC_SPRINT3 4).
static func battle_rewards(encounter: EncounterDef) -> Dictionary[StringName, int]:
	if encounter.boss:
		return _res(0, 0, 0)
	if encounter.elite:
		return _res(2, 4, 2)
	match encounter.tier:
		1:
			return _res(1, 2, 1)
		2:
			return _res(1, 3, 1)
	return _res(2, 3, 2)


static func _res(ink: int, parchment: int, aether: int) -> Dictionary[StringName, int]:
	var r: Dictionary[StringName, int] = {}
	r[RunState.INK] = ink
	r[RunState.PARCHMENT] = parchment
	r[RunState.AETHER] = aether
	return r
