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


## Острова следующего слоя, доступные только перелётом.
static func flight_targets(run: RunState) -> Array[int]:
	var result: Array[int] = []
	if run.pending_node >= 0 or run.map.current == MapState.START:
		return result
	var cur := run.map.node(run.map.current)
	var linked := reachable(run)
	for n in run.map.layer_nodes(cur.layer + 1):
		if not linked.has(n.id) and absi(n.lane - cur.lane) <= FLIGHT_LANES:
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
	return visible and not n.scouted and n.content != &"" and run.can_afford(RunState.AETHER, SCOUT_COST)


static func scout(run: RunState, node_id: int) -> bool:
	if not can_scout(run, node_id):
		return false
	run.spend(RunState.AETHER, SCOUT_COST)
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
