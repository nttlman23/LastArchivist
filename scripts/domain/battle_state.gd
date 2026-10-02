class_name BattleState
extends RefCounted
## Полное состояние боя — только данные, без узлов сцены.

enum Outcome { NONE, PLAYER_WON, PLAYER_LOST }

const PLAYER_COL := 0
const START_ROWS: Array[int] = [0, 2, 4, 6, 8]
const MAX_STACKS := 5

var grid := HexGrid.new()
var obstacles: Dictionary[Vector2i, bool] = {}
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


## Собирает бой из встречи и выбранных карт Кодекса.
static func create(db: DefsDB, encounter: EncounterDef, codex: CodexState, selected: Array[int], seed_value: int) -> BattleState:
	assert(selected.size() <= MAX_STACKS)
	var s := BattleState.new()
	s.rng.seed = seed_value
	for h in encounter.obstacles:
		s.obstacles[h] = true
	for i in selected.size():
		var card := codex.cards[selected[i]]
		var mem := db.memory(card.memory_id)
		var u := s.add_unit(db.unit(mem.unit_id), UnitState.Side.PLAYER, mem.count, Vector2i(PLAYER_COL, START_ROWS[i]))
		u.card_index = selected[i]
	var enemy_col := s.grid.width - 1
	for i in mini(encounter.unit_ids.size(), MAX_STACKS):
		s.add_unit(db.unit(encounter.unit_ids[i]), UnitState.Side.ENEMY, encounter.counts[i], Vector2i(enemy_col, START_ROWS[i]))
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


func is_free(hex: Vector2i) -> bool:
	return grid.in_bounds(hex) and not obstacles.has(hex) and unit_at(hex) == null


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


func to_dict() -> Dictionary:
	var obs: Array = []
	for h in obstacles:
		obs.append([h.x, h.y])
	var us: Array = []
	for u in units:
		us.append(u.to_dict())
	return {
		"width": grid.width, "height": grid.height, "obstacles": obs, "units": us,
		"round": round_number, "queue": queue.duplicate(), "wait_queue": wait_queue.duplicate(),
		"active_uid": active_uid, "outcome": outcome, "max_rounds": max_rounds,
		"objective": String(objective),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "next_uid": _next_uid,
	}


static func from_dict(d: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.grid = HexGrid.new(int(d["width"]), int(d["height"]))
	for h: Array in d["obstacles"]:
		s.obstacles[Vector2i(int(h[0]), int(h[1]))] = true
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
	return s
