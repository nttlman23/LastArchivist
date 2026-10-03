class_name MapActions
extends RefCounted
## Перемещение по карте экспедиции (SPEC_SPRINT3 3.2): по рёбрам, перелётом, разведка.

const SCOUT_COST := 1
const FLIGHT_COST := 2
const FLIGHT_LANES := 2


## Острова, куда можно попасть по мостам.
static func reachable(run: RunState) -> Array[int]:
	if run.pending_node >= 0:
		return []
	return run.map.next_of(run.map.current)


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


## Путь по мостам от текущего острова до target (без текущего, с target); пусто — не дойти.
static func path_to(run: RunState, target: int) -> Array[int]:
	var start := run.map.current
	var prev: Dictionary[int, int] = {start: start}
	var frontier: Array[int] = [start]
	var head := 0
	while head < frontier.size():
		var cur := frontier[head]
		head += 1
		if cur == target:
			break
		for nxt in run.map.next_of(cur):
			if not prev.has(nxt):
				prev[nxt] = cur
				frontier.append(nxt)
	var path: Array[int] = []
	if not prev.has(target) or target == start:
		return path
	var cur := target
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


## Ресурсы за бои на пути (награды за победу).
static func path_rewards(db: DefsDB, run: RunState, path: Array[int]) -> Dictionary[StringName, int]:
	var total := _res(0, 0, 0)
	for id in path:
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
		if not linked.has(n.id) and absi(n.lane - cur.lane) <= flight_lanes(run):
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
