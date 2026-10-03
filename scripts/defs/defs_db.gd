class_name DefsDB
extends RefCounted
## Реестр всех определений, загружаемых из res://data.

const DATA_DIR := "res://data"

var units: Dictionary[StringName, UnitDef] = {}
var memories: Dictionary[StringName, MemoryCardDef] = {}
var encounters: Dictionary[StringName, EncounterDef] = {}
var abilities: Dictionary[StringName, AbilityDef] = {}
var spells: Dictionary[StringName, SpellDef] = {}
var orders: Dictionary[StringName, OrderDef] = {}
var upgrades: Dictionary[StringName, UpgradeDef] = {}
var events: Dictionary[StringName, EventDef] = {}
var schools: Dictionary[StringName, SchoolDef] = {}
var commanders: Dictionary[StringName, CommanderDef] = {}
const DEFAULT_SCHOOL := &"ash_archive"
## Приказы, доступные всегда.
var base_orders: Array[StringName] = [&"order_advance", &"order_close_ranks"]


static func load_default() -> DefsDB:
	var db := DefsDB.new()
	for res in _load_dir("units"):
		db.units[res.id] = res as UnitDef
	for res in _load_dir("memories"):
		db.memories[res.id] = res as MemoryCardDef
	for res in _load_dir("encounters"):
		db.encounters[res.id] = res as EncounterDef
	for res in _load_dir("abilities"):
		db.abilities[res.id] = res as AbilityDef
	for res in _load_dir("spells"):
		db.spells[res.id] = res as SpellDef
	for res in _load_dir("orders"):
		db.orders[res.id] = res as OrderDef
	for res in _load_dir("upgrades"):
		db.upgrades[res.id] = res as UpgradeDef
	for res in _load_dir("events"):
		db.events[res.id] = res as EventDef
	for res in _load_dir("schools"):
		db.schools[res.id] = res as SchoolDef
	for res in _load_dir("commanders"):
		db.commanders[res.id] = res as CommanderDef
	return db


func unit(id: StringName) -> UnitDef:
	assert(units.has(id), "Unknown unit: %s" % id)
	return units[id]


func commander(id: StringName) -> CommanderDef:
	assert(commanders.has(id), "Unknown commander: %s" % id)
	return commanders[id]


func commander_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in commanders:
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func memory(id: StringName) -> MemoryCardDef:
	assert(memories.has(id), "Unknown memory: %s" % id)
	return memories[id]


func encounter(id: StringName) -> EncounterDef:
	assert(encounters.has(id), "Unknown encounter: %s" % id)
	return encounters[id]


func ability(id: StringName) -> AbilityDef:
	assert(abilities.has(id), "Unknown ability: %s" % id)
	return abilities[id]


func spell(id: StringName) -> SpellDef:
	assert(spells.has(id), "Unknown spell: %s" % id)
	return spells[id]


func order(id: StringName) -> OrderDef:
	assert(orders.has(id), "Unknown order: %s" % id)
	return orders[id]


func upgrade(id: StringName) -> UpgradeDef:
	assert(upgrades.has(id), "Unknown upgrade: %s" % id)
	return upgrades[id]


func school(id: StringName) -> SchoolDef:
	assert(schools.has(id), "Unknown school: %s" % id)
	return schools[id]


func schools_sorted() -> Array[SchoolDef]:
	var list: Array[SchoolDef] = []
	list.assign(schools.values())
	list.sort_custom(func(a: SchoolDef, b: SchoolDef) -> bool: return a.order < b.order)
	return list


func event(id: StringName) -> EventDef:
	assert(events.has(id), "Unknown event: %s" % id)
	return events[id]


## Шаблоны встреч уровня tier (элитные — отдельно), отсортированные по id.
func encounter_pool(tier: int, elite: bool) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in encounters:
		var e := encounters[id]
		if not e.boss and e.elite == elite and (elite or e.tier == tier):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func boss_encounter() -> StringName:
	for id in encounters:
		if encounters[id].boss:
			return id
	assert(false, "Нет встречи-босса")
	return &""


func event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(events.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func memory_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(memories.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


static func _load_dir(sub: String) -> Array[Resource]:
	var path := DATA_DIR.path_join(sub)
	var result: Array[Resource] = []
	for file in ResourceLoader.list_directory(path):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(path.path_join(file))
			if res:
				result.append(res)
	return result
