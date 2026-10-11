extends GutTest


func _pair(atk: int, def: int) -> Array[UnitState]:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 0), 10, {"attack": atk, "dmg_min": 3, "dmg_max": 3})
	var d := TestHelpers.add(s, 1, Vector2i(1, 0), 10, {"defense": def})
	return [a, d]


func test_modifier_equal_stats() -> void:
	assert_almost_eq(DamageCalc.attack_modifier(5, 5), 1.0, 0.0001)


func test_modifier_attack_advantage_and_cap() -> void:
	assert_almost_eq(DamageCalc.attack_modifier(15, 5), 1.5, 0.0001)
	assert_almost_eq(DamageCalc.attack_modifier(100, 0), 4.0, 0.0001)


func test_modifier_defense_advantage_and_cap() -> void:
	assert_almost_eq(DamageCalc.attack_modifier(5, 15), 0.75, 0.0001)
	assert_almost_eq(DamageCalc.attack_modifier(0, 100), 0.3, 0.0001)


func test_fixed_damage() -> void:
	var p := _pair(5, 5)
	assert_eq(DamageCalc.roll(p[0], p[1], false, RandomNumberGenerator.new()), 30)


func test_defending_raises_defense() -> void:
	var p := _pair(5, 10)
	p[1].defending = true
	# защита 13 против атаки 5 -> 1 - 0.025 * 8 = 0.8
	assert_eq(DamageCalc.damage_range(p[0], p[1], false), Vector2i(24, 24))


func test_long_range_penalty() -> void:
	var p := _pair(5, 5)
	p[0].is_ranged = true
	assert_eq(DamageCalc.damage_range(p[0], p[1], true).x, 30)
	p[1].hex = Vector2i(9, 0)
	assert_eq(DamageCalc.damage_range(p[0], p[1], true).x, 15)


func test_shooter_melee_penalty() -> void:
	var p := _pair(5, 5)
	p[0].is_ranged = true
	assert_eq(DamageCalc.damage_range(p[0], p[1], false).x, 15)


func test_min_damage_one() -> void:
	var p := _pair(0, 100)
	p[0].count = 1
	p[0].dmg_min = 1
	p[0].dmg_max = 1
	assert_eq(DamageCalc.damage_range(p[0], p[1], false), Vector2i(1, 1))


func test_take_damage_and_kills() -> void:
	var d: UnitState = _pair(5, 5)[1]
	assert_eq(DamageCalc.kills(d, 25), 2)
	assert_eq(d.take_damage(25), 2)
	assert_eq(d.count, 8)
	assert_eq(d.top_hp, 5)
	assert_eq(d.take_damage(5), 1)
	assert_eq(d.count, 7)
	assert_eq(d.top_hp, 10)
	assert_eq(d.take_damage(1000), 7)
	assert_false(d.is_alive())


func test_roll_in_range() -> void:
	var s := TestHelpers.empty_battle()
	var a := TestHelpers.add(s, 0, Vector2i(0, 0), 20, {"dmg_min": 1, "dmg_max": 6})
	var d := TestHelpers.add(s, 1, Vector2i(1, 0), 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 50:
		assert_between(DamageCalc.roll(a, d, false, rng), 20, 120)


# --- Разбор урона (SPEC_SPRINT11 3) ----------------------------------------------

## Разбор даёт тот же итог, что бой: произведение множителей и диапазон.
func test_breakdown_matches_damage_range() -> void:
	var cases := [
		{"atk": 7, "def": 4},
		{"atk": 4, "def": 9, "defending": true},
		{"atk": 6, "def": 3, "ranged": true, "far": true},
		{"atk": 6, "def": 3, "is_ranged": true},
		{"atk": 5, "def": 5, "mark": true},
		{"atk": 5, "def": 5, "illusion": true},
		{"atk": 8, "def": 2, "bonus": 1.5},
	]
	for c: Dictionary in cases:
		var s := TestHelpers.empty_battle()
		var a := TestHelpers.add(s, 0, Vector2i(0, 0), 12, {"attack": c["atk"], "dmg_min": 2, "dmg_max": 5})
		var d := TestHelpers.add(s, 1, Vector2i(8, 0) if c.get("far", false) else Vector2i(1, 0), 10, {"defense": c["def"]})
		a.is_ranged = c.get("ranged", false) or c.get("is_ranged", false)
		d.defending = c.get("defending", false)
		d.illusion = c.get("illusion", false)
		if c.get("mark", false):
			d.statuses[UnitState.STATUS_MARKED] = 1
		var ranged: bool = c.get("ranged", false)
		var bonus: float = c.get("bonus", 1.0)
		var b := DamageCalc.breakdown(a, d, ranged, bonus)
		assert_almost_eq(float(b["factor"]), DamageCalc.multiplier(a, d, ranged) * bonus, 0.0001, str(c))
		assert_eq(b["range"], DamageCalc.damage_range(a, d, ranged, bonus), str(c))
		assert_eq(b["base_min"], 24)
		assert_eq(b["base_max"], 60)
		var kinds: Array = (b["parts"] as Array).map(func(p: Dictionary) -> StringName: return p["kind"])
		assert_eq(kinds[0], &"attack")
		assert_eq(kinds.has(&"far"), c.get("far", false), str(c))
		assert_eq(kinds.has(&"melee_ranged"), c.get("is_ranged", false), str(c))
		assert_eq(kinds.has(&"mark"), c.get("mark", false), str(c))
		assert_eq(kinds.has(&"illusion"), c.get("illusion", false), str(c))
		assert_eq(kinds.has(&"bonus"), c.has("bonus"), str(c))


func test_retaliation_range() -> void:
	var p := _pair(5, 5)
	var back := DamageCalc.retaliation_range(p[0], p[1], 0)
	assert_eq(back, DamageCalc.damage_range(p[1], p[0], false), "без потерь — ответ полным стеком")
	assert_eq(DamageCalc.retaliation_range(p[0], p[1], 10000), Vector2i(-1, -1), "цель погибнет — ответа нет")
	p[1].retaliated = true
	assert_eq(DamageCalc.retaliation_range(p[0], p[1], 0), Vector2i(-1, -1), "уже отвечала")
	p[1].statuses[UnitState.STATUS_SHIELD_WALL] = 1
	assert_ne(DamageCalc.retaliation_range(p[0], p[1], 0), Vector2i(-1, -1), "«Стена щитов» — отвечает всем")
	p[1].inert = true
	assert_eq(DamageCalc.retaliation_range(p[0], p[1], 0), Vector2i(-1, -1), "оцепенела")
