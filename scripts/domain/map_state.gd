class_name MapState
extends RefCounted
## Карта экспедиции: граф слоёв островов (SPEC_SPRINT3 3). Только данные.

enum NodeType { BATTLE, ELITE, EVENT, SHOP, HAVEN, RIFT, RELIQUARY }

const LAYERS := 7
const LANES := 4
const RIFT_LAYER := LAYERS + 1
## Узел «до карты»: с него доступен весь первый слой.
const START := -1


class MapNode:
	var id: int
	var layer: int
	var lane: int
	var type: NodeType
	## id встречи (бои) или события; пусто для лавки и гавани.
	var content: StringName
	var scouted := false

	func _init(p_id: int = 0, p_layer: int = 0, p_lane: int = 0, p_type: NodeType = NodeType.BATTLE) -> void:
		id = p_id
		layer = p_layer
		lane = p_lane
		type = p_type

	func is_battle() -> bool:
		return type == NodeType.BATTLE or type == NodeType.ELITE or type == NodeType.RIFT


var nodes: Array[MapNode] = []
## id -> id узлов следующего слоя.
var edges: Dictionary[int, Array] = {}
var current := START
var visited: Array[int] = []


func node(id: int) -> MapNode:
	return nodes[id]


func layer_nodes(layer: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.layer == layer:
			result.append(n)
	return result


func node_at(layer: int, lane: int) -> MapNode:
	for n in nodes:
		if n.layer == layer and n.lane == lane:
			return n
	return null


func next_of(id: int) -> Array[int]:
	var result: Array[int] = []
	if id == START:
		for n in layer_nodes(1):
			result.append(n.id)
		return result
	for to in edges.get(id, []):
		result.append(int(to))
	return result


## Соседи по мостам в обе стороны (SPEC_SPRINT3 3.4): следующий и предыдущий слой; первый слой связан со START.
func linked(id: int) -> Array[int]:
	var result := next_of(id)
	if id != START and node(id).layer == 1:
		result.append(START)
	for from in edges:
		if edges[from].has(id) and not result.has(from):
			result.append(from)
	return result


## Через остров можно пройти насквозь: он уже пройден (или это START).
func passable(id: int) -> bool:
	return id == START or visited.has(id)


func current_layer() -> int:
	return 0 if current == START else node(current).layer


## Самый дальний достигнутый слой: по карте можно вернуться назад, а глубина забега не убывает.
func reached_layer() -> int:
	var result := current_layer()
	for id in visited:
		result = maxi(result, node(id).layer)
	return result


func add_edge(from: int, to: int) -> void:
	if not edges.has(from):
		edges[from] = []
	if not edges[from].has(to):
		edges[from].append(to)


func to_dict() -> Dictionary:
	var ns: Array = []
	for n in nodes:
		ns.append({"id": n.id, "layer": n.layer, "lane": n.lane, "type": n.type, "content": String(n.content), "scouted": n.scouted})
	var es := {}
	for from in edges:
		es[str(from)] = edges[from].duplicate()
	return {"nodes": ns, "edges": es, "current": current, "visited": visited.duplicate()}


static func from_dict(d: Dictionary) -> MapState:
	var m := MapState.new()
	for nd: Dictionary in d["nodes"]:
		var n := MapNode.new(int(nd["id"]), int(nd["layer"]), int(nd["lane"]), int(nd["type"]) as NodeType)
		n.content = StringName(nd["content"])
		n.scouted = bool(nd["scouted"])
		m.nodes.append(n)
	var es: Dictionary = d["edges"]
	for from: String in es:
		for to in es[from]:
			m.add_edge(int(from), int(to))
	m.current = int(d["current"])
	for id in d["visited"]:
		m.visited.append(int(id))
	return m
