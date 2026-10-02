class_name EncounterDef
extends Resource
## Состав противника и арена для одного боя.

@export var id: StringName
@export var name_key: String
## Параллельные массивы: unit_ids[i] в количестве counts[i].
@export var unit_ids: Array[StringName] = []
@export var counts: Array[int] = []
@export var obstacles: Array[Vector2i] = []
## Уровень 1–3 для подбора на карте (SPEC_SPRINT3 6.1).
@export var tier: int = 1
@export var elite := false
## Бой с Хранителем Разлома: действует правило «Стирание».
@export var boss := false
