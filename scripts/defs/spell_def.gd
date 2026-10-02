class_name SpellDef
extends Resource
## Заклинание Архивариуса, получаемое из карты отряда. Логика — в HeroActions по id.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var target: Targeting.Kind = Targeting.Kind.ENEMY
## Основная величина эффекта (урон, лечение, бонус).
@export var power: int = 0
