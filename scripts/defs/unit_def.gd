class_name UnitDef
extends Resource
## Неизменяемое описание типа существа.

@export var id: StringName
@export var name_key: String
@export var hp: int = 10
@export var attack: int = 1
@export var defense: int = 1
@export var dmg_min: int = 1
@export var dmg_max: int = 1
@export var speed: int = 3
@export var initiative: int = 5
@export var is_ranged := false
@export var shots: int = 0
@export var is_flying := false
@export var color := Color.WHITE
