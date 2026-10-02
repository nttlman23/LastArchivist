class_name RunState
extends RefCounted
## Состояние забега. Сохраняется только на чекпоинтах (перед подготовкой к бою).

const SAVE_VERSION := 2
const REWARD_CHOICES := 3

var run_seed: int
## Индекс текущего боя в цепочке DefsDB.encounter_chain.
var battle_index := 0
var codex := CodexState.new()
var hero := HeroState.new()
var loot_rng := RandomNumberGenerator.new()


static func create(db: DefsDB, seed_value: int) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_value
	run.loot_rng.seed = hash("loot:%d" % seed_value)
	for id in db.starting_codex:
		run.codex.add(db, id)
	return run


func battle_seed() -> int:
	return hash("battle:%d:%d" % [run_seed, battle_index])


func current_encounter_id(db: DefsDB) -> StringName:
	return db.encounter_chain[battle_index]


func is_last_battle(db: DefsDB) -> bool:
	return battle_index >= db.encounter_chain.size() - 1


## Распад после победы: −1 картам-участникам и всем геройским картам.
func decay_after_battle(db: DefsDB, selected: Array[int]) -> Array[StringName]:
	var indices := selected.duplicate()
	for i in codex.hero_indices(db):
		if not indices.has(i):
			indices.append(i)
	return codex.decay(indices)


## Переносит остаток зарядов из боя; пустые заклинания исчезают.
func apply_spell_charges(charges: Array[int]) -> void:
	for i in mini(charges.size(), hero.spells.size()):
		hero.spells[i].charges = charges[i]
	var kept: Array[HeroState.SpellSlot] = []
	kept.assign(hero.spells.filter(func(s: HeroState.SpellSlot) -> bool: return s.charges > 0))
	hero.spells = kept


## Случайные карты для награды (могут повторяться между боями, но не внутри выбора).
func roll_rewards(db: DefsDB) -> Array[StringName]:
	var pool := db.memory_ids()
	var result: Array[StringName] = []
	for i in mini(REWARD_CHOICES, pool.size()):
		var idx := loot_rng.randi_range(0, pool.size() - 1)
		result.append(pool[idx])
		pool.remove_at(idx)
	return result


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"run_seed": str(run_seed),
		"battle_index": battle_index,
		"codex": codex.to_array(),
		"hero": hero.to_dict(),
		"loot_rng_seed": str(loot_rng.seed),
		"loot_rng_state": str(loot_rng.state),
	}


static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return null
	var run := RunState.new()
	run.run_seed = String(d["run_seed"]).to_int()
	run.battle_index = int(d["battle_index"])
	run.codex = CodexState.from_array(d["codex"])
	run.hero = HeroState.from_dict(d["hero"])
	run.loot_rng.seed = String(d["loot_rng_seed"]).to_int()
	run.loot_rng.state = String(d["loot_rng_state"]).to_int()
	return run
