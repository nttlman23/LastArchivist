class_name BattleState
extends RefCounted
## Полное состояние боя — только данные, без узлов сцены.

enum Outcome { NONE, PLAYER_WON, PLAYER_LOST }

const PLAYER_COL := 0
const START_ROWS: Array[int] = [0, 2, 4, 6, 8]
const MAX_STACKS := 5
const HERO_ACTIONS_PER_ROUND := 1

var grid := HexGrid.new()
var obstacles: Dictionary[Vector2i, bool] = {}
## Временные стены: клетка -> оставшиеся раунды.
var temp_obstacles: Dictionary[Vector2i, int] = {}
var units: Array[UnitState] = []
var round_number := 0
## uid стеков, которые ещё ходят в этом раунде (основная фаза).
var queue: Array[int] = []
## uid стеков, выбравших «Ждать».
var wait_queue: Array[int] = []
var active_uid := -1
var outcome := Outcome.NONE
var max_rounds := 30
var objective := &"eliminate"
var rng := RandomNumberGenerator.new()
var _next_uid := 1

# Архивариус (только сторона игрока).
var hero_actions_left := HERO_ACTIONS_PER_ROUND
var hero_orders: Array[StringName] = []
## Заклинания на бой: {spell_id, charges}; индексы совпадают с HeroState.spells.
var hero_spells: Array[Dictionary] = []
## Последняя способность отряда каждой стороны — для «Отголоска».
var last_ability: Dictionary[int, StringName] = {}
## Перезарядки способностей из реестра: бой симулируется без DefsDB.
var ability_cooldowns: Dictionary[StringName, int] = {}
## Бой с разломом: действует правило «Стирание» (SPEC_SPRINT3 6.2).
var rift := false
## Индексы карт Кодекса, чьи стеки стёрты разломом.
var erased_cards: Array[int] = []
## Хранитель Разлома (первый стек встречи-босса); его гибель — победа.
var boss_uid := -1
## Пассивка школы Архивариуса (SchoolPassives).
var passive_id: StringName


## Собирает бой из встречи и выбранных карт Кодекса.
static func create(db: DefsDB, encounter: EncounterDef, codex: CodexState, selected: Array[int], seed_value: int,
		hero: HeroState = null, passive: StringName = &"") -> BattleState:
	assert(selected.size() <= MAX_STACKS)
	var s := BattleState.new()
	s.rng.seed = seed_value
	for id in db.abilities:
		s.ability_cooldowns[id] = db.abilities[id].cooldown
	for h in encounter.obstacles:
		s.obstacles[h] = true
	s.rift = encounter.boss
	s.passive_id = passive
	var upgrades: Array[StringName] = []
	if hero:
		upgrades = hero.active_upgrades(db, codex)
		s.hero_orders = hero.available_orders(db, codex)
		for slot in hero.spells:
			s.hero_spells.append({"spell_id": slot.spell_id, "charges": slot.charges, "power": db.spell(slot.spell_id).power})
	for i in selected.size():
		var card := codex.cards[selected[i]]
		var mem := db.memory(card.memory_id)
		assert(mem.is_unit(), "Геройскую карту нельзя выставить в бой")
		var u := s.add_unit(db.unit(mem.unit_id), UnitState.Side.PLAYER, card.count(db), Vector2i(PLAYER_COL, START_ROWS[i]))
		u.card_index = selected[i]
		HeroState.apply_upgrades(db, upgrades, u)
	var enemy_col := s.grid.width - 1
	for i in mini(encounter.unit_ids.size(), MAX_STACKS):
		var e := s.add_unit(db.unit(encounter.unit_ids[i]), UnitState.Side.ENEMY, encounter.counts[i], Vector2i(enemy_col, START_ROWS[i]))
		if encounter.boss and i == 0:
			s.boss_uid = e.uid
			e.is_boss = true
	return s


func add_unit(def: UnitDef, side: int, count: int, hex: Vector2i) -> UnitState:
	var u := UnitState.from_def(def, _next_uid, side, count, hex)
	_next_uid += 1
	units.append(u)
	return u


func get_unit(uid: int) -> UnitState:
	for u in units:
		if u.uid == uid:
			return u
	return null


func active_unit() -> UnitState:
	return get_unit(active_uid)


func unit_at(hex: Vector2i) -> UnitState:
	for u in units:
		if u.is_alive() and u.hex == hex:
			return u
	return null


func is_obstacle(hex: Vector2i) -> bool:
	return obstacles.has(hex) or temp_obstacles.has(hex)


func is_free(hex: Vector2i) -> bool:
	return grid.in_bounds(hex) and not is_obstacle(hex) and unit_at(hex) == null


