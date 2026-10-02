class_name DefsDB
extends RefCounted
## Реестр всех определений, загружаемых из res://data.

const UNITS_DIR := "res://data/units"
const MEMORIES_DIR := "res://data/memories"
const ENCOUNTERS_DIR := "res://data/encounters"

var units: Dictionary[StringName, UnitDef] = {}
var memories: Dictionary[StringName, MemoryCardDef] = {}
var encounters: Dictionary[StringName, EncounterDef] = {}
## Порядок боёв забега.
var encounter_chain: Array[StringName] = [&"crypt_1", &"crypt_2", &"crypt_3"]
var starting_codex: Array[StringName] = [&"salt_legion", &"salt_legion", &"ash_chroniclers", &"ghoul_pack"]


static func load_default() -> DefsDB:
	var db := DefsDB.new()
	for res in _load_dir(UNITS_DIR):
		var u := res as UnitDef
		if u:
			db.units[u.id] = u
	for res in _load_dir(MEMORIES_DIR):
		var m := res as MemoryCardDef
		if m:
			db.memories[m.id] = m
	for res in _load_dir(ENCOUNTERS_DIR):
		var e := res as EncounterDef
		if e:
			db.encounters[e.id] = e
	return db


func unit(id: StringName) -> UnitDef:
	assert(units.has(id), "Unknown unit: %s" % id)
	return units[id]


func memory(id: StringName) -> MemoryCardDef:
	assert(memories.has(id), "Unknown memory: %s" % id)
	return memories[id]


func encounter(id: StringName) -> EncounterDef:
	assert(encounters.has(id), "Unknown encounter: %s" % id)
	return encounters[id]


func memory_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(memories.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


static func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for file in ResourceLoader.list_directory(path):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(path.path_join(file))
			if res:
				result.append(res)
	return result
