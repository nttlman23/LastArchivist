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