func alive(side: int) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for u in units:
		if u.is_alive() and u.side == side:
			result.append(u)
	return result


func alive_all() -> Array[UnitState]:
	var result: Array[UnitState] = []
	for u in units:
		if u.is_alive():
			result.append(u)
	return result


func enemies_of(u: UnitState) -> Array[UnitState]:
	return alive(1 - u.side)


## Стрелок заблокирован, если рядом стоит враг.
func is_blocked(u: UnitState) -> bool:
	for n in grid.neighbors(u.hex):
		var other := unit_at(n)
		if other and other.side != u.side:
			return true
	return false


## Живые стеки на соседних клетках.
func neighbors_of(hex: Vector2i) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for n in grid.neighbors(hex):
		var other := unit_at(n)
		if other:
			result.append(other)
	return result


## Стек уже сходил в этом раунде (не активен и не ждёт своей очереди).
func has_acted(u: UnitState) -> bool:
	return u.uid != active_uid and not queue.has(u.uid) and not wait_queue.has(u.uid)


func can_hero_act() -> bool:
	var u := active_unit()
	return outcome == Outcome.NONE and hero_actions_left > 0 and u != null and u.side == UnitState.Side.PLAYER


## Оставшиеся заряды заклинаний — для переноса в забег.
func spell_charges() -> Array[int]:
	var result: Array[int] = []
	for s in hero_spells:
		result.append(int(s["charges"]))
	return result


func to_dict() -> Dictionary:
	var obs: Array = []
	for h in obstacles:
		obs.append([h.x, h.y])
	var temp: Array = []
	for h in temp_obstacles:
		temp.append([h.x, h.y, temp_obstacles[h]])
	var us: Array = []
	for u in units:
		us.append(u.to_dict())
	var spells: Array = []
	for sp in hero_spells:
		spells.append({"spell_id": String(sp["spell_id"]), "charges": int(sp["charges"]), "power": int(sp["power"])})
	var last := {}
	for side in last_ability:
		last[str(side)] = String(last_ability[side])
	var cds := {}
	for id in ability_cooldowns:
		cds[String(id)] = ability_cooldowns[id]
	return {
		"width": grid.width, "height": grid.height, "obstacles": obs, "temp_obstacles": temp, "units": us,
		"round": round_number, "queue": queue.duplicate(), "wait_queue": wait_queue.duplicate(),
		"active_uid": active_uid, "outcome": outcome, "max_rounds": max_rounds,
		"objective": String(objective),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "next_uid": _next_uid,
		"hero_actions_left": hero_actions_left, "hero_orders": Array(hero_orders).map(func(x: StringName) -> String: return String(x)),
		"hero_spells": spells, "last_ability": last, "ability_cooldowns": cds,
		"rift": rift, "erased_cards": erased_cards.duplicate(), "boss_uid": boss_uid, "passive_id": String(passive_id),
	}


static func from_dict(d: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.grid = HexGrid.new(int(d["width"]), int(d["height"]))
	for h: Array in d["obstacles"]:
		s.obstacles[Vector2i(int(h[0]), int(h[1]))] = true
	for h: Array in d["temp_obstacles"]:
		s.temp_obstacles[Vector2i(int(h[0]), int(h[1]))] = int(h[2])
	for ud: Dictionary in d["units"]:
		s.units.append(UnitState.from_dict(ud))
	s.round_number = int(d["round"])
	for uid in d["queue"]:
		s.queue.append(int(uid))
	for uid in d["wait_queue"]:
		s.wait_queue.append(int(uid))
	s.active_uid = int(d["active_uid"])
	s.outcome = int(d["outcome"]) as Outcome
	s.max_rounds = int(d["max_rounds"])
	s.objective = StringName(d["objective"])
	s.rng.seed = String(d["rng_seed"]).to_int()
	s.rng.state = String(d["rng_state"]).to_int()
	s._next_uid = int(d["next_uid"])
	s.hero_actions_left = int(d["hero_actions_left"])
	for id: String in d["hero_orders"]:
		s.hero_orders.append(StringName(id))
	for sp: Dictionary in d["hero_spells"]:
		s.hero_spells.append({"spell_id": StringName(sp["spell_id"]), "charges": int(sp["charges"]), "power": int(sp["power"])})
	var last: Dictionary = d["last_ability"]
	for side: String in last:
		s.last_ability[int(side)] = StringName(last[side])
	var cds: Dictionary = d["ability_cooldowns"]
	for id: String in cds:
		s.ability_cooldowns[StringName(id)] = int(cds[id])
	s.rift = bool(d["rift"])
	s.boss_uid = int(d["boss_uid"])
	s.passive_id = StringName(d["passive_id"])
	for i in d["erased_cards"]:
		s.erased_cards.append(int(i))
	return s
