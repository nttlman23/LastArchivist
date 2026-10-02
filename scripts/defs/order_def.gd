class_name OrderDef
extends Resource
## Приказ Архивариуса. Логика — в HeroActions по id.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var target: Targeting.Kind = Targeting.Kind.ALLY
