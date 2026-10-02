class_name TestHelpers
extends RefCounted
## Фабрики для тестов: бой без реестра, со стеками на заданных клетках.


static func unit_def(id: StringName, overrides: Dictionary = {}) -> UnitDef:
	var d := UnitDef.new()
	d.id = id
	d.hp = 10
	d.attack = 5
	d.defense = 5
	d.dmg_min = 2
	d.dmg_max = 2
	d.speed = 4
	d.initiative = 5
	for key: String in overrides:
		d.set(key, overrides[key])
	return d


static func empty_battle(seed_value: int = 1) -> BattleState:
	var s := BattleState.new()
	s.rng.seed = seed_value
	for id in _db().abilities:
		s.ability_cooldowns[id] = _db().abilities[id].cooldown
	return s


static var _cached_db: DefsDB


static func _db() -> DefsDB:
	if _cached_db == null:
		_cached_db = DefsDB.load_default()
	return _cached_db


static func add(s: BattleState, side: int, hex: Vector2i, count: int = 10, overrides: Dictionary = {}) -> UnitState:
	return s.add_unit(unit_def(&"test", overrides), side, count, hex)


## Делает стек активным, минуя очередь.
static func activate(s: BattleState, u: UnitState) -> void:
	if s.round_number == 0:
		TurnManager.start_round(s)
	s.queue.erase(u.uid)
	s.active_uid = u.uid
