class_name RelicDef
extends Resource
## Реликвия (SPEC_SPRINT7 11): постоянный бонус на забег с ценой. Эффекты — в RelicOps по id.

@export var id: StringName
@export var name_key: String
## Описание: бонус и цена.
@export var desc_key: String
@export var icon: StringName = &"points"
@export var color := Color(0.85, 0.75, 0.5)
