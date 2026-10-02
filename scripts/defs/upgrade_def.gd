class_name UpgradeDef
extends Resource
## Постоянный бонус армии на забег.

@export var id: StringName
@export var name_key: String
## attack, defense, initiative, speed, hp_pct, shots
@export var stat: StringName
@export var amount: int = 1
@export var ranged_only := false
