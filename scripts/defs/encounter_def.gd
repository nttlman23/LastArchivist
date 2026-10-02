class_name EncounterDef
extends Resource
## Состав противника и арена для одного боя.

@export var id: StringName
@export var name_key: String
## Параллельные массивы: unit_ids[i] в количестве counts[i].
@export var unit_ids: Array[StringName] = []
@export var counts: Array[int] = []
@export var obstacles: Array[Vector2i] = []
