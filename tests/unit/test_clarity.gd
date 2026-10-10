extends GutTest
## Этап A Спринта 5: подсказки наград, риск боёв, путь на карте, летопись.

const PROFILE_PATH := "user://test_chronicle_profile.cfg"

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_all() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		SafeFile.remove(PROFILE_PATH)


func _codex(ids: Array[StringName]) -> CodexState:
	var c := CodexState.new()
	for id in ids:
		c.add(db, id)
	return c


# --- Советник карт ---------------------------------------------------------------

func test_roles() -> void:
	assert_eq(CardAdvisor.role(db, &"salt_legion"), CardAdvisor.Role.MELEE)
	assert_eq(CardAdvisor.role(db, &"clock_turrets"), CardAdvisor.Role.RANGED)
	assert_eq(CardAdvisor.role(db, &"brass_tinkers"), CardAdvisor.Role.SUPPORT)
	assert_eq(CardAdvisor.role(db, &"last_king"), CardAdvisor.Role.HERO)


func test_reasons_show_gap_and_fuse() -> void:
	var codex := _codex([&"clock_turrets", &"brass_tinkers"] as Array[StringName])
	var gap := CardAdvisor.reasons(db, codex, &"salt_legion")
	assert_eq(gap[0][2], "ROLE_MELEE_TIP", "первой идёт роль")
	assert_true(gap.any(func(r: Array) -> bool: return r[2] == "ADVICE_GAP_TIP"), "ближнего боя нет — закрывает дыру")
	assert_true(gap.any(func(r: Array) -> bool: return r[2] == "ADVICE_MORE_UNITS_TIP"), "отрядов меньше четырёх")
	var dup := CardAdvisor.reasons(db, codex, &"clock_turrets")
	assert_false(dup.any(func(r: Array) -> bool: return r[2] == "ADVICE_GAP_TIP"), "стрелок уже есть")
	assert_true(dup.any(func(r: Array) -> bool: return r[2] == "ADVICE_FUSE_TIP"), "такая карта есть — можно слить")


func test_similar_card_is_same_role() -> void:
	var codex := _codex([&"salt_legion", &"clock_turrets"] as Array[StringName])
	assert_eq(CardAdvisor.similar_card(db, codex, &"ghoul_pack"), 0)
	assert_eq(CardAdvisor.similar_card(db, codex, &"brass_tinkers"), -1)


func test_risk_levels() -> void:
	var codex := _codex([&"salt_legion", &"salt_legion", &"ghoul_pack", &"ash_chroniclers"] as Array[StringName])
	var army := CardAdvisor.army_power(db, codex)
	assert_gt(army, 0.0)
	var enc := EncounterDef.new()
	enc.unit_ids = [&"ash_ghoul"] as Array[StringName]
	var per_ghoul := CardAdvisor.stack_power(db.unit(&"ash_ghoul"), 1)
	enc.counts = [int(army * 0.3 / per_ghoul)] as Array[int]
	assert_eq(CardAdvisor.risk(db, codex, enc), CardAdvisor.Risk.LOW)
	enc.counts = [int(army * 0.6 / per_ghoul)] as Array[int]
	assert_eq(CardAdvisor.risk(db, codex, enc), CardAdvisor.Risk.EVEN)
	enc.counts = [int(army * 1.0 / per_ghoul)] as Array[int]
	assert_eq(CardAdvisor.risk(db, codex, enc), CardAdvisor.Risk.HIGH)
	enc.counts = [int(army * 0.3 / per_ghoul)] as Array[int]
	enc.boss = true
	assert_eq(CardAdvisor.risk(db, codex, enc), CardAdvisor.Risk.EVEN, "Разлом — на уровень выше")


func test_empty_army_is_high_risk() -> void:
	var enc := db.encounter(&"t1_wall")
	assert_eq(CardAdvisor.risk(db, CodexState.new(), enc), CardAdvisor.Risk.HIGH)


func test_unscouted_risk_uses_tier_average() -> void:
	var run := RunState.create(db, 5)
	for n in run.map.nodes:
		if n.type == MapState.NodeType.BATTLE:
			var enc := db.encounter(n.content)
			var expected := CardAdvisor.risk_of_power(db, run.codex, CardAdvisor.expected_power(db, enc.tier, false))
			assert_eq(CardAdvisor.node_risk(db, run, n), expected)
			n.scouted = true
			assert_eq(CardAdvisor.node_risk(db, run, n), CardAdvisor.risk(db, run.codex, enc))
			return
	fail_test("нет боя на карте")


func test_non_battle_has_no_risk() -> void:
	var run := RunState.create(db, 5)
	for n in run.map.nodes:
		if not n.is_battle():
			assert_eq(CardAdvisor.node_risk(db, run, n), -1)
			return


# --- Путь на карте ---------------------------------------------------------------

