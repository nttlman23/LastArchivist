class_name CodexState
extends RefCounted
## Кодекс Памяти — колода карт-воспоминаний игрока.

const MAX_CARDS := 12
const MAX_LEVEL := 3


class Card:
	var memory_id: StringName
	var durability: int
	## Уровень слияния: численность = базовая × (1 + 0.5 × (level − 1)).
	var level := 1
	## «Надломлена» (SPEC_SPRINT12 2): стек погиб целиком — прочность не выше 1, пока карту не починят.
	var cracked := false

	func _init(id: StringName = &"", dur: int = 0, p_level: int = 1) -> void:
		memory_id = id
		durability = dur
		level = p_level

	func count(db: DefsDB) -> int:
		return floori(db.memory(memory_id).count * (1.0 + 0.5 * (level - 1)))

	## Ремонт на amount (не выше максимума): снимает «надломлена».
	func repair(db: DefsDB, amount: int) -> void:
		cracked = false
		durability = mini(db.memory(memory_id).max_durability, durability + amount)


var cards: Array[Card] = []


func is_full() -> bool:
	return cards.size() >= MAX_CARDS


func add(db: DefsDB, memory_id: StringName) -> Card:
	assert(not is_full())
	var card := Card.new(memory_id, db.memory(memory_id).max_durability)
	cards.append(card)
	return card


func remove_at(index: int) -> void:
	cards.remove_at(index)


## Индексы карт отрядов (геройские в бой не выставляются).
func unit_indices(db: DefsDB) -> Array[int]:
	var result: Array[int] = []
	for i in cards.size():
		if db.memory(cards[i].memory_id).is_unit():
			result.append(i)
	return result


## Индексы геройских карт.
func hero_indices(db: DefsDB) -> Array[int]:
	var result: Array[int] = []
	for i in cards.size():
		if not db.memory(cards[i].memory_id).is_unit():
			result.append(i)
	return result


func has_unit_cards(db: DefsDB) -> bool:
	return not unit_indices(db).is_empty()


## Снимает 1 прочность с карт по индексам и удаляет угасшие.
## Возвращает id угасших карт.
func decay(indices: Array[int]) -> Array[StringName]:
	var faded: Array[StringName] = []
	var to_remove: Array[int] = []
	for i in indices:
		var card := cards[i]
		card.durability -= 1
		if card.durability <= 0:
			faded.append(card.memory_id)
			to_remove.append(i)
	to_remove.sort()
	to_remove.reverse()
	for i in to_remove:
		cards.remove_at(i)
	return faded


func to_array() -> Array:
	var result: Array = []
	for c in cards:
		result.append({"memory_id": String(c.memory_id), "durability": c.durability, "level": c.level, "cracked": c.cracked})
	return result


static func from_array(arr: Array) -> CodexState:
	var codex := CodexState.new()
	for d: Dictionary in arr:
		var card := Card.new(StringName(d["memory_id"]), int(d["durability"]), int(d.get("level", 1)))
		card.cracked = bool(d.get("cracked", false))
		codex.cards.append(card)
	return codex


## Износ по итогам боя (SPEC_SPRINT12 2): карта -> на сколько угасает; надломленные — прочность не выше 1.
## Возвращает id угасших карт.
func wear(amounts: Dictionary, cracked_cards: Array) -> Array[StringName]:
	var faded: Array[StringName] = []
	for card: Card in amounts:
		card.durability -= int(amounts[card])
		if card.durability > 0 and cracked_cards.has(card):
			card.cracked = true
			card.durability = mini(card.durability, 1)
		if card.durability <= 0:
			faded.append(card.memory_id)
			cards.erase(card)
	return faded
