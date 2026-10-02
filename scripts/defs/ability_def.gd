class_name AbilityDef
extends Resource
## Активная способность отряда. Логика — в Abilities по id.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var cooldown: int = 2
@export var target: Targeting.Kind = Targeting.Kind.NONE