func test_path_to_follows_bridges() -> void:
	var run := RunState.create(db, 7)
	for n in run.map.layer_nodes(3):
		var path := MapActions.path_to(run, n.id)
		if path.is_empty():
			continue
		assert_eq(path.size(), 3, "слои 1–3")
		assert_eq(path[-1], n.id)
		assert_true(run.map.next_of(MapState.START).has(path[0]))
		for i in range(1, path.size()):
			assert_true(run.map.linked(path[i - 1]).has(path[i]), "по мостам")
		var rewards := MapActions.path_rewards(db, run, path)
		var expected := 0
		for id in path:
			var node := run.map.node(id)
			if node.is_battle():
				expected += MapActions.battle_rewards(db.encounter(node.content))[RunState.PARCHMENT]
		assert_eq(rewards[RunState.PARCHMENT], expected)
		return
	fail_test("нет пути")


func test_path_to_current_or_start_is_empty() -> void:
	var run := RunState.create(db, 7)
	var first := run.map.next_of(MapState.START)[0]
	MapActions.travel(run, first)
	MapActions.complete(run)
	assert_true(MapActions.path_to(run, first).is_empty(), "текущий — некуда идти")
	assert_true(MapActions.path_to(run, MapState.START).is_empty())
	var second := MapActions.forward(run)[0]
	MapActions.travel(run, second)
	MapActions.complete(run)
	assert_eq(MapActions.path_to(run, first), [first] as Array[int], "к пройденному — по мосту назад")


func test_path_back_through_visited() -> void:
	var run := RunState.create(db, 7)
	var layer1 := run.map.next_of(MapState.START)
	for step in 2:
		MapActions.travel(run, MapActions.forward(run)[0])
		MapActions.complete(run)
	var far := layer1.filter(func(id: int) -> bool: return id != layer1[0] and not run.map.linked(run.map.current).has(id))
	assert_false(far.is_empty(), "на сиде 7 есть остров первого слоя без моста к текущему")
	var path := MapActions.path_to(run, far[0])
	assert_eq(path, [layer1[0], MapState.START, far[0]] as Array[int], "вниз по пройденным, через START")
	var rewards := MapActions.path_rewards(db, run, path)
	var n := run.map.node(far[0])
	var expected := MapActions.battle_rewards(db.encounter(n.content))[RunState.PARCHMENT] if n.is_battle() else 0
	assert_eq(rewards[RunState.PARCHMENT], expected, "пройденные острова наград не дают")


# --- Летопись --------------------------------------------------------------------

func test_finish_run_writes_chronicle() -> void:
	var profile := ProfileState.new()
	var run := RunState.create(db, 9, &"tide_order")
	MapActions.travel(run, run.map.next_of(MapState.START)[0])
	MetaRewards.finish_run(profile, run, false, db)
	assert_eq(profile.chronicle.size(), 1)
	var e := profile.chronicle[0]
	assert_eq(e["school"], "tide_order")
	assert_eq(e["outcome"], ProfileState.OUTCOME_LOST)
	assert_eq(e["layer"], 1)
	assert_eq(e["encounter"], String(run.current_encounter_id(db)))
	assert_eq((e["codex"] as Array).size(), run.codex.cards.size())
	assert_eq(profile.school_stats[&"tide_order"]["runs"], 1)
	assert_eq(profile.school_stats[&"tide_order"]["wins"], 0)


func test_chronicle_trims_and_orders() -> void:
	var profile := ProfileState.new()
	for i in 25:
		profile.record_run({"school": "ash_archive", "layer": i % 8, "outcome": ProfileState.OUTCOME_WON if i == 24 else ProfileState.OUTCOME_LOST})
	assert_eq(profile.chronicle.size(), ProfileState.CHRONICLE_SIZE)
	assert_eq(profile.chronicle[0]["outcome"], ProfileState.OUTCOME_WON, "новые — первыми")
	var stats := profile.school_stats[&"ash_archive"]
	assert_eq(stats["runs"], 25, "сводка — за всё время, не только 20 записей")
	assert_eq(stats["wins"], 1)
	assert_eq(stats["best"], 7)


func test_abandon_records_without_points() -> void:
	var profile := ProfileState.new()
	var run := RunState.create(db, 9)
	MetaRewards.abandon_run(profile, run)
	assert_eq(profile.chronicle[0]["outcome"], ProfileState.OUTCOME_ABANDONED)
	assert_eq(profile.chronicle[0]["points"], 0)
	assert_eq(profile.points, 0)


func test_chronicle_roundtrip() -> void:
	var profile := ProfileState.new()
	profile.record_run({"school": "garden_of_faces", "layer": 5, "outcome": ProfileState.OUTCOME_LOST, "codex": ["salt_legion"]})
	profile.save(PROFILE_PATH)
	var loaded := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(loaded.chronicle.size(), 1)
	assert_eq(loaded.chronicle[0]["layer"], 5)
	assert_eq(loaded.school_stats[&"garden_of_faces"]["best"], 5)


func test_old_profile_without_chronicle() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", ProfileState.VERSION)
	cfg.set_value("profile", "points", 7)
	cfg.save(PROFILE_PATH)
	var loaded := ProfileState.load_or_new(PROFILE_PATH)
	assert_eq(loaded.points, 7)
	assert_true(loaded.chronicle.is_empty())
	assert_true(loaded.school_stats.is_empty())
