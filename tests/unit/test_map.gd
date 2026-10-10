extends GutTest
## Карта экспедиции: генерация, перемещение, ресурсы (SPEC_SPRINT3 3–4).

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func _maps() -> Array[MapState]:
	var result: Array[MapState] = []
	for seed_value in 40:
		result.append(MapGenerator.generate(db, seed_value * 131 + 7))
	return result


func test_deterministic() -> void:
	var a := MapGenerator.generate(db, 42)
	var b := MapGenerator.generate(db, 42)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))
	assert_ne(JSON.stringify(a.to_dict()), JSON.stringify(MapGenerator.generate(db, 43).to_dict()))


func test_structure() -> void:
	for map in _maps():
		assert_eq(map.layer_nodes(MapState.RIFT_LAYER).size(), 1, "один разлом")
		for layer in range(1, MapState.LAYERS + 1):
			assert_between(map.layer_nodes(layer).size(), 1, MapState.LANES)
		for n in map.nodes:
			if n.layer < MapState.RIFT_LAYER:
				assert_false(map.next_of(n.id).is_empty(), "из %d есть путь дальше" % n.id)
			for to in map.next_of(n.id):
				assert_eq(map.node(to).layer, n.layer + 1, "рёбра только на следующий слой")


func test_all_nodes_reachable_and_lead_to_rift() -> void:
	for map in _maps():
		var seen := {}
		var frontier: Array[int] = map.next_of(MapState.START)
		while not frontier.is_empty():
			var id: int = frontier.pop_back()
			if seen.has(id):
				continue
			seen[id] = true
			frontier.append_array(map.next_of(id))
		assert_eq(seen.size(), map.nodes.size(), "все острова достижимы")


func test_no_crossing_edges() -> void:
	for map in _maps():
		for layer in range(1, MapState.LAYERS):
			var segs: Array[Vector2i] = []
			for n in map.layer_nodes(layer):
				for to in map.next_of(n.id):
					segs.append(Vector2i(n.lane, map.node(to).lane))
			for a in segs:
				for b in segs:
					assert_false((a.x < b.x and a.y > b.y), "пересечение %s и %s на слое %d" % [a, b, layer])


func test_type_rules() -> void:
	for map in _maps():
		var has_shop := false
		var has_elite := false
		for n in map.nodes:
			match n.layer:
				1:
					assert_eq(n.type, MapState.NodeType.BATTLE)
				MapState.LAYERS:
					assert_eq(n.type, MapState.NodeType.HAVEN)
				MapState.RIFT_LAYER:
					assert_eq(n.type, MapState.NodeType.RIFT)
			if n.type == MapState.NodeType.ELITE:
				assert_gte(n.layer, MapGenerator.ELITE_FROM_LAYER)
			has_shop = has_shop or n.type == MapState.NodeType.SHOP
			has_elite = has_elite or n.type == MapState.NodeType.ELITE
			for to in map.next_of(n.id):
				var t := map.node(to).type
				if t == n.type:
					assert_false(MapGenerator.NO_REPEAT.has(t), "два подряд: %s" % MapState.NodeType.keys()[t])
		assert_true(has_shop)
		assert_true(has_elite)


func test_content_matches_type_and_tier() -> void:
	for map in _maps():
		for n in map.nodes:
			match n.type:
				MapState.NodeType.BATTLE:
					var e := db.encounter(n.content)
					assert_eq(e.tier, MapGenerator.tier_for_layer(n.layer))
					assert_false(e.elite or e.boss)
				MapState.NodeType.ELITE:
					assert_true(db.encounter(n.content).elite)
				MapState.NodeType.RIFT:
					assert_true(db.encounter(n.content).boss)
				MapState.NodeType.EVENT:
					assert_true(db.events.has(n.content))


func test_travel_by_edges_only() -> void:
	var run := RunState.create(db, 5)
	var first := run.map.next_of(MapState.START)
	assert_eq(MapActions.reachable(run), first)
	assert_true(MapActions.travel(run, first[0]))
	assert_eq(run.pending_node, first[0])
	assert_eq(MapActions.reachable(run).size(), 0, "пока остров не пройден, лететь нельзя")
	MapActions.complete(run)
	assert_true(run.map.visited.has(first[0]))
	var layer2 := run.map.layer_nodes(2).filter(func(n: MapState.MapNode) -> bool: return not run.map.next_of(first[0]).has(n.id))
	for n: MapState.MapNode in layer2:
		assert_false(MapActions.reachable(run).has(n.id))
	for id in run.map.next_of(first[0]):
		assert_true(MapActions.reachable(run).has(id))
	for id in first.slice(1):
		assert_true(MapActions.reachable(run).has(id), "назад к START и на другой остров первого слоя")
	assert_false(MapActions.reachable(run).has(first[0]), "пройденный остров не входится снова")


func test_return_for_skipped_islands() -> void:
	var run := RunState.create(db, 5)
	var skipped := run.map.next_of(MapState.START)[1]
	for step in 3:
		MapActions.travel(run, MapActions.forward(run)[0])
		MapActions.complete(run)
	assert_eq(run.map.reached_layer(), 3)
	assert_true(MapActions.reachable(run).has(skipped), "через пройденные острова — к пропущенному")
	assert_eq(MapActions.forward(run), run.map.next_of(run.map.current), "вперёд — как раньше")
	assert_true(MapActions.travel(run, skipped))
	MapActions.complete(run)
	assert_eq(run.map.current_layer(), 1)
	assert_eq(run.map.reached_layer(), 3, "глубина забега не убывает")
	assert_eq(run.total_layer(), 3)


