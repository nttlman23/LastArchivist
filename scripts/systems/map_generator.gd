class_name MapGenerator
extends RefCounted
## Генерация карты экспедиции по сиду (SPEC_SPRINT3 3.1).

const PATHS := 4
const MAX_ATTEMPTS := 50
## Веса типов на слоях 2–6.
const WEIGHTS := {
	MapState.NodeType.BATTLE: 45,
	MapState.NodeType.EVENT: 25,
	MapState.NodeType.SHOP: 12,
	MapState.NodeType.HAVEN: 10,
	MapState.NodeType.ELITE: 8,
}
const ELITE_FROM_LAYER := 3
## Нельзя два подряд по ребру.
const NO_REPEAT: Array[MapState.NodeType] = [MapState.NodeType.SHOP, MapState.NodeType.HAVEN]


static func tier_for_layer(layer: int) -> int:
	return clampi((layer + 1) / 2, 1, 3)


static func generate(db: DefsDB, seed_value: int) -> MapState:
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("map:%d:%d" % [seed_value, attempt])
		var map := _build_graph(rng)
		_assign_types(map, rng)
		if _valid(map):
			_assign_content(db, map, rng)
			return map
	push_error("Не удалось сгенерировать карту для сида %d" % seed_value)
	return MapState.new()


static func _build_graph(rng: RandomNumberGenerator) -> MapState:
	var map := MapState.new()
	var ids: Dictionary[Vector2i, int] = {}  # (layer, lane) -> id
	var get_id := func(layer: int, lane: int) -> int:
		var key := Vector2i(layer, lane)
		if not ids.has(key):
			ids[key] = map.nodes.size()
			map.nodes.append(MapState.MapNode.new(map.nodes.size(), layer, lane))
		return ids[key]
	# Рёбра по слоям для проверки пересечений: layer -> Array[Vector2i(lane_from, lane_to)].
	var segments: Dictionary[int, Array] = {}
	var starts: Array[int] = []
	for p in PATHS:
		# Первые два пути — из разных дорожек, чтобы карта не была «нитью».
		var lane := rng.randi_range(0, MapState.LANES - 1)
		if p == 1:
			while starts.has(lane):
				lane = rng.randi_range(0, MapState.LANES - 1)
		starts.append(lane)
		var prev: int = get_id.call(1, lane)
		for layer in range(2, MapState.LAYERS + 1):
			var next_lane := _step(rng, lane, segments.get(layer - 1, []))
			var nid: int = get_id.call(layer, next_lane)
			map.add_edge(prev, nid)
			if not segments.has(layer - 1):
				segments[layer - 1] = []
			segments[layer - 1].append(Vector2i(lane, next_lane))
			lane = next_lane
			prev = nid
	var rift := MapState.MapNode.new(map.nodes.size(), MapState.RIFT_LAYER, (MapState.LANES - 1) / 2, MapState.NodeType.RIFT)
	map.nodes.append(rift)
	for n in map.layer_nodes(MapState.LAYERS):
		map.add_edge(n.id, rift.id)
	return map


## Шаг дорожки −1/0/+1 без пересечения с уже проложенными рёбрами этого слоя.
static func _step(rng: RandomNumberGenerator, lane: int, existing: Array) -> int:
	var options: Array[int] = []
	for d in [-1, 0, 1]:
		var to: int = lane + d
		if to < 0 or to >= MapState.LANES:
			continue
		var crosses := false
		for seg: Vector2i in existing:
			# Рёбра (a→b) и (c→d) пересекаются, если порядок концов меняется.
			if (seg.x < lane and seg.y > to) or (seg.x > lane and seg.y < to):
				crosses = true
				break
		if not crosses:
			options.append(to)
	if options.is_empty():
		return lane
	return options[rng.randi_range(0, options.size() - 1)]


static func _assign_types(map: MapState, rng: RandomNumberGenerator) -> void:
	# Идём по слоям снизу вверх, чтобы знать типы предков.
	var parents := _parents(map)
	for layer in range(1, MapState.LAYERS + 1):
		for n in map.layer_nodes(layer):
			if layer == 1:
				n.type = MapState.NodeType.BATTLE
			elif layer == MapState.LAYERS:
				n.type = MapState.NodeType.HAVEN
			else:
				var banned: Array[MapState.NodeType] = []
				for p in parents.get(n.id, []):
					var pt := map.node(p).type
					if NO_REPEAT.has(pt):
						banned.append(pt)
				if layer < ELITE_FROM_LAYER:
					banned.append(MapState.NodeType.ELITE)
				n.type = _weighted(rng, banned)
	# Слой 6 → гавань на слое 7: гавань не может стоять сразу после гавани.
	for n in map.layer_nodes(MapState.LAYERS - 1):
		if n.type == MapState.NodeType.HAVEN:
			n.type = MapState.NodeType.BATTLE


static func _weighted(rng: RandomNumberGenerator, banned: Array[MapState.NodeType]) -> MapState.NodeType:
	var total := 0
	for t in WEIGHTS:
		if not banned.has(t):
			total += WEIGHTS[t]
	var roll := rng.randi_range(1, total)
	for t in WEIGHTS:
		if banned.has(t):
			continue
		roll -= WEIGHTS[t]
		if roll <= 0:
			return t
	return MapState.NodeType.BATTLE


static func _parents(map: MapState) -> Dictionary:
	var result := {}
	for from in map.edges:
		for to in map.edges[from]:
			if not result.has(to):
				result[to] = []
			result[to].append(from)
	return result


static func _valid(map: MapState) -> bool:
	var has_shop := false
	var has_elite := false
	for n in map.nodes:
		has_shop = has_shop or n.type == MapState.NodeType.SHOP
		has_elite = has_elite or n.type == MapState.NodeType.ELITE
	return has_shop and has_elite


## Встречи и события без повторов, пока пул не исчерпан.
static func _assign_content(db: DefsDB, map: MapState, rng: RandomNumberGenerator) -> void:
	var pools := {}
	var draw := func(key: String, source: Array[StringName]) -> StringName:
		if not pools.has(key) or pools[key].is_empty():
			var fresh := source.duplicate()
			_shuffle(fresh, rng)
			pools[key] = fresh
		return pools[key].pop_back()
	for n in map.nodes:
		match n.type:
			MapState.NodeType.BATTLE:
				var tier := tier_for_layer(n.layer)
				n.content = draw.call("tier%d" % tier, db.encounter_pool(tier, false))
			MapState.NodeType.ELITE:
				n.content = draw.call("elite", db.encounter_pool(0, true))
			MapState.NodeType.EVENT:
				n.content = draw.call("event", db.event_ids())
			MapState.NodeType.RIFT:
				n.content = db.boss_encounter()


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
