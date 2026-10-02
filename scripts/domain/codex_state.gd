class_name CodexState
extends RefCounted
## Кодекс Памяти — колода карт-воспоминаний игрока.

const MAX_CARDS := 12


class Card:
	var memory_id: StringName
	var durability: int

	func _init(id: StringName = &"", dur: int = 0) -> void:
		memory_id = id
		durability = dur


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


func has_unit_cards() -> bool:
	return not cards.is_empty()


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
		result.append({"memory_id": String(c.memory_id), "durability": c.durability})
	return result


static func from_array(arr: Array) -> CodexState:
	var codex := CodexState.new()
	for d: Dictionary in arr:
		codex.cards.append(Card.new(StringName(d["memory_id"]), int(d["durability"])))
	return codex
