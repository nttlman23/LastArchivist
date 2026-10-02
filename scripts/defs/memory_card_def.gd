class_name MemoryCardDef
extends Resource
## Карта-воспоминание: отряд определённого размера или геройская карта, с ограниченной прочностью.

enum Kind { UNIT, HERO }

@export var id: StringName
@export var name_key: String
@export var kind: Kind = Kind.UNIT
@export var unit_id: StringName
@export var count: int = 1
@export var max_durability: int = 1
## Во что превращается карта отряда.
@export var spell_id: StringName
@export var upgrade_id: StringName
## Геройская карта: открываемый приказ и пассивный бонус, пока карта в Кодексе.
@export var order_id: StringName
@export var passive_upgrade_id: StringName
@export var desc_key: String


func is_unit() -> bool:
	return kind == Kind.UNIT