func test_walk_to_visited_island() -> void:
	var run := RunState.create(db, 5)
	assert_true(MapActions.walk_targets(run).is_empty(), "в начале пройденных нет")
	var path: Array[int] = []
	for step in 3:
		path.append(MapActions.forward(run)[0])
		MapActions.travel(run, path[-1])
		MapActions.complete(run)
	assert_eq(MapActions.walk_targets(run).size(), 2, "два пройденных позади")
	assert_false(MapActions.walk_targets(run).has(path[2]), "текущий — не цель")
	var reach_before := MapActions.reachable(run)
	var aether: int = run.resources[RunState.AETHER]
	assert_true(MapActions.walk(run, path[0]))
	assert_eq(run.map.current, path[0])
	assert_eq(run.pending_node, -1, "остров заново не проходится")
	assert_eq(run.resources[RunState.AETHER], aether, "бесплатно")
	assert_eq(run.map.visited.size(), 3)
	assert_eq(run.map.reached_layer(), 3)
	reach_before.sort()
	var reach_after := MapActions.reachable(run)
	reach_after.sort()
	assert_eq(reach_after, reach_before, "доступные острова те же — пройденные связаны")
	assert_false(MapActions.walk(run, path[0]), "уже здесь")
	var unvisited := MapActions.reachable(run)[0]
	assert_false(MapActions.walk(run, unvisited), "на непройденный — только «Лететь»")
	MapActions.travel(run, unvisited)
	assert_true(MapActions.walk_targets(run).is_empty(), "посреди острова не ходят")


func test_all_islands_can_be_visited() -> void:
	for s in 12:
		var run := RunState.create(db, s)
		MapActions.begin_act(db, run, 1 + s % 2)
		var rift := -1
		while true:
			var open := MapActions.reachable(run).filter(func(id: int) -> bool: return run.map.node(id).type != MapState.NodeType.RIFT)
			if open.is_empty():
				break
			assert_true(MapActions.travel(run, open[0]))
			MapActions.complete(run)
		for n in run.map.nodes:
			if n.type == MapState.NodeType.RIFT:
				rift = n.id
			else:
				assert_true(run.map.visited.has(n.id), "сид %d: остров %d пройден" % [s, n.id])
		assert_true(MapActions.reachable(run).has(rift), "Разлом доступен")
		assert_eq(run.map.reached_layer(), MapState.LAYERS)


func test_flight_costs_aether() -> void:
	var run := _run_with_flight_target()
	if run == null:
		pass_test("на тестовых сидах нет острова для перелёта")
		return
	var target: int = MapActions.flight_targets(run)[0]
	run.resources[RunState.AETHER] = 1
	assert_false(MapActions.can_travel(run, target), "мало Эфира")
	run.resources[RunState.AETHER] = 3
	assert_true(MapActions.travel(run, target))
	assert_eq(run.resources[RunState.AETHER], 1)


func test_scout_reveals_and_costs() -> void:
	var run := RunState.create(db, 5)
	var id: int = run.map.next_of(MapState.START)[0]
	run.resources[RunState.AETHER] = 1
	assert_true(MapActions.scout(run, id))
	assert_true(run.map.node(id).scouted)
	assert_eq(run.resources[RunState.AETHER], 0)
	assert_false(MapActions.can_scout(run, id), "уже разведан")


func test_rewards_by_tier() -> void:
	var t1 := MapActions.battle_rewards(db.encounter(&"crypt_1"))
	var elite := MapActions.battle_rewards(db.encounter(&"crypt_5"))
	assert_eq(t1[RunState.PARCHMENT], 2)
	assert_eq(elite[RunState.PARCHMENT], 4)
	assert_true(MapActions.battle_rewards(db.encounter(db.boss_encounter())).values().all(func(v: int) -> bool: return v == 0))


func test_resources_never_negative() -> void:
	var run := RunState.create(db, 1)
	run.gain(RunState.INK, -100)
	assert_eq(run.resources[RunState.INK], 0)
	assert_false(run.spend(RunState.PARCHMENT, 100))
	assert_eq(run.resources[RunState.PARCHMENT], RunState.START_RESOURCES[RunState.PARCHMENT])


func test_elite_reward_guarantees_hero_card() -> void:
	var run := RunState.create(db, 9)
	var offer := run.roll_rewards(db, true)
	assert_true(offer.any(func(id: StringName) -> bool: return not db.memory(id).is_unit()))
	run.codex.add(db, &"last_king")
	for i in 10:
		var again := run.roll_rewards(db, true)
		assert_eq(again.size(), RunState.REWARD_CHOICES)


func _run_with_flight_target() -> RunState:
	for s in 30:
		var run := RunState.create(db, s)
		MapActions.travel(run, run.map.next_of(MapState.START)[0])
		MapActions.complete(run)
		if not MapActions.flight_targets(run).is_empty():
			return run
	return null
